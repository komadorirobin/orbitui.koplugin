# OrbitUI releases and OTA

## First installation

Download **orbitui.koplugin.zip**, not GitHub's source-code archive, from an
OrbitUI release. Follow `MIGRATION.md`: back up settings and patches, disable
standalone Bookshelf and SimpleUI, restart, install OrbitUI and restart again.
The original standalone OTA channels are not redirected or modified.

## OrbitUI 0.1.0-beta.18

Beta 18 publishes the locally reviewed quick-control input fixes. There is no
new upstream import: the reviewed October 30 pins and all Beta 17 features remain.

- Home's current status fields can open quick controls before its parent menu
  intercepts the tap. Blank topbar areas, the menu chevron, configured corner
  gestures and long presses retain their existing behavior.
- Enabling/disabling **Tap status fields for quick controls** takes effect on
  the mounted Home without rebuilding books/providers or restarting first.
- Quick controls opened from settings or a bar action remain native dialogs
  instead of being converted to SimpleUI action sheets. This fixes blocked tabs,
  Refresh, Close and Wi-Fi actions without relaxing stale-dialog/owner guards.

Svenska: Beta 18 rättar snabbkontrollerna. Tryck på statusfälten på Hem ska nu
öppna rätt kontroll i stället för den vanliga toppmenyn. **Tryck på statusfält för
snabbkontroller** börjar/slutar gälla direkt när valet ändras. Dialoger som öppnas
från inställningarna eller en knapp behåller rätt identitet, så flikar,
**Uppdatera status**, **Stäng** och Wi-Fi-åtgärder inte blockeras. Egna hörngester,
långtryck, vanliga menyytor och skydd mot gamla dialogers tryck behålls.

Open **OrbitUI settings > Navigation & interface > Quick controls** / öppna
**OrbitUI-inställningar > Navigation och gränssnitt > Snabbkontroller**.
Status taps remain opt-in; saved bars/layouts/profiles are not replaced.
Android Wi-Fi delegates to the system settings. Light control still requires
working native KOReader device support; this release does not add a hardware
driver. The separately distributed optional Bigme compatibility userpatch is
installed through the Ereader patch catalogue or its own repository, not OrbitUI.
Svenska: Ljuset kräver fungerande enhetsstöd i KOReader. Bigmes separata valfria
kompatibilitetspatch installeras via Ereader-patchpaketet eller sin egen repo;
den ingår inte i denna OrbitUI-release.

Update on the preview channel and restart KOReader / uppdatera via
förhandsversionskanalen och starta om KOReader. Beta 17 and earlier supported
betas can update directly. Bootstrap/API 1, all 2,000 installed paths, artwork,
fonts, languages and source pins are unchanged. Old tags/assets remain immutable;
rollback changes code only, never reading progress or later settings.

This remains a prerelease. Automated source/package/native-boundary tests are
not physical acceptance: retest Home status/menu routing, toggling, every panel's
tabs/Close/Back/outside, Android Wi-Fi return, reader return, rotation and sleep
on Boox/Bigme. Svenska: Fortsatt beta; tryck, dialoger, systemåtergång och
enhetslivscykel behöver bekräftas på läsplattan efter uppdateringen.

## OrbitUI 0.1.0-beta.17

Beta 17 publishes the approved settings cards/quick controls and already-reviewed
October 30 upstream changes. There is no additional upstream import in this
release: Bookshelf master `ee84a8fe` (issue forms only after 6.0.4) and SimpleUI
main `257c26d6` (3.0.1 follow-ups) are the integrated pins.

- **Clear settings start:** five large icon cards with short descriptions,
  including **Home (SimpleUI)**. Existing search, scopes and advanced/native
  controls remain. **List view** is available; small screens page or fall back
  to the complete list rather than hide categories.
- **Shared quick controls:** open **OrbitUI settings > Navigation & interface >
  Quick controls > Open quick controls**. Optionally enable **Tap status fields
  for quick controls**, or add **Quick controls** through the existing bar/
  quick-action editor. Saved bars and status layouts are not replaced.
  Home's brightness/Wi-Fi/battery/clock fields open the relevant small menu;
  Bookshelf's ordinary book-hero/micro status line opens the same controls.
  Choose a tab inside the menu when a custom status template is used.
- **Device-aware controls:** supported native brightness/colour-temperature
  sliders plus night mode/advanced light settings; Android system Wi-Fi settings
  or native non-Android connection prompts; battery state/statistics and date/
  time/reading-calendar links when their existing plugins are enabled. Opening
  status does not scan, connect, cold-initialize networking or start polling.
  Refresh explicitly rereads values; Back/outside tap/Close dismiss the menu.
  Job Stop/page dots, configured gestures/long presses and expanded-shelf return
  keep priority. Stale/closed/rotated/sleeping callbacks cannot act on a new view.
- **Reviewed upstream additions:** optional grid quick actions and up to six
  book covers per row on Home, protected/restorable menu hiding, page-turn
  statistics, expanded Tiny Critter options/panel/games/voices, guarded deferred
  startup listing and scrollable long messages. Existing Critter screen choices
  and native Android Bluetooth remain. Automatic patch disabling stays blocked.

Svenska: Beta 17 ger inställningsstarten fem stora kategorikort med förklaringar,
inklusive **Hem (SimpleUI)**. Sökningen, listvyn och befintliga undermenyer finns
kvar. Öppna **OrbitUI-inställningar > Navigation och gränssnitt > Snabbkontroller >
Öppna snabbkontroller**. Slå vid behov på **Tryck på statusfält för
snabbkontroller**, eller lägg till **Snabbkontroller** i navigationsraden.
Tryckfunktionen är av från början; sparade knappar och egna gester behålls.

Menyerna ger ljusstyrka/färgtemperatur där enheten stöder det, nattläge,
Wi-Fi-inställningar, batteristatus/statistik samt klocka och läskalender.
På Boox/Bigme går Wi-Fi till Androids systeminställningar. På Hem kan du trycka
på respektive statusfält; i Bookshelf trycker du på den vanliga statusraden och
väljer kontroll i menyn. Helskärmens befintliga återgång och aktiva jobbknappar
behålls. **Uppdatera status** läser om värdena; stäng med Tillbaka, Stäng eller
tryck utanför. Alla nya egna texter och hjälpsidor finns på svenska och engelska.

