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

## Snapshot: 2026-11-10

- **Local Next in series Home module, not published.** User requests the next
  Aleph-list point after local recommendations. Branch
  `feature/next-series-home-20261110` starts at **9f2cc4af**, retaining point 1.
  Lazy opt-in registry id `orbitui_next_series` is available on Home and as a
  dashboard SimpleUI card; no existing placement/Continue reading change.
  All configured libraries or one explicit section; own per-screen style.
  Cooperative prewarming + bounded RO cached text feeds the same native
  next-volume selector through small optional records/checkpoint/identity
  seams. Preserve default shelf behavior; prioritize current then next unread
  in started series, separate author/profile identities and decimal order.
  Eight memory snapshots, rank before 400-series output cap, lifecycle/page/
  data-generation guards and safe native opener/hold ownership. No tag-index
  requirement, AI/server/account, network, reading-data writer, new runtime
  path or dependency. Native progress/facts caches keep their prior owner.
  C10/FEATURES/TESTING/MERGE_LOG record the implementation and physical gaps;
  no upstream/pin/version/public-dist/device/server/watch change. Stable 1.1
  and public preview beta.1 remain unchanged. Final local checks follow.

- **Local similar-books/series feature, not published.** User approves point 1
  from the Aleph review. In the existing offline Tags section, an explicit
  action ranks local EPUBs by distinct common literal tags; Books/Series reuse
  passive cached/RO series discovery and exclude the current series across
  profiles. MAX volume score avoids inflating long series. Reuse existing
  stat/epoch-checked SQLite batches (128 paths/200 source tags), fall back only
  to existing caches, scan all candidates then cap the ranked view at 400.
  Missing tags/metadata are disclosed with an explicit tag-index action.
  No AI/server/network, reader auto-open, new index/schema/runtime path, Home
  replacement or data migration. Native stop/close/sleep/navigation guards and
  separate view preferences remain. Independent OrbitUI code; no Aleph source,
  assets or dependency imported. No upstream/pin/version/public-dist/device/
  server/watch change; stable 1.1.0 and public preview beta.1 stay unchanged.
  C10/FEATURES/TESTING/MERGE_LOG record the local work and physical gaps.
  Frozen **ee3d5cf5** passes both full scripts/43 catalogs and all 117 sealed
  root suites in Lua/LuaJIT; separate native SQLite/series/EPUB-input suites
  pass 10/29/55. Private ZIP **88192bab**, 9,703,716 bytes, manifest **6e755bc2**,
  same 33/412 helpers/identities and API1/exact 2,000 paths. Exact-source/path/
  art/secret gates pass. Receipt commit changes docs only; no beta.1 replacement
  or physical acceptance. Public dist remains **25f988ce**.

- **1.2.0-beta.1 preview is public.** Published 06:01:52 UTC, release
  438785778, source/tag 93d879bf / v1.2.0-beta.1; ZIP 25f988ce, 9,695,479
  bytes, manifest 4ff774d9, API1/exact 2,000 paths. Bookshelf 6.4.1 integration
  ace1e222 is retained. Both frozen scripts/43 catalogs, sealed/native suites,
  real SQLite, all four exact main/tag CI jobs 42570125844 / 42570125824,
  source/history/art/secrets and draft/public byte checks pass. Seventeen real
  older installers pass offline; sixteen pass anonymous public-HTTPS upgrades/
  restart/rollback/recovery, including stable 1.1. Transient GitHub 504s clear
  without client/asset changes. All 98 old releases/171 tag refs and maintenance
  branches remain unchanged; latest/stable stays 1.1.0, preview/dist is beta.1.
  README's stable 1.1 presentation is public. No real device/server/catalog
  operation; new physical Bigme acceptance and timings remain pending. Full
  receipts in OTA/TESTING/MERGE_LOG; following receipt changes docs only.

- **1.2.0-beta.1 release freeze.** After ace1e222, only VERSION, README,
  release docs and channel regression change. All full/sealed/native/installer/
  source/history/CI/draft/public gates precede publication. Keep latest stable
  1.1.0 and both maintenance branches unchanged. No device/server/catalog
  operation; newly merged physical/performance acceptance remains pending.
  Evidence upstream-20261109; frozen/public receipts follow verification.

- **Reviewed 1.2 upstream integration (now published above).** Stable 1.1 is public and
  maintenance/1.1 is preserved at 16cae997. Bookshelf 60 commits through 6.4.1
  3fe9702d imported unsquashed as 68f2fcf3; SimpleUI 4426601f is unchanged.
  Stable README refresh f53840db is public (CI 42566976676 green) and merged
  separately into this branch. Follow-up adaptations preserve C01–C11: scoped
  lists/decades/styles, host bindings/dock/series/ornaments, cancellable background
  work, atomic disk-cache failures and SV/EN. Five new helpers are exact-source
  embedded (33/412), keeping the identical 2,000 API1 paths. Host defers new
  bytecode searcher, position-file split and whole-page cache/build-ahead; prior
  automatic publication-file reads/folder-delete deferrals remain. No saved
  data reset, new sync owner, device/server operation or stable-byte replacement.
  Full/sealed/native/older-installer/source/history/CI/public gates precede
  the explicitly authorized 1.2.0-beta.1 publication. Bigme timings and new UI
  acceptance remain unmeasured/unverified. Evidence upstream-20261109.

- **Stable 1.1 README refresh requested during the separate 1.2 merge.**
  Replace the historical beta diary with a current, moderately promotional
  overview and stable install links. Highlight OrbitUI's own connected workflow,
  sections/dashboard, local tags/index/smart chips/series results, alphabet/
  suggestions, optional BookOrbit and Silverfish cards, Android shortcuts and
  presentation/add-on/update refinements. Retain prominent upstream attribution,
  experimental/external requirements, preservation and test limitations. README/
  feature guide/receipts only; frozen stable code/tag/assets and maintenance
  branches unchanged. Prepared separately from the unresolved subtree import.

- **Stable 1.1 first, upstream and 1.2 beta afterward — explicitly approved.**
  User reports everything working well and requests stable 1.1, followed by a
  reviewed upstream merge/new beta. Release from ed2f42e3 with beta.12 runtime
  unchanged; only VERSION/README/docs/channel tests. No source/component/pin/
  art/bootstrap/API1/data/device/server change. Both full/sealed/native suites,
  43 catalogs, exact source/beta.12 parity, older installers, history/art/secrets,
  exact main/tag CI and draft/public/channel verification precede publication.
  Make new v1.1.0 stable/latest; prior tags/assets and maintenance/1.0 immutable.
  Preserve maintenance/1.1 before importing upstream into separate 1.2 preview.
  General user acceptance is not agent-run or per-test device certification.
  Evidence stable11-20261109; receipts follow.
  **Stable published 2026-11-09 05:07:44 UTC**, release **438759601**,
  source/tag **16cae997 / v1.1.0**, ZIP **b625a25f** / 9,637,693 bytes,
  manifest **d7e754e2**, exact 2,000 API1 paths. Runtime equals beta.12.
  Both full scripts/43 catalogs, sealed/native regressions and four main/tag
  CI jobs **42564959769 / 42565018766** pass; exact source/draft/public/CI bytes,
  history/held-art/secrets verified. Sixteen actual older installers pass offline;
  fifteen pass anonymous public-HTTPS upgrades/restart/rollback/recovery,
  including beta.12. All 97 old releases/169 tag refs and maintenance/1.0 are
  unchanged. Stable/preview/latest select 1.1.0; public dist is stable 1.1.
  Preserve maintenance/1.1 at 16cae997 before importing upstream. No new device/
  server install or per-test physical certification. Following receipt is docs only.

- **1.1.0-beta.12 preview published.** User requests a new beta
  after viewing the schematic composition. Branch release/1.1.0-beta.12-20261108
  starts at fa670875, retaining ed456402 runtime: companion left, centered text,
  cover right. Only VERSION/README/release docs and draft/preview regression.
  No further upstream/component/pin/art/bootstrap/API1/device/server/catalog
  change. Stable/latest/maintenance1.0 and older releases/tags/assets immutable.
  Same 28/407 helpers/identities, exact 2,000 paths. Both complete scripts/43
  catalogs, frozen sealed/native sandbox/Font/Silverfish/retained regressions,
  actual older installers including beta.11, history/art/secrets, exact main/tag
  CI and verified draft/public bytes/channels precede activation. Evidence
  preview11-beta12-20261108; receipts follow. Prior local-only restrictions are
  superseded only for this release. Physical Bigme acceptance remains pending;
  no actual device install, server or independent catalog operation.
  **Published 2026-11-08 22:13:26 UTC**, release **438555721**, frozen source/
  tag **4d2f3507 / v1.1.0-beta.12**, public ZIP **7fc47a39** / 9,634,943
  bytes, manifest **0cff5d08**, API1/exact 2,000 paths. Both complete scripts/
  43 catalogs, all 116 sealed roots in Lua/LuaJIT, minimum/current native
  sandbox/Font/Silverfish and retained native regressions pass. All four
  main/tag CI jobs **42528779452 / 42528781196** pass; four payloads match every
  frozen file. Source/history/held-art/secrets/draft/public byte checks pass.
  Fifteen actual old installers pass offline; fourteen pass anonymous public-
  HTTPS upgrades/restart/rollback/recovery, including beta.11, in temporary
  installations. All 96 previous releases/167 tag refs and stable/latest/
  maintenance1.0 unchanged; public dist/preview is beta.12. No actual device/
  plugin install, server or independent catalog operation. Physical Bigme/
  full-plugin acceptance remains pending. Following receipt changes docs only.

- **Reading companion composition (local phase; published in beta.12).** User's beta.11 photo
  requests a right-hand cover and better use of space. Branch
  fix/silverfish-card-composition-20261108 starts at fdaf02e1. Full-height
  creature left, vertically centered middle text stack, native portrait cover
  right. Name/stage share a row; title/author and percentage/companion statistics
  stay together above the progress bar. Secondary text uses normal contrast.
  Reuse the native title widget's measured height to remove unused title lines,
  not character-count guesses or another shaping pass. Compact cards omit
  secondary rows before shrinking fonts. Companion/name taps open Silverfish;
  title/cover resume the book. Continue reading, placements, saves, progression,
  source pins/components/art/bootstrap/API1/VERSION/public dist stay unchanged.
  No push/release/ADB/server or independent catalog operation. C10/TESTING hold
  tests and physical gaps; evidence silverfish-composition-20261108. Same
  28/407 helpers/identities and 2,000 paths; frozen/package receipts follow.
  Frozen **ed456402**, private ZIP **c34ba77c** / 9,633,509 bytes, manifest
  **fbaaa2ad**, API1/exact 2,000 paths. Both complete scripts/43 catalogs and
  all 116 sealed roots in Lua/LuaJIT pass. Minimum/current native sandbox/Font
  fixtures pass 19 each in both interpreters; input/FFI/frozen Silverfish
  matrices pass 24 dashboard / 20 companion / 18 placement cases each.
  Exact source/inventory/held-art/redacted-secret gates pass. Public beta.11/
  dist stays **e204872e**; no actual device install/publication. Following
  verification receipt changes docs only.

- **1.1.0-beta.11 preview publication authorized.** User requests a new beta
  after the local fix report explicitly discloses pending physical Bigme tests.
  Branch release/1.1.0-beta.11-20261108 starts at 6c53fa2e; retain runtime
  a094bbe9. VERSION/README/release docs and preview/draft-selection regression
  only; no further upstream/component/pin/art/bootstrap/API1/data/server/device
  or catalog change. Stable/latest/maintenance1.0 and prior releases/tags/assets
  immutable. Same 28/407 helpers/identities and exact 2,000 paths. Both full
  scripts/43 catalogs, frozen sealed/native sandbox/Font/Silverfish, older
  installers including beta.10, history/secrets, exact main/tag CI and verified
  draft/public bytes/channels precede activation. Evidence under
  test-results/preview11-beta11-20261108; receipts follow. Earlier local-only
  restrictions are superseded only for this requested release, not physical
  acceptance, an actual plugin/device install or an independent catalog release.
  **Published 2026-11-08 21:32:02 UTC**, release **438533738**, frozen source/
  tag **d9b0f54e / v1.1.0-beta.11**, public ZIP **e204872e** / 9,630,353
  bytes, manifest **742cf005**, API1/exact 2,000 paths. Both full scripts/43
  catalogs, sealed/native sandbox/Font/Silverfish/menu/source/history/secrets
  pass. All four main/tag CI jobs **42525307604 / 42525329181** pass and all
  four payloads match every frozen file. Draft/public assets are byte-identical.
  Fourteen actual old installers pass offline; thirteen pass anonymous public-
  HTTPS upgrade/restart/rollback/recovery, including beta.10. All 95 previous
  releases/165 old tag refs and stable/latest/maintenance1.0 unchanged; public
  dist/preview is beta.11. No real device/plugin install, server or catalog
  operation. Physical Bigme/full-plugin acceptance remains pending. Following
  receipt changes docs only.

- **Local beta.10 Silverfish reading-card correction; not published.** User's
  Bigme photo shows the unsupported-version fallback and tiny text. Branch
  fix/silverfish-card-layout starts at 2a2108ac. KOReader's PluginLoader wraps
  onMostrarTraca in a callable HandlerSandbox table; accept that public event
  boundary without unwrapping/bypassing it, retaining all version/state/species
  checks. Fonts now follow density/available width rather than short card
  height; the cover uses full height, companion header stays in its own column
  and compact book titles elide instead of becoming miniature. No placement/
  Continue reading/settings/plugin-save changes or upstream/pin/bootstrap/API1/
  VERSION/public-dist/ADB/server operations. Same 28/407 helpers/identities and
  2,000 installed paths. New regression fails on frozen beta.10; exact native
  PluginLoader/Font service and frozen Silverfish drawing supplements cover
  the fix. C10/TESTING record scope and receipts. Evidence under
  test-results/silverfish-card-layout-20261108; physical Bigme fonts/layout/
  touch/wake/night and full-plugin lifecycle still need acceptance.
  Frozen fix **a094bbe9**, private ZIP **6cec9a44** / 9,628,809 bytes, manifest
  **0b130f45**, API1/exact 2,000 paths. Both full scripts/43 catalogs and all
  116 sealed roots in Lua/LuaJIT pass. Native minimum/current sandbox/Font
  fixtures pass 16 each in both interpreters; input/FFI/frozen Silverfish
  matrices pass 24 dashboard / 17 companion / 18 placement cases each.
  Exact source/inventory/held-art/redacted-secret gates pass; public beta.10/
  dist stays **83157ee1**. No actual device install or publication; following
  verification receipt changes docs only.

- **1.1.0-beta.10 preview publication authorized.** User requests a new beta
  after both local reports disclose pending physical Bigme tests. Branch
  release/1.1.0-beta.10-20261108 starts at 8b40cb29; retain runtime d971b338
  and the optional Silverfish card. VERSION beta.10, README/release docs and
  preview/draft-selection regression only; no further upstream/component/pin/
  art/bootstrap/API1/data/server/device changes. Stable/latest/maintenance1.0
  and all prior tags/assets immutable. Same 28/407 helpers/identities and 2,000
  installed paths; one reviewed adapter/helper path exchange from beta.9.
  Full/package/sealed/native/menu/frozen Silverfish/actual older-installer/
  history/secret gates and exact main/tag CI plus downloaded draft/public
  bytes/channels must pass. No independent module-catalog publication or
  physical/full-plugin certification. Evidence preview11-beta10-20261108;
  receipts follow. Earlier local-only restrictions below are superseded only
  for this explicit publication, not device acceptance or duplicate cleanup.
  **Published 2026-11-08 19:28:20 UTC**, release **438466180**, frozen tag/
  source **65bad370 / v1.1.0-beta.10**, public ZIP **83157ee1**, 9,625,340
  bytes, manifest **d09ba311**, API1/exact 2,000 paths. Both full scripts/43
  catalogs, sealed/native/menu/frozen Silverfish/source/history/secrets pass.
  All four main/tag CI jobs **42514809970 / 42514810638** pass and all four
  payloads match every frozen file. Draft/public assets are byte-identical.
  Thirteen actual old installers pass offline; twelve also pass anonymous
  public-HTTPS upgrade/restart/rollback/recovery, including beta.9. All 94 old
  releases/163 old tag refs and stable/latest/maintenance1.0 unchanged; preview/
  dist is beta.10. Public-HTTPS upgrade verification is recorded in TESTING.
  No actual device/plugin install, server operation or independent catalog
  publication; Bigme/full-plugin acceptance remains pending. Following receipt
  changes docs only.

- **Local dashboard add/remove feedback fix; not pushed/released.** User
  reports silent BookOrbit source additions causing duplicates, stale removal
  menus and misleading Unavailable labels. Branch
  fix/dashboard-card-feedback-20261108 starts at cd8c862b, retaining the
  separately approved local Silverfish card. Picker actions now report saved
  additions/failures and mark sources already added to this screen. Repeated
  picker taps are idempotent by account/section/id; low-level independent
  placements, existing duplicates and other screens are retained. Remove is
  a single explicit action with feedback and return to Cards and content,
  not a second removal submenu. Retired successful callbacks cannot remove
  a newly reused row id; missing entries have no active controls. BookOrbit
  availability uses its passive snapshot, not third-party registry lookup;
  cached usable results remain available offline. Twenty SV/EN native menu/
  navigation fixture cases cover these paths, failed saves and full/future
  layouts. C10/TESTING hold receipts and remaining physical gates. No upstream,
  component/pin, bootstrap/API1, VERSION/public dist, ADB/server or existing
  settings migration. Same 28/407 helpers/identities and 2,000-path budget.
  Evidence test-results/dashboard-card-feedback-20261108; receipts follow.
  Frozen runtime **d971b338**, private ZIP **8de318f3** / 9,622,807 bytes,
  manifest **90068e27**, exact 2,000 paths. Both complete scripts/43 catalogs
  and all 116 sealed roots in Lua/LuaJIT pass, including the 20-case menu
  suite; minimum/current native input/FFI supplements pass 15/24/18 cases.
  Exact source projection/inventory, new-history held-art and redacted-secret
  audits pass. Public beta.9/dist remains **d171ea5f**. No real device/server
  operation or distribution; this following receipt is docs-only.

- **Local optional Currently reading + Silverfish card; not pushed/released.**
  User explicitly keeps Continue reading unchanged and approves a separate
  module with cover, title/progress and the active companion. Branch
  feature/silverfish-reading-card-20261108 starts at eb35fbad. New opt-in
  native registry descriptor orbitui_reading_silverfish is available through
  the dashboard's Home modules picker or ordinary Home module picker. Reuse
  only already-loaded, checked public Silverfish 2.0.0 state/species/drawing
  APIs; never initialize it, read/write saves, advance development, copy art,
  modify its files or maintain a fork. KOReader owns the actual book and
  resume action; companion tap opens Silverfish. Missing/unreviewed APIs
  show a reason without changing existing placements. Bounded local paint/
  input, native late-cover polling and visible-page minute refresh reuse
  existing owners. C10/TESTING record checks and outstanding physical gates.
  A pure drill-rekey helper is exact-source lazy embedded to offset the new
  adapter: 28/407 helpers/identities, unchanged 2,000 API1 paths. Components,
  pins, artwork, bootstrap, VERSION and public beta.9/dist stay unchanged.
  Local implementation/testing only; no push, release, ADB or server work.
  Evidence test-results/silverfish-reading-20261108; receipts follow.
  Frozen runtime **043b41ec**, private ZIP **a0bd23a9** / 9,618,765 bytes,
  manifest **12201352**, exact 2,000 paths. Both complete scripts/43 catalogs
  and all 116 sealed root files in Lua/LuaJIT pass. Minimum/current native
  input/FFI matrices pass 15 reading-card, 24 dashboard and 18 placement cases
  each. Exact source projection/new-blob held-art/redacted-secret gates pass;
  public beta.9/dist stays **d171ea5f**. Schematic inspection is not native
  font/device acceptance. Following verification receipt changes docs only.

- **1.1.0-beta.9 preview publication authorized.** User requests a new beta
  after the local Silverfish report explicitly discloses pending physical
  retesting. Branch release/1.1.0-beta.9-20261108 starts at cfebd307, preserving
  runtime f60bcf98. VERSION beta.9 and release docs/channel coverage only;
  no additional upstream/component/pin/art/bootstrap/API1/data/server/device
  change. Full/package/sealed/native/frozen Home API/actual older-installer/
  history/secrets, exact main/tag CI and verified draft/public assets/channels
  must pass. Stable/latest/maintenance1.0 and prior tags/assets immutable;
  27/407 helpers/identities and 2,000 paths. No actual device/plugin install
  or independent module-catalog publication. Evidence preview11-beta9-20261108;
  receipts follow. Earlier local-only restrictions below are superseded only
  for this explicitly requested publication, not physical acceptance.
  **Published 2026-11-08 16:54:56 UTC**, release **438380489**, frozen
  source/tag **3632d18d / v1.1.0-beta.9**, public ZIP **d171ea5f**,
  9,609,810 bytes, manifest **75df6d3d**, API1/exact 2,000 paths. Both full
  scripts/43 catalogs, sealed/native/frozen Home API/source/history/secret
  gates pass. All four main/tag CI jobs **42501824036 / 42501823791** pass;
  all four payloads match every frozen file. Draft/public downloads are exact.
  Twelve actual old installers pass offline; eleven also pass anonymous
  public-HTTPS upgrade/restart/rollback/recovery, including beta.8. All 93
  prior releases/161 tag refs and stable/latest/maintenance1.0 unchanged;
  public dist is beta.9. No real device/plugin or server operation, independent
  catalog or full-plugin acceptance. Following receipt is docs-only.

- **Local Silverfish default-placement fix; not pushed/released.** User's
  beta.8 photos show a standalone Silverfish sibling after the full-page
  Reading dashboard, drawing over the dock. User approves placing new cards
  inside the dashboard, or on a separate Home page when ordinary Home lacks
  proven room, preserving existing manual placements. Branch
  fix/silverfish-default-placement-20261108 starts at bbbc85d9. Only explicit
  canonical registry/layout seams and the existing module-store adapter change;
  no Silverfish fork/archive/save, component/pin, bootstrap/API1, VERSION,
  public dist or upstream change. Fresh Silverfish is opt-in in the in-memory
  native registry; its public Home toggle understands dashboard placement.
  Saved native/custom/legacy choices and edited dashboard cards are retained.
  Native layout APIs retain refresh/order/enable ownership; no build/scan/HTTP
  for placement. Tests/packaging and physical limits are recorded in TESTING
  and MERGE_LOG; evidence silverfish-placement-20261108. This turn authorizes
  local implementation/testing only, not push, release or device installation.
  Frozen runtime **f60bcf98**, private ZIP **dfec7d8a** / 9,607,453 bytes,
  exact 2,000 paths. Both complete scripts/43 catalogs and all 115 sealed
  root files in Lua/LuaJIT pass; 18-case frozen Home API and both 23-case
  native input/FFI Silverfish dashboard supplements pass. Source inventory,
  held-art/new-blob and redacted secret checks pass. Public beta.8/dist remains
  **fd4d58e1**; full-plugin/physical Bigme acceptance is still outstanding.
  Following verification receipt is docs-only.

- **1.1.0-beta.8 preview publication authorized.** User explicitly requests
  push/new beta after the local fix and crash-log confirmation; real Bigme
  retesting remains disclosed. Release branch starts at d76326f7. Preserve
  the three-index fix and regression tests only; no new upstream/component/
  pin/art/bootstrap/API1/data/server/device change. VERSION beta.8,
  preview/prerelease only; stable/latest/maintenance1.0 and previous tags/assets
  immutable, 27/407 helpers/identities and 2,000 paths. Full/package/sealed/
  native/actual older-installer/history/secrets and exact main/tag CI plus
  downloaded draft/public-byte/channel gates precede activation. Evidence
  preview11-beta8-20261108; receipts follow. Prior local-only restrictions
  below are superseded only for this explicitly requested publication.
  **Published 2026-11-08 15:06:47 UTC**, release **438317954**, frozen
  source/tag **564243a0 / v1.1.0-beta.8**, public ZIP **fd4d58e1**,
  9,601,664 bytes, manifest **0eff173b**, API1/2,000 paths. Both full scripts,
  43 catalogs, sealed/native/menu/source/history/secret gates and all four
  main/tag CI jobs **42492684427 / 42492684728** pass. All four CI payloads
  match every frozen file; draft/public downloads are exact. Eleven actual
  old installers pass offline; ten also pass anonymous public-HTTPS upgrade/
  recovery, including beta.7. All 92 previous releases/159 tag refs and
  stable/latest/maintenance1.0 unchanged; public dist is beta.8. No device/
  server operation or new physical acceptance. Following receipt is docs-only.

- **Local beta.7 catalog-menu regression fix; not pushed/released.** User's
  Bigme photos/report show blank BookOrbit sources after refresh, a crash on
  reopening, and an empty module library. Branch
  fix/dashboard-catalog-menus-20261108 starts at c820a54b; runtime eab9256f.
  Three loop indices shadowed the translation function: populated source
  labels, bundled module labels/deferred callbacks, and row/carousel choices.
  Rename only those indices. Real SimpleUI SettingsWindow/MenuTable/ListRow/
  input/navigation reproduce all three faults against frozen public beta.7
  in SV/EN, including the unhandled cached-source tap; fixed paths pass.
  Older protected-show test could swallow both a builder error and its own
  incorrect cumulative assertion; now require completed builds plus direct
  bundled-catalog rows. No cache/reset, HTTP/sync/installer policy, upstream,
  component/pin/bootstrap/API1/assets/version or public dist change.
  Private sealed runtime retains exactly 2,000 paths; tests/receipt and physical
  limits in TESTING/MERGE_LOG. No device, server, push or publication operation.

- **1.1.0-beta.7 published 2026-11-08 14:21:06 UTC.** User requests push and the
  next beta after the BookOrbit-card report explicitly disclosed desktop-only
  evidence and pending real Bigme/server checks. Release branch starts at
  72190eaa; include those local cards only, no new upstream/import/pin change.
  VERSION beta.7, preview/prerelease only; stable/latest/maintenance1.0 and all
  previous tags/assets immutable. Component pins stay c014b133 / 4426601f,
  bootstrap/API1/assets/component bytes fixed, 27/407 helpers/identities and
  2,000 paths. No device/plugin install, independent catalog or server work.
  Full/package/sealed/native/frozen API/old-installer/source/history/secret
  gates, exact main/tag CI and draft/public-byte/channel verification precede
  activation. Evidence preview11-beta7-20261108; receipts follow in TESTING/
  MERGE_LOG/OTA. Earlier local-only entries describe their original implementation;
  this authorization supersedes their publication restrictions only.
  Frozen tag/source **c9366f52 / v1.1.0-beta.7**, release **438291937**, public
  ZIP **c5befabd**, 9,597,006 bytes, manifest **eff14dab**, exact 2,000 paths.
  Both full scripts/43 catalogs, sealed/native/frozen API/source/history/secret
  checks and all four main/tag CI jobs **42488973659 / 42488973545** pass.
  All four CI payloads match every frozen file; draft/public downloaded bytes
  are exact. Ten actual older installers pass offline, nine also pass anonymous
  public-HTTPS discovery/download/restart/rollback/recovery, including beta.6.
  All 91 older releases/157 tag refs and stable/latest/maintenance1.0 unchanged;
  public dist is beta.7. No Bigme/BookOrbit-server operations or new physical
  acceptance. This subsequent verification receipt changes docs only.

- **Local BookOrbit dashboard source cards; not pushed/released.** User approves
  shelves/smartscopes as independent local-files-only cards. Branch
  feature/bookorbit-dashboard-rows-20261108 starts at edf54516 (published beta.6
  receipt). Native catalogSection/catalogBooks and read-only stable on-device
  links; library/collection/smartScope IDs, no copied rules/server extension,
  metadata guesses, manifest/directory scans, downloads or status writes.
  Multiple cards, source/title/size and row/carousel picker, SV/EN, dedicated
  integrations rows switch under existing master. Cache is account/credential
  fingerprint-bound; no client construction/stat sweep/HTTP during build/paint.
  Visible-only scheduled native subprocess work, 15-minute success TTL, one-minute
  failure backoff, coalesced/serialized jobs, exact source existence check,
  complete bounded pagination and generation/account/policy/mount/sleep guards.
  Cache survives failures/disable; a missing source suppresses old membership.
  Only each row's subtree redraws/pages; other modules/timers stay mounted.
  v3 placement config makes older builds fail closed, preserving settings on
  downgrade; existing v1/v2 pages unchanged until explicitly adding a source card.
  One new runtime adapter offset by exact lazy embedding of the pure existing
  folder-label helper: 27/407 helpers/identities, 2,000 API1 path cap unchanged.
  Pins/bootstrap/assets/VERSION/public beta.6/dist/stable1.0, real Bigme and
  server unchanged. Tests/evidence and acceptance gates: TESTING/MERGE_LOG,
  test-results/bookorbit-rows-20261108.
  Frozen **8a5af49b** (runtime 2e6024be), private ZIP **c3fbacca**, 9,593,528
  bytes, exact source and 2,000 paths. Full scripts/43 catalogs pass; final
  sealed 113 roots repeat in Lua/LuaJIT, 18-case frozen native BookOrbit API
  supplement, both 21-case native widget/buffer dashboard checks and actual
  beta.5 native installer/restart/rollback/recovery pass. Public dist remains
  a198828f; physical/live-server gates open. Following receipt is docs-only.

