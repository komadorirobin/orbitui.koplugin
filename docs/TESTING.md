# Verification and device acceptance

## Automated

2026-10-09 second upstream merge (local, unpublished, VERSION still alpha.31):
both complete Lua and LuaJIT runs pass 475 OrbitUI cases across 40 files, 351
Bookshelf suites (zero failures, two existing native SQLite suite skips), and
all 13 SimpleUI test files. Two existing font-dependent cases remain skipped.
Python runs 91 tests successfully with the same four external source-photo /
museum-cache audit skips; no artwork changes. All 42 translation catalogs pass,
265 module-map paths verify and 739 Lua files pass LuaJIT syntax validation.
No assertion, test suite or known-failure gate was removed to accept the merge.

The new follow-up suite exercises lazy radio/alignment menus, per-instance
settings, retained BookOrbit Want to Read and unsaved collection sources,
unchanged visual defaults, placeholder hook ownership across later third-party
patches, bounded shadow buffers with collision-free keys, and disposal of
off-screen placeholder sheets while cropped widgets own their slice buffers.
Existing series-box, completed-box, dock, Bento and ornament tests still pass.
The clean-commit package result is recorded with the merge's validation below.
Physical Bigme checks still required: no-cover book rendering/cropping in native
grids and Cover Deck, default/classic folder stacks, repeated native menus,
day/night shadows/backdrops and coexistence with external placeholder patches.
No device test, speedup, public push or OTA publication is claimed.

2026-10-09 upstream merge (local, unpublished, VERSION still alpha.30): both
complete Lua and LuaJIT runs pass 468 OrbitUI cases across 39 files, 351
Bookshelf suites (zero failures, two native SQLite suite skips) and all 13
SimpleUI test files. The existing font-dependent cases remain skipped. Python
runs 91 tests successfully with four original-photo/museum pixel audits skipped
because their external source caches are unavailable; artwork is unchanged.
All 42 translation checks pass with no baseline exceptions or new failures.
The generated module map verifies 264 paths and syntax checks cover 737 runtime
Lua files. No skip or known-failure allowance was added for this merge.

The new October 9 suite exercises legacy/new page state, non-destructive close
target migration, legacy badge scales, classic versus opt-in tab icons, shared
hook lifetime and exception-safe margins, retryable SQL/cover failures, DB/WAL
cache invalidation, native reader close targets and day/night wallpaper erasers.
Additional regressions cover direct layout saves and transient decoded-cover
failures without losing warm-cache reuse. Existing icon, navbar, Bento, reading
sync, statistics, series-box and ornament tests remain green. Read-only upstream
collection at 05:11 UTC reports zero missing commits for both components.

Still needs physical Bigme verification: closing books to each configured
destination, repeated menu/reader opens without shrinking margins, Bento and
custom-screen spacing, live bottom-margin changes on Home and Bookshelf, optional
titlebar tabs with custom icons, paginated backdrop opacity and night mode.
No device test or measured speedup is claimed. Adaptation commit `bf5ea7b2`
passes clean-commit sealed ZIP validation: 1661 runtime files, 1714 archive
entries, all module/asset/license/recovery checks. This is a local development
package, not replacement bytes for the published alpha.30 release. This task
does not publish, tag, change OTA or modularize the UI. The older checkpoints
below describe their own historical candidates.

Frontal Ahrens/Mann replacement (local, unpublished): eight Python asset checks
cover exact source-photo/mask reproduction, hashes and licenses, unchanged
author biography and other ornament PNGs, frozen published baselines, and
recognition of the real alpha.23 metadata/notices. The shared artwork updater's
32 Lua cases include completed alpha.23 markers, custom/deleted/linked artwork,
native placements, interrupted writes and retry. The full source-audited Python
suite passes 88 checks; full Lua and LuaJIT runs pass 389 OrbitUI cases, 351 Bookshelf
suites (two SQLite suite skips; existing native-font cases also skipped), all
13 SimpleUI files, and all 41 translation checks. The light/dark shelf comparison
was visually reviewed; it is not a screenshot from a reader. An isolated-index
runtime ZIP passes inventory and archive integrity checks (1320 manifest files,
1371 entries); its embedded Mann PNG matches the reviewed SHA-256. This is an
unpublished working-tree package, not a replacement alpha.23 release or a
clean-commit release build. Physical-device appearance and migration remain
untested. No publication requested.

