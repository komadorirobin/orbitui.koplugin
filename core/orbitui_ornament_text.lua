local M = {}

function M.language(language)
    language = type(language) == "string" and language:lower() or "en"
    return (language == "sv" or language:match("^sv[_%-]")) and "sv" or "en"
end

function M.resolve(record, language)
    -- Translations belong to this exact official caption, not a reader's edit.
    if type(record.info) ~= "string" or record.info ~= record.info_source then return record.info end
    local translated = record["info_" .. M.language(language)]
    if type(translated) ~= "string" or translated == "" then translated = record.info_en end
    return type(translated) == "string" and translated ~= "" and translated or record.info
end

return M