- **1.1.0-beta.6 published 2026-11-08 12:56:30 UTC.** User
  explicitly requests push and a new beta after the local module-library report,
  including the disclosed desktop-only/Bigme gaps. Release branch starts at
  479c4d84. Ship preserved thumbnail reuse, dashboard cards/catalog and the
  already reviewed main backlog since public beta.5; no new upstream merge.
  VERSION beta.6, preview prerelease only; stable 1.0/latest/maintenance and old
  tags/releases/assets are immutable. Component pins stay Bookshelf c014b133 /
  SimpleUI 4426601f. No independent module-catalog release, real device/plugin
  install or server operation. Tests/package/audits precede main/tag push,
  matching CI and verified draft/public bytes. Evidence preview11-beta6-20261108.
  Historical local-only entries below describe their original implementation;
  this authorized release supersedes those publication restrictions only.
  Frozen tag/source **26924cc2**, release **438244122**, public ZIP **a198828f**,
  9,580,403 bytes. All local/full/sealed/native/43-catalog/source/history/secret
  gates and both main/tag CI runs **42482149058 / 42482148698** pass (four jobs).
  Both CI payloads match every frozen runtime file. Draft/public downloads
  match; all 90 older releases/155 tag refs and stable/latest/maintenance1.0
  remain unchanged. Nine actual older installers pass offline native checks;
  eight also pass real anonymous public-HTTPS discovery/download/recovery,
  including beta.5. Public dist is beta.6. Physical full-plugin/Bigme and device
  latency/RSS gates remain open. This following receipt is docs-only.
  Separate observation watch **42482149200** reports Kobold history divergence
  (23 ahead/12 behind baseline 556dad48, merge base 4f725f22); no baseline reset
  or code import. This is not a beta runtime test failure. Silverfish observation
  succeeds; no automatic compatibility approval or independent catalog publish.

- **Local curated module-library prototype; not pushed/released.** User approves
  trying a mini store from the dashboard picker. Branch feature/module-library-20261108
  starts at 82f76b75, preserving previous dashboard/thumbnail work. Separate
  executable core/adapter, SV/EN Get more modules, pinned official Silverfish
  2.0.0 archive 959d6179 (842,889 bytes) and adapter-desktop-only evidence.
  Explicit first installs/next restart; no overwriting existing/manual/legacy
  plugins, automatic latest update/enable/removal, save migration or pet code
  import. JSON inventory intent, bounded source-only ZIP/hash verification,
  hidden owned staging, conservative extra-path conflict checks and changed-file
  unverified status. Independent reviewed modules-N catalog supported but none
  published; explicit check says so. Local observation-only Silverfish mapping
  and release watch never alter catalog pins/approval. Two pure Bookshelf helpers
  are now exact lazy embeds (26/407), offsetting two runtime files within API1
  cap 2,000; component bytes/pins/bootstrap/assets/VERSION remain unchanged.
  Native real-archive desktop smoke passes without starting the pet; full tests,
  sealed package/audits and device gaps recorded in TESTING/MERGE_LOG. No public
  beta.5/dist, stable 1.0, ADB installation, existing plugins or server changes.
  Final executable **3276a058**: both complete scripts pass (134 Python/four
  optional exclusions, 112 roots, 551 Bookshelf/zero fail/three normal native
  exclusions, 13 SimpleUI, 1,189 syntax and 43 catalogs). Sealed roots repeat in
  Lua/LuaJIT, 12 store/18 runtime cases, native official ZIP and both 21-case
  dashboard/Silverfish supplements pass. Actual public Beta 20 API1 installer
  accepts candidate/restart/rollback/recovery; same-version beta.5 correctly
  offers no OTA. Private ZIP **ddd93563**, 9,577,127 bytes, exact frozen source,
  2,000 paths with two helper/new-host path exchanges. History/artwork/secret
  checks pass. Physical full-plugin/UI gates remain open; no publication.

- **Local pluggable Reading dashboard; not pushed/released.** User approves the
  generic module picker proposal with Silverfish as first compatibility target.
  Work on feature/dashboard-modules-20261108 above the preserved local thumbnail
  candidate/receipt 5e4a3468; no upstream/push/publication/device/server authority.
  Extend existing dashboard model/adapters only: public SimpleUI registry cards,
  Bookshelf non-hero-only micro modules, and native QA/custom action shortcuts.
  No per-plugin fork, code/art import, new runtime path/helper or bootstrap/pin/
  version/installed-file change. Picker is reached by +, hold or Cards and content;
  all owned wording/help/search is SV/EN. Explicit per-screen placements use a
  bounded 16-card v2 config (v1 remains unchanged until adding); old builds fail
  closed. Half/full/tall/page sizing and mixed ordering use three-row pages with
  independent paging. Retain original book actions, sources/headings/colours,
  Home/Custom layouts and plugin saves. Missing/failing modules stay removable.
  Build only current-page cards; existing declarative needs feed Home preparation.
  Clip actual widgets with native translated tap forwarding and guarded Lua
  build/paint/input/free. Coalesced per-card refreshes have widget/page/child
  generation guards; private mounted-state proxies preserve ordinary clocks.
  Visible minute hooks/clock hints retire on sleep/park/covered/page/close.
  Registry enumeration is picker-only; no new scan/provider fetch during paint.
  Standalone plugins still own their code, data, timers and possible native risks;
  this is not a sandbox/blanket compatibility promise. Silverfish frozen 2.0.0
  d3da0797b6e51ee73afdb4da6745b297b3a19830 passes real unmodified SimpleUI and
  Bookshelf adapter checks with native minimum/current input and FFI buffers;
  creature/font/asset services are fixtures, not a pet-engine/device test.
  Tests/evidence and physical gates: docs/TESTING, test-results/dashboard-modules-20261108.
  Final executable **7c02737e**; both full scripts/catalogs pass, final sealed
  111 roots repeat in Lua/LuaJIT and 19 ordinary/21 native-Silverfish cases pass.
  Private ZIP **3a72094e**, 9,561,420 bytes, exact source and unchanged 2,000
  API1 paths/24 helpers/407 identities; history/artwork/secret audits pass.
  Public beta.5/dist, stable 1.0, real device and BookOrbit server are unchanged.

- **Local Library-GUI-inspired thumbnail cache maintenance; not pushed/released.**
  User approves investigating metadata/cover reuse after clarifying that the
  performance reference was Library GUI, not Bookshelf's publication-year
  benchmark. Branch performance/library-cache-20261108 starts clean at published
  main d1b6754e (November 7 CI 42421134956 and upstream watch 42421134933 passed).
  No merge/push/release/ADB/server action is authorized by this step. Native
  batched/lazy/shared metadata and canonical RAM/disk/hero/thumbnail tiers already
  exist; do not add a second whole-library index or pretend these are new.
  One reproduced defect: native exact-size thumbnail reuse is FIFO, and each
  entry strongly pins its larger source. Add two small optional renderer seams
  and independent core service using the existing shared LRU, max 96 entries/
  normal 12 MiB budget, weak source identity plus geometry/type/inverse/rotation/
  stride checks. Keep one oversized newest entry usable like other native LRUs.
  Original scaler arguments/pixels/borrowing remain; native source drop,
  dropMemory/contrast, clear and repeated teardown retire only derived copies.
  External owners win; initialization is lazy and existing memory-pressure
  policy applies without saved-setting changes. No new runtime path/helper/
  module-map/pin/bootstrap/version/asset/sync change. Ten standard/eleven native
  minimum/current ImageWidget/grey-RGB/CBB/software cases and synthetic reference/
  work accounting are in TESTING. No ADB device is available; no measured Bigme
  opening-time/RSS gain. Evidence: test-results/cover-thumbnails-20261108.
  External replacement covers also bypassed thumbnail reuse on the warm path:
  twenty repeated smaller-slot renders scaled twenty times. The same bounded
  service now scales once, preserving the native external-file stamp and
  non-fill/standalone fallback. Actual minimum/current ImageWidget control
  and native buffers reproduce 20 -> 1 scaler calls, not a device speed ratio.
  Final executable **20167c74** passes both fresh complete scripts/43 catalogs:
  110 roots, 551 Bookshelf/zero failures/three normal native SQLite exclusions,
  13 SimpleUI, 1,184 syntax; sealed roots and retained native supplements pass.
  Private ZIP **81865063**, 9,548,338 bytes, exact source/2,000 API1 paths;
  source/history/artwork/secrets pass. No push/CI/release/device/server action;
  public beta.5/dist **2cc94f4f** and stable/latest 1.0 are unchanged. Actual
  Bigme opening-time/RSS/visual acceptance remains open; no new ADB connection.

- **Reviewed upstream merge; main push authorized, no release.** User requests
  upstream after the local word suggestions. Branch maintenance/upstream-20261107
  starts at fe284249; origin/main was e0cad59b. Freeze/review Bookshelf 6.3.3
  c014b133 (three commits) and SimpleUI 3.0.3 4426601f (seven commits), imported
  unsquashed in 71894ea3/ac06c803. Keep local POT additions in its one conflict.
  Cover-tab paging gains a measured crop for text/icon feedback, scroll bodies
  keep their own region, and refresh notices wait for panel submission/short
  yield. SimpleUI facets follow native collation while series preserve volume
  order; collection arrangement regains four explicit sort choices with guarded
  current-owner callbacks/native popup identity. Repair only the incoming
  Italian header/plural syntax; no translation text or failure allowance is
  discarded. Popup helper is regenerated as an exact lazy embed: unchanged
  24 helpers/407 canonical identities/2,000 API1 paths. No new runtime module,
  asset, dependency, migration, sync owner or bootstrap/version change.
  Preserve word suggestions/alphabet visibility plus prior profile/Home/Manga/
  series/ornament/BookOrbit/MAL/patch behavior and 1.1 date/delete safety deferrals.
  Local complete scripts/catalogs/sealed/native/source/history/secret gates
  precede the authorized push; main CI is checked afterward. No new beta/tag/release/device/server action;
  stable/latest 1.0 and public beta.5/dist remain fixed. Physical checks remain
  open; see TESTING/MERGE_LOG and test-results/upstream-20261107.
  Final executable **99dd847a** passes both full scripts: 109 roots, 551
  Bookshelf suites/zero failed/three normal native SQLite exclusions, 13 SimpleUI,
  1,182 syntax and 43 catalogs. All sealed roots, nine new cases/ten with actual
  minimum/current repaint/invert/native dialog Close, retained native supplements
  and eight older local installers pass. Sort cancel/dismiss can reopen without
  stale buttons; tests use real PO parsing for wrapped headers and expect 6.3.3.
  Private ZIP **79615586**, 9,542,014 bytes, exact source/2,000 API1 paths;
  history/artwork/secrets pass. Final upstream check: zero missing commits.
  Main-only delivery includes the previously local word suggestions; older
  local-only notes below describe their original implementation step, not a
  separate public release. Public beta.5/dist stays **2cc94f4f**.

- **Local opt-in search word suggestions; not published.** After confirming
  beta.5's alphabet strip now works on Bigme, user requests the next reviewed
  Library GUI idea. The confirmation covers that visibility report only, not
  every theme/font/rotation/sleep checklist. Branch
  feature/search-word-suggestions-20261107 starts at public e0cad59b. Independent
  host vocabulary/completion in the existing search module; no imported engine,
  assets, new runtime path, pin/version/bootstrap/API1 or sync changes. Search
  OrbitUI > Word suggestions is default OFF; hold the toggle for SV/EN help.
  Three native buttons complete only the final word (two-letter minimum,
  cursor at end/no selection), preserving spelling/diacritics and the preceding
  query. Tap fills text with keyboard retained, never searches/opens a book.
  A minimal native repository passive-cursor seam exposes only already warm
  scoped membership/text: no walk/stat/SQLite/snapshot/EPUB/cover/provider/network
  work. Missing current-source cache fails closed, never widens to the profile.
  Suggestions are explicitly partial/cache-only, not guaranteed search hits.
  Vocabulary is ephemeral and bounded; cooperative eight-candidate/8ms turns,
  positive input windows, 180ms typing debounce and bounded prefix lookup.
  Close/sleep/rotation/covered/replaced/navigation/data changes retire callbacks;
  normal Search and Close remain usable. No push/release/device/server action
  is authorized by this step. Verification and physical gaps: TESTING; evidence:
  test-results/search-word-suggestions-20261107. Stable/latest 1.0 and public
  beta.5/dist remain immutable.
  Final executable candidate **8c6e9ec0** passes both complete scripts/43 catalogs,
  108 sealed roots in Lua/LuaJIT, 14 ordinary/16 actual-dialog suggestion cases
  against v2025.08/v2026.03/current and retained native input/alphabet supplements.
  Development ZIP **57c9a4f7**, 9,522,853 bytes, same 2,000 installed paths, exact
  source/manifest; history/artwork/secrets pass. Desktop synthetic checks are
  not device measurements. No publication/device action; dist remains 2cc94f4f.
  Receipt docs do not rebuild or replace that private same-version artifact.

- **1.1.0-beta.5 is public in preview: alphabet-label visibility fix.** User
  explicitly approves publication. Published 2026-11-07 17:17:30 UTC, release
  437717781, frozen source/tag 38cadd99 / v1.1.0-beta.5, ZIP 2cc94f4f
  (9,514,172 bytes). Only measured-label correction below plus version/docs/
  channel regression; no new upstream/components/pins/assets/bootstrap/API1/
  settings/reading-data/sync/device/server change. Both full scripts/43 catalogs,
  107 sealed roots in Lua/LuaJIT, 26 standard/27 raster alphabet cases, actual
  minimum/current TextWidget/input with real bundled-font measurements and
  native SQLite/archive/night supplements pass. Eight actual older local OTA
  installers pass. Main/tag CI 42395143967 / 42395143921 pass all four jobs;
  CI's runtime manifest matches. Draft/public bytes are exact, all 89 older
  releases/153 tag refs unchanged. Preview selects beta.5, stable/latest 1.0
  and maintenance/1.0 stay fixed; public dist matches beta.5. Seven actual older
  installers pass public-HTTPS scenarios (TESTING). User now confirms the strip
  works on Bigme; other physical acceptance remains open.
  Evidence: test-results/preview11-beta5-20261107. Receipt docs never rebuild/
  retag frozen release bytes; earlier local-only notes are historical.

- **Local alphabet-label visibility fix; not published.** User reports beta.4's
  strip responds to dragging but is invisible. Reproduce zero painted letters
  with realistic native line metrics/default padding and with minimum/current
  TextWidget sizing plus bundled Inter's actual FreeType metrics. The old test
  stub capped height at ten pixels and never asserted visible text. Set owned
  label padding to zero, derive label stride from measured regular/bold heights
  and fit actual width/height before painting (including selected slot/bubble).
  Preserve margin/input geometry, scoped jumps, clipped repaint/lifecycle and
  zero metadata reads during drag. Add realistic metric, visibility, selected/
  bubble, DPI/narrow-margin and bounded-cache regressions. Full source/native/
  package checks are recorded in TESTING; physical Bigme confirmation remains
  open. No VERSION/pin/component/asset/bootstrap/sync/device/server/publication
  change. Public beta.4/dist b5692f54 is immutable. Evidence:
  test-results/alphabet-visibility-20261107.

- **1.1.0-beta.4 is public in preview.** User authorizes the next beta with the
  completed alphabet strip below; no additional upstream merge or device/server
  deployment. Published 2026-11-07 15:33:18 UTC, release 437660137, frozen
  source/tag b65e9098 / v1.1.0-beta.4. ZIP b5692f54 (9,509,281 bytes), unchanged
  2,000 API1 paths/bootstrap/components/pins/artwork/sync owners. Both full
  scripts, 43 catalogs, 107 sealed roots in Lua/LuaJIT, native input/raster/
  SQLite/archive and seven older local installers pass. Main/tag CI
  42386627139 / 42386627270 pass all four jobs. Draft/public bytes match and
  all 88 older releases/151 tag refs remain unchanged. Preview selects beta.4;
  stable/latest 1.0 and maintenance/1.0 stay fixed. Public dist matches beta.4.
  Six older actual installers pass public-HTTPS scenarios (TESTING). Physical
  font/gesture/night/sleep/rotation and timing acceptance remains open. Evidence:
  test-results/preview11-beta4-20261107. Receipt docs never rebuild/retag frozen
  release bytes. Older local-only notes are historical.

