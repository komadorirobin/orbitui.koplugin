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
3. Map changed behavior to contracts C01-C11. Pay particular attention to
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

- October 16: SimpleUI main `36e7430f` is reviewed (still 2.7.5);
  Bookshelf master is unchanged at `aeada050`. PR #508 remains deferred.
  The new Tabbed Grid is an optional Home/custom-screen module, not a
  replacement for Bookshelf's Library/Manga chips. Its tab sources retain
  hidden Recent books and screen-scoped current/finished choices. New Books
  ranks at most 15 candidates from the shared index, keyed by root/revision,
  without sorting or mutating that index. Cover Deck only requests history
  when using its Recent source; BookOrbit and other sources remain independent.
- The optional Reader Book quick-settings layout does not replace Classic by
  default (including first run). Keep detailed Currently Reading statistics
  and left-aligned descriptions. Copy legacy `currently_elem_order` to the
  new main/stat orders only if those are unset; retain the old key for rollback.
  Statistics now form one group at the first legacy statistic position, with
  their relative order retained. Explicit new orders always win.
- The new LRU/memory/menu-hook helpers retain bounded metadata/raster caches,
  retryable incomplete reads, expiring no-cover probes and reset-aware unload.
  Alpha-mask scratch buffers are reused per nesting level, released on reset,
  and keep valid ownership/depth after allocation, viewport or paint failures.
  Cancel reset-hook-scheduled collections too. Central menu hooks acquire an
  owner per host; last-owner teardown only restores methods still owned by us
  and leaves later patch wrappers as pass-throughs. Keep BookOrbit file-dialog
  cleanup. The module map adds 17 paths. Coverage: `test_upstream_20261016`,
  prior integration suites and all native SimpleUI tests. Fix the new duplicate
  plural forms in the single-form Chinese catalogues without extra exceptions.
- October 14: Bookshelf master `aeada050` and SimpleUI main `84a9c0e9`
  are reviewed imports (still versioned 5.4.4 / 2.7.5). PR #508 remains
  excluded: its series boxes are on `feat/series-boxes`, not tracked master.
  Keep OrbitUI's series-box adapter, completion badges and colour rendering.
- Bookshelf now discovers plugin-registered formats. Include the format
  fingerprint in the keyed walk snapshot, and bypass SimpleUI's core-only
  shared index whenever plugin formats are registered. Preserve cancellation,
  generation checks and directory validation. Scope extension helpers inside
  a private block to keep the repository chunk below LuaJIT's 200-local limit.
  Upstream's plugin-format cover guards avoid incidental network requests;
  OPDS-PSE resume/stream actions remain delegated to their external owner.
- SimpleUI's new finished-book ledger reconciles transactionally. Incomplete
  sidecar/filesystem reads cannot delete records or seal a day's counts, and
  missing/locked DB results cannot replace the saved activity snapshot. Keep
  partial-to-full cache promotion and full/streak invalidation semantics.
  Legacy deleted-book and manual-count settings are retained; a ledger marker
  prevents reimporting an old manual count after the user edits/removes it.
- Copy-only migrations v10/v11 retain fade/grouping settings and respect the
  embedding deferral guard. Explicit flat-library finished visibility stays
  authoritative. The new file filter uses ownership-safe teardown so external
  patch wrappers survive. Flow carousel remains opt-in (Classic default), with
  BookOrbit/custom-shelf index callbacks intact. Shared shadow/backdrop helpers
  retain collision-free cache keys, legacy aliases, zero default backdrop
  strength, custom icon fonts and per-instance label sizes/Bento gaps.
  Module unloading passes through the existing reset-aware eviction callback.
  Regression coverage: `test_upstream_20261014`, the older integration suites,
  native `_test_walk_snapshot` and `_test_performance_caches`.
- October 12 follow-up: Bookshelf 5.4.4 `2c8bfd8e` and SimpleUI `5bddc5bb`
  (Czech/Chinese translations only) are reviewed imports. Retain the corrected
  single Chinese plural form while importing the new strings. Auto with List on both levels
  supports independent `list_rows_l2`, `list_columns_l2` and expanded zoom in
  profile records too; profile gestures must resolve the target key before
  saving. Preserve first-level fallback, profile isolation and the legacy unset
  style. Physical favourite covers now retain their native heart/star at the
  top right. The new Finished/On hold orientation reasons do not override
  OrbitUI's all-face-out policy. No native series-box code is imported: PR #508
  was still open at review, and OrbitUI's existing adapter remains the owner.
  Tests: `test_upstream_20261012_followup`, `test_face_out_shelves` and native
  `_test_list_density_levels` / `_test_face_out_finished_heart`.
- October 12: Bookshelf 5.4.3 `ed135103` and SimpleUI `213a3c70`
  (still versioned 2.7.5) are reviewed imports. Bookshelf's new Auto levels are
  persisted in profile records as well as native tabs. Unset OrbitUI shelves
  keep their legacy policy; only explicit Auto uses the new level choices.
  The cross-shelf caption reserve reads OrbitUI's independent labels through
  the adapter, preserving Manga strips and dock geometry. The whole-bookcase
  fetch no longer shares Select all's 5000-item ceiling. Drill-ins seed their
  own ornament deal while keeping profile deck IDs and session shuffle rules.
