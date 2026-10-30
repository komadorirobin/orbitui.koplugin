#!/usr/bin/env python3
"""Observe selected design references; never import or execute their code."""
import argparse
import datetime
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from upstream_watch import Git, GitHub, SHA, SLUG, WatchError, run, safe_text

MARKER = "<!-- orbitui-inspiration-watch:v1 -->"
TITLE = "OrbitUI inspiration references (review only)"
LIMIT = 5000


def load_sources(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or not isinstance(data.get("references"), list):
        raise WatchError("Invalid inspiration source schema")
    names = set()
    for source in data["references"]:
        name = source.get("id", "")
        if not re.fullmatch(r"[a-z][a-z0-9-]*", name) or name in names:
            raise WatchError("Invalid or duplicate reference ID")
        names.add(name)
        if not SLUG.fullmatch(source.get("repository", "")) or not SHA.fullmatch(source.get("reviewed_commit", "")):
            raise WatchError("Invalid repository or reviewed reference commit")
        branch = source.get("branch", "")
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_./-]*", branch):
            raise WatchError("Invalid reference branch")
        run(["git", "check-ref-format", "refs/heads/" + branch])
        if not isinstance(source.get("ideas"), list) or not source["ideas"]:
            raise WatchError("Each reference needs an explicit idea/path mapping")
        for idea in source["ideas"]:
            if (not idea.get("idea") or not idea.get("orbitui")
                    or idea.get("relationship") not in ("design-reference", "review-only")
                    or not isinstance(idea.get("paths"), list) or not idea["paths"]):
                raise WatchError("Invalid reference idea")
            for pattern in idea["paths"]:
                if (not isinstance(pattern, str) or not pattern or pattern.startswith(("/", "-"))
                        or ".." in pattern.split("/") or any(ord(c) < 32 for c in pattern)
                        or pattern in ("*", "**")):
                    raise WatchError("Unsafe or excessively broad path pattern")
    return data["references"]


def matched_ideas(source, paths):
    return [idea["idea"] for idea in source["ideas"]
            if any(fnmatch.fnmatchcase(path, pattern) for path in paths for pattern in idea["paths"])]


def changed_paths(git, commit):
    # Inspect every commit, not just the net diff: changes later reverted still
    # matter. -m covers merge resolutions; both sides of renames/copies count.
    raw = run(["git", "diff-tree", "--root", "-r", "-m", "--no-commit-id",
               "--name-status", "-z", "--find-renames", commit], cwd=git.root).stdout
    tokens = raw.rstrip("\0").split("\0") if raw else []
    paths, moved = set(), False
    pos = 0
    while pos < len(tokens):
        status = tokens[pos]; pos += 1
        count = 2 if status.startswith(("R", "C")) else 1
        if not re.fullmatch(r"[ACDMRTUXB][0-9]*", status) or pos + count > len(tokens):
            raise WatchError("Unrecognised Git change record; refusing partial filtering")
        paths.update(tokens[pos:pos + count]); pos += count
        moved = moved or status.startswith(("R", "D"))
    return sorted(paths), moved


def release_signature(value):
    if value is None:
        return None
    # No download or execution. Same-tag asset replacements are visible too.
    return {"tag": value["tag_name"], "id": value.get("id"), "published_at": value.get("published_at"),
            "notes_sha256": hashlib.sha256((value.get("body") or "").encode()).hexdigest(),
            "assets": sorted([{"id": a["id"], "name": a["name"], "size": a["size"],
                               "updated_at": a.get("updated_at"), "digest": a.get("digest")}
                              for a in value.get("assets", [])], key=lambda a: a["id"])}