Mann/Molgreen replacement (local, unreleased): fifteen targeted Lua cases
cover both old image hashes, a completed v1 marker, current-image retries,
old versus custom notices, default placement triples, custom/deleted/linked
artwork and byte-limited captions. Seven Python cases include source/mask/PNG
provenance, exact reproduction from the original photo, repeatable credit
generation, native zoom/colour/base alignment and unchanged Joyce/Woolf/Kafka.
The clean contour was visually reviewed on light/dark backgrounds. Full Lua and
LuaJIT runs pass 372 OrbitUI cases, 82 Python checks (museum and sculpture source
audits included), 351 Bookshelf suites (two native SQLite suite skips) and all
13 SimpleUI test files. The existing font-dependent cases remain skipped.
All 41 translation checks pass. Clean-commit runtime packaging is the final
local gate; no version bump or public artifact replacement is authorized here.
Physical-device appearance and migration remain untested. No release or public
push is implied; the retired Mann bitmap remains held in unpublished history.

Earlier checkpoints (before the Molgreen replacement):

Authors II (local, unreleased): full Lua/LuaJIT runs pass 370 OrbitUI cases,
80 Python checks, 351 Bookshelf suites (two native SQLite suite skips), all
13 SimpleUI files and 41 translation checks. The two new author bindings are
included in name/alias, row-placement and 27 pagination configurations; two seed
regressions cover additive installation and retries without rewriting old packs.
Five asset checks cover photo/mask/PNG provenance, byte-for-byte reproduction,
colour/alpha, native base offsets, zoom/info, caption limits and reproducible
metadata generation. All original-photo audits ran with the external source
cache. Both cutouts were visually reviewed on light/dark backgrounds.
Existing Modernists/Authors images and frozen migration baselines are unchanged.
The clean-commit runtime ZIP is checked separately. Physical-device placement,
native zoom/info and colour display still need user testing; Hemingway's large
zoom is limited by source detail. Dazai is deferred, not bundled. No public
release or claim that Mann's existing rights hold has been resolved.

Six photographic author replacements (local, unreleased): full Lua and LuaJIT
runs pass 366 OrbitUI cases, 75 Python checks, 351 Bookshelf suites (two native
SQLite suite skips), and all 13 SimpleUI files. All 41 translation checks pass.
The Python run includes both the museum-original audit and the six source-photo
pixel audits. New tests cover resumable checksum-only upgrades, custom/removed/
linked artwork and captions, frozen old hashes, source/mask provenance, RGBA,
base alignment, biography limits and startup ordering. Light/dark cutouts were
visually reviewed; Joyce/Woolf/Kafka/Mann PNG hashes are unchanged.

Run the extra source audit with `SCULPTURE_SOURCE_CACHE=<downloaded-photo-dir>`.
Without the cache, that single audit is skipped, not silently claimed complete.
The installed-device upgrade, colour-screen appearance and native zoom/info
still need physical-device testing. Dostoevsky's enlarged image is source-detail
limited. No public release; Mann's separate sculpture-rights hold remains.

Mann replacement (local only): thirteen Lua/LuaJIT cases cover exact-checksum
replacement, custom/deleted artwork and metadata, linked paths, one-time cost,
corruption, byte-limited captions and interrupted writes/retries. Five Python
checks verify provenance, transparent colour output, native base alignment,
frozen old credits, release hold and unchanged other authors. Integration tests
cover migration ordering and the generic biography updater's Mann exclusion.
Physical-device appearance, touch/zoom/info and installed-default migration
remain manual checks. Public redistribution is on hold; see the Seitz notice.

Lispector retirement (unreleased): ten Lua/LuaJIT cases cover exact-checksum
deletion, custom replacements, absent images/packs/metadata, symlinks, hash/remove
failures, interrupted markers, intervening edits, one-time cost and retained
custom-image author binding. Biography tests cover the missing retired runtime
entry and startup ordering. Pack validation must reject a bundled Lispector PNG;
the old biography source and frozen historical baselines remain available.
No device test or OTA publication is implied by these headless checks.

