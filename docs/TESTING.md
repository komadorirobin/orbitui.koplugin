# Verification and device acceptance

## Automated

The unreleased Bento margin fix adds 12 OrbitUI cases executing the real page
builder over geometry-only widget stubs. It covers independent column/stack
margins, a warm layout cache, legacy module order, full-width/three-column rows,
topbar-off padding, narrow-row horizontal centring, landscape, custom screens,
labels/backgrounds and clock/book slot ownership. These are layout calculations,
not native painting or Bigme touch verification.
Both full Lua/LuaJIT runs pass with 275 OrbitUI cases, 46 Python checks,
351 Bookshelf suites (two native SQLite skips) and 13 SimpleUI test files.
All 41 translation catalogs pass. No version bump or public OTA release.

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
