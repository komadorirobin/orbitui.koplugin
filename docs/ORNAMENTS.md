# Ornaments

## Ukiyo-e Gallery (alpha.19)

The independent **Ukiyo-e Gallery** pack contains 27 actual Japanese woodblock
prints: Hokusai (8), Hiroshige (12), Utamaro (3), Sharaku (2) and Kuniyoshi (2).
Each object's image is explicitly CC0 in the Cleveland Museum of Art API or
public domain in The Met API under its CC0 Open Access policy. Individual
source URLs, rights evidence, credits and SHA-256 hashes accompany the pack.
This is not AndyHazz's Ko-fi collection; no paid-pack files or descriptions
were used. The selection, frames and Swedish commentaries are independent.

The museum art is only reduced proportionally with LANCZOS, preserving the
complete image, colour and orientation. No cropping, quantization, recolouring
or AI reinterpretation. Warm dark frames have a light mat, subtle bevel and
transparent exterior. The unreleased height correction raises frames by 20%
of the shelf's stand height from the books' foot line. Alpha.20's 12% lift
could still touch the plank's receding top surface; alpha.19 used zero lift.
The new placement clears that surface without resizing the pictures. Native tap to
zoom shows title, artist, date, measurements, commentary, museum credit and sources. Artwork
does not mirror or invert at night. Only the washi/wood **material textures**
are AI-generated images; prompts and original source-image hashes are supplied.

Alpha.19's short visual notes were written for OrbitUI, not copied from museum
wall labels. Alpha.20's expanded Swedish texts are AI-assisted editorial
summaries of museum catalogue/curatorial sources, explicitly labelled as such.
They are not direct translations or museum-authored Swedish texts. Cards link
all their sources and retain uncertainties in the museum's interpretations.
Additional sources sometimes discuss a related work or another impression;
dimensions, date and credit always come from the pictured object's own record.
The editable source text lives in `scripts/artwork/ukiyoe-context.json`.

The pack also contains one quiet washi wallpaper and a named Hinoki-style plank
using Bookshelf's native three-band, 80/20 surface/face template. The repeated
wood tile has matching edges and needs no end caps. There are no global colour
overrides. Installation does not activate a theme or modify existing choices.

- **Ornament collection > Ukiyo-e Gallery** controls individual prints.
- **Shelf theme > Ukiyo-e Gallery** activates the full theme, using its
  ornaments in place of the other packs, per upstream theme behavior.
- To retain the author busts and other ornaments, select the pack's wallpaper
  and **Shelf plank > Hinoki** independently rather than choosing a full theme.

Frames use the same session shuffle, one-ordinary-piece-per-row cap and author
bust priority as other ordinary ornaments. Nested theme files are seeded once
to `koreader/settings/bookshelf/ornaments/Ukiyo-e Gallery/`, with their own
`ornament-ukiyoe-gallery-v1.installed` marker. Copies are additive and atomic;
initial copies do not overwrite existing files, completed installs do not restore deletions,
and a failure cannot crash the browser or commit an incomplete installation.

The wall/info correction adds the independent `ornament-ukiyoe-gallery-v2.updated`
marker. It compares installed metadata against a frozen alpha.19 baseline and
changes only untouched `lift` and `info` fields. Explicit reader height, anchor
or size adjustments prevent automatic repositioning; pack size/anchor edits do
too. The reader's own settings file is never written. Deleted entries, images
and packs stay deleted. Default notices/provenance update only if byte-identical
to their old versions; edited copies survive. Writes are atomic and interrupted
upgrades retry on the next process. Image bytes, active themes and author-bust
placement remain unchanged.

The subsequent height correction uses `ornament-ukiyoe-gallery-v3.updated` so
it also reaches alpha.20 installs that already completed v2. Only recognized
12% placement defaults move to 20%; the v2 pass still handles direct alpha.19
upgrades. An existing v2 marker prevents replaying its info/zero-lift update.
The compact alpha.20 baseline records placement fields and the old README;
only an unedited README follows the new defaults. The same explicit reader
and pack-position exclusions apply, including a saved zero-height override.
No PNGs, info cards, themes or other ornaments change in v3.

### Rebuilding and verifying

`scripts/build-ukiyoe.py` is maintainer-only (Pillow required). Network access is
opt-in; never fetch or generate art on a reader. Source images/records go to an
external cache, and are SHA-256 checked on subsequent builds. If a museum
changes bytes or metadata, stop and review the provenance change explicitly.
Generated material originals live under `scripts/artwork/` and are excluded
from release archives, as is the build script.