The unreleased Kafka replacement adds ten Lua/LuaJIT migration cases and four
Python asset checks. Cover old/current image checksums, caption/notice migration,
custom and deleted files, custom positioning/enablement/native overrides,
interrupted atomic writes through marker completion, retry after intervening
edits, corrupt input and no hashing after completion. The biography suite also
checks that Kafka's credits are owned by the artwork-aware migration. Check
RGBA transparency, retained bronze colour/provenance, native base alignment and
the distinct photo/sculpture rights notice. Physical Bigme appearance, scale,
tap-to-zoom/info and migration from an actual alpha.20 install remain device checks.
Full Lua/LuaJIT verification passes 335 OrbitUI cases, 65 Python checks (museum
pixel audit included), 351 Bookshelf suites (two native SQLite skips), all 13
SimpleUI files and all 41 translation catalogs.

The unreleased author-info addition has 12 Lua/LuaJIT regressions for caption-only
updates, independent markers, startup ordering, custom/empty/deleted fields,
unchanged placement/enablement, reader overrides, deleted packs, bad JSON,
UTF-8 byte limits, atomic write/close/rename failures and partial-update retries.
Three Python checks cover all eleven sourced biographies, reproducible cards,
verbatim artwork credits, default README updates and unchanged metadata fields.
Existing PNG/provenance hash checks remain in force. The native zoom/info panel
is reused without changes. Physical Bigme scrolling, Swedish text and taps are
still device checks; automated tests do not render its native widgets.
Both full Lua/LuaJIT runs pass with 324 OrbitUI cases, 61 Python checks including
museum-source pixel auditing, 351 Bookshelf suites (two native SQLite skips)
and all 13 SimpleUI files. All 41 translation checks pass.

The unreleased gallery height follow-up extends the native placement regression
to 240 DPI/row-height/aspect/width combinations using the actual plank geometry.
It reproduces alpha.20's overlap and requires at least 5% of the stand height
as clear wall above the plank's back edge at the new 20% lift, without crossing
the upper row. Five additional Lua/LuaJIT cases cover v2-to-v3 migration,
zero-valued reader overrides, custom positions, deletions, no replay of v2,
atomic failures and interrupted notice/marker writes. A Python check locks the
compact alpha.20 baseline and all 27 new defaults. Physical Bigme spacing still
needs confirmation; the gallery preview is only an asset contact sheet.
Both full Lua/LuaJIT runs passed with 312 OrbitUI cases, 58 Python checks
(museum-source pixel audit included), 351 Bookshelf suites (two native SQLite
skips) and all 13 SimpleUI files. All 41 translation checks passed.

Alpha.20 packages the reviewed October 6 import and the gallery correction below.
Publication gates rerun the full Lua/LuaJIT suites, translations and clean-commit
sealed packaging, then exercise native OTA from the actual published alpha.19
installer. Downloaded draft assets, both CI jobs and anonymous public OTA must
pass before closing publication. These are headless checks, not Bigme acceptance.

The 2026-10-06 reviewed SimpleUI import adds 13 regressions covering isolated
layout drafts, repeated saves, module removal/re-addition, preserved clock
visibility, custom screens, legacy layout normalization, live start-view settings,
native radio callbacks, Unicode fallback, quote line-break rules and action-list
widths. These tests execute native functions with settings/widget stubs, not a
physical reader. Both full Lua/LuaJIT suites pass: 307 OrbitUI cases, 57 Python
checks with source-cache pixel auditing, 351 Bookshelf suites (two native SQLite
skips) and all 13 SimpleUI test files. All 41 translation catalogs pass.
See MERGE_LOG.md for the reviewed revisions and final packaging gate.

The alpha.20 gallery wall/info correction adds 10 Lua/LuaJIT cases for the
v1-to-v2 metadata migration and native placement calculations across 60
height/aspect/width combinations. Tests preserve reader/pack overrides, images,
theme files and deletions, and exercise corrupt JSON, failed writes/renames and
partial-upgrade retries. A Python regression locks unchanged PNG/theme bytes
against alpha.19 and checks that only lift/info defaults change. Info cards
remain below the native 4000-byte (not character) limit and label their sources.
Full Lua and LuaJIT runs passed: 294 OrbitUI cases, 57 Python checks (including
the museum-original pixel audit), 351 Bookshelf suites (two native SQLite skips)
and all 13 SimpleUI test files. Translation validation passed all 41 checks.
The full release gates remain required; none of these tests simulate Bigme UI.