- **Local opt-in alphabet strip approved; not published.** User asks to start
  with the letter-strip idea after reviewing Library GUI main acda0adb. Branch
  feature/alphabet-strip-20261107 starts at public 13087a61. Independent host
  code, no imported engine/assets or source pin change. Footer counter ▾ >
  Sort, filter & view > Alphabet strip enables it per existing view identity,
  default OFF. Right margin only; existing hero/chips/rows/footer/dock geometry
  is unchanged. Tap or drag/release uses native sort keys and the current
  filtered/boxed list, Å/Ä/Ö distinct and other-script/numeric # fallback.
  No metadata/cover/EPUB reads, book opening or shelf rebuild while dragging.
  Release uses existing explicit scoped producers; not an automatic indexing
  worker. Native module visual slots and variable spine cursors are retained.
  Hide nonalphabetical, single-page, one-series, remote and two-column-list
  contexts; never change sorting to make the strip appear. Guard current owner,
  navigation generation, dimensions, close/suspend/rebuild and deferred jumps.
  Native clipped fast refreshes touch the strip/bubble, not a global paint hook.
  New labels/help are SV/EN. No VERSION/bootstrap/API1/new installed paths,
  settings migration, reading/sync/server/device change or new publication.
  Tests and physical gaps: TESTING/MERGE_LOG; evidence in
  test-results/alphabet-strip-20261107. Physical fonts, drag ergonomics, theme/
  night/rotation, interrupted gestures and Bigme timings remain unaccepted.
  Local source ce918297 passes final sealed roots under both interpreters,
  22 standard/23 raster alphabet cases, native minimum/current input and six
  actual older local installer scenarios; complete scripts/43 catalogs pass.
  Development ZIP 55ca742e is 9,506,144 bytes, same 2,000 API1 paths. Source/
  artwork/history/secrets pass. VERSION/public beta.3 dist dbaa735a remain
  unchanged. No push/release/tag/device/server action. This is not an offered
  beta.3 replacement; receipt docs do not rebuild the frozen private archive.

- **User authorizes reviewed merge and next release: 1.1.0-beta.3 preview.**
  Branch maintenance/upstream-beta3-20261105 includes local Series / Volumes
  commits 37f2d3d/e0763b73. Fresh watch: Bookshelf d47edfcc has no new commits;
  SimpleUI two commits to 4bf2d2c5. Reviewed exact unsquashed import retains
  foreign-menu navpager guard and updated cover-patch catalog; hosted read-only
  compatibility shim remains unchanged, never disabling patches. Regenerate
  the exact embedded helper string, with no new API1 paths or bootstrap/artwork/
  settings/reading-data/sync change. Complete source/sealed/native/installer/
  history/secret/CI/public-byte gates precede publication. Physical Series/
  Volumes and new menu refresh acceptance remain outstanding, not inferred
  from automated checks. Stable/latest 1.0 and old releases stay immutable.
  Evidence: test-results/preview11-beta3-20261105.
  **Published 2026-11-05 11:01:37 UTC**, release 435083775, tag/source
  v1.1.0-beta.3 / cac8233a; ZIP dbaa735a (9,495,686 bytes). Both full scripts,
  43 catalogs, 106 sealed root files under both interpreters, native/SQLite
  supplements and six older local installer scenarios pass. Main/tag CI
  42014846339 / 42014845959 pass all four jobs. Draft/anonymous public bytes
  match; all 87 previous releases/149 previous tag refs remain unchanged.
  Actual Beta 9/29/RC2/stable1.0/beta.2 public-HTTPS installer scenarios pass.
  Preview selects beta.3; stable/latest and maintenance/1.0 remain fixed. Both
  upstream pins are current at final watch; public dist is beta.3. No device/
  server action or new physical acceptance. Receipt docs do not rebuild or
  retag the frozen release.

- **Historical local Series / Volumes implementation before beta.3.** User's
  "Kör!" authorises implementing the two views, not a new upstream merge,
  push/release or device deployment. Branch feature/tag-series-results-20261105
  starts from public 07c1c09d. Group checked tag hits by series/author/profile,
  keep standalone/unknown books visible, preserve volume-level AND/OR and cap.
  Per-origin remembered tabs do not change all-library scope. Manga defaults
  to Series. Reuse warm BIM rows, otherwise bounded read-only text lookups;
  never an EPUB scan or new index. First local series volume may be untagged;
  a tap reveals its pinned series drill/cover/description, never the reader.
  Keep lifecycle guards, SV/EN, native cover ownership, unchanged pins/version/
  bootstrap/API1 inventory/artwork/sync. Tests/evidence are recorded in
  TESTING/MERGE_LOG and test-results/tag-series-20261105. Physical UI/timing
  acceptance remains open. Public preview beta.2 and stable 1.0 stay unchanged.
  Local implementation 37f2d3d passes both full gates, 43 catalogs, sealed
  Lua/LuaJIT roots, 20 actual SQLite series cases and 48 native tag cases.
  Development archive 80743ebb is 9,492,169 bytes with the same 2,000 API1
  paths. No push/release/device/server action; public dist stays 0d033933.

- **1.1.0-beta.2 is public in preview; stable/latest remains 1.0.0.** A last actual
  callback test reproduces a page timer overriding a direct choice. Cancel it
  on direct card/header choice and reject closed-page scheduling. Keep pushed
  beta.1 tag/source `867a1da5` immutable; draft 433577941 is not published.
  VERSION becomes 1.1.0-beta.2 with no extra upstream/data/asset/sync/boot work.
  Repeat complete gates on corrected bytes; previous beta.1 evidence stays
  historical. Evidence: `test-results/preview11-beta2-20261104/`. Stable 1.0 and
  maintenance/1.0 remain fixed; new 1.1 physical UI testing remains outstanding.
  Corrected source `3d908e42` / ZIP `0d033933` (9,482,898 bytes) passes fresh
  complete Lua/LuaJIT/catalogs, both sealed roots/native, actual SQLite and five
  older-installer local scenarios including stable 1.0. Same 2,000 paths/API1,
  24 helpers/407 identities; source/artwork/bootstrap/sync/history/secrets pass.
  Verified unpublished beta.1 draft is deleted; tag/ZIP/metadata/tests retained.
  Main/tag CI, draft/public/channel/immutability/live installer gates remain.
  **Published 2026-11-04 06:38:01 UTC**, release **433586379**,
  `v1.1.0-beta.2` -> `3d908e42`, ZIP `0d033933`, main/tag CI
  **41786359176 / 41786359029** pass. Exact draft/public assets, preview beta.2/
  stable-latest 1.0, all 86 old releases/147 old tag refs and actual Beta
  9/29/RC2/stable1.0 public-HTTPS installer scenarios pass. Both source pins are
  caught up at the final watch. Public dist is beta.2; stable 1.0 bytes and
  maintenance branch are retained. No device/server action or new physical 1.1
  acceptance. Do not rebuild/move frozen sources/tags/assets for receipt docs.

- **Separate 1.1 preview cycle in progress, after stable release.** Approved
  upstream review/imports `a6f8ff31` / `ecd3e0e8` integrate Bookshelf `d47edfcc`
  (53 commits) and SimpleUI `633ffbff` (five). Keep bounded metadata refresh,
  now with completed-fingerprint/group invalidation. New year sort/curated dates,
  book-menu/wallpaper improvements and cache/cover/text fixes remain distinct
  from stable. Defer unsafe unowned automatic file-date forks and premature
  sidecar deletion in new folder-delete while hosted. Preserve standalone
  fallbacks, native/canonical aliases, preload, SV/EN, all art/settings/sync
  owners. Two new exact lazy helpers: 407 identities/24 embeds, same 2,000 paths.
  VERSION 1.1.0-beta.1 is preview only; no new physical acceptance or measured
  speedup. Stable/tag 1.0/maintenance branch stay fixed. TESTING/MERGE_LOG and
  `test-results/upstream-20261104/` hold execution/publication receipts.
  Exact source `867a1da5` / ZIP `877ce353` (9,480,927 bytes) passes both full
  scripts, 43 catalogs, 104 root/549 Bookshelf suites, sealed/native supplements,
  actual SQLite and five older native installer scenarios including stable 1.0.
  Same 2,000 paths/API1; source/artwork/bootstrap/sync/history/secrets pass.
  Fresh watch is caught up. Main/tag CI and draft/public/channel/immutability/
  public-byte installer checks remain gates. Public dist stays stable 1.0.

- **Stable 1.0 promotion and separate 1.1 cycle approved.** The user reports
  RC2 stable/good/ready and says "Kör" to the proposed release strategy. Promote
  exactly RC2's runtime to 1.0.0 after release checks; only version/docs/channel
  regressions change. Do not import the backlog into stable. Fresh observation:
  Bookshelf 53 commits to `d47edfcc`, SimpleUI five to `633ffbff`. Review of the
  fix paths finds no demonstrated stable-release blocker: facts invalidation
  loses derived facts, not original sidecars; render-cap and missing-file/menu
  fixes are useful but do not justify adding unaccepted implementation to 1.0.
  User also approves reviewing/merging upstream afterward into a separate 1.1
  beta cycle. Keep a 1.0 maintenance branch. General RC2 sign-off is recorded as
  reported acceptance, not invented per-scenario/multi-device test results.
  Evidence: `test-results/stable1-20261104/`; TESTING/MERGE_LOG govern receipts.
  Exact stable source `71ba3342` / ZIP `79fec788` (9,444,672 bytes) passes both
  full scripts, 43 catalogs, sealed/native and five actual older-installer local
  scenarios including RC2. Same 2,000 paths/API1; implementation byte-identical
  to RC2. Source/history/artwork/secret checks pass. Main/tag CI, draft/public
  assets/channel/immutability and public-byte installer checks remain gates.
  **Published stable/latest 2026-11-04 06:02:21 UTC**, release **433563970**,
  `v1.0.0` -> `71ba3342`, ZIP `79fec788`; main/tag CI
  **41782513993 / 41782513892** pass. Draft/public bytes, stable/preview/latest
  and all 85 prior releases/143 public tag refs pass. Actual Beta 9/29/RC2
  public-HTTPS installer scenarios pass. Public dist is stable 1.0; no reader/
  server action. Keep immutable 1.0 and its maintenance branch separate from 1.1.

- **RC2 is public in preview; feature freeze continues.** User says "Pusha
  och publicera" after the disclosed local fix/device-test gap. Prepare
  `1.0.0-rc.2` as a preview prerelease only, preserving RC1 and older tags/assets.
  Include exactly the tested tag-lifecycle/shelf-reveal implementation below;
  no new runtime implementation, upstream import or device/server action.
  Feature freeze, pins, API-1 / 2,000 paths and external sync owners remain.
  Repeat exact release-source/full/sealed/native/older-installer checks, audit
  outgoing history/artwork/secrets, then require main/tag CI and draft/public
  exact-byte/channel/immutability gates. Physical Bigme/Boox sleep/index/reveal
  acceptance remains open, not inferred from publication. Evidence:
  `test-results/rc2-20261102/`.
  Exact candidate `e3aa55c8` / ZIP `783431f0` (9,440,887 bytes) passes both
  complete scripts, 43 catalogs, sealed roots/native supplements and actual
  Beta 5/9/29/RC1 installer scenarios, including RC1 -> RC2 discovery/restart/
  rollback/recovery. Same 2,000 API-1 paths; exact source/manifest/pin/artwork/
  history/secret checks pass. Runtime implementation is byte-identical to
  tested `cca558c4`; only release metadata/docs/ordering tests change. Public
  RC1 dist is preserved during staging. Published **2026-11-02 10:12:48 UTC**,
  release **431307659**, tag `v1.0.0-rc.2` -> `e3aa55c8`. Verified main
  `e0229482` CI **41426196528** and exact-tag CI **41426197224** pass both
  matrix jobs. Draft and anonymous public ZIP/checksum match `783431f0`;
  public dist is now those RC2 bytes. Preview advances RC1 -> RC2, stable
  remains absent; all 84 previous releases and 141 old tag refs are unchanged.
  Native actual Beta 9/29/RC1 installers also pass discovery/download from
  public HTTPS assets, activation/restart/rollback/recovery/snapshot/cleanup.
  Documentation-only receipts do not rebuild the frozen source/tag/assets.
  No device/server action; physical acceptance remains open.

- **RC1 tag-search lifecycle fix and shelf reveal, now included in public RC2.**
  User reports the visible offline tag search stuck at 2,090/3,341 after device
  sleep; Stop search and Close highlight but do nothing. No ADB device is
  connected. A synthetic navigation-generation change while that modal remains
  shown reproduces both dead controls and a stopped worker at the same counts
  under Lua and LuaJIT; the index manager has the same stale-Close condition.
  This confirms a code path, not that sleep caused the user's exact incident.
  User explicitly approves the fix and a narrow UX change during the freeze:
  tag-result title taps reveal/select the book on its shelf, not ReaderUI.
  Close now checks view lifetime rather than expired work ownership. Retired
  work releases busy/index ownership; sleep pauses without painting/autoresume.
  Existing successful cache entries survive; stale views explain reopening.
  Offline and online tag results use a guarded native-profile/folder/page
  reveal, with collapsed-size pagination and target anchoring in spine mode.
  Explicit preview avoids native _previewBook's second-call reader opening;
  long-press details and unrelated reader/search callbacks remain unchanged.
  Native local-file checks/supersession/missing-target/active-reader guards,
  SV/EN help and regressions are added without new installed paths, component
  source/pin/default/bootstrap/assets/sync/reading-data changes. Both complete
  scripts and 43 catalogs pass; latest targeted/native archive/SQLite/UIManager
  tests also pass on exact sealed source `cca558c4`, private ZIP `61b90676`
  (9,438,262 bytes), same 2,000 API-1 paths. Exact source/manifest/bootstrap/
  component/pin/artwork/history/secret audits pass; status-import implementation
  remains byte-unchanged. Public dist stays RC1 `dfc2cced`, not the private
  same-version verification archive. Device sleep/
  full-library/reveal acceptance remains open. At that local implementation
  stage no release/push/device/server action was authorized; the separate RC2
  publication approval above supersedes only the push/release limitation. Evidence:
  `test-results/rc1-tag-fix-20261102/` and earlier diagnostic reproduction.