Även de granskade upstream-ändringarna från 30 oktober ingår: valfria rutnät
för snabbåtgärder, upp till sex omslag per rad på Hem, menyfiltrering, statistik
för bläddrade sidor, fler Tiny Critter-val och mindre arbete vid uppstart.
Egna patchar stängs inte av automatiskt. Biblioteksprofiler, chip/position,
Android safe mode/omslagsfixen, snabbstängning och BookOrbit/MAL-ägarskap behålls.

Update through the preview channel and restart KOReader. Beta 16 and earlier
supported betas can update directly; no bridge or settings reset is introduced.
The stable bootstrap/API 1, all 2,000 installed paths, artwork, fonts and languages
remain. New exact Lua sources are lazily embedded in the existing module
registry to stay within older installers' limits, not shipped as extra files.
Old public releases and tags remain immutable. Rollback changes code only;
older code ignores the new quick-control preference/action, so remove or reselect
that optional bar button after rollback if necessary. Keep an independent backup
of KOReader's settings/data; never restore old reading progress to undo a UI build.

This remains a prerelease. Physical Boox/Bigme font/touch/focus, light/warmth,
Android system return, colour/night/underlay, reader/rotation/sleep and update
acceptance remains open. Automated checks do not establish a device speed/RAM gain.

## OrbitUI 0.1.0-beta.16

Beta 16 brings the reviewed local performance and size/storage work together.
There is no new upstream import: Bookshelf remains at `d07905ba` (6.0.4) and
SimpleUI at `22d5a3d2` (3.0.1 follow-up), as in Beta 15.

- **Reading dashboard:** hidden cards stop requesting unnecessary statistics,
  book counts and recent-book candidates. Visible local goals and native Recent
  sources retain their needs; other enabled modules still request their data.
- **Optional performance profiles:** open **OrbitUI settings > System &
  maintenance > Speed, memory & diagnostics**. **Keep existing behaviour** is
  the default. **Adaptive memory** coordinates retained cover-cache limits when
  available memory is low or a reader is visible, without rewriting saved
  limits or freeing images borrowed by the active shelf. **Responsive** also
  disables Bookshelf wipe animations and speculative next-page/chip preload;
  cold page loads can take longer. Android safe mode, visible cover extraction,
  image quality and prepared fast reader return are preserved.
- **Local diagnostics:** opt in to **Measure performance**, then view/copy a
  report. Only fixed operation labels and numeric timing/memory/cache/queue data
  are included. No book paths/titles, accounts, raw errors, automatic file or
  upload. Reports measure synchronous calls, not panel/deferred end-to-end
  latency, and Lua heap is not total RAM. Device speed/RAM gains are not claimed.
- **Quick guide:** **Home and Bookshelf: quick guide** explains Home (SimpleUI),
  library profiles, chip sources, the navigation button and fast reader return.
  The guide and all new settings/help are available in Swedish and English.
- **Smaller package and safer update storage:** omit only developer source
  references from translation catalogs, retaining every language/message/license.
  After healthy startup, at most one verified strictly older unused code runtime
  may be collected. Factory/current/rollback, pending/newer code and unknown or
  modified files remain. Details below; no reading/settings/cover/artwork cleanup.

Svenska: Beta 16 gör Läsöversikts databehov beroende av synliga kort och samlar
de frivilliga lägena **Adaptiv minneshantering** och **Snabbhetsläge** under
**OrbitUI-inställningar > System och underhåll > Snabbhet, minne och diagnostik**.
**Behåll befintligt beteende** är fortfarande standard. Snabbhetsläget stänger
av svepanimationer och spekulativ förladdning; kalla sidladdningar kan därför ta
längre tid. Androids säkra omslagshantering, bildkvalitet och vår återgång till
rätt hylla behålls. Slå på **Mät prestanda** för en lokal rapport utan boknamn,
sökvägar eller konton; inget laddas upp. **Hem och Bookshelf: snabbguide** visar
hur startskärm, profiler, chip och navigationsknapp hänger ihop.

Paketet blir mindre utan att språk eller resurser tas bort. Gamla, oanvända
kodkopior kan städas efter en verifierad start, högst en per start. Fabrikskopia,
aktiv version, återställningsversion och okända/ändrade filer behålls. Böcker,
inställningar, läsdata, omslagscache och tilläggsbilder rörs inte. Faktisk snabbhet,
minnespåverkan, skärmrendering och lagringsbeteende på Boox/Bigme återstår att
kontrollera; detta är fortsatt en förhandsversion.

Update from Beta 15 or earlier supported betas on the preview channel, then
restart KOReader. Bootstrap/API 1 and the complete installed file set are
unchanged: 1,999 inventoried files plus manifest, all 2,000 slots. No new fonts,
image packs or runtime dependencies. Old public releases remain immutable.
Rollback changes code, not later settings/reading data; earlier code ignores
the new performance preferences. Keep an independent KOReader data backup.

## Update-storage cleanup (Beta 16 and later)

After confirmed healthy startup a quiet deferred worker may remove one obsolete
code snapshot, rather than leave it until a later update. It first verifies the
active and previous packages completely. Factory, current and previous versions
are always kept. A pending update, recovered startup, stale context or unreadable/
modified retained runtime prevents collection. Equal/newer prepared snapshots
are kept. Settings, reading data, links, covers/cache and add-on artwork are not
cleanup targets; this does not shrink the release ZIP or measure RAM usage.

