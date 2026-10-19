# Ornament add-ons

OrbitUI's installer no longer contains ornament artwork. Fresh installations do
not seed ornaments, including the upstream template/cactus. Existing folders,
reader overrides, placement keys and theme selections are not removed.

## Reader workflow

Open **OrbitUI settings > Add-ons > Ornament add-ons**, or **Add ornaments** in
the ornament browser. Choose **Check ornament updates**, open a pack, preview it,
then install/update. Downloads use verified HTTPS, whole-ZIP and per-file SHA-256
checks, a bounded data-only format and inactive staging. Cancelling a download
does not activate its partially downloaded files. No account is required.

A new pack starts disabled. **Use in current theme** enables it and adds its
pieces through Bookshelf's native theme switches. Shelves sharing that theme
share its ornament choices; this does not create an independent per-chip theme.
Existing local packs retain their activation choices during adoption. **Disable
pack** temporarily suppresses it in all shelf pools without changing those choices.
**Credits and licenses** displays the downloaded pack's attribution notices.

Installed packs also offer **Placement > Match books (default) / Random**.
Matching keeps busts beside their authors and manga ornaments beside their series;
pieces without a binding remain ordinary mixed decorations. Random ignores those
bindings and uses the normal shuffled deck, including on unrelated/bare shelves.
The choice applies to this logical pack wherever it is enabled, across themes and
shelves. It neither enables the pack nor changes theme selections or saved deck
order. Paging does not reshuffle; Classic retains its once-per-session shuffle.
Random busts count as ordinary ornaments (at most one per row); multiple matching
busts may still share a row. Matching busts retain priority over ordinary pieces.
Narrow rows shrink/omit an oversized piece rather than overlap its book.
Choices survive restart, independent updates and reinstallation. Missing settings
mean matching without writing a migration. Existing unmanaged folders retain
matching until explicitly installed/adopted through the add-on manager.

Information cards use Swedish for KOReader's Swedish locale and English for all
other languages. Translations travel with the add-on, not the plugin. Existing
local installations receive them when installing/updating their ornament pack.
Source and licence links are identical in both versions. Reader-written captions
keep precedence in either language; untranslated third-party packs keep their own
captions. Raw attribution documents retain their original language.

Manga is one visible pack, with one independent version. `Manga II/...` and
`Manga III/...` remain compatibility paths for already-installed artwork, not
separate future products. The browser groups all three into the **Manga** chip.
Add future pieces under `Manga/`; do not introduce Manga IV, V, etc.

## Preservation and recovery

State lives under `settings/orbitui/addons`, outside the plugin/runtime slots.
`installed.json` atomically selects immutable version directories. Update work is
performed in a cancellable subprocess; only the main process activates a
verified, prepared directory, provided the registry revision has not changed.
Unknown registry schemas fail closed, without erasing the file or native artwork.

The frozen `assets/addons/legacy-v1.json` inventory identifies the previously
bundled artwork. During explicit installation, unchanged legacy copies are
overlaid, but their native files are not deleted. Modified native files keep
priority. Missing old images in existing pack folders remain missing. The exact
old relative paths keep existing on/off, per-reader metadata and manual deck
references valid. This is deliberately conservative for partial old installs.

Managed updates preserve edited images, added files and deleted images. Pack
metadata is merged field-by-field against the previous official defaults; local
edits/deletions win, while untouched values receive updated descriptions/defaults.
Native reader-level `ornaments.json` remains untouched. New verified `bindings`
data can add author/series aliases without an OrbitUI code release.

Uninstall removes unchanged downloaded files, retaining modified files and the
registry tombstone. Old native folders are retained for safety but recognized
unmodified copies stay masked. Custom files remain available. This intentionally
does not promise to reclaim disk space occupied by the pre-add-on installation.
After successful updates, obsolete inactive snapshots are reclaimed. An
interrupted download may leave inactive staging until the next installation attempt.

## Maintainer workflow

The first catalog is **ornaments-1**, paired with **0.1.0-alpha.54**. Older plugin
versions cannot understand this add-on channel. The bundled catalog contains
descriptions only: **Check ornament updates** retrieves verified download details
from the published release. Publishing remains an explicit maintainer action.

1. Add/update source artwork, attribution, information and default metadata under
   `assets/ornaments/<folder>/`. Keep stable paths for existing images.
   Update `addons/ornament-translations.json` too: each information card has
   `en`, `sv` and the original caption's UTF-8 SHA-256 (`source_sha256`). A source
   change requires translation review; missing, stale or oversized translations
   block the build. One language must retain the original caption verbatim.
   The builder emits flat `info_en`, `info_sv` and `info_source` strings alongside
   the unchanged native `info`. The latter snapshot prevents translations from
   hiding an edited caption, including after three-way update merges.
2. Increase only that pack's integer `version` in `addons/packs.json`. Optional
   `bindings` map image paths to `{kind, id, names}`. `kind` is `author` or `series`;
   series IDs start with `series:`. Aliases are literal data, never Lua/actions.
3. Build using `python3 scripts/build-ornament-addons.py --revision N --previous
   /path/to/previous/ornaments-catalog.json --output dist/ornaments-N`. Omit
   `--previous` for the first release. Revisions must increase; unchanged pack
   versions must have identical ZIP bytes and keep their immutable download URL.
4. Review rights/credits, run tests and the native smoke test, then publish only
   with explicit approval. Use the tag **ornaments-N** in this repository with
   `ornaments-catalog.json`, new ZIPs, previews and `SHA256SUMS` as release assets.
   Retain referenced assets from previous releases. Never overwrite a released
   pack version. Mark these releases as prereleases and never as GitHub's Latest
   (`make_latest: false`), so plugin download links still point to a code release.
   These non-semver tags are ignored by the OrbitUI code updater.

No plugin VERSION bump or new OrbitUI ZIP is needed for subsequent ornament
updates. The catalog is refreshed only on request, with its last verified copy
available offline. It currently discovers catalogs among the latest 100 GitHub
releases; do not let the last ornament catalog age out of that window.

`--baseline` is for the initial frozen migration inventory only, not for artwork
updates. It refuses to replace an existing inventory with different content.
Do not alter the artwork release hold in AGENTS.md; the builder rejects its hash.

## Verification before release

Run `sh scripts/test.sh`, `LUA=luajit sh scripts/test.sh`, translation and runtime
archive checks. `scripts/smoke-addons.lua` exercises actual libarchive/SHA-256/JSON
installation, preservation, cleanup and uninstall on Linux with the pinned
KOReader reference FFI modules. It uses local ZIPs by default; append `--live`
to fetch the published catalog and install through actual LuaSocket/LuaSec HTTPS.

Device acceptance remains required: fresh install with no artwork; existing
reader adoption; cancelled/offline download; Manga update; custom image and
deleted-image preservation; restart; enabled/disabled themed shelves; preview,
credits, zoom and native browser controls. Verify that native artwork remains
available if add-on state is unreadable. Headless tests do not prove touch UI or
device-specific rendering. No public beta approval is implied.
Also switch each pack between matching and random, return to both active and
parked shelves, page forward/back and restart. Confirm off switches and theme
choices stay unchanged, all old Manga folders follow the same setting, and the
choice survives a pack update. Test narrow rows and cancelling the placement menu.