- **RC1 is public in preview; feature freeze active, not stable 1.0.** User approves the
  proposed RC1 direction; VERSION becomes `1.0.0-rc.1` on
  `release/1.0.0-rc.1-20261102`, based on `bf59c980`. Exact reviewed component
  pins remain Bookshelf `b512cd90` / SimpleUI `fdf83c7d`; no feature import,
  migration/default/sync change or runtime implementation. Existing status-report
  changes are included. README/OTA/migration and the RC acceptance plan are
  updated in existing paths; same 2,000 API-1 files/bootstrap/assets/languages.
  RC discovery/major-version ordering/preview-only behavior get explicit tests.
  User separately approves "Publicera RC1 efter tester" as a preview GitHub
  prerelease; neither preparation nor CI is stable 1.0/device acceptance.
  No ADB device is connected, so all physical RC1
  gates remain open. See TESTING, MERGE_LOG and `test-results/rc1-20261102/`.
  Exact candidate `66410c3b` seals as `dfc2cced` / 9,430,364 bytes, exactly
  2,000 API-1 paths. Both full scripts, 43 catalogs, sealed/native supplements,
  Beta 5/9/28/29 old-installer scenarios and source/history/secret audits pass.
  Runtime implementation/pins/assets/bootstrap are unchanged from reviewed main;
  only metadata/docs and monitoring configuration/tests change. Published
  **2026-11-02 06:05:57 UTC** as `v1.0.0-rc.1`, source `66410c3b`, release
  **431117603**, prerelease only. Verified main `a7781a9e` CI **41397184439** and
  exact-tag CI **41397184468** pass both matrix jobs. Draft and anonymous public
  ZIP/checksum downloads match the sealed bytes; preview selects RC1 and stable
  stays absent. All 83 previous releases and 139 old tag refs remain unchanged.
  Native Beta 9/28/29 installers also pass discovery/download from public HTTPS
  files, restart/rollback/recovery/snapshot/cleanup. Public dist is now RC1
  `dfc2cced`; verification receipts do not rebuild it. No device installation or
  server change; the physical RC checklist remains open.

- **Bookshelf-OS retired from active inspiration monitoring.** User explicitly
  requests removing the unavailable reference. GitHub's fresh API returns 404;
  this does not distinguish deletion from a private repository. Prior Inspiration
  watch `41282377404` has a Bookshelf-OS fetch failure. The separate Upstream
  watch `41393454748` instead rejects a stale `main` report. Only the configured
  Bookshelf-OS source is removed; the five remaining reference mappings/pins,
  monitor guards and historical attribution stay intact. OrbitUI settings cards
  and quick controls are not removed. Offline filtering/removal tests and a
  fresh five-reference read-only collection pass. User also approves moving
  toward RC1/feature freeze; preparation and publication gates are tracked
  separately. No device is currently connected through ADB.

- **Reviewed documentation-only Bookshelf merge, now included in RC1.** Fresh
  05:07 UTC check finds exactly two commits through
  `b512cd906cc494cc8d32ed6b9bdb582c12fe1078`; SimpleUI `fdf83c7d` is current.
  Unsquashed import `1882a227` changes only module README API-release/surface/
  sizing guidance. No runtime, dependency, asset, migration or hook changes.
  Keep all hosted contracts, plus the previously local status-report follow-up
  below. Standing authorization covers the audited verified main push, not a
  release/OTA/device/server operation. VERSION and public Beta 29 assets stay
  unchanged. Tests/package/audit results: TESTING/MERGE_LOG and
  `test-results/upstream-20261102/`. No new visual change or measured speedup;
  physical status-view and original skip-reason acceptance remain open.
  Candidate `c2237ca3` / private ZIP `be284f81` passes both full scripts,
  43 catalogs, both sealed roots/native suites, four older-installer scenarios
  and exact 2,000-path/source/history/secret checks. Fresh watch shows zero
  missing commits. Public dist `60fc00b3` is restored. Audited fast-forward
  main `cb976654` includes the status-report work. CI **41392861973** passes
  both matrix jobs, including Linux native OTA; upstream-watch **41392861974**
  passes. This documentation receipt does not rebuild private/public bytes or
  authorize a beta/tag/OTA/device/server action.

- **Status-import reporting follow-up, now public in RC1.** User approves fixing
  the misleading "0 updated, 469 protected or conflicting" summary. Existing
  import/write rules, OFF default, batches/throttle/owners remain unchanged.
  New SV/EN details separate unchanged server/local status, missing local files/
  data, protections, newer-local conflicts and not-imported statuses; uncertain
  dates are labelled protection. Native read-only viewer; no extra metadata I/O
  for reports or canonical-unchanged entries. Counts only persist; at most 50
  sanitized filename/reason samples stay in memory. Old reports ask for a fresh
  check instead of inventing reasons. No diagnosis of the user's particular 469
  entries without device evidence. Beta 29/version/pins/public bytes remain
  unchanged; no push/publication/device/server operation in this step. See
  TESTING/MERGE_LOG and `test-results/status-report-20261101/` for verification.
  Candidate `e3f2ce14` / private verification ZIP `10568ac9` passes both full
  scripts, 43 catalogs, 28 importer supplements (including 1,080 unchanged
  Beta 29 decisions), sealed/native/package/source checks at exactly 2,000
  paths. Public dist `60fc00b3` is restored. New physical viewer acceptance and
  this device's actual skip causes remain open. Do not release the private
  same-version test ZIP as replacement Beta 29 bytes.

- **Beta 29 is public**, source/tag `98be962a` / `v0.1.0-beta.29`, published
  **2026-11-01 21:59:45 UTC** after the explicit user request and disclosed
  physical-device gaps. Main `48234e73` / tag CI **41354378033 / 41354377995**
  pass all four matrix jobs, including native Linux OTA. Publishes the reviewed
  Bookshelf 6.2.0 (`78f582fd`) contrast/footer/menu/swipe/minute/RGB changes;
  SimpleUI stays `fdf83c7d`. No additional import/implementation in publication.
  ZIP `60fc00b3` / 9,414,999 bytes passes both full scripts, 43 catalogs, sealed
  roots/native supplements and four older-installer gates, same 2,000 API-1
  paths. Draft **430882883** is downloaded/byte-checked before publishing those
  exact assets. Anonymous public ZIP/checksum match; preview selects 29, stable
  stays absent. Public-byte native upgrades from Beta 9/27/28 pass restart,
  rollback, recovery, external snapshots and cleanup. All 82 prior releases
  and 137 old tag refs are unchanged. Source/manifest/bootstrap/artwork/history/
  secret checks pass. Documentation-only receipts do not rebuild public bytes.
  Existing Home/Manga/profiles/series/art/settings/sync/patch owners remain.
  No connected ADB device/install, server deployment, importer opt-in or new
  sync owner. New physical Bigme/Boox contrast/footer/swipe/night/minute checks
  and measured timing remain open; beta publication is not device acceptance.
  Exact evidence: TESTING and `test-results/beta29-20261101/`.

- **Reviewed Bookshelf 6.2.0 merge-only stage (now in Beta 29).** The user's next
  "Merga upstream" request integrates 23 commits through exact master
  `78f582fd8e4f2612b2d41498e6878af90d30f31e`, unsquashed import `dc77c11a`.
  SimpleUI `fdf83c7d` is already current. Adds opt-in image/wallpaper contrast,
  Show/Hide/Invisible footer modes, less flashing for shelf menu/theme changes,
  slider/swipe fixes and minute callbacks for explicitly configured modules.
  Retain OrbitUI's night-tone/inverse guards, profile-qualified theme identity,
  series artwork/aspect/cache ownership, custom footer sizing/margins and dock
  geometry. The new global menu-close hook is host-owned/released; late minute
  callbacks cannot repaint a different/hidden shelf. Two exact-source lazy
  helpers fit the existing registry (22 embedded, 405 canonical identities),
  not extra installed paths. New labels/help are SV/EN. VERSION/public Beta 28,
  bootstrap, all artwork, SimpleUI source, reading/settings/sync owners and
  BookOrbit server stay unchanged. Candidate `b3fd8887`, private ZIP `5ff334e2`
  passes both full scripts, sealed/native/package/history and four older-beta
  installer gates. Exact 2,000 paths and public dist `3fd75c19` are retained.
  Audited main push `c5656b02` is complete; upstream-watch run `41351394509`
  passes. Runtime CI is tracked at `41351394477`; see TESTING/MERGE_LOG. No fresh
  physical Bigme test or measured performance improvement is claimed.

- **Companion server now published/deployed, separately from Beta 28.** User
  explicitly requests publication and deployment, and approves the modified
  build name Littex with BookOrbit attribution. Extras **v0.3.0** pins
  `644640a8`, published **19:52:52 UTC**; all six CI jobs at **41341624599**
  pass. The existing installation's legacy-0101 undo source is reproduced
  exactly, then only the read-status API plus Littex/full-source notices are
  added. No schema/migration/lockfile change or generic-0132 replacement.
  Exact complete source `819daf51`, published archive SHA `4f3149cf`, runtime
  image `sha256:2a1a4f9b7de2ed7b12bf550543bf1c1ca334293aeeb2955ddb08f9c42f01ce6b`.
  Deployment **19:54:13 UTC** is healthy. Fresh backup restores all 177 table
  fingerprints; 13 real undo DB tests and authenticated status acceptance
  pass on an isolated outbound-blocked copy. Production loopback/public HTTPS
  GET acceptance returns exact canonical statuses, rejects anonymous/invalid
  requests and preserves 12 protected tables. Existing undo, data mounts,
  credentials/PWA overrides/assets and unrelated containers are preserved.
  Full source/legal notices are live in SV/EN. The generic all-source archive
  separately uses 0132 and is NOT the existing server's upgrade image.
  No device change, client opt-in or actual remote reading-status mutation.
  Physical status-import acceptance remains pending. Private server evidence
  is in bookorbit-extras/test-results/status-release-20261101; public receipt
  is Extras VERIFICATION.md. OrbitUI changes here are documentation only:
  VERSION, runtime, upstream pins and all Beta 28/public bytes stay unchanged.

- **Beta 28 is public**, source/tag `e9d3e084` / `v0.1.0-beta.28`. Reviewed
  Bookshelf `0d976875c47f786c1a6df55591f36fb3153554b6` is integrated through
  unsquashed `ceb86a6d`: OPDS 1.x/2.0 catalog publication years, no new paths,
  settings/hooks or assets. SimpleUI remains `fdf83c7d`, already current.
  Includes the previously local status importer described below, still OFF.
  Its companion Extras/API code was still local at beta publication; the
  separately approved server follow-up above supersedes that limitation.
  Beta 27 public bytes remain immutable. Fresh ADB inventory has no devices;
  physical OPDS/status layout/timing is not accepted. Exact evidence in TESTING.
  User explicitly approves publication with these device limits. Candidate
  `e9d3e084`, sealed ZIP `3fd75c19` / 9,376,824 bytes passes both full suites,
  43 catalogs, both sealed root/native supplements, exact source/path/artwork/
  secret audits and older Beta 5/9/26/27 installer scenarios. No rebuild of
  these bytes for verification-only docs. Main `f0665548` / tag CI
  **41337249777 / 41337305703** pass both jobs each. Draft **430776228**,
  anonymous published ZIP/checksum and native public-byte OTA from Beta 9/26/27
  all pass. Preview selects 28; stable stays absent. All 81 previous releases
  and 135 old tag refs remain unchanged. Published **2026-11-01 18:38:40 UTC**.
  At beta publication there was no device install/server deployment and Extras
  remained local at `ab47cd2`. The server follow-up above is separate.
  Verification docs do not rebuild the public archive.

- **Status-import implementation history (client now in Beta 28).**
  Original local approval covered the client and a local read-only API addition
  in `bookorbit-extras`, not deployment. The later server approval/publication
  is recorded above; the OrbitUI client is public as above. Host lifecycle
  schedules work after paint, opt-in defaults OFF. GET-only 200-ID batches,
  15-minute attempt throttle, saved native matches only; no library traversal,
  document engine, cover work or new runtime path. Child reads are nonrepairing;
  parent atomically publishes at most four changed sidecars per turn, preserving
  positions/history/rating/review, and acknowledges canonical status with the
  existing native state manager. Same-day/newer/unknown local conflicts,
  open/parked reader, pending Undo, stale accounts/links, competing sidecar
  copies and existing temp files fail closed. Caches invalidate without an
  automatic heavy shelf/Home rebuild. Existing native sync preferences remain
  unchanged. Settings/help SV/EN under Integrations > BookOrbit, Update now,
  last success and session outcome. Server `status.patch` targets exact 3.6.0
  `a96ff0c`; no migration or production changes. ADB has no connected device;
  physical latency/rendering/acceptance is still pending. The original local
  stage preserved Beta 27's source/version/ZIP and upstream pins.
  Runtime source **`f3aa3ff6`** (includes persistence/callback containment),
  Extras **`ab47cd2`**, exact server implementation **`6cb2feb2`**. Private
  validation-only ZIP **`6ad7b4b8c4bc2c013f8aa77fb8765bf94b50b8f9a37c26da3be4112f0ab86aec`**,
  9,373,240 bytes; exact source projection and unchanged 2,000 API-1 paths
  pass. Both sealed status suites pass 17 cases with the pinned native payload
  builder; minimum/current native input forwarding passes. Evidence:
  `test-results/status-import-20261101/`. Do not replace public Beta 27 bytes
  with this same-version local test archive. That stage had no device install/
  push/release; the separate versioned Beta 28 publication supersedes it.

- **Beta 27 is public**, source/tag `617848a8` / `v0.1.0-beta.27` after the
  explicit request to build all-library indexing and publish pending work.
  ZIP `7f4d19ba5d544a8659c526a8ff5b8bd66e4762cc04285614dd224768ded2b05d`,
  9,359,164 bytes, same 2,000 API-1 paths. No extra import: Bookshelf `c686f5a3`,
  SimpleUI `fdf83c7d`. Publishes the formerly local app-pager/native-dialog/
  metadata-cover fixes, offline aggregate/progressive tag search, smart AND/OR
  chips and the resumable global index manager under Settings > Bookshelf.
  Update reuses valid cache entries; confirmed Reread supports same-run resume
  after restart. No 400-file index cap; match views retain their 400-hit notice.
  Disposable index/journal/snapshot revision only; no book/reading/server write,
  cache wipe, new runtime path or sync owner. All controls/help SV/EN.
  Final full Lua/LuaJIT, 43 catalogs, sealed/native/real SQLite, exact source/
  history/secret and local/live anonymous old-installer OTA gates pass. Main
  `fd70572a` / tag CI **41322288961 / 41322288865** pass all four jobs. Draft and
  anonymous public downloads match; preview selects 27, stable remains absent.
  All 80 previous releases and 133 old tag refs are unchanged. Evidence:
  `test-results/beta27-20261101/` and `test-results/tag-index-manager-20261101/`.
  Installed/accepted on Bigme with `6df633e0` rollback; all 2,000 hashes before/
  after pass. Real inventory 3,341; actual Pause, Continue after restart, native
  SV layout, reread confirmation/Cancel and Home/Quit pass. Job is paused at
  1,780, NOT complete. Full cold/reread, repaint stress, smart-chip UI/English/
  Boox and broader 1.0 acceptance remain open. Reader/sync choices restored;
  history/50-row queue/BookOrbit state byte-identical. Diagnostic inactive,
  KOReader closed. Verification-only descendants never rebuild public bytes.

The following bullets record historical pre-release stages, not additional
unpublished runtime work after Beta 27.

