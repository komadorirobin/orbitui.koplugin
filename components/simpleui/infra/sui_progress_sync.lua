-- Android progress prompts must close before a reader navigation event runs.
-- Keep this scoped to sync plugins, not KOReader's shared ConfirmBox class.
local Device = require("device")
local UIManager = require("ui/uimanager")
local SUISettings = require("infra/sui_store")
local logger = require("logger")

local M = {}
local patches = setmetatable({}, { __mode = "k" })
local hooks_registered = false
local methods = {
    kosync = { "getProgress" },
    bookorbit = { "getProgress", "reconcileProgressBeforeBookSync" },
}

local function patchPrompt(fn, plugin_name)
    if type(fn) ~= "function" then return false end
    for index = 1, 64 do
        local name, ConfirmBox = debug.getupvalue(fn, index)
        if not name then break end
        if name == "ConfirmBox" and type(ConfirmBox) == "table"
                and type(ConfirmBox.new) == "function" then
            -- BookOrbit's two progress methods share this upvalue. Do not
            -- wrap it twice, including when another plugin instance loads.
            if ConfirmBox._simpleui_android_progress_proxy then return true end
            local proxy = setmetatable({
                _simpleui_android_progress_proxy = true,
            }, { __index = ConfirmBox })

            function proxy:new(options)
                if type(options) == "table" and type(options.ok_callback) == "function" then
                    local callback = options.ok_callback
                    local ReaderUI = package.loaded["apps/reader/readerui"]
                    local reader = ReaderUI and ReaderUI.instance
                    local document = reader and reader.document
                    options.ok_callback = function()
                        -- nextTick can still run in Android's modal dispatch
                        -- cycle. Preserve the existing KOSync real-time delay.
                        UIManager:scheduleIn(0.15, function()
                            if reader and (ReaderUI.instance ~= reader or reader.tearing_down
                                    or reader.document ~= document) then
                                logger.dbg("simpleui: skipped stale progress prompt:", plugin_name)
                                return
                            end
                            local ok, err = pcall(callback)
                            if not ok then
                                logger.err("simpleui: deferred progress prompt failed:", plugin_name, err)
                            end
                        end)
                    end
                end
                return ConfirmBox.new(ConfirmBox, options)
            end

            debug.setupvalue(fn, index, proxy)
            patches[fn] = { index = index, original = ConfirmBox, proxy = proxy }
            logger.info("simpleui: installed Android progress-prompt workaround:", plugin_name)
            return true
        end
    end
    logger.warn("simpleui: progress prompt ConfirmBox upvalue not found:", plugin_name)
    return false
end

function M.patchTarget(plugin, plugin_name)
    if not Device:isAndroid() or not SUISettings:nilOrTrue("simpleui_enabled") then return false end
    if type(plugin) ~= "table" or not methods[plugin_name] then return false end
    local patched = false
    for _, method in ipairs(methods[plugin_name]) do
        if type(plugin[method]) == "function" then
            patched = patchPrompt(plugin[method], plugin_name) or patched
        end
    end
    return patched
end

function M.patchAll(simpleui)
    if not Device:isAndroid() or not SUISettings:nilOrTrue("simpleui_enabled") then return end
    local ok, PluginLoader = pcall(require, "pluginloader")
    for name in pairs(methods) do
        local plugin = simpleui and simpleui.ui and simpleui.ui[name]
        if not plugin and ok and type(PluginLoader.getPluginInstance) == "function" then
            plugin = PluginLoader:getPluginInstance(name)
        end
        -- Both sync plugins are optional. ReaderReady retries after the full
        -- plugin load pass, while the hooks cover later instantiations.
        if plugin then M.patchTarget(plugin, name) end
    end
end

function M.installHooks()
    if not Device:isAndroid() or hooks_registered then return end
    local ok, userpatch = pcall(require, "userpatch")
    if not (ok and userpatch and type(userpatch.registerPatchPluginFunc) == "function") then
        logger.warn("simpleui: unable to register Android progress-prompt hooks")
        return
    end
    hooks_registered = true
    for name in pairs(methods) do
        local plugin_name = name
        userpatch.registerPatchPluginFunc(plugin_name, function(plugin)
            local installed, err = pcall(M.patchTarget, plugin, plugin_name)
            if not installed then
                logger.err("simpleui: Android progress-prompt hook failed:", plugin_name, err)
            end
        end)
    end
end

function M.teardown()
    for fn, patch in pairs(patches) do
        local _, current = debug.getupvalue(fn, patch.index)
        if current == patch.proxy then
            debug.setupvalue(fn, patch.index, patch.original)
        end
        patches[fn] = nil
    end
end

return M
