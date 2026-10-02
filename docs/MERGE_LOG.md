# Reviewed import and merge log

This log is the durable handoff between development conversations. It records
approved imports, not merely upstream commits seen by the monitor. An entry
does not imply a public release or successful device testing.

## 2026-10-02: Initial OrbitUI import

- Bookshelf fork: `v5.2.2.3`, `2d46b259028ddbebc0159effe6171abb14520868`.
- SimpleUI fork: `2.7.2-beta.5`, `a8bbbdb89dcce9a4b9d86cfa321c8cecce9b030f`.
- Included Bookshelf upstream: `dc96d18848cfc8dfb543b9ae9aec77e65fd00b0a`.
- Included SimpleUI upstream: `ade0df9eca195c2cf8134005025f4b971e681ac0`.
- History imported without squash, in separate subtree commits. Embedding seams
  are described in `UPSTREAM.md`; neither predecessor repository was modified.
- OrbitUI foundation: `08175cb353e7018ebe51f1e999dbccadc4577037`.
- Verification: 39 OrbitUI integration tests; 310 Bookshelf suites passed with
  3 skipped; 13 SimpleUI test files passed, under Lua and LuaJIT. GitHub Actions
  run [37050332399](https://github.com/komadorirobin/orbitui.koplugin/actions/runs/37050332399)
  passed. Seven inherited translation failures remain explicit hash-bound
  exceptions; see `TESTING.md`.
- Device: not yet tested on the Bigme. Manual alpha package only, no OTA release.

## 2026-10-02: Monitoring policy

The user chose automatic monitoring with reviewed merges in the development
conversation, not automatic merges or releases. Exact tracked branches and
already-integrated upstream pins were recorded in `sources.json`. This records
existing ancestry; it does not import any additional upstream code.

The monitor's current counts, commits and releases live in the status issue and
Actions artifacts, not in this log. Changing counts must not create fake merge
entries or repeatedly edit source files.

## Template for the next approved merge

Copy this section and replace placeholders only after performing the work.

- User request / scope:
- Component and tracked branch:
- Prior integrated upstream SHA:
- Reviewed target upstream SHA / release:
- OrbitUI merge commit and adaptation commits:
- Affected contracts (C01-C09):
- Conflicts and semantic decisions (including upstream changes deliberately deferred):
- Updated upstream pin and generated module-map changes:
- Tests passed, skipped, known baseline failures and new gaps:
- Device checks performed / still required:
- Release decision and user approval (or explicitly "not published"):
- Recovery considerations and next maintainer notes:
