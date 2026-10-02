package.path = "./?.lua;" .. package.path
local now, reads, tree, mtimes = 1000, 0, {}, {}
local realTime = os.time
os.time = function() return now end
package.loaded["logger"] = { dbg = function() end }
package.loaded["device"] = { home_dir = "/books" }
G_reader_settings = { readSetting = function() return "/books" end }
package.loaded["libs/libkoreader-lfs"] = {
    dir = function(path)
        reads = reads + 1
        assert(not path:match("%.sdr$"), "entered a sidecar")
        local names, i = assert(tree[path], path), 0
        return function() i = i + 1; return names[i] end
    end,
    attributes = function(path, key)
        local attrs = { mode = tree[path] and "directory" or "file",
            modification = mtimes[path] or 1, size = 100 }
        return key and attrs[key] or attrs
    end,
}
package.loaded["engines/sui_book_grid"] = { makeModule = function(opts) return opts end, reset = function() end }
package.loaded["infra/sui_i18n"] = { translate = function(s) return s end }
local Scan = require("engines/sui_library_scan")
local New = dofile("modules/module_new_books.lua")
local passed = 0
local function test(name, fn)
    Scan.invalidate()
    reads, now = 0, now + 1
    tree = { ["/books"] = { ".", "..", "a.epub", "b.epub", "a.sdr", "other.fb3" },
        ["/books/a.sdr"] = { "metadata.epub.lua" } }
    mtimes = { ["/books"] = 10, ["/books/a.epub"] = 20, ["/books/b.epub"] = 30 }
    local ok, err = pcall(fn)
    if not ok then error(name .. ": " .. tostring(err)) end
    passed = passed + 1
end

test("New Books shares the existing library walk", function()
    assert(#Scan.getRaw("/books") == 2 and reads == 1)
    local books = New.getFileList({})
    assert(#books == 2 and books[1] == "/books/b.epub")
    assert(reads == 1, "walk repeated")
end)

test("five minutes with no changes does not force a rescan", function()
    New.getFileList({})
    now = now + 301
    New.getFileList({})
    assert(reads == 1)
    mtimes["/books/a.sdr"] = 80
    now = now + 1
    New.getFileList({})
    assert(reads == 1, "reading metadata triggered a scan")
end)

test("import and deletion update the candidates", function()
    New.getFileList({})
    tree["/books"][#tree["/books"] + 1] = "new.epub"
    mtimes["/books"], mtimes["/books/new.epub"], now = 11, 100, now + 1
    assert(New.getFileList({})[1] == "/books/new.epub" and reads == 2)
    table.remove(tree["/books"])
    mtimes["/books"], now = 12, now + 1
    assert(New.getFileList({})[1] == "/books/b.epub" and reads == 3)
end)

test("top 15 remains ordered and bounded", function()
    for i = 1, 100 do
        local name = string.format("%03d.epub", i)
        table.insert(tree["/books"], name)
        mtimes["/books/" .. name] = i + 100
    end
    local books = New.getFileList({})
    assert(#books == 15 and books[1] == "/books/100.epub" and books[15] == "/books/086.epub")
end)

test("optional index keeps formats Bookshelf supports and rejects insufficient coverage", function()
    assert(Scan.peekFileIndex("/books", 3) == nil, "peek started a scan")
    Scan.getRaw("/books")
    local index = assert(Scan.peekFileIndex("/books", 3))
    assert(#index.files == 3 and index.files[3].fp == "/books/other.fb3")
    assert(not Scan.peekFileIndex("/books", 9))
    assert(not Scan.peekFileIndex("/books2", 3))
end)

test("unpacked EPUB chapters do not become books", function()
    table.insert(tree["/books"], "unpacked")
    tree["/books/unpacked"] = { "mimetype", "META-INF", "chapter.txt" }
    tree["/books/unpacked/META-INF"] = { "container.xml" }
    assert(#Scan.getRaw("/books") == 2)
end)

test("truncated indexes are not exported as complete", function()
    tree["/books"] = {}
    for i = 1, 20010 do tree["/books"][i] = i .. ".epub" end
    Scan.getRaw("/books")
    assert(not Scan.peekFileIndex("/books", 3))
end)

test("trailing slashes share one cache key and can be invalidated", function()
    assert(#Scan.getRaw("/books/") == 2)
    assert(Scan.peekFileIndex("/books/", 3))
    assert(#Scan.getRaw("/books") == 2 and reads == 1)
    Scan.invalidate("/books/")
    assert(#Scan.getRaw("/books") == 2 and reads == 2)
end)

test("nested roots export only when the requested depth was covered", function()
    table.insert(tree["/books"], "sub")
    tree["/books/sub"] = { "child" }
    tree["/books/sub/child"] = { "x.epub" }
    Scan.getRaw("/books")
    assert(Scan.peekFileIndex("/books/sub", 7))
    assert(not Scan.peekFileIndex("/books/sub/child", 7))
    assert(not Scan.peekFileIndex("/books/submarine", 1))
end)

os.time = realTime
print("PASS " .. passed .. " New Books/index tests")
