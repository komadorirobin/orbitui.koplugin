# Reviewed import and merge log

This log is the durable handoff between development conversations. It records
approved imports, not merely upstream commits seen by the monitor. An entry
does not imply a public release or successful device testing.

## 2026-10-02: Initial OrbitUI import

- Bookshelf fork: `v5.2.2.3`, `2d46b259028ddbebc0159effe6171abb14520868`.
- SimpleUI fork: `2.7.2-beta.5`, `a8bbbdb89dcce9a4b9d86cfa321c8cecce9b030f`.
- Included Bookshelf upstream: `dc96d18848cfc8dfb543b9ae9aec77e65fd00b0a`.
- Included SimpleUI upstream: `ade0df9eca195c2cf8134005025f4b971e681ac0`.
- History imported without squash, in separate subtree commits. Embedding seams
  are described in `UPSTREAM.md`; neither predecessor repository was modified.
- OrbitUI foundation: `08175cb353e7018ebe51f1e999dbccadc4577037`.
- Verification: 39 OrbitUI integration tests; 310 Bookshelf suites passed with
  3 skipped; 13 SimpleUI test files passed, under Lua and LuaJIT. GitHub Actions
  run [37050332399](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/37050332399)
  passed. Seven inherited translation failures remain explicit hash-bound
  exceptions; see `TESTING.md`.
- Device: not yet tested on the Bigme. Manual alpha package only, no OTA release.

## 2026-10-02: Monitoring policy

The user chose automatic monitoring with reviewed merges in the development
conversation, not automatic merges or releases. Exact tracked branches and
already-integrated upstream pins were recorded in `sources.json`. This records
existing ancestry; it does not import any additional upstream code.

The monitor's current counts, commits and releases live in the status issue and
Actions artifacts, not in this log. Changing counts must not create fake merge
entries or repeatedly edit source files.

## 2026-10-03: Public preview and whole-package OTA

The user explicitly requested a release and OTA, and approved making the OrbitUI
repository public. This is a preview release, not device acceptance or an
upstream merge. Both component pins and the original standalone channels remain
unchanged. No automatic release workflow was added.

Contracts C01, C08 and C09 now include a stable bootstrap and versioned runtime
slots. Existing initialization moved to `core/orbitui_plugin.lua`. The common
updater verifies complete packages, selects code on restart and preserves a
previous version without rolling back settings or reading progress. The stable
bootstrap may not be changed by OTA API 1; incompatible changes require a manual
installation. `OTA.md` describes limits and recovery.

Verification includes Lua/LuaJIT suites, package inventory/checksum tests,
native libarchive/SHA smoke tests, interrupted-start recovery and real
LuaSocket/LuaSec HTTPS access. Device UI, restart and suspend/resume on the Bigme
are still unverified. Existing SQLite/slow-geometry skips and translation
exceptions remain; no new exceptions were introduced.

Before changing visibility, all 2,843 reachable commits were scanned with
Gitleaks. Two alerts were reviewed as non-secret upstream source (column-key
constants and the packed pinyin table); the worktree had the same pinyin-table
false positive. No detected credential was published. This scan is not an
absolute guarantee that all possible secret formats can be recognized.

## 2026-10-03: Reviewed Bookshelf and SimpleUI upstream merge

Scope: the user requested "Merga upstream" for OrbitUI. Both tracked branches
were reviewed and merged, without a release or any change to the old forks.

- Bookshelf `master`: `dc96d18848cfc8dfb543b9ae9aec77e65fd00b0a` ->
  `21e005a79900c210067128f674eef745c8a545ef`, 176 previously missing commits.
  Includes v5.3.0 and the fixes through that tip. Unsquashed subtree merge:
  `af71336f4b9d81cf28dac6fe7f39a254137afd59`.
- SimpleUI `main`: `ade0df9eca195c2cf8134005025f4b971e681ac0` ->
  `3444cc9c03756df1b4c7cb1847d56f517116f842`, 21 previously missing commits.
  This is the tracked development branch, not a downgrade to the watcher's
  latest stable label 2.7.1. Unsquashed subtree merge:
  `5d40154e838840ee854d92a60b5c284c831cba3e`.
- Main adaptation commit: `4cda52779ab0a7e8b2eb2dd64c1084394ae0cc45`;
  the following documentation/package-check commit records this review.
  `sources.json` advances only the integrated upstream pins; original fork
  provenance remains unchanged. Module map regenerated: 261 canonical paths.

