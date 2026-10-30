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

## 2026-10-04: Author-matched ornaments and alpha.14 publication preparation

The user requested bundling the prepared Joyce and Woolf busts, placing them
beside the correct authors' books, and publishing the next release. This is an
OrbitUI-only addition under C11, not an upstream import. Component source and
both upstream pins remain unchanged. Root VERSION advances to alpha.14; the
stable bootstrap, API 1 and existing update channels are unchanged.

The runtime adapter seeds the Modernists pack once without replacing existing
files, settings or deleted artwork. It filters author busts out of the ordinary
deck, then wraps native fill hooks to reserve a bust beside each matching run.
Native balancing keeps the pair together. Author metadata is matched exactly
after normalization, including inverted names; folder covers and titles do not
imply authorship. Off/disabled settings are respected. Keep page-boundary resets
and the author-lead empty-row rule together: ordinary row-end ornaments yield
to a book/bust pair so full pagination matches isolated page rendering.

The two images retain their distinct derivative-art licenses and notices:
Joyce CC BY-SA 4.0; Woolf CC BY-NC-SA 4.0 (non-commercial only). They are not
relicensed under the software's AGPL. The earlier manual preview pack is also
matched, with released pieces taking priority to avoid duplicates. Code rollback
does not remove the installed pack; pre-alpha.14 versions need it disabled if
random placement is unwanted.

Both full Lua runtimes pass, including 23 new Lua cases, 41 Python tests (two
new asset checks), and 350 Bookshelf suites with 0 failures and the same three
known native-SQLite/opt-in geometry skips. Author placement includes 27 complete
pagination/page-render combinations. All 41 translation catalogs pass. Release
gates also require a clean-commit sealed package, native OTA from the actual
published alpha.13 ZIP, verified draft downloads, both CI jobs, then anonymous
public discovery/download/installation. Keep this a preview: physical Bigme
rendering and touch checks are outstanding. See `ORNAMENTS.md` and the alpha.14
release notes for controls, recovery and device follow-up.

## 2026-10-04: Eight additional author busts (unreleased)

The user approved the proposed Strindberg, Lem, Dylan Thomas, Thomas Mann,
Dostoevsky, Hamsun, Lispector and Musil ornaments. Add them as a separate Authors
pack under C11, extending exact full-name matching and keeping the existing
placement planner. Independent install markers permit an alpha.14 upgrade
without overwriting edits, restoring deleted artwork or changing enablement.
Preserve that additive migration during future upstream merges.

All eight transparent PNGs retain their generated bytes and provenance. Notices
and exact prompts distinguish reference adaptations from four original portrait
interpretations; the latter do not reproduce restricted commercial/museum busts.
Keep the per-image licenses separate from software licensing, including the
non-commercial restriction on Dostoevsky. The Modernists pack is unchanged.

Both full Lua and LuaJIT suites pass: 22 author-placement tests, 14 seed tests,
43 Python tests and 350 Bookshelf suites with 0 failures and the same three
known SQLite/opt-in geometry skips. The 27 pagination configurations now cover
all ten authors. All eight images render in the desktop artwork preview on
light/dark/patterned backgrounds; its mobile layout has no horizontal overflow.
Physical Bigme shelf scale, touch behavior and author metadata still need the
user's follow-up. A clean-commit sealed runtime ZIP is the final packaging gate.

No component source, upstream pin, VERSION, bootstrap or public OTA change.
Not published. Rollback keeps copied artwork; disable Authors on alpha.14 or
older versions if unrelated-author placement is unwanted. See ORNAMENTS.md.

## 2026-10-04: Include Kafka in the unpublished Authors pack

The user identified Kafka's omission and requested his inclusion. Add an
original AI-assisted light-plaster portrait with retained RGBA/provenance bytes,
exact prompt and attribution. Register `Authors/Franz Kafka.png` for both seeding
and C11 placement; exact `Franz Kafka` and `Kafka, Franz` metadata matches use the
existing planner. Surname-only, family-name and title mentions do not match.
The Authors pack now has nine pieces; with Modernists there are eleven authors.

Authors has not been publicly released, so this completes its existing v1
manifest rather than migrating a deployed pack. No existing artwork, user
settings, upstream pins, component source or VERSION changes. Both full Lua and
LuaJIT suites pass, including 23 author tests, 14 seed tests, 43 Python tests and
350 Bookshelf suites with no failures and the same three known skips. All
eleven authors participate in the 27 pagination combinations. The visual
preview loads all nine Authors images on light/dark backgrounds, with no
mobile horizontal overflow. Validate the clean-commit sealed runtime ZIP as
the final packaging gate before considering this candidate ready for device testing.
Bigme rendering/touch confirmation remains outstanding. Not published.

## 2026-10-04: Alphabetical series blocks on bookcases (unreleased)

The user approved keeping series together while interleaving them with single
books by series name (first volume title as fallback). This deliberately changes
C07's bookcase ordering, not saved sort preferences or grid/list ordering.

Two paths needed correction: folder sections kept filesystem order and only
sorted their own members, while mixed Series-source shapes lacked a title and
therefore sorted after standalone books under the Title key. Install small
optional repository hooks before either window is sliced. The pure policy and
canonical-module adapters live in `core/orbitui_shelf_sort.lua` and
`adapters/orbitui_shelf_sort.lua`; preserve these seams in future imports.

Title/author/series-primary sorts compare entire blocks using native sort keys.
Reverse affects the block alphabet, not ascending volume order. Keep folder
labels, paths and author metadata for navigation and C11 ornaments. Letter
scans use the same scoped folder producer and transient block keys on output
copies; temporary spine flags are restored even after a scan error. Cached
source records/shapes, persisted priorities and reader progress are unchanged.
No new walk, cover hydration or network request is added. Nonalphabetical and
grid/list behavior remains native.

Verification: both full Lua and LuaJIT runs pass, including 214 OrbitUI cases
(13 new sort tests), 43 Python tests, 350 Bookshelf suites and all 13 SimpleUI
test files. Bookshelf has 0 failures and the same three known suite skips
(SQLite and opt-in exhaustive geometry). Tests execute the actual folder
producer and series readout as well as the adapters: Moberg order, different
first-title/series-title, reverse, missing/decimal indices, title fallbacks,
scoped/filtered pagination, warm reads and error-safe letter scans.

No upstream import/pin, VERSION, bootstrap or public OTA change. This remains
unpublished with the author-bust additions. Validate the clean-commit runtime
ZIP before device testing; Bigme layout, book selection, letter jumps and bust
placement still require the checklist in SHARED_UI.md.

## 2026-10-04: Colour Japan ornaments replace stock plants (unreleased)

The user requested bonsai, cats and Japanese shelf decorations instead of the
stock cacti, and confirmed a colour screen. Add five original AI-generated
transparent PNGs in a separate Japan pack: pine bonsai, red maple bonsai,
sleeping calico, maneki-neko and daruma. Retain the exact generated RGBA and
provenance bytes, with prompts, hashes, separate CC BY 4.0 notices (to the extent
applicable) and native placement metadata. These are normal deck ornaments,
not author-bound pieces. C11's eleven author busts and matching stay unchanged.

Extract the existing atomic additive copy code to `core/orbitui_ornament_install.lua`;
Modernists, Authors and Japan keep independent markers. The adapter attempts
Japan separately, so either pack family can fail without breaking the browser
or the other installation. The user-approved C08 exception is a one-time,
reversible switch-off of only byte-identical native cactus.svg/template.svg in
their effective root. Do not delete artwork, overwrite custom same-name files,
change ornament frequency or enable a disabled Japan pack. A new-root custom or
unreadable file must not fall through to a legacy stock file. Persist the defaults
marker only after the settings write succeeds, and never repeat the switch-off
after a user re-enables a plant. Existing off entries and deleted artwork survive.

Both full Lua and LuaJIT runs pass: 227 OrbitUI cases (13 Japan regressions),
46 Python tests, 350 Bookshelf suites with 0 failures and the same three known
SQLite/opt-in geometry skips, and all 13 SimpleUI test files. All 41 translation
catalogs pass. Asset tests cover PNG colour/alpha format, generated-byte hashes,
provenance, notices and the matching preview references/defaults. The packaged
inventory check now requires every file in all three ornament packs.

The individual images and real alpha were inspected. The new desktop preview
could not be browser-rendered because browser control was unavailable; do not
claim a browser or physical-device visual pass. Bigme colour rendering, small
and width-constrained placement, light/dark backgrounds, touch controls and
re-enabling the old plants still need device confirmation. See ORNAMENTS.md and
`docs/japan-ornaments-preview.html`. Validate the clean-commit sealed ZIP as the
final packaging gate. No component source, upstream pins, VERSION, bootstrap or
public OTA changes. Not published; rollback retains user-side art and off settings.

## 2026-10-04: Shuffle ordinary ornaments once per KOReader session

The user approved a fresh random ordinary-ornament order at startup, stable
throughout browsing and normal suspend/resume. This deliberately changes C11's
cross-restart fixed deck order; author binding and frequency remain unchanged.
Use the existing native deck shuffle in the canonical ornament adapter, once
after seeding and the first nonempty catalogue, before list/page signatures
are captured. Empty catalogues defer the attempt; failures log once. Keep the
guard module-local, not per widget or profile. Native manual swaps and shuffles
remain stable until another explicit shuffle or the next process startup.

No component source, bootstrap, upstream pin, asset bytes or enablement changes.
Thirteen new tests exercise native deck/cache/layout code, session lifetime,
insertion, off settings, failure handling, page signatures and author adjacency.
Both complete Lua and LuaJIT logs pass: 240 OrbitUI cases, 46 Python checks,
350 Bookshelf suites (0 failures, the same three SQLite/opt-in geometry skips)
and all 13 SimpleUI test files. All 41 translation catalogs pass. Physical
Bigme checks remain outstanding; see ORNAMENTS.md. The subsequent user request
authorizes publishing this feature together with the accumulated local work.

## 2026-10-04: Prepare alpha.17 after publication interruption

The user explicitly requested publication, then asked to resume after the usage
interruption. Fetching origin found alpha.15 and alpha.16 published meanwhile:
alpha.15 tags the alpha.14 source; alpha.16 changes only VERSION and release
notes. Its downloaded, checksum-verified runtime has the old author-only adapter
and does not contain the additional ornaments or series-sort work named in its
notes. Merge origin's two non-conflicting commits without rewriting history,
published tags or assets, and use a new version, 0.1.0-alpha.17.

This release includes the four accumulated feature commits (additional busts,
Kafka, series blocks, Japan) plus the session shuffle above. Upstream pins,
stable bootstrap files, API 1 and existing component update routing stay intact.
Preserve the independent install markers, attribution/non-commercial notices,
one-time reversible stock-plant setting and session-only deck stability.

Release gates: rerun both full runtimes and translations on the reconciled
release tree, seal the clean-commit runtime package, test native OTA using the
published alpha.16 ZIP, verify downloaded draft assets and both CI jobs, then
publish and test anonymous discovery/download/activation with the old installer.
This remains a prerelease, not a claim of new physical-device acceptance. See
`docs/releases/0.1.0-alpha.17.md` for exact scope and rollback considerations.

## 2026-10-04: Reviewed Bookshelf and SimpleUI upstream merge after alpha.17

The user requested another upstream merge. Start from published alpha.17
(`5bdb66ca107f307c2334e19718215c1dedfd6cf6`) on the dedicated
`maintenance/upstream-2026-10-04` branch. Review all three missing Bookshelf
commits and all five missing SimpleUI commits, including their net diffs and
the current release notes; no branch or source repository changes.

- Bookshelf `master`: `9633b0319cc282ec7bcb85e7b5a400bff328d7da` to
  `74b825bb20aa5560129384910ad414bd2bebad75`; unsquashed subtree merge
  `8d5bcb0f`. Latest tagged release remains 5.3.1. New changes are test-only:
  portable GNU/BSD stat/touch helpers and a memoised row-budget source match.
  The exhaustive geometry sweep now runs by default, not only when opted in.
- SimpleUI `main`: `3444cc9c03756df1b4c7cb1847d56f517116f842` to
  `19874b3b8f02af34d849caee2ee13e7f6b8ecd94`; unsquashed subtree merge
  `ae110441`. Embedded metadata advances to 2.7.5. New runtime behavior covers
  safe Android zlib symbol probing/fallback, pagination callback lifetime and
  immediate streak refresh after spending a freeze.

Bookshelf's six textual conflicts are overlapping local macOS test fixes.
Replace the duplicate inline helpers with upstream's shared statCmd/touchAtCmd;
retain all tests and production code. SimpleUI conflicts are its version and
section-label implementation. Use the 2.7.5 component version, but preserve
OrbitUI's fresh label widgets, per-module styling and background wrappers.
Reintroducing upstream's widget cache would regress freed label text and
callback ownership. Keep the new page-nav screen_id, propagate it into the
primitive label signature, and retain the no-op close-lifecycle hook.

Semantic adaptation (C04/C07): upstream invalidateStreak unconditionally marked
book counts valid. A new regression reproduces false complete/zero counts when
OrbitUI has only partial stats. Require complete, still-valid counts before
carrying them over, without overriding full invalidation or directly reusing
previous-day snapshots. Valid counts still avoid another sidecar scan. Preserve
the upstream live-stats refresh and safe no-op when the provider is not loaded.
The Android loader probes all three inflate symbols inside pcall, tries native
32/64-bit system paths and caches unavailability rather than crashing/retrying
on every book.

Affected contracts: C02/C03 screen lifetime, C04 cache validity, C06 Android and
canonical module compatibility, C07 labels, C09 source provenance. C01/C05/C08/
C10/C11 remain unchanged: single updater/plugin ownership, BookOrbit-only
progress writes, fonts/icons/settings, cover-facing shelves and dock clearance,
series blocks, author matching, Japan seeding and session-stable shuffling.
Upstream's previously reviewed auto-disable behavior remains blocked by the
read-only OrbitUI guard. No new assets, dependencies or runtime module names;
the 261-path module map remains unchanged. Advance only the two upstream_commit
pins; retain the original fork provenance and stable bootstrap/API 1.

Verification: complete Lua/LuaJIT suites after the Bookshelf merge, then both
again after SimpleUI and the adaptation. The final suites contain 253 OrbitUI
cases (13 new focused merge regressions), 46 Python checks, 351 Bookshelf suites
and all 13 SimpleUI test files (four additional cache tests). The two remaining
Bookshelf skips require KOReader's native SQLite runtime; the exhaustive
geometry sweep is no longer skipped. All 41 translation catalogs pass.
Adaptation commit `59b2b920` passes clean-commit sealed packaging: 1249 runtime
files, 1296 archive entries, all 261 module paths and asset/license/recovery
checks. Read-only upstream collection reports zero missing commits for both
components at 18:09 UTC. The candidate ZIP is local only, not a replacement for
the published alpha.17 asset.

No physical-device test performed: verify Android CBZ metadata browsing,
Home/custom-screen pagination after reader return/reopen, freeze display and
unchanged book counts on the Bigme. Automated label tests use widget stubs;
zlib tests simulate missing FFI symbols, not the device's binary libraries.
VERSION remains alpha.17 and published release bytes are untouched. This is
a reviewed merge, **not published to OTA**; publication needs a separate request.

## 2026-10-04: One ordinary ornament per row, with an author-bust exception

The user requested at most one ornament per physical shelf row, then explicitly
exempted author busts while the change was in progress. Final policy: at most
one ordinary decoration, or several correctly matched author busts without an
additional ordinary decoration on that row. This intentionally updates C11;
None, disabled pieces/packs, author aliases, session shuffle, asset seeding and
saved settings remain unchanged. This is not an upstream import or release.

Reserve busts before ordinary row-end dealing, so they have priority without
leaving a hidden row-end width reservation. Several author runs can share a
row. Keep each bust/book pair together if it needs the next row. Use two small,
opt-in Bookshelf seams: the deck's max_per_row/row_count reservation and a fifth
final() result forwarded to balanceRows as row_accept. The predicate uses
prefix counts, allows several busts and rejects extra/mixed ordinary pieces.
Standalone default density and balancing remain unchanged without these hooks.

The regression matrix also exposed a squeeze edge case: releasing a removed
row-end slot after lead measurement allowed an unbudgeted lead decoration when
the book was placed. Keep that slot spent for this row. Update the native
wiring assertion to cover the optional fifth result rather than weakening it.

Ten added OrbitUI cases cover two/three author busts, ordinary gap/end competition,
bare/oversized rows, squeeze safety, optional native defaults, balancing,
book/bust carry-over and real planner wiring. The existing 27 pagination
configurations now compare page-start deck states, row ornaments and balanced
output as well as page boundaries and author adjacency. Both Lua and LuaJIT pass:
263 OrbitUI cases, 46 Python checks, 351 Bookshelf suites (zero failures, the
same two native-SQLite skips), all 13 SimpleUI test files. All 41 translation
catalogs pass. Clean-commit package validation is the final installation gate.

Physical Bigme rendering/touch is not tested. Device checks are recorded in
ORNAMENTS.md; especially inspect rows with several authors and the partly empty
last page, in both orientations. No VERSION, source pin, bootstrap, artwork,
settings schema or public OTA changes. Publication requires a separate request.

## 2026-10-04: Prepare alpha.18 for explicit publication

The user requested publication after the Bento margin correction (`501f57a9`).
Bundle that correction with `447ee60b`'s ordinary-ornament row cap and the
previously reviewed post-alpha.17 upstream merge. No additional fetch-and-merge,
source-pin advancement, stable-bootstrap/API change or settings migration.

Bento Top Margin now sits above each module's complete cell, including the
first module in every column. Top-align columns instead of sharing the first
column's margin and vertically centring their different heights. Gaps join the
cached layout fingerprint so warm pages respect updated values. Full-width
spacing, topbar-off padding, horizontal width allocation and live clock/book
slot ownership remain unchanged. Contract C07 and the device checklist document
the deliberate alignment change; twelve geometry regressions cover it.

Release as 0.1.0-alpha.18, not replacement bytes for alpha.17. Required gates:
both full runtimes, translations, clean-commit sealed package, native OTA using
the published alpha.17 installer, downloaded draft-asset verification, both CI
jobs and anonymous public OTA. Physical Bigme layout/touch testing remains open.
See `docs/releases/0.1.0-alpha.18.md` for scope and recovery.

## 2026-10-05: Gallery wall placement and source-linked information (unreleased)

The user reported that the new frames stand on the plank and requested the
appearance of wall-mounted pictures, while asking for richer information and
its provenance. No upstream merge or new publication was requested.

C11's narrow metadata-upgrade exception corrects untouched alpha.19 lift/info
defaults, using a frozen snapshot from `17b3970c`. Explicit reader positioning,
custom pack fields, deleted records/files, image bytes, themes, and other packs
remain intact. Updates are atomic per file and retry after interruption; the
new marker is separate from the original additive install marker. The stand
height determines the 12% wall gap, without resizing artwork or altering native
layout, pagination, taps or ornament frequency.

All 27 info cards now include measurements and longer Swedish AI-assisted
summaries tied to primary museum sources, labelled as OrbitUI commentary rather
than museum-authored text. Original artwork and texture bytes are unchanged.
Tests cover 10 new migration/native-geometry cases and an alpha.19 metadata/
image-baseline check. Full Lua/LuaJIT suites, original-museum pixel audits and
all 41 translation checks passed; see TESTING.md for coverage and skips.
Physical Bigme wall spacing and scroll/zoom still need
testing. Keep the current published alpha.19 assets intact; publish corrections
only as a new release on a separate explicit request.

## 2026-10-06: Reviewed SimpleUI upstream merge after the gallery correction

The user requested an upstream merge. Read-only collection found Bookshelf
`master` already integrated at `74b825bb20aa5560129384910ad414bd2bebad75`
(latest release 5.3.1) and five missing SimpleUI `main` commits. Start from
`acff89ac` on `maintenance/upstream-2026-10-06`, retaining the unpublished
gallery wall/info correction. No Bookshelf subtree or original-fork changes.

SimpleUI advances from `19874b3b8f02af34d849caee2ee13e7f6b8ecd94` to
`b58dfefb26012e44b5b9c96d61d646466ca53b46`, imported unsquashed in
`42a1c351`. Reviewed the complete five-commit list and net 12-file diff:
`a26d8066` preserves clock visibility on layout saves; `3282e42f` adds a Unicode
lowercase fallback; `6817c91a` unifies start-view access; `b30e9190` reorganizes
the bundled quote catalogue and revises attributions; `b58dfefb` removes duplicate
horizontal module padding and improves quote line breaks. The latest tagged
SimpleUI release remains 2.7.5; no module paths, dependencies or assets are added.

The sole textual conflict is the menu reset's start-view write: use upstream's
`Config.setStartWithHomescreen(false)`, which preserves a different active native
choice. The actual setting key/value and first-run behavior are unchanged.
Accept the live accessor instead of stale cached startup state. Preserve the
OrbitUI guard, which still prevents upstream's previously reviewed automatic
plugin/patch disabling from changing the user's integrations.

Semantic adaptation: a failing regression demonstrated that native layout
load/save shares tables with LuaSettings. Upstream's membership comparison then
sees the already-edited table and misses removals/additions, including after a
first successful save. Copy serializable layout data at both boundaries instead
of restoring unconditional enablement, so hidden clock elements survive reorder
and unrelated saves while actual membership changes still apply. This is a
small component adaptation in a separate commit, not a settings migration.

Affected contracts: C02 live startup choice, C06 older-reader Unicode helpers,
C07 module margins/visibility and quote wrapping, C08 layout snapshot isolation,
C09 tracked history. C01/C03/C04/C05/C10/C11 and their adapters remain intact:
one plugin/updater, normal reader routes, BookOrbit progress ownership, Bento top
margins, shared panels/Home shelves, all-cover bookcases, series ordering,
author-bound busts, ordinary ornament limits/shuffling and gallery v2 migration.
Advance only SimpleUI's upstream_commit; preserve import provenance, all 261
module paths, stable bootstrap/API 1, VERSION and published release bytes.

Both full Lua and LuaJIT runs pass: 307 OrbitUI cases (13 new), 57 Python checks
including museum-source pixel audits, 351 Bookshelf suites (zero failures, the
same two native SQLite skips), and all 13 SimpleUI test files. All 41 translation
catalogs pass. Read-only collection at 04:05 UTC reports zero missing commits
for both components. Adaptation commit `710a38db` passes clean-commit sealed
packaging: 1290 runtime files, 1340 archive entries, all 261 module paths and
asset/license/recovery checks. The candidate is an unpublished development ZIP
with VERSION still alpha.19, not replacement bytes for the published release.
Physical Bigme checks are not performed: layout editing/clock visibility,
custom screens, native startup selection and quote/clock/action-list margins
still need the checklist in TESTING.md. This is not an OTA publication; the
merge and the gallery correction remain local pending a separate request.

## 2026-10-06: Prepare alpha.20 for explicit publication

The user explicitly requested publication after the reviewed merge. Release
`0.1.0-alpha.20` from `2ca9ac8d` plus version/release documentation, including
`acff89ac`'s gallery wall/info correction and the reviewed SimpleUI import
(`42a1c351`) with isolated layout snapshots (`710a38db`). No additional upstream
merge or pin advance. Preserve the stable bootstrap/API 1 and all published
alpha.19 bytes; the new optional gallery ZIP includes the corrected defaults.

Required gates: full Lua/LuaJIT suites and translations on the versioned tree,
clean-commit runtime inventory/checksum, native OTA from the published alpha.19
installer, both CI jobs, downloaded draft-asset verification, and anonymous
discovery/download/install/rollback after publication. Keep this a prerelease:
Bigme wall spacing, native text/layout rendering, touch and device recovery
checks remain outstanding. See `docs/releases/0.1.0-alpha.20.md` for scope and
user-preserving metadata migration/rollback notes.

## 2026-10-06: More wall clearance for gallery frames (unreleased)

The user reports that alpha.20's frames still touch the shelf and requests a
slightly higher position. Its 12% lift was measured from the book-foot line,
not the receding plank surface. Raise the pack defaults to 20%, leaving their
95% scale, image bytes, museum texts, tap-to-zoom and all other packs unchanged.
This is a C11 placement correction, not an upstream import or publication.

A separately marked v3 migration recognizes untouched alpha.20 placements
from a compact frozen baseline at `d224901d`. Preserve reader height/anchor/
size overrides (even zero), custom pack positions, edits and deletions. Direct
alpha.19 upgrades still receive the expanded information and new lift, but an
existing v2 marker prevents replaying the old update. Only an unedited README
is replaced; metadata/marker writes remain atomic and retryable. No component
source, upstream pins, bootstrap/API, VERSION or published release is changed.

The geometry regression exercises native sizing/placement/plank calculations
across 240 combinations, proves the old overlap and requires clearance above
the actual back edge without crossing the upper row. The expanded 15-case
Lua/LuaJIT suite covers fresh/v1/v2 installs and migration failure recovery.
Both full Lua and LuaJIT runs passed: 312 OrbitUI cases, 58 Python checks
(including all museum-source pixel comparisons), 351 Bookshelf suites with two
native SQLite skips, and all 13 SimpleUI test files. All 41 translation checks
pass. Clean-commit packaging remains a separate final gate, not device
acceptance. Physical Bigme confirmation is still required; not published.

## 2026-10-06: Informative author bust captions (unreleased)

The user requests author information, not just sculpture credits, for the busts.
Add Swedish, source-linked life/writing/major-works cards to all eleven bundled
Modernists/Authors busts. Label the original summaries as AI-assisted OrbitUI
text, retain old artwork credits verbatim below them, and keep the complete
cards below the native 4000-byte UTF-8 limit. The build script is offline after
capturing a frozen alpha.20 baseline; no image processing or runtime network.
Native tap-to-zoom and its scrollable info panel already support the content.

C11 gains a narrowly scoped default-caption migration before native listing.
Each pack has its own update marker, separate from initial seeding. Replace
only recognized old info and an unchanged README. Preserve empty/removed/custom
captions, reader overrides, placements, tap settings, enablement, deleted
entries/files/packs and trial packs. Never rewrite PNGs, attribution notices or
prompts. Atomic failures leave the current file intact and unmarked work can
retry without replaying the completed pack or replacing later edits.

Twelve Lua/LuaJIT regressions and three Python asset checks cover this behavior,
source coverage, reproducible text, exact credit retention and byte limits.
Both full Lua/LuaJIT suites pass: 324 OrbitUI cases, 61 Python checks including
museum-source pixel auditing, 351 Bookshelf suites (two native SQLite skips)
and all 13 SimpleUI files. All 41 translation checks pass. Clean-commit sealed
packaging remains the final local gate; it is not device acceptance.
No component source, upstream pin, VERSION, bootstrap/API or public OTA change.
Not published; native Bigme appearance and scrolling still need confirmation.

## 2026-10-06: Replace Kafka with the approved Kielce bronze (unreleased)

The user explicitly selected the Kielce bust after rejecting the commercial
product-photo candidate. Replace only `Authors/Franz Kafka.png`, retaining its
canonical author binding, biography, zoom and colour behaviour. The new bitmap
is a built-in image_gen background-extraction edit of Pawel Ciesla's 2006
CC BY-SA 4.0 photograph of Anna Wierzchowska-Grabiwoda's 2005 bronze. Preserve
the bowler hat, bronze colour and rough modelling, not the old ivory portrait.
Document the AI-assisted edit honestly: it is not a pixel-identical photograph.
Record the photographer/sculptor separately, original URL/hash, exact prompt,
output hash, change notice, ShareAlike terms and the Polish panorama rights
basis/limits. No commercial product photograph or private preview is bundled.

C11 deliberately gains a narrow reviewed image-upgrade exception. A separate
marker and frozen alpha.20/unpublished-biography baseline replace only the
known old image checksum, then recognized caption/default base-offset fields
and byte-identical shared notices. The new image checksum supports retries
after metadata/documentation failure. An additive dedicated license notice
also covers cases where shared pack notices were customized. Custom/deleted
images and records, custom captions, scale/lift/anchor, native reader overrides,
enablement and all other busts remain untouched. The generic author-info
migration skips Kafka, so it cannot give a custom image the new photo credits.
The update runs before first native listing and never hashes artwork again
after its completion marker. No component source or upstream pins changed.

Ten Lua/LuaJIT migration regressions, one additional biography integration
case and four Python asset checks cover upgrade/retry, preservation, corruption,
RGBA/provenance, bronze colour, base alignment and license/source distinctions.
Both full Lua/LuaJIT suites pass: 335 OrbitUI cases, 65 Python checks including
museum-source pixel auditing, 351 Bookshelf suites (two native SQLite skips)
and all 13 SimpleUI files. All 41 translation checks pass. Local sealed package
validation follows a clean commit; no VERSION bump, push, tag or OTA release.
Physical Bigme appearance, zoom/info and installed alpha.20 migration still
require user acceptance. Code rollback retains the copied artwork and credits.

## 2026-10-06: Prepare alpha.21 for explicit publication

The user requests publication after the approved Kafka replacement. Prepare
`0.1.0-alpha.21` from `ffaab470`, including the preceding unreleased gallery
clearance and author-biography commits. No new upstream import, pin changes,
bootstrap/API changes or reading-data migration. Keep it a prerelease until
physical-device acceptance is complete. CI now explicitly installs Pillow for
the mandatory Kafka colour/alpha checks, rather than relying on runner packages.

Publication gates rerun complete Lua/LuaJIT tests, translations and clean-commit
sealed packaging. Test discovery/install/activation/rollback using the actual
published alpha.20 installer, verify downloaded draft assets and both CI jobs,
then publish and verify anonymous API/download/preview OTA. No existing tag's
bytes are replaced. Gallery spacing and Bigme bust appearance/touch remain
device checks. See `docs/releases/0.1.0-alpha.21.md` for scope and rollback limits.

## 2026-10-06: Retire the generated Lispector portrait (unreleased)

The user explicitly requests removing the old Lispector bust while researching
real sculptures for the other authors. C11 gains a narrow deletion exception:
remove the old runtime PNG, current pack metadata/provenance and preview card,
but retain the researched biography source and frozen historical baselines.
The separate Rio preview remains outside this repository and all OTA packages.
Authors now ships eight PNGs (ten busts together with Modernists).

Before native listing, `core/orbitui_lispector_retirement.lua` removes only the
exact published SHA-256 at the canonical Authors filename. Keep custom images,
file/pack symlinks, other packs, metadata, reader settings and notices. Preserve
the author binding for future reader-supplied artwork. The biography builder
and generic migration skip the retired entry. A separate completion marker
avoids recurring hashes; hash/deletion/marker failures retry without resurrecting
the portrait or deleting intervening custom replacements. No seed-marker reset,
upstream changes, new artwork, version bump, push, tag or OTA release.

Both full Lua/LuaJIT runs passed: 346 OrbitUI cases, 351 Bookshelf suites
(two native SQLite skips) and all 13 SimpleUI files. Python checks total 66;
the additional retirement asset check was also rerun separately after the Lua
run. All 41 translation checks pass. Ten retirement regressions cover exact
deletion, preservation, non-regular files, failures/retries and one-time cost;
biography integration covers the missing runtime entry and startup ordering.
The old hash was verified against the published source, and building author
cards does not restore the retired entry. Package validation explicitly rejects
any bundled `Authors/Clarice Lispector.png`. Clean-commit packaging is the final
local check. The physical-device removal and appearance of remaining ornaments
are still user tests. Code rollback does not restore the removed default.

## 2026-10-06: Replace Mann locally and research real sculpture alternatives

The user requests replacing Mann and looking up real busts/statues for the
remaining interpreted authors, explicitly excluding Joyce and Woolf. Integrate
the previously prepared AI-assisted cutout of Gustav Seitz's bronze portrait,
photographed by Pauline Ahrens. Preserve the photograph-derived PNG, canonical
filename, matching and biography; adjust the default base offset for its alpha
margin. The image is not presented as a pixel-identical extraction.

C11 now includes an independent Mann migration, before generic biography
updates. Replace only the old default checksum and recognized captions/default
placement; keep custom/deleted art, records, captions, overrides and linked paths.
Copy the dedicated notice and replace shared notices only on known checksums.
Old/current hashes support interrupted writes/retries; a completed marker avoids
future hashing. The generic updater skips Mann, as it already does Kafka.

The photograph is CC BY 4.0, but the sculpture/adaptation rights review remains
unresolved. AGENTS and the bundled Seitz notice explicitly prohibit public
push/OTA publication until resolved. This is a local integration, not a rights
clearance or public release. No permission requests were sent. No upstream
code/pins, version, settings or other author images changed. Source findings for
Strindberg, Hamsun, Dostoevsky, Dylan Thomas, Lem and Musil are recorded in
`docs/AUTHOR_SCULPTURE_RESEARCH.md`; no additional replacements are made.

Full Lua and LuaJIT suites pass: 359 OrbitUI cases, 351 Bookshelf suites
(two native SQLite skips) and all 13 SimpleUI files. Thirteen new migration
cases and five Python asset checks cover preservation, retry, symlinks, source
hashes, alpha/colour, base alignment, caption provenance and the release hold.
The Python suite has 71 checks; its museum-source pixel audit is rerun separately
with the local source cache. All 41 translation checks pass. Final packaging
uses a clean local commit, with no tag/push/OTA. Physical-device appearance,
zoom/info and migration from an installed old default remain user checks.

## 2026-10-06: Six original-photo sculpture replacements (unreleased)

The user approves the six remaining replacements and specifically selects
Bavaud's Geneva Musil photo instead of the private-use Belvedere candidate.
Integrate hand-masked original photographs of Eldh's Strindberg, Frolich's
Hamsun, Laveretsky's Dostoevsky, de Wet's Dylan Thomas, Kurkowski's Lem and
Bavaud's Musil. Preserve real surfaces, material colours and anatomy; no imagegen
redrawing, colourization or invented plinths. Hamsun remains monochrome.

C11 adds a checksum-guarded batch migration before generic author biographies,
with exact old/current hashes, independent marker, dedicated hash-scoped credits,
recognized caption/placement changes and resumable partial writes. Preserve
custom art, captions, reader overrides, links and deletions. The generic updater
skips all six to avoid assigning photo credits to user replacements. Existing
author matching, shelf placement policy and tap-to-zoom are unchanged.

Record source/mask/output hashes and separate photograph/sculpture terms.
Dostoevsky uses a new BY-SA photograph, not a relicensing of the old NC-derived
PNG. Original source photos stay outside repo/runtime; masks and reproducible
build scripts are checked in. Joyce, Woolf, Kafka and Mann PNG bytes are
unchanged. Mann's existing public-release hold remains; no version bump,
upstream merge/pin change, push, tag or OTA publication.

Full Lua/LuaJIT runs pass 366 OrbitUI cases, 75 Python checks (museum and sculpture
source-pixel audits included), 351 Bookshelf suites (two SQLite suite skips),
all 13 SimpleUI files and 41 translation checks. The six light/dark cutouts were
visually reviewed. Local clean-commit packaging validates the ZIP and manifest;
actual device migration, colour rendering and zoom/info remain user checks.

## 2026-10-06: Add photographic Svevo and Hemingway; research Dazai (unreleased)

The user approves adding Mayer's Svevo and Boada's Hemingway, and suggests
Nakamura's Dazai statue in Ashino Park. Add the first two as `Authors II` using
the existing seed/planner/zoom paths, with their own install marker and exact
full-name aliases. Do not rewrite older packs, reset markers/settings or alter
frozen replacement baselines. C11 records the additive behavior.

