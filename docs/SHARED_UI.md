# Shared OrbitUI surfaces

Introduced in the 0.1.0-alpha.4 preview release. Existing settings and component
versions remain in place. Performance optimization is not the purpose of this
change. Device acceptance is still pending.

## Controls

### Local EPUB tags and optional BookOrbit tags (October 31)

The existing **Tags / Taggar** tab now begins with **EPUB tags (offline) /
EPUB-taggar (offline)**. Choose **Read EPUB tags / Läs EPUB-taggar**, then tap
a tag for exact local matches across configured library profiles and the native
home library. No BookOrbit plugin/account/link/server/API is required. EPUB 2
name/content and EPUB 3 property metadata containing `bookorbit:tags` JSON work;
ordinary dc:subject stays under native Genres. The originating file is included
even outside configured folders; normal library scan depth applies elsewhere.
The scanner reads only bounded ZIP metadata, one EPUB per event-loop turn, with
tap-to-cancel and retired navigation/scope guards. A separate stat-keyed derived
cache speeds later searches. Explicit Refresh rereads the files; failed reads
are retryable and counted as incomplete results, not silently missing matches.
The same native result modal retains paging, filename filtering, 400-hit notice
and original book-open/hold actions. No books, metadata or reading state change.

The optional **BookOrbit tags / BookOrbit-taggar** online section follows it.
The original author, series, collections, genres and folder
sections remain below it. **Load BookOrbit tags / Hämta BookOrbit-taggar** reads
the linked book's tags; **Refresh BookOrbit tags / Uppdatera BookOrbit-taggar**
rereads them. No fetch on opening/painting and no mixing with genres or KOReader
collections. Tags remain in this panel's memory only, never a new disk index.

Tap a tag for exact matches among **BookOrbit-linked files on the device, across
all library profiles**. The native paginated result modal offers filename
filtering, Refresh and Close; tap opens via the caller's original reader action,
hold opens the shared book panel. Only visible-page metadata is read, without
covers. At most 400 results, with an explicit cap notice. Account/link changes,
closed/replaced owners, canceled work, missing files and invalid/partial responses
fail closed; requests run through the external plugin's cancelable worker.
Only explicit actions may request Wi-Fi. Nothing edits metadata, collections,
reading status, remote progress or existing preferences.

The separately approved LOCAL BookOrbit API adds a KOReader-authenticated
`GET /koreader/plugin/catalog/tag-matches?ids=1,2&tag=...` (API-v1 prefix as
usual), with 1..200 IDs and one literal tag per request, returning `{bookIds}`.
Native accessible-library/present-book/content-filter rules still apply. The
account-scoped BookOrbit plugin's existing public client methods suffice; its bounded private
detail cache is not scraped. An older server displays an update-needed message.
The user now explicitly approves OrbitUI push/publication after local tags and
an upstream merge. The BookOrbit server change is still LOCAL and is not deployed
by that publication; it is NOT needed for embedded tags. Physical SV/EN
fonts/touch/D-pad/keyboard, long names, scroll/zoom,
Wi-Fi/cancel/offline, reader return, rotation/sleep and live API acceptance are
still required. See MERGE_LOG/TESTING for final local verification.

### October 31 UI refinements (Beta 20)

- Shared Search has **Typo-tolerant search / Stavfelstålig sökning**, on unless
  explicitly disabled. Exact spelling, including Swedish å/ä/ö, ranks before
  accent-folded and approximate book matches. Short words stay exact; longer
  words allow at most one/two edits, including transposition and typed prefixes.
  Native scope/genre choices and the 400-hit cap still apply. No new book index,
  cover decode, metadata writer or remote query is added. Query-local distance
  memoization is bounded; unknown future search/history data remains untouched.
- Tap the shelf counter marked **▾** for **Sort, filter & view / Sortering,
  filter och vy**. The native footer's former page-jump action remains in that
  menu; advanced native multi-level sorting remains available too. Filters show
  counts for All/Unread/In progress/Barely started/Finished. Barely started is a
  derived local category at 0–5% for a started book, never a status write.
  Quick sort/status choices display this shelf's matching books, not its group
  cards. Source membership and existing filters are applied first. **Use shelf
  defaults here / Använd hyllans standard här** restores the original grouping,
  layout and sorting without overwriting the chip's saved configuration.