Review covered contracts C01-C09. Notable incoming changes: Bookshelf themes,
planks, ornament packs, wallpaper management, gesture switches, drilldown filter
retention, reading-goal/stat corrections and scoped page-count scans with
suspend protection. SimpleUI adds per-element font controls, module opacity and
frames, live collection folders, resolved metadata-query caching, night icons,
quick-settings fixes and mounted-cover refresh fixes. No performance improvement
has been measured on the Bigme.

Conflict and integration decisions:

- C01/C06: OrbitUI remains the sole plugin owner. The new SimpleUI checker must
  not auto-disable plugins or rename user patches. OrbitUI reports incompatible
  active UI plugins through its read-only guard instead. KOReader older than
  v2025.08 is rejected before either component initializes, rather than loading
  half of the combined UI. Existing preload-hook priority is unchanged.
- C02/C03/C07: preserve the Home/prose/manga dock, its gesture priority, native
  reader/profile lifecycle, page-number long-press sorting, transparent
  title/footer option, BookOrbit Cover Deck source, dynamic section labels and
  custom-action icon mapping. Bookshelf's gesture switch for the page-number
  hold is named for sorting rather than claiming it cycles styles.
- C04/C07: keep Android-safe extraction/poll policy. After SimpleUI's chrome
  change, book/stat slots now retain both mounted wrapper and module-content
  references. Stats update the content, rebuilds retarget both stats and cover
  polling, and book modules are not updated twice in one refresh. Existing
  light-background/label wrappers remain independent of upstream chrome.
- C05: Hardcover remains link/enrichment-only on the KOReader side; BookOrbit
  is still the intended progress writer. Sync-prompt sequencing and external
  BookOrbit/MAL/Patch Manager integrations were not replaced.
- C08: explicitly defer Bookshelf 5.3's automatic settings/database/cache and
  ornament moves. The path adapter keeps existing flat filenames; three
  status-line keys stay authoritative in `G_reader_settings`. Reads and writes
  therefore remain visible to earlier OrbitUI and external header patches.
  New content folders still work, and ornaments in both old/new folders are
  read without moving the user's files. The two added book-facts highlight
  columns are additive; old queries remain compatible. Do not manually run the
  upstream migration while this adapter is active.
- C09: bootstrap API 1 files, root VERSION, release tags and OTA channel are
  unchanged. New plank/shadow assets are explicitly checked in runtime archives;
  upstream README-only logos/screenshots remain excluded.

Verification: 31 Python tests, 75 OrbitUI integration cases, 343 Bookshelf suites
and all 13 SimpleUI test files pass under Lua and LuaJIT. The three existing
SQLite/slow-geometry suite skips remain, as do the two per-case native font/UI
skips. No new failure waivers. All 41 translation catalogs pass after fixing
redundant plural forms and the Lithuanian rule; the old seven hash-bound
translation exceptions were removed. Updated test doubles follow upstream API
changes, and ornament filesystem tests now support both GNU and BSD stat/touch.

The clean candidate package passes inventory checks and native libarchive/SHA
OTA smoke tests: complete extraction, missing-file rejection, activation,
restart, rollback and truncated-download recovery. This is an unpublished test
package, not a replacement asset for the existing alpha. A fresh watcher check
at 06:34 UTC reports zero missing commits for both tracked branches.

Device acceptance remains outstanding: Home module chrome/fonts/labels, shelf
themes/ornaments, navigation/profile actions, existing settings/link retention,
external patch behavior and suspend/resume need testing on the Bigme B7 Pro.
The merge is **not published to OTA**; a separate release request is required.

## 2026-10-03: OrbitUI 0.1.0-alpha.3 release preparation

The user explicitly requested publication after approving the shared
"Uppdatera OrbitUI" menu labels. This preview includes the reviewed upstream
merge above, not any additional upstream commits. The label adapter and menu
hooks were committed separately in `942ace5e`; the original forks are unchanged.

Contracts C08/C09 retain the exact API 1 bootstrap and whole-package installer.
Root VERSION advances to `0.1.0-alpha.3`, and the About text reflects Bookshelf
5.3.0. Update entries still route to the same OrbitUI updater. Menu regression
tests cover both embedded labels/routing and the standalone label fallback.

