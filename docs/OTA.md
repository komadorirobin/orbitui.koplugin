# OrbitUI releases and OTA

## First installation

Download **orbitui.koplugin.zip**, not GitHub's source-code archive, from an
OrbitUI release. Follow `MIGRATION.md`: back up settings and patches, disable
standalone Bookshelf and SimpleUI, restart, install OrbitUI and restart again.
The original standalone OTA channels are not redirected or modified.

## OrbitUI 1.1.0-beta.10

Published **2026-11-08 19:28:20 UTC**, release **438466180**, frozen source/tag
**65bad370 / v1.1.0-beta.10**. Public ZIP SHA-256
`83157ee1f0801e0d5173053b0e2e3c6812b2582c6716583f46ef09294893f679`
(9,625,340 bytes), manifest **d09ba311**, exact 2,000 paths. Both full scripts/
43 catalogs, sealed/native/menu/frozen Silverfish/source/history/secrets gates
and all four main/tag CI jobs **42514809970 / 42514810638** pass; all four
payloads match every frozen file. Draft/public assets match exact bytes.
Thirteen actual old installers pass offline; twelve also pass anonymous public-
HTTPS upgrade/recovery, including beta.9. All 94 older releases/163 tag refs and stable/latest/
maintenance1.0 unchanged. Preview/public dist is beta.10. No actual device/
server/catalog operation; physical Bigme/full-plugin acceptance remains pending.

User-requested preview release from 8b40cb29, including the locally tested
optional reading companion and dashboard add/remove feedback fixes. No new
upstream merge, component/pin import, artwork, bootstrap/API1, server or device
change. Stable/latest1.0 and all previously published tags/assets stay fixed.

Dashboard source additions show a saved confirmation and BookOrbit checkmarks.
Repeated picker taps on the same account/section/id cannot create another card
on this screen. Existing duplicates and independent low-level placements are
retained, not automatically removed. Remove card is one deliberate action,
with feedback and return to the rebuilt list; stale controls cannot remove a
replacement reusing its row id. Failed saves/full/future layouts never show
success. Healthy empty BookOrbit sources and usable offline caches no longer
receive a false Unavailable label from optional-plugin registry resolution.

Add **Currently reading + Silverfish** through **Reading dashboard > + > Home
modules (SimpleUI)** or the ordinary Home module picker. It is a separate
opt-in choice with KOReader's cover/title/author/progress/resume and the active
companion's name/stage/sprite. Tap book to resume, companion to open Silverfish.
Continue reading and existing placements remain unchanged. Requires separately
installed/enabled public **Silverfish 2.0.0** and restart; unreviewed versions
explain why instead of calling guessed APIs. No plugin fork/file edit, copied
art, save reads/writes or duplicate progression. Colours follow its native
renderer/KOReader setting. Late and absent covers use native completion/change
polling; visible-page refresh reuses the existing minute owner.

**Svenska:** BookOrbit-kort får kvittens och källorna en bock när de lagts till.
Upprepade tryck skapar inga dubbletter. Ta bort kort återgår direkt till den
uppdaterade listan och visar kvittens; ingen extra borttagningsmeny behövs.
Felaktig Inte tillgänglig-märkning är rättad. Befintliga dubbletter är orörda.
Det nya valfria **Läser just nu + Silverfish** kombinerar bokomslag/läsprogress
och din aktiva figur. **Fortsätt läsa ersätts inte.** Lägg till under
**Läsöversikt > + > Hem-moduler (SimpleUI)**; Silverfish 2.0.0 behöver vara
installerat och aktiverat separat. Ingen fork eller ändring av sparfiler.

Update via preview and restart KOReader; back up settings/reading data
separately. Code rollback never reverts settings or third-party data.
Dashboard v2/v3 downgrade limits from beta.6/7 remain. Exact 2,000 installed
paths/API1 are retained; a pure drill-rekey helper becomes an exact-source lazy
embed to offset the new adapter (28 helpers/407 canonical identities).
Both full interpreters/43 catalogs, frozen sealed/native/menu/Silverfish,
actual older installers, source/history/artwork/secrets, exact main/tag CI and
downloaded draft/public bytes/channel checks precede activation. No full-plugin
or physical Bigme font/touch/colour/night/wake/rotation acceptance is implied;
those checks remain pending. No live BookOrbit-server or real-device operation.
Evidence: test-results/preview11-beta10-20261108; verification receipts follow.

## OrbitUI 1.1.0-beta.9

Published **2026-11-08 16:54:56 UTC**, release **438380489**, frozen source/tag
**3632d18d / v1.1.0-beta.9**. Public ZIP SHA-256
`d171ea5f26640fde4076537d82f85fe8895251cef72984ae9012ce65a102d105`
(9,609,810 bytes). Both full scripts/43 catalogs, frozen sealed/native/public
Home API/source/history/secrets gates and all four main/tag CI jobs
**42501824036 / 42501823791** pass; all four payloads match every frozen file.
Downloaded draft/public assets are exact. Twelve actual old installers pass
offline; eleven pass anonymous public-HTTPS upgrade/recovery, including beta.8.
All 93 older releases/161 tag refs and stable/latest/maintenance1.0 unchanged.
Preview/public dist is beta.9. No physical device/plugin install, server or
independent catalog operation; full-plugin/Bigme acceptance remains pending.

User-requested preview bugfix release from cfebd307, preserving the locally
tested Silverfish placement fix f60bcf98. No new upstream merge, component/pin,
plugin archive/save, bootstrap/API1, artwork, server or device operation.
Stable/latest1.0 and previous tags/assets remain unchanged.

New explicit Silverfish Home additions become a SimpleUI card inside Reading
dashboard, not a sibling after that full-height module. On ordinary Home, use
a new page unless matching live portrait geometry proves room. Fresh registry
defaults are opt-in in memory only; saved native/legacy/Custom Screen choices
and existing dashboard titles/size/hidden/order are preserved. Silverfish's
public Home getter/add/off recognizes the dashboard card across restart and
avoids duplicates. Native layout APIs still own order, enable flags and refresh.
No builds/scans/network for placement, private fork, pet save modification or
screensaver takeover. Existing manually placed cards are deliberately not moved.

**Svenska:** Nya Silverfish-kort hamnar i Läsöversikt, inte under den i docken.
På vanligt Hem får kortet en egen sida om det inte säkert finns utrymme.
Redan sparade placeringar och anpassningar behålls, liksom alla Silverfish-data
och skärmsläckarval. Hem-valet fungerar för på/av och omstart utan dubletter.
En gammal överlappande placering rättas inte automatiskt: ta bort och lägg till
kortet igen, eller justera placeringen manuellt. Inget plugin installeras om.

Update through preview and restart KOReader. Back up settings/reading data
separately; code rollback does not undo settings or third-party data. Dashboard
config v2/v3 retains the downgrade limits described in beta.6/7. Exact 2,000
installed paths, 27 lazy helpers/407 identities and bootstrap/API1 unchanged.
Both full interpreters/43 catalogs, frozen sealed/native/frozen Silverfish
methods, actual older installers, source/history/artwork/secrets, exact main/tag
CI payloads and draft/public-byte/channel checks precede activation. Only the
native adapters/public Home methods were desktop-tested, not the full plugin
or actual Bigme drawing/touch/wake/rotation. Physical acceptance remains pending.
Evidence: test-results/preview11-beta9-20261108; TESTING/MERGE_LOG receipts follow.

## OrbitUI 1.1.0-beta.8

Published **2026-11-08 15:06:47 UTC**, release **438317954**, frozen source/tag
**564243a0 / v1.1.0-beta.8**. Public ZIP SHA-256
`fd4d58e180ef2e3420d6c55da4a95f89871225dca1f321b9887bad83841016d2`
(9,601,664 bytes). Full dual-interpreter/43-catalog/sealed/native/source/
history/secret checks and all four main/tag CI jobs **42492684427 /
42492684728** pass; every CI payload file matches. Draft/public downloads are
exact. Eleven actual old installers pass offline; ten also pass anonymous
public-HTTPS upgrade/recovery, including beta.7. All 92 older releases/159
tag refs and stable/latest/maintenance1.0 remain unchanged. Preview/public dist
is beta.8. No physical device/plugin install or BookOrbit-server operation.

User-requested preview bugfix release from d76326f7; no new upstream merge.
Fixes the blank BookOrbit sources after refresh, an uncaught error when
reopening cached sources, the empty Module library, and the row/carousel
chooser. Three numeric loop indices shadowed the translator. The device log
confirms the exact module-store error in published beta.7. Eight native menu
regressions reproduce failures against frozen beta.7 and pass with the fix
in Swedish and English; protected-show tests now require completed builds.

**Svenska:** Fixar den tomma BookOrbit-källistan efter hämtning, kraschen när
sparade källor öppnas igen, det tomma Modulbiblioteket och valet omslagsrad/
karusell. Orsaken var tre loopvariabler som skymde översättningsfunktionen.
Din logg bekräftar modulbiblioteksfelet. Befintliga källor, kort, inställningar
och plugindata bevaras. Inga ändringar av server, synk eller installationsregler.

