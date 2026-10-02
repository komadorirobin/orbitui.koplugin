#!/usr/bin/env python3
"""Report upstream state. Never merge, execute upstream code, or publish builds."""

import argparse
import datetime
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import sys


MARKER = "<!-- orbitui-upstream-watch:v1 -->"
TITLE = "OrbitUI upstream status (monitoring only)"
LABEL = "upstream-watch"
SLUG = re.compile(r"[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+\Z")
SHA = re.compile(r"[0-9a-f]{40}\Z")


class WatchError(Exception):
    pass


def run(argv, cwd=None, data=None, allow_failure=False):
    result = subprocess.run(argv, cwd=cwd, input=data, text=True, encoding="utf-8",
                            errors="replace", capture_output=True, timeout=120,
                            env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if result.returncode and not allow_failure:
        raise WatchError(result.stderr.strip()[:1000] or "Command failed: " + argv[0])
    return result


class Git:
    def __init__(self, root):
        self.root = root

    def text(self, *args):
        return run(["git", *args], cwd=self.root).stdout.strip()

    def ancestor(self, older, newer):
        result = run(["git", "merge-base", "--is-ancestor", older, newer],
                     cwd=self.root, allow_failure=True)
        if result.returncode not in (0, 1):
            raise WatchError(result.stderr.strip()[:1000])
        return result.returncode == 0


class GitHub:
    def request(self, endpoint, method="GET", payload=None, missing_ok=False):
        args = ["gh", "api", "--hostname", "github.com", "--method", method, endpoint]
        data = None
        if payload is not None:
            args += ["--input", "-"]
            data = json.dumps(payload)
        result = run(args, data=data, allow_failure=True)
        if result.returncode:
            if missing_ok and "HTTP 404" in result.stderr:
                return None
            raise WatchError(result.stderr.strip()[:1000] or "GitHub API request failed")
        return json.loads(result.stdout) if result.stdout.strip() else None

    def pages(self, endpoint):
        values = []
        separator = "&" if "?" in endpoint else "?"
        for page in range(1, 101):
            batch = self.request(f"{endpoint}{separator}per_page=100&page={page}")
            if not isinstance(batch, list):
                raise WatchError("Expected a GitHub list response")
            values.extend(batch)
            if len(batch) < 100:
                return values
        raise WatchError("GitHub pagination limit reached; refusing a partial issue lookup")


def repository_slug(url):
    match = re.fullmatch(r"https://github\.com/([A-Za-z0-9_-]+/[A-Za-z0-9_.-]+)\.git", url)
    if not match:
        raise WatchError("Upstream must be an HTTPS github.com repository ending in .git")
    return match.group(1)


def load_sources(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or set(data.get("components", {})) != {"bookshelf", "simpleui"}:
        raise WatchError("Unexpected sources.json schema or component set")
    for name, source in data["components"].items():
        repository_slug(source["upstream"])
        if source.get("path") != "components/" + name:
            raise WatchError("Unexpected component path: " + name)
        for key in ("commit", "upstream_commit"):
            if not SHA.fullmatch(source.get(key, "")):
                raise WatchError("Expected a full commit SHA: " + name + "." + key)
        branch = source.get("upstream_branch", "")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*", branch):
            raise WatchError("Invalid upstream branch: " + name)
        run(["git", "check-ref-format", "refs/heads/" + branch])
    return data["components"]


def latest_release(api, slug):
    release = api.request(f"repos/{slug}/releases/latest", missing_ok=True)
    if release is None:
        return None
    if release.get("draft") or release.get("prerelease"):
        raise WatchError("Latest stable release endpoint returned an unpublished or prerelease item")
    return {key: release[key] for key in ("id", "tag_name", "published_at")}


def collect_component(git, api, name, source, head):
    slug = repository_slug(source["upstream"])
    item = {"name": name, "repository": slug, "branch": source["upstream_branch"],
            "integrated": source["upstream_commit"], "status": "ok", "errors": []}
    phase = "history"
    try:
        if not git.ancestor(source["commit"], head) or not git.ancestor(item["integrated"], head):
            raise WatchError("Recorded import/upstream revision is not in OrbitUI history")
        phase = "fetch"
        ref = "refs/remotes/orbitui-watch/" + name
        # This only updates a private remote-tracking ref, never a branch/worktree.
        git.text("fetch", "--no-tags", "--no-recurse-submodules", source["upstream"],
                 "+refs/heads/" + item["branch"] + ":" + ref)
        tip = git.text("rev-parse", ref + "^{commit}")
        if not SHA.fullmatch(tip):
            raise WatchError("Invalid fetched commit")
        item["head"] = tip
        phase = "history"
        if not git.ancestor(item["integrated"], tip):
            raise WatchError("Upstream no longer contains the integrated revision; manual review required")
        bases = git.text("merge-base", "--all", head, tip).splitlines()
        if len(bases) != 1:
            raise WatchError("Ambiguous merge base; manual history review required")
        item["included"] = bases[0]
        item["manifest_stale"] = bases[0] != item["integrated"]
        delta = head + ".." + tip
        item["behind"] = int(git.text("rev-list", "--count", delta))
        log = git.text("log", "--max-count=25", "--format=%H%x09%s", delta)
        item["commits"] = [dict(zip(("sha", "subject"), line.split("\t", 1)))
                           for line in log.splitlines() if line]
        files = git.text("diff", "--name-only", bases[0], tip).splitlines()
        item["changed_files"] = len(files)
    except (WatchError, subprocess.TimeoutExpired) as error:
        item["status"] = "error"
        item["errors"].append({"phase": phase, "message": str(error)[:1000]})
    try:
        item["release"] = latest_release(api, slug)
    except (WatchError, subprocess.TimeoutExpired, KeyError, ValueError) as error:
        item["status"] = "error"
        item["errors"].append({"phase": "releases", "message": str(error)[:1000]})
    return item


def fingerprint(report):
    # Timestamps, OrbitUI-only commits and volatile error messages are not news.
    state = [{key: item.get(key) for key in (
        "name", "repository", "branch", "integrated", "head", "included", "behind",
        "manifest_stale", "release", "status")}
        | {"error_phases": sorted({error["phase"] for error in item["errors"]})}
        for item in report["components"]]
    return hashlib.sha256(json.dumps(state, sort_keys=True).encode()).hexdigest()


def safe_text(value):
    value = " ".join(str(value).split())[:400]
    return "".join("&#" + str(ord(char)) + ";" if char in "\\`*_{}[]()#!|@"
                   else html.escape(char, quote=True) for char in value)


def commit_link(slug, sha):
    if not SHA.fullmatch(sha):
        raise WatchError("Invalid commit in report")
    return f"[{sha[:8]}](https://github.com/{slug}/commit/{sha})"


def render(report):
    from urllib.parse import quote
    lines = [MARKER, "<!-- orbitui-upstream-state:" + fingerprint(report) + " -->",
             "# OrbitUI upstream status", "",
             "**Monitoring only. Nothing is merged, installed or released by this job.**", "",
             "Last check: " + report["checked_at"] + ".",
             "Counts are upstream commits absent from OrbitUI history, including merge commits.",
             "They are not counts of features or a compatibility verdict.", "",
             "| Component | Branch | Missing commits | Latest stable release | State |",
             "| --- | --- | ---: | --- | --- |"]
    for item in report["components"]:
        release = item.get("release")
        release_text = "None published" if "release" in item else "Unavailable"
        if release:
            release_text = (f"[{safe_text(release['tag_name'])}](https://github.com/"
                            f"{item['repository']}/releases/tag/{quote(release['tag_name'], safe='')})")
        status = "CHECK FAILED" if item["status"] == "error" else (
            "Manifest needs review" if item.get("manifest_stale") else "Checked")
        count = str(item["behind"]) if "behind" in item else "Unknown"
        lines.append(f"| {item['name']} | {safe_text(item['branch'])} | {count} | {release_text} | {status} |")
    for item in report["components"]:
        slug = item["repository"]
        lines += ["", "## " + item["name"], "",
                  "Recorded integrated upstream: " + commit_link(slug, item["integrated"]) + "."]
        if item.get("head"):
            lines.append("Observed upstream tip: " + commit_link(slug, item["head"]) + ".")
        if item.get("manifest_stale"):
            lines.append("Additional upstream history is already included. Update sources.json during the next reviewed merge.")
        for error in item["errors"]:
            lines.append("- **" + safe_text(error["phase"]) + " check failed:** " + safe_text(error["message"]))
        if "changed_files" in item:
            lines += [f"Net upstream changes since the included revision: {item['changed_files']} files.", ""]
        for commit in item.get("commits", []):
            lines.append("- " + commit_link(slug, commit["sha"]) + " " + safe_text(commit["subject"]))
        remaining = item.get("behind", 0) - len(item.get("commits", []))
        if remaining > 0:
            lines.append(f"- {remaining} more commits; inspect the complete Git history before merging.")
    lines += ["", "## Next step", "",
              "Ask for a reviewed upstream merge in the development conversation. Follow docs/UPSTREAM.md",
              "and docs/INTEGRATION_CONTRACTS.md. A clean merge and passing CI do not replace device testing.", "",
              "This issue stays open as the dashboard. A change produces one comment; unchanged checks do not.",
              "Notifications follow your GitHub issue-subscription settings. Pause via the Actions workflow, not by closing this issue."]
    return "\n".join(lines) + "\n"


def publish(api, repository, report, assignee=None):
    if not SLUG.fullmatch(repository):
        raise WatchError("Invalid issue repository")
    if assignee and not re.fullmatch(r"[A-Za-z0-9_-]+", assignee):
        raise WatchError("Invalid assignee")
    endpoint = "repos/" + repository
    live_head = api.request(endpoint + "/git/ref/heads/main")["object"]["sha"]
    if report.get("schema") != 1 or report.get("orbitui_commit") != live_head:
        raise WatchError("Report is not for current main; collect again before publishing")
    body = render(report)
    issues = api.pages(endpoint + "/issues?state=all")
    matches = [issue for issue in issues if not issue.get("pull_request")
               and (issue.get("body") or "").startswith(MARKER)]
    if len(matches) > 1:
        raise WatchError("Multiple upstream dashboards found; refusing to update an arbitrary issue")
    if not matches:
        label = api.request(endpoint + "/labels/" + LABEL, missing_ok=True)
        if label is None:
            api.request(endpoint + "/labels", "POST", {
                "name": LABEL, "color": "27656B", "description": "Read-only upstream monitoring; no automatic merges"})
        payload = {"title": TITLE, "body": body, "labels": [LABEL]}
        if assignee:
            payload["assignees"] = [assignee]
        return api.request(endpoint + "/issues", "POST", payload)["html_url"]
    issue = matches[0]
    target = endpoint + "/issues/" + str(issue["number"])
    old = re.search(r"<!-- orbitui-upstream-state:([0-9a-f]{64}) -->", issue.get("body") or "")
    previous = old.group(1) if old else "initial"
    current = fingerprint(report)
    if previous != current:
        transition = hashlib.sha256((previous + ":" + current).encode()).hexdigest()
        notice = "<!-- orbitui-upstream-notice:" + transition + " -->"
        comments = api.pages(target + "/comments")
        notices = [comment.get("body", "") for comment in comments
                   if comment.get("body", "").startswith("<!-- orbitui-upstream-notice:")]
        # Comment first; retries after a failed dashboard update must not spam.
        if not notices or not notices[-1].startswith(notice):
            summary = "\n".join(f"- {item['name']}: " + (
                "check failed; see dashboard" if item["status"] == "error" else
                str(item.get("behind", "unknown")) + " commits not imported")
                for item in report["components"])
            api.request(target + "/comments", "POST", {"body": notice
                + "\nUpstream status changed. No merge or release was performed.\n\n" + summary})
    api.request(target, "PATCH", {"title": TITLE, "body": body, "state": "open"})
    return issue["html_url"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    collect = sub.add_parser("collect")
    collect.add_argument("--output-dir", type=Path, default=Path("test-results/upstream-watch"))
    posting = sub.add_parser("publish")
    posting.add_argument("--report", type=Path, required=True)
    posting.add_argument("--repository", required=True)
    posting.add_argument("--assignee")
    args = parser.parse_args()
    api = GitHub()
    if args.command == "publish":
        report = json.loads(args.report.read_text(encoding="utf-8"))
        print(publish(api, args.repository, report, args.assignee))
        return 0
    root = Path(__file__).resolve().parent.parent
    git = Git(root)
    if git.text("rev-parse", "--is-shallow-repository") != "false":
        raise WatchError("Full Git history is required; use checkout fetch-depth: 0")
    head = git.text("rev-parse", "HEAD")
    sources = load_sources(root / "sources.json")
    report = {"schema": 1, "orbitui_commit": head,
              "checked_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
              "components": [collect_component(git, api, name, source, head)
                             for name, source in sorted(sources.items())]}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / "report.md").write_text(render(report), encoding="utf-8")
    print(render(report))
    return int(any(item["status"] == "error" for item in report["components"]))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (WatchError, subprocess.TimeoutExpired, OSError, ValueError, KeyError) as exc:
        print("Upstream watch failed: " + str(exc), file=sys.stderr)
        sys.exit(1)
