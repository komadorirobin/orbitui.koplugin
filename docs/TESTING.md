# Verification and device acceptance

## Automated

### Local Beta 17 quick-control device regressions (October 30; not published)

The user's screenshots/tests expose gaps in the original 22-case boundary suite:
Home's full-width parent menu zone preempts the child status target, and a real
SimpleUI NativeSheets replacement silently blocks the exact-dialog guard. The
expanded `test_quick_controls.lua` has 28 cases. It loads complete `sui_core`
and `sui_native_sheets`, exercises real owner-level priority dispatch and keeps
a positive ordinary-dialog conversion control. The new cases fail on Beta 17
before the fixes and pass with them. Optional native dispatch is enabled with
`ORBITUI_NATIVE_INPUT_DIR` pointing to inspected `inputcontainer.lua` and
`widgetcontainer.lua`, alongside `ORBITUI_NATIVE_BUTTON_DIALOG` as below.
Minimum `v2025.08` and current `801277394b7fdb77da5580459a9827e9d95e95a4`
input/dialog supplements pass under Lua and LuaJIT; fonts/hardware/rendering
remain boundary stubs, not physical acceptance.

Added checks: cold-disabled cells activate/deactivate in place without rebuilding
books/providers; current mounted cell/painted geometry only; configured corners,
holds/swipes and previous host hooks win as before; hidden/retired/covered and
touch-disabled cells do not open; already-installed priority closures see the
new host hook. Native, unanchored Wi-Fi/battery/clock/light panels retain identity,
tabs/refresh/Close/system Wi-Fi/night actions work, and retired callbacks remain
inert. Other native dialogs keep their normal SimpleUI sheet conversion.

Physical retest remains required: toggle while Home stays live, tap actual status
fields versus blank topbar/chevron; custom screens/corners/holds; open the panel
from settings and the added action (without an anchor), switch every tab, Refresh,
Close/outside/Back, Android Wi-Fi return, reader return, rotation and sleep.
The user's separate Bigme light failure also occurs in native KOReader with
OrbitUI disabled; no hardware support or ADB/device change is included here.
Local VERSION stays Beta 17. Never replace the published Beta 17 ZIP with this
same-version development build. Gate/package details are recorded in MERGE_LOG.

### Beta 17 publication (October 30)

Exact candidate/tag `ab2e0bd7` passes both full interpreters: 122 Python/four
unchanged optional skips, 86 root Lua files, 487 Bookshelf/zero failures/three
normal SQLite exclusions, 13 SimpleUI files, map 396, syntax 1,082, all 43
catalogs. Every root suite passes on the sealed ZIP under Lua and LuaJIT.
Actual Beta 5/9/15/16 installers pass native archive/hash/recovery gates;
anonymous public-byte application TLS/native OTA also passes from Beta 9/16.
Main/tag CI `41034381766`/`41034383748` are green. Exact candidate/source/
inventory/artwork/secret/draft/public-byte audits pass; previous releases/tags
remain unchanged. See MERGE_LOG and `test-results/beta17-20261030/` for evidence.
No physical device acceptance, new measured speed/RAM result or stable release.

### Quick controls (included in Beta 17)

`test_quick_controls.lua` exercises the complete shared chrome adapter over
native widget/hardware boundaries: default-off taps/isolated preference write,
capability gating, cold NetworkMgr refusal, honest Android no-toggle state and
system settings, native non-Android connection/chooser delegation, native light
ranges/warmth conversions/readback/retired slider callbacks, short-screen native
fallback, unknown battery/errors/zero charge, existing plugin statistics/calendar
and clock formatting. It covers one-popup replacement, copied anchors, double/
stale callbacks, navigation/modal/rotation/suspend/teardown guards, unchanged
expanded shelf/custom gesture/job Stop paths, hero ownership, topbar dimensions,
SV/EN/error text and complete native Topbar construction/label identities.
Set `ORBITUI_NATIVE_BUTTON_DIALOG` to an inspected official `buttondialog.lua`
to repeat against its whole native dialog implementation. Boundary sizing is
not native font shaping or an emulator/device result. Candidate `493775af`
passes both complete interpreter gates, all 86 root suites on final sealed bytes,
43 catalogs, exact package/source/path/artwork/secret audits and actual-Beta-15
native installer/restart/rollback/cleanup checks. All 22 new cases pass with
both interpreters against the complete `v2025.08` and official current
`801277394b7fdb77da5580459a9827e9d95e95a4` ButtonDialog. Evidence and exact
development ZIP digest are recorded in MERGE_LOG; no new release is published.

Physical checks remain: enable the opt-in through SV/EN navigation settings;
Home fields at all saved placements/scales, hidden/disabled fields and corner/
hold gestures; Bookshelf hero/micro status, active job Stop/page dots, expanded
return; small/landscape/large-text layout, touch/sliders/D-pad/Back/outside close;
Boox/Bigme Android Wi-Fi settings return without fake connection indications;
actual light minimum/maximum/warmth/resume and no-API fallback; plugin-disabled
battery/calendar; unknown/full/charging state; day/night underlay, reader fast
return/profile state, rotation and sleep during drag/dialog/action. No poller,
automatic scan/connect, metadata extraction or network-provider call is expected.

### October 30 reviewed merge (not a release)

`test_upstream_20261030` covers thirteen embedded source identities/Lua syntax,
copy-only scoped Critter defaults, native Android/absent Kindle Bluetooth,
protected/restorable menu pruning and read-only snapshots/last-owner teardown,
pure games, bounded hidden-Recent book facts, opt-in grid capacity, stale boot
warm callbacks/one-folder ticks, plural headers, scrolling long messages and
page-turn aggregate/error semantics. Extended runtime tests exercise sealed
compilation, legacy/canonical identity, preload priority and both read-only
compatibility entry modules. The actual shared reader-menu suite covers a
hidden cabinet descriptor, exact profile return and owned unbinding too.
All prior category-card/Home/reader/Android cover/series/ornament tests remain.

Physical checks still required: hide/show/restore menu items with safe settings
access; cabinet/Book quick-panel exit to exact chip/page with both hidden/visible
tabs; touch/D-pad/rotation/suspend; grid scales and six-cover rows; old per-screen
Critter choices, panel on/off, games, conversation and close/reopen; native colour/
night frames; startup warm cancellation and Android covers. No headless test is
a measured Bigme/Boox speed, RAM, e-ink or document-engine acceptance result.

### Local category-card settings start (October 29)

`test_settings_start.lua` loads the complete actual LibraryModal and OrbitUI
settings adapter over a native widget/font/display boundary stub. Eleven cases
cover the five static bilingual categories and existing icon assets, unchanged
stores/lazy shelf access, native category and Back routes, stale/double taps,
search/cancel/query Back, list/card switching, touch-only and D-pad/footer exits,
rotation and deferred-library cancellation, missing UI/tiny-screen fallback.
The geometry matrix has six portrait/landscape/narrow sizes (including native
1264x1680 and 1680x1264), SV/EN and three font-scale factors: 36 fixtures per
interpreter. Actual native grid/pagination/focus code runs, but text wrapping uses
a conservative boundary proxy, NOT native fonts/shaping or a rendered screen.
Opening cards never loads providers, initializes a shelf or writes preferences.

Physical acceptance still required: both languages and UI fonts, large DPI,
portrait/landscape paging and touch targets, category/list/search Back and Cancel,
hardware keys, close/reopen, display contrast/night mode and return to the exact
underlying Home/shelf/reader after rotation/suspend. No new release is implied;
the local same-version Beta 16 ZIP must never replace its public asset.

Candidate `8133c7aba6260d5e018564f955e72f7b6e8a0ff5`: complete sequential local
Lua/LuaJIT gates pass 122 Python tests/four unchanged optional source-pixel skips,
84 root Lua files, 487 Bookshelf suites/zero failures/three normal SQLite
exclusions and all 13 SimpleUI files. Map 383, syntax 1,067, catalogs 43/zero
failures. ALL 84 root files additionally pass on the final sealed bytes under
both interpreters, including the final eleven card-start cases. Exact candidate
Git archive/approved PO projection/manifest/hash/checksum audit passes with the
same 1,999 inventory files plus manifest/all 2,000 installed paths. Native actual
public Beta 15's installer accepts this LOCAL fixture package, including archive/
SHA, restart/rollback, external snapshot and interrupted cleanup/resume checks.
It is not live public discovery of a new release. No reader or public asset is
changed. Evidence: `test-results/settings-start-20261029/`. Follow-up verification
docs do not rebuild the candidate ZIP. Native font/display acceptance stays open.

### Beta 16 publication (October 28)

Exact release candidate/tag `5c846730d5fbcaafc805fce9db97f6b57257139d` passes both
complete Lua/LuaJIT runs: 122 Python tests/four unchanged optional source-pixel
skips, 83 root Lua files, 487 Bookshelf suites/zero failures/three normal SQLite
exclusions and 13 SimpleUI files. All 83 root suites also pass on actual sealed
bytes under both interpreters. Map 383, syntax 1,066; all 43 catalogs validate.
Main/tag CI `40750773286`/`40750773783` passes, including native archive/SHA OTA.
Exact source projection, manifest/checksum/path inventory and outgoing history/
artwork/secret audits pass. No bootstrap, source-pin, asset or installed-path change.

Draft downloads and anonymous public assets match the exact candidate ZIP:
SHA-256 `a9a1b6f6a36376b11091f195f2a0230208898909b483914c4cddd0e80d4aff98`,
8,781,021 bytes, 25,632,378 expanded and 1,999 inventory files plus manifest.
Native actual-public-Beta-5/9/14/15 installers accept the new full package;
activation/restart/rollback, missing-module/truncated recovery, external snapshot
and interrupted obsolete-code cleanup/resume preserve retained and unknown data.
Live anonymous application-TLS public-byte upgrade from Beta 9/15 passes with
native archive/SHA and the same recovery scenarios. Preview selects Beta 16;
stable stays unchanged with no stable release. All 70 previous public releases/
assets and all older remote tag refs remain unchanged.

Evidence: `test-results/beta16-20261028/`. The local POSIX shim and locally built
TLS/JSON test dependencies stay outside the reader package and global install
paths. No actual reader installation or display is touched. Follow-up verification
docs do not rebuild the release ZIP. The device protocol below remains open;
optional profiles remain opt-in and no measured device speed/RAM gain is claimed.

### Local UI/performance follow-up (October 28, not a release)

`test_dashboard_demand.lua` runs the real registry against all 512 card visibility
combinations, Home/custom-screen scopes, native Recent sources, local/Hardcover
goal ownership and unsupported/disabled configurations. It must not load stats,
book/remote providers or rewrite existing settings merely to calculate demand.
`scripts/benchmark-dashboard-demand.lua` prints the same seven declared-demand
cases before/after the change. It does NOT count actual provider calls or measure
UI startup, native buffers or device latency; another enabled Home module can
legitimately still request the same data. Evidence: before/after CSVs in
`test-results/performance-20261028/`.

`test_performance.lua` covers both real native-free cover-cache implementations,
borrowed buffer retention, oversize guards, reversible base budgets and later
user changes; invalid/unknown memory readings; shown versus parked readers;
one-shot/cancelled/superseded/suspended/last-owner work; opt-in bounded timing,
nil/error identity, CPU-versus-elapsed series, privacy allowlist, idempotent hooks
and later external wrappers; animation/screen seams and bilingual read-only menus.
It does not emulate C image allocations or the Android document renderer.

### Physical performance acceptance (still required)

In Swedish: **OrbitUI-inställningar → System och underhåll → Snabbhet, minne och
diagnostik**. In English: **OrbitUI settings → System & maintenance → Speed,
memory & diagnostics**. Existing behaviour remains the default. Enable **Mät
prestanda / Measure performance** explicitly, then view/copy the local report.
Capture is opt-in, in memory, capped at 60 recent samples per operation. Reset
clears timings only; no persistent report or upload is automatic. Reports contain
fixed operation labels, numeric cache/memory/queue counters and error counts,
never file/title/profile/account strings, raw errors or screenshots. No forced GC.

Use the SAME books, library profile, chip/page, cover mode, orientation and
KOReader version for each variant. Keep Android safe mode enabled. Separate cold
startup/first visits from warm loops (two warmups, at least ten measured repeats).
Compare existing, Adaptive and Responsive separately: Home, shelf/chip navigation,
opening from Home and shelf, cabinet fast return and normal fallback. Verify the
exact profile/chip/cursor and unchanged cover quality after every return. Include
rotation, settings over reader/shelf, suspend/resume, repeated opens and low-memory
conditions on both Boox and Bigme. The Home/Bookshelf quick guide must remain
read-only until a native setting is explicitly selected; inspect SV/EN wrapping,
Back/close and clipboard-unavailable fallback on the device.

Current timings are SYNCHRONOUS METHOD intervals, not the benchmark project's
settled end-to-end transitions: deferred stats/prewarm/reader work and physical
panel refresh are not included. A close-event sample is not full book-close
latency. Lua heap excludes C image buffers; cache bytes omit image references
still legitimately held by live/parked widgets and allow one oversized newest
entry. OS available RAM may include reclaimable caches and is not process RSS.
Missing/invalid readings keep native budgets. Do not compare these reports with
the published macOS SDL numbers or claim speed/RAM gains without device evidence.
No complete runnable KOReader emulator was available during this local task.

Candidate `5def9a06a65c081dd05d8cb9c00e4447ef4f089a` passes complete sequential
Lua/LuaJIT suites: 122 Python/four unchanged optional source-pixel skips, 83 root
Lua files, 487 Bookshelf suites/zero failures/three normal SQLite exclusions and
all 13 SimpleUI files. Map 383; syntax 1,066; catalogs 43/zero failures. Both
interpreters additionally rerun ALL 83 root files against the sealed package,
including the 14 performance cases, four demand cases/all visibility combinations,
existing Home/cover/navigation/menu/OTA/storage/translation cases. Exact Git
archive→approved PO projection→manifest/hash/checksum audit passes with the same
1,999 inventory files plus manifest. Native actual-public-Beta-14 upgrade,
extraction/SHA/restart/rollback/truncated/external-snapshot and interrupted code-
cleanup/resume/retained-data checks pass on macOS using the existing test-only
POSIX shim. No reader installation or physical display is touched. Evidence:
`test-results/performance-20261028/`. This is an unpublished same-version test
ZIP, not a replacement Beta 15 asset. Follow-up docs do not rebuild its bytes.

Local October 28 storage cleanup: `test_update_storage.lua` exercises the real
collector/validator/bootstrap reads and Lua syntax checks on a confined in-memory
filesystem, without touching a reader. Fifteen cases cover current/rollback/
factory and user-data preservation, full retained-package verification, strict
older-version filtering, one-snapshot budget, pending/stale/recovered/unconfirmed
startup, links/unknown/modified/missing files, manifest/bootstrap failures,
interrupted quarantine/resume, empty final quarantine, changed selection and
rename failures and a full 1,999-file API-1 inventory. Preparation must preserve
arbitrary hash-named user directories.
Four added updater cases check health/deferred-worker ordering, idempotence,
failed startup, cleanup failure/cancellation, following external/daily checks and
a stale rollback confirmation while busy. `smoke-ota.py`/`.lua` add actual-file,
native SHA/libarchive cleanup plus interrupted-delete restart/resume and retained
rollback/data checks after the ordinary older-installer scenarios. Full results
are recorded in `MERGE_LOG.md`; this is not device or publication acceptance.

Candidate `ff972412`: complete sequential Lua/LuaJIT runs pass 122 Python/four
unchanged source-cache skips, 81 root Lua files, 487 Bookshelf suites/zero
failures/three normal SQLite exclusions and 13 SimpleUI files. Map 383; syntax
1,063; translations 43/zero failures. Final targeted/sealed reruns include all
15 collector and 12 total updater cases, plus bootstrap/OTA/external/menu/HTTP
regressions. Actual public Beta 14's older installer accepts the full local ZIP;
native extraction/hash/activation/rollback/external-snapshot and real-file
collector interruption/reload/resume/unknown-and-modified-data preservation pass.
For this supplemental macOS run the optional `ORBITUI_TEST_NATIVE_FS` adapter
uses locally compiled POSIX lstat/mkdir/rmdir/opendir/readdir, avoiding thousands
of shell processes; the normal smoke harness remains compiler-free. The obsolete
native fixture is a small synthetic complete manifest, not a whole reader install.
The full 1,999-file deletion is exercised in memory. Evidence:
`test-results/update-storage-20261028/`. No new failure waiver/device claim.