Pre-release tests pass under Lua and LuaJIT: 31 Python tests, 80 OrbitUI cases,
343 Bookshelf suites and 13 SimpleUI test files. The existing three suite skips
and two per-case native font/UI skips remain. All 41 translation catalogs pass.
The bootstrap, HTTP transport and OTA installer are byte-for-byte unchanged
from the published alpha.2 tag; package and published-byte checks remain
mandatory release gates.

The user reports successful initial startup/navigation of alpha.2 on the Bigme,
with a subjective impression of faster dock navigation. No timing benchmark,
full device checklist or device OTA/rollback test has been completed. The new
merged version therefore remains an alpha prerelease. Publication requires the
checks and draft-asset verification in `OTA.md`; GitHub's release/tag and Actions
record the final published revision and automated results.

## 2026-10-03: Reviewed Bookshelf 5.3.1 merge

Scope: the user requested "Merga upstream" for OrbitUI after the folder-pager
divider fix. Both tracked branches were checked; only Bookshelf had new commits.
The previous unpublished fix in `3f375ecd` remains intact. The old standalone
forks and their update channels were not modified.

- Bookshelf `master`: `21e005a79900c210067128f674eef745c8a545ef` ->
  `9633b0319cc282ec7bcb85e7b5a400bff328d7da`, 11 previously missing commits.
  Includes v5.3.1 plus its two README follow-ups. Unsquashed subtree merge:
  `2ba033f36f0ba2245dc380bc1b6c23d72d2cda86`.
- OrbitUI adaptation: `7dea52b908b420df0feb599ad013af592ae29198`.
- SimpleUI `main`: unchanged at `3444cc9c03756df1b4c7cb1847d56f517116f842`,
  zero missing commits. Its tracked development version remains 2.7.2-beta.5;
  the watcher's informational stable label 2.7.1 is not a downgrade instruction.
- `sources.json` advances only Bookshelf's integrated upstream pin. Original
  fork provenance, module map (261 paths), root VERSION and OTA channels stay
  unchanged. A fresh read-only check at 15:28 UTC reports zero missing commits
  for both tracked branches.

The review covered the complete commit list and net diff: key/D-pad navigation
for the footer, book-detail tabs, cover grid, shelf editor, resizing and spine
shelves, plus whole-group navigation from book-detail pills. No runtime modules,
dependencies, migrations or assets were added or removed. No synchronization
writer, installer or background network behavior changed.

Conflict resolution and semantic adaptations:

- C02/C07: the one textual conflict was in `_test_swap_footer_region.lua`.
  Retain upstream's realistic outgoing row at `0,0` with `getSize`, and the
  fork's dock case. Production footer refresh geometry now uses the same
  dock-aware anchor as its placement, retaining upstream's focus-ring extension
  and widget offsets. The regression test reproduces the otherwise 120-pixel
  displacement with a 1264 x 1680 viewport and reserved dock.
- C07: the transparent-title/footer option still suppresses the divider in
  folder/list and full-screen module views without removing the hero, chip or
  list panels. All 12 painter regression cases pass after the import.
- C10: forward the new `whole` argument through the Home/shared book-panel
  controller, and retain it in current-shelf search references. Whole groups
  omit only the chip filter; normal groups and folders retain it, profile scope
  is preserved, and the saved shelf filter is not mutated. New integration tests
  failed before these adaptations and pass afterward.
- The new upstream drill-restoration test supplies the fork's profile-scope
  helper and verifies that scope is preserved. New footer tests supply the dock
  helper. These are test-double adaptations, not new failure exceptions.
- C01/C03-C06/C08/C09: shared ownership, reader-opening routes, caches, Hardcover
  link-only behavior, external plugins/patches, settings paths and bootstrap are
  unchanged. No upstream behavior was deliberately dropped.

Verification: Lua and LuaJIT full suites pass with 31 Python tests, 123 OrbitUI
integration cases, 350 Bookshelf suites and all 13 SimpleUI test files. The three
existing suite skips (two native SQLite suites and the opt-in exhaustive geometry
sweep) and two per-case native font/UI skips remain. No new waivers. All 41
translation catalogs pass, LuaJIT verifies 681 Lua files, and `git diff --check`
is clean.

The clean committed candidate ZIP passes inventory/integrity checks: 422 entries
and 392 runtime files. Native libarchive/SHA smoke tests pass full extraction,
missing-module rejection, activation, restart, rollback and truncated-download
recovery. This is a local development package, not a replacement for the already
published alpha.4 ZIP. Do not upload it under that existing release.

Device verification remains outstanding for key focus, footer refreshes above
the dock, transparent folder pagination and whole-group navigation/search from
Home and filtered shelves. `TESTING.md` records those checks. No Bigme performance
or stability improvement has been measured. **Not published to OTA**; publication
and a version bump require a separate request. Existing installation/recovery
instructions and data paths remain applicable.

## 2026-10-03: OrbitUI 0.1.0-alpha.5 release preparation

The user explicitly requested publication of the reviewed merge above. The
release also includes the unpublished transparent folder/full-screen pagination
fix in `3f375ecd`; it does not import additional upstream commits. Bookshelf is
5.3.1 through `9633b031`, and SimpleUI remains at `3444cc9c`.

Root VERSION advances to `0.1.0-alpha.5`. Bootstrap API 1, the bootstrap files,
HTTP transport and installer are byte-for-byte unchanged from alpha.4. Keep this
a prerelease in the existing preview OTA channel, with both ZIP and SHA-256
assets. Never overwrite the previously published alpha.4 package.

Both local Lua/LuaJIT runs pass: 31 Python tests, 123 OrbitUI integration cases,
350 Bookshelf suites and all 13 SimpleUI test files. The three existing suite
skips and two per-case native font/UI skips remain; no new waivers. All 41
translation catalogs pass. Anonymous HTTPS access also passes with the actual
LuaSocket/LuaSec transport in an isolated Linux test environment.

Clean-commit packaging, native archive/hash installation, draft-asset download
verification and anonymous published-release installation remain publication
gates per `OTA.md`. The GitHub release/tag and Actions record the final commit
and results. Device verification remains outstanding as listed in `TESTING.md`
and the alpha.5 release notes; headless OTA testing is not device acceptance.

## 2026-10-03: Per-icon Material weights (unreleased local change)

The user explicitly requested per-icon weight selection and a default of 300.
This intentionally updates C07/C08: unweighted Material selections use 300
instead of 500; icon identities and other icon sources are unchanged. Explicit
200/300/400/500 choices retain their weights through restarts and OTA-slot
rebasing. No settings migration or variable-font rendering is introduced.

The host adapter owns preview state and the weight popup. Bookshelf has only
two additional seams: an optional pre-construction picker hook and forwarding
the current start-menu icon. Preserve these along with all four static SVG
inventories when merging. `ICONS.md` documents identifiers and legacy aliases;
`TESTING.md` records the automated coverage and outstanding device checks.

This is not an upstream import. Baselines, VERSION and the published alpha.8
assets are unchanged. Publication requires a separate request; **not published**.

## 2026-10-03: OrbitUI 0.1.0-alpha.9 release preparation

The user explicitly requested publication of the per-icon weight feature above.
Root VERSION advances to `0.1.0-alpha.9`; all earlier published assets remain
immutable. No upstream commits are imported and neither integrated pin changes.

C07/C08 retain the approved default change to 300 and independent explicit
weights. All four static SVG inventories and the backward-compatible flat aliases
ship in the runtime ZIP. Bootstrap API 1, all three bootstrap files, the HTTP
transport and installer are unchanged from alpha.8. This is a prerelease in the
existing preview OTA channel, not a stable or device-accepted release.

Publication gates are the complete Lua/LuaJIT suites, 41 translation catalogs,
a clean-commit runtime ZIP, native archive/hash installation using the published
alpha.8 installer, downloaded draft-asset verification and anonymous published
release discovery/installation. `docs/releases/0.1.0-alpha.9.md` records the scope
and remaining device gaps; `TESTING.md` retains the Bigme checklist. No changes
to books, reading progress, synchronization ownership or stored preferences are
part of this release.

## 2026-10-04: Cover-facing shelves (unreleased local change)

The user requested that every book face cover-forward in the shelf/spines
display instead of mixing front covers and spines. This is an intentional C07
presentation change, not an upstream import; neither component pin advances.

The OrbitUI UI adapter fixes `_spineFaceOut()` to the native `all` policy for
existing/new Library and Manga shelves. Keep both render and pagination on
`_spinePlanBase` so they agree about the wider covers. The chip editor's optional
`face_out_override` displays All books read-only instead of offering ignored
choices. Preserve both adapter hooks and this small component seam on merges.
No custom renderer, new layout algorithm or settings migration is introduced.
Saved face-out choices remain intact for C08 rollback; grid/list/Auto modes,
book data, sync ownership, shelves and ornaments remain native.