- Quick choices are remembered independently per profile/chip and opened
  author/series/collection/folder (whole-group views have their own identity).
  Up to 100 saved places; a full/future-format store refuses new writes rather
  than evicting another saved place. Covers/List/Book spines/Compact list/
  Compact list · 2 columns reuse native renderers and density limits. Compact
  rows show title, author, progress and relative last-read/added date; narrow
  screens use the native one-column fallback. Cover-preview pins still win.
  Spine quick sorting preserves OrbitUI's series-block/volume order. Only visible
  page records hydrate covers through the existing cache/Android-safe path.
- Shared settings display **You are here / Du är här**. Tap for an ancestor
  picker; direct jumps retain the selected profile and native Back/page/close
  ownership. Nested settings retain the row. Category navigation has a submenu
  cue; native check/radio/disabled/hold actions remain. Native Menu pagination
  remains responsible for visible widgets; no global menu or setDirty takeover.
- The book detail header emphasizes cover/title/author and percentage read.
  **Book details / Bokdetaljer**, before Edit, holds pages/language/format/size/
  dates/filename/folder. It is read-only, escaped, lazy and independently zoomable;
  Description/Reviews/Tags/Cover and registered plugin actions remain. **Read
  now / Läs nu** uses the existing open/close callback, not a new reader path.
- Existing opt-in diagnostics additionally time library search, browse filtering/
  sorting, settings search and technical-detail building. Same scalar-only,
  bounded, local memory report; no paths/titles/queries/raw errors are recorded.
  `luajit scripts/benchmark-ui.lua` is a synthetic CPU-only 200/2,000/5,000-book
  comparison, not an emulator/native-image/e-ink/device latency measurement.

Design references (reviewed, not imported): modern_menu `6aef188c`, Library GUI
`c7e60300`, KiKome `b232f18b`. All owned UI/help is Swedish/English. Source pins,
all original user data, artwork, bootstrap and installed paths remain unchanged.
Physical Boox/Bigme fonts, touch, paging, compact rows, transitions, rotation,
sleep and the retained local night fix still require device acceptance.

### Local Kobold design follow-up (October 30; not published)

Search adds **Recent searches** (ten local query/scope pairs, explicit Clear)
and **Sort results**: relevance, title, author or series. Sorting happens before
the existing 400-result limit. Profiles/current shelf, group matches and native
book-open/hold actions retain their existing meaning. History never indexes book
records, remote accounts or credentials, and a missing scope cannot silently
become the entire library. Switching sort/scope preserves typed text; obsolete
windows/pickers and queued native-navigation work cannot cover a newer search.

In Bookshelf **Manage collections**, tap a custom collection, then **Manage
books…**. The shared native LibraryModal has **In collection**, **Add books**
and **Changes** views, selected with the bottom-left view button. Search filters members; Add books searches the local
library only on explicit submission. Tap to stage/undo membership, review the
add/remove counts, choose title/author ordering, then Save or Cancel. Back/X
also discards the draft. Neither removal nor deleting a collection deletes a
book file. This editor does not create/delete/rename collections or modify
Hardcover lists; existing native actions still own those separate workflows.
Favourites and auto-folder collections stay in their original KOReader controls.
One optional `CollectionManager.orbitui_edit_contents` seam adds the manage-only
entry; native standalone, per-book and bulk membership behavior is unchanged.
No hidden shelf, cover extraction, new data index or installed runtime file.

All new owned wording is English/Swedish. Device acceptance remains: native
fonts on narrow/landscape screens, long collection names/paths, touch and D-pad,
keyboard/search/view/paging focus, Back/X/Cancel/Save, a removed book during an
open draft, native book-detail return and rotation/sleep. Headless tests are not
evidence that these interactions have passed on Boox/Bigme.

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
- Published Beta 13's **OrbitUI settings** uses the task-oriented grouping below.
  The old SimpleUI settings dispatcher action still opens the shared hub.
