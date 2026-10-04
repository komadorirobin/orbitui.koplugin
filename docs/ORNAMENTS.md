# Ornaments

## Author busts

OrbitUI alpha.14 includes two AI-adapted light-plaster busts: James Joyce and
Virginia Woolf. No additional download or manual file installation is required.
The original PNGs keep their generated alpha and provenance metadata.

OrbitUI alpha.17 adds the separate **Authors** pack with nine more busts:
August Strindberg, Stanislaw Lem, Dylan Thomas, Thomas Mann, Fyodor Dostoevsky,
Knut Hamsun, Clarice Lispector, Robert Musil and Franz Kafka. They follow the
same placement rules. No runtime rendering of 3D models, image generation or
network fetch is needed; the artwork is bundled as static transparent PNGs.

## Placement

An enabled bust stands immediately before the first matching book in a
contiguous author run. A run continuing on the next page gets a bust there too.
The same planner reserves the space for pagination and display; row balancing
keeps a bust with its book. If space is scarce, an ordinary row-end ornament
gives way first. The bust shrinks or is omitted rather than overlapping a book.

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
Other ornaments use a session-shuffled native deck and its frequency pattern. On a shelf
with ornaments enabled, the author match takes precedence over that pattern.
**None** disables all ornaments, including author busts. Disabling a piece or
its pack also prevents author matching from selecting it.

## Controls and installation

The pack appears under **Wallpaper, ornaments and colours > Ornament collection
> Modernists**. Tap a bust on a shelf to zoom and read its source information;
long-press for native size, height and padding controls. Shuffle/ordering do not
move an author bust to an unrelated author. The earlier `Modernists-Preview`
trial pieces are matched as well; the released pack wins if both are enabled.
The nine additions appear in the same browser under **Authors**.

The first ornament listing copies the bundled files from the active runtime to
`koreader/settings/bookshelf/ornaments/Modernists/`. A separate install marker
under `settings/orbitui/` prevents a later startup from restoring deleted files.
Existing same-name files and user placement metadata are never overwritten.
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
are not changed. Busts still stand beside their matching authors, never in the
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
- Strindberg: CC BY 4.0, adapted from nicolasdiolez's
  [bronze bust scan](https://zenodo.org/records/10336453).
- Lem: CC BY-SA 4.0, adapted from Pawel Ciesla (Staszek Szybki Jest)'s
  [Kielce bust photograph](https://commons.wikimedia.org/wiki/File:Popiersie_Stanis%C5%82aw_Lem_ssj_20110627.jpg).
- Dylan Thomas: CC BY 4.0 adaptation of AndyScott's CC0
  [photograph of Hugh Oloff de Wet's bust](https://commons.wikimedia.org/wiki/File:Royal_Festival_Hall,_National_Poetry_Library,_bust_of_Dylan_Thomas_by_Hugh_Oloff_de_Wet.jpg).
- Dostoevsky: **CC BY-NC-SA 4.0, non-commercial use only**, adapted from
  [Scan-the-World's gravestone bust](https://zenodo.org/records/21671389).
- Thomas Mann, Hamsun, Lispector, Musil and Kafka: original AI-generated portrait
  interpretations, CC BY 4.0 to the extent applicable. No third-party reference
  image was supplied. They do not reproduce the commercial/museum sculptures
  found during research, and must not be attributed to those sculptors.
- Japan collection: original AI-generated ornaments, CC BY 4.0 to the extent
  applicable. No third-party reference image was supplied. Exact prompts,
  generated-byte hashes and attribution ship in the Japan pack.

Complete attribution, change descriptions and license links ship with the images,
including in the device-side pack. Preserve those notices on redistribution.
These are AI-reinterpreted ornaments, not documentary reproductions or endorsements.
The photo/model source licenses are recorded separately from the adaptations;
they do not imply blanket permission for all uses of underlying sculptures.
Exact prompts, inputs, asset hashes and changes are recorded with each pack.

## Verification

The desktop prototypes were checked on light and dark backgrounds. Headless
tests cover metadata matching, book-adjacent placement, narrow rows, balancing,
27 pagination configurations, on/off behavior, duplicate trial packs and safe
one-time installation. The packaged PNG bytes and notices are also checked.
The pagination test now includes all eleven authors. Additive-pack migration tests
cover alpha.14 upgrades, deleted old/new packs, custom metadata, partial copies
and retries. Asset checks cover all nine new PNGs without changing their bytes.
Japan checks cover all five RGBA files, metadata, safe stock replacement, custom
and legacy-root plants, re-enablement, disabled packs and failed/retried copies
or settings writes. The author-placement tests still cover the unchanged busts.
Session-shuffle tests run the native deck, enabled-pool cache and page-signature
methods, including process restarts, empty/one-piece catalogues, manual changes,
failed shuffles and author placement after shuffling.
The [artwork preview](ornaments-preview.html) uses the production assets on
light, dark and patterned backgrounds; it is not a KOReader emulator.
Rendering and touch behavior still need a physical Bigme B7 Pro test, especially
with custom ornament sizes, narrow landscape rows and background images.