Alpha.19's Ukiyo-e Gallery adds 8 installer/native-theme cases, one session
shuffle regression and 10 asset/build checks. The museum source-cache pixel
audit is enabled with `UKIYOE_SOURCE_CACHE=/tmp/orbitui-ukiyoe-sources` (Pillow
required). It checks actual source hashes and unchanged art pixels in all 27
frames. CI can run metadata/hash/format checks without Pillow or networking;
optional pixel audits clearly skip when their build-time inputs are absent.
Both complete Lua/LuaJIT suites pass with 284 OrbitUI cases, 56 Python checks
(including the source-cache pixel audit), 351 Bookshelf suites (two native
SQLite skips), and 13 SimpleUI test files. All 41 translation catalogs pass.
The release gates also cover a sealed archive, native OTA from the published
alpha.18 installer, draft-asset byte verification, both CI jobs and anonymous
public discovery/install/rollback. The stable bootstrap/API 1 and upstream pins
remain unchanged.
Visual proof sheets are not physical e-ink acceptance; see `ORNAMENTS.md`.

Alpha.18's Bento margin fix adds 12 OrbitUI cases executing the real page
builder over geometry-only widget stubs. It covers independent column/stack
margins, a warm layout cache, legacy module order, full-width/three-column rows,
topbar-off padding, narrow-row horizontal centring, landscape, custom screens,
labels/backgrounds and clock/book slot ownership. These are layout calculations,
not native painting or Bigme touch verification.
Both full Lua/LuaJIT runs pass with 275 OrbitUI cases, 46 Python checks,
351 Bookshelf suites (two native SQLite skips) and 13 SimpleUI test files.
All 41 translation catalogs pass. The alpha.18 publication request adds the
release gates: rerun both suites/translations on the versioned tree, sealed ZIP
checks, native OTA from the published alpha.17 installer, draft-asset byte
verification, both CI jobs and anonymous public discovery/install/rollback.
The stable bootstrap/API 1 and the previously reviewed upstream pins remain
unchanged; new physical-device verification is still pending.

The ordinary-ornament row limit adds ten OrbitUI regressions and strengthens
the 27 author-placement pagination configurations. Tests cover bust priority,
multiple author busts sharing a row, book/bust carry-over, group/end slot
competition, optional native defaults,
empty/oversized pieces, balanced row constraints, saved page-start deck state
and the real planner's constraint wiring. Device checklist: `ORNAMENTS.md`.

The 2026-10-04 upstream merge adds 13 focused OrbitUI cases for SimpleUI's
Android zlib fallback, fresh header/callback ownership, streak mutators and
live-stat refresh routing. Four more component cache tests cover streak-only
invalidation of partial, valid, fully invalidated and previous-day book counts.
Bookshelf's optimized exhaustive row-budget suite now runs by default.

Alpha.17 extends coverage to 240 OrbitUI cases and 46 Python checks. New cases
cover eleven authors, independent/additive pack installation, native alphabetical
series-block sorting, five colour Japan ornaments and a session-stable startup
shuffle. The release OTA smoke test uses the actual published alpha.16 installer.
The complete component suites and translation checks remain required. Physical
Bigme rendering, touch, series navigation and sleep/restart behavior still need
the checklists in `ORNAMENTS.md` and `SHARED_UI.md`.

Alpha.14 adds 23 Lua tests for author-bound busts, native fill/balancing and safe
one-time asset installation, plus two Python checks for the reviewed PNG bytes,
alpha format, placement metadata, prompts and separate artwork notices.
Pagination/render parity is checked in 27 combinations of width, row count and
ornament frequency. The native OTA upgrade uses the published alpha.13 installer.
Physical e-ink appearance and native touch/zoom remain device checks.

- `sh scripts/test.sh`: LuaJIT syntax, integration tests, and original component suites.
- `LUA=luajit sh scripts/test.sh`: the same test bodies under KOReader's Lua dialect.
- `sh scripts/check-translations.sh`: validate catalogs with explicit baseline exceptions.
- `python3 -m unittest discover -s tests -p 'test_upstream_watch.py' -v`: monitor,
  error handling, real Git ancestry and idempotent reporting tests; no network.
- `sh scripts/package.sh`: clean-commit runtime ZIP, archive integrity and layout checks.
- `tests/test_shared_*.lua`: shared panel/controller ownership, native registered
  actions, Home pin persistence and isolation, live source resolution, scoped
  search, settings routing and native source fallback boundaries.