- **Smart EPUB tag chips are a LOCAL follow-up, not a new public beta.**
  User approves the proposed first stage: hold an offline Tags pill to create
  a named chip in an existing enabled library, with literal AND/OR rules (up to
  16 tags), selected-library/all-local scope and SV/EN editing. No virtual root,
  book move/copy/tag write, server-only tag alias, sync writer, upstream import,
  version bump or new installed file. Saved rules use existing profile settings;
  bounded derived snapshots use the existing independent EPUB-tag cache.
  Rendering reads validated saved matches only. The visible chip defers a
  cache-only, owner-safe incremental check (60s throttle); missing/changed EPUB
  archives require explicit swipe-down/settings Update. A native measured footer
  says Indexed (400+ when capped); settings explain incompleteness. Reuse native
  explicit-path filtering/sorting/page/cover hydration and existing Home pins.
  Manual updates retire automatic work; reader opening rechecks cached results
  without blocking unrelated global-search routes or parked-reader returns.
  Clean implementation `9bd76331`, private ZIP `969b908f` (9,351,377 bytes),
  exact source/hash/held-art and identical 2,000-path audits pass. Sequential
  full Lua/LuaJIT gates, all final 100 root files, 43 catalogs, both sealed
  11-suite passes (12 chip/30 native EPUB cases) and six real SQLite cases pass.
  Details/limits in TESTING; no device install, push or publication. The preceding installed
  `711d507e` / `6df633e0` candidate below is unchanged on Bigme.

- **Offline index/progressive results are installed as a LOCAL test candidate.**
  Final source `711d507e`, exact ZIP
  `6df633e02b10dbad03341e3fd71de94cdac6fb05916b1c5b72a5c7ddaa7c50d5`.
  All 2,000 paths verify before/after; bootstrap pending=0, known-good step-1/2
  `2ac22d61` remains rollback, NOT either rejected intermediate. Public Beta 26
  bytes/version/pins/assets/installed paths stay unchanged; no push/release.
  Actual native Stop touch works during the real 3,342-EPUB all-profile scan
  (including the synthetic origin): cancels at 1,706, checked partial match stays;
  real Refresh revalidates/advances, and real partial selection retires work and
  invokes a guard-only opener without opening any document. Normal Home/Quit
  passes. Whole-library completion/actual reading/rotation/panel/Boox/1.0 remain
  open; cold Manga metadata stays slow. 1,734 durable index rows, quick_check OK.
  Visible progress reserves 50ms for input; nonpainting cache batches keep 1ms.
  Final full LuaJIT and both sealed/native root gates (25 tag/five real SQLite
  cases), preceding full Lua and 43 catalogs pass; TESTING states exact limits.
  Original reader/sync/lastdir restored and pushed hashes match; retain only
  normal patch-manager timestamp/read-only Hardcover goal-cache refreshes.
  History/50-row KOSync queue/BookOrbit state are byte-identical. Diagnostics are
  inactive, fixtures outside roots, KOReader normally CLOSED with final local
  slot installed. Preserve exact tested bytes across verification-doc descendants.
  Evidence: `test-results/tag-index-20261101/`.

- **Offline aggregate index / progressive results follow-up (local).** User
  says Gå vidare after the installed step-1/2 candidate; no push/release/import
  authorization. Work starts at `56924edc`, same branch. Host integration/search/
  i18n only: separate lazy derived SQLite index, 128-path parameterized reads,
  native stat validation, <=32-entry checkpoint transactions, known-empty rows,
  no negative errors and existing-index updates on single-file reread. A small
  keyed-cache generation marker retires old SQL rows after faults/marker loss;
  fallback never deletes caches or touches BIM/reading data. Inline progress
  exposes only checked partial matches, marks incompleteness and supports Stop/
  Refresh/partial open/close/navigation retirement. Clicked local EPUB first,
  all profiles/depth still included. No new installed file, version, component
  pin, asset, sync owner or BookOrbit API change. Focused Lua/LuaJIT plus real
  native-SQLite tests cover these contracts. Preliminary actual-native Bigme
  300-file warm worker comparison: previous step 186.3/280.4/260.1ms vs index
  56.2/75.4/74.4ms; medians 260.1 ->74.4ms (~3.5x). Separate cache reads 300->1,
  no archive opens/skips; initial index fill 687.7ms. Enumeration/UI excluded;
  do not multiply with prior-run speedups or claim first-library completion.
  First sealed candidate `5148c077` / ZIP `01008d9b` passes desktop/package
  checks but is NOT accepted: actual all-profile inventory is 3,342 EPUBs, and
  a repaint/1ms scheduling cycle starves touch under slow Manga reads. Timed
  footer callback stop at 980 retains a partial match; Resume revalidates the
  cached prefix, but actual tap/Back cannot stop it. Force-stop only the test
  process (no book opened, sync paused), leaving the atomic derived index intact.
  Fix drains native repaint before scheduling the continuation. A regression
  using actual native handleInput/_checkTasks/forceRePaint fails old source
  (3 archives before input vs expected 1) and passes both interpreters after
  repair. A second candidate `b9c07cff` / `7631ca9d` drains paint but still fails
  actual touch: Android's remaining frame bookkeeping can exceed 1ms. It is
  force-stopped as an owned test, not accepted. Reserve a 50ms input window only
  after visible updates; cached no-paint batches keep 1ms scheduling. Strengthen
  the native regression with 5ms bookkeeping even when no paint is pending.
  New sealed bytes/device touch acceptance and restoration follow;
  never classify the first candidate as ready. Evidence:
  `test-results/tag-index-20261101/`.

- **Offline tag-search optimization, local step 1/2 (not published).** User
  approves cache-aware Refresh and bounded cache-hit batching before an aggregate
  index. Ordinary result Refresh no longer forces every archive to reopen;
  changed/new/missing/unreadable files are still rechecked. A separate confirmed
  SV/EN reread-all action bypasses the cache. Workers process at most 32 hits /
  8ms, one uncached archive per turn, with a positive 1ms input yield. No schema,
  namespace, file slot, component pin, sync owner, version or public ZIP changes.
  Seventeen focused cases pass both interpreters; full Lua/LuaJIT and 43 catalogs
  pass. The known macOS long-TMPDIR fixture issue is reproduced, not changed;
  repeat full runs use documented TMPDIR=/tmp. On Bigme, isolated actual-native
  queue/archive/zstd scans of the same 300 cached local EPUBs take old
  4174.8/3731.7/3734.6ms vs new 542.8/611.1/561.9ms, zero archive opens/errors.
  This is a warm 300-file worker comparison, not whole-library cold completion,
  tap-to-paint or whole-library acceptance. Exact source `a936b718`, sealed local
  ZIP `2ac22d61f6cdd7eeba95e35e7855b7f5479e326d60136bdf6b7bf19e391521d5`
  is installed/accepted with pending=0 and preceding `4d66d68a` local fixes as
  rollback; all 2,000 paths verify before/after. Sealed-root suites pass both
  interpreters. Native SV modal tests use an isolated two-fixture catalog:
  matches, normal Refresh, cancelled confirmation, confirmed reread and Close
  pass; no book opens. Both diagnostics are outside patches and KOReader is
  normally closed. Both sync flags and original lastdir are restored/hash-verified;
  only Ereader Patch Manager's normal check timestamp is retained. Original
  history, 50-row queue and BookOrbit sync state remain byte-identical. Public
  archive is unchanged; no push/release is authorized. Aggregate indexing and
  progressive result presentation remain later steps. Private evidence:
  `test-results/tag-performance-20261101/`.

- **The three acceptance fixes are implemented and locally device-tested.**
  Exact source `1502f632`, sealed local ZIP
  `4d66d68a5a74bc89e0667f997ce11c7e7b9b9f74658c6f508ac65c81794be221`;
  no version bump, push, publication, upstream import or public ZIP replacement.
  Bigme accepts this separate slot with pending=0 and public Beta 26 as rollback;
  all 2,000 installed paths verify before/after. Seven-app paging/hold works
  and survives restart. Offline EPUB tag loading and actual scan cancellation
  work; whole-library search is still too slow for acceptance (cache entries
  advance, but the long first scan is explicitly cancelled, not marked passed).
  Eight single-book refreshes (SVG/PNG/JPEG/coverless, safe mode off/on) commit
  without extraction warnings or cover loss; reopen/restart keeps the covers.
  Both full suites, all 43 catalogs, sealed roots, native minimum/current input/
  pager, EPUB/archive, raster/night and real SQLite supplements pass. Restored
  original six-app/unset preference, safe mode off, navigation, last-file/fonts,
  sync and own history/Hardcover additions only; all six restoration hashes
  match. Old reading rows/events, all 50 KOSync queue rows and BookOrbit sync
  state are unchanged; one permitted synthetic statistics book remains.
  Fixtures are archived outside roots; KOReader is normally closed. Initial
  premature activation during copying caused a failed startup; it is excluded,
  then all files are verified before a clean retry. Details/limits in TESTING;
  do not claim full tag-result, UI-polish or 1.0 acceptance.

- User authorizes fixing the three acceptance findings and retesting, **not**
  push/publication or another upstream merge. Branch
  `fix/beta26-acceptance-20261101` starts at `8f0ceff2` with the preceding local
  acceptance notes. Restrict the app pager to its first return; honor explicit
  `sui_native` ownership in native-widget interception. On Android, explicit
  single/bulk metadata refresh uses the existing transactional no-fork queue
  even with safe mode off; automatic extraction and the saved preference stay
  unchanged. Switching safe mode off drops only automatic queued work, not
  explicit refreshes. New tests fail on the old code and pass after the fixes,
  with real pager/input and interceptor/request boundaries; cover tests include
  both preferences, failure/coverless retention and mixed queued work. Both
  full interpreter gates pass. Separate sealed candidate/device verification
  follows; never overwrite the immutable public Beta 26 ZIP or claim a device
  repair from headless results alone. Private evidence:
  `test-results/beta26-acceptance-fixes-20261101/`.

- **Beta 26 Bigme device acceptance is NOT complete; two blockers reproduced.**
  The exact public ZIP is installed/accepted (pending=0), and all 2,000 runtime
  paths verify before and after testing. No runtime correction, upstream import,
  push or publication in this pass. Seven Android apps trigger a native input
  crash: `PageNav.buildPager`'s second return becomes a bare container child;
  the old one-return pager fake missed it. Offline EPUB tag requests also fail:
  the native-widget interceptor replaces their `sui_native` InfoMessage, so
  `isWidgetShown(original)` is false, parsing self-cancels and the toast stays.
  Focused unchanged-source diagnostics reproduce both boundaries. Metadata
  refresh no longer crashes, but drops previously visible SVG covers for both
  an opened and unopened synthetic EPUB; raster-cover/safe-mode controls remain
  open. Book details, page turning, native fast-close to the correct profile/
  folder, basic Home/Library/Manga navigation, day/night framebuffer rendering,
  quick-controls Wi-Fi settings launch, and settings-root/app menus in SV/EN
  pass. This is not a full deep-menu, physical e-ink or stress acceptance.
  User-approved synthetic books only; pre-existing statistics rows/events are
  unchanged. An initially overlooked legacy KOSync writer attempted a failed
  synthetic-book push before being paused; its one owned queue row and a local
  Hardcover autolink were removed after proving all old entries unchanged.
  Original sync/language/navigation/app choices are restored and hash-verified,
  all 50 old KOSync queue rows retained, fixtures archived outside the library,
  KOReader left normally closed. No successful remote test write is confirmed;
  do not describe this as zero attempted network writes. Details/remaining
  checks: `docs/TESTING.md`; private evidence:
  `test-results/device-acceptance-beta26-20261101/`.

- **Beta 26 is public**, exact candidate/annotated tag
  `96e10fbf9e7b4703810f87908df39a9da7bc2229` / `v0.1.0-beta.26`.
  It publishes the reviewed Bookshelf **6.1.1** import (`c686f5a3`) and the
  formerly local Beta 25 Android apps/metadata and measured library/input/card
  fixes. SimpleUI stays `fdf83c7d`. Main/tag CI **41290954328 / 41290954313**
  pass all four jobs; the upstream watcher also passes. Both full interpreter
  suites, 43 catalogs, sealed/native input/EPUB/raster/span/Trapper checks,
  old-installer OTA and exact source/path/history/held-art/secret audits pass.
  ZIP SHA-256 `6800190ab077407f2fa5d42bc276ee52fdcb6ca33b44441a389fe1571f92817d`,
  9,316,969 bytes / 27,516,914 expanded / unchanged 2,000 API-1 installed files.
  Draft/public downloads match; live anonymous native-TLS upgrades from Beta
  9/24 and the actual local Beta 25 pass recovery/rollback/cleanup. Preview
  selects 26; stable stays absent. All 79 older releases and 131 old tag refs
  remain unchanged. Evidence: `test-results/beta26-20261101/`.
  At publication ADB was disconnected; the later physical final-package pass
  above now records partial acceptance and blockers. Earlier Bigme measurements
  apply to the pre-import performance candidate, not a controlled 26 benchmark.
  Undo-opening fix is separately public in Ereader / BookOrbit Extras **0.2.1**,
  not embedded or automatically deployed by OrbitUI. Existing history/server
  state is unchanged. Verification-only descendants never rebuild public bytes.

- User explicitly requests publication of the Undo-opening fix, then an upstream
  merge and the next OrbitUI beta. Ereader `30ded4e` and BookOrbit Extras
  `4c7e1b2` are pushed; Extras **0.2.1** is public, with exact patch/checksum
  verification. It preserves future same-cover reloads without reopening done
  rows or repairing the earlier accidental reading. No server/device change.
  OrbitUI preparation starts clean at `480dc52b` on
  `release/upstream-beta25-20261101`. Reviewed Bookshelf **6.1.1**
  `c686f5a36af134e778e8e1172be75ead76b08168` imports two commits in unsquashed
  subtree merge `f27d98fa`, without conflicts; SimpleUI stays `fdf83c7d`.
  The self-sized picker height fix preserves the stateless-pager host guard.
  VERSION becomes **0.1.0-beta.26**, not an in-place replacement of the local
  25 or any published release. Include the previously unpublished Android apps,
  metadata safety and measured library/input/category-card fixes. Full/sealed/
  native/OTA/source/history/secret gates must pass before publication. Current
  ADB lists no device; new final-package/picker/app-edit and broader metadata
  acceptance stay explicitly open. The new publication request supersedes the
  old publication pause, not the evidence limits. Final release facts follow
  in MERGE_LOG/TESTING; do not rebuild already sealed bytes for verification docs.

- Overnight pass has a tested local candidate at `6271a6f2`, sealed ZIP
  `443fa966cde4df35ce86126b5dd23d9c3c1e04efe68244b8d080eab7af267c4d`.
  Full Lua/LuaJIT, catalogs, sealed/native/OTA/source gates pass. All 2,000
  installed paths verify on Bigme; bootstrap accepts pending=0, previous
  b9d423f2 retained. No push/release/upstream merge. Detailed samples/limits
  in TESTING: first Manga median 15.76 -> 6.175 seconds (three first-profile
  visits each, old-runtime control returns to 14.9); fresh Library 1.669 ->
  0.732 seconds (one matched trial). Warm Manga not improved; metadata-refresh
  re-derivation still ~5.9 seconds. No RAM/e-ink-panel benchmark claim.
  All five settings cards/categories/Back work physically after the stateless
  pager fix; Android module hold/real launcher picker/cancel and Quick Controls
  Wi-Fi/Battery Close/status-area routes pass. English is headless-only;
  app edit persistence and broader metadata-refresh acceptance remain open.
  Ereader Patch Manager's separate first-tap DROP and native date/power display
  issues remain outside these fixes. Diagnostic patches are inactive.
  A menu-test accident opened one book at cover; its registered undo row is
  already done, so Undo was unavailable. A targeted repair question is pending;
  do not reset history, assume it was undone, or claim no reading-state writes.
  Verification-only descendants must not rebuild the exact tested archive.

