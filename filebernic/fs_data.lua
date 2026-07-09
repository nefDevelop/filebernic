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

return M
