# Integration contracts

These are project requirements to preserve during reviewed merges, not a claim
that every device behavior has been proven in this alpha. Read alongside
`TESTING.md`. The original component tests use many stubs; a green result is not
equivalent to a successful Android reader session. Keep these IDs stable so
merge notes can name the affected contracts.

## C01: One plugin, one event path

OrbitUI alone owns the combined plugin entry point. Standalone Bookshelf and
SimpleUI must stay disabled while OrbitUI is active. Keep their installed files
and update channels intact for rollback. Fail closed on duplicate installations,
mixed-version loaded modules or failed pre-start backup.

Expose `ui.bookshelf`, `ui.simpleui`, the corresponding PluginLoader instance
aliases and `_simpleui_plugin` where the component supplies it. Children receive
events once in Bookshelf/SimpleUI order. Preserve event arguments, consumption,
and cleanup that cannot erase a newer reader's instance aliases.

Source: `main.lua`, `core/orbitui_plugin.lua`, `core/orbitui_guard.lua`, `core/orbitui_host.lua`,
`core/orbitui_runtime.lua`. Tests: `tests/test_guard.lua`, `test_host.lua`,
`test_entrypoint.lua`, `test_runtime.lua`.

## C02: Navigation and close ownership

Home belongs to SimpleUI; configured library sections belong to Bookshelf.
Keep the dock's active item, profile roots and current drilldown consistent.
Do not let a generic Show/PathChanged event steal a destination already chosen
by another component. A stale deferred callback must not reopen the previous
book or raise the wrong screen.

The approved Beta 7 Home error path must remain shared across manual Home,
startup, resume and reader return. Preserve the first real load error and full
trace, catch built-in Home factory/first-run-hook failures, and close only its
partial instance without auto-reopen or settings resets. Do not treat failed
LuaJIT require sentinels as screens or purge valid/third-party module state.
Keep the shared engine table and callbacks. Source: `infra/sui_screen_nav.lua`,
`screens/sui_homescreen.lua`, `infra/sui_patches.lua` and `features/sui_quickactions.lua`
under SimpleUI; regressions: `tests/test_home_first_run.lua` and
`tests/test_home_module_load.lua`. The latter must load the entire screen engine
without ambient Blitbuffer/logger; an extracted factory alone misses dependency
failures during module initialization, as the Beta 8 photo/reproduction proved.
This is not a claim of physical Android native-crash acceptance.

User-approved generalisation, stage 1 (October 19, 2026): runtime sections are
stored in `orbitui_libraries` (version 1) in the Bookshelf settings store. Import
the old prose/comics definitions only when profile-specific settings prove that
they were used, not merely because a stock Bookshelf settings file exists. Keep
the old profile and chip IDs, settings keys, themes, binding overrides, Home
references and dispatcher aliases. Never move books or rewrite reading data.
A clean install seeds a local Library from KOReader's chosen home directory;
without one, it offers section creation instead of guessing device paths.

Section names, icons, roots, order and shelves are editable. Folder sources use
the native source-descriptor shape; Bookshelf still owns query/render engines.
Disable sections without deleting their settings. Disabled/stale Home and search
references fail closed; do not silently display the entire library. Dock actions,
search scopes, theme inventories, reader-return matching and Home prewarming
must resolve the same saved inventory. Longest-root matching is deterministic.
Changing a root updates descendant folder sources, not shelf IDs or actual files.

October 27 user-approved editor cleanup (Beta 14): each chip exposes its own source
and, for a folder source, its path. Whole-library roots remain distinct under an
advanced submenu; replacing one explicitly confirms the descendant remapping.
Changing just a chip must not relocate siblings or remove old roots. Choosing
an out-of-root folder asks before appending it to library scope (including search
and reader-return matching). Keep all existing paths/IDs/settings; no file moves.
Library ordering lives at inventory level and must not claim to order navigation
buttons. Chip ordering matches the chip bar left-to-right. Both use a live numbered
list, explicit positions and named before/after neighbours; stable IDs, not stale
indices, identify the selected item and destination. All owned wording/help and
search terms support Swedish and English. No component import/release is implied.

October 25 user-approved navigation improvement (Beta 9): Bookshelf is a
first-class action in unsaved/default bars and the fresh setup guide, without
requiring a prose/comics profile. Saved/custom bars are not automatically changed;
explicit removal persists. Distinguish the file browser from Bookshelf. The
Bookshelf button's optional saved profile and per-section Add to navigation
controls reuse the same inventory, IDs, chip settings and real reader lifecycle.
A full bar requires an explicit replacement choice. Missing/disabled profile
aliases must explain the problem and offer configuration, never silently no-op
or substitute an unrelated library. Source: the library/navbar/setup/UI adapters;
regression: `tests/test_bookshelf_navigation.lua`. No bootstrap or data migration.

The old comics-only presentation choices (folder-label strip and three-row
folder-list cap) are now explicit shelf options. The Oneshots grouping rule is
an optional subfolder-name rule on any folder shelf; migrating the old Manga
and Comics shelves preserves their original choices. The legacy definitions in
the component remain a migration fixture, not OrbitUI's live source of truth.

Source: `core/orbitui_libraries.lua`, `adapters/orbitui_libraries.lua`,
`adapters/orbitui_library_settings.lua`. Regression coverage:
`tests/test_libraries.lua`, `tests/test_library_settings.lua`, shared settings,
search, themes and component navigation suites. Device acceptance still needed:
rename/move a library root, add a dock destination, switch from Home and reader,
then restart and verify existing profile-specific appearance and Home pins.

October 27 user-approved native reading-menu integration (Beta 14):
OrbitUI owns the file-browser/cabinet button through a shared menu prepare step
AFTER KOReader builds/rebuilds its table. Both embedded init-time callback writers
delegate to that owner. This changes only that button, not explicit Home gestures,
hardware keys, exit/restart or end-of-book policy. Default is fast Bookshelf return;
a bilingual opt-out invokes the original construction-time native/userpatch
callback. Native close events, invalidations, reading progress and sync owners
remain intact; skip only competing destination restoration on that fallback.

An exact shelf-launched file keeps its source profile/chip/page/drilldown. Home/
search/external files use the same enabled inventory/longest-root matcher, never
hard-coded prose/comics IDs. Disabled/deleted source profiles and unmatched files
fall back to the original action, not another library. An external location can
hot-park ONLY when prewarm finished for that exact ReaderUI/file/profile; otherwise
let native real-close finish before resolving the location. Do not rebuild a
buried shelf while the live reader owns its screen/document. Rotation refusal
still uses native normal close. Opening the menu over an already parked shelf
keeps its explicit real-file-browser exit. Stale/replaced menu callbacks and
double taps are inert; owner-safe teardown restores only that owner's callback.
Source: `adapters/orbitui_libraries.lua`, `adapters/orbitui_ui.lua`,
`core/orbitui_host.lua` and the optional native Bookshelf return fields/guard.
Regression: `tests/test_reader_menu_return.lua`; execute physical Boox/Bigme
menu/rotation/sleep/reader-profile checks before claiming device acceptance.

Preserve the warm shelf on an ordinary reader return, but drain windows on
exit. Closing a book via gesture, menu or end-of-book dialog must reach the
intended destination without a second menu layer or prolonged input blocking.
These are historical regressions, not merely cosmetic preferences.

SimpleUI's October 17 displaced-screen restoration keeps Home/custom screens
alive beneath their own main menu. Temporary plugin fullscreens may inherit
the displaced screen ID, but Bookshelf, Home and ReaderUI are navigation
destinations with their own return ownership. They must not inherit a Home
restore marker. A navigation-generation guard cancels stale deferred restores,
even if the newer destination closes before the callback runs. Regression
coverage: `tests/test_upstream_20261017.lua` and the `orbitui_ui` patch seam.

Source: `components/bookshelf/main.lua`,
`components/simpleui/sui_bookshelf_bridge.lua`, SimpleUI `infra/sui_patches.lua`
and `engines/sui_screen_engine.lua`.
Bookshelf tests: `_test_close_keeps_shelf.lua`, `_test_close_raise_on_show.lua`,
`_test_onshow_takeover.lua`, `_test_safe_show_takeover.lua`,
`_test_profile_navigation_reuse.lua`. SimpleUI test: `_test_bookshelf_bridge.lua`.

Global navbar geometry changes also refresh Bookshelf's independently embedded dock.
An on-stack shelf (including one beneath settings) reflows immediately; a warm
off-stack shelf defers until its normal return. Preserve the current profile,
chip, folder and reading lifecycle, and never raise a hidden shelf to refresh
chrome. Home/custom-screen content and pagination must reflow to the new
available height after a bottom-margin change, without discarding book caches.
Ordinary icon-only rebuilds (including Wi-Fi changes) must not rebuild shelves.
Source: `adapters/orbitui_navbar.lua`, SimpleUI `ScreenWidget:_refreshImmediate`.
Regression coverage: `tests/test_navbar_margin.lua`.

## C03: All book-opening routes

A book opened from Home, Want to Read, Currently Reading, search, quick actions
or a shelf must still follow KOReader's normal reader-opening lifecycle. Keep
ShowingReader/ReaderReady delivery and the real file path intact, so the user's
path-based automatic reading profiles can run. Do not implement a shortcut by
bypassing ReaderUI or by reusing the previous book's profile state.

The Bookshelf UI profile (prose/comics) and a KOReader reading profile (margins,
rendering, etc.) are different concepts. Preserving one does not prove the other.
Source: SimpleUI `engines/sui_screen_engine.lua`, `features/sui_quickactions.lua`,
`features/library/sui_library_search.lua`, `infra/sui_patches.lua` and the bridge.
Device check: open new manga and prose through every route with path-based
auto-execution configured; this still needs real KOReader verification.

## C04: Bounded background work and cache correctness

October 30 evening monthly Reading Insights activity is lazy, read-only and
derived from positive-duration distinct book/page/day records and the existing
finished ledger, never a second completion/sync owner. Cache only successful,
complete results, including in the window; distinguish an empty SQL year from
missing rows. Failed queries and incomplete reconciliation must retry. Full
invalidation drops historical page caches; partial invalidation may retain
closed months but cannot freeze future years at zero across year rollover.
Preserve original finished-book return values; its additive completeness result
only gates the new chart. Tests: `test_upstream_20261030_evening` and real SQLite
`test_monthly_activity`. No hidden dashboard work or settings/data migration.

October 30: covered boot listings may defer until safe idle/exposure. Idle warm
callbacks require the same live owner, Home/FM, navigation generation and no
reader/suspend/exit; folder work is one entry per tick, max 64, cancelled on
chooser path/page/list changes. Dynamic menu snapshots never evaluate current
values/providers and are cancelled/restored on last-owner release. Page-turn
counts reuse the existing aggregate query, retaining error/retry signaling and
distinct-page statistics. No new network or synchronization writer.

October 28 approved local performance follow-up: dashboard data demand follows
visible per-screen cards and the selected goal owner, retaining native Recent
source candidates independently of hero/ongoing visibility. Other enabled modules
still contribute their own demands. Optional Adaptive/Responsive policies modify
only runtime retained-cover budgets, never saved native limits, source images,
disk caches or parked shelf state. Unknown readings preserve existing budgets;
unset/future modes retain existing behaviour. Eviction uses existing borrowed
reference lifetimes and keeps one oversized newest image usable, without explicit
free/synchronous GC. Existing deferred native GC-pressure accounting remains.
Work is one-shot, deferred, cancellable and owner/generation-safe.
Responsive can suppress wipes and speculative next-page/chip work, not mandatory
reader-return preparation or Android's safe visible extraction. Timing is opt-in,
bounded and payload-free, preserves original nil/results/errors and distinguishes
synchronous method time from screen/deferred latency. Later external hooks win;
last-owner teardown neutralizes policy. Tests: test_dashboard_demand/performance.
Physical Boox/Bigme performance, image pressure and UI acceptance remain required.

October 28: native cover polling may report done/changed to avoid redundant
refreshes, but a legacy/external callback returning only done must still repaint.
Resolved native slots are not decoded again; failed ImageWidget construction
stays pending. Weak shared hook ownership must not retain dropped reader UIs.
Deferred file-manager listing materializes when exposed; temporary per-instance
refresh overrides restore exactly even after errors. These optimizations do not
supersede C02 reader/profile/navigation-generation guards or Android cover safety.
Coverage: test_upstream_20261028 and retained Home/reader/navigation suites.

