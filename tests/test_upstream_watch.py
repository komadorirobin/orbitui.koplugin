import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("upstream_watch", ROOT / "scripts/upstream_watch.py")
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)
BASE, FORK, HEAD, TIP = (char * 40 for char in "abcd")
SOURCE = {"upstream": "https://github.com/example/bookshelf.git", "path": "components/bookshelf",
          "upstream_branch": "master", "upstream_commit": BASE, "commit": FORK}


class FakeGit:
    def __init__(self):
        self.calls = []
        self.fail = None
        self.not_ancestors = set()
        self.base = BASE

    def ancestor(self, older, newer):
        return (older, newer) not in self.not_ancestors

    def text(self, *args):
        self.calls.append(args)
        if args[0] == self.fail:
            raise watch.WatchError("simulated " + self.fail + " error")
        return {"fetch": "", "rev-parse": TIP, "merge-base": self.base,
                "rev-list": "3", "log": TIP + "\tAn upstream change",
                "diff": "main.lua\nlib/helper.lua"}[args[0]]


class FakeAPI:
    def __init__(self):
        self.issues = []
        self.comments = []
        self.writes = []
        self.release = {"id": 7, "tag_name": "v1.2.3", "published_at": "2026-10-01T12:00:00Z"}
        self.release_error = False
        self.fail_patch = False

    def pages(self, endpoint):
        return copy.deepcopy(self.comments if endpoint.endswith("/comments") else self.issues)

    def request(self, endpoint, method="GET", payload=None, missing_ok=False):
        if method == "GET":
            if endpoint.endswith("/git/ref/heads/main"):
                return {"object": {"sha": HEAD}}
            if endpoint.endswith("/releases/latest"):
                if self.release_error:
                    raise watch.WatchError("release lookup failed")
                return self.release
            return None
        self.writes.append((endpoint, method, payload))
        if method == "PATCH":
            if self.fail_patch:
                raise watch.WatchError("dashboard update failed")
            self.issues[0].update(payload)
        elif endpoint.endswith("/comments"):
            self.comments.append(payload)
        elif endpoint.endswith("/issues"):
            issue = {**payload, "number": 1, "state": "open", "html_url": "https://github.com/owner/orbitui/issues/1"}
            self.issues.append(issue)
            return issue
        return {}


def report():
    return {"schema": 1, "orbitui_commit": HEAD, "checked_at": "2026-10-02 19:00 UTC",
            "components": [watch.collect_component(FakeGit(), FakeAPI(), "bookshelf", SOURCE, HEAD)]}