- Home/library search uses one input/results flow with **Entire library**,
  **Library**, **Manga & comics**, and **Current shelf** when a supported local
  shelf is available. Tap a book to open it, long-press for the shared panel.
  Author/series/genre/folder matches navigate to the corresponding library view.
  Results are capped at 400 with a notice; narrow the query if necessary.

## Quick controls (Beta 17)

Open **OrbitUI settings > Navigation & interface > Quick controls**
(**OrbitUI-inställningar > Navigation och gränssnitt > Snabbkontroller**).
**Open quick controls / Öppna snabbkontroller** works without changing a bar.
Optionally enable **Tap status fields for quick controls / Tryck på statusfält
för snabbkontroller**, or add the **Quick controls / Snabbkontroller** action
using the existing navigation/quick-action editor. Saved bars are never replaced.

- Home (SimpleUI): tap a visible brightness, Wi-Fi, battery or clock field.
  Its small menu opens at that field. Hidden fields stay hidden; existing
  long-press settings and configured corner gestures keep their behaviour.
- Bookshelf: tap the ordinary book-hero or micro-module status line to open
  the same controls. Custom token layouts are not guessed into per-icon zones;
  select the desired control inside the menu. Job Stop/page dots retain priority.
  Expanded/full-screen shelves retain their existing tap-to-restore behaviour.
- Light offers brightness and colour-temperature sliders only when supported,
  plus native advanced light settings and night mode. Native numeric ranges
  and warmth conversions are preserved. If the sliders cannot fit the screen,
  the native settings button remains; no partly clipped slider is installed.
- Wi-Fi reports known local state, never treats Android's no-toggle shim as
  proof of connection, and opens Android's system Wi-Fi settings. Supported
  non-Android devices use KOReader's original connection prompts/network chooser.
  Opening the menu never enables Wi-Fi, scans, or cold-initializes NetworkMgr.
- Battery reports level/charge state and opens the existing battery-statistics
  plugin when available. Time/date follows KOReader's clock formatting and
  opens the existing statistics plugin's reading calendar when enabled.

Tabs replace one dialog; **Refresh status / Uppdatera status** rereads values
explicitly. Back, outside tap and Close dismiss it. There is no new polling
timer or provider/database work in paint. Navigation, close, rotation, sleep
and host lifecycle guards make retired callbacks inert; no reader/profile
transition is introduced. Native widget fonts, touch, D-pad focus, system return
and day/night underlay behaviour still need physical Boox/Bigme acceptance.
No third-party code, artwork, icon/font pack or additional runtime path is used.

## Library/chip editor refinement (Beta 14)

From **Navigation & interface > Bookshelf button & destinations > Profiles and
chips**, or **Bookshelf > Libraries & shelves**, open a library profile:

- Open a chip (for example Fiktion) for its name, source, folder and appearance.
  A folder change edits that chip only. Choosing a folder outside existing roots
  asks before adding it to whole-library search/reader-return scope; old roots
  and other chips stay intact. Cancel writes nothing and no book files move.
- **Order chips / Ordna chip** shows the whole numbered chip list in bar order
  (left-to-right). Select a chip, then **Place before… / Placera före…** or
  **Place after… / Placera efter…** its named neighbour. The list and
  **Position N of M / Plats N av M** update in place, without going Back.
  The position row inside a chip opens the same view with that chip selected.
- **Order libraries / Ordna bibliotek** is one level up, alongside the profiles.
  It orders profiles, not navigation buttons or chips. Disabled profiles remain
  visible. Equal-specificity folder matching prefers the first enabled profile.
- **Library folders (advanced) / Bibliotekets mappar (avancerat)** holds the
  whole-profile roots formerly listed alongside chips. Its help explains the
  scope; replacing a root requires confirmation and remaps descendant chip
  sources, preserving the existing model and files.

