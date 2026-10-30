# OrbitUI project context

This is the durable orientation map for continuing OrbitUI work after the
original development conversation was lost. It summarizes the current state;
it does not replace the detailed contracts, merge record, release procedures or
device checklist linked below.

## Authority and reading order

1. `AGENTS.md` contains mandatory safety and release rules.
2. `docs/INTEGRATION_CONTRACTS.md` defines behavior that reviewed merges must
   preserve. Contract IDs C01-C11 are stable references.
3. `docs/MERGE_LOG.md` records the exact history, approvals, conflict decisions,
   tests and device gaps.
4. `sources.json` is the source of truth for imported provenance and currently
   integrated upstream commits.
5. `docs/UPSTREAM.md`, `docs/TESTING.md`, `docs/OTA.md` and
   `docs/MIGRATION.md` govern their respective workflows.

If this summary conflicts with one of those sources, follow the specific source
and correct this file in the same change.

## Snapshot: 2026-10-30

- The user explicitly requests a new beta after the main push and confirms
  leaving Hardcover/automatic edition linking unchanged. Prepare Beta 19 from
  clean public `493eb05a` on `release/search-collections-beta19-20261030`.
  Include the already-reviewed search/collection work and evening SimpleUI merge,
  no additional import, hardware patch, source pin or installed-path change.
  VERSION advances to `0.1.0-beta.19`; bilingual notes use existing docs/OTA.md.
  Inspiration watch is active: first run `41133753256` succeeded and owns issue
  #2; main CI `41133753262` passed both jobs/native OTA. Release requires fresh
  full/sealed/translation/source/history/secret/native installer gates and exact
  draft/public byte audits; record results in MERGE_LOG. Physical Boox/Bigme
  acceptance remains open and the release must be a prerelease, not stable.

- Local approved Kobold follow-up on
  `feature/search-collections-inspiration-watch-20261030`, from public `71442369`:
  shared search gains ten local recent query/scope pairs and relevance/title/
  author/series ranking before the existing cap. Preserve groups, profile/current
  membership and original reader/book-panel callbacks. Collection management
  gains an optional host-owned content editor: searchable members/additions/
  changes, live counts, title/author sorting, explicit Save/Cancel, native local
  ReadCollection writes to one manual collection only. Favourites/folder-managed
  collections stay with KOReader; no remote list, metadata or book-file writer.
  A separate six-reference inspiration watcher uses explicit idea/path mappings
  in `scripts/inspiration-sources.json`, not `sources.json`. References are
  design comparisons, not vendored upstream or integrated revisions. It reports
  matching commits (including reverted changes, rename/deletion and missing-path
  warnings), fails closed on rewritten history/errors and never imports/executes
  reference code. Bookshelf-OS currently exposes only README in its source tree:
  monitor README/release metadata and clearly request manual code review.
  Initially local-only; the subsequent user request "Pusha" authorizes the
  verified main push and workflow/dashboard activation, NOT a release. No version
  bump, source-pin change, new runtime path or device acceptance is implied.
  See UPSTREAM/SHARED_UI/TESTING for operation, limits and remaining checks.
  Source/package candidate `3e01ee0f` passes both full interpreter gates and
  final sealed root reruns, 43 catalogs and exact path/source/artwork/secret
  audits. Same 2,000 installed paths, only a 12-line optional component action;
  development digest/evidence is in MERGE_LOG. Verification docs do not replace
  the sealed ZIP; GitHub activation is checked after push, device tests remain open.

- Evening user request "Merga upstream": from clean public `70fc3473`, review
  and merge all 18 SimpleUI commits through `7a605bbc261196fa65609adf26f59c77a4d966a7`
  (3.0.2 plus branch follow-ups); Bookshelf remains `ee84a8fe` with no new commits.
  Unsquashed subtree import `6c3b9324` uses upstream's real plural-expression
  parser instead of the superseded local ternary translator. New Reading
  Insights monthly books/pages chart has an independent year selector; it does
  not change the dashboard layout or remote goal/sync ownership. Preserve the
  custom-screen Dispatcher fix, passive-toast Home return, our generation guards
  and Beta 18 quick-control seams. Retry missing/busy/incomplete activity reads
  in both provider and window; complete empty years have an explicit SQL sentinel,
  incomplete finished-ledger reconciliation cannot seal totals, and future-year
  page caches remain queryable at rollover. Full invalidation rereads historical
  months; partial invalidation retains closed months. Add Swedish new labels and
  retain all languages. No new installed path, bootstrap, artwork or hardware
  patch. Standing authorization includes audited main push, NOT publication:
  VERSION/public Beta 18 and all its assets remain immutable. Verification and
  device gaps are recorded in MERGE_LOG; this is not a measured Bigme speedup.

- User now explicitly requests the next beta after the unpublished-code audit.
  Beta 18 is public at exact candidate/tag `7c0f7057`, published 2026-10-30
  16:31:24 UTC from `release/quick-controls-beta18-20261030`, clean `e2f1aa32`
  and prior public main `f97d9bd0`. It contains only the reviewed quick-control
  input fixes below plus version/English-Swedish release documentation; no new
  upstream import, hardware driver or installed path. Prior local-only approval
  is superseded for this release. VERSION is `0.1.0-beta.18`; both complete
  interpreter gates, all sealed root/native-owner suites, 43 catalogs and exact
  source/history/artwork/secret/draft/public audits pass. Main/tag CI
  `41089949928`/`41089950111` are green. Native actual-Beta-5/9/17 installers
  and live public-byte application-TLS upgrades from Beta 9/17 pass. Preview
  selects Beta 18; stable and all 72 previous releases/assets/tags are unchanged.
  Exact digest/results are in MERGE_LOG and `test-results/beta18-20261030/`.
  Verification-only docs do not rebuild/replace the tagged ZIP.
  Physical quick-control acceptance remains open. The optional Bigme frontlight
  userpatch is already published separately through Ereader and
  `komadorirobin/koreader-bigme-frontlight`, not embedded in OrbitUI.

- User's Beta 17 device test exposes two quick-control integration regressions:
  Home's priority menu zone consumes status taps before child cells, and SimpleUI
  converts unanchored plain dialogs into action sheets that fail the controller's
  exact topmost-dialog guard (including Close). User approves LOCAL fixes only,
  on `fix/quick-controls-input-20261030` from clean `f97d9bd0`; no push/release.
  A three-line optional `sui_core.beforeGesture` seam lets the chrome adapter
  dispatch only current painted Home/custom-screen status cells before the menu,
  preserving configured corner gestures, holds, whitespace and native FM input.
  Dormant wrappers read the opt-in live, so toggling needs no body/provider
  rebuild. Quick dialogs explicitly use the documented `sui_native` opt-out;
  lifecycle/navigation guards are not weakened. Six new full-owner cases cover
  these regressions; the two reproduced failures pass after the fixes. Tests use
  the real Core/NativeSheets and optional whole minimum/current native input/UI.
  VERSION remains Beta 17; pins/bootstrap/assets/installed paths stay unchanged.
  Source/package candidate `c1fe57df` passes both complete interpreter gates,
  fresh final 86-root-file reruns, 43 catalogs and all 28 quick-control cases on
  sealed bytes (also with current native input/dialog boundaries). Exact ZIP/
  source/path/secret audits pass; evidence is in MERGE_LOG and ignored
  `test-results/quick-controls-input-20261030/`. Verification-only docs do not
  rebuild that same-version development ZIP. Nothing is pushed/published;
  fixes are not installed or physically accepted on Boox/Bigme yet.
  The separate Bigme light problem reproduces in native KOReader with OrbitUI
  disabled. User reports all compatibility light choices fail; supplied test.log
  identifies `bigme/hibreak`, MT6877, Generic plus missing Onyx DeviceController.
  No Bigme hardware driver, ADB permission change or device write is included.

- User explicitly requests push and publication so the new quick controls can
  be tested on Boox/Bigme before further reader UI work. Beta 17 release branch
  `release/quick-controls-beta17-20261030` starts clean at `b83c2175`, with public
  main `44316d3e`. Include the approved quick controls, category cards and the
  already-reviewed October 30 imports; do not fetch/import another upstream.
  Beta 17 is public at exact candidate/tag `ab2e0bd7`, published 2026-10-30
  09:38:55 UTC. Notes use existing docs/OTA.md at the API-1
  path ceiling. Status taps remain opt-in; existing bars/profiles/cover safety,
  external sync/patch owners, bootstrap, assets and source pins stay intact.
  Both complete local interpreters, all 86 root suites on sealed bytes, 43
  catalogs, native actual-Beta-5/9/15/16 installers and exact source/path/
  history/artwork/secret/draft checks pass. Main/tag CI `41034381766`/
  `41034383748` are green. Anonymous public bytes, live application-TLS OTA
  from Beta 9/16 and recovery pass; preview selects Beta 17, stable is unchanged.
  All 71 prior releases/assets and previous tag refs remain unchanged. Exact
  ZIP digest/evidence is in MERGE_LOG; verification docs do not rebuild it.
  Physical device acceptance remains open; this is a prerelease, not stable.