Svevo uses Amrei-Marie's CC BY-SA 4.0 photo from Trieste. Hemingway uses Carol M.
Highsmith's Library of Congress 06293 photograph of Cojimar, selected after the
previously suggested 06294 view proved too distant. A documented source crop
retains detail before deterministic masking. Preserve material colour, anatomy
and source pixels; no generative redraw or invented base. Provenance includes
source/mask/output hashes, photo licenses and separate sculpture-rights notes.
Offline Swedish biographies use institutional sources and native tap-to-zoom.

The Ashino Park statue is confirmed as Shinya Nakamura's, unveiled 19 June 2009.
No suitable photo with verified redistribution terms was found. Record the
city/foundry evidence and defer Dazai rather than bundling a stock photo or
inventing a substitute. No image purchase or rights request was sent.

Full Lua/LuaJIT suites pass: 370 OrbitUI cases, 80 Python checks including source
pixel audits, 351 Bookshelf suites (two native SQLite suite skips), all 13
SimpleUI files and 41 translation checks. The new masks were visually reviewed.
New tests cover alias/placement integration, old-pack preservation, partial
installation retry, provenance, native info limits and reproducible builds.
Existing Modernists/Authors image bytes and migrations are unchanged. Package
validation follows from a clean local commit. Device appearance and touch
behavior remain unverified. No upstream change, version bump, push, tag or OTA;
Mann's release hold and the new per-artwork redistribution review notes remain.

## 2026-10-06: Replace Mann with Molgreen's original photograph (unreleased)

The user approves the Wikimedia photograph of Gustav Seitz's Mann bust by
Molgreen (11 April 2024). Replace the local AI-assisted portrait with a reviewed
deterministic alpha cutout of that photograph. Retain the bronze surface, head,
neck, mounting block and thin bronze plinth; mask the background and separate
granite column. No generative reconstruction, retouching or invented anatomy.
Keep the Swedish biography, author binding, canonical filename and native zoom.

C11 advances Mann to an independent v2 marker/baseline, recognizing both previous
stock image hashes and default placements. A completed v1 marker cannot prevent
this upgrade. Preserve custom/deleted/linked artwork, captions, placements and
notices; retry partial writes safely. The frozen v1 baseline stays unchanged.
The new photograph and cutout use CC BY-SA 4.0 with Molgreen/Seitz attribution;
the separate sculpture review basis is documented in the dedicated notice.
This is not blanket rights-holder permission. The old AI-assisted bitmap remains
under its existing release hold, including unpublished Git ancestors. Do not
push those ancestors; preserve local history and prepare a public history without
that bitmap before any later release. No history rewrite is performed here.

Full Lua/LuaJIT runs pass 372 OrbitUI cases, 82 Python checks (including exact
source-photo/mask reproduction), 351 Bookshelf suites (two native SQLite suite
skips), all 13 SimpleUI files and 41 translation checks. Existing font-dependent
cases remain skipped. Fifteen targeted migration cases cover both old images,
the v1 marker, preservation and retries; seven asset checks cover provenance,
pixel identity, credits, placement and unchanged Joyce/Woolf/Kafka. Light/dark
previews were visually reviewed. Clean-commit ZIP/manifest validation is the
final local gate; actual reader appearance, zoom and migration remain untested.
No upstream code/pin changes, version bump, push, tag or OTA publication.

## 2026-10-06: Publish alpha.22 photographic author ornaments

The user explicitly requests publication after approving the Molgreen Mann
replacement. Prepare alpha.22 as a prerelease, not a device-accepted beta.
It includes the seven photographic replacements, additive Svevo/Hemingway pack
and checksum-only retirement of the generated Lispector image described above.
Joyce/Woolf/Kafka, upstream pins and stable bootstrap files remain unchanged.

Preserve all five unpublished commits at local branch
`local/author-artwork-pre-alpha22` (tip `6f0889ec`). The public change is a squash
of their final tree on alpha.21, not a merge of their ancestry. This keeps the
uncleared intermediate Mann bitmap out of GitHub without deleting local work,
rewriting published history or force-pushing. Never publish the archive branch.
The sculpture-image test now compares unchanged old defaults against the public
alpha.21 tag rather than a local-only commit. Frozen migration baselines remain
unchanged and retain their historical provenance records.

Publication gates: complete Lua/LuaJIT suites with external original-photo
audits, translations, clean-commit sealed package, forbidden-blob ancestry check,
actual alpha.21 installer smoke test, downloaded draft checksums, both CI jobs
and anonymous live OTA. Physical Bigme appearance, native touch/zoom and device
migration remain unverified. See the release notes for update/rollback behavior.

## 2026-10-06: Refine Hemingway and Mann bases (local, unpublished)

The user's device photos show Hemingway too small/low and Mann's wide mounting
plate protruding sideways. Retain the existing original photographs and their
rights notices; do not generate anatomy, retouch colours or narrow shoulders.
Mask Mann's wide plate, keep the compact mounting block, use scale 0.85. Crop
Hemingway's real stone support to a level lower edge and use a shorter 1024 x 896
canvas at scale 1.0. Removing transparent headroom increases visible height by
about 67% without creating a taller-than-row transparent widget. Other images,
author matching, biographies and upstream sources/pins remain unchanged.

Extract the existing Mann updater to a shared single-artwork implementation.
Mann v3 and Hemingway v1 have independent markers, frozen exact old/new hashes,
known metadata/default-placement values and checksum-scoped notices. Completed
alpha.22 markers do not block these refinements. Keep custom/deleted/linked
artwork, captions, placement overrides and pack settings. Interrupted updates
retry safely; completed starts do not rehash images. Older published migration
baselines are byte-for-byte unchanged. No version bump, push, tag or OTA release.

Validation: 87 Python checks with external original-photo/museum audits, 389
OrbitUI integration cases on both Lua and LuaJIT, Bookshelf's 351 passing suites
(2 SQLite suites skipped; native-font cases also skipped), all 13 SimpleUI test
files, and 41 translation checks. Light/dark before/after previews reviewed.
Clean-commit runtime ZIP validation is the final local gate. Physical device
appearance and migration still need testing.

## 2026-10-06: Publish alpha.23 bust refinements

The user explicitly requests publication of the reviewed Hemingway/Mann
refinements at `4431a382`. Prepare alpha.23 as a prerelease, not a device-accepted
beta. Bump VERSION and release documentation only; retain upstream pins, stable
bootstrap/API 1, all other artwork, biographies and settings behavior.

Publication gates: both complete Lua/LuaJIT test runs with source-pixel audits,
translations, clean-commit runtime package, held-blob ancestry exclusion, native
OTA from the real alpha.22 installer, draft-asset byte verification, both CI jobs
and anonymous live OTA. Device appearance and migration still need user testing.
Do not publish the local archive branch containing the held earlier Mann bitmap.

## 2026-10-06: Frontal Mann photograph (local, unpublished)

The user prefers the composition of the previous Ahrens/image_gen preview and
approves a fresh mask of its original photograph without generative redrawing.
Use Pauline Ahrens's 2022 frontal photograph, CC BY 4.0, verified against the
Bildhauerei in Berlin source. Retain its head, neck, bronze mounting block and
thin plinth; exclude only the surroundings and granite column. Preserve colour,
camera angle, facial detail and proportions. The new PNG is independently
reproducible from the original photograph and checked-in mask. The held
image_gen bitmap remains excluded from distribution, including Git history.

Contract C11: use a separate Mann v4 marker and frozen alpha.23 baseline.
Recognize all earlier standard images and default metadata, even after v3;
preserve customized/deleted/linked files, native placements and edited captions.
Retain the Swedish author biography, matching and zoom. Only Mann's PNG changes;
all other ornaments and previously published migration baselines remain exact.
Update hash-scoped attribution, source records and the light/dark preview.
No component code, upstream pin, bootstrap, version, push, tag or OTA changes.

Validation is recorded in TESTING.md. The physical reader's colour display,
tap/zoom and real installed-default migration still require device acceptance.

## 2026-10-06: Publish alpha.24 frontal Mann photograph

The user explicitly requests publication after reviewing the non-generative
Ahrens replacement. Prepare alpha.24 as a prerelease, not a device-accepted beta.
Keep upstream pins, the stable bootstrap/API 1, all other artwork and reading
data unchanged. Retain the old AI-assisted bitmap's release hold and keep its
local archive branch unpublished.

Publication gates: full Lua/LuaJIT suites with external source-pixel audits,
translations, a clean-commit sealed runtime package, forbidden-blob ancestry
check, native OTA from the real alpha.23 installer, draft download verification,
CI and anonymous live OTA. Physical reader appearance and migration remain
device checks, separate from the automated release tests.

## 2026-10-06: Publish alpha.25 cover sizing and bottom-bar margins

The user explicitly requests publication of the cover-size setting and the
preceding bottom-bar margin fix. Prepare alpha.25 as a prerelease, not a
device-accepted beta. No upstream merge: retain Bookshelf `74b825bb`, SimpleUI
`b58dfefb`, sources.json, the stable bootstrap/API 1 and all artwork.

Contracts C02/C07: reflow Home after navigation chrome changes, rebuild a shown
Bookshelf dock and defer hidden/warm shelves until return. Ordinary icon/status
refreshes must not trigger a full shelf rebuild. Add a per-chip 50-150% cover-size
control in the physical bookcase style, shared by render and pagination. Preserve
aspect ratio, 100% legacy geometry, ornaments and dock/footer reserves; clear
old back-page boundaries on resizing without moving the current book.

Publication gates: complete Lua/LuaJIT suites, translations, clean-commit runtime
ZIP, held-bitmap ancestry exclusion, native OTA from the actual alpha.24
installer, downloaded draft-asset hashes, CI and anonymous live OTA. Physical
reader appearance, live margin changes and device OTA remain manual checks.
Keep the old Mann bitmap's local archive branch unpublished.

## 2026-10-09: Reviewed SimpleUI upstream merge after alpha.30

The user deferred modularization and requested an upstream merge only. Start
from clean main `93cd76c9ca893ff36aed9ac19920357ef33566f9` on
`maintenance/upstream-2026-10-09`. Bookshelf master remains fully integrated at
`74b825bb20aa5560129384910ad414bd2bebad75`; its subtree is unchanged.

SimpleUI main advances from `b58dfefb26012e44b5b9c96d61d646466ca53b46` to
the reviewed, fixed target `6f34fb76a137c86e30f4eaf7caa290e927803982`.
Import commit `ea116e65` retains the complete unsquashed ancestry. The latest
tagged upstream release remains 2.7.5. The 16 reviewed commits are:

- `b115c645`: wallpaper darken and live lighten control.
- `53e294fa`, `f822ca1a`: independent book-close target and native startup menu.
- `778070a6`, `dfbf718a`, `39d0f2fc`: paginated backdrop and night-mode tint fixes.
- `e36ee29d`: digital clock glyph alignment.
- `c0f16812`: translation catalog refresh.
- `b51d902b`, `e4ed85e1`: independent progress badge sizes and scale accessors.
- `3956c079`: shared section-label/page state.
- `01f50fc1`, `434318f6`: optional titlebar tabs, ordering and search.
- `661b85c8`: unified book-stack naming.
- `9f3ed4fc`: install shared menu hooks only once.
- `6f34fb76`: faster reader return, prefetch, statistics and metadata/cover caches.

Resolve 17 textual conflicts semantically, preserving OrbitUI's startup guard,
Android sync workaround, BookOrbit refresh, fresh section labels, local label
scales, Bento padding and independent layout snapshots. Keep local Swedish
translations while incorporating new strings; fix the imported Chinese plural
entries to match their existing nplurals=1. Rebuild the module map for three new
runtime modules: `sui_section_label`, `sui_tab_strip` and `sui_bim_stamp` (264
canonical modules). Advance only the SimpleUI upstream pin, not fork provenance.

Some conflict resolutions necessarily adapt code in the import commit; the
following compatibility/test/documentation commit isolates the remaining work.
Do not automatically switch existing users to tabs or overwrite native library
layout defaults on first run. Keep classic/custom icons, button-only backdrops,
legacy wallpaper/grid scale accessors, collection stack settings and hidden
statusbar geometry. Preserve top-aligned Bento cells with per-module margins.
New PageState mirrors and initializes from legacy pagination fields. Retain
fresh labels rather than cached widgets that could be freed or retain callbacks.

Regression tests caught the removed `Bottombar.SIDE_M` API used by Bookshelf;
restore it via the new shared geometry, together with the topbar height used by
live dock reflow. Preserve copied layout drafts and initialize membership before
a save without a prior load. Transient SQL/cover-decode failures must retry rather
than populate permanent empty-result caches. Confirmed missing covers still use
the new directory/DB/WAL invalidation. Free injected tab strips on teardown.

Affected contracts: C01 shared hook lifetime, C02 close targets/dock reflow,
C04 bounded caches and transient failure handling, C06 legacy APIs, C07 layout,
icons and margins, C08 nondestructive settings, C09 reviewed history. C03 normal
reader opening, C05 BookOrbit sync ownership, C10 shared panels and C11 ornaments
remain unchanged. VERSION, root bootstrap, artwork and public release bytes are
unchanged. The held Mann bitmap remains excluded; no archive branch is pushed.

Adaptation commit `bf5ea7b2` passes full Lua/LuaJIT, translations and clean-commit
sealed ZIP validation (1661 runtime files, 1714 archive entries, 264 modules).
Detailed counts and unchanged skip reasons are recorded in TESTING.md. Read-only
collection at 05:11 UTC confirms zero missing commits for both upstreams.
The local candidate retains VERSION alpha.30 and never replaces the published
release archive. Device checks remain outstanding:
reader return to each destination, repeated native menu opens, Bento/custom
screens, live dock margin changes, optional tabs/icons and paginated wallpaper
backdrops in day/night mode. Retain the existing rollback installation and
settings; no new destructive migration or modularization is part of this merge.
No push, version bump, tag, release or OTA publication is authorized/performed.

## 2026-10-09: Prepare alpha.31 for explicit publication

The user explicitly requests publication of the reviewed upstream merge at
`451f29d3`. Prepare alpha.31 as a prerelease, not a device-accepted beta. Include
the unsquashed import `ea116e65` and compatibility adaptations `bf5ea7b2` without
following newer upstream revisions. Preserve bootstrap/API 1, all artwork,
existing reading/sync data and the held-bitmap exclusion. Never push the local
artwork archive branch or replace already published release assets.

Publication gates: full Lua/LuaJIT suites, translations, clean-commit sealed
runtime package, outgoing-history/runtime held-bitmap audit, native OTA from
the actual published alpha.30 installer, downloaded draft-asset verification,
both CI jobs and anonymous live OTA. Physical reader checks remain outstanding
as listed in TESTING.md and the release notes. No modularization is included.

## 2026-10-09: Second reviewed SimpleUI upstream merge after alpha.31

Scope: "Merga upstream igen", not publication. Start from clean main
`8af873836a2a12f79bd3015494b735b626dbe943` on
`maintenance/upstream-2026-10-09-2`. Read-only collection at 12:37 UTC reports
Bookshelf master unchanged at `74b825bb20aa5560129384910ad414bd2bebad75`.
SimpleUI main advances from `6f34fb76a137c86e30f4eaf7caa290e927803982` to fixed
review target `f14507afdc2cabd36a2ec20a6c3c5dfe0c98a211` (latest stable 2.7.5).
Unsquashed subtree import: `5e9ec1af52160fab6ee1dd96d70fd279cbef7c06`.
The nine new commits, including two merge commits, are:

- `efdf7998`, `314fd1ec`, `feffaf82`: French translation updates.
- `b29e64b9`: cover-strip/bar backdrop controls and softer cover shadows.
- `5cb66db9`, `6a9627a3`: upstream branch/PR merges.
- `901e948d`: shared generated cover placeholders, cropped Cover Deck sides.
- `2c673888`: default/classic folder and collection book-stack styles.
- `f14507af`: shared radio/alignment menus, lazy submenu construction.

Resolve seven conflicted files: wallpaper keeps both the local button-only
backdrop and the new cover-strip API; Cover Deck uses the shared radio helper
while retaining BookOrbit Want to Read and unsaved native collections; wallpaper
menus retain button opacity alongside the new shared bar controls. Merge PO/POT
catalogs by message identity rather than stale line references: preserve local
Swedish/custom strings and corrected single-plural Chinese entries while adding
upstream messages. Translation validation has no exception or new failure.

Advance only the SimpleUI upstream pin. Regenerate the module map for
`engines/sui_cover_placeholder.lua` (265 canonical paths). Keep the remaining
compatibility adaptations separate from the import. C01/C06: placeholder
teardown restores only the owned upvalue in the captured native function, so
later third-party patches survive. C04: cap shadow masks at 64 size tuples,
free buffers when clearing and avoid arithmetic cache-key collisions.
C07/C08: preserve transparent titlebar/pagination/cover-strip defaults, opt-in
4px shadows, detailed Currently Reading stats and left description alignment.
Explicit user settings still win. Include the new strip-opacity key in native
library backups and appearance presets; no settings migration is required.

The new stack styles and opacity/alignment choices remain available. Native
test doubles gain the new placeholder module's UI dependencies; no assertions
or suites are removed. C02/C03 navigation and reader flow, C05 BookOrbit sync
ownership, C10 shared panels and C11 ornaments are unchanged. Bookshelf code,
artwork, VERSION alpha.31, bootstrap/API 1 and published archives are untouched.
The held Mann bitmap remains excluded and its local archive branch is not pushed.

Full Lua and LuaJIT verification passes 475 OrbitUI cases across 40 files, 351 Bookshelf suites
(two existing SQLite suite skips) and all 13 SimpleUI files. Python runs 91
tests with four existing source-cache audit skips. All 42 catalogs pass. The
clean-commit package check is recorded below before local integration.
Physical-device checks remain outstanding:
placeholder sizing/cropping, default/classic folder stacks, day/night shadows
and opacity, repeated native menu opens and external placeholder patches.
Keep the previous installation for rollback; no OTA or release is published.

Validation: adaptation commit `67f00890` passes clean-commit sealed runtime
packaging: 1663 manifest files, 1716 archive entries and all module, asset,
license and recovery checks. The reviewed SimpleUI target is fully in ancestry;
Bookshelf and all artwork/bootstrap/version files are byte-identical to alpha.31.
The local package still identifies as alpha.31 for development only and must
never replace that published release's assets. No push, tag or version change.

## 2026-10-09: Prepare alpha.32 for explicit publication

The user explicitly requests publication after the reviewed merge at `0c04c08c`.
Prepare alpha.32 as a prerelease, not a device-accepted beta. Include the
unsquashed import `5e9ec1af` and compatibility adaptations `67f00890`, keeping
the exact reviewed upstream pins. Preserve bootstrap/API 1, all artwork,
reading/sync data and the held-bitmap exclusion. Do not push the local artwork
archive branch or replace any previously published release assets.

Publication gates: full Lua/LuaJIT suites, translations, a clean-commit sealed
runtime ZIP, outgoing-history/runtime held-bitmap audit, native OTA from the
published alpha.31 installer, downloaded draft-asset checksums, both CI jobs
and anonymous live OTA. Device-only visual checks remain listed in TESTING.md
and the release notes; there is no modularization or new upstream merge here.

## 2026-10-10: Reviewed Bookshelf 5.4 upstream merge after alpha.32

Scope: "Merga upstream igen" and explain relevant changes, not publication.
Start from clean main `fd61b010c02c7ef7e9226c76f50cd76e3262d38f` on
`maintenance/upstream-2026-10-10`. Read-only collection fixes the review target
to Bookshelf master `a0bc7e37ae8ca444026d980c1820e0cf0f052131`, version 5.4.0:
166 commits / 148 changed files since `74b825bb20aa5560129384910ad414bd2bebad75`.
SimpleUI main remains `f14507afdc2cabd36a2ec20a6c3c5dfe0c98a211`; no import there.
Unsquashed subtree merge: `c9f1bcc5`. Original fork provenance is unchanged.

The full commit range, net diff, changed migrations/dependencies and new native
source API were reviewed. Main additions: layered/editable per-shelf themes and
four-card Theme library; shelf-of-shelves sources; independent group/custom
cover labels; an opening pose for face-out books; native progress-bar styles;
wallpaper blur/cover panels; per-shelf ornament decks/placement; fallback-cover,
font, series-recent-read sorting, search and OPDS fixes. The 3D opening painter
does not replace OrbitUI's custom slipcase painter. The new source API is an
extension point, not a newly implemented BookOrbit integration.

Resolve 13 conflicts individually in README, repository, chip editor, image
source, full-screen modules, ornament deck, settings, shelf row, spine shelf,
widget, POT, grid-label tests and stack-display tests. Retain scoped candidate
caches/Next shelves, hidden metadata alias paths, series boxes/completion,
cover size, dock reserves, incremental Hardcover linking and transparent label/
footer controls. Adopt the native live-apply ordinary-chip editor, including
pending-tab cleanup and flush-on-close/suspend; the old Save/Cancel semantics
are deliberately replaced as part of the requested upstream feature update.
Preserve native one-pixel bare-panel gaps, not the old opaque-footer hairline.

Post-import compatibility adaptations (separate commit):

- C04/C06: scope cover-wrapper memo locals to fit LuaJIT's 200-local limit;
  retain patch detection, one-time probes and invalidation. The custom Next
  shelf resolves the library through the new native HomeDir helper.
- C02/C07/C08: profile themes use `orbitui:<profile>:<chip>` and existing
  `profile_shelf_*` records. Theme menu lookup/activation hooks enumerate fixed
  profiles without creating tabs, preserve visual overrides, and honor deferred
  saves. Same-chip cross-profile activation still rebuilds. Native tabs and
  nested-shelf inheritance remain available; profile roots stay fixed.
- C07/C11: synchronize/shuffle each shelf's deck before its first page signature,
  once per process; prune against native plus profile IDs. Manual changes stay
  stable on revisits and restarts randomize again. All author reservations and
  the one-ordinary-ornament rule remain. Block ornament gestures above the dock
  at the actual pagination boundary. No artwork/asset changes.
- C07: clip new 3D pose columns before raw framebuffer writes, including a
  lifted cover extending above the screen; free its temporary buffer on errors.
- Update source-pattern/test doubles for changed native APIs and menu rows,
  retaining behavioral coverage. Add theme/deck isolation, migration, deferred
  persistence, same-chip navigation, dock hit-boundary and pose-boundary cases.

Advance only the Bookshelf upstream pin; regenerate 277 module-map entries.
C01/C03 normal host/reader ownership, C05 external BookOrbit sync ownership,
C06 read-only compatibility guard, C10 shared services and C11 artwork/license
holds remain. VERSION alpha.32, bootstrap/API 1, SimpleUI and all artwork are
unchanged. No credentials, reading data, external plugins or device files were
touched. Upstream's versioned theme migration is retained and tested natively;
it translates applied-theme/piece choices, not a reset of all preferences.

Validation: adaptation commit `77a347c1` passes both complete Lua and LuaJIT
runs: 485 OrbitUI cases in 41 files, 379 Bookshelf suites (zero failures, two
existing native SQLite suite skips), all 13 SimpleUI files and 91 Python tests
(four existing external source-cache audit skips). Native-font skips remain;
Bookends parity helpers have no adjacent checkout and check no files/regions.
All 42 translation catalogs, 277 module-map paths and 781 Lua syntax checks
pass. No skip or known-failure gate was added by the adaptations. Clean-commit
sealed packaging verifies 1678 manifest files and 1731 archive entries,
including modules/assets/licenses/recovery files. Local development ZIP SHA-256:
`4b132c174575a0be0567f67e602eff7cecf8b71673c68f521edbad0f4c33f57b`.
Never replace published alpha.32 bytes with this unpublished development ZIP.
Both frozen upstream targets are ancestors, with zero missing commits to those
targets; SimpleUI, artwork, VERSION and bootstrap files match the starting tip.

Device checks still required: first launch with the existing
custom look, separate Library/Manga themes and return navigation, ornament
placement/revisits/shuffle, completed boxes, live shelf editor, blur in colour/
night mode and opening poses at screen edges. No measured speedup or physical
Bigme test is claimed. Retain the previous install and a settings backup before
device acceptance; theme storage changes mean a code-only rollback is not an
inverse migration. No push, version bump, tag, release or OTA publication.

## 2026-10-10: Prepare alpha.33 for explicit publication

The user explicitly requests publication after the reviewed merge at `86cc1ee0`.
Prepare alpha.33 as a prerelease, not a device-accepted beta. Include the
unsquashed Bookshelf import `c9f1bcc5` and adaptations `77a347c1`, keeping the
reviewed Bookshelf/SimpleUI pins. Preserve bootstrap/API 1, all artwork and
external BookOrbit sync ownership. Do not push the local artwork archive branch
or replace any previously published release assets.

Publication gates: both full Lua/LuaJIT suites, translations, clean-commit
sealed packaging, outgoing-history/runtime held-bitmap audit, native OTA from
the published alpha.32 installer, downloaded draft checksums, both CI jobs and
anonymous live OTA. Device checks remain outstanding in TESTING.md and release
notes. Native theme migration requires a settings backup for full rollback;
the isolated OTA smoke test validates code rollback, not UI/theme acceptance.

## 2026-10-11: Reviewed Bookshelf 5.4.1 upstream merge after alpha.35

Scope: "Merga upstream igen", not publication. Start from clean main
`f3f48f1ae54cbc6ff36db72ce7b124b4f002ec48` on
`maintenance/upstream-2026-10-11`. Read-only collection at October 10 22:56 UTC
(October 11 locally) fixes Bookshelf master to
`7c4c5da6f0668c8f73ee7a791b0c25f149f72a1d`, release 5.4.1: ten commits and
42 changed files since `a0bc7e37ae8ca444026d980c1820e0cf0f052131`.
SimpleUI main remains `f14507afdc2cabd36a2ec20a6c3c5dfe0c98a211`; no import there.
Unsquashed subtree import: `f7f567e4`. The reviewed commits are:

- `09f418b7`: allow a nested shelf to choose its own theme.
- `54066344`, `d5eafa8e`, `514a123e`, `b1d40006`: per-shelf cover captions,
  compact picker layout, meaningful group-author controls and library-wide groups.
- `fa5b963c`: simplify group captions to Show author below series.
- `eadf7027`, `1319eaa6`, `27c184e8`, `7c4c5da6`: caption terminology,
  font-size dialog naming, translations and release metadata.

Review the full commit list, net code/test/catalog diff and removed group APIs.
There are no new runtime modules, dependencies, artwork or settings migrations.
Resolve three conflicts in the custom-caption editor, shelf widget and POT.
Keep OrbitUI's scoped target/function preview through the editor's new `_open`;
retain `_bookLabelMode` and route `_booksLabelNone` through it. Preserve the
Manga folder-strip policy, above-cover position, card geometry and local
transparent-label strings. Regenerated upstream catalogs retain local additions.

Separate compatibility work suppresses the new native grid-only caption picker
through `Editor.cover_text_external` while embedded. OrbitUI already has one
chip-level menu for grids, physical books and placement; using both would split
preferences between `cover_text*` and `cover_label_*`. Keep the existing local
storage, independent child-chip defaults and profile-qualified IDs; do not
migrate preferences or opt chips into native parent-caption inheritance.
Standalone Bookshelf retains its new picker and inheritance. Tests cover both.
Advance only the Bookshelf upstream pin; keep original fork provenance.

C07 intentionally adopts upstream's library-wide group-caption simplification:
Show author below series replaces None/Author/Custom. An old Custom selection
reads as Author without deleting its stored template, so code rollback retains
the old value. This does not affect individual book captions or OrbitUI's
physical series-box titles/count badges. C07/C08 nested-theme pickers now target
the actual child and can restore parent inheritance without modifying the parent
or either profile's theme. C06 editor callback compatibility is retained.

C01-C05 host/navigation/cache/sync ownership, C09 explicit release policy,
C10 shared services and C11 ornaments remain unchanged. VERSION alpha.35,
bootstrap/API 1, SimpleUI and artwork are byte-identical to the starting tip.
No device files, credentials or reading data are touched. The held Mann bitmap
and its unpublished archive branch remain excluded.

Validation: adaptation commit `c4552ed9` passes both complete Lua and LuaJIT
runs: 508 OrbitUI cases across 42 files, 380 Bookshelf suites (zero failures,
two existing native SQLite suite skips), all 13 SimpleUI files and 91 Python
tests (four existing external artwork-source audit skips). Existing native-font
skips and absent adjacent Bookends parity checkout remain. All 42 translation
catalogs, 277 module-map entries and 786 Lua syntax checks pass. No skip or
known-failure exception was added. The version-identity test is updated to
5.4.1; no behavioral assertion was removed to accept the merge.

The clean-commit sealed package validates 1684 manifest files and 1737 archive
entries, including modules, assets, licenses and recovery documentation. This
unpublished alpha.35 development ZIP has SHA-256
`aa506b5a27c9efb106ccf6adfb6905cff8d72e5a31b6326c7b2142997bc4d7a5`;
it must never replace the published alpha.35 artifact. Read-only collection at
23:02 UTC confirms zero missing commits for both tracked upstream branches.

Device checks remain outstanding: nested theme selection/return to inheritance,
both library profiles, title/author/series/custom captions above and below in
grid/full-screen/bookcase views, and the series-author toggle on native stacks.
Keep the existing installation and settings backup. No push, version bump,
tag, release or OTA publication is part of this merge.

## 2026-10-11: Prepare alpha.36 for explicit publication

The user explicitly requests publication of the reviewed Bookshelf 5.4.1 merge
at `966252a1`. Prepare alpha.36 as a prerelease with no further upstream changes.
Include subtree import `f7f567e4` and compatibility work `c4552ed9`. Preserve
bootstrap/API 1, SimpleUI, artwork, per-chip caption preferences and external
sync ownership. Do not push any local artwork archive branch or replace earlier
published release bytes.

Publication gates: full sequential Lua/LuaJIT suites, translations, clean-commit
sealed packaging, outgoing-history/runtime held-bitmap audit, native OTA from
the published alpha.35 installer, downloaded draft checksums, CI and anonymous
live OTA. These are headless tests, not reader acceptance. Nested themes and
all caption views/placements still need reader checks; retain a settings backup.
Upgrades from before alpha.33 retain the theme-migration rollback caveat.

## 2026-10-12: Reviewed Bookshelf 5.4.3 and SimpleUI upstream merge

Scope: "Merga upstream igen", not publication. Start from clean main
`68a9fa0b83301e6d95f05cc1b58cb3be8e5d1c1e` (published alpha.36) on
`maintenance/upstream-2026-10-12`. Read-only collection at 04:08 UTC freezes:

- Bookshelf master: `7c4c5da6f0668c8f73ee7a791b0c25f149f72a1d` ->
  `ed135103c687a09e0443ec8c3119033adf579b0f`, release 5.4.3, seven commits,
  35 files. Unsquashed subtree import `687e42ab`.
- SimpleUI main: `f14507afdc2cabd36a2ec20a6c3c5dfe0c98a211` ->
  `213a3c70f4e8670394c4ac6db63baaea1660ba3a`, still labelled 2.7.5,
  four commits, 24 files. Unsquashed subtree import `1df2426e`.

Reviewed Bookshelf changes: `4b7ab709` whole-bookcase fetch and wallpaper-only
themes, `822a3742` 5.4.2 release, `6ea5ef0b` fixed hero height across caption
choices, `e3b2c19b` Auto by drill level, `5ae4e248` distinct ornament deals
inside groups, `c8c8fb6e` wallpaper-safe opening-ring erase, `ed135103` 5.4.3.
SimpleUI: `8a63906b` D-pad focus cells, `97301e17` content-aware module
updates, `79b56a7d` in-place clock/status refresh and raster/metadata reuse,
`213a3c70` hide Uncategorized by default with a toggle.

Review includes the net runtime/test/catalog diff, settings and removed APIs.
One new runtime module, `infra/sui_raster_cache.lua`, is added to the generated
map. No dependency, artwork or data migration is introduced. Original fork
provenance remains unchanged; only the reviewed upstream pins advance.

Resolve four Bookshelf and six SimpleUI conflict files individually, retaining
the profile filter, explicit Covers pin, legacy unset Auto, scoped labels,
Manga strips, hidden Recent books, live read status, bounded caches and local
module decorations. Separate compatibility work records these semantic choices:

- C07: explicit Auto adopts Level 1/Level 2 even when the top level is expanded.
  Profile records persist the two keys independently. Unset remains the old
  automatic policy; no settings are rewritten. Remote Spines falls back to
  Covers rather than inadvertently falling through to the local list default.
- C07: hero height uses our `cover_label_*` adapter across native/nested/profile
  shelves, not upstream's separate `cover_text*` preferences. Per-chip text,
  Above placement, all-face-out policy, series boxes and dock reserves remain.
- C04/C06: accept the shared raster LRU but retain a 64-entry bound alongside
  3 MiB, including tiny/zero-byte entries, colour-aware byte counts, tuple
  geometry keys and existing clear/badge APIs. Metadata stays bounded to 256
  rows/five seconds, with short negative probes, cheap progress-only reads,
  prefetched descriptions and immediate live-status refresh. Sidecar reads
  never close/write. New BIM change events also clear stale series metadata.
- C02/C04/C07: live text updates repaint only changed boxes; changed geometry
  rebuilds the appropriate widget. Preserve separate topbar instances per window,
  clock module backgrounds/hold wrappers, and content passed to stats updates.
- C08/C11: wallpaper-only packs may be themes; each drill-in gets a stable seed
  in its existing profile-qualified deck. Native page maps start from the same
  deal as page one. Keep session shuffling, manual choices, ordinary ornament
  limits and author-bound bust rules. Opening selected covers restores wallpaper.

The native Uncategorized default is adopted for SimpleUI metadata browsing;
it neither deletes books nor changes OrbitUI's fiction/manga membership.
C01/C03/C05 host, opening and synchronization ownership remain unchanged;
C09 still requires a separate publication request. VERSION alpha.36,
bootstrap/API 1 and artwork are unchanged. No device files or credentials
are accessed. Held Mann artwork and its archive branch remain unpublished.

Validation: full Lua and LuaJIT runs pass 515 OrbitUI cases across 43 files,
380 Bookshelf suites (zero failures, two existing native SQLite suite skips),
all 13 SimpleUI files and 91 Python tests (four existing external artwork
source-audit skips). Both interpreters also rerun all integration tests and the
native view/row-budget suites after the final profile-versus-native OPDS lookup
guard. Existing native-font skips and absent adjacent Bookends parity checkout
remain. All 42 translation catalogs, 278 module-map paths and 788 Lua syntax
checks pass. No skip or known-failure allowance was added. The new regressions
exercise real Auto/profile persistence, caption ownership, shared raster eviction,
clock refresh/backgrounds, isolated topbars and metadata/status invalidation.
Read-only collection at 04:23 UTC reports zero missing commits for both branches.

Compatibility commit `1e280cda` passes clean-commit sealed packaging: 1686
manifest files and 1739 archive entries, including the new raster module,
assets, licenses and recovery documentation. That unpublished alpha.36
development ZIP has SHA-256
`2ae2106a16ad76e19f63de69a5fa55dc695c6294270142944061affc77745046`.
It must never replace the published alpha.36 release artifact. Both frozen
upstream tips are ancestors; VERSION, bootstrap files and artwork are identical
to the starting tip. The maintenance branch is fast-forwarded into local main
after recording this validation.

Device checks remain outstanding: Auto levels on both profiles and native/
nested shelves; hero consistency with labels above/below/none; drill ornament
revisits and manual shuffle; selected-cover opening over wallpaper; Home clock
ticks, suspend/resume, custom screens and live status changes; colour/night
rasters and metadata browsing's Uncategorized toggle. Keep the prior install
and settings backup. No physical Bigme test or measured speedup is claimed.
No push, version bump, tag, release or OTA publication belongs to this merge.

## 2026-10-12: Prepare alpha.37 for explicit publication

