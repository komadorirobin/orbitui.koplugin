# Author ornaments

OrbitUI alpha.14 includes two AI-adapted light-plaster busts: James Joyce and
Virginia Woolf. No additional download or manual file installation is required.
The original PNGs keep their generated alpha and provenance metadata.

The next release adds the separate **Authors** pack with nine more busts:
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
Other ornaments keep the native deck/order and frequency pattern. On a shelf
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
Disable **Authors** when rolling back to alpha.14 or earlier, since those
versions do not know the nine new author-bound filenames.

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
The [artwork preview](ornaments-preview.html) uses the production assets on
light, dark and patterned backgrounds; it is not a KOReader emulator.
Rendering and touch behavior still need a physical Bigme B7 Pro test, especially
with custom ornament sizes, narrow landscape rows and background images.
