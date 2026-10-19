# Verification and device acceptance

## Automated

2026-10-19 dashboard card headings (unpublished): exercise all nine editors from
both the shared and native module settings entries. Cover saving, cancel,
per-card reset, blank/invalid values, module reload, per-screen isolation,
Swedish/English menus and unchanged user text after language switches. Renderer
checks cover long UTF-8 headings at three screen sizes and DPI factors in both
hero colour modes, refresh/paging retention and dynamic hero/goal defaults.
Evidence belongs in `test-results/dashboard-headings-20261019/`. Run full
sequential Lua/LuaJIT suites, translations and a clean-commit package; do not
replace the published alpha.50 asset. Bigme keyboard/menu, font truncation and
immediate redraw acceptance remain open.

Completed automated gates: 677 Lua / 678 LuaJIT root cases in 54 files (27
dashboard cases), 407 Bookshelf suites and all 13 SimpleUI files on both
runtimes. Python: 103 tests with four existing external-artwork-source skips;
Bookshelf retains two existing environment skips. All 43 translation catalogues,
318 module paths and 874 syntax files pass. No new exceptions were added.

2026-10-19 alpha.50 publication preparation: explicitly requested after the
verified Bookshelf 5.5.4 merge at `82fd72c9`. Only VERSION and release documents
change during preparation. Re-run complete sequential Lua/LuaJIT suites and
translations, seal a clean-commit runtime and audit all outgoing history for
held artwork and secrets. Compare bootstrap files, SimpleUI and existing assets
with the public alpha.49 ZIP. Exercise the actual alpha.49 installer's native
upgrade/restart/rollback and failed-download recovery; verify both CI jobs and
downloaded draft/public bytes, including anonymous OTA discovery. Evidence
belongs in `test-results/alpha50-20261019/`. Publish as a prerelease; the physical
Bigme checks below remain open, and no device acceptance is inferred.

2026-10-19 reviewed Bookshelf 5.5.4 merge (unpublished): import `982375a7`
after `c7a9db2c`; SimpleUI stays at `7eb80f9e`. Run complete sequential Lua and
LuaJIT suites, translations, then a clean-commit package. Evidence belongs in
`test-results/upstream-20261019/`. New regressions cover native/host binding
control exclusivity, preserved profile/series choices, per-root history sorts,
and embedded dock priority with FileManager or a parked reader. All incoming
cache, deferred-statistics, e-ink refresh, binding and gesture suites must run.
No new failure allowances or upstream settings migrations are permitted.

Completed: both runtimes pass all 407 Bookshelf suites, all 13 SimpleUI files
and root integration tests (670 Lua / 671 LuaJIT cases including the four
separately run Lua dock cases). All 43 translation catalogues, 318 mapped paths,
874 syntax files and the 103 Python checks pass, with the existing four artwork
cache and two KOReader-SQLite suite skips. The added profile-scoped history-sort
case also passes its focused Lua run. Clean committed source `05cb0b83` packages
successfully with 1,888 manifest files and stays within the reviewed OTA bounds.
The final documentation-only commit is repackaged, never published over alpha.49.

On the Bigme, still verify Pocket/Kanzenban and series overrides, completed and
partly filled boxes, MAL/title cutouts, Library/Manga dock taps/holds, gestures
in ornament zoom/book details after returning from reading, opt-in full-refresh
cadence in day/night mode, and reopening cached statistics cards. Headless
tests do not establish device timing, rendering or touch acceptance. VERSION
and published OTA assets remain unchanged until a separate publication request.

2026-10-18 alpha.49 publication: the user confirmed the alpha.48 installation
and restart, satisfying the bridge prerequisite. Publish the pending Manga /
Manga II ornaments and Solar v1.1.0 icons with the already-reviewed updater.
Re-run sequential full Lua/LuaJIT suites, translations, clean-commit packaging,
original-artwork/outgoing-history audits, native alpha.48 upgrade/rollback,
CI and downloaded draft/public bytes. Evidence belongs in
`test-results/alpha49-20261018/`. Keep bootstrap files and upstream pins intact,
and preserve the unpushed design branch. No physical-device acceptance of the
new artwork is claimed; check series adjacency, enabled-pack selections,
tap-to-zoom and icon rendering on the Bigme after installation.

2026-10-18 alpha.48 bridge preparation: the user chose an OTA-compatible small
intermediate release before publishing the larger artwork bundle. Build from
public alpha.47 only; keep all assets, bootstrap files and upstream pins
byte-identical. Test 128 MiB ZIP / 256 MiB expanded bounds, retained per-file,
file-count and manifest limits, and the longer bounded file-download timeout.
The package sealer enforces the same limits and the native smoke harness now
executes release selection before download/extraction.

Gates: full sequential Lua/LuaJIT suites, translations, a clean sealed ZIP under
64 MiB, actual alpha.47-to-alpha.48 native OTA/rollback, a private over-64-MiB
fixture accepted by alpha.48 but rejected by alpha.47, outgoing-history/artwork
audits, both CI jobs, draft download hashes and anonymous public OTA. Evidence
belongs in `test-results/alpha48-bridge-20261018/`. Headless checks are not Bigme
device acceptance. Do not publish the large successor until the user confirms
alpha.48 has been installed and KOReader restarted.

2026-10-18 alpha.47 publication preparation: requested after `31f5fdfc`, including
the opt-in Reading dashboard, independent two-way book-row paging and the earlier
per-shelf title-on-cover option. Re-run complete sequential Lua/LuaJIT suites,
translations and a clean-commit package. Audit all outgoing history/runtime
assets against published alpha.46, retain stable bootstrap/API 1, and test the
actual alpha.46 installer's upgrade/rollback and failed-download recovery.
Verify both CI jobs, downloaded draft assets and anonymous public discovery,
download and installation. Evidence belongs in `test-results/alpha47-20261018/`.
No device acceptance is inferred from these gates: physical Bigme typography,
touches, night mode, rotation and reading-return behavior remain to be checked.

