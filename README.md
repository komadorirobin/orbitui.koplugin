# OrbitUI for KOReader

An experimental, single-plugin distribution of the BookOrbit-tailored SimpleUI
and Bookshelf forks. The first milestone preserves the existing screens and
behavior; it is not a rewrite of the navigation or reading engine.

## Status

Public preview, not yet fully device-accepted. Retain a working installation and its
backups while testing. Original SimpleUI and Bookshelf installations must be
disabled and KOReader restarted before enabling OrbitUI. Their files and user
data must not be deleted. OrbitUI refuses to initialize its components while
either original plugin is enabled.

The imported baselines are Bookshelf 5.2.2.3 and SimpleUI 2.7.2-beta.5. Their
complete histories and licenses are retained under `components/`. Exact sources
are recorded in `sources.json`. Neither original repository is modified.

Version **0.1.0-alpha.10** includes Bookshelf **5.3.1** through `9633b031` and
SimpleUI `main` through `3444cc9c`, on top of alpha.4's shared OrbitUI surfaces.
See [the release notes](docs/releases/0.1.0-alpha.10.md)
and [the merge log](docs/MERGE_LOG.md) for retained behavior and testing.
KOReader v2025.08 or newer is required. Storage paths remain rollback-compatible;
OrbitUI does not run Bookshelf 5.3's automatic file move.

The alpha.5 preview adapts upstream's footer refresh regions to the OrbitUI dock
and retains whole-group navigation through shared book panels/search. The
transparent-pagination divider fix also covers folder/list views and full-screen
modules. No existing release assets are replaced.

The first public build has a positive initial Bigme startup/navigation report.
Full device acceptance and device OTA/recovery testing are still outstanding.

Alpha.10 adds per-icon Solar Outline, Solar Line Duotone and Tabler
sources, including an OrbitUI manga icon in both Solar styles. Existing choices
are unchanged; these are not bulk icon-pack presets. See [icons](docs/ICONS.md)
for previews and selection instructions.

The alpha.6 preview added 110 offline Material Symbols Rounded icons, including
manga. A Bigme startup crash was reported after applying its whole-pack preset.
If that prevents startup, see the non-destructive [recovery patch](recovery/README.md).
The alpha.7 correction makes Material a [per-icon picker](docs/ICONS.md) only
and uses SVGs instead of a separate text font. Existing choices are not reset.
It can be installed directly from alpha.5 through the preview OTA channel.
Alpha.8 fixes a separate crash when opening the Material picker: the category
loop shadowed the translation function. Regression tests now construct and
refresh the real shared modal over native widget stubs. Device testing remains
outstanding; no saved icon choices are changed.
Alpha.9 adds a Material line-thickness preview and per-icon weights of 200, 300,
400 or 500. The requested new default is 300, also for older unweighted Material
selections. Explicit weights remain independent; Nerd Font and custom image
choices are unchanged. All variants remain offline SVGs, not variable fonts.

## Architecture

- `main.lua` is the only KOReader plugin entry point, backed by a stable OTA bootstrap.
- `core/` owns component loading, compatibility checks and the host lifecycle.
- `adapters/` contains the small component-specific embedding seams.
- `components/` contains the two imported Git subtrees.
- `tests/` exercises OrbitUI's integration contracts in addition to the original
  component suites.

Version `0.1.0-alpha.4` adds shared book panels, searchable library scopes,
live Home shelf modules and an OrbitUI settings hub.
See [shared UI features](docs/SHARED_UI.md) for controls,
compatibility boundaries and the pending device checks.

BookOrbit synchronization, MyAnimeList and Patch Manager remain separate plugins.
The component updaters are disabled in OrbitUI; components must never update
independently inside a combined installation. Install the first
[release ZIP](https://github.com/komadorirobin/orbitui.koplugin/releases) manually.
Subsequent updates use **Tools > OrbitUI > Uppdatera OrbitUI**. The same label
appears in the embedded SimpleUI and Bookshelf update menus. The common OTA
installer validates a complete package, activates it on restart and retains
rollback. See [OTA and recovery](docs/OTA.md).

## Upstream monitoring

[Upstream watch](https://github.com/komadorirobin/orbitui.koplugin/actions/workflows/upstream-watch.yml)
checks Bookshelf `master` and SimpleUI `main` every six hours. The
[status issue](https://github.com/komadorirobin/orbitui.koplugin/issues?q=label%3Aupstream-watch)
shows missing commits, exact revisions and latest stable releases. It adds a
comment only when the monitored state changes, not on every check.

The watcher never merges, creates merge PRs, changes versions or publishes OTA
updates. Request merges in the development conversation. Follow
[the merge procedure](docs/UPSTREAM.md), preserve
[the integration contracts](docs/INTEGRATION_CONTRACTS.md), and record results
in [the merge log](docs/MERGE_LOG.md). This keeps project knowledge in the repo,
not only in a particular chat or model's context.

## Development

Run `sh scripts/test.sh` to check syntax and run the integration and component
tests. Run `sh scripts/package.sh` to build a runtime ZIP from a clean, committed
revision. The ZIP contains one `orbitui.koplugin/` directory; do not
install GitHub's source archive as a plugin.

See `docs/MIGRATION.md` for the opt-in installation and rollback procedure,
`docs/TESTING.md` for device verification, and `docs/UPSTREAM.md` for the import
workflow. No automatic migration, upstream merge or public release is performed
by the build scripts.

## Licensing

OrbitUI's original code is licensed under AGPL-3.0. The complete license is in
`LICENSE`. Bookshelf's AGPL-3.0 license and SimpleUI's MIT license and copyright
notice are preserved in their component directories. Bundled assets retain
their original notices. OrbitUI is an independent integration, not an official
release of either upstream project.