October 27 SimpleUI import: catch recognized metadata-cache faults and retain
last known text, with one warning per failure episode and a real read on every
later attempt. Never automatically delete the DB/WAL/SHM or reset shared live
connections/statements; upstream's destructive recreation is deferred under C08.
Non-database errors propagate unchanged. Unicode search/sort/filter keys use the
native helper or utf8proc on older supported KOReader, without changing global
util. Headless native-free environments may fall back to ASCII. Tests:
`test_upstream_20261027`; minimum supported KOReader remains v2025.08.

Beta 12's user-approved Android cover fix keeps Android safe mode enabled.
The host adapter may extract local covers/metadata serially in the foreground,
one document per UI turn with a 256-entry queue/attempt bound, cancellation on
navigation/reader/suspend/close, and cooldown-limited retryable failures. It must
not invoke subprocess-only BIM extraction, redirect crengine's global cache,
reload/close an already live reader, or fetch provider-stream formats. Borrow
the matching live document read-only, as Book information does. Prepare native
images before a savepoint-protected derived-row update; retain old rows/covers
on failure and ignore/custom-cover choices always. Never cache a synthetic
upscale as new high-resolution source art or downgrade a larger cached image
to a smaller requested slot. Single/bulk metadata refresh delegates before
native row/cache deletion. Bookshelf's full-library metadata scanner explains
the safe-mode alternative instead of forking. Native fallback and SimpleUI's
independent Android background gate remain unchanged. Coverage:
`test_android_covers` (including optional actual-SQLite supplement). Physical
native-engine/latency/image quality remains unaccepted; a synchronous native
document load cannot be preempted halfway through.

The October 25 SimpleUI daily-history ledger is derived statistics, not a new
reading-data owner. Busy/missing aggregates must not persist zero days/pages;
close failed statements and retry within the same window. Full statistics
invalidation also drops the ledger's disk/memory prefix, including historical
duration edits that leave its row-count/min/max signature unchanged. Insights
retains both ends of its year range. Bounded Bookshelf sticker buffers retain
aspect-true pixels across widget rebuilds, exclude text overlays, and free on
eviction/explicit cover-cache reset. A failed image build remains retryable.
Tests: `test_upstream_20261025`, `test_upstream_series_boxes` and the real-SQLite
supplement in the October 25 evidence directory.

The October 22 Bookshelf 5.5.5 import honors an explicit disabled stable-page
preference in both hydrated metadata and progress-cache reads. Preserve the
fork's doc_pages/rendered-cache precedence and never use stored publisher page
labels when disabled. Ratings on covers/sorts use only cached Hardcover data
when explicitly enabled, never write the user's rating or fetch while painting.
Folder read-state sort invalidation retains scope-qualified keys and leaves
unrelated title/filename caches usable. Cover-cache clearing also invalidates
sampled spine colours, without removing page facts or status. C05/C07 still apply.

Prewarming is idle-only, bounded and cancellable. No poll may live indefinitely
after its owning screen/reader is gone. Reuse shared index/metadata work where
the baseline does, but invalidate it on status, metadata, file or day changes.
An unavailable/busy database must not turn a temporary miss into permanent zero
statistics. Normal shelf rendering must not initiate Hardcover network work.

Streak-only invalidation must not promote partial or disk-stale book counts,
undo a pending full invalidation, or reuse previous-day counts. Preserve valid
same-day counts without another sidecar scan. This adapts SimpleUI 2.7.5's new
freeze invalidation to the partial-cache contract; tests cover both paths.

Source: Bookshelf `lib/bookshelf_book_repository.lua`, `lib/bookshelf_hardcover.lua`,
`main.lua`; SimpleUI `modules/module_stats_provider.lua`,
`features/library/sui_metadata_source.lua` and the bridge.
Tests: Bookshelf `_test_home_prewarm.lua`, `_test_progress_cache_writers.lua`,
`_test_lightmeta_stale_snapshot.lua`, `_test_hardcover.lua`; SimpleUI
`_test_performance_caches.lua`, `_test_new_books_index.lua`, `_test_config_cover_cache.lua`.
Measure warm/cold navigation and memory on the Bigme before claiming a speedup.

The October 12 SimpleUI refresh/cache import keeps live module content separate
from decorated wrappers. Same-size clock/topbar labels update in place; size
changes rebuild with the existing module background and hold wrapper. Each
window owns its own topbar tree and geometry, including the fallback path.
Shared raster masks have a 3 MiB LRU budget and a 64-entry ceiling (also for
zero-byte metrics); the just-built oversized raster survives until a later
request. Preserve collision-free geometry keys and legacy cache-clear/badge
APIs. Metadata rows retain the 256-entry/five-second bound, retryable failures,
progress-only/skip-description paths and immediate live-status invalidation.
Read-only sidecar probes must not close/write handles. No-cover probes expire.
Tests: `test_upstream_20261012`, `test_simpleui_upstream_20261009_followup`,
and native `_test_performance_caches`.

The October 16 shared LRU/memory helpers retain these bounds and retry rules.
New Books ranking is capped at 15 candidates and keyed by the shared index's
root/revision; it must not sort the shared records or cache a root switch away.
Recent demand follows active module sources, not unrelated BookOrbit/TBR grids.
Reset cancels collections scheduled by reset hooks as well as earlier work.
Nested alpha-mask scratch buffers are reused and freed on reset; allocation,
viewport and paint failures must not poison their ownership or nesting depth.
Tests: `test_upstream_20261016` and the native cache/index suites.

## C05: Synchronization has explicit owners

The October 14 finished-book ledger is local statistics state, not a new
external synchronization owner. Read-only reconciliation must not write book
sidecars; completion dates are aligned only on explicit status-change events.
Reconciliation is atomic across the bounded history scan: transient stat or
sidecar failures neither remove known entries nor suppress retries for the day.
Partial counts and unavailable/locked DB activity cannot overwrite the last
valid persisted totals. Full invalidation resets ledger reconciliation too;
streak-only invalidation keeps valid same-day counts. Retain legacy deleted-book
records and manual-count keys for rollback, with an idempotent migration marker
inside the new ledger. The new format-aware Bookshelf walk cannot adopt a
core-only SimpleUI index when plugin formats are present (C04).
Tests: `test_upstream_20261014`, native `_test_performance_caches` and
`_test_walk_snapshot`.

BookOrbit remains an external plugin/service, not an OrbitUI component. In this
user's setup, BookOrbit should remain the intended Hardcover reading-progress
writer. Do not introduce an additional automatic Hardcover completion/status
writer in OrbitUI; duplicate reading dates were a reported regression.

Bookshelf's Hardcover integration supplies linking, edition identity and cached
enrichment/ratings. Preserve incremental linking of unlinked files as distinct
from intentionally relinking the whole library. Do not clear links, editions or
user display choices as a side effect of merging or refreshing metadata.

On Android, an accepted remote progress prompt must close before its navigation
callback runs; discard callbacks for a closed/replaced reader. The workaround
is scoped to BookOrbit/KOSync, not a global replacement of ConfirmBox.

Source: Bookshelf `lib/bookshelf_hardcover.lua` (`unlinkedFiles` and link/cache
functions); SimpleUI `infra/sui_progress_sync.lua` and
`integrations/sui_bookorbit_want.lua`.
Tests: Bookshelf `_test_hardcover.lua`, `_test_hardcover_match.lua`,
`_test_bookorbit_want_source.lua`; SimpleUI `_test_progress_sync.lua`,
`_test_bookorbit_want.lua`, `_test_coverdeck_bookorbit.lua`.
Device/server checks: one finished read record, remote position actually moves,
and server-backed Want to Read remains usable. No live credentials in tests.

## C06: External plugin and patch compatibility

Bookshelf 6.0's underlay/dirty hooks must not overwrite later plugin wrappers.
Window paint wrappers become inert when released; widget close releases only
the current underlay owner. Preserve nil positions and original errors/results
under Lua 5.1 as well as newer Lua, including restoring closes. New exposed-screen
refreshes retain OrbitUI navigation-generation guards. Coverage: native
`_test_underlay`, `test_simpleui_dialog_merge` and existing navigation suites.

MyAnimeList, Patch Manager, manga-header patches and BookOrbit undo-opening
support are external integrations, not features reimplemented by this import.
Preserve the canonical `lib/bookshelf_*`, `infra/sui_*` and legacy `sui_*`
module identities and package.preload priority. Do not globally replace require,
gettext or DataStorage. External plugins may load helpers before OrbitUI init.

The October 16 central menu hooks acquire each host once and release it once.
They remain installed while another host owns them. Last-owner teardown only
restores methods still equal to our wrappers; later external wrappers survive
with our captured inner functions disabled. Reinstall must not stack effects.
Keep canonical module identity and reset-aware unload when moving hook code.
Tests: `test_upstream_20261016` (including out-of-order teardown/reinstall).

Do not import a future upstream "disable incompatible plugins/patches" feature
without reviewing exactly which local integrations it would disable. A clean
Git merge is insufficient approval to change the user's enabled integrations.

Source: `core/orbitui_runtime.lua`, component i18n/path helpers and the bridge.
Tests: `tests/test_runtime.lua`, component language tests. Device checks: MAL
folder actions/rating badges/completion, manga volume suffix and bookmark ribbon,
patch updates and undo-opening behavior. Their external code/server state must
be inspected separately before changing their contracts.

The approved October 18 box-rating integration uses only the existing
`bookshelf_folder_badge_providers.myanimelist` cached callback (inspected in
myanimelist.koplugin 1.5.2), with the series label and the common parent of its
local member files. The provider still owns Manga scope and explicit-folder
link precedence; do not guess a first member's folder for mixed directories.
Do not fetch ratings, hydrate metadata, read private plugin settings or change
links while painting. Missing/disabled/erroring providers and absent/invalid
scores produce no badge. Read the live callback on repaint so cached refreshes,
relinks and removal do not leave a stale score. No MAL plugin update required.
Folder-backed Oneshots boxes have no shared series rating; never inherit a
representative one's link or average unrelated ratings.
Tests: `test_series_rating`, `test_upstream_series_boxes`.

## C07: Presentation and preferences

October 31 local night-mode correction: dark Home/shelf wallpaper must provide
readable contrast without changing saved day settings, theme/pinned-look choices,
source images or covers. Shade only the background destination, before panels/
text/images. Full, partial, scratch, legacy facade and blurred backgrounds must
agree; tone participates in the blur cache key, including independently pinned
Light/Dark with an unchanged screen flag. Preserve native image/cache ownership.
Android CBB's flag-ignoring rectangles and flag-aware rounded corners need one
error-safe inverse guard for the whole RGB fill; software-only/non-Android
targets keep their native inversion. Home's optional hero emphasis is day-only,
so every night card uses light text on a dark surface. The shared dock's runtime
opacity is at least 90% at night, independently of pinned shelf Light; resolve
native tone/ink together and retain day opacity and memoized surface ownership.
No global framebuffer/
image patch or settings migration. Tests: `test_night_mode`, dashboard/colour and
native CBB/scrim/blur/rotation checks. Physical legibility/lifecycle remains open.

October 30: grid quick actions/six-column covers/new statistics and panel Critter
are opt-in. Existing rows/layouts and native Android Bluetooth remain usable.
Global Critter controls are defaults; saved screen-specific picks, style, source,
topics, reactions and decorations retain their original scope and editable keys.
Keep v14 copy-only/retry/deferred-marker guards and prior migrations in main;
the upstream migration-extraction refactor is intentionally deferred.

The October 26 upstream free-width/stack editor remains opt-in for existing
OrbitUI layouts. Unset fixed-grid stacking stays off; legacy percentage/stacked
layouts keep their old renderer until explicit width/movement or Free widths
selection. Merely reading a saved percentage must not snap it. Each stacked
module retains its own top margin; preview/render mode and warm-cache keys agree.
Wallpaper uses one owned raster with bounded failed-decode retries, safe partial
allocation cleanup and a legacy paint facade that never owns a freed image.
The library-opacity migration copies into an unset new key, retaining the old
show-in-file-manager flag and preset/backup fields for rollback. Explicit new
opacity wins. Keep the old opacity/show APIs usable. New Fast Book Closing is
off until selected, not an automatic memory/performance migration. Coverage:
`test_upstream_20261026`, `test_simpleui_bento_margins` and native underlay tests.

