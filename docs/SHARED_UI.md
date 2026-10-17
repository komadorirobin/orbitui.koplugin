# Shared OrbitUI surfaces

Introduced in the 0.1.0-alpha.4 preview release. Existing settings and component
versions remain in place. Performance optimization is not the purpose of this
change. Device acceptance is still pending.

## Controls

- Long-press a book on Home or in shared search results to open the Bookshelf
  detail panel, initially on Edit. Description, tags/collections, ratings,
  Hardcover linking and registered external plugin actions remain native.
  Home module actions and its module-settings shortcut remain available.
- Long-press a library/manga shelf chip and select **Show this shelf on Home**
  (Swedish: **Visa den här hyllan på Hem**). Choose **Book row** or **Cover
  carousel**. Edit shelf still opens the existing shelf editor/style picker.
- In that same chip menu, **Cover text** (**Omslagstext**) selects Title, Author,
  Series, Custom text or None for this shelf only. Library and Manga choices
  are independent, even on identically named chips. The former global book-text
  row is removed; the separate group-text control is unchanged.
- Each newly pinned shelf starts on a new Home page. Move it into the desired
  Home/Bento layout with the existing layout editor. Pinning it again changes
  its display type instead of adding a duplicate. The settings hub's **Home
  shelves** list can open the shelf, switch type or remove it from Home.
- **OrbitUI settings** groups Home, Library, Manga & comics, Home shelves,
  Appearance, search, **Uppdatera OrbitUI** and advanced settings. The old
  dispatcher action for SimpleUI settings still works and opens this hub.
- Home/library search uses one input/results flow with **Entire library**,
  **Library**, **Manga & comics**, and **Current shelf** when a supported local
  shelf is available. Tap a book to open it, long-press for the shared panel.
  Author/series/genre/folder matches navigate to the corresponding library view.
  Results are capped at 400 with a notice; narrow the query if necessary.

## Data and behavior

Home pins store only id, display mode, fallback label and profile/chip reference
under `simpleui_orbitui_home_shelves` in the existing SimpleUI store.
`simpleui_orbitui_home_shelves_next_id` supplies monotonic module ids.
Layouts retain their existing storage format. Module ids are
`orbitui_shelf_<number>`; carousel-specific settings use a private
`simpleui_orbitui_<module-id>_` prefix. The original Cover Deck is untouched.

Bookshelf resolves membership at use time from current filters/sorts, local
collection membership, folder contents, next-volume selection or the existing
BookOrbit Want to Read cache. Normal cache refresh rules still apply. No Home
render starts a new BookOrbit/Hardcover network fetch. Remote OPDS shelves
cannot be pinned as local book modules. Deleted and empty shelves show a
placeholder, not a fallback book list. Unpinning does not delete books, links or
progress; a module still used on a Custom Screen remains registered.

The panel inherits the actual Bookshelf class, including userpatch wrappers,
without running its shelf initialization. Navigation/selection actions hand off
to the real visible shelf. There is no second hidden shelf or event owner.
Registered file-dialog factories receive their optional close callback, just as
in SimpleUI's previous Home dialog. Disabled actions cannot be invoked by the
panel's chip buttons.

Book openings keep their native Home or Bookshelf route and real file path,
including profile auto-execution and external undo-opening hooks. Reading-status
changes delegate to the existing native action; OrbitUI adds UI invalidation,
not another Hardcover status/progress writer. The external undo patch and
BookOrbit server continue to own server rollback behavior.

## Bento module margins (0.1.0-alpha.18)

Top Margin now belongs to each module, including modules in the right-hand
column and those stacked below another module. The margin sits above the label
and content, not between the label and its covers. Columns are top-aligned so
one module's changed margin does not vertically recenter its neighbours.
Full-width spacing, row widths and topbar-off padding remain unchanged.
Existing saved margins are used without migration; old layouts that relied on
vertical centring may need their individual margins adjusted. Headless coverage
is in `tests/test_simpleui_bento_margins.lua`; Bigme verification is pending.

## Cover-facing shelves (0.1.0-alpha.12)

The shelf/spines style now displays every book cover-forward, as requested on
2026-10-04. Existing Library and Manga shelves are included. Native shelves,
ornaments and aspect-aware cover geometry are retained; wider covers can mean
fewer books per page, with native pagination using the same layout. Missing
covers use the native face-out placeholder. Ordinary cover grids, lists and
Auto's folder behavior are unchanged.

