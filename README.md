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

Version **0.1.0-alpha.46** places physical series-box MAL ratings in a rounded
cover-corner cutout instead of a separate badge. Alpha.45's Kanzenban option
and cached ratings remain, along with alpha.44's natural spine widths,
partial filling and `+N`, complete read/total counts,
aspect-true covers, scoped binding choices, the automatic-cover fix and bounded
image picker. Bookshelf **5.5.2** (`c7a9db2c`) and SimpleUI **2.7.5** (`7eb80f9e`)
remain the reviewed upstream baselines.
The read-total sits in the compact exposed head, above the picture; minimum
box width is 85% of a normal cover, with the existing maximum/space cap.
The requested upstream series-box trial keeps native open-topped slipcases
instead of OrbitUI's old whole-box completion mark/fade. The compact head shows
the aggregate read-total rather than individual member marks.
The old design remains on local branch `design/orbitui-series-boxes`, not as an
in-app switch. Existing Library/Manga profiles, face-out books, per-chip cover
labels/sizes, ornaments,
custom icons and dock/Bento layout are retained. Back up settings before
updating: new grouped-order, ledger and module edits are not mirrored to older
code on rollback. New surface choices are likewise not mirrored to older code.
See [the release notes](docs/releases/0.1.0-alpha.46.md)
and [the merge log](docs/MERGE_LOG.md) for retained behavior and testing.
KOReader v2025.08 or newer is required. Storage paths remain rollback-compatible;
OrbitUI does not run Bookshelf 5.3's automatic file move.

Tankobon is replaced by **Kanzenban / large format**.
It uses Paperback's cover-derived colours and thin boards, about 12% taller
where shelf space permits. Covers retain their proportions, and page-derived
spine widths do not grow. Saved Tankobon choices display as Paperback without
rewriting those preferences; existing Paperback/Hardcover choices are unchanged.

Physical series boxes show the linked MyAnimeList community rating (for example
`★8.72`) directly on the board in a rounded cutout at the cover's upper-left.
It uses the same cached provider and font scale as folder cards, not a personal
score or a new network request, with the box's own text colour. Only that small
corner is masked; cover size and proportions are unchanged. Read/total and `+N`
stay above the cover, with the series name below. The cutout follows the text's
width and disappears with the rating. Unlinked/unrated series have no cutout;
exceptionally small covers omit it instead of clipping text. Folder-card badges
keep their existing appearance.

Unpublished follow-up: long-press a shelf chip > **Series box title** >
**On the cover (bottom)** to put series names on an opaque, box-coloured plate
inside the image. This reclaims the separate title strip for the full,
aspect-preserved cover and aligns it with the bottom inset. The choice is
independent per shelf in Library/Manga; **Below the cover (default)** restores
the previous layout. It does not change individual-book captions or folder cards.

Long-press a shelf chip > **Book binding** to choose Hardcover, Paperback or
Kanzenban / large format. Long-press a series box > **Book binding** for an override
that follows that series across shelves, or choose **Follow shelf** to clear it.
Untouched shelves retain Hardcover. Choices affect physical books and box
member spines, not book metadata, cover-grid/list views or reading progress.

Unpublished Home option: **OrbitUI settings > Reading dashboard > Show dashboard
as first Home page** adds a BookOrbit-inspired card layout without replacing
any existing pages. It combines a larger continue-reading card, daily/week/streak
statistics, three in-progress books, the existing reading goal, and three-cover
BookOrbit Want to Read / Recently added rows. Arrows page those rows independently.
Tap books to open, hold them for the existing book panel; tap the goal/statistics
cards for their settings. The dark hero can be switched off. Disabling the page
preserves edits to other pages and never resets data, wallpaper or dock choices.
The existing Hardcover goal is used when that module is enabled, otherwise the
local annual KOReader goal. This is a local-book view, not a new BookOrbit sync
client: unavailable remote covers/books are not downloaded, no library totals
are invented, and no pet/remote-download feature is copied from the reference.

Box members pack left at natural widths, up to eight visible volumes; `+N`
counts additional local volumes not drawn, not missing or unread books.
Unknown or reader-layout-dependent page counts use a neutral thickness.
Binding labels use Swedish when selected in KOReader and English otherwise.

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
Alpha.11 adds Database, Cloud Download, Download Minimalistic and Library in
both Solar styles, bringing each selection to 80 icons. Selection remains
per-icon only; no existing choice is replaced.

Alpha.14 bundles James Joyce and Virginia Woolf busts in the **Modernists**
ornament pack. They stand next to books by the matching author, not randomly
among other books. Installation is automatic on first opening the shelf or
ornament collection after updating; existing settings/files are preserved.
See [author ornaments](docs/ORNAMENTS.md) for matching, controls and artwork licenses.
Alpha.17 also includes the **Authors** pack: Strindberg, Lem, Dylan
Thomas, Thomas Mann, Dostoevsky, Hamsun, Lispector, Musil and Kafka. It installs
independently without replacing Modernists artwork or user adjustments.
Alpha.22: the generated Lispector portrait is retired. Only the exact old
default is removed on upgrade; custom replacements and settings stay intact.
The Authors pack now contains eight busts. No Rio replacement is bundled yet.
The new **Authors II** pack adds photographic Svevo and Hemingway ornaments.

Alpha.19: **Ukiyo-e Gallery** adds 27 genuine CC0 museum prints in original
frames, native zoom/info cards and an optional washi/Hinoki-style theme. No
existing theme is activated or replaced. See [the gallery preview](docs/ukiyoe-gallery-preview.html)
and [installation/source notes](docs/ORNAMENTS.md#ukiyo-e-gallery-alpha19).

Alpha.20 gallery correction: frames hang above the plank rather than stand
on it. Expanded Swedish, source-linked commentary and museum measurements replace
the short visual notes. A guarded metadata upgrade reaches existing alpha.19
installations without replacing artwork, user captions or manual positioning.

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

The Modernists artwork is separately licensed: Joyce under CC BY-SA 4.0 and
Woolf under **CC BY-NC-SA 4.0 (non-commercial only)**. The AGPL code license
does not grant additional rights to those images. Sources, adaptations and
license links accompany the assets in `assets/ornaments/Modernists/ATTRIBUTION.txt`.
The additional Authors collection has its own per-image notices in
`assets/ornaments/Authors/ATTRIBUTION.txt`: Lem is CC BY-SA 4.0, Dostoevsky is
**CC BY-NC-SA 4.0 (non-commercial only)**, and the other six are CC BY 4.0
to the extent applicable. Original portrait interpretations are distinguished
from adaptations of source photographs or scans.

Ukiyo-e Gallery uses individually verified CC0 museum images, with independent
frames/AI-assisted Swedish commentary and separately identified AI-generated material
textures. Its provenance and credits are in
`assets/ornaments/Ukiyo-e Gallery/ATTRIBUTION.txt` and `provenance.json`.
No assets or descriptions from a paid ornament pack are redistributed.