Local October 28 package-size work: `test_release_package.py` checks narrow PO
source-reference omission (including CRLF/UTF-8/indented comments, literal `#:`
inside strings, legal/translator comments, headers/plurals/flags/obsolete text,
idempotence and non-catalog exclusions). All 43 tracked catalogs must compile
to byte-identical `msgfmt --check --no-hash` output before/after the transform;
the source files remain unchanged. Sealing tests verify the same path set and
recomputed ZIP sizes, manifest sizes/hashes and whole-archive checksum. The
transformed PO bytes, not their larger Git sources, are the source-audit target.
The local package at candidate `edc2c850` passes complete sequential Lua/LuaJIT
gates: 122 Python/four unchanged external-source skips, 80 root Lua files,
487 Bookshelf suites/zero failures/three normal SQLite exclusions and 13
SimpleUI files. Translations 43/zero failures; map 383; no new skip/waiver.
Actual older public Beta 14 installer passes native libarchive/SHA extraction,
activation/restart/rollback, truncated recovery and external snapshot/recovery
with the local ZIP on macOS; no device or live publication test is implied.
Both real component PO loaders compare all 43 catalogs on source versus sealed
bytes under Lua/LuaJIT: 54,517 singular/fallback and 327,102 plural comparisons
per interpreter agree. Source/manifest/checksum/path audits pass. Test ZIP is
8,756,519 bytes / 25,554,846 expanded, retaining all 2,000 installed paths.
This local build change does not republish Beta 15; exact size comparison and
older-installer verification are recorded in `MERGE_LOG.md`. Evidence lives in
`test-results/slim-translations-20261028/`.

2026-10-27 public Beta 14 at exact candidate/tag `575fdb7a`, 13:22:20 UTC:
complete sequential Lua/LuaJIT and main/tag CI `40510806422`/`40510806468` pass
119 Python/four unchanged source-cache skips, 78 root Lua files, 483 Bookshelf
suites/zero failures/three normal SQLite exclusions and 13 SimpleUI files.
Map 383; syntax 1,056; translations 43/zero failures. Ten new upstream cases and
retained editor/reader-menu/Home/cover/navigation regressions pass on sealed
bytes. Eight changed modules pass undeclared-global lint. Official utf8proc
wrapper/system ABI supplement passes without util.stringLower (not an exact
reader-library build). No new exclusions. Physical device acceptance stays open.

Exact source/manifest/draft/public audits pass, with no new/removed runtime paths,
unchanged bootstrap/assets/fonts/map and no destructive cache migration. ZIP
SHA-256 `01010c252a9abd5842cd0e7e3c539cb9e609fec07358a1196039911f80c30bc0`,
9,363,469 bytes/29,300,429 expanded; 1,999 inventory plus manifest/all 2,000 API 1
slots. All 69 outgoing blobs exclude held artwork; 14 non-merge commits pass
Gitleaks. Actual Beta 5/9/13 native local installers and Beta 9/13 public-byte
live-TLS upgrades pass discovery, extraction, activation/restart/code rollback,
truncated recovery and external snapshot/restart/rollback. Previous assets remain
immutable. Evidence: `test-results/beta14-20261027/`; follow-up docs do not rebuild.

2026-10-27 LOCAL library/chip editor refinement, not pushed/released:
`test_library_settings` now has 18 cases under Lua/LuaJIT, including the real
Bookshelf menu host with a stub native widget. It checks separate profile/chip
ordering, immediate list/position/boundary updates, stable-ID stale callbacks,
disabled libraries, non-folder source labels, isolated chip folder changes,
out-of-root consent/cancel/stale/invalid paths, explicit broad root replacement,
live parent controls and SV/EN wording. Search regressions include Order chips,
Ordna bibliotek, Placera före and Source without native providers or writes.
The underlying roots, metadata model, IDs and stored appearance remain intact.
No new runtime paths or component edits are introduced by this refinement.
Evidence: `test-results/library-chip-settings-20261027/`; final full gates and
sealed package results are recorded in `MERGE_LOG.md`.

Source `5810c567` passes complete sequential Lua/LuaJIT suites: 119 Python/four
unchanged external-source skips, 77 root Lua files, 483 Bookshelf suites/zero
failures/three normal SQLite exclusions, 13 SimpleUI files, map 383, syntax 1,055,
translations 43/zero failures. Targeted 18 library/19 settings/12 navigation and
retained 23 reader-menu cases plus host/Home/panel/Android-cover cases also pass
against sealed bytes under both interpreters. Exact source/manifest/history
audit passes: 25 outgoing blobs exclude held artwork, three local commits pass
Gitleaks, no new runtime path or upstream/component/VERSION/bootstrap/asset change.
Development ZIP SHA-256
`e41141216342ed6d9710a9636c1313630e0c06d2cc997a2fdffe454c6b4250ee`,
9,329,310 bytes/29,229,702 expanded, 1,999 files plus manifest/zero API 1 slots
free. Main/origin/tag/public ZIP remain unchanged; verification-only follow-up
docs do not rebuild the artifact. Not a replacement Beta 13 or a published OTA.

Physical acceptance still required: SV/EN long-path wrapping, small-screen and
multi-page order lists, selected position/boundaries, touch/Back/close, restart,
old and newly selected folder membership, root remapping, Home links, navigation
targets and reader return on Boox/Bigme. No physical-device claim is made.

2026-10-27 native reader-menu LOCAL candidate `1f2bb837`, no push/release:
complete final sequential Lua/LuaJIT suites pass 119 Python/four unchanged
source-cache skips, 77 root Lua files, 483 Bookshelf suites/zero failures/three
normal SQLite exclusions and 13 SimpleUI files. Map 383; syntax 1,055;
translations 43/zero failures. No new exception. All 23 new reader-menu cases
pass under both interpreters with whole actual KOReader ReaderMenu references
at `f0db5fcb3c3e35949a99c8bff3dc36837a3f0fd6` and minimum `v2025.08`. Native UI/
sorter/document services remain explicit stub boundaries, not a whole reader UI.
The first full-menu case fails on public `33b13a08` before this fix. Those cases
plus retained host/settings/library/Home/panel/cover regressions pass on the
sealed bytes. Exact source/manifest audit: no runtime paths added/removed,
1,999 inventory plus manifest/all 2,000 API 1 slots; bootstrap/assets/fonts/pins/
VERSION/module map unchanged. ZIP SHA-256
`f3aa81c4bf2a36a2e6dcf649318daa6f621edff4411ac0b1a63aadd15208ecee`,
9,322,410 bytes, expanded 29,207,174. All 12 outgoing blobs exclude held artwork;
source commit passes Gitleaks. Evidence: `test-results/native-reader-close-20261027/`.
Same-version development ZIP, NOT a replacement public Beta 13 or a new OTA.
Main/origin/tag/public assets are unchanged; follow-up docs do not rebuild it.

Physical acceptance still required: cabinet-button exits from arbitrary saved
profiles/chips/pages and Home/shared search; cold/not-ready and rotated returns;
repeated menu rebuild/reload/close/open; suspend/resume; the live SV/EN opt-out;
unchanged Home gestures/end-of-book/exit; actual saved reading position and one
intended BookOrbit/Hardcover writer. No measured speed/native-crash claim.

2026-10-27 Beta 13 is public at exact candidate/tag `f9d3b3a2`, 06:04:40 UTC,
after explicit push/publication approval. Complete sequential local Lua/LuaJIT
and main/tag CI `40458588212`/`40458587953` pass: 119 Python/four unchanged skips,
76 root Lua files, 483 Bookshelf/zero failures/three normal SQLite exclusions,
13 SimpleUI files, module map 383, syntax 1,054, translations 43/zero failures,
332 static search phrases. Both interpreters pass the 19 settings cases and
retained shared settings/library/Home/navigation/cover/updater sealed regressions.
Undeclared-global lint passes all six changed host modules. No new exclusions.

Clean source/manifest audit: 1,999 files plus manifest equals the exact 2,000
installed API 1 boundary; only the new release note adds a path, none removed.
Bootstrap/entry/assets/fonts/upstream pins/module map remain unchanged. ZIP
9,314,791 bytes, expanded 29,182,623, 2,065 entries; SHA-256
`65ce2609b4bf914c298abb2f812c98d0e3ae84fad0863bf7786e1d54ac4a6c63`.
All 30 outgoing blobs exclude held artwork; five commits pass Gitleaks. Actual
Beta 5/9/12 native Linux installers pass all local OTA/recovery/restart/rollback/
external-snapshot phases at that file boundary. Exact draft and anonymous public
assets match local bytes and API digests; Beta 12 metadata/assets are unchanged.
Published-byte native TLS discovery/download and every phase pass from Beta 9
and Beta 12 without credentials. Evidence: `test-results/beta13-20261027/`.
Follow-up docs do not rebuild/replace immutable release bytes. Temporary installs
are not physical-reader tests. SV/EN layout/touch/Back, SimpleUI custom screens,
themes, reader return/rotation/sleep/wake remain open. No speed/device claim.

Historical local settings final verification: source candidate `ffd3ef34` includes the
native Menu:init ordering fix after `d905e04c`. KOReader's actual Menu:init resets
constructor-supplied paths; parent breadcrumbs and the footer arrow are now set
after construction, before first paint. The native-boundary stub intentionally
matches that reset so the regression cannot pass by assuming the options survive.
Official reference saved in the evidence directory:
`https://raw.githubusercontent.com/koreader/koreader/master/frontend/ui/widget/menu.lua`.