- `tests/test_face_out_shelves.lua`: all-cover shelf policy for existing Library
  and Manga settings, native shared render/pagination options, no recent-book
  scan, read-only native style row and untouched saved drafts. Standalone
  Bookshelf configuration and grid/list/Auto/OPDS behavior remain native.
  Physical rendering, page turns, rotation and tap targets still require the
  shelf check in `SHARED_UI.md`; these tests do not simulate native painting.
- `tests/test_icons.lua` exercises the actual icon pickers/render helpers and
  shared modal init/refresh with native widget stubs: Material SVG paths,
  unchanged Nerd rendering, image-only
  destinations, per-icon selection/cancellation, rejection of the legacy bulk
  preset, retained preferences and rebasing old OTA asset paths. The Font stub
  rejects Material font loads; both pickers exercise all 110 icons. Weight
  tests round-trip all 440 qualified choices through IDs, tokens and OTA paths,
  preview every weight, preserve search/category/page state, reopen saved
  weights and verify cancel/no-write behavior and independent icon settings.
  Material modal construction runs in English and Swedish, portrait/landscape,
  with and without directional keys. Tests cover category labels, rendered cell
  paths, search/filter refreshes, pagination and empty results. Native painting,
  text measurement and keyboard behavior are still not simulated.
  `tests/test_icon_recovery.lua` covers the real module resolver/store with
  fake persistence: delayed startup loading, no writes/deletes, unrelated reads,
  idempotence, an existing preload and restoration when the patch is removed.
  `tests/test_material_assets.py` verifies the pinned asset inventory, static
  TTF character coverage, self-contained SVGs and license notices. It verifies
  the four weight inventories, distinct outlines, the weight-300 static font
  and byte-identical legacy aliases. The build
  requires FontTools only when regenerating assets, not for tests or on-device.
  Solar/Tabler extend the same modal tests to all three sources, both languages,
  orientations and key modes. All 235 vector SVG identities round-trip through
  values, Bookshelf tokens and old OTA paths. Material weight changes leave
  these sources unchanged. Per-icon cancellation, image-only gating, native
  tab registration and alpha-renderer routing are covered without loading fonts.
  The additional Solar Database, Cloud Download, Download Minimalistic and
  Library icons have focused search/category and selection coverage in both styles.
  `tests/test_vector_assets.py` checks pinned sources, exact output checksums,
  local SVG geometry, styles and attribution. The optional CairoSVG/Pillow
  contact sheet is a desktop preview, not a KOReader/e-ink rendering test.
- OTA tests cover release channels, semantic versions, archive safety, TLS host
  checks, deferred activation, interrupted startup and rollback. `OTA.md` records
  the protocol and recovery limits. Package tests verify inventory and checksum bytes.
- The LuaJIT CI job tests the full packaged installer against pinned KOReader-base
  archive/SHA modules (`fe41d7698ad8a6a7caf794d9b601229009a34053`) and system
  libarchive. The smoke harness substitutes only the filesystem/network/JSON
  adapters, not archive extraction or hashing. It tests activation, restart,
  rollback, a missing runtime file and a truncated download in a temporary install.
  `scripts/smoke-ota.py ZIP REFERENCE_DIR --live` additionally tests anonymous
  release discovery and download with real LuaSocket/LuaSec and `lua-cjson`.
- CI validates both components' translation files and stores an experimental ZIP
artifact. It does not publish releases or modify upstream repositories.

`scripts/test.sh` includes the monitor tests. Python 3.9+ is a development/CI
dependency only; it is not installed or needed on KOReader. The monitor has a
separate workflow and cannot publish plugin packages. See `UPSTREAM.md`.

Run the two full suites sequentially on the same host. Some upstream tests
use hard-coded, second-resolution `/tmp` paths (for example the start-menu
module fixture), so separate `TMPDIR` values alone do not prevent collisions.

Bookshelf's two native SQLite suites require KOReader's runtime and remain
explicit skips. Since the 2026-10-04 upstream merge, its exhaustive list geometry
sweep runs by default after upstream memoised the repeated source matching.
These headless checks must not be presented as device verification.

All 41 catalogs pass `msgfmt --check` after the 2026-10-03 merge. Upstream fixed
the Italian header; the integration removes identical extra plural forms in
five single-form languages and corrects the Lithuanian plural rule. No failure
exceptions remain in `tests/translation-baseline.txt`. Header-only warnings in
some catalogs remain upstream debt; passing syntax does not verify translation
quality or completeness.