The user-approved October 23 SimpleUI 3.0 ZIP import preserves existing Bento
percentages and stacked columns. No render-time width snapping or automatic
layout conversion is permitted. Explicit width/movement edits in the new editor
set the screen layout's `bento_model=3`, enabling its fixed-span preview/rows.
Both models retain independent module top gaps and top alignment. The 96dp
embedded navbar, transparent defaults and opt-in UI fonts remain unchanged.
The old Reading Stats module path aliases the new directory module (C06).
The v12/v13 badge/folder/caption migrations copy only into unset new keys,
retain all old keys for rollback and mark completion only after success (C08).
New charts/session caches must retry transient DB failures. Coverage:
`test_simpleui3`, `test_simpleui_bento_margins` and existing integration suites.

Retain the user's independent prose/manga configurations, backgrounds, fonts,
dock and custom Home/Bento layout. "Show section label" must still show labels.
Transparent book-title/page-indicator backgrounds must not also erase the hero
panel or chip bar unless those independent controls are explicitly changed.
Keep hiding accidentally opened books distinct from deleting book files or
resetting all reading data.

October 16's Tabbed Grid is opt-in, scoped by module instance and screen prefix.
Unavailable source tabs remain stored, tab changes reset only their own page
and book-list cache, and the module reserves a stable height across tabs.
Keep hidden-Recent filtering and its restore action in the shared source.
Reader Quick Settings stays Classic until Book is explicitly selected, including
fresh installs. Currently Reading stays detailed/left-aligned by default.
Copy legacy item order into unset main/stat orders only, retaining the old key;
statistics are grouped at their first old position in relative order. New
choices do not overwrite old preferences, nor roll back into them automatically.
Tests: `test_upstream_20261016` and the prior layout/label/cache suites.

Per the user's 2026-10-04 request, the shelf/spines view faces **all books**
cover-forward in **Classic OrbitUI**, including existing prose/manga chips and profile overrides.
`adapters/orbitui_appearance.lua` sets the widget's native face-out policy to `all`;
rendering and pagination must continue to share the native geometry. Ordinary
grid/list/Auto modes and shelf decorations remain unchanged. Retain saved
orientation choices for rollback rather than migrating preferences. The chip
editor's optional `face_out_override` makes its row read-only and report All
books, without changing the draft. Tests: `tests/test_face_out_shelves.lua`.

User-approved standalone stage 4 (2026-10-19) makes that policy selectable.
Existing OrbitUI hosts retain Classic; new hosts (including first-time OrbitUI
over standalone components) default to native Shelf settings. Minimal forces
face-out without boxes or any ornaments. Store the versioned policy separately
from native preferences; never erase per-shelf orientation, box toggles or pack
choices. Profile `series_boxes` must use the qualified style record, not a
same-named native tab. Classic performs the additional once-per-session shuffle;
optional packs are installed separately through Add-ons (C11). Matching/spacing for already-installed
artwork is retained in other decorated presets. No policy switch deletes files.
Guide changes are draft-only until review/confirmation, standalone selection
also confirms, and both preserve Home/wallpaper/icons/accounts/reading state.
Clear prepared spine lists on switching, including parked widgets before their
next fetch/rebuild, so render and pagination use the same new policy. Earlier
all-face-out/all-series descriptions below refer to the Classic preset.
Tests: `test_appearance`, `test_setup_ui`, `test_backup`, the existing face-out,
series-box and ornament suites. Device acceptance remains a separate gate.

Bookshelf 5.4.3 explicit Auto is per drill level: `view_level1` governs the
chip's top level (collapsed or expanded), `view_level2` all its drills.
Defaults are Covers then List. Persist both keys independently in native and
profile-chip records. An unset mode retains OrbitUI's legacy collapsed-covers,
expanded/drilled-list policy; do not silently opt existing shelves into new
level controls. Explicit Covers remains stored, not erased. OPDS cannot use
physical shelves and falls back to Covers, including a drilled Auto choice.

Bookshelf 5.4.4 splits list density only when explicit Auto uses List at both
levels. Preserve `list_rows_l2`, `list_columns_l2` and `list_rows_expanded_l2`
in fixed-profile records as well as native tabs. Level 2 inherits Level 1's
rows/columns until overridden, but never its expanded zoom. Pinch writes and
clears only the visible level's key; non-list geometry and searches keep their
existing keys. Do not leak a namesake native tab into either profile or change
legacy unset/one-list-level behavior. Face-out favourites retain their native
heart/star at the top right; the new Finished/On hold orientation reasons do
not change OrbitUI's all-face-out policy or stored choices. Tests:
`test_upstream_20261012_followup` and native list-density/favourite suites.

The shelf-style picker also exposes `spine_cover_size_pct` (50-150%, default
100%) for each chip, including independent prose/manga profile chips. Only
face-out covers scale: preserve their aspect ratio, the hero, row count,
ornaments and dock/footer reserves. Cap enlargement at the renderer's standing
height above the plank; the shared `_spinePlanBase` must carry the size into
both painting and pagination so wider covers repack rather than overlap.
The reviewed Bookshelf 5.4 merge (2026-10-10) adopts upstream's live-apply
ordinary-chip editor: changes save in memory on selection, deferred/coalesced
preview rebuilds follow, and Close flushes. It no longer offers Save/Cancel.
Profile-chip changes remain immediate. Clearing the size must remove only its
override, preserving other fields. Tests: `tests/test_shelf_cover_size.lua` and
`tests/test_face_out_shelves.lua`.

Cover text is chosen from each chip's long-press menu, not the global Cover
display menu. `cover_label_mode`, `cover_label_custom` and `cover_label_position` live on native tabs
(including nested shelves) or their profile-qualified `profile_shelf_*` record.
The same explicit Title/Author/Series/Custom/None choice drives ordinary and
expanded cover grids and physical shelves, including drills within that chip.
Unconfigured grids retain the legacy global default; unconfigured physical
shelves remain bare. Do not rewrite old settings or automatically enable bands.
Custom editing retains native tokens, debounce, Save/Cancel and a preview scoped
to the original chip/profile; other style edits must survive the save.
The widget's `_bookLabelMode` also drives grid label-strip/cache decisions.
`spineCoverLabel` passes a resolver to face-out covers only, never series boxes,
ornaments or the hero. Default placement stays inside the physical card, above
progress, or below grid covers. The optional `above` placement moves the grid's
existing strip before the book; group text remains unchanged. Physical labels
are separate widgets above the page block, budgeted from existing headroom and,
only if needed, proportional cover downsizing. Page-block, feet and shadow widths
must follow the smaller cover. Never paint outside the row or move the book's foot.
Keep the actual cover-card identity, bounded single-line text, native fade,
status glyphs, opening effects and bitmap ownership; label gestures forward to
that cover. Packing and row height must not change. An undersized row omits the
label instead of overflowing. Placement does not enable text or replace its mode.
The row's optional `label_position` and physical label's `above` builder are
explicit native seams; standalone Bookshelf without these options is unchanged.
The settings row's `book_cover_label` ID and the custom editor's optional scoped
target are explicit upstream seams. Tests: `tests/test_shelf_cover_labels.lua`.

The reviewed 5.4.1 import also has native `cover_text*` settings and a grid-only
caption picker. While embedded, `Editor.cover_text_external` hides that picker
in favour of OrbitUI's existing chip menu. Do not split storage across the two
systems or silently inherit parent captions: native/nested/profile `cover_label_*`
preferences stay independent and unchanged. `_booksLabelNone` must delegate to
the overridable `_bookLabelMode`, not read the native settings directly.
The shared custom editor's `_open` preserves the scoped target and function
preview callback despite the removal of its old group-editing mode.
The 5.4.1 global group-text control intentionally follows upstream: Show author
below series is an on/off switch; a stored Custom group mode reads as Author.
Retain the old custom template on disk for rollback. Book captions, physical
series-box labels and their completion badges are not group-text settings.

The 5.4.3 cross-shelf hero-height reference must query the adapter's scoped
`cover_label_*` modes across native/nested/profile shelves, not `cover_text*`.
Retain the Manga folder-strip exception and the live dock/footer reserve.
Do not change per-chip text placement, series-box captions or stored preferences
to make the new height arithmetic work. Tests: `test_shelf_cover_labels`,
`test_upstream_20261012` and native `_test_list_row_budget`.

Bookshelf 5.4 themes also work on the fixed profiles. Theme/deck identity is
`orbitui:<profile>:<chip>` for a fixed chip, never just `authors`/`latest`, which
both profiles share with native tabs. Keep theme choices in the existing
`profile_shelf_*` records, not synthetic navigation tabs. `themeShelfId` feeds
the theme resolver, planner, manual shuffle and ornament menu. Preserve profile
decks during native pruning and other visual fields during theme edits. Switching
profiles through Other shelves must rebuild even when the restored chip ID is
unchanged. Native tabs and nested shelves retain their own inheritance.
Since the reviewed 5.4.1 import, theme pickers target the actual nested shelf;
choosing its own theme must not modify its parent's or a fixed profile's theme.
Clearing the child's choice restores inheritance and the picker names its parent.
The independent transparent-title/footer override remains global, outside the
new theme parts; theme switching must not reset it. Native one-pixel bare-panel
gaps replace the old dark footer rule, including full-screen modules. Tests:
`tests/test_shelf_themes.lua`, `test_ornament_session.lua`, native
`_test_transparent_labels_footer.lua`. Opening-pose raster columns are clipped
to framebuffer bounds before raw pixel writes; temporary buffers are freed
even after a failed pose (`_test_faceout_pose.lua`).

### Active series-box design: upstream 5.5 trial

The user's subsequent 2026-10-16 request explicitly replaces OrbitUI's box
design with Bookshelf 5.5's native slipcase for testing. The previous design
and its tests are preserved on local branch `design/orbitui-series-boxes` at
`1ae66bd0`; the old two core modules are no longer shipped on main. This is an
approved C07 presentation change, not an upstream pin change or publication.

Native `bookshelf_series_boxes` and `bookshelf_series_box_widget` now own the
grouping, geometry, shadows and painter. OrbitUI keeps boxes enabled on all
eligible physical shelves, including both fixed profiles, without writing
settings or exposing a redundant native on/off switch. Grid/list, remote feeds,
search, opened series and native single-series chips remain unboxed. The
approved October 19 follow-up boxes named series even with one local volume;
the native `prepare` default still flattens singletons when the host opt-in
is absent. Fixed profile IDs must not
inherit an unrelated native tab's source or box preference.

The same follow-up adds folder-backed **Oneshots** boxes only on the fixed
Comics profile's folder chips (Manga/Serier and their folder drills). Match the
exact directory component, case-insensitively, within that chip's root, never
a filename, similar prefix or path outside the root. One box per actual path,
including nested title folders, using only the complete fetched membership.
Deduplicate files, preserve incoming folder order and retain original member
metadata. Do not infer other metadata-free folders to be series or apply this
folder rule on author, latest, TBR, next, search or remote sources.

These boxes keep `kind=folder` and a real path, with a distinct box-cache key.
Native tap/hold, image lookup, bulk selection and persistence use folder
identity, not a fictional series. Opening/restoring the folder fetches current
membership and disables reboxing within it. A one-book Oneshots folder remains
a box at its parent. No representative author/series ornament, series-name
binding override or MAL score may be assigned to the whole collection. Genuine
member series bindings and the shelf's default binding remain available.
Only view records change: never move files, edit metadata or migrate settings.

The open-topped box shows up to eight native member spines above a first-cover
sticker, with its name and full read/total count. Its width follows the native
member-width/name-fit cap. This trial intentionally does not apply our
former whole-box completed mark/fade or manga-style badge. Stored status and
badge/fade preferences remain intact. Keep the all-face-out policy for ordinary
books and opened series, per-chip cover sizing/labels, dock and ornament rules.

The approved 2026-10-17 follow-up preserves the first cover's actual aspect
ratio (portrait, square or landscape), fitting and centering it inside the
front board instead of stretching it. Keep the native box height and maximum
width. The later approved height/binding refinement raises the host minimum
from 70% to 85% of a cover width, still within the native maximum and available
shelf space. `SLIPCASE_COMPACT_HEADS` reduces the exposed member heads and
places the aggregate count there instead of reserving a band inside the front
board. Hide member glyphs in that compact head, avoiding half-visible or
count-obscured status marks; the full read/total still reflects all members.
Leave unused image space as the existing cover-coloured board. The count
shrinks to fit rather than losing digits;
the name stays centered on the whole board, not the narrower sticker. The
ordinary rounded sticker edge remains, but no count notch masks the image.
Crop only the cover widget's `CARD_BORDER` and copy its already fitted image
1:1, with no second anisotropic scale. Free scratch buffers even after paint
errors so the next redraw can retry. `orbitui_ui` enables the new optional
`preserve_cover_aspect` seam; standalone Bookshelf keeps its old default.
This is a small adaptation of the native painter, not a restored second one.

The initial October 18 rating sticker used the folder cards' CountBadge
renderer. The user's subsequent approved follow-up replaces that overlay with
a rounded top-left cutout in the cover, mirroring upstream's count-notch
stencil and its light edge. Keep the normal bold text font, shared badge font
scale and star-plus-two-decimal format, but use the box's name/count ink instead
of the folder-badge background/palette. A small optional `stickerLeftLabel`
hook returns host-owned text; the native painter fits it after image decoding,
without resizing the cover or reserving a new band. This masks only the corner,
not a new anisotropic fit or permanent edit of the artwork.

Keep `+N` and read/total in the head, with the series name below the image by
default. Rating lookup alone leaves native box/cover geometry unchanged.
Omit both cutout and text if the complete
label plus rounded transitions cannot fit; never clip digits or collide with
another label. Missing/removed ratings restore the original corner on repaint.
Own/free only the added text on replacement, widget reinit and teardown.
Repeated adapter installation must not stack effects or alter tap/hold.
The optional hook is not a native Bookshelf dependency on MAL; standalone
rendering without it and folder-card badges are unchanged. See C06 for provider
ownership. Tests exercise the real stencil, including mirrored edges, fit,
repaint, day/night and custom-image refits.

The approved October 18 title-placement follow-up adds **Series box title**
to each shelf chip's hold menu. `orbitui_series_title_positions` stores only
explicit per-shelf choices (`below` or `overlay`), using the same native/nested
and profile-qualified IDs as other chip presentation settings. Default to the
old below-image strip without writing preferences; preserve unrelated/unknown
values and all book metadata. Keep this independent of individual-book cover
captions, folder cards, bindings and theme changes. Translate the new choices
to Swedish for Swedish locales and otherwise use English.

Pass `series_title_position` through the shared plan options/cache key. The
host geometry wrapper sets optional `title_on_cover` only on box shapes; outer
geometry, member widths, shadows, pagination and counts are unchanged. With
the flag, the native painter no longer reserves the title strip, bottom-aligns
the aspect-fitted image inside the normal inset and calls `paintStickerTitle`
before applying its rounded-edge stencil. The host paints an opaque
board-coloured band with the normal day/night name ink inside that image.
Use at most two bounded lines, re-fit after decoded custom-image dimensions
change, and keep clear of the MAL notch. Omit text on exceptionally tiny images
rather than overrun the cover. No image crop/stretch, source-artwork edit,
network lookup or new image-cache ownership. Own/free only the added title
text on refit, widget reinit and teardown; repeated installation is idempotent.
Untouched shelves and standalone Bookshelf retain their prior layout.

The next approved October 17 refinement stops normalizing member widths to the
box interior. Optional `memberSpineWidth` / `packSpines` hooks use the native
page-to-width curve, row-height/DPI calibration and shelf thickness percentage,
then pack a whole prefix left without stretching, squeezing or skipping books.
Use cached print/stable/calibre/filename counts, explicit filename markers or
fixed-layout PDF/CBZ/CBR/DJVU counts. Unknown and reflowable render/legacy counts
use the same neutral fallback; do not hydrate members or read their sidecars
for width. `cachedPageCount` reads facts without validating reading status, so
a changed status/mtime cannot temporarily discard a known width.
Keep the existing cover/outer-width bounds. Leave one contiguous shaded low
interior to the right and match its shadow silhouette; no phantom full-height
volume slots. At most eight whole members are shown, with `+N` for the hidden
remainder separate from the uncapped read/total. Extremely narrow interiors
may show no member instead of clipping its width. All series membership and
navigation remain complete. Standalone Bookshelf keeps fill-to-width unless
the host installs these hooks. Tests: `test_series_box_fill`,
`test_book_bindings`, and `test_upstream_series_boxes`.

Physical book binding is opt-in per shelf: Hardcover (unchanged default),
Paperback (thin, flush soft covers), or Kanzenban / large format. The approved
October 18 refinement replaces the former pale Manga/tankobon jacket with
Kanzenban: the same cover-derived colours and soft boards as Paperback,
12% taller where room permits. The optional `bindingGeometry` hook applies
before row packing and slipcase geometry, bounded by the actual standing
height (including face-out push) and content width. Grow cover width with its
height, never stretch its aspect or change page-derived member/spine thickness.
Keep partial filling, count labels and silhouette shadows. The styles are
presentation choices, not claims to know printed spine art or trim dimensions.
Legacy `tankobon` settings resolve to Paperback without rewriting preferences;
they must not silently select the taller Kanzenban style. Per-series overrides,
keyed by the same series identity as the native menu, win on every shelf and
in opened/pinned series;
Follow shelf removes only that override. Profile-qualified shelf IDs must not
collide with native or other profile chips. Store choices separately under
`orbitui_book_bindings`, preserving all existing settings and book metadata.
Pass the same choices through page planning and rendering; key both the plan
and spine bitmap cache by them. Face-out top blocks and opening poses must
retain the binding. Apply all matching runtime adapters so ornament spacing
and binding skins coexist. As of the reviewed 5.5.4 import, the standalone
component also offers native Hardback/Paperback settings. Native defaults and
rendering work without host hooks, but embedded OrbitUI retains ownership of
its three styles and saved namespace: hide the native chip binding toggle via
`book_binding_external` and suppress the native series toggle when the host's
`seriesBindingButton` exists. Never show two controls backed by different keys,
silently import native choices, or let native plan options override the host's
profile-qualified preferences. Covered by `test_book_bindings`
and the real-loader composition case in `test_runtime`.

Bookshelf 5.5.2 may use an explicit series image instead of the first cover.
Apply the same aspect-preserving fit to either source, using decoded image
dimensions rather than trusting stale file-size metadata. A missing/undecodable
custom image falls back to the first cover and may retry on a later redraw.
Keep cached source buffers owned by the image cache; free only owned scaled
scratch, including after blit failures. Do not move the count onto the picture.

Compact once before page planning and cache signatures; letter jumps use that
same native preparation. Use native full-group fetching, scoped restoration
and numeric series order. The adapter reads legacy `orbitui_series_files` into
the native `series_box_files` field on a copy, and writes both identifier-only
keys on new saves for rollback. Never widen a restored box to another filter
or profile or erase its old saved navigation. Redundant section badges remain
hidden inside series. Tests: `tests/test_upstream_series_boxes.lua`, native
`_test_series_boxes` / `_test_series_boxes_navigation` and existing status suites.

### Archived series-box design

The following specifies the old design retained on `design/orbitui-series-boxes`,
not the active upstream trial. Restore it deliberately, not during an upstream
merge; keep its original tests with it.

Series in the physical bookshelf are now one front-facing slipcase per series,
per the user's concept-B approval. Group the full filtered light list before
the page cache and planner, never a page-sized slice or an open remote feed.
Metadata-free folders must not be guessed to be series. A box retains its full
member list for native drill/bulk actions; author/genre groups keep their raw
members and a separate compact display list. Count display slots in the footer,
and use the same grouping for letter jumps. Opening a series exposes every
volume to the local planner and must not box it again. Preserve the box's member
scope across native drill restoration using identifiers, never cover buffers.
The first volume supplies the cover. Per the user's open-slipcase revision,
side width grows from 20% of cover width by 5 percentage points per additional
volume, capped at 45% (six or more volumes); the count always
shows the actual membership. Plan and paint share this geometry. Cover sizing,
author busts, plank/dock clearance and other view modes must remain intact.
The box is drawn procedurally, with an inset dark opening and up to six
separate rounded bindings, not an image or buffer per volume. `spineSlots`
reduces the visible binding count when there is too little room for proper
gaps. The adapter supplies native `bookLook`: reuse the first volume's planned
look and sample at most five additional visible members through the native
persistent colour cache, at construction only. Never decode all members or
retain their cover buffers. Missing covers use native stable fallback tones.
No preferences or metadata are migrated.
All procedural sleeve fills use `paintRectRGB32`, not `paintRect` (whose C
fast path discards RGB hue). The case board and rim keep a lighter version of
the cached first-cover colour, which is already luminance-capped for native
spine lettering; do not compound that clamp into a nearly black case. Only
the recessed opening and the contrasting title band are deliberately dark.
Night pre-inversion and native greyscale conversion still apply.
Its top and right side share the same `(side, -depth)` projection: the side's
lower edge recedes just like its upper edge, while the front sits level on the
plank. Preserve wallpaper in the unpainted front-left/rear-right corners;
never flatten these into a rectangular top strip or side foot. Rounded spines,
gaps, end highlights and the outer lip stay inside both rims and share that
projection. Use bounded drawing strips, not per-volume buffers, and make
pagination consume the revised widths while preserving the height budget.
The native `SpineShelf.recessColumns` seam returns one shadow column for an
ordinary book, preserving its existing geometry. The series adapter instead
uses `Boxes.shadowColumns`: joined strips matching both sloping edges and the
actual inset from the row baseline. Both asset and fallback shadow painters
must consume them. In particular, the contact shadow must rise with the rear
foot, not leave a flat rectangular band under the side. Build these bounded
strips only for visible boxes, not per frame or per series member.
The front's slim dark title band shows the series name only, without a volume-count
line. Its top-right read/total badge uses the native `bookshelf_count_badge`
renderer (including badge scale, colours and night-mode recolouring) and counts
only canonical `finished` statuses from `Repo.readProgress`, like manga stacks.
Count the box's deduplicated, scoped membership, never a stale group aggregate
or percent read. Sweep members only when building a visible box, using the
native progress cache/invalidation; no status reads during planning or paint,
and no extra persistent count cache. Keep the badge inside the front face and
clear of the title. If a face is too small to fit it, omit it rather than
overflowing the slot. This does not change other views' badge preferences.
When every member of a nonempty box is finished, add the native completed mark
and the ordinary finished-book fade. `SpineWidget.finishedDecoration` is an
optional, render-only factory: it composes a synthetic finished record with no
filepath/cover, returning the native tickbox/bookmark, its real painted bounds
and the existing fade amount. Preserve `progress_badge_style`, the legacy badge
toggle, badge size/colours/night recolouring, and the independent
`fade_finished_books` / `finished_fade_enabled` choices (recessed fade wins).
Do not use the folder fade preference or the representative volume's status.
Place the mark above the title label; paint the silhouette fade before labels
and the mark, with no double-blended edges or wallpaper/plank wash. Keep the
title's explicit contrasting ink and binding colours safe on night-mode flips
and greyscale screens. Use bounded
strips rather than allocating another cover buffer. Reuse the read-count sweep;
partial/unknown/empty membership has no completed treatment, and a rebuild
after reverting a member's status must remove it. Source book status is never
changed. The helper does not alter ordinary book rendering.
The factory's blank synthetic card MUST have explicit dimensions: KOReader's
`OverlapGroup:init` queries every child's size even with an explicit group
size, while bare `Widget:getSize` returns nil. The completion tests deliberately
model this strict contract so a fully read box cannot reintroduce the crash.
Inside a series drill, or a `single_series` chip with no deeper drill, omit
the redundant black section badges below the planks; retain the series heading
and all individual books. `spineShowSectionBadges` in the series-box adapter
supplies the optional `rowWidget.show_section_badges` render policy. Do not
change planning, section metadata, settings or other views. Recompute it for
each row build, including in-place swaps, so leaving the series restores normal
badges and the deferred overlay cannot retain stale labels. Without the hook,
standalone Bookshelf retains its original badges.
Sources: `core/orbitui_series_boxes.lua`, `core/orbitui_series_box_widget.lua`,
`adapters/orbitui_series_boxes.lua`. Tests: `tests/test_series_boxes.lua`.

### Other presentation contracts

Per the user's 2026-10-04 approval, alphabetical bookcase ordering interleaves
series/folder blocks with standalone books. Use the series name as the block's
title, falling back to its first volume's title; author order uses member author
metadata. Keep volumes in ascending numeric order even when reversing the block
alphabet. Sort before slicing, preserve section labels/paths and member metadata
(including C11 ornament matching), and use the same producer/keys for letter
jumps. This policy applies to title/author/series-primary sorts only; date,
status, filename and manual ordering, and grid/list modes, stay native. Never
rewrite stored priorities. The repository's optional `orderShelfSections` and
`orderShelfSeries` hooks are installed by `adapters/orbitui_shelf_sort.lua` via
the UI adapter; the pure policy is in `core/orbitui_shelf_sort.lua`. Reuse the
native SortEngine and existing light metadata, not new I/O or cached covers.
Tests: `tests/test_shelf_sort.lua`; device cases in `SHARED_UI.md`.

Shelf row sizing must subtract the live SimpleUI dock height before splitting
the remaining viewport. Use the shared visible pagination reserve, not just its
outer box: negative top margins can paint controls above that box. Keep this
consistent in `_collapsedSpineSplit`, `_layoutPrimitives` and `_rebuild`; do not
fix overlap by clipping books or changing stored row counts. Tests: Bookshelf
`_test_tall_screen.lua` and `_test_pagination_footer_reserve.lua`.

Material Symbols is opt-in **per icon**, never a whole-pack preset. This corrects
alpha.6's bulk replacement per the user's startup-crash report and request.
Keep existing Nerd Font and image selections, and do not change KOReader's
global symbols/fallback face. Render Material through the existing image paths,
not a custom text font. Preserve the small generic icon/picker seams documented
in `ICONS.md`, including image-only destinations and live titlebar resizing.
Material weight is a per-icon choice (200/300/400/500), saved only when an icon
is selected. Per the user's explicit request, unweighted Material selections
now default to 300 instead of 500; other icon sources remain unchanged. Changing
a preview weight or cancelling must not write settings or alter another icon.
Solar Outline, Solar Line Duotone and Tabler are additional SVG-only per-icon
sources, not presets. Their native shapes/opacity stay independent of Material
weights. Keep the custom manga adaptations, attribution, lazy catalogues and
OTA-safe SVG identities. No global font changes or automatic icon substitution.
Tests: `tests/test_icons.lua`.

Solar Colour and Solar Mono add all 220 SVGs per style from the separately
pinned pxlflux Solar Icon Pack. Keep these sources distinct from Solar Outline
and Line Duotone. Import artwork and license notices only, never the upstream
installer, `pack.lua` or updater. Preserve colours, strokes, opacity and geometry;
use the native colour-preserving image route for Home quick actions and dock
styles, not a recoloured alpha mask. Selection is per icon with no whole-pack
application or startup setting writes. Preserve whitelisted identities and OTA
rebasing (`solar-colour:pack-library`, `solar-mono:extra-rakuyomi`). The builder
and full source/hash inventory are `scripts/build-solar-pack.py` and
`assets/vector-icons/pxlflux-{source,generated}.json`. Tests also cover all icons,
both styles, categories, search, cancellation, native menu registration and
palette preservation (`tests/test_solar_pack_assets.py`, `tests/test_icons.lua`).
The v1.1.0 artwork update adds 60 supplementary icons per style and refreshes
Instapaper/Z-Library without renaming existing identities or rewriting choices.

The built-in SimpleUI `night_mode` quick action retains full icon contrast in
both day and night mode. Its off-state must not look unavailable, regardless of
the chosen SVG, bitmap or font glyph. `adapters/orbitui_icons.lua` wraps the
canonical `getEntry` and copies the shared dynamic entry before clearing only
its `dim` flag. Keep native toggle execution, real screen state, labels, icon
overrides and other actions' dimming unchanged. This applies to quick settings,
Home quick-action rows/lists and the dock; it writes no settings. Regression
coverage is in `tests/test_icons.lua`.

Source: Bookshelf `lib/bookshelf_settings_store.lua`, `lib/bookshelf_widget.lua`;
SimpleUI `modules/module_recent.lua`, `features/library/sui_recent_hidden.lua`,
`engines/sui_screen_engine.lua` and `infra/sui_store.lua`.
Tests: Bookshelf `_test_transparent_labels_footer.lua`, `_test_background_menu.lua`,
`_test_grid_labels.lua`; SimpleUI `_test_recent_hidden.lua`, `_test_progress_badge.lua`.
Verify Home section labels, long-press actions and retained configuration on device.

Section labels are fresh widget instances, not cached widgets which KOReader
may already have freed. Keep pagination callbacks bound to their own screen
and retain screen identity in the primitive label signature. Upstream 2.7.5's
cache-key fix is represented without restoring its widget cache.
Regression coverage: `tests/test_simpleui_upstream.lua`.

Bento Top Margin is per module, including the first module of each column and
later modules stacked in that column. Align columns to the row's top edge;
do not reintroduce the leading column's shared gap or vertical centring that
moves neighbours when one margin changes. Preserve the extra first-row padding
when the topbar is off, full-width spacing and horizontal centring of narrow
rows. Cached layout fingerprints include gaps as well as widths/order. Labels,
backgrounds and clock/book refresh slots stay attached to their own cells.
No settings migration. Regression coverage: `tests/test_simpleui_bento_margins.lua`.

Layout saves preserve per-item visibility for modules that remain placed,
including a hidden clock face with the date/battery still visible. Apply module
enable/disable and text-style resets only to changed membership, not a reorder
or page move. Keep editor drafts and persisted layout tables separate on both
load and save: LuaSettings retains references, so aliasing silently defeats the
upstream membership comparison after the first edit/save. Home and custom
screens keep independent layouts and refresh targets. Regression coverage:
`tests/test_simpleui_upstream_20261006.lua`.

## C08: Assets, data and recovery

The October 25 Bookshelf 6.0 migrations are copy-only while hosted: retain the
old main-file ornament-deck snapshot and its auxiliary-store copy when SQLite
imports it. Code rollback can read the old snapshot; it does not undo later
deck/layout edits. New module-grid positions may be added, but keep legacy
size/page fields for old code. Standalone component migration remains native
when the optional host flags are absent. Failed SQLite import/commit preserves
its source and memo, rolls back and remains retryable. Existing flat/native
paths, profile namespaces, custom ornaments, book sidecars and reading data
must not move. Tests: `test_upstream_20261025`, `_test_ornament_decks_db` against
real SQLite, and the existing storage/ornament/profile suites.

Bookshelf 5.5's author-photo lookup is explicit and separate from the bundled
bust ornaments. Bulk discovery keeps existing/manual images; a failed install
must keep prior files in every format. Rename the completed replacement before
removing obsolete extensions. Photo discovery still recognizes both image-library
roots and both author-name orders. The page-count crash quarantine is separate
from reading progress, and its memory limit is applied only in the render child.
The metadata scanner's temporary nil-count plural guard is restored on success
and error; it must not become a permanent global gettext replacement (C06).

SimpleUI visual defaults remain stable across merges: titlebar, pagination and
cover-title strips are transparent over wallpaper unless explicitly configured;
cover shadows remain opt-in at the existing 4px base. Currently Reading retains
detailed stats and left-aligned descriptions by default. New appearance choices
must not rewrite existing settings. The new placeholder hook and bounded shadow
cache follow C01/C04/C06 ownership rules; see the October 9 follow-up tests.

The October 17 surface migration splits old looks into tone/frame/opacity and
old navigation styles into Full-width/Floating. Copy only into unset fields;
retain old look/style/transparent flags for rollback, and respect explicit new
choices. Preserve legacy bar getters/setters and titlebar-button opacity as an
independent field. Quick-setting button opacity must still render and remain
editable. Backup/preset schemas retain old fields as well as the new ones.
Tests: `tests/test_upstream_20261017.lua`, `tests/test_navbar_margin.lua`.

Embedded resources resolve relative to their component, not the outer plugin
root. Preserve fonts, icons, translations, wallpapers and license notices in
runtime archives. Legacy cleanup must never target the retained old installs.

Shared Material assets resolve from the active OrbitUI runtime root. Keep named
icon selections stable across OTA slots; rebase packaged image-only paths.
Keep explicit weights stable too. Legacy unweighted paths/tokens use the current
default (300); retain flat SVG aliases for older path consumers. Package all
four weight variants and never instantiate a variable font on the reader.
Preserve the pinned source/license, static subset and matching SVG inventory
(`ICONS.md`, `tests/test_material_assets.py`, `scripts/check-package.lua`).
The temporary alpha.6 Material recovery patch only masks affected icon reads
in memory. It must not delete or flush settings, restore a whole old snapshot,
replace global `require`, or bypass the user's existing preload interceptors.
See `recovery/README.md` and `tests/test_icon_recovery.lua`.

Keep the existing settings filenames and schemas unless a separately reviewed,
recoverable migration is required. The automatic first-run snapshot is limited
to UI settings and Bookshelf-owned links; it is not a full device backup.
Never overwrite a completed snapshot or erase sidecars/progress to roll back UI.

Beta 1 also recognizes a native-only Bookshelf 5.3+ installation without moving
its files. Select the native layout only when `settings/bookshelf/settings.lua`
or its `.old` exists and neither flat `settings/bookshelf.lua` nor its `.old`
exists. Keep this decision fixed for the session; flat wins if both exist.
Native settings, auxiliary stores, SQLite companions, caches and status-line
keys stay native. Flat installations retain the old global reader-key wrapper.
Backup native top-level Lua files before component startup and detect them as
an existing setup, not fresh onboarding. Preserve all ornament paths. Tests:
`test_bookshelf_storage_native.lua`, `test_bookshelf_storage.lua`,
`test_backup.lua`, `test_setup_ui.lua`. No storage move/import is authorized.

The approved standalone-configuration work adds a host-owned setup guide
(`core/orbitui_setup.lua`, `adapters/orbitui_setup.lua`). Detect fresh versus
existing configuration before component initialization and persist that decision
in the versioned `settings/orbitui/setup.lua`, never in credential/history files.
Existing installations are not automatically reconfigured. Draft edits and
cancellation must not write UI choices; save only on reviewed confirmation.
Keep existing Home pages, scope IDs, book-close target and accounts. Suppress
embedded SimpleUI onboarding and its automatic first-run startup override only
when OrbitUI owns the instance. Reader-first startup defers automatic setup;
teardown invalidates pending UI callbacks. Optional-integration inspection is
local/read-only and must not call providers or expose tokens.
Tests: `test_setup.lua`, `test_setup_ui.lua`, `test_runtime.lua`,
`test_simpleui_upstream_20261009.lua`. Device acceptance remains required.

The 2026-10-04 Japan ornament request permits one narrow, reversible presentation
migration: disable exact copies of the two bundled stock plants after the Japan
pack has installed successfully. Keep the SVG files, all custom drawings, pack
enablement and frequency settings. Use an independent one-time defaults marker;
never repeat the disable after the user re-enables a plant. Failed copies or
settings writes must not commit that marker. See `ORNAMENTS.md` and
`tests/test_japan_ornaments.lua` for legacy-root and interrupted-install cases.

Source: `core/orbitui_backup.lua`, component embedding changes in `UPSTREAM.md`.
Tests: `tests/test_backup.lua`, `test_runtime.lua`, `scripts/check-package.lua`.
Recovery procedure: `MIGRATION.md`.

## C09: Reviewed imports and explicit releases

October 30 merge-only keeps VERSION/public Beta 16 immutable. Thirteen new Lua
modules are exact source strings in metadata on the existing generated registry,
not extra installed paths. Canonical loader compilation is lazy, real-file and
preload overrides retain priority, aliases share identity, parse errors propagate.
Verify source parity/syntax, sealed all-root tests, unchanged old inventory and
native older-installer upgrade/rollback. Stable bootstrap/API-1 limits stay fixed.

October 28 merge-only maintenance preserves VERSION Beta 14 and all public
tag/asset bytes. API 1 still allows at most 2,000 installed files including the
manifest. New Hazel originals remain tracked unchanged; sealed packages embed
their exact PNG bytes in an existing critter resource rather than add runtime
paths, remove old assets or raise old installer limits. File-based/user overrides
and existing cache/pixel/alpha ownership remain unchanged. The package audit must
check old path-set equality, embedded source-byte parity and unchanged bootstrap.

October 28 user-approved package-size work omits only developer source-location
comments (`#:` lines) from the component `locale/*.po` files when sealing a new
build. Tracked upstream sources and all runtime paths/languages remain intact;
headers, plural rules, messages, flags, legal notices and translator credits are
unchanged. Manifest sizes/hashes describe the optimized bytes. Source-parity
audits must apply this narrow documented transform to PO files, not waive their
integrity checks. Compiled catalog semantics must remain identical. No language
pack split, cache/rollback cleanup, bootstrap change or publication is implied.

The separately approved October 28 storage-cleanup step runs only after the
host confirms healthy startup. A deferred, serialized Trapper worker may
collect at most one strictly older unselected runtime per start, after full
integrity verification of both retained packages. Always keep the factory root,
current and previous selections, pending/equal/newer candidates and unknown or
modified files/directories/links. Require a complete manifest-verified old
runtime before atomically renaming it to `.orbitui-versions/.orbitui-gc-<slot>`.
Keep its manifest until last; resume only when every remaining entry is known
and byte-identical. Recheck activation state and plain paths during deletion;
on uncertainty keep the remainder. No generic recursive delete may collect
arbitrary hash-named slots during preparation. Cleanup must not block startup,
change activation/recovery records or touch settings, caches, reading data,
artwork, standalone installs or external sync owners. Prevent a stale rollback
confirmation from changing selection while the update worker is busy. Preserve
bootstrap API 1 byte-for-byte; no publication is implied by this change.

The monitor can fetch refs and update its one status issue only. It cannot merge,
open merge PRs, advance integrated pins, tag, release or publish OTA. Publishing
to users remains a separate explicitly approved action after reviewed changes.
Both embedded legacy installers remain blocked; OrbitUI OTA must stage and
validate the whole package, not update one component independently. Preserve
the stable bootstrap, deferred activation and previous-version recovery.

The approved 2026-10-19 app-store compatibility work keeps all three bootstrap
files and API 1 unchanged. The active runtime may verify a strictly newer external
root installation after healthy startup, snapshot only its verified inventory and
defer activation to the main process/restart. Never reset the pointer merely
because factory and active versions differ, execute candidate code during copy,
or discard the previous OTA slot. Record an external candidate before activation
to prevent failed-start/manual-rollback loops; explicit Retry is the recovery for
an interrupted marker/pointer write. Beta 1 needs the feature via internal OTA
before it can detect future external overwrites. Tests: `test_external_updates`,
`test_updates` and the full-package native `smoke-ota` scenario. Device acceptance
is separate; this change is not publication approval.

Source: `.github/workflows/upstream-watch.yml`, `scripts/upstream_watch.py`,
`sources.json`, `adapters/orbitui_updates.lua`, `core/orbitui_ota.lua`, `orbitui_bootstrap.lua`.
Tests: `tests/test_upstream_watch.py`, `test_updates.lua`, `test_runtime.lua`,
`test_bootstrap.lua`, `test_ota.lua`, `test_http.lua`, `test_release_package.py`.
Full device acceptance, including the OTA UI, is still outstanding.

Beta 11's hosted component menus must show the running OrbitUI version and its
actual preview/daily/recovery preferences, not standalone component versions,
branch selectors, wake notifications or upstream changelogs. Standalone menu
builders retain their fallback when no host seam is supplied. No component
installer is re-enabled. A GitHub HTTP failure carries only safe status/rate-limit
diagnostics; respect bounded retry/reset hints within the session and never
claim generic 403s are proven rate limits. Trapper must retain those diagnostics
without exposing raw bodies, headers or signed URLs and without activation.
Coverage: `test_update_menus`, `test_updates`, `test_http`.

## C10: Shared panels, search, settings and Home shelves

October 31 user-approved refinements: optional native repository match callbacks
let the shared host implement bounded typo/Unicode matching without a second
index. Preserve exact Swedish spelling priority, profile/current membership,
genre choice, ranking before the cap, native records and inert stale callbacks.
Native callers without options retain their original matching rules.

Browse sort/filter/view choices belong only to their profile/chip/drill identity,
not a destructive chip migration. Keep original source filters first and expose
native page jump/advanced sorting plus explicit per-place defaults. A local
5-percent category must never write read status, annotations, files or remote
progress. Retain native cover-preview pins, renderer/density limits, Android-safe
visible covers and bookcase series blocks. Retire stale menu owners; expire only
listing caches after a choice. Future schema/unknown fields/other places survive.

Settings ancestor navigation preserves the native stack, pages, checks, holds
and close ownership; do not globally replace KOReader menus or painting. Book
details remain the same native panel and reader callbacks: technical metadata
moves into an independently zoomable, lazy, read-only tab, with no network fetch.
Original tabs/cover ownership/plugin actions remain. Extra opt-in timing labels
remain scalar-only and bounded; synthetic CPU tests are not device acceptance.

October 30 approved Kobold design follow-up: shared search keeps ten local
query/scope pairs in the existing SimpleUI store, with explicit Clear and no
provider/account/book records in history. Preserve future schemas; deleted
scopes fail closed. Relevance/title/author/series sorting uses cached fields,
does not mutate metadata, and precedes the shared 400-hit cap; existing groups,
current-shelf membership and caller reader/book-panel paths remain. Retired
search windows/pickers and deferred native-navigation callbacks must be inert.

The optional `CollectionManager.orbitui_edit_contents` host seam is available
only in manage mode for custom collections; standalone/book/bulk membership
behavior is unchanged. The host editor uses LibraryModal and native local
ReadCollection: searchable members, Add books, staged Changes/counts, explicit
Save/Cancel, title/author ordering. No speculative all-library scan on paint,
cover extraction, hidden shelf, metadata/file deletion or remote list writer.
Preserve unrelated concurrent membership, detect replaced/deleted collections
and touched-file conflicts, preflight missing additions, and keep a failed draft
open. Roll back in-memory membership on native write exceptions. Favourites and
folder-managed collections retain their native owner. Close/Back discards only
the draft and retires its callbacks. Both English and Swedish labels are required.
Regression: `test_shared_search`, `test_collection_contents`; physical bilingual
native-font/touch/keyboard/paging/rotation/Back and reader-underlay acceptance
remain required. No publication or performance claim accompanies this change.

October 30 approved Bookshelf-OS follow-up: small quick-control dialogs reuse
native widgets/PowerD/core network/statistics owners in the existing chrome
adapter. Status taps default off and saved bars/layouts remain unchanged; an
addable shared action and searchable SV/EN settings entry expose the same UI.
Home preserves custom corner/hold behaviour; Shelf preserves custom gestures,
job Stop/page dots and expanded-return taps. Do not parse custom status tokens
into guessed icon zones or build a hidden shelf. Read local state only when
opening/explicitly refreshing, never cold-load NetworkMgr (which can restore
Wi-Fi), scan/connect while painting, infer Android connectivity from no-toggle
shims, manufacture network events or add a synchronization writer. Use actual
native light ranges/warmth conversions/readback and keep a native fallback when
sliders cannot fit. Owner/navigation/rotation/suspend/close guards invalidate
retired callbacks; popup hardware/status UI does not navigate or close books.
Keep canonical/preload identity and existing global menu hooks untouched.
Tests: `test_quick_controls`, including complete Topbar and optional native
ButtonDialog, plus existing settings/navigation/host/reader/cover tests.
Physical native-font/touch/focus/PowerD/system-return/underlay acceptance remains.

October 30 local device-regression fix: the optional `sui_core.beforeGesture`
seam must route only an enabled, current, painted Home/custom-screen status cell
before Home's full-width priority menu zone. Keep native FM/other host routing,
custom corners, holds/swipes, whitespace menu taps and touch-input disabling.
Cells stay mounted while disabled and read the opt-in at dispatch time; toggling
must not need a restart or invalidate book/provider caches. Quick-control dialogs
use the documented `sui_native` opt-out of automatic NativeSheets conversion:
preserve the actual dialog identity rather than weakening stale/modal/lifecycle
guards to accept unrelated topmost windows. Other dialogs still convert normally.
Tests load the whole Core/NativeSheets and minimum/current native input/dialog
boundaries. The Bigme light failure outside OrbitUI is a separate hardware/API
compatibility investigation, not a claimed fix or reason to add guessed writes.
No upstream import, preference migration, publication or new device acceptance.

October 29 approved category-card settings start: keep the same five stable
category IDs, explicit Home/SimpleUI identity, SV/EN summaries, existing search
and all native submenus/scopes/callbacks. Build static descriptions only, without
opening a shelf, native settings builders, providers or preference writes.
Measured wrapping, responsive columns/paging, touch/keyboard exit and a complete
list fallback must keep every destination accessible. List and category Back
return to cards; search results retain their query; obsolete root/dialog and
deferred-shelf callbacks cannot cover a newer destination. Reuse native modal
chrome/focus/close semantics with a read-only spacing seam, not global menu or
private-upvalue replacement. No third-party plugin or new runtime file. Tests:
`test_settings_start` and existing settings/navigation suites. Physical native
fonts, SV/EN layout/touch, rotation, sleep and reader-underlay acceptance remain.

Home book actions and search results reuse the real Bookshelf detail panel.
Its detail-only controller must not initialize a hidden shelf, claim the live
widget, register shelf timers or replace repository callbacks. Keep registered
file-dialog actions, their close/navigation callbacks and module-specific actions.
Opening the panel reads cached Hardcover data only; C05 still governs all writes.

Home shelf modules persist profile/chip references, not copied file lists. Resolve
current source/filter/sort through Bookshelf. Missing or empty sources must never
fall back to unrelated recent books. New modules get a new Home page, leaving the
existing arrangement intact. Each carousel has its own context/index/settings.
Removing from Home must preserve placements on Custom Screens and book files.

Search uses the repository's metadata and explicit all/prose/comics/current
scopes. Apply current-shelf membership before the result limit. Preserve group
results, the typed query when switching scope, and the caller's reader-opening
path. Remote OPDS catalog search remains separate.

The settings hub delegates to existing component controls and storage. Both
native Tools settings entries use one shared menu key. Keep legacy dispatcher
actions, the advanced SimpleUI window and the single OrbitUI updater available.
No silent settings reset, new sync owner or automatic release accompanies these
UI changes.

October 26 user-approved local redesign: keep five task areas and settings search,
with Home explicitly identified as SimpleUI in Swedish and English. New labels,
help, scopes and search vocabulary must support both languages; user-entered
names remain values, not translation keys. Global Bookshelf settings must never
be presented as profile-specific. Show library/shelf/theme and SimpleUI editing
scopes honestly without changing their storage scope. Direct visibility switches
delegate to the original region/tag callbacks, preserve templates/other choices,
and reflect the labels line's effective visibility. A label switch may enable
its master line, but must keep other category flags and explain this behavior.

Search is static, bounded and local: never index credentials/current values,
invoke a provider/native callback, or mutate settings to build results. Retained
native wording is checked against the generated static vocabulary after imports;
unknown future native controls remain reachable in Advanced. Use stable metadata
IDs, not translated-label or numeric-position matching. Native controls retain
their callbacks; scoped wrappers are shallow copies, not a preference migration.
Back/close-all remain distinct and delayed library openers are cancelled by a
newer settings destination. The optional menu-host Back and SimpleUI title seams
must leave standalone behavior unchanged. Contextual shelf/panel shortcuts keep
the real edit/detail actions and gesture/selection gates. Regression:
`test_settings_navigation`, `test_shared_settings`, `test_settings_i18n` and
`scripts/settings-search.py --check`. Physical bilingual layout/touch/Back and
reader-return acceptance remains outstanding; no release is implied.

Source: `core/orbitui_context.lua`, `orbitui_shelf_query.lua`,
`orbitui_search.lua`, `orbitui_i18n.lua`; adapters `orbitui_ui.lua`,
`orbitui_book_panel.lua`, `orbitui_home_shelves.lua`, `orbitui_settings.lua`.
Tests: `tests/test_shared_book_panel.lua`, `test_shared_home.lua`,
`test_shared_search.lua`, `test_shared_settings.lua`.
See `SHARED_UI.md` for the minimal component seams and device checklist.

The 2026-10-18 **Reading dashboard** is an opt-in external SimpleUI module and
an additive first Home page, never a migration of the user's existing Bento
layout. Disabling it removes only that module and empty generated pages;
later user edits, other Home/Custom Screen pages, wallpaper, fonts and dock
preferences survive. Preserve native open/hold handlers, independent cover-row
pagination, cover-cache ownership and stats/cover refresh slots. Each cover row
has its own previous/next arrows and page counter below the covers, with no
wraparound at either end. Hide controls for a single page, clamp saved positions
when a source shrinks, and never change the Home page when paging a book row.
The enlarged controls sit near each card's bottom without overlapping covers.
Interior horizontal swipes starting anywhere in either cover-row card (including
the heading or pager) use the same clamped paging callback as its arrows. Consume
boundary, empty and single-page swipes too; clear pending holds, never open a book
or fall through to Home paging. Rebuild swipe regions/callbacks with the content.
Expose `onSwipe` for the native screen engine's book-module routing, not an
independent swipe gesture range that bypasses screen-edge priority. Other cards,
vertical/diagonal swipes and screen-edge gestures retain native handling.
Its height reserves the dock-adjusted content bounds, module margin and pager;
font sizes must not double-apply device DPI. It owns its individual card chrome,
so native whole-module background controls must not be offered as if they affected it.

Dashboard card headings have independent, per-screen overrides under the
`orbitui_dashboard_heading_` keys in the existing SimpleUI store. Preserve
user-entered text across language changes, refreshes and cover-row pagination.
Empty input or an explicit reset removes only that card's override, restoring
the translated/dynamic default (including last-opened and remote goal titles).
Do not rename ordinary modules, metadata, remote goals or other screens.
Headings stay single-line and width-bounded without changing cover geometry.

Reuse native recent-book filtering/metadata, the New Books source, the cached
BookOrbit Want to Read list and StatsProvider. Ongoing rows omit the hero,
duplicates, unread, abandoned and finished entries. Use the configured
Hardcover goal when that module is enabled, otherwise the local annual goal;
an unavailable remote goal must not be silently replaced with unrelated local
numbers. The dashboard participates in the existing Want to Read auto-refresh
gate, respecting its opt-out, without introducing a sync writer, network paint
work or a remote-download action. It does not import the future BookOrbit UI.

The user-approved standalone stage 2 (2026-10-19) makes these cards configurable
per Home/Custom Screen prefix. Preserve the original default geometry and old
BookOrbit choice on existing installations; new screens default to local TBR.
Use stable card IDs, a versioned config, separate headings, six reorderable main
blocks and four separately hideable/reorderable statistics within their group.
Hidden blocks leave no holes. The view must rebuild touch/swipe/cover regions
from current geometry, keeping cards and controls inside the dock-safe body.
An entirely hidden dashboard has a settings affordance. Layout restoration is
confirmed and affects only visibility/order, never sources/headings/other pages.

Both cover rows bind read-only to native TBR/new/recent/collection producers or
saved Bookshelf references through `core/orbitui_shelf_query`, including current
scope/filter/sort and flattened series membership. Missing, disabled or deleted
sources fail closed; unsupported schemas are not overwritten. Only the changed
source resets its pager; reordering preserves independent pagination. Hidden
cards do not load their book/goal providers. Extend the existing BookOrbit
auto-refresh gate only for visible BookOrbit-backed rows, without overriding
other modules or the global opt-out. Goal source may explicitly select local or
Hardcover while the automatic mode retains existing behavior.

October 28 user-approved card colours are scoped independently under each
screen prefix's orbitui_dashboard_colour key. Off is the default; Accents and
Tinted cards do not alter layout, headings, sources, dark-hero preference or
other SimpleUI/Bookshelf colours. Monochrome/colour-disabled readers retain
the exact greyscale route while preserving the saved choice. Stable IDs own
palette roles after reordering. Night palettes account for native inversion;
text stays native black/white with contrast tested in logical display space.
RGB fills/borders use colour-aware primitives, including older FrameContainer
implementations. Cover arrival recolours only the hero frame: text/actions/
pagers keep their identities. Read at most 64 pixels of an already-borrowed
native cover, cache at most 32 weak-keyed derived strings, retry after a missing
or replaced bitmap, and never decode, mutate, scale, invert, retain strongly,
free, write settings/data or fetch artwork to compute a colour. The native
night-mode layout invalidation rebuilds these palettes too. Own OrbitUI palette
and RGB-bucket code; no BookOrbit implementation/assets are imported.
Tests: test_dashboard_colour, test_dashboard and test_dashboard_config.

Source: `core/orbitui_dashboard.lua`, `adapters/orbitui_dashboard.lua`,
`adapters/orbitui_dashboard_view.lua`, `adapters/orbitui_dashboard_sources.lua`,
`adapters/orbitui_dashboard_settings.lua`, explicit UI loader/settings seams.
Tests: `tests/test_dashboard.lua`, `test_dashboard_config.lua`, `test_shared_settings.lua`; optional schematic
from `tests/dashboard_preview.lua` uses synthetic covers/approximate text, not
real-device output. Check native fonts/touch, offline cache, rotation, night
mode, sleep/resume and book-close updates on the Bigme before device acceptance.

## C11: Author-bound ornaments

User-approved change, October 19, 2026: optional data-only add-ons supersede the
automatic pack seeding described in the historical notes below. No preset seeds
artwork. `adapters/orbitui_addons.lua` owns install/update/disable/uninstall and
bridges managed roots through the native optional `acceptFile` seam. The optional
browser `packGroup` seam presents old Manga folders as one pack without changing
their stable identities. Preserve these hooks during subtree merges; standalone
Bookshelf keeps its original behavior when hooks are absent. Dynamic manifest
bindings extend the author/series matches without replacing existing aliases.
`docs/ADDONS.md` defines the independent release channel, preservation rules and
tests. Never erase old folders or reading/theme data to migrate the add-ons.

Information cards are bilingual data carried by each add-on. Preserve the optional
`bookshelf_ornaments.resolveInfo(record)` seam inside native layer resolution:
Swedish locales select `info_sv`; every other language selects `info_en`.
`info_source` must equal `info` before translation is applied, so a reader-edited
caption still wins. Reader-level overrides must not inherit translations from a
lower pack layer. The builder checks source hashes, full translation coverage,
source/licence links and the native 4000-byte caption limit. The frozen legacy
inventory remains unchanged; old local packs gain translations on explicit
add-on installation/update, not through automatic settings rewrites.

User-approved placement choice: each installed logical pack may opt into random
placement, applying across its enabled shelves/themes. Missing/unknown settings
mean matching (the default) without migration writes. Persist the local choice
through independent updates/reinstalls; never take it from remote metadata.
Random pieces, including busts, join the ordinary deck and its one-per-row cap,
balanced spacing, frequency, disabled-state and bare-row rules. Matching author
busts keep priority and the multiple-bust exception. Do not reshuffle or rewrite
saved decks on a mode change; invalidate row/page caches, including parked widgets.
Ordinary boundary pieces must fit alongside their book in both measurement and
placement; shrink/omit oversized pieces as for targeted ornaments. The rules
below about author/series adjacency and excluding bound pieces from the ordinary
deck apply in default matching mode. Tests: `test_addons`, `test_addon_ui`,
`test_author_ornaments`, `test_ornament_spacing`, `test_ornament_session`,
`test_appearance`.

In matching mode, author busts and trial copies never enter the ordinary deck.
Match full author metadata, not filename/title substrings or multi-book folder
representatives. Keep each bust adjacent to its book through fill, page planning
and balancing; disabled shelves, packs and pieces must stay disabled. Native
ordinary ornaments keep their frequency setting and their order within a session.
Author runs reset on page boundaries identically in the pagination and display passes.

The user's subsequent 2026-10-04 request limits each physical shelf row to at
most one ordinary ornament. Their follow-up explicitly exempts author busts:
several can stand together at their matching books, without an additional
ordinary piece on that row. Never move busts to unrelated books or rewrite
user settings. Reserve before filling, apply the same rule in pagination and
display, and constrain balancing as well. A book/bust pair too wide for the
remaining room moves to the next row, not to a detached decorative slot.
Keep ordinary gap/end choices when a slot is free, zero for None, and at most
one ordinary piece on bare rows. Suppressed slots do not consume deck cards.

The user's 2026-10-18 approval adds the Manga miniature pack: Kaneda's motorcycle
for Akira, the Walking Mushroom for Dungeon Meshi / Delicious in Dungeon, and
the mortar for The Apothecary Diaries. Match exact series metadata aliases via
`core/orbitui_manga_ornaments.lua`, including compact series boxes and explicit
series-group members. Never infer a series from a title, author, filename or a
multi-book folder's representative. Exclude these pieces from random dealing
and bare shelves, just like busts, but count them as ordinary decorations:
at most one per row, and author busts keep priority. Reserve before the native
dealer, preserve adjacency during balancing, and reset series runs at the same
page boundaries in pagination and display. Disabled packs/pieces and None stay
disabled. The new pack has its own additive installer marker; it must not reset
older art, placement or theme selections. Zoom uses the native tap/info fields.

The same day's follow-up adds eleven series-bound pieces in the independent
Manga II pack: Natsume, Witch Hat Atelier, Nausicaa, Frieren, Chainsaw Man,
Dandadan, One Piece, Girls' Last Tour, Laid-Back Camp, Orb and Yokohama Kaidashi
Kikou. Keep the separate installer marker so adding this pack cannot overwrite
Manga metadata or resurrect its deleted files. Known Omnibus/Deluxe series
aliases and typographic apostrophes must match without substring inference.
The same adjacency, row limit, author priority, disabled-state and zoom rules
apply to both packs. Captions distinguish thematic still lifes from fan art;
source/provenance notices and unmodified generated PNGs ship with each pack.

The user's 2026-10-19 approval adds Manga III: an original thematic telescope
for Insomniacs After School and a generic bungalow for Hirayasumi. Preserve
all the same matching, row-cap, priority, enablement and zoom contracts. Use
the independent `ornament-manga-iii-v1.installed` marker rather than changing
either earlier pack's marker or defaults. No third-party model/render is used;
captions must not present the generic designs as exact canonical replicas.

For ordinary end ornaments, distribute unused room evenly between the ornament
and its two slot boundaries (shelf end and adjacent book). The optional
`SpineShelf.positionOrnamentX` seam is installed by `adapters/orbitui_ornaments.lua`
and also handles a section's ordinary leading piece. This is paint-time alignment
only: preserve book coordinates, reserved widths, paging, deck order, vertical
placement and the ornament widget's tap/hold area. Never center a leading piece
over a separate left-end piece. Keep author busts and series miniatures adjacent to their books and
honor explicit negative padding/overlap; tight slots retain native placement.
Standalone Bookshelf, middle gaps, bare shelves and the pack editor retain their
native layout. See `core/orbitui_ornament_spacing.lua` and
`tests/test_ornament_spacing.lua` when merging row-rendering changes.

Per the user's 2026-10-04 approval, the ordinary deck now shuffles once per
KOReader process. With the reviewed 5.4 per-shelf decks, this means once per
shelf identity, on its first nonempty `Deck.sync(all, shelf)`, after bundled
seeding. `_ornSig` synchronizes before capturing the first page signature;
listing alone must not create an anonymous shuffled deck. The adapter's guard
belongs to the canonical deck module, not a widget, and uses the qualified
profile ID from C07. Never reshuffle a visited shelf on redraws, reader returns, directory
polls or normal resume. Empty catalogues defer the first shuffle; an exception
logs once and cannot repeatedly stall rendering. Preserve native generation/epoch
updates, cached list identities and manual shuffle/swap behavior for the rest of
the session. Automatic shuffling does not enable disabled pieces/packs or place
author busts randomly. Keep this explicit user-approved exception to upstream's
cross-restart fixed order in future merges. See `tests/test_ornament_session.lua`.

The reviewed 5.4.3 import varies the initial deal and placement seed by drill
identity, without creating another shuffled deck. Both the page-map plan and
page-one renderer must use `_ornFirstState`; revisiting the same author/folder
keeps its deal during the session. Profile deck namespaces, author matching and
the per-row ordinary-piece limit still apply inside drills.

