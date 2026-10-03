# OrbitUI releases and OTA

## First installation

Download **orbitui.koplugin.zip**, not GitHub's source-code archive, from an
OrbitUI release. Follow `MIGRATION.md`: back up settings and patches, disable
standalone Bookshelf and SimpleUI, restart, install OrbitUI and restart again.
The original standalone OTA channels are not redirected or modified.

The first public build is `0.1.0-alpha.2`, a prerelease. Its initial Bigme
startup/navigation test was positive; full device OTA acceptance remains open.
Version `0.1.0-alpha.3` is the next preview, using the same OTA bootstrap API 1.
It includes the reviewed upstream merges and shared update-menu labels.
Version `0.1.0-alpha.4` adds the shared book panel, Home shelf modules, scoped
search and settings hub. It also keeps bootstrap API 1 unchanged, so existing
alpha installations can install it through the same preview OTA channel.
Version `0.1.0-alpha.5` includes the reviewed Bookshelf 5.3.1 merge, dock-aware
footer refreshes, shared whole-group navigation and the transparent folder-pager
divider fix. Bootstrap API 1 and the preview update path remain unchanged.
Version `0.1.0-alpha.6` adds the optional Material Symbols Rounded icon pack.
Its font, SVGs and license notices ship in the same verified runtime package;
existing icon choices are retained and bootstrap API 1 remains unchanged.
Version `0.1.0-alpha.7` replaces Material text-font rendering with matching SVGs
after a reported alpha.6 startup crash, and removes the Material whole-pack
preset. Selection is per icon only. It can update directly from alpha.5 or
alpha.6; bootstrap API 1 and the three bootstrap files are unchanged. No
recovery patch is needed on an already-working alpha.5. If the temporary
Material recovery patch was installed, disable/remove it after updating and
restart to make saved Material choices visible again.
Version `0.1.0-alpha.8` fixes the individual Material picker's category-initialization
crash. It retains alpha.7's per-icon SVG selection, existing settings and bootstrap
API 1. The same preview OTA path works directly from alpha.5, alpha.6 or alpha.7.
Version `0.1.0-alpha.9` adds independent Material icon weights of 200/300/400/500,
with 300 as the requested default. Legacy unweighted Material choices become
lighter; explicitly selected weights are retained across OTA slots. Other icon
sources and the bootstrap remain unchanged. It uses the same preview channel
and can be installed directly from alpha.8 or the earlier alpha releases.
Version `0.1.0-alpha.10` adds Solar Outline, Solar Line Duotone and Tabler as
per-icon SVG sources, including the custom manga icon in both Solar styles.
Existing selections and Material weights are unchanged. The stable bootstrap,
API 1 and preview OTA path are unchanged; alpha.9 and earlier alpha releases
can update directly. The new sources are not whole-pack presets.
Version `0.1.0-alpha.11` adds four icons to both Solar sources: Database, Cloud
Download, Download Minimalistic and Library. Existing choices, the stable
bootstrap and API 1 remain unchanged. Alpha.10 and earlier alpha releases can
update directly through the same preview channel.
An alpha installation defaults to including preview releases; a stable installation defaults to stable
only. This is separate from upstream monitoring, which never publishes builds.

## On the reader

Open **Tools > OrbitUI > Uppdatera OrbitUI > Check for updates**. The update entries
inside the embedded components are also named **Uppdatera OrbitUI** and open this
same OrbitUI menu, not their old installers. The label is supplied by the common
updater adapter; retain the components' optional `menuLabel` hooks during merges.
The menu also provides:

- Include preview releases (alpha/beta/rc).
- Optional daily checking when already online, disabled by default. It never
  turns Wi-Fi on and never installs without confirmation. After enabling it,
  checks run on a subsequent startup; manual checking is always available.
- Restore previous OrbitUI version. This changes code only, not reading data.

The updater reads the public GitHub releases API, including prereleases when
enabled. It compares semantic versions, does not downgrade automatically and
requires the exact release assets `orbitui.koplugin.zip` and
`orbitui.koplugin.zip.sha256`. Branch archives are not accepted.

## Installation safety

The first installation is the factory fallback. `main.lua`, `_meta.lua` and
`orbitui_bootstrap.lua` form a stable bootstrap. New code is extracted into an
inactive version directory; it never overwrites the running modules.