## Before calling the alpha device-tested

The user reported successful initial startup/navigation on the Bigme with
`0.1.0-alpha.2`, and a subjective impression of faster dock navigation. This is
not a timing measurement, full acceptance, or a device OTA/recovery test.
The upstream merge and renamed menus in `0.1.0-alpha.3` still need device testing.
The shared surfaces in `0.1.0-alpha.4` also await device acceptance.
Version `0.1.0-alpha.5` remains a preview: its Bookshelf 5.3.1 changes and
transparent folder-pagination fix have headless regression coverage, not a
completed physical-device check.
Version `0.1.0-alpha.6` added the optional Material icon pack. The user reports
that choosing its bulk preset causes repeated startup crashes on the Bigme.
There is no crash log yet; the user cannot reach the log-export menu. The exact
crash site is unconfirmed. The old tests accepted any Font path and missed the
native rendering risk: KOReader does not resolve bare relative custom-font paths
like absolute or `./` paths, and a missing face can fail inside TextWidget.
The user restored alpha.5 and reports that KOReader starts again. That confirms
recovery, not alpha.7 device acceptance. The alpha.7 correction removes Material
font rendering and bulk application, with 16 focused icon tests and 6 recovery
tests. The native OTA smoke harness also accepts the published alpha.5 archive
via `--base-zip` to test the old installer rather than only a simulated version
number. Those tests and the asset checks do not replace physical-device startup,
touch, layout and e-ink checks.

After alpha.7, the user reported a crash on opening Material from the individual
icon picker. This is reproduced in Lua and traced to the adapter's category loop:
its numeric `_` index shadowed the translation function, failing in real modal
initialization before any SVG was rendered. Renaming that index fixes this
specific crash without changing saved icons. The original tests replaced the
whole modal with a passive widget, so never called its category callback. They
now construct and refresh the real modal over native widget stubs, and the
regression fails against the old adapter. This correction is not yet a
physical-device verification or evidence for the earlier alpha.6 startup cause.

The alpha.9 per-icon weight control uses the same SVG rendering path, with
300 as the requested new default. Its 23 focused icon tests pass in Lua and
LuaJIT; the added popup, native preview appearance and touch interactions still
need device verification. Existing unweighted Material choices intentionally
become lighter, without changing their identity or rewriting settings.

The alpha.10 Solar/Tabler sources have 29 focused icon tests and 4 additional
asset tests, plus desktop rendering checks for all 227 packaged SVGs and both
custom source SVGs. Its real-modal tests still stub native widgets. Device
startup, touch selection, sizing, night mode and duotone contrast remain to be
verified. No existing icon choice or Material weight changes in this release.

Alpha.11 adds eight packaged SVGs (four icons in two Solar styles) and one
focused search/category/selection test, for 30 icon tests and 235 vector icons.
All eight additions were previewed at 144 and 40 pixels on desktop. The native
OTA smoke test uses the published alpha.10 installer; physical-device rendering
and selection still need verification. No renderer or bootstrap changes are made.

Alpha.12 makes all books cover-forward in the shelf/spines style. Five focused
tests exercise the integration policy and real native geometry/editor helpers;
the existing component suites retain planning and pagination coverage. Native
OTA checks use the published alpha.11 installer. Bigme shelf rendering, page
turns, rotation and tap/hold targets still need the checks in `SHARED_UI.md`.

The user confirms alpha.12's cover-facing appearance but reports its lower shelf
overlapping pagination and the dock. The alpha.13 height correction adds seven
tests to Bookshelf's `_test_tall_screen.lua`: the 1264 x 1680 case, live dock and
footer sizing, retained hero height, expanded viewport behavior and a 432-case
portrait/landscape, row-count, chip-visibility and footer-settings matrix.
Five of these tests fail against alpha.12, including a 160px dock overlap in the
two-row fixture; the corrected geometry passes. The tests load the real widget
over native stubs, not a painted KOReader screen. Device verification is pending.
Native OTA checks use the published alpha.12 installer, including activation,
restart, rollback and incomplete-package rejection.

Use the Bigme B7 Pro at its native 1264 x 1680 resolution. Retain a recovery path.

- For the 2026-10-06 import, hide the clock face but keep date/battery visible;
  save/reorder other modules repeatedly, then remove and re-add the clock on
  Home and a custom screen. Confirm the expected visibility and style resets.