class CollectTests(unittest.TestCase):
    def collect(self, git=None, api=None):
        return watch.collect_component(git or FakeGit(), api or FakeAPI(), "bookshelf", SOURCE, HEAD)

    def test_counts_upstream_commits_absent_from_combined_history(self):
        git = FakeGit()
        item = self.collect(git)
        self.assertEqual(item["behind"], 3)
        self.assertEqual(item["changed_files"], 2)
        self.assertFalse(item["manifest_stale"])
        self.assertIn(("rev-list", "--count", HEAD + ".." + TIP), git.calls)
        self.assertEqual(set(call[0] for call in git.calls),
                         {"fetch", "rev-parse", "merge-base", "rev-list", "log", "diff"})
        self.assertEqual(git.calls[0][-1], "+refs/heads/master:refs/remotes/orbitui-watch/bookshelf")

    def test_failed_fetch_is_unknown_not_up_to_date(self):
        git = FakeGit()
        git.fail = "fetch"
        item = self.collect(git)
        self.assertEqual(item["status"], "error")
        self.assertNotIn("behind", item)
        self.assertEqual(item["errors"][0]["phase"], "fetch")

    def test_recorded_history_must_belong_to_orbitui(self):
        git = FakeGit()
        git.not_ancestors.add((FORK, HEAD))
        item = self.collect(git)
        self.assertEqual(item["status"], "error")
        self.assertEqual(git.calls, [])

    def test_rewritten_integrated_history_is_not_a_normal_update(self):
        git = FakeGit()
        git.not_ancestors.add((BASE, TIP))
        item = self.collect(git)
        self.assertNotIn("behind", item)
        self.assertIn("no longer contains", item["errors"][0]["message"])

    def test_ambiguous_history_requires_review(self):
        git = FakeGit()
        git.base = BASE + "\n" + FORK
        self.assertEqual(self.collect(git)["status"], "error")

    def test_merge_without_manifest_update_is_reported(self):
        git = FakeGit()
        git.base = FORK
        self.assertTrue(self.collect(git)["manifest_stale"])

    def test_no_published_release_is_not_an_error(self):
        api = FakeAPI()
        api.release = None
        item = self.collect(api=api)
        self.assertIsNone(item["release"])
        self.assertEqual(item["status"], "ok")

    def test_release_failure_does_not_erase_valid_commit_count(self):
        api = FakeAPI()
        api.release_error = True
        item = self.collect(api=api)
        self.assertEqual(item["behind"], 3)
        self.assertEqual(item["status"], "error")
        self.assertNotIn("release", item)

    def test_github_url_is_not_an_arbitrary_fetch_target(self):
        for value in ("/tmp/repo", "http://github.com/owner/repo.git", "https://evil.test/owner/repo.git",
                      "https://github.com/owner/repo.git --upload-pack=bad"):
            with self.subTest(value=value), self.assertRaises(watch.WatchError):
                watch.repository_slug(value)

    def test_checked_in_sources_are_valid(self):
        sources = watch.load_sources(ROOT / "sources.json")
        self.assertEqual(sources["simpleui"]["upstream_branch"], "main")
        self.assertEqual(sources["bookshelf"]["upstream_branch"], "master")

    def test_malformed_manifest_is_rejected(self):
        data = json.loads((ROOT / "sources.json").read_text())
        for key, bad in (("upstream_branch", "main..other"), ("upstream_branch", "--all"),
                         ("commit", "abc"), ("path", "../outside")):
            with self.subTest(key=key, value=bad), tempfile.TemporaryDirectory() as tmp:
                altered = copy.deepcopy(data)
                altered["components"]["bookshelf"][key] = bad
                path = Path(tmp) / "sources.json"
                path.write_text(json.dumps(altered))
                with self.assertRaises(watch.WatchError):
                    watch.load_sources(path)

    def test_real_git_counts_do_not_include_unrelated_orbitui_commits(self):
        with tempfile.TemporaryDirectory() as tmp:
            git = watch.Git(tmp)
            git.text("init", "-q")
            git.text("config", "user.name", "OrbitUI test")
            git.text("config", "user.email", "test@example.invalid")
            tree = watch.run(["git", "mktree"], cwd=tmp, data="").stdout.strip()
            base = git.text("commit-tree", tree, "-m", "base")
            fork = git.text("commit-tree", tree, "-p", base, "-m", "local adaptations")
            orbit = git.text("commit-tree", tree, "-p", fork, "-m", "other component and host")
            next_upstream = git.text("commit-tree", tree, "-p", base, "-m", "upstream 1")
            tip = git.text("commit-tree", tree, "-p", next_upstream, "-m", "upstream 2")
            self.assertEqual(git.text("rev-list", "--count", orbit + ".." + tip), "2")
            merged = git.text("commit-tree", tree, "-p", orbit, "-p", tip, "-m", "reviewed subtree merge")
            self.assertEqual(git.text("rev-list", "--count", merged + ".." + tip), "0")


class ReportTests(unittest.TestCase):
    def test_punctuation_is_escaped_once_and_still_readable(self):
        self.assertEqual(watch.safe_text("fix(icons): A & B"), "fix&#40;icons&#41;: A &amp; B")

    def test_check_time_and_local_only_commit_do_not_trigger_notifications(self):
        old = report()
        new = copy.deepcopy(old)
        new.update(checked_at="later", orbitui_commit=TIP)
        self.assertEqual(watch.fingerprint(old), watch.fingerprint(new))

    def test_release_and_upstream_changes_are_news(self):
        old = report()
        for key, value in (("head", FORK), ("behind", 4), ("release", None), ("integrated", FORK)):
            with self.subTest(key=key):
                new = copy.deepcopy(old)
                new["components"][0][key] = value
                self.assertNotEqual(watch.fingerprint(old), watch.fingerprint(new))

    def test_repeated_network_error_messages_do_not_spam(self):
        old = report()
        old["components"][0].update(status="error", errors=[{"phase": "fetch", "message": "timeout 1"}])
        new = copy.deepcopy(old)
        new["components"][0]["errors"][0]["message"] = "timeout 2"
        self.assertEqual(watch.fingerprint(old), watch.fingerprint(new))

    def test_commit_subject_cannot_inject_markdown_mentions_or_html(self):
        data = report()
        data["components"][0]["commits"][0]["subject"] = "@owner [click](https://bad.test) <script> | `code`\n# fake"
        rendered = watch.render(data)
        for raw in ("@owner", "[click]", "<script>", "`code`", "\n# fake"):
            self.assertNotIn(raw, rendered)

    def test_failure_never_renders_as_zero(self):
        data = report()
        item = data["components"][0]
        item.pop("behind")
        item.update(status="error", errors=[{"phase": "fetch", "message": "offline"}])
        self.assertIn("| Unknown |", watch.render(data))
        self.assertIn("CHECK FAILED", watch.render(data))

    def test_commit_list_is_bounded_but_total_is_preserved(self):
        data = report()
        data["components"][0]["behind"] = 1024
        self.assertIn("1023 more commits", watch.render(data))


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeAPI()
        self.data = report()

    def publish(self, data=None):
        return watch.publish(self.api, "owner/orbitui", data or self.data, "owner")

    def test_first_run_creates_one_assigned_dashboard(self):
        self.publish()
        self.assertEqual(len(self.api.issues), 1)
        self.assertEqual(self.api.issues[0]["assignees"], ["owner"])
        self.assertEqual(self.api.comments, [])
        self.assertTrue(all("/issues" in call[0] or "/labels" in call[0] for call in self.api.writes))

    def test_old_or_feature_branch_report_cannot_overwrite_main_status(self):
        self.data["orbitui_commit"] = TIP
        with self.assertRaises(watch.WatchError):
            self.publish()
        self.assertEqual(self.api.writes, [])

    def test_unchanged_check_refreshes_dashboard_without_comment(self):
        self.publish()
        self.data["checked_at"] = "later"
        self.publish()
        self.assertEqual(len(self.api.issues), 1)
        self.assertEqual(self.api.comments, [])
        self.assertIn("later", self.api.issues[0]["body"])

    def test_changed_upstream_posts_once(self):
        self.publish()
        self.data["components"][0]["head"] = FORK
        self.publish()
        self.publish()
        self.assertEqual(len(self.api.comments), 1)

    def test_retry_after_dashboard_write_failure_does_not_duplicate_notice(self):
        self.publish()
        self.data["components"][0]["head"] = FORK
        self.api.fail_patch = True
        with self.assertRaises(watch.WatchError):
            self.publish()
        self.api.fail_patch = False
        self.publish()
        self.assertEqual(len(self.api.comments), 1)

    def test_repeated_error_recovery_cycle_still_notifies(self):
        self.publish()
        healthy = copy.deepcopy(self.data)
        broken = copy.deepcopy(self.data)
        broken["components"][0]["status"] = "error"
        for state in (broken, healthy, broken, healthy):
            self.publish(state)
        self.assertEqual(len(self.api.comments), 4)

    def test_closed_dashboard_is_reused_not_duplicated(self):
        self.publish()
        self.api.issues[0]["state"] = "closed"
        self.publish()
        self.assertEqual(len(self.api.issues), 1)
        self.assertEqual(self.api.issues[0]["state"], "open")

    def test_duplicate_dashboards_fail_closed(self):
        self.publish()
        self.api.issues.append(copy.deepcopy(self.api.issues[0]))
        with self.assertRaises(watch.WatchError):
            self.publish()

    def test_pr_is_not_mistaken_for_dashboard(self):
        self.api.issues = [{"body": watch.MARKER, "pull_request": {"url": "pr"}}]
        self.publish()
        self.assertEqual(len(self.api.issues), 2)

    def test_api_404_is_different_from_authentication_failure(self):
        api = watch.GitHub()
        missing = subprocess.CompletedProcess([], 1, stdout="", stderr="gh: Not Found (HTTP 404)")
        with patch.object(watch, "run", return_value=missing):
            self.assertIsNone(api.request("repos/owner/repo/releases/latest", missing_ok=True))
        denied = subprocess.CompletedProcess([], 1, stdout="", stderr="gh: Forbidden (HTTP 403)")
        with patch.object(watch, "run", return_value=denied), self.assertRaises(watch.WatchError):
            api.request("repos/owner/repo/releases/latest", missing_ok=True)


if __name__ == "__main__":
    unittest.main()