User explicitly requested publication after the reviewed upstream merge at
`527e35aa`. Prepare alpha.37 as a prerelease, without further upstream changes.
The Bookshelf 5.4.3 and SimpleUI October 12 pins above are the release baselines.
Bootstrap/API 1 and artwork remain unchanged. Do not publish the held Mann
bitmap or push the local artwork archive branch.

Release gates: sequential full Lua/LuaJIT tests, translations, clean-commit
sealed packaging, outgoing-history/runtime held-bitmap audit, native OTA
upgrade/rollback using the published alpha.36 installer, downloaded draft-asset
checksums, CI and anonymous live release/OTA verification. Do not overwrite any
existing release's assets. Device acceptance remains open for the cases above;
no measured performance improvement is claimed. Keep the prior installation and
settings backup, including the pre-alpha.33 theme-migration rollback caveat.

## 2026-10-12: Reviewed Bookshelf 5.4.4 follow-up merge

Scope: "Merga upstream igen", not publication. Start from clean main
`a97246c9cb6171bc92f0b67eefdbc21327dc3b7a` (published alpha.37) on
`maintenance/upstream-2026-10-12-followup`. Freeze the two tracked targets:

- Bookshelf master: `ed135103c687a09e0443ec8c3119033adf579b0f` ->
  `2c8bfd8e53b73b24232e674e12ebc6168963aef5`, release 5.4.4, three commits,
  28 files. Unsquashed subtree import `c3a0f5b0`.
- SimpleUI main: `213a3c70f4e8670394c4ac6db63baaea1660ba3a` ->
  `24eb65f77be5d82e27ffe4f44bacd70db9677ed1`, still versioned 2.7.5,
  two commits (including merge), Czech catalogue only. Subtree import `2a9799c5`.

Review covers the full commit list, runtime/test changes, release notes and
catalogue changes. Bookshelf `bbcd3799` adds per-level list density, `70a3c642`
adds Finished/On hold orientation reasons and fixes favourite markers, and
`2c8bfd8e` updates version/catalogues. SimpleUI merges Czech translations
`49b3db31` via `24eb65f7`. No dependency, artwork, removed runtime module or
settings migration. Original fork provenance remains; only integrated pins
advance. No module-map regeneration is needed.

Resolve Bookshelf's three conflict files individually: README keeps the local
unset-style and footer-hold semantics while describing the new levels;
`_chipListValue` keeps the profile-first lookup and adds native level resolution;
the extracted-method gesture fixture retains both profile and level stubs.
The Czech update merges cleanly. Separate compatibility work adds the three new density
keys to the existing profile whitelist and resolves the profile gesture's key
before save. A regression first reproduced lost Level 2 settings, then passes
with independent prose/comics reloads, reads, writes, clears and native-name
isolation. New upstream tests retain their assertions with the profile-method
stub and cover-constructor source locator adapted to the embedded component.

C07 adopts the new list-level controls and top-right favourite mark, preserving
all-face-out books, labels above/below covers, series-box geometry/completion,
ornaments and dock clearance. Standalone Bookshelf retains its new orientation
reasons; they cannot undo OrbitUI's all-face-out override or rewrite preferences.
C08 retains settings paths and unrelated profile fields. C01-C06 and C10-C11
ownership rules remain unchanged. C09 requires separate publication approval.
PR #508 is still open, not merged; do not duplicate its series-box implementation
alongside OrbitUI's adapter. VERSION alpha.37, bootstrap/API 1 and artwork are
unchanged. No device files, reading data or credentials are accessed. The held
Mann bitmap and its unpublished archive branch remain excluded.

At 08:36 UTC, the read-only watcher found two additional SimpleUI commits:
`9503ffc2` Chinese catalogue updates and merge `5bddc5bb`. Review their two-file,
translation-only diff and import exact target
`5bddc5bb7858c2e75a1047b5adfc9c9bbc8e2f1f` in subtree commit `02e72c24`.
Keep the existing single-plural-form corrections in both Chinese catalogues,
while adopting the new translations; all 42 catalogues validate. The final
SimpleUI pin includes this follow-up. Runtime code is unchanged by it.

Compatibility commit `48778414` contains the profile change and seven new
integration cases. The native favourite test's source locator is adjusted to
find the real cover constructor despite OrbitUI's series-box branch; all
favourite-placement assertions remain. Update the existing version/Reading
label assertions to match upstream; do not add failure/skip allowances.

Validation: complete sequential Lua and LuaJIT runs both pass 522 OrbitUI
cases across 44 files, 382 Bookshelf suites (zero failures, two existing native
SQLite suite skips), all 13 SimpleUI files and 91 Python tests (four existing
external artwork-source audit skips). Two native-font case skips and absent
adjacent Bookends parity checkout remain. All 42 translation catalogues, 278
module paths and 791 Lua syntax checks pass. No skip or known-failure allowance
was added. Read-only upstream collection at 08:43 UTC reports zero missing
commits for both tracked branches.

Clean-commit candidate `67436938` passes sealed ZIP validation: 1687 manifest
files and 1740 archive entries, with modules, assets, licenses and recovery docs
verified. Its unpublished alpha.37 development ZIP has SHA-256
`556c40da370786e155d41fe799942ac5badcd97e0b6ebfb54148235474862006`.
It must never replace the published alpha.37 artifact. Both reviewed upstream
tips are ancestors; bootstrap/API, VERSION, shared core/adapters and artwork
are unchanged from the starting tip. Fast-forward the reviewed maintenance
branch into local main after recording these results.

Physical Bigme checks remain: Auto/List on both levels, different row/column
counts in Library and Manga, pinch then back/restart, and favourite heart/star
with read marks and above/below labels in day/night mode. No device test or
measured performance improvement is claimed. Keep the prior installation and
settings backup. No push, version bump, tag, release or OTA publication.

## 2026-10-12: Prepare alpha.38 for explicit publication

User request: "Publicera" after the tested follow-up merge recorded at
`f72ba3cf`. Prepare alpha.38 as a prerelease without further upstream changes.
Keep Bookshelf `2c8bfd8e` / 5.4.4 and SimpleUI `5bddc5bb` / 2.7.5 pinned.
Only VERSION and release documentation change. Stable bootstrap/API 1,
artwork, settings and reading data remain unchanged. The native series-box
PR #508 is not part of this release; OrbitUI's adapter remains the owner.

Release gates: sequential full Lua/LuaJIT tests, translations, clean-commit
sealed packaging, outgoing-history/runtime held-bitmap audit, native OTA
upgrade/rollback using the published alpha.37 installer, downloaded draft-asset
checksums, CI and anonymous live release/OTA verification. Do not overwrite any
existing release's assets. Device acceptance remains open for the cases above;
no measured performance improvement is claimed. Keep the prior installation
and settings backup, including the pre-alpha.33 theme-migration rollback caveat.

## 2026-10-14: Reviewed tracked-branch merge, series-box PR deferred

User: "Da avvaktar vi med det sa lange. Merga upstream igen."
Start from clean published alpha.38 main
`0154a5586eb8dab4dd3f5835dd4fca8dbde1a1b5`, on
`maintenance/upstream-2026-10-14`. Freeze and review these exact targets:

- Bookshelf master: `2c8bfd8e53b73b24232e674e12ebc6168963aef5` ->
  `aeada050f90921b748dcef0ae2f88367bd0e1b69`, 12 commits / 19 changed files.
  Unsquashed subtree import `4a9acfa6`.
- SimpleUI main: `5bddc5bb7858c2e75a1047b5adfc9c9bbc8e2f1f` ->
  `84a9c0e96152c81c9879b484840ad4cd22ab1580`, 16 commits / 84 changed files.
  Unsquashed subtree import `34c09970`.

The read-only watcher captured the targets at 18:43 UTC. Upstream metadata
still says 5.4.4 and 2.7.5 respectively. Bookshelf PR #508 was merged into
`feat/series-boxes` (merge `3a8b2e2a5d6ef7341de10a01197cc84c78490cbc`),
not tracked master. Per the user's deferral, do not import that branch or
replace OrbitUI's series-box adapter. Original fork provenance is unchanged.

Bookshelf adds Favourite first sorting, plugin-registered document formats
(excluding images), format-aware walk caches, extraction guards for formats
that may need network access, and OPDS-PSE stream/resume plus an optional record
action API. Keep the keyed multi-root snapshots, cancellable validation and
post-invalidation generation capture. Skip SimpleUI's shared core-format index
when plugin formats are registered. Scope the extension helpers to avoid the
LuaJIT 200-local limit exposed by the first syntax run; no format is dropped.

SimpleUI adds a persistent finished-book ledger, manual-book/goal controls,
Stats menu, finished visibility modes, per-view series grouping, smarter folder
cover planning, opt-in Flow carousel, shared backdrop/shadow rendering, extracted
ScreenWidget methods and Dutch translations. Resolve individual conflicts across
27 files rather than applying a blanket side. Keep fresh label widgets and
per-module scaling/prefixes, independent Bento gaps, local icon fonts and Classic
titlebar defaults, BookOrbit carousel sources/index callbacks, warm/docked
navigation and refresh token/instance guards. Stats updates still target mounted
content, not decorators, and book modules are not updated twice. The shared
shadow retains collision-free keys and legacy clear/badge APIs. Preserve wallpaper
aliases and zero default backdrop strengths. Unloading uses reset-aware eviction.

Separate compatibility work preserves old fade/grouping/deleted-book/manual-count
keys and explicit flat-library visibility. Migrations v10/v11 honor embedded
deferral and do not overwrite explicit per-view choices. Manual-count migration
is marked inside the ledger so retained legacy values cannot resurrect removed
entries. Finished-file-filter teardown disables its owned gate without erasing
later patch wrappers. Ledger reconciliation is transactional and retryable on
sidecar/stat errors; incomplete counts cannot erase stored totals. Missing/locked
DBs retry even for full stats, without persisting zero activity. No read-only
sidecar probe flushes metadata. No additional BookOrbit/Hardcover writer.

Affected contracts C01-C08 and C10-C11 remain intact; C09 forbids publication
without a separate request. Module map grows from 278 to 289 paths. Update
fixtures for relocated renderers and new directory-cover plans while retaining
behavioral assertions. Keep single-form plural repairs in ja/ko/vi/zh catalogues;
all 43 catalogues validate without new baseline exceptions. The new focused
suite covers real migrations, ledger retry/rollback, wrapper ownership, shared
walk guards, perspective geometry and guarded grayscale/RGB framebuffer writes
under LuaJIT. Full-suite and package validation results follow below.

Validation: complete sequential Lua and LuaJIT runs pass 534 / 535 OrbitUI
cases across 45 files (the extra case exercises actual FFI buffers), 385
Bookshelf suites (zero failures, two existing SQLite suite skips), all 13
SimpleUI files and 91 Python checks (four existing external-artwork audit
skips). Two native-font case skips and the absent adjacent Bookends parity
checkout remain. All 43 catalogues, 289 module paths and 806 Lua syntax checks
pass. No skip or known-failure allowance was added. Read-only collection at
19:02 UTC reports zero missing commits for both tracked branches.

Compatibility commit `05e49ac3` passes clean-source sealed packaging: 1700
manifest files and 1753 archive entries, including all new module paths,
assets, licenses and recovery documentation. The unpublished development ZIP
(still labelled alpha.38) has SHA-256
`fe8a350caa9089f21f372710b6f910c65025bf59657927deca091d02b7c30aa5`.
Never replace the published alpha.38 assets with this development build. The
previous local archive/checksum is preserved under ignored test-results.
Both reviewed upstream tips are ancestors; VERSION, bootstrap/API, adapters
and artwork are unchanged from the starting tip. Fast-forward local main to
the reviewed branch after recording this result; do not push it in this task.

Device checks still required: finished/manual totals through restart and
BookOrbit status edits; hide/show/fade and external file filters; per-view groups;
Flow carousel swipes/zoom/close with colour/night-mode covers; Home clock,
Bento, custom icons, module labels and dock reflow; Favourite first sorting;
optional plugin formats and OPDS-PSE resume with the relevant plugins installed.
No Bigme test or measured speedup is claimed. Keep installation/settings backup:
old keys survive rollback, but new ledger edits are not mirrored to older code.
VERSION, bootstrap/API and artwork are unchanged. No push, tag, release or OTA
publication is part of this task; the held Mann bitmap remains excluded.

## 2026-10-14: Prepare alpha.39 for explicit publication

User request: "Publicera" after the tested merge at `50c04c57`. Prepare a new
alpha.39 prerelease without further upstream imports. Retain Bookshelf
`aeada050` and SimpleUI `84a9c0e9`; PR #508 remains deferred. VERSION and
release documentation change, not runtime logic, bootstrap/API or artwork.
The held Mann bitmap and any history containing it must remain unpublished.

Release gates: full Lua and LuaJIT suites sequentially, translations, sealed
clean-commit packaging, outgoing-history/runtime held-bitmap audit, upgrade and
rollback using the published alpha.38 installer, downloaded draft-asset hash
verification, both CI jobs, and anonymous public discovery/download through
the old installer's OTA path. Never replace an existing release's assets.
Physical Bigme acceptance remains open as documented above. Keep installation
and settings backups: new ledger edits are not mirrored to older code, and
pre-alpha.33 upgrades retain their theme-storage migration caveat.

## 2026-10-16: Reviewed SimpleUI upstream merge

User request: "Merga upstream". Start from clean published alpha.39 main
`a6c399a25db93c0e68daad379ae769808f12e1e0` on
`maintenance/upstream-2026-10-16`. Reviewed exact SimpleUI main
`84a9c0e96152c81c9879b484840ad4cd22ab1580` ->
`36e7430f6379693266d1082ae0b9d88de62cb877`: five commits, 91 changed files.
Unsquashed subtree import `b02528bb`, with individual conflict resolutions in
26 files. Separate adaptations preserve OrbitUI's contracts. Bookshelf master
is already current at `aeada050f90921b748dcef0ae2f88367bd0e1b69`; no new import.
Versions remain upstream 2.7.5 / 5.4.4. PR #508 remains explicitly deferred.

Relevant upstream additions are an optional Tabbed Grid Home/custom-screen
module, optional Reader Book quick-settings layout, draggable sliders, shared
book sources/group cells, centralized book statistics, LRU/memory/menu hooks,
and updated Chinese translations. Import the architecture rather than retaining
duplicate old implementations, but preserve the existing source/UI defaults.

Semantic decisions: keep hidden Recent filtering/restore, bounded root/revision
New Books ranking and BookOrbit file-dialog actions/source isolation. Preserve
per-prefix label sizing, independent Bento gaps, custom icons, Classic menus,
detailed Currently Reading stats, left-aligned descriptions, metadata retry
guards, 300-second no-cover expiry and the raster count/byte caps. Copy old
Currently Reading ordering into unset main/stat orders, keep old settings, and
place the new stats group at the first old statistic position. Explicit new
orders win. New Tabbed Grid and Reader Book layouts do not activate themselves.
The shared menu hooks retain multi-host ownership and later patch wrappers.
Reset cancels GC work rescheduled by cache clears; scratch-buffer failures
cannot leave freed buffers or poison the nesting depth. No new sync writer.

C01-C08/C10 remain preserved; Bookshelf/ornaments/series-box behavior (C11) is
unchanged. C09 still requires separate publication approval. Source provenance
is unchanged, SimpleUI's integrated pin advances, and the generated map adds
17 module paths (289 -> 306). Tests follow moved functions/real new cache helpers
without deleting behavioral assertions. The new 12-case integration file covers
cache ownership/failure recovery, menu hooks, source filtering/ranking, per-tab
settings and selection/height/empty states, stats-order migration and defaults.
Correct Chinese single-plural entries without changing validation exceptions.

Validation: full sequential Lua / LuaJIT suites pass 546 / 547 OrbitUI cases
across 46 files, 385 Bookshelf suites (zero failures, two existing native SQLite
suite skips), all 13 SimpleUI files and 91 Python checks (four existing external
artwork-source skips). Two native-font case skips and the absent adjacent
Bookends parity checkout remain. All 43 catalogues, 306 module paths and 824
Lua syntax checks pass. No new skip or known-failure allowance. Read-only
collection at 19:22 UTC reports zero missing commits on both tracked branches.
Compatibility commit `0066a6c4` passes sealed clean-source packaging: 1718
manifest files and 1771 archive entries, all 306 mapped modules present.
All manifest sizes/hashes and bootstrap/API 1 are verified; the held bitmap
is absent. The unpublished development ZIP, still labelled alpha.39, has SHA-256
`47931e9c3d4e516938fe7426852311402b74b668316a31c83e867c68ddf372a0`.
Never replace the published alpha.39 assets with this development build.
The previous local ZIP/checksum is preserved in ignored
`test-results/upstream-20261016/previous-dist/`. Both reviewed upstream tips
are ancestors. This result-recording commit changes documentation only;
fast-forward local main after recording it, without pushing.

Physical Bigme checks remain: optional Tabbed Grid paging/tab switches, empty
and group sources in Bento/custom screens; existing hidden Recent/BookOrbit
sources; optional Reader Book panel, sliders and stats; colour/night-mode text,
custom icons and patch toggles; Home/Library/Manga navigation and memory across
repeated reader returns. No device acceptance or measured speedup is claimed.
Keep installation/settings backups. Old preference keys survive rollback, but
new grouped-order edits and new module settings are not reflected in old code.
VERSION, bootstrap/API, adapters and artwork are unchanged. No push, version
bump, tag, release or OTA publication is part of this merge.

## 2026-10-16: Reviewed Bookshelf 5.5 merge

User request: merge the newly released Bookshelf 5.5. Start from
clean local main `e3442fd3`, including the earlier unpublished SimpleUI merge,
on `maintenance/bookshelf-5.5-2026-10-16`. Read-only collection at 20:58 UTC
froze Bookshelf master `048ab4bad8993ebc713800d884fc485e54753343`, advancing
from `aeada050f90921b748dcef0ae2f88367bd0e1b69`: 75 commits, 88 upstream files.
This includes `v5.5.0` (`a0224c75a43ced03c013c0a98cf3daa1089d60ee`), published
19:51 UTC, and its README follow-up. SimpleUI remains at reviewed
`36e7430f6379693266d1082ae0b9d88de62cb877`, with no new commits to import.
Unsquashed subtree merge `c6387e77` resolves 12 conflicts individually;
adaptations and regenerated module map are separate from that import.

PR #508 is no longer an unmerged feature branch: its series boxes are part
of this explicitly requested 5.5 master release. Import the native code and
tests, but retain OrbitUI's series-box owner, approved coloured slipcase design,
completion/fade/count badges, member scope and physical labels. The adapter
disables the native preparation pass and the editor hides its redundant switch,
without deleting any stored native choice. Widgets and shadow geometry dispatch
by box identity; standalone Bookshelf still uses the new native implementation.
Profile scope and all-face-out behavior survive the overlapping navigation
changes. Existing ornament/session-deck rules and dock reserves stay intact.

Other imported features: explicit author-photo lookup via Open Library/Wikipedia,
aspect-preserving author cards, page/percentage/printed-count badges, Added or
opened sorting, Recently read micro-module, token/placeholder registration,
temporary nil-count plural guard, page-scan memory limits/crash quarantine,
source-change cache invalidation and offline-aware micro-modules. Keep both
image-library roots and both author-name orders. Photo installation renames the
new file before deleting other extensions, protecting prior images on failure.
Hardcover re-linking preserves enrichment choices from either link store.
The merged redirect tests retain cross-origin credential isolation and add the
same-host default-port HTTP-to-HTTPS exception and response-memory caps.

Compatibility checks found the combined repository exceeding LuaJIT's 200-local
limit: scope the new printed-page constants without changing the API. Infer
reading status for positive unclassified progress, but preserve OrbitUI's
unopened interpretation of imported zero-progress sidecars; explicit reading
at zero stays reading. Native test fixtures now supply existing profile/layout
seams instead of removing assertions. The root runner explicitly enables the
seven slow filesystem/theme suites newly skipped by upstream's default runner.
No new skip/failure allowance. Module map grows from 306 to 315 paths.

C01-C11 remain intact, with the native/embedded box boundary clarified in C07
and image/quarantine preservation documented in C08. VERSION stays alpha.39;
bootstrap/API, artwork and original source provenance are unchanged. This is a
local merge only: no push, version bump, tag, release or OTA change is authorized.

Adaptation candidate `d65badec` passes complete sequential Lua / LuaJIT gates:
548 / 549 OrbitUI cases across 46 files, 394 Bookshelf suites (zero failures,
two existing SQLite suite skips), all 13 SimpleUI files and 91 Python checks
(four existing artwork-source audit skips). Existing native-font case skips
and absent adjacent Bookends parity checkout remain. All 43 translation
catalogues, 315 module paths and 842 LuaJIT syntax checks pass. No new skip or
failure allowance; slow filesystem/theme tests run in both full gates.

Clean-candidate packaging at `d65badec` verifies 1727 manifest files / 1780 ZIP
entries, every file size/hash, exact upstream pins, bootstrap/API 1 and held
bitmap exclusion. ZIP SHA-256:
`19f3d511601e62e704d78a1db53960b12345e6f8aa47c059420092b18c938358`.
The previous local development archive/checksum is retained under ignored
`test-results/bookshelf-5.5-20261016/previous-dist/`; validation logs are in the
parent directory. The new archive still identifies as alpha.39 for local
development only: it must not replace the published alpha.39 asset. Final
result recording is documentation-only; local main is fast-forwarded without
any remote push or publication.

Physical Bigme checks remain: author-photo
single/bulk lookup, Stop/offline/restart, both image-library locations; page and
percentage badges in colour/night mode; same-origin/upgrade OPDS access; page
scan cancellation/quarantine; nested-chip refresh, captions, dock and existing
series-box completion/ornaments. No device acceptance or speedup is claimed.
Keep installation/settings backups; old keys survive rollback, but new 5.5
preferences and downloaded author photos are not backported to older code.

## 2026-10-16: User-approved upstream series-box design trial

User request: preserve the existing OrbitUI box design on a branch and use
AndyHazz's design for testing. Before edits, save clean main `1ae66bd0` as
local `design/orbitui-series-boxes`. That branch retains the old adapter, two
core box modules and all 30 original regression cases. No remote branch is
created or pushed. Main now uses the already reviewed Bookshelf 5.5 renderer;
component source and upstream pins are unchanged by this trial.

C07 deliberately changes the box appearance: native open-topped slipcase,
up to eight exposed member spines, first-cover sticker, printed name/read-total
and individual spine status marks. The old perspective shape, separate badge
and whole-box finished mark/fade are not applied. Lone volumes remain books.
No reading state or display preference is erased. All ordinary books still
face out; per-chip sizing/text, ornaments and dock are unchanged.

The smaller adapter retains all-series enablement in prose/comics and ordinary
physical shelves, suppresses redundant section labels inside series, and makes
letter jumps use native preparation. Profile IDs cannot inherit an unrelated
native single-series tab. Native fetching/counting/planning/restoration replace
the old parallel paths. Read legacy `orbitui_series_files` on a copy; save both
it and `series_box_files` for identifier-only scoped rollback. Native rendering
is not monkey-patched. Package validation requires the native modules instead
of the retired core modules. Fifteen replacement host tests cover these seams,
live completion/reversal and bounded day/night drawing; native box/status
suites cover the upstream implementation. The retired tests stay with their
renderer, rather than being skipped or weakened on main.

Trial implementation `2368cd46` passes complete sequential Lua / LuaJIT runs:
533 / 534 OrbitUI cases across 46 files, 394 Bookshelf suites (zero failures,
two existing SQLite suite skips), all 13 SimpleUI files and 91 Python checks
(four existing artwork-source audit skips). Native-font case skips and absent
adjacent Bookends parity checkout remain. All 43 catalogues, 315 module paths
and 840 LuaJIT syntax checks pass. The host case count is 15 lower because 30
archived renderer cases are replaced by 15 native-integration cases; no new
skip or failure allowance is added. All native box/status suites still run.

Clean-candidate packaging at `2368cd46` verifies 1725 manifest files / 1778 ZIP
entries. Additional archive inspection verifies every size/hash, bootstrap
API 1, native modules present, both retired core modules absent and held-bitmap
exclusion. SHA-256:
`781b5621d4931c94d428db4a8cc2b49463bb3313bbabe0bb71792a85a265098e`.
Validation logs and the previous local ZIP/checksum are retained under ignored
`test-results/upstream-boxes-20261016/`. VERSION remains alpha.39; this is a
local development ZIP, not a replacement for the public alpha.39 release.
Final validation recording is documentation-only.

Device acceptance remains pending: compare two/large-volume boxes,
change the last volume's read status, restart inside a scoped series, letter
jump/back/page, cover sizing, colour/night mode and ornament/dock clearance.
Keep installation/settings backups. To restore the old design after later
work lands, revert this trial's changes rather than rolling back unrelated
upstream merges to the snapshot branch. No version bump, release or OTA change
is requested or performed.

## 2026-10-16: Prepare alpha.40 for explicit publication

User request: "Publicera" after upstream series-box trial `2368cd46` and result
recording `0a8a410c`. Publish a new prerelease with both reviewed October 16
merges and the native slipcase trial. Keep the old design on local branch
`design/orbitui-series-boxes`; do not publish that branch or new upstream
changes. Pins remain Bookshelf `048ab4ba` and SimpleUI `36e7430f`. The version
and documentation change, not runtime code, bootstrap/API or artwork.

Fresh origin/release inspection confirms alpha.39 is the latest published
release and main remains a fast-forward. Initial outgoing-history audit covers
815 objects / 462 blobs (60,952,291 blob bytes); the held bitmap is absent.
Repeat the audit for the final release commit and sealed runtime. Release
gates: full sequential Lua/LuaJIT runs, translations, clean packaging, actual
published alpha.39 installer upgrade/rollback and corrupt-download rejection,
both CI jobs, downloaded draft-asset hash verification, then anonymous live
discovery/download. Device gaps and rollback limitations remain as documented
above. Explicit publication approval does not establish physical acceptance.

Versioned-tree gates pass sequentially: Lua / LuaJIT 533 / 534 OrbitUI cases
across 46 files, 394 Bookshelf suites (zero failures, two existing SQLite suite
skips), all 13 SimpleUI files and 91 Python checks (four existing external
artwork-source audit skips). Native-font skips and absent Bookends parity
checkout remain. All seven slow suites run; all 43 catalogues, 315 module paths
and 840 LuaJIT syntax checks pass. No new skip/failure allowance. The published
alpha.39 runtime and checksum are downloaded and match their GitHub asset
digests, ready for upgrade/rollback testing after clean release packaging.

## 2026-10-17: Preserve cover proportions on upstream slipcases

User request: "Testa detta" after accepting the upstream perspective but
reporting distorted covers on small/large collections. Start from published
alpha.40 `a66719ff`. Keep the native box, spines, completion marks, grouping,
navigation and maximum width; opt into a 70% minimum width and an aspect-true
centered cover sticker. The count moves to the board above the picture and
shrinks to fit; names stay centered on the entire board. Unused picture area
retains the existing board colour. Crop only the native cover tile border and
copy at final resolution, without the old second anisotropic scale.

The `orbitui_ui` wrapper enables the optional `preserve_cover_aspect` policy
and the existing geometry constant. Native standalone defaults are unchanged;
no duplicate renderer or settings migration is added. Scratch buffers are
freed on success and failure. C07 is deliberately refined; upstream pins,
VERSION, bootstrap/API, artwork and reading state are unchanged. The archived
old-design branch remains intact. No publication is requested.

Eight added host tests cover opt-in/standalone boundaries, width limits,
portrait/square/landscape aspect and centered fitting, read-count/name
separation, fallback metadata, large counts at small sizes, scaled borders
and cleanup/retry after cover-paint failure. The original live completion,
night-mode, scoped navigation and gesture cases remain. Complete sequential
Lua / LuaJIT runs pass 541 / 542 OrbitUI cases across 46 files, 394 Bookshelf
suites (zero failures, two existing SQLite skips), all 13 SimpleUI files and
91 Python checks (four existing external artwork-source audit skips). Existing
native-font skips and absent Bookends parity checkout remain. All seven slow
suites run; all 43 translation catalogues, 315 module paths and 840 LuaJIT
syntax checks pass. No new skip or failure allowance. Device appearance still
needs Bigme testing, especially
two-volume and long-series boxes at cover-size extremes in colour/night mode.

Clean candidate `d1b1f74f8ece65064bb8fcece8e152368fe8ec57` is sealed and
validated: 1726 manifest files / 1779 entries, 54,286,450 ZIP bytes and
71,067,945 inventoried bytes. SHA-256:
`40a6391a0f89d69f1dfe119b05c270b627b8f0c2afb0e999848169cd990a67b1`.
Every inventory size/hash matches. Bootstrap/API, VERSION and sources.json
match public alpha.40; the old core renderer and held bitmap are absent.
The preview must not replace the existing public alpha.40 assets. Original
release bytes and validation logs are retained in ignored
`test-results/box-aspect-20261017/`. No push, tag, release or OTA update is made.
The old-design branch still points to `1ae66bd09a1e8b609974a3b1e58d5ab46cba6183`.

## 2026-10-17: Prepare alpha.41 for explicit publication

User request: "Publicera" after the aspect-preserving slipcase implementation
`d1b1f74f` and verification record `8c0e95b6`. Origin/main and the latest public
prerelease remain alpha.40 at `a66719ff`; publish a new version, never replace
its assets. No additional runtime changes or upstream imports are included.
Bookshelf remains at `048ab4ba`, SimpleUI at `36e7430f`; artwork and the stable
bootstrap/API 1 remain unchanged. The old-design branch remains local.

Publication gates: complete sequential Lua/LuaJIT runs on the versioned tree,
translations, a sealed clean-commit package, actual published alpha.40 installer
upgrade/rollback and corrupt-download rejection, outgoing-history/runtime held
artwork audit, both CI jobs, downloaded draft hashes, then anonymous live OTA
discovery/download. Physical Bigme acceptance and performance are not established
by these checks. Earlier rollback limitations and install/settings backups apply.

Versioned-tree gates pass sequentially: Lua / LuaJIT 541 / 542 OrbitUI cases
across 46 files, 394 Bookshelf suites (zero failures, two existing SQLite suite
skips), all 13 SimpleUI files and 91 Python checks (four existing external
artwork-source audit skips). Native-font skips and absent Bookends parity
checkout remain. All seven slow suites run; all 43 translation catalogues,
315 module paths and 840 LuaJIT syntax checks pass. No new skip/failure allowance.
The actual published alpha.40 ZIP and checksum have been downloaded and verified
against their checksums and GitHub asset digests for upgrade/rollback testing.
The initial outgoing-history audit covers 21 objects / 10 blobs / 527,281 blob
bytes and excludes the held bitmap; repeat after the release commit.

## 2026-10-17: Reviewed Bookshelf 5.5.2 and SimpleUI surface merge

User request: "Merga upstream och sammanfatta ändringarna". Start from clean
published alpha.41 `a33eda9cbbdcc8cdee6ed7758069934d640c84ce` on a dedicated
`maintenance/upstream-2026-10-17` branch. Review both tracked branches, not
unmerged feature branches; no publication or version bump is requested.

- Bookshelf master: `048ab4bad8993ebc713800d884fc485e54753343` to
  `c7a9db2ca1c21ef6a38715e74306fe7f514ba807` (eight commits; release 5.5.2),
  unsquashed subtree import `f0b2862d`.
- SimpleUI main: `36e7430f6379693266d1082ae0b9d88de62cb877` to
  `7eb80f9e570e6351c55f501f91e1a29c1442b756` (two commits; still 2.7.5),
  unsquashed subtree import `3ee64740`.

Review includes complete commit lists/net runtime diffs, release metadata,
removed APIs, settings migrations, dependencies and UIManager hooks. Preserve
original fork provenance in sources.json and advance only integrated pins.
The generated map adds `infra/sui_text`.

C07: custom series images now reach the slipcase. Preserve alpha.41's actual
aspect, minimum-width policy, count band and native design. Read actual decoded
dimensions, retain cache ownership, and fall back/retry on missing or unreadable
art. Free owned scratch even on blit failure. Random Book adds explicit direct
opening while retaining preview as default (C03). Include the native software
wallpaper overlay fallback and its tests; no hardware-performance claim.

C02/C06: keep Home under its own main menu and retain the displaced custom
screen for temporary fullscreens. Add a narrow optional destination seam so
Bookshelf/Home/Reader do not inherit a Home-return marker. A generation check
invalidates delayed restores after navigation. Retain legacy bottom-bar and
wallpaper APIs used by the embedded dock and existing patches.

C08: import the new surface model, white/gray tones, frame controls and
Full-width/Floating navbar layout. Preserve transparent titlebar/pagination/
cover-strip/module defaults, separate titlebar-button opacity and legacy
quick-setting button transparency. Keep opacity editable. Migrate by copying
only into unset fields; do not erase old look/style/transparent keys. Preserve
legacy and new fields in presets/backups. C01/C04/C05/C10/C11 ownership, cache,
BookOrbit and ornament contracts are unchanged.

Textual conflicts were resolved individually in the box painter, wallpaper/
backdrop/navbar compatibility, backup/presets and i18n. Keep lazy native gettext
and Swedish fork strings. Single-form Japanese/Korean/Vietnamese catalogue
conflicts keep one plural entry, with no new exceptions. Update test fixtures
for real `sui_text`/KOReader `util.trim` and the new resolved-surface API;
do not stub away the native bottom-bar separator API. No assets are replaced.

Adaptation candidate `157ecc2102bf9dec2f245367e0186ddd262e7f8e` passes complete
sequential Lua / LuaJIT gates: 553 / 554 OrbitUI cases across 47 files, 395
Bookshelf suites (zero failures, two existing SQLite suite skips), all 13
SimpleUI files and 91 Python checks (four existing artwork-source audit skips).
Existing native-font skips and absent adjacent Bookends parity checkout remain.
All seven slow suites run; all 43 translation catalogues, 316 module paths and
843 LuaJIT syntax checks pass. No new skip or failure allowance. The final Lua
rerun also includes the last preset-field compatibility change.

The same clean candidate passes sealed package validation: 1728 inventoried
files / 1781 ZIP entries, 54,302,981 ZIP bytes and 71,119,849 inventoried bytes.
Every file size/hash, exact source pins and imported ancestry are verified.
Bootstrap/API 1 and VERSION are byte-identical to public alpha.41. The old core
box renderer and held Mann bitmap are absent. SHA-256:
`968e211ca946174a109d8fb349b2c5976cc42fe24cfeca85037291d7a675ae42`.
Use the native-size image loader before fitting custom art: the ordinary loader
stretches to the requested rectangle, so a later fit cannot recover its shape.
Regression tests distinguish both APIs. Presets also retain the new cover-strip
tone/frame choices alongside the old opacity and titlebar-button fields.

Physical Bigme checks in TESTING.md remain outstanding. The old renderer archive
branch remains at `1ae66bd09a1e8b609974a3b1e58d5ab46cba6183`. Logs/audits and
the unchanged alpha.41 public ZIP are retained in `test-results/upstream-20261017/`.
This local preview must not replace the public release assets. Final verification
recording is documentation-only; fast-forward local main after recording it.
No push, tag, release, version bump or OTA update is performed.

## 2026-10-17: Prepare alpha.42 for explicit publication

User request: "Publicera" after reviewed imports/adaptations `157ecc21` and
verification record `0bfa9f24`. Origin/main and the latest public release remain
alpha.41 at `a33eda9c`. Publish the reviewed merge as a new prerelease; do not
replace old release assets or include new upstream changes. Pins stay Bookshelf
`c7a9db2c` and SimpleUI `7eb80f9e`. Only VERSION and release documentation change;
stable bootstrap/API 1, runtime code and artwork are unchanged from the merge.
The archived old box design remains local and untouched.