def collect_reference(git, api, source):
    result = {"id": source["id"], "repository": source["repository"],
              "reviewed_commit": source["reviewed_commit"], "ideas": source["ideas"],
              "status": "ok", "matches": [], "warnings": [], "errors": []}
    phase = "fetch"
    try:
        ref = "refs/remotes/orbitui-inspiration/" + source["id"]
        git.text("fetch", "--no-tags", "--no-recurse-submodules",
                 "https://github.com/" + source["repository"] + ".git",
                 "+refs/heads/" + source["branch"] + ":" + ref)
        tip = git.text("rev-parse", ref)
        result["observed_commit"] = tip
        phase = "history"
        if not git.ancestor(source["reviewed_commit"], tip):
            raise WatchError("Reference history changed; manually review the baseline (no automatic reset)")
        count = int(git.text("rev-list", "--count", source["reviewed_commit"] + ".." + tip))
        result["commits_scanned"] = count
        if count > LIMIT:
            raise WatchError("More than 5000 commits pending; manual baseline review required")
        # Validate every configured exact file/glob against the *current* tree.
        tree = git.text("ls-tree", "-r", "--name-only", "-z", tip).split("\0")
        for idea in source["ideas"]:
            for pattern in idea["paths"]:
                if not any(fnmatch.fnmatchcase(path, pattern) for path in tree):
                    result["warnings"].append("Missing tracked path: " + pattern + " (" + idea["idea"] + ")")
        commits = git.text("rev-list", "--reverse", source["reviewed_commit"] + ".." + tip).splitlines()
        for commit in commits:
            paths, moved = changed_paths(git, commit)
            ideas = matched_ideas(source, paths)
            if ideas:
                result["matches"].append({"sha": commit, "subject": git.text("show", "-s", "--format=%s", commit),
                                          "ideas": ideas, "paths": paths, "path_review": moved})
        if source.get("release_watch"):
            phase = "release"
            result["release"] = release_signature(api.request(
                "repos/" + source["repository"] + "/releases/latest", missing_ok=True))
            result["warnings"].append("Release-only source: inspect published assets manually; README filtering cannot inspect code")
    except (WatchError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as exc:
        result["status"] = "error"
        result["errors"].append({"phase": phase, "message": str(exc)[:1000]})
    return result


def fingerprint(report):
    # An unrelated source commit or a new OrbitUI commit is NOT a notification.
    # Stable failures do not spam merely because a server's raw error changes.
    state = [{"id": r["id"], "reviewed_commit": r["reviewed_commit"], "ideas": r["ideas"],
              "status": r["status"], "matches": r["matches"], "warnings": r["warnings"],
              "errors": [e["phase"] for e in r["errors"]], "release": r.get("release")}
             for r in report["references"]]
    return hashlib.sha256(json.dumps(state, sort_keys=True).encode()).hexdigest()


def render(report):
    lines = [MARKER, "<!-- orbitui-inspiration-state:" + fingerprint(report) + " -->",
             "# Inspiration references / Inspirationsbevakning", "",
             "Review suggestions only / Endast granskningsförslag. No merge, code import, release or OTA.",
             "Reviewed reference ≠ integrated upstream. These are design references, not vendored components.",
             "Path filters are conservative leads, not proof that other commits are irrelevant.",
             "Checked: " + safe_text(report["checked_at"]), ""]
    for r in report["references"]:
        base = "https://github.com/" + r["repository"]
        lines += ["## " + safe_text(r["id"]), "",
                  "[Reference repository](" + base + ") · reviewed `" + r["reviewed_commit"][:12] + "`",
                  ((str(len(r["matches"])) + " matching commits / matchande commits") if r["status"] == "ok"
                   else "Incomplete check / Ofullständig kontroll; matching count unknown") + "; status: " + r["status"], ""]
        for idea in r["ideas"]:
            lines += ["- " + safe_text(idea["idea"]) + " → " + safe_text(idea["orbitui"])
                      + " (" + idea["relationship"] + ")"]
        for match in r["matches"][:10]:
            lines += ["- [" + match["sha"][:10] + "](" + base + "/commit/" + match["sha"] + ") "
                      + safe_text(match["subject"]) + " — " + safe_text(", ".join(match["ideas"]))
                      + (" **Rename/deletion: review paths.**" if match["path_review"] else "")]
        if len(r["matches"]) > 10:
            lines += ["More matches in the JSON artifact; dashboard displays the first 10 per reference."]
        for warning in r["warnings"]:
            lines += ["- Manual review: " + safe_text(warning)]
        for error in r["errors"]:
            lines += ["- CHECK FAILED (" + safe_text(error["phase"]) + "): " + safe_text(error["message"])]
        if r.get("release"):
            lines += ["- Latest published asset signature: " + safe_text(r["release"]["tag"])
                      + "; compare artifact JSON for asset replacements."]
        lines += [""]
    return "\n".join(lines) + "\n"


def publish(api, repository, report):
    if not SLUG.fullmatch(repository) or report.get("schema") != 1:
        raise WatchError("Invalid report destination/schema")
    endpoint = "repos/" + repository
    if report["orbitui_commit"] != api.request(endpoint + "/git/ref/heads/main")["object"]["sha"]:
        raise WatchError("Stale report; collect against current main before publishing")
    issues = [i for i in api.pages(endpoint + "/issues?state=all") if not i.get("pull_request")
              and (i.get("body") or "").startswith(MARKER)]
    if len(issues) > 1:
        raise WatchError("Duplicate inspiration dashboards; refusing arbitrary update")
    body = render(report)
    if not issues:
        return api.request(endpoint + "/issues", "POST", {"title": TITLE, "body": body})["html_url"]
    issue = issues[0]
    target = endpoint + "/issues/" + str(issue["number"])
    old = re.search(r"<!-- orbitui-inspiration-state:([0-9a-f]{64}) -->", issue.get("body") or "")
    previous, current = old.group(1) if old else "initial", fingerprint(report)
    if previous != current:
        notice = "<!-- orbitui-inspiration-notice:" + hashlib.sha256((previous + ":" + current).encode()).hexdigest() + " -->"
        notices = [c.get("body", "") for c in api.pages(target + "/comments")
                   if c.get("body", "").startswith("<!-- orbitui-inspiration-notice:")]
        if not notices or not notices[-1].startswith(notice):
            api.request(target + "/comments", "POST", {"body": notice
                        + "\nInspiration status changed / Inspirationsläget har ändrats. Review the dashboard. No code was imported."})
    api.request(target, "PATCH", {"title": TITLE, "body": body, "state": "open"})
    return issue["html_url"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    collecting = sub.add_parser("collect")
    collecting.add_argument("--output-dir", type=Path, default=Path("test-results/inspiration-watch"))
    posting = sub.add_parser("publish")
    posting.add_argument("--report", type=Path, required=True)
    posting.add_argument("--repository", required=True)
    args = parser.parse_args()
    api = GitHub()
    if args.command == "publish":
        print(publish(api, args.repository, json.loads(args.report.read_text(encoding="utf-8"))))
        return 0
    root = Path(__file__).resolve().parent.parent
    git = Git(root)
    if git.text("rev-parse", "--is-shallow-repository") != "false":
        raise WatchError("Full checkout required")
    report = {"schema": 1, "orbitui_commit": git.text("rev-parse", "HEAD"),
              "checked_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
              "references": [collect_reference(git, api, s) for s in load_sources(root / "scripts/inspiration-sources.json")]}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    (args.output_dir / "report.md").write_text(render(report), encoding="utf-8")
    print(render(report))
    return int(any(r["status"] == "error" for r in report["references"]))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (WatchError, OSError, ValueError, KeyError, subprocess.TimeoutExpired) as exc:
        print("Inspiration watch failed: " + str(exc), file=sys.stderr)
        sys.exit(1)