Complete sequential suites pass 119 Python/four unchanged skips, 483 Bookshelf/
zero failures/three standard SQLite exclusions and 13 SimpleUI files. Both
interpreters rerun all 76 root Lua files against final source. The final parent-
arrow fix and all 19 settings cases are rechecked on sealed bytes under Lua/
LuaJIT, alongside retained shared-settings, library, Home, navigation, cover and
update cases. Native MenuHost and hero-region suites also rerun after the fix.
Module map 383, syntax 1,054, translations 43/zero failures, static vocabulary
332. Package/source/hash audit: no runtime paths added/removed; 1,998 files plus
manifest, one API 1 slot. ZIP 9,309,755 bytes, expanded 29,170,091; SHA-256
`2fc49a0db048e32b34faf2fd568987e12a96df7309148aacc86428d062c5c4f7`.
All 23 outgoing blobs exclude held artwork and both source commits pass Gitleaks.
Evidence includes `lua-final.log`, `luajit-final.log`, `*-root-sealed-source.log`,
`native-host-final.log`, `sealed.log`, `audit-local.json` and `gitleaks.log` under
`test-results/settings-navigation-20261026/`. Final docs are audited separately;
do not rebuild or publish this same-version development ZIP as Beta 12. No push,
tag, release, live OTA or physical-device installation occurs in this task.

2026-10-26 local settings redesign, not published: `test_settings_navigation`
exercises the five task areas, explicit SimpleUI ownership, complete SV/EN owned
labels/scopes and 332 native search phrases, literal/bounded bilingual search,
no eager providers/preferences, real native region/tag callbacks and preserved
templates/categories, effective label-line behavior, canonical/search Back versus
close-all, scope inheritance, stable native IDs/future-control retention and
deferred-open cancellation. It cold-loads the complete SimpleUI settings window
and applies hosted titles before window construction, keeping custom-screen
context unchanged. It also loads the real Bookshelf settings module and MenuHost
with only native UI boundaries stubbed. `test_settings_i18n` checks format
parameters, inherited-only duplicate keys and static vocabulary/UTF-8 byte escape
decoding. Existing settings/navigation/Home/cover suites remain required.

Both full interpreters, translations and clean-commit/sealed package gates are
run in `test-results/settings-navigation-20261026/`. This does not authorize a
push/release or replacing Beta 12 bytes. VERSION and installed API 1 limits stay
unchanged; no runtime paths are added/removed. Physical SV/EN pagination/title
width, scope comprehension, genre/labels, shelf/panel shortcuts, nested Back,
native SimpleUI windows, custom-screen state, reader return/rotation/suspend
remain untested. The user separately confirms Beta 12 covers now display
correctly on the affected Boox; that is not acceptance of this settings redesign.

2026-10-26 Beta 12 published at exact `ea8bbaf0`, 20:42:10 UTC. Both main/tag
CI runs `40397510037`/`40397510247` pass complete clean-source Lua/LuaJIT,
translation/package and native OTA gates. Local complete sequential suites also
pass 117 Python/four unchanged skips, 483 Bookshelf/zero failures/three normal
SQLite exclusions and 13 SimpleUI files. All 75 root Lua files are additionally
rerun on the final committed source under both interpreters. Module map 383;
syntax 1,053; translations 43/zero failures; changed-host undeclared-global lint
passes. The new suite passes 26 cases under each interpreter and 27 with the
real KOReader SQLite binding; sealed bytes repeat these and Home/navigation/
updater/Bento regressions under both interpreters.

Local native installers from public Beta 5/9/11 pass all five phases. Anonymous
real LuaSocket/LuaSec TLS discovery/download plus all phases pass from Beta 9
and Beta 11 against the published bytes. Draft/public downloads, API digests,
manifest and committed source match. ZIP SHA-256
`fe54c593c9b06fc0ba6055c82d6544a2807ee7e96efd9fd158b9c40d41dbafe2`,
9,286,577 bytes, 1,998 inventoried files plus manifest, 2,064 entries and
29,092,889 expanded bytes. One API 1 installed-file slot remains; no installed
path is removed and no bootstrap/API/assets/fonts/pin changes occur. Thirteen
outgoing blobs exclude held artwork; Gitleaks scans the candidate without leaks.
Evidence: `test-results/beta12-20261026/`. Follow-up documentation is audited
separately and does not rebuild/replace immutable release bytes. Physical Boox/
Bigme quality, UI responsiveness/memory and lifecycle acceptance remains open.

2026-10-26 Beta 12 preparation: user confirms Android safe mode is enabled on
the affected Boox and explicitly requests the fix plus immediate release.
`test_android_covers` exercises local extraction without the subprocess BIM
extractor, native dimensions/no fake upscale/no thumbnail downgrade, cold module
load, custom-cover API, live-reader borrowing without reload/close, metadata
preservation/ignore flags, failed decode/compress/DB/resource cleanup, visible
hero-first work, foreign-indexer/no-network/provider exclusions, bounds,
cancellation/stale callbacks, cooldown/retry and actual single/bulk refresh
seams. Optional `ORBITUI_NATIVE_SQLITE` points at KOReader's pinned binding for
a real SQLite BLOB commit and failed-write savepoint rollback. Full Lua/LuaJIT,
translation, sealed-package, older native OTA, exact asset/CI/history/artwork/
secret release gates follow. Evidence: `test-results/beta12-20261026/`.
Device checks: keep Android safe mode ON, pause/browse affected shelf pages,
refresh a selected book/batch, compare hero/slot resolution, interrupt by reader,
Home/menu/suspend/rotation, restart and verify saved covers/custom covers and
normal progress. Home has no new Android extractor; one synchronous native
document cannot be preempted, and native crashes/latency remain physical gaps.

2026-10-26 Beta 11 published: `v0.1.0-beta.11` at `03106015`, 18:43:59 UTC,
prerelease. Both full suites pass 117 Python tests/four unchanged source-cache
skips, 74 root Lua files, 483 Bookshelf suites/zero failures/three normal SQLite
exclusions and all 13 original SimpleUI files. Module map 383; syntax 1,051;
translations 43/zero failures. Sealed-byte runs under Lua/LuaJIT pass 8 HTTP,
8 updater/Trapper, 4 real menu-builder/root-dialog, 12 navigation, 3 whole-Home,
14 first-run/error, 4 book-helper, 8 October 26 and 15 Bento geometry cases.
Undeclared-global checks pass three changed host modules. Existing October 26
actual-SQLite supplements remain latest; no database code changes in this fix.

Clean package/source/inventory match; 1,996 files plus manifest, three installed
API 1 slots, 2,062 entries, 29,058,002 expanded bytes. Bootstrap/assets/fonts/
pins unchanged since reviewed main; only the optional two-line native menu seam
changes component code. All 15 outgoing blobs exclude held artwork; one-commit
Gitleaks is clean. Draft and anonymous public assets/API digests match exactly:
ZIP SHA-256 `b9a78e82ffdceaf3b2d0c77da1ec4e7c60319df4eaab60a81dfacd0b68b9b391`,
9,274,291 bytes. Actual Beta 5/9/10 installers pass local Linux native inventory,
rejection/recovery/activation/restart/code rollback and external snapshot/adoption/
persistent rollback; macOS Beta 9 passes all phases too. Anonymous published-byte
LuaSocket/LuaSec discovery/download and all phases pass from Beta 9 and Beta 10.
Main/tag CI `40379763363`/`40379764285` pass. Evidence:
`test-results/beta11-20261026/`. Follow-up docs leave runtime/ZIP unchanged;
older tags/assets remain immutable. Temporary installs do not prove the photo's
403 cause, real menu rendering or physical Bigme/Boox lifecycle/new upstream
acceptance. No automatic index/reset, network bypass or measured speedup.

2026-10-26 Beta 11 preparation: user approves updater UI/error fix and release.
Native Bookshelf menu-builder tests must exercise the optional hosted menu seam
and unchanged standalone fallback, actual OrbitUI version/preview/daily controls,
Swedish labels and real root dialog checkbox callbacks/disabled recovery actions.
HTTP tests must distinguish generic/confirmed 403, 429, 404 and 5xx, preserve the
longest bounded header wait, reject malformed/unbounded timing, omit private
response details and retain TLS/host/byte limits. Trapper/check tests must carry
safe diagnostics, suppress quiet/manual network work until cooldown expires and
retry afterward without activation or preference resets. Run complete Lua/
LuaJIT/translation/sealed/native OTA, clean source/inventory/history/secret and
draft/public/main/tag gates. Evidence: `test-results/beta11-20261026/`.
New device/network UI checks and the October 26 upstream acceptance gaps remain
open; no actual cause of the photographed 403 or measured speedup is inferred.

