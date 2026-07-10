---@diagnostic disable: undefined-global
local M = {}

local function escapeXML(s)
    if not s then return "" end
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub("\"", "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end
M.escapeXML = escapeXML

function M.findInGamelist(romFullPath, romFilename)
    if not romFullPath then return nil end
    local dir = romFullPath:match("(.*/)")
    if not dir then return nil end
    local xmlPath = dir .. "gamelist.xml"

    local f = io.open(xmlPath, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()

    local searchPath = "./" .. romFilename
    local escapedPath = searchPath:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    local gameBlock = nil
    for block in content:gmatch("<game>(.-)</game>") do
        if block:find("<path>%s*" .. escapedPath .. "%s*</path>") then
            gameBlock = block
            break
        end
    end

    if gameBlock then
        local desc = gameBlock:match("<desc>(.-)</desc>")
        local year = gameBlock:match("<releasedate>(%d%d%d%d)")
        local img = gameBlock:match("<image>(.-)</image>")

        if desc then desc = desc:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\""):gsub("&apos;", "'") end

        local absImgPath = nil
        if img then
            if img:sub(1,2) == "./" then absImgPath = dir .. img:sub(3)
            elseif img:sub(1,1) ~= "/" then absImgPath = dir .. img
            else absImgPath = img end
        end

        return { description = desc, year = year, imagePath = absImgPath, source = "Gamelist.xml" }
    end
    return nil
end

local function updateGamelistXML(romPath, metadata, action)
    local dir = romPath:match("(.*/)")
    if not dir then return end
    local filename = romPath:match("([^/]+)$")
    local xmlPath = dir .. "gamelist.xml"

    local content
    local f = io.open(xmlPath, "r")
    if f then
        content = f:read("*all")
        f:close()
    else
        if action == "delete" then return end
        content = "<?xml version=\"1.0\"?>\n<gameList>\n</gameList>"
    end

    local relPath = "./" .. filename
    local escapedPath = relPath:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")

    local games = {}
    for game in content:gmatch("<game>(.-)</game>") do
        if not game:find("<path>%s*" .. escapedPath .. "%s*</path>") then
            table.insert(games, "<game>" .. game .. "</game>")
        end
    end

    if action == "add" and metadata then
        local name = metadata.name or filename:gsub("%.[^%.]+$", "")
        local entry = "  <game>\n"
        entry = entry .. "    <path>" .. relPath .. "</path>\n"
        entry = entry .. "    <name>" .. escapeXML(name) .. "</name>\n"
        if metadata.image then entry = entry .. "    <image>" .. escapeXML(metadata.image) .. "</image>\n" end
        if metadata.desc then entry = entry .. "    <desc>" .. escapeXML(metadata.desc) .. "</desc>\n" end
        if metadata.year then entry = entry .. "    <releasedate>" .. metadata.year .. "0101T000000</releasedate>\n" end
        entry = entry .. "  </game>"
        table.insert(games, entry)
    end

    f = io.open(xmlPath, "w")
    if f then
        f:write("<?xml version=\"1.0\"?>\n<gameList>\n")
        for _, g in ipairs(games) do f:write(g .. "\n") end
        f:write("</gameList>")
        f:close()
    end
end

function M.updateGamelistXML(romPath, metadata, action)
    updateGamelistXML(romPath, metadata, action)
end

return M
