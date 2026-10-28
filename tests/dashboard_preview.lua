-- Schematic of the real widget tree with synthetic covers (not a device shot).
return function(widget, path)
    local function xml(s)
        return tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    end
    local function utf8len(s)
        local _, n = s:gsub("[^\128-\191]", "")
        return n
    end
    local function take(s, count)
        local pos, n = 1, 0
        while pos <= #s and n < count do
            local b = s:byte(pos)
            pos = pos + (b < 128 and 1 or b < 224 and 2 or b < 240 and 3 or 4)
            n = n + 1
        end
        return s:sub(1, pos - 1)
    end
    local lines, clips = {}, 0
    local function emit(s) lines[#lines + 1] = s end
    local function rect(x, y, w, h, fill, stroke, radius)
        emit(string.format('<rect x="%s" y="%s" width="%s" height="%s" fill="%s" stroke="%s" rx="%s"/>',
            x, y, w, h, fill or "none", stroke or "none", radius or 0))
    end
    emit(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
        widget.dimen.w + 40, widget.dimen.h + 40, widget.dimen.w + 40, widget.dimen.h + 40))
    rect(0, 0, widget.dimen.w + 40, widget.dimen.h + 40, "#f4f2ed")
    emit('<g transform="translate(20 20)" font-family="Helvetica, sans-serif">')
    local cover_colors = { "#477776", "#a86a50", "#c9bd92", "#595879", "#924e55", "#3f5867" }
    local i = 0
    for _, child in ipairs(widget[1]) do
        local xy, size = child.overlap_offset, child:getSize()
        local x, y, w, h = xy[1], xy[2], size.w, size.h
        if child.kind == "text" then
            local fs = child.face.size
            local max_chars = math.max(1, math.floor(w / (fs * .54)))
            local nlines = child.max_lines or 1
            local words, result, row = {}, {}, ""
            for word in tostring(child.text):gmatch("%S+") do words[#words + 1] = word end
            for _, word in ipairs(words) do
                if row ~= "" and utf8len(row .. " " .. word) > max_chars then
                    result[#result + 1], row = row, word
                else row = row == "" and word or row .. " " .. word end
            end
            if row ~= "" then result[#result + 1] = row end
            clips = clips + 1
            emit(string.format('<clipPath id="c%d"><rect x="%s" y="%s" width="%s" height="%s"/></clipPath>', clips, x, y, w, h))
            emit(string.format('<g clip-path="url(#c%d)">', clips))
            for n = 1, math.min(nlines, #result) do
                local line = result[n]
                if n == nlines and (#result > n or utf8len(line) > max_chars) then line = take(line, max_chars - 1) .. "…" end
                emit(string.format('<text x="%s" y="%s" font-size="%s" font-weight="%s" fill="%s">%s</text>',
                    x, y + fs + (n - 1) * fs * 1.3, fs, child.bold and 700 or 400, child.fgcolor, xml(line)))
            end
            emit('</g>')
        elseif child.kind == "bar" then
            rect(x, y, w, h, child.background or "#a9aaa9", nil, h / 2)
            rect(x, y, w * child.pct, h, child.color or "#525754", nil, h / 2)
        elseif child.kind == "cover" then
            i = i + 1
            rect(x, y, w, h, cover_colors[(i - 1) % #cover_colors + 1], "#303333")
            rect(x + w * .07, y + h * .05, w * .86, h * .90, "none", "#d9d2b3")
            emit(string.format('<text x="%s" y="%s" text-anchor="middle" fill="#f5eed6" font-family="Georgia, serif" font-size="%s">%s</text>',
                x + w / 2, y + h * .4, math.max(7, w * .11), i == 1 and "SKANNAD" or "BOK"))
            emit(string.format('<text x="%s" y="%s" text-anchor="middle" fill="#f5eed6" font-family="Georgia, serif" font-size="%s">%s</text>',
                x + w / 2, y + h * .5, math.max(6, w * .10), i == 1 and "I DUNKLET" or tostring(i)))
        else
            rect(x, y, w, h, child.background, child.color, child.radius)
        end
    end
    emit('</g></svg>')
    local file = assert(io.open(path, "w"))
    file:write(table.concat(lines, "\n")); file:close()
end
