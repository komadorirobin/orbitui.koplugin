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

Version **0.1.0-alpha.3** integrates Bookshelf **5.3.0** through `21e005a7`
and SimpleUI `main` through `3444cc9c`. See [the release notes](docs/releases/0.1.0-alpha.3.md)
and [the merge log](docs/MERGE_LOG.md) for retained behavior and testing.
KOReader v2025.08 or newer is required. Storage paths remain rollback-compatible;
OrbitUI does not run Bookshelf 5.3's automatic file move.

The first public build has a positive initial Bigme startup/navigation report.
Full device acceptance and device OTA/recovery testing are still outstanding.

## Architecture

- `main.lua` is the only KOReader plugin entry point, backed by a stable OTA bootstrap.
- `core/` owns component loading, compatibility checks and the host lifecycle.
- `adapters/` contains the small component-specific embedding seams.
- `components/` contains the two imported Git subtrees.
- `tests/` exercises OrbitUI's integration contracts in addition to the original
  component suites.

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