2026-10-26 upstream main verified/pushed at `706b7341`, not released: both
complete sequential Lua/LuaJIT gates pass 117 Python tests/four existing
external-source skips, 74 root Lua files, 483 Bookshelf suites/zero failures/
three normal SQLite exclusions and 13 original SimpleUI files. Module map 383;
syntax 1,051; translations 43/zero failures. Fresh real-SQLite supplements pass
7 deck, 16 facts, 100 OPDS cases and the daily/year/pages/invalidation ledger.
Sealed-byte runs under both interpreters pass 12 navigation, three whole-Home
cold-load, 14 first-run/error, four book-helper, eight October 26 merge and 15
Bento geometry cases. Native underlay has 16 passing ownership/wake cases.

Every validation-package path/hash/size matches clean candidate source. No
installed path is added/removed; inventory 1,995 plus manifest leaves four API 1
slots, 2,061 ZIP entries and 29,032,084 expanded bytes. Host/bootstrap/assets/
fonts/VERSION remain unchanged. All 194 outgoing blobs exclude held artwork;
Gitleaks scans 13 non-merge commits without leaks. Validation ZIP SHA-256
`119cd716929a3797c0d8cc13ff13ccd74323994ed2a37a433481fede8b80a6e4`,
9,265,056 bytes. Actual public Beta 9 native installer passes local macOS native
SHA/libarchive inventory, missing-module rejection, activation/restart/code
rollback, truncated-download recovery and external snapshot/adoption/persistent
rollback against candidate bytes. Temporary installations only; no device or
public release changes. Final evidence uses `*-current.log` and
`audit-current.json` in `test-results/upstream-20261026/`, not initial-target
logs. The immutable public Beta 10 ZIP/tag are unchanged. Headless success does
not close physical editor/rotation, wallpaper/night, image-screensaver wake,
module-toggle or Fast Book Closing/external-plugin acceptance gaps.
Main CI `40374393514` passes both interpreter jobs at this exact candidate,
including integration/translations/package/native OTA. Node/runner migration
annotations are warnings. Follow-up verification docs leave runtime/ZIP intact.

2026-10-26 upstream maintenance preparation (no release): five Bookshelf commits
through `c37580a1` (6.0.3), four SimpleUI commits through `b1580f90`. Preserve
C01-C11, VERSION/public Beta 10 bytes, existing layouts/profiles/settings/artwork.
Eight new merge cases exercise the whole wallpaper module's single-raster ownership,
legacy painting API, bounded decode/error retry, constructor/allocation/fill/paint
cleanup, copy-only library-opacity migration, fixed-grid stacking opt-in, free
percentages, later-page statistics demand and Flow night-mode source ownership.
They also cover categorized/instanced module lookup and actual picker navigation,
retaining external OrbitUI modules under Other and adding only the chosen item.
The existing geometry suite gains two real page-builder cases for stacked gaps,
warm mode invalidation and unsnapped free widths. Native underlay coverage adds
screen-hook nil results/owner-safe teardown/reinstallation beside new sleep/wake
cases. Native rendering/services are stubbed. Full gates, translations, sealed
package/source/history/artwork/secrets and native OTA validation are required;
evidence `test-results/upstream-20261026/`. New editor/rotation, wallpaper/night,
screensaver wake, module switches and Fast Book Closing/BookOrbit/patch device
checks remain open; no measured Bigme speedup or OTA publication is inferred.

2026-10-25 beta.10 published: tag `v0.1.0-beta.10` at `0a2ea22b`, 22:58:45 UTC,
prerelease. Complete sequential Lua/LuaJIT gates pass: 73 root Lua files,
117 Python tests/four unchanged external-source skips per run, 482 Bookshelf
suites/zero failed/three normal SQLite exclusions, all 13 original SimpleUI
files. Module map 383; LuaJIT syntax 1,049; translations 43/zero failures.
The four whole-module helper/opener, 12 navigation, three cold-load Home and
14 first-run/error cases also pass on sealed ZIP bytes under both interpreters.
All eleven changed runtime modules pass Luacheck's undeclared-global checks
with the explicit KOReader host globals; optional broader style lint reports
unused/shadowing warnings, not undeclared globals. Fresh actual-SQLite runs
pass 7 deck, 16 facts, 100 OPDS cases and the SimpleUI ledger checks.

Every package file matches committed source and manifest hash/size. No old path
is removed; only the Beta 10 note is added. Inventory 1,995 plus manifest leaves
four installed API 1 slots; 2,061 entries, 27,950,557 expanded bytes. All 42
outgoing blobs exclude held artwork; Gitleaks scans ten non-merge commits with
no leaks. Host/SimpleUI/assets/fonts/bootstrap remain unchanged; Bookshelf
matches the reviewed import. ZIP SHA-256
`d461f9afd5a1e122df4bacfa44b4e6595b27a024acc0e43b9bd78739d21cdd43`,
9,035,141 bytes. Draft and anonymous public bytes/digests match exactly.

Actual public Beta 9 and Beta 5 installers pass local Linux and public-byte
anonymous TLS discovery/native SHA/libarchive inventory, missing-module
rejection, activation/restart/code rollback, truncated-download recovery and
external snapshot/adoption/restart/persistent rollback. Local macOS Beta 9
also passes all phases. Main/tag CI `40242459682`/`40242459905` and upstream
watch `40242459666` pass at the exact candidate. Evidence:
`test-results/beta10-20261025/`. These are temporary installations, not reader
tests. Home/navigation has user confirmation; new cover refresh/repaint/tick/
module-key and broader Bigme/external-plugin physical acceptance remains open.
Verification follow-up docs do not rebuild or replace the immutable assets.

2026-10-25 beta.10 preparation: explicit user request to merge upstream, push
and publish. Review all eight Bookshelf commits through `5f726c25` (6.0.2),
retain SimpleUI `40b301f0`; conflict-free unsquashed merge `0db81b46`.
New native cases cover refresh/requeue, clipped colour shadows, status bounds,
covered-window ticks, module book helpers and editor key focus. The four-case
`test_module_book_integration` loads both entire helper/opener modules with
native services stubbed, checking live-host/deferred-close delivery, detail
hydration, ReaderUI fallback and adopted surface ownership. Update the runtime
version fixture, not production code, from 6.0.0 to 6.0.2. Re-run both complete
gates, translations, sealed-byte regressions, inventory/history/artwork/secrets,
actual public Beta 9/Beta 5 native OTA and draft/public/main/tag verification.
Evidence: `test-results/beta10-20261025/`. No new runtime path or data migration;
one installed release note should leave four slots under the old API 1 limit.
User confirms Home and Beta 9 navigation work on Boox; new cover-refresh,
colour repaint, minute-tick/overlay, module-key, rotation and Bigme lifecycle/
external-plugin checks still need physical testing. No native Android mutex
crash diagnosis or measured speedup is inferred.

2026-10-25 beta.9 published: tag `v0.1.0-beta.9` at `a4bb9acb`, 19:49 UTC,
prerelease. Both complete Lua/LuaJIT suites pass: 72 root Lua files, 117 Python
tests/four unchanged external-source skips, 478 Bookshelf suites/zero failures/
three normal SQLite exclusions, all 13 original SimpleUI files. Module map 383,
LuaJIT syntax 1,044, translations 43/zero failures. The 12 navigation, three
whole-Home-load and 14 first-run cases also pass on sealed ZIP bytes under both
interpreters. Explicit-host-globals Luacheck passes on all seven changed runtime
files. Source/inventory comparison, all 31 outgoing blobs/held-artwork checks and
four-commit Gitleaks pass. No existing path is removed; only the new release note
is added. Components/pins/bootstrap/fonts/artwork are unchanged; 1,994 inventoried
files plus manifest leave five API 1 slots. Local and anonymous published-byte
Linux/LuaSec/native OTA from actual Beta 8 and Beta 5 pass release discovery,
SHA/archive verification, activation/restart, rollback, missing-module/truncated
download rejection and external snapshots/adoption/persistent rollback. Main/tag
CI `40227604923`/`40227604800` pass. Draft/public assets match the build exactly:
ZIP SHA-256 `3a2c8fab178e01ff99822b8b8a6105bc4d70228f42a2f6fa227a6275403842c9`,
9,025,063 bytes. Evidence: `test-results/beta9-20261025/`. No database supplement
was repeated for this host-only change; recorded Beta 6 supplements remain latest.
New physical Boox/Bigme navigation/reader-transition checks below remain open.
The earlier user-confirmed Beta 8 Home check is not native Android crash acceptance.

