---@diagnostic disable: undefined-global
local M = {}
local utils = require "utils"

local artPathCache = {}

function M.getArtPathForSystem(systemName)
    if not systemName or systemName == "" then return nil end
    if artPathCache[systemName] then return artPathCache[systemName] end

    local baseMuosPath
    local devicePath = "/mnt/mmc"
    if love.filesystem.getInfo(devicePath) then
        baseMuosPath = devicePath .. "/MUOS/info/catalogue/"
    else
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        baseMuosPath = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
    end

    local walker = require "fs_walker"
    local entries = walker.listDir(baseMuosPath)
    if entries then
        for _, dir in ipairs(entries) do
            if walker.isDir(baseMuosPath .. dir) then
                if dir:lower() == systemName:lower() then
                    local res = baseMuosPath .. dir .. "/box/"
                    artPathCache[systemName] = res
                    return res
                end
            end
        end
    end

    local res = baseMuosPath .. systemName .. "/box/"
    artPathCache[systemName] = res
    return res
end

function M.hasRoms(path, validExtensions)
    local walker = require "fs_walker"
    local items = walker.listDir(path)
    if items then
        for _, item in ipairs(items) do
            if not walker.isDir(path .. "/" .. item) then
                local ext = item:match("[^%.]+$")
                if ext and validExtensions[ext:lower()] then
                    return true
                end
            end
        end
        return false
    end

    -- Fallback: io.popen si love.filesystem falla
    local handle = io.popen('ls -p ' .. utils.escapeShellArg(path) .. ' 2>/dev/null')
    if handle then
        for line in handle:lines() do
            if line:sub(-1) ~= "/" then
                local ext = line:match("[^%.]+$")
                if ext and validExtensions[ext:lower()] then
                    handle:close(); return true
                end
            end
        end
        handle:close()
        return false
    end
    return false
end

return M