Gates: complete sequential Lua/LuaJIT runs on the versioned tree, translations,
clean sealed packaging, outgoing-history/runtime held-artwork audit, real public
alpha.41 installer upgrade/rollback and corrupt-download rejection, both CI jobs,
downloaded draft-byte checks and anonymous live discovery/download/install.
The existing device-acceptance gaps and settings-backup caveats remain.

## 2026-10-17: Fix light-member box covers and bound image-picker work

User report on public alpha.42: Manga series boxes show placeholders, and
"Set series image" stays unresponsive until KOReader is force-closed.
This is a local follow-up, not another upstream import. Source pins, VERSION,
stable bootstrap/API, artwork, profiles and stored image choices are unchanged.

The slipcase hydrated a private copy of its first member for its colour/aspect,
but gave the original light member to SpineWidget. That record lacks has_cover,
so the actual cover-selection gate renders the placeholder even when a cover
exists. Reuse the hydrated, buffer-free copy for the image and subsequent
fallback resizing. Regression test fails on the original code.

Use a small shared Bookshelf image-picker helper for series/author/group,
folder and book image actions: validate the initial directory, fall back to
an existing home/cwd, use filename sorting and plain entries, and avoid
inherited book-status filtering and eager subfolder counts. Do not create an
image-library directory or rewrite settings just to open the chooser. SimpleUI
series grouping now leaves PathChooser choices alone instead of querying them
as books. The module map includes the new helper. Contracts C02/C04/C07 remain;
native navigation, long-press confirmation and existing save callbacks remain.

The device hang itself still needs confirmation after updating: no device log
was available, so eliminated synchronous work is a concrete risk correction,
not proof of the only cause of the reported lock-up. Test evidence is retained
under test-results/series-image-fix-20261017/. No publication is requested in
this turn; do not replace alpha.42's public assets.

Full sequential Lua/LuaJIT gates pass 561/562 root cases in 48 files,
395 Bookshelf suites, all 13 SimpleUI files and 91 Python checks, with the
same existing SQLite/native-font/external-artwork/Bookends-checkout skips.
All 43 translation catalogues, 317 module paths and 845 syntax files pass.
Real KOReader FileChooser/PathChooser methods with a simulated 500-folder
filesystem reduce initial directory scans from 501 to 1 and preserve native
selection/confirmation/close. This is not a physical Bigme timing measurement.

## 2026-10-17: Larger slipcase artwork and shelf/series book bindings

User approved increasing cover area without skewing proportions, and requested
modern pocket/manga spine choices per shelf and per series. Interpret the manga
format as tankobon. This is a local C07 presentation change, not an upstream
merge or publication. Keep VERSION alpha.42, exact source pins, bootstrap/API,
artwork and the archived box-design branch unchanged. Preserve unpublished
`b3849c5d` (light cover metadata and bounded image picker).

Raise only the host minimum width from 70% to 85% of the existing cover cap.
Compact the exposed heads, retaining paper tops, and move the full read/total
there instead of reserving a separate band inside the front. Suppress member
glyphs in the compact head to prevent overlaps; the aggregate remains complete.
The whole cover, including custom art, is still fitted without anisotropic
scaling or image-pixel cropping. Name and count stay outside the picture.

New OrbitUI-owned Book binding menus on chip hold and series hold offer
Hardcover, Paperback and Manga/tankobon; series overrides win across shelves,
and Follow shelf clears just that override. Qualified profile shelf identities
cannot collide with each other or native tabs. Persist only presentation
choices, copy-on-write, in `orbitui_book_bindings`; no status/metadata/cache
files or existing preferences are rewritten. Hardcovers remain the default.
The native renderer gets small optional resolver/skin seams: flush thin covers,
subtler paper lines, flatter spine shading, and a pale manga jacket with dark
text. Share the skin with rotated/CJK text backgrounds and opening poses.
Keep natural aspect, page-count thickness, sizing and pagination geometry.

The runtime loader previously returned after the first matching adapter;
the spine shelf already belonged to the ornament adapter. Compose all matching
adapters in fixed icon/ornament/UI order after one module load, preserving
userpatch preload priority. A real-loader regression test verifies both hooks.
The older face-out fixture now supplies the settings/tab services used by the
binding resolver; no test is skipped. Tests/logs and physical acceptance gaps
are recorded in TESTING.md. No push, tag, version bump or OTA publication.

Both complete suites pass sequentially: Lua 575 and LuaJIT 576 root cases in
49 files, 395 Bookshelf suites, all 13 SimpleUI files, 91 Python checks, 43
translation catalogues, 317 module paths and 847 syntax files. Existing
SQLite/native-font/external-source/Bookends-checkout skips remain unchanged.
The sealed preview and its audit are local only; do not replace public
alpha.42 assets. Physical-device acceptance remains outstanding.

## 2026-10-17: Prepare alpha.43 for explicit publication

User request: "Publicera" after the light-member cover/image-picker fix
`b3849c5d` and larger slipcase/scoped binding work `5104eff4`. Fresh origin/main
and the latest public release are alpha.42 at `dcb01c50`. Publish both reviewed
commits as a new prerelease, not replacement alpha.42 assets. No additional
upstream import is requested: pins stay Bookshelf `c7a9db2c` and SimpleUI
`7eb80f9e`. This step changes only VERSION and release documentation.
Stable bootstrap/API 1 and artwork remain unchanged. The archived old box
design and held-artwork history stay local and untouched.

Gates: complete sequential Lua/LuaJIT runs, translations, clean sealed package,
outgoing-history/runtime held-artwork audits, real published alpha.42 installer
upgrade/rollback and corrupt-download rejection, both CI jobs, downloaded draft
hashes and anonymous live discovery/download/installation. Device rendering,
binding appearance and the reported chooser hang still require confirmation.

## 2026-10-17: Consistent member thickness and partially filled boxes

User approved the partial-fill proposal with "Kör!" after testing alpha.43.
Start at public `c9a163ff`; this is a local C07 presentation change, not a
merge or publication. VERSION remains alpha.43 and upstream pins remain
Bookshelf `c7a9db2c` / SimpleUI `7eb80f9e`. Bootstrap/API, assets, existing
preferences, reading data and the archived design branch are unchanged.

Keep the larger aspect-true cover and outer width bounds, but stop scaling
all member widths to fill the interior. The host's two small geometry hooks
use the native page-width curve, common row/DPI/shelf-thickness calibration,
and reliable print or fixed-layout counts. Unknown/reflowable render counts
use a neutral fallback. A read-only cached-page seam avoids sidecar scans and
status-mtime invalidation affecting width. Pack a whole left-aligned prefix,
up to eight members, without squeezing, clipping or skipping ahead. Shade the
remaining low interior and adapt its shadow; show `+N` for undrawn members
beside the complete read/total. Membership, order and opening remain unchanged.
Standalone Bookshelf retains its old policy without host hooks.

Tests cover geometry, count provenance, invalid values, different series
lengths, DPI/row/thickness settings, very narrow boxes, status independence,
binding inheritance, colour/night drawing, shadows and count-label separation.
Full gates and remaining device checks are recorded in TESTING.md; evidence
is in `test-results/series-box-fill-20261017/`. No push, tag or release.
Any sealed alpha.43 preview is local only and must not replace public assets.

## 2026-10-17: Prepare alpha.44 for explicit publication

User request: "Publicera" after partial series-box fill `e1ce48bb` and
confirmation of Swedish/English binding-label fallback. Fresh origin/main
and the latest public release are alpha.43 at `c9a163ff`. Publish the reviewed
change as a new prerelease, never replace alpha.43 assets. This step changes
only VERSION and release documentation. Bookshelf `c7a9db2c`, SimpleUI
`7eb80f9e`, bootstrap/API 1, artwork and the archived design remain unchanged.

Gates: complete sequential Lua/LuaJIT runs, translations, clean sealed package,
outgoing-history/runtime held-artwork audits, published alpha.43 installer
upgrade/rollback and corrupt-download rejection, both CI jobs, downloaded draft
hashes and anonymous live discovery/download/installation. Physical Bigme
rendering of partial interiors, thickness and labels still needs confirmation.
Keep evidence in `test-results/alpha44-20261017/`; do not publish the archived
design branch or any held-artwork history.

## 2026-10-18: Kanzenban replaces the Tankobon binding option

User approved with "Kor pa det!" after preferring Paperback and proposing a
taller Kanzenban alternative. Start at public alpha.44 `6671b2ca`. This is a
local C07 change, not a merge or publication; VERSION stays alpha.44 and the
reviewed Bookshelf `c7a9db2c` / SimpleUI `7eb80f9e` pins are unchanged.

Kanzenban / large format shares Paperback's colours and thin soft boards,
with 12% extra height where shelf space allows. A small optional native
planner hook applies host geometry before row packing and slipcase building.
Cover width follows height, respecting row/push/width limits. Page-derived
thickness and partial box filling are unchanged. Per-series overrides still
win across shelves, drills and pinned series. Swedish uses
"Kanzenban / storformat"; every other language uses the English label.
Legacy `tankobon` settings resolve to Paperback without rewriting them, so
existing selections do not unexpectedly grow and rollback retains the old
preference. Paperback, Hardcover and standalone component defaults are intact.

Focused tests cover legacy menus/no writes, translations, warm plan caches,
height/aspect limits across DPI and cover sizes, natural member widths,
native box painting/shadows, and unchanged source records. Full sequential
gates and clean-commit package evidence belong in
`test-results/kanzenban-20261018/`, with results and device gaps in TESTING.md.
No push, tag, release, artwork or bootstrap changes. Any sealed alpha.44
preview is local only and must not replace the public alpha.44 assets.

## 2026-10-18: Cached MAL star rating on physical series boxes

User approved the upper-left front-cover sticker and requested the same star
format as folder cards, not a MAL prefix. Start at local `a8dd8f45` (unpublished
Kanzenban follow-up); this is a C06/C07 adaptation, not a merge or publication.
VERSION stays alpha.44; upstream pins, artwork and bootstrap stay unchanged.

The new OrbitUI adapter wraps the native box painter, then draws the shared
CountBadge inside the fitted cover. Keep read/total and `+N` above, the series
name below, and all geometry, buffers, binding choices and gestures intact.
Too-small images omit the badge instead of clipping text. Reuse the normal
text face and shared font scale/day-night palette. Own and free added text
on updates, reinit and teardown; installation is idempotent.

Inspected myanimelist.koplugin 1.5.2's cached folder hook. Pass the common member
directory and series name, leaving Manga scope and explicit-folder matching
with the external plugin. No new API, credential reads, link changes, metadata
hydration, sidecar access or network operations. Absent/invalid/erroring ratings
are hidden. Query the live cached callback on paints for refreshes/unlinking.

Focused provider/lifecycle tests and real native geometry/paint tests cover
complete series, DPI, aspect ratios, native head/title separation and cached
badge ownership. Full sequential gates and clean-package evidence belong in
`test-results/series-rating-20261018/`, with results/device gaps in TESTING.md.
No push, tag or release; any local alpha.44 ZIP must not replace public assets.

## 2026-10-18: Prepare alpha.45 for explicit publication

User requested "Publicera" after the Kanzenban and cached MAL star-rating
implementations. Include local `a8dd8f45` and `f15f666e`; bump VERSION to
0.1.0-alpha.45 and update release/OTA documentation. Do not import upstream,
change bootstrap/API 1, modify artwork, rewrite preferences or reading data,
publish the preserved box-design branch, or replace any existing release asset.

Re-run sequential full Lua/LuaJIT suites and translation checks, then seal a
clean-commit package and audit the runtime/outgoing history. Check alpha.44's
actual installer offline and against public release bytes, with both CI jobs
and downloaded draft/public hashes verified before declaring publication done.
Store release evidence in `test-results/alpha45-20261018/`. Physical Bigme
Kanzenban height, star-label legibility, night mode and interaction still need
confirmation; publish as a prerelease, not latest stable.

## 2026-10-18: Rounded cutout for the physical box rating

User approved replacing the upper-left MAL badge with an upstream-style rounded
cutout. Start at public alpha.45 `daa16ca1`. This is a C06/C07 presentation
follow-up, not an upstream merge or publication; VERSION and pins stay put.

The native stencil mirrors its right-hand count notch for an optional
host-owned left label. OrbitUI supplies unframed cached star-plus-score text;
the box uses its own name/count ink and rounds both notch transitions, with
the original light sticker edge. Fit after actual first/custom-image sizing,
with no cover scaling, band, box geometry or count/overflow/title movement.
Too-small images omit text and cutout together. Missing/removed scores restore
the cover on repaint; cached refreshes, text sizing and lifecycle remain local.
The standalone no-hook outline and folder-card badges do not change.

Retain the cached MAL provider contract, shared font scaling and explicit text
ownership. No new queries, settings or reading-data writes, artwork changes,
bootstrap changes, pushes, tags or OTA releases. Provider/lifecycle, real native
stencil/paint and custom-image tests are extended. Full sequential test/package
evidence belongs in `test-results/rating-notch-20261018/`; device checks remain
explicit in TESTING.md. Any local alpha.45 package must not replace the public
alpha.45 release asset.

## 2026-10-18: Prepare alpha.46 for explicit publication

User requested "Publicera" after the rounded MAL-notch implementation at
`fdc7958d`. Include that follow-up and bump VERSION to 0.1.0-alpha.46, with
release/OTA documentation. Do not import upstream, modify artwork or bootstrap,
rewrite preferences or reading data, publish the archived box-design branch,
or replace any previously published asset. Bootstrap API stays at 1.

Re-run sequential full Lua/LuaJIT suites and translations on the versioned
tree, build from a clean commit, audit runtime/outgoing history, and exercise
the actual alpha.45 installer's offline upgrade/rollback and recovery. Verify
both CI jobs and downloaded draft hashes before publication, then anonymous
public release discovery/download/install. Evidence belongs in
`test-results/alpha46-20261018/`. Physical Bigme corner/colour/night typography
and interaction acceptance remains outstanding; use a prerelease, not latest
stable. No additional runtime changes are part of this publication step.

## 2026-10-18: Optional series title inside the cover (not published)

User asked for a title at the foot of the series cover with a legible
background so the image can extend to the bottom. Add a per-chip **Series box
title** choice, defaulting to the current below-cover strip. Store the opt-in
in OrbitUI settings with profile-qualified shelf IDs; no metadata or migration.

`orbitui_series_titles` owns menus, translation selection, plan policy, fitted
title text and its lifecycle. A small generic seam in the native box painter
reclaims the strip height, bottom-aligns the proportional image and paints
the host caption before the rounded stencil. Keep the normal inset/light edge,
the MAL notch, counts, spines, box footprint and pagination unchanged. Custom
image refits adapt the title, and tiny covers omit it instead of overlapping.

Tests cover shelf isolation/reload, English/Swedish labels, immediate cache
invalidation, unchanged warm pagination, long/CJK titles, completed series,
custom images, day/night, DPI/aspect ranges and resource ownership. Evidence
belongs in `test-results/series-title-20261018/`. The preview records actual
paint calls but uses placeholder artwork and approximate fonts, not a device.
No upstream import, VERSION bump, push, tag, GitHub release or OTA publication.
Any local alpha.46 package must not replace the existing public alpha.46 asset.

## 2026-10-18: Optional BookOrbit-inspired Home dashboard (not published)

User supplied their SimpleUI Home and an upcoming BookOrbit dashboard as visual
references. Add an opt-in **Reading dashboard** under OrbitUI settings, as a
new first Home page rather than overwriting the existing layout. Reuse existing
reading, statistics, goal, Want to Read and New Books providers. Keep the dock
and book open/hold routes, and preserve the reader's older pages on disable.

The adapter owns native rounded cards, a dark/light hero option, independent
three-cover pagers and bounded responsive geometry. Stats update its tree;
cover completion replaces only its borrowed cover widgets, not text or data.
DPI is applied exactly once to fonts. Native module chrome settings are skipped
because this module draws multiple cards itself. Explicit loader seams register
the module and include its enabled state in BookOrbit's existing auto-refresh
gate. There are no component edits, new sync owners, remote download buttons,
invented summary counts or imported artwork.

Evidence belongs in `test-results/dashboard-20261018/`: sequential Lua/LuaJIT
suites, translations and clean-commit package checks. The optional SVG/PNG
schematic comes from the real widget positions with synthetic cover art and
approximate fonts; it is not a device screenshot. Bigme rendering, touches and
performance remain to be checked. Preserve the previous unpublished title-on-
cover commit. No upstream merge, VERSION bump, push, tag or release; a locally
rebuilt alpha.46 ZIP must never replace the already-public alpha.46 asset.

## 2026-10-18: Two-way dashboard book-row paging (not published)

User requested the tab module's arrow-paging behavior for BookOrbit Want to Read
and New Books in the dashboard. Replace each row's forward-only wrapping arrow
with previous/next controls and a page counter beneath the covers. Keep three
books per page and independent row positions, hide controls for single-page
lists, dim/disable end arrows and clamp saved positions after source changes.
The full-width titles and book open/hold areas remain separate from the controls.

No component edits, data-provider changes, upstream import or release. Focused
tests exercise both directions, independent Home/row state, partial last pages,
disabled arrows, shrinking lists and book actions after paging. Re-run Lua,
LuaJIT and clean-commit package gates; evidence under
`test-results/dashboard-paging-20261018/`. Physical-device touch/render checks
remain pending. Any local alpha.46 ZIP is unpublished and must not overwrite
the existing public release asset.

## 2026-10-18: Prepare 0.1.0-alpha.47 publication

Explicit publication request after `31f5fdfc`. Release the three reviewed local
changes together: `83fc014b` (series titles over covers), `c36c3a47` (optional
Reading dashboard) and `31f5fdfc` (two-way book-row paging). Only VERSION and
release documentation change during preparation. Existing Home layout remains
the default; enabling the new page is a separate user action.

Keep bootstrap/API 1, upstream pins, artwork and external sync ownership
unchanged. Preserve the unpushed `design/orbitui-series-boxes` branch and do not
publish the held artwork or history containing it. Gate publication on full
Lua/LuaJIT and translation checks, a sealed runtime, outgoing-history/asset
audits, the actual alpha.46 installer's upgrade/rollback, green CI and verified
draft/public bytes. Store evidence under `test-results/alpha47-20261018/`.
Publish as a prerelease; physical-device validation remains open. Never replace
the previously published alpha.46 asset. Disable the dashboard before code-only
rollback so the older runtime is not presented with its unsupported page.

## 2026-10-18: Solar Icon Pack v1.1.0 artwork update (not published)

User requested the new icons from pxlflux's Solar Icon Pack. Advance only the
artwork pin from `d4f4799c7a48e8e341163e7b7edb07ddd777614f` to the reviewed
v1.1.0 commit `8182c4e6e89c7e74e02e5fa566774a3441fe299a`. Bookshelf/SimpleUI
baselines, VERSION and runtime settings remain unchanged (C07/C08).

Import all 60 new supplementary motifs in both Colour and Mono, bringing each
catalogue to 220 icons. Retain all 320 previous identities and catalogue rows;
only Instapaper and Z-Library receive revised upstream artwork. Add categories
and search aliases for the new entries. Preserve the original SVG geometry,
palette, strokes and CC BY 4.0 attribution. Do not import or execute upstream's
installer, updater, pack.lua presets or overview images.

Focused asset and picker tests cover the full inventory, checksums, static SVG
allowlist, search, both styles, selection and OTA path rebasing. An independent
rebuild reproduced all 443 generated outputs byte-for-byte. The runtime
candidate's ZIP integrity and all 443 Solar files pass verification. Full Lua
and LuaJIT runs pass: 103 Python tests (four existing source-artwork audit skips),
36 icon tests, 317 module paths, 858 syntax checks, 395 Bookshelf suites (two
existing SQLite-environment skips) and the SimpleUI suites. All 43 translation
checks pass. Logs are in `test-results/solar-v1.1.0-20261018/`; device rendering
and touch checks remain outstanding.

The prior manga publication is still blocked: the candidate is about 76 MiB,
above the installed OTA updater's 64 MiB limit. The sealer correctly rejects it;
no limit is bypassed and no artwork is resized without the pending approval.
Keep the earlier package-safety changes separate. No push, version bump, tag,
GitHub release or OTA publication accompanies this icon update.

## 2026-10-18: Prepare alpha.48 OTA size-limit bridge

User explicitly requested a larger updater limit and publication, then chose
a small OTA intermediate release rather than a one-off manual installation.
Base this bridge on public alpha.47 (`36745592`), isolated from the pending
manga/Solar work. Preserve that work for the later full release; no art is
resized, deleted or imported here. The bridge itself must remain below 64 MiB.

Raise download/extraction budgets to 128/256 MiB. Keep individual files at
32 MiB, the 2,000-file cap, 1 MiB manifest, strict paths, TLS/hash validation,
staging/rollback and unchanged bootstrap/API 1. File downloads get ten minutes
while small in-memory requests retain three minutes and socket blocking stays
at 15 seconds. The packager now rejects payloads outside these limits without
replacing the candidate archive; its test checks agreement with runtime bounds.
The native smoke harness calls the starting runtime's real release selector so
the older 64 MiB discovery failure can no longer escape the upgrade test.

Only updater, packaging/tests, VERSION and release documentation change. Gate
publication on Lua/LuaJIT, translations, a sealed sub-64-MiB runtime, actual
alpha.47 upgrade/rollback, a private larger fixture with alpha.48, outgoing
history/assets, CI and downloaded draft/public bytes. Evidence:
`test-results/alpha48-bridge-20261018/`. Physical-device acceptance remains open.
The larger successor requires the user to install this bridge and restart
before it is published; do not immediately supersede the bridge with it.

The bridge was published from `2c707ec0` as `v0.1.0-alpha.48`, with an unchanged
alpha.47 artwork inventory. Both GitHub CI runs passed, and the downloaded
draft/public ZIPs match the tested 54,356,479-byte runtime. The complete Lua,
LuaJIT and translation gates passed, as did native alpha.47 upgrade/rollback
and an alpha.48-only private 79.5 MB test payload; alpha.47 rejects that larger
payload as expected. The updater changes are merged back into local development
without publishing the pending manga/Solar commits. Do not reuse alpha.48's tag
or assets for that combined tree. Wait for the user to confirm installing the
bridge and restarting KOReader, then prepare a separately versioned successor.

## 2026-10-18: Prepare alpha.49 artwork publication after the OTA bridge

The user confirmed completing the alpha.48 installation and KOReader restart.
Proceed with their pending full-publication request: Manga/Manga II from
`b22e9e35` / `8c96aa84`, Solar Icon Pack v1.1.0 from `eb4ab1d3`, the package
guardrails and alpha.48 updater merged back in `d74d2681`. This is a new
version and asset, never a replacement for the public alpha.48 bridge.

Only VERSION and release documentation change in preparation. Preserve all
fourteen original transparent ornament PNGs, their provenance/notices and all
Solar SVGs. No resizing, new generation, component merge, source-pin change,
settings rewrite or reading-data migration. The separate design branch and
held Mann artwork must remain unpublished, including their history.

Gate the release on complete Lua/LuaJIT and translation suites, a sealed runtime
within alpha.48's bounds, original asset and outgoing-history audits, the actual
public alpha.48 installer's native upgrade/restart/rollback, green CI and exact
downloaded draft/public bytes. Save evidence in `test-results/alpha49-20261018/`.
Publish as a prerelease; physical Bigme rendering/touch checks remain open.
Disable Manga/Manga II before rolling back to a runtime without series matching.

## 2026-10-19: Reviewed Bookshelf 5.5.4 merge

User request: "Merga upstream", without publication. Review both tracked
branches on `maintenance/upstream-bookshelf-5.5.4-20261019`, starting from the
clean published alpha.49 tree (`9271cb33`).

- Bookshelf master: `c7a9db2ca1c21ef6a38715e74306fe7f514ba807` to
  `982375a7f1fe48ccaad4627dad0646af5e0f6651`, 29 previously absent commits,
  including 5.5.3, 5.5.4 and the user's Paperback PR #536.
- SimpleUI main is unchanged at `7eb80f9e570e6351c55f501f91e1a29c1442b756`.
- Unsquashed subtree import: `3efaecee`. Original fork provenance and the
  alternate box-design branch are untouched. Only the Bookshelf integrated
  pin advances; module map adds book binding/module cache and removes the
  obsolete internal gesture-passthrough module.

Reviewed C01-C11, with changes concentrated in C01/C02/C04/C06/C07/C08/C10.
Incoming behavior includes deferred/cached micro-module fitting and statistics,
optional KOReader-rate e-ink flashes, live-host gestures for parked readers,
folder progress/history sorting, shelf-of-shelves counts/random picks, themed
cover/badge colours, Calibre home fallback and About/help/translation updates.
The new count and goal caches are performance caches, not synchronization or
reading-state owners. No claim of measured Bigme acceleration.

Resolve six textual conflicts semantically: retain OrbitUI documentation in a
short note beside the new upstream guide, per-root metadata caches and profile
scope in the repository, host-owned binding/series controls, reader prewarm
controls, binding skins/geometry and box render keys, folder actions and dock
gestures. Native Hardback/Paperback works without host hooks; embedded controls
continue to use `orbitui_book_bindings`, including Kanzenban and legacy read-only
tankobon handling. Keep native and host preferences separate, never show both
controls. Scope statistics-only locals after the added upstream helper pushed
the combined repository over LuaJIT's 200-local limit.

Adaptation and regression commit: `05cb0b83`. Full sequential Lua and LuaJIT
runs passed, including 407 Bookshelf suites and all 13 SimpleUI test files.
Root coverage is 670 Lua / 671 LuaJIT cases in 54 files (the last four Lua dock
cases ran separately after the full run); the added scoped-history assertions
also passed a separate Lua repository run. Python: 103 tests, four unchanged
external-artwork-cache skips. Module map: 318 paths; final LuaJIT syntax: 874
files. Translation checks: all 43 catalogues, no baseline or new failures.
Existing two KOReader-SQLite suite skips, native-font and absent-Bookends
limitations remain; no failure allowances were added.

Clean-source package from `05cb0b83` passed sealing, full ZIP validation and
runtime inventory checks: 1,888 manifest files / 1,943 ZIP entries, 79,647,494
bytes, SHA-256 `a74b434958bd44c76a65989005516f8abed03f5c4b3b3d7ed188ee402533bcdf`.
This is an unpublished development package still carrying alpha.49, NOT a
replacement for the public alpha.49 asset. Rebuild after this documentation
record; any publication must use a new version and the normal release gates.
Evidence lives in `test-results/upstream-20261019/`. Physical Bigme checks remain
open as listed in `TESTING.md`. No version bump, push, tag, GitHub release, CI
dispatch or OTA update was made. Fast-forward local main to the verified branch.

## 2026-10-19: Prepare alpha.50 Bookshelf 5.5.4 publication

The user explicitly requested publication after the verified merge at `82fd72c9`.
Publish that reviewed tree as a new prerelease, never replace alpha.49 assets.
Only VERSION and release documentation change in preparation. Keep the exact
component pins, stable bootstrap/API 1, artwork and unpushed alternate design
branch unchanged. No additional upstream fetch/import or settings migration.

Release gates: full sequential Lua/LuaJIT suites, all translation catalogues,
clean-commit packaging, complete inventory and outgoing-history audits, the
public alpha.49 installer's native upgrade/restart/rollback and truncated-file
recovery, green CI and verified draft/public downloads. Evidence lives in
`test-results/alpha50-20261019/`. Alpha.48 or later is still required for OTA;
the payload exceeds the older 64 MiB bound. Bigme rendering, gestures, cache
timing and opt-in full-refresh acceptance remain to be checked on the device.

## 2026-10-19: Editable Reading dashboard headings (not published)

User approved adding independent names for the dashboard cards. Add
Reading dashboard > Headings in shared and native module settings, with an
editor for each of the nine cards. Store overrides in the existing SimpleUI
store, scoped to the screen prefix. Empty input and Restore default remove
only the selected override; Cancel does not write or refresh. Automatic hero
and goal titles remain dynamic when no override is set. User names are not
translated, and long single-line headings retain the existing width bounds.

Changes stay in OrbitUI core/adapters and tests; no component or source-pin
change. Other Home modules, layouts, book metadata, goals, reading progress,
artwork and bootstrap files remain unchanged. C10 records the ownership and
fallback contract. Test all editors, menu translations, persistence through
module reload, refresh/paging, screen isolation and bounded rendering; evidence
belongs in `test-results/dashboard-headings-20261019/`. No version bump, push,
tag or public OTA change is authorized by this implementation request.

Full sequential Lua/LuaJIT verification passed: 677/678 root cases, including
27 dashboard cases, 407 Bookshelf suites, all 13 SimpleUI files and 103 Python
tests. All 43 translations pass. Existing four artwork-source and two
environment suite skips remain; no new exceptions. Package the clean local
commit for validation only, retaining VERSION alpha.50 without replacing its
public assets. Device keyboard/menu, redraw and native font checks remain open.

## 2026-10-19: Larger dashboard pagination and card swipes (not published)

User requested larger pagination controls and horizontal swipes in the Reading
dashboard's Want to Read / Recently added cards. Increase the scaled pager
height from 32 to 48, button width from 36 to 52, arrow type from 18 to 28 and
counter type from 11 to 16, with dark counters and a smaller bottom inset.
Use the existing card bounds and preserve width-limited portrait cover size;
do not borrow space reserved for the Home footer or bottom dock.

Both arrows and interior card swipes share a clamped callback and independent
session positions. Consume swipes at boundaries and for empty/single-page rows
to avoid accidental Home turns. Rebuild regions with content and discard a
pending book hold when swiping. Use native SimpleUI `onSwipe` delegation rather
than registering an independent gesture range, retaining screen-edge, vertical
and outside-card behavior. No component, pin, layout/settings migration, source
provider, artwork, bootstrap or version changes. The earlier unpublished custom
card headings remain intact.

Add seven dashboard cases, including execution of the native screen-routing
methods, in addition to the existing geometry/book-action/paging/heading tests.
Evidence belongs in `test-results/dashboard-pagination-20261019/`. Validate full
sequential Lua/LuaJIT suites, translations and the clean-commit runtime ZIP.
No push, tag or release requested; physical-device acceptance remains open.

Full sequential Lua/LuaJIT verification passed: 684/685 root cases (34 dashboard
cases), 407 Bookshelf suites, all 13 SimpleUI files and 103 Python tests, plus
all 43 translation catalogues. Existing four artwork-source skips and two
environment suite skips remain unchanged. The generated schematic shows both
larger pagers, without claiming native font or physical touch verification.

## 2026-10-19: Oneshots folder boxes and single-volume series (not published)

User requested one box for Oneshots manga and boxes for named series that so
far have only one local volume. Enable a new optional `include_singletons`
argument to native box preparation from the OrbitUI adapter, including nested
group preparations. Calls without that option retain upstream's lone-book
behavior. Existing grid, series drills, incomplete lists, search and OPDS
exclusions remain.

On the fixed Comics profile's Manga/Serier folder chips and folder drills,
group complete local Oneshots directory membership into a view-only native
box. Scope matching to the chip root, exact folder components and real paths;
include title subfolders and deduplicate without changing source metadata or
folder order. Do not collect other metadata-free directories or widen special
source/filter membership by introducing folder navigation on other chips.

Folder boxes retain kind/path, native folder callbacks and path-only restore;
the folder's live fetch handles additions/deletions. Disable compaction while
inside Oneshots. Extend native box image/callback dispatch minimally for folder
identity, preserving normal series defaults. Suppress representative ornaments
and shared MAL ratings, and do not treat the collection name as a series binding
override. Keep shelf and genuine member binding choices. No component import,
source-pin/version bump, file move, settings write or public release.

C06/C07 document the deliberate follow-up; tests cover both host preparation
and native folder navigation/painter/gestures. Full sequential Lua/LuaJIT,
translations and clean-commit ZIP validation belong in
`test-results/oneshots-boxes-20261019/`. Physical Bigme verification remains
open. The earlier unpublished heading and dashboard-swipe changes are retained.

Both full runtimes passed: 694 Lua / 695 LuaJIT root cases in 54 files,
407 Bookshelf suites (two environment skips), all 13 SimpleUI files and
103 Python tests (four existing external-source skips). All 43 translation
catalogues, 318 module paths and 874 syntax files passed. No new exceptions.

## 2026-10-19: alpha.51 publication preparation

The user explicitly requested publication after the Oneshots/singleton-box
change. Release the three reviewed local commits: independent dashboard card
headings, larger pagination controls with card-local swipes, and folder-backed
Oneshots/single-volume series boxes. Preparation changes only VERSION and
release documentation. Bookshelf stays at `982375a7`, SimpleUI at `7eb80f9e`;
there is no new import, artwork migration, bootstrap change or book-data write.

Run full sequential Lua/LuaJIT, translations and clean-commit packaging; audit
outgoing history and the exact runtime for held artwork/secrets. Verify native
OTA from public alpha.50, both CI refs and downloaded draft/public bytes. Keep
the release a prerelease, preserve the unpushed alternate design branch and
report Bigme rendering/touch acceptance separately. Alpha.48 or later is still
required for OTA of this larger bundle. Evidence belongs in
`test-results/alpha51-20261019/`; earlier rollback caveats remain applicable.

## 2026-10-19: alpha.52 publication preparation

The user explicitly requested publication of the two Manga III ornaments.
Release `8940e7ae`: original image_gen telescope and bungalow, exact series
bindings for Insomniacs After School and Hirayasumi, native zoom/info cards
and an independent additive installer marker. Prior packs, settings, reading
data and upstream pins remain untouched. No third-party bitmap or model was
used as generation input. Original generated bytes and provenance ship together.

Preparation changes only VERSION and release documentation. Run full sequential
Lua/LuaJIT, translation and clean-commit package checks, audit outgoing history
and runtime for held artwork/secrets, verify both CI refs and draft/public
downloads, and test native OTA from public alpha.51 before/after publication.
Preserve the local alternate design branch and keep prerelease status. Alpha.48
or later is still required for OTA; disable Manga III before rolling back to
alpha.51 or earlier, where its images are not known as series-bound pieces.
Physical e-ink checks remain separate. Evidence: `test-results/alpha52-20261019/`.

## 2026-10-22: Bookshelf 5.5.5 and Beta 3 publication preparation

The user explicitly requested merging and publishing before replying about
Bookshelf compatibility. Scope is Bookshelf, from integrated
`982375a7f1fe48ccaad4627dad0646af5e0f6651` to master
`065f25c06d9a8e0607f29cbe632f4b3d44a8bd37`: 15 incoming commits, including
5.5.5 (`2d26fd7f96ee1cc5caccf3960bd70076ca7a763e`) and PR #544's subsequent
Shelf size translator fix. SimpleUI stays at
`7eb80f9e570e6351c55f501f91e1a29c1442b756` (2.7.5).

Import commit `ee10004e` is an unsquashed subtree merge on the dedicated
`maintenance/bookshelf-5.5.5-beta3-20261022` branch. The following adaptation
and release commit records the pin, regressions, Swedish strings and beta.3
documentation separately. No module-map changes (318 canonical paths).

Four conflicts were resolved individually: retain the shared sidecar page-count
resolver and doc_pages/rendered-cache priority while honoring an explicit
disabled stable-page preference; retain lazy widget dependencies with upstream's
variable-width halo glyphs; keep both the new rating painter and completed-group
decoration; retain local title/footer gettext messages in the refreshed template.
No upstream feature is deliberately deferred. Reviewed C01-C11, especially C04
cache/page-count semantics, C05 navigation, C06/C07 shelf scope and rendering,
C08 migration safety and C09 package/update ownership.

