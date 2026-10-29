-- Task-oriented settings shell. Search uses static bilingual descriptors, never
-- values/credentials or eagerly built provider/native menus. Original callbacks
-- and stores remain the only preference writers.
local M = {}
local _ = require("core/orbitui_i18n")
local Context = require("core/orbitui_context")
local settings_request = 0
local start_ref = setmetatable({}, { __mode = "v" })
local function beginRequest()
    settings_request = settings_request + 1
    local old = start_ref.current
    start_ref.current = nil
    if old and not old._orbitui_closed then require("ui/uimanager"):close(old) end
end
-- BEGIN GENERATED SETTINGS SEARCH TERMS
local native_terms = {
    bookshelf_advanced = {
        "+ Add new shelf",
        "Accept",
        "Add a line",
        "Add a line (maximum reached)",
        "Adjust shelf/top panel size",
        "Advanced",
        "Alignment",
        "Apply",
        "Author",
        "BETA: Read calibre metadata.calibre",
        "Behavior",
        "Cancel",
        "Center",
        "Check for updates",
        "Collections",
        "Cover display",
        "Custom branch",
        "Default",
        "Delete",
        "Developer updates",
        "Edge: bottom",
        "Edge: top",
        "Edit top panel content",
        "Flexible shelf widths",
        "Folder",
        "Follow KOReader",
        "Font size",
        "Full-screen button",
        "Genres",
        "How many rows of tag pills the top panel shows before the rest collapse into a tappable +N button.",
        "In start menu",
        "In the top panel",
        "Installed: v",
        "Launcher buttons",
        "Left",
        "Library & search",
        "Link copied to clipboard",
        "List view",
        "Master branch",
        "Maximum tag rows",
        "Micro modules",
        "Minimum start menu width",
        "Minimum start menu width: default",
        "Move down",
        "Move up",
        "New shelf",
        "Notify on wake when update available",
        "Off",
        "On the shelf",
        "Pack editor…",
        "Pagination footer bottom margin",
        "Pagination footer top margin",
        "Performance tweaks",
        "Reinstall selected channel",
        "Reset",
        "Reset shelf menu to defaults",
        "Reset to latest stable release",
        "Reset top panel content to defaults",
        "Right",
        "Rows, columns and view are set per shelf:",
        "Series",
        "Set",
        "Show tags line",
        "Side: left",
        "Side: right",
        "Stable release",
        "Start menu",
        "Tags font size",
        "Tap a shelf to edit it. Long-press to show or hide it.",
        "Test branch",
        "Text size",
        "Update available",
        "Update channel",
        "Uppercase labels",
        "View changelog",
        "While reading",
        "long-press a shelf, then open Shelf style.",
        "never",
    },
    bookshelf_text = {
        "...",
        "Apply",
        "Cancel",
        "Cover badge size",
        "Cover badges",
        "Cover captions",
        "Cover captions font scale",
        "Default",
        "List text",
        "Micro-modules",
        "Modal tab label font scale",
        "Modal tabs",
        "Pagination bottom margin",
        "Pagination footer",
        "Pagination footer font scale",
        "Pagination top margin",
        "Shelf menu",
        "Shelf menu font scale",
        "Stack & folder label scale",
        "Stack & folder labels",
        "Start menu",
        "Start menu font scale",
        "Text size",
        "Top panel",
        "Top panel font scale",
    },
    covers = {
        "(default)",
        "All stacks",
        "Always",
        "Author",
        "Bookmark style",
        "Both",
        "Both, for books you are reading or have on hold; the pages alone for the rest.",
        "Completed book badge",
        "Count: printed pages first",
        "Count: your reading settings",
        "Cover captions",
        "Cover opening effect",
        "Custom",
        "Custom…",
        "Extract page counts…",
        "Fade finished books",
        "Faded cover",
        "Find page counts for books that do not have one yet.",
        "Finished / Total",
        "Folders only",
        "Groups only",
        "Heart (favorite)",
        "How far through you are, for books you are reading or have on hold. Other books show no badge.",
        "How folders and stacks are drawn on any shelf that has not chosen its own. Long-press a shelf to override it there.",
        "Never",
        "No cover drop shadow",
        "None",
        "Number only",
        "Off",
        "On-hold display",
        "Page badge",
        "Pages",
        "Pause badge",
        "Pause badge + faded cover",
        "Percent read",
        "Percent read and pages",
        "Series",
        "Show \"220\" rather than \"220 p\".",
        "Show author below series",
        "Show favorites icon",
        "Show progress bars",
        "Show reading bookmarks",
        "Show series #",
        "Small tick box",
        "Square cover corners",
        "Stack count badge",
        "Stack count format",
        "Star (favorite)",
        "Stars (rating)",
        "Tallest cover shape",
        "The author's name under each series stack. Folder title styles that print the series name below the tile keep that line for the name.",
        "Title",
        "Total",
        "True cover aspect ratio",
        "Within series folder",
    },
    hardcover = {
        "Auto-link editions",
        "Auto-link report",
        "Auto-link unlinked books",
        "Cached Hardcover ratings: unavailable",
        "Cancel",
        "Clear cache (keeps links)",
        "Download covers from Hardcover",
        "Fetching Hardcover ratings...",
        "Hardcover cache cleared",
        "Hardcover genres used",
        "Hardcover integration could not be loaded",
        "Hardcover plugin is not available",
        "Hardcover ratings refresh failed",
        "How many of a book's Hardcover genres to use for tag pills and the genre shelves/stacks.",
        "Manage Hardcover data",
        "No books to scan.",
        "No unlinked books to auto-link.",
        "Re-scan all books with edition IDs",
        "Refresh linked book details",
        "Refresh ratings only",
        "Remove all",
        "Remove all Hardcover data",
        "Remove all downloaded Hardcover covers?\n\nEach book's original cover is restored; links, descriptions and ratings are kept.",
        "Remove covers",
        "Remove downloaded covers",
        "Set",
        "Show Hardcover ratings",
        "Use Hardcover metadata",
        "Use Hardcover rating if no user rating",
    },
    maintenance = {
        "\"Latest\" folder walk depth",
        "(none)",
        "Author name formatting",
        "Auto",
        "Bottom to top",
        "Bulk selection mode",
        "Choose image library folder",
        "Create, rename, reorder and delete collections. Also reachable from collection shelves and stacks.",
        "Extract page counts…",
        "Find author images online…",
        "First Last",
        "Hide single-book series and genres",
        "How deep to scan your library folder for newly-added books. Higher values take longer on a cold start.",
        "Ignore The, A, An when sorting",
        "Image library",
        "Include folder names in search results",
        "Include genres and tags in search results",
        "Last, First",
        "Manage collections…",
        "Scan all library metadata",
        "Show each book in one group only",
        "Sort Chinese text by pinyin",
        "Spine text direction",
        "Top to bottom",
    },
    panel = {
        "All",
        "Author",
        "Authors",
        "Book",
        "Bookshelf tokens",
        "Cancel",
        "Close",
        "Default",
        "Description",
        "Device",
        "Disabled",
        "Enabled",
        "Help",
        "Insert token",
        "Logic",
        "Metadata",
        "Micro-modules font scale",
        "Progress",
        "Rating (interactive)",
        "Save",
        "Search tokens…",
        "Size",
        "Star size",
        "Status line",
        "Style",
        "Subtitle",
        "Tags (interactive)",
        "Time",
        "Title",
    },
    reader = {
        "Adds the Bookshelf menu button to the reader. Takes effect the next time you open a book.",
        "Adds the micro-modules button to the reader, in the corner opposite the menu button. Takes effect the next time you open a book.",
        "Bookshelf gestures",
        "Closing book notification",
        "Currently reading",
        "Double tap to open books",
        "Fast",
        "Launcher button position and size",
        "Micro modules",
        "Normal",
        "Off",
        "Open with a double tap",
        "Open with a single tap",
        "Page turn animation",
        "Show menu button",
        "Show micro-modules button",
        "Show status line",
        "Show the book's details",
        "Slow",
        "Start menu animation",
        "Tap a book in full screen shelves",
        "Top panel starts with",
    },
    safety = {
        "Android safe mode",
        "Clear cover cache",
        "Color panel dithering",
        "Cover cache",
        "Cover cache budget",
        "Cover cache cleared",
        "Disable spine mode shadows",
        "Instant book close (beta)",
        "MB",
        "Plank designs: none in use",
        "Pre-warm shelf cache",
        "Preload Bookshelf while reading (experimental)",
        "Show preload indicator while reading",
        "Use E-ink refresh rate for shelf pages",
    },
    themes = {
        "Auto",
        "Auto (follow night mode)",
        "Badge background",
        "Badge foreground",
        "Blur wallpaper behind panels",
        "Bookmark color",
        "Border color",
        "Choose wallpaper folder",
        "Color behind wallpaper",
        "Color of the ring drawn around the selected book or the one you are currently reading. Default black.",
        "Colors",
        "Cover shadow color",
        "Dark",
        "Default",
        "Favorite heart color",
        "Favorite star color",
        "Finished bookmark color",
        "First, so you see them",
        "Folder overlay background",
        "Folder text color",
        "Heavy",
        "Invert wallpaper when dark",
        "Label color on the selected shelf. Defaults to paper white over the fill. Long-press to clear.",
        "Last, so your shelf stays put",
        "Light",
        "Low",
        "Micro-module background",
        "Micro-module border",
        "Moderate",
        "None",
        "Other shelves: 1 with own theme",
        "Other shelves: all default",
        "Panel behind Covers shelves",
        "Panel color",
        "Panel text",
        "Progress bar",
        "Progress bar track",
        "Remove the backgrounds behind text below covers and the pagination bar. The book information panel and chip bar keep their panel shading.",
        "Reset to default colors",
        "Same as wallpaper",
        "Selected shelf background",
        "Selected shelf text",
        "Selection outline color",
        "Shelf menu background",
        "Shelf plank color",
        "Solid",
        "Text ink",
        "The frame around covers and the border of badges. Default black.",
        "The plank the Spines style stands its books on: a plain color, the built-in oak, or a plank from an ornament pack.",
        "The thin line around each micro-module card. Left unset it follows the text color. Long-press to clear.",
        "Transparent",
        "Transparent book titles and page indicator",
        "color",
        "default",
        "first",
        "last",
    },
}
-- END GENERATED SETTINGS SEARCH TERMS
local nodes = {
    { "home", "Home (SimpleUI)", nil, "home", "homescreen hemskärm startsida simpleui" },
    { "home_layout", "Layout & modules", "home", "home", "layout moduler widgets bento kolumner columns pages sidor", screen = "pages" },
    { "home_screens", "Custom screens", "home", "screens", "egna anpassade skärmar screens", screen = "custom_screens" },
    { "home_dashboard", "Reading dashboard", "home", "screens", "läsöversikt statistik mål goals kortfärger accenter tonade färg card colours colors accents tinted" },
    { "home_shelves", "Bookshelf shelves on Home", "home", "home", "bokhyllor carousel karusell bokrad book row" },
    { "home_options", "Wallpaper, presets & behaviour", "home", "home", "bakgrund wallpaper förinställningar beteende fast book closing", screen = "home_screen_settings" },
    { "home_advanced", "Advanced SimpleUI settings", "home", "screens", "alla all settings statistik statistics", screen = "__root__" },
    { "bookshelf", "Bookshelf", nil, "mixed", "bibliotek library böcker books manga prosa" },
    { "libraries", "Libraries & shelves", "bookshelf", "mixed", "biblioteksavdelningar profiler profiles mappar folders chip chips filters filter sortering sorting ordna bibliotek order libraries ordna chip order chips placera före place before källa source" },
    { "book_search", "Search books", "bookshelf", "mixed", "böcker böksökning books library search" },
    { "panel", "Book panel at the top", "bookshelf", "bookshelf", "toppanel hero bokinformation baksidestext tags interactive" },
    { "covers", "Covers & book information", "bookshelf", "bookshelf", "omslag upplösning resolution metadata indexering indexing" },
    { "themes", "Themes, backgrounds & ornaments", "bookshelf", "theme", "tema färger colors bakgrund wallpaper plank hyllplan dekorationer" },
    { "preset", "Shelf preset", "bookshelf", "bookshelf", "classic klassisk minimal bokboxar series boxes kanzenban" },
    { "bookshelf_text", "Fonts & text size", "bookshelf", "bookshelf", "typsnitt teckenstorlek font size text" },
    { "bookshelf_advanced", "Advanced Bookshelf settings", "bookshelf", "mixed", "listvy list view micromodules mikromoduler beteende behavior start menu sökning search" },
    { "navigation", "Navigation & interface", nil, "navigation", "navigationsrad bottenmeny knappar buttons dock navbar bars pagination" },
    { "bookshelf_navigation", "Bookshelf button & destinations", "navigation", "navigation", "bookshelf navigationsrad mål profile profil prose comics manga" },
    { "bars", "Bars, buttons & start view", "navigation", "screens", "status titelrad title navigation pagination startvy", screen = "bars_settings" },
    { "interface", "Icons, fonts & shared appearance", "navigation", "screens", "ikoner icon font färger colors stil style", screen = "style_settings" },
    { "quick_actions", "Custom quick actions", "navigation", "screens", "snabbåtgärder gester gestures shortcuts", screen = "quick_actions_settings" },
    { "reader", "Opening books & returning", "navigation", "bookshelf", "läsare reader bokstängning close return återgång hot park" },
    { "reader_menu", "Reader menu: fast return to Bookshelf", "reader", "navigation", "arkivskåp arkivknapp snabbstängning stäng boken file browser cabinet close button reader menu fast return" },
    { "integrations", "Integrations", nil, "integrations", "bookorbit hardcover myanimelist mal synk sync kopplingar" },
    { "connections", "Connections & help", "integrations", "integrations", "bookorbit myanimelist mal anslutningar credentials" },
    { "hardcover", "Hardcover book information", "integrations", "bookshelf", "hardcover enrichment berikning api betyg rating omslag" },
    { "addons", "Ornament add-ons", "integrations", "bookshelf", "ornament tillägg packs paket download hämta" },
    { "system", "System & maintenance", nil, "system", "system underhåll uppdatering update backup återställning restore felsökning diagnostics" },
    { "updates", "Update OrbitUI", "system", "system", "uppdatera update version rollback återställ tidigare" },
    { "maintenance", "Covers, metadata & troubleshooting", "system", "bookshelf", "saknade suddiga omslag cache index scan extrahera metadata felsökning" },
    { "safety", "Android safety & advanced cache settings", "performance", "bookshelf", "android safe mode säkerhetsläge prestanda performance mutex crash krasch cache" },
    { "performance", "Speed, memory & diagnostics", "system", "system", "snabbhetsläge snabb prestanda minne adaptiv responsive adaptive benchmark diagnostik rapport mätning measurement memory latency" },
    { "quick_start", "Home and Bookshelf: quick guide", "system", "system", "introduktion guide komma igång hem simpleui bookshelf bibliotek profil chip navigation" },
    { "setup", "Setup guide", "system", "system", "startguide inställningar setup startvy" },
    { "recovery", "Backup & recovery information", "system", "system", "säkerhetskopia återställning backup restore settings" },
}
local by_id = {}
for _i, n in ipairs(nodes) do
    n.id, n.label, n.parent, n.scope, n.aliases = n[1], n[2], n[3], n[4], n[5]
    by_id[n.id] = n
