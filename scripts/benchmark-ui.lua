-- Synthetic CPU-only comparison, NOT a device/paint/cover-extraction benchmark.
-- Run from the repo root: luajit scripts/benchmark-ui.lua [repetitions, default 5]
package.path = "./?.lua;" .. package.path
local Search = require("core/orbitui_search")
local repetitions = math.max(1, math.min(20, tonumber(arg[1]) or 5))
local queries = { "harry potter", "harry poter", "charlote bronte", "zzzzzzzz" }
print("Synthetic metadata-only CPU benchmark; no filesystem scan, covers, UI paint or hardware refresh")
print("interpreter,books,mode,queries,repetitions,median_ms,p90_ms,max_ms")
for _, count in ipairs({ 200, 2000, 5000 }) do
    local books = {}
    for i = 1, count do
        books[i] = { filepath = "/synthetic/" .. i .. ".epub", title = "Book " .. i .. " of the library",
            author = "Author " .. (i % 300), series_name = "Series " .. (i % 80) }
    end
    books[count].title, books[count].author = "Harry Potter", "J. K. Rowling"
    books[count - 1].title, books[count - 1].author = "Jane Eyre", "Charlotte Brontë"
    for _, forgiving in ipairs({ false, true }) do
        local samples = {}
        for _repeat = 1, repetitions do
            for _, query in ipairs(queries) do
                local start, hits = os.clock(), 0
                local match = Search.matcher(query, forgiving)
                for _, book in ipairs(books) do if match(book, nil, true) ~= nil then hits = hits + 1 end end
                samples[#samples + 1] = (os.clock() - start) * 1000
                if query == "harry potter" or (forgiving and query ~= "zzzzzzzz") then
                    assert(hits >= 1, "late exact/fuzzy hit must survive")
                end
            end
        end
        table.sort(samples)
        print(string.format("%s,%d,%s,%d,%d,%.3f,%.3f,%.3f", jit and jit.version or _VERSION,
            count, forgiving and "typos" or "exact", #queries, repetitions,
            samples[math.ceil(#samples / 2)], samples[math.ceil(#samples * .9)], samples[#samples]))
    end
end