Update via preview and restart KOReader; back up settings and reading data
separately. Source cards retain config v3's downgrade limitations described
in beta.7. No cache reset, component/pin/art/bootstrap/API1 or data change.
Stable/latest 1.0 and all earlier tags/assets stay immutable; 27 exact lazy
helpers / 407 identities and 2,000 installed paths remain. No device install
or BookOrbit-server operation. Full dual-interpreter, catalogs, sealed/native,
actual older-installer, source/history/secrets, exact main/tag CI and downloaded
draft/public bytes/channel checks precede activation. Physical Bigme retesting
is still pending; automated fixtures are not real-device acceptance.
Evidence: test-results/preview11-beta8-20261108; TESTING/MERGE_LOG retain receipts.

## OrbitUI 1.1.0-beta.7

Published **2026-11-08 14:21:06 UTC**, release **438291937**, frozen source/tag
**c9366f52 / v1.1.0-beta.7**. ZIP SHA-256
`c5befabd597cbb6811d17c8c48aa852902d3d3e269a6526f06b94fe7c9b5fc17`
(9,597,006 bytes). Both full scripts/43 catalogs, sealed/native/frozen API/
source/history/secrets checks and all four main/tag CI jobs
**42488973659 / 42488973545** pass. Every file from all four CI payloads matches;
downloaded draft/public assets are exact. Ten actual older installers pass
offline native upgrades/recovery; nine also pass anonymous public-HTTPS paths,
including beta.6. All 91 old releases/157 old tag refs and stable/latest/
maintenance1.0 remain unchanged. Preview/public dist is beta.7. No real-device
or BookOrbit-server test/installation is performed.

User-requested preview publication of the locally built BookOrbit source cards,
starting at 72190eaa. No new upstream merge, independent module-catalog release,
server change or device/plugin installation. Stable/latest 1.0.0 and all earlier
published tags/assets remain immutable. Bookshelf c014b133 / SimpleUI 4426601f
and all component bytes, artwork and API1/bootstrap stay fixed.

Add independent cards through **Reading dashboard → + → BookOrbit shelves and
smartscopes → Refresh shelves and smartscopes**. Choose a library, shelf or
smartscope from the connected BookOrbit catalog. Several cards, custom titles,
half/full/tall/page sizes, cover rows or a one-cover carousel, native book
tap/hold and independent swipe/arrow paging. The server evaluates rules; only
exact stable BookOrbit-linked files already on this device are shown. Unlinked
copies are not guessed and server-only books are not downloaded. No new extras
server extension, reading-status/progress writes, directory/manifest scan or
automatic Wi-Fi activation. A native catalog/subprocess-capable BookOrbit plugin
and server are required; unsupported versions give a reason rather than block.

Cached results appear immediately without constructing a client or sweeping
files in widget build/paint. Visible cards refresh asynchronously with a
15-minute success TTL; failed automatic attempts back off one minute. Request
coalescing, bounded complete pagination and account/policy/map/mount/sleep guards
keep retired requests from committing. Only the requesting row subtree redraws;
other modules and timers stay mounted. A definite removed/inaccessible source
suppresses its saved membership. Cached results survive transient errors and
disable. **Integrations → BookOrbit → BookOrbit shelves and smartscopes** is
separate from Want to Read and the external plugin's own sync preferences.

**Svenska:** Lägg till flera egna kort via **Läsöversikt → + → BookOrbit-hyllor
och smartscopes → Uppdatera hyllor och smartscopes**. Välj källa och justera
rubrik/storlek eller omslagsrad/karusell via rubriken eller långtryck på kortets
bakgrund. Bara BookOrbit-länkade böcker som finns på enheten visas. Servern
utvärderar reglerna; inget laddas ned, ingen lässtatus skickas och inget nytt
extras-servertillägg behövs. Sparade träffar visas direkt, synliga kort uppdateras
i bakgrunden högst var 15:e minut och bara det berörda kortet ritas om.
Av/på finns separat under Integrationer → BookOrbit. För gammalt plugin/server
ger förklaring; OrbitUI slår inte på Wi-Fi. Svenska och engelska finns.

Update via **preview** and restart KOReader. Back up settings and reading data
separately. Explicitly adding a BookOrbit card opts that screen into dashboard
config v3: beta.6/older fail closed and preserve it, rather than silently dropping
new source selections. Code rollback does not revert layout/cache or third-party
data; restore a matching settings backup to edit that page on older code.
Existing v1/v2 layouts remain unchanged until adding a new source card.
One new adapter path is balanced by lossless lazy embedding of the existing
folder-label helper: 27 helpers/407 canonical identities, 2,000 installed files,
unchanged API1/bootstrap. No existing settings, links or reading-data reset.

This is a prerelease. Full Lua/LuaJIT, 43 catalogs, sealed/native/frozen BookOrbit
methods, old-installer/source/history/artwork/secrets and main/tag CI gates must
pass before verified draft/public-byte activation. Physical Bigme and live-server
source/membership/link coverage, menus/day/night, suspend/read-return and measured
start/latency/RSS remain unverified. No device speed or universal server
compatibility claim. Evidence: test-results/preview11-beta7-20261108;
TESTING/MERGE_LOG retain results and the exact frozen source.

## OrbitUI 1.1.0-beta.6

Published **2026-11-08 12:56:30 UTC**, release **438244122**, frozen source/tag
**26924cc2 / v1.1.0-beta.6**. ZIP SHA-256
`a198828f4c48110b5b3d9084376f46971e1da4c299f359b7cb65e5942cc81746`
(9,580,403 bytes). Full/sealed/native/translation/source/history/secret gates
and all four main/tag CI jobs **42482149058 / 42482148698** pass. Both CI-built
payloads match all files; downloaded draft/public bytes are exact. Nine old
actual installers pass native upgrades/recovery; eight also pass anonymous
public-HTTPS scenarios, including beta.5. All 90 older releases/155 previous tag
refs, stable/latest 1.0 and maintenance/1.0 remain unchanged. Preview/dist is
beta.6. No physical-device/server/plugin installation is performed.

The separate observation-only inspiration watch flags a diverged Kobold source
history, not a runtime/build failure; its reviewed baseline is retained for
manual review. No new source import or automatic baseline reset is implied.

User-requested preview release of the previously local dashboard-module,
curated-catalog and thumbnail-reuse work, plus the already reviewed November 7
upstream/settings/search improvements on main. No additional upstream merge,
server deployment or device installation is part of this publication. Stable
1.0.0/latest and all previously published tags/assets remain unchanged.

- Reading dashboard: add compatible SimpleUI/Bookshelf cards or native action
  shortcuts through + or Cards and content > Add module. Arrange, resize,
  hide/remove and independent pages support up to 16 added cards per screen.
  Keep ordinary Home layouts/book actions; refresh only the requesting visible
  card and retire its callbacks/minute hooks across page/close/sleep.
- Get more modules opens the curated Module library, initially official
  Silverfish 2.0.0. Explicit first install, pinned archive/hash/source/license
  disclosure and restart; never overwrite/adopt/enable an existing plugin or
  reset its data. Updates/removal remain manual. The badge means desktop
  adapter testing only, not full-plugin safety or physical Bigme certification.
  No Silverfish code/art is bundled. An independent catalog is supported but
  has not been published; its explicit check retains the bundled entry.
- Native cover thumbnails: bounded LRU-derived copies no longer strongly pin
  larger sources; external covers reuse warm downscales. Native cache/contrast/
  source teardown invalidates derived copies. Desktop repeat-render fixtures
  reduce scaler calls from 20 to 1; this is not a measured device speedup.
- Optional Word suggestions in Search OrbitUI, OFF by default, complete the
  final word from cached local titles/authors/series without typing-time scans
  or network. Already reviewed Bookshelf 6.3.3 and SimpleUI 3.0.3 include cover-tab
  refresh/feedback fixes, native facet ordering and collection arrange choices.

**Svenska:** Läsöversikt får +/Lägg till modul för kompatibla pluginkort och
åtgärdsgenvägar. Ändra storlek, ordna/dölj/ta bort kort och använd egna sidor.
Hämta fler moduler öppnar Modulbibliotek med versionslåst Silverfish 2.0.0.
Installation kräver bekräftelse och omstart; befintliga plugins/sparfiler lämnas
orörda. Uppdatering och avinstallation görs manuellt. Bara adaptrarna är testade
på dator, inte hela pluginet på Bigme. Silverfishs eget gränssnitt är engelska/
portugisiska; OrbitUIs katalog och reglage finns på svenska och engelska.
Omslagens miniatyrer återanvänds bättre utan att hålla stora original i minnet;
ingen hastighetsvinst på enheten är ännu uppmätt. Valfria Ordförslag är avstängda
som standard. Tidigare granskade upstream-fixar följer också med; ingen ny
upstream-merge eller serverdriftsättning görs i denna publicering.

Update from beta.5 through the preview channel and restart. API1/bootstrap
stay fixed at 2,000 installed files, using 26 exact lazy helper sources/407
canonical identities. Preserve separate settings/reading-data backups: adding
dashboard cards opts that screen into config v2, which older builds cannot
edit but must preserve. Code rollback does not undo layout or third-party data
migrations and does not uninstall a separately installed plugin. Existing source
headings, profiles, ornaments, sync ownership and plugin saves are retained.
Physical Bigme module/install/lifecycle/UI and real opening-time/RSS checks
remain outstanding. This is an experimental prerelease, not stable 1.1.

Full dual-interpreter, translation, sealed/native/archive/older-installer,
source/history/artwork/secrets, main/tag CI, draft/public-byte and channel checks
precede public activation. Evidence: test-results/preview11-beta6-20261108;
TESTING/MERGE_LOG retain the exact candidate and physical limits.

