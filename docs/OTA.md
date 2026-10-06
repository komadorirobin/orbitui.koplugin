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
Version `0.1.0-alpha.12` faces every book cover-forward in the shelf/spines
style, including existing Library and Manga shelves. Native pagination handles
the wider covers; saved orientation preferences remain intact for rollback.
The stable bootstrap and API 1 are unchanged. Alpha.11 and earlier alpha
releases can update directly through the same preview channel.
Version `0.1.0-alpha.13` corrects bookcase height allocation to exclude the
persistent dock and reserve the visible pagination controls. Cover-forward
shelves and saved layout preferences are retained. The stable bootstrap and
API 1 are unchanged. Alpha.12 and earlier alpha releases can update directly
through the same preview channel; restart KOReader after installation.
Version `0.1.0-alpha.14` bundles the Modernists author ornaments and adds
book-adjacent author matching. The pack is seeded once from the active runtime;
user artwork and settings are not overwritten. Bootstrap API 1 is unchanged,
and alpha.13 or earlier alpha releases can update directly. Code rollback keeps
the installed images, but older runtimes do not apply the new author matching.
An alpha installation defaults to including preview releases; a stable installation defaults to stable
only. This is separate from upstream monitoring, which never publishes builds.

Version `0.1.0-alpha.17` adds nine more author busts, five colour Japan ornaments,
alphabetical series blocks on bookcases and a once-per-start ordinary-ornament
shuffle. These changes were absent from the alpha.16 runtime despite its release
notes. Alpha.17 preserves the intervening history rather than replacing published
assets. Alpha.16 and earlier alpha installations can update directly with the
same bootstrap/API 1. New artwork is copied once without overwriting user files.
Only byte-identical stock plants are disabled once, reversibly; other enablement
and frequency settings remain unchanged. Rollback retains artwork and settings:
disable Authors on alpha.16 or earlier to prevent unrelated-author placement.
See `ORNAMENTS.md` for startup shuffle behavior and the original plants' controls.

Version `0.1.0-alpha.18` fixes independent Bento top margins, limits ordinary
ornaments to one per shelf row (with multiple matched author busts allowed),
and includes the reviewed Bookshelf/SimpleUI merge documented in `MERGE_LOG.md`.
Columns now align to the row's top rather than vertically centring one another;
saved margins are retained and can be adjusted individually. Alpha.17 and
earlier alpha releases can update directly through the same preview channel.
No bootstrap/API change, new artwork, settings migration or reading-data change.

Version `0.1.0-alpha.19` bundles the independent Ukiyo-e Gallery: 27 museum
prints, native zoom/info cards and an optional washi/Hinoki-style shelf theme.
The new pack is seeded once, additively, including its nested theme files.
Existing artwork, settings and reading data are preserved; no theme is
automatically activated. Alpha.18 and earlier alpha releases can update
directly with the same stable bootstrap/API 1. Code rollback retains installed
artwork. The optional standalone gallery ZIP is not required for an OTA update.

Version `0.1.0-alpha.20` raises untouched gallery frames above the shelf and
adds richer source-linked Swedish commentary and museum measurements. A narrow
metadata upgrade preserves custom captions, manual positioning and deleted
ornaments. It also includes the reviewed SimpleUI merge and a layout-snapshot
fix that preserves clock visibility while correctly handling added/removed
modules. Alpha.19 and earlier alpha releases can update directly with the same
bootstrap/API 1. No theme, reading-data or sync setting changes. Code rollback
retains the updated ornament metadata as well as artwork.

Version `0.1.0-alpha.21` increases the gallery's default wall clearance, adds
Swedish author biographies to the eleven busts and replaces the default Kafka
image with the licensed Kielce bronze adaptation. Narrow, independently marked
updates preserve custom artwork, captions, positioning, native overrides and
deletions. Alpha.20 and earlier releases can update directly using the same
bootstrap/API 1 and preview channel. Code rollback retains updated artwork,
credits and captions; it does not restore the old Kafka image.

Version `0.1.0-alpha.22` replaces seven stock author ornaments with photographic
cutouts and adds Svevo/Hemingway in the independent Authors II pack. It removes
only the exact generated Lispector default. Image-aware migrations preserve
custom/deleted/linked artwork, captions, manual positioning and native overrides.
Alpha.21 and earlier alpha releases can update directly through the same preview
channel and bootstrap/API 1. Code rollback retains copied artwork and metadata;
it does not resurrect removed images or restore earlier ornament versions.

Version `0.1.0-alpha.23` improves Hemingway's visible size and level base crop,
and gives Mann a compact mounting block without the wide plate. Independent
checksum-guarded migrations update the known defaults even when alpha.22's
installation markers are complete. Custom images, captions, placements, native
overrides, links and deletions are preserved. Alpha.22 and earlier alpha releases
can update directly using the same preview channel and unchanged bootstrap/API 1.
Code rollback retains the refined artwork and metadata.

Version `0.1.0-alpha.24` replaces Mann with the frontal Pauline Ahrens photograph,
masked without generative redrawing. Its independent v4 migration recognizes
exact prior defaults, including alpha.23, even after older update markers were
completed. Custom/deleted/linked artwork, edited captions, native placements
and settings remain untouched. Other ornaments and the bootstrap/API 1 are
unchanged. Alpha.23 and earlier alpha releases can update directly through the
preview channel. Code rollback retains the new image and updated credits.

Version `0.1.0-alpha.25` adds per-chip cover sizing in the physical shelf view
and fixes bottom-bar margin refreshes in Home and Library/Manga. Existing cover
sizes remain at 100% until changed. Alpha.24 and earlier alpha releases can
update directly through the same preview channel and unchanged bootstrap/API 1.
No artwork migration, upstream merge or reading-data change. Code rollback
retains the new size preferences, which older runtimes ignore.

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
250 MiB free for the current package's download, staging and one-time artwork
installation, in addition to existing installed versions. Allow more as future
packages grow.

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