Incoming behavior includes opt-in cover star ratings and cached Hardcover
fallback, the refresh-library dispatcher action, read-state folder re-sorting,
base-shelf Back/Folder up guards, taller hero covers, spine-colour cache reset
and stable-page preference handling. Existing dashboard, bindings, MAL badges,
aspect-preserving box covers, profiles and optional ornament packs remain.
No root bootstrap, artwork, SimpleUI code or reading-data migration changes.

Full sequential Lua and LuaJIT runs passed: 823/824 OrbitUI cases in 66 files,
410 Bookshelf suites and all 13 SimpleUI test files. The two Bookshelf SQLite
suite skips, four external-artwork-source skips among 115 Python tests, and
existing native-font/parity limitations are unchanged. All 43 translation
catalogues, module-map checks and 904 LuaJIT syntax checks passed. No new
exceptions. Added regressions cover disabled stable labels with all local count
sources, fresh lazy wide-glyph construction and wrapped Shelf size repainting.

Publication is approved as a prerelease, not device acceptance. The release
gate additionally requires a clean-commit ZIP, audit of outgoing history and
held artwork, native OTA upgrade/restart/rollback from public Beta 2, both CI
refs and verified draft/public download bytes. Evidence belongs in
`test-results/beta3-20261022/`. Physical-reader checks of stars, navigation and
tall cover layout remain outstanding; do not infer them from headless tests.

Internal OTA needs no bridge: bootstrap API 1 is unchanged. Rollback retains
settings and reading data; old code may treat the new rating icon choice as its
default heart. The install guide now identifies Storefront 26.10.20 as containing
PR #5078's embedded-root fix; its external-import device test is still pending.
Preserve the separate unpushed design branch and artwork hold.

## 2026-10-22: SimpleUI dialogs and Beta 4 publication preparation