## OrbitUI 1.1.0-beta.5

Published **2026-11-07 17:17:30 UTC**, release **437717781**, frozen source/tag
**38cadd99 / v1.1.0-beta.5**. ZIP SHA-256
`2cc94f4fc3596627f5e49ee7449b7889e00b01c2110adb94b01eb2f399d1eb03`
(9,514,172 bytes). Both complete scripts/catalogs, sealed/native/old-installer/
history/secret gates and all four main/tag CI jobs **42395143967 / 42395143921**
pass. CI-built runtime manifest matches; downloaded draft/public bytes are
exact. All 89 old releases/153 previous tag refs, stable/latest 1.0 and
maintenance/1.0 remain unchanged. Preview/public dist is beta.5. Seven older
actual installers also pass public-HTTPS upgrade/recovery scenarios (TESTING).
Physical Bigme confirmation remains outstanding.

User-approved preview correction for beta.4's active but invisible letter strip.
Its old layout estimated height from point size, while actual TextWidget line
metrics and default vertical padding exceeded the slot; oversized text was
silently skipped. Own labels now use padding=0, measured regular/bold heights
determine stride, and bounded cached width/height fitting covers normal and
selected labels plus large feedback. Touch mapping, right-margin/content
geometry, sorting/filtering, lifecycle and data producers are unchanged.
The exact beta.4 adapter fails a visible-text assertion with actual minimum/
current KOReader TextWidget and FreeType metrics from bundled Inter; the fix
passes. Native shaping and the user's physical Bigme output remain unverified.

**Svenska:** Fixar att bokstavslisten kan reagera på dragning utan att bokstäverna
syns. Den gamla beräkningen missade typsnittets faktiska höjd och textmarginaler;
för stor text ritades inte. Nu mäts texten och storlek/radavstånd anpassas, även
för markerad bokstav och den stora återkopplingen. Pekytor, hyllans utrymme och
sortering/filter ändras inte. Automattestet återskapar felet i beta.4 och passerar
med fixen; synligheten behöver fortfarande bekräftas på riktig enhet.

Preview only, no additional upstream merge, component/source-pin/bootstrap/API1/
asset/sync/data change or device/server deployment. Stable/latest 1.0 and all
older versions remain immutable. The strip stays opt-in with SV/EN controls.
Both complete scripts/catalogs, exact source/package/sealed/native/older-OTA/
history/secrets, main/tag CI and draft/public-byte/channel gates precede
publication. Evidence: test-results/preview11-beta5-20261107; TESTING/MERGE_LOG.

## OrbitUI 1.1.0-beta.4

Published **2026-11-07 15:33:18 UTC**, release **437660137**, frozen source/tag
**b65e9098 / v1.1.0-beta.4**. ZIP SHA-256
`b5692f542d895e3390f42d317d515aff91fcf7e8b1000ff449fb17e0e4e71c91`
(9,509,281 bytes). Main/tag CI **42386627139 / 42386627270**, full/sealed/
native/local-installer gates, draft/public bytes, preview/stable/latest selection
and all 88 older releases/151 old tag refs pass. CI's built runtime manifest
matches the frozen package. Public dist is beta.4; stable/latest 1.0 and its
maintenance branch are unchanged. Six older actual installers also pass public-
HTTPS upgrade/recovery scenarios (TESTING).
No user-device/server action or new physical acceptance.

User-requested preview release of the independently implemented alphabet strip.
OFF by default, per existing view: footer counter ▾ > Sort, filter & view >
Alphabet strip. Tap a letter or drag to preview a large letter, then release to
jump in the current native sorted/filtered list. Å/Ä/Ö are distinct; other Latin
accents use the base letter, untransliterated scripts/numbers use #. Native
article/curated keys, module visual slots and spine item cursors are preserved.
No reading/metadata/cover/index/network work or shelf rebuild during dragging;
the explicit jump can query cached native metadata. No new index or worker.

The strip occupies spare right-margin space, not cover/content width. Hide it
for nonalphabetical, one-page, opened-series, remote, two-column and too-tight
contexts. Current-owner/nav-generation/dimension guards cancel stale gestures
on rebuild, reader/menu interruption, sleep and rotation. Monochrome feedback
follows native page paint space. Native input/raster tests are not physical
font shaping, ghosting, drag ergonomics or Bigme performance acceptance.

**Svenska:** Valfri **Bokstavslist**, avstängd som standard. Aktivera per vy via
**sidräknaren ▾ > Sortering, filter och vy > Bokstavslist**. Tryck på en bokstav,
eller dra för att visa en stor bokstav och släpp för att hoppa i samma sorterade/
filtrerade hylla. Å/Ä/Ö hålls isär. Dragning läser ingen metadata och bygger inte
om hyllan; ett uttryckligt hopp kan fråga den befintliga metadatacachen. Listen
använder ledig högermarginal och döljs när vyn/sorteringen saknar stöd. Ingen ny
indexering startas. Svenska/engelska finns; gester, typsnitt, nattläge, rotation,
vila/återgång och kalla/varma hopptider behöver fortfarande enhetstestas.

Stable/latest 1.0.0 and all older tags/assets stay immutable. No new upstream
merge: Bookshelf d47edfcc / SimpleUI 4bf2d2c5, provenance and component files
unchanged. API1/bootstrap, 2,000 paths, artwork, reading data, existing settings
and sync owners remain. No device/server deployment. Full/sealed/native/older
installer, source/history/secrets, CI and exact draft/public/channel gates are
required before publication; receipts: TESTING/MERGE_LOG and
test-results/preview11-beta4-20261107.

## OrbitUI 1.1.0-beta.3

Published 2026-11-05 11:01:37 UTC, release 435083775, frozen source/tag
`cac8233a` / `v1.1.0-beta.3`. ZIP SHA-256
`dbaa735a634072aaf79f0d260dd9b43442602ce59bb651255a6fa251b1cbdb97`
(9,495,686 bytes). All main/tag CI jobs, exact draft/public bytes, old-release
immutability, channel selection and five actual older public-HTTPS installer
scenarios pass; full verification is in TESTING. Preview only; stable/latest
1.0.0 remains unchanged. Physical acceptance remains separate.

Preview only, after the user's explicit merge/publication request. Stable 1.0.0
and all older tags/assets remain unchanged. Includes the previously local
Series / Volumes tag-results feature: remember the tab per origin library,
default Manga to Series, keep standalone/unknown-metadata rows and group only
checked matching volumes by series/author/profile. Counts mean matching versus
locally indexed volumes, not the server's full series. Missing-first/unknown-order
warnings and the existing 400-volume match limit are explicit. Switching views
reuses the tag scan and bounded read-only cached metadata. A series tap reveals
the first available locally indexed volume in the proper native shelf/series
preview, even if that volume lacks the tag; it never opens ReaderUI.

SimpleUI integrates two reviewed commits through `4bf2d2c5`: foreign menus no
longer update the navbar subtitle/arrows, avoiding competing refreshes. File
chooser/injected menu paging remains native. The added incompatible cover-icon
patch entry is retained as upstream source only: OrbitUI's canonical/legacy
compatibility shim still cannot rename/disable patches. Bookshelf remains
`d47edfcc` (already caught up). API1/bootstrap, 2,000 installed paths, artwork,
settings/reading data and all sync owners remain unchanged. No device/server
deployment or measured Bigme speedup. Physical SV/EN, rotation, sleep/indexing,
series-preview/filter and menu refresh acceptance remain outstanding.

**Svenska:** Ny förhandsversion med **Serier / Volymer** i taggträffarna. Manga
visar Serier som standard och valt läge minns per ursprungsbibliotek. Fristående
böcker och okänd metadata hålls synliga; antal gäller lokalt indexerade volymer,
inte en komplett serverkatalog. Varningar visas när första volymen eller ordningen
saknas i metadata. Ett tryck markerar första tillgängliga indexerade volymen i
rätt serie/bokhylla, utan att öppna boken. Flikbyte gör ingen ny taggskanning.
SimpleUI hindrar orelaterade menyer från att rita om nederlisten. OrbitUI ändrar
inte dina patchval. Bookshelf är redan ikapp. Stabil 1.0, läsdata, inställningar,
bilder och synkägare behålls. De nya vyerna behöver provas på riktig enhet.

## OrbitUI 1.1.0-beta.2

Supersedes the never-published beta.1 draft. A final reproduced picker race
showed a delayed page selection overriding an explicit card/header choice.
Direct choices now cancel that timer; callbacks after Close cannot arm new work.
Beta.1's pushed tag stays unchanged; no beta.1 release/OTA was published.

**Svenska:** Ersätter det aldrig publicerade beta.1-utkastet. Ett sista test
återskapade hur ett väntande sidval kunde skriva över ett manuellt val i
bakgrundsväljaren. Manuella val avbryter nu timern; stängda vyer startar inga nya
jobb. Den pushade beta.1-taggen flyttas inte och ingen beta.1-OTA publicerades.

Separate preview cycle after stable 1.0.0; not a replacement of its runtime or
assets. Bookshelf 53 commits through `d47edfcc` (6.3.2), SimpleUI five through
`633ffbff`, imported separately with full ancestry. Publication-year sort/tokens
and local display-date editing, the revised book menu, wallpaper Stretch/Crop
to fill/Fit to screen and miniature-screen previews join fixes for stale series
metadata, filtered-folder queries, cover refresh and retained facts/spine colours.
Cover Deck budgets non-Latin titles more conservatively; Critter adds shadows.
Upstream performance measurements are not OrbitUI/Bigme measurements.

