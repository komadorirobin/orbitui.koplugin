local root = assert(debug.getinfo(1, "S").source:match("^@(.+)/_meta%.lua$"))
return dofile(root .. "/orbitui_bootstrap.lua").metadata(root)