2026-10-25 beta.9 publication preparation: the user explicitly approved push
and publication after disclosure that the new navigation flow still needs device
testing. Re-run both complete suites and translations on the versioned tree,
the 12 navigation cases and retained Home regressions against sealed ZIP bytes,
source/inventory/history/artwork/secret audits, real public Beta 8/Beta 5 native
installers against local and public bytes, draft/public digest checks and main/tag
CI. Preserve all component source/pins/fonts/artwork/bootstrap API 1. Only the new
release note adds an installed file: expected 1,994 plus manifest, five API 1
slots remain. Evidence: `test-results/beta9-20261025/`. Physical checks below
are not replaced by these headless gates. Keep Beta 8's public assets immutable.

2026-10-25 Bookshelf navigation (local/unreleased): the user confirms Beta 8
Home works, then reports a silent `open_bookshelf_prose` navbar action on a fresh
Boox. Reproduce missing legacy profile rejection and cover a first-class default
Bookshelf action without prose/comics, saved-bar/label/icon preservation,
explicit persistent removal, direct profile buttons/targets, same-view defaults,
missing/disabled repair, full-bar explicit replacement, correct generic/specific
indicators, real deferred profile enforcement after simulated reader parking,
newer-request ownership, and minimum/navpager limits. The 12-case new suite loads
the complete config and QA modules, real library model/profiles, bridge and host
adapters; native delivery/rendering/reader lifecycle are stubbed. Run both full
gates, translations and a clean local validation ZIP; do not publish or replace
Beta 8 assets. Evidence: `test-results/bookshelf-navigation-20261025/`.
Verification completed locally at candidate `2366897f`: both complete Lua/LuaJIT
gates pass (117 Python/four unchanged skips, 478 Bookshelf/zero failed/three
normal SQLite exclusions, all 13 original SimpleUI files). All 72 root Lua files
were rerun under both interpreters after the final label/test refinements.
Module map 383, LuaJIT syntax 1,044, translations 43/zero failures. All 12 new
cases also pass under both interpreters against the extracted sealed ZIP using
`ORBITUI_TEST_ROOT`. This includes an empty profile inventory/no chosen home,
not merely a home-folder-generated Library. Package/source/hash comparison
passes: the same 1,993 inventoried paths plus manifest; no additions/removals,
unchanged component source/pins/bootstrap/fonts/artwork, six API 1 slots remain.
All 15 candidate blobs exclude the held artwork; Gitleaks reports no secrets.
Local validation ZIP SHA-256:
`10fd487498b313add62e47c719f52b2456a069944c8eb9ebd819bf6f56681735`.
This same-version ZIP is validation only, not a replacement public Beta 8 or an
install recommendation. Follow-up tests/docs do not change candidate runtime.
Physical acceptance: fresh Boox with no home/with a chosen home; open Bookshelf
from Home and the file browser; create Prose/Manga with separate chips; select
each as a button target and as separate buttons; full-bar replacement/cancel;
remove/restart; rename/disable a target; verify Bigme's existing aliases and
chip style settings; parked-reader returns, rotation and dock indicators.

2026-10-25 beta.8 published: tag `v0.1.0-beta.8` at `50edce78`, 19:00 UTC,
prerelease. Both complete suites pass: 71 root Lua files, 117 Python tests/four
unchanged skips, 478 Bookshelf suites/zero failed/three normal SQLite exclusions,
all 13 original SimpleUI files. Module map 383, LuaJIT syntax 1,043, translations
43/zero failures. The three whole-engine and 14 first-run cases also pass on
sealed ZIP bytes under both interpreters. Explicit-host-globals Luacheck passes
for the complete engine/Home/navigation sources. Inventory/source equivalence,
all nine outgoing blobs/held-artwork checks and two-commit Gitleaks pass.
The sole runtime difference from Beta 7 is one import; no file is removed.
Both public Beta 5/Beta 7 native installers pass local and anonymous published-byte
Linux/LuaSec discovery, native hash/archive verification, activation/restart,
rollback, missing-module/truncated-download rejection and external snapshots.
Main/tag CI runs `40223707342`/`40223707268` pass. Draft/public assets exactly
match the sealed build: ZIP SHA-256
`ebd0271530e30cb2173ca9e87c974351321b60b7c314ffc38179e3f111b82bca`,
9,012,570 bytes; 1,993 inventoried files plus manifest, six API 1 slots remain.
Evidence: `test-results/beta8-20261025/`. Physical Go Color 7 Home/native-crash
and wider Bigme acceptance remain outstanding. No new database supplement was
needed for this import-only hotfix; Beta 6's recorded supplements remain latest.

2026-10-25 beta.8 preparation: the supplied photo identifies a missing
`Blitbuffer` global at engine module initialization, line 288. The new
`test_home_module_load.lua` loads the ENTIRE engine without ambient Blitbuffer
or logger, not an extracted factory. Both interpreters reproduce that exact
error before the one-line import fix and pass afterward. Three cases cover
whole-module exports/colour initialization and Home/Custom Screen opening,
fresh/existing settings, identity, callbacks and cached-state preservation.
Native construction/rendering and surrounding services remain stubbed. Retain
the 14 first-run/error/retry tests too; run both suites against sealed ZIP bytes,
both full gates, translations, package/history audits and real Beta 5/Beta 7
native OTA/rollback. Evidence: `test-results/beta8-20261025/`. Neither this
reproduction nor headless tests establish native Android crash resolution.

2026-10-25 beta.7 published: tag `v0.1.0-beta.7` at `31f287e1`, 18:34 UTC,
prerelease. Both complete Lua/LuaJIT suites pass (70 root files, 117 Python tests
with four unchanged skips, 478 Bookshelf suites with zero failures/three normal
native-SQLite exclusions, all 13 original SimpleUI files). Module map 383,
LuaJIT syntax 1,042, translations 43/0 failures. All 14 new cases also pass on
the extracted sealed ZIP under both interpreters. Exact source/inventory and
outgoing held-artwork/secret audits pass. Both public Beta 5/Beta 6 installers
pass local and anonymous published-byte Linux/LuaSec discovery, native hash/
archive verification, activation/restart, rollback, missing-module/truncated
download rejection and external snapshots. Main/tag CI runs
`40221675093`/`40221674987` passed; draft/public assets match the tested build.
Evidence: `test-results/beta7-20261025/`. Physical Home/native-crash retesting
on the affected Go Color 7 and wider Bigme acceptance remain outstanding.

2026-10-25 beta.7 preparation: reproduce the missing-logger failure on a fresh
Home, not only a configured/onboarded fixture. `test_home_first_run.lua` executes
the real Home facade and generic open factory with native services stubbed;
all 14 cases pass under Lua/LuaJIT after the first case fails on the previous
source. Cover absent/false/true onboarding flags, host no-op onboarding, original
callbacks/shared identity, real require failures and owned-sentinel cleanup,
retained initial cause, partial constructor/show/hook failures, close/notification
failures, third-party replacement ownership and the actual Home action.
Persistent error messages must not auto-reopen Home on close. Run this suite
against extracted release bytes too, then both full gates, translations, clean
packaging and public Beta 5/Beta 6 native OTA/rollback. Evidence:
`test-results/beta7-20261025/`. No physical Home/native-crash resolution is inferred.

2026-10-25 beta.6 publication completed: tag `v0.1.0-beta.6` at `7e573fd9`,
published 17:52 UTC as a prerelease. Both complete local Lua/LuaJIT runs and all
43 translations pass; native SQLite deck/facts/OPDS/ledger checks also pass.
The sealed package contains 1,991 inventoried files plus manifest (eight API 1
file slots remain). All 876 outgoing blobs exclude the held bitmap; Gitleaks
reports no leaks across 188 commits. Draft/public downloads match the build
exactly. Local macOS/Linux and anonymous public-byte Linux/LuaSec OTA from the
actual Beta 5 installer pass discovery, full native hash/archive verification,
missing-module rejection, activation/restart, code rollback, truncated download
and external snapshots/restart/persistent rollback. Main/tag CI runs
`40218238089`/`40218233505` passed. Evidence: `test-results/beta6-20261025/`.
Beta 5 remains immutable; the physical Bigme checklist remains open.

2026-10-25 beta.6 publication preparation: the user explicitly requested push
and publication after disclosure of the remaining Bigme checks. Keep prerelease
status; no new physical-device acceptance is claimed. Re-run both complete
Lua/LuaJIT suites and translations on the versioned tree, seal/audit the exact
clean-commit ZIP and all outgoing history/artwork/secrets, and retain bootstrap
API 1 and existing assets/fonts. Exercise the actual public Beta 5 installer
against local and downloaded public Beta 6 bytes, including activation/restart,
rollback and external snapshots. Verify draft/public asset digests and main/tag
CI. Evidence: `test-results/beta6-20261025/`. The device checklist below remains
open. The standing merge authorization now includes audited pushes, not releases.