2026-10-18 optional Reading dashboard (unpublished): `tests/test_dashboard.lua`
checks additive enable/disable and later user edits, duplicate/finished/abandoned
book filtering, existing cached goal/source selection, no-cache/offline handling,
auto-refresh opt-out, card chrome ownership, footer/margin reservation, five
screen geometries at three DPI factors, native book/hold actions, independent
two-way cover pagination, disabled end arrows, partial last pages, changed lists,
progress refresh and borrowed-cover replacement. Shared-menu tests cover its
registration and entry point. The optional
`ORBITUI_DASHBOARD_PREVIEW=/path/preview.svg lua tests/test_dashboard.lua`
renders a schematic of those widget positions with illustrative data/cover art
and approximate fonts; it is not a native raster/font test. Full evidence lives
under `test-results/dashboard-20261018/`.

2026-10-18 per-shelf series-title placement (unpublished follow-up to alpha.46):
complete sequential Lua/LuaJIT runs passed with 626/627 root cases in 52 files,
395 Bookshelf suites, all 13 SimpleUI files and 91 Python checks. All 43
translation catalogues pass; 317 module paths and 852 LuaJIT syntax files pass.
Existing SQLite/native-font/absent-Bookends and four external artwork-source
audit skips remain; no new failure allowances. Evidence is under
`test-results/series-title-20261018/`.

Focused tests cover independent native/nested/prose/manga shelf choices,
reload and invalid preferences, English/Swedish menus, immediate invalidation,
warm planner/pagination parity, full-height aspect-true bottom fitting, long
and CJK titles, tiny images, completed boxes, MAL/count separation, changing
custom-image dimensions, day/night/DPI and text reinit/free ownership. A
schematic preview from native paint calls was inspected; it is not a device
screenshot and uses placeholder art, stubbed spines and approximate fonts.
Package only a clean commit and compare its complete inventory to published
alpha.46; never replace the published asset. VERSION remains alpha.46, with
no push, tag, release or OTA change. Physical Bigme font legibility, colour/night,
small/large boxes, Paperback/Kanzenban and tap/hold still need device acceptance.

2026-10-18 alpha.46 publication preparation: explicitly requested after the
rounded rating-notch follow-up `fdc7958d`. Complete sequential Lua/LuaJIT gates
passed on the versioned tree: 615/616 root cases in 51 files, 395 Bookshelf
suites, all 13 SimpleUI files, 91 Python checks, 43 translation catalogues,
317 module paths and 850 syntax files. Nine actual MAL provider probes also
passed on each runtime, using fixture settings without plugin initialization
or network. Existing SQLite/native-font, absent-Bookends and four external
artwork-source skips remain; no failure allowances were added.

The remaining publication gates seal a clean-commit package.
Audit the full inventory and outgoing history, including held artwork; compare
bootstrap/API, upstream pins and assets with public alpha.45. Exercise the
actual alpha.45 installer for upgrade/rollback and truncated-download recovery,
both CI jobs, downloaded draft hashes and anonymous public discovery/install.
Store evidence in `test-results/alpha46-20261018/`. Only VERSION and release
documentation change during publication preparation. Physical-device corner,
colour/night, typography and interaction checks remain open; this is a prerelease.

2026-10-18 rounded MAL cutout (unpublished follow-up to alpha.45): the rating
uses the native stencil, mirrored to the top-left, instead of an overlay frame.
Focused checks cover mirrored light edges/curves, text-dependent notch widths,
unchanged aspect/geometry, label/count/title separation, tiny-cover omission,
score removal/restored pixels, day/night ink, custom-image refits/fallbacks,
provider isolation and text lifecycle. Complete sequential Lua/LuaJIT gates
pass 615/616 root cases in 51 files, 395 Bookshelf suites, all 13 SimpleUI files
and 91 Python checks. All 43 translation catalogues, 317 module paths and 850
LuaJIT syntax files pass. Existing SQLite/native-font/external-artwork/absent-
Bookends skips are unchanged. Nine actual MAL-provider fixture probes also
pass on each runtime without plugin initialization or network access.
Logs, the shape-only preview and clean-commit package audit belong in
`test-results/rating-notch-20261018/`; no device acceptance or publication is
implied. The package comparison allows only the two renderer/adapter files
and four documentation files to differ from published alpha.45.

Device checks still required: inspect the corner on actual colour and greyscale
e-ink, particularly Paperback/Kanzenban, small covers, large badge fonts, night
mode and fully read series. Confirm rating refresh/unlink, count/overflow/name
clearance and unchanged tap/hold behavior. The preview uses schematic artwork
and approximate fonts, not native device pixels.

2026-10-18 alpha.45 publication preparation: explicitly requested after the
Kanzenban (`a8dd8f45`) and MAL star-rating (`f15f666e`) follow-ups. Re-run complete
sequential Lua/LuaJIT gates and translations on the versioned tree, then build
from a clean commit. Audit runtime and outgoing history for held artwork;
compare bootstrap/API, upstream pins and assets with public alpha.44. Exercise
alpha.44's real installer for upgrade/rollback and truncated-download recovery,
both CI jobs, downloaded draft hashes and anonymous public discovery/install.
Evidence belongs in `test-results/alpha45-20261018/`. Only VERSION and release
documentation change in this step. This remains a prerelease; the physical
Bigme height/rating/interaction checks below remain outstanding.

The versioned tree passes 610/611 Lua/LuaJIT root cases in 51 files, 395
Bookshelf suites, all 13 SimpleUI files and 91 Python checks. Translation
validation passes all 43 catalogues; module/syntax checks cover 317 paths and
850 Lua files. Existing skips are unchanged. The nine actual MAL-provider
fixture probes also pass on both runtimes, without plugin initialization or
network access. Final package, CI and publication receipts live with the logs.