Stable profile/chip IDs and existing theme, Home and navigation references are
kept. Both languages and search aliases are covered headlessly. Device checks
remain open: long paths/names, small screens, many chips/page boundaries, touch,
Back/close, restart persistence, profile matching and reader return on Boox/Bigme.
Beta 14 also includes the approved native reader-menu fast-return change;
public Beta 13 and its assets are unchanged.

## Task-oriented settings (Beta 13)

The approved redesign has five root categories and **Search settings / Sök
inställning**. Earlier release tags/assets remain unchanged.

Included in Beta 17 from the October 29 follow-up: the settings start presents the
same five categories as large icon cards with short Swedish/English descriptions.
Home is still explicitly SimpleUI. Search settings remains a prominent action;
List view opens the unchanged six-row root with a Back link to Category cards.
Category Back also returns to cards. Cancelling a search opened from cards
returns there; result Back retains the typed query. Close/Back exits the card
start without changing preferences. Existing legacy menu item APIs remain lists.

The existing Bookshelf LibraryModal supplies pagination, touch and D-pad/footer
focus and close repaint; no extra plugin, icon/font pack or global widget patch
is installed. Titles/descriptions are measured at the actual card width with
focus-ring space. Two columns collapse to one at larger text/narrower widths;
short screens page instead of clipping. Unusable geometry or unavailable native
UI dependencies fall back to the full old list. A new read-only `gridGap()`
accessor keeps measurement aligned with the native modal across DPI changes.
The root does not construct shelf/provider settings, index current values,
change profiles or write preferences. Native rendering and physical-device
acceptance remain required; headless wrapping tests are a geometry proxy.

- **Home (SimpleUI) / Hem (SimpleUI):** layout/modules, custom screens, reading
  dashboard, Bookshelf shelves pinned on Home, wallpaper/presets/behavior and
  clearly named Advanced SimpleUI settings. The native window's titles identify
  Home versus named custom screens and global SimpleUI bars/style controls.
- **Bookshelf:** libraries and shelf sources, separate book search, the upper
  book panel, covers, themes/backgrounds/ornaments, shelf presets, fonts and
  retained advanced controls. Global settings are not falsely labelled Prosa/
  Manga-specific. Library and individual shelf editors name their actual scope;
  theme edits follow the selected theme wherever it is used.
- **Navigation & interface / Navigation och gränssnitt:** Bookshelf destination
  and profile buttons, bars/start view, icons/common style, custom quick actions
  and native reader/return behavior controls.
- **Integrations / Integrationer:** connection/help inspection, native Hardcover
  enrichment controls and ornament add-ons. Existing optional providers and
  explicit network actions are unchanged; opening search never calls them.
- **System & maintenance / System och underhåll:** the sole OrbitUI updater,
  metadata/cover maintenance, Android/performance safety, setup and honest
  backup/recovery information. This does not introduce a full-device backup or
  reset a cache automatically. Keep Android safe mode enabled on the affected Boox.

The genre example becomes **Bookshelf > Book panel at the top > Show genres**
(**Bookshelf > Bokpanelen överst > Visa genrer**). Title, subtitle, author,
description, rating, metadata, progress and label visibility have ordinary
checkboxes; templates/font/alignment remain under Advanced. Category switches
reflect actual visibility: enabling one can enable the labels line, retaining
all other saved category choices. Metadata/filter membership is not changed.

Long-press the upper book panel to choose **Customize book panel / Anpassa
bokpanelen** or the existing real book detail/actions panel. Selection mode and
disabled hold gestures still gate this. Long-pressing a shelf chip keeps the
existing shelf actions and names its edit action **Customize this shelf /
Anpassa den här hyllan**. These are shortcuts to the same controls and stores.

Settings search accepts Swedish and English regardless of UI language. Static
catalogue words and 332 short native Bookshelf phrases contain no current values,
paths or credentials. Exact visible labels rank ahead of broad section matches;
there are at most 40 results and an explicit truncation notice. Results open a
live control or its owning native section; opening never activates that control.
Back from a result restores the query; category Back and close-all are separate.
The old misleading All settings entry is now Advanced SimpleUI settings.

