# Verification and device acceptance

## Automated

- `sh scripts/test.sh`: LuaJIT syntax, integration tests, and original component suites.
- `LUA=luajit sh scripts/test.sh`: the same test bodies under KOReader's Lua dialect.
- `sh scripts/check-translations.sh`: validate catalogs with explicit baseline exceptions.
- `python3 -m unittest discover -s tests -p 'test_upstream_watch.py' -v`: monitor,
  error handling, real Git ancestry and idempotent reporting tests; no network.
- `sh scripts/package.sh`: clean-commit runtime ZIP, archive integrity and layout checks.
- OTA tests cover release channels, semantic versions, archive safety, TLS host
  checks, deferred activation, interrupted startup and rollback. `OTA.md` records
  the protocol and recovery limits. Package tests verify inventory and checksum bytes.
- The LuaJIT CI job tests the full packaged installer against pinned KOReader-base
  archive/SHA modules (`fe41d7698ad8a6a7caf794d9b601229009a34053`) and system
  libarchive. The smoke harness substitutes only the filesystem/network/JSON
  adapters, not archive extraction or hashing. It tests activation, restart,
  rollback, a missing runtime file and a truncated download in a temporary install.
  `scripts/smoke-ota.py ZIP REFERENCE_DIR --live` additionally tests anonymous
  release discovery and download with real LuaSocket/LuaSec and `lua-cjson`.
- CI validates both components' translation files and stores an experimental ZIP
artifact. It does not publish releases or modify upstream repositories.

`scripts/test.sh` includes the monitor tests. Python 3.9+ is a development/CI
dependency only; it is not installed or needed on KOReader. The monitor has a
separate workflow and cannot publish plugin packages. See `UPSTREAM.md`.

Bookshelf's native SQLite tests require KOReader's runtime. Its exhaustive list
geometry sweep remains opt-in (`BOOKSHELF_SLOW_TESTS=1`). The runner identifies
these skips; they must not be presented as device verification.

All 41 catalogs pass `msgfmt --check` after the 2026-10-03 merge. Upstream fixed
the Italian header; the integration removes identical extra plural forms in
five single-form languages and corrects the Lithuanian plural rule. No failure
exceptions remain in `tests/translation-baseline.txt`. Header-only warnings in
some catalogs remain upstream debt; passing syntax does not verify translation
quality or completeness.

## Before calling the alpha device-tested

The user reported successful initial startup/navigation on the Bigme with
`0.1.0-alpha.2`, and a subjective impression of faster dock navigation. This is
not a timing measurement, full acceptance, or a device OTA/recovery test.
The upstream merge and renamed menus in `0.1.0-alpha.3` still need device testing.

Use the Bigme B7 Pro at its native 1264 x 1680 resolution. Retain a recovery path.
Record KOReader version, installed patches and active plugins, plus crash.log.

- Verify original-plugin conflict detection before enabling the alpha normally.
- Confirm Home layout, dock, backgrounds, icons, custom screens, fonts and language.
- Test new per-element fonts and module opacity alongside existing light
  backgrounds; verify section labels and live cover/stat updates after swipes.
- Check shelf themes, planks, ornaments and wallpaper picking at both orientations.
- Confirm existing settings, Hardcover links and status-line preferences remain
  in their original files after startup, edits, restart and rollback.
- Open Fiction and Manga from the dock, and switch between them repeatedly.
- Open books from Home, Want to Read, Currently Reading, search and a folder.
- Verify the expected automatic reading profile for every opening path.
- Close using the custom gesture, native menu and end-of-book dialog; confirm the
  intended destination and no unintended reopening or duplicate menu layer.
- Verify rotations, overlays, menus, long-press actions and exit/restart.
- Suspend and resume on Home, in each library view and inside a book. Repeat
  several cycles, including an overnight resume.
- Confirm BookOrbit progression prompts actually move the reading position.
- Check Hardcover linking and one intended sync writer; confirm no duplicate reads.
- Check MAL folder actions, badges and a completed-volume update.
- Check manga header, volume suffix and bookmark ribbon/userpatch compatibility.
- Confirm component update actions cannot download or install standalone plugins.
- Install an OrbitUI preview through its common updater, cancel a download,
  restart into the staged version and test previous-version rollback. Confirm
  the public release is found without a GitHub token and its displayed version
  matches the active runtime. Check cancellation and restart dialogs on Android.
- Test rollback without resetting book progress, links or UI configuration.

Record cold-start, warm Home/library switch and book-close times against the
published predecessor versions with the same books and settings. Compare memory
after repeated open/close cycles. Do not claim a performance gain without these
measurements.

Device acceptance is outstanding until this checklist has been executed. A
single plugin package alone is not evidence of improved performance or stability.