- User requests the next high-priority Bookshelf-OS idea after the category-card
  start. The recovered review identifies small light/Wi-Fi/battery/time menus.
  Local work on `feature/quick-controls-20261030` starts clean at `44316d3e`.
  Shared anchored native dialogs reuse SimpleUI's slider/control widgets and
  actual PowerD units/readback, core network prompts/Android system settings,
  and existing statistics owners. Status taps are opt-in, with a searchable
  Navigation > Quick controls page and an addable quick action. Existing custom
  gestures, long presses, expanded-shelf return and preferences stay intact.
  Owner/navigation/rotation/suspend/close guards retire stale callbacks. No
  polling, cold network initialization, fake connectivity event, provider/DB work
  while painting, foreign code/assets, new installed path or upstream import.
  All owned labels/help support SV/EN. That implementation request alone did
  not authorize a version bump, push or release; the subsequent explicit
  request now publishes it in Beta 17. Public Beta 16 remains unchanged.
  Local implementation candidate `493775af` passes
  both complete interpreter gates, all 86 root suites on its sealed bytes,
  43 catalogs, exact path/source/artwork/secret audits and actual-Beta-15 native
  installer/restart/rollback checks. Twenty-two new cases also pass the complete
  minimum/current native ButtonDialog and component Topbar/Slider boundaries.
  MERGE_LOG records the evidence; physical fonts/touch/PowerD/Android/underlay
  acceptance stays open. Verification-only docs do not rebuild that local ZIP.

- User requests an upstream merge, including the standing audited push to main,
  NOT a new release. Maintenance branch starts at local `7083c8a1`, retaining the
  category-card work below. Reviewed imports: Bookshelf master
  `ee84a8fe1621171c00df91c41dee76b9ed07028c` (six issue-form commits, no runtime
  change); SimpleUI main `257c26d6685ced4fc2e895f98287b5f16f1d4f5e` (14 commits).
  New optional menu hiding, grid quick actions, six-column cover rows, page-turn
  statistics, Critter settings/panel/games/voices and guarded lazy boot listing.
  Keep Android Device Bluetooth API, exact cabinet/profile return even with a
  hidden tab, per-screen Critter choices and read-only patch compatibility.
  The migration-extraction refactor is deliberately deferred: the existing
  retry/copy-only/deferral implementation remains, with a guarded v14 copy.
  Thirteen exact Lua sources are lazily embedded in the existing generated
  registry, retaining canonical/legacy/preload identity and all API-1 installed
  paths. No bootstrap/limit change or asset/language removal. New settings labels
  have Swedish/English support; all catalogs remain. VERSION/public assets stay
  Beta 16. Full/sealed/native verification is recorded in MERGE_LOG below;
  physical Boox/Bigme UI, memory/latency and lifecycle acceptance remains open.

- User approves only the category-card settings start, following the Bookshelf-OS
  review. Local work on `feature/settings-start-cards-20261029` starts clean at
  `fe93bb39`. The same five task areas now have icons and static SV/EN summaries;
  Home remains explicitly SimpleUI. The existing search, category/scope/native
  controls and list API remain. Cards use the existing LibraryModal's grid,
  paging, key focus and close handling, with measured wrapping and a complete
  list fallback. A four-line read-only grid-gap accessor is the only component
  edit; no private upvalue patch, foreign plugin/code/artwork/font import, new
  installed path or settings migration. VERSION stays Beta 16 for local testing;
  never replace its public ZIP. That implementation request alone did not
  authorize push/publication; the October 30 merge now includes the local work.
  Candidate
  `8133c7ab` passes full Lua/LuaJIT, 43 catalogs, all 84 root suites on sealed
  bytes, exact source/path/artwork/secret audits and native actual-Beta-15 OTA/
  restart/rollback checks. Verification-only follow-up does not rebuild that ZIP.
  Exact evidence is in MERGE_LOG; native SV/EN touch/font/rotation acceptance on
  Boox/Bigme remains open.

- User explicitly approves push/publication of the accumulated performance and
  size/storage work. Beta 16 is public at exact candidate/tag `5c846730`,
  published 2026-10-28 19:09:05 UTC from
  `release/performance-beta16-20261028`. Main/tag checks
  `40750773286`/`40750773783`, both full interpreters, all 83 root suites on
  sealed bytes, translations/source/history/artwork/secret audits and native
  actual-Beta-5/9/14/15 upgrade/rollback tests pass. Anonymous public assets and
  live application-TLS OTA from Beta 9/15 pass; preview selects Beta 16 and stable
  remains unchanged. Bootstrap/API 1, all 2,000 paths, upstream pins and assets
  remain unchanged. All 70 previous public releases/assets and old tag refs
  are unchanged. Exact artifact/evidence is in MERGE_LOG. Optional profiles
  remain opt-in; no physical-device performance acceptance is implied.

- User approves the comparative UI/performance recommendations. Local work on
  `feature/performance-20261028` from `66b6f1c1` retains the unpublished PO/OTA
  storage work. Dashboard demands now follow each screen's visible cards and
  goal owner (native Recent rows keep their candidates). Optional shared
  Adaptive/Responsive profiles cap only retained cover references; existing
  behaviour is the unset/default and original budgets/animations/preload choices
  remain saved. Responsive skips wipes and speculative next-page/chip warming,
  never Android's safe visible-cover queue or mandatory reader-return prewarm.
  Bounded opt-in local timings/cache reports and a bilingual Home→library→chip→
  navigation/return guide are under System & maintenance. No external UI code,
  new installed path, source-pin/bootstrap/VERSION/artwork change, push or release.
  Candidate `5def9a06` passes full Lua/LuaJIT, all 83 root suites on sealed bytes,
  43 catalogs, exact package/source/path audits and native actual-Beta-14 OTA/
  restart/rollback/cleanup tests. Verification follow-up does not rebuild its ZIP.
  Full/sealed verification is recorded in MERGE_LOG; actual UI/device latency
  and native image-pressure acceptance remain open. The headless demand baseline
  is not a KOReader emulator benchmark or a measured RAM/speed improvement.

- User approves size-reduction step 3: safer update-slot storage cleanup, local
  only on `maintenance/update-storage-20261028` from `58b944b7`, retaining the
  preceding PO optimization. After confirmed startup, a quiet deferred worker
  collects at most one strictly older unused runtime. Current/previous packages
  must verify fully; factory, pending/equal/newer snapshots, modified/unknown
  files and links remain. Atomic quarantine plus manifest-last deletion permits
  interrupted cleanup to resume. The unsafe prepare-time bulk slot deletion is
  removed. Stable bootstrap/API/2,000-file limit, VERSION Beta 15, source pins,
  settings/progress/cache/artwork and external integrations remain unchanged.
  No push/release is authorized. Candidate `ff972412` passes complete interpreter,
  translation/package/source-byte and native older-installer/cleanup/resume gates.
  Fifteen collector and four new updater cases also pass on the sealed bytes;
  the largest in-memory candidate has all 1,999 API-1 inventory entries. Exact
  results are in MERGE_LOG. Follow-up test/verification notes do not rebuild the
  candidate ZIP; physical Boox/Bigme storage/startup acceptance remains open.

- User approves the first size-reduction proposal only: omit developer source
  locations (`#:` comments) from the 43 component PO catalogs during packaging,
  before generating manifest sizes/hashes. Tracked catalogs, all languages,
  headers/plurals/translation bytes and legal/translator notices remain intact.
  Work is local on `maintenance/slim-translations-20261028`; no component import,
  runtime path/bootstrap/limit change, language-pack split, cache/slot cleanup,
  version bump, push or publication is included. Beta 15 remains the public build.
  Tested package candidate `edc2c850` retains the same 1,999 inventory files plus
  manifest: 8,756,519 ZIP bytes and 25,554,846 expanded, versus public Beta 15's
  9,380,788 / 29,340,517 (6.65% / 12.90% smaller). Complete Lua/LuaJIT gates,
  all-language semantic/native-loader parity and package/source integrity pass;
  actual Beta 14 native archive/SHA upgrade/rollback/external-snapshot checks
  also pass on macOS. Exact verification is recorded in MERGE_LOG. Follow-up
  verification notes do not rebuild/republish the tested candidate ZIP.