```sh
python3 scripts/build-ukiyoe.py --cache /tmp/orbitui-ukiyoe-sources --fetch --washi scripts/artwork/ukiyoe-washi.png --hinoki scripts/artwork/ukiyoe-hinoki.png
UKIYOE_SOURCE_CACHE=/tmp/orbitui-ukiyoe-sources python3 -m unittest discover -s tests -p test_ukiyoe_assets.py -v
```

Omit `--fetch` for an offline, cache-only rebuild. See the [gallery preview](ukiyoe-gallery-preview.html)
and colour/grayscale contact sheets generated in `dist/`. The source-cache
audit compares the art rectangle of all 27 shipped PNGs pixel-for-pixel against
the proportionally scaled museum originals. Theme/seeding tests execute the
native theme scanner and installation failure paths. Desktop previews and
grayscale conversion are not a native KOReader or physical e-ink test.

Device acceptance still required: check colour/grayscale clarity, the visible
wall gap at several shelf sizes, tall/wide
frame placement, tap-to-zoom and info scrolling, native theme/individual-part
selection, author-bust priority, paging/restart stability and upgrades retaining
customized or deleted artwork. The single-pack install ZIP, if used manually,
must contain **Ukiyo-e Gallery**, not the unrelated Halloween folder name.

## Author busts

OrbitUI alpha.14 includes two AI-adapted light-plaster busts: James Joyce and
Virginia Woolf. No additional download or manual file installation is required.
The original PNGs keep their generated alpha and provenance metadata.

OrbitUI alpha.17 adds the separate **Authors** pack with nine more busts:
August Strindberg, Stanislaw Lem, Dylan Thomas, Thomas Mann, Fyodor Dostoevsky,
Knut Hamsun, Clarice Lispector, Robert Musil and Franz Kafka. They follow the
same placement rules. No runtime rendering of 3D models, image generation or
network fetch is needed; the artwork is bundled as static transparent PNGs.

### Lispector portrait retired (unreleased)

The user requested removal of the original generated Lispector portrait. The
current Authors pack contains eight busts, ten together with Modernists. Remove
the old PNG from the runtime, pack metadata, provenance list and visual preview;
do not bundle the separate Rio proposal while its sculpture rights remain unclear.
Keep her researched biography source and the frozen historical migration baselines.

`core/orbitui_lispector_retirement.lua` runs before the first native listing.
It removes only the SHA-256-matching published PNG in the canonical Authors pack.
Custom replacements, symlinks, other packs, existing metadata, notices, placement
and enablement settings remain untouched. The canonical author binding remains
available to reader-supplied artwork. The generic biography updater skips the
retired entry rather than requiring a new default caption or changing its credits.
Deletion or marker failures retry; a completed marker avoids further image hashing.
No seed marker is reset and deleted artwork is never reinstalled by this version.
Rolling back code does not restore the retired image. Device verification of the
old default disappearing and custom artwork remaining is still required.

## Placement

**At most one ordinary ornament per physical shelf row. Author busts are an
exception:** two, three or more may share a row when their matching books fit
there. A row with busts does not receive an additional ordinary decoration.
This is automatic in OrbitUI, not an additional setting. Busts are never placed
beside unrelated books or moved to an empty shelf.

An enabled bust stands immediately before the first matching book in a
contiguous author run. A run continuing on the next page is eligible again.
The same planner reserves the space for pagination and
display; row balancing keeps busts with their books, permits several author
pieces together, and cannot add ordinary decorations to that row. Selected
busts replace the ordinary row-end reservation before filling books, rather
than leaving hidden blank space. The bust shrinks
or is omitted rather than overlapping a book.

Matching uses existing book author metadata, not titles, filenames or a guess
based on the open folder. Supported full names include `James Joyce`,
`Joyce, James`, `Virginia Woolf`, `Woolf, Virginia` and Adeline Virginia Woolf.
Matching ignores case and extra whitespace and also accepts author arrays.
The additional authors accept both first-name-first and surname-first forms.
Lem accepts the Polish L-with-stroke (including uppercase) and ASCII spelling.
Dostoevsky also accepts Swedish `Fjodor Dostojevskij` and common English
`Dostoyevsky` forms, with supported middle names. No surname-only match is made:
Thomas Mann must not be confused with Heinrich Mann or Klaus Mann.
Kafka matches `Franz Kafka` and `Kafka, Franz`, never a bare surname or a
title mention.
Missing/ambiguous metadata does not match. A multi-book folder tile is not
attributed to the author of its representative cover.

