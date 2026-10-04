# Author ornaments

OrbitUI alpha.14 includes two AI-adapted light-plaster busts: James Joyce and
Virginia Woolf. No additional download or manual file installation is required.
The original PNGs keep their generated alpha and provenance metadata.

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

The first ornament listing copies the bundled files from the active runtime to
`koreader/settings/bookshelf/ornaments/Modernists/`. A separate install marker
under `settings/orbitui/` prevents a later startup from restoring deleted files.
Existing same-name files and user placement metadata are never overwritten.
An interrupted initial copy can retry on the next start; an installation error
is logged without aborting the browser or KOReader startup.

Future artwork revisions must use a reviewed migration or new names rather than
silently replacing edited files. Code rollback retains these user-side assets:
versions before alpha.14 do not know author matching, so disable the Modernists
pack when rolling back if random placement is unwanted.

## Artwork licenses

The images are separate from OrbitUI's AGPL-licensed software. They are a
collection of separately licensed adaptations, not one combined derivative.

- Joyce: CC BY-SA 4.0, based on Illustratedjc's photograph of Marjorie
  Fitzgibbon's bust. [Source](https://commons.wikimedia.org/wiki/File:Marjorie_Fitzgibbon_-_Bust_of_James_Joyce_(1982)_closer.jpg).
- Woolf: **CC BY-NC-SA 4.0, non-commercial use only**, based on Scan-the-World's
  bust views. [Source](https://doi.org/10.5281/zenodo.20236358).

Complete attribution, change descriptions and license links ship with the images,
including in the device-side pack. Preserve those notices on redistribution.
These are AI-reinterpreted ornaments, not documentary reproductions or endorsements.

## Verification

The desktop prototypes were checked on light and dark backgrounds. Headless
tests cover metadata matching, book-adjacent placement, narrow rows, balancing,
27 pagination configurations, on/off behavior, duplicate trial packs and safe
one-time installation. The packaged PNG bytes and notices are also checked.
Rendering and touch behavior still need a physical Bigme B7 Pro test, especially
with custom ornament sizes, narrow landscape rows and background images.
