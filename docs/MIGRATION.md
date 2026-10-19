# Installing, switching and returning safely

OrbitUI Beta 1 replaces the standalone SimpleUI and Bookshelf plugins with one
combined plugin. Neither original plugin is required for a fresh installation.
Existing users can retain their settings and artwork, with the limits below.
This is a public beta, not an exhaustive device-compatibility certification.

## Before installing

1. With KOReader stopped, make an independent backup of its settings, user
   patches, custom artwork and working plugin folders/ZIPs. Include the entire
   `settings/bookshelf/` and `settings/simpleui/` directories, any loose
   `settings/bookshelf*` files, `settings.reader.lua`, custom resources under
   `icons/`, and external wallpaper/image folders. Book sidecars and reading
   data may live elsewhere; include them in your normal reading-data backup.
2. Start KOReader, disable **SimpleUI and Bookshelf** in the plugin manager
   (whichever are installed), then restart. Do not delete their files/settings.
3. Fully exit KOReader. Download **orbitui.koplugin.zip** from the
   [OrbitUI release](https://github.com/komadorirobin/orbitui.koplugin/releases/tag/v0.1.0-beta.1),
   extract it into KOReader's `plugins/` directory and start KOReader again.
   The correct path is `plugins/orbitui.koplugin/main.lua`, with no extra wrapper.
4. Enable OrbitUI and restart if necessary. Fresh users get a setup guide;
   existing component users can open **Tools > OrbitUI > OrbitUI settings >
   Setup guide** manually. Review choices before applying them.

OrbitUI blocks startup if either standalone plugin is still enabled. Installing
the ZIP does not automatically disable anything. Renaming a backup directory to
another name ending in `.koplugin` is not a safe way to disable it.

## What is preserved

| Data | Behavior in Beta 1 |
| --- | --- |
| SimpleUI preferences and Home layout | Reused at `settings/simpleui/sui_settings.lua`, not reset to a demonstration layout. |
| Older Bookshelf / existing OrbitUI preferences | Continue using `settings/bookshelf.lua` and related flat files. |
| Current standalone Bookshelf preferences | If no flat settings file (or `.old`) exists, use `settings/bookshelf/settings.lua` and its associated stores/caches in place. No file move is run. |
| Ornaments | Existing `settings/bookshelf/ornaments/` and legacy `icons/bookshelf.ornaments/` remain available. Files, custom captions and selections are not intentionally replaced. |
| Wallpapers, icons and external image folders | Files remain where they were. Keep custom paths and the disabled original plugin folders if settings refer to resources inside them. |
| Books, bookmarks and reading progress | No book move or reading-progress reset is performed by setup. Normal KOReader reading behavior continues. |
| Other plugins and accounts | Not removed or reconfigured by setup. BookOrbit/MAL synchronization still belongs to those plugins. |

**These stores are reused, not isolated copies.** UI preference changes may be
visible when you return to the standalone plugins. New OrbitUI-only keys and
newer upstream formats may be ignored by older versions; exact visual rollback
is not guaranteed.

If both `settings/bookshelf.lua` and `settings/bookshelf/settings.lua` exist
(including `.old` backups), the **flat layout wins** to preserve established
OrbitUI installations. Neither copy is merged or deleted. If the native folder
contains the configuration you want instead, stop and back up both complete
sets before switching; do not delete individual settings files to experiment.
Ask for help if you are unsure which installation last wrote each set.

The first-run snapshot covers selected Lua settings, not artwork, books,
databases or every external plugin. Its exact scope and rollback instructions
are below. It does not replace the independent backup in step 1.

## Settings

### Configurable library sections (stage 1)

OrbitUI settings > Library sections edits saved library names, icons, folder
roots, order and shelves. The same sections are available as bottom-bar actions
under Navigation & bars. Long-press a shelf > Edit shelf edits its name and
folder-grouping options; Appearance keeps the existing Bookshelf style picker.
Adding a folder shelf outside a section's current roots extends that section's
scope. Changing a root repoints its descendant folder shelves but never moves
files. Removing a shelf removes only its reference, not books or saved styling.
Disabling a section is reversible and retains its settings and action identity.

On first use, version 1 of `orbitui_libraries` is added to bookshelf.lua. Existing
profile-specific settings trigger an additive import of the former prose/comics
definitions with the same IDs and folder choices. No other preference keys,
Home layouts, credentials or document sidecars are changed. A stock Bookshelf
file by itself does not trigger that import. With no earlier profile usage, the
initial section uses KOReader's selected home directory, or remains unconfigured
if no absolute home directory is set. Invalid/future schemas are not overwritten.

This is the configuration foundation used by the beta setup guide below.
Older OrbitUI versions ignore the new section registry and retain their former
fixed profiles; new sections and edited paths therefore require this build.

### Configurable Reading dashboard (stage 2)

OrbitUI settings > Reading dashboard > Cards and content can show/hide each of
the nine cards, reorder the six main blocks and reorder the four statistics
inside their block. Visible blocks fill rows left to right; an unpaired block
uses the full width. Statistics remain a compact group, not a free-form canvas.
The same settings are available in the dashboard module's Custom Screen menu,
scoped to that screen. Existing heading overrides and dark-card preference stay
separate and unchanged. Restore card layout shows all cards in the original
order, without resetting sources, headings or other Home pages.

Both book rows can use local To Be Read, New Books, recent history, a named
KOReader collection, a saved library shelf, or cached BookOrbit Want to Read.
Shelf references follow current scope/filter/sort settings. A deleted collection
or disabled/deleted shelf shows an unavailable/empty state, never unrelated
books. Changing sources resets only that card's paging; moving cards keeps its
page. Hidden book/goal cards do not read their source or request goal refreshes.
Goal source can be automatic (the previous behavior), local annual goal, or
Hardcover. BookOrbit and Hardcover remain optional and own their data/sync.

The versioned `<screen-prefix>orbitui_dashboard_config` is added to SimpleUI's
existing store. At registration, existing Home/Custom Screen dashboard settings
(including a previously disabled dashboard) retain the old BookOrbit default.
New dashboards use local To Be Read. The one-time marker prevents subsequently
created screens from being mistaken for old installations. Other layout pages,
wallpaper, navigation, credentials and reading data are not rewritten. Unknown
config versions are preserved and shown as unsupported, not silently reset.

Device checks before release: existing layout unchanged after upgrade; hide,
reorder and restore cards; change each row's source; swipe/paging after rotation;
delete a chosen collection/disable its section; offline optional integrations;
independent Custom Screen settings; night mode and book-close refresh. Headless
geometry/interaction tests and schematic previews are not device approval.

### Setup guide and optional integrations (stage 3, alpha.53)

**OrbitUI settings > Setup guide** edits a draft of library sections/folders,
the launch screen and bottom-bar buttons. Review and apply shows the choices
before saving. Cancel discards the draft; no books are moved, no `home_dir` or
folder-lock preference is changed, and no credentials, reading data, existing
Home pages or book-close target are reset. Section IDs remain stable when a
folder or label changes. Newly selected folders must exist; temporarily absent
old roots (for example on removable storage) may remain unchanged.

The guide appears automatically only on a fresh installation, in FileManager,
not while a book is opening. It offers the local Reading dashboard and a small
Home/library/power bar, applied only after confirmation. The dashboard is an
additional page, not a replacement layout. Existing Home pages and File browser
are alternative launch targets. Bar buttons appear in selection order and obey
the native bar limit (including navigation-pager mode); two buttons are required
when building a bar with this guide. More advanced choices remain in Navigation
& bars. Adding a library section does not silently add a button to an existing
bar: select it in the guide's Bottom bar step.

Before components create defaults, `settings/orbitui/setup.lua` records version 1
and a `pending` or `kept` status. Existing Bookshelf/SimpleUI files (including
native Bookshelf's `settings/bookshelf/settings.lua`, `.old` backups, or legacy
global preferences) select `kept`: upgrades are not prompted
and their choices are left alone. The user can open the guide manually, with
all choices initially set to Keep existing. On a fresh install, Cancel leaves
setup pending for the next launch; Skip automatic setup stops automatic prompts
but does not prevent opening the guide from settings. A reader-first launch
defers the prompt until FileManager is available. Unknown setup schemas block
initialization rather than being overwritten. Normal component defaults and
additive stage 1/2 migrations still run independently of the guide.

OrbitUI suppresses the embedded SimpleUI onboarding and its pre-guide startup
override. Standalone SimpleUI behavior is unchanged. Draft callbacks stop after
the owning host is torn down. Stale drafts are rejected before saving. Detected
write failures attempt to restore only touched keys and leave setup incomplete;
this is not a power-loss-atomic transaction across three settings files.

**OrbitUI settings > Optional integrations** explains BookOrbit, Hardcover and
MyAnimeList and shows local detection only, not a connection test. Opening it
does not load a provider, scan books, make network requests, display tokens or
enable another plugin. Accounts remain configured in their owning plugin/module.
Local books, TBR, reading goals and series boxes work without these integrations.
Existing configured integrations continue to work; this guide does not disable
them or rewrite old dashboard sources.

Broader beta testing should cover fresh/upgrade installs on devices,
folder picker/back/cancel in portrait and landscape, ReaderUI-first startup,
Home/library/bar transitions after restart, missing integrations/offline use,
and OTA/rollback. Shelf appearance presets are covered in stage 4 below.
Legacy action aliases remain supported, not forcibly renamed. Artwork/license
and public documentation review are separate release checks. The maintainer
approved Beta 1 after testing the existing setup and ornament menu; this does not
certify every fresh-install path or device.

### Shelf presets (stage 4, alpha.53)

**OrbitUI settings > Appearance > Shelf preset**, also available as a draft choice
in the setup guide, controls only the physical bookshelf:

- **Shelf settings**: native cover-facing rules and series-box toggle per chip,
  including profile-qualified chips, with the existing ornament selection.
  No extra OrbitUI artwork is automatically copied. Native series grouping
  excludes single-volume series, unlike Classic.
- **Classic OrbitUI**: retain all-face-out covers, boxes for all eligible series
  including singletons and explicitly configured grouped folders, and the
  existing session shuffle. Optional packs are installed through Add-ons. Author and
  manga affiliations remain intact.
- **Minimal bookshelf**: all covers forward, no series compaction and no
  ornaments, including targeted author busts and manga miniatures.

Preset choice is a versioned `appearance` entry in `settings/orbitui/setup.lua`.
Detection runs after the backup but before components/ornament installers load.
A pre-existing completed OrbitUI first-run snapshot preserves Classic. A first
OrbitUI launch, even over standalone Bookshelf/SimpleUI settings, uses Shelf
settings. An already-pending fresh setup remains neutral after restarts. Once a
preset is stored, neither detection nor completing/skipping the guide changes it.
Unknown schemas block startup rather than being reset.

These are reversible runtime policies, not bulk writes into Bookshelf settings.
Home, wallpapers, icons, bindings, cover size/text, native per-chip selections,
disabled packs, manually edited artwork, reading data and credentials stay intact.
Switching away from Classic does not uninstall artwork it already installed;
disable individual installed packs in Shelf theme or select Minimal to hide all.
Existing matching and spacing improvements apply to any installed ornaments.
No preset runs the old one-time installers, including stock-cactus replacement.
The [add-on migration](ADDONS.md) is explicit, preserves old folders and uses
stable relative image paths. Manga, Manga II and Manga III appear as one Manga
pack; no existing preference/placement keys are renamed.

Selection asks for confirmation, saves with rollback on detected errors and
invalidates prepared box/ornament pagination. Parked shelves rebuild on return.
The guide includes presets in its normal stale-draft validation and review/save
transaction. Cancel does not apply a preset or install artwork. Geometry fixes
and modern bindings remain available in all presets; standalone components are
unchanged by default: profile `series_boxes` joins the style fields and an optional
editor frequency override reports None/read-only in Minimal without changing the
saved frequency. Returning to a decorated preset restores that control.
Beta feedback should include these choices on fresh and upgraded installations.

Before exposing either component on the first OrbitUI launch, OrbitUI snapshots
flat `settings/bookshelf*.lua` files and `.old` backups, top-level Lua files and
`.old` backups in `settings/bookshelf/`, SimpleUI's `sui_settings.lua` and `.old`,
and the global reader settings into:

`settings/orbitui/before-first-run/`

`COMPLETE` names the successful `attempt-*` snapshot and its files. Failed
attempts are retained for inspection, never declared complete. Backup failure
blocks component startup. A completed snapshot is not overwritten on later
launches. Native Bookshelf files use the `bookshelf/` subdirectory inside the
snapshot attempt. These files may contain private tokens; do not attach them to issues.

OrbitUI deliberately keeps using the selected existing settings filenames
and schemas. There is no destructive settings migration. Normal UI preference
changes therefore also remain visible to the old plugins if you roll back.
Bookmarks, document sidecars and reading-history databases are not copied or
rewritten by OrbitUI's backup mechanism. Normal component reading behavior is
unchanged. External BookOrbit/Hardcover plugin settings and SQLite caches are
not part of this snapshot; retain an independent full backup before testing.

## Returning to the old plugins

1. Disable OrbitUI and restart KOReader.
2. Enable the retained standalone Bookshelf and SimpleUI plugins, then restart.
3. If UI settings were damaged, restore only the affected UI settings from the
   successful snapshot with KOReader stopped. Do not blindly restore all global
   settings or replace reading-progress files with older copies.

Never run the standalone plugins alongside OrbitUI, even if an earlier startup
failed. A failed initialization may already have installed some UI hooks; a
restart is required before switching implementations.

## Updating OrbitUI

After the first manual installation, use **Tools > OrbitUI > Uppdatera OrbitUI**
(the updater's current label).
Embedded component update entries open the same common updater; they cannot
install standalone packages. Preview releases are included by default on an
alpha/beta installation. No predecessor update channel is redirected to OrbitUI.

Beta 1's native Bookshelf layout support is new. If you switch from a current
standalone Bookshelf installation using `settings/bookshelf/settings.lua`, an
OrbitUI alpha rollback does not understand that location. It leaves the native
files intact but may display defaults from a newly created flat store. Prefer
returning to the retained standalone Bookshelf instead of downgrading to an alpha
in that case. Existing flat-layout OrbitUI users retain their usual code rollback.

Read `OTA.md` for verified staging, restart activation and code rollback. Manual
replacement of the factory ZIP requires stopping KOReader and renaming any
existing `.orbitui-active` record so that it will not select an older OTA slot.