Hosted safeguards: retain cancellable blob-free metadata windows and profile
scope instead of upstream's blocking whole-table refresh; revalidate completed
memory against BIM and retire group caches after refresh. The unowned automatic
publication-date fork queue is deferred on all hosted platforms: existing cached,
Hardcover/calibre/OPDS and user dates work, but missing file dates explain the
deferral rather than showing endless Checking. Explicit date edits affect local
display facts, not EPUB metadata/sidecars/server status. New folder deletion is
not offered by OrbitUI because native cleanup removes sidecars before a fallible
folder purge. Standalone component fallback remains intact. Wallpaper timers
retire on tab/page/close; extreme fit allocations are bounded.

All new owned labels/help are SV/EN. Two new helper sources are exact lazy
embedded strings, keeping all 2,000 API-1 paths/bootstrap/assets/languages and
canonical/preload aliases. Existing Home/Manga/profile/series/ornament settings,
reader-return and BookOrbit/Hardcover/MAL/patch owners remain. New facts columns
are additive; no database recreation or reading-data migration. No device/server
installation. Preview only; stable/latest remains 1.0.0. New UI, wallpaper/night,
year sort/date editing, full indexing and reader/sleep/return need physical tests.

**Svenska:** Separat förhandsversion efter stabil 1.0.0, inte ersatta stabila
filer. Bookshelf 6.3.2 och SimpleUI-fixar ger sortering efter utgivningsår, egna
lokala visningsdatum, ny bokmeny, bakgrundsskalning/förhandsbilder och fixar för
metadata, filtrerade mappar, omslag och bokryggarnas färger. Titlar med exempelvis
japanska tecken kortas säkrare i Cover Deck; läskompanjonen får skuggor.

Våra avbrytbara metadatajobb, profiler, bokmärken/läsdata, språk/bilder och
externa synkägare behålls. Automatisk datumläsning ur filer är uppskjuten; redan
kända datum och datum från Hardcover/Calibre/OPDS samt egna visningsdatum fungerar.
Okända datum förklarar begränsningen. Den nya mappraderingen erbjuds inte ännu,
eftersom misslyckad radering kan förlora sidodata. Bakgrundsväljarens sena anrop
stängs säkert och extrema bildallokeringar begränsas. Inga böcker, EPUB-taggar
eller serverstatusar skrivs av datumfunktionen. Endast förhandskanalen; stabil
1.0.0 behålls. Den nya vyn och livscykeln behöver testas på riktig enhet.

## OrbitUI 1.0.0

First stable release, explicitly approved after the user reports RC2 stable and
ready. The runtime implementation, components, artwork, bootstrap API 1 and
source pins are identical to RC2 (`e3aa55c8`). Only version/release documentation
and channel regression coverage change. Bookshelf stays `b512cd90`; SimpleUI
stays `fdf83c7d`. The observed upstream backlog is NOT part of stable 1.0.

Includes the connected Home/Reading dashboard and Library/Manga, configurable
profiles/navigation, shared details/search/settings, offline EPUB tag indexing
and tag shelves, optional ornament packs and separately owned integrations.
RC2's tag-dialog lifecycle/sleep pause and non-opening shelf-reveal fixes remain.
No book/sidecar/history/reset, new cache/settings migration, sync writer, server
deployment or bootstrap change. Optional BookOrbit status import stays
experimental and OFF by default, with its existing server requirement/guards.

Stable and preview channels may select 1.0.0 over RC2; preview may later select
1.1 betas while stable remains on 1.0.x. Restart KOReader after updating. Use
the full runtime ZIP, not GitHub's source archive, and back up first. Old release
assets/tags remain immutable. Package/source parity, both full interpreters,
translations and native older-installer activation/rollback/recovery are checked
again. General user acceptance of RC2 does not establish every historical
Bigme/Boox, 3,341-file index, on-device recovery or optional-service test; detailed
coverage and unrun scenarios stay explicit in TESTING.md.

**Svenska:** Första stabila releasen, godkänd efter att användaren bekräftat att
RC2 är stabil och redo. Samma funktionskod, komponenter, bilder, API-1 och pins
som RC2; upstream-nyheterna hålls till en separat 1.1-beta. Hem/Läsöversikt,
Bibliotek/Manga, profiler, taggar, bokdetaljer och integrationer fungerar som
tidigare. RC2:s fixar för paus/Stäng och markering på bokhyllan ingår.
Ingen ny läsdatamigrering, nollställning, synkägare eller serverdriftsättning.
BookOrbit-statusimport förblir experimentell och avstängd som standard.
Uppdatera via stabil eller förhandskanalen och starta om KOReader. Hämta hela
plugin-ZIP:en och säkerhetskopiera först. Godkännandet gäller RC2:s beprövade
användning, inte en ny certifiering av alla enheter eller testscenarier.

## OrbitUI 1.0.0-rc.2

**Release candidate, not stable 1.0.** Publishes the explicitly approved tag
lifecycle fix and tag-result navigation change, without another upstream merge.
Bookshelf stays `b512cd90`; SimpleUI stays `fdf83c7d`. Feature freeze continues.

- A retired tag search/index manager no longer leaves a permanently busy
  dialog with a dead Close. Closing uses its own visible lifetime, not the
  expired background-work generation. Unsafe actions are disabled with an
  explanation to reopen a changed view; stale work cannot adopt results.
- Sleep pauses offline tag search/indexing, keeps completed reads, releases
  derived index ownership and avoids painting while asleep. No automatic wake
  scan. Continue/Refresh reuses valid entries; reopen first if navigation changed.
- Tapping a title in offline or BookOrbit tag results selects the actual book
  on its Bookshelf profile/folder/page with cover/description, not ReaderUI.
  Repeated selection cannot open the book. Long-press still opens book details;
  other search/reader actions are unchanged. Missing/filtered targets fail safely.

Existing settings, caches, reading progress/history, artwork/languages and
BookOrbit/Hardcover/MAL/patch ownership remain. Status import retains its OFF
default and safety rules; no server is deployed. Bootstrap API 1 and exactly
2,000 installed paths are preserved. Old public releases/tags are immutable.
Update via **preview** and restart KOReader; stable must ignore RC2. Automated
and native headless tests do not close physical acceptance: verify sleep/wake
during all 3,341 EPUBs, pause/continue/Close, actual selected-cover/description
layout, cold/warm/parked transitions and on-device update/recovery on Bigme/Boox.
The exact cause on the user's device is not proven by the synthetic reproduction.

**Svenska: testkandidat, inte stabil 1.0.** RC2 innehåller den godkända fixen
och ändringen av titeltryck i taggträffar. Funktionsfrys gäller fortfarande;
ingen ny upstream-merge. Stäng fungerar även när bakgrundsarbetet blivit
inaktuellt. En ändrad vy förklarar att den behöver öppnas igen. Vila pausar
lokal taggsökning/indexering utan automatisk återstart; redan lästa taggar
behålls. Fortsätt/Uppdatera återanvänder giltiga poster.

Titeltryck i lokala eller BookOrbit-taggträffar visar och markerar boken på rätt
profil/mapp/sida i bokhyllan, med omslag/beskrivning, utan att öppna läsvyn.
Upprepade tryck öppnar inte boken; långtryck öppnar fortfarande bokdetaljer.
Övriga sök- och läsåtgärder är oförändrade. Saknade/filtrerade mål hanteras säkert.
Läsdata, inställningar, cache, bilder, språk och externa synkägare behålls;
ingen server ändras. API-1 och 2 000 installationsfiler är kvar. Använd
**förhandskanalen** och starta om KOReader. RC1 och äldre releaser ersätts inte.
Fysisk testning på Bigme/Boox återstår: vila under hela indexeringen av 3 341
filer, paus/fortsätt/Stäng, markerat omslag/beskrivning, kall/varm/parkering samt
riktig uppdatering/återställning. Automattester bevisar inte exakt vad som
utlöste felet på enheten och är inte ett godkännande för stabil 1.0.

## OrbitUI 1.0.0-rc.1

**Release candidate, not stable 1.0.** This starts a feature freeze for targeted
acceptance testing. The reviewed Bookshelf pin is `b512cd90` (documentation-only
follow-up after 6.2.0); SimpleUI stays `fdf83c7d`. No additional upstream import,
redesign, cache/settings migration or new synchronization owner.

Compared with Beta 29, **Integrations > BookOrbit > Import reading status >
Status check details** separates local-equal and unchanged server statuses,
missing files/reading data, protected entries, newer-local conflicts and statuses
not imported by policy. Same-day/unknown dates remain protected. Counts persist;
up to 50 sanitized basename/reason samples stay only in session memory. Legacy
reports ask for a new check rather than inventing a reason for old skips.
No guard is relaxed, no extra EPUB/sidecar work is added to report rendering or
the canonical-unchanged path, and no server/Hardcover write is introduced.
Status import stays experimental and OFF by default with the same server API
requirement; this release does not deploy that API or change native sync choices.

The unavailable Bookshelf-OS reference is removed from inspiration monitoring.
Kobold, CyberUI, VOS, ProjectTitle and Zen-OS retain their exact mappings/pins.
Historical attribution and existing settings-category cards/quick controls stay.
The separate stale-main upstream report guard is unchanged.