- User approves dashboard colour implementation and immediate Beta 15
  publication, including the already-reviewed October 28 upstreams. Work starts
  clean at public main `eacfa7a7` on `feature/dashboard-colour-beta15-20261028`.
  Independent OrbitUI code/palette adds per-screen Off/Accents/Tinted cards;
  existing installs default Off. Native monochrome fallback, night palettes,
  explicit RGB card paint and bounded read-only borrowed-cover sampling preserve
  layout/headings/sources/row pages/actions and all external sync owners.
  No BookOrbit code/art/palette is imported. Inspiration: BookOrbit colour-board
  feature `267f53fc` (27 October), not a new embedded component or sync feature.
  New runtime logic lives in existing dashboard files at the API-1 path ceiling.
  Beta 15 is public at exact candidate/tag `ee35bf19`, published 2026-10-28
  15:08:36 UTC. Main/tag checks `40712349677`/`40712349197`, local complete
  Lua/LuaJIT/translation/sealed-byte/source/history/artwork/secret gates, actual
  older-install native OTA from Beta 5/9/14 and live public-byte OTA from Beta
  9/14 pass. Exact asset digest and device gaps are in the latest MERGE_LOG entry.

- User-requested upstream merge (no release) starts from clean `19cec4de` on
  `maintenance/upstream-20261028`. Exact unsquashed imports are Bookshelf
  `d07905ba932e09044827aadf480c188a5d324b96` (6.0.4, import `695035f1`) and
  SimpleUI `22d5a3d2dd7be4651e718eb49027d82f68b3ace7` (3.0.1 follow-up,
  import `048174b2`). Retain reader-menu return, profile/chip settings, Android
  cover safety, metadata fault containment and Unicode compatibility.
  Hazel's twelve new upstream PNGs stay byte-identical in Git and are losslessly
  embedded in the existing critter assets.lua for sealed packages: no old path,
  image, license or bootstrap is removed; installed API 1 limits stay unchanged.
  Native/data PNG rendering retains pixel scaling, alpha and bounded raster-cache
  ownership. Source/user files override the embedded fallback. Eleven targeted
  regressions cover this, legacy cover-poll callbacks, weak hook ownership,
  error-safe Android inverse state and deferred chooser callback restoration.
  Full verification and audited push are recorded in the latest MERGE_LOG entry.
  Candidate `eb4f4347` is pushed to main; GitHub checks `40684034831` (both
  interpreters, package/native OTA) and watch `40684034924` are green. Watch
  reports zero missing commits for both components. Local sealed-byte/source/
  artwork/history/secret audits and native older-installer rollback pass.
  VERSION remains Beta 14; no new tag/release/OTA is authorized by this request.

- User explicitly requested upstream merge, push and publication. Beta 14 is
  public at exact candidate/tag `575fdb7a`, published 2026-10-27 13:22:20 UTC.
  Work used `maintenance/upstream-beta14-20261027` from `7a3c519f`,
  retaining both preceding local reader-menu/editor features. SimpleUI's twelve
  incoming commits are imported unsquashed in `a94b7533`, through exact
  `e5cd6dcb31fa759b9831223d4719f61126367cff`; Bookshelf is unchanged at `c37580a1`.
  Adaptation `856e28ab` adds older-reader Unicode fallback and keeps recognized
  DB faults retryable without upstream's destructive auto-reset. Chinese catalogs
  retain local-only messages and valid single-form plurals with new translations.
  VERSION advances to `0.1.0-beta.14`. Release notes use existing `docs/OTA.md`
  and GitHub's body, adding no runtime path at the installed 2,000-file limit.
  Full tests/package/native OTA/CI/public-byte checks pass. Main/tag checks
  `40510806422`/`40510806468` are green; live public-byte upgrades from Beta 9/13
  and local upgrades from Beta 5/9/13 pass. Physical Boox/Bigme acceptance stays
  open. SimpleUI 3.0.1 appeared during verification: its ZIP runtime matches
  reviewed e5cd6dcb exactly (only extra .DS_Store files), so no ZIP-only import.
- User-approved library/chip editor cleanup, now published in Beta 14, was on
  `feature/library-chip-settings-20261027`, continuing `3d9dfad4` and retaining
  the native reader-menu return below. Each folder chip now contains its own
  Source/Folder control. Whole-library roots are collapsed under Library folders
  (advanced); changing them still remaps descendant sources after confirmation.
  Separate Order libraries/Order chips screens show a numbered live list,
  position and named before/after neighbours. Stable IDs, themes, Home references,
  existing roots and navigation bindings survive. An out-of-root chip choice
  requires explicit confirmation before adding that folder to library scope.
  SV/EN labels/help/search are included. Targeted logic/menu-host tests pass;
  physical Boox/Bigme layout,
  touch, long-path wrapping and persistence acceptance remains outstanding.
- User-approved native cabinet/file-browser return, now in Beta 14, was on
  `fix/native-reader-close-20261027`, based on public `33b13a08`. One post-build
  menu owner delegates to existing safe Bookshelf parking/close and matches
  saved profiles for Home/search opens. A bilingual opt-out retains the original
  action. Source shelf state and exact external prewarm identity are guarded.
  No new runtime path was required.
  Implementation candidate `1f2bb837` passes complete Lua/LuaJIT/translation
  gates, 23 targeted/native-menu regressions and sealed-byte/source/history
  audits. Physical Boox/Bigme acceptance remains open. Details below.
- The user explicitly requested push/publication of the bilingual settings
  redesign. Beta 13 is public at exact tag/candidate `f9d3b3a2`, fast-forwarded
  from public main `9f3f75a0` via `release/settings-beta13-20261027` after complete
  gates. Main/tag CI and native published-byte upgrade/rollback pass. No new
  upstream import. Beta 12 and older tags/assets remain immutable. The release
  note uses the final API 1 slot: 1,999 inventory files plus manifest, exactly
  2,000 installed. Do not add runtime paths or merely raise producer limits.
  Physical settings acceptance remains outstanding; this is a prerelease.
- The settings implementation was developed locally on
  `feature/settings-navigation-20261026`, then published in Beta 13.
  Five task areas plus bilingual settings search replace the crowded root;
  Home is explicitly Home/Hem (SimpleUI). Native preference callbacks, scopes,
  advanced controls and stored values remain in place. The earlier same-version
  development ZIP was never published as a replacement Beta 12.
- Product version: `0.1.0-beta.18` (public GitHub prerelease, published
  2026-10-30 at 16:31:24 UTC after explicit user request; verification is in
  `docs/MERGE_LOG.md`). Beta 17 and earlier assets remain immutable.
- Beta 12 starts from clean public main `70e5a1fd` on
  `fix/android-covers-beta12-20261026`. Android safe mode remains enabled;
  host-owned foreground local extraction replaces the blocked Bookshelf queue,
  with non-destructive single/bulk refresh and a guard on Bookshelf's forking
  full-metadata scanner. Home's separate Android background guard stays on.
  No upstream pins, bootstrap, settings, reading data or artwork change.
  Physical cover quality/responsiveness/native-engine acceptance remains open.
  Tag `v0.1.0-beta.12` pins candidate `ea8bbaf0`; main/tag CI and public native
  upgrade/rollback checks pass. Only verification docs follow, without rebuilding
  the ZIP. Inventory 1,998 plus manifest leaves one installed API 1 file slot.
- User explicitly approved the photo's updater UI/HTTP diagnostics fix and
  publication. Candidate `03106015` starts from clean public `25a2e7ab` on
  `fix/orbitui-updater-beta11-20261026`, then fast-forwards/pushes to main.
  Already-reviewed October 26 imports are included; no new upstream import/pin.
  Public Beta 10 and earlier tags/assets remain immutable.
- Public main baseline before Beta 10: `97b7948a` (Beta 9 verification).
- October 26 maintenance starts from public main `84597df5` on
  `maintenance/upstream-20261026` and is fast-forwarded/pushed to `main` at
  verified candidate `706b7341`. That request was merge/push only; the later
  explicit Beta 11 request publishes its runtime. Import commits
  are `c8c0f394` (Bookshelf) and `eeb5e012` (SimpleUI); adaptation/tests `dff46bce`.
  A later observed SimpleUI picker commit is imported separately in `65ca534e`,
  with category/instance/external-module tests in `0acdd843`.
  Complete local Lua/LuaJIT, translation, sealed-package and native OTA gates
  pass; exact verification results are recorded in `docs/MERGE_LOG.md`.
