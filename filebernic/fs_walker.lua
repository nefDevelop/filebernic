---@diagnostic disable: undefined-global
local M = {}

function M.listDir(path)
    local ok, result = pcall(love.filesystem.getDirectoryItems, path)
    if not ok or not result then return nil end
    return result
end

function M.isDir(path)
    local info = love.filesystem.getInfo(path)
    return info and info.type == "directory"
end

function M.isFile(path)
    local info = love.filesystem.getInfo(path)
    return info and info.type == "file"
end

function M.getModTime(path)
    local info = love.filesystem.getInfo(path)
    return info and info.modtime
end

function M.walkFiles(rootPath, callback, batchSize)
    batchSize = batchSize or 500
    local function walk(dir)
        local entries = M.listDir(dir)
        if not entries then return end

        local count = 0
        for _, entry in ipairs(entries) do
            local fullPath = dir .. "/" .. entry
            if M.isFile(fullPath) then
                callback(fullPath)
                count = count + 1
                if count >= batchSize then
                    count = 0
                    coroutine.yield()
                end
            elseif M.isDir(fullPath) then
                walk(fullPath)
            end
        end
    end
    walk(rootPath)
end

function M.walkDirs(rootPath, callback, batchSize)
    batchSize = batchSize or 500
    local function walk(dir)
        local entries = M.listDir(dir)
        if not entries then return end

        local count = 0
        for _, entry in ipairs(entries) do
            local fullPath = dir .. "/" .. entry
            if M.isDir(fullPath) then
                callback(fullPath)
                count = count + 1
                if count >= batchSize then
                    count = 0
                    coroutine.yield()
                end
                walk(fullPath)
            end
        end
    end
    walk(rootPath)
end

function M.getDirTimestamp(dir)
    local modtime = M.getModTime(dir)
    if modtime then return modtime end
    -- Fallback: sumar timestamps de archivos (para directorios cuyo modtime no cambia en algunos FS)
    local total = 0
    local files = M.listDir(dir)
    if files then
        for _, f in ipairs(files) do
            local t = M.getModTime(dir .. "/" .. f)
            if t then total = math.max(total, t) end
        end
    end
    return total
end

function M.dirSize(dir)
    local count = 0
    local files = M.listDir(dir)
    if files then
        for _, f in ipairs(files) do
            local full = dir .. "/" .. f
            if M.isFile(full) then count = count + 1 end
        end
    end
    return count
end

return M
