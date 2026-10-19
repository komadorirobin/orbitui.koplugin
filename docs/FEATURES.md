# Using OrbitUI's additions

OrbitUI includes and adapts SimpleUI by doctorhetfield-cmd and Bookshelf by
AndyHazz. Their Home modules, library views, themes, series boxes and ornament
system are the foundation. This guide focuses on OrbitUI's integration and
additional choices; see the [README](../README.md) for installation and credits.

## One Home and library workflow

Open **Tools > OrbitUI > OrbitUI settings** for the shared settings hub. Home
uses SimpleUI; the visual library uses Bookshelf, with the same bottom bar and
book-detail flow. Long-press a book on Home or in shared search to open its
details. Reading status and metadata continue to use the underlying book data,
not a new independent database of reading progress.

Long-press a shelf chip and select **Show this shelf on Home** to add a book row
or cover carousel. The row follows that shelf's current membership and filters.
Arrange it with the Home layout editor. Removing the Home module does not delete
the shelf or books. Shared search offers the entire library, a configured section
or the current supported local shelf; remote catalogue search remains separate.

## Your folders, not someone else's setup

**Library sections** edits names, folders, order and shelves. Add a library section
for comics, textbooks or anything else, or keep one library for everything.
**Setup guide** lets you review folders, launch screen, bottom-bar buttons and
shelf preset before applying them. Existing installations start with Keep existing.
Changing folder references does not move book files. Custom library buttons can
be selected in the guide or **Navigation & bars**.

## Optional Reading dashboard

Under **Reading dashboard**, enable the extra first Home page. It does not
replace your existing pages. **Cards and content** controls visible cards,
their order and book-row sources; **Headings** renames its nine card headings.
The dark continue-reading card can be disabled separately.

Use local To Be Read, New Books, recent history, a KOReader collection, a saved
shelf, or cached BookOrbit Want to Read for the two book rows. Each row pages
independently with arrows or a left/right swipe inside the card. Swiping outside
those cards changes Home pages; configured screen-edge gestures retain priority.
Unavailable sources show an empty/unavailable state, not unrelated books.

Goals can use the local annual goal or the optional Hardcover integration.
BookOrbit and Hardcover remain optional; this dashboard is not a remote-book
download client. Other SimpleUI Home modules and Custom Screens remain available.

## Shelf and series presentation

**Appearance > Shelf preset** offers three policies:

- **Shelf settings:** follow each shelf's native face-out/series-box choices.
- **Classic OrbitUI:** face-out covers and compact eligible series, including
  single-volume series and configured grouped folders, with session ornament shuffle.
- **Minimal bookshelf:** face-out books, no series compaction and no ornaments.

Presets do not reset Home, wallpapers, icons or saved per-shelf preferences.
Long-press a shelf chip for its editor and presentation controls, including
**Cover text**, **Book binding** and **Series box title**. **Cover size** is in
the editor's physical-shelf style controls. Caption content and placement are independent per shelf;
above-cover labels also work in the physical bookcase. Series titles may sit
below the cover or on a readable plate at its bottom.

Bindings include **Hardcover**, **Paperback** and **Kanzenban / large format**.
Long-press a series box to override the shelf's binding just for that series.
These are generated visual treatments, not real spine artwork or changed book
metadata. Series covers retain their proportions; spines keep natural widths
rather than stretching to fill the box. Up to eight are drawn, with `+N` for
additional local volumes and a separate read/total count.

Classic's manga/comics folder shelves can box an **Oneshots** directory, including
its nested title folders, without inventing series metadata. Linked manga can
show a cached MyAnimeList community rating in a compact star/corner label; that
integration requires its separate provider. It is not a personal rating.

## Optional ornaments and icons

Use **Add-ons > Ornament add-ons > Check ornament updates** to browse the six
optional packs: Manga, Japan, Ukiyo-e Gallery, Modernists, Authors and Authors II.
Preview a pack, install it and select **Use in current theme**. New packs start
disabled. Future artwork updates do not require a new OrbitUI release.

**Placement > Match books (default)** puts linked author and manga pieces beside
their matching books. **Random** uses the ordinary shuffled pool. Unbound
decorations are mixed in either mode. Ordinary ornaments are limited to one per
row, while multiple matching author busts may share a row. Information cards
have Swedish and English text; tap supported ornaments to view them enlarged.
Custom captions take priority. [Preservation, licenses and removal](ADDONS.md).

The shared icon pickers add Material Symbols Rounded, Solar and Tabler choices,
including pxlflux's Solar Colour/Mono artwork. These select individual icons,
not a mandatory whole-theme replacement. [Picker instructions and credits](ICONS.md).

## Updates and compatibility

Use **Uppdatera OrbitUI** for the whole plugin, with preview releases enabled
for the beta. Both embedded component update menus lead there. Original standalone
repositories and their update channels are unchanged. Add-on updates use their
separate menu. [OTA and recovery](OTA.md).

OrbitUI preserves integration hooks and legacy action names where supported,
but arbitrary SimpleUI/Bookshelf user patches can still conflict. Report problems
to OrbitUI first and keep a full backup. For implementation details and historical
behavior, see [shared surfaces](SHARED_UI.md) and the [integration contracts](INTEGRATION_CONTRACTS.md).
