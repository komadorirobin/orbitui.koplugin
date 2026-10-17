package.path = "./?.lua;./components/bookshelf/?.lua;" .. package.path
local H = require("tests/helpers")
local dirs, home, cwd, stats = {}, "/library", "/koreader", 0
package.loaded["libs/libkoreader-lfs"] = {
    attributes = function(path, key)
        H.eq(key, "mode"); stats = stats + 1; return dirs[path]
    end,
    currentdir = function() return cwd end,
}
package.loaded["lib/bookshelf_home_dir"] = {get = function() return home end}
package.loaded["lib/bookshelf_i18n"] = {gettext = function(s) return s end}
package.loaded.logger = {warn = function() end}
package.loaded["ui/renderimage"] = {}
local settings = {image_library_path = nil}
package.loaded["lib/bookshelf_settings_store"] = {
    read = function(k) return settings[k] end,
    save = function(k, v) settings[k] = v end,
}
local BD = {filename = function(s) return s end, directory = function(s) return s end}
package.loaded["ui/bidi"] = BD
local collate = {strcoll = {init_sort_func = function() end}}
local native = H.widget():extend{collates = collate}
-- These are deliberately forbidden for an image-only chooser. Native
-- FileChooser:getListItem normally asks both collate metadata and subdir counts.
function native:getListItem() error("book metadata / subfolder scan") end
function native:getCollate() error("inherited library metadata sorting") end
function native:show_file() error("inherited book-status filter") end
package.loaded["ui/widget/pathchooser"] = native
local Picker = require("lib/bookshelf_image_picker")
local ImageSource = require("lib/bookshelf_image_source")

H.test("picker uses an existing image library without creating or changing it", function()
    dirs = {["/art"] = "directory", ["/library"] = "directory"}
    settings.image_library_path = "/art"
    H.eq(Picker.startPath(ImageSource.getImageLibraryPath()), "/art")
    H.eq(settings.image_library_path, "/art")
end)

H.test("absent default or deleted custom image library falls back to the real home", function()
    dirs = {["/library"] = "directory"}
    settings.image_library_path = nil
    H.eq(ImageSource.getImageLibraryPath(), "/library/.bookshelf-images")
    H.eq(Picker.startPath(ImageSource.getImageLibraryPath()), "/library")
    settings.image_library_path = "/removed"
    H.eq(Picker.startPath(ImageSource.getImageLibraryPath()), "/library")
    H.eq(settings.image_library_path, "/removed")
end)

H.test("invalid image and home paths fall back without loops or directory creation", function()
    dirs = {["/a.jpg"] = "file", ["/koreader"] = "directory"}
    for _, path in ipairs({false, "", "/missing", "/a.jpg"}) do
        stats = 0
        H.eq(Picker.startPath(path), "/koreader"); assert(stats <= 3)
    end
    dirs = {}; H.eq(Picker.startPath(nil), "/")
end)

H.test("image chooser filters only images and keeps file selection and cancellation native", function()
    dirs = {["/library"] = "directory"}
    local selected
    local picker = Picker.new{path = "/missing", title = "Choose image",
        onConfirm = function(path) selected = path end}
    H.eq(picker.path, "/library"); H.eq(picker.title, "Choose image")
    H.eq(picker.select_file, true); H.eq(picker.select_directory, false)
    H.eq(picker.show_files, true); H.eq(picker.onMenuHold, native.onMenuHold)
    for _, file in ipairs({"art.jpg", "art.PNG", "art.webp", "art.tiff"}) do
        assert(picker.file_filter(file)); assert(picker:show_file(file))
    end
    for _, file in ipairs({"book.epub", "book.cbz", "settings.lua", "art.svg"}) do
        H.eq(picker.file_filter(file), false); H.eq(picker:show_file(file), false)
    end
    H.eq(selected, nil)
    picker.onConfirm("/art.jpg"); H.eq(selected, "/art.jpg")
    H.eq(rawget(native, "file_filter"), nil)
end)