2026-10-18 MAL series-box rating (unpublished follow-up to Kanzenban): 13 new
provider/lifecycle cases exercise shared folder links, common-directory
resolution, cached refresh/relink/unlink, missing/invalid/failing providers,
late plugin registration, shared badge typography/palette, font scale/DPI,
tiny-cover omission and explicit text ownership. A new real native box-paint
case covers 2/8/120-member completed series, portrait/square/landscape covers,
1/1.5/2/3x DPI, day/night, and separation from read-total, `+N` and the title.
Existing custom-image, cover-aspect, binding and navigation cases remain on.

Complete sequential Lua/LuaJIT runs pass 610/611 root cases in 51 files,
395 Bookshelf suites, all 13 SimpleUI files and 91 Python checks. All 43
translation catalogues, 317 module paths and 850 LuaJIT syntax files pass.
Existing SQLite/native-font/external-artwork/absent-Bookends skips are unchanged.
Nine additional fixture-only probes execute the actual MAL 1.5.2 cached
provider methods from local revision `f6b4dff6`, on both runtimes, without
plugin initialization or network. They cover custom Manga roots, Android
aliases, explicit links, normalized series names, missing/zero scores and
personal-score isolation. No external plugin source was changed.
Logs and clean-package audits: `test-results/series-rating-20261018/`.

Device checks still required: compare the same linked series' folder badge
and physical box (`star + score`); test long and fully read series, first/custom
covers, Paperback/Kanzenban, day/night and smaller/larger cover and badge sizes.
Confirm no label collision, unchanged tap/hold, and refresh/unlink after repaint.
No Bigme/device acceptance or public release is implied by headless checks.

2026-10-18 Kanzenban replacement (unpublished follow-up to alpha.44): the 20
binding cases cover Swedish/English menus, read-only legacy Tankobon-to-Paperback
resolution, scoped choices, warm plan invalidation, 12% growth with unchanged
page-derived widths, and actual planner/painter box bounds. Exercise portrait,
square and landscape cover aspects, 1/1.5/2/3x DPI, 50/100/150% cover sizes,
2/6/12/120-member boxes, partial interiors, shadows, count/overflow separation,
colour/night rendering and unchanged source metadata. Existing navigation,
opening, completed-series and first-cover fallback cases remain enabled.
Logs and the shape-only comparison live in `test-results/kanzenban-20261018/`;
the comparison uses placeholder covers and approximate fonts, not device pixels.

Complete sequential Lua/LuaJIT runs pass 596/597 root cases in 50 files,
395 Bookshelf suites, all 13 SimpleUI files and 91 Python checks. All 43
translation catalogues, 317 module paths and 848 LuaJIT syntax files pass.
Existing SQLite/native-font/external-artwork/absent-Bookends skips are unchanged;
no new failure allowance. Clean-commit package and held-artwork/stable-asset
audits are recorded in the same evidence directory, not as a public release.

Device checks still required: compare Paperback and Kanzenban on the same
Manga series, including small/large covers and tall covers at the height cap.
Verify chip defaults, series overrides, opened/pinned series and restart.
An old Tankobon choice must show Pocket/Paperback without selecting Kanzenban.
Check row clearances, colour/night mode, opening, and complete/partial boxes;
read totals and navigation must still include all volumes. No public release
or physical Bigme test is implied by these headless checks.

2026-10-17 alpha.44 publication preparation: explicitly requested after
partial-fill implementation `e1ce48bb`. Re-run complete sequential Lua/LuaJIT
gates and translations on the versioned tree, then seal a clean-commit package.
Audit runtime/outgoing history for held artwork and compare stable bootstrap,
upstream pins and assets with public alpha.43. Exercise the published alpha.43
installer's upgrade/rollback and corrupt-download rejection; verify both CI
jobs, downloaded draft hashes and anonymous public discovery/download/install.
Evidence belongs in `test-results/alpha44-20261017/`. This step changes only
VERSION and release documentation. The partial-fill device checks below remain
open; this is a prerelease. Binding-label smoke checks confirm sv/sv_SE use
Swedish and en/en_US/de/fr/unset use the English fallback.

2026-10-17 partial box fill (unpublished follow-up to alpha.43): thirteen new
geometry/cache cases cover host-only hooks, consistent widths across series
lengths and title-fit widths, whole-prefix packing, eight-member work bound,
page-count provenance/fallback, invalid counts, status independence,
DPI/row/shelf thickness, too-narrow boxes and low empty-space shadows.
Two additional real-painter cases cover all three bindings, colour/night
interior shades, untouched air above the gap, and separate `+N` / read-total
labels. Existing aspect, hydration, completion, opening and navigation cases
remain enabled. Logs and shape-only preview live in
`test-results/series-box-fill-20261017/`; the preview uses placeholder covers
and approximate fonts, not device rendering.

Complete sequential Lua/LuaJIT runs pass 590/591 root cases in 50 files,
395 Bookshelf suites (zero failures, two existing SQLite skips), all 13
SimpleUI files and 91 Python checks (four existing source-artwork skips).
All 43 translation catalogues, 317 module paths and 848 LuaJIT syntax files
pass. Existing native-font/absent Bookends-checkout skips remain unchanged.
Clean-commit package validation and an inventory/hash comparison with public
alpha.43 are recorded separately in the same evidence directory. This is an
unpublished preview, not replacement alpha.43 release assets.

Device checks still required: compare two short and long Manga series with
similarly sized volumes; verify the short box has a contiguous empty right
interior and matching shadows. Check known thicker/thinner volumes, unknown
page counts, small/large cover sizes, all binding overrides and night mode.
Confirm `+N` means undrawn volumes while read/total and opening still include
all members, including after marking the final volume finished and restarting.

2026-10-17 alpha.43 publication preparation: explicitly requested after
`b3849c5d` and `5104eff4`. Re-run complete sequential Lua/LuaJIT gates and
translations on the versioned tree, then seal a clean-commit package. Verify
runtime and outgoing history exclude the held artwork, the public alpha.42
installer upgrades/rolls back and rejects corrupt downloads, both CI jobs,
downloaded draft hashes and anonymous live discovery/download/installation.
Evidence belongs in `test-results/alpha43-20261017/`. Only VERSION and release
documentation change in this step; upstream pins, bootstrap/API and artwork
stay unchanged. The device checks below remain open; this is a prerelease.

The versioned tree passes both complete suites sequentially: 575 Lua / 576
LuaJIT root cases in 49 files, 395 Bookshelf suites, all 13 SimpleUI files and
91 Python checks. All 43 translations, 317 module paths and 847 syntax files
pass. Existing SQLite/native-font/external-artwork/Bookends-checkout skips are
unchanged. Final package, public-byte and OTA evidence is retained separately
in the release evidence directory, not claimed as physical-device acceptance.

2026-10-17 larger slipcase art and scoped bindings (unpublished): focused tests
cover independent native/child/profile shelf choices, series precedence and
reset, reload, invalid settings, pinned/drilled light-member fallbacks, live
menu saves, real plan-cache refresh, real spine/top-block drawing at multiple
DPI and in night mode, contrasting Latin/Japanese jacket text, bitmap cache
keys, and propagation into real box member slots. A loader test verifies that
ornament and binding adapters both run. Aspect tests compare the old/new art
area for small/large series and portrait/square/landscape images; count and name
remain outside the image. Existing completion, hydration and picker cases stay.
Logs and generated shape-only preview: `test-results/book-bindings-20261017/`.

Device checks still required: long-press Fiction and Manga chips > Book binding;
change each independently. Override one box, open it, switch shelves and
restart; choose Follow shelf and confirm inheritance returns. Check thin
pocket boards and the light manga jacket in colour and night mode, opening
animation, and 2/8/120-volume boxes at small/large cover sizes. Confirm covers
are larger without stretching, read totals remain legible after completion,
and ornaments, taps, paging and series order are unchanged. The generated
preview exercises shape paint calls, not real cover art, fonts or Bigme output.
Complete sequential Lua/LuaJIT runs pass 575/576 root cases in 49 files,
395 Bookshelf suites (zero failures, two existing SQLite skips), all 13 SimpleUI
files and 91 Python checks (four existing source-artwork skips). All 43
translation catalogues, 317 module paths and 847 LuaJIT syntax files pass.
Existing native-font/absent Bookends-checkout skips are unchanged; no new
failure allowance. Clean-commit package validation is recorded separately in
the same evidence directory's `package.log`.

2026-10-17 alpha.42 device-report follow-up (not yet published): the series-box
test now executes SpineWidget's real init/cover-selection gate with light
members. It reproduces the placeholder regression before the fix and covers
embedded, external and absent covers, fallback resizing, and borrowed-buffer
exclusion without mutating group members. Seven image-picker cases cover
missing/deleted image-library paths, bounded path fallback, image filtering,
500 folders without descendant-count/metadata queries, all three apply
callbacks, and isolation from SimpleUI's virtual series grouping.
The new picker keeps native PathChooser navigation/confirmation but uses
filename sorting and plain entries rather than book metadata and folder counts.
Device validation is still required: open/cancel/select a series image in the
large Manga library, then verify automatic first-book covers after paging and
restart. No device log was provided; these tests do not establish that the
observed forced-exit hang was caused solely by the removed synchronous work.
Full sequential Lua/LuaJIT runs pass 561/562 root cases in 48 files,
395 Bookshelf suites (zero failures, two existing SQLite skips), all 13
SimpleUI test files, and 91 Python checks (four existing external-image skips).
All 43 translation catalogues, 317 module paths and 845 LuaJIT syntax files
pass; existing native-font and absent Bookends-checkout skips are unchanged.
An additional smoke test loads KOReader's actual FileChooser/PathChooser code
against a simulated 500-folder directory: the original picker scans 501
directories and queries book metadata; the corrected picker scans one and
does no book-metadata work. Native long-press confirmation and close pass.

2026-10-17 alpha.42 publication preparation: explicitly requested after the
reviewed Bookshelf 5.5.2 / SimpleUI merge. Re-run full sequential Lua/LuaJIT
gates and translations on the versioned tree, then seal a clean-commit package.
Verify outgoing history and runtime exclude the held artwork, both CI jobs,
the published alpha.41 installer's upgrade/rollback and corrupt-download
rejection, downloaded draft hashes and anonymous live discovery/download.
No additional runtime, upstream, bootstrap/API or artwork changes are included.
Physical-device gaps and rollback caveats remain; this is a prerelease.

2026-10-17 reviewed Bookshelf 5.5.2 / SimpleUI `7eb80f9e` merge: nine new
integration cases cover surface defaults, copy-only legacy migrations,
quick-settings opacity, UTF-8 metadata bounds, main-menu ownership and deferred
Home/custom-screen restoration versus Library/Manga navigation. Three added
box cases cover custom-art aspect, stale tags, lookup/probe/decode failure
fallback, retry and scaled-buffer cleanup. The full box file now has 26 cases.
Native SimpleUI fixtures supply `util.trim` for the new shared text helper;
no tests or failure allowances are removed. Clean adaptation `157ecc21` passes
complete sequential Lua / LuaJIT gates: 553 / 554 OrbitUI cases in 47 files,
395 Bookshelf suites (zero failures, two existing SQLite skips), all 13 SimpleUI
files and 91 Python checks (four existing source-image skips). Existing native
font skips and absent Bookends parity checkout remain. All seven slow suites,
43 translation catalogues, 316 module paths and 843 LuaJIT syntax checks pass.
Sealed clean-commit packaging verifies all 1728 manifest files / 1781 entries,
every size/hash, exact pins/ancestry, unchanged bootstrap/API and held-artwork
exclusion. Package hash and details are in the matching MERGE_LOG.md entry.

