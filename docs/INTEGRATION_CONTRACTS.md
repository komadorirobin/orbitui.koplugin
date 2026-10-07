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

Home belongs to SimpleUI; prose and manga library views belong to Bookshelf.
Keep the dock's active item, profile roots and current drilldown consistent.
Do not let a generic Show/PathChanged event steal a destination already chosen
by another component. A stale deferred callback must not reopen the previous
book or raise the wrong screen.

Preserve the warm shelf on an ordinary reader return, but drain windows on
exit. Closing a book via gesture, menu or end-of-book dialog must reach the
intended destination without a second menu layer or prolonged input blocking.
These are historical regressions, not merely cosmetic preferences.

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

## C05: Synchronization has explicit owners

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

MyAnimeList, Patch Manager, manga-header patches and BookOrbit undo-opening
support are external integrations, not features reimplemented by this import.
Preserve the canonical `lib/bookshelf_*`, `infra/sui_*` and legacy `sui_*`
module identities and package.preload priority. Do not globally replace require,
gettext or DataStorage. External plugins may load helpers before OrbitUI init.

Do not import a future upstream "disable incompatible plugins/patches" feature
without reviewing exactly which local integrations it would disable. A clean
Git merge is insufficient approval to change the user's enabled integrations.

Source: `core/orbitui_runtime.lua`, component i18n/path helpers and the bridge.
Tests: `tests/test_runtime.lua`, component language tests. Device checks: MAL
folder actions/rating badges/completion, manga volume suffix and bookmark ribbon,
patch updates and undo-opening behavior. Their external code/server state must
be inspected separately before changing their contracts.

## C07: Presentation and preferences

Retain the user's independent prose/manga configurations, backgrounds, fonts,
dock and custom Home/Bento layout. "Show section label" must still show labels.
Transparent book-title/page-indicator backgrounds must not also erase the hero
panel or chip bar unless those independent controls are explicitly changed.
Keep hiding accidentally opened books distinct from deleting book files or
resetting all reading data.

Per the user's 2026-10-04 request, the shelf/spines view faces **all books**
cover-forward, including existing prose/manga chips and profile overrides.
`adapters/orbitui_ui.lua` sets the widget's native face-out policy to `all`;
rendering and pagination must continue to share the native geometry. Ordinary
grid/list/Auto modes and shelf decorations remain unchanged. Retain saved
orientation choices for rollback rather than migrating preferences. The chip
editor's optional `face_out_override` makes its row read-only and report All
books, without changing the draft. Tests: `tests/test_face_out_shelves.lua`.

The shelf-style picker also exposes `spine_cover_size_pct` (50-150%, default
100%) for each chip, including independent prose/manga profile chips. Only
face-out covers scale: preserve their aspect ratio, the hero, row count,
ornaments and dock/footer reserves. Cap enlargement at the renderer's standing
height above the plank; the shared `_spinePlanBase` must carry the size into
both painting and pagination so wider covers repack rather than overlap.
Retain the preview/cancel semantics of ordinary chips and immediate persistence
of profile chips. Tests: `tests/test_shelf_cover_size.lua` and
`tests/test_face_out_shelves.lua`.

Series in the physical bookshelf are now one front-facing slipcase per series,
per the user's concept-B approval. Group the full filtered light list before
the page cache and planner, never a page-sized slice or an open remote feed.
Metadata-free folders must not be guessed to be series. A box retains its full
member list for native drill/bulk actions; author/genre groups keep their raw
members and a separate compact display list. Count display slots in the footer,
and use the same grouping for letter jumps. Opening a series exposes every
volume to the local planner and must not box it again. Preserve the box's member
scope across native drill restoration using identifiers, never cover buffers.
The first volume supplies the cover. Side depth grows from 8% of cover width
by 2.5 percentage points per additional volume, capped at 30%; the count always
shows the actual membership. Plan and paint share this geometry. Cover sizing,
author busts, plank/dock clearance and other view modes must remain intact.
The box is drawn procedurally, using one visible cover and at most five edge
lines, not an image or buffer per volume. No preferences or metadata are migrated.
Sources: `core/orbitui_series_boxes.lua`, `core/orbitui_series_box_widget.lua`,
`adapters/orbitui_series_boxes.lua`. Tests: `tests/test_series_boxes.lua`.

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

The monitor can fetch refs and update its one status issue only. It cannot merge,
open merge PRs, advance integrated pins, tag, release or publish OTA. Publishing
to users remains a separate explicitly approved action after reviewed changes.
Both embedded legacy installers remain blocked; OrbitUI OTA must stage and
validate the whole package, not update one component independently. Preserve
the stable bootstrap, deferred activation and previous-version recovery.

Source: `.github/workflows/upstream-watch.yml`, `scripts/upstream_watch.py`,
`sources.json`, `adapters/orbitui_updates.lua`, `core/orbitui_ota.lua`, `orbitui_bootstrap.lua`.
Tests: `tests/test_upstream_watch.py`, `test_updates.lua`, `test_runtime.lua`,
`test_bootstrap.lua`, `test_ota.lua`, `test_http.lua`, `test_release_package.py`.
Full device acceptance, including the OTA UI, is still outstanding.

## C10: Shared panels, search, settings and Home shelves

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

Source: `core/orbitui_context.lua`, `orbitui_shelf_query.lua`,
`orbitui_search.lua`, `orbitui_i18n.lua`; adapters `orbitui_ui.lua`,
`orbitui_book_panel.lua`, `orbitui_home_shelves.lua`, `orbitui_settings.lua`.
Tests: `tests/test_shared_book_panel.lua`, `test_shared_home.lua`,
`test_shared_search.lua`, `test_shared_settings.lua`.
See `SHARED_UI.md` for the minimal component seams and device checklist.

## C11: Author-bound ornaments

Bundled author busts and their trial copies must never enter the ordinary deck.
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

For ordinary end ornaments, distribute unused room evenly between the ornament
and its two slot boundaries (shelf end and adjacent book). The optional
`SpineShelf.positionOrnamentX` seam is installed by `adapters/orbitui_ornaments.lua`
and also handles a section's ordinary leading piece. This is paint-time alignment
only: preserve book coordinates, reserved widths, paging, deck order, vertical
placement and the ornament widget's tap/hold area. Never center a leading piece
over a separate left-end piece. Keep author busts adjacent to their books and
honor explicit negative padding/overlap; tight slots retain native placement.
Standalone Bookshelf, middle gaps, bare shelves and the pack editor retain their
native layout. See `core/orbitui_ornament_spacing.lua` and
`tests/test_ornament_spacing.lua` when merging row-rendering changes.

Per the user's 2026-10-04 approval, the ordinary deck now shuffles once per
KOReader process. Run native `Deck.sync(all)` and `Deck.shuffle()` after bundled
seeding and the first nonempty `listAll`, before returning to `list()` and
capturing page signatures. The adapter's guard belongs to the canonical module,
not a shelf widget/profile. Never reshuffle on redraws, reader returns, directory
polls or normal resume. Empty catalogues defer the first shuffle; an exception
logs once and cannot repeatedly stall rendering. Preserve native generation/epoch
updates, cached list identities and manual shuffle/swap behavior for the rest of
the session. Automatic shuffling does not enable disabled pieces/packs or place
author busts randomly. Keep this explicit user-approved exception to upstream's
cross-restart fixed order in future merges. See `tests/test_ornament_session.lua`.

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
