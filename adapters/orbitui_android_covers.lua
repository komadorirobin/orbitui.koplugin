-- Android cannot safely fork a multithreaded renderer. Extract local covers
-- on the UI thread, one document per turn, WITHOUT BIM's subprocess-only
-- extractBookInfo (which also changes the process-wide crengine cache).
local M = {}
local LIMIT = 256
local META = { "title", "authors", "series", "series_index", "language", "keywords", "description", "pages" }

local function enabled()
    return require("device"):isAndroid()
        and require("lib/bookshelf_settings").nilOrTrue("android_safe_mode")
end

local function localFile(fp)
    local Repo = require("lib/bookshelf_book_repository")
    return type(fp) == "string" and fp:sub(1, 1) == "/"
        and not fp:find("://", 1, true)
        and not (Repo.isPluginFormatFile and Repo.isPluginFormatFile(fp))
        and require("libs/libkoreader-lfs").attributes(fp, "mode") == "file"
end

-- Prepare everything before touching the existing row. UPDATE only our derived
-- columns inside a savepoint: ignored/custom covers, sidecars and progress are
-- never reset; a decode/SQL failure leaves the old cache intact.
function M.extract(fp, specs)
    if not localFile(fp) then return false end
    local reader = package.loaded["apps/reader/readerui"]
    local live_document = reader and reader.instance and reader.instance.document
    if live_document and live_document.file ~= fp then live_document = nil end
    if not live_document and require("lib/bookshelf_file_ops").inUsePaths()[fp] then return false end
    local Registry = require("document/documentregistry")
    if not Registry:hasProvider(fp) then return false end
    local old, read_error = require("lib/bookshelf_book_repository").bimGetBookInfo(require("bookinfomanager"), fp, false)
    if read_error then return false end
    if specs then
        specs = { max_cover_w = math.max(specs.max_cover_w, tonumber(old and old.cover_w) or 0),
            max_cover_h = math.max(specs.max_cover_h, tonumber(old and old.cover_h) or 0) }
    end
    local document, bb, stmt, db, saving, compressed
    local borrowed = live_document ~= nil
    local ok, err = pcall(function()
        document = live_document or assert(Registry:openDocument(fp), "document unavailable")
        -- Book information already reads a live document this way. Never
        -- reload/close it or change its rendering profile/cache configuration.
        if document.loadDocument and not borrowed then
            assert(document:loadDocument(false), "metadata unavailable")
        end
        local BookInfo = require("apps/filemanager/filemanagerbookinfo")
        local props = BookInfo.extendProps(document:getProps(), fp)
        if not document.loadDocument then props.pages = document:getPageCount() end
        local attr = require("libs/libkoreader-lfs").attributes(fp)
        local values = { in_progress = 0, unsupported = false, has_meta = "Y",
            filesize = attr.size, filemtime = attr.modification }
        for _, key in ipairs(META) do
            if props[key] ~= nil then values[key] = props[key] end
        end
        if specs then
            bb = BookInfo:getCoverImage(document, fp) -- honors the user's custom cover
            values.cover_fetched = "Y"
            if bb then
                local w, h = bb:getWidth(), bb:getHeight()
                values.cover_sizetag = w .. "x" .. h
                local BIM = require("bookinfomanager")
                local tw, th = BIM.getCachedCoverSize(w, h, specs.max_cover_w, specs.max_cover_h)
                if tw < w or th < h then
                    local scaled = assert(require("ui/renderimage"):scaleBlitBuffer(bb, tw, th, false))
                    if scaled ~= bb then bb:free(); bb = scaled end
                end
                values.has_cover, values.cover_w, values.cover_h = "Y", bb.w, bb.h
                values.cover_bb_type, values.cover_bb_stride = bb:getType(), tonumber(bb.stride)
                local size
                compressed, size = require("ffi/zstd").zstd_compress(bb.data, bb.stride * bb.h)
                values.cover_bb_data = require("lua-ljsqlite3/init").blob(compressed, size)
            end
        end
        if not borrowed then document:close() end
        document = nil
        local BIM = require("bookinfomanager")
        BIM:openDbConnection()
        db = assert(BIM.db_conn)
        local directory, filename = require("util").splitFilePathName(fp)
        db:exec("SAVEPOINT orbitui_android_cover;"); saving = true
        stmt = db:prepare("INSERT OR IGNORE INTO bookinfo (directory,filename,in_progress) VALUES (?,?,0);")
        stmt:bind(directory, filename):step(); stmt:close(); stmt = nil
        local columns, bindings = {}, {}
        for key in pairs(values) do columns[#columns + 1] = key end
        table.sort(columns)
        for _, key in ipairs(columns) do bindings[#bindings + 1] = key .. "=?" end
        stmt = db:prepare("UPDATE bookinfo SET " .. table.concat(bindings, ",")
            .. " WHERE directory=? AND filename=?;")
        for i, key in ipairs(columns) do
            local value = values[key]
            if value == false then value = nil end
            -- LJSQLite3's BLOB binder takes ownership and frees its pointer,
            -- including when binding fails. Until then it is ours to release.
            if key == "cover_bb_data" then compressed = nil end
            stmt:bind1(i, value)
        end
        stmt:bind1(#columns + 1, directory):bind1(#columns + 2, filename):step()
        stmt:close(); stmt = nil
        db:exec("RELEASE orbitui_android_cover;"); saving = false
    end)
    if stmt then pcall(stmt.close, stmt) end
    if saving then
        pcall(db.exec, db, "ROLLBACK TO orbitui_android_cover;")
        pcall(db.exec, db, "RELEASE orbitui_android_cover;")
    end
    if document and not borrowed then pcall(document.close, document) end
    if bb then pcall(bb.free, bb) end
    if compressed then require("ffi").C.free(compressed) end
    if not ok then require("logger").warn("OrbitUI: local Android cover extraction failed; previous cache retained") end
    return ok, err
end

local function cancel(self)
    local job = self._orbitui_cover_job
    if job and job.callback then require("ui/uimanager"):unschedule(job.callback) end
    self._orbitui_cover_job = nil
end

local function foreground(UI, self)
    if UI.topdown_widgets_iter then
        for widget in UI:topdown_widgets_iter() do
            if not widget.invisible and not widget.toast then return widget == self end
        end
        return false
    end
    return UI:getTopmostVisibleWidget() == self
end

local function ready(self, fp)
    local Repo = require("lib/bookshelf_book_repository")
    require("lib/bookshelf_scaled_cover_cache"):drop(fp)
    Repo.forgetBook(fp)
    if Repo.lightMetaReady then Repo.lightMetaReady({ [fp] = true }) end
    self._bim_check_memo = nil
    self._hero_current_memo = nil
    if self._isSpineMode and self:_isSpineMode() then
        local Spine = require("lib/bookshelf_spine_shelf")
        if Spine.invalidateBook then Spine.invalidateBook(fp) end
        self:_expireSpineFetch()
    end
end

local function queue(self, files, explicit)
    local UI = require("ui/uimanager")
    local job = self._orbitui_cover_job
    if not job then job = { files = {}, seen = {} }; self._orbitui_cover_job = job end
    if not explicit then
        -- Replace obsolete visible-page work, retaining explicitly requested
        -- metadata refreshes. A page switch never scans the rest of the library.
        local kept = {}
        job.seen = {}
        for _, file in ipairs(job.files) do
            if file.explicit then kept[#kept + 1] = file; job.seen[file.filepath] = file end
        end
        job.files = kept
    end
    for _, file in ipairs(files or {}) do
        if #job.files >= LIMIT then break end
        local fp = file.filepath
        if localFile(fp) then
            local old = job.seen[fp]
            if old then
                old.explicit = old.explicit or explicit
                if file.cover_specs then old.cover_specs = file.cover_specs end
            else
                local entry = { filepath = fp, cover_specs = file.cover_specs, explicit = explicit }
                job.files[#job.files + 1] = entry; job.seen[fp] = entry
            end
        end
    end
    if job.callback then return #job.files > 0 end
    job.callback = function()
        if self._orbitui_cover_job ~= job then return end
        job.callback = nil
        if self._closed or not enabled() or not foreground(UI, self) then cancel(self); return end
        local file = table.remove(job.files, 1)
        if not file then cancel(self); return end
        job.seen[file.filepath] = nil
        local ok_bim, BIM = pcall(require, "bookinfomanager")
        -- Never interrupt somebody else's indexer or race its database writes.
        if not ok_bim or BIM:isExtractingInBackground() then cancel(self); return end
        local success = M.extract(file.filepath, file.cover_specs)
        self._orbitui_cover_attempts = self._orbitui_cover_attempts or {}
        local attempts = self._orbitui_cover_attempts
        if not attempts[file.filepath] and (self._orbitui_cover_attempt_count or 0) >= LIMIT then
            attempts = {}; self._orbitui_cover_attempts = attempts; self._orbitui_cover_attempt_count = 0
        end
        if not attempts[file.filepath] then self._orbitui_cover_attempt_count = (self._orbitui_cover_attempt_count or 0) + 1 end
        -- Failures retry after a minute; a successful coverless result settles
        -- until the file changes, a larger spec is needed, or explicit refresh.
        -- No permanent failure marker is written.
        attempts[file.filepath] = { until_time = success and math.huge or os.time() + 60,
            specs = file.cover_specs, mtime = require("libs/libkoreader-lfs").attributes(file.filepath, "modification") }
        if success then
            local painted = pcall(function()
                ready(self, file.filepath)
                if file.explicit then require("lib/bookshelf_book_repository").invalidateBookCache("android-metadata-refresh") end
                if self._inner_vgroup and self._shelf_dims then
                    self:_swapShelvesInPlace()
                    if not self._expanded and self._hero_parent and self._hero_dims then self:_swapHeroInPlace() end
                end
            end)
            if not painted then require("logger").warn("OrbitUI: Android cover is saved; repaint deferred") end
        end
        if self._orbitui_cover_job == job and #job.files > 0 and not job.callback then
            -- A small gap lets input/repaint run between native document loads.
            job.callback = job.step; UI:scheduleIn(0.15, job.callback)
        elseif self._orbitui_cover_job == job and #job.files == 0 then cancel(self) end
    end
    job.step = job.callback
    UI:scheduleIn(0.15, job.callback)
    return #job.files > 0
end

function M.widget(Widget)
    local stop, kick, fire = Widget._stopStatusTimer, Widget._kickOffMissingMetaExtractionNow, Widget._fireBimExtraction
    Widget._stopStatusTimer = function(self, ...)
        cancel(self)
        return stop(self, ...)
    end
    Widget.orbitui_preserveMetadataRefresh = function() return enabled() end
    Widget.orbitui_refreshMetadata = function(self, paths)
        if not enabled() then return false end
        local files = {}
        local screen = require("device").screen
        local w = math.floor(screen:getWidth() * 0.4)
        for _, fp in ipairs(paths) do
            files[#files + 1] = { filepath = fp, cover_specs = { max_cover_w = w, max_cover_h = math.floor(w * 1.6) } }
        end
        queue(self, files, true)
        local count = 0
        local job = self._orbitui_cover_job
        for _, file in ipairs(job and job.files or {}) do if file.explicit then count = count + 1 end end
        local _ = require("core/orbitui_i18n")
        require("ui/uimanager"):show(require("ui/widget/notification"):new{
            text = string.format(_("Local metadata refresh queued: %d book(s), maximum 256 at a time. Keep Bookshelf open. Existing covers are kept if extraction fails."), count),
            timeout = 5,
        })
        return true
    end
    Widget._fireBimExtraction = function(self, files, label)
        if not enabled() then return fire(self, files, label) end
        if label == "bulk-refresh" then
            local paths = {}
            for _, file in ipairs(files or {}) do paths[#paths + 1] = file.filepath end
            return self:orbitui_refreshMetadata(paths)
        end
        return queue(self, files, false)
    end
    Widget._kickOffMissingMetaExtractionNow = function(self, items, sw, sh, hw, hh)
        if not enabled() then return kick(self, items, sw, sh, hw, hh) end
        if self._closed then return end
        local Repo, BIM = require("lib/bookshelf_book_repository"), require("bookinfomanager")
        local files, seen = {}, {}
        local function add(fp, w, h)
            if not fp or seen[fp] or not localFile(fp) or self:_isRemoteRecord(fp) then return end
            seen[fp] = true
            local specs = { max_cover_w = w, max_cover_h = h }
            local attempt = self._orbitui_cover_attempts and self._orbitui_cover_attempts[fp]
            if attempt and attempt.until_time > os.time() and attempt.specs
                    and attempt.mtime == require("libs/libkoreader-lfs").attributes(fp, "modification")
                    and attempt.specs.max_cover_w >= w and attempt.specs.max_cover_h >= h then return end
            local info, err = Repo.bimGetBookInfo(BIM, fp, false)
            if err or (info and info.ignore_cover == "Y") then return end
            if info and (info.unsupported or (tonumber(info.in_progress) or 0) >= (BIM.max_extract_tries or 3)) then return end
            if not info or info.has_meta ~= "Y" or info.has_cover ~= "Y" or Widget._coverNeedsResize(info, specs) then
                files[#files + 1] = { filepath = fp, cover_specs = specs }
            end
        end
        local hero = self._preview_book and self._preview_book.filepath or (Repo.currentFilepath and Repo.currentFilepath())
        add(hero, math.max(sw, hw or sw), math.max(sh, hh or sh))
        for _, item in ipairs(items or {}) do
            add(item.filepath, sw, sh)
            if item.first_book then add(item.first_book.filepath, sw, sh) end
            for i = 1, math.min(4, #(item.books or {})) do add(item.books[i].filepath, sw, sh) end
        end
        return queue(self, files, false)
    end
end

function M.bookshelf(Bookshelf)
    local scan = Bookshelf.scanAllMetadata
    if type(scan) ~= "function" then return end
    Bookshelf.scanAllMetadata = function(self, ...)
        if not enabled() then return scan(self, ...) end
        local _ = require("core/orbitui_i18n")
        require("ui/uimanager"):show(require("ui/widget/infomessage"):new{
            text = _("Android safe mode: local metadata and covers load as you browse Bookshelf pages. For selected books, use Refresh metadata. The full-library scanner is disabled because it starts subprocesses. Keep Android safe mode enabled."),
        })
    end
end

return M
