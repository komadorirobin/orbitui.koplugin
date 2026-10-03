# Upstream maintenance

## Policy

Automate observation, not integration decisions. The user explicitly chose
reviewed merges in the development conversation. No scheduled job may merge,
open a merge PR, advance integrated pins, bump versions or publish releases/OTA.
Monitoring is independent of the common OTA implementation in `OTA.md`.

Read `INTEGRATION_CONTRACTS.md` before each merge. Record decisions and testing
in `MERGE_LOG.md`, so correctness does not depend on access to one chat history
or on a particular model. A request to merge is not automatically a request
to publish to devices.

## History and source pins

`components/bookshelf` and `components/simpleui` were imported with `git subtree
add` without squashing. The imported fork commits and their parent histories are
available in this repository. `sources.json` pins the baselines; it is not a
claim that the component trees remain byte-identical after documented adaptations.

`sources.json` distinguishes provenance from the current upstream baseline:

- `repository`, `tag`, `commit`: the original imported fork and its revision.
  Keep these as provenance; the original fork commit must remain in history.
- `path`: the component's subtree directory.
- `upstream`, `upstream_branch`: the explicit source and branch being monitored.
  Bookshelf tracks `master`; SimpleUI tracks `main`. Do not silently change branches.
- `upstream_commit`: the latest upstream revision integrated by an approved
  merge, not the newest revision observed by the watcher. Update it as part of
  the reviewed merge and record the change in `MERGE_LOG.md`.

The missing-commit count is `git rev-list --count HEAD..<observed-upstream-sha>`.
Full, unsquashed history makes this work even though OrbitUI contains both
projects. Count each remote separately; a whole-repo "ahead" number is not a
useful measure of local component changes. Merge commits count as commits.
Cherry-picked equivalents with different SHAs still count as missing; inspect
them during review rather than assuming every counted commit needs its code
applied again. A count is ancestry information, not a guarantee of compatibility.

## Automatic watch

`.github/workflows/upstream-watch.yml` runs at 05:17, 11:17, 17:17 and 23:17 UTC,
on relevant pushes to `main`, or manually via Actions. GitHub may delay a
scheduled run; this is periodic monitoring, not a real-time delivery guarantee.
It runs on GitHub, without requiring the user's computer to remain on.

The workflow has read-only repository contents access plus issue-writing access.
There is no contents-write permission, merge step or release step. It checks
out full history and never checks out or executes fetched upstream code. Git
fetch only writes `refs/remotes/orbitui-watch/*` and objects. Commit subjects
are escaped for display, never treated as instructions or shell fragments.

The one issue marked `orbitui-upstream-watch:v1` is the durable dashboard. It is
assigned to the repository owner on creation. Every check refreshes its time;
changed upstream commits, releases, pins or error/recovery state produce a
comment. Unchanged checks do not add comments. GitHub notifications follow the
owner's issue subscription and account preferences; delivery by email is not
guaranteed. Closing the dashboard does not pause monitoring; the next run reopens
it. Disable the workflow in Actions to pause it.

The report includes exact revisions, all missing-commit counts, the first 25
commit subjects per component and the latest published non-prerelease release.
That release tag is informational: it is not compared to our fork's version
number, and it is never used to downgrade or automatically update anything.
Branch commits are monitored even when upstream has not published a release.
Other upstream branches and prerelease-tag-only changes are not monitored.

Git/API failures are shown as failures, never as zero updates. The other component
can still report successfully. A missing integrated ancestor, rewritten history
past that ancestor or multiple merge bases requires manual investigation. An
already-included newer upstream revision with an old manifest pin is flagged.
The dashboard refuses a report for a non-current `main` revision, including a
stale in-flight run after `main` advances. Rerun the workflow to collect afresh.

Each run keeps JSON/Markdown artifacts for 30 days and puts the report in its
Actions summary. If even report generation fails (invalid manifest, shallow
checkout, unavailable tooling), the job fails and the old dashboard timestamp
remains old; inspect the failed Actions run rather than treating it as a fresh
successful check.

Local read-only collection (Git and authenticated `gh`, Python 3.9+):

```sh
python3 scripts/upstream_watch.py collect
```

This creates ignored `test-results/upstream-watch/report.json` and `report.md`.
It does not update the GitHub issue. The separate `publish` subcommand is used by
the workflow; regular local work only needs `collect`.

Monitor tests are offline and include real Git ancestry, transient errors,
release failures, dashboard deduplication and notification retries:

```sh
python3 -m unittest discover -s tests -p 'test_upstream_watch.py' -v
```

