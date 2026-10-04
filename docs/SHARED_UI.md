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

Alpha.13 correction after the alpha.12 device report: the bookcase's collapsed
row-height calculation now excludes the live dock height, like the other view
modes. It shares the visible pagination reserve, and the rebuild uses that same
reserve even when a negative footer margin moves controls above their outer box.
Rows resize to the remaining viewport without changing the saved row count or
the normal hero size. The user confirmed alpha.12's cover-facing appearance,
but its bottom row overlapped the pager/dock; the correction needs a new device
check in portrait/landscape, after paging and after collapsing/expanding the hero.

## Component seams to preserve during merges

- Bookshelf Widget: optional chip-hold/search callbacks; return the created
  detail modal; preserve Home underneath detail-only panels; supply the optional
  registered-action close callback; honor action enabled state.
  Preserve the dock-free shelf viewport and visible footer reservation in both
  the shared geometry and the rebuild; the full widget height includes the dock.
- Bookshelf Chip Editor: optional `face_out_override` reports the host's fixed
  orientation and disables only the face-out picker, without rewriting drafts.
  OrbitUI wraps both the widget's `_spineFaceOut` and this editor field.
- SimpleUI book-hold helper: export its existing one-shot Home-preservation
  helper for native Book Information opened from the shared detail panel.
- Bookshelf Repository: optional search book limit (default still 200) and
  light-only next-volume records (default still full native records).
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

The headless tests cover logic and extracted native factories, not native font
metrics, image rendering, touch interaction or complete device lifecycle.
