# Material Symbols Rounded

OrbitUI bundles an optional, offline catalogue of 110 Material Symbols Rounded
icons, including `manga` and `comic_bubble`. Installing/updating OrbitUI does
not change any existing icon choice. KOReader's Symbols Nerd Font and custom
PNG/SVG selections remain available.

## Choosing icons

In OrbitUI settings, open **Appearance > Home appearance > Icons**.
Choose a system icon or quick-action icon, then **Material Symbols Rounded...**.
The picker has previews, Reading/Navigation/System/Tools categories and search
(including some Swedish aliases). Manga appears first under Reading.

Material is a source for choosing **one icon at a time**, not an entry under
**Icon Packs**. Opening or cancelling the picker changes nothing. Selecting an
icon changes only the button/action being edited. Other installed icon packs
keep their existing behavior.

The published alpha.6 still has the whole-pack preset. Do not apply that preset
to browse icons: it immediately overwrites many icon overrides. The per-icon
path above also exists in alpha.6, but use alpha.7 for the corrected SVG rendering.
If alpha.6 can no longer start after applying Material, see
[temporary recovery](../recovery/README.md). An already-working alpha.5 can update
directly to alpha.7 without the recovery patch or an intermediate alpha.6 install.

Bookshelf's icon library includes a **Material** category and searchable
Material entries for chip labels, start-menu icons and hero action cards.
Text-only token templates deliberately do not offer them: these templates
cannot render a different icon font or image token without further changes.

## Integration

`core/orbitui_icons.lua` owns names, paths and cached catalogue/search data.
`adapters/orbitui_icons.lua` supplies optional component
hooks through the existing runtime module resolver. No global Font or
IconWidget replacement, fallback-face mutation, or copied icon directory.

- SimpleUI's picker returns a bundled SVG path. Legacy `material:manga`
  references resolve to the same SVG through `safeIconPath`, without rewriting
  settings. Material never loads a custom font or replaces native image buttons
  with TextWidgets; Nerd-specific APIs and their existing rendering are unchanged.
- Native menu tabs use the SVG and existing registration path. Known packaged
  SVG paths are rebased to the current runtime root on read, including when a
  setting contains a previous OTA-slot path.
- Bookshelf stores `[icon=orbitui-material-manga]`. The start-menu model's
  optional imageIconFile resolver is shared by start-menu, chip and action
  renderers; other user icons continue through native name lookup.
- The font and SVGs have identical static weight-500 outlines. The static font
  remains part of the reproducible asset inventory but is not loaded by the UI.
  Material now follows the existing SVG, dimming and alpha-mask rendering paths.

Component seams: SimpleUI config, quick-action rendering/picker, style,
titlebar resizing and empty-folder covers; Bookshelf icon-library extra
sources/explicit preview file and three image-token rendering paths. These are kept
small and must be preserved in future imports (contracts C07/C08).

## Rebuilding and verification

The upstream revision, input SHA-256s and selection are pinned in
`assets/material-symbols/selection.json`. Fetch that exact revision's
`variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf` and `.codepoints`;
then, in a development environment with `fonttools==4.60.1`, run:

```sh
python scripts/build-material-icons.py /path/to/font.ttf /path/to/font.codepoints
```

The script checks the inputs before generating the static subset, SVGs,
Lua catalogue and output checksums. License and modification notices are
included in runtime archives. No generation or network access occurs on the
reader. Run `sh scripts/test.sh` and validate a runtime ZIP before release.

Device checklist (not replaced by headless tests): select manga for a dock
action and a shelf chip; check large/small sizes, light/dark themes, dimming,
native menu tabs, screen rotation, default reset, mixed Nerd/SVG/Material
choices, restart and an OTA update. Existing icon choices must not change
until the user explicitly selects a replacement for that particular icon.
The Material preset must be absent from Icon Packs, and opening/cancelling its
per-icon catalogue must not save anything. For recovery testing, retain saved
Material values, install the temporary patch on alpha.6, restart, then install
the corrected build and remove the patch. No unrelated settings may change.
