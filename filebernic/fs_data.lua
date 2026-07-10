---@diagnostic disable: undefined-global
local M = {}
local core = require "fs_core"

function M.saveFavorites(favoriteRoms, json_encode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/favorites.json", "w")
    if f then
        f:write(json_encode(favoriteRoms))
        f:close()
    end
end

function M.loadFavorites(json_decode)
    local path = love.filesystem.getSource() .. "/data/favorites.json"
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        return json_decode(content) or {}
    end
    return {}
end

function M.addToHistory(path, playedRoms)
    playedRoms[path] = true
    M.saveHistory(playedRoms)
    return playedRoms
end

function M.saveLastPlayed(path)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/last_played.txt", "w")
    if f then
        f:write(path)
        f:close()
    end
end

function M.savePendingHistory(path)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/pending_played.txt", "w")
    if f then
        f:write(path)
        f:close()
    end
end

function M.checkPendingHistory(playedRoms, saveHistoryFunc)
    local dataDir = love.filesystem.getSource() .. "/data"
    local path = dataDir .. "/pending_played.txt"
    local f = io.open(path, "r")
    if f then
        local romPath = f:read("*all")
        f:close()
        if romPath and romPath ~= "" then
            playedRoms[romPath] = true
            saveHistoryFunc(playedRoms)
        end
        core.safeRemove(path)
    end
    return playedRoms
end

function M.saveHistory(playedRoms)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/played_roms.txt", "w")
    if f then
        for path, _ in pairs(playedRoms) do
            f:write(path .. "\n")
        end
        f:close()
    end
end

function M.logDeletion(path, json_encode, json_decode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local logPath = dataDir .. "/deleted_roms.json"

    local logData = {}
    local f = io.open(logPath, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content ~= "" then
            logData = json_decode(content) or {}
        end
    end

    table.insert(logData, {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        path = path
    })

    f = io.open(logPath, "w")
    if f then
        f:write(json_encode(logData))
        f:close()
    end
end

function M.saveViewCache(files, romPath, selectedIndex, isVirtualRoot, json_encode, love_filesystem_getSource, io_open)
    local startIdx = 1
    local endIdx = #files
    local savedIndex = selectedIndex

    if isVirtualRoot and #files > 100 then
        startIdx = math.max(1, selectedIndex - 25)
        endIdx = math.min(#files, selectedIndex + 25)
        savedIndex = selectedIndex - startIdx + 1
    end

    local cache = {
        romPath = romPath,
        selectedIndex = savedIndex,
        isVirtualRoot = isVirtualRoot,
        files = {}
    }

    for i = startIdx, endIdx do
        local item = files[i]
        local cleanItem = {}
        for k, v in pairs(item) do
            if type(v) ~= "userdata" then
                cleanItem[k] = v
            end
        end
        table.insert(cache.files, cleanItem)
    end

    local dataDir = love_filesystem_getSource() .. "/data"
    local f = io_open(dataDir .. "/view_cache.json", "w")
    if f then
        f:write(json_encode(cache))
        f:close()
    end
end

function M.loadViewCache(json_decode, love_filesystem_getSource, io_open, getSystemIcon_func, getSystemContentIcon_func, fs_getInfo, gfx_newImage)
    local path = love_filesystem_getSource() .. "/data/view_cache.json"
    local f = io_open(path, "r")
    if not f then return nil, nil, nil end

    local content = f:read("*a")
    f:close()

    local cache = json_decode(content)
    if not cache or not cache.files then return nil, nil, nil end

    for _, item in ipairs(cache.files) do
        if item.isDir and getSystemIcon_func then item.icon = getSystemIcon_func(item.name, fs_getInfo, gfx_newImage) end
    end

    return cache.files, cache.selectedIndex, cache.romPath, cache.isVirtualRoot
end

local RECENT_MAX = 20

function M.addRecent(path, json_encode, json_decode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local recentPath = dataDir .. "/recent.json"
    local recent = {}

    local f = io.open(recentPath, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content ~= "" then
            recent = json_decode(content) or {}
        end
    end

    -- Remove duplicate
    for i = #recent, 1, -1 do
        if recent[i] == path then table.remove(recent, i) end
    end

    -- Prepend (most recent first)
    table.insert(recent, 1, path)

    -- Trim
    while #recent > RECENT_MAX do table.remove(recent) end

    f = io.open(recentPath, "w")
    if f then
        f:write(json_encode(recent))
        f:close()
    end
end

function M.loadRecent(json_decode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/recent.json", "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
        local recent = json_decode(content)
        if recent and type(recent) == "table" then return recent end
    end
    return {}
end

-- Collections / Playlists

function M.saveCollections(collections, json_encode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/collections.json", "w")
    if f then
        f:write(json_encode(collections))
        f:close()
    end
end

function M.loadCollections(json_decode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/collections.json", "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
        local cols = json_decode(content)
        if cols and type(cols) == "table" then return cols end
    end
    return {}
end

function M.addToCollection(collectionName, gamePath, json_encode, json_decode)
    local cols = M.loadCollections(json_decode)
    if not cols[collectionName] then cols[collectionName] = {} end
    for _, p in ipairs(cols[collectionName]) do
        if p == gamePath then return end -- ya existe
    end
    table.insert(cols[collectionName], gamePath)
    M.saveCollections(cols, json_encode)
end

function M.removeFromCollection(collectionName, gamePath, json_encode, json_decode)
    local cols = M.loadCollections(json_decode)
    if not cols[collectionName] then return end
    local new = {}
    for _, p in ipairs(cols[collectionName]) do
        if p ~= gamePath then table.insert(new, p) end
    end
    cols[collectionName] = new
    if #new == 0 then cols[collectionName] = nil end
    M.saveCollections(cols, json_encode)
end

function M.renameCollection(oldName, newName, json_encode, json_decode)
    local cols = M.loadCollections(json_decode)
    if not cols[oldName] then return end
    cols[newName] = cols[oldName]
    cols[oldName] = nil
    M.saveCollections(cols, json_encode)
end

function M.deleteCollection(name, json_encode, json_decode)
    local cols = M.loadCollections(json_decode)
    cols[name] = nil
    M.saveCollections(cols, json_encode)
end

return M
