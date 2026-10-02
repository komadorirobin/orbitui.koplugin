# Experimental installation and rollback

This is the first integration milestone, not a stable replacement. It keeps the
two component implementations and existing navigation behavior behind one
KOReader plugin. The navigation state machine and shared data services have not
yet been consolidated. Headless tests do not establish device stability.

## Before testing

1. Retain the working Bookshelf and SimpleUI installation ZIPs.
2. Make an independent backup of KOReader's settings and your userpatches.
3. Disable the standalone Bookshelf and SimpleUI plugins in KOReader, then restart.
4. Install the generated `dist/orbitui.koplugin.zip` in the plugins directory and
   restart. Keep the original plugin directories, but keep them disabled.

OrbitUI blocks startup if either standalone plugin is still enabled. Installing
the ZIP does not automatically disable anything. Renaming a backup directory to
another name ending in `.koplugin` is not a safe way to disable it.

## Settings

Before exposing either component, OrbitUI snapshots Bookshelf settings (including
Bookshelf-owned link records), SimpleUI settings, and the global reader settings into:

`settings/orbitui/before-first-run/`

`COMPLETE` names the successful `attempt-*` snapshot and its files. Failed
attempts are retained for inspection, never declared complete. Backup failure
blocks component startup. A completed snapshot is not overwritten on later
launches. These files may contain private tokens; do not attach them to issues.

The first milestone deliberately keeps using the existing settings filenames
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

## Updating this alpha

Install the entire new OrbitUI runtime ZIP and restart KOReader. Both component
updaters are replaced with an informational, non-networking adapter. Existing
component update menu entries cannot install standalone packages. There is no
active common OTA installer in this milestone, and no production update channel
is redirected to OrbitUI.
