---@diagnostic disable: undefined-global
local M = {}
local core = require "fs_core"
local gamelist = require "fs_gamelist"
local utils = require "utils"

function M.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    local currentPath = item.fullPath or (romPath .. item.name)
    local detectedSystem = currentPath:match("ROMS/([^/]+)/") or currentPath:match("Simulador_SD/([^/]+)/")

    if detectedSystem and (detectedSystem ~= systemName or not muosArtPath or muosArtPath == "") then
        systemName = detectedSystem
        local baseMuosPath
        local f = io.open("/mnt/mmc", "r")
        if f then
             f:close()
             baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
        else
             local cwd = love.filesystem.getSource()
             if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
             local simPath = cwd .. "/../Simulador_SD/"
             baseMuosPath = simPath .. "MUOS/info/catalogue/"
        end
        muosArtPath = baseMuosPath .. systemName .. "/box/"
        muosTextPath = baseMuosPath .. systemName .. "/text/"
        muosPreviewPath = baseMuosPath .. systemName .. "/preview/"
        return systemName, muosArtPath, muosTextPath, muosPreviewPath
    end
    return systemName, muosArtPath, muosTextPath, muosPreviewPath
end

function M.deleteGameMedia(romPath)
    local system = romPath:match("ROMS/([^/]+)/")
    if not system then return end
    local baseMuosPath
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
        baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
    else
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        baseMuosPath = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
    end
    local baseName = romPath:match("([^/]+)$")
    if not baseName then return end
    baseName = baseName:gsub("%..-$", "")

    local artPath = baseMuosPath .. system .. "/box/" .. baseName .. ".png"
    local textPath = baseMuosPath .. system .. "/text/" .. baseName .. ".txt"
    local yearPath = baseMuosPath .. system .. "/text/" .. baseName .. ".year"
    local prevPath = baseMuosPath .. system .. "/preview/" .. baseName .. ".png"

    core.safeRemove(artPath, log)
    core.safeRemove(textPath, log)
    core.safeRemove(yearPath, log)
    core.safeRemove(prevPath, log)

    gamelist.updateGamelistXML(romPath, nil, "delete")
end

function M.saveScrapeResult(item, result, muosArtPath, muosTextPath, muosPreviewPath, log)
    local baseName = item.name:gsub("%..-$", "") or item.name:gsub("%.[^%.]+$", "")

    local ok = os.execute("mkdir -p " .. utils.escapeShellArg(muosArtPath))
    if not ok then log("Error: Failed to create boxart directory: " .. muosArtPath) end

    local destPath = muosArtPath .. baseName .. ".png"
    local finalImagePath = destPath
    log("Saving boxart to: " .. destPath)

    local inp = io.open(result.tempPath, "rb")
    if inp then
        local content = inp:read("*a")
        inp:close()
        local out = io.open(destPath, "wb")
        if out then
            out:write(content)
            out:close()
        else
            log("Error writing boxart file: " .. destPath)
        end
    else
        log("Error reading temp boxart file: " .. result.tempPath)
    end

    if result.description then
        ok = os.execute("mkdir -p " .. utils.escapeShellArg(muosTextPath))
        if not ok then log("Error: Failed to create text directory: " .. muosTextPath) end
        local txtPath = muosTextPath .. baseName .. ".txt"
        log("Saving description to: " .. txtPath)
        local f = io.open(txtPath, "w")
        if f then f:write(result.description) f:close() end
    end

    if result.year then
        ok = os.execute("mkdir -p " .. utils.escapeShellArg(muosTextPath))
        if not ok then log("Error: Failed to create year directory: " .. muosTextPath) end
        local yearPath = muosTextPath .. baseName .. ".year"
        log("Saving year to: " .. yearPath)
        local f = io.open(yearPath, "w")
        if f then f:write(result.year) f:close() end
    end

    if result.tempScreenPath and muosPreviewPath ~= "" then
        ok = os.execute("mkdir -p " .. utils.escapeShellArg(muosPreviewPath))
        if not ok then log("Error: Failed to create preview directory: " .. muosPreviewPath) end
        local destScreen = muosPreviewPath .. baseName .. ".png"
        log("Saving preview to: " .. destScreen)
        local inp = io.open(result.tempScreenPath, "rb")
        if inp then
            local content = inp:read("*a")
            inp:close()
            local out = io.open(destScreen, "wb")
            if out then
                out:write(content)
                out:close()
            end
        end
    end

    -- Update gamelist.xml
    local filename = item.name
    local metadataForXML = {
        name = baseName,
        image = "./" .. baseName .. ".png",
        desc = result.description,
        year = result.year
    }
    local romFullPath = item.fullPath or (muosArtPath:gsub("/box/.*", "") .. "/../" .. filename)
    gamelist.updateGamelistXML(romFullPath, metadataForXML, "add")
end

return M