Device checks still required: custom portrait/landscape series images and
missing-image fallback at cover-size extremes; last-volume completion/reversal;
Random Book's default preview versus direct opening with path-based profiles;
old wallpaper/navbar/quick-setting appearance before/after migration; live dock
margin changes in Home/Library/Manga; main menu over Home, temporary plugin
fullscreen return, and navigation away before a scheduled restore. Check colour
and night mode. The software overlay fallback primarily targets devices without
the C blitter; host tests do not establish Bigme rendering or performance.
This merge is local, unpublished and leaves VERSION at alpha.41.

2026-10-17 alpha.41 publication preparation, explicitly requested after the
aspect-preserving slipcase refinement. Complete sequential Lua / LuaJIT runs
on the versioned tree pass 541 / 542 OrbitUI cases across 46 files, 394 Bookshelf
suites (zero failures, two existing SQLite suite skips), all 13 SimpleUI files
and 91 Python checks (four existing external artwork-source skips). Existing
native-font skips and absent adjacent Bookends parity checkout remain. All seven
slow suites run; all 43 translation catalogues, 315 module paths and 840 LuaJIT
syntax checks pass. Clean-commit packaging is the next gate.
Validate the published alpha.40 installer's upgrade/rollback and corrupt-download
recovery, outgoing Git/runtime artwork exclusion, both CI jobs, downloaded draft
hashes and anonymous live discovery/download before completing publication.
No new skip/failure allowance, upstream import, stable-bootstrap/API or artwork
change. Existing physical-device gaps and rollback caveats remain; the request
authorizes a prerelease, not a claim of Bigme visual acceptance.

2026-10-17 aspect-preserving slipcase follow-up: eight added host cases cover
the opt-in boundary, 70%-to-native-max width range, full-image proportions and
centered fitting across portrait/square/landscape art, small and large series,
count/name placement, invalid aspect fallback, large read totals at small
sizes, high-DPI tile-border removal and scratch cleanup/retry. Existing box
completion/reversal, day/night drawing and scoped navigation cases still run.
The focused host file passes 23 cases in Lua and LuaJIT; the standalone native
box suite retains its original defaults. Complete sequential Lua / LuaJIT runs
pass 541 / 542 OrbitUI cases across 46 files, 394 Bookshelf suites (zero failures,
two existing SQLite skips), all 13 SimpleUI files and 91 Python checks (four
existing external artwork-source audit skips). Existing native-font skips and
absent adjacent Bookends parity checkout remain. All seven slow suites run;
all 43 translation catalogues, 315 module paths and 840 LuaJIT syntax checks
pass. No new skip or failure allowance. Clean candidate `d1b1f74f` passes sealed
ZIP validation (1726 manifest files / 1779 entries), every inventory size/hash,
unchanged bootstrap/API and upstream pins, and exclusion of the held bitmap
and old core renderer. This is an unpublished development change, not
replacement alpha.40 release bytes; package details are in `MERGE_LOG.md`.
Physical Bigme rendering is not established by these bounded-surface tests.

2026-10-16 alpha.40 publication preparation, explicitly requested after the
upstream slipcase trial: both full suites rerun sequentially on the versioned
tree and pass 533 / 534 OrbitUI cases in Lua / LuaJIT across 46 files,
394 Bookshelf suites (zero failures, two existing SQLite suite skips), all 13
SimpleUI files and 91 Python checks (four existing external artwork-source
skips). Existing native-font skips and absent adjacent Bookends parity checkout
remain. All 43 translation catalogues, 315 module paths and 840 LuaJIT syntax
checks pass. No new skip or failure allowance; all seven slow suites run.

Gate publication on sealed clean-commit packaging, the actual published
alpha.39 installer's upgrade/rollback and corrupt-download
checks, both CI jobs, downloaded draft-asset hashes and anonymous live discovery
and download. Audit outgoing Git objects and runtime bytes for the held Mann
bitmap. No additional upstream import, bootstrap/API or artwork change is
included. The trial and broader physical checklists below remain outstanding;
this is a prerelease, not a claim of Bigme acceptance or improved performance.

2026-10-16 upstream slipcase trial, explicitly requested after the 5.5 merge:
old design and all 30 associated host tests retained on local branch
`design/orbitui-series-boxes` at `1ae66bd0`. Main uses the native renderer with
15 replacement integration tests; the decrease in host cases is deliberate,
not a new skip or relaxed failure allowance. Component source remains unchanged.

Complete sequential Lua / LuaJIT runs pass 533 / 534 OrbitUI cases across
46 files, 394 Bookshelf suites (zero failures, two existing SQLite suite skips),
all 13 SimpleUI files and 91 Python checks (four existing artwork-source audit
skips). Existing native-font case skips and absent Bookends parity checkout
remain. All 43 catalogues, 315 module paths and 840 LuaJIT syntax checks pass.
Clean candidate `2368cd46` passes sealed ZIP checks (1725 manifest files / 1778
entries), plus every file size/hash and absence of the old core box modules
and held artwork. Details are in `MERGE_LOG.md`; alpha.39 is not republished.

Physical trial checklist: two-volume/large-series slipcases, read-total after
marking/reverting the final volume, restart inside an old scoped series,
letter/page/back navigation, cover-size extremes, colour/night rendering and
ornament/plank/dock clearance. The new count and exposed member-spine marks
replace the old separate badge and whole-box completion mark/fade on purpose.
Ordinary books still face out. No device acceptance or speedup is claimed.
Keep install/settings backups and the broader upstream device checks below.