- SimpleUI's in-place clock/stat refresh retains content-versus-wrapper
  ownership, module backgrounds and fresh topbar widgets per window when a
  rebuild is needed. The new shared raster cache stays byte- and count-bounded;
  keep legacy clear methods and the older `applyBadges` signature usable.
  Its shared sidecar/metadata refactor retains local short TTLs, 256 metadata
  rows, hidden Recent books, live status refresh, prefetched descriptions and
  progress-only rendering. `sui_raster_cache` is in the generated module map.
  The new hide-Uncategorized default affects native metadata browsing, not
  the separate Bookshelf profiles or actual book membership.

- Bookshelf 5.4.1 (`7c4c5da6`, October 11 review): nested shelves can choose
  their own theme; the theme menu targets the actual child, not its root.
  Preserve profile-qualified IDs and inherited themes until a child opts in.
  OrbitUI already owns per-chip captions (including physical books and Above),
  so `Editor.cover_text_external` suppresses the redundant native grid-only
  picker. Keep `cover_label_*` storage and independent nested-chip defaults;
  do not migrate to upstream's `cover_text*` fields or enable parent-caption
  inheritance in OrbitUI. `_booksLabelNone` delegates to `_bookLabelMode`, so
  the native grid budget still sees the adapter's scoped mode and preview.
  The native custom editor's new `_open` retains the optional scoped target
  and callback-based preview; token Save/Cancel must not become global writes.
  Adopt upstream's library-wide Show author below series switch: old Custom
  group mode reads as Author, with its old settings retained for code rollback.
  This does not change OrbitUI's physical series-box labels. Tests:
  `test_shelf_cover_labels`, `test_face_out_shelves`, `test_shelf_themes` and
  the native caption/theme suites.
- Bookshelf 5.4 (`a0bc7e37`, October 10 review): preserve the new layered,
  editable Theme library and native live-apply chip editor. The small theme-menu
  lookup/activation seams delegate fixed profiles to `orbitui_shelf_themes`;
  profile-qualified theme/deck IDs prevent shared Authors/Latest IDs from mixing
  Library and Manga. Themes use existing profile settings and deferred writes.
  Keep the independent transparency override outside the theme layer. Do not
  reintroduce Save/Cancel assumptions into cover-size tests.
- The 5.4 deck is per shelf. The session-shuffle adapter wraps `Deck.sync`;
  `_ornSig` synchronizes before recording page states, and all swap/shuffle/
  planning paths use `themeShelfId`. Include profiles in the deck-pruning
  inventory without adding navigation tabs. Ornament gesture blocking uses the
  actual pagination reserve above the embedded dock, not native screen bottom.
- `bookshelf_book_repository` scopes fallback-cover-hook locals in a private
  `CoverHooks` block to stay under LuaJIT's 200-local chunk limit. Preserve memo
  reset on rescans and the patch detection/probe behavior. The custom Next shelf
  uses native `HomeDir` resolution. The new face-out pose clips raster columns
  before raw framebuffer writes and releases its source buffer on errors; do
  not lose either safety fix when importing the painter.
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
- SimpleUI 2.7.5's pagination-cache fix must not reintroduce cached label widgets.
  OrbitUI builds fresh labels to prevent both freed text and stale callbacks.
  Keep upstream's screen identity in page navigation and the primitive label
  signature, and retain the close-lifecycle compatibility hook.
- SimpleUI `modules/module_stats_provider.lua`: the new `invalidateStreak()`
  must preserve only complete, still-valid book counts. Upstream's unconditional
  carry-over is incompatible with OrbitUI's partial/stale cache and pending full
  invalidation. Keep the completeness/day/validity guard and its tests.
- SimpleUI `screens/sui_settings_window.lua`: preserve upstream's membership-only
  enable/disable policy, but copy layouts across both load and save boundaries.
  Otherwise editor mutations also change the stored previous membership and
  removing/adding modules stops updating their flags. Keep clock element choices
  intact on reorder/unrelated saves and preserve custom-screen prefixes (C07/C08).
  Coverage: `tests/test_simpleui_upstream_20261006.lua`.
- SimpleUI's October 9 titlebar tabs are opt-in. Do not reinstate its automatic
  tabs migration or first-run CoverBrowser layout overwrite. Classic icons,
  custom font-icon guards, hidden-statusbar height, independent Bento top gaps
  and top alignment remain unchanged. Keep the legacy button-only backdrop
  setting alongside the new full-width titlebar backdrop, including backup and
  presets. The old wallpaper opacity API aliases the new lighten API.
- The shared navbar geometry must retain `Bottombar.SIDE_M()` for Bookshelf's
  embedded dock and `_navbar_topbar_h` for immediate margin reflow. New shared
  menu hooks are installed once across hosts, reference-counted on teardown,
  and restore temporarily narrowed widths even after exceptions.