- Release tag: `v0.1.0-beta.18` at `7c0f7057`; previous tags
  `v0.1.0-beta.17` at `ab2e0bd7`,
  `v0.1.0-beta.16` at `5c846730`,
  `v0.1.0-beta.15` at `ee35bf19`,
  `v0.1.0-beta.14` at `575fdb7a`,
  `v0.1.0-beta.13` at `f9d3b3a2`,
  `v0.1.0-beta.12` at `ea8bbaf0`,
  `v0.1.0-beta.11` at `03106015`,
  `v0.1.0-beta.10` at `0a2ea22b`, `v0.1.0-beta.9` at `a4bb9acb` and all
  earlier tags/assets are unchanged.
- Public branch: `main`; the next October 30 publication request produces
  Beta 18 with the reviewed status-routing/live-opt-in/native-dialog fixes.
  The earlier separate October 30 publication request produces
  Beta 17 with quick controls, category cards and the already-reviewed imports.
  The preceding merge includes the local category cards and reviewed upstream
  follow-ups under the standing push-only authorization.
  The October 28 push/publication request produces
  Beta 16 with the reviewed local performance, translation-size and safe obsolete
  update-code cleanup work. The earlier colour/publication request produces
  Beta 15, including the preceding reviewed merge/push-only maintenance.
  The preceding merge/push/release request produced Beta 14. The settings request produced
  Beta 13. The preceding cover
  request produced Beta 12. The earlier updater request
  produced Beta 11. The previous
  explicit publication request produced Beta 10: Bookshelf import `0db81b46`,
  integration tests/pin `66fe1b4a` and release candidate `0a2ea22b`.
  Retained local branches include `release/settings-beta13-20261027`,
  `feature/settings-navigation-20261026`, `fix/android-covers-beta12-20261026`,
  `fix/orbitui-updater-beta11-20261026`,
  `maintenance/upstream-20261026`,
  `maintenance/upstream-late-20261025`, the earlier maintenance branch and
  `fix/bookshelf-navigation-20261025`, `fix/home-blitbuffer-20261025` and
  `fix/home-first-run-20261025`.
  Future user-requested verified merges include an audited push to `origin/main`;
  a new release still requires a separate explicit request.
- Embedded Bookshelf Git in main: `ee84a8fe1621171c00df91c41dee76b9ed07028c`
  (issue-form follow-ups only). Public Beta 15/16 retains
  `d07905ba932e09044827aadf480c188a5d324b96` (6.0.4). Public Beta 14 retains
  `c37580a1ca5040d2423e45b9bdd429776117f3c1` (6.0.3).
  Public Beta 10 keeps `5f726c25` / merge `0db81b46` unchanged.
  Prior 6.0.0 integration `fc1103a3` / `48438837` is retained in ancestry.
- Embedded SimpleUI Git in main: `257c26d6685ced4fc2e895f98287b5f16f1d4f5e`
  (3.0.1 follow-ups). Public Beta 15/16 retains
  `22d5a3d2dd7be4651e718eb49027d82f68b3ace7`. Beta 14 keeps
  `e5cd6dcb31fa759b9831223d4719f61126367cff` (3.0.1 runtime), twelve commits
  after `b1580f90b2e17cf03a66c744c323a1df66d77100` retained in Beta 13.
  Public Beta 10 keeps `40b301f0` / merge `b9dfc849` unchanged.
- Prior broad adaptation candidate: `3a33fee6`; its final headless gates passed.
  A read-only local collector at 2026-10-25 22:43 UTC found eight Bookshelf
  commits and no SimpleUI changes. Issue #1's older 17:48 result listed only
  five commits; the exact newer Git tip was inspected before importing it.
  The 22:53 local check and 22:56 public monitoring run both report zero missing
  commits for the reviewed pins. Beta 10 verification is recorded below.
- The real SimpleUI Git history now accounts for the approved 3.0 ZIP snapshot
  `3cb36431`. Content reconciliation preserved OrbitUI's changes; the active
  `release_snapshot` field is retired. Historical digest/asset provenance stays
  in `docs/MERGE_LOG.md` and Git, not relabelled as an upstream commit.
- GitHub issue #1 is monitoring-only and describes public main. Run
  `40242459666` passed at the Beta 10 candidate; it never authorizes an import.
- Open pull requests: none. The only open issue is the monitoring-only upstream
  dashboard.
- The repository was clean, had no stash and had no unreachable commits during
  recovery inspection. There are deliberately retained maintenance/history
  branches, including `design/orbitui-series-boxes` at `1ae66bd0` for the old
  OrbitUI box renderer.

This is a point-in-time snapshot. Recheck Git, GitHub and the upstream dashboard
before treating volatile status as current.

## Product definition

OrbitUI is one KOReader plugin that embeds and coordinates the published
SimpleUI and Bookshelf projects. SimpleUI supplies the customizable Home and
statistics surfaces; Bookshelf supplies the visual library, shelves, covers,
series, themes and ornaments. OrbitUI connects them through one plugin entry
point, one settings hub, shared navigation/search/detail surfaces and one
whole-package update channel.

It is not a replacement reading engine, a BookOrbit client, a new sync engine
or an official release from either upstream author. Local books and KOReader
data work without online services. BookOrbit, Hardcover, MyAnimeList and Patch
Manager integrations remain optional and externally owned.

Standalone SimpleUI and Bookshelf must be disabled while OrbitUI is active, but
their files and settings must be retained for rollback. OrbitUI never silently
activates itself beside them.

## Repository architecture

| Area | Responsibility |
| --- | --- |
| `main.lua`, `_meta.lua`, `orbitui_bootstrap.lua` | Stable plugin entry and OTA bootstrap. Treat bootstrap compatibility as a release boundary. |
| `core/` | Host-owned orchestration: runtime, guard, libraries, dashboard, search, setup, OTA, add-ons and shared policies. |
| `adapters/` | Narrow integration seams around embedded component behavior. Prefer adapters over broad component edits. |
| `components/simpleui/` | Unsquashed embedded SimpleUI history and source. |
| `components/bookshelf/` | Unsquashed embedded Bookshelf history and source. |
| `assets/`, `addons/` | Runtime assets, licenses and the independent ornament catalogue metadata. |
| `tests/` | OrbitUI integration/regression tests. Component suites remain under each component. |
| `scripts/` | Module-map, test, package, release, asset-build and upstream-watch tooling. |
| `docs/` | User guides, contracts, merge history, device acceptance and release evidence. |

Runtime code must remain Lua 5.1/LuaJIT compatible. The generated module map
provides canonical module names and legacy aliases while preserving
`package.preload` priority. Regenerate it only when runtime source paths change.

## Current user-facing state

### Shared Home and library

- In Beta 14, the reader menu's cabinet button uses the
  existing fast Bookshelf return after every native menu build/rebuild. Exact
  source shelves keep profile/chip/page; external books use saved root matching.
  Only exact ready reader/file/profile prewarms can park; cold/rotated targets
  use safe normal close first. Missing/disabled sources fall back to the original
  action. A searchable SV/EN checkbox under Navigation > Opening books & returning
  opts out without changing other gestures, close policies or data. No new sync
  owner. Stale taps are inert; teardown restores only its own menu callback.
- Beta 11 replaces the embedded Bookshelf update page with shared
  real OrbitUI version/preview/daily/recovery controls. Bounded safe HTTP
  status/rate-limit diagnostics survive Trapper; confirmed limits suspend checks
  for their retry/reset interval in the running session. Generic 403s are not
  mislabelled. The photo does not prove its device/network cause. Settings,
  component installers, TLS, bootstrap/API and activation safety remain intact.
- October 26 maintenance (included in Beta 11, not Beta 10): Bookshelf 6.0.3 fixes
  image-screensaver wake repaint and fullscreen status-line taps, and adds an
  independent On the shelf module toggle that retains saved modules. SimpleUI
  adds optional free widths/stacking, Fast Book Closing (off by default), library
  wallpaper opacity, later-page statistics refresh and Flow night-mode colours.
  The categorized Add Module picker retains uncategorized external OrbitUI
  modules under Other and follows categories for instanced modules.
  Existing layouts/margins, old wallpaper flags/APIs, profiles/navigation and
  external owners are retained; physical-device acceptance remains outstanding.
  Fast Book Closing exposes an existing internally-disabled Home soft-park as a
  saved menu option; it is not a new replacement for Bookshelf's fast return.
