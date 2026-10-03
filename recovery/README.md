# Temporary Material icon recovery

Use `2-orbitui-material-safe-mode.lua` only when OrbitUI alpha.6 cannot start
after applying Material Symbols Rounded. It is a standalone KOReader userpatch,
not a second plugin, and does not need a working KOReader menu to install.

1. Stop/force-stop KOReader on the reader.
2. Using the device's file manager or a USB connection, place the Lua file in
   KOReader's `patches` directory, alongside the manga-header patch. Keep its
   filename, including the `2-` prefix and `.lua` extension. Do not put it inside
   `plugins/orbitui.koplugin/` or a subdirectory of `patches`.
3. Start KOReader. Material overrides for system/default-action icons are ignored
   in memory, allowing those slots to use their ordinary defaults. This is a
   targeted workaround, not a confirmed fix for an as-yet-unidentified crash.
4. After installing the corrected OrbitUI build, stop KOReader and remove this
   temporary patch (or change its extension to `.lua.disabled`), then restart.
   Material choices become visible again through the corrected SVG renderer.

No settings file is rewritten, no icon override is deleted, and book files,
progress, links, credentials and layout are untouched. Non-Material custom icons
are not hidden. The patch preserves the existing module resolver and earlier
userpatch preload interceptors. Userpatch support must already be enabled.

The old bulk preset overwrote icon values without taking a per-change snapshot.
This patch cannot reconstruct those earlier icon choices; it only hides the
new Material values temporarily. Do not delete `sui_settings.lua`, erase reading
data or restore an entire old settings snapshot to fix an icon problem.

The corrected working tree makes Material a per-icon catalogue only; it has
not yet been published. In that build use **Appearance > Home appearance >
Icons**, choose the one icon to edit, and then **Material Symbols Rounded...**.
Opening the catalogue does not apply anything. Other icon packs are unchanged.

Validation: `lua tests/test_icon_recovery.lua` and
`luajit tests/test_icon_recovery.lua`. These are headless tests, not a successful
startup report from the affected device. If the patch does not restore startup,
stop retrying and diagnose separately; no crash-log export from a working UI is
required for installing this workaround.
