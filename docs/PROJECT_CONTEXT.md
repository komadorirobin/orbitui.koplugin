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

## Snapshot: 2026-10-25

- Product version before this merge: `0.1.0-beta.9` (public GitHub prerelease, published
  2026-10-25 at 19:49 UTC; verification is in `docs/MERGE_LOG.md`).
- Public main baseline for the requested Beta 10: `97b7948a` (Beta 9 verification).
- Release tag: `v0.1.0-beta.9` at `a4bb9acb`; previous tag
  `v0.1.0-beta.8` at `50edce78` and all earlier assets are unchanged.
- Active branch: `maintenance/upstream-late-20261025`; the user explicitly
  requested merging upstream, pushing and publishing a new release. Beta 10
  preparation follows a conflict-free Bookshelf subtree import `0db81b46`.
  Main remains at the public baseline until final gates pass.
  The feature and Beta 9 candidate were previously fast-forwarded/pushed.
  `fix/bookshelf-navigation-20261025` is retained locally.
  The user explicitly approved pushing and publishing this feature as Beta 9.
  Public main before this release was Beta 8 verification at `abe6164e`. The earlier Home
  runtime fix `8641271c` and release candidate `50edce78` were pushed.
  The user explicitly approved fixing and publishing Beta 8 after the photo.
  `fix/home-blitbuffer-20261025` is retained locally.
  `fix/home-first-run-20261025` is retained locally.
  `maintenance/upstream-20261025` is retained locally.
  Future user-requested verified merges include an audited push to `origin/main`;
  a new release still requires a separate explicit request.
- Embedded Bookshelf Git: `5f726c253c5cb4d5a2a2137af52731562e1cb9b7`
  (6.0.2), eight reviewed incoming commits; merge `0db81b46`.
  Prior 6.0.0 integration `fc1103a3` / `48438837` is retained in ancestry.
- Embedded SimpleUI Git: `40b301f0f5e4466021d00b4e47ac8c09bb65ac8c`
  (3.0 plus follow-ups), 18 reviewed incoming commits; merge `b9dfc849`.
- Prior broad adaptation candidate: `3a33fee6`; its final headless gates passed.
  A read-only local collector at 2026-10-25 22:43 UTC found eight Bookshelf
  commits and no SimpleUI changes. Issue #1's older 17:48 result listed only
  five commits; the exact newer Git tip was inspected before importing it.
  Final Beta 10 verification/publication is recorded separately after completion.
- The real SimpleUI Git history now accounts for the approved 3.0 ZIP snapshot
  `3cb36431`. Content reconciliation preserved OrbitUI's changes; the active
  `release_snapshot` field is retired. Historical digest/asset provenance stays
  in `docs/MERGE_LOG.md` and Git, not relabelled as an upstream commit.
- GitHub issue #1 is monitoring-only and describes public main. Its run for
  `7e573fd9` passed after the merge push; it never authorizes a new import.
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

- The user confirms both Home and the Beta 9 Bookshelf navigation fix work on
  the affected Boox. Wider lifecycle/rotation/device checks remain outstanding.
  The later cover-loading/indexing report is not yet device-verified as resolved.
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
- One settings hub joins Home, arbitrary library sections, appearance, search,
  Home shelves and the OrbitUI updater.
- Library sections are user-defined; no personal fiction/manga folder layout is
  hard-coded as the live source of truth.
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

A fresh local verification on the versioned Beta 9 tree on 2026-10-25 passed:

- `sh scripts/test.sh`
- `LUA=luajit sh scripts/test.sh`
- `sh scripts/check-translations.sh`
- 117 Python tests per run, with four documented external source-cache audits
  skipped
- all 72 OrbitUI Lua test files under both interpreters, including 12 new
  navigation cases, three whole-engine cold-load and 14 first-run/error/retry
  cases. All three suites also pass against the sealed ZIP under both interpreters
- module map: 383 paths verified
- LuaJIT syntax: 1,044 Lua files verified
- Bookshelf: 478 suites, 0 failed, 3 documented KOReader-SQLite skips per run;
  the latest supplemental real SQLite runs remain Beta 6's 7 deck, 16 facts,
  100 OPDS cases and SimpleUI ledger check. Beta 9 changes no component or
  database code; those supplemental runs were not repeated for this host UI change.
- all 13 original SimpleUI test files exercised by `scripts/test.sh`
- translations: 43 passed, 0 baseline failures and 0 new failures
- clean-commit release package: 1,994 inventoried files plus its manifest, all
  sizes/hashes verified; bootstrap/API 1 and existing artwork/fonts unchanged.
  All 31 outgoing blobs were checked for held artwork, and Gitleaks found no
  secrets in four outgoing commits. No Beta 8 path was removed; runtime changes
  are six host adapters and owned translations, with component files/pins unchanged.
- Luacheck reports no undeclared globals in all seven changed runtime files
  after allowing the intentional G_reader_settings host global.
- actual public Beta 5 and Beta 8 native installers passed discovery of Beta 9, extraction,
  activation, restart, rollback, truncated-download recovery and external
  snapshots. Both local Linux and anonymous public-byte Linux/TLS runs passed
  for each starting release. No installed reader was touched.
- GitHub checks passed for both main and the exact release tag at `a4bb9acb`
  (runs `40227604923` and `40227604800`). No upstream pins were changed.
- draft and anonymously downloaded public assets match the local build exactly:
  ZIP SHA-256 `3a2c8fab178e01ff99822b8b8a6105bc4d70228f42a2f6fa227a6275403842c9`,
  9,025,063 bytes. Evidence: `test-results/beta9-20261025/`. Later verification
  documentation commits do not replace or rebuild the immutable release assets.

These results are headless. They do not establish real fonts, touch targets,
e-ink rendering, device lifecycle, performance or update recovery.

## Known gaps and next milestones

The published Beta 9 runtime contains 1,994 inventoried files, plus its
manifest, within the installed OTA API 1 limit of 2,000 extracted files. Review
that budget before adding more assets/modules; a producer-only limit increase
would not change limits enforced by already-installed updaters.
Only five installed file slots remain. Do not raise only the producer limit or
discard runtime assets/licenses to force a build through.

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

For the full decision trail, use `docs/MERGE_LOG.md`; commit messages and tags
are supporting evidence, not substitutes for the recorded contracts and tests.