Home/Bento, Library/Manga profiles, opening/fast return, local tags/indexing,
shelves/series/artwork, optional add-ons and external plugin/patch ownership
retain their existing behavior. The stable API-1 bootstrap and exactly 2,000
installed paths remain; no original asset/language or old public release changes.
Once published, update through **preview**, then restart KOReader. Stable-channel
selection must ignore RC1. Fresh install, real-device OTA/recovery, complete
3,000+ book indexing, sleep/rotation/night/menu/stress and write-safe optional
integration checks are still outstanding. No physical-device sign-off or speed
improvement is claimed. See TESTING for the exact RC acceptance checklist.

**Svenska: testkandidat, inte stabil 1.0.** RC1 inleder funktionsfrys inför
riktad testning. Bookshelf är granskat till `b512cd90` (bara dokumentation efter
6.2.0); SimpleUI ligger kvar på `fdf83c7d`. Ingen ytterligare upstream-merge,
ny design, migrering eller synkägare. Under **Integrationer > BookOrbit > Hämta
lässtatus > Detaljer om statuskontrollen** skiljs oförändrat, saknade filer/
läsdata, skyddade poster, nyare lokal status och avsiktligt ej importerade statusar
åt. Osäkra datum skyddas fortfarande. Bara antalen sparas; högst 50 filnamn/
orsaker visas tillfälligt. Äldre rapporter behöver en ny kontroll för orsakerna.
Ingen extra bokskanning, uppluckrad skrivregel eller skrivning till server/
Hardcover. Statusimport är fortsatt experimentell, avstängd som standard och
kräver sitt separata servertillägg. Ingen server driftsätts av denna release.

Bookshelf-OS tas bort enbart ur inspirationsbevakningen. De andra fem källorna,
historiken, inställningskorten och snabbkontrollerna behålls. Hem/Manga, profiler,
taggar/indexering, boköppning/snabbåtergång, utseende, tillägg och externa plugins/
patchar ändras inte. API-1 och alla 2 000 installationsfiler, bilder, språk och
tidigare releaser behålls. När RC1 är publicerad: använd **förhandskanalen** och
starta om KOReader. RC1 ska aldrig väljas av stabila kanalen. Fysiska Bigme/
Boox-tester, full indexering av 3 000+ böcker, uppdatering/återställning och
säkra integrationstester återstår. En grön automattest är inte enhetsgodkännande.

## OrbitUI 0.1.0-beta.29

Beta 29 publishes the reviewed **Bookshelf 6.2.0** merge at `78f582fd`.
SimpleUI remains at `fdf83c7d`; no further upstream revision is imported.

- **Image contrast** adds optional cover/ornament/spine contrast boost and
  separate wallpaper contrast/brightness. All are unchanged/off by default.
  Adjustments apply once to retained image copies, not the original artwork
  or raw disk cache. Wallpaper controls also appear in **Theme > Wallpaper**.
- **Behavior > Footer bar** offers Show, Hide or Invisible buttons. Hide
  reclaims the space; Invisible keeps the button hitboxes without showing the
  buttons. Selection/key focus reveals the controls. OrbitUI's custom footer
  size, margins and navigation-bar geometry are retained.
- Menu/theme transitions request fewer full-screen flashes. Side swipes on
  the shelf outside a picker can turn the shelf page without closing it;
  tapping outside a slider commits its value. The X/Back still cancel it.
- Android night-mode rounded RGB paints keep consistent corners, including
  the software fallback. Existing OrbitUI night wallpaper/dock fixes remain.
  Stale wallpaper/menu restoration and face-out opening-shadow bugs are fixed.
- Explicitly configured shelf modules can update every minute. Hidden or
  replaced shelves cannot be refreshed by a late callback. Shared menu hooks
  are released with their host rather than remaining active after teardown.

Svenska: Beta 29 innehåller den granskade **Bookshelf 6.2.0**-uppdateringen.
SimpleUI är redan uppdaterat och inga ytterligare upstream-ändringar hämtas.
**Bildkontrast** ger valfri kontrastökning för omslag, ornament och bokryggar,
plus separat kontrast/ljusstyrka för bakgrunden. Standardutseendet ändras inte;
originalbilder och rå bildcache skrivs inte om. Under **Beteende > Nederkantens
knapprad** kan knapparna visas, döljas eller vara osynliga men fortfarande
tryckbara. Markering/tangentfokus visar dem igen. Egna storlekar/marginaler
och navigationsfältets placering behålls.

Meny- och temabyten ska ge färre helskärmsblinkningar. Svep på hyllan utanför
en dialog kan byta sida bakom dialogen. Ett tryck utanför ett reglage sparar
värdet; kryss/Bakåt ångrar fortfarande. Förbättrad hantering av runda färgade
hörn i Android-nattläge, bakgrunder, menyåterställning och skuggor när böcker
öppnas. Valda hyllmoduler får minutuppdateringar bara medan rätt hylla visas.
Ingen ny uppmätt hastighetsförbättring på Bigmen utlovas.

Existing Home/Bento, Manga profiles, series artwork/aspect, tags/indexing,
ornament add-ons, reading data and BookOrbit/Hardcover/MAL/patch ownership stay
intact. Optional BookOrbit status import remains OFF by default and still
requires its separate server extension; this release deploys no server.
All owned new controls/help are Swedish and English. Exactly 2,000 installed
paths and the stable API-1 bootstrap are retained. Earlier public assets/tags
are immutable. Update through the preview channel and restart KOReader.
Still a prerelease: the new contrast/footer/swipe/menu/minute behavior has no
fresh physical Bigme/Boox acceptance. See TESTING for verification and gaps.

## OrbitUI 0.1.0-beta.28

Beta 28 imports Bookshelf master through `0d976875` (after 6.1.1), adding
publication years for OPDS 1.x/2.0 catalog books through `%calibre{pubdate}`.
It prefers publication-specific fields over an Atom date-added value and
preserves the first known year when editions merge. SimpleUI stays at
`fdf83c7d`. Existing Home/Manga profiles, fast close/return, shelves, tags,
ornaments and external integrations retain their behavior.

