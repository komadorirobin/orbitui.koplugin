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

## Optional BookOrbit integrations

Open **Integrations > BookOrbit / Integrationer > BookOrbit** for the master
switch and separate list, manual status-action and online-tag switches. Unset
switches preserve existing behaviour. Disabling them keeps caches, library
profiles, module/source IDs, custom headings, layout and local TBR membership.
It never turns off the external BookOrbit plugin's own reading-progress sync.
Queued requests retire; an already-sent server write cannot be unsent, but its
late response cannot overwrite OrbitUI's cache after a policy change.

**Want to read [Local] / Vill läsa [Lokalt]** is the existing local To Be Read
module, backed by KOReader's `To Be Read` collection. **Want to read [BookOrbit]
/ Vill läsa [BookOrbit]** is the separate server list matched to local files.
Add either or both using **Home (SimpleUI) > Layout & modules**, or select the
source in the Reading dashboard. Disabling the online list never substitutes
the local one. No automatic layout, membership or collection-name migration.

Automatic Home refresh uses the existing preference; explicit **Refresh from
BookOrbit now / Uppdatera från BookOrbit nu** shows whether that request
succeeded. The timestamp is the last successful saved list, not a connection
test or proof of optional server support. Opening settings/Tags never requests
the network. Manual Add/Remove actions do change BookOrbit's read status on an
explicit tap; that is distinct from automatic progress sync.