1. Download over CA- and hostname-verified HTTPS, restricted to GitHub and its
   release-asset hosts. KOReader's `data/ca-bundle.crt` is preferred; OrbitUI also
   bundles Certifi's Mozilla roots for older installs (license/provenance under
   `assets/`). A missing CA bundle is an error, never a reason to disable TLS.
2. Verify ZIP byte count and SHA-256. Validate safe paths, file types, size limits,
   every file's inventory/hash and Lua syntax. No package code is executed here.
3. Require the package's bootstrap files to match the installed bootstrap and
   its format to use bootstrap API 1. A future incompatible bootstrap change
   must be installed manually rather than silently ignored.
4. Move the verified runtime into `.orbitui-versions/<zip-sha256>/`. It does not
   end in `.koplugin` and cannot be discovered as a second plugin.
5. The main process atomically selects the new version in `.orbitui-active`.
   A cancelled/killed download subprocess cannot activate anything.
6. Restart KOReader. The resolver loads all core and component modules from the
   selected runtime. Old code continues running until this restart.

Downloads, hashing and extraction run under KOReader's Trapper in a subprocess.
UI work is deferred until after Trapper/confirmation callbacks return. ZIPs are
bounded to 64 MiB, expanded contents to 128 MiB and individual files to 32 MiB.
Symlinks, special files, traversal, hidden paths and case-ambiguous duplicates
are rejected. Archive extraction copies bytes rather than filesystem metadata.

The factory installation and previous code remain available. Obsolete inactive
version slots are cleaned during a later update; current and previous slots are
retained. `.orbitui-work` is disposable download/staging space. Allow roughly
100 MiB free for the present package, and more as future packages grow.

## Startup failure and recovery

A pending version writes `.orbitui-booting` before loading its runtime. After
component initialization succeeds, a deferred callback confirms the startup.
If the process exits/crashes before confirmation, the next launch restores the
previous version and reports it. This detects interrupted startup, not every
later UI/device regression; use manual rollback for those.

Manual rollback is available in the update menu. It also cancels a pending
update. If KOReader cannot reach that menu, stop it and rename `.orbitui-active`
to `.orbitui-active.saved` inside **orbitui.koplugin**, then restart. The original
factory code is selected when no active record exists. Do not delete the plugin
or its settings. Reinstalling a new factory ZIP manually also requires removing
or renaming the old activation record while KOReader is stopped.

Activation uses same-filesystem rename and flush/fsync where available. This
does not replace a backup against storage corruption or power-loss behavior
specific to Android's filesystem. The initial settings snapshot is limited;
see `MIGRATION.md`. Rollback never restores older book progress or settings.

## Publishing a reviewed release

Publication always requires an explicit user request. There is no release job
triggered by upstream activity or ordinary pushes. Before publishing:

1. Update `VERSION`; do not change the stable bootstrap casually. Record any
   remaining device gaps and label unaccepted builds as prereleases.
2. Run both Lua test suites, translations, and a clean-commit package build.
   `scripts/package.sh` adds an exact manifest and produces the checksum asset.
3. Create a draft release for the exact reviewed commit/tag and upload both
   assets. Download the assets and verify their checksums before publishing.
4. Publish the draft with the correct prerelease flag. Verify anonymous API and
   asset access, channel selection and installation of the published bytes.
5. Never replace bytes on an existing published tag. Issue a new version for a
   fix; report device checks separately from headless tests.

For an upgrade test from an actual older release, pass its runtime ZIP to
`scripts/smoke-ota.py NEW_ZIP REFERENCE_DIR --base-zip OLD_ZIP` (add `--live`
after publication). This loads the old installer's code from a temporary
installation and tests discovery, validation, activation and code rollback.
It does not run the KOReader UI or alter the user's installation.

The checksum detects inconsistent/truncated packages. It is not an independent
signature: the GitHub account/release and HTTPS trust chain remain trusted.

API references: [KOReader Trapper](https://github.com/koreader/koreader/blob/master/frontend/ui/trapper.lua),
[archive reader](https://github.com/koreader/koreader-base/blob/master/ffi/archiver.lua),
[SHA-256](https://github.com/koreader/koreader-base/blob/master/ffi/sha2.lua).