2026-10-25 reviewed upstream import (unpublished): Bookshelf 6.0.0 plus
follow-ups through `fc1103a3`, SimpleUI 3.0 through `40b301f0`. Reconcile the
previous ZIP snapshot without discarding original suites or OrbitUI choices.
Regression coverage includes scoped group restoration, hosted grid/deck rollback
keys, failed SQLite transactions, complete/retryable daily statistics, Insights
year ranges, bounded aspect-true sticker ownership, independent labels/bindings,
top/dock gesture exclusions, nil-return/third-party underlay hooks and navigation
generations. Full sequential Lua/LuaJIT and translations are required; supplement
the normal runner's three SQLite exclusions with actual native database runs.
Evidence: `test-results/upstream-20261025/`.

Bigme checks still required: existing top-panel and fullscreen module layouts
before/after migration and rotation; module move/resize/page/palette controls;
Shelf/Ornament modules among books; Pin here alongside bound add-ons; labels,
bindings, captions and aspect-true series stickers; Highlights from both Home
and Library; menu/sleep underlay restoration, day/night/grayscale; statistics
after reader return or cloud import; external BookOrbit/MAL/Patch Manager hooks.
Headless checks do not establish device performance or physical acceptance.
VERSION remains Beta 5 until a separate release request; a local validation ZIP
must never replace the public Beta 5 asset or be described as a new OTA release.

2026-10-23 beta.5 publication: user explicitly requested push and publication
after disclosure of the remaining Bigme checks. Retain the existing beta's
limited device evidence; this is a prerelease, not new physical acceptance.
Re-run both full Lua/LuaJIT suites and translations on the versioned tree,
audit all outgoing Git objects (including the release-snapshot parent), secrets,
held artwork, sealed inventory and unchanged bootstrap/Bookshelf/artwork.
Exercise the actual public Beta 4 installer locally and against anonymous public
Beta 5 bytes, including restart, rollback and external-runtime snapshots. Verify
main/tag CI and exact downloaded draft/public assets before handoff.
Evidence: `test-results/beta5-20261023/`; the device checklist below remains open.

2026-10-23 SimpleUI 3.0 release-ZIP import (unpublished): verify the exact official
asset against its recorded digest, then preserve all original suites. New
regressions exercise copy-only badge/folder migrations, failed-migration retries
and embedded deferral, legacy stacked/percentage Bento layouts and explicit
fixed-span activation, independently aligned new rows, retryable chart/session
queries, the old Reading Stats module alias, Lua 5.1 varargs and owner-safe
night-mode teardown beneath external wrappers. Native search tests execute the
new dialog facade; icon tests retain custom sources, weights, cancellation and
both legacy picker signatures. Package all new fonts/OFL notices, critter assets
and module paths; keep the public VERSION/bootstrap and Bookshelf pin unchanged.
Evidence: `test-results/upstream-simpleui3-20261023/`.

Physical acceptance still required on Bigme B7 Pro: existing Home/Custom Screen
layout before editing, new preview and width/movement controls, detailed stats
and charts after reader return, accent day/night and grayscale, font selection
and fallback, optional Tiny Critter, dialog keyboard/touch/D-pad, suspend/resume,
and BookOrbit/MAL/Patch Manager interactions. No device acceptance or release
approval is inferred from headless tests or this import request.

2026-10-22 beta.3: reviewed Bookshelf 5.5.5 plus PR #544. Run both complete
Lua/LuaJIT suites, including the upstream tests for base-shelf Back/Folder up,
refresh action, cached ratings, read-state sort invalidation and spine colour
reset. Additional regressions preserve doc_pages/rendered-cache priority with
stable labels disabled, lazy variable-width glyph construction and the Shelf
size translator after wrapping/repainting. Verify unchanged bootstrap and
artwork, sealed packages, public bytes and native Beta 2 upgrade/rollback.
No new physical-device test is claimed: check corner-star fit, tall top panels,
gesture navigation, colour resampling and your Home/Library/Manga layout after
updating. Evidence: `test-results/beta3-20261022/`.

2026-10-19 beta.2: user requested publication after the reported headless tests
and remaining device gap. No new physical-device result is claimed. Coverage
includes complete external-root snapshots, deferred main-process activation,
unchanged/older factory copies, incomplete/corrupt inventories, symlink parents,
cancelled/stale activation, failed startup, manual rollback and explicit retry.
The stable bootstrap and API 1 remain unchanged. The packaged native smoke test
also exercises import/restart/rollback after ordinary OTA installation.

Ornament channel migration accepts only the exact old/new repository prefixes,
retains cached catalogs and registry state, and rejects changed immutable pack
versions. All six ZIPs and previews in the new repository are byte-identical to
the original release; the legacy release remains intact. Native HTTPS/archive
testing installs from legacy URLs, refreshes the new catalog and verifies that
updates preserve local captions, deletions, enablement and placement. Actual
app-store installation and the extra-restart prompt still need device feedback;
Storefront's separate installer fix must be released first.

2026-10-19 beta.1: the user confirmed the alpha.55 ornament menu now works and
explicitly approved the first public beta. Earlier reader feedback confirmed
the retained layout, restart and setup/preset controls. This is limited device
evidence, not a completed fresh-install/device matrix.

Release review found native Bookshelf 5.3+ settings were not selected by the
flat-path adapter. Beta.1 reads the existing native layout in place when no flat
settings/backup exists, retains native reader-line keys, snapshots native Lua
settings and recognizes that install as existing during onboarding. Regressions
cover both layouts and `.old`, deterministic flat precedence, stable per-session
paths, auxiliary stores/caches/SQLite companions, no file moves, native read/write,
backup failure and preservation, and no automatic setup prompt. Native standalone
migration still needs wider physical-device feedback. No upstream pins or artwork
changed. Public documentation now separates upstream credit, OrbitUI additions,
installation, limited backup coverage and rollback caveats.

2026-10-19 alpha.55 release preparation: reproduce opening the
ornament add-on menu from Home with pre-existing, unmanaged ornament folders.
The status-label branch shadowed the gettext function with the numeric loop
index, failing before the menu opened or any download started. The regression
test fails on the released code under both Lua and LuaJIT, then passes after
renaming the two loop indexes. Cover each legacy Manga folder in both native
roots, with Swedish and English labels, and assert opening the menu neither
downloads/adopts artwork nor changes installed state or theme switches. Preserve
the existing install/update/placement tests. Device confirmation is still needed.

2026-10-19 ornament placement (unpublished): test the read-only matching default,
per-pack random choices, disabled-state preservation, failed atomic writes,
restart, stale update plans and preference retention across update/reinstall.
Use the real native dealer/planner for mixed modes, ordinary bust row limits,
targeted author priority, broad/narrow rows, bare shelves and pagination/render
agreement. Check default spacing vs random spacing, dynamic bindings, saved
manual deck order and parked page-cache invalidation. Exercise the translated
menu's selection/cancel path. Device acceptance still needs mode switching,
paging, restart and updating a pack in both Library and Manga; headless tests
do not prove native touch-menu layout or e-ink rendering.

2026-10-19 ornament languages (unpublished): every information card in all six
add-on packages must carry Swedish and English text, identical source/licence
links, and captions no longer than the native 4000-byte limit. Changed source
text requires reviewed translations. Exercise Swedish locale variants, English
fallback for other/missing languages, native caption-layer precedence, custom
text preservation and three-way metadata updates with Lua and LuaJIT. Check the
actual built ZIPs, not only the translation source. On-device acceptance still
needs installing/updating a pack, opening zoom cards in both languages after
restart, and verifying a reader-edited caption remains unchanged.

2026-10-19 alpha.53 publication preparation: the user explicitly chose one final
OTA test alpha because the standalone build has not been tested on the reader.
Release all four configuration stages together; do not label this beta. Re-run
the complete sequential Lua/LuaJIT suites, translations and clean-commit package.
Audit runtime changes against public alpha.52, exact assets/bootstrap/upstream
pins, outgoing history, held artwork and secrets. Exercise alpha.52's native
installer before publication and against anonymous public bytes, including
activation, restart, rollback and interrupted download recovery. Verify main/tag
CI and downloaded draft/public assets. Evidence: `test-results/alpha53-20261019/`.
The release checklist in `releases/0.1.0-alpha.53.md` requires physical tests of
both preserved upgrades and an isolated fresh setup before beta approval.
The first full run caught an obsolete source-shape assertion in Bookshelf's
ornament-frequency test. Replace it with execution of the real dial row,
covering live apply plus host override, read-only callbacks and restoration of
the saved frequency. Re-run both complete suites; no runtime workaround is used.