- Switch the start view through both native and OrbitUI menus, restart, and
  check that the selected destination opens. Inspect quote, clock and action-list
  horizontal margins with/without module backgrounds in narrow Bento columns;
  check quote wrapping on the reader's native text engine.
Record KOReader version, installed patches and active plugins, plus crash.log.

- Verify original-plugin conflict detection before enabling the alpha normally.
- Confirm Home layout, dock, backgrounds, icons, custom screens, fonts and language.
- For the corrected Material picker, follow `ICONS.md`'s device checklist. Verify
  readable manga icons in the dock and shelf chips, correct resizing/dimming and
  native menu tabs, mixed old/new icons, restart and an OTA-slot change. Loading
  the new build alone must not change an existing icon identity. Unweighted
  Material choices now use 300, while explicit weights and other icon sources
  must remain unchanged. Check all four preview weights, reopen individual
  selections and cancel both the thickness popup and the main picker. Headless tests do
  not verify native SVG rendering, e-ink contrast or real touch/layout behavior.
- With transparent book titles/page indicator enabled, check the root shelf,
  a folder list, a nested folder and full-screen modules for a line-free pager.
  The hero/chip/list panels and dock separator must remain unchanged. Toggle
  the option off/on and check both orientations and custom pagination margins.
- For the Bookshelf 5.3.1 import, verify pagination focus/page-turn refreshes
  above the dock without flashing the hero or leaving an old focus ring. With
  directional keys, reach every spine book, switch detail tabs and cover buttons,
  navigate the shelf editor, and cancel shelf/top-panel resizing with Back.
- From a filtered shelf and Home/search book panels, open a series, author,
  genre and collection via their pills. Verify the whole group, return from a
  book and search the current group; keep the prose/manga scope and the original
  shelf filter. Ordinary shelf stacks and folder navigation retain that filter.
- Test new per-element fonts and module opacity alongside existing light
  backgrounds; verify section labels and live cover/stat updates after swipes.
- For Bento margins, put a 55% Want to Read carousel beside 45% Recent Books
  and 45% New Books stacked on the right. Change New Books' Top Margin through
  0%, 100% and 300% from both module settings entry points. Only that module
  should move within the row; its label must move with its covers. Check the
  first right-column module independently, change pages and return, restart,
  and repeat in landscape/a Custom Screen with labels/backgrounds toggled.
  Columns now start at the row's top rather than being vertically centred;
  retain saved settings and verify full-width spacing is unchanged.
- Check shelf themes, planks, ornaments and wallpaper picking at both orientations.
- Confirm existing settings, Hardcover links and status-line preferences remain
  in their original files after startup, edits, restart and rollback.
- Open Fiction and Manga from the dock, and switch between them repeatedly.
- Open books from Home, Want to Read, Currently Reading, search and a folder.
- Verify the expected automatic reading profile for every opening path.
- Close using the custom gesture, native menu and end-of-book dialog; confirm the
  intended destination and no unintended reopening or duplicate menu layer.
- Verify rotations, overlays, menus, long-press actions and exit/restart.
- For the shared UI work in `0.1.0-alpha.4`, execute the focused device checklist in
  `SHARED_UI.md`. Headless widget stubs do not verify fonts, layout, touch hit
  regions or the complete real FileManager/ReaderUI transition.
- Suspend and resume on Home, in each library view and inside a book. Repeat
  several cycles, including an overnight resume.
- Confirm BookOrbit progression prompts actually move the reading position.
- Check Hardcover linking and one intended sync writer; confirm no duplicate reads.
- Check MAL folder actions, badges and a completed-volume update.
- Check manga header, volume suffix and bookmark ribbon/userpatch compatibility.
- Confirm component update actions cannot download or install standalone plugins.
- Install an OrbitUI preview through its common updater, cancel a download,
  restart into the staged version and test previous-version rollback. Confirm
  the public release is found without a GitHub token and its displayed version
  matches the active runtime. Check cancellation and restart dialogs on Android.
- Test rollback without resetting book progress, links or UI configuration.

Record cold-start, warm Home/library switch and book-close times against the
published predecessor versions with the same books and settings. Compare memory
after repeated open/close cycles. Do not claim a performance gain without these
measurements.

Device acceptance is outstanding until this checklist has been executed. A
single plugin package alone is not evidence of improved performance or stability.