- User authorizes an overnight Bigme ADB performance/menu pass, measured
  optimizations and device retesting, NOT a push/release or upstream merge.
  Start clean at `76876d44`, branch `performance/bigme-library-20261101`.
  The accepted shortcut-only Beta 25 slot is the baseline; the later Android
  app-management candidate is not installed yet. Device cold Manga navigation
  takes roughly 15–17 seconds, versus warm rebuilds around 0.2 seconds.
  Temporary read-only instrumentation attributes ~4.8 seconds to the grid-label
  counterfactual and ~3.2 seconds to duplicate global/scoped metadata derivation
  for series boxes. Do not confuse rebuild time with tap-to-paint latency.
  Build a 4,096-entry/60-second in-memory text derivation pool per BIM row batch,
  preserving separate deep-copied scope records, original prefix checks, retry
  behavior and all native invalidations. A narrow optional producer seam keeps
  standalone behavior. Label measurement uses the existing light-record path
  without recursive folder collage preparation; restore both flags/cursor even
  when the native protected pin catches a fetch error. Three physically observed
  missing menu translations gain SV/EN support; saved personal action labels
  are not rewritten. No new runtime paths/bootstrap/pins/assets, preference,
  reading-data, safe-mode or sync-owner change. First sealed candidate `7a19786c`
  passes full/sealed/source gates and is physically tested: first Manga is
  6.2 seconds versus 15–17 before; the old-runtime control returns to 14.9.
  Warm Manga is not faster; metadata refresh still triggers a fresh ~5.9-second
  derivation. Silent startup maintenance also swallowed its canceling tap:
  use native Trapper nil/invisible-resend mode, keeping visible cancellation
  modal and cleanup safety unchanged. New native minimum/current input tests
  pass both interpreters; own worker forwards on device. A separate DROP worker
  belongs to Ereader Patch Manager and remains unchanged. Physical menu review
  also finds one-page settings cards falling back because native pagination
  returns a stateless VerticalSpan without free. Guard that one cleanup call;
  correct the overpowered fixture and exercise real minimum/current spans.
  Combined final candidate/device verification continues.
  Evidence:
  `test-results/device-performance-20261101/`. The temporary instrumentation
  patch is already moved out of `patches/` before uninstrumented comparisons.

- User additionally requests personal app selection through module long-press.
  Work stays on `fix/android-metadata-beta25-20261031` from clean `d1798813`;
  no new upstream merge, release authorization or device preference change.
  Existing custom App Launcher becomes Android apps / Android-appar (stable
  `app_launcher` ID). Native module hold/settings ownership is reused. Apps
  supports explicit launcher discovery, manual package fallback, rename,
  stable-package remove/confirm and named-neighbour ordering with live numbers.
  The saved list belongs to SUISettings, key
  `simpleui_app_launcher_apps_v1`, device-local/shared across its Home pages;
  read/paint never migrates or writes it. An already-enabled legacy module
  retains its old six choices. First explicit enable of a genuinely new module
  writes an empty list; a deliberately emptied selection never resurrects
  defaults. The earlier Settings-destination key remains unchanged in its
  original store and survives Settings removal/re-addition. Responsive bounded
  single-row pages fit narrow bento cells and more than six apps; page turns
  are memory-only and fetch icons only for visible items. Query only public
  launcher activities on Add app, with JNI frame/exception cleanup and UTF-8
  labels; do not enumerate while painting, grant permissions, install/uninstall
  packages, call a server or log the inventory. All new wording is SV/EN.
  No new API-1 installed paths, bootstrap, assets or external patch changes.
  Twenty-one real module/menu/widget/JNI-boundary tests pass both interpreters;
  full/catalog/sealed/package evidence follows in MERGE_LOG/TESTING. ADB now
  lists no device: this new app-management build is LOCAL, not installed on
  Bigme. The earlier shortcut-only candidate remains its last tested runtime;
  physical long-press/picker/add/remove/reorder/paging acceptance is still open.
  Local sealed candidate `3e52650b9c9ef20b2a55036a85dcf049e4b2bc1d` passes
  both complete interpreter gates, all 43 catalogs, all-root sealed/native
  input/EPUB/raster and actual Beta 5/9/24 native OTA/recovery/cleanup. Exact
  source/path/bootstrap/pins/assets, outgoing held-art and Gitleaks audits pass.
  ZIP SHA-256 `233d7a61cea392b3feb577dca10554d65ce73a5ceb6fdb6c5cff0207f180facc`,
  9,304,185 bytes / 27,482,431 expanded / unchanged 2,000 installed paths.
  Evidence: `test-results/beta25-20261031/android-apps/`. One reconnect to the
  known device port is refused; do not scan other ports or alter Android's
  debugging settings. Ask for its current connection before device testing.
  No push, tag, draft, release or device installation. Verification docs are
  descendants only and must not rebuild the sealed candidate bytes.

- User approves the Android metadata-refresh fix, regression coverage, testing
  on the connected Bigme and Beta 25 publication. Start clean at `60c57efc` on
  `fix/android-metadata-beta25-20261031`. A direct ADB capture proves
  `adapters/orbitui_android_covers.lua:10` called missing `nilOrTrue` on the
  settings editor, before extraction. Use `lib/bookshelf_settings_store`;
  preserve existing safety/default semantics and all queue/cache protections.
  The corrected old fixture reproduces the exact nil-field failure before the
  fix. A real runtime/store/storage-adapter test covers unset/on/off/non-Android
  and no preference write; sealed tests load the actual candidate adapter.
  VERSION becomes `0.1.0-beta.25`. No new upstream import, bootstrap/API/path,
  resource, external patch or server/sync-owner change. Physical staging uses
  a separate verified runtime slot, retaining Beta 24 and data. Test/publication
  evidence and device acceptance will be recorded in MERGE_LOG/TESTING.
  An additional approved Bigme request adds an explicit device-local App
  Launcher > Settings shortcut choice (SV/EN). Default stays normal Android
  Settings; Developer options uses only the public development-settings action.
  User rejects the alternative `.Settings` homepage. The public Developer
  options route reaches the existing Wireless debugging page without a crash;
  Android refuses direct private SubSettings startup. No system toggle or
  permission is changed. Select the new option only on the user's Bigme;
  retain its Settings icon and the other five launch targets. Supersede the
  unbooted metadata-only test slot, keeping known-working Beta 24 as rollback.
  Do not publish before the physical metadata test; no Beta 25 is public yet.
  Earlier shortcut-only test candidate is `2fdd1e97006208d1c28566096bea9a859e590b9f`, ZIP
  SHA-256 `3115c35d49175230f46b5f96a155bb4296109c227118210b1b3e9daefc485f46`.
  Both full gates, 43 catalogs, sealed/native/OTA and exact source/history/
  secret audits pass. It is installed on the connected Bigme, bootstrap pending
  flag cleared to 0, with Beta 24 retained. The actual SimpleUI Settings icon
  opens public Developer options, then Wireless debugging without a crash.
  The single preference persists after another launch; the temporary setup
  userpatch was removed (recoverable copy retained). No Android toggle changed.
  A physical book-menu Refresh metadata no longer exits KOReader with the old
  error, but the tested book leaves the current filtered page after refresh;
  extraction/filter-result acceptance and the user's original-book check stay
  open. Existing `android_safe_mode=false` is retained, not silently enabled.
  No push, tag, draft or public release. Evidence lives under ignored
  `test-results/beta25-20261031/settings-shortcut/`; verification docs do not
  rebuild or change the tested runtime bytes.

- **Beta 24 is public**, exact candidate/annotated tag
  `6532b06b8b79b466342e93b7a31c28f49c21e2c4` / `v0.1.0-beta.24`, published
  **2026-10-31 20:51:49 UTC**, prerelease true. The user's explicit
  "Pusha och publicera etc" follows the verified Bookshelf 6.1 merge;
  preparation starts clean at `bfd9a9d9` on `release/bookshelf61-beta24-20261031`.
  Only VERSION and existing SV/EN release documents change; no further import,
  runtime code, bootstrap/API-1/path, asset/language or external server/patch
  change. Main/tag CI `41240494963` / `41240495034` pass all four jobs.
  Both full interpreter gates, all 43 catalogs, sealed-root/native input/EPUB/
  raster checks, exact source/path/history/held-art/secret and draft/public byte
  audits pass. Actual Beta 5/9/23 native installers pass recovery/rollback;
  live anonymous LuaSocket/LuaSec upgrades from Beta 9/23 pass all phases.
  Preview selects Beta 24; stable stays absent. All 78 earlier releases/assets
  and 129 old tag refs stay unchanged. ZIP SHA-256
  `80b2dee3e057aace19ad9c3102a67db2a14ddda9a397d89dbaf0564462e845fc`,
  9,288,226 bytes, 27,431,859 expanded, same 2,000 installed API-1 paths.
  Evidence: `test-results/beta24-20261031/`. Verification-only docs never
  rebuild/replace published bytes. Physical Bigme/Boox acceptance remains open.

- A user-requested merge-only maintenance pass integrates Bookshelf **6.1.0**
  at `7ff93b9d8fb11194701440bcafd366002745cb01` (255 commits) and SimpleUI at
  `fdf83c7da73e6fa82c4ad02efa84a0dad3733541` (two font/compatibility follow-ups).
  Work starts clean at `0561e2ba` on `maintenance/upstream-bookshelf61-20261031`.
  Verified merges include an audited main push, NOT a new release. Public
  Beta 23 stays immutable; VERSION, bootstrap/API 1 and all 2,000 installed
  paths stay unchanged. Seven new Bookshelf helpers join the existing 13 exact
  lazy embedded sources in the generated map (403 module identities).
  New page-based editor/popup controls retain profile-specific settings,
  bindings, all-cover shelves, cover scale/captions, BookOrbit Tags/details,
  MAL/folder actions, night/Android safety and external patch ownership.
  Separate cover/ornament disk budgets and use-based recency retain our
  cancellable bounded maintenance rather than a synchronous full sweep.
  New native UI has SV/EN host translations. Full/sealed/native verification
  and final push evidence belong to the latest MERGE_LOG entry. Physical
  Bigme/Boox popup/editor/navigation and cache acceptance remain open.

- User explicitly approves pushing the remaining BookOrbit controls and a new
  beta ("Kör" after the unpublished-code status). Beta 23 is now public at
  exact candidate/annotated tag `51f63ed9f632effadc19c6c7575435032237d457` /
  `v0.1.0-beta.23`, published **2026-10-31 14:48:11 UTC**, prerelease true.
  Preparation starts
  clean at `43c627db` on `release/bookorbit-controls-beta23-20261031` from public
  main `b8619fad`. No new upstream import is requested; retain pins, bootstrap,
  all 2,000 runtime paths, assets, saved data and external sync/patch owners.
  Update SV/EN extras help and guides for the public exact-3.6.0 source package,
  preserving the legacy database warning and no-deployment boundary. No
  BookOrbit server change is authorized. Both full interpreter gates, 43
  catalogs, sealed root/native EPUB/input/raster suites, exact source/path/
  held-art/history/secret checks, draft/public byte verification and main/tag
  CI `41211382356` / `41211383347` pass. Actual Beta 5/9/22 native installers
  and live anonymous application-TLS upgrades from Beta 9/22 pass recovery,
  code rollback and retained-data cleanup. Preview selects Beta 23; stable
  stays absent, all 77 previous releases/assets and 127 old tag refs remain
  unchanged. ZIP SHA-256
  `756a535844d4145c73287312c9b7661e9ddee26c3348fbc13d7593c45e1eb965`,
  9,105,906 bytes, 26,750,160 expanded. Evidence:
  `test-results/beta23-20261031/`. Verification-only docs do not rebuild these
  published bytes; physical Bigme/Boox and live optional tag API acceptance
  remain open.
  Extras is already public at `3533480`, CI `41208332613` green for device
  checks, undo-only, tags-only and combined server builds. A separate read-only
  server check found an existing custom 3.6.0 undo installation, registered
  authenticated routes and a migrated opening table; the newer public package
  was not deployed there. Do not equate publication with server deployment.

- Earlier approved BookOrbit settings/documentation/extras work was LOCAL on
  `feature/bookorbit-controls-20261031` from clean `b8619fad`. New searchable
  Integrations > BookOrbit page keeps five root categories. Master plus
  independent list/manual-status/online-tag flags preserve unset behaviour,
  caches/layouts/source IDs and the external plugin's own progress sync.
  Existing local TBR is explicitly Want to read [Local] / Vill läsa [Lokalt];
  the separate server list is Want to read [BookOrbit] / Vill läsa [BookOrbit].
  No silent source substitution or new local list owner. Queue/off-on/subprocess
  policy guards retire late results; already-sent writes cannot be unsent.
  Offline EPUB tags stay independent. Detection/paint is passive, explicit
  refresh and durable successful timestamp are honest, and extras help never
  disables protected undo state. README now identifies public Beta 22 and
  distinguishes the new local-only controls. Separate extras packaging is in
  `/Users/robinbolinsson/bookorbit-extras`, with exact tested device copies,
  bilingual guides/licenses and separately pinned old undo/new tag server
  diffs. They target DIFFERENT bases, not an installable combined overlay.
  No OrbitUI release or BookOrbit production deployment is authorized by this
  step. Final local candidate `18a8547c` passes both full interpreter gates
  (133 Python/four existing skips, 94 root files, 487 Bookshelf/zero failures/
  three normal SQLite exclusions, 13 SimpleUI, syntax 1,091/map 396), 43
  catalogs, sealed-root/native EPUB/input/raster and native OTA/recovery/cleanup
  checks. Exact source/path/artwork/history/secret audits pass: same 2,000
  API-1 paths, bootstrap/pins/assets unchanged. DEVELOPMENT ZIP SHA-256
  `f23cf9ad10fad4943be5376052cf2c1bb174c8dbaaa76db43e96dbf7d1eb5c6e`.
  Extras is now public at `0c8302d`, CI `41204384358` green, with public README/
  remote bytes verified. Its API diff is public, but the BookOrbit source
  branch stays local/undeployed. OrbitUI's GitHub description is updated;
  its implementation/README remain LOCAL and public Beta 22 is unchanged.
  Verification-only docs do not rebuild sealed bytes. See MERGE_LOG.

- Beta 22 is now public at exact candidate/annotated tag
  `db909dcff807e255d4ba878d99028ee968ba963c` / `v0.1.0-beta.22`, published
  **2026-10-31 12:14:47 UTC**, prerelease true. It includes the approved offline
  EPUB tags plus the earlier optional online tag UI. Both full interpreter
  gates, sealed-root/native EPUB/modal/input/raster checks, all 43 catalogs,
  exact source/path/held-art/history/secret audits and actual Beta 5/9/21 native
  OTA recovery pass. Main/tag CI `41199505965` / `41199887141` pass all four
  jobs at that exact candidate. Draft/anonymous public bytes match; live
  application-TLS upgrades from Beta 9/21 pass. Preview selects Beta 22, stable
  stays absent; all 76 prior releases/assets and 125 old tag refs are unchanged.
  ZIP SHA-256 `2ed3191e76fda3828757163e3786b770c195bf834af7d509f89ae5e777243013`,
  9,089,361 bytes, 26,698,613 expanded, same 2,000 installed paths/API 1.
  No new upstream commits were available; pins remain unchanged. The separate
  BookOrbit API branch stays local and undeployed, and is not needed for EPUB
  tags. Verification-only docs never rebuild/replace these published bytes.
  Evidence: `test-results/beta22-20261031/`; physical Bigme/Boox acceptance remains
  open, not established by native headless tests.