These pieces never enter the general ornament rotation or decorate bare shelves.
Other ornaments use a session-shuffled native deck and its frequency pattern,
limited to one ordinary slot per row. Bare shelves also have at most one piece.
On a shelf with ornaments enabled, the author match takes precedence over that pattern.
**None** disables all ornaments, including author busts. Disabling a piece or
its pack also prevents author matching from selecting it.

## Controls and installation

The pack appears under **Wallpaper, ornaments and colours > Ornament collection
> Modernists**. Tap a bust on a shelf to zoom and read about the author;
long-press for native size, height and padding controls. Shuffle/ordering do not
move an author bust to an unrelated author. The earlier `Modernists-Preview`
trial pieces are matched as well; the released pack wins if both are enabled.
The eight remaining additions appear in the same browser under **Authors**.

The first ornament listing copies the bundled files from the active runtime to
`koreader/settings/bookshelf/ornaments/Modernists/`. A separate install marker
under `settings/orbitui/` prevents a later startup from restoring deleted files.
Initial seeding never overwrites same-name files or user placement metadata.
An interrupted initial copy can retry on the next start; an installation error
is logged without aborting the browser or KOReader startup.
`Authors/` is installed alongside `Modernists/`, with its own install marker.
An alpha.14 upgrade does not recopy the old pack, merge or rewrite its metadata,
change on/off settings, or restore a deleted old pack. A partially installed
new pack is retried independently of the completed old pack.

Future artwork revisions must use a reviewed migration or new names rather than
silently replacing edited files. Code rollback retains these user-side assets:
versions before alpha.14 do not know author matching, so disable the Modernists
pack when rolling back if random placement is unwanted.
Disable **Authors** when rolling back to alpha.16 or earlier, since those
versions do not know the nine new author-bound filenames.

### Author information (unreleased)

All ten remaining bundled busts have Swedish introductions to the author's life,
literary style, themes and major works. Tap a bust for the existing enlarged
image and scrollable info card. Source links follow the biography, with the
image credits and artwork licences at the bottom (unchanged except for the
explicitly requested image replacements described below).
The text is available offline; opening its source websites requires a browser
and network. These are labelled AI-assisted OrbitUI summaries, not verbatim
museum/author-centre/publisher text or statements from the original sculptors.

Maintain the copy in `scripts/artwork/author-biographies.json` and regenerate
pack metadata with `python3 scripts/build-author-info.py`. No image is processed.
Every complete card fits the native 4000-byte UTF-8 limit, including credits.

Existing installations receive a one-time, info-only default update before the
first native ornament listing. The frozen alpha.20 baseline allows replacing
only byte-identical old captions and READMEs. Custom captions (including empty
or removed info), reader overrides, positions, disabled pieces, deleted files
and the Modernists-Preview trial pack stay intact. No prompts, attribution
notices, image bytes or enablement settings change. Each pack has an independent
update marker, written only after successful atomic writes. Interrupted updates
retry at the next process start. Rolling back code retains the new captions.

### Kafka in Kielce (unreleased)