The style editor reports **Face out: All books** as a read-only row. Stored
chip/profile/global face-out choices remain intact but inactive, allowing a
code rollback without a settings migration. Other layout controls remain native.

### Per-shelf cover text (0.1.0-alpha.34)

Long-press the desired chip, choose **Cover text**, then select the label content.
An explicit choice applies to both regular/full-screen cover grids (text under
the cover) and the physical bookcase (a single-line dark band inside the bottom
of the cover). The band avoids the progress bar; native status badges, finished
fading and opening animation remain in place. Long labels truncate to fit and
very small covers omit a band that cannot safely fit. Series boxes retain their
own series-name band and read-count badge; opening them shows the chosen text on
individual volumes. Ornament geometry, pagination and the dock are unchanged.

Existing untouched shelves keep their old appearance. Grids fall back to the old
global label choice; physical shelves stay unlabelled until explicitly enabled.
Custom text uses the native token editor, including bold, uppercase, live preview,
Save and Cancel. Saving updates only that chip's mode/template. A chip's folders
and series drills inherit its text; actual nested shelf chips have their own
choice. These controls do not replace the separate list-view line configuration.

Since alpha.35, **Cover text > Placement > Above the cover** moves the book label
above the cover on this chip, in both grid modes and the physical bookcase.
**Bottom (default)** keeps the previous below-cover/grid or in-cover/bookcase
placement. The position is saved separately from the content and custom template;
choosing a position does not turn on text when None is selected. Library, Manga
and nested chips remain independent; drills inherit their chip's position.
Grid slots reuse their existing text-strip budget. Physical labels sit above the
page block, using headroom first and scaling the cover down proportionally only
when needed to stay inside the same row. Its page block, feet and shadow follow
the narrower cover without changing packing. Tiny rows omit a label that cannot
fit. Text can be tapped/held like its book, and shares finished/on-hold fading. The real card,
status indicators and opening target are not replaced. Group labels, series-box
labels and ornaments are unchanged. Device rendering still needs verification.

The October 11 Bookshelf 5.4.1 import retains this menu and its saved choices.
Its overlapping native grid-only caption picker is hidden in OrbitUI, so there
is still one caption setting per chip, including physical shelves and placement.
No caption settings are migrated and nested chips do not start inheriting a
parent's captions. The native Text size row is now named **Cover captions**.
The separate library-wide group-text control is now **Show author below series**;
upstream interprets a previous Custom group choice as Author but retains its
stored template. This does not alter the physical series boxes.

Alpha.13 correction after the alpha.12 device report: the bookcase's collapsed
row-height calculation now excludes the live dock height, like the other view
modes. It shares the visible pagination reserve, and the rebuild uses that same
reserve even when a negative footer margin moves controls above their outer box.
Rows resize to the remaining viewport without changing the saved row count or
the normal hero size. The user confirmed alpha.12's cover-facing appearance,
but its bottom row overlapped the pager/dock; the correction needs a new device
check in portrait/landscape, after paging and after collapsing/expanding the hero.

## Series ordering on bookcases (0.1.0-alpha.17)

When sorting the bookcase by title, author or series, series blocks now share
the alphabet with standalone books instead of remaining in filesystem order
or sinking to the end because group records have no title. The series name
decides its position; without usable series metadata, the first volume's title
is the fallback. Author sorts use the members' author metadata. For example,
Moberg's `Rid i natt` precedes the `Utvandrarna` block, whose members remain
`Utvandrarna`, `Invandrarna`, `Nybyggarna`, `Sista brevet till Sverige`.

Existing folder sections remain grouped and retain their labels. Loose books
with matching series metadata within a section also stay together. Volume
numbers sort numerically (including decimals); missing/tied numbers fall back
to native natural filename order. Reverse alphabet changes block placement,
not reading order inside a block. The reorder happens before page slicing,
and letter scans use the same scoped bookcase producer and block keys.

There is no settings migration or new switch. Grid/list views and sorts whose
primary key is date, status, filename, count or manual collection order retain
their native behavior. No additional disk walk, cover decode or network request
is introduced. The policy uses batched light records and native sort keys.

## Compact series boxes (0.1.0-alpha.26)

The 2026-10-16 user-approved trial uses Bookshelf 5.5's native open-topped
slipcase in place of OrbitUI's former perspective box. The previous design
and regression tests are preserved on local branch `design/orbitui-series-boxes`
at `1ae66bd0`, not included as a second runtime renderer.

