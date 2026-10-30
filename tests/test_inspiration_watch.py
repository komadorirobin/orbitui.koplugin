import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import inspiration_watch as w
from test_upstream_watch import FakeAPI as UpstreamAPI, HEAD


class FakeAPI(UpstreamAPI):
    def request(self, *args, **kwargs):
        try:
            return super().request(*args, **kwargs)
        except Exception as exc:
            raise w.WatchError(str(exc)) from exc

SOURCE = {"id": "example", "repository": "owner/example", "branch": "main",
          "reviewed_commit": "a" * 40,
          "ideas": [{"idea": "Search", "relationship": "design-reference", "orbitui": "core/orbitui_search.lua",
                     "paths": ["ui/search.lua", "data/cache*.lua"]}]}


class FakeGit:
    root = ROOT
    def __init__(self):
        self.calls, self.count, self.rewritten, self.failure = [], 2, False, None
    def ancestor(self, a, b): return not self.rewritten
    def text(self, *args):
        self.calls.append(args)
        if args[0] == self.failure: raise w.WatchError("Failed")
        return {"fetch": "", "rev-parse": "b" * 40, "ls-tree": "ui/search.lua\0data/cache.lua\0",
                "rev-list": str(self.count) if "--count" in args else "c" * 40 + "\n" + "d" * 40,
                "show": "untrusted @person <b> [title]"}[args[0]]


def collected(git=None):
    with patch.object(w, "changed_paths", side_effect=[(["ui/search.lua"], False), (["README.md"], False)]):
        return w.collect_reference(git or FakeGit(), FakeAPI(), SOURCE)


def report():
    return {"schema": 1, "orbitui_commit": HEAD, "checked_at": "now", "references": [collected()]}