- The user confirms both Home and the Beta 9 Bookshelf navigation fix work on
  the affected Boox. Wider lifecycle/rotation/device checks remain outstanding.
  After Beta 12 the user confirms all covers now display correctly on that Boox.
  This does not close unrelated native-crash, memory or lifecycle acceptance.
  Bookshelf 6.0.2 fixes stale batch rows that prevented explicit Refresh metadata
  from re-extracting a deleted metadata/cover row; it is not an automatic rescan.
  It also corrects colour-cover shadows during clipped repaints, narrows status
  refreshes, suppresses covered-window clock refreshes and improves module keys.
  Home worked on the affected Go Color 7 with Beta 8.
  A subsequent navbar report matches a missing legacy `prose` profile: its
  handler silently returned false. Published Beta 9 adds a
  first-class default/removable Bookshelf action, hold-to-configure and shared
  navigation settings, optional saved-profile target, direct per-profile bar
  buttons and explicit missing-profile repair. Saved bars/aliases/data remain
  intact. Existing saved bars need explicit enablement in Bookshelf navigation;
  these changes do not retrofit Beta 8. See `docs/SHARED_UI.md`.
- Beta 8 explicitly imports `ffi/blitbuffer` in the shared engine. The photo's
  exact line-288 load error reproduces before the import and passes afterward
  under Lua/LuaJIT. New whole-engine cold-load tests close the gap left by the
  extracted-open first-run tests. The user's affected-device Home check now passes;
  wider rendering/lifecycle/device acceptance remains open.
- Beta 7 imports Home's missing logger and reports guarded
  Home load/open failures, preserving the initial cause across LuaJIT retries.
  Shared identity/callbacks and settings/data stay intact. Android fresh-install
  failure is reported on a Go Color 7 with KOReader 2026.07.2; Cover browser is
  now enabled, but the native mutex abort in the logs is not tied to a Lua trace
  and is not proven causally resolved. The later Home check passes; wider native
  crash/lifecycle acceptance remains open.
- The SimpleUI 3.0 integration adds detailed statistics/charts, live Bento
  preview, accent/secondary colours, optional bundled fonts and Tiny Critter.
  Existing percentage/stacked layouts retain their geometry until an explicit
  new-editor width/movement change; per-module gaps remain independent.
  UI fonts remain explicit choices and the embedded navbar keeps its 96dp base.
- The reviewed Bookshelf 6.0 import adds grid-editable micro-modules, Shelf/Ornament
  modules among books, pinned ornaments, Highlights and persistent derived caches.
  Hosted migrations retain old module/deck keys; no settings/book data moves.
- Beta 13 groups settings into Home (SimpleUI), Bookshelf, Navigation &
  interface, Integrations and System & maintenance, with a separate settings
  search. Book search stays under Bookshelf. Clear scope headers distinguish
  global Bookshelf controls, library/shelf overrides, shared themes and SimpleUI
  screen contexts. Native advanced controls remain accessible; no migration.
  Beta 12 and earlier retain the previous hub; update/restart to use the new one.
- Library sections are user-defined; no personal fiction/manga folder layout is
  hard-coded as the live source of truth.
- The Beta 14 profile editor separates chip sources from advanced library-wide
  roots, and library order from chip-bar order. Reordering stays on the numbered
  list with immediate position feedback. Beta 13 retains the earlier editor.
- Home can pin live shelf rows/carousels by profile/chip reference. It never
  copies membership or falls back to unrelated recent books when a source is
  missing.
- Shared search supports the entire library, configured sections and supported
  current local shelves. Remote OPDS search remains separate.
- Home and search reuse the real Bookshelf detail panel without constructing a
  second hidden shelf or event owner.

### Optional Reading dashboard

- The dashboard is an additive, configurable Home/Custom Screen module, not a
  migration of existing layouts.
- Cards, statistics, headings, goals and both book-row sources are independently
  configurable. Each row has independent arrows and swipe paging.
- Sources may be local TBR, New Books, recent history, collections, saved
  shelves or cached BookOrbit Want to Read.
- Hidden/unavailable sources fail closed. Rendering does not start network
  fetches or create a synchronization writer.

### Shelves and series

- Appearance presets are Shelf settings, Classic OrbitUI and Minimal bookshelf.
  They retain the underlying per-shelf preferences for reversible switching.
- Classic faces all physical-shelf books forward and compacts eligible series,
  single-volume series and configured Oneshots/grouped folders.
- Bookshelf 5.5's native slipcase owns series preparation/rendering. OrbitUI adds
  profile isolation, aspect-preserving covers, natural member widths, read/total
  counts, `+N`, binding choices, optional titles and cached MAL ratings.
- Hardcover, Paperback and Kanzenban are generated display styles, not changes
  to metadata or reconstructed physical artwork.
- The superseded OrbitUI-specific box renderer is retained only on the local
  `design/orbitui-series-boxes` branch, not as a second runtime renderer.

### Ornaments and icons

- Fresh installs seed no ornament artwork. Optional packs are installed and
  updated through the separate OrbitUI add-on channel.
- Existing artwork, edits, deletions, enablement, placement and theme choices
  survive updates. Add-on updates are data-only and cannot carry executable
  actions.
- Matching placement is the default; per-pack random placement is optional.
  Matching author/series pieces stay adjacent to their books. Ordinary pieces
  are limited to one per row; several matching author busts may share a row.
- Material, Solar and Tabler are per-icon choices. Existing icon identities and
  explicit Material weights survive OTA slot changes.

### Installation and updates

- Required KOReader: v2025.08 or newer; v2026.03 or newer is recommended by
  Bookshelf. KOReader's Cover browser plugin stays enabled.
- OrbitUI OTA stages and verifies the whole plugin in an inactive immutable
  version slot, activates on restart and retains the previous/factory code for
  rollback. It verifies TLS, byte limits, hashes, paths, inventory and Lua.
- Beta 2 and later can verify and snapshot a strictly newer external release-ZIP
  installation after healthy startup. Adoption requires an additional restart.
- Component self-updaters remain blocked. App-store listings do not replace the
  recommended OrbitUI updater.

## Non-negotiable integration contracts

- **C01 — one plugin/event path:** one host, early aliases, exactly-once event
  delivery and fail-closed conflict detection.
- **C02 — navigation ownership:** SimpleUI owns Home; Bookshelf owns configured
  libraries. Stale callbacks must never reopen or cover a newer destination.
- **C03 — book opening:** every route uses KOReader's real ReaderUI lifecycle and
  real path so automatic reading profiles and external hooks still work.
- **C04 — bounded work/correct caches:** no unbounded pollers, network work while
  painting or permanent-zero caches after temporary failures.
- **C05 — explicit sync owners:** BookOrbit remains the intended Hardcover
  progress writer in this setup. OrbitUI must not create duplicate read/status
  writes. Bookshelf owns linking and cached enrichment.
- **C06 — external compatibility:** preserve canonical/legacy module identities,
  userpatch preload priority and MAL/Patch Manager/undo-opening seams. Never
  globally replace `require`, `gettext` or `DataStorage`.
- **C07 — presentation/preferences:** preserve independent profiles, Home/Bento
  layouts and saved choices; new settings are opt-in or copy-only migrations.
- **C08 — assets/data/recovery:** preserve paths, settings, links, artwork,
  caches and rollback data. The first-run snapshot is deliberately limited and
  is not a device backup.
- **C09 — reviewed imports/releases:** monitoring never merges or publishes.
  Upstream import, adaptation, version/tag and publication are separate steps.
- **C10 — shared surfaces:** detail panels, search, settings, Home shelves and
  dashboard reuse native owners and fail closed on missing sources.
- **C11 — bound ornaments:** add-ons preserve custom data and exact matching;
  targeted pieces never drift into unrelated random/bare-shelf placement.

Change a contract only with an explicit reason and user approval, matching
tests/device checklist updates, and a `MERGE_LOG.md` entry.

## Data and ownership boundaries

- Never move book files or erase reading progress, sidecars, links, credentials,
  settings, caches, artwork or predecessor plugin folders during migration.
- Flat legacy Bookshelf settings win when both flat and native layouts exist;
  this protects established OrbitUI installations. No storage move/import is
  authorized.
- Setup-guide drafts write nothing until confirmation. Existing installations
  are not automatically reconfigured.
- Reading status changes delegate to the existing native action. OrbitUI may
  invalidate UI caches but does not become another Hardcover writer.
- MAL series ratings are cached-only, provider-owned and optional. Do not fetch,
  read private plugin settings or invent links while rendering.
- Rollback changes code, not reading data or settings. Never restore stale
  progress files merely to undo a UI release.

## Upstream and release workflow

- Upstream monitoring runs four times daily and updates GitHub issue #1. It may
  fetch and report only; it has no authority to merge, bump, tag or release.
- Reviewed subtree imports use an exact full SHA on a dedicated maintenance
  branch and retain unsquashed history. Keep the import commit separate from
  OrbitUI adaptations and release documentation where feasible.
- October 23's official 3.0 ZIP exception was reconciled with real upstream Git
  on October 25. Retain its historical identity; future ZIP-only imports still
  require their own explicit approval and source comparison.
