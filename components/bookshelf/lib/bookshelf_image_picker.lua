-- Image browsing must not inherit book-metadata sorting or count every
-- subfolder's contents before the first page can be shown.
local Picker = {}

function Picker.startPath(preferred)
    local lfs = require("libs/libkoreader-lfs")
    local function directory(path)
        return type(path) == "string" and path ~= ""
            and lfs.attributes(path, "mode") == "directory"
    end
    if directory(preferred) then return preferred end
    local home = require("lib/bookshelf_home_dir").get()
    if directory(home) then return home end
    local cwd = lfs.currentdir()
    return directory(cwd) and cwd or "/"
end

function Picker.new(opts)
    local PathChooser = require("ui/widget/pathchooser")
    local ImageSource = require("lib/bookshelf_image_source")
    local BD = require("ui/bidi")
    local _ = require("lib/bookshelf_i18n").gettext
    return PathChooser:new{
        title = opts.title,
        path = Picker.startPath(opts.path),
        select_directory = false,
        select_file = true,
        show_files = true,
        file_filter = ImageSource.isImageFile,
        -- Ignore book reading-status filters for image files, on this picker
        -- only. Do not change FileChooser or the saved library preferences.
        show_file = function(_, filename) return ImageSource.isImageFile(filename) end,
        getCollate = function(self) return self.collates.strcoll, "strcoll" end,
        getListItem = function(_, dirpath, filename, fullpath, attr)
            local is_file = attr.mode == "file"
            local text = is_file and filename or filename .. "/"
            if filename == "./." then
                text = _("Current folder not readable. Some content may not be shown.")
            end
            return {text = text, path = fullpath, attr = attr, is_file = is_file,
                bidi_wrap_func = is_file and BD.filename or BD.directory}
        end,
        onConfirm = opts.onConfirm,
    }
end

return Picker