2026-10-19 standalone appearance stage 4 (unpublished): test neutral defaults
before component seeding, existing OrbitUI defaults, first-time adoption over
standalone component settings, persistence, unknown schemas and failed writes.
Exercise native per-chip/profile/global orientations and series toggles, reversible
Classic/Minimal overrides, singleton grouping, active/parked pagination caches,
targeted and ordinary ornament suppression, optional independent pack installation,
session shuffling, confirmation/cancel and setup drafts. Both runtimes must pass
the existing geometry, ornament, settings, integration and upstream suites.
Evidence: `test-results/appearance-presets-20261019/`.

Device acceptance additionally needs all three presets on physical shelves in
Library and Manga, after paging, opening/returning from a series, restart and
changing a native chip style. Test a fresh settings copy without integrations,
and an existing setup with custom packs/backgrounds/icons. Confirm no artwork
is installed on any first launch or preset selection; Add-ons explicitly installs
the packs, Minimal hides every ornament, and returning to Shelf settings restores
saved choices. Test profile chips sharing IDs with native tabs. Verify touch-menu
refresh and Home/back navigation. Do not infer device acceptance from headless tests.

2026-10-19 standalone setup stage 3 (unpublished): exercise detection before
component defaults, fresh/FileManager and reader-first launches, preserved
upgrades, one automatic prompt per session, pending/skip/reopen, teardown and
late callbacks. Draft tests cover folder changes, stable IDs, stale snapshots,
removable drives, launch targets, additive dashboard pages, ordered/capped bar
buttons, save/flush failures and touched-key rollback. Verify standalone
SimpleUI still owns its original onboarding while the embedded instance does
not overwrite launch/book-close choices. Optional integration inspection must
work without installed providers and make no provider/client calls or show
credentials. Run both runtimes, translations and a sealed development ZIP from
the actual working tree, without committing or changing VERSION/upstream pins.
Evidence: `test-results/setup-guide-20261019/`.

Device acceptance for this stage: use an isolated fresh KOReader settings copy,
then a copy of an existing OrbitUI setup. Test Cancel, Skip, Review/Apply and
reopening from settings; folder picker/keyboard/back in both orientations;
reader-first startup; changes to the dock and Home after restart; disabled or
missing providers and no network. Verify old shelves, custom pages, icons,
book-close behavior and credentials remain intact. Recovery tests include
unwritable settings and interrupted startup. Headless tests are not device
acceptance; artwork/public-release review remains separate.

2026-10-19 alpha.52 publication preparation: explicitly requested for Manga III.
The implementation passed 696 Lua / 697 LuaJIT root cases in 54 suites,
407 Bookshelf suites (two existing environment skips), all 13 SimpleUI files,
108 Python tests (four existing external-source skips), 43 translation
catalogues and clean-commit packaging. Re-run both runtimes for the release;
audit the exact runtime delta against public alpha.51, outgoing history,
held artwork and secrets. Verify both CI refs, downloaded draft/public bytes
and alpha.51's native installer, including activation, restart and rollback.
Only the new Manga III artwork/metadata and its series registration are added;
older assets, component code, upstream pins and bootstrap remain unchanged.
Evidence belongs in `test-results/alpha52-20261019/`. Keep prerelease status;
physical Bigme appearance and interaction remain unverified.

2026-10-19 alpha.51 publication preparation: explicitly requested after the
Oneshots/singleton boxes, enlarged dashboard pagination/swipes and editable
card headings. Only VERSION and release documentation change during preparation.
Re-run full sequential Lua/LuaJIT suites, translations, clean-commit packaging,
outgoing-history/artwork/secret audits and both CI refs. Compare all runtime
changes with public alpha.50; bootstrap, assets and upstream pins must remain
identical. Exercise alpha.50's native installer before publication and against
anonymous published bytes, including activation, restart, rollback and failed
download recovery. Verify downloaded draft/public hashes. Evidence belongs in
`test-results/alpha51-20261019/`. Keep prerelease status; no physical Bigme
acceptance is inferred from these headless tests.

2026-10-19 Oneshots and singleton boxes (unpublished): exercise exact local
directory matching, nested title folders, duplicate files, separate same-named
directories, real series named Oneshots, cached metadata, grouped stubs and
one-volume series on ordinary and profile shelves. Verify unmodified native
defaults, incomplete/windowed-list guards, grid/search/OPDS exclusions, scoped
folder chips, pagination/letter-jump identity and source-record immutability.
Native folder tap/hold and image callbacks, path-only navigation restore and
fresh membership fetch must work; the open folder must not rebox its members.
Render singleton and folder counts before/after completion in both colour modes,
and exclude misleading representative ornaments, series binding names and MAL
ratings. Evidence belongs in `test-results/oneshots-boxes-20261019/`. Run full
sequential Lua/LuaJIT, translations and a clean-commit package. No publication
or upstream pin change is part of this request.

Completed automated gates: 694 Lua / 695 LuaJIT root cases in 54 files,
407 Bookshelf suites and all 13 SimpleUI files on both runtimes. Python:
103 tests with four existing external-artwork-source skips; Bookshelf retains
two environment suite skips. All 43 translation catalogues, 318 module paths
and 874 syntax files pass. Physical Bigme rendering, navigation and read-status
acceptance remain open.

2026-10-19 dashboard pagination and swipes (unpublished): test larger arrows,
page-counter type and hit targets near each card bottom at five screen sizes
and three DPI factors, preserving portrait cover size and footer/dock bounds.
Exercise independent west/east paging, mixed arrow/swipe use, clamping, no-op
boundary/empty/single-page swipes, pending-hold cancellation and refreshed data.
Run the native SimpleUI screen-routing methods against the real dashboard
handler: other cards still turn Home pages, hidden modules do not consume
swipes, and vertical and edge gestures retain their file-manager actions.
Evidence belongs in `test-results/dashboard-pagination-20261019/`. Run complete
sequential Lua/LuaJIT, translations and clean-commit ZIP validation without
updating VERSION or public alpha.50 assets. Physical Bigme touch, typography,
redraw, rotation and swipe-direction acceptance remain open.

Completed automated gates: 684 Lua / 685 LuaJIT root cases in 54 files (34
dashboard cases), 407 Bookshelf suites and all 13 SimpleUI files on both
runtimes. Python: 103 tests with the four existing external-artwork-source
skips; Bookshelf retains two environment suite skips. All 43 translation
catalogues, 318 module paths and 874 syntax files pass. The optional schematic
was rendered and inspected with synthetic covers, not native device fonts.

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

- On Manga/Serier physical shelves, confirm the Oneshots box contains every
  local member (including nested title folders), preserves read/total counts,
  opens the real folder and offers the folder menu on hold. Check folder image
  overrides, restart/Back and added/deleted books, with no nested Oneshots box.
  Named one-volume series must box too, including in Library, and open to their
  individual volume. Confirm completion, cover proportions, bindings and
  pagination on the Bigme; no shared MAL score belongs on the Oneshots box.

- Enable **OrbitUI settings > Reading dashboard > Show dashboard as first Home
  page**. Confirm older Home pages still appear on swipe, retain their settings,
  and are unchanged after disabling the dashboard, including edits made while
  it was enabled. Repeat after restarting KOReader.
- On the dashboard check portrait/landscape, actual DPI/font choice, long titles,
  dark/light hero, night mode and large dock/pager margins. No card should paint
  under the pager/dock. Covers keep their proportions and colour.
- Rename cards via Reading dashboard > Headings from both settings entry points.
  For Beta 15 also test **Home (SimpleUI) > Reading dashboard > Card colours**
  (Hem (SimpleUI) > Läsöversikt > Kortfärger) and native module settings:
  Off/Accents/Tinted cards, before/after restart and independently on Custom
  Screens. Existing installs must remain Off. Check real coloured fills/borders
  and progress on Boox/Bigme, dark/light hero with colourful/grey/missing/custom
  covers, night-mode flips, colour rendering on/off and an actual monochrome
  reader. Cover arrival must only recolour its frame, not change text, row pages,
  sources or book actions. Check portrait/landscape, language/search, Back,
  reader return, sleep/resume and tinted-area ghosting without changing native
  refresh preferences. Schematic SVGs/contrast tests are not display acceptance.
  Check the keyboard, immediate redraw, long Swedish/CJK titles, persistence
  after restart and language changes, Cancel, blank input and Restore default.
  Other Home modules and Custom Screens must retain their own names; reset must
  restore the current-book status title and configured reading-goal title.
- Open and hold the hero, each ongoing book and both cover rows. Change progress
  and completion status, return from the reader, switch pages and sleep/resume;
  check updated counts/bars and no stale/freed covers. Page Want to Read and New
  Books independently with the larger arrows and left/right swipes anywhere
  within each card. Check the counters, first/last-page stops and empty or
  single-page lists never switching Home pages. Other cards should still allow
  Home-page swipes; edge gestures retain their configured actions. Check the
  larger targets never cover a book or the Home pager/dock. Verify BookOrbit auto-refresh
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