- Before a merge, read `docs/UPSTREAM.md`, all C01-C11 contracts and the latest
  `docs/MERGE_LOG.md` entries. Update only the appropriate `upstream_commit` in
  `sources.json`; preserve original fork provenance fields.
- Publication requires a separate explicit user request. A green CI/package is
  not publication approval and is not physical-device acceptance.
- User-requested merges include pushing the verified result to `origin/main`
  after history/artwork/secret audits. Summarize changes in Swedish by likely
  practical impact on Robin's setup, distinguishing expected/measured benefits,
  retained custom behavior, device gaps and local/published status.
- Never replace the bytes of an existing published tag. Fixes receive a new
  version/tag.

### Artwork release hold

The superseded AI-assisted Seitz/Mann PNG with SHA-256
`fc6d71bd1538bee9a569a9838b7a00c5374469f0cc8efad3c70674a20c286bb9`
is not cleared. Do not push that bitmap, publish an OTA containing it or push Git
history that contains it. The current non-generative Ahrens-based cutout is a
different documented asset. Replacing the working-tree file does not sanitize an
ancestor; audit outgoing history before every push/publication.

## Verification status

Beta 18 candidate/tag `7c0f7057` passes both complete local interpreters and
main/tag CI `41089949928`/`41089950111`: 122 Python/four unchanged optional
source-pixel skips, 86 root Lua files, 487 Bookshelf suites/zero failures/three
normal SQLite exclusions, 13 SimpleUI files, map 396, syntax 1,082 and 43 catalogs.
All root suites pass on sealed bytes under both interpreters, including 28
quick-control cases with complete minimum/current native input/dialog owners.
Native actual-Beta-5/9/17 upgrade/recovery and live anonymous application-TLS OTA
from Beta 9/17 pass. Exact draft/public bytes and source/history/artwork/secret
checks pass; all 72 prior releases/assets/tag refs remain unchanged. SHA-256
`9205d218043989cbbd89aac90a6b6df8305f3f587c05efa2602f28cdb616ce27`;
8,967,453 ZIP bytes, 26,326,308 expanded, same 2,000 installed paths/bootstrap.
Preview selects Beta 18; stable is unchanged. Evidence:
`test-results/beta18-20261030/`. Verification docs do not rebuild this ZIP.
Physical Boox/Bigme quick-control and lifecycle acceptance remains open.

Beta 17 candidate/tag `ab2e0bd7` passes both complete local interpreters and
main/tag CI `41034381766`/`41034383748`: 122 Python tests/four unchanged optional
source-pixel skips, 86 root Lua files, 487 Bookshelf suites/zero failures/three
normal SQLite exclusions, 13 SimpleUI files, map 396, syntax 1,082 and all 43
catalogs. All root suites also pass against sealed bytes under both interpreters.
Actual older installers from Beta 5/9/15/16 pass native archive/hash/activation/
restart/rollback/recovery/external snapshot and interrupted cleanup checks.
Draft and anonymously downloaded public assets match the clean candidate;
live real application TLS passes public discovery/download and all native phases
from Beta 9/16. Preview selects Beta 17, stable is unchanged; all 71 previous
public releases/assets and old tags are immutable. SHA-256
`8767d8ed569529f8b8bba779140f5e8df894b9169a36d83b7c116caa80cbc4ae`;
8,959,367 ZIP bytes, 26,300,406 expanded, same 2,000 installed paths and bootstrap.
Evidence: `test-results/beta17-20261030/` and MERGE_LOG. Follow-up verification
docs do not rebuild the tagged ZIP. Physical Boox/Bigme acceptance remains open.

October 30 final local source/package `3b47b194` passes both complete sequential
Lua/LuaJIT gates (122 Python/four unchanged skips, 85 root files, 487 Bookshelf/
zero failures/three normal SQLite exclusions and 13 SimpleUI files), all 43
catalogs and every root suite on sealed bytes under both interpreters. Map 396,
syntax 1,081. Exact source/path/manifest and outgoing history/artwork/secret
audits plus actual-Beta-15 native installer/restart/rollback/cleanup gates pass.
Same 2,000 installed paths, unchanged bootstrap/assets; ZIP 8,943,741 bytes,
SHA-256 `2ca3ec818d82e3a14795902e172a8586d84e7e4277087be8aecfe852baf4c0ca`.
This is not a new public release. Follow-up docs do not rebuild this local ZIP;
physical device acceptance remains open. See the October 30 MERGE_LOG evidence.

Beta 16 candidate/tag `5c846730` passes both complete local interpreters and
main/tag CI `40750773286`/`40750773783`: 122 Python tests/four unchanged optional
source-pixel skips, 83 root Lua files, 487 Bookshelf suites/zero failures/three
normal SQLite exclusions and 13 SimpleUI files. Map 383, syntax 1,066, catalogs
43/zero failures. All 83 root suites also pass against sealed bytes under both
interpreters. Native actual-Beta-5/9/14/15 upgrade/restart/rollback/external
snapshot and interrupted obsolete-code cleanup/resume pass. Live anonymous
application-TLS public-byte upgrade from Beta 9/15 and channel selection pass.
SHA-256 `a9a1b6f6a36376b11091f195f2a0230208898909b483914c4cddd0e80d4aff98`;
8,781,021 ZIP bytes, 25,632,378 expanded, same 2,000 installed paths. All prior
public tags/assets remain unchanged. Evidence: `test-results/beta16-20261028/`.
Verification-only follow-up docs do not rebuild the tagged/public ZIP. Physical
Boox/Bigme performance, UI, image pressure, storage and update-dialog acceptance
remain outstanding; automated checks do not prove a device speed/RAM gain.

Beta 14 tag/candidate `575fdb7a` passes complete sequential Lua/LuaJIT suites:
119 Python/four unchanged source-cache skips, all 78 root Lua files, 483
Bookshelf suites/zero failures/three normal SQLite exclusions and 13 SimpleUI
files. Map 383, syntax 1,056, translations 43/zero failures. Ten new upstream
cases and retained editor/menu/Home/cover cases pass on sealed bytes under both
interpreters. Native system utf8proc supplement and eight-module global lint
pass. Main/tag CI `40510806422`/`40510806468` and upstream watch are green.

Draft and anonymous public assets match the clean candidate/manifest exactly:
SHA-256 `01010c252a9abd5842cd0e7e3c539cb9e609fec07358a1196039911f80c30bc0`,
9,363,469 bytes, 29,300,429 expanded, 1,999 inventory plus manifest/all 2,000
API 1 slots. No runtime paths added/removed; bootstrap/assets/fonts/map unchanged.
All 69 outgoing blobs exclude held artwork; Gitleaks scans 14 non-merge commits
without leaks. Local native OTA from actual Beta 5/9/13 and public live-TLS
upgrade/restart/rollback/external snapshot from Beta 9/13 pass. Beta 13 remains
immutable. Evidence: `test-results/beta14-20261027/`. Follow-up docs do not rebuild
or replace public bytes. No physical reader touched; device acceptance stays open.

Earlier LOCAL library/chip editor source `5810c567` passes complete sequential
Lua/LuaJIT gates: 119 Python/four unchanged source-cache skips, all 77 root Lua
files, 483 Bookshelf suites/zero failures/three normal SQLite exclusions and 13
SimpleUI files. Module map 383; syntax 1,055; translations 43/zero failures.
All 18 library settings cases (including the real MenuHost), 19 settings cases,
12 navigation cases, prior 23 native-reader-menu cases and retained host/Home/
panel/Android-cover regressions pass on the sealed bytes under both interpreters.
No new skip/failure exception. Evidence:
`test-results/library-chip-settings-20261027/`.

Earlier development-only ZIP SHA-256
`e41141216342ed6d9710a9636c1313630e0c06d2cc997a2fdffe454c6b4250ee`,
9,329,310 bytes, expanded 29,229,702. Every manifest file matches clean committed
source `5810c567`; exactly the same 1,999 paths plus manifest/all 2,000 API 1
slots. No new component/runtime paths, bootstrap/API/VERSION/pins/assets/font/map
changes. All 25 outgoing blobs exclude held artwork; all three local commits
pass Gitleaks. Main/origin remain `33b13a08`, tag/public Beta 13 ZIP unchanged.
The previous reader-menu development ZIP is retained in its evidence directory.
Follow-up verification docs do not rebuild the ZIP. No push, tag, release, OTA,
CI or installed reader change; physical bilingual/Boox/Bigme checks remain open.