Only a strictly older, complete manifest-verified runtime with no extra or
modified files/directories/links can enter cleanup. A same-filesystem rename
quarantines it as `.orbitui-versions/.orbitui-gc-<slot>`; known files are checked
again before unlinking, directories are removed only when empty and the manifest
is removed last. An interruption can resume from the verified remainder on a
later healthy startup. Unknown/changed entries stop deletion and stay intact.
The collector inspects at most 128 version-directory entries/eight candidates,
with a 12,000-node tree limit, and completes at most one snapshot per startup.
Large backlogs may therefore need several starts; this is deliberately bounded.
The previous unsafe bulk deletion during update preparation is removed.

Cleanup is serialized with update operations, does not change activation records
and is not required for successful startup. External installation and daily
checks follow its completion/cancellation. Removal counts/bytes are logged; actual
savings depend on installed obsolete snapshots. Factory + current + rollback
copies still take space by design. Introduced in Beta 16; Beta 15 is unchanged.

Svenska: Efter bekräftad lyckad start kan en gammal, oanvänd kodversion städas
bort. Aktiv version och återställningsversion måste först klara en fullständig
kontroll. Fabrikskopian och de två behållna versionerna lämnas alltid kvar.
Högst en gammal kopia tas bort per start; ändrade/okända filer och väntande eller
nyare versioner behålls. Avbruten städning kan fortsätta vid nästa start.
Inställningar, läsdata, omslagscache och tilläggsbilder rörs inte. Ändringen är
införs i Beta 16; lagringsbesparingen beror på vilka gamla kodkopior som finns.

## Packaging optimization (Beta 16 and later)

Sealed packages omit only developer source-file/line references (`#:`
comments) from the 43 component PO catalogs. All languages, message bytes,
headers, plural rules and copyright/license/translator notices remain. Original
upstream catalogs in Git are not rewritten. The package manifest and checksum
are generated after optimization, so older API-1 installers still validate the
exact shipped bytes. No file paths, bootstrap, limits, settings, caches, artwork
or retained update versions change in this packaging step. Beta 15's existing
asset is not replaced. Semantic checks compile each original and
optimized catalog and require byte-identical translation tables.

Svenska: Releasepaketet utelämnar bara utvecklarnas fil- och radreferenser
i översättningsfilerna. Alla språk, texter, pluralregler och licensuppgifter
behålls; originalen i Git ändras inte. Kontrollsummor beräknas efter optimeringen.
Optimeringen införs i Beta 16.

## OrbitUI 0.1.0-beta.15

Beta 15 adds optional **Card colours > Off / Accents / Tinted cards** under
**OrbitUI settings > Home (SimpleUI) > Reading dashboard** and the dashboard's
own module settings. The choice belongs to that Home/Custom Screen only.
Existing installations stay Off until explicitly changed. Monochrome screens
and disabled colour rendering keep the old greyscale regardless of the stored
choice. Tinted cards add quiet backgrounds; accents colour borders/progress.
The continue-reading card can use the displayed cover's dark shade, retaining
its light/dark preference. Night-mode palettes keep native black/white text
contrasting. Layout, card order/headings/sources, row paging, covers and actions
are preserved. No BookOrbit code, palette or artwork is imported; the feature
is an independent OrbitUI implementation inspired by its colour-board options.

Also includes the reviewed October 28 upstream imports: Bookshelf 6.0.4 through
`d07905ba` (colour-safe frames, bounded dialog refreshes, searchable collections
and sleep-screen capture), SimpleUI 3.0.1 follow-up through `22d5a3d2` (weak
reader hook owners, deferred file listing, cover-poll/page-refresh and hidden
pager fixes, dithered wallpaper, optional page flash and Hazel). OrbitUI's fast
profile return, clearer settings, Android safe-mode covers, Home/Bento,
series/ornaments, cached MAL and external BookOrbit sync owners remain intact.

Svenska: Välj **OrbitUI-inställningar > Hem (SimpleUI) > Läsöversikt > Kortfärger**:
Av, Accenter eller Tonade kort. Tonade kort ger pastellbakgrunder och färgade
ramar/indikatorer. Valet gäller bara den aktuella läsöversikten. Befintliga
installationer behåller gråskalan tills du väljer färg. Mörkt Fortsätt läsa-kort
kan hämta sin färg från omslaget; rubriker, layout, bokkällor och bläddring behålls.
Även senaste granskade upstream-rättningarna ingår. Fysisk Boox/Bigme-kontroll
av färg, nattläge, ghosting och lyhördhet återstår.

Update from Beta 14 (or earlier supported betas) on the preview channel and
restart KOReader. Bootstrap/API 1 and the complete installed file set stay
unchanged: 1,999 inventoried files plus manifest, all 2,000 slots. New code and
notes use existing runtime files; Hazel's exact original PNG bytes remain
embedded as reviewed. No old asset/license/note is removed or installer limit
raised. Old public tags/ZIPs stay immutable. Rollback changes code, not later
settings/reading data; older builds ignore the new scoped colour preference.
Headless/native-archive tests are not physical colour/display acceptance.

## OrbitUI 0.1.0-beta.14

Beta 14 includes the approved native reader-menu fast Bookshelf return and the
clearer bilingual library/chip editor, plus reviewed SimpleUI upstream through
`e5cd6dcb` (Bookshelf stays at `c37580a1`, 6.0.3). Open a chip for its own folder
and source. Order libraries and chips separately, with live numbered positions
and named before/after neighbours. Library-wide roots remain in Advanced.
The cabinet/file-browser reader-menu button returns to the source shelf or
matching library; cold or unsafe targets use normal close. A searchable bilingual
opt-out keeps KOReader's original button action.

SimpleUI adds Unicode-aware search/sorts and a preset-list export fix. OrbitUI
retains the older-reader utf8proc fallback and contains recognized metadata-cache
faults without upstream's automatic database/WAL deletion or connection reset.
It does not automatically repair a corrupt database; last known text may remain
visible and future reads retry. No progress/settings/links/artwork are reset.
Home/Bento, Android safe-mode covers, bindings/ornaments, profile identities and
external sync owners remain unchanged. Physical Boox/Bigme checks are outstanding.