Series occupy one physical shelf slot, except a series with just one local
volume, which remains an ordinary book. Up to eight member spines show above
the front board. Following the October 17
correction, the first cover fits a centered rounded sticker without stretching;
unused space shows the board's existing cover-derived colour. The read/total
count is printed in the compact exposed head instead of taking a band from
the picture or obscuring it with a notch, with the
series name below. The native geometry sizes the box from its members and
name, with an 85% minimum and a face-out cover's width as its maximum (subject
to available shelf space). The count is never capped and shrinks to fit.
It reads canonical finished status for the visible box's scoped membership,
not a stale aggregate or percentage. The trial intentionally omits our old
whole-box checkmark/fade and separate manga-style badge. Preferences and book
status remain stored unchanged for rollback. The aggregate count replaces
individual head glyphs in the compact layout, where they would overlap it.

The later October 17 partial-fill refinement keeps the cover area but stops
stretching member spines to fill it. Comparable page counts determine thickness
on one shared scale; unknown or reflowable reader-layout counts use a neutral
fallback. Members pack left and leave a shaded interior on the right. Only a
whole prefix that fits is shown, up to eight members. `+N` means additional
local volumes not drawn, not missing or unread volumes; the separate read/total
still counts the complete group. This applies to all physical series boxes
without a new setting, and retains all shelf/series binding choices.

Tap opens the series and shows its individual volumes. Long-press retains the
native series menu. The box is a display-only record: source membership, status,
metadata and saved sorting settings are not rewritten. Filtered boxes contain
only eligible members; restoring one after restart cannot widen it to another
section/profile. The adapter accepts both old and native scope keys and writes
both identifier-only spellings on new saves for rollback. Arbitrary folders
without series metadata are not guessed to
be series. Grid/list views and remote catalogues remain unchanged.

Grouping precedes page planning, so boxes count as single displayed items in
the shelf pager and letter navigation. Author groups preserve their complete
native membership separately from the compacted display list. Native code in
`components/bookshelf/lib/bookshelf_series_boxes.lua` and
`bookshelf_series_box_widget.lua` owns preparation and rendering; the thin
`adapters/orbitui_series_boxes.lua` keeps the host's all-series policy, profile
isolation, letter navigation and rollback-compatible restoration.
`orbitui_ui` opts into the 85% minimum, compact head and the native painter's aspect-preserving
cover policy; standalone Bookshelf retains its default layout. The fitted
cover is copied without a second stretch, with only its tile border removed.

Long-press a chip > Book binding sets the physical shelf's default: Hardcover,
Paperback or Manga / tankobon. Long-press a box > Book binding sets a series
override across shelves, including its opened volumes; Follow shelf removes
only that override. Existing shelves stay Hardcover until changed. Pocket and
manga styles use thin flush covers rather than protruding boards. The manga
jacket is pale with contrasting dark lettering and a cover-coloured accent.
These are generated visual treatments, not reconstructed printed spine art.
Cover proportions, page-count thickness and the separate cover-size control
are unchanged. The choices live in the normal settings backup, not metadata.

## Component seams to preserve during merges

- Bookshelf Widget: optional chip-hold/search callbacks; return the created
  detail modal; preserve Home underneath detail-only panels; supply the optional
  registered-action close callback; honor action enabled state.
  Preserve the dock-free shelf viewport and visible footer reservation in both
  the shared geometry and the rebuild; the full widget height includes the dock.
  Native `_prepareSpineItems` runs once before pagination/cache signatures;
  the old optional `prepareSpineItems` / `spineItemCount` seams are no longer
  installed by the host's box adapter.
  Preserve `_bookLabelMode` in all grid label-budget/cache decisions and
  `spineCoverLabel` forwarding through row options to face-out covers.
- Bookshelf SpineShelf: native box geometry, widget and shadow paths share one
  measured width. The old optional external renderer seams remain uninstalled.
  Box entries must not receive the expanded-series badge beneath the shelf.
- Bookshelf Chip Editor: optional `face_out_override` reports the host's fixed
  orientation and disables only the face-out picker, without rewriting drafts.
  OrbitUI wraps both the widget's `_spineFaceOut` and this editor field.
- Bookshelf cover-text editor accepts an optional scoped target; vanilla book
  and group targets stay unchanged. Keep the `book_cover_label` menu-row ID for
  removing only the old global book control, and both cover-label fields in the
  profile shelf whitelist. The adapter decorates the existing card before native
  status overlays, retaining its dimensions, disposal and opening-effect identity.