Earlier local native-reader-menu candidate `1f2bb837` was verified locally;
its behavior is now included in Beta 14.
Complete final sequential Lua/LuaJIT suites pass 119 Python/four unchanged skips,
77 root Lua files, 483 Bookshelf suites/zero failures/three normal SQLite skips
and 13 SimpleUI files. Module map 383; syntax 1,055; translations 43/zero failures.
The 23 targeted cases pass with complete official ReaderMenu references at
`f0db5fcb3c3e35949a99c8bff3dc36837a3f0fd6` and `v2025.08`, both interpreters,
also on sealed bytes. The first actual-menu case fails against public `33b13a08`
before the change. Existing Home/settings/navigation/panel/Android-cover/host
sealed regressions pass. No new skip/failure exception or sync owner.

Development-only ZIP SHA-256
`f3aa81c4bf2a36a2e6dcf649318daa6f621edff4411ac0b1a63aadd15208ecee`,
9,322,410 bytes; 29,207,174 expanded. Exact clean source/manifest audit, same
1,999 files plus manifest/all 2,000 installed slots, no runtime paths added or
removed. Entry/bootstrap/API 1/VERSION/pins/assets/fonts/module map unchanged.
All 12 outgoing blobs exclude held artwork; source commit passes Gitleaks.
Evidence: `test-results/native-reader-close-20261027/`. Main/origin remain
`33b13a08`, tag/Beta 13 public ZIP unchanged. Do not publish/install this
same-version validation ZIP as a replacement Beta 13. Follow-up docs do not
rebuild it. Physical menu/reader/profile/rotation/sleep/BookOrbit checks remain
open. No push/tag/release/OTA/CI or installed reader is changed in this task.

Beta 13 candidate/tag `f9d3b3a2` passes full sequential Lua/LuaJIT gates: 119
Python/four unchanged skips, all 76 root Lua files, 483 Bookshelf suites/zero
failures/three normal SQLite exclusions and 13 SimpleUI files. Module map 383,
syntax 1,054, translations 43/zero failures and search vocabulary 332. Nineteen
settings cases and retained Home/library/navigation/cover/updater regressions
pass on sealed bytes under both interpreters. Six changed host modules pass
undeclared-global lint. Five outgoing commits pass Gitleaks; all 30 outgoing
blobs exclude held artwork. No new test exclusion.

Every ZIP file equals committed source/manifest hash/size. Only the release
note adds a runtime path; no path is removed. Inventory 1,999 plus manifest uses
all 2,000 API 1 slots. Bootstrap/entry/assets/fonts/pins/module map unchanged.
ZIP SHA-256 `65ce2609b4bf914c298abb2f812c98d0e3ae84fad0863bf7786e1d54ac4a6c63`,
9,314,791 bytes, expanded 29,182,623, 2,065 entries. Draft and anonymous public
assets/API digest match exactly; Beta 12 metadata/assets are unchanged. Native
actual Beta 5/9/12 installers pass Linux local activation/restart/recovery/code
rollback/external adoption. Anonymous published-byte TLS discovery/download and
all native phases pass from Beta 9 and Beta 12. Main/tag CI
`40458588212`/`40458587953` pass at the exact candidate. Existing runner/Node
migration annotations are warnings. Evidence: `test-results/beta13-20261027/`.
Verification docs do not rebuild/replace the published ZIP. These are not
physical-reader tests; SV/EN layout/touch/Back/themes/reader/sleep/rotation remain
open. Beta 12's user-confirmed Boox covers are retained, not new device proof.

Historical pre-release settings candidate `ffd3ef34` (implementation `d905e04c`
plus the native Menu:init ordering fix) was packaged/verified locally. Complete
sequential Lua/LuaJIT gates pass 119 Python/four existing skips, 483 Bookshelf
suites/zero failures/three normal SQLite exclusions and 13 SimpleUI files. All
76 root Lua files are rerun against final code under both interpreters. Nineteen
new settings cases, plus retained settings/library/Home/navigation/cover/update
regressions, pass on sealed bytes. The real native MenuHost/region supplements
pass again under both interpreters. Module map 383; syntax 1,054; translations
43/zero failures; static vocabulary 332. No new exclusion is introduced.

Development-only ZIP SHA-256
`2fc49a0db048e32b34faf2fd568987e12a96df7309148aacc86428d062c5c4f7`,
9,309,755 bytes, exact candidate source/manifest inventory, 1,998 files plus
manifest and one API 1 slot left. No runtime paths added/removed. Stable entry/
bootstrap, version/pins/assets/fonts/module map and public main/tag/Beta 12 ZIP
remain unchanged. Twenty-three outgoing blobs exclude held artwork; two source
commits pass Gitleaks. Evidence: `test-results/settings-navigation-20261026/`.
Follow-up verification docs do not rebuild/replace those validation bytes. This
same-version development ZIP must not be published/used as replacement Beta 12.
Physical new-menu SV/EN/touch/Back/reader acceptance remains open.

Beta 11 candidate/tag `03106015` passes both complete Lua/LuaJIT suites: 117
Python tests/four existing source-cache skips, 74 root Lua files, 483 Bookshelf
suites/zero failures/three normal SQLite exclusions and 13 original SimpleUI
files. Syntax 1,051; module map 383; translations 43/zero failures. The HTTP,
Trapper/update, real-menu/root-dialog and retained Home/navigation/Bento cases
also pass on sealed bytes under both interpreters. Undeclared-global lint passes
the three changed host modules. Prior October 26 actual-SQLite supplements
remain applicable; no database code changes in this fix.

Every ZIP file matches committed source/manifest hash/size: 1,996 inventoried
files plus manifest, three API 1 slots, 2,062 entries, 29,058,002 expanded bytes.
All 15 outgoing blobs exclude held artwork; one-commit Gitleaks is clean.
Bootstrap/assets/fonts/pins unchanged since reviewed main. Draft/anonymous
public assets match exactly: ZIP SHA-256
`b9a78e82ffdceaf3b2d0c77da1ec4e7c60319df4eaab60a81dfacd0b68b9b391`,
9,274,291 bytes. Actual Beta 5/9/10 native installers pass local Linux OTA,
recovery/restart/rollback/external adoption; macOS Beta 9 also passes. Anonymous
published-byte TLS discovery/download and every native phase pass from Beta 9
and Beta 10. Main/tag CI `40379763363`/`40379764285` pass at the exact candidate;
Node/runner migration annotations are warnings. Evidence:
`test-results/beta11-20261026/`. Temporary installs are not reader tests. The
photo's device/network cause and physical UI acceptance remain open. Follow-up
docs do not rebuild/replace immutable assets.

October 26 unreleased main candidate `706b7341` passes both complete sequential
Lua/LuaJIT gates: 117 Python tests/four existing external-source skips, all 74
root Lua files, 483 Bookshelf suites/zero failures/three normal SQLite exclusions
and all 13 original SimpleUI test files. Module map remains 383; syntax checks
1,051 Lua files; all 43 translation catalogues pass. Fresh actual-SQLite checks
pass 7 deck, 16 facts, 100 OPDS cases and the SimpleUI daily/year/pages ledger.
Sealed-byte Home/navigation/book-helper cases, eight new merge cases and all 15
real Bento geometry cases pass under both interpreters. The 16-case native
underlay suite includes owner-safe screen-hook teardown and wake handling.

The validation-only ZIP matches clean candidate source and manifest exactly:
1,995 inventoried files plus manifest, no installed paths added/removed, four
API 1 slots left, 29,032,084 expanded bytes. Its SHA-256 is
`119cd716929a3797c0d8cc13ff13ccd74323994ed2a37a433481fede8b80a6e4`
(9,265,056 bytes). All 194 outgoing blobs exclude held artwork; Gitleaks finds
no secrets across 13 non-merge commits. Host/bootstrap/fonts/artwork/VERSION
are unchanged. The actual public Beta 9 native installer passes all local macOS
OTA, rejection/recovery, restart, snapshot and persistent rollback phases against
these candidate bytes in temporary installations. This is not public discovery
of a new release or a physical reader test. Evidence:
`test-results/upstream-20261026/`. Public Beta 10 tag/assets remain immutable;
the same-version validation ZIP is never uploaded as a replacement.
Main CI run `40374393514` passes both Lua/LuaJIT integration, translation,
package and native OTA jobs at the exact candidate. Node/runner migration
annotations are warnings. Follow-up documentation leaves tested runtime and
validation ZIP bytes unchanged.

A fresh local verification on the versioned Beta 10 tree on 2026-10-25 passed:

- `sh scripts/test.sh`
- `LUA=luajit sh scripts/test.sh`
- `sh scripts/check-translations.sh`
- 117 Python tests per run, with four documented external source-cache audits
  skipped