Svenska: Arkivskåpsknappen i läsmenyn använder nu vår snabba återgång till rätt
hylla, med säker vanlig stängning som reserv. Profil- och chipinställningarna är
tydligare: mappen finns inne i chippet och ordningen visas direkt i en numrerad
lista. SimpleUI får bättre Unicode-sökning/sortering och en startguidefix.
Databasfel fångas utan att automatiskt radera cachen. Befintliga inställningar,
läsläge, bibliotek, omslagsfixar och integrationer behålls. Enhetstester återstår.

Beta 13 and older supported installers can update directly using the preview
channel, then restart KOReader. Bootstrap/API 1 and the complete installed path
inventory are unchanged: 1,999 files plus manifest, exactly 2,000. This release's
notes live in this existing document and the GitHub release body, not a new
runtime file. No assets/licenses/old notes are removed and no installer limit is
raised. Older public tags/assets remain immutable. Code rollback does not undo
later settings edits or reading progress; keep a separate settings backup.

## Earlier releases

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

Version `0.1.0-alpha.26` displays identified series as compact dynamic boxes in
the physical shelf view and balances ordinary shelf-end ornament spacing.
Boxes are display-only: tapping opens their members, and existing book files,
metadata, reading data, artwork and settings are preserved. Alpha.25 and earlier
alpha releases can update directly through the same preview channel and
unchanged bootstrap/API 1. No upstream merge or artwork migration is included.
Code rollback returns to the expanded series presentation.

Version `0.1.0-alpha.27` gives series boxes a consistent receding top and side,
including the lower side edge, without changing their dimensions or pagination.
The night-mode quick action now retains full icon contrast in both states;
chosen icons, toggle behavior and other actions' dimming are preserved.
Alpha.26 and earlier alpha releases can update directly through the same
preview channel and unchanged bootstrap/API 1. No settings, reading data,
artwork or upstream baselines are changed. Device visual acceptance remains open.

Version `0.1.0-alpha.28` adds pxlflux's Solar Colour and Solar Mono as per-icon
chooser sources, with 160 SVGs each. Existing icon choices are unchanged; no
whole-pack installer or global icon replacement is included. Redundant black
section badges are hidden inside an opened series or a single-series tab in
the physical shelf view, while other shelf contexts keep their badges.
Alpha.27 and earlier alpha releases can update directly through the same
preview channel and unchanged bootstrap/API 1. No settings migration, reading
data, ornament artwork or upstream baseline changes are included. Code rollback
preserves settings; the new icon sources require alpha.28 or later. Device
visual acceptance remains open.

Version `0.1.0-alpha.29` redraws physical-shelf series boxes as open slipcases
with up to six cover-coloured bindings and a slim dark title band. Box width
grows with membership, up to a cap; native pagination uses that width and the
existing height budget is preserved. A read/total badge replaces the volume
count line. Fully finished boxes follow the ordinary book checkmark/bookmark
and fading preferences, with clear labels and no changes to member statuses.
Alpha.28 and earlier alpha releases can update directly through the same
preview channel and unchanged bootstrap/API 1. No settings migration, reading
data, artwork or upstream baseline changes are included. Code rollback restores
the earlier presentation. Device visual acceptance remains open.

Version `0.1.0-alpha.30` fixes alpha.29's crash when a fully finished series box
is displayed, including after a restart. The completed-mark compositor now
receives an explicitly sized blank card. Slipcase fills preserve cover hues
on colour screens, with lighter boards and rims, and contact shadows follow
the sloping side instead of a rectangular footprint. Alpha.29 and earlier
alpha releases can update directly through the same preview channel and
unchanged bootstrap/API 1. No settings migration, reading-data, artwork or
upstream baseline changes are included. Device visual acceptance remains open.
Code rollback to alpha.29 also restores its completed-box crash.

Version `0.1.0-alpha.31` includes the reviewed 16-commit SimpleUI upstream merge,
with reader-return/cache improvements, optional titlebar tabs, an independent
book-close destination, wallpaper darkening and badge sizing. OrbitUI keeps the
current titlebar/icons, Bento margins, embedded dock geometry and legacy settings.
Transient database/cover failures remain retryable. Alpha.30 and earlier alpha
releases can update directly through the same preview channel and unchanged
bootstrap/API 1. No artwork or reading-data changes, new Bookshelf baseline or
general modularization are included. Code rollback retains settings; older
runtimes ignore new options. Physical-device acceptance remains open.

Version `0.1.0-alpha.32` includes nine further reviewed SimpleUI commits through
`f14507af`, with generated cover placeholders, cropped Cover Deck sides,
folder-stack styles, backdrop controls and shared choice menus. OrbitUI keeps
its existing visual defaults and BookOrbit source. Shadow buffers are bounded
and placeholder teardown respects later third-party patches. Alpha.31 and
earlier alpha releases can update directly through the same preview channel
and unchanged bootstrap/API 1. No settings migration, artwork, reading-data,
Bookshelf baseline or general modularization changes. Device acceptance remains
open; code rollback preserves settings and earlier runtimes ignore new options.

Version `0.1.0-alpha.33` includes the reviewed 166-commit Bookshelf 5.4.0 merge
through `a0bc7e37`, with layered per-shelf themes, a Theme library, nested shelves,
custom cover/group labels and per-shelf ornament decks. OrbitUI's profile roots,
series slipcases, completion badges, artwork, icons and BookOrbit sync ownership
are retained. Alpha.32 and earlier alpha releases can update directly through
the same preview channel and unchanged bootstrap/API 1. Back up settings before
updating: native theme storage is migrated, and code-only rollback does not
reverse it. Keep the previous install and settings backup together. Physical
device acceptance remains open; no general UI modularization is included.

Version `0.1.0-alpha.34` moves book-cover text to each chip's long-press menu.
Title/Author/Series/Custom/None is stored independently per shelf, including
Library and Manga chips with the same name. Physical shelves draw a bounded
text band inside each cover, while grids retain their below-cover labels.
Untouched shelves keep their previous appearance; series boxes retain their
own labels and counters. Alpha.33 and earlier alpha releases can update
directly through the same preview channel and unchanged bootstrap/API 1.
No artwork, reading data, sync settings or upstream baselines are changed.
Code rollback preserves the per-shelf preferences; older runtimes ignore them.
Device visual acceptance remains open.

