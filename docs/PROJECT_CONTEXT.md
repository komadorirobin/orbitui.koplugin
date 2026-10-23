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

## Snapshot: 2026-10-23

- Product version: `0.1.0-beta.4` (public GitHub prerelease).
- Baseline commit: `11bbbcb8` on `main`, which matched `origin/main` when this
  context was reconstructed. It adds the public README screenshots on top of
  the Beta 4 release commit.
- Latest release tag: `v0.1.0-beta.4` at `b4c51138`.
- Embedded Bookshelf upstream: `065f25c06d9a8e0607f29cbe632f4b3d44a8bd37`
  (5.5.5 plus PR #544's Shelf size translator fix).
- Embedded SimpleUI upstream: `dd541fc2b384af43287474587622ef68a2fb3185`
  remains the public Git baseline. The approved local 3.0 release-ZIP import
  is source snapshot `3cb364313ee8b2b17f860f67ef330cd6c2f5370b`, merged in
  `a5d9e76a` on `maintenance/simpleui-3-zip-20261023` (unpublished).
- SimpleUI 3.0.0's official ZIP differs from its Git tag/main. Its exact digest,
  asset ID and local snapshot are in `sources.json.release_snapshot`.
  Reconcile them with upstream's eventual commits using `docs/UPSTREAM.md`.
- Read-only upstream check at 2026-10-23 20:59 UTC: zero missing Git commits
  for both components, despite the release-only code difference. GitHub issue
  #1 is the published monitor; local snapshot-aware output is separate.
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

- The local SimpleUI 3.0 integration adds detailed statistics/charts, live Bento
  preview, accent/secondary colours, optional bundled fonts and Tiny Critter.
  Existing percentage/stacked layouts retain their geometry until an explicit
  new-editor width/movement change; per-module gaps remain independent.
  UI fonts remain explicit choices and the embedded navbar keeps its 96dp base.
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
- Exception approved October 23: the official SimpleUI 3.0 ZIP is a separately
  identified local source snapshot. Do not advance the Git pin or remove the
  snapshot record until upstream's matching history has been reviewed.
- Before a merge, read `docs/UPSTREAM.md`, all C01-C11 contracts and the latest
  `docs/MERGE_LOG.md` entries. Update only the appropriate `upstream_commit` in
  `sources.json`; preserve original fork provenance fields.
- Publication requires a separate explicit user request. A green CI/package is
  not publication approval and is not physical-device acceptance.
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

A fresh local verification on 2026-10-23 passed:

- `sh scripts/test.sh`
- `LUA=luajit sh scripts/test.sh`
- `sh scripts/check-translations.sh`
- 117 Python tests per run, with four documented external source-cache audits
  skipped
- all 68 OrbitUI Lua test files under both interpreters, plus the final
  nine-case SimpleUI 3.0 compatibility suite after its last regression was added
- module map: 364 paths verified
- LuaJIT syntax: 952 Lua files verified
- Bookshelf: 410 suites, 0 failed, 2 documented KOReader-SQLite skips per run
- all 13 original SimpleUI test files exercised by `scripts/test.sh`
- translations: 43 passed, 0 baseline failures and 0 new failures
- clean-commit package: 1,969 inventoried files, all byte sizes/hashes verified;
  native installer smoke test from public Beta 3 passed extraction, activation,
  restart, code rollback, truncated-download recovery and external snapshots

These results are headless. They do not establish real fonts, touch targets,
e-ink rendering, device lifecycle, performance or update recovery.

## Known gaps and next milestones

The SimpleUI 3.0 local runtime contains 1,969 inventoried files, plus its
manifest, within the installed OTA API 1 limit of 2,000 extracted files. Review
that budget before adding more assets/modules; a producer-only limit increase
would not change limits enforced by already-installed updaters.

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
- **2026-10-23 — local maintenance:** approved SimpleUI 3.0 release-ZIP import;
  its tag still points to the already-integrated 2.7.5 Git baseline. Bookshelf,
  OrbitUI VERSION and public releases remain unchanged.

For the full decision trail, use `docs/MERGE_LOG.md`; commit messages and tags
are supporting evidence, not substitutes for the recorded contracts and tests.