All native preference controls remain available, including unknown future rows.
Small optional metadata/title/Back/hero hooks preserve standalone behavior;
neither global gettext nor require is replaced. No settings migration or new
runtime file is needed. Before a future release, test SV/EN touch/long-press,
native windows, nested Back, Prosa/Manga scopes, custom-screen layout, theme
sharing, reading-profile opening and sleep/rotation on physical Boox/Bigme.

## Reading-menu cabinet button (local, not yet released)

The native reading-menu file-browser/cabinet button uses OrbitUI's existing
Bookshelf return routine. A book opened from Bookshelf returns to its original
profile, chip, page and drilldown. A Home/search/external book selects the saved
library matching its file. A safe, exact prewarmed reader/file/profile can return
instantly; otherwise normal close happens before the target location is shown.
Rotation changes retain the native safe fallback. Unmatched files or a disabled/
deleted source use the original action, never an unrelated library. No new
background document/sync owner is introduced. Other explicit gestures retain
their destinations. In a menu over an already parked shelf the button exits to
the real file browser, as before.

Setting (on by default, no migration/reset): **Navigation & interface > Opening
books & returning > Reader menu: fast return to Bookshelf**. Swedish:
**Navigation och gränssnitt > Öppna böcker och återgå > Läsmenyn: snabb återgång
till Bookshelf**. Turn it off for KOReader's original file-browser action.
Settings search also finds "arkivskåp", "stäng boken" and "reader menu".

Only the existing native routines perform parking, deferred real close, progress
saving, book opens and rotation restoration. No new runtime file fits/is added;
VERSION remains Beta 13 locally. This is not available in the immutable published
Beta 13 ZIP yet. Test it on Boox/Bigme before claiming physical acceptance.

## Bookshelf navigation (Beta 9)

Beta 9 introduces this navigation improvement. The user has confirmed that
Beta 8 opens Home on the affected Go Color 7; the new flow still needs device tests.

`open_bookshelf_prose` opens the saved profile whose internal ID is `prose`.
It is a compatibility alias, not a universal "open Bookshelf" command. A fresh
reader deliberately does not import another reader's prose/comics folders.
Merely naming a newly created section "Prose" does not give it that legacy ID.

For the currently published Beta 8, create/rename sections under **OrbitUI
settings > Library sections**, choose this reader's folders and add its shelves
(chips). Then choose that section's NAME directly for a navigation slot under
**Appearance > Navigation & bars > Navigation Bar**; do not create a custom
dispatcher action pointing to `open_bookshelf_prose`. Each saved section has a
registered navigation action. Existing legacy sections and bindings remain valid.

Beta 9 adds:

- A first-class **Bookshelf** action, included in unsaved/default navigation
  bars and the fresh setup guide. It opens Bookshelf without needing any fixed
  profile; the native last view is retained. The file browser is separately
  labelled **File browser**. Saved/custom bars are not rewritten.
- **OrbitUI settings > Bookshelf navigation** (**Bookshelf i navigationsraden**).
  Toggle the Bookshelf button and choose **Destination** (**Öppnar**): native
  Bookshelf or any enabled, locally saved profile. Long-press the Bookshelf
  button to reach this same menu.
- **Profiles and chips** leads to the existing section editor. Name profiles
  Prose, Manga, Children, etc.; choose their roots and shelves independently.
  No device paths, folders or online integrations are assumed.
- Each profile offers **Add to navigation bar** and **Use for Bookshelf button**.
  The first supports several independent profile buttons. A full bar asks which
  existing button to replace; cancellation changes no slots. Explicitly removing
  Bookshelf persists and does not cause it to reappear on restart.
- Missing/disabled old dispatcher profiles open an explanation/repair menu;
  they never silently open an unrelated library or invent a profile. Existing
  prose/comics aliases, chip IDs, custom labels/icons and all data are retained.

Focused regression: `tests/test_bookshelf_navigation.lua` loads the complete
SimpleUI config and QA modules with native services stubbed, the real library
model/profile inventory, host adapters, bridge and deferred shelf coordinator.
Touch/layout/reader-transition acceptance still needs Bigme and Boox testing.

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