Version `0.1.0-alpha.35` adds Cover text > Placement > Above the cover to each
chip's long-press menu. The choice applies to both cover grids and physical
bookcases, independently of the text content. Existing placement remains the
default. Physical labels use headroom first and proportionally reduce the cover
only when needed, keeping row height, book feet and pagination unchanged.
Alpha.34 and earlier alpha releases can update directly through the same preview
channel and unchanged bootstrap/API 1. No artwork, reading data, sync settings
or upstream baselines are changed. Code rollback retains the new preference;
earlier runtimes ignore it. Device visual acceptance remains open.

Alpha.36 integrates the reviewed Bookshelf 5.4.1 update. Nested shelves can
choose independent themes or restore parent inheritance. OrbitUI's existing
per-chip cover-text menu, custom text and above/bottom placement remain the
single owner of caption preferences in all supported views; the duplicate
native grid-only picker is hidden. The native grid-stack group setting is now
Show author below series, without changing physical series-box labels. Alpha.35
can update directly through the preview channel and unchanged bootstrap/API 1.
SimpleUI, artwork, reading data and sync ownership are unchanged. No new
settings migration is introduced; older upgrades still carry the alpha.33
theme-storage migration. Device acceptance remains open.

Alpha.37 integrates Bookshelf 5.4.3 and the reviewed October 12 SimpleUI update.
Explicit Auto view modes have independent top/drill styles; existing unset
choices retain their behavior. Caption-aware hero height, stable per-drill
ornament deals, wallpaper-safe opening effects and bounded in-place clock/status
refreshes preserve OrbitUI's profiles, series boxes, dock and per-chip captions.
Alpha.36 and earlier alpha installations can update directly through the same
preview channel and unchanged bootstrap/API 1. No new settings migration,
artwork, reading-data or sync-ownership change is included. Earlier upgrades
still carry alpha.33's theme-storage migration. Code rollback keeps preferences;
older code ignores the new Auto levels. Physical-device acceptance remains open.

Alpha.38 integrates Bookshelf 5.4.4 and SimpleUI's reviewed Czech/Chinese
translation updates. Explicit Auto/List supports independent per-level density
within each Library/Manga profile; face-out favourite markers use the top-right
corner. The all-face-out policy and existing shelf customizations remain.
Alpha.37 and earlier alpha installations can update directly through the same
preview channel and unchanged bootstrap/API 1. No new migration, artwork,
reading-data or sync change. Code rollback retains the new level preferences;
older code ignores unsupported preferences. The pre-alpha.33 theme-migration
caveat and physical-device acceptance gaps still apply.

Alpha.39 integrates the reviewed October 14 Bookshelf and SimpleUI branch
updates: Favourite first sorting, plugin formats/OPDS-PSE actions, finished-book
ledger/manual entries, per-view grouping and an opt-in Flow carousel. OrbitUI's
existing profiles, series boxes, icons and layout choices are preserved; PR #508
is not included. Alpha.38 and earlier alpha installations can update directly
through the same preview channel and unchanged bootstrap/API 1. Copy-only
migrations retain old settings and counts, but new ledger edits are not mirrored
to older code on rollback. Keep the prior installation and settings backup,
including the pre-alpha.33 theme-migration caveat. Artwork and external sync
ownership are unchanged. Physical-device acceptance remains open.

Alpha.40 includes the reviewed October 16 SimpleUI update, Bookshelf 5.5 and
the explicitly requested upstream series-slipcase trial. The old OrbitUI box
design is preserved on a local branch, not offered as an in-app switch. Native
read-total and member-spine marks replace the separate box badge and whole-box
finished fade/mark. Existing series scopes remain readable and new scopes keep
rollback-compatible member IDs. All ordinary books remain face out. Author
photos, optional Tabbed Grid/Reader Book layouts and new page badges do not
replace ornaments or change external sync ownership. Alpha.39 can update
directly via the same preview channel and bootstrap/API 1. Keep installation
and settings backups: new grouped-order, ledger and module edits are not
backported on code rollback, nor are new photo/preferences removed. The
pre-alpha.33 theme-migration caveat and physical-device acceptance gaps remain.

Alpha.41 preserves the first cover's proportions on native series slipcases,
centers it with visible board around unused space, and moves the read-total
above the image. The minimum box width is 70% of a normal cover, with the native
maximum retained. Alpha.40 and earlier alpha installations can update via the
same preview channel and unchanged bootstrap/API 1. No upstream import, artwork,
settings migration or reading-data change is included. Code rollback restores
the prior box appearance; the earlier settings-backup and migration caveats
still apply. Physical Bigme rendering of this refinement remains unverified.

Alpha.42 integrates Bookshelf 5.5.2 and SimpleUI `7eb80f9e`. Custom series art
uses the aspect-preserving slipcase fit, Random Book gains optional direct
opening, and SimpleUI adds shared surface controls and Home/menu/metadata fixes.
Copy-only appearance migrations retain old keys and explicit new choices;
legacy dock and wallpaper APIs remain available. Alpha.41 and earlier alpha
installations can update through the same preview channel and bootstrap/API 1.
No artwork, reading-data or external sync changes. Keep installation/settings
backups: code rollback does not mirror new surface edits into older appearance
keys, and all earlier migration caveats remain. Physical Bigme acceptance of
the merged changes remains outstanding.

Alpha.44 stops stretching or squeezing member spines to fill series boxes.
Reliable page counts set comparable widths; unknown/reflowable reader counts
use a neutral fallback. Short series leave a shaded interior on the right,
while a separate `+N` identifies undrawn members in long series. The complete
read/total, aspect-true cover area and alpha.43's shelf/series binding choices
remain. Alpha.43 and earlier alpha installations can update through the same
preview channel and unchanged bootstrap/API 1. No new upstream import, artwork,
settings migration or reading-data change is included. Code rollback restores
the earlier fill-to-width presentation without changing data. Earlier settings
backup/migration caveats and physical-device acceptance gaps still apply.

