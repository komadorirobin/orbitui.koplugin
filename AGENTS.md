# OrbitUI

Artwork release hold: the superseded AI-assisted Seitz/Mann PNG with SHA-256
`fc6d71bd1538bee9a569a9838b7a00c5374469f0cc8efad3c70674a20c286bb9` remains
uncleared. Do not push that bitmap, including Git history containing it, or
publish an OTA containing it. The current non-generative Ahrens cutout is a
different asset with its own documented source/license/panorama basis in
`assets/ornaments/Authors/THOMAS-MANN-SEITZ.txt`. Replacing the tip's image does
not sanitize unpublished ancestors; preserve local work and prepare a public
history without the held bitmap before releasing.

Experimental KOReader Lua plugin combining the published user forks of SimpleUI
and Bookshelf. Keep the original repositories and their update channels intact.

- Work in `core/` and `adapters/` for shared integration logic. Keep component
  source changes minimal, documented, and in separate commits from subtree imports.
- Do not update upstream baselines unless explicitly requested. Record exact
  revisions in `sources.json`; never silently follow a moving branch.
- Only the root is a KOReader plugin. Component directories must not end in
  `.koplugin` and must never self-update.
- Do not erase or reset user settings, reading data, links, credentials, or caches
  during migration. Never automatically activate OrbitUI alongside its predecessors.
- Use Lua 5.1/LuaJIT-compatible syntax. Run `sh scripts/test.sh` and validate the
  runtime ZIP before marking a build ready. Headless tests are not device tests.
- Keep legacy actions and plugin-instance aliases working until callers have a
  tested migration. Do not globally replace `require`, `gettext` or DataStorage.
- No automatic public release or production OTA change from CI. Device approval
  and an explicit publication request are required before a public beta release.
- Upstream automation is monitoring only: no automatic merge, merge PR, version
  bump, tag, release or OTA publication. A reviewed merge requires a user request.
- Before merging, read `docs/UPSTREAM.md`, `docs/INTEGRATION_CONTRACTS.md` and
  `docs/MERGE_LOG.md`. Preserve the contract IDs; record any deliberate change
  and its approval rather than silently dropping a local behavior.
- `sources.json` records original fork imports and separately the integrated
  upstream commits/branches. Advance upstream pins only in a reviewed merge;
  never mark an observed-but-unmerged upstream commit as integrated.