- New `sui_section_label.PageState` mirrors legacy `_row_page_*`/`_row_npages_*`
  fields and initializes from them. Keep OrbitUI's fresh label widgets, custom
  screen prefixes and per-module label scales rather than mounting upstream's
  cached widgets. Retain grid badge API aliases and the saved legacy scale
  fallback, without applying it to the newly scalable Currently Reading and
  Coverdeck badges. A saved collection `stack` remains readable without rewrite.
- The October 9 metadata/cover caches must not persist transient SQL or decode
  failures as empty results. Retry without requiring a database timestamp
  change; confirmed misses may remain cached until the DB/WAL stamp changes.
  Preserve stats completeness guards with the faster reader-return pipeline.
  Coverage for these merge seams: `tests/test_simpleui_upstream_20261009.lua`,
  `tests/test_navbar_margin.lua` and native `_test_config_cover_cache.lua`.
- The second October 9 import (`f14507af`) adds generated cover placeholders,
  per-bar/cover-strip opacity, folder-stack styles and shared choice menus.
  Keep `bookorbit_want` in Cover Deck's new radio options/current label and do
  not reload native collections merely to populate a menu. Retain transparent
  titlebar/pagination/cover-strip defaults, opt-in 4px cover shadows, detailed
  Currently Reading stats and left-aligned descriptions. Explicit saved choices
  win; no settings rewrite is needed. The new cover-strip key participates in
  library backups and appearance presets.
- Keep the new shadow-mask cache bounded (64 dimension tuples, native buffers
  freed on reset), with collision-free dimension keys. Placeholder teardown
  restores only its own FakeCover upvalue on the exact function it patched;
  never overwrite a later plugin replacement or an unrelated wrapper upvalue.
  Tests: `tests/test_simpleui_upstream_20261009_followup.lua` (choice-menu
  laziness, BookOrbit/collection sources, defaults, hook ownership, bounded
  buffers and cropped placeholder ownership).
- Upstream compatibility auto-disable is replaced by OrbitUI's read-only guard.
  Conflicting UI plugins are reported; user plugin flags and patches are never
  rewritten. Unsupported KOReader versions stop before either component starts.
- Shared UI seams in `adapters/orbitui_ui.lua` redirect book panels, search and
  settings while retaining native actions and opening paths. The small optional
  component hooks and their tests are listed in `SHARED_UI.md`; review C10 when
  importing changes to those modules. Home shelf references live in the existing
  SimpleUI store, not in a second library index.
- Bookshelf `lib/bookshelf_widget.lua` and `lib/bookshelf_micro_fullscreen.lua`:
  the transparent-title/page-indicator option suppresses the footer divider in
  folder/list views and full-screen modules too. A zero-height footer panel is
  a layout boundary, not a visible separator. Preserve the upper/list panels,
  dock and the 5.4 native one-pixel bare-panel gap instead of a dark divider
  (C07). Regression coverage executes both
  painters in `_test_transparent_labels_footer.lua`.
- Bookshelf 5.3.1 `_swapFooterInPlace` computes its refresh region from the actual
  footer anchor, above the reserved OrbitUI dock, rather than the full screen
  bottom (C02/C07). Keep upstream's focus-ring extension and widget offsets;
  `_test_dpad_footer_refresh.lua` includes Bigme-sized dock geometry.
- The shared book-panel adapter forwards the `whole` group flag added in
  Bookshelf 5.3.1. Shared current-shelf queries capture it and omit the chip
  filter for whole groups, but retain folder filters and profile scope (C10).
  Do not mutate the source chip's saved filter. Tests cover forwarding, ordinary
  versus whole groups, and profile-scoped restoration/search.
- Author ornaments wrap `lib/bookshelf_ornament_deck.fillHooks` and the first
  `lib/bookshelf_ornaments.listAll` through `adapters/orbitui_ornaments.lua` (C11).
  Review the planner hooks, balancing
  constraints, enabled-card filtering and entry author metadata on future merges.
  Keep whole-library pagination consistent with separate page rendering; author
  pieces must never fall back to the ordinary random deck. Preserve one-time
  installation and the separate artwork licenses. See `ORNAMENTS.md`.
- The approved ordinary-ornament row limit uses minimal opt-in Bookshelf hooks:
  `bookshelf_ornament_deck.fillHooks` accepts `env.max_per_row` and exposes
  `row_count` for the adapter's author reservation before row-end dealing.
  A row-end slot removed by squeeze remains spent: releasing it after lead
  measurement would permit an unbudgeted replacement at placement time.
  The adapter returns a fifth value from `final()`; `bookshelf_spine_shelf`
  forwards it to `bookshelf_spine_layout.balanceRows` as `opts.row_accept`.
  The predicate allows several matching busts together, but prevents combining
  ordinary ornaments or mixing them with busts. Keep default native density
  and balancing unchanged
  when these options are absent. Tests: `tests/test_author_ornaments.lua` (C11).

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