Alpha.45 replaces Tankobon with the taller Kanzenban / large format option and
adds a cached MAL star-rating sticker to physical series-box covers. Legacy
Tankobon choices resolve to Paperback without rewriting saved preferences;
select Kanzenban explicitly per shelf or series to use the taller format.
Rating stickers reuse the existing MAL folder provider; no MAL plugin update
or network fetch while painting is required. Alpha.44 and earlier alpha
installations can update through the same preview channel and bootstrap/API 1.
No upstream import, artwork, settings migration or reading-data change is
included. Code rollback retains preferences but older runtimes do not implement
Kanzenban or the new box badge. Earlier backup/migration caveats and physical
device-acceptance gaps still apply.

Alpha.46 replaces the physical series-box rating sticker with a rounded
top-left cover cutout. The cached star-plus-score text uses the box's own ink;
the cover's size/proportions and the count/overflow/name placements are unchanged.
Folder badges retain their appearance. Alpha.45 and earlier alpha installations
can update through the same preview channel and unchanged bootstrap/API 1.
No upstream import, artwork, settings migration, reading-data or external sync
change is included. Code rollback to alpha.45 restores the separate rating
sticker without changing data. Earlier backup/migration caveats and physical
device-acceptance gaps still apply.

Alpha.47 adds an opt-in Reading dashboard as an additional first Home page,
with independent previous/next paging for Want to Read and New Books. It also
offers per-shelf series titles on the bottom of the cover, freeing the separate
title strip for aspect-preserved cover art. Existing layouts and title placement
stay unchanged until selected. Alpha.46 and earlier alpha installations can
update through the same preview channel and unchanged bootstrap/API 1. No
upstream import, artwork change, reading-data migration or new sync owner is
included. Disable the dashboard before rolling back to alpha.46 or earlier,
so an older runtime is not left with an unsupported dashboard page; the older
Home pages remain intact. Code rollback retains the series-title preference,
which older code ignores. Earlier backup/migration caveats and physical-device
acceptance gaps still apply.

Alpha.48 is a small **OTA compatibility bridge**, built on alpha.47 without the
pending manga ornaments or Solar v1.1.0 artwork. Its ZIP stays below the older
64 MiB limit, so alpha.47 and earlier can install it normally. Install alpha.48
and restart KOReader before the subsequent larger artwork release. Alpha.48
raises the ZIP limit to 128 MiB and expanded-content limit to 256 MiB, retaining
the 32 MiB per-file, 2,000-file and 1 MiB manifest limits, checksums, path checks
and bootstrap/API 1. Large file downloads get up to ten minutes; API requests
retain their three-minute limit. Nothing is resized or removed from user data.

Alpha.49 publishes the 14 series-bound Manga/Manga II ornaments and Solar Icon
Pack v1.1.0 after the user confirmed installing the alpha.48 bridge and restarting.
The runtime exceeds 64 MiB: use alpha.48 or later for OTA. Alpha.47 and earlier
must install the small alpha.48 release separately; their selector does not
skip the oversized latest release to offer an intermediate version. The stable
bootstrap/API 1 and upstream pins are unchanged. Existing settings and icon
choices survive. Before rolling back to alpha.48 or earlier, disable Manga and
Manga II: copied artwork remains but the older planner lacks series matching.
New Solar icons require alpha.49 or later. Earlier rollback caveats still apply.

Alpha.50 publishes the reviewed Bookshelf 5.5.4 merge through `982375a7`.
It includes native Paperback bindings, deferred/cached statistics modules,
optional KOReader-rate shelf refreshes, parked-reader gesture fixes and folder
history/progress sorting. OrbitUI retains its independent Hardcover/Paperback/
Kanzenban choices, profile-specific shelves and series-box refinements without
duplicate native controls. SimpleUI, artwork, stable bootstrap and API 1 remain
unchanged. Alpha.48 or later can update directly through the preview channel;
older installers still require the small alpha.48 bridge because this ZIP
exceeds 64 MiB. No settings or reading-state migration is introduced. Existing
rollback caveats and physical-device acceptance gaps remain in effect.

Alpha.51 adds independent Reading dashboard card headings and larger paging
controls with horizontal swipes for Want to Read and New Books. On the physical
shelves, named series with one local volume now keep a box; Oneshots directories
on the Manga/Serier folder chips become folder-backed boxes, including nested
title folders. Tapping opens the current folder contents; counts and folder
image/hold actions remain available without inventing series metadata or a
shared MAL rating. Existing grid/list views, upstream pins, assets, stable
bootstrap and API 1 are unchanged. Alpha.48 or later can update directly;
earlier installers still need the alpha.48 bridge. Code rollback retains new
dashboard headings but older code ignores them, and restores the earlier
grouping/paging presentation without changing book files or reading state.
Earlier backup/migration caveats and physical-device acceptance gaps still apply.

Alpha.52 adds the independent Manga III ornament pack: a stargazing telescope
for Insomniacs After School and a quiet Japanese bungalow for Hirayasumi.
Both are original AI-generated thematic designs, with transparent colour,
native zoom, sourced info cards and exact series-metadata matching. Enable
Manga III when a theme selects specific packs. Its independent additive marker
preserves older packs, customized artwork, deletions and all theme settings.
Upstream pins and bootstrap/API 1 are unchanged. Alpha.48 or later can update
directly; older installers still need the alpha.48 bridge. Before rolling back
to alpha.51 or earlier, disable Manga III: copied artwork remains but older
planners do not recognize these series bindings. Earlier backup/migration
caveats and physical-device acceptance gaps remain in effect.

Alpha.53 is the standalone-configuration **test alpha**, not beta. It adds
editable library sections, per-screen dashboard cards/sources, a reviewed setup
guide and reversible Shelf settings / Classic OrbitUI / Minimal bookshelf
presets. Upgrades preserve their layout, integrations and Classic appearance;
fresh installs start neutral and offer the guide in FileManager. Existing users
open it manually under OrbitUI settings > Setup guide. No book files move and
no credentials or reading data are reset. No upstream merge, asset replacement
or bootstrap/API change is included. Alpha.48 or later can update directly;
older installers still require the alpha.48 bridge.

