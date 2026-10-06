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