The user explicitly requested merging the remaining SimpleUI upstream changes,
publishing and drafting (not posting) an English reply about tab compatibility.
SimpleUI main advances from `7eb80f9e570e6351c55f501f91e1a29c1442b756` to
`dd541fc2b384af43287474587622ef68a2fb3185` (still 2.7.5), containing
`58e0ce66`'s dialog refactor and `dd541fc2`'s active-tab frame fit. Bookshelf
stays at `065f25c0` (5.5.5 + PR #544); no fresh Bookshelf import is implied.

Import `732714d6` is an unsquashed subtree merge on
`maintenance/simpleui-dialogs-beta4-20261022`. Nine file conflicts were resolved
individually. New window-step registration keeps navigation-generation guards,
destination-safe displaced-screen handover, ProgressSync and owned menu hooks.
The new soft-park promotion replaces the unused old warm helper and retains
immediate refresh. Window hooks deactivate rather than overwrite third-party
wrappers during teardown. New ActionSheet icon choices retain all OrbitUI icon
sources and both call signatures. Book opening retains bridge preparation;
the Home helper export and extra-row refresh callbacks remain compatible.
Metadata ignore flags coexist with the bounded cache, invalidation and
progress-only/prefetched fast paths; non-Kobo paths avoid provider lookups.
Chinese single-plural translations remain valid.

Separate adaptation work retains the native file-browser book action sheet
(including file operations) while keeping OrbitUI's detail panel on Home.
The panel consumes upstream's navigation-row registry when the old explicit
row-id option is absent. Nine new canonical modules bring the map to 327.
SimpleUI's upstream LICENSE now contains GPL-3.0; the original MIT copyright
and permission notice remains in `LICENSE-MIT-ORIGINAL.txt`. `sources.json`
distinguishes original import licensing from the current component license.

Reviewed C01-C11, especially C02/C05 navigation, C03 book opening, C04 caches,
C06 plugin wrappers and C07 grid/settings. No upstream feature is deliberately
deferred. Tabbed Grid already existed before this merge; only its frame fit
changes here. No bootstrap/API, artwork, settings reset or reading-data migration.

Release gate: sequential full Lua/LuaJIT suites, translations, clean-commit
package audit, outgoing secret/held-artwork checks, native OTA from public
Beta 3 with restart/rollback, both CI refs and exact draft/public bytes.
Evidence: `test-results/beta4-20261022/`. Added tests cover window ordering,
error propagation, later wrappers/stale owners, scheduled navigation, store
memoization, optional virtual paths, file-browser/Home routing, ignored metadata
and whitespace outside the active Tabbed Grid frame. Existing icon and book
panel tests now exercise the new API rather than discard prior assertions.

Full sequential runs passed: 832/833 OrbitUI cases in 67 files under
Lua/LuaJIT, 410 Bookshelf suites and all 13 SimpleUI test files. All 115 Python
tests passed with four unchanged external-source skips. The two native SQLite
suite skips and existing font/parity limitations remain unchanged. All 43
translation catalogues, 327 module paths and 914 LuaJIT syntax checks passed.
Local native archive/SHA OTA from Beta 3 passed upgrade, restart, code rollback,
truncated-download recovery and the external-runtime snapshot path. Package and
outgoing-history audits found no held artwork; Gitleaks found no secrets in
the outgoing commits. Final CI/draft/public verification remains a release gate.

Publication is approved as a prerelease, not physical-device acceptance.
Dialogs, touch/keyboard navigation, suspend/resume and third-party plugin
interactions still need a physical-reader smoke test. Internal OTA requires
no bridge; code rollback retains settings and reading data. Preserve the
unpublished alternate-design branch and the held-artwork exclusion.

## 2026-10-23: Reviewed SimpleUI 3.0 release-ZIP import (not published)

User requested an upstream merge for both components, then explicitly approved
using SimpleUI's official 3.0 release ZIP after the Git/asset discrepancy was
demonstrated. Bookshelf `master` remains
`065f25c06d9a8e0607f29cbe632f4b3d44a8bd37` with zero incoming commits.
SimpleUI `main` and tag `3.0.0` both remain
`dd541fc2b384af43287474587622ef68a2fb3185`, already integrated in Beta 4;
the ZIP contains 93 changed and 142 added paths relative to that Git tree,
and omits 10 Git paths. This is an approved source-import exception, not a
claim that the missing upstream commits have been published.

Artifact: `simpleui.koplugin.zip` from the official `3.0.0` release,
published `2026-10-23T19:19:21Z`, GitHub asset `670136743`, 2,625,011 bytes.
Downloaded SHA-256, also matching GitHub's asset digest:
`033f19775610faca6b9cf2d0f92802fdd0fbfad9ebcdda881a1910884cafcf87`.
Source URL:
https://github.com/doctorhetfield-cmd/simpleui.koplugin/releases/download/3.0.0/simpleui.koplugin.zip

Local source snapshot `3cb364313ee8b2b17f860f67ef330cd6c2f5370b` is parented
to the real published Git baseline. Every runtime asset matches the ZIP;
`fonts/.DS_Store` is excluded. Git-only development documentation is retained,
while the four omitted runtime paths are removed in the source snapshot.
Unsquashed subtree merge `a5d9e76a` imports that snapshot on
`maintenance/simpleui-3-zip-20261023`. Existing context documentation is a
separate preceding commit, `78ac30e9`. Adaptation commit `9248fe71` records the
source manifest, regressions and compatibility work separately.

`sources.json.release_snapshot` records the exact artifact and local source
commit; SimpleUI's `upstream_commit`, original fork provenance and tracked
branch remain unchanged. The watcher validates and reports the snapshot apart
from Git ancestry counts. `UPSTREAM.md` explains how to reconcile it when the
matching Git history arrives. No older fork was modified and no upstream
commit was fabricated or falsely marked integrated.

Incoming features include detailed statistics and charts, live Bento preview
and quick adjustments, accent/secondary colours, bundled Inter/Geist fonts,
Tiny Critter, label/cover-element controls, and new dialogs/native-widget
bridges. The snapshot contains GPL-3.0 code and both fonts' OFL notices.
The original MIT notice stays retained. All new runtime modules and assets are
included; 37 new canonical paths bring the module map to 364.

Reviewed C01-C11. Resolutions and adaptations:

- C02/C03/C05/C06: retain navigation-generation/displacement guards, real book
  opening, the Android progress-jump bridge, BookOrbit Want to Read and external
  patch ownership. New native input and night-mode hooks become inert under
  later third-party wrappers when their last owner tears down. Lua 5.1 helpers
  preserve nil varargs and results; no global table/require/gettext replacement.
- C04: preserve complete/partial statistics cache rules and ledger reconciliation.
  New session/chart/year failures remain retryable, including a nil aggregate
  result, instead of persisting a day's zeros. New data work stays on demand.
- C06/C07/C10: old positional icon-picker signatures coexist with the new options
  and flow pages. Extra Material/Solar/Tabler pickers retain selection, cancel,
  handle replacement and per-icon weight choices. The old Reading Stats path
  forwards to the new module, giving both names one instance. Section labels
  are fresh, normally freed widgets with scoped scales and stable repaint
  signatures; hidden labels can be restored. Chrome refresh targets real content.
- C07/C08: retain exact legacy Bento percentages, stacked columns and independent
  top margins. An explicit width/movement edit opts only that screen into the
  new fixed-span row model; new rows remain top-aligned. Layout drafts and saved
  tables stay separate. Keep the 96dp navbar, transparent control/cover/module
  defaults, detailed Currently Reading defaults and explicit UI font selection.
  v12/v13 badge/folder/caption migrations copy into unset new keys, retain all
  legacy keys for code rollback, honor embedding deferral and retry failures.
- C08/C09/C11: root bootstrap/API 1, VERSION, Bookshelf, existing artwork/add-ons,
  ornament ownership and reading-data paths stay unchanged. About identifies
  the integrated component versions. The new fonts/critter asset directories
  participate in package inventory checks. No publication or OTA change.

Both full sequential Lua/LuaJIT gates and all 43 translation catalogues passed.
Supplemental root runs passed 841/842 cases in 68 files under Lua/LuaJIT. After
the final missing-aggregate regression was added, the complete nine-case
`test_simpleui3` suite passed separately under both runtimes. Python: 117 tests
per full run, with four existing external-source skips. Both runtimes passed
410 Bookshelf suites (zero failures, two environment skips); all 13 original
SimpleUI test files passed. All 364 module paths and 952 LuaJIT syntax files
passed.

Clean committed candidate `9248fe71` packaged successfully: 1,969 inventoried
runtime files plus the manifest (2,034 ZIP entries including directories),
SHA-256 `f99a6889e01a70b8805aeba8a4074c7d00ec3d3e5e7249ee7411b232cd50992e`.
Every packaged file matched its inventory size/hash and `.DS_Store` was absent.
The actual public Beta 3 installer passed native libarchive extraction and
SHA verification, missing-module rejection, activation/restart, code rollback,
truncated-download recovery and the full external-runtime snapshot path with
persistent rollback. These are temporary headless installations, not reader UI
tests or publication. The final documentation-only verification commit is
repackaged separately; its checksum stays with the local artifact/evidence.

A fresh read-only collector at 20:59 UTC reported zero missing Git commits for
both components and explicitly displayed the additional reviewed 3.0 ZIP
snapshot. The official asset digest remained unchanged. No issue was published
or updated by the local collector. The temporary source checkout was removed;
`imports/simpleui-3.0.0-release-zip` retains the source commit, and the exact ZIP
is preserved in the local evidence directory.
The original 13 SimpleUI test files remain enabled, with native fixtures adapted
to the new APIs rather than discarded assertions. Python includes two additional
monitor/provenance tests. The existing four external-source audits and two
Bookshelf KOReader-SQLite environment skips remain; no new exceptions.

Evidence: `test-results/upstream-simpleui3-20261023/`, including the frozen ZIP,
full logs and final package checks. `docs/TESTING.md` records outstanding Bigme
layout/editor, typography, colour/night mode, charts, Critter, dialog/keyboard,
reader return and external-plugin checks. Physical-device acceptance is not
claimed. VERSION stays `0.1.0-beta.4`; a local validation ZIP must never replace
the published Beta 4 asset. Publication, version/tag and OTA require a separate
user request. Preserve the held-artwork exclusion and alternate design branch.

## 2026-10-23: Beta 5 publication request

After the completed SimpleUI 3.0 import and disclosure of the remaining Bigme
tests, the user explicitly requested "Pusha och publicera". Prepare a new
`0.1.0-beta.5` prerelease; never replace Beta 4's assets. This continues the
previously approved public beta line and does not claim new physical-device
acceptance. Preserve the device checklist, old layouts/settings, stable
bootstrap/API 1, Bookshelf, artwork and held-bitmap exclusion.

Only VERSION and release documentation change in this preparation. Release
gates: both full runtimes/translations, clean-commit inventory and all outgoing
Git-object/secret audits, actual public Beta 4 native upgrade/restart/rollback,
main/tag CI, exact draft/public bytes and anonymous live OTA. Evidence belongs
in `test-results/beta5-20261023/`; publication outcomes are recorded separately
after verification. The raw source snapshot remains an unsquashed import;
unrelated alternate-design/held-artwork branches must not be pushed.

### Beta 5 publication verification

Published `v0.1.0-beta.5` from clean commit
`a19a96abce51e46da7175aab829cea6239bee127` at `2026-10-23T21:26:16Z`,
as a prerelease, not a stable release. Main and the annotated tag were pushed
explicitly and atomically; unrelated branches were not pushed. Public release:
https://github.com/komadorirobin/orbitui.koplugin/releases/tag/v0.1.0-beta.5

Both complete sequential Lua/LuaJIT runs passed: all 68 OrbitUI test files,
117 Python tests per run (four existing external-source skips), 410 Bookshelf
suites per run (zero failures, two environment skips), and all 13 original
SimpleUI files. All 43 translation catalogues, 364 module paths and 952 LuaJIT
syntax files passed. No new skip or failure allowance was introduced.

The sealed ZIP contains 1,970 inventoried files plus its manifest, 2,035 entries
including directories, 8,793,504 compressed bytes and 27,137,935 expanded bytes.
SHA-256: `ff36fa56485f725f78cae11ea4023edb95fda3362e90b4f4e05641db03aa9146`.
Every file's inventory size/hash and committed source bytes matched. The public
Beta 4 base matched its GitHub digest. Bootstrap/API, Bookshelf and existing
artwork are byte-identical; only three obsolete SimpleUI SVGs are removed.
All 334 outgoing blobs, including the raw source snapshot's ancestry, were
hashed and excluded the held bitmap. Gitleaks found no outgoing secrets.

Main CI `40026326806` and tag CI `40026326592` both passed their Lua/LuaJIT
jobs; monitoring-only upstream watch `40026326440` also passed. Downloaded
authenticated draft and anonymous public assets exactly matched the sealed ZIP
and checksum, including GitHub's sizes/digests and the target commit.

Native macOS OTA from the actual public Beta 4 passed full archive/SHA checks,
missing-module rejection, activation/restart, code rollback, truncated download
recovery and external-root snapshot/restart/persistent rollback. The first local
live attempt lacked `cjson`, before any discovery/download. A fresh isolated
Debian test with the required native dependencies then passed anonymous GitHub
discovery and real LuaSocket/LuaSec HTTPS download of the published Beta 5 bytes,
followed by all the same upgrade/rollback checks. Its temporary container was
removed; Docker was returned to its initially stopped state. No reader install
was touched. Evidence: `test-results/beta5-20261023/`, particularly
`audit-{local,draft,public}.json`, `ci*.log`, `native-ota-local.log` and
`native-ota-live-linux.log`. The earlier failed environment-only live attempt is
retained separately in `native-ota-live.log`.

Physical Bigme acceptance remains open as documented. This verification-only
documentation follow-up does not replace or regenerate published release bytes.

## 2026-10-25: Reviewed Bookshelf 6.0 and SimpleUI Git reconciliation (unpublished)

User explicitly requested another upstream merge, not publication. Start from
clean public main `254a1182` on `maintenance/upstream-20261025`. Bookshelf master
advances from `065f25c06d9a8e0607f29cbe632f4b3d44a8bd37` to
`fc1103a3de9fd19eea89a53c5f1f1b0e8175682a`: 209 missing commits, including
6.0.0 (`3411d901`) and its follow-ups, net 215 changed paths. SimpleUI main
advances from `dd541fc2b384af43287474587622ef68a2fb3185` to
`40b301f0f5e4466021d00b4e47ac8c09bb65ac8c`: 18 missing commits.

SimpleUI's newly published Git history contains the approved 3.0 ZIP runtime.
Its net difference from source snapshot `3cb36431` is only 25 paths. A standard
unsquashed subtree merge retains actual upstream ancestry; content reconciliation
uses that exact reviewed ZIP snapshot as the three-way baseline, preserving
all local adaptations and all 13 original test files. Two remaining content
conflicts combine the refreshed upstream README with fork information and the
new exposed-screen ghosting refresh with navigation-generation guards. Retire
the active `release_snapshot` manifest field only now; its digest, asset ID,
snapshot and original approval remain in the October 23 log/history. Import
commit: `b9dfc849`. No Git commit is fabricated or relabelled.

Bookshelf import `48438837` resolves nine file conflicts individually, retaining
profile scope in the new shelf-visible `findGroup` option, optional host binding
controls beside card-plank settings, dock/footer geometry and top-panel gesture
exclusions, above-cover labels during in-place lift, the series-box hooks,
aspect-preserving sticker fitting and scratch ownership. Repository helpers stay
scoped/on existing module tables to fit LuaJIT's 200-local limit. Both imports
are separate from the following OrbitUI adaptation/regression/documentation work.

Reviewed C01-C11. Incoming Bookshelf features: grid-editable top/fullscreen
micro-modules and module packs, Shelf/Ornament modules among books, per-card and
panel colours, Highlights, Pin here, shelf copy/move, optional single-group
display, own menu icon, and persistent cover/progress/ornament/wallpaper/plank
caches. SimpleUI adds the shared daily-history ledger, retry-sensitive Insights/
Streak/Heatmap changes, transparent-bar/exposed-screen fixes, translations and
Critter dialogue. No upstream feature is deliberately omitted.

Adaptations preserve current OrbitUI behavior:

- C02/C03/C05/C10: retain generation guards, normal ReaderUI opening, profiles,
  shared panels/search/Home shelves, BookOrbit/KOSync bridge and one intended
  external progress writer. Exposed-screen refresh never reopens a stale route.
- C04/C07: native aspect-true sticker buffers survive widget rebuilds, bounded
  to 12 and freed on eviction/explicit cover-cache reset. Never scale the fitted
  cover again or cache text overlays. Unknown custom-file stamps bypass custom
  caching; missing custom images fall back/retry. Above-cover labels, natural
  member widths, binding/title/MAL seams and bare-module shadows stay intact.
- C06: underlay show/close and per-window paint wrappers preserve nil results
  and errors under Lua 5.1, release only their own owner and leave later plugin
  wrappers in place with retired inner wrappers inert. Failed wallpaper eraser
  allocations free their scratch before retry.
- C07/C08/C11: hosted grid migration retains old size/page fields; Lua/SQLite
  deck migration keeps the main-file rollback snapshot and auxiliary copy.
  Failed commits preserve source/memo and roll back. Existing flat/native paths,
  settings, links, ornaments and reading data stay put. Standalone migration
  defaults are unchanged when host flags are absent.
- C04: missing/busy ledger/page aggregates cannot seal zeros; failed statements
  close, malformed persisted rows rebuild, and full statistics invalidation
  discards stale historical prefixes. Insights preserves both year-range values
  and retries failed year/page queries without caching a zero result.

Both full sequential Lua/LuaJIT runs passed, with 478 Bookshelf suites (zero
failures), 117 Python tests (four existing external source-cache skips), all
original SimpleUI tests, 383 module paths and 1,041 LuaJIT syntax files. All 43
translation catalogues pass. Targeted follow-ups cover the final grid-rollback
and bounded-sticker cases under both interpreters. Test fixtures were updated
for new helper names and cache ownership without dropping original assertions.

The normal Bookshelf runner now excludes three native SQLite suites (the new
deck suite plus the prior facts/OPDS suites). Supplemental LuaJIT runs execute
all three against real macOS SQLite with unmodified pinned KOReader LJSQLite3:
7 deck, 16 facts and 100 OPDS cases pass, including failed transactions and
rollback-copy retention. A real-SQLite SimpleUI ledger check passes daily/year
totals, distinct pages, active days and historical edits after invalidation.
The new failure/retry tests also run with both plain Lua and LuaJIT; underlay
ownership/nil-result tests pass under both. No new failure exception is added.

Clean-commit packaging, complete inventory/held-artwork/history/secret audit and
native archive/SHA smoke remain final gates, recorded in the verification entry.
Evidence: `test-results/upstream-20261025/` (including exact upstream patches,
merge/reconciliation logs, test logs and pinned native-test reference hashes).
Physical Bigme module migration/editor/rotation, pinned/bound ornaments, colours,
Highlights/shared panels, menus/sleep, statistics and external-plugin checks
remain open in `TESTING.md`. VERSION stays `0.1.0-beta.5`; no push/tag/release/OTA
publication is authorized. Never replace the published Beta 5 ZIP. Preserve the
held-artwork exclusion and unrelated alternate-design branch.

### October 25 final verification

Adaptation candidate `3a33fee6ec6b806157caa622038ab9ab1a35c265` passed both
complete sequential gates again after all runtime/test changes: all 69 root
Lua files under Lua and LuaJIT, 117 Python tests per run (four unchanged external
source-cache skips), 478 Bookshelf suites per run (zero failures; three native
SQLite suites separately passed as described above), all 13 original SimpleUI
files, 383 module paths, 1,041 syntax files, and all 43 translation catalogues.
The nine new merge tests, 49 series-box cases and 11 underlay cases are included
in these final runs. Logs: `lua-final.log`, `luajit-final.log` and
`translations-final.log` in the evidence directory. A full native archive/SHA
smoke from the real public Beta 4 ZIP passed all inventory checks, missing-module
rejection, activation/restart, code rollback, truncated-download recovery, and
the external snapshot/restart/persistent-rollback path (`native-ota.log`). No
installed reader was touched. Keeping the old VERSION means this tests packaging
and installer compatibility, not offering a new update to a Beta 5 reader.

Candidate package: 1,990 inventoried files plus manifest, 2,056 ZIP entries,
8,996,740 compressed bytes and 27,840,709 expanded bytes. SHA-256:
`28c122d53fa6c6d973cdb36ace535ee34dd38720d0794854e51a361ea5d7079f`.
Every file matched its committed source and inventory size/hash. There are 20
additive runtime paths and no removed paths relative to the byte-verified public
Beta 5 ZIP. Root bootstrap/API 1, VERSION, existing artwork and fonts are
unchanged. Full imported ancestry, including the former ZIP source and original
forks, is retained. All 864 outgoing blobs were hashed and exclude the held
bitmap; Gitleaks found no secrets in the outgoing commits.

The local read-only collector at 12:30 UTC reported zero missing commits and
current pins for both components, without the reconciled snapshot warning. It
did not update the GitHub issue. The final documentation-only verification commit
is packaged/audited separately; runtime/tool/test bytes remain the candidate's.
No push, public CI run, version/tag, release, OTA publication or physical-reader
acceptance. A future publication needs a new version and OTA from public Beta 5;
never replace Beta 5's existing files. The archive is close to API 1's 2,000-file
limit: only nine slots remain, before adding future release notes/assets.

## 2026-10-25: OrbitUI 0.1.0-beta.6 release preparation and push policy

The user explicitly requested "Pusha och publicera" after the local merge and
disclosure of the remaining Bigme checks. Publish a new Beta 6 prerelease, never
replace Beta 5's assets or infer new physical acceptance. In the same request,
the user gave standing authorization to push each future requested merge after
verification/audits; new releases continue to require a separate explicit request.
`AGENTS.md` and `UPSTREAM.md` retain this distinction and the personalized Swedish
merge-summary preference. Scheduled monitoring still cannot merge or publish.

This release contains the exact already-reviewed Bookshelf `fc1103a3` and
SimpleUI `40b301f0` imports/adaptations above; no additional upstream update.
Only VERSION and release/workflow documentation change. Bootstrap/API 1,
runtime/tool/test bytes, existing assets/fonts, source pins and integration
contracts C01-C11 are unchanged. The new release note uses one more installed
file slot; respect the installed API 1 2,000-file ceiling.

Required final gates: complete sequential Lua/LuaJIT runs and translations,
clean-commit package with exact inventory/source hashes, all outgoing objects
checked for held artwork and secrets, actual public Beta 5 native installer
upgrade/restart/rollback/external snapshots, exact downloaded draft/public bytes,
anonymous API/asset/channel selection and main/tag CI. Evidence belongs in
`test-results/beta6-20261025/`. New Bigme module migration/editor/rotation,
pinning/bound ornaments, series labels/bindings, Highlights, colours/underlay,
statistics and BookOrbit/MAL/Patch Manager checks remain outstanding. Publication
results are appended only after the gates actually complete.

### Beta 6 publication verification

Published `v0.1.0-beta.6` at exact candidate
`7e573fd90a0ed6b352607568e9c3008655c31bdf` on 2026-10-25 at 17:52 UTC, as a
prerelease. `main` was fast-forwarded to the reviewed maintenance candidate and
pushed with only the exact new OrbitUI tag; unrelated local branches and all
earlier releases/assets are retained unchanged. The old standalone forks were
not modified. Final verification documentation is a separate follow-up commit,
not a replacement ZIP for the release tag.

Both full sequential local runs passed: 117 Python tests per run (four existing
external source-cache skips), all 69 root Lua test files, 478 Bookshelf suites
(zero failures; three native SQLite exclusions), all 13 original SimpleUI files,
383 module-map paths, 1,041 LuaJIT syntax files and all 43 translations.
Supplemental real SQLite runs passed 7 deck, 16 facts, 100 OPDS cases and the
SimpleUI ledger checks. Runtime/tool/test bytes remain those of `3a33fee6`;
only the root VERSION and documentation changed for release preparation.

Clean-commit ZIP: 1,991 inventoried files plus manifest, 2,057 entries,
9,001,302 compressed bytes, 27,852,531 expanded bytes. SHA-256:
`abf753248e490d742f03240b19ed4d01e0cb0b60aefe945c6f47fd61f8b01c8b`.
Every file matches committed source and manifest size/hash; all 21 added paths
are additive relative to public Beta 5, with no removed runtime paths. Stable
bootstrap/API 1 and existing artwork/fonts are unchanged. All 876 outgoing blobs
exclude the held bitmap; Gitleaks found no secrets in 188 outgoing commits.
There are only eight installed file slots left under the existing 2,000 limit.

Draft and anonymous public API/download checks verified both exact uploaded
assets, their GitHub digests/sizes and equality with the tested local build.
The actual public Beta 5 installer offered Beta 6 and passed native SHA/libarchive
inventory verification, missing-module rejection, activation/restart, code
rollback, truncated-download recovery and external runtime snapshots/restart/
persistent rollback. Local macOS/Linux and anonymous public-byte Linux runs
passed; the live run used real LuaSocket/LuaSec TLS for release discovery and
downloads. No installed KOReader or user settings were touched.

GitHub checks succeeded for [main run 40218238089](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40218238089)
and [tag run 40218233505](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40218233505),
both at `7e573fd9`; upstream watch `40218238155` also passed. Evidence:
`test-results/beta6-20261025/` (`audit-local/draft/public.json`, native OTA logs,
Lua/LuaJIT/translation/SQLite logs, Gitleaks and downloaded draft/public assets).
The focused Bigme module/editor/rotation, pinning/bound ornaments, Highlights,
colours/underlay, statistics and external-plugin checks remain open. Headless
tests and the explicit publication request are not new physical acceptance.

## 2026-10-25: Beta 7 first-run Home fix and release preparation

The user reported a fresh Android Beta 5 installation where Home was unavailable
or KOReader crashed, persisting after a KOReader update and enabling Cover
browser. The supplied logs contain a native destroyed-mutex abort from a process
preceding the logged restart, not a matching Lua traceback. Do not claim that
this identifies or resolves the native crash. Raw device logs are not committed.
The user explicitly requested implementing the proposed fix/diagnostics and
publishing a new release immediately, after the remaining uncertainty was stated.

Confirmed independently in Beta 5/Beta 6: the built-in Home post-open hook uses
`logger.info` without importing logger, only when onboarding is absent/false.
The first-run regression fails on the previous code with a nil-global error;
configured installations skip it. Import logger explicitly. Keep the real Home
facade's shared engine identity, callbacks, host-owned onboarding and optional
cached BookOrbit refresh, rather than rewriting user flags or layouts.

The existing screen-nav module now owns Home load diagnostics and guarded open.
Home action, boot, resume, reader return and reopen use the reporting loader;
full tracebacks are logged and the real first error is shown persistently.
Only newly failed non-table entries for the two owned Home/engine modules are
restored to their previously absent values. LuaJIT's real require sentinel can
be numeric; test real require failures, not only mocked userdata. Never purge
valid tables, pre-existing state or third-party modules. Partial Home cleanup
sets intentional-close before closing, does not erase a later replacement, and
reports even if cleanup/notification fails. Closing the error message cannot
schedule an automatic Home retry. Existing navigation-generation guards remain.

Contracts C01/C02/C06/C07/C08 are preserved; no settings, links, reading data,
libraries, artwork, fonts, bootstrap/API 1 or upstream pins change. No upstream
merge is included. Four existing component files change, plus one excluded test
file; no runtime module path is added. Beta 7 uses a new version/tag/asset, never
replacement bytes for Beta 5/Beta 6. The release note consumes one additional
installed file slot under the existing API 1 limit (seven remain).

All 14 targeted cases pass under Lua/LuaJIT: fresh and configured onboarding,
actual factory/facade and action, optional host setup, callback/table identity,
load/construct/show/hook errors, bounded readable notifications/full traces,
first-cause retention, real retry sentinel cleanup and owner-safe partial close.
Final gates: both full suites, translations, tests against extracted sealed
payload, source/inventory/artwork/history/secret audits, native upgrade/rollback
from actual public Beta 5 and Beta 6, exact downloaded draft/public bytes and
main/tag CI. Evidence: `test-results/beta7-20261025/`. Physical Go Color 7/Bigme
Home and native-crash acceptance remain open. Publication results follow only
after verification actually completes.

### Beta 7 publication verification

Published `v0.1.0-beta.7` at candidate
`31f287e1e6b291d95669b0d466b281e96c365bf3` on 2026-10-25 at 18:34 UTC as a
prerelease. Runtime/test fix is `42021c5e`, release preparation `31f287e1`;
main was fast-forwarded and only the exact new OrbitUI tag pushed. No upstream
pin or old fork changed; Beta 5/Beta 6 tags and assets remain immutable.

Both complete sequential local suites pass: 117 Python tests per run (four
unchanged external-source skips), all 70 root Lua files, all 14 new Home cases,
478 Bookshelf suites (zero failures/three normal native SQLite exclusions), all
13 original SimpleUI test files, 383 module-map paths, 1,042 LuaJIT syntax files,
and 43 translations with zero failures. Native SQLite supplements remain the
unchanged database code's Beta 6 results, not newly repeated Beta 7 runs.
The new first test fails on the prior code with missing global logger; all 14
pass on extracted sealed release bytes under both Lua and LuaJIT.

Package: 1,992 inventoried files plus manifest (seven API 1 slots remain),
2,058 ZIP entries, 9,007,880 compressed bytes and 27,869,078 expanded bytes.
SHA-256 `b463ad3a416f21910a6f7ec69ea66ad6a515ba6108cd77c37a560d70797d5775`.
Every file matches source and manifest size/hash; the only new path is the
Beta 7 release note and no old path is removed. Only the four documented
SimpleUI runtime files change; Bookshelf, assets/fonts, module map, source pins
and stable bootstrap/API 1 are unchanged. All 12 outgoing blobs exclude the
held bitmap; Gitleaks found no leaks in the two outgoing commits.

Draft and anonymous public API/download audits verify both exact assets and
their GitHub digests/sizes against the local build. Actual public Beta 5 and
Beta 6 installers each passed local Linux and live anonymous LuaSocket/LuaSec
discovery of Beta 7, complete native SHA/libarchive inventory checks, rejected
missing modules, activation/restart, code rollback, truncated-download recovery,
and external runtime snapshots/restart/persistent rollback. No installed reader
or live user settings were touched.

CI succeeded for [main run 40221675093](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40221675093)
and [tag run 40221674987](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40221674987),
both at `31f287e1`. Evidence: `test-results/beta7-20261025/` (before/after and
packaged Home tests, full suite/translation logs, local/live OTA logs for both
bases, exact draft/public downloads, audits and CI logs). Verification and the
new error-path contract note are documentation-only follow-ups; do not rebuild
or replace the published assets. No claim that the reported native Android
mutex abort is fixed. Physical Home retesting remains required on the affected
Go Color 7; broader Bigme/device acceptance remains open.

## 2026-10-25: Beta 8 screen-engine import fix and release preparation

The user supplied a photo from the affected reader showing
`sui_screen_engine.lua:288: attempt to index global 'Blitbuffer' (a nil value)`.
The displayed slot prefix matches the published Beta 7 ZIP. Read-only source
inspection confirmed the engine initializes a colour at module load and later
uses COLOR_WHITE without importing `ffi/blitbuffer`; Beta 5 also has this defect.
After explaining the test gap and asking to fix/publish Beta 8, the user said
"Ja". This explicitly approves this new hotfix release, not an upstream merge
or any data reset. Physical acceptance is still outstanding and disclosed.

Runtime commit `8641271c` adds exactly one local import to the engine. The new
three-case `test_home_module_load.lua` executes the entire engine, Home facade
and navigation module in isolated environments without ambient Blitbuffer/logger.
The first case fails with the exact photographed error under Lua and LuaJIT
before the import and passes afterward. Home fresh/existing settings, cached
state/callbacks, exports/shared identity and Custom Screen separation are covered.
Native widget construction/rendering and surrounding services remain stubbed.
Beta 7's 14-case extracted-open suite is retained; it did not cover module-level
initialization, which is why that suite missed this defect.

Relevant contracts: C02 navigation, C06 module compatibility, C07/C08 preserved
preferences/data and C09 explicit publication. No contract is relaxed. No
upstream import or pin change, no module-map path change, no font/artwork,
bootstrap/API, library, migration or external-provider change. Existing public
assets/tags remain immutable. The versioned candidate adds only its new release
note to the installed inventory (expected 1,993 files plus manifest, six slots
below API 1's 2,000-file limit). Preserve all existing assets/licenses.

Required gates: both complete Lua/LuaJIT suites, translations, packaged-byte
Home regressions, clean-commit inventory/source equivalence, outgoing held-artwork
and secret audits, actual public Beta 5/Beta 7 native installers against local
and public bytes, draft/public digest checks and main/tag CI. Evidence:
`test-results/beta8-20261025/`. The one-line change fixes the reproduced Lua
load error, not a demonstrated cause of the earlier native Android mutex abort.
Affected Go Color 7 Home retesting and the wider Bigme checklist remain open.

### Beta 8 publication verification

Published `v0.1.0-beta.8` at candidate
`50edce78b4691fc6b14db975c207e98ccdf26958` on
2026-10-25 at 19:00:36 UTC as a prerelease. Both complete local Lua/LuaJIT runs
and all 43 translation checks passed. Each full run covers 117 Python tests
(four unchanged source-cache skips), 71 root Lua test files, 478 Bookshelf
suites (zero failed, three normal native-SQLite exclusions) and all 13 original
SimpleUI test files. Module map 383; LuaJIT syntax 1,043. Beta 6's supplemental
database tests remain the latest; no database code changes in this import-only fix.

The three new whole-module cases fail with the exact line-288 error before the
import and pass afterward in both interpreters. Both these and the existing 14
first-run/error/retry cases also pass against extracted sealed ZIP bytes.
Additional Luacheck inspection of the complete engine, Home and navigation
reports no undeclared globals after explicitly allowing KOReader's intentional
G_reader_settings/G_defaults host globals. Native construction/rendering remains
stubbed; no physical Home or native Android abort acceptance is inferred.

The clean-commit ZIP has 1,993 inventoried files plus manifest (2,059 ZIP entries,
27,881,470 expanded bytes). Every inventory size/hash matches candidate Git.
Only the new Beta 8 release note is added; no Beta 7 path is removed. The engine
diff is exactly one local import; bootstrap/API 1, module map, source pins,
Bookshelf, fonts, artwork, settings/migrations and external integrations remain
unchanged. Six installed API 1 file slots remain. All nine outgoing blobs were
hashed for the held bitmap; absent. Gitleaks scanned two commits: no leaks.

The actual public Beta 5 and Beta 7 native installers each pass local and
anonymous public-byte Linux/LuaSec runs: real TLS release discovery, complete
native SHA/libarchive inventory verification, missing-runtime rejection,
activation/restart/code rollback, truncated-download recovery, complete external
snapshot/native verification, adoption restart and persistent rollback. Each
uses an isolated temporary installation, not a user's reader. Docker was started
only for this validation; its task-owned container is removed and the previously
stopped desktop runtime restored after verification.

Main/tag CI runs `40223707342` and `40223707268` passed for the exact candidate.
Existing Node action runtime and ubuntu-latest migration notices are warnings,
not test failures. Draft and anonymous public ZIP/checksum downloads match the
sealed local build byte for byte, including GitHub's asset digests. ZIP SHA-256:
`ebd0271530e30cb2173ca9e87c974351321b60b7c314ffc38179e3f111b82bca`;
9,012,570 bytes. Previous tags/assets were not changed. All evidence is under
`test-results/beta8-20261025/`. Follow-up verification/contract documentation
does not rebuild or replace the immutable published release. Physical retesting
on the affected Go Color 7 and the wider Bigme acceptance checklist remain open.

## 2026-10-25: Bookshelf navigation and profile setup (local, unpublished)

The user confirms Home works after Beta 8, then reports that a navbar custom
action bound to `open_bookshelf_prose` works on Bigme but only changes the
indicator on a fresh Boox. The code checks `Profiles.get("prose")` and returns
false silently when absent/disabled. Fresh OrbitUI deliberately seeds only the
reader's own home-based section, not Bigme's old prose/comics folders. A section
named Prose has a generated stable ID, not automatically the old `prose` ID.
The old SimpleUI Library default is the file browser, not Bookshelf.

The user explicitly requests Bookshelf as a removable default navbar item, a
simple way to open it without a profile and easy profile/chip targeting. This
authorizes the local implementation, not a release, new upstream import or
device-data rewrite. Branch: `fix/bookshelf-navigation-20261025`; VERSION stays
Beta 8 and published assets/tags remain unchanged. No push/publication was asked
for this feature. The user received the root cause and preservation/default plan.

Host-owned changes only: wrap config defaults/catalogue without touching saved
bars, register generic `orbitui_bookshelf`, distinguish File browser, use the
existing native opener for no fixed profile and the deferred shelf coordinator
for an explicit profile, preserve profile/legacy IDs, and retain specific-tab
indicator priority over the generic button. Fix the old nil==nil tab resolution
ambiguity exposed by an unscoped Bookshelf view. Generic long-press opens the
new shared Bookshelf navigation menu, also accessible from the settings hub.
Saved target uses additive `orbitui_bookshelf_profile`; absent means no forced
profile, not resetting the native last view.

The section editor now offers Add to navigation bar / Use for Bookshelf button,
and the navigation menu exposes destination and Profiles and chips. A full bar
requires the user to choose a replacement; cancellation changes no slots.
Existing bars and explicit removals remain saved. Missing/disabled legacy profile
handlers show a repair/configuration menu; no fabricated profile, unrelated
fallback or settings/data reset. Swedish labels have English fallbacks. Native
component source, source pins, module map, assets/fonts, bootstrap/API, library
data and external sync owners are unchanged. No new runtime path/file is added.

Contracts C02/C06/C07/C08/C09 are preserved and C02 documents the user's new
default/repair expectations. The 12-case focused suite loads complete config/QA
modules with native services stubbed, actual model/profiles/adapters/bridge and
the real deferred coordinator. It covers the photo's legacy action, profile
selection and chips, saved bars and overrides, full-bar replacement, persistent
removal, disabled/missing targets, scoped indicators, simulated reader parking
and superseded requests. Full Lua/LuaJIT, translation and local-package gates
are required. Evidence: `test-results/bookshelf-navigation-20261025/`.
All physical Boox/Bigme navigation/reader-transition checks remain open; the
earlier user-confirmed Home result is not acceptance of this new feature.

### Local navigation verification

Candidate `2366897f58d50518bdd4ce623c0ebd37bca8a13f` is committed locally.
Both complete test gates passed: 117 Python tests/four unchanged external
source-cache skips per run, 478 Bookshelf suites/zero failures/three normal
native-SQLite exclusions, all 13 original SimpleUI files. Module map 383;
LuaJIT syntax 1,044. After final display-label/test refinements, all 72 root
Lua files pass again under both interpreters. Translations: 43, zero failures.
The final 12 navigation cases also pass under both interpreters against the
extracted sealed package, with `ORBITUI_TEST_ROOT` selecting packaged adapters,
model/config/QA/bridge sources. Includes an empty profile inventory as well as
the default home-based section. This is still not a physical KOReader session.

The clean local validation package contains the same 1,993 inventoried files
plus manifest as public Beta 8; no path was added or removed. Every hash/size
matches the candidate Git source. Runtime changes are limited to six existing
host adapters and owned translations. All embedded component files, source
pins, module map, bootstrap/API 1, assets/fonts and VERSION are unchanged.
Six installed file slots remain. All 15 candidate blobs were checked against
the held bitmap; absent. Gitleaks scanned the feature commit without leaks.
Local ZIP SHA-256:
`10fd487498b313add62e47c719f52b2456a069944c8eb9ebd819bf6f56681735`,
9,020,151 bytes. It is a same-version validation ZIP only, not a public update
or install recommendation. Follow-up package-test support and evidence docs
do not change that candidate runtime. Evidence is retained under
`test-results/bookshelf-navigation-20261025/`.

No merge to main, remote push, version bump, tag, public release, OTA publication
or user-device mutation occurred. Publication needs a new explicit request.

## 2026-10-25: Beta 9 navigation release preparation

After the local implementation/verification and explicit disclosure of remaining
device checks, the assistant asked whether to push and publish this as Beta 9.
The user replied "Ja". This authorizes the audited feature push and new Beta 9
prerelease, not changes to existing public assets or an upstream import. Runtime
feature commit `2366897f` and supplementary tests/docs `35fa08fb` are retained.

Keep C01-C11, existing profile IDs and saved bars/settings/data. No component,
source pin, asset/font, module-map path or bootstrap/API change. The release
only adds one installed note (expected 1,994 inventoried files plus manifest,
five remaining API 1 file slots). Do not remove assets/licenses or raise only
the producer's installer limit. VERSION advances to `0.1.0-beta.9` separately
from the feature commits. README, shared controls, OTA and testing docs identify
the upgrade behavior and the explicit enablement needed for saved bars.

Gates: both complete Lua/LuaJIT suites, translations, packaged navigation and
Home regressions, clean-commit source/inventory/hash equivalence, all outgoing
held-artwork/secret checks, exact draft/public downloads and main/tag CI. Exercise
the real public Beta 8 and Beta 5 native installers against local and anonymous
public bytes, including discovery, verification, restart, rollback, missing-module
and truncated-download rejection and external snapshot/adoption/rollback.
Evidence: `test-results/beta9-20261025/`. All new Boox/Bigme navigation, touch,
rotation, parked-reader and dock-indicator device checks remain outstanding.
The earlier user-confirmed Beta 8 Home result is retained, not generalized to
new-flow acceptance or a diagnosis of the native Android mutex abort.

Pre-tag documentation refinement: older immutable releases cannot recognize
`orbitui_bookshelf` and their existing unknown-action pruning can remove that
new button after rollback. Release/OTA notes disclose that an older saved-profile
action may need to be reselected, and recommend backing up navigation choices.
No old public code/assets are changed. This is not a reading-data rollback.

### Beta 9 publication verification

Published `v0.1.0-beta.9` at candidate
`a4bb9acbab883b8510924de19a67f6414ed3df32` on
2026-10-25 at 19:49:26 UTC as a prerelease after the explicit user approval.
Both complete local Lua/LuaJIT gates passed: 117 Python tests/four unchanged
source-cache skips per run, 72 root Lua files, 478 Bookshelf suites/zero failures/
three normal native-SQLite exclusions, all 13 original SimpleUI files. Module
map 383; LuaJIT syntax 1,044; translations 43/zero failures. All 12 navigation,
three whole-engine Home-load and 14 first-run/error/retry cases also pass against
the final extracted release ZIP under both interpreters. Luacheck of all seven
changed runtime files reports zero undeclared globals after explicitly allowing
G_reader_settings. No database/component source changed; Beta 6's recorded
SQLite/ledger supplements remain latest, not newly repeated Beta 9 evidence.

The clean candidate ZIP contains 1,994 inventoried files plus manifest, 2,060
entries and 27,919,804 expanded bytes. Every inventory size/hash matches Git.
Only the new release note is added; no Beta 8 path is removed. Runtime changes
are six existing host adapters and owned translations. Components, source pins,
module map, main entry/bootstrap/API 1, artwork/fonts and existing data paths are
unchanged. Five installed file slots remain. All 31 outgoing blobs exclude the
held bitmap; Gitleaks scanned four outgoing commits without leaks.

Actual public Beta 8 and Beta 5 installers each pass local and anonymous
public-byte Linux/LuaSec runs: real TLS release discovery, complete native
SHA/libarchive inventory verification, missing-runtime rejection, activation,
restart/code rollback, truncated-download recovery, full external runtime
snapshot/native verification, adoption restart and persistent rollback. These
are isolated temporary installations, not user devices. The task-owned Docker
container is removed and the previously stopped desktop runtime restored after
validation, provided no unrelated containers were started meanwhile.

Main/tag CI runs `40227604923` and `40227604800` passed for the exact candidate.
Existing Node action runtime and ubuntu-latest migration annotations are warnings,
not failures. Draft and anonymously downloaded public ZIP/checksum assets match
the sealed local build byte for byte and GitHub's asset digests. ZIP SHA-256:
`3a2c8fab178e01ff99822b8b8a6105bc4d70228f42a2f6fa227a6275403842c9`,
9,025,063 bytes. Previous public tags/assets were not changed. Evidence:
`test-results/beta9-20261025/`. Follow-up verification docs do not rebuild or
replace published assets. The new Bookshelf profile/navigation flow remains
unverified on physical Boox/Bigme devices; the earlier Home confirmation is
retained without claiming native Android mutex-crash resolution. Existing bars
need explicit Bookshelf enablement; code rollback's unknown-action pruning risk
is disclosed in the immutable release/OTA notes.

## 2026-10-25: Reviewed Bookshelf 6.0.2 merge and Beta 10 preparation

The user explicitly requested "Merga upstream, pusha ouch publicera". This
authorizes the reviewed merge, audited push and a new prerelease, not rewriting
any published tag/assets. Start from clean main `97b7948a` on dedicated branch
`maintenance/upstream-late-20261025`. The read-only collector at 22:43 UTC finds
eight incoming Bookshelf commits; issue #1's older 17:48 result lists only five.
Review the exact Git delta, not the older dashboard count. Bookshelf advances
from `fc1103a3de9fd19eea89a53c5f1f1b0e8175682a` to
`5f726c253c5cb4d5a2a2137af52731562e1cb9b7` (6.0.2), net 22 changed paths.
SimpleUI is unchanged at `40b301f0f5e4466021d00b4e47ac8c09bb65ac8c`.

Unsquashed subtree import `0db81b46885f5802414253a912f5a34c0c670a4a` has no
text conflicts. Review overlapping repository/hero/widget/fullscreen paths for
all C01-C11 contracts nonetheless. No upstream feature is omitted. Import the
metadata batch-row invalidation (single/bulk refresh, stale sweep and cover
revert), hero memo invalidation after extraction, clipped colour-shadow fix,
measured status-strip bounds, covered-window tick suppression, editor key focus
and public module book helpers. Preserve all host profile/navigation, shared
detail/ReaderUI, dock, underlay ownership, series/binding/rating/title/ornament,
Home first-run/cold-load, settings/storage and external-owner behavior.

No production adaptation is needed after the import. Update the pinned upstream
SHA and runtime-version test fixture separately; retain all original component
tests. Add four whole-module helper/opener integration cases for live shelf
delivery/deferred fullscreen close, hydrated details, ordinary ReaderUI fallback
and adopted shelf-context ownership. Native rendering/lifecycle is stubbed.
No runtime path is added, so the generated 383-path map remains unchanged.
Original fork provenance/tags, SimpleUI pin, stable bootstrap/API 1, fonts/artwork,
profile/chip IDs, reading data and external sync ownership stay unchanged.

The user has confirmed Home and Beta 9 Bookshelf navigation work on Boox.
The new cover-loading/indexing report is not yet physically retested; upstream's
metadata fix addresses a reproduced stale-row cause, not every missing cover.
No automatic rescan, cache reset or data migration is introduced. Broader device
checks and the earlier unproven native Android abort remain open.

Required release gates: full sequential Lua/LuaJIT and translations, new native
and sealed-byte integration/Home/navigation tests, clean-commit source/inventory
checks, every outgoing Git blob checked for held artwork, Gitleaks, actual public
Beta 9/Beta 5 native OTA upgrade/restart/rollback and external adoption, exact
draft/public assets and main/tag CI. Evidence: `test-results/beta10-20261025/`.
The release note adds one installed path; expect 1,995 inventoried files plus
manifest, four slots below the installed API 1 2,000-file ceiling. Preserve all
assets/licenses and keep existing public releases immutable. Publication results
will be appended only once verified.

### Beta 10 publication verification

Published `v0.1.0-beta.10` at exact candidate
`0a2ea22bcc37c0739351c52e841e17fa8b22cf5c` on
2026-10-25 at 22:58:45 UTC as a prerelease. Import `0db81b46`, separate pin/
integration tests `66fe1b4a` and release preparation `0a2ea22b` are retained.
Main was fast-forwarded and only main plus this exact new OrbitUI tag pushed
atomically; unrelated local branches, old tags/assets and standalone forks
remain unchanged. No production adaptation beyond the reviewed import is needed.

Both complete sequential Lua/LuaJIT gates pass: 117 Python tests per run/four
unchanged source-cache skips, all 73 root Lua files, 482 Bookshelf suites/zero
failed/three normal SQLite exclusions, all 13 original SimpleUI files. Module
map 383, LuaJIT syntax 1,049, translations 43/zero failures. New native suites
cover the incoming regressions. Four whole-module opener/helper, 12 navigation,
three Home cold-load and 14 first-run/error/retry cases also pass on extracted
sealed ZIP bytes under both interpreters. Native services/rendering are stubbed.
Luacheck's global checks pass on eleven changed runtime modules with the explicit
host globals; broader optional style lint still reports unused/shadowing warnings.
Fresh real-SQLite supplements pass 7 deck, 16 facts, 100 OPDS cases and the
SimpleUI daily/year/page/invalidation checks using the pinned KOReader helpers.

The clean-commit ZIP has 1,995 inventoried files plus manifest, 2,061 entries,
27,950,557 expanded bytes and 9,035,141 compressed bytes. Every hash/size matches
candidate source; only the new release note is added, no Beta 9 path removed.
Four installed API 1 file slots remain. Bootstrap/API 1, host/SimpleUI runtime,
module map, fonts/artwork and data paths are unchanged. Bookshelf equals the
reviewed subtree tree; only its upstream pin advances, with original provenance
retained. All 42 outgoing blobs exclude held artwork; Gitleaks finds no secrets
in ten non-merge commits. ZIP SHA-256:
`d461f9afd5a1e122df4bacfa44b4e6595b27a024acc0e43b9bd78739d21cdd43`.

Draft and anonymously downloaded public ZIP/checksum bytes, API asset digests/
sizes and exact target SHA all match. Actual public Beta 9 and Beta 5 installers
each pass local Linux and anonymous public-byte LuaSocket/LuaSec discovery,
native SHA/libarchive inventory verification, missing-module rejection,
activation/restart/code rollback, truncated-download recovery and complete
external runtime snapshot/adoption/restart/persistent rollback. Local macOS
Beta 9 also passes every phase. No installed reader/settings are touched. The
task-owned container is removed; the previously stopped Docker Desktop runtime
is restored after confirming no unrelated containers are running.

Main/tag CI runs `40242459682` and `40242459905` pass for the exact candidate;
monitor `40242459666` also passes, reporting both upstreams current at 22:56 UTC.
Node action-runtime and ubuntu-latest migration annotations are warnings.
Evidence: `test-results/beta10-20261025/`. Follow-up verification docs do not
rebuild/replace immutable release bytes. The user-confirmed Home/navigation
results are retained, but new cover loading/refresh, colour repaint, overlay
minute ticks, module-key/rotation and wider Bigme/external-plugin acceptance
remain open. No automatic index/reset, measured speedup or native Android
mutex-crash diagnosis is inferred.

## 2026-10-26: Reviewed Bookshelf 6.0.3 and SimpleUI follow-ups (not released)

User requested "Merga upstream igen". Standing authorization includes the audited
push to main, not a version/tag/release. Start from clean public `84597df5` on
`maintenance/upstream-20261026`. Collector at 17:37 UTC and issue #1's 17:27
report agree: Bookshelf `5f726c253c5cb4d5a2a2137af52731562e1cb9b7` to
`c37580a1ca5040d2423e45b9bdd429776117f3c1` (6.0.3), five commits/30 changed
paths; SimpleUI `40b301f0f5e4466021d00b4e47ac8c09bb65ac8c` to
`96fcd0f024fd62fe88f6b534b4e856f3c5fd3a81`, three commits/51 paths. Review
all runtime changes, original tests, removed/added paths and refreshed locales;
validate the complete catalogues rather than treating line-reference churn as
new features. Neither import adds a runtime module; the 383-path map is unchanged.

Unsquashed Bookshelf import `c8c0f394` resolves underlay conflicts by combining
sleep-screen clear/rotation detection with OrbitUI's existing owner-safe UI
hooks/window cleanup/nil-result handling. Screen hooks inherit that ownership:
restore only our exact wrappers and leave later wrappers with retired inners
inert. Import the new non-destructive On the shelf switch/loader fix and the
fullscreen-strip respect for disabled swipe-back. Preserve shelf/profile scopes,
dock, bindings, series/rating/title/ornament and external integration seams.

Unsquashed SimpleUI import `eeb5e012` resolves engine/config/layout conflicts
without reinstating shared top margins, widget reuse or automatic percentage
snapping. Keep host-level wallpaper painting behind all chrome, move the
independent titlebar-button opacity into the new submenu, retain preset keys and
old opacity aliases, and preserve Swedish fork strings. Single-form catalogues
keep valid plural forms and known rollback strings; deduplicate active/obsolete
entries mechanically without adding validation exceptions.

Adaptation/tests `dff46bce`: fixed-grid stacking remains opt-in; old layouts keep
their renderer, explicit Free widths activates model 3, saved percentage reads
do not snap, and layout fingerprints include mode/stack. Adopt the one-raster
wallpaper renderer with complete partial-allocation cleanup, five-second failed
decode retry, safe legacy paint facade/show API and copy-only library-opacity
migration. Preserve the old show flag and explicit new opacity precedence.
Later-page stats request flags are set only after successful data reads; retain
the new live DB handoff. Flow side covers counter-invert at paint time without
mutating their shared source. Fast Book Closing is optional/off by default;
existing generation guards, real ReaderUI paths and sync owners remain intact.
All C01-C11 are preserved; no migration of book data/settings paths or artwork.

Six new merge cases load the whole wallpaper module and real Bento packing,
plus focused stats/Flow methods; two extra real page-builder geometry cases and
one native underlay ownership case cover the merge seams. Existing test fixtures
now supply new layout helpers/mode APIs and the renamed raster source, retaining
their assertions. The Bookshelf version fixture advances to 6.0.3. Complete
Lua/LuaJIT, translation, sealed-package/native OTA and outgoing history/artwork/
secret gates follow; exact verification/push results will be appended afterward.
Evidence: `test-results/upstream-20261026/`. VERSION remains Beta 10; no new
release note/tag/assets or public OTA update. A same-version validation package
is not a replacement for the immutable published Beta 10 ZIP. Physical Bigme/
Boox editor/free-width/stack/rotation, wallpaper/night, wake restoration, shelf
modules and optional Fast Book Closing/external-plugin tests remain open.

### Additional SimpleUI picker commit observed during verification

The later collector observes one new SimpleUI commit, `b1580f90b2e17cf03a66c744c323a1df66d77100`,
after the initial target was reviewed. Review all 24 changed paths and include
it separately, conflict-free and unsquashed, in import `65ca534e`. There are now
four incoming SimpleUI commits and 67 net changed paths from `40b301f0`.
The Add Module picker groups Books/Statistics/Shortcuts/Extras/Other, inherits
instance categories and leaves unknown/external host modules reachable in Other.
No module ID, settings, layout or default enablement changes. Focused tests
`0acdd843` verify category lookup/localization and the real picker builder,
external/instance add paths and two-level navigation. Eight new merge cases in
total. Re-run complete sequential gates and validate a fresh exact candidate ZIP;
the earlier initial-target logs/packages are not final-target evidence.
The Swedish compiled-catalog audit confirms no changed surviving translation;
30 retired native labels are retained as obsolete source entries rather than
compiled into the new menu. Original localized fork entries remain available.

### Final October 26 verification and push (no publication)

Clean candidate `706b73419dc16a03f875d4166ba068ab568a30eb` is fast-forwarded
to main and pushed after complete final-target verification. Exact imported
tips are Bookshelf `c37580a1ca5040d2423e45b9bdd429776117f3c1` and SimpleUI
`b1580f90b2e17cf03a66c744c323a1df66d77100`; no later moving tip is implicitly
approved. Both full sequential `scripts/test.sh` runs (Lua and LuaJIT) pass:
117 Python tests/four existing external-source cache skips per run, 74 root
Lua test files, 483 Bookshelf suites/zero failures/three normal SQLite exclusions
and all 13 original SimpleUI files. Module map remains 383; syntax verifies
1,051 Lua files; all 43 translation catalogues pass without baseline exceptions.
Fresh actual-SQLite supplements pass 7 deck, 16 facts, 100 OPDS cases and the
SimpleUI daily/year/page/invalidation ledger. Swedish catalogue comparison
preserves every surviving active fork translation.

Sealed-byte tests under both interpreters pass 12 navigation, three whole-Home
cold-load, 14 first-run/error, four whole-module book-helper, eight new merge and
15 real Bento geometry cases. The native underlay suite passes 16 cases including
clear/rotation wake tracking, nil-result preservation and owner-safe teardown/
reinstallation. These rendering/native service fixtures remain headless.

The clean-source validation ZIP has SHA-256
`119cd716929a3797c0d8cc13ff13ccd74323994ed2a37a433481fede8b80a6e4`,
9,265,056 bytes, 1,995 inventoried files plus manifest, 2,061 ZIP entries and
29,032,084 expanded bytes. Every file hash/size equals committed source; no
installed path is added/removed. Four installed API 1 file slots remain.
Host/core/adapters/bootstrap/assets/fonts/VERSION are unchanged. All 194 outgoing
blobs exclude held artwork; Gitleaks scans 13 non-merge commits without leaks.
Actual public Beta 9's native installer passes local macOS SHA/libarchive
inventory, missing-module rejection, activation/restart/code rollback,
truncated-download recovery and full external snapshot/adoption/restart/
persistent rollback against these candidate bytes. No reader installation,
settings, live release channel or Docker state is changed.

Evidence: `test-results/upstream-20261026/` final `lua-current.log`,
`luajit-current.log`, `translations-current.log`, `sealed-current.log`,
`native-ota-current.log`, `audit-current.json` and `gitleaks-current.log`.
Initial-target logs/packages are historical, not final-candidate evidence.
This same-version validation ZIP is not published or substituted for Beta 10:
VERSION remains `0.1.0-beta.10`; tag `v0.1.0-beta.10` remains at `0a2ea22b`
and public ZIP SHA remains
`d461f9afd5a1e122df4bacfa44b4e6595b27a024acc0e43b9bd78739d21cdd43`.
No version bump, new tag, release note, release assets or live-OTA publication.
Follow-up verification documentation does not rebuild/replace candidate bytes.
Physical Bigme/Boox editor/free-width/stack/rotation, wallpaper/night, wake,
module switches and optional Fast Book Closing/external-plugin checks remain
open. No measured performance gain or native Android crash fix is inferred.

Main CI [40374393514](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40374393514)
passes both Lua/LuaJIT jobs at candidate `706b7341`, including integration,
translations, packaging and native OTA checks. Node action-runtime and
ubuntu-latest migration annotations are warnings, not failures. This follow-up
changes only PROJECT_CONTEXT, TESTING and MERGE_LOG; runtime and the sealed
validation ZIP stay byte-identical. Audit follow-up outgoing documentation
blobs and Gitleaks before pushing; do not rebuild or publish a release.

## 2026-10-26: Beta 11 shared updater and safe GitHub diagnostics preparation

User sends a photo of the Bookshelf update page labelled OrbitUI, showing
`Installed: v6.0.0`, standalone Stable release/channel/wake/changelog controls
and `core/orbitui_http.lua`'s nested generic HTTP 403 trace. Read-only diagnosis
finds that the updater shim blocks native installers but the native settings
builder still constructs its standalone rows. HTTP discards GitHub's headers/
reason and Trapper stringifies errors. The endpoint returns HTTP 200 from this
host; the photo alone cannot prove the reader's cause. GitHub's primary docs
confirm 403/429 rate-limit signals and retry/reset header semantics.

User explicitly approves both the fix and publication. Start from clean public
`25a2e7ab` on `fix/orbitui-updater-beta11-20261026`; version `0.1.0-beta.11`.
No new upstream review/import/pin is implied. Include the already-reviewed
October 26 Bookshelf `c37580a1` / SimpleUI `b1580f90` integrations. Clarification:
Fast Book Closing exposes the existing internally-disabled Home soft-park as a
saved option; it does not replace Bookshelf's separate hot-return/deferred-close.

Add one two-line component seam: `_updateSubItems` delegates to an optional
updater `menuItems` before native menu construction. Host/root menus share real
OrbitUI version, retained preview/daily choices and existing confirmed recovery.
Hide misleading standalone rows, do not rewrite their settings or re-enable
their installers. The standalone fallback remains test-covered.

HTTP errors carry safe status and bounded timing only, never raw bodies/headers/
signed URLs. Trapper converts them to localized messages and serializable safe
metadata. Confirmed 403/429 limits use the longest valid retry/reset wait (one-day
cap/minimum one minute); failed checks do not poll again within that session's
deadline. Generic 403s explicitly remain unconfirmed rate limits. No bypass,
automatic retry loop, credentials or security relaxation. TLS/CA/hostname,
allowlisted redirects, byte limits and deferred activation remain unchanged.

Five added regression cases extend existing suites: HTTP header/body/error and
language checks, Trapper cooldown expiry/no-activation, hosted/standalone real
menu builders and root checkbox callbacks. Complete sequential gates, native
older/public installers, sealed tests and release audits follow. Evidence:
`test-results/beta11-20261026/`. No runtime module added; module map stays 383.
Only the Beta 11 release note adds an installed path, leaving three API 1 slots.
Physical Boox/Bigme update dialogs and underlying network rejection, reader/
suspend/rotation and upstream editor/wallpaper/module acceptance remain open.
This is an explicitly approved prerelease, not a device-acceptance claim.

### Beta 11 publication and final verification

Publish prerelease `v0.1.0-beta.11` at exact candidate
`0310601522ac97925915438ca424e3e555799c57`, 2026-10-26 18:43:59 UTC, after
explicit user approval. Main and this exact tag are pushed. Both complete
Lua/LuaJIT gates pass 117 Python tests/four unchanged source-cache skips, 74 root
Lua files, 483 Bookshelf suites/zero failures/three normal SQLite exclusions and
all 13 original SimpleUI files. Module map 383; syntax 1,051; translations 43/
zero failures. No exceptions added. All 8 HTTP, 8 update/Trapper, 4 real-menu/
root-dialog, 12 navigation, 3 whole-Home, 14 first-run/error, 4 book-helper,
8 October 26 and 15 real Bento geometry cases also pass on sealed bytes under
both interpreters. Three changed host modules pass undeclared-global lint with
explicit G_reader_settings; this is not a broad style-lint claim. Actual-SQLite
checks from unchanged October 26 data code remain latest, not newly repeated.

Every package file matches clean committed source and manifest hash/size. Only
the Beta 11 note adds an installed path; none is removed. Inventory 1,996 plus
manifest leaves three API 1 slots, 2,062 entries, 29,058,002 expanded bytes.
Bootstrap/API/assets/fonts/artwork/module-map/pins unchanged since reviewed main;
only component change is the optional two-line menu delegation. All 15 outgoing
blobs exclude held artwork; Gitleaks scans one commit with no leaks. ZIP SHA-256
`b9a78e82ffdceaf3b2d0c77da1ec4e7c60319df4eaab60a81dfacd0b68b9b391`,
9,274,291 bytes. Draft and anonymously fetched public ZIP/checksum bytes and API
asset digests/sizes match exactly. Inspect draft ID `424624609` when the draft
by-tag API returns 404; anonymous published by-tag access succeeds.

Actual public Beta 5/9/10 native installers pass local Linux SHA/libarchive
inventory, missing-module rejection, activation/restart/code rollback,
truncated-download recovery and full external snapshot/adoption/restart/
persistent rollback. macOS Beta 9 also passes all phases. Anonymous published-byte
LuaSocket/LuaSec TLS discovery/download and all native phases pass from Beta 9
and Beta 10. These are temporary installations; no reader/settings/data touched.
Main/tag CI [40379763363](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40379763363)/
[40379764285](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40379764285)
pass at the exact candidate. Node/runner migration annotations are warnings.
Evidence: `test-results/beta11-20261026/`.

Older tags/assets remain unchanged. Follow-up PROJECT_CONTEXT/TESTING/MERGE_LOG/
UPSTREAM edits record results only, with outgoing held-artwork/secrets audit;
they do not rebuild/replace published bytes. Physical Boox/Bigme update menu,
network cause, editor/free-width/stack/rotation, wallpaper/night, wake, modules
and optional Fast Book Closing/external-plugin acceptance remain open. No bypass,
measured performance gain or native Android crash fix is claimed. An old updater
still receiving 403 must wait/retry or use the complete release ZIP, preserving
hidden version directories/settings; new error UI cannot repair old running code
before installation.

## 2026-10-26: Beta 12 Android-safe local covers preparation

User reports missing and intermittently pixelated Bookshelf covers on the Boox
despite latest KOReader/OrbitUI and repeated metadata indexing, then confirms
Android safe mode is enabled. Read-only diagnosis finds the default safe-mode
gate disables all Bookshelf BIM background work; metadata indexing can leave
known coverless rows and single/bulk refresh deletes old rows/caches before the
blocked rebuild. User explicitly approves the fix and immediate new release.

Start from clean public `70e5a1fd` on `fix/android-covers-beta12-20261026`;
version `0.1.0-beta.12`. No upstream merge/pin advance. Add one host adapter and
minimal optional single/bulk refresh hooks (one/four component lines), plus
host UI wiring and two Swedish messages. Preserve C01-C11, particularly C03/
C04/C06/C08/C09: no ReaderUI lifecycle shortcut or process-wide require/cache
replacement, no progress/settings/sidecar/link/artwork reset, no automatic
network, no legacy installers and unchanged bootstrap/API 1.

Foreground local work is hero-first and one document per turn, capped at 256
queued/attempt entries, cancellable on page/foreground/reader/suspend/close.
Prepare document metadata and an adequately sized original/custom cover before
an SQLite savepoint; insert only missing rows and UPDATE only derived fields.
Retain accurate pages/ignore flags/old cover on absent replacement; rollback on
failure. Native pixel buffers are freed, compressed buffers transfer to the
KOReader SQLite BLOB binder (which frees its pointer) or are freed on failure.
Borrow the matching live document read-only, never reload/close it. Do not use
BIM's subprocess-only extractor: it changes global crengine cache settings and
prewrites a placeholder row. Non-Android/native fallback remains unchanged.
The Bookshelf full-library scanner now explains page-by-page safe extraction
instead of forking while safe mode is enabled. SimpleUI's separate Android
background extraction remains blocked; this is not a new full-library/Home
indexer. New callbacks do not take over external KOReader/plugin scanners.

Primary API review uses official KOReader BookInfo/BookInfoManager/UIManager/
Notification and koreader-base zstd source, saved in ignored evidence. The
cover API honors existing custom covers; original dimensions constrain scaling.
Existing large thumbnails are not downgraded. Native load/scale/SQL failures
leave old data/cache intact, settle only in bounded session memory and remain
retryable. Single and real bulk-refresh branch tests execute the component
seams before any native deletion. Actual-SQLite BLOB commit/failed-row rollback
also pass with KOReader's binding; complete gates and publication follow.

Only adapter + release note add installed paths (two of the three remaining
API 1 slots); do not raise only producer limits, remove resources/licenses or
change old bootstrap to make room. Physical Boox/Bigme cover quality, UI pause/
memory, suspend/rotation, menus/reader return and prior acceptance gaps remain
open. A single synchronous native document load is not cancellable midway;
headless tests do not prove damaged-document/native Android crash containment.
This is an explicitly requested prerelease, not a device-acceptance claim.

### Beta 12 publication and final verification

Publish user-requested prerelease `v0.1.0-beta.12` at exact candidate
`ea8bbaf0296f32c2bfd5a40460e219a3b3f2318f`, 2026-10-26 20:42:10 UTC.
Fast-forward/push main and this exact tag only. Complete local sequential suites
pass 117 Python/four existing external-source skips, 483 Bookshelf/zero failures/
three normal SQLite exclusions and 13 SimpleUI files. All 75 root Lua files are
also rerun against final committed code under Lua/LuaJIT. Exact main/tag CI
[40397510037](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40397510037)/
[40397510247](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/40397510247)
each pass both complete clean-source test jobs, translations, packaging and
native OTA gates. Node/runner migration annotations remain warnings.

New Android suite: 26 cases under each interpreter, 27 with actual KOReader
SQLite binding, including native BLOB ownership and failed-write savepoint
rollback. Sealed-byte runs repeat these and HTTP/update/menu/navigation/whole-
Home/first-run/book-helper/October 26/Bento regressions under both interpreters.
Module map 383; syntax 1,053; translations 43/zero failures. Three changed host
modules pass undeclared-global lint with explicit G_reader_settings; this is not
a broad style-lint claim. No source-cache or SQLite exclusions are added.

Clean-source inventory audit matches every package file/hash/size to candidate
Git. Only adapter and Beta 12 note add installed paths; none removed. Inventory
1,998 plus manifest leaves one API 1 file slot, with 2,064 ZIP entries and
29,092,889 expanded bytes. Bootstrap/assets/fonts/artwork/pins/module map remain
unchanged. Thirteen outgoing blobs exclude held artwork; Gitleaks scans the
one candidate commit without leaks. ZIP SHA-256
`fe54c593c9b06fc0ba6055c82d6544a2807ee7e96efd9fd158b9c40d41dbafe2`,
9,286,577 bytes. Draft ID `424742800` and anonymous published ZIP/checksum bytes,
asset digests/sizes match exactly. Older public Beta 9/11 assets are reverified;
no older tag/release is modified.

Actual public Beta 5/9/11 native installers pass local Linux SHA/libarchive
inventory, missing-module rejection, activation/restart/code rollback,
truncated-download recovery and external snapshot/adoption/restart/persistent
rollback. Anonymous published-byte LuaSocket/LuaSec TLS discovery/download and
all native phases pass from Beta 9 and Beta 11. Temporary installations only;
no reader settings/data touched. Evidence: `test-results/beta12-20261026/`.

Follow-up PROJECT_CONTEXT/TESTING/MERGE_LOG edits record verification only, with
outgoing held-artwork/secrets audit; do not rebuild/replace published ZIP bytes.
The task-owned Linux container is removed and Docker Desktop returned to its
initial stopped state if no unrelated container has started. Physical Boox/
Bigme cover quality/input latency/native-engine and prior device gaps remain
open. Keep Android safe mode ON and browse affected Bookshelf pages after
restart; do not instruct another cache wipe or full-library scan. No measured
speedup or general native Android crash fix is claimed.

## 2026-10-26: Local bilingual task-oriented settings redesign

User asks for clearer settings, approves all five-area/direct-controls/scope/
context-shortcut/search proposals, explicitly requests SimpleUI ownership for
Home and Swedish plus English throughout the new UI. Implement on
`feature/settings-navigation-20261026` from clean public `9f3f75a0`. This is not
an upstream merge, push or release request. Keep public Beta 12, VERSION and its
assets immutable; retain the one remaining installed API 1 path slot.

Root becomes Settings search + Home (SimpleUI), Bookshelf, Navigation & interface,
Integrations, System & maintenance. Library names/chips no longer crowd the root.
Retain the complete native Advanced controls, sole updater and old dispatcher
aliases. Book search moves under Bookshelf, distinct from settings search.
Scope headers distinguish shared Bookshelf, SimpleUI/Home/custom-screen,
library/shelf and shared-theme edits without changing preference ownership.
Menu-host parent Back preserves native nested Back/close-all, and search Back
restores the query. Newer settings navigation cancels delayed library openers.

Direct region/category visibility delegates to actual native callbacks; no second
store or migration. Existing templates, fonts, ignore choices, profile/chip IDs,
progress, books, links and data stay intact. Category switches reflect the master
line: turning a label on can enable its line but keeps all other category flags.
Top-panel hold offers customization plus the original detail action after the
same gesture/selection guards. Shelf hold retains its actions and renames Edit
to Customize this shelf. Existing themes are edited through the current native
theme menu, fixing the obsolete host call to absent `_backgroundSubItems`.

Static bilingual search indexes the owned descriptors plus 332 native short
Bookshelf phrases, without building native settings, evaluating current values,
opening a reader/provider or contacting a service. Forty-result cap with notice,
label relevance ranking, literal token matching and true UTF-8 byte decoding.
Generated vocabulary remains in the existing adapter; its source checker runs
in the normal gates after future imports. Small component metadata and optional
hero/title/Back seams preserve standalone behavior. Namespace-only Bookshelf
translation fallback keeps native/preload translations ahead of owned SV text;
no global gettext or require replacement. Existing SimpleUI translations stay
untouched. New labels/help, indexed phrases and common dynamic labels are SV/EN;
numeric/format placeholders are checked. No runtime file is added.

Focused native-backed settings/navigation/locale tests pass under Lua/LuaJIT;
complete final suites, translations, sealed-package and audits follow in
`test-results/settings-navigation-20261026/`. C01-C11 preserved, especially
C02/C03/C04/C06/C07/C08/C09/C10. Physical bilingual layout/touch, SimpleUI window
return/custom context, shared themes and reader/suspend/rotation acceptance is
still outstanding. No performance gain or device-acceptance claim. The user's
new cover confirmation applies to already published Beta 12, not this local UI.

### Local settings final verification (not published)

Implementation commit `d905e04c` plus native-ordering fix `ffd3ef34` remain only
on the feature branch. Reviewing official KOReader Menu:init reveals that it
always resets paths, so supplying parent paths in Menu:new options would leave
the Back arrow disabled. Set the parent path/enable the arrow after construction
before first paint. Update the complete MenuHost native-boundary test to emulate
the real reset, not a permissive fake. Parent/nested Back and close-all still
have separate semantics; a closed host cannot trigger a second parent callback.

Complete sequential gates pass 119 Python/four existing source-cache skips,
483 Bookshelf suites/zero failures/three normal SQLite exclusions and all 13
SimpleUI files. Both interpreters rerun all 76 root Lua files on final source.
All 19 new settings cases and retained shared settings/library/Home/navigation/
cover/update cases pass on the sealed ZIP. The native MenuHost/hero-region
supplements rerun under both interpreters after the arrow-ordering fix. Module
map 383; syntax 1,054; translations 43/zero failures; native search vocabulary
332. No new failure exception or skip is introduced.

Every validation ZIP file/hash/size equals clean candidate `ffd3ef34` plus its
manifest. No runtime path is added/removed: 1,998 files plus manifest, 2,064 ZIP
entries, one API 1 slot remaining. Bootstrap/entry/assets/fonts/VERSION/pins/
module map unchanged from public baseline. ZIP SHA-256
`2fc49a0db048e32b34faf2fd568987e12a96df7309148aacc86428d062c5c4f7`,
9,309,755 bytes, expanded 29,170,091. Twenty-three outgoing blobs exclude held
artwork; two source commits pass Gitleaks. Main/origin remain `9f3f75a0`; Beta 12
tag stays `ea8bbaf0` and public ZIP SHA stays `fe54c593c9b06fc0ba6055c82d6544a2807ee7e96efd9fd158b9c40d41dbafe2`.
Evidence: `test-results/settings-navigation-20261026/`.

Follow-up PROJECT_CONTEXT/TESTING/MERGE_LOG records results only and is audited
for secrets/held artwork. Do not rebuild/replace those development bytes or
publish them as a replacement Beta 12: VERSION is unchanged and no new release
was requested. No push, tag/release/OTA, physical install or new Docker session.
Actual SV/EN pagination/title widths, touch/long-press, scope comprehension,
themes, native SimpleUI Back/custom context and reader/sleep/rotation still need
Boox/Bigme acceptance. No measured speed or complete native-crash fix is claimed.

## 2026-10-27: Explicit settings Beta 13 push/publication request

The user explicitly says "Pusha och publicera" after the local settings handoff.
Prepare `release/settings-beta13-20261027` from `4a042fc2`, retaining settings
implementation `d905e04c`, native parent-navigation fix `ffd3ef34` and final
validation docs. Fresh origin/main remains `9f3f75a0`; latest public release is
Beta 12. No upstream import, pin advance or unrelated feature is authorized.

Advance VERSION to `0.1.0-beta.13`, add bilingual release notes, keep stable
bootstrap/API 1 and all previous tags/assets intact. The note consumes the last
installed API 1 slot: 1,999 inventoried files plus manifest equals 2,000. Verify
the exact boundary using actual older native installers, not a producer-only
limit change. No assets/licenses/runtime paths are removed to fit. Repeat full
Lua/LuaJIT/translation, clean committed package, sealed source, history/artwork/
secret, native OTA and CI gates before publishing exact verified draft assets.
Record final outcomes below. Evidence: `test-results/beta13-20261027/`.

Physical SV/EN/touch/Back/theme/reader/rotation/suspend acceptance remains open;
publish as a prerelease, not as proof of physical acceptance. The user's cover
confirmation concerns Beta 12 and is preserved, not extended to other claims.

### Beta 13 publication and final verification

Candidate/tag `f9d3b3a20148c10b204f4815b484252e25d11d37` combines release prep
`a2fe1045` and exact-label note correction `f9d3b3a2` with the three local settings
commits. Fast-forward and atomic main/tag push succeed; no unrelated branch/ref
or upstream pin is pushed/changed. Public prerelease `v0.1.0-beta.13` published
2026-10-27 at 06:04:40 UTC, after exact draft asset verification and green main/
tag CI `40458588212`/`40458587953`. Both jobs run complete Lua/LuaJIT, translation,
package and native OTA gates. Node/runner migration annotations are warnings.

Complete local sequential suites pass 119 Python/four unchanged external-source
skips, all 76 root Lua files, 483 Bookshelf suites/zero failures/three normal
SQLite exclusions and all 13 SimpleUI files. Module map 383; syntax 1,054;
translations 43/zero failures; search vocabulary 332. Nineteen settings cases
and retained shared settings/library/Home/navigation/cover/update regressions
pass on final sealed bytes under both interpreters. Six changed host modules
pass undeclared-global lint. No new failure exception. The sole change during
full gates is release-note wording; final exact-commit CI reruns all gates.

Every ZIP file/hash/size equals clean candidate source and manifest. Only the
new release note adds a path; none removed. Inventory 1,999 plus manifest equals
the existing 2,000-file installed API 1 limit; zero slots remain. Bootstrap,
entry/assets/fonts/pins/module map stay unchanged. Final ZIP SHA-256
`65ce2609b4bf914c298abb2f812c98d0e3ae84fad0863bf7786e1d54ac4a6c63`,
9,314,791 bytes, 29,182,623 expanded bytes, 2,065 entries. All 30 outgoing blobs
exclude held artwork; Gitleaks scans five outgoing commits with no leaks.

Actual immutable public Beta 5/9/12 ZIPs are checked against fresh API digests
and used as native Linux starting installers. All local phases pass: offer,
full native SHA/libarchive extraction at the file limit, missing-module rejection,
activation/restart/code rollback/truncated recovery and complete external
snapshot/restart/persistent rollback. Anonymous public API/ZIP/checksum and
GitHub asset digests match local/draft bytes exactly. Published-byte live TLS
discovery/download and all six native phases pass from Beta 9 and Beta 12.
Beta 12 release metadata/assets remain byte-for-byte unchanged. Evidence:
`test-results/beta13-20261027/`. Do not rebuild/replace published assets for this
follow-up documentation. Audit/push only these verification docs; restore the
task-owned Docker environment to its initially stopped state after tests finish.

No physical reader was changed. SV/EN pagination, touch/hold, native SimpleUI
Back/custom context, theme edits, reader return, rotation and sleep/wake still
need Boox/Bigme checks. Existing user-confirmed Beta 12 covers remain working
evidence for that earlier fix, not acceptance of the new settings. Code rollback
preserves current progress/settings. No new upstream merge or performance claim.

## 2026-10-27: Local native reading-menu fast Bookshelf return

User asks to route KOReader's native file-browser/cabinet reading-menu button
through OrbitUI's fast close and correct shelf profile, then explicitly approves
local implementation. Branch `fix/native-reader-close-20261027` starts from clean
public main `33b13a08`. No upstream import, push, version bump, release or device
installation is requested. Published Beta 13/tag/assets remain immutable; retain
its exact 2,000 installed-file budget by adding no runtime file.

Observed cause: current native ReaderMenu:getDefaultMenuButtons creates the
original onClose/showFileManager callback again inside setUpdateItemTable.
Bookshelf and SimpleUI previously wrote it at init/show time, before that reset.
The shared prepare hook now runs after native table construction and on each
cached opening. Both hosted component writers delegate to one owner; native
component standalone methods remain unchanged. A first-menu regression fails
against public `33b13a08` with the actual native menu, then passes locally.

Keep exact shelf-origin file/profile/chip/page/drilldown; Home/search files use
the shared saved-inventory matcher, no hard-coded prose/comics. Source provenance
records the real path before delegating to the unchanged native launch method.
External hot parking requires completed location prewarm for this exact reader,
file and profile. No positioning/rebuild occurs over a live unrelated reader;
otherwise the existing normal-close/location fallback runs, including rotation
refusal. Native menu over an already parked shelf keeps its real-browser exit.

Default-on `orbitui_reader_menu_return` in the SimpleUI store is the sole new
preference. A searchable checkbox/help is owned SV/EN, under Navigation > Opening
books & returning; turning it off invokes the original construction-time callback.
Unmatched/disabled/deleted sources likewise fall back, not to an unrelated shelf.
Skip only competing destination restoration; CloseDocument, progress/statistics,
sync, normal ReaderUI lifecycle and native invalidations still run. No other
gesture, hardware key, exit/restart or end-of-book policy is replaced. Per-item/
owner/generation/active-reader/consumed guards prevent stale and double taps.
Owner-safe Host.detach restores only its own callback, including older native
menus that retain their item table rather than resetting it.

Focused tests use complete host adapters/shared MenuHooks plus native close/
prewarm methods at explicit native service boundaries. The optional supplement
loads the WHOLE official KOReader ReaderMenu, at current reference
`f0db5fcb3c3e35949a99c8bff3dc36837a3f0fd6` and minimum supported `v2025.08`,
under Lua/LuaJIT. Evidence: `test-results/native-reader-close-20261027/`.
Full gates, sealed package and final audits follow below. C01-C08/C10 remain
preserved; C02's menu-only destination behavior is the expressly approved change.
Physical Boox/Bigme menu/layout/touch/rotation/sleep/reader-profile acceptance is
outstanding. Do not claim a measured speed gain or a new native-crash fix.

### Local native reader-menu final verification

Source candidate `1f2bb837b709e4a9b56e60edefeaef61fd6dcab7` remains local on the
feature/fix branch. Final complete sequential Lua/LuaJIT gates pass 119 Python/
four unchanged external-source skips, all 77 root Lua files, 483 Bookshelf suites/
zero failures/three normal SQLite exclusions and all 13 SimpleUI files. Module
map 383; syntax 1,055; translations 43/zero failures. No new exclusions. A final
scope refinement makes the third `exact_target` `_safeShow` argument opt-in for
ONLY this menu callback; standalone, gesture and end-of-book callers keep their
existing native fast-path contract. Both complete suites run again after that
refinement, without subsequent runtime edits.

Twenty-three targeted cases pass against whole official native ReaderMenu at
current pinned `f0db5fcb3c3e35949a99c8bff3dc36837a3f0fd6` and minimum `v2025.08`,
under both interpreters, including sealed bytes. Coverage includes native first/
cached/rebuilt/copied tables, icon retention, single owner, stale/double taps,
reader/owner identity, teardown, actual path/callback forwarding, source state,
external matching, disabled/unmatched fallback, searchable SV/EN live opt-out,
parked-shelf browser exit, exact prewarm identity and normal rotation/close
fallback. The first actual-menu case fails against public `33b13a08` before the
fix. Root supplements and final suites include all added tests. Native UI,
sorter and document services are still stub boundaries, not physical rendering.
Retained sealed host/settings/library/Home/navigation/panel/Android-cover cases
also pass. Evidence: `test-results/native-reader-close-20261027/`.

Every development ZIP file/hash/size equals the clean committed source and
manifest. No runtime path added/removed: 1,999 inventory plus manifest/all 2,000
API 1 installed slots, 2,065 entries. Entry/bootstrap/VERSION/API/pins/assets/
fonts/module map stay unchanged. SHA-256
`f3aa81c4bf2a36a2e6dcf649318daa6f621edff4411ac0b1a63aadd15208ecee`,
9,322,410 bytes, expanded 29,207,174. All 12 outgoing blobs exclude held artwork;
one source commit passes Gitleaks. Main/origin remain `33b13a08`, public Beta 13
tag remains `f9d3b3a2`, public ZIP remains
`65ce2609b4bf914c298abb2f812c98d0e3ae84fad0863bf7786e1d54ac4a6c63`.

This is a same-version LOCAL validation build: never upload it as replacement
Beta 13 or call it a new OTA. Follow-up verification docs are audited separately
without rebuilding the ZIP. No push, new tag, release, CI run, Docker session,
native OTA publication or installed reader change. Physical Boox/Bigme menu,
profile, progress/sync, layout/touch, rotation and sleep acceptance remain open.

## 2026-10-27 — LOCAL library/chip editor clarity (not released)

User approved the proposed cleanup after the photo of Books under Navigation >
Bookshelf button & destinations > Profiles and chips. Work continues from
`3d9dfad4` on `feature/library-chip-settings-20261027`, retaining both preceding
local reader-menu commits. No upstream import/pin, version, push, tag, release,
OTA replacement or device installation is requested or performed.

Only owned adapters/translations change at runtime. Each chip shows its source
and editable folder, separately from whole-library roots, now collapsed in an
advanced submenu with scope help and explicit replacement confirmation. A chip
folder change preserves siblings and old roots; an external folder requires
consent before appending it to whole-library scope. Stale/invalid chooser results
cannot overwrite a newer chip source. No file operations or settings migration.

Separate Order libraries (inventory level) and Order chips (profile level) keep
the numbered list visible. Select an item, then place before/after a named
neighbour; position/list/boundaries update immediately. Selection itself does not
write settings. Reorder callbacks resolve stable IDs in the latest inventory,
preserving appearance, disabled flags, Home references and navbar bindings.
Library order help explains equal-root matching and that navbar order is separate.
Ambiguous Move up/down rows are removed from these editors. SV/EN labels, help,
confirmations and bounded static search aliases are provided.

C02's editor presentation is deliberately refined with approval; underlying
matching/storage semantics and C01-C11 remain preserved. Targeted coverage:
18 library settings cases under both interpreters, including the real MenuHost,
plus existing 19 settings-navigation and 12 Bookshelf-navigation cases. Full
gates, clean-source package and history/artwork audits are recorded below after
completion. Physical bilingual layout/touch/long paths/multi-page order/Back/
restart/profile/reader-return acceptance remains open. No performance claim.

### Local library/chip editor final verification

Source candidate `5810c567960b23e95361456ea3c2ac086b25fb33` passes the complete
sequential Lua/LuaJIT gates with no runtime edits afterwards: 119 Python/four
unchanged source-cache skips, all 77 root Lua files, 483 Bookshelf suites/zero
failures/three normal SQLite exclusions and all 13 SimpleUI files. Module map
383, syntax 1,055, static search vocabulary 332, translations 43/zero failures.
No new skip or failure allowance. All 18 library settings cases include the real
MenuHost and pass under both interpreters. Sealed-byte regressions also pass for
19 settings/12 navigation cases, all prior 23 reader-menu cases against whole
pinned/minimum native ReaderMenu, host/shared settings/Home/panel/Android covers.
Native UI/font/touch/document services remain stub boundaries, not device tests.

Package/source/manifest audit passes for every file: development-only ZIP SHA-256
`e41141216342ed6d9710a9636c1313630e0c06d2cc997a2fdffe454c6b4250ee`,
9,329,310 bytes; expanded 29,229,702. Same 1,999 inventory paths plus manifest,
all 2,000 installed API 1 slots; 2,065 ZIP entries. No new/removed runtime path,
component change in this task, VERSION/bootstrap/API/pin/asset/font/map change.
No release note added. All 25 outgoing blobs exclude held artwork and all three
local commits pass Gitleaks. Main/origin remain `33b13a08`, public tag remains
`f9d3b3a2`, public Beta 13 ZIP remains
`65ce2609b4bf914c298abb2f812c98d0e3ae84fad0863bf7786e1d54ac4a6c63`.
The preceding `1f2bb837` development ZIP was preserved before the local rebuild.

Evidence: `test-results/library-chip-settings-20261027/`, with the existing
native-reader-menu audit/sealed runners reused against this package. Follow-up
verification documentation is audited separately without rebuilding. This is
NOT a replacement Beta 13 or new OTA. No push/tag/release/CI/upstream import or
installed-reader change. Physical Boox/Bigme bilingual layout, long paths,
multi-page ordering, touch/Back, persistence, Home links and profile/reader return
remain open. Zero new claims of speed, native-crash acceptance or device testing.

## 2026-10-27 — Reviewed SimpleUI merge and Beta 14 preparation

The user explicitly requests merge, push and publication. Start clean from
`7a3c519f` on `maintenance/upstream-beta14-20261027`, retaining local reader-menu
`1f2bb837` and library/chip editor `5810c567` plus their verification docs.
Fresh main/origin are `33b13a08`; Beta 13 and older public assets remain immutable.
BookShelf master has zero incoming commits and stays at exact
`c37580a1ca5040d2423e45b9bdd429776117f3c1` (6.0.3).

SimpleUI main advances from `b1580f90b2e17cf03a66c744c323a1df66d77100` to reviewed
`e5cd6dcb31fa759b9831223d4719f61126367cff`: 12 commits/10 changed paths. Reviewed
all subjects and net runtime diff: Unicode-aware library/collection/asset search
and sorts, buildListRows export for onboarding, cache-error guard and Spanish/
Chinese translations. No dependency/license/asset/runtime path change. Import
`a94b7533` uses unsquashed exact-SHA subtree merge. Chinese PO conflicts are
resolved semantically: preserve six local-only entries per catalog, take updated
translations, remove 50 invalid extra plural forms per single-form catalog.
Both catalogs pass msgfmt; no baseline allowance is increased.

Adaptation `856e28ab` preserves C01-C11, especially C03/C04/C06/C08/C10. Upstream's
automatic deletion of the bookinfo DB/WAL/SHM and reset of shared statements is
deliberately deferred. Known faults return last known text or nil, warn once per
failure episode and retry; unrelated errors retain their original error value.
No automatic DB repair is claimed. All five changed Unicode paths use existing
sui_text with native/utf8proc/ASCII fallback without mutating global util. Actual
official v2025.08 util lacks stringLower, confirming this compatibility need.
The preset export and scoped reader-opening paths are preserved. Ten new cases
include complete provider/preset/search modules, Unicode fallback/matching,
single-pass sort keys, idempotence, varargs, non-destructive errors and retries.

VERSION becomes `0.1.0-beta.14`, published only after complete Lua/LuaJIT/
translation/package/history/artwork/secret/native OTA/CI gates. Installed API 1
has no free slot: notes are added to existing docs/OTA.md and GitHub body, not a
new runtime file. This reviewed plan preserves every old path/asset/license/note,
all bootstrap bytes and installed limits. No source provenance field changes;
only the reviewed SimpleUI integrated pin advances. Code rollback preserves
settings, links and reading data. Physical Boox/Bigme bilingual editor/menu,
reader-profile, covers, rotation/sleep and external integration acceptance is
outstanding; no measured speed or device-crash claim. Final results follow.

### Beta 14 publication and final verification

Exact candidate/tag `575fdb7aead98f94de593e35ecf27772363ebb41` fast-forwards and
atomically pushes main/tag after all local gates. Public prerelease
`v0.1.0-beta.14` published 2026-10-27 13:22:20 UTC after exact draft audit and
green main/tag CI `40510806422`/`40510806468`. Both check jobs run complete suites,
translations, packaging and native OTA. Only runner/Node migration warnings.
Upstream watch `40510806263` passes and reports zero missing commits. SimpleUI
3.0.1 appeared at 13:12:29 UTC during verification: read-only ZIP comparison finds
every supplied source/runtime byte equal to reviewed e5cd6dcb, with only two extra
.DS_Store files. No release-only code or new ZIP-import exception is needed.

Complete sequential Lua/LuaJIT gates pass 119 Python/four unchanged external-source
skips, all 78 root Lua files, 483 Bookshelf suites/zero failures/three normal
SQLite exclusions and 13 SimpleUI files. Map 383; syntax 1,056; translation
validation 43/zero failures; settings vocabulary 332. All ten new upstream cases
and retained reader-menu/editor/settings/Home/panel/navigation/Android-cover
regressions pass on sealed bytes under both interpreters. Eight changed modules
pass undeclared-global lint. The official utf8proc wrapper with native system
casefold ABI passes a real Unicode supplement without util.stringLower; it is
not an exact reader-library build or device test. No new skip/failure allowance.

Every packaged file/hash/size equals clean candidate source and manifest. No
runtime path added/removed; notes use existing docs/OTA.md and the GitHub body.
Same 1,999 inventory plus manifest/all 2,000 installed API 1 slots, 2,065 entries.
Bootstrap/entry/assets/fonts/map and Bookshelf pin stay unchanged. SimpleUI pin
alone advances; original provenance retained. ZIP SHA-256
`01010c252a9abd5842cd0e7e3c539cb9e609fec07358a1196039911f80c30bc0`,
9,363,469 bytes, expanded 29,300,429. All 69 outgoing blobs exclude held artwork;
Gitleaks scans 14 outgoing non-merge commits with no leaks. No unrelated ref is
pushed and no earlier tag/asset is replaced.

Fresh GitHub digests verify actual immutable Beta 5/9/13 starting ZIPs. Their
native Linux installers pass local offer/extraction/full-inventory SHA, missing
module rejection, activation/restart/code rollback/truncated recovery and full
external snapshot/restart/persistent rollback. Exact draft and anonymously
downloaded public ZIP/checksum/API asset digests match the local build. Live
public-byte TLS discovery/download and all six native phases pass from Beta 9
and Beta 13. The first anonymous tag request during publication returned 404;
fresh verification and actual updater discovery succeed. Beta 13 metadata/assets
remain unchanged. Evidence: `test-results/beta14-20261027/`.

Follow-up verification docs do not rebuild/replace public bytes. Task-owned
Docker is stopped and Desktop returned to its initially stopped state. No reader
installation, settings, progress, artwork, links or external sync owner changes.
Physical Boox/Bigme bilingual editor/menu, long paths/paging/touch/Back, reader
profiles, covers, rotation/sleep and server-backed BookOrbit/MAL/Hardcover checks
remain open. No measured speed or native-crash acceptance claim.

## 2026-10-28 — Reviewed Bookshelf/SimpleUI maintenance (no release)

User requests upstream merge; standing authorization includes audited push to
origin/main, not a new version/tag/release/OTA. Start clean at `19cec4de` on
`maintenance/upstream-20261028`. Fetch tracked branches and review exact net
diffs/commit lists. Bookshelf advances c37580a1 to
`d07905ba932e09044827aadf480c188a5d324b96` (6.0.4, seven commits/22 paths),
SimpleUI e5cd6dcb to `22d5a3d2dd7be4651e718eb49027d82f68b3ace7`
(3.0.1 follow-up, sixteen commits/36 paths). No dependency/license change.
Unsquashed exact-SHA subtree imports: `695035f1` and `048174b2`; source provenance
is untouched and only the two reviewed upstream_commit fields advance.

Bookshelf colour fill/border fixes cover picked colours on colour displays;
collection manager now uses shared searchable LibraryModal; modal/editor closes
bound refresh regions; sleep capture happens before timer-driven anti-ghosting.
Conflicts: retain shared renderText/custom badge API with upstream colourBorder,
and retain owner-safe underlay wrapper removal with eager sleep capture.
SimpleUI reduces redundant cover repainting, dithers Home wallpaper, adds optional
page-turn flash, repairs hidden pagination arrows, uses two-column action sheets,
weakens old plugin hook owners and defers file listing until exposed on Home
return. Conflicts combine flash/full-repaint precedence, replace old lazy-refresh
marker with upstream pending-listing while retaining navigation generation, and
accept the corrected TBR comment. Existing native reader fast-return owner and
exact source-profile/prewarm matching survive.

C01-C11 are preserved; especially C02/C03/C04/C06/C07/C08/C09/C10. Compatibility
adaptations retain one-result external cover poll redraws, retry failed group
image widgets, restore chooser instance callbacks and Android inverse state on
errors. New flash label/help is SV/EN and opt-in. Retain Unicode old-reader
fallback, non-destructive cache-fault retry, settings editor, covers safe mode,
bounded extraction and all external sync owners. No settings/data/cache resets.

API 1 has zero spare paths. Twelve new Hazel PNGs remain byte-identical in Git,
but sealed packages losslessly embed them in existing assets.lua; only their new
separate PNG paths are export-ignored. Native renderImageData (confirmed present
in official minimum v2025.08) retains file rendering for every existing/custom
image, pixel scaling/alpha/night-mode and bounded raster ownership. User/source
files override the embedded fallback. No old runtime resource, license, artwork,
font or bootstrap is removed. No module path change/map regeneration needed.
Eleven new regressions exercise these boundaries; generator checks all twelve
PNGs. VERSION remains 0.1.0-beta.14; public Beta 14 ZIP is never replaced.

Adaptation candidate `6902f104` passes full sequential Lua/LuaJIT gates: 119
Python tests/four unchanged source-cache skips, all 79 root Lua files, 487
Bookshelf suites/zero failures/three normal SQLite exclusions and all 13
SimpleUI files. Module map 383; syntax 1,061; static search vocabulary 332;
translations 43/zero failures. No new skip or failure allowance. All eleven
new cases and retained native reader-menu/profile/editor/Home/Android regressions
also pass against sealed bytes under both interpreters. Native menu supplements
load complete pinned/minimum v2025.08 ReaderMenu with native UI services stubbed.

The first package-validator run correctly flagged that it still required each
new separate Hazel path. Its narrow replacement checks all twelve SEALED hex
resources against the tracked original PNG bytes; every other old asset/path
remains mandatory. A corrupted embedded-image ZIP must fail this whole checker.
Package/source/history audit verifies 1,999 inventory files plus manifest,
identical prior runtime file set and unchanged VERSION/bootstrap/assets/fonts/map.
All twelve embedded PNGs match exact reviewed upstream, and no held bitmap is
in the outgoing history. Gitleaks scans 21 incoming non-merge commits without
leaks. The native Linux libarchive/SHA smoke passes offer, complete extraction,
missing-module rejection, activation/restart/code rollback, truncated recovery
and external snapshot/restart/persistent rollback from immutable public Beta 13.
Its OTA implementation is byte-identical to Beta 14's; the same-version
development ZIP is NOT offered or uploaded as a replacement public Beta 14.
Final clean-candidate package hash/audits and push/CI results follow separately.
Evidence: test-results/upstream-20261028/ and its full-suite logs in test-results/.

Physical
Boox/Bigme colour, ghosting, wallpaper, sleep/rotation, repeated reader returns,
touch/Back and server-backed integrations remain outstanding; headless testing
does not demonstrate speed, native document-engine safety or device acceptance.

### October 28 final package and push verification

Exact tested source candidate `eb4f4347e82c874e31293dc0328c8b4f55862f52`
fast-forwards/pushes only main after the complete local gates. GitHub checks
`40684034831` pass both Lua/LuaJIT jobs, translations, packaging and native OTA;
watch `40684034924` passes and its fresh dashboard reports zero missing commits
for both reviewed targets. No PR, tag, release or OTA publication is created.

Clean-candidate development ZIP SHA-256
`55350876950d8653c174f70b71267a73d24e6a601063feab092f3e7f70dcb43e`,
9,374,227 bytes; expanded 29,321,004; 2,066 entries, 1,999 inventory files plus
manifest. Every file/hash/size equals committed source and manifest. Prior
runtime file set, bootstrap/API/VERSION/font/old-artwork/module-map bytes stay
unchanged. All twelve embedded PNGs exactly match reviewed upstream, decode as
32x40 RGBA and pass PNG verification. Corrupted embedded-image ZIPs fail the
whole checker under Lua and LuaJIT. All 125 outgoing blobs exclude held artwork;
Gitleaks scans 22 non-merge commits with no leaks. No new exception/skip.

Final sealed regressions (both interpreters) and all native Linux OTA phases
also pass on these exact bytes. The actual immutable Beta 13 starting installer
has the same OTA implementation as Beta 14, verified byte-for-byte. VERSION is
unchanged, so this development ZIP is never offered/uploaded over public Beta 14.
Public Beta 14 tag stays `575fdb7a`; its release metadata is unchanged and its
saved public ZIP stays
`01010c252a9abd5842cd0e7e3c539cb9e609fec07358a1196039911f80c30bc0`.
Follow-up verification docs do not rebuild/replace the tested development ZIP.
Task-only Docker container is removed and Desktop restored to initially stopped.
No reader installation or user data/settings/cache/link/sync-owner changes.
Physical Boox/Bigme acceptance remains open as above; no measured speed or
native document-engine/device-crash claim.

## 2026-10-28 — Dashboard card colours and approved Beta 15 publication

User approves the colour-dashboard proposal and immediate publication together
with the reviewed October 28 upstreams. Start clean at `eacfa7a7` on
`feature/dashboard-colour-beta15-20261028`; no additional upstream import/pin or
license/dependency/asset/module path change. Bookshelf d07905ba and SimpleUI
22d5a3d2 are already reviewed/imported in the preceding maintenance records.

Independent OrbitUI implementation in existing core/dashboard/view/settings
files adds Off (default), Accents and Tinted cards per Home/Custom Screen.
Stable card IDs own a distinct palette; native black/white text stays readable
on day/night fills, and monochrome/colour-disabled screens use the old route.
Existing dark/light hero, headings, sources, layout and independent row paging
stay intact. Colour-aware fill/border primitives bypass older native frame
chroma loss without global drawing patches. Native night-layout invalidation
re-resolves colours. The optional cover-derived hero reads at most 64 existing
bitmap pixels, with at most 32 weak-keyed derived strings: no decode, I/O,
strong retention, mutation/free, cover or provider work is added to paint.
Pending/missing/replaced covers remain retryable. Cover arrival recolours the
frame, preserving text/action/pager identity and borrowed-cover ownership.
All new controls/help/search are bilingual; unknown future colour values are
not silently rewritten. Main settings search includes colour/tint aliases.

BookOrbit's colour feature 267f53fccd909cc05dbb8edca88b698a439b8a9e is product/
visual inspiration only. No code, palette, icons, pets or artwork are copied.
Its AGPL-plus additional terms were reviewed; this is not a BookOrbit subtree
import or claim of endorsement. Sync/plugin/server responsibilities stay external.
Own RGB-bucket sampler/palette reuse existing OrbitUI native cover/render owners.

VERSION advances to 0.1.0-beta.15 under explicit publication approval; notes stay
in existing OTA.md and the GitHub body because API 1 already has all 2,000 file
slots. No old runtime path/license/artwork/bootstrap/limit is removed or changed.
Public Beta 14 and all earlier tags/assets remain immutable. README download
points to the release list rather than an outdated Beta 10 tag. Contracts
C01-C11 preserved, especially C02/C04/C05/C07/C08/C09/C10. Targeted model/menu/
whole-widget tests and schematics supplement the complete sequential Lua/LuaJIT,
translation/package/history/artwork/secret/native older-installer and public-byte
gates; final results follow. Physical Boox/Bigme colour/contrast/night/ghosting,
touch/Back, DPI, restart/rotation/sleep and actual document-engine acceptance
remain open. Do not infer device performance from stubbed UI/contrast tests.

### Beta 15 publication and final verification

Exact candidate/tag `ee35bf19836906ea81bf74737fc661ec8e4fa178` fast-forwards and
atomically pushes main/tag only after complete local gates. Public prerelease
v0.1.0-beta.15 is published 2026-10-28 15:08:36 UTC after both main/tag checks
`40712349677`/`40712349197` pass both interpreters, translations, packaging and
native OTA. Only runner/Node migration annotations. The draft's tag endpoint
returned 404; authenticated release listing/by-ID found the existing draft
426819687, so there was no duplicate creation. Exact draft assets were downloaded
and audited before publication. Anonymous public metadata/download/digest and
actual old-installer live TLS discovery/download then pass.

Complete sequential final local gates: 119 Python/four unchanged external-source
cache skips, all 80 root Lua files, 487 Bookshelf suites/zero failures/three
normal SQLite exclusions and all 13 SimpleUI files. Map 383, syntax 1,062,
static vocabulary 332, translations 43/zero failures. No new skip/allowance.
All 38 dashboard/15 config/six colour cases, retained settings/Home/panel/Android
covers/navigation/Unicode/cache and 23 native reader-menu cases (whole pinned and
minimum v2025.08 ReaderMenu) pass on sealed bytes under both interpreters.
Tests cover logical day/night contrast, default-off/monochrome/colour-disabled
fallback, independent scopes, unchanged geometry/actions/text/pagers, 64-pixel
read-only sampling, weak ownership, pending/failed bitmap retry and RGB paint.
Native UI/font/document boundaries are stubbed; synthetic SVG/Quick Look previews
are schematic with approximate text, not actual native/device rendering.

Every package file/hash/size equals committed source and exact manifest. No
runtime path added/removed: 1,999 files plus manifest/all 2,000 installed API 1
slots; 2,066 entries. Stable bootstrap/API/limits/fonts/artwork/module map and
both reviewed component trees/pins stay unchanged from preceding maintenance.
ZIP SHA-256 `f2005c95e9d4536661402c424811861c729369ea32313dc3e1c9ce559f593043`,
9,380,788 bytes, expanded 29,340,517. All 149 blobs since public Beta 14 exclude
held artwork; Gitleaks scans 25 non-merge commits without leaks. No old tag or
release asset is changed. Source/manifest and draft/public asset/API digests match.

Fresh GitHub digests verify immutable public Beta 5/9/14 starting ZIPs. Actual
old-installer Linux libarchive/SHA tests pass offer/extraction/full inventory,
missing-module rejection, activation/restart/code rollback, truncated recovery
and external snapshot/restart/persistent rollback from all three. Live actual
published-byte TLS discovery/download and every native phase pass from Beta
9 and 14. Public Beta 14 tag remains 575fdb7a and its metadata/asset identities,
sizes/digests/update timestamps stay unchanged; its ZIP is still
01010c252a9abd5842cd0e7e3c539cb9e609fec07358a1196039911f80c30bc0.

Evidence: test-results/beta15-20261028/. Follow-up verification documentation
does not rebuild/replace published bytes. Task-only Docker container is removed
and Desktop restored to its initially stopped state. No reader install, settings,
progress, links, cache reset, external sync owner or artwork change. Physical
Boox/Bigme colour strength/night/ghosting/touch/Back/DPI/rotation/restart/sleep and
actual document-engine acceptance remains open. This beta does not claim measured
speed, physical display acceptance or newly verified native-crash safety.

## 2026-10-28 — Local translation package-size optimization (not released)

User approves the recommended first size-reduction step after measurement of
public Beta 15: strip developer source-file/line references from packaged PO
catalogs, not languages, functions, artwork or legal information. Work starts
clean at public main `af238167` on `maintenance/slim-translations-20261028`.
No upstream import/pin, component source, runtime path, stable bootstrap, API-1
limit, VERSION, user data/cache or rollback-slot cleanup changes. No push,
new tag or publication is authorized by this implementation request; public
Beta 15 and all earlier releases remain immutable.

`scripts/release-package.py` omits only lines beginning with `#:` (optionally
indented) in the two components' direct `locale/*.po` catalogs. Original
catalogs stay tracked byte-for-byte, along with all languages, legal/translator
comments, flags, headers, plural rules and message bytes. The transform runs
before inventory sizes/SHA-256 and archive checksum generation. No new runtime
file is required at the installed 2,000-path ceiling. Source-parity audits use
this narrow documented projection, never an unconditional PO exception.

Targeted packaging tests pass all seven cases, including all 43 current
catalogs compiling to identical checked, hash-free GNU gettext MO bytes before
and after optimization. Regression fixtures retain CRLF/UTF-8, literal `#:` in
message/context/continuation strings, plural rules, legal and translator text,
fuzzy/format flags and obsolete entries; only source comments disappear. Path
scope/idempotence and ZIP/manifest/checksum byte integrity are verified.
### Local verification and size comparison

Tested, clean committed source/package candidate: `edc2c850389c9df84d2f6644a9fecc78200149c4`.
Complete sequential `scripts/test.sh` under Lua and LuaJIT passes: 122 Python
tests/four unchanged external-source pixel-audit skips, all 80 root Lua files,
487 Bookshelf suites/zero failures/three normal SQLite exclusions and all 13
SimpleUI files. Module map 383 and syntax pass; all 43 source catalogs validate
without exceptions. An initial host invocation selected a Python lacking
Pillow and stopped before Lua; full runs use the established Python 3.12/Pillow
environment instead. No test exemption or source change masks that environment
problem.

The sealed ZIP passes module/assets/licenses/recovery inventory checks. An
independent exact-source audit projects only PO source-reference lines; every
other file equals the clean committed Git archive, every catalog equals its
expected projection, and all manifest sizes/hashes plus the ZIP checksum match.
The same 1,999 inventoried files plus manifest occupy all 2,000 API-1 paths;
2,066 archive entries remain. All bootstrap bytes, assets/fonts and source pins
are unchanged. All 43 original/sealed catalogs compile identically. The actual
component Lua translation loaders additionally agree on 54,517 singular/fallback
and 327,102 plural comparisons per interpreter under both Lua and LuaJIT,
without replacing native gettext. This uses headless native-loader execution,
not physical screen acceptance.

Local optimized package SHA-256:
`5e1bd3241f944477b9753e8bd21858da4750b69ef8f669ff034a76ca4eba4851`.
ZIP: 8,756,519 bytes, compared with immutable public Beta 15's 9,380,788
(624,269 bytes / 6.65% smaller). Expanded contents: 25,554,846 versus 29,340,517
(3,785,671 bytes / 12.90% smaller, including the added documentation).
Source-reference removal itself saves exactly 3,794,410 bytes across 43 files.
The public Beta 15 ZIP retains its original `f2005c95...` digest. Original
catalogs and all languages remain; no source/runtime loader is rewritten.

Actual public Beta 14's older installer also passes the local full-package
native libarchive/SHA smoke on macOS: update offer, full inventory extraction/
hash verification, missing-module rejection, activation/restart/code rollback,
truncated-download recovery and external runtime snapshot/restart/persistent
rollback. This uses the existing headless filesystem scaffolding, not a device
or live published-byte download; no new release exists for live discovery.

Evidence:
`test-results/slim-translations-20261028/` (full interpreter/translation/package
logs, independent `audit.py`/`audit.log`, native OTA log). This test ZIP keeps
VERSION Beta 15 only for local verification; it must never replace the published
Beta 15 asset. A future release needs explicit approval and a new version/build.
Follow-up verification documentation does not rebuild this tested candidate.
No reader installation, settings/progress/cache, retained version or external
sync owner is changed. Physical device acceptance is separate; no speed/RAM
improvement is claimed. Work stays local, without push/tag/release.

## 2026-10-28 — Local safe update-storage collection (not released)

User requests step 3 of the size proposal after the local PO optimization.
Work starts from clean `58b944b7` on `maintenance/update-storage-20261028`;
preceding local packaging work is retained. No upstream import/pin, VERSION,
bootstrap/API-1 or runtime path/limit change, push, tag or release is authorized.
No reader installation or user data is accessed. Public Beta 15 stays immutable.

Previous behavior retained an extra obsolete code snapshot after a healthy boot
until the next in-app update; external snapshots could also accumulate. The new
host-confirmed, deferred quiet Trapper task may collect one strictly older unused
snapshot per start. Verify current and previous packages fully before deleting
any old code. Retain factory/current/previous, pending/equal/newer snapshots,
unknown/modified files/directories, links and unverified data. A recovered/stale/
unconfirmed start cannot collect; corrupt retained code keeps every old version.
Remove the old prepare-time bulk deletion of arbitrary hash-named directories.

Atomic rename to an invalid-bootstrap-slot quarantine, complete preflight,
rechecked state/plain paths/hashes and manifest-last unlink make interruption
resumable. Only byte-identical known remaining files can be removed; unknown or
changed data stops cleanup. Empty final quarantines use rmdir only. Work is
bounded to 128 directory entries/eight candidates/12,000 tree nodes and one
completed snapshot per startup. Busy guards also stop stale rollback callbacks.
Failure/cancellation never fails startup or changes activation/recovery markers;
external/daily checks follow. Actual freed bytes are logged, not inferred from
ZIP size. Factory/current/rollback duplication intentionally remains.

Fifteen collector cases and four new updater-order/guard cases pass under Lua
and LuaJIT. Collector tests use actual production validation and Lua parsing on
an in-memory filesystem; no candidate Lua is executed and no user path is
touched. The native full-package smoke additionally covers real-file interrupted
cleanup and resume after reloading bootstrap/collector state. Complete final
test/package/source-integrity/native results follow below. Physical Boox/Bigme
startup responsiveness, cancellation/power-loss and storage behavior remain
unverified. No RAM/speed benefit or actual device-space saving is claimed.

### Final local verification

Clean implementation/package candidate:
`ff972412078fa798bea4e25e4c1a8ca873394af4`. Complete sequential Lua/LuaJIT
`scripts/test.sh` runs pass 122 Python tests/four unchanged optional source-pixel
skips, 81 root Lua files, 487 Bookshelf suites/zero failures/three normal SQLite
exclusions and all 13 SimpleUI files. Map 383, syntax 1,063; all 43 catalogs
validate without exceptions. Final targeted and sealed-byte runs cover the
collector's last interruption guard and the added full 1,999-file inventory case
(15 collector cases), all 12 updater cases, bootstrap/OTA/external-update/menu/
HTTP suites, under both interpreters. No new skip or failure waiver.

The full sealed package passes inventory/asset/license/recovery checks and an
independent Git-archive/source audit applying only the approved PO projection.
Every manifest hash/size and ZIP checksum agrees, with the same 1,999 inventory
files plus manifest/all 2,000 API-1 paths, 2,066 ZIP entries. Stable bootstrap,
module map, VERSION, pins, component sources and artwork/fonts/assets are
byte-identical to `58b944b7`. Native PO loaders still agree on 54,517 singular/
fallback and 327,102 plural comparisons per interpreter, across all 43 catalogs.
Local test ZIP: 8,763,124 bytes; expanded contents 25,577,967 bytes; SHA-256
`d4ef0c875a7a715a7ac593169412f2edb078526322fba3f6a139bd2e8b0cdc65`.
VERSION stays Beta 15 only for local testing; never replace its public asset.

Actual public Beta 14's installer passes local full-package native libarchive/
SHA discovery, extraction, missing-module rejection, activation/restart/code
rollback, truncated recovery and external snapshot/restart/persistent rollback.
The new sealed collector additionally operates on real files: interruption after
the first obsolete unlink, fresh bootstrap/collector state, manifest-based resume,
retained active/rollback records, and unknown/modified/user-data preservation.
The obsolete fixture is a small synthetic complete API-1 runtime; full 1,999-file
collection is separately covered in memory. The optional test-only filesystem
hook uses a locally compiled POSIX C shim on macOS (native lstat/mkdir/rmdir/
opendir/readdir, strict compiler warnings), rather than the default shell-backed
scaffolding; no dependency or helper is added to the reader package. Existing
native hash/archive sources remain pinned. This is not a device, native KOReader
UI/power-cut or live newly published-byte test. Public Beta 14/15 cached ZIP
digests are rechecked unchanged. No Docker/app state is changed by these tests.

Evidence: `test-results/update-storage-20261028/` (complete logs, collector and
updater targeted logs, `package.log`, independent `audit.log`, `sealed-final.log`,
native older-install/cleanup logs and the native filesystem test source).
Follow-up verification/test-only refinements do not rebuild the tested candidate
ZIP. No actual reader, settings, progress, links, cache, artwork, external writer
or production update channel changes. No user files have been deleted; only
generated obsolete-runtime test fixtures were removed. Work remains local,
without push/tag/release. Physical startup responsiveness/storage/recovery on
Boox/Bigme remains outstanding; this does not certify real device-space savings.

## Template for the next approved merge

Copy this section and replace placeholders only after performing the work.

- User request / scope:
- Component and tracked branch:
- Prior integrated upstream SHA:
- Reviewed target upstream SHA / release:
- OrbitUI merge commit and adaptation commits:
- Affected contracts (C01-C11):
- Conflicts and semantic decisions (including upstream changes deliberately deferred):
- Updated upstream pin and generated module-map changes:
- Tests passed, skipped, known baseline failures and new gaps:
- Device checks performed / still required:
- Release decision and user approval (or explicitly "not published"):
- Recovery considerations and next maintainer notes:
## 2026-10-28 — Local UI/performance follow-up (not released)

The user says "Kör" after the comparative review of CyberUI, VOS, Project:Title,
ZenOS and d1-m4ss's published benchmark. Work is local on
`feature/performance-20261028` from `66b6f1c1`, retaining the unpublished PO
packaging and safe update-storage work. This is not an upstream merge or
authorization to push/publish. VERSION stays Beta 15; its public bytes remain
immutable. No foreign UI code, assets or fonts are copied. Research checkouts
are ignored under `test-results/ui-survey-20261028/`.

Implementation:

- C04: dashboard `M.needs` uses the existing real registry's per-screen dynamic
  API. Only visible statistics/local annual-goal consumers request stats; only
  the local goal requests book-count reconciliation. Ongoing keeps 30 recent
  candidates, hero alone needs one, and a visible native Recent source keeps 30
  independently. Hidden source labels no longer resolve saved shelf references.
  Other enabled modules still contribute their own demands. Existing card
  geometry/actions/ordering/sources and cached/remote goal ownership are retained.
- C02/C04/C06/C07: opt-in Adaptive/Responsive profiles coordinate the two loaded
  cover-cache runtime caps against a shared available-memory/reader policy.
  Native budget writers keep their saved/base values; switching back restores
  them. Unknown readings do not guess memory. Native reference-only eviction
  keeps borrowed images/one oversized newest entry, reports deferred GC pressure
  and does not clear disk caches or rebuild a parked shelf. One deferred 1.5s
  one-shot is generation/owner/suspend guarded, never periodic. Responsive also
  gates wipe animation and speculative next-page/chip warming; mandatory reader
  prewarm, cabinet return/profile/chip/page, safe visible Android extraction,
  source resolution and external progress writers are unchanged. Existing
  behaviour is the default and an unknown future saved mode is retained inertly.
- C04/C06: bounded opt-in local diagnostics record only allowlisted synchronous
  method labels/counts/error counts and the latest 60 durations per operation.
  Nil arguments/results and original error objects survive. CPU fallback is not
  mixed with monotonic elapsed samples. Snapshot/report reads do not force GC or
  fetch metadata/network data. Reports include numeric Lua/OS/cache/queue data,
  not book paths/titles/profile names/credentials/raw errors. View/copy is an
  explicit local user action; no automatic report file/upload. Captured wrappers
  become inert on last-owner teardown and do not overwrite later external hooks.
- Shared settings add one bilingual Speed, memory & diagnostics page and a short
  read-only Home→Bookshelf profile/chips→navigation→reader-return guide. Both
  retain the five task areas and static SV/EN settings search. No reset/migration,
  menu auto-launch, added dependency or new installed runtime path. The only
  component edit is the existing SimpleUI LRU's optional runtime byte-cap setter;
  canonical paths, module map, source pins/bootstrap/assets/reading data remain.

Baseline and limits:

`scripts/benchmark-dashboard-demand.lua` was run before/after on the same local
tree/interpreter. With only hero shown, declared recent candidates fall 30→1;
book rows without statistics stop requesting stats/counts; remote-goal-only and
all-hidden layouts request neither stats/counts nor recent candidates. Local
annual goals and native Recent rows retain their needs. This is a deterministic
DECLARED-DEMAND comparison, not observed provider calls or a device speed/RAM
benchmark. All 512 visibility combinations and the real registry are tested.

No complete runnable KOReader emulator was present. Device/emulator end-to-end
latency, real C-buffer memory pressure, SV/EN touch/layout and Boox/Bigme cover/
reader/rotation/suspend acceptance remain open. Reports measure synchronous
methods only (not settled deferred work/panel latency); close-event timing is
not total book-close latency. Lua heap is not total RAM and retained-cache bytes
exclude live borrowed buffers. The published benchmark has different pins and
views; no comparison or speedup percentage is claimed. Exact final local
verification follows after the sealed package checks.

### Final local verification

Implementation/package candidate: `5def9a06a65c081dd05d8cb9c00e4447ef4f089a`.
Complete sequential Lua/LuaJIT `scripts/test.sh` runs pass 122 Python tests/four
unchanged optional source-pixel skips, 83 root Lua files, 487 Bookshelf suites/
zero failures/three normal SQLite exclusions and all 13 SimpleUI files. Map 383;
LuaJIT syntax 1,066; all 43 catalogs validate without exceptions. All 83 root Lua
files ALSO pass on actual sealed bytes under both interpreters, including 14 new
performance cases, four new demand cases/all 512 visibility combinations, and
the retained Android-cover/Home/reader-menu/lifecycle/OTA/storage suites. No new
skip or failure waiver. Initial harness launches used a Python lacking Pillow
and omitted the optional POSIX-shim library variable; final complete runs use the
existing Python 3.12/Pillow environment and both documented shim variables.

The source/package audit compares every sealed byte to a Git archive of the exact
candidate with only the already-approved PO projection. Manifest sizes/hashes,
archive checksum and the complete path set agree: 1,999 inventory files plus
manifest/all 2,000 API-1 paths, 2,066 ZIP entries. All 13 newly outgoing blobs
exclude held artwork and the implementation commit passes Gitleaks. Stable
bootstrap/entry, VERSION, source pins/map, images/fonts/assets and all component
sources except the documented nine-line SimpleUI LRU extension are unchanged
from `66b6f1c1`. Existing public Beta 14/15 cached asset digests remain unchanged.

Local ZIP: **8,777,692 bytes**, expanded **25,622,138 bytes**; SHA-256
`4b32158c0142556aeba3972db605dc7df1853611c10b6d46b8d427673ad2b8c1`.
This includes the preceding unpublished package-size/storage work, not a new
public version. Compared with that preceding tested ZIP it adds 14,568 compressed
bytes (code, bilingual help and verification docs), no installed file paths,
artwork or dependency. Never replace the published same-version Beta 15 asset.

Actual public Beta 14's older installer passes full-package native libarchive/
SHA extraction, missing-module rejection, activation/restart/code rollback,
truncated recovery and external snapshot/restart/persistent rollback. Native
real-file obsolete-code interruption/reload/resume and active/rollback/unknown/
modified/user-data preservation pass too. These are isolated temporary macOS
fixtures, not an emulator UI or physical device. Native reference files use the
same pinned koreader-base revision as CI; no foreign UI plugin is executed.

Evidence: `test-results/performance-20261028/` (`full-lua.log`, `full-luajit.log`,
before/after demand CSVs, targeted/settings/cover/menu logs, package and complete
sealed/source audit, Gitleaks and native OTA log). Verification-only follow-up
documentation does not rebuild the candidate ZIP. No push, tag, release, public
asset/OTA change or user-device installation occurred. The optional profiles
remain opt-in pending the physical acceptance protocol in TESTING.
## 2026-10-28 — Beta 16 release preparation

The user explicitly requests "Pusha och publicera" after the local performance
work. `release/performance-beta16-20261028` starts clean at `fa17565c`; fresh
GitHub/main is `af23816717586674a4ab82f5968cb6f707ffeb35` and Beta 15 is the
newest public prerelease. Include all six reviewed local performance/PO/storage
commits, without a new upstream import. VERSION becomes `0.1.0-beta.16`.
Release notes reuse OTA/README, keeping all installed paths and stable bootstrap.
Publication is gated on both full interpreters, translations, clean candidate
package/source/history/artwork/secret audit, native older-installer upgrade/
rollback, CI, exact draft-download bytes and anonymous published-byte checks.
Optional profiles remain opt-in; physical device response/memory/display/OTA
UI acceptance remains open and this release remains a prerelease. No public
Beta 15 or older asset/tag may be changed. Final evidence follows below.

### Beta 16 publication and verification

Exact candidate/tag: `5c846730d5fbcaafc805fce9db97f6b57257139d`.
Fast-forward/atomic push updates `origin/main` from `af238167` and adds only
`v0.1.0-beta.16`. Main/tag CI `40750773286`/`40750773783` is green (both
interpreters, translations, package and native archive/SHA OTA). A draft release
for that exact commit receives only ZIP and checksum. Both downloaded draft
assets match local bytes and GitHub's size/digest/state before publication.
Published as a prerelease, not latest/stable, at **2026-10-28 19:09:05 UTC**:
<https://github.com/komadorirobin/orbitui.koplugin/releases/tag/v0.1.0-beta.16>.

Both complete local interpreters pass 122 Python tests/four unchanged optional
source-pixel skips, all 83 root Lua files, 487 Bookshelf suites/zero failures/
three normal SQLite exclusions and all 13 SimpleUI files. Map 383; syntax 1,066;
all 43 catalogs validate. ALL 83 root suites also pass on the sealed package
under Lua and LuaJIT. No new failure waiver. Each manifest byte/hash/size is
compared against a Git archive of the exact candidate with only the reviewed
PO source-reference projection. Bootstrap/API 1, all 2,000 installed paths,
module map, source pins, fonts/artwork/assets stay unchanged. The only component
source change since public main is the documented nine-line optional SimpleUI
LRU runtime-cap setter. All 47 newly outgoing blobs exclude held artwork;
Gitleaks scans seven commits without leaks.

Public package: **8,781,021 bytes**, expanded **25,632,378 bytes**, 2,066 ZIP
entries, 1,999 manifest inventory files plus manifest. SHA-256:
`a9a1b6f6a36376b11091f195f2a0230208898909b483914c4cddd0e80d4aff98`.
Compared with unchanged Beta 15: **6.39% smaller ZIP / 12.64% smaller expanded**.
All languages/messages, licenses, images and fonts remain; real installed
storage savings depend on the device's obsolete code snapshots. No device
speed or memory improvement is measured by this comparison.

Native real-public-Beta-5/9/14/15 installer checks pass: full inventory extraction
with pinned KOReader libarchive/SHA, missing-module rejection, activation/restart/
code rollback, truncated-download recovery and external snapshot/restart/persistent
rollback. Real-file obsolete-code interruption/reload/resume and protection of
active/rollback/unknown/modified/user data pass too. After publication, anonymous
API and both public asset downloads match the reviewed bytes. Actual application
HTTP/TLS discovery and public-byte OTA from Beta 9/15 pass the same native and
recovery scenarios. Preview selects Beta 16; stable remains unchanged (no stable
release). All 70 previous public release records/assets and all earlier remote
tag refs are checked unchanged, excluding mutable download counts.

Test-only JSON/LuaSocket/LuaSec are built under the ignored evidence folder,
not globally installed or shipped; the old Lua-CJSON test source has a local
LuaJIT compatibility guard. The optional native filesystem shim is also confined
to test fixtures. No reader or user data is touched. Evidence:
`test-results/beta16-20261028/` (complete/full/sealed logs, package/source audit,
native and live older-installer logs, CI results, draft/public metadata/downloads,
channel and immutability checks). Follow-up verification docs do not rebuild or
replace the tagged/public ZIP. The prerelease retains open physical Boox/Bigme
UI, native image-pressure, performance, storage/power-cut and updater-dialog
acceptance. Existing behaviour is still default; Adaptive/Responsive remain opt-in.

## 2026-10-29 — Category-card settings start (local, not released)

The user requests "Börja med Inställningsstart med stora, tydliga kategorikort"
after the read-only Bookshelf-OS comparison. Work starts clean at `fe93bb39` on
`feature/settings-start-cards-20261029`. Scope is ONLY the OrbitUI settings start,
not the reader toolbar/font menu, light/Wi-Fi popovers or a global KOReader menu
replacement. No new upstream import, push, VERSION bump, tag or release.

The five existing category IDs gain static localized summaries and existing
Material SVG icons. Home remains Home/Hem (SimpleUI). The existing LibraryModal
provides grid gestures, pagination, key/footer focus, keyboard/close cleanup and
repaint, without global class or private-upvalue modification. Its only source
change is a four-line read-only `gridGap()` accessor, so measured card content
uses its exact initialized grid spacing across later DPI changes. No Bookshelf-OS
implementation, icons, fonts or extra plugin is imported; this is an independent
presentation over OrbitUI's existing menu routes. All runtime paths and source
pins/bootstrap/artwork remain; settings/progress/caches/providers are untouched.

Measured wrapped labels/descriptions and focus-ring space determine card height,
column count and page size. Narrow/large-text configurations use one column;
short screens page. The old complete list is an explicit option and the fallback
for unusable geometry/missing UI. Its Back link and category Back return to cards;
search Cancel from cards returns there and results keep their query Back route.
Opening any newer settings destination closes the old root and invalidates stale
root/search/deferred-library callbacks. Native submenus, scopes, preference writers
and public list-building APIs remain unchanged. No current values, credentials,
provider menus or book queries are needed to render the start.

Eleven targeted tests run the real complete native modal and adapter over stubbed
native widgets/fonts; 36 SV/EN size/scale fixtures per interpreter verify bounds,
page reachability and unclipped proxy text, including Bigme native portrait and
landscape. The first matrix run caught initialized-modal spacing versus later DPI
spacing drift; the read-only accessor fixes it. Existing settings/search/native
checkbox tests remain. Final full/sealed/package verification follows below.
These checks do not establish actual KOReader shaping/e-ink/touch, rotation/sleep
or the underlying Boox/Bigme reader/profile lifecycle; physical acceptance stays
open. Public Beta 16 remains immutable and is not replaced by a development ZIP.

### Final local card-start verification

Implementation/package candidate `8133c7aba6260d5e018564f955e72f7b6e8a0ff5`.
Complete sequential Lua/LuaJIT gates pass 122 Python tests/four unchanged optional
source-pixel skips, 84 root files, 487 Bookshelf suites/zero failures/three normal
SQLite exclusions and all 13 SimpleUI files. Map 383, syntax 1,067, catalogs
43/zero failures. All 84 root suites rerun on final sealed bytes under BOTH
interpreters, including the final eleven start-card/search/touch/key/rotation/
geometry cases and retained settings/native control/deferred-library tests.
No new skip or failure waiver. The final sealed rerun covers the search Cancel
and stale-dialog guard refinements made after the first Lua root-file phase.

Every package byte equals the exact committed Git-archive source after only the
approved PO projection; inventory hashes/sizes/checksum agree. Same 1,999 files
plus manifest/all 2,000 installed API-1 paths, 2,066 ZIP entries. No bootstrap,
VERSION, source pin/map, asset, artwork/font or license change. The four-line
read-only modal grid-gap accessor is the only component source change. All nine
new outgoing blobs exclude held artwork and the source commit passes Gitleaks.
Local ZIP **8,788,882 bytes**, expanded **25,656,913 bytes**, SHA-256
`1c404bb6814103ad523d3b933dbe264ea9a85e6a160f8e65246707bfdc39279f`.
This is 7,861 ZIP bytes above the unchanged public Beta 16, with no new path.

The actual public Beta 15 installer passes local full-package native libarchive/
SHA validation, missing-module rejection, activation/restart/rollback, truncated
recovery and external snapshot/restart/persistent rollback. Real-file obsolete
cleanup interruption/reload/resume retains active/rollback/unknown/modified/user
data. These isolated fixtures use the existing pinned native references/POSIX
shim, not an installed reader or live new release. The cached public Beta 16 ZIP
digest is unchanged. Evidence: `test-results/settings-start-20261029/` (full Lua/
LuaJIT/translation logs, complete sealed rerun, package/source/history audit,
Gitleaks and native OTA log). Verification-only follow-up documentation does not
rebuild the tested ZIP. No push, tag, release, production OTA or reader install;
physical SV/EN shaping/layout/touch/night/rotation/sleep acceptance stays open.

## 2026-10-30 — Reviewed upstream merge and standing main push (no release)

User requests "Merga upstream". Standing authorization includes an audited,
verified fast-forward push to `origin/main`, not a version/tag/release/OTA.
Start clean at `7083c8a120c62e1c950edd4f1135eee42dc0e478` on
`maintenance/upstream-20261030`, retaining the two local category-card commits
`8133c7ab` / `7083c8a1`. Public main is `fe93bb391f7de9bc2d87eb7fb731cc5c9990bee9`.

Reviewed/imported exact branches:

- Bookshelf master `d07905ba932e09044827aadf480c188a5d324b96` →
  `ee84a8fe1621171c00df91c41dee76b9ed07028c`, six commits, four issue-form/workflow
  files only. Unsquashed import `39e28383`; no Bookshelf runtime change. The
  existing read-only LibraryModal grid-gap accessor remains.
- SimpleUI main `22d5a3d2dd7be4651e718eb49027d82f68b3ace7` →
  `257c26d6685ced4fc2e895f98287b5f16f1d4f5e`, all 14 commits / 82 net paths.
  Unsquashed import `f339c492`. Latest published releases remain Bookshelf 6.0.4
  and SimpleUI 3.0.1; branch follow-ups, not new release tags, are reviewed here.

C01-C10 review and semantic decisions (C11 has no native runtime delta):

- Import optional hidden menu items, grid Quick Actions (up to 7×4), six-column
  cover modules, page-turn statistics/odometer, scrollable long action-sheet
  messages, Critter global defaults/quick-panel/games/quotes/voices and platform
  Bluetooth follow-ups. Existing layout/defaults remain. Page turns count
  positive-duration records (including rereads), not unique rendered/book pages.
- Menu hiding protects shared OrbitUI settings and Quick Settings, restores
  native order and cancels snapshots on last-owner release. Snapshots use static
  text/IDs, never evaluate dynamic current-value/provider callbacks. Cabinet
  ownership also updates hidden copied descriptors, retaining exact fast shelf
  return, opt-out, stale guards and teardown. No new reader or sync owner.
- Covered boot listing retains guarded Home failure fallback. Idle work requires
  the same owner/FM/Home/navigation generation, no reader/suspend/exit; folder
  warming is one visible entry per tick, max 64, cancelled on chooser changes.
  CoverFinder's new no-mandatory-text optimization restores the exact previous
  instance callback, dummy and filter even after error. Real device latency and
  RAM benefits are unmeasured.
- Keep Android's Device Bluetooth API before platform fallbacks; unavailable
  Kindle does not appear supported. Preserve native safe-mode Android covers.
  Raw Critter alpha scanning retains pixel/stride ownership and a non-FFI path;
  embedded Hazel still uses native image-data decoding and exact PNG bytes.
- Do NOT activate upstream's patch-disable dialogue/rename implementation.
  Both compatibility module entry points remain read-only in the host, including
  legacy aliases. MAL, BookOrbit, Patch Manager and arbitrary user patches remain.
- The upstream migration-extraction refactor is deliberately deferred: retain
  the existing main-file copy/retry/deferral/first-run implementation, not the
  unadapted replacement's old deletions/default overrides. Add only guarded,
  retryable v14 default copies. Saved per-screen Critter pick/style/source/topics/
  reactions/decor remain effective and editable; global controls supply defaults.
  Prefix-local phrases cannot overwrite another screen's presentation. Panel
  suggestion callbacks validate reader/navigation; root release is idempotent.
- Plural parser imports header/boolean/nested-ternary fixes and additionally
  handles enclosing parentheses used by real Russian/Polish/Czech/Lithuanian
  headers. Existing global gettext remains untouched. 352 Swedish empty/new
  messages are completed, including visible new controls and games. All original
  catalog languages remain; this is not a claim of complete upstream prose
  translation in every locale.

Conflicts: CoverFinder combines callback optimization with exact original-field
restoration; Home boot combines guarded Home loading/full repaint with safe
deferred listing. Main keeps the reviewed migration implementation as above.
Japanese/Korean/Swedish/Vietnamese PO conflicts are reconciled by message identity:
upstream references/new phrases, retained actual translations and correct
single-form plurals. Remove one duplicate Swedish Row entry introduced by the
new action-grid message. No test baseline or failure allowance is expanded.

API-1 compatibility plan: thirteen new Lua source modules stay tracked complete
and export-ignore only their separate installed paths. The existing generated
module registry carries exact source strings in metatable metadata, preserving
the old string-valued path iteration API. Canonical loader compilation is lazy;
real files and userpatch preload win, real parse errors cannot silently fall
back, and legacy aliases share the canonical instance. No source extraction,
eager module execution, old asset/language/license deletion, new installed path,
bootstrap/API/file-limit change or new external dependency. Pin both reviewed
upstream SHAs; regenerate the map from 383 to 396 canonical paths. The sealed
checker verifies all thirteen exact source bytes/identities/syntax, while full
source/manifest and old-path equality audits remain mandatory.

Tests added/extended: 18 October 30 merge cases, runtime loader/patch guard cases,
hidden-cabinet actual shared menu handling, native-window API boundary and prior
finished-gate memoization boundary. Existing category-card, Home, cover, navigation,
settings, series/bindings/ornaments and external-owner suites remain. Supplemental
actual SQLite validates repeated-page turns versus distinct pages and duration.
Final full interpreter/sealed/package/native/history/CI evidence follows below.
Physical Boox/Bigme fonts/touch/D-pad/night/rotation/sleep/reader-profile/cover/
startup and native-image pressure acceptance remains open. No reader install or
user data/settings/credentials/artwork change; public Beta 16 is immutable and
VERSION stays Beta 16 solely for local development validation.

### Final local verification before push

Final source/package candidate: `3b47b194710d0169de7c0325ca5eb3fde1736dcd`.
Implementation `2573a869` is followed by test-only `53df3a9f` (sealed reader must
return one source value, not assert's additional diagnostic argument) and
`3b47b194` (explicit global/Home/quick-panel Critter scope, including its new
regression). The complete final sequential `scripts/test.sh` Lua and LuaJIT runs
pass: 122 Python tests/four unchanged optional source-pixel skips, all 85 root
Lua files, 487 Bookshelf suites/zero failures/three normal SQLite exclusions and
all 13 SimpleUI files. Map 396; LuaJIT syntax 1,081; all 43 catalogs validate.
All 85 root files ALSO pass on the final sealed bytes under both interpreters,
including 18 merge, 24 native-menu and eleven category-card cases. No new failure
waiver. The early harness/API-boundary and source-copy mistakes caught during
development are corrected; the final gate has no remaining failure.

Actual SQLite additionally verifies repeated page turns versus distinct pages
and positive-duration totals. Complete minimum-v2025.08 ReaderMenu plus the
previous pinned official ReaderMenu pass the expanded 24-case actual-menu
supplement. Native UI/font/engine boundaries remain stubbed, not device evidence.

Local development ZIP: **8,943,741 bytes**, expanded **26,251,910 bytes**,
2,066 entries, same 1,999 inventory files plus manifest/all 2,000 API-1 paths.
SHA-256 `2ca3ec818d82e3a14795902e172a8586d84e7e4277087be8aecfe852baf4c0ca`.
Every byte equals the exact candidate Git archive after only the approved PO
reference-comment projection; manifest sizes/hashes and checksum agree. Sealed
module checks verify all thirteen embedded Lua sources against tracked originals.
Bootstrap/entry/VERSION/fonts/icons/artwork and all old installed paths remain.
All 222 newly outgoing candidate blobs exclude held artwork; Gitleaks scans all
25 non-merge commits without leaks. Final documentation/history is re-audited
before push. Public Beta 15/16 cached ZIP digests remain unchanged.

Actual public Beta 15's older installer accepts the final local package with
native pinned KOReader libarchive/SHA: complete inventory extraction, missing-
module rejection, activation/restart/code rollback, truncated recovery, external
snapshot/restart/persistent rollback and interrupted obsolete-code cleanup/resume
with active/rollback/unknown/modified/user data retained. This is an isolated
macOS POSIX-shim fixture, not live discovery of a new release or a physical reader.
No actual user data was removed; only generated obsolete-runtime test fixtures.

Evidence: `test-results/upstream-20261030/` (`final-lua.log`, `final-luajit.log`,
`translations.log`, `sealed.log`, package/source/path/history audit, Gitleaks,
native-menu/SQLite and native OTA logs). Follow-up verification documentation
does not rebuild this ZIP. VERSION/public Beta 16 stays immutable; no tag,
release, production OTA or installed device change is authorized. Physical
acceptance and measured startup/memory gains remain open. Main CI/watch results
are checked after the standing audited push; publication still requires a
separate explicit request.