The user selected the real bronze bust by Anna Wierzchowska-Grabiwoda (2005)
in Kielce. `Authors/Franz Kafka.png` now uses an AI-assisted cutout of
[Pawel Ciesla's photograph](https://commons.wikimedia.org/wiki/File:Popiersie_Franz_Kafka_ssj_20060914.jpg),
retaining bronze colour, bowler hat and rough sculptural modelling instead of
the old invented ivory portrait. This is not a pixel-identical photo extraction;
the generated PNG retains its original alpha/provenance. The photograph and
adaptation are CC BY-SA 4.0. `KAFKA-KIELCE.txt` identifies the sculptor, distinguishes
the photo license from the sculpture rights, and records the Polish freedom of
panorama basis and limits. It is not a worldwide rights-clearance statement.

The filename, author match and author biography stay stable. The native base
offset changes only to compensate for the new image's transparent bottom margin.
`core/orbitui_kafka_update.lua` runs before the generic biography updater, which
deliberately skips Kafka. It replaces only the SHA-256-recognized old default;
the new hash permits retry after a partially completed update. Custom/deleted
images and deleted metadata records are untouched. Recognized captions and
unedited shared notices follow the new image; an additional license notice
is installed without replacing reader annotations. Custom placement, captions,
native overrides and enablement remain authoritative. The separate completed
marker avoids image hashing on subsequent starts. No upstream code changes.

Maintain source/provenance/prompt in `scripts/artwork/kafka-kielce.json` and
regenerate metadata with the existing author-info builder. The frozen
`assets/ornament-updates/kafka-kielce-v1.json` records both alpha.20 and the
unpublished old biography, never a duplicate of the old bitmap.

### Thomas Mann / Gustav Seitz (Molgreen photograph, unreleased)

The user approved Molgreen's 11 April 2024 Wikimedia photograph of Seitz's
Berlin bronze. The current cutout preserves original photo pixels, colour,
head/neck and the visible bronze mounting block/plinth. Only surroundings and
the separate granite column are masked away; scaling is proportional. It is
not an AI redraw. The Swedish biography, author matching and native zoom remain.

Source, mask, output hashes and credits are in `scripts/artwork/mann-seitz.json`.
Reproduce with `build-sculpture-cutouts.py --spec scripts/artwork/mann-photo-cutout.json
--sources <photo-cache> --output <out>`, then `build-mann-photo.py --cutouts <out>`
and `build-author-info.py`. Reviewed masks avoid a runtime/image-generation cost.

Photo and adaptation: CC BY-SA 4.0. The sculpture's separate documented basis
is German UrhG section 59 (permanent public art), with sections 62 and 63 for
alterations and attribution. No sculpture-rights waiver or Foundation approval
is claimed. `THOMAS-MANN-SEITZ.txt` records the exact scope and sources.
**The retired Ahrens/image_gen bitmap remains held, including in unpublished
Git history. Do not push ancestors containing it.** This replacement does not
clear that older adaptation. Keep a local backup and prepare a public history
without the held bitmap before publishing; no history is rewritten here.

`core/orbitui_mann_update.lua` now uses the independent `mann-photo-v2` marker
and frozen baseline. It recognizes both the original published generated PNG
and the earlier local Seitz cutout, including a completed v1 marker. Known
captions, full default placement triples and unchanged notices are upgraded;
custom/deleted/linked artwork, captions, reader overrides and other busts survive.
Retries recognize the new hash; completed starts do not rehash. Rollback keeps
the image, and the old updater ignores its unknown new hash. No upstream,
version, push, tag or OTA change is part of this replacement.

### Six photographic replacements (local, unreleased)

The user approved replacing Strindberg, Hamsun, Dostoevsky, Dylan Thomas, Lem
and Musil. Musil uses Bernard Bavaud's Geneva bronze from the user-selected
Commons photo, not Wotruba/Belvedere. See [research notes](AUTHOR_SCULPTURE_RESEARCH.md).
Their images now use masked original photographs, not AI redraws. Actual
surfaces, colours and silhouettes are retained; Hamsun remains monochrome.

`scripts/build-sculpture-cutouts.py --sources <photo-cache> --output <out>` uses
the checked-in alpha masks. Pillow is needed; `--refine` also requires NumPy and
OpenCV and requires fresh edge review. The reviewed masks used Pillow 12.3.0,
NumPy 2.5.3 and opencv-python-headless 5.0.0.93. `--previews` writes light/dark QA
images. Source URLs/hashes and final hashes live in `scripts/artwork/author-sculptures.json`.
Only resulting RGBA files and notices enter the runtime; no online processing.

The checksum-guarded `orbitui_sculpture_updates` batch runs after Mann and before
generic biographies. It preserves custom/deleted/linked images, captions,
native overrides and nondefault placement; partial updates resume from either
old or new image hashes. A completion marker prevents repeat startup hashing.
Biographies, author matching and tap-to-zoom stay unchanged. The old NC-derived
Dostoevsky file is replaced with an independent BY-SA photograph, not relicensed.
Those six replacements left Joyce, Woolf, Kafka and Mann unchanged. Mann was
subsequently replaced separately with the Molgreen photograph described above.

## Session shuffle (alpha.17)

Ordinary ornaments are automatically shuffled once per KOReader process, at the
first nonempty ornament listing. Bundled packs are installed and the full
catalogue is reconciled before shuffling, so newly installed pieces participate.
This happens before page-layout signatures are captured: page planning and
rendering use the same order, without moving pieces on the next repaint.

Paging, switching prose/manga, returning from a book, cache refreshes and normal
suspend/resume do not shuffle again. Closing and restarting KOReader does;
an Android process restart after background termination also counts as a new
start. Empty/unavailable catalogues defer until a nonempty listing. A failed
shuffle is logged once and skipped for that session, not retried on every paint.

Long-press an ornament and choose **Shuffle all** to mix again immediately.
Manual swaps and Earlier/Later moves remain in force for the current session,
then the next restart randomizes the order again. Newly added mid-session pieces
use the native New ornaments first/last preference until the next shuffle.
Disabled pieces/packs, frequencies, scale/position metadata and author matching
are not rewritten. Placement is subject to the ordinary-ornament row limit.
Busts still stand beside their matching authors, never in the
ordinary rotation. This is an OrbitUI adapter policy, not an upstream source edit.

Device check: compare a page before/after paging away and back, closing a book,
switching profiles and waking from sleep; its ordinary ornaments should stay
stable. Restart KOReader and check the newly shuffled order, then verify manual
Shuffle all, disabled pieces and Joyce/Woolf adjacency. A one-piece pool cannot
show a different order; a random shuffle may also repeat a previous permutation.

## Japan collection (alpha.17)

The **Japan** pack adds five original, transparent colour ornaments: a green
pine bonsai in a jade pot, a red maple bonsai in an indigo pot, a sleeping calico
cat, a maneki-neko and a red daruma. They use the ordinary ornament rotation,
not author matching. The frequency, profile preferences and all busts
remain unchanged. **None** still hides every ornament.

On first installation, the user's requested replacement turns off only exact
copies of the two native stock plants, `cactus.svg` and `template.svg`. Their
files are not deleted. Custom drawings with the same names, other packs and
existing disabled entries are preserved. An already disabled Japan pack does
not switch off the old plants. The change is recorded separately from the
artwork installation, so a failed settings save can retry without recopying art.

Find the pack under **Wallpaper, ornaments and colours > Ornament collection
> Japan**. Each piece can be disabled, resized or moved with native controls;
the original plants can be re-enabled there too, including after a rollback.
That choice survives later startups. PNG colours stay intact in night mode
(`night: off`); no greyscale conversion or new rendering pipeline is introduced.

Files are seeded additively to `koreader/settings/bookshelf/ornaments/Japan/`,
using `ornament-japan-v1.installed` and `ornament-japan-defaults-v1.applied` in
`settings/orbitui/`. Existing artwork and metadata are not overwritten; completed
installs never resurrect deleted pieces. No runtime network request or image
generation is involved. Modernists, Authors and Japan all use the same atomic
copy helper, but each retains its independent install marker.

The [Japan artwork preview](japan-ornaments-preview.html) uses the production
images and placement defaults with light/dark, patterned and smaller-size
controls. This preview could not be browser-rendered in the current environment.
The PNGs and real alpha were inspected directly; physical colour-e-ink rendering,
shelf contact when width-constrained, and touch behavior still need device testing.

## Artwork licenses

The images are separate from OrbitUI's AGPL-licensed software. They are a
collection of separately licensed adaptations, not one combined derivative.

- Joyce: CC BY-SA 4.0, based on Illustratedjc's photograph of Marjorie
  Fitzgibbon's bust. [Source](https://commons.wikimedia.org/wiki/File:Marjorie_Fitzgibbon_-_Bust_of_James_Joyce_(1982)_closer.jpg).
- Woolf: **CC BY-NC-SA 4.0, non-commercial use only**, based on Scan-the-World's
  bust views. [Source](https://doi.org/10.5281/zenodo.20236358).
- Strindberg: Gotogo's CC0 photograph of Carl Eldh's bronze at Waldemarsudde.
  [Source](https://commons.wikimedia.org/wiki/File:Portrait_bust_of_August_Strindberg_by_Carl_Eldh.jpg).
- Lem: CC BY-SA 4.0, adapted from Pawel Ciesla (Staszek Szybki Jest)'s
  [Kielce bust photograph](https://commons.wikimedia.org/wiki/File:Popiersie_Stanis%C5%82aw_Lem_ssj_20110627.jpg).
- Dylan Thomas: masked AndyScott CC0
  [photograph of Hugh Oloff de Wet's bust](https://commons.wikimedia.org/wiki/File:Royal_Festival_Hall,_National_Poetry_Library,_bust_of_Dylan_Thomas_by_Hugh_Oloff_de_Wet.jpg).
- Dostoevsky: CC BY-SA 3.0, Paramecium's photograph of Laveretsky's grave bust.
  [Source](https://commons.wikimedia.org/wiki/File:Grab_Dostojewskys.jpg).
- Hamsun: Frolich's plaster, photograph distributed by SNL as Public domain;
  Nasjonalmuseet credits Annar Bjorgli. [Source](https://snl.no/Fin_Haakon_Fr%C3%B8lich).
- Musil: CC BY 3.0 photograph by Fanny Schertzer, crop by Lewenstein, of Bavaud's
  Geneva bronze. [Source](https://commons.wikimedia.org/wiki/File:Robert_Musil_-_Cimetiere_des_Rois_II.jpg).
- Thomas Mann: Molgreen's CC BY-SA 4.0 photograph of Seitz's Berlin bronze,
  masked without generative changes; separate German panorama basis above.
- Kafka: the CC BY-SA 4.0 Kielce photo adaptation described above, not the retired
  invented ivory portrait. Lispector's old portrait is no longer bundled.
- Japan collection: original AI-generated ornaments, CC BY 4.0 to the extent
  applicable. No third-party reference image was supplied. Exact prompts,
  generated-byte hashes and attribution ship in the Japan pack.

Complete attribution, change descriptions and license links ship with the images,
including in the device-side pack. Preserve those notices on redistribution.
Six Authors images are photographic masks; the others retain their documented
AI-assisted provenance. None implies endorsement.
The photo/model source licenses are recorded separately from the adaptations;
they do not imply blanket permission for all uses of underlying sculptures.
Exact prompts, inputs, asset hashes and changes are recorded with each pack.

## Verification

### Additional photographic authors (local, unreleased)

`Authors II` adds Giovanni Mayer's Italo Svevo bust in Trieste and Fernando
Boada's Ernest Hemingway bust in Cojimar. The pack seeds once, independently
of Authors/Modernists, without resetting settings or resurrecting older packs.
Hemingway also matches Ernest Miller Hemingway; Svevo matches Ettore Schmitz
and the documented full-name variants. Both use the existing matching and
multi-author row behavior, native zoom and Swedish author information cards.

Svevo's photo is by Amrei-Marie (CC BY-SA 4.0); Hemingway's is Carol M.
Highsmith's Library of Congress image LC-DIG-highsm-06293 (not the distant
06294 view). The masks preserve colour and photographic texture. Source
photographs remain outside the repo/runtime. Rebuild from those sources with:

```sh
python3 scripts/build-sculpture-cutouts.py --spec scripts/artwork/sculpture-additions.json \
  --sources /path/to/sculpture-research --output /path/to/sculpture-additions
python3 scripts/build-author-additions.py --cutouts /path/to/sculpture-additions
```

Committed masks avoid needing OpenCV unless deliberately regenerating them
with `--refine`. The card builder also runs without arguments to regenerate
metadata/notices from committed provenance. It never changes historical packs
or migration baselines. Per-photo and separate sculpture-rights notes are in
the pack's `ATTRIBUTION.txt`; public redistribution review is still needed.
Dazai's Ashino Park statue is confirmed, but no suitably licensed photo has
been selected. No placeholder or generated substitute is installed.

### Checks

The desktop prototypes were checked on light and dark backgrounds. Headless
tests cover metadata matching, book-adjacent placement, narrow rows, balancing,
27 pagination configurations, on/off behavior, duplicate trial packs and safe
one-time installation. The packaged PNG bytes and notices are also checked.
The pagination test includes the ten bundled authors and custom Lispector replacements. Additive-pack migration tests
cover alpha.14 upgrades, deleted old/new packs, custom metadata, partial copies
and retries. Asset checks cover all eight remaining Authors PNGs without changing their bytes.
Japan checks cover all five RGBA files, metadata, safe stock replacement, custom
and legacy-root plants, re-enablement, disabled packs and failed/retried copies
or settings writes. The author-placement tests still cover the unchanged artwork
and matching. The row-limit tests include two/three authors sharing a row, ordinary group gaps
versus row ends, empty and squeezed rows, unchanged standalone defaults and the
native balancer. The 27 pagination configurations also compare saved deck state,
row-end placements and balanced output. Physical device check: inspect a shelf
with several matching authors, an ordinary series/group shelf and the final
partly empty page in portrait and landscape. Ordinary rows have zero or one
decoration; author rows may have several correctly matched busts but no ordinary
piece. Check again after paging away/back; books remain above the dock.
Session-shuffle tests run the native deck, enabled-pool cache and page-signature
methods, including process restarts, empty/one-piece catalogues, manual changes,
failed shuffles and author placement after shuffling.
The [artwork preview](ornaments-preview.html) uses the production assets on
light, dark and patterned backgrounds; it is not a KOReader emulator.
Rendering and touch behavior still need a physical Bigme B7 Pro test, especially
with custom ornament sizes, narrow landscape rows and background images.