- all 73 OrbitUI Lua test files under both interpreters, including four new
  whole-module book-helper/opener cases, 12 navigation, three whole-engine
  cold-load and 14 first-run/error/retry cases. These four suites also pass
  against the sealed ZIP under both interpreters
- module map: 383 paths verified
- LuaJIT syntax: 1,049 Lua files verified
- Bookshelf: 482 suites, 0 failed, 3 documented KOReader-SQLite skips per run;
  fresh supplemental real SQLite runs pass 7 deck, 16 facts, 100 OPDS cases
  and the SimpleUI ledger daily/year/page/invalidation checks
- all 13 original SimpleUI test files exercised by `scripts/test.sh`
- translations: 43 passed, 0 baseline failures and 0 new failures
- clean-commit release package: 1,995 inventoried files plus its manifest, all
  sizes/hashes verified; bootstrap/API 1 and existing artwork/fonts unchanged.
  All 42 outgoing blobs were checked for held artwork, and Gitleaks found no
  secrets in ten scanned non-merge commits. No Beta 9 path is removed; only
  the release note is added. Host/SimpleUI runtime is unchanged; Bookshelf
  equals the reviewed subtree import and only its upstream pin advances.
- Luacheck's global checks pass on all eleven changed runtime Lua modules after
  allowing G_reader_settings/G_defaults. Optional broader style checks still
  report unused/shadowing warnings; they are not a clean style-lint claim.
- actual public Beta 5 and Beta 9 native installers passed discovery of Beta 10, extraction,
  activation, restart, rollback, truncated-download recovery and external
  snapshots. Both local Linux and anonymous public-byte Linux/TLS runs passed
  for each starting release. A local macOS Beta 9 run also passes all phases.
  No installed reader was touched.
- GitHub checks passed for both main and the exact release tag at `0a2ea22b`
  (runs `40242459682` and `40242459905`).
- draft and anonymously downloaded public assets match the local build exactly:
  ZIP SHA-256 `d461f9afd5a1e122df4bacfa44b4e6595b27a024acc0e43b9bd78739d21cdd43`,
  9,035,141 bytes. Evidence: `test-results/beta10-20261025/`. Later verification
  documentation commits do not replace or rebuild the immutable release assets.

These results are headless. They do not establish real fonts, touch targets,
e-ink rendering, device lifecycle, performance or update recovery.

## Known gaps and next milestones

The published Beta 14 runtime contains 1,999 inventoried files plus its manifest:
all 2,000 installed OTA API 1 file slots are used. The settings redesign itself
adds no runtime path; its release note uses Beta 12's final free slot. A reviewed
compatibility plan is required before adding runtime assets/modules/release
notes. A producer-only limit increase cannot change already-installed updaters.
Do not discard runtime assets/licenses or casually change the bootstrap to fit.
Beta 14's reviewed compatibility plan adds no runtime file: its notes go into
existing `docs/OTA.md` and the GitHub body. Retain all Beta 13 paths and limits.

The primary unresolved gate is focused physical acceptance on the Bigme B7 Pro
at 1264 x 1680. `docs/TESTING.md` and `docs/SHARED_UI.md` contain the authoritative
checklists. Highest-value remaining checks include:

1. Fresh setup, arbitrary library sections, dashboard configuration and optional
   add-on installation/update while preserving existing settings.
2. Shared Home/library/search/detail navigation, every book-opening/closing
   route, reading profiles, rotation, suspend/resume and parked-reader returns.
3. Physical shelves, pagination/dock clearance, captions, series boxes,
   bindings, ratings, ornaments, tap/hold and day/night rendering.
4. Built-in OTA interruption, activation, restart, startup failure and rollback,
   plus the Beta 2 external app-store/manual-install import and extra restart.
5. BookOrbit remote progress, a single intended Hardcover read writer, MAL
   actions/ratings and external patches on the actual device.

The longer-term milestones recorded in `docs/UPSTREAM.md` are:

1. Complete target-device compatibility validation.
2. Move navigation/reader-return ownership into one explicit coordinator.
3. Complete common OTA device acceptance.
4. Consolidate duplicate measured data/cache work behind stable services.

Do not combine these milestones with an unrelated upstream import or visual
redesign.

## Working checklist for a new session

1. Read `AGENTS.md` and this file.
2. Run `git status --short --branch`; preserve unrelated user changes.
3. Read the specific authority document for the requested area.
4. For upstream work, inspect `sources.json`, GitHub issue #1 and the exact
   upstream diff before changing any pin.
5. Keep component imports, OrbitUI adaptations and release work separable.
6. Run focused tests during development, then the full Lua/LuaJIT/translation
   gates for integration or release candidates.
7. Run `sh scripts/package.sh` only from a clean committed candidate. Packaging
   is not permission to publish.
8. Record durable decisions in the relevant docs and merge log instead of
   relying on conversation history.

## Condensed chronology

- **2026-10-02:** OrbitUI imported the two component histories and established
  reviewed, monitoring-only upstream maintenance.
- **Alpha cycle:** shared navigation/settings/search/Home shelves; safe OTA;
  icons; physical shelf refinements; series boxes; ornaments; arbitrary
  libraries; configurable dashboard/setup/presets; then optional add-ons.
- **2026-10-19 — Beta 1:** public combined-plugin beta and native Bookshelf
  settings compatibility.
- **Beta 2:** independent ornament distribution plus verified external release
  snapshots and restart-only adoption.
- **2026-10-22 — Beta 3:** reviewed Bookshelf 5.5.5 integration and Shelf size
  translator fix.
- **2026-10-22 — Beta 4:** reviewed SimpleUI 2.7.5 action-dialog and Tabbed Grid
  integration. The following `11bbbcb8` commit added public screenshots only.
- **2026-10-23 — Beta 5:** approved SimpleUI 3.0 release-ZIP import and explicit
  push/publication request. Its upstream tag still points to the integrated
  2.7.5 Git baseline. Bookshelf and stable bootstrap/API remain unchanged;
  no new physical-reader acceptance is claimed.
- **2026-10-25 — local maintenance:** reviewed Bookshelf 6.0 + SimpleUI follow-ups;
  the old ZIP baseline is reconciled with upstream Git. No push, version bump,
  publication or new physical-reader acceptance.
- **2026-10-25 — Beta 6:** published the reviewed merge after the explicit
  push/publication request, complete release gates and public-byte OTA tests.
  Standing merge authorization now includes audited pushes, never automatic
  releases. New physical-reader acceptance remains outstanding.
- **2026-10-25 — Beta 7:** published the confirmed first-run Home logger fix,
  shared guarded diagnostics and first-run regression coverage after explicit
  approval and full/public-byte gates. Native Android crash acceptance is open.
- **2026-10-25 — Beta 8:** published the missing screen-engine Blitbuffer import
  after the exact photo error reproduced under both interpreters and the user
  explicitly approved publication. Whole-module cold-load coverage, complete
  gates, CI and public-byte OTA from Beta 5/Beta 7 pass. Device retesting is open.
- **2026-10-25 — Beta 9:** after the user's Beta 8 Home confirmation, published
  first-class Bookshelf navigation, simple profile/chip targeting, removable
  defaults and missing-legacy-profile repair. Explicitly approved; full gates,
  CI and public-byte OTA from Beta 8/Beta 5 pass. Saved bars/data are retained.
  New-flow Boox/Bigme physical acceptance remains open.
- **2026-10-25 — Beta 10:** user confirms Home/navigation work on Boox, then
  explicitly requests merge/push/publication. Reviewed Bookshelf 6.0.2 fixes
  metadata/cover refresh, clipped colour shadows, status refreshes and module
  actions/keys. Full gates, main/tag CI, fresh SQLite supplements and local/live
  native OTA from Beta 9/Beta 5 pass. Cover/device acceptance remains open.

- **2026-10-26 — Beta 11:** explicitly approved shared updater/HTTP diagnostic fix
  plus the already-reviewed October 26 upstream changes. Complete suites, sealed
  bytes, exact draft/public assets, main/tag CI and native older-installer OTA
  pass. Physical UI/network and upstream device acceptance remain open.

- **2026-10-26 — Beta 12:** explicitly approved Android safe-mode cover fix;
  native older installers, CI and public-byte checks pass. The user later
  confirms all covers display correctly on Boox; broader lifecycle gaps remain.
- **2026-10-27 — Beta 13:** explicitly approved push/publication of the bilingual
  five-area settings hub, local search, scope headers, panel controls and context
  shortcuts. Full suites, exact assets, CI and native public-byte older-installer
  upgrade/rollback pass. No upstream import; physical settings acceptance is open.

For the full decision trail, use `docs/MERGE_LOG.md`; commit messages and tags
are supporting evidence, not substitutes for the recorded contracts and tests.