class InspirationTests(unittest.TestCase):
    def test_only_selected_ideas_not_all_repo_commits(self):
        git = FakeGit(); r = collected(git)
        self.assertEqual(r["status"], "ok")
        self.assertEqual(r["commits_scanned"], 2)
        self.assertEqual(len(r["matches"]), 1)
        self.assertEqual(r["matches"][0]["ideas"], ["Search"])
        self.assertEqual(git.calls[0][-1], "+refs/heads/main:refs/remotes/orbitui-inspiration/example")
        self.assertTrue(set(c[0] for c in git.calls) <= {"fetch", "rev-parse", "rev-list", "ls-tree", "show"})

    def test_noise_does_not_change_notification_fingerprint(self):
        r = report(); other = copy.deepcopy(r)
        other["orbitui_commit"], other["checked_at"] = "f" * 40, "later"
        other["references"][0]["observed_commit"] = "e" * 40
        other["references"][0]["commits_scanned"] = 100
        self.assertEqual(w.fingerprint(r), w.fingerprint(other))
        other["references"][0]["matches"][0]["sha"] = "e" * 40
        self.assertNotEqual(w.fingerprint(r), w.fingerprint(other))

    def test_fetch_history_and_limit_fail_closed(self):
        for mode in ("fetch", "rewrite", "limit"):
            git = FakeGit()
            if mode == "fetch": git.failure = "fetch"
            if mode == "rewrite": git.rewritten = True
            if mode == "limit": git.count = 5001
            r = collected(git)
            self.assertEqual(r["status"], "error")
            self.assertEqual(r["matches"], [])
            rendered = w.render({"checked_at": "now", "references": [r]})
            self.assertIn("matching count unknown", rendered)
            self.assertNotIn("0 matching commits", rendered)

    def test_missing_paths_warn_and_rename_destination_matches(self):
        source = copy.deepcopy(SOURCE); source["ideas"][0]["paths"].append("moved.lua")
        with patch.object(w, "changed_paths", return_value=(["ui/search.lua", "new/search.lua"], True)):
            r = w.collect_reference(FakeGit(), FakeAPI(), source)
        self.assertIn("Missing tracked path", r["warnings"][0])
        self.assertTrue(r["matches"][0]["path_review"])
        self.assertEqual(w.matched_ideas(source, ["data/cache-v2.lua"]), ["Search"])
        self.assertEqual(w.matched_ideas(source, ["unrelated/main.lua"]), [])

    def test_configuration_exact_files_and_local_destinations_exist(self):
        sources = w.load_sources(ROOT / "scripts/inspiration-sources.json")
        self.assertEqual(len(sources), 6)
        for source in sources:
            for idea in source["ideas"]:
                for path in idea["orbitui"].split("; "):
                    self.assertTrue((ROOT / path).is_file(), path)
        for bad in ("*", "../escape", "/root", "--option", "x\ny"):
            data = {"schema": 1, "references": [copy.deepcopy(SOURCE)]}
            data["references"][0]["ideas"][0]["paths"] = [bad]
            with tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / "sources.json"; path.write_text(json.dumps(data))
                with self.assertRaises(w.WatchError): w.load_sources(path)

    def test_release_asset_replacement_changes_signature(self):
        a = {"tag_name": "same", "assets": [{"id": 1, "name": "plugin.zip", "size": 99}]}
        b = copy.deepcopy(a); b["assets"][0]["id"] = 2
        self.assertNotEqual(w.release_signature(a), w.release_signature(b))
        source = {**SOURCE, "release_watch": True}
        with patch.object(w, "changed_paths", return_value=([], False)):
            r = w.collect_reference(FakeGit(), FakeAPI(), source)
        self.assertIn("Release-only source", r["warnings"][0])
        api = FakeAPI(); api.release_error = True
        with patch.object(w, "changed_paths", return_value=([], False)):
            r = w.collect_reference(FakeGit(), api, source)
        self.assertEqual(r["status"], "error"); self.assertEqual(r["errors"][0]["phase"], "release")
        self.assertEqual(api.writes, [], "collection must never post anything")

    def test_matching_list_is_complete_but_dashboard_is_bounded(self):
        r = report(); item = r["references"][0]
        item["matches"] = [copy.deepcopy(item["matches"][0]) for _ in range(75)]
        rendered = w.render(r)
        self.assertEqual(rendered.count("/commit/"), 10)
        self.assertIn("75 matching commits", rendered)
        self.assertIn("first 10 per reference", rendered)
        self.assertEqual(len(item["matches"]), 75)

    def test_merge_resolution_is_checked_against_each_parent(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*a, ok=True):
                p = subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=t@example.invalid", *a],
                                   cwd=tmp, capture_output=True, text=True)
                if ok: self.assertEqual(p.returncode, 0, p.stderr)
                return p.stdout.strip()
            git("init", "-qb", "main"); path = Path(tmp) / "search.lua"; path.write_text("base\n")
            git("add", "."); git("commit", "-qm", "base"); git("checkout", "-qb", "side")
            path.write_text("side\n"); git("commit", "-qam", "side change"); git("checkout", "-q", "main")
            path.write_text("main\n"); git("commit", "-qam", "main change"); git("merge", "side", ok=False)
            path.write_text("resolution\n"); git("add", "."); git("commit", "-qm", "resolve")
            paths, _ = w.changed_paths(w.Git(Path(tmp)), git("rev-parse", "HEAD"))
            self.assertIn("search.lua", paths)

    def test_dashboard_is_separate_escaped_and_deduplicates_retries(self):
        api, r = FakeAPI(), report()
        w.publish(api, "owner/orbitui", r)
        self.assertTrue(api.issues[0]["body"].startswith(w.MARKER))
        self.assertNotIn("@person", api.issues[0]["body"])
        self.assertNotIn("<b>", api.issues[0]["body"])
        w.publish(api, "owner/orbitui", r)
        self.assertEqual(len(api.comments), 0)
        r["references"][0]["warnings"].append("path moved")
        api.fail_patch = True
        with self.assertRaises(w.WatchError): w.publish(api, "owner/orbitui", r)
        api.fail_patch = False; w.publish(api, "owner/orbitui", r)
        self.assertEqual(len(api.comments), 1)
        r["orbitui_commit"] = "e" * 40
        with self.assertRaises(w.WatchError): w.publish(api, "owner/orbitui", r)
        r["orbitui_commit"] = HEAD
        api.issues.append(copy.deepcopy(api.issues[0]))
        with self.assertRaises(w.WatchError): w.publish(api, "owner/orbitui", r)

    def test_real_git_detects_reverts_deletions_and_both_rename_sides(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*a):
                return subprocess.check_output(["git", "-c", "user.name=Test", "-c", "user.email=t@example.invalid", *a], cwd=tmp).decode().strip()
            git("init", "-q"); path = Path(tmp) / "search.lua"; path.write_text("one\n" * 30)
            git("add", "."); git("commit", "-qm", "baseline")
            git("mv", "search.lua", "renamed.lua"); git("commit", "-qm", "rename")
            paths, review = w.changed_paths(w.Git(Path(tmp)), git("rev-parse", "HEAD"))
            self.assertEqual(paths, ["renamed.lua", "search.lua"]); self.assertTrue(review)
            git("revert", "--no-edit", "HEAD")
            paths, review = w.changed_paths(w.Git(Path(tmp)), git("rev-parse", "HEAD"))
            self.assertIn("search.lua", paths); self.assertTrue(review)
            git("rm", "search.lua"); git("commit", "-qm", "delete")
            self.assertEqual(w.changed_paths(w.Git(Path(tmp)), git("rev-parse", "HEAD")), (["search.lua"], True))


if __name__ == "__main__": unittest.main()
