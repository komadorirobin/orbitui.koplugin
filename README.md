# OrbitUI for KOReader

An experimental, single-plugin distribution of the BookOrbit-tailored SimpleUI
and Bookshelf forks. The first milestone preserves the existing screens and
behavior; it is not a rewrite of the navigation or reading engine.

## Status

Development only. Do not replace a working installation until the device test
checklist has passed. Original SimpleUI and Bookshelf installations must be
disabled and KOReader restarted before enabling OrbitUI. Their files and user
data must not be deleted. OrbitUI refuses to initialize its components while
either original plugin is enabled.

The imported baselines are Bookshelf 5.2.2.3 and SimpleUI 2.7.2-beta.5. Their
complete histories and licenses are retained under `components/`. Exact sources
are recorded in `sources.json`. Neither original repository is modified.

## Architecture

- `main.lua` is the only KOReader plugin entry point.
- `core/` owns component loading, compatibility checks and the host lifecycle.
- `adapters/` contains the small component-specific embedding seams.
- `components/` contains the two imported Git subtrees.
- `tests/` exercises OrbitUI's integration contracts in addition to the original
  component suites.

BookOrbit synchronization, MyAnimeList and Patch Manager remain separate plugins.
The component updaters are disabled in OrbitUI; components must never update
independently inside a combined installation. This first development build is
installed manually. A common OTA installer is a later milestone.

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