Implementation references: [scheduled GitHub workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
[token permissions](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token),
and [issue API](https://docs.github.com/en/rest/issues/issues).

## Reviewed merge procedure

Future imports are explicit maintenance tasks, not a startup/build side effect.
Fetch the requested upstream revision, inspect it, and merge it into the correct
subtree on a dedicated work branch. Record the imported revision and relevant
conflict resolutions. Do not first merge it into both old forks and then repeat
the same merge here. The old forks remain stable fallback distributions during
the transition.

Keep import commits separate from OrbitUI adaptations. Preserve licenses and
asset notices. Re-run all integration tests, both original suites, translations
and package checks after each merge. A Git subtree preserves provenance; it does
not make semantic conflicts disappear.

1. Confirm the requested component and scope. Start from a clean tree on a
   dedicated maintenance branch. Do not mix in an unrelated redesign or rewrite.
2. Fetch the tracked branch and pin the target's full SHA for this review. Read
   the complete new commit list and the net diff; check release notes, removed
   files, dependencies, settings migrations and changed native KOReader hooks.
3. Map changed behavior to contracts C01-C09. Pay particular attention to
   navigation callbacks, plugin/patch compatibility checks, cache invalidation,
   background timers, i18n, reader profiles and synchronization ownership.
4. Merge that exact commit with `git subtree merge --prefix=components/bookshelf
   <reviewed-full-sha>` or the corresponding `components/simpleui` prefix. Do not
   use `--squash`, a root-level `git merge`, blanket "ours/theirs", or a moving
   branch name in place of the reviewed SHA. Stop and review conflicts.
5. Keep the import separate from adaptation commits where feasible. Inspect
   semantic conflicts even when Git reports a clean merge. If some upstream
   behavior is deliberately adapted/deferred, document what and why; a recorded
   integrated SHA says its history was reviewed, not that every behavior is enabled.
6. Update that component's `upstream_commit`. Preserve import provenance. If
   runtime module paths changed, regenerate `core/orbitui_module_map.lua` using
   `lua scripts/module-map.lua > core/orbitui_module_map.lua`. Check assets and
   every installer entry point.
7. Run `sh scripts/test.sh`, `LUA=luajit sh scripts/test.sh`, translation checks,
   then `sh scripts/package.sh` from a clean committed candidate. Do not increase
   known-failure exceptions simply to make the new import pass.
8. Perform the affected device checks from `TESTING.md`, or explicitly record
   that they remain outstanding. Inspect external integration versions when their
   interfaces changed. Do not claim Bigme verification from headless tests.
9. Append the exact commits, affected contracts, resolutions, test results and
   device gaps to `MERGE_LOG.md`. Report the outcome for review. Publication and
   any OTA channel change still require a separate explicit approval.

## Current embedding changes

- Bookshelf `main.lua`: legacy flat-file cleanup uses the component instance's
  actual path, never the retained standalone installation directory.
- SimpleUI `infra/sui_paths.lua`: embedded assets and translations resolve from
  `components/simpleui/`, not the outer OrbitUI directory.
- SimpleUI `main.lua`: initialization errors propagate to the owning OrbitUI
  host instead of being reported as a successful combined startup.
- Bookshelf `lib/bookshelf_settings_store.lua`: an opt-in path-adapter flag
  defers the new status-line key migration. `adapters/orbitui_bookshelf_storage.lua`
  retains flat file/database/cache paths and keeps the three status-line keys
  in `G_reader_settings`, readable by previous OrbitUI and external patches.
- SimpleUI `engines/sui_screen_engine.lua`: keep content identity separately from
  chrome wrappers, so stats/cover refreshes target mounted module content while
  our section-label/background wrappers remain intact. Book stats are not
  updated twice in the same refresh.
- Upstream compatibility auto-disable is replaced by OrbitUI's read-only guard.
  Conflicting UI plugins are reported; user plugin flags and patches are never
  rewritten. Unsupported KOReader versions stop before either component starts.

Other shared integration logic is coordinated through `core/` and `adapters/`. The generated
module map gives canonical require names and legacy `sui_*` aliases a single
component instance. Re-generate it with
`lua scripts/module-map.lua > core/orbitui_module_map.lua` after adding or removing
runtime source files. Preload hooks retain priority for userpatches.

## Next milestones

1. Validate the unchanged UX on the target device and address compatibility gaps.
2. Move navigation and reader-return ownership into one explicit coordinator,
   replacing the existing cross-plugin retry/ownership logic incrementally.
3. Device-test the common OTA installer, including interruption, preview channel
   selection, startup failure and rollback. See `OTA.md`.
4. Consolidate measured duplicate data/cache work behind stable service interfaces.

Do not combine these changes with an unrelated upstream update or visual redesign.