end
local regions = {
    { "title", "Show title" }, { "subtitle", "Show subtitle" },
    { "author", "Show author" }, { "description", "Show description" },
    { "rating", "Show rating" }, { "metadata", "Show extra book information" },
    { "progress", "Show reading progress" }, { "tags", "Show labels" },
}
local categories = {
    { "show_genres", "Show genres", "genre genrer genres tags facklitteratur fiction" },
    { "show_series", "Show series labels", "serie series tags" },
    { "show_author", "Show author labels", "författare author tags" },
    { "show_collections", "Show collection labels", "samlingar collections tags" },
    { "show_folder", "Show folder labels", "mapp folder tags" },
}
for _i, list in ipairs({ regions, categories }) do
    for _i, e in ipairs(list) do
        local n = { id = "panel_" .. e[1], label = e[2], parent = "panel",
            scope = "bookshelf", aliases = e[3] or e[1], target = e[1] }
        nodes[#nodes + 1] = n; by_id[n.id] = n
    end
end
local scopes = {
    home = "Applies to: Home (SimpleUI)",
    screens = "Applies to: SimpleUI screens; screen-specific editors identify their screen",
    bookshelf = "Applies to: all Bookshelf libraries",
    navigation = "Applies to: shared OrbitUI navigation",
    theme = "Applies to: the selected theme and shelves using it",
    integrations = "Applies to: the selected integration",
    system = "Applies to: this OrbitUI installation",
    mixed = "Scope is shown inside each settings page",
}
function M.scopeRow(scope, name)
    local text
    if scope == "library" then text = string.format(_("Applies to library: %s"), name or "")
    elseif scope == "shelf" then text = string.format(_("Applies only to shelf: %s"), name or "")
    else
        local label = assert(scopes[scope], "Unknown settings scope")
        text = _(label)
    end
    return { orbitui_id = "scope", text = text, keep_menu_open = true,
        callback = function() Context.notify(text .. "\n\n" ..
            _("Opening settings does not change saved choices. Each control keeps its existing scope.")) end }
end
local function scopedControls(source, scope, depth)
    depth = depth or 0
    local rows = {}
    for key, value in pairs(source or {}) do rows[key] = value end
    if depth > 8 then return rows end
    for index, original in ipairs(source or {}) do
        local row = {}
        for key, value in pairs(original) do row[key] = value end
        local child_scope = row.orbitui_scope or scope
        if child_scope == "mixed" and row.orbitui_id
                and (row.orbitui_id:match("^settings%.") or row.orbitui_id:match("^hero%.")) then
            child_scope = "bookshelf"
        end
        local build = original.sub_item_table_func
        if build or original.sub_item_table then
            row.sub_item_table = nil
            row.sub_item_table_func = function(...)
                local sub = build and build(...) or original.sub_item_table
                if type(sub) ~= "table" then return sub end
                local decorated = scopedControls(sub, child_scope, depth + 1)
                if not decorated[1] or decorated[1].orbitui_id ~= "scope" then
                    table.insert(decorated, 1, M.scopeRow(child_scope))
                end
                return decorated
            end
        end
        rows[index] = row
    end
    return rows
end
local function host(title, rows, parent, opts)
    local on_back = opts and opts.return_to
    if not on_back and parent then on_back = function()
        if parent == "__root__" then M.show() else M.open(parent, { profile = opts and opts.profile }) end
    end end
    return require("lib/bookshelf_menu_host").show{ title = title, item_table = rows,
        on_back = on_back, parent_title = on_back and ((opts and opts.return_label)
            or (by_id[parent] and _(by_id[parent].label)) or _("OrbitUI settings")),
        close_callback = function() require("adapters/orbitui_appearance").refreshVisible() end }
end
local function nativeHome(screen)
    if screen == "__root__" then screen = nil end
    return require("screens/sui_settings_window"):show(nil, screen)
end
local function children(id, close, opts)
    local rows = {}
    for _i, n in ipairs(nodes) do
        if n.parent == id then
            local target = n.id
            rows[#rows + 1] = { orbitui_id = target, text = _(n.label),
                callback = function()
                    if close then close() end
                    M.open(target, { profile = opts and opts.profile })
                end }
        end
    end
    return rows
end
function M.catalog()
    local rows = {}
    for _i, n in ipairs(nodes) do
        local path, current = {}, n
        while current do
            table.insert(path, 1, current.label); current = by_id[current.parent]
        end
        local terms = {}
        for _i, term in ipairs(native_terms[n.id] or {}) do terms[#terms + 1] = term end
        rows[#rows + 1] = { id = n.id, label = n.label, path = path, scope = n.scope, aliases = n.aliases, terms = terms }
    end
    return rows
end
local function fold(s)
    return tostring(s or ""):gsub("Å", "å"):gsub("Ä", "ä"):gsub("Ö", "ö"):lower()
end
function M.find(query)
    local words = {}
    query = fold(query):sub(1, 200)
    for word in query:gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then return {} end
    local hits = {}
    for index, item in ipairs(M.catalog()) do
        local text = { item.label, _(item.label, "sv"), item.aliases or "" }
        for _i, term in ipairs(item.terms) do text[#text + 1] = term; text[#text + 1] = _(term, "sv") end
        for _i, part in ipairs(item.path) do text[#text + 1] = part; text[#text + 1] = _(part, "sv") end
        local haystack, matched = fold(table.concat(text, " ")), true
        for _i, word in ipairs(words) do
            if not haystack:find(word, 1, true) then matched = false; break end
        end
        if matched then
            local label, score = fold(item.label .. " " .. _(item.label, "sv")), 0
            for _i, word in ipairs(words) do if label:find(word, 1, true) then score = score + 10 end end
            if label:find(query, 1, true) then score = score + 50 end
            item.score, item.index = score, index
            hits[#hits + 1] = item
        end
    end
    table.sort(hits, function(a, b) return a.score > b.score or (a.score == b.score and a.index < b.index) end)
    local truncated = #hits > 40
    while #hits > 40 do table.remove(hits) end
    return hits, truncated
end
function M.search(query, opts)
    beginRequest()
    if query == nil then
        local dialog
        local UI = require("ui/uimanager")
        local request = settings_request
        dialog = require("ui/widget/inputdialog"):new{
            title = _("Search settings"), input = "", input_hint = _("For example: genres, covers, navigation"),
            buttons = {{ { text = _("Cancel"), id = "close", callback = function()
                    UI:close(dialog)
                    if request == settings_request and opts and opts.cancel_to then opts.cancel_to() end
                end },
                { text = _("Search"), is_enter_default = true, callback = function()
                    if request ~= settings_request then return end
                    local text = dialog:getInputText(); UI:close(dialog); M.search(text, opts)
                end } }},
        }
        UI:show(dialog); dialog:onShowKeyboard(); return dialog
    end
    local rows, result_host = { M.scopeRow("mixed") }
    local matches, truncated = M.find(query)
    for _i, item in ipairs(matches) do
        local id, path = item.id, {}
        for _i, part in ipairs(item.path) do path[#path + 1] = _(part) end
        rows[#rows + 1] = { orbitui_id = id, text = table.concat(path, " / "), callback = function()
            if result_host then require("lib/bookshelf_menu_host").close(result_host) end
            M.open(id, { profile = opts and opts.profile, return_label = _("Search settings"),
                return_to = function() M.search(query, opts) end })
        end }
    end
    if truncated then rows[#rows + 1] = { text = _("Showing the first 40 settings. Narrow your search for more specific results."),
        enabled_func = function() return false end } end
    if #rows == 1 then rows[#rows + 1] = { text = _("No matching settings. Try a shorter word or a category name."),
        enabled_func = function() return false end } end
    result_host = host(_("Search settings"), rows, "__root__"); return result_host
end
local function withSettings(profile, action)
    local request = settings_request
    local plugin = Context.plugin("bookshelf")
    local widget = plugin and plugin._widget
    local function ready(w)
        if request ~= settings_request then return end
        local S = require("lib/bookshelf_settings")
        S._bw, S._plugin = w, Context.plugin("bookshelf"); action(S, w)
    end
    if widget and not widget._closed and (profile == nil or widget.profile_key == profile)
            and require("ui/uimanager"):isWidgetShown(widget) then return ready(widget) end
    return Context.withShelf(profile, ready, { is_current = function() return request == settings_request end })
end
local function originalSettings(S, wanted)
    local rows = S:_settingsSubItems()
    if not wanted then return rows end
    local selected = {}
    for _i, row in ipairs(rows) do if wanted[row.orbitui_id] then selected[#selected + 1] = row end end
    return selected
end
function M.panelItems(S)
    local R, rows = require("lib/bookshelf_hero_regions"), {}
    local tags = {}
    for _i, row in ipairs(S:_tagsRegionSubItems()) do tags[row.orbitui_id or "unknown"] = row end
    for _i, e in ipairs(regions) do
        local key, label = e[1], e[2]
        rows[#rows + 1] = { orbitui_id = key, text = _(label), keep_menu_open = true,
            checked_func = function() return not R.read()[key].disabled end,
            callback = function(menu)
                if key == "tags" and tags["tags.enabled"] then tags["tags.enabled"].callback(menu)
                else S:_toggleRegionEnabled(key, menu) end
            end }
    end
    for _i, e in ipairs(categories) do
        if tags[e[1]] then
            local field, native = e[1], tags[e[1]]
            local row = {}; for k, v in pairs(tags[e[1]]) do row[k] = v end
            row.text = _(e[2])
            row.checked_func = function() return not R.read().tags.disabled and native.checked_func() end
            row.callback = function(menu)
                if R.read().tags.disabled and tags["tags.enabled"] then
                    tags["tags.enabled"].callback(menu)
                    if not native.checked_func() then native.callback(menu) end
                else native.callback(menu) end
            end
            if field == "show_genres" then table.insert(rows, 5, row) else rows[#rows + 1] = row end
        end
    end
    rows[#rows + 1] = { text = _("About label switches"), callback = function()
        Context.notify(_("Enabling a label also enables the labels line. Other saved category choices are kept. This changes only the book panel, not book metadata or shelf filters."))
    end }
    rows[#rows + 1] = { orbitui_id = "advanced", text = _("Advanced: text templates, fonts & alignment"),
        sub_item_table_func = function() return S:_heroSubItems() end }
    return rows
end
function M.library(profile, appearance, page, target, opts)
    beginRequest()
    page = page or (appearance and "themes" or "bookshelf_advanced")
    return withSettings(profile, function(S)
        local rows = { M.scopeRow(page == "themes" and "theme" or "bookshelf") }
        local native
        if page == "panel" then native = M.panelItems(S)
        elseif page == "themes" then native = require("lib/bookshelf_theme_menu").items(S)
        elseif page == "covers" then native = originalSettings(S, { ["settings.covers"] = true })
        elseif page == "bookshelf_text" then native = originalSettings(S, { ["settings.text"] = true, ["settings.font"] = true })
        elseif page == "maintenance" then native = S:_librarySubItems()
        elseif page == "safety" then native = S:_performanceSubItems()
        elseif page == "reader" then native = {
            require("adapters/orbitui_libraries").readerMenuSetting(),
            { text = _("Bookshelf behaviour"), sub_item_table_func = function() return S:_behaviourSubItems() end },
            { text = _("While reading"), sub_item_table_func = function() return S:_whileReadingSubItems() end },
        }
        elseif page == "hardcover" then native = S:_hardcoverSubItems()
        else native = originalSettings(S) end
        for _i, row in ipairs(scopedControls(native, page == "themes" and "theme"
                or page == "bookshelf_advanced" and "mixed" or "bookshelf")) do
            if not target or row.orbitui_id == target then rows[#rows + 1] = row end
        end
        if target then rows[#rows + 1] = { text = _("All book-panel settings"), callback = function(menu)
            menu.closeMenu(); M.library(profile, nil, "panel")
        end } end
        if page == "bookshelf_advanced" then rows[1] = M.scopeRow("mixed") end
        local title = by_id[page] and _(by_id[page].label) or _("Bookshelf")
        return host(_("OrbitUI settings") .. " / " .. title, rows,
            by_id[page] and by_id[page].parent or "bookshelf", opts or { profile = profile })
    end)
end
function M.performanceItems()
    local Host = require("core/orbitui_host")
    return {
        { text = _("Performance profile"), sub_item_table_func = function()
            local rows = {}
            for _i, choice in ipairs({
                { "existing", "Keep existing behaviour", "Uses your saved animation, cache and preload choices without a shared runtime cap." },
                { "adaptive", "Adaptive memory", "Reduces retained cover-cache entries when memory is low or the reader is visible. Keeps image quality, saved budgets and the active shelf for fast return." },
                { "responsive", "Responsive", "Also disables Bookshelf wipe animations and speculative next-page/chip preload. Cold page loads may take longer. Visible Android covers and reader-return preparation keep their safe existing path." },
            }) do
                local id = choice[1]
                rows[#rows + 1] = { text = _(choice[2]), help_text = _(choice[3]), radio = true,
                    checked_func = function() return Host.performanceMode() == id end,
                    keep_menu_open = true, callback = function() Host.setPerformanceMode(id) end }
            end
            return rows
        end },
        { text = _("Measure performance"), checked_func = Host.isMeasuring, keep_menu_open = true,
            help_text = _("Optional local timing of synchronous calls. No book names, paths, accounts or raw errors are recorded. Nothing is uploaded; measurements stay in memory until reset or restart."),
            callback = function() Host.setMeasuring(not Host.isMeasuring()) end },
        { text = _("View performance report"), callback = function()
            require("ui/uimanager"):show(require("ui/widget/textviewer"):new{
                title = _("OrbitUI performance report"), text = Host.performanceReport() })
        end },
        { text = _("Copy performance report"), callback = function()
            local input = require("device").input
            if input and type(input.setClipboardText) == "function" then
                local ok, result = pcall(input.setClipboardText, input, Host.performanceReport())
                if ok and result ~= false then Context.notify(_("Performance report copied.")); return end
            end
            Context.notify(_("Clipboard unavailable. Use View performance report instead."))
        end },
        { text = _("Reset measurements"), keep_menu_open = true, callback = Host.resetMeasurements,
            help_text = _("Clears only in-memory timing samples. Books, reading data, settings and cover caches are kept.") },
        { text = _("How to compare performance"), callback = function()
            Context.notify(_("Use the same library, profile, chip, book and cover settings. Measure a first visit separately, then repeat warm operations ten times: Home, shelf paging, book open and fast return. Compare the existing and optional profiles separately. These call timings do not measure panel refresh or deferred work; confirm responsiveness and cover quality on the device."))
        end },
    }
end

function M.quickStartItems(close)
    local rows = {{ text = _("About this guide"), callback = function()
        Context.notify(_("Home (SimpleUI) is your start screen. Bookshelf is the library view. A library profile chooses folders and shelves; chips are the tabs inside that profile. These are not KOReader reading profiles. Opening this guide changes nothing."))
    end }}
    for _i, step in ipairs({
        { "1. Choose library folders and chips", "libraries", "Choose a library profile, then edit each chip's Source/Folder. Library folders (advanced) define the whole profile's scope, not just one chip." },
        { "2. Point the Bookshelf button at a profile", "bookshelf_navigation", "Choose Bookshelf for the navigation bar, then optionally select a library profile. Saved bars are kept until you edit them." },
        { "3. Customize Home (SimpleUI)", "home_dashboard", "Reading dashboard belongs to Home (SimpleUI). Choose which cards and book sources to show independently of your Bookshelf profile." },
        { "4. Check fast reader return", "reader_menu", "Open a book from the chosen shelf and use the cabinet/file-browser button in the reading menu. A safe prepared shelf returns to its profile, chip and position; otherwise the book closes normally." },
    }) do
        local id = step[2]
        rows[#rows + 1] = { text = _(step[1]), help_text = _(step[3]), callback = function()
            if close then close() end
            M.open(id)
        end }
    end
    return rows
end
function M.open(id, opts)
    beginRequest()
    local n = assert(by_id[id], "Unknown settings page")
    local profile = opts and opts.profile
    if n.target then return M.library(profile, nil, "panel", n.target, opts) end
    if n.screen then return nativeHome(n.screen) end
    if id == "reader_menu" then
        return host(_(n.label), { M.scopeRow("navigation"),
            require("adapters/orbitui_libraries").readerMenuSetting() }, "reader", opts)
    end
    if id == "book_search" then return require("core/orbitui_search").show() end
    if id == "updates" then return require("adapters/orbitui_updates").show() end
    if id == "setup" then return require("adapters/orbitui_setup").show() end
    if id == "preset" then return require("adapters/orbitui_appearance").show() end
    if id == "addons" then return require("adapters/orbitui_addons").show() end
    if id == "recovery" then return Context.notify(_("Updates and code rollback keep current settings and reading progress. The first-run snapshot covers selected UI settings and links, not your books or a complete device backup. Back up KOReader's data directory separately. Opening this page does not run a backup or restore.")) end
    if id == "panel" or id == "themes" or id == "covers" or id == "bookshelf_text" or id == "maintenance"
            or id == "safety" or id == "reader" or id == "hardcover" or id == "bookshelf_advanced" then
        return M.library(profile, nil, id, nil, opts)
    end
    local current
    local function close() if current then require("lib/bookshelf_menu_host").close(current) end end
    local rows, extra = { M.scopeRow(n.scope) }
    if id == "libraries" then extra = require("adapters/orbitui_library_settings").items()
    elseif id == "home_dashboard" then extra = require("adapters/orbitui_dashboard").menuItems()
    elseif id == "home_shelves" then extra = require("adapters/orbitui_home_shelves").menuItems()
    elseif id == "bookshelf_navigation" then extra = require("adapters/orbitui_library_settings").navigationItems()
    elseif id == "connections" then extra = require("adapters/orbitui_integrations").items()
    elseif id == "performance" then
        extra = M.performanceItems()
        for _i, row in ipairs(children(id, close, opts)) do extra[#extra + 1] = row end
    elseif id == "quick_start" then extra = M.quickStartItems(close)
    else extra = children(id, close, opts) end
    for _i, row in ipairs(extra or {}) do rows[#rows + 1] = row end
    current = host(_("OrbitUI settings") .. " / " .. _(n.label), rows, n.parent or "__root__", opts); return current
end
function M.items(close)
    local rows = { { orbitui_id = "search", text = _("Search settings"), callback = function()
        if close then close() end; M.search()
    end } }
    for _i, row in ipairs(children(nil, close)) do rows[#rows + 1] = row end
    return rows
end
function M.showList(opts)
    beginRequest()
    local current
    current = host(_("OrbitUI settings"), M.items(function()
        if current then require("lib/bookshelf_menu_host").close(current) end
    end), nil, opts)
    return current
end

-- Presentation only: no native settings/provider builders, current values or
-- preference writes are needed to describe the five existing destinations.
local start_cards = {
    { "home", "home", "Layout, widgets and reading dashboard" },
    { "bookshelf", "shelves", "Library profiles, shelves and covers" },
    { "navigation", "tune", "Navigation bar, buttons and reader return" },
    { "integrations", "extension", "BookOrbit, Hardcover and add-ons" },
    { "system", "settings", "Updates, performance and troubleshooting" },
}
function M.startCards()
    local cards = {}
    for _i, card in ipairs(start_cards) do
        cards[#cards + 1] = { id = card[1], text = _(by_id[card[1]].label),
            icon = card[2], description = _(card[3]) }
    end
    return cards
end

-- All inputs are measured pixels, not assumptions about device DPI. The
-- caller measures wrapped labels at the chosen column width, including room
-- for the native keyboard focus ring. Short screens page instead of clipping.
function M.startLayout(width, height, gap, min_width, min_height, count)
    local cols = width >= 2 * min_width + gap and 2 or 1
    local rows = math.min(math.ceil(count / cols), math.floor((height + gap) / (min_height + gap)))
    if rows < 1 then return nil end
    return { cols = cols, rows = rows, per_page = rows * cols,
        cell_w = math.floor((width - (cols - 1) * gap) / cols),
        area_h = rows * min_height + (rows - 1) * gap }
end

local function cardBody(card, width, deps, with_icon)
    local Screen, Space, BFont = deps.Screen, deps.Space, deps.BFont
    local title_face, title_bold = BFont:getFace("cfont", 20, { bold = true })
    local body_face = BFont:getFace("cfont", 14)
    local icon_h = Screen:scaleBySize(30)
    local icon
    if with_icon then
        local ok, result = pcall(function()
            return require("ui/widget/iconwidget"):new{
                file = require("core/orbitui_icons").imageFile("material:" .. card.icon .. ":300"),
                width = icon_h, height = icon_h, alpha = true, is_icon = true,
            }
        end)
        if ok then icon = result end
    end
    return deps.VerticalGroup:new{ align = "left",
        icon or deps.VerticalSpan:new{ width = icon_h },
        deps.VerticalSpan:new{ width = Space.px(8) },
        deps.TextBox:new{ text = card.text, face = title_face, bold = title_bold,
            width = width, fgcolor = deps.BB.COLOR_BLACK },
        deps.VerticalSpan:new{ width = Space.px(6) },
        deps.TextBox:new{ text = card.description, face = body_face,
            width = width, fgcolor = deps.BB.COLOR_DARK_GRAY },
    }
end

local function showCards(request, initial_page, initial_focus)
    local deps = {
        Screen = require("device").screen, Space = require("lib/bookshelf_space"),
        BFont = require("lib/bookshelf_fonts"), BB = require("ffi/blitbuffer"),
        VerticalGroup = require("ui/widget/verticalgroup"), VerticalSpan = require("ui/widget/verticalspan"),
        TextBox = require("ui/widget/textboxwidget"),
    }
    local Base = require("lib/bookshelf_library_modal")
    local Frame = require("ui/widget/container/framecontainer")
    local Top = require("ui/widget/container/topcontainer")
    local HG = require("ui/widget/horizontalgroup")
    local HS = require("ui/widget/horizontalspan")
    local Geom = require("ui/geometry")
    local UI = require("ui/uimanager")
    local cards, modal = M.startCards()
    local gap = Base.gridGap()
    local border = deps.Screen:scaleBySize(1)
    local padding = deps.Space.px(14)
    local inset = padding + border
    local layout
    local function current()
        return request == settings_request and modal and not modal._orbitui_closed
            and start_ref.current == modal
    end
    local function choose(id)
        if not current() then return end
        if id == "search" then return M.search(nil, { cancel_to = M.show }) end
        if id == "list" then return M.showList({ return_to = M.show, return_label = _("Category cards") }) end
        return M.open(id)
    end
    local function padded(widget)
        return HG:new{ align = "center", HS:new{ width = gap }, widget, HS:new{ width = gap } }
    end
    local Start = Base:extend{ name = "orbitui_settings_start" }
    -- Reuse the native modal's grid gestures, D-pad/footer focus, pagination,
    -- keyboard cleanup and close repaint. Only this instance's presentation
    -- changes; no component or KOReader widget class is monkey-patched.
    function Start:refresh()
        local cw = self.content_w
        local face, bold = deps.BFont:getFace("cfont", 22, { bold = true })
        local title = deps.TextBox:new{ text = _("OrbitUI settings"), face = face,
            bold = bold, width = cw, fgcolor = deps.BB.COLOR_BLACK }
        local footer = self:_renderFooter(cw)
        -- Reserve the measured pager even on a one-page screen: stable chrome
        -- avoids jumping cards when orientation or font scale changes.
        layout = layout or { per_page = #cards }
        local pager = self:_renderPagination(cw)
        local remaining = deps.Screen:getHeight() - title:getSize().h - footer:getSize().h
            - pager:getSize().h - 6 * gap - 2 * require("ui/size").border.window
        local min_width = deps.Screen:scaleBySize(220)
        local cols = cw >= 2 * min_width + gap and 2 or 1
        local cell_w = math.floor((cw - (cols - 1) * gap) / cols)
        local focus_inset = 2 * deps.Screen:scaleBySize(2)
        local text_w = cell_w - 2 * inset - focus_inset
        assert(text_w >= deps.Screen:scaleBySize(70), "Settings card width unavailable")
        local min_height = 0
        for _i, card in ipairs(cards) do
            local body = cardBody(card, text_w, deps, false)
            min_height = math.max(min_height, body:getSize().h + 2 * inset + focus_inset)
            body:free()
        end
        layout = assert(M.startLayout(cw, remaining, gap, min_width, min_height, #cards),
            "Settings card height unavailable")
        -- The provisional pager is no longer needed; render it with the final
        -- page size (native paging/focus use the same per_page).
        pager:free()
        local grid = self:_renderGridArea(cw, layout.area_h)
        pager = self:_renderPagination(cw)
        local old = self._shown_rect
        local previous = self.frame[1]
        self.frame[1] = deps.VerticalGroup:new{ align = "left",
            deps.VerticalSpan:new{ width = gap }, padded(title),
            deps.VerticalSpan:new{ width = gap }, padded(grid),
            deps.VerticalSpan:new{ width = gap }, padded(pager),
            deps.VerticalSpan:new{ width = gap }, padded(footer),
        }
        if previous then previous:free() end
        self:_repaintIfResized(old)
        if self._focus_zone == "footer" and self._footer_layout then
            local row = self._footer_layout[self._footer_row or 1]
            local button = row and row[self._footer_col or 1]
            if button then button:onFocus() end
        end
        self:_dirty()
    end
    function Start:onSetDimensions()
        if current() then M.show({ page = self.page, focus = self._dpad_idx }) end
        return true
    end
    modal = Start:new{ page = initial_page or 1, config = {
        title = _("OrbitUI settings"), no_search = true,
        grid_cols = function() return layout and layout.cols or 1 end,
        cells_per_page = function() return layout and layout.per_page or #cards end,
        item_count = function() return #cards end,
        item_at = function(i) return cards[i] end,
        focus_on_key = function() return initial_focus or 1 end,
        cell_renderer = function(card, dimen)
            local body = cardBody(card, dimen.w - 2 * inset, deps, true)
            return Frame:new{ bordersize = border, padding = padding, margin = 0,
                radius = deps.Space.px(7), background = deps.BB.COLOR_WHITE,
                color = deps.BB.COLOR_BLACK,
                Top:new{ dimen = Geom:new{ w = dimen.w - 2 * inset, h = dimen.h - 2 * inset }, body },
            }
        end,
        on_cell_tap = function(card) choose(card.id) end,
        footer_rows = {
            {{ key = "search", label = _("Search settings"), on_tap = function() choose("search") end }},
            {{ key = "list", label = _("List view"), on_tap = function() choose("list") end },
             { key = "close", label = _("Close"), on_tap = function() if current() then UI:close(modal) end end }},
        },
        on_closed = function()
            if modal then modal._orbitui_closed = true end
            if start_ref.current == modal then start_ref.current = nil end
        end,
    } }
    start_ref.current = modal
    UI:show(modal)
    return modal
end

function M.show(opts)
    beginRequest()
    local ok, modal = pcall(showCards, settings_request, opts and opts.page, opts and opts.focus)
    if ok then return modal end
    -- Unsupported/very small UI configurations retain the complete old menu,
    -- not a blank screen or an installation/settings migration.
    local logger = package.loaded.logger
    if logger then logger.warn("OrbitUI: settings cards unavailable; using the settings list", modal) end
    return M.showList()
end
function M.heroMenu(widget, book)
    beginRequest()
    local dialog
    local UI = require("ui/uimanager")
    local function close() UI:close(dialog) end
    dialog = require("ui/widget/buttondialog"):new{
        title = _("Book panel at the top"), buttons = {
            {{ text = _("Customize book panel"), callback = function() close(); M.open("panel", { profile = widget.profile_key }) end }},
            {{ text = _("Book details & actions"), callback = function() close(); widget:_showBookDetail(book, { active = "edit" }) end }},
            {{ text = _("Cancel"), callback = close }},
        },
    }
    UI:show(dialog); return dialog
end
function M.homeTitles(titles, state)
    titles.__root__ = _("Advanced SimpleUI settings")
    titles.home_screen_settings = _("Home (SimpleUI)")
    for _i, id in ipairs({ "bars_settings", "style_settings", "library_settings", "quick_actions_settings" }) do
        local original = titles[id]
        titles[id] = function(...)
            local title = type(original) == "function" and original(...) or original or ""
            return title .. " — " .. _("All SimpleUI screens")
        end
    end
    local original = titles.pages
    titles.pages = function(...)
        local title = type(original) == "function" and original(...) or original or _("Layout & modules")
        local scope = state.screen_id == "hs" and _("Home (SimpleUI)")
            or string.format(_("SimpleUI screen: %s"), state.screen_name or state.screen_id or "")
        return title .. " — " .. scope
    end
end
return M