2026-10-16 reviewed Bookshelf 5.5 merge (local, unpublished; VERSION stays
alpha.39): complete sequential Lua / LuaJIT gates pass 548 / 549 OrbitUI cases
across 46 files, 394 Bookshelf suites (zero failures, two existing SQLite suite
skips), all 13 SimpleUI files and 91 Python checks (four existing artwork-source
audit skips). Native-font case skips and absent adjacent Bookends parity
checkout remain. All 43 catalogues, 315 module paths and 842 LuaJIT syntax
checks pass. The runner enables all seven slow filesystem/theme suites; no new
skip or failure allowance is introduced.

Bookshelf is pinned to `048ab4ba` (v5.5.0 plus README follow-up); SimpleUI stays
at `36e7430f`. Native PR #508 is now merged upstream, but OrbitUI retains its
own series-box renderer, badges, completion/fade and settings without a second
native preparation pass. Clean candidate `d65badec` passes sealed ZIP validation
(1727 manifest files / 1780 entries), including every file hash, upstream pins,
bootstrap/API and held-bitmap exclusion. Package hash and recovery details are
in `MERGE_LOG.md`. This development ZIP must not replace public alpha.39.

Physical Bigme checks remain: explicit author-photo lookup/bulk Stop and both
image-library roots; page/percentage badges in colour/night mode; OPDS redirect
access; scan cancellation/quarantine; nested-chip refresh, captions, dock and
existing series-box completion/ornaments. Author photos are separate from bust
ornaments. No device acceptance or measured speedup is claimed. Preserve the
earlier SimpleUI device checklist below and installation/settings backups.

Earlier 2026-10-16 reviewed SimpleUI merge (local, unpublished; VERSION stays
alpha.39): complete sequential Lua / LuaJIT runs pass 546 / 547 OrbitUI cases
across 46 files, 385 Bookshelf suites (zero failures, two existing SQLite suite
skips), all 13 SimpleUI files and 91 Python checks (four existing artwork-source
skips). Two native-font case skips and the absent adjacent Bookends parity
checkout remain. All 43 catalogues, 306 module paths and 824 Lua syntax checks
pass; no new skip/failure allowance. The 12 new cases cover central hook
ownership, LRU/reset/scratch-buffer failure recovery, source filtering/ranking,
tab selection/empty states/stable height and preserved default/order settings.

SimpleUI is pinned to `36e7430f`; Bookshelf is unchanged at `aeada050`. Both
tracked branches have zero missing commits at the 19:22 UTC collection.
PR #508 remains deferred. Clean-candidate package details are in `MERGE_LOG.md`.
Candidate `0066a6c4` passes sealed ZIP validation (1718 manifest files / 1771
archive entries), including every file hash and held-bitmap exclusion.
Existing physical shelves, series boxes, artwork, bootstrap/API and adapters
are unchanged. Tabbed Grid and Reader Book quick settings are opt-in.

Device checks still required: Tabbed Grid with book/group/empty sources and
paging in Home/Bento/custom screens; hidden Recent and BookOrbit sources;
Reader Book panel, dragging sliders and reading statistics; colour/night-mode
text, custom icons and patch enable/disable; repeated reader returns and
Home/Library/Manga navigation. No Bigme acceptance or speedup is claimed.
Keep installation/settings backups; old ordering keys remain readable for
rollback, but new grouped-order/module edits are not mirrored to old code.
No publication or replacement of the public alpha.39 archive is authorized.

2026-10-14 alpha.39 release preparation: both full suites rerun sequentially
after the version/documentation change and pass 534 / 535 OrbitUI cases in
Lua / LuaJIT across 45 files, 385 Bookshelf suites (zero failures, two existing
SQLite skips), all 13 SimpleUI files and 91 Python checks (four existing
external-artwork source skips). Native-font skips and absent adjacent Bookends
parity checkout remain. All 43 catalogues, 289 module paths and 806 Lua syntax
checks pass. No new skip or failure allowance. The extra LuaJIT case verifies
guarded writes to real 8/24/32-bit framebuffers.

Release gates use sealed clean-commit packaging, both CI matrix jobs, the actual
published alpha.38 installer for native upgrade/rollback and corrupt-download
rejection, downloaded draft-asset hashes, and anonymous live discovery/download
after publication. Bundled artwork and bootstrap/API 1 remain unchanged; the
held Mann bitmap is excluded from outgoing history and the runtime archive.
Physical Bigme checks and rollback caveats below still apply. This explicit
publication request does not claim new device acceptance or a measured speedup.

2026-10-14 reviewed upstream merge (local, unpublished; VERSION remains
alpha.38): complete sequential Lua / LuaJIT runs pass 534 / 535 OrbitUI cases
across 45 files, 385 Bookshelf suites (zero failures, two existing SQLite suite
skips), all 13 SimpleUI files and 91 Python checks (four existing external-artwork
source skips). Two native-font case skips and absent adjacent Bookends parity
checkout remain. All 43 translation catalogues, 289 module paths and 806 Lua
syntax checks pass. No new failure/skip allowance. `test_upstream_20261014`
adds migration/ledger rollback, transient failure retries, wrapper ownership,
format-index isolation and perspective-geometry cases; LuaJIT additionally
checks real guarded 8/24/32-bit framebuffer writes. Existing native tests use
the new renderer/planner modules without removing behavioral assertions.

Targets are Bookshelf `aeada050` and SimpleUI `84a9c0e9`, with no missing
tracked-branch commits at 19:02 UTC. PR #508 remains excluded; OrbitUI's
series-box, completion, ornament and profile tests remain green. The new Flow
carousel is opt-in. Legacy settings survive copy-only migrations, but new ledger
edits are not backported to old code during rollback. Clean-candidate packaging
is recorded in `MERGE_LOG.md`; this is not a new alpha.38 release artifact.