The adapter wraps `bookshelf_ornament_deck.fillHooks`, preserving `avail`, `lead`,
`gaps`, `placed`, `empty_ok`, `squeeze`, `stop`, `final`, state and bare-row behavior.
Native `final()` must continue pinning lead placements and retaining mid-row
book/ornament pairs. Changes to these hooks or the entry's author metadata need
review during future upstream merges. The row cap uses two opt-in component
seams: `fillHooks(env.max_per_row)` exposes `row_count` for a row's author
reservation (one reserved native slot regardless of how many matching busts);
`hooks.final()` may return a fifth row-acceptance callback. `SpineShelf.plan`
forwards it as `opts.row_accept` to `SpineLayout.balanceRows`. Preserve those
optional hooks without imposing OrbitUI's limit on standalone Bookshelf.

Seed assets from the selected OTA runtime once, with attribution and notices.
Never overwrite existing artwork or user-customized placement fields, resurrect deleted packs,
or mark a failed copy complete. An installation error must not crash startup.
The software license must not obscure the separate artwork licenses.
New bundled packs use independent install markers: adding Authors must not
invalidate the Modernists marker or rewrite its user-editable metadata. Name
aliases may cover known transliterations but must still match full names.

The user's 2026-10-06 author-info request adds offline Swedish biographies for
all eleven bundled busts, using the native tap-to-zoom/info panel. Keep the
life/writing/major-works text and its primary-source links distinct from the
artwork credits, which remain verbatim below it. Label the biographies as
AI-assisted OrbitUI summaries, not copied institutional text. Enforce the native
4000-byte UTF-8 info cap. No new UI, image, matching or placement logic is needed.
A caption-only migration compares each existing info field with the frozen
published alpha.20 baseline. Update only exact defaults plus unedited READMEs;
preserve edited/empty/deleted info, native reader overrides, other metadata,
images, notices, deletions and the preview trial pack. Independent per-pack
update markers follow successful atomic writes; failed updates retry without
replacing later edits or replaying a completed pack. Do not reset seed markers.

The subsequent explicit "Ta Kielce-bysten" request permits replacing Kafka's
default image only. Keep its canonical filename, author matching and biography.
Use the licensed Kielce photo adaptation, with bronze colour/hat retained,
separate photographer/sculptor credit and rights basis. Do not present the
AI-assisted cutout as an unmodified photo. A separate checksum-guarded migration
owns Kafka's image, default caption and base-offset change; the generic info
updater skips Kafka to avoid adding new credits to custom artwork. Recognize
old/current image hashes for resumable atomic writes. Preserve edited/deleted
artwork, deleted metadata records, custom captions and placement, reader
overrides, enablement and other busts. Add the dedicated license notice and
update shared notices only on exact old checksums. Never reset seed markers.
Do not hash images again after the independent completion marker is present.

The explicit "Ersatt Mann" request adds a second, independent artwork-aware
migration with the same preservation contract. Use the reviewed Seitz portrait
photo cutout, retain the canonical name and author biography, and update only
the exact old PNG, known captions/default lift and checksum-recognized notices.
Skip linked Authors directories, images, metadata and notices. The generic
biography updater must skip Mann too. Record the photographer's CC BY license
separately from sculpture rights: this local replacement is NOT cleared for
public distribution. Do not push or publish it before the review in
`THOMAS-MANN-SEITZ.txt` is resolved. Joyce, Woolf, Kafka and other images stay
unchanged by that Mann-only change.

The subsequent approval of Molgreen's Wikimedia photo replaces that held
AI-assisted Mann bitmap, not its rights status. Preserve source pixels and
bronze colour via a reviewed alpha mask and proportional scaling. Keep the
CC BY-SA 4.0 photo/adaptation terms separate from the German panorama basis.
Use `mann-photo-v2.json` and an independent v2 marker to recognize both prior
exact PNGs and current PNG for retry, all known captions, both default placement
triples and old notice hashes. A completed v1 marker must not block v2. Keep
the v1 baseline frozen, preserve custom/deleted/linked files and native settings,
and never attach new photo credits to unrelated custom artwork. No other author
bitmap changes. The retired bitmap remains held in local history too; do not
push ancestor commits containing it. Current source licensing does not clear
the retired adaptation. Tests: `test_mann_update.lua`, `test_mann_assets.py`.

The subsequent shelf-photo feedback authorizes a compact Mann base and a more
legible Hemingway, still using original photo pixels without invented anatomy.
Mann v3 excludes the wide mounting plate and adjusts default scale. Hemingway's
level pedestal crop and shorter canvas remove excessive transparent headroom
without stretching shoulders or enlarging the image beyond row height. Keep all
published baselines frozen. Independent Mann v3 / Hemingway v1 markers and
`orbitui_single_ornament_update` retain the same exact-checksum, retry, symlink,
custom-caption/placement and deletion protections. Alpha.22's completed markers
must not block either refinement. Seed Hemingway's dedicated hash-scoped notice
and run its migration after Mann, before the other author migrations. No changes
to upstream layout code or other authors. `test_bust_refinements.py` locks the
published baselines, unchanged authors, geometry and upgrade source hashes;
`test_mann_update.lua` exercises both concrete updater definitions.

The subsequent explicit "Kor, och ersatt de andra" approval authorizes the six
photographic replacements: Strindberg/Eldh, Hamsun/Frolich, Dostoevsky/Laveretsky,
Dylan Thomas/de Wet, Lem/Kurkowski and Musil/Bavaud (Geneva, not Belvedere).
Preserve photographic surfaces and material colours using alpha masks and
proportional resizing, not generative redrawing. The independent
`orbitui_sculpture_updates` migration and `author-sculptures-v1.json` baseline
replace only exact old defaults, known captions and unchanged placement triples.
New hashes support resumed partial batches; copy the hash-scoped dedicated
AUTHOR-SCULPTURES notice, replace shared notices only on recognized old hashes,
and preserve custom/deleted/linked images and metadata. Generic author-info
migration must skip all six too. Run seeding, Kafka, Mann, this batch, Lispector
retirement, then generic biographies. Never reset previous markers.
Source photos stay outside runtime/repo; checked-in masks/provenance reproduce
the images offline. Keep photo licenses separate from sculpture rights; the
Mann release hold remains. Tests: `test_sculpture_updates.lua` and
`test_sculpture_assets.py`, plus seed, biography and package checks.

The subsequent Svevo/Hemingway approval adds `Authors II` with an independent
`ornament-authors-ii-v1.installed` marker. Do not enlarge or reset older pack
markers, rewrite their metadata or change the frozen replacement baselines.
Match Hemingway (including Ernest Miller Hemingway) and Svevo (including his
full Schmitz names) via the same author-bound planner, never surname substrings.
Use Mayer's Trieste bust and Boada's Cojimar bust with deterministic photo masks,
offline Swedish biographies, separate credits and native tap-to-zoom. The
Highsmith source is 06293: its recorded pre-mask crop avoids downsampling the
small sculpture inside the large original. Keep source/mask/PNG hashes and
original pixels reproducible. No Dazai asset is bundled without a suitable
licensed photo of Nakamura's Ashino Park statue. Public redistribution reviews
and Mann's existing release hold remain; no automatic OTA follows this addition.
Tests: `test_author_addition_assets.py`, seed and author-planner regressions.

The user's 2026-10-06 request to remove the old Lispector portrait is a narrow
exception to additive-only artwork installation. Omit its PNG and current pack
metadata/provenance from new runtimes. A separate one-time retirement removes
only the exact published SHA-256 at `Authors/Clarice Lispector.png`; never follow
file/pack symlinks or remove custom replacements, metadata, notices, settings or
other packs. Preserve the author binding for reader-provided images. Skip the
retired entry in generic biography updates/builds, keeping its researched source
and historical migration baselines. Mark only after successful deletion; retries
must preserve later reader edits and completed markers prevent rehashing. No Rio
image is bundled. Do not reset seed markers, restore the old image or alter any
other author's artwork. Test the retirement and inclusion/exclusion in packages.

The subsequent approval of the frontal Ahrens photograph authorizes a new
non-generative mask of that original, not reuse of the held image_gen output.
Retain the original bronze head, neck, block and thin plinth, without changes
to colour, facial detail, proportions or camera angle. The granite column and
surroundings are excluded. Photo/cutout terms are CC BY 4.0, documented separately
from sculpture rights. Mann v4 adds exact alpha.23 defaults to its frozen
baseline; completed v1/v2/v3 markers must not block it. Preserve all earlier
baselines, the biography before artwork credits, other author assets and the
same custom/deleted/linked image and setting protections. No version bump,
release or change to the held bitmap's status is implied by this approval.

The Japan pack uses ordinary native ornament placement, never author binding.
Keep its install and defaults markers independent of the author packs. All
bundled packs share `core/orbitui_ornament_install.lua` for additive atomic copies;
an error installing Japan must not prevent author installation or native listing.
The five colour PNGs must retain their alpha/provenance and separate notices.

The 2026-10-05 Ukiyo-e Gallery request adds a fourth independent pack. Use
native theme discovery, wallpaper/plank selection and zoom/info cards without
changing component code. Seed nested `theme/` files additively too, committing
the marker only after the entire pack arrives. Never auto-select the theme or
rewrite ornament enablement/colours/wallpapers; its frames join the ordinary
session deck before the startup shuffle, not the author-matched pool. Keep
each museum image's CC0 evidence and provenance. Museum works are scaled
proportionally, never cropped, recoloured, mirrored or AI-reinterpreted. The
generated washi/wood materials are separately identified. No third-party paid
ornament-pack assets or text are bundled. Source materials/build tooling stay
out of OTA packages; the runtime needs no network or image-processing tools.

The user's subsequent wall-placement/info correction permits a narrow v2
metadata migration, not a new seed or general overwrite policy. Compare against
frozen alpha.19 defaults: change untouched `lift` (0 to 0.12) and `info` only.
Preserve explicit reader positioning, edited fields and deleted records/files;
never rewrite reader settings or PNGs. Untouched notices/provenance may follow
the new metadata. Commit the independent update marker only after all atomic
writes succeed. Keep museum catalogue facts separate from labelled AI-assisted
Swedish editorial summaries and retain each summary's primary-source URLs.

The user's 2026-10-06 follow-up requests more wall clearance: v3 raises the
default lift to 0.20, measured from the book-foot line, to clear the painted
plank's receding top surface. Use a separate v3 marker and frozen alpha.20
placement baseline to update untouched 0.12 placements even after v2 completed.
Direct alpha.19 upgrades still receive the info correction and the new lift;
an existing v2 marker must prevent replaying that older migration. Preserve
all reader/pack placement overrides, deletions and image bytes as above. Only
the byte-identical alpha.20 README may follow this placement-only correction;
its info cards and provenance are not changed. Test against the painted plank
surface, not merely the book-foot line, including DPI and row-size variations.

Source: `core/orbitui_author_ornaments.lua`, `adapters/orbitui_ornaments.lua`,
`core/orbitui_runtime.lua`, `core/orbitui_japan_ornaments.lua`,
`core/orbitui_ornament_install.lua`, `assets/ornaments/Modernists/`,
`core/orbitui_author_info.lua`, `assets/ornament-updates/author-info-v1.json`,
`core/orbitui_kafka_update.lua`, `assets/ornament-updates/kafka-kielce-v1.json`,
`core/orbitui_lispector_retirement.lua`,
`assets/ornaments/Authors/`, `assets/ornaments/Japan/`,
`core/orbitui_ukiyoe_ornaments.lua`, `core/orbitui_ukiyoe_update.lua`,
`assets/ornaments/Ukiyo-e Gallery/`, `assets/ornament-updates/ukiyoe-gallery-v1.json`,
`assets/ornament-updates/ukiyoe-gallery-v2.json`.
Tests: `tests/test_author_ornaments.lua`, `test_ornament_seed.lua`,
`test_author_info.lua`, `test_author_info_assets.py`,
`test_kafka_update.lua`, `test_kafka_assets.py`,
`test_lispector_retirement.lua`,
`test_japan_ornaments.lua`, `test_ornament_session.lua`, `test_ornament_assets.py`,
`test_ukiyoe_ornaments.lua`, `test_ukiyoe_update.lua`, `test_ukiyoe_assets.py`;
`scripts/check-package.lua` requires all pack files.

## Recording an intentional contract change

Name the contract, explain why the old behavior is no longer required, record
the user's approval and update tests plus the device checklist. Append the
result to `MERGE_LOG.md`. Do not silently delete a contract to make a merge pass.