Five focused regression tests cover the policy, shared plan options, no recent
scan, native editor behavior and saved-draft preservation. Full Lua and LuaJIT
suites pass, including 350 Bookshelf suites (0 failed, 3 known skips: two native
SQLite suites and the optional exhaustive geometry sweep). All 41 translation
catalogs pass. A private candidate ZIP passes runtime layout/inventory and ZIP
integrity checks; the published alpha.11 archive remains byte-identical.
Device checks are recorded in `SHARED_UI.md`; physical Bigme rendering has not
been verified. VERSION and the public OTA package are unchanged. Not published.

## 2026-10-04: OrbitUI 0.1.0-alpha.12 release preparation

The user explicitly requested publication of the all-cover shelf change above.
Root VERSION advances to `0.1.0-alpha.12`; earlier published releases remain
immutable. There is no upstream import or pin change. The intentional C07
orientation policy and C08 settings-preservation contract remain as documented.

Publication gates are both full Lua suites, translations, a clean-commit runtime
ZIP, native OTA installation/rollback using the published alpha.11 installer,
downloaded draft-asset verification and anonymous public discovery/installation.
The three bootstrap files, bootstrap API 1 and installer are unchanged. This
release stays in the preview channel; headless checks are not Bigme acceptance.
See `docs/releases/0.1.0-alpha.12.md` for scope and remaining device checks.

## 2026-10-04: Dock-aware bookcase height (unreleased local correction)

After installing alpha.12, the user confirmed the cover-facing style but reported
the lower shelf under the pagination controls and dock. `_collapsedSpineSplit`
still used the full widget height; the grid, list and expanded paths already
subtracted `_simpleUIReservedBottom()`. Its independent footer estimate also
ignored the live shared reservation. Correct both inputs instead of clipping
the books or changing saved density/hero preferences. `_rebuild` now uses the
visible footer reserve rather than only its outer box, so negative top margins
cannot give those pixels back to the rows through gap redistribution.

This repairs C07's viewport boundary without changing C02 navigation, C08
settings, orientation policy, sync ownership or upstream pins. Preserve the
small component geometry fix during future merges. Seven new tests in
`_test_tall_screen.lua` exercise native methods and the rebuild's footer sizing;
five reproduce the old failure in both Lua and LuaJIT. The fixture's two-row
Bigme layout overran by exactly its 160px dock height. The corrected 40-test
suite passes, including 432 viewport combinations. Full Lua and LuaJIT suites
also pass: 350 Bookshelf suites, 0 failures and the same 3 known skips (native
SQLite and opt-in exhaustive geometry). All 41 translation catalogs pass. A
private candidate ZIP passes inventory/layout and archive integrity checks.
Physical rendering still needs the follow-up documented in `SHARED_UI.md`.
Not published; VERSION and the public alpha.12 assets remain unchanged.

## 2026-10-04: Prepare 0.1.0-alpha.13 preview publication

The user explicitly requested publication of the dock-aware bookcase height
correction. Advance the root VERSION and add alpha.13 release notes without
changing upstream pins, the stable bootstrap, API 1 or the installer. Retain
saved row counts, normal hero size, all-cover orientation and reading data.

Release gates: both Lua runtimes, translations, clean-commit packaging and sealed
inventory checks; native OTA from the actual published alpha.12 ZIP, then draft
asset download/checksum verification and both CI jobs. After publishing, verify
anonymous public downloads and live discovery/installation with the alpha.12
installer, including restart, rollback and rejected incomplete packages.
This stays a preview: the reported overlap has headless regression coverage,
but the corrected rendering still needs the user's follow-up device check.
See `docs/releases/0.1.0-alpha.13.md` for scope and update instructions.

## Template for the next approved merge

Copy this section and replace placeholders only after performing the work.

- User request / scope:
- Component and tracked branch:
- Prior integrated upstream SHA:
- Reviewed target upstream SHA / release:
- OrbitUI merge commit and adaptation commits:
- Affected contracts (C01-C10):
- Conflicts and semantic decisions (including upstream changes deliberately deferred):
- Updated upstream pin and generated module-map changes:
- Tests passed, skipped, known baseline failures and new gaps:
- Device checks performed / still required:
- Release decision and user approval (or explicitly "not published"):
- Recovery considerations and next maintainer notes:
