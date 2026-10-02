# Upstream maintenance

`components/bookshelf` and `components/simpleui` were imported with `git subtree
add` without squashing. The imported fork commits and their parent histories are
available in this repository. `sources.json` pins the baselines; it is not a
claim that the component trees remain byte-identical after documented adaptations.

Future imports are explicit maintenance tasks, not a startup/build side effect.
Fetch the requested upstream revision, inspect it, and merge it into the correct
subtree on a dedicated work branch. Record the imported revision and relevant
conflict resolutions. Do not first merge it into both old forks and then repeat
the same merge here. The old forks remain stable fallback distributions during
the transition.

Keep import commits separate from OrbitUI adaptations. Preserve licenses and
asset notices. Re-run all integration tests, both original suites, translations
and package checks after each merge. A Git subtree preserves provenance; it does
not make semantic conflicts disappear.

## Current embedding changes

- Bookshelf `main.lua`: legacy flat-file cleanup uses the component instance's
  actual path, never the retained standalone installation directory.
- SimpleUI `infra/sui_paths.lua`: embedded assets and translations resolve from
  `components/simpleui/`, not the outer OrbitUI directory.
- SimpleUI `main.lua`: initialization errors propagate to the owning OrbitUI
  host instead of being reported as a successful combined startup.

Everything else is coordinated through `core/` and `adapters/`. The generated
module map gives canonical require names and legacy `sui_*` aliases a single
component instance. Re-generate it with `lua scripts/module-map.lua` after adding
or removing runtime source files. Preload hooks retain priority for userpatches.

## Next milestones

1. Validate the unchanged UX on the target device and address compatibility gaps.
2. Move navigation and reader-return ownership into one explicit coordinator,
   replacing the existing cross-plugin retry/ownership logic incrementally.
3. Add a common, staged and recoverable OTA installer, with whole-package
   validation, prerelease handling, interrupted-install tests and rollback.
4. Consolidate measured duplicate data/cache work behind stable service interfaces.

Do not combine these changes with an unrelated upstream update or visual redesign.