Physical Bigme verification remains: Home statistics/manual entries and
BookOrbit completion through restart; finished visibility and patch filters;
per-view series grouping; optional Flow swipes/zoom/close in colour/night mode;
custom icons, Bento gaps, labels and dock reflow; Favourite first sorting;
plugin-format discovery and OPDS-PSE resume with those plugins installed.
Keep the prior installation/settings backup. No measured speedup or new device
acceptance is claimed, and no public release is authorized by this merge.

2026-10-12 alpha.38 release preparation: both full suites rerun sequentially
after the version/documentation change and pass with 522 OrbitUI cases across
44 files, 382 Bookshelf suites (zero failures, two existing native SQLite
skips), all 13 SimpleUI files and 91 Python checks (four existing artwork-source
audit skips). Native-font skips and the absent adjacent Bookends checkout
remain. All 42 catalogues, 278 module paths and 791 Lua syntax checks pass.
Sealed clean-commit packaging and upgrade/rollback gates use the actual public
alpha.37 installer, followed by anonymous live discovery/download after
publication. Preserve the physical Bigme checks below; no new device
acceptance is claimed. Artwork and the stable bootstrap remain unchanged.

2026-10-12 Bookshelf 5.4.4 follow-up (local, unpublished; VERSION stays
alpha.37): complete sequential Lua/LuaJIT runs pass 522 OrbitUI cases across
44 files, 382 Bookshelf suites (zero failures, two existing native SQLite
skips), all 13 SimpleUI files and 91 Python checks (four existing external
artwork-source audit skips). Two native-font case skips and absent adjacent
Bookends parity checkout remain. All 42 catalogues, 278 module-map entries
and 791 Lua syntax checks pass, with no new skip or known-failure allowance.

Seven new cases cover per-level list density in both profiles, reloads,
pinch writes/clears, inherited rows versus independent expanded zoom, native
namesake isolation, legacy/search/non-list behavior and favourite-glyph corner
geometry. The new native density and finished/favourite tests run too. Existing
all-face-out, labels, series-box completion, ornaments and dock tests stay green.
SimpleUI changes only its Czech and Chinese catalogues; retain the corrected
single Chinese plural form. Both tracked branches are caught up at 08:43 UTC.
Clean-commit candidate `67436938` passes sealed ZIP validation: 1687 manifest
files and 1740 archive entries, including modules, assets, licenses and recovery
docs. This is a local development package, not a public update.

Physical Bigme checks remain: Auto/List at both levels with different rows and
columns, Library/Manga independence after pinch/back/restart, and favourite
heart/star alongside finished marks and above/below labels in day/night mode.
No device acceptance or performance gain is claimed. Keep the existing install
and settings backup. This merge does not publish or replace alpha.37 assets.

2026-10-12 alpha.37 release preparation: both full suites rerun sequentially
after the version/documentation change and pass with the same counts and
existing skips documented below. All 42 translation catalogs pass. Release
packaging and upgrade/rollback gates use the actual public alpha.36 installer;
the prerelease notes retain the physical-reader acceptance gaps. Artwork and
the stable bootstrap files are unchanged from alpha.36.

2026-10-12 Bookshelf 5.4.3 / SimpleUI October 12 upstream merge (local,
unpublished; VERSION stays alpha.36): full Lua/LuaJIT runs pass 515 OrbitUI
cases across 43 files, 380 Bookshelf suites (zero failures, two existing native
SQLite skips), all 13 SimpleUI files and 91 Python tests (four existing external
artwork source-audit skips). Existing native-font skips remain. Final profile
OPDS isolation is also covered by rerunning all integration tests and native
view/row-budget suites on both interpreters. All 42 catalogs, 278 module paths
and 788 Lua syntax checks pass; no additional skip allowance.

New cases exercise profile-specific Auto level persistence, the legacy unset
policy, scoped caption hero reserves, byte/count-bounded raster reuse and freeing,
same-size clock updates, isolated topbar rebuilds, clock backgrounds and live
metadata/status invalidation. Existing boxes, ornaments, dock, Bento, custom
icons, hidden Recent books and synchronization tests still pass.

Bigme checks remain: Auto Level 1/2 on Library, Manga and native/nested chips;
switch between labels above/below/none without a jumping hero or dock overlap;
revisit author/folder ornaments and manually shuffle; open the selected cover
over wallpaper; change read status and return Home; clock ticks and suspend/
resume on Home/custom screens; colour/night rasters; native metadata browsing
with Show Uncategorized Items off/on. No measured speedup or reader acceptance
is claimed. Keep the previous installation/settings backup. No publication or
replacement of published alpha.36 bytes is part of this merge.

The clean-commit package at `1e280cda` verifies 1686 manifest files and 1739
archive entries, including the new raster-cache module and all asset/license/
recovery entries. It is a development build, not a public OTA update.

2026-10-11 Bookshelf 5.4.1 upstream merge (local, unpublished, VERSION still
alpha.35): both full Lua and LuaJIT runs pass 508 OrbitUI cases across 42 files,
380 Bookshelf suites (zero failures, two existing native SQLite suite skips),
all 13 SimpleUI test files and 91 Python checks (four existing external artwork
source-audit skips). Native-font skips remain. No skip/known-failure allowance
was added. All 42 catalogs, 277 module-map paths and 786 syntax checks pass.

Added regression coverage exercises the actual child-theme resolver/menu with
both profile namespaces, native versus OrbitUI caption-menu ownership and the
new grid-strip helper respecting scoped text/placement even when native caption
fields disagree. Existing above-cover geometry, preview/cancel, gestures,
bookcase, series-box and ornament suites remain green. Upstream's new native
per-shelf caption tests run as well; standalone behavior is not disabled.