- SimpleUI book-hold helper: export its existing one-shot Home-preservation
  helper for native Book Information opened from the shared detail panel.
- Bookshelf Repository: optional search book limit (default still 200) and
  light-only next-volume records (default still full native records).
  Preserve `orderShelfSections` before the folder window and `orderShelfSeries`
  in the spine-only series readout, plus transient `_orbitui_shelf_sort` keys
  on output copies. Cached metadata/shapes must not inherit these render keys.
  The sort adapter wraps canonical SortEngine letter keys and the widget's
  `_jumpScanList`; folder scans must match profile scope, filter and full
  priority, with temporary native spine flags restored after errors.
- SimpleUI ScreenEngine: export its existing native openBook function unchanged.
- SimpleUI SettingsWindow: expose its existing LayoutService and allow opening
  a known settings subsection, while retaining the original default entry.
- SimpleUI Cover Deck: optional source provider without recent-book fallback,
  per-instance navigation callback and held-module identity.
- OrbitUI loader: wrap explicit canonical module names after loading; retain
  package.preload priority and all existing aliases. Menu wrapping covers the
  lazy SimpleUI menu installer as well as Bookshelf's menu builder.

Most logic resides in `core/` and `adapters/`, not copied component forks.
Upstream commits/pins and the stable OTA bootstrap are unchanged.

## Focused device acceptance

Not yet performed on the Bigme. Use the existing recovery procedure.

1. Compare the book panel from Home, a row/carousel, search and the library.
   Check status, rating, collection editing, Hardcover link selection, undo
   opening, file-info return, selection handoff and module settings. Confirm
   panels close cleanly and the correct underlying view remains visible.
2. Pin prose, Manga Next and a filtered collection as rows/carousels. Check
   counts/membership after a completed volume, collection edit and new import.
   Restart and verify persistence, section labels, pagination and independent
   swipe positions. Delete/empty a source and check its placeholder.
3. Move pins into Bento and a Custom Screen. Unpin from Home and confirm the
   original layout, original TBR deck and Custom Screen remain usable.
4. Search the same title from Home and Library. Exercise all scopes, empty
   results, group navigation and long-press actions. Switch scope with text
   entered. Open and close a book; confirm its reading profile and return view.
5. Open shared settings from Tools, the existing dispatcher action and the
   OrbitUI menu. Change Home/prose/manga appearance independently and confirm
   existing preferences remain intact. Check the sole OrbitUI update target.
6. Repeat navigation after a parked reader, rotation and suspend/resume.
   Verify one Hardcover read record, MAL behavior and external patches.
7. In the shelf/spines style, verify all covers face forward in Library and
   Manga, including previously customized shelves, folder drills, large series
   and books without cover images. Page forward/back in portrait and landscape;
   check there are no skipped/duplicated books and tap/hold still selects the
   right book. Confirm switching back to grid/list/Auto retains its old layout.
8. Mix standalone books and multi-volume series on a bookcase. Sort by surname,
   then title/series, and by title alone; verify the Moberg example above and a
   series whose name differs from volume one's title. Reverse the alphabet and
   check that volume order stays ascending. Page forward/back across a long
   series, filter out finished books, drill into a folder and jump by letter.
   Check the correct book opens and author busts remain adjacent. Switch to
   date order and grid/list to confirm their behavior and saved sorts are intact.
9. With compact series boxes, compare series with two, four, ten and more than
   ten volumes. Verify increasing then capped depth, the actual count and first
   cover, portrait/landscape fit, and no overlap with neighboring books, ornaments,
   plank or pager. Tap/double-tap opens all eligible members; long-press opens the
   series menu. Check filtered shelves, author drills, an empty/restored filtered
   series, letter navigation and return after reading or restarting. Check both
   day/night mode and small/large cover sizes. Grid/list views must be unchanged.
10. Long-press Fiktion and enable Title in Cover text; leave Manga on None.
    Switch chips, drill into a series, return, restart and change between grid,
    physical and full-screen views. Compare same-named Authors chips in both
    profiles. Edit Custom text, cancel a pending preview, then save a new one.
    Check long titles, missing covers, small/large cover sizes, colour/night mode,
    progress bars and completed marks. Ensure no label crosses the plank and a
    series box does not acquire a second title band.

The headless tests cover logic and extracted native factories, not native font
metrics, image rendering, touch interaction or complete device lifecycle.
