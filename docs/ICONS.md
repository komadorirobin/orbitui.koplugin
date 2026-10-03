# Material Symbols Rounded

OrbitUI bundles an optional, offline pack of 110 Material Symbols Rounded
icons, including `manga` and `comic_bubble`. Installing/updating OrbitUI does
not change any existing icon choice. KOReader's Symbols Nerd Font and custom
PNG/SVG selections remain available.

## Choosing icons

In OrbitUI settings, open **Appearance > Home appearance > Icons**.
Choose a system icon or quick-action icon, then **Material Symbols Rounded...**.
The picker has previews, Reading/Navigation/System/Tools categories and search
(including some Swedish aliases). Manga appears first under Reading.

**Icons > Icon Packs > Material Symbols Rounded** applies the built-in mappings
to Home/dock actions and configurable system buttons, including separate
Library and Manga icons. Like other packs, applying it replaces those slots'
overrides; it does not change custom quick actions, shelf labels, layout,
reading status or book data. Individual icons can still be changed/reset.

Bookshelf's icon library includes a **Material** category and searchable
Material entries for chip labels, start-menu icons and hero action cards.
Text-only token templates deliberately do not offer them: these templates
cannot render a different icon font or image token without further changes.

## Integration

`core/orbitui_icons.lua` owns names, paths, cached catalogue/search data and
default pack mappings. `adapters/orbitui_icons.lua` supplies optional component
hooks through the existing runtime module resolver. No global Font or
IconWidget replacement, fallback-face mutation, or copied icon directory.

- SimpleUI stores `material:manga` (not an ambiguous PUA codepoint). Its
  generic iconGlyph/iconFace path selects the bundled TTF; Nerd-specific APIs
  remain unchanged. Live titlebar resizing preserves the chosen face.
- Image-only native menu tabs use the matching SVG and existing registration
  path. Known packaged SVG paths are rebased to the current runtime root on
  read, including when a setting contains a previous OTA-slot path.
- Bookshelf stores `[icon=orbitui-material-manga]`. The start-menu model's
  optional imageIconFile resolver is shared by start-menu, chip and action
  renderers; other user icons continue through native name lookup.
- The font and SVGs have identical static weight-500 outlines. Existing
  foreground, dimming and monochrome/night-mode paths stay in control.

Component seams: SimpleUI config, quick-action rendering/picker, style,
titlebar resizing and empty-folder covers; Bookshelf icon-library extra
sources/preview face and three image-token rendering paths. These are kept
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
until the user explicitly selects an icon or applies the pack.