In **Tags / Taggar**, EPUB tags remain offline regardless of these switches.
The online section is hidden when its feature/master switch is off. Online
exact tag matching requires the separate compatible server API addition.
[BookOrbit Extras](https://github.com/komadorirobin/bookorbit-extras) documents
the composable exact official 3.6.0 source package and the legacy artifacts
separately, with SV/EN installation, licenses and test limitations. Never put
the old compiled 3.2.0 overlay on a newer server; old custom databases need a
separately reviewed upgrade. OrbitUI neither installs device patches
nor deploys a server, and never offers a naive off toggle for protected undo state.

**Svenska:** De två Vill läsa-källorna är separata. Lokalt kräver inget konto;
BookOrbit visar matchade filer från serverns lista. Huvudbrytaren stänger bara
av OrbitUIs funktioner, inte BookOrbits egen progressionssynk. EPUB-taggar finns
kvar offline. Serverpatchar är frivilliga, versionsbundna och installeras av
administratören separat. Hantera skyddade öppningar innan ångra-stöd tas bort.

## Next in series

Add **Next in series / Nästa i serien** from Home's Books module picker, or
through **Cards and content > Add card > Home modules (SimpleUI)** in the
Reading dashboard. It is optional and initially off; it never replaces
Continue reading or changes the existing Home layout automatically.

The card uses Bookshelf's native next-volume selection: prefer a volume in
progress; otherwise choose the next unread local volume after the latest
completed one, in a series already started. Unstarted and fully completed
series are not random recommendations. Decimal volume numbers retain their
normal order. The card keeps different authors' and libraries' series separate.
Tap a cover to read through the normal KOReader opener; hold it for the usual
configured cover action, including book details. BookOrbit/Hardcover continue
to own their existing sync hooks, not this card.

Long-press the module for **Library** (all libraries or one configured section),
**Refresh next volumes**, row/column controls and ordinary cover styling.
This uses indexed series metadata and local reading status, not the tag index,
an account or a server. Missing cached metadata is reported in the module's
options. A placeholder explains missing folders, empty results or an error;
none of those states fall back to unrelated recent books.

Preparation runs after the initial render: cooperative folder prewarming,
bounded read-only text metadata, and the native selection in small yielding
progress batches. Completed results are reused in memory; only visible covers
are rendered. Sleep, hiding, navigation, rotation and removal retire the work;
paused preparation needs explicit Refresh. Closing a module releases its screen
references. Library/status invalidation or explicit Refresh prepares a new
snapshot. Results are limited to 400 series after native ranking, not 400
input volumes. The card writes only its explicit library/style preferences;
it never marks a book read, moves files or adds a second progress database.

## Local similar books and series

In a local EPUB's **Tags / Taggar** tab, choose **Find similar books and
series… / Hitta liknande böcker och serier…**. Recommendations use exact
embedded EPUB tags across your configured libraries, ranked by the number of
distinct shared tags. The current book and its series are excluded. No AI,
BookOrbit account, server extension or network connection is required.

Switch between **Series / Serier** and **Books / Böcker** without rescanning
tags. Manga/comics starts on Series. A series uses its best matching volume's
score, not the sum of its volumes, so a long series does not win merely by
having more volumes. Same-named series by different authors remain distinct.
Tapping selects the book on its shelf; a series selects its first locally
available volume, which need not carry the matching tag. Nothing starts reading
automatically.

Other books use only current indexed tags. Missing/stale tags and unavailable
cached series metadata are disclosed, not guessed from genres or titles. Use
**Update tag index… / Uppdatera taggindex…** for fuller coverage; existing
library metadata must also be indexed for safe series identification. The
source EPUB may be read on your explicit request. Only the best 400 results
are displayed after ranking/grouping; the scan is not cut off at 400 volumes.
Stop/Close remain usable, and sleep does not automatically restart the work.

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

### Plugin cards and Module library (included in 1.1)

Tap **+** in the dashboard, long-press a non-book area, or open **Home (SimpleUI)
→ Reading dashboard → Cards and content → Add module…**. The picker groups
**Home modules (SimpleUI)**, **Shelf modules (Bookshelf)** and **Action shortcuts**.
It enumerates the existing public registries without preview-rendering cards or
adding a download/install system. Declared network cards ask before being added.

Install and enable [Silverfish](https://github.com/theusmaoliveiras/silverfish-koreader)
separately and restart KOReader. Its existing Home card or adaptive Bookshelf
card can then be selected; tapping opens Silverfish itself. OrbitUI neither
copies its creature engine/assets nor changes its save or screensaver settings.
Desktop checks use Silverfish 2.0.0 source d3da0797; Android acceptance is pending.
Its own language support remains the plugin's, not an OrbitUI translation.

Long-press an added card for half-width, full-width, tall or whole-page sizing,
visibility or removal. **Arrange cards** moves it among the built-in blocks;
statistics remain one group. Up to 16 added cards use at most three rows per
dashboard page. Dashboard page arrows are separate from Home and book-row arrows.
Book-cover long-press actions in the original dashboard cards are unchanged.
Missing/broken modules retain a configurable placeholder. Removal deletes only
the placement, never the plugin, its data or the ordinary Home module settings.
SimpleUI module settings are explicitly shared with that screen's ordinary
module. Dynamic-instance modules and Bookshelf-only action/shelf/ornament cards
stay in their native layout editors; use an action shortcut to launch a plugin
without a compatible card. **Create shortcut…** reuses SimpleUI's existing
action/Dispatcher/plugin-action editor and native Home navigation.

Only the current page's added cards are built. Refreshes are coalesced and replace
only the requesting card; no new whole-library scan or independent sync writer.
Minute hooks run only while visible, stop during suspend and are retired on
page changes/close. Lua errors are contained, but arbitrary third-party code is
not sandboxed or protected against native crashes/infinite loops. Oversized
content is clipped rather than painted over other cards; choose a larger size.
Existing layouts need no migration. Adding a card opts that screen into config
v2, which older OrbitUI builds show as unsupported without overwriting it.

**Svenska:** Tryck på **+**, håll inne en yta utan bokomslag eller gå till
**Hem (SimpleUI) → Läsöversikt → Kort och innehåll → Lägg till modul…**. Välj
**Hem-moduler (SimpleUI)**, **Hyllmoduler (Bookshelf)** eller **Åtgärdsgenvägar**.
Installera Silverfish separat eller via **Hämta fler moduler…** och starta om KOReader. Håll inne pluginkortet för
storlek, synlighet och borttagning; placera det via **Ordna kort**. Välj **Hel
sida** om innehållet beskärs. Borttagning av ett kort avinstallerar inte pluginet
och raderar inte dess data. Äldre OrbitUI-versioner kan inte redigera den nya
kortlayouten, men ska inte skriva över den.

The **Get more modules… / Hämta fler moduler…** prototype offers a separate
executable-plugin catalog, initially the official Silverfish 2.0.0 release.
Its badge means desktop adapter testing, not full-plugin safety/device approval.
No automatic installation, latest-version chasing, overwrite, enable, downgrade,
uninstall or save migration. Explicit consent, SHA-256, bounded plain-file ZIP
extraction, source compilation without execution, isolated staging and one
new-directory rename precede restart. Check catalog shows no publication yet;
a reviewed JSON catalog can later ship independently through modules-N releases.
Existing/legacy conflicts remain manual. Another updater's changed files show
unverified; status is refreshed on catalog open/explicit refresh, not Home paint.
Own UI is SV/EN; Silverfish itself remains upstream English/Portuguese.
See ADDONS for trust limits, licenses, data and manual recovery.

### Currently reading + Silverfish (included in 1.1)

Add the separate **Currently reading + Silverfish / Läser just nu + Silverfish**
module through the Home module picker or the Reading dashboard's **Add module…**
picker. It leaves Continue reading and existing placements unchanged. The active
companion sits on the left, reading information in the middle and the book cover
on the right. Companion/name taps open Silverfish; the title/cover resume the book.
Install and enable the reviewed public Silverfish 2.0.0 separately and restart.
OrbitUI uses checked public APIs, not a fork or copied artwork, and never advances
the creature or changes its save. Missing/unsupported APIs show a reason instead.

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

Use **Uppdatera OrbitUI** for the whole plugin: stable for 1.1 releases, or opt
into preview for the next beta cycle. Both embedded component menus lead there. Original standalone
repositories and their update channels are unchanged. Add-on updates use their
separate menu. [OTA and recovery](OTA.md).

OrbitUI preserves integration hooks and legacy action names where supported,
but arbitrary SimpleUI/Bookshelf user patches can still conflict. Report problems
to OrbitUI first and keep a full backup. For implementation details and historical
behavior, see [shared surfaces](SHARED_UI.md) and the [integration contracts](INTEGRATION_CONTRACTS.md).