Before testing, back up current KOReader settings independently: the first-run
snapshot is not refreshed on upgrades. Rollback changes code only. Alpha.52
ignores new library sections, dashboard sources/card order and presets, returning
to its fixed Library/Manga configuration and earlier presentation. It does not
undo setup-guide edits to shared launch/dock preferences; newly created section
buttons therefore require this build. Keep the existing bar during initial
upgrade tests, or restore its affected preferences separately if rolling back.
Do not delete new settings or restore old reading progress. Physical restart,
setup-guide and shelf-preset acceptance remain mandatory before the first beta.

Alpha.54 is the optional-add-ons **test alpha**, still not beta. The main runtime
contains no ornament artwork; six packs are independently installed/updated via
OrbitUI settings > Add-ons > Ornament add-ons, using catalog `ornaments-1`.
Existing native artwork, themes, local edits and deletions are retained. New
packs start disabled. Matching authors/series remains the default, with optional
random placement per pack. Info cards are Swedish for Swedish locales and English
otherwise; custom captions take precedence. Explicitly install/adopt old packs
to receive managed updates and translated cards. Manga has one visible version.

The bootstrap/API and upstream pins remain unchanged. Alpha.53 can update
directly through the preview channel. Add-on state lives outside code slots, so
code rollback does not roll it back: alpha.53 ignores the managed pack directory
and newly downloaded artwork may not appear there. Old native folders remain.
Keep a separate settings backup; do not restore old reading progress. Fresh
setup and add-on device acceptance are required before beta; see the
[alpha.54 checklist](releases/0.1.0-alpha.54.md).

Version `0.1.0-alpha.55` fixes opening the ornament add-on menu when pre-existing,
unmanaged ornament folders are present. A loop index shadowed the translation
function, failing before the menu opened or any download began. Existing artwork,
settings and the separately published `ornaments-1` catalog are unchanged. Update
from alpha.54 through the preview channel and restart KOReader; no artwork removal
or reinstallation is needed. Bootstrap API 1 is unchanged. This remains a test
alpha pending the fresh-setup and add-on physical-device acceptance checks.

## On the reader

Beta 11 makes the root and embedded Bookshelf update controls use the same
OrbitUI version, **Include preview releases**, daily online check and recovery
settings. The old component version/branch/channel/wake/changelog rows do not
describe OrbitUI and are no longer shown on the hosted page. Existing OrbitUI
preferences win; Bookshelf's old settings are retained for rollback.

GitHub HTTP failures show safe status/retry guidance instead of Lua paths.
Confirmed 403/429 limits honor the longest valid Retry-After/reset hint (bounded
to one day; one minute when no valid timing is supplied), with no further check
in the same running session before that deadline. A generic 403 is not assumed
to be a rate limit. This does not bypass GitHub/network policy. An older installed
updater still needs to download the new runtime before it can show these fixes;
wait before retrying a blocked request. Do not delete settings or version slots.

Version `0.1.0-beta.10` integrates reviewed Bookshelf 6.0.2 metadata-refresh,
colour-cover clipping, bounded/covered status repaint and module-action/key fixes.
SimpleUI, Home/Bento and Bookshelf profile/navigation behavior are retained.
Beta 9 and Beta 5 can update directly through the preview channel and restart;
bootstrap/API 1 is unchanged. No automatic metadata scan, settings/data reset,
artwork change or external sync-owner change is included. Physical cover refresh,
minute-tick/overlay, module-key and broader device checks remain open. See
[the Beta 10 notes](releases/0.1.0-beta.10.md).

Version `0.1.0-beta.9` adds a first-class Bookshelf navbar destination and simple
saved-profile/chip targeting. Beta 8 and Beta 5 can update directly through the
preview channel and restart. Existing bars are retained: enable Bookshelf in
**OrbitUI settings > Bookshelf navigation**, then choose a destination; each
profile also offers Add to navigation bar. No reset or raw dispatcher ID is
needed. Bootstrap/API 1, component pins, artwork/fonts and existing data stay
unchanged. The new physical Boox/Bigme navigation checks remain open. See
[the Beta 9 notes](releases/0.1.0-beta.9.md).
Older releases do not recognize the new generic Bookshelf action ID and may
prune that button after a code rollback. Reselect an older saved-profile action
if necessary; keep a separate navigation/settings backup. No older public
release is rewritten to retrofit support for the new action.

Version `0.1.0-beta.8` imports `ffi/blitbuffer` in the shared screen engine,
fixing the photographed `sui_screen_engine.lua:288` cold-load failure that
remained after Beta 7. Beta 5 and Beta 7 can update directly through the preview
channel and restart; no reset or bridge is needed. Existing settings/data,
artwork/fonts, component pins and bootstrap/API 1 are unchanged. Whole-module
tests now supplement the first-run hook tests. Physical Home/native-crash
retesting remains required. See [the Beta 8 notes](releases/0.1.0-beta.8.md).

Version `0.1.0-beta.7` fixes a reproduced first-run Home logger failure and adds
shared load/open error reporting with guarded partial-window cleanup. Beta 5
and Beta 6 can update directly through the preview channel and restart. No
settings reset is needed; bootstrap/API 1 and all existing data/assets remain
unchanged. The separately reported native Android mutex crash is not proven
resolved; retest on the affected device and capture any detailed Home error.
See [the Beta 7 notes](releases/0.1.0-beta.7.md).

Version `0.1.0-beta.6` integrates reviewed Bookshelf 6.0.0 and SimpleUI 3.0
follow-ups. Beta 5 can update directly through the preview channel and restart;
the stable bootstrap and API 1 are unchanged. Existing Home/Bento geometry,
scoped shelves, series bindings, ornaments and reading data are retained.
Bookshelf's new module-grid/deck migrations retain old keys/copies for code
rollback; code rollback does not undo later settings edits. New modules, pinning,
Highlights, colours/underlay and external-plugin behavior still need physical
Bigme acceptance. Cache changes are not a measured device speedup. See
[the Beta 6 notes](releases/0.1.0-beta.6.md).