**Experimental, off by default:** **Integrations > BookOrbit > Import reading
status from BookOrbit** checks already matched device books after Home or a
shelf is visible, at most every 15 minutes. The page has Update now and last
successful check. It requires the separate `read-statuses v1` server extension
for exact BookOrbit 3.6.0, now published in
[BookOrbit Extras 0.3.0](https://github.com/komadorirobin/bookorbit-extras/releases/tag/v0.3.0).
An administrator installs it separately. The reviewed Littex server build was
deployed after this beta's publication; the client remains OFF by default.
Updating OrbitUI alone does not provide server support on other installations.

The importer only reads the server. It preserves page position, history,
ratings/reviews and existing BookOrbit/Hardcover sync preferences. Open/parked
books, pending Undo, newer local status, ambiguous same-day changes and
competing metadata copies are protected rather than resolved automatically.
Unread/Want to Read never reset a local read. Work is deferred and bounded;
unchanged canonical statuses require no sidecar reads/writes. No EPUB scan,
cover work, forced Manga rebuild or new remote status/progress writer.

Svenska: Beta 28 hämtar senaste Bookshelf-ändringen: utgivningsår för
OPDS-katalogböcker via `%calibre{pubdate}`. SimpleUI är redan uppdaterat.
Under **Integrationer > BookOrbit > Hämta lässtatus från BookOrbit** finns en
experimentell funktion, **avstängd som standard**, som kontrollerar redan
kopplade böcker högst var 15:e minut efter att Hem/hyllan visas. Kräver det
separata servertillägget `read-statuses v1`, nu publicerat i BookOrbit Extras
0.3.0. Det separat granskade Littex-bygget driftsattes efter betans publicering;
funktionen i läsaren är fortfarande avstängd. Andra servrar kräver separat
administratörsinstallation. Enbart OrbitUI-uppdateringen räcker inte för det.
Öppna böcker, väntande ångring och osäkra/nyare lokala ändringar skyddas.
Sidposition, historik, betyg, recensioner och externa synkinställningar behålls.
Ingen server, EPUB-fil eller gammal release ändras av uppdateringen.

Update via the preview channel and restart KOReader. All new controls/help
are Swedish and English. The 2,000 installed paths and API-1 bootstrap remain
unchanged. This is a prerelease: latest OPDS/status changes have no fresh
physical Bigme/Boox acceptance or measured startup/return speedup. See TESTING
for exact automated/sealed/native OTA evidence and remaining device gates.

## OrbitUI 0.1.0-beta.27

Beta 27 publishes the offline EPUB-tag index/search and smart-chip follow-ups,
plus the locally verified Android app-paging/native-dialog and metadata-cover
fixes after Beta 26. No new upstream import: Bookshelf remains **6.1.1**
(`c686f5a3`), SimpleUI `fdf83c7d`. Existing settings, caches, reading data and
external BookOrbit/Hardcover synchronization ownership are retained.

- **OrbitUI settings > Bookshelf > Tags and indexing**: Update checks all
  configured library roots at the saved scan depth, reusing unchanged entries
  and retrying failures. Confirmed **Reread all EPUB tags…** reads every EPUB
  afresh, useful after bulk retagging. This explicit job has no 400-file cap.
  Pause/Continue works after restart; closing the page pauses. Resume starts a
  new checked counter but reuses unchanged successful reads from that same run.
  Keep KOReader open while it runs; pause before replacing EPUBs. Failed files
  are counted separately and never cached as an empty successful result.
- Long-press a local EPUB tag in **Tags** to save a named smart chip in an
  existing library. Combine up to 16 literal tags with **AND/OR**, scoped to
  that library or all local libraries. Cached indexed matches render without
  opening EPUB archives; explicit Update reads missing/changed entries.
  Result views remain capped at 400 matches and disclose **400+**, even though
  the separate indexer can process thousands of files. Rename/order/Home pins
  and native sorting/filtering/pagination remain available.
- Local tag search uses a separate disposable SQLite index, bounded batches
  and progressive checked/total results with Stop/Refresh. Native touch gets
  an input window after visible updates, so slow archive scans stay stoppable.
  Existing tagless success rows and completed work survive cancellation.
- Android app lists with page arrows no longer crash on the native pager's
  extra return value. Explicitly owned native progress dialogs are not replaced
  by a toast. Explicit Android metadata refresh uses the transactional no-fork
  cover queue regardless of the automatic safe-mode preference, retaining
  existing covers on extraction failure. The saved preference is not changed.

Offline tags mean EPUB 2/3 **`bookorbit:tags` JSON**, not ordinary subjects,
genres or KOReader collections. No BookOrbit account, plugin or API patch is
needed for these offline features. No EPUB/reading-state write, cache reset,
server deployment, new runtime path, bootstrap or API-1 limit change. All owned
controls/help are Swedish and English. Older releases/assets remain immutable.

Svenska: Beta 27 samlar taggindexeringen, smarta taggchip och de lokalt provade
Android-/omslagsfixarna efter Beta 26. Öppna **OrbitUI-inställningar > Bookshelf >
Taggar och indexering**. **Uppdatera taggindex** läser nya/ändrade filer och
försöker igen med fel; **Läs om alla EPUB-taggar…** läser efter bekräftelse om
hela det konfigurerade beståndet utan någon gräns på 400 filer. Du kan pausa och
fortsätta efter omstart. Stängning pausar och behåller färdiga läsningar.
Fortsätt räknar det aktuella beståndet på nytt men återanvänder oförändrade filer
från samma jobb. Låt KOReader vara öppet under körningen; pausa innan du ersätter
EPUB-filer. Långtryck på en lokal tagg i **Tags/Taggar** för ett eget chip med
upp till 16 taggar och **OCH/ELLER**, i valt eller alla lokala bibliotek.
Träffvyerna behåller sin tydliga gräns på 400/400+; indexeringen kan hantera fler.
Sökningen visar framsteg och går att stoppa. Appmodulens sidpilar och taggarnas
inläsningsruta fungerar med native-widgetarna. Manuell metadatauppdatering på
Android använder den säkra omslagskön utan att ändra din inställning. Offline
kräver `bookorbit:tags` i EPUB-filen, inget BookOrbit-konto eller servertillägg.
Inga böcker, läsdata, synkägare, upstream-versioner eller gamla releaser ändras.

Update through the preview channel and restart KOReader. This remains a beta:
desktop/native-service tests do not establish full-library cold completion,
physical panel quality, every menu/reader return, rotation, suspend/resume,
Boox compatibility or 1.0 readiness. Focused Bigme checks and final sealed/public
byte verification are recorded separately in TESTING; earlier open gates remain.

## OrbitUI 0.1.0-beta.26

Beta 26 publishes the previously local Beta 25 changes and the reviewed
Bookshelf **6.1.1** import through `c686f5a3`. Self-sizing picker cards use their
own height when opened as an editor page, while remaining within the display.
SimpleUI stays at `fdf83c7d`; no new SimpleUI commits were available. Beta 25
was never publicly released: using 26 also permits upgrades from that installed
local test version. All earlier public release assets remain immutable.

Svenska: Beta 26 publicerar de tidigare lokala Beta 25-ändringarna och
Bookshelf **6.1.1**. Valkort får sin egen höjd inne i hyllredigeraren utan att
gå utanför skärmen. SimpleUI är oförändrat. Beta 25 släpptes aldrig offentligt;
26 gör att även den lokala testversionen kan uppdateras.

The release fixes the Android crash after long-pressing a book and choosing
**Refresh metadata**. OrbitUI's Android safety check read the settings editor
instead of the preference store and called a missing `nilOrTrue` function.
It now reads the existing store without changing the safety preference.

Regression coverage reproduces the original failure before the fix, uses the
real component loader/preference store/storage adapter, and checks unset,
enabled, disabled and non-Android behavior. The cover queue tests no longer
give the editor an invented store API. Both source and sealed-package paths
are covered. Existing cover preservation, bounded no-fork extraction and
cancellation remain; no cache reset or full reindex is required for this fix.

Svenska: Beta 26 rättar kraschen vid **långtryck på en bok > Uppdatera metadata**
på Android. Säkerhetskontrollen läste från inställningsmenyn i stället för
inställningslagret. Befintligt säkerhetsläge behålls och ett regressionstest
använder det riktiga lagret. Du behöver inte radera omslagscachen eller indexera
om biblioteket för att rätta den här kraschen.

The SimpleUI **App Launcher** module also gains **Settings shortcut > Android
settings / Developer options**. Normal Android Settings remains the default
on all devices. The explicit device-local alternative opens Android's public
Developer options entry, useful where a vendor Settings homepage crashes
entering Wireless debugging. It does not directly open private Android pages,
enable debugging, grant permissions or change any system setting. The Settings
icon and other app buttons remain unchanged.

Svenska: SimpleUI-modulen **App Launcher** får valet **Inställningar-genväg >
Android-inställningar / Utvecklaralternativ**. Standardvalet är oförändrat;
det nya målet väljs separat på varje enhet. Det kan kringgå en felande
inställningsstartsida hos tillverkaren. Inga Android-inställningar eller
behörigheter ändras och felsökning aktiveras inte. Från Utvecklaralternativ
öppnar du själv Trådlös felsökning. Ikonen och de andra appknapparna behålls.

The release additionally makes **Android apps**
(previously App Launcher) configurable through long-press > **Apps**. Add a
device launcher app, rename, move before/after a named neighbour, or confirm
removal of its shortcut without uninstalling it. Extra apps receive responsive
page arrows; an empty module remains configurable. Existing enabled modules
keep their choices; newly enabled ones start empty, not with personal defaults.
Only explicit edits save the device-local list. Discovery runs on Add app only;
manual package-name entry is available if Android filters/fails the query.
Removing/re-adding Settings does not reset its destination choice.

Svenska: Du kan långtrycka på
**Android-appar > Appar** för att lägga till, byta namn, flytta och ta bort
genvägar. Flyttvalen namnger grannen och visar platsen direkt. Att ta bort en
genväg avinstallerar inte Android-appen. Fler appar får sidpilar och en tom
modul går fortfarande att konfigurera. Befintliga aktiva moduler behåller
sina val; nya börjar tomma. Applistan och Inställningar-målet sparas lokalt.
Långtryck, riktig applista och avbryt är nu provade på Bigme. Ändringar av
applistan är ännu bara automatiskt testade.

The release also reuses bounded text metadata between library
scopes and makes layout probes skip unused folder-cover work. First Manga
profile visits measured about 5–7 seconds versus 15–17 before on the test Bigme;
warm Manga did not improve, and metadata refresh can still pause for a fresh
derivation. Own quiet update work forwards its canceling input rather than
dropping it; visible download cancellation is unchanged. One-page category
cards no longer fall back to the old list when native pagination is a stateless
span. Full tests and focused device checks pass, not complete device acceptance.

Svenska: Versionen återanvänder textmetadata mellan biblioteksvyer
och undviker onödigt omslagsarbete vid layoutmätning. Första Manga-besök tog
cirka 5–7 sekunder mot tidigare 15–17 på test-Bigmen. Redan laddad Manga blev
inte snabbare och metadatauppdatering kan fortfarande ge en paus. OrbitUIs
tysta uppdateringsarbete släpper nu vidare trycket som avbryter det. Kategorikort
på en sida fungerar även med KOReaders enkla sidavstånds-widget. Detta är
testat på Bigmen, men är inte ett godkännande av alla enhetsflöden.

All Beta 24 Bookshelf/SimpleUI behavior remains alongside the reviewed 6.1.1
picker fix. No bootstrap/API-1 or installed-path change, settings migration, resource removal,
external patch or BookOrbit/Hardcover synchronization change. Previous public
releases/assets remain immutable. Update through the preview channel and
restart KOReader. Still a prerelease: the exact final merged package has not
been tested on a physical device. Broader Bigme/Boox acceptance, app-edit
persistence and metadata-refresh extraction/filter-result acceptance remain
open. The user's new explicit publication request approves this beta with
those limits; it is not a claim that all earlier device gates have passed.

The separately published Undo-opening fix is **BookOrbit Extras 0.2.1** /
the Ereader Patch Manager catalogue, not an embedded OrbitUI patch. Update
that patch separately and restart KOReader. No server is deployed and no
already committed reading history is restored by either update.
Svenska: Ångra-fixen uppdateras separat via Ereader Patch Manager eller
BookOrbit Extras 0.2.1. OrbitUI installerar ingen serverpatch. Befintlig
läshistorik ändras inte. Slutpaketet och kvarstående app-/metadataflöden
behöver fortfarande provas på enheten.

## OrbitUI 0.1.0-beta.24

Beta 24 publishes the reviewed **Bookshelf 6.1.0** merge through `7ff93b9d`
and SimpleUI follow-ups through `fdf83c7d`. It does not import another upstream
revision during release preparation.

- Bookshelf's shelf editor gains a short front page and dedicated source,
  view, sort, filter, theme, module and order pages, with breadcrumbs and
  coalesced live previews. Existing OrbitUI profiles and unset view preferences
  retain their behavior; visiting settings never resets a layout.
- Book dialogs use clearer rounded action cards and segmented choices, with
  a rearrangeable action layout, persistent Tags edit strip and optional review
  spoilers. Our minimal header, lazy Book details and offline/online BookOrbit
  tag sections remain; opening them never starts an automatic network request.
- Filters can require all selected genres or exclude genres/collections.
  Theme sorting adds newest and last-used choices. Filter changes still need
  their explicit Apply where offered; they do not edit books or reading status.
- Disk cache separates covers (96 MiB) and ornament renders (24 MiB), scales
  budgets with available space and retains recently used images. Our bounded,
  cancelable maintenance stays outside painting. This should reduce avoidable
  decoding after restart, not a measured Bigme/Boox speed improvement.
- SimpleUI fixes cached bold-face sizing when global UI text is scaled.
  New controls have English/Swedish labels. All prior languages/resources stay.

Svenska: Beta 24 innehåller **Bookshelf 6.1.0** och de redan granskade
SimpleUI-ändringarna. Hyllredigeraren delas upp i tydligare sidor för källa,
visningsläge, sortering, filter, tema, moduler och ordning. Bokdialogerna får
tydligare åtgärdskort, valknappar och en redigeringsrad i Taggar. Fler
genre-/samlingsfilter och sortering av teman ingår. Omslag och ornament får
separata cachegränser och senast använda bilder prioriteras. Rensningen är
fortfarande avbrytbar och görs i små steg. Förväntad nytta är färre onödiga
omladdningar, inte en uppmätt snabbhetsvinst. SimpleUI rättar storleken på fet
text när gränssnittets textskalning används.

Our profile/chip navigation, fast close/return, all-cover shelves, 50–150%
cover size, binding/caption controls, Android safe covers, night contrast,
folder/MAL actions and BookOrbit features retain their owners. No external
BookOrbit/Hardcover progress writer, hardware driver, credential, book metadata,
reading data or user patch is changed. No server is deployed.

Update via the preview channel and restart KOReader / uppdatera via
förhandsversionskanalen och starta om KOReader. Back up settings separately
first. Earlier supported betas can update directly; bootstrap API 1 and all
2,000 installed paths remain unchanged. Seven new helpers use the existing
exact-source embedded registry; no language/font/artwork is removed to fit.
Previous public releases/assets remain immutable.

Code rollback preserves settings/data but older runtimes may ignore new 6.1
filters or action-layout choices and display shelves differently. Review the
scope after rollback; never restore old reading progress to undo UI changes.
Svenska: Kodåterställning behåller data, men äldre kod kan ignorera nya filter
och visningsval. Kontrollera hyllans avgränsning efter återställning.

Still a prerelease: physical Bigme/Boox dialog layout, tap/keyboard/Back/Close,
profile editing/reorder, Tags/Book details/zoom, cache warmth, day/night,
rotation/sleep and reader return need acceptance. Full headless/native archive,
input and raster tests are not device acceptance. Svenska: Fortsatt beta;
prova de nya vyerna på enheten. Ingen fysisk snabbhetsvinst är verifierad.

## OrbitUI 0.1.0-beta.23

Beta 23 publishes the optional **OrbitUI settings > Integrations > BookOrbit**
page. A master switch plus independent Want to Read list, manual reading-status
actions and online-tag controls affect OrbitUI only. Unset preferences preserve
existing behaviour. BookOrbit's own reading-progress sync, credentials, links,
cached lists and saved layouts are not disabled or reset. Opening settings or
Tags never tests the network automatically.

The two sources are now explicitly **Want to read [BookOrbit]** and **Want to
read [Local]**. The local source is the existing KOReader To Be Read collection,
not a new list or a replacement when the online source is disabled. Add either
or both through **Home (SimpleUI) > Layout & modules**, or choose a Reading
dashboard source. Saved IDs, memberships and custom headings remain intact.

An explicit refresh reports success/failure and preserves the last successful
list-refresh timestamp even if membership is unchanged. Queued work is retired
when its feature is disabled, including an off/on cycle. An already-sent server
write cannot be unsent; its retired result does not overwrite the local cache.
Manual Add/Remove Want to Read actions explicitly change server read status.

Offline EPUB tags remain independent. Optional online exact tag matching needs
its compatible server API addition. The separate
[BookOrbit Extras 3.6.0 guide](https://github.com/komadorirobin/bookorbit-extras/tree/main/server-support/bookorbit-3.6.0)
provides composable tag/undo source patches for that exact official release,
not every newer release. Never put the old 3.2.0 compiled overlay on a newer
server. An old custom undo database needs a separately reviewed upgrade plan.
OrbitUI does not install, remove or deploy these patches; resolve protected
openings and pending cleanup before disabling external undo support.

Svenska: **OrbitUI-inställningar > Integrationer > BookOrbit** samlar de valfria
funktionerna. Huvudbrytaren och separata val för Vill läsa, manuella lässtatusval
och nättaggar styr bara OrbitUI, inte BookOrbits egen progressionssynk. Befintliga
listor, kopplingar, inställningar och layouter behålls. **Vill läsa [Lokalt]**
använder KOReaders lokala samling; **Vill läsa [BookOrbit]** visar serverlistans
matchade filer på enheten. Listorna byts aldrig ut mot varandra. Lägg till båda
via Hem (SimpleUI), eller välj källa i Läsöversikt. Tydlig uppdatering/tidsstämpel
och skydd mot gamla väntande svar ingår. Manuella Vill läsa-val ändrar serverns
lässtatus. EPUB-taggar fungerar fortfarande offline utan BookOrbit.
Hjälpen pekar på versionsgranskat serverstöd, men installerar ingenting.

No new upstream merge, runtime path, artwork, language removal, bootstrap or
API-1 limit change. Earlier published releases remain immutable. Update via the
preview channel and restart KOReader. This remains a prerelease: Bigme/Boox
layout, touch/keyboard, refresh, off/on, local/server source selection, long
help text, Back/rotation/sleep and reader return need physical acceptance.
Headless tests do not establish a working live tag API on your server.

## OrbitUI 0.1.0-beta.22

Beta 22 adds clickable tags to the existing **Tags** tab. Start with **EPUB tags
(offline) > Read EPUB tags**. EPUB 2/3 `bookorbit:tags` metadata is read directly
from the file: no BookOrbit plugin, account, link, patch/API addition or connection
is needed. Standard EPUB subjects remain native Genres; collections stay separate.

Tap a tag for exact matches among local EPUBs across your configured library
profiles and home library. The library's scan-depth setting still applies; the
originating book is included even outside those folders. Scanning yields between
books and can be canceled. Successful reads use a disposable file-stat cache;
Refresh rereads the files. Unreadable books and the 400-match cap are disclosed.
Results retain native paging, filename filtering and normal reader/hold actions.

The separate optional online BookOrbit section can fetch server-only tags for
linked files. Its tag search requires the separately prepared BookOrbit API
addition; that server change is NOT deployed by this release and is not needed
for embedded tags. Nothing writes book metadata, collections, reading status or
remote progress, and no settings/data are reset.

Svenska: Beta 22 lägger taggar i den befintliga **Taggar-fliken**. Börja med
**EPUB-taggar (offline) > Läs EPUB-taggar**. Taggar som BookOrbit har skrivit in
i EPUB-filen fungerar utan plugin, konto, koppling eller nätverk. Tryck på en
tagg för att hitta fler lokala EPUB-filer med exakt samma tagg i alla dina
biblioteksprofiler. Bibliotekets skanningsdjup gäller fortfarande. Sökningen går
att avbryta; Uppdatera läser om filerna. Genrer och samlingar hålls separata.
Den valfria nätkällan kräver serverstöd för taggsökning, men offlinefunktionen
gör inte det. Inga böcker, läsdata eller inställningar skrivs över.

Fresh upstream check on October 31 finds no new commits: Bookshelf remains
`ee84a8fe`, SimpleUI `5631ce10`. Beta 21's Book details crash fix and previous
night/search/navigation/cover adaptations remain. No runtime paths, artwork,
fonts/languages, bootstrap or API-1 limits change. Earlier public assets remain
immutable. Update via the preview channel and restart KOReader.

Still a prerelease: Bigme/Boox layout, touch/keyboard, long tags, scroll/zoom,
scan latency, cancel/Back, rotation/sleep and reader return need physical checks.
Automated native archive/modal tests are not device acceptance.

## OrbitUI 0.1.0-beta.21

Beta 21 fixes the crash when selecting **Book details** in the book panel.
The information tab incorrectly called a renderer requiring a header widget
without supplying one. It now uses the modal's native headerless HTML scroller,
retaining its CSS, current dimensions, per-tab zoom and gesture/resource owner.

Regression coverage now follows the real modal tab-switch/render/zoom/resize/
close path rather than mocking the headed renderer. Beta 20 reproduces the
nil-header failure; the corrected path retains scrolling and safe body teardown.
No book files, metadata, links, progress, collections or settings are reset.

Svenska: Beta 21 rättar kraschen när du väljer **Bokdetaljer**. Fliken använde
fel renderingshjälp utan den rubrikdel som den krävde. Nu används dialogens
vanliga HTML-yta med rätt textstorlek, scrollning och stängning. Testet växlar
verkligen till fliken och kontrollerar zoom, storleksändring och frigöring av
ersatta vyer. Du behöver inte indexera om eller ändra några inställningar.

Update through the preview channel and restart KOReader / uppdatera via
förhandsversionskanalen och starta om KOReader. Earlier betas can update directly.
The Beta 20 night/search/shelf improvements remain, along with original book/
reader/plugin actions. No new upstream import, source-pin change, BookOrbit
feature/sync change, asset, installed path or bootstrap/API-1 change. BookOrbit
tag navigation is being assessed separately, not shipped by this crash hotfix.
All 2,000 installed paths and earlier public assets remain unchanged in identity.

Still a prerelease: retest Book details scrolling, independent zoom, repeated tab
switches, close and reader/shelf return on Bigme/Boox. Automated modal-path tests
are not physical MuPDF/font/touch/e-ink acceptance. Svenska: Fortsatt beta;
prova Bokdetaljer på enheten efter uppdateringen.

## OrbitUI 0.1.0-beta.20

Beta 20 publishes the approved night-mode and shared-interface refinements,
plus the reviewed SimpleUI follow-up through `5631ce10`. Bookshelf remains at
`ee84a8fe` (6.0.4 plus issue forms), with no new commits. No original artwork,
font/language, library data, external sync owner or hardware patch is replaced.

- **Night mode:** dark Home/shelf backgrounds gain runtime contrast over retained
  wallpaper, rounded RGB cards keep consistent corners on Android, and the dock
  retains readable ink. Day preferences and source cover colours stay intact;
  independently pinned Light/Dark shelf looks are preserved.
- **Tilted Cover Deck artwork:** upstream matches warped buffers to the screen
  format before inverted night blits and correctly counts their resident bytes
  in the existing cache. The original cached cover is never freed by conversion;
  allocation failures retain the native fallback. Polish translations improve.
- **Shared search:** optional typo-tolerant matching handles accents, prefixes
  and transposed letters. Exact spelling, including Swedish å/ä/ö, ranks first.
  Existing scopes, genre choice, recent queries, result ordering and the 400-hit
  cap remain. Disable **Typo-tolerant search** to keep exact substring matching.
- **Sort, filter & view:** tap the shelf counter marked **▾**. Choose ordering,
  reading-state filters or Covers/List/Book spines/compact one-/two-column rows.
  Choices are remembered per profile/chip/opened group, without rewriting shelf
  defaults. **Use shelf defaults here** restores original grouping/layout/order.
  Quick sort/status choices show that shelf's matching books. Barely started is
  a read-only local 0–5% category for started books, never a remote status write.
  Existing page jump and advanced native sorting remain in the same menu.
- **Settings and book details:** **You are here** offers direct ancestor jumps.
  Book details emphasize cover/title/author/progress; a lazy, independently
  zoomable **Book details** tab holds technical fields. **Read now** uses the
  original reader action. Other tabs and external plugin actions remain.
- **Diagnostics:** existing opt-in local timings cover search, browse, settings
  search and technical details, without titles, queries or paths. The synthetic
  developer benchmark is not a measured reader/paint/cover-performance claim.

Svenska: Beta 20 innehåller nattlägesfixen för ljusa bakgrunder, felaktiga
korthörn och svårläst navigationsrad. Dina daginställningar, bakgrundsbilder och
omslag behålls. SimpleUI rättar dessutom bildformatet för lutade omslag i Cover
Deck vid nattläge och deras minnesräkning. Bookshelf har inget nytt upstream.

**Stavfelstålig sökning** kan hitta böcker även med stavfel, accenter och
omkastade bokstäver; exakt svensk stavning prioriteras. Valet kan stängas av.
Tryck på hyllans sidräknare med **▾** för **Sortering, filter och vy**. Valen
sparas per profil/chip/grupp. Kompaktlistor visar titel, författare, läsprocent
och datum. **Använd hyllans standard här** återställer ursprunglig gruppering,
vy och sortering. Filtren ändrar aldrig lässtatus eller fjärrsynk.

**Du är här** gör det enklare att gå tillbaka genom inställningarna. Bokpanelen
får en renare header, teknisk information under **Bokdetaljer** och **Läs nu**
med samma läsaröppning som förut. Alla nya egna texter finns på svenska och
engelska; befintliga språk och pluginåtgärder behålls.

Update through the preview channel and restart KOReader / uppdatera via
förhandsversionskanalen och starta om KOReader. Older supported betas can update
directly. All 2,000 installed paths and the API-1 bootstrap remain; no bridge,
settings reset, metadata scan or automatic Android-safe-mode change is needed.
Profiles/chips, snabbstängning, BookOrbit/Hardcover/MAL and external patches keep
their existing owners. The separately published Ereader prose bookmark patch
is updated through Ereader Patch Manager, not embedded in this OrbitUI release.
Previous public releases and assets are never overwritten. Code rollback keeps
later user settings, progress, annotations, links and collections.

This remains a prerelease. Physical Bigme/Boox acceptance is outstanding: retest
day/night/day, tilted and ordinary covers, SV/EN fonts/touch/keyboard, shelf
controls/compact lists/defaults/restart, settings ancestors, detail tabs/zoom,
reader return, rotation/sleep and OTA. Svenska: Fortsatt beta; prova på enheten.
Automatiska tester är inte fysisk enhetsverifiering eller en uppmätt snabbhet.

## OrbitUI 0.1.0-beta.19

Beta 19 publishes the reviewed shared-search/collection changes and the earlier
October 30 evening SimpleUI merge. No additional upstream is imported for this
release: SimpleUI stays at `7a605bbc` (3.0.2 plus follow-ups), Bookshelf at
`ee84a8fe` (6.0.4 plus issue forms). Hardcover behavior is deliberately unchanged.

- **Shared search:** ten recent local query/scope pairs, explicit history clear,
  and relevance/title/author/series sorting. Ranking happens before the existing
  400-hit cap. Profile/current-shelf restrictions, group results and the original
  open/hold book actions remain. Missing profiles never silently become the
  whole library. Recent choices are paged; changing scope/sort retains typed text.
- **Collection contents:** in Bookshelf's **Manage collections**, tap a custom
  collection and choose **Manage books…**. Search members or choose **Add books**
  with the bottom-left view selector, review **Changes** and the add/remove
  counts, sort by title/author, then Save or Cancel. Back/X also discards the
  draft. Removal changes membership only, never deletes a book file. Favourites
  and folder-managed collections retain their native KOReader controls.
- **Reading Insights:** the reviewed SimpleUI update adds monthly books/pages
  charts with a separate year selector. Missing/busy/incomplete activity reads
  can retry; empty years, historical refresh and future-year rollover retain
  accurate cache boundaries. Existing Home/dashboard layout is not replaced.
- **Repository monitoring:** a separate daily inspiration dashboard watches
  selected source files from six design references. It never merges, imports
  or publishes code automatically and does not run on the reader.

Svenska: Beta 19 ger sökningen **Senaste sökningar** med tio lokala poster och
**Sortera träffar** efter relevans, titel, författare eller serie. Profilen och
den aktuella hyllans avgränsning behålls. En borttagen profil ger ett tydligt fel
i stället för att söka i hela biblioteket. Historiken kan rensas.

I Bookshelfs samlingshantering väljer du en egen samling och **Hantera böcker…**.
Knappen nere till vänster växlar mellan **I samlingen**, **Lägg till böcker** och
**Ändringar**. Sök och markera böcker, kontrollera antalet tillägg/borttagningar
och välj **Spara** eller **Avbryt**. Tillbaka/krysset kastar också utkastet.
Inga bokfiler tas bort. Favoriter och mappstyrda samlingar hanteras som tidigare.

De redan granskade upstream-ändringarna ingår också: månadsdiagram för böcker/
sidor i läsinsikterna, egen årsväljare och säkrare återförsök/cachehantering av
statistik. Läsöversiktens layout, profiler, chip, snabbstängning, Androids säkra
omslagshantering och BookOrbit/MAL/patch-integrationer behålls. Hardcover-patchen,
utgåvekopplingen och ansvaret för lässtatus/progress ändras inte av denna release.
Den separata inspirationsbevakningen körs på GitHub, inte på läsplattan.

Update on the preview channel and restart KOReader / uppdatera via
förhandsversionskanalen och starta om KOReader. Older supported betas can update
directly; no bridge, reset, new runtime path or bootstrap/API change is needed.
All 2,000 installed paths, artwork/fonts/languages and current source pins remain.
Previous releases/assets are immutable. Rollback changes code only, not later
settings, reading progress, metadata links or collections saved by the reader.

This is still a prerelease. Automated tests do not establish physical Boox/Bigme
acceptance or a measured speedup. Retest Swedish/English fonts/touch/keyboard,
search/history/scope, collection view/search/clear/paging/Save/Cancel, the Insights
year picker and reader/rotation/sleep return. Svenska: Fortsatt beta. Prova de nya
vyerna på enheten; ingen fysisk enhetsverifiering eller prestandavinst påstås.

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