Adaptation commit `c4552ed9` passes clean-commit sealed packaging: 1684 manifest
files and 1737 archive entries, including module/asset/license/recovery checks.
Do not replace published alpha.35 with this local development package. No
device rendering, public push, version bump, tag or OTA publication is claimed.
Check nested-theme selection and clearing, the series-author switch, and all
per-chip caption modes/placements in grid, full-screen and physical shelves
on the Bigme. Existing appearance and both profile settings must remain intact.

2026-10-10 per-shelf cover text (local, unpublished, VERSION still alpha.33):
complete Lua/LuaJIT regression runs pass, with final adapter-suite reruns passing
499 OrbitUI cases across 42 files on both interpreters. Fourteen new cases cover
native/nested/profile chip isolation, persistence without losing themes/layout,
custom token editing and delayed preview cancellation, label budget/cache keys,
light-metadata fallbacks, per-chip menus and bounded physical-card painting/freeing.
Bookshelf passes 379 suites with the same two native SQLite skips; all 13 SimpleUI
test files pass. Python passes 91 checks with the four existing external artwork
audit skips. Artwork is unchanged. All 42 translation catalogs pass, 277 module
paths verify, and 784 Lua files pass LuaJIT syntax checks. No new skip allowances.

Physical labels reuse the existing card and opening/status layers, without cover
decodes or additional shelf height. Device font metrics, colour/night appearance,
touch interaction and completed-cover/box rendering still need Bigme acceptance
(see SHARED_UI.md). No device result, version bump, public push or OTA change is
claimed. A local preview ZIP must not replace the published alpha.33 artifact.

2026-10-10 Bookshelf 5.4 upstream merge (local, unpublished, VERSION still
alpha.32): both complete Lua and LuaJIT runs pass 485 OrbitUI cases across
41 files, 379 Bookshelf suites (zero failures, two existing native SQLite suite
skips), and all 13 SimpleUI test files. Existing native-font skips remain.
Python runs 91 tests successfully with the same four external source-photo /
museum-cache audit skips; artwork is unchanged. All 42 translation catalogs
pass, 277 module-map paths verify and 781 Lua files pass LuaJIT syntax checks.
No new skip or known-failure allowance was added by the compatibility work.
Bookends parity helpers have no adjacent checkout and check no files/regions.

New regressions cover profile-qualified theme/deck isolation, legacy deck
migration, deferred persistence, same-chip cross-profile navigation, stable
session ornament choices, pagination/dock hit boundaries and clipped 3D pose
writes. Existing series-box completion, cover-size, dock and sync tests pass.
Adaptation commit `77a347c1` passes clean-commit sealed ZIP validation: 1678
manifest files and 1731 archive entries, including module/asset/license/recovery
checks. ZIP SHA-256:
`4b132c174575a0be0567f67e602eff7cecf8b71673c68f521edbad0f4c33f57b`.
This local development package must not replace the published alpha.32 asset.

Physical Bigme checks remain: first launch preserving the current appearance,
separate Library/Manga themes and return navigation, ornament placement and
revisits/shuffle, completed boxes, live shelf editor, blur in colour/night mode
and opening poses at screen edges. Keep the previous install and a settings
backup: native theme storage migration cannot be undone by code-only rollback.
No device test, measured speedup, public push or OTA publication is claimed.

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
Adaptation commit `67f00890` passes clean-commit sealed ZIP validation: 1663
manifest files and 1716 archive entries, including module/asset/license/recovery
checks. The local development ZIP does not replace the published alpha.31 asset.
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

`tests/test_shelf_cover_labels.lua` also covers per-chip text placement, its
menu callbacks and persistence across profile reloads. It executes the native
grid-slot and physical face-out layout branches with widget doubles to verify
above-label ordering, fixed row budgets, selected-book lift and unchanged book
feet. The above-label helper is tested at multiple DPI/font scales, including
tiny rows, long labels, disposal, fading and forwarding tap/hold/double-tap to
the actual cover. These geometry checks are not a substitute for checking the
fonts, dark plates, night mode and opening animation on the reader.

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

- Enable **OrbitUI settings > Reading dashboard > Show dashboard as first Home
  page**. Confirm older Home pages still appear on swipe, retain their settings,
  and are unchanged after disabling the dashboard, including edits made while
  it was enabled. Repeat after restarting KOReader.
- On the dashboard check portrait/landscape, actual DPI/font choice, long titles,
  dark/light hero, night mode and large dock/pager margins. No card should paint
  under the pager/dock. Covers keep their proportions and colour.
- Rename cards via Reading dashboard > Headings from both settings entry points.
  Check the keyboard, immediate redraw, long Swedish/CJK titles, persistence
  after restart and language changes, Cancel, blank input and Restore default.
  Other Home modules and Custom Screens must retain their own names; reset must
  restore the current-book status title and configured reading-goal title.
- Open and hold the hero, each ongoing book and both cover rows. Change progress
  and completion status, return from the reader, switch pages and sleep/resume;
  check updated counts/bars and no stale/freed covers. Page Want to Read and New
  Books independently with both arrows; check the counters and first/last-page
  stops, and that the controls never cover a book. Verify BookOrbit auto-refresh
  opt-out, offline cached data, missing cover/goal states and Hardcover/local
  annual goal selection.

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
- For the Manga ornament pack, check Akira's motorcycle, Dungeon Meshi's mushroom
  and The Apothecary Diaries' mortar beside both series boxes and individual
  volumes. Browse forward/back, return from a book and restart: no miniature
  may migrate to an unrelated series or an empty shelf. Verify at most one per
  row, author-bust priority and several busts still sharing a row. Check the
  pack/individual off switches and None frequency, tap-to-zoom info, colour and
  monochrome, foot alignment, tight widths and custom size/height adjustments.
  Confirm an edited or deleted PNG stays edited/deleted after another startup.
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