H.test("large directory listings never query child contents or book metadata", function()
    local picker = Picker.new{path = "/library"}
    local c, id = picker:getCollate()
    H.eq(c, collate.strcoll); H.eq(id, "strcoll")
    stats = 0
    for i = 1, 500 do
        local path = "/library/Series " .. i
        local item = picker:getListItem("/library", "Series " .. i, path, {mode = "directory"}, c)
        H.eq(item.path, path); H.eq(item.text, "Series " .. i .. "/")
        H.eq(item.is_file, false); H.eq(item.mandatory, nil)
        H.eq(item.bidi_wrap_func, BD.directory)
    end
    local item = picker:getListItem("/library", "art.png", "/library/art.png", {mode = "file"}, c)
    H.eq(item.text, "art.png"); H.eq(item.is_file, true)
    H.eq(item.bidi_wrap_func, BD.filename); H.eq(stats, 0)
end)

local function source(path)
    local f = assert(io.open(path)); local text = f:read("*a"); f:close(); return text
end
local function compile(code, env)
    setmetatable(env, {__index = _G})
    if setfenv then local f = assert(loadstring(code)); setfenv(f, env); return f end
    return assert(load(code, "image picker", "t", env))
end
local widget_src = source("components/bookshelf/lib/bookshelf_widget.lua")
local function method(name, env)
    local args, body = widget_src:match("function BookshelfWidget:" .. name .. "%((.-)%)\n(.-)\nend")
    return compile("return function(self," .. args .. ")\n" .. assert(body) .. "\nend", env)()
end

H.test("series folder and book actions all open the bounded picker and preserve apply callbacks", function()
    settings.image_library_path = "/missing"
    dirs = {["/library"] = "directory"}
    local shown, rebuilt, dirty, applied = nil, 0, 0, nil
    local ui = {show = function(_, w) shown = w end, setDirty = function() dirty = dirty + 1 end}
    local bw = {_rebuild = function() rebuilt = rebuilt + 1 end,
        _applyCoverCandidate = function(_, book, candidate, modal, state)
            applied = {book, candidate, modal, state}
        end}
    local env = {UIManager = ui, _ = function(s) return s end}
    method("_pickStackImage", env)(bw, "series", "Saga")
    H.eq(shown.path, "/library"); H.eq(shown:getCollate(), collate.strcoll)
    H.eq(settings.stack_images, nil)
    shown.onConfirm("/art.jpg")
    H.eq(settings.stack_images["series:Saga"], "/art.jpg")
    H.eq(rebuilt, 1); H.eq(dirty, 1)
    method("_pickFolderImage", env)(bw, "/library/Saga")
    shown.onConfirm("/folder.png")
    H.eq(settings.folder_images["/library/Saga"], "/folder.png")
    H.eq(rebuilt, 2); H.eq(dirty, 2)
    local book, modal, state = {filepath = "/book.epub"}, {}, {}
    method("_pickBookCoverFromDevice", env)(bw, book, modal, state)
    shown.onConfirm("/cover.png")
    H.eq(applied[1], book); H.eq(applied[2].local_path, "/cover.png")
    H.eq(applied[3], modal); H.eq(applied[4], state)
    H.eq(rebuilt, 2)
end)

H.test("SimpleUI does not turn image picker choices into virtual book series", function()
    local src = source("components/simpleui/features/library/sui_series_grouping.lua")
    local body = assert(src:match("local function sgProcessItemTable%(item_table, file_chooser%)\n(.-)\nend"))
    local probes = 0
    local process = compile("return function(item_table, file_chooser)\n" .. body .. "\nend", {
        SeriesGrouping = {isEnabled = function() return true end},
        VirtualPath = {isVirtual = function() return false end},
        _sg_items_cache = {},
        require = function() probes = probes + 1; error("no book metadata in picker") end,
    })()
    local items = {{path = "/library/cover.jpg", is_file = true}}
    process(items, Picker.new{path = "/library"}); H.eq(probes, 0)
    process(items, {path = "/library", select_file = false, select_directory = true})
    H.eq(probes, 0); H.eq(items[1].opened, nil)
    process(items, {path = "/library", name = "filemanager"}); H.eq(probes, 1)
end)

H.finish()