- User explicitly approves local-first EPUB tags, then a fresh upstream merge,
  push and new beta publication. The offline section precedes the optional
  BookOrbit source in the existing Tags tab. Explicit Read/Refresh parses
  EPUB 2/3 `bookorbit:tags` JSON without a plugin/account/network; dc:subject
  stays with native genres. A separate disposable stat-keyed cache stores
  successful local tag reads, never server/account data or failures. Native
  bounded archive reads and a non-expanding XML reader inspect metadata only.
  Local search uses native home/profile path inventories and scan depth, one
  EPUB per event-loop turn, deduplicated across profiles, with cancel/retired
  guards, a 400-result notice and unreadable-file counts. No document engine,
  cover extraction, metadata/file/progress write or settings migration. Real
  reader/hold/modal ownership remains; optional API code is not deployed.
  Implementation/upstream/release gates and exact final pins will be recorded
  in MERGE_LOG. Physical Bigme/Boox acceptance remains open.

- User approves implementing clickable BookOrbit tags with ON-DEVICE matches
  only, then explicitly moves them to the existing Tags tab rather than the
  technical Book details tab. Local work on `feature/bookorbit-local-tags-20261031`
  starts from clean public Beta-21 verification head `de51ac9b`. Tags/Taggar has
  a separate BookOrbit section first, followed by unchanged author/series/
  collections/genres/folder sections. Loading and refresh are explicit; opening
  or painting never starts a network request. Native focus, zoom, scrolling,
  close/resource owners and original book-open/plugin actions remain. Exact
  case-sensitive tag lookup uses BookOrbit's current-account onDeviceMaps and
  native cancelable subprocess/client, batches 200 IDs, rechecks real files and
  caps results at 400 with a notice. Results include all library profiles,
  hydrate only visible metadata without covers and offer filename filtering.
  No persistent tag index/detail-cache scraping, account data in settings/logs,
  metadata/collection/progress writes or sync owner. Missing/old/offline/malformed
  providers and stale account/link/navigation/close callbacks fail closed.
  User additionally approves LOCAL BookOrbit API support, NOT deployment:
  `/Users/robinbolinsson/work/bookorbit-local-tags-20261031` on
  `feat/koreader-local-tags-20261031` from observed public `ba315c7` adds a bounded
  read-only catalog tag-matches route with native KOReader auth, accessible-
  library/present-book/content-filter scope and shared response types. Existing
  client methods suffice, so no BookOrbit KOReader plugin fork is necessary.
  Neither repository is pushed or published; no server is deployed. VERSION,
  source pins, all 2,000 installed paths, bootstrap and assets stay unchanged.
  Final checks and physical-device gaps are recorded in MERGE_LOG/TESTING.
  Final local source/package candidate `dd31edcb` passes both fresh full
  interpreter gates, 43 catalogs, all 15 tag cases plus existing modal/search
  cases and sealed-root reruns. Source/path/history/held-art/Gitleaks audits
  pass; all 2,000 installed paths stay identical. Actual Beta 20 native upgrade/
  recovery/rollback passes; actual Beta 21 correctly rejects a same-version
  development OTA before activation. BookOrbit revision `0cf7db1` passes 215
  targeted tests, full backend typecheck/ESLint/format checks and Gitleaks. Both
  repositories remain LOCAL; no release/deployment/live API check. Deployment
  and a device build/publication require separate user direction. Exact ZIP
  digest/evidence is in MERGE_LOG; verification docs never rebuild sealed bytes.

- User reports KOReader exits on selecting Bokdetaljer in Beta 20; reproduce
  the deterministic nil-header error locally. User approves the fix, a true
  render-path regression and immediate Beta 21 publication. Work from clean
  public `f02f3c74` on `fix/book-details-beta21-20261031`. The host now calls
  the modal's native headerless scroller with its CSS, scaled independent font
  and current dimensions. Native gestures and body lifetime remain authoritative.
  The new test reproduces Beta 20's nil `top` through real native modal methods
  and passes after the fix; prior tests had stubbed away this render contract.
  BookOrbit tag navigation is a design/research request, NOT bundled into this
  hotfix. Existing detail payload has separate tags/genres, but its current
  KOReader list-query DTO has no exact tag filter. Native Bookshelf Tags are
  KOReader collections; never silently equate them with BookOrbit tags.
  User explicitly chooses tag matches from books on the device only. Keeping
  results within the current profile is a proposal, not an approved extra
  restriction. Metadata completeness/local book-ID mapping still needs design;
  do not claim the existing bounded detail cache covers every local book.
  No BookOrbit/server/plugin write, new sync owner, import pin, installed path,
  asset or bootstrap change. Final publication gates/device gaps go in MERGE_LOG.
  Beta 21 is now public at exact candidate/tag `3116ed1c` /
  `v0.1.0-beta.21`, published **2026-10-31 10:32:57 UTC**, prerelease true.
  Both complete interpreter gates, sealed/native suites, 43 catalogs and exact
  source/history/held-art/secret/draft/public audits pass. Main/tag CI
  `41192857769` / `41192857730` pass all four jobs. Actual Beta 5/9/20 native
  installers and anonymous published-byte application-TLS upgrades from Beta
  9/20 pass all recovery phases. Preview selects Beta 21; stable stays absent;
  all 75 prior releases/assets and 123 old tag refs remain unchanged. ZIP
  SHA-256 `b694c19b3da9ced3d2814d0f87a8bd3f36e0100b89d48673c01b64e1d5bfcf94`.
  Evidence is in ignored `test-results/beta21-20261031/` and MERGE_LOG/TESTING.
  Verification-only docs do not rebuild sealed bytes. Physical detail-tab
  scrolling/zoom/repeated switches/close and reader return remain unverified.

- The user's explicit "Merga upstream, den pusha och publicera etc" supersedes
  local-only publication limits for the night/UI work below. Beta 20 is public
  at exact candidate/annotated tag `326035753702ca70492097d5a32391dd5023250c` /
  `v0.1.0-beta.20`, published **2026-10-31 08:20:10 UTC**, prerelease true.
  It starts from clean `82d4104c` on `release/upstream-ui-beta20-20261031` and
  public main `3476ac93`. Reviewed unsquashed merge `e6694c77` adds three commits
  through `5631ce1035286803d7586979c75993671ff022cb`: native-screen tilted-cover
  format for night blits, correct final-buffer LRU byte accounting and updated
  Polish translation. Bookshelf stays `ee84a8fe` with no new commits. Preserve
  private/borrowed cover ownership, every local adapter and all 2,000 API-1
  installed paths; no bootstrap/assets/hardware patch or external sync change.
  Both fresh full interpreter gates, sealed/native input/raster suites, all 43
  catalogs and source/history/held-art/Gitleaks/draft/public byte audits pass.
  Main/tag CI `41183802880` / `41183802884` pass all four jobs; upstream watch
  `41183802881` is green. Actual Beta 5/9/19 native installers pass; anonymous
  published-byte LuaSocket/LuaSec upgrades from Beta 9/19 and recovery pass.
  Preview selects Beta 20; stable remains absent and all 74 previous releases
  and 121 old remote tag refs are unchanged. ZIP SHA-256
  `33d9971a6fb8b4771222bd4f4568704fa62134d4f63fd943d806c91c386858d9`.
  Evidence is in ignored `test-results/beta20-20261031/` and MERGE_LOG/TESTING.
  Verification-only docs never rebuild or replace the tagged bytes. Physical
  Bigme/Boox acceptance remains open; this is not a stable/performance claim.

- User approves all five UI-review follow-ups, but first asks for a longer
  NON-manga bookmark ribbon and its publication. Ereader alone is published at
  `6c05155cb96395b656f85c47b4924523488715a1`: the prose ribbon reaches the
  measured header-text bottom, keeping width/notch/contrast and thumbnail safety;
  manga is unchanged. All 51 header cases pass in Lua/LuaJIT, Gitleaks is clear,
  and GitHub's public patch blob matches `7b48586881e5991888ba4c7038a5bf175ca83c48`.
  Patch Manager discovers that commit automatically; no manager release needed.
- Earlier OrbitUI follow-up was LOCAL on `feature/ui-refinements-20261031`;
  it and the night-mode correction below are now included in Beta 20. Independent
  code, not another embedded
  UI engine: bounded typo/Unicode search with exact-spelling priority and opt-out;
  explicit sort/filter/view access from the shelf counter; per-profile/chip/group
  browse preferences, compact one/two-column lists and relative dates; an ancestor
  picker in shared settings; simpler detail header plus lazy technical-info tab;
  opt-in private timings and a reproducible synthetic CPU-only search benchmark.
  Native scope, Android cover queue, series-block order, reader lifecycle, all
  original tabs/actions/fonts and external sync owners remain. Quick sort/status
  choices show that shelf's matching books; shelf defaults restore group cards.
  No setting migration, source pin/bootstrap/VERSION/asset change, new installed
  path, reference-watch activation, push or OrbitUI release is authorized here.
  Full verification and device gaps are recorded in SHARED_UI/TESTING/MERGE_LOG.
  Final source/package candidate `885b16f6` also preserves rich group metadata
  and native lazy date-sort keys. Both fresh complete interpreter gates and
  sealed-root reruns pass, as do all 43 catalogs, minimum/current native input
  owners, Android/non-Android raster cases and actual Beta 18 installer recovery.
  Exact source/path/history/held-art/secret checks pass; same 2,000 runtime paths.
  The same-version ZIP is DEVELOPMENT ONLY, never a public Beta 19 replacement.
  Verification-only documentation does not rebuild it; device acceptance is open.

- The user's Beta 19 photos expose unreadable white chrome over retained light
  wallpaper and Android RGB rounded-fill corner islands. User approves a LOCAL
  night-mode pass only, on `fix/night-mode-20261030` from clean `3476ac93`.
  A shared runtime-only 82% backdrop shade follows Home's screen flag and each
  shelf's actual light/dark look, without changing saved themes or image files.
  Optional wallpaper paint seams cover full/partial/scratch/legacy/blur paths;
  blur cache keys include the tone. Shade before chrome, never over covers or
  borrowed source rasters. The host guards the entire RGB rounded fill against
  Android CBB's mixed inverse handling, restores flags on errors, and keeps the
  native software/hardware paths. The day-only hero emphasis no longer becomes
  a bright night card. The dock gets a 90% runtime opacity floor with native
  tone/contrasting ink, also over pinned Light; day opacity stays saved.
  VERSION stays Beta 19; no source pin, bootstrap, installed
  path, asset/font/language, external sync or hardware patch change. No push or
  release is authorized. Candidate `67bbe60c` passes both complete interpreter
  gates plus fresh final 89-root-suite sealed reruns, 43 catalogs and exact
  source/path/artwork/history/secret audits. All 11 native raster cases pass
  in Android and non-Android modes on sealed bytes; actual Beta 18's native
  installer/restart/rollback/cleanup passes. The same-version development ZIP
  is never a replacement for public Beta 19. Verification-only docs do not
  rebuild it. Evidence is in MERGE_LOG/TESTING and ignored
  `test-results/night-mode-20261030/`. Nothing is pushed or published; physical
  Bigme/Boox acceptance remains open, not established by headless pixels.

- The explicitly requested Beta 19 is public at exact candidate/annotated tag
  `89d23c78d5432f35cf14046ab78dc26de85ef13d` / `v0.1.0-beta.19`, published
  2026-10-30 22:40:07 UTC, from clean public `493eb05a` on
  `release/search-collections-beta19-20261030`. VERSION is `0.1.0-beta.19`.
  It includes the reviewed search/collection work and evening SimpleUI merge;
  Hardcover/edition behavior, source pins, hardware patches, bootstrap and all
  2,000 installed paths are unchanged. Both fresh full interpreter gates,
  sealed/native-owner suites, 43 catalogs and exact source/history/artwork/
  secret/draft/public byte audits pass. Main/tag CI `41139100244`/`41139100184`
  pass all four jobs. Actual Beta 5/9/18 native installers pass; anonymous
  LuaSocket/LuaSec TLS discovery/download and installation of published bytes
  pass from Beta 9 and 18. Preview selects Beta 19; stable remains absent and
  all 73 prior releases/assets and 119 prior remote tag refs are unchanged.
  ZIP SHA-256 `86b5ffc63ddbd820a1e335c8a8cb21651683edba1b336785057e9455a71d9e64`;
  evidence is in ignored `test-results/beta19-20261030/` and MERGE_LOG/TESTING.
  Verification-only docs never rebuild or replace the released artifact.
  Inspiration watch remains active, with first successful run `41133753256`
  and separate issue #2. Physical Boox/Bigme search/collection/Insights and
  lifecycle acceptance remain open; this is a prerelease, not a stable release
  or measured performance claim.

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
- Product version: `0.1.0-beta.23` (public GitHub prerelease, published
  2026-10-31 at 14:48:11 UTC after explicit user request; verification is in
  `docs/MERGE_LOG.md`). Beta 22 and earlier assets remain immutable.
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
- Release tag: `v0.1.0-beta.23` at `51f63ed9`; previous tags
  `v0.1.0-beta.22` at `db909dcf`, `v0.1.0-beta.21` at `3116ed1c`,
  `v0.1.0-beta.20` at `32603575`,
  `v0.1.0-beta.19` at `89d23c78`, `v0.1.0-beta.18` at `7c0f7057`,
  `v0.1.0-beta.17` at `ab2e0bd7`,
  `v0.1.0-beta.16` at `5c846730`,
  `v0.1.0-beta.15` at `ee35bf19`,
  `v0.1.0-beta.14` at `575fdb7a`,
  `v0.1.0-beta.13` at `f9d3b3a2`,
  `v0.1.0-beta.12` at `ea8bbaf0`,
  `v0.1.0-beta.11` at `03106015`,
  `v0.1.0-beta.10` at `0a2ea22b`, `v0.1.0-beta.9` at `a4bb9acb` and all
  earlier tags/assets are unchanged.
- Public branch: `main`; Beta 23 publishes the optional BookOrbit settings,
  explicit Local/BookOrbit source names and deferred-policy guards. No new
  upstream merge or server deployment. Beta 22 publishes local-first EPUB tags and the earlier
  optional online source, after a fresh check found no new upstream commits.
  The earlier October 30 publication request produced
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
- Reviewed Bookshelf maintenance pin: `7ff93b9d8fb11194701440bcafd366002745cb01`
  (6.1.0; see latest merge-only entry). Public Beta 23 remains `ee84a8fe`.
  Public Beta 15/16 retains
  `d07905ba932e09044827aadf480c188a5d324b96` (6.0.4). Public Beta 14 retains
  `c37580a1ca5040d2423e45b9bdd429776117f3c1` (6.0.3).
  Public Beta 10 keeps `5f726c25` / merge `0db81b46` unchanged.
  Prior 6.0.0 integration `fc1103a3` / `48438837` is retained in ancestry.
- Reviewed SimpleUI maintenance pin: `fdf83c7da73e6fa82c4ad02efa84a0dad3733541`
  (3.0.2 plus font/compatibility follow-ups). Public Beta 23 remains `5631ce10`.
  Public Beta 15/16 retains
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