Version `0.1.0-beta.5` includes the reviewed official SimpleUI 3.0 release-ZIP
snapshot. Beta 4 can update directly through the preview channel and restart;
the stable bootstrap and API 1 are unchanged. Existing percentage/stacked Bento
layouts are retained until explicitly editing width/movement in the new editor.
New font choices and Tiny Critter are optional. Settings migrations copy into
unset new keys while retaining old keys for rollback; preserve a separate
settings backup because code rollback does not undo later settings edits.
Bookshelf, ornament packs and reading data are unchanged. New layout, font,
chart, colour/night, input and external-plugin behavior still needs physical
reader acceptance. See [the Beta 5 notes](releases/0.1.0-beta.5.md).

Version `0.1.0-beta.3` integrates Bookshelf 5.5.5 and the subsequent Shelf size
translator fix through `065f25c0`. SimpleUI 2.7.5, ornament channels, bootstrap
and API 1 are unchanged. Update through OrbitUI's preview channel and restart;
no intermediate Beta 2 installation is required when using internal OTA.
Existing preferences and reading data are retained. New cover-rating display
and cached Hardcover fallback are opt-in. Code rollback retains their keys;
older Bookshelf code may treat the new rating icon choice as its default heart.
No physical-device result is inferred from automated upgrade/rollback tests.

Version `0.1.0-beta.1` is the first explicitly approved public beta, following the
reader confirmation of alpha.55's ornament menu fix. It adds native-only current
Bookshelf settings-path recognition and backup/onboarding coverage without moving
files, alongside a rewritten public introduction and installation guide. Existing
flat-layout OrbitUI settings remain on their old paths. The optional `ornaments-1`
catalog, artwork, upstream pins and bootstrap API 1 are unchanged. Alpha.55 can
update through the preview channel; restart after installation. A new installation
over native-only standalone Bookshelf should not roll back to an OrbitUI alpha
that cannot read that path; see [migration and rollback](MIGRATION.md).

Version `0.1.0-beta.2` moves ornament discovery to the separate `orbitui-addons`
repository, retaining old catalog URLs, pack versions, settings and artwork. It
also adds verified snapshots of newer external root installations with deferred
activation, previous-slot rollback and an explicit retry control. Install this
release through internal OTA first, then restart. Bootstrap/API 1 and upstream
pins are unchanged. Returning to Beta 1 removes the new import logic but retains
ornament state. External app-store/device acceptance remains open; see below and
[the Beta 2 notes](releases/0.1.0-beta.2.md).

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
UI work is deferred until after Trapper/confirmation callbacks return. Starting
with alpha.48, ZIPs are bounded to 128 MiB, expanded contents to 256 MiB and
individual files to 32 MiB (at most 2,000 files and a 1 MiB manifest). Older
installers retain 64/128 MiB limits and must install the small alpha.48 bridge
before a larger payload. Downloaded files have a ten-minute deadline; API and
checksum requests retain three minutes, with the same 15-second socket timeout.
Symlinks, special files, traversal, hidden paths and case-ambiguous duplicates
are rejected. Archive extraction copies bytes rather than filesystem metadata.

The factory installation and previous code remain available. Published Beta 15
and earlier clean obsolete inactive slots during a later update. Beta 16's
collector described above instead verifies/removes at most one old
snapshot after healthy startup, preserving current/previous/factory and unknown
data. `.orbitui-work` is disposable download/staging space. Allow space for the
ZIP download, extraction, retained code versions and any optional add-on artwork;
actual requirements depend on the installed versions and selected packs.

## External updates (Beta 2 and later)

Install Beta 2 through OrbitUI's own updater first.
Beta 1 and earlier cannot detect root changes while running an older OTA slot.
The stable bootstrap and API 1 remain byte-identical; no manual bridge is needed.

When an app store or manual **release ZIP** subsequently overwrites the plugin
root while an OTA slot is selected, OrbitUI checks the root VERSION after healthy
startup. Only a strictly newer semantic version is considered. An older factory
copy, equal version or pending activation is left alone. Source-code ZIPs without
a sealed manifest are not supported. The app store must preserve hidden version
directories; an installer that deletes the whole plugin removes rollback too.

Verification copies only manifest-listed files into an inactive snapshot, bounded
by the normal file/count/size limits. It rejects links (including parent-directory
links), altered/truncated files, incompatible bootstrap files and invalid Lua.
It verifies the copied snapshot against the manifest before selecting it. No
candidate code executes during preparation. Unlisted root files, user settings,
ornaments and reading data are neither imported nor removed.

The main process then selects `.orbitui-versions/<manifest-sha256>/` with the
current OTA slot as rollback. An **additional restart** is required and offered;
the current session keeps its old runtime. Later root overwrites cannot mutate
the selected snapshot. The normal pending-boot recovery remains in force.

`.orbitui-external-attempt` records the candidate before activation so startup
failure or manual rollback cannot create an automatic update loop. If interrupted
between recording and activation, the old runtime stays selected. Use **Retry
external installation** in the update menu after checking the installed ZIP to
retry explicitly. Interrupted preparation can be retried without a new download.
The verifier checks integrity, not an independent signature; only install trusted
release ZIPs. It cannot protect bootstrap files already overwritten by an external
installer, nor retroactively recover a factory installation with no retained slot.

Headless coverage includes corrupt/incomplete files, unsafe paths/links, unchanged
and older factory versions, cancelled/stale activation, failed startup and manual
rollback. Real app-store/device installation and the extra restart still need
acceptance testing. Keep using the built-in updater as the recommended path.

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
or its settings. On beta 1 and earlier, manually replacing the factory ZIP also
requires renaming the old activation record while KOReader is stopped. After
external-update support is installed, prefer its verified import/restart instead.

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
