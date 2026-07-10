---@diagnostic disable: undefined-global
local filesystem = require "filesystem"
local utils = require "utils"

local M = {}

local function requestItemAssets(item, systemName, log_func, loader_obj, gs)
    if not item or item.isDir then return end
    local targetItem = item
    if gs and gs.launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
        targetItem = item.versions[1]
    end

    local baseName = targetItem.name:gsub("%.[^%.]+$", "")
    local itemSystem = systemName or (gs and utils.getSystemNameForItem(targetItem, nil, gs and gs.isVirtualRoot))
    if not itemSystem then return end

    local artPath = filesystem.getArtPathForSystem(itemSystem)
    if not artPath then return end

    local textPath = artPath:gsub("/box/", "/text/")
    local previewPath = artPath:gsub("/box/", "/preview/")

    if loader_obj then
        loader_obj:request(artPath .. baseName .. ".png")
        loader_obj:request(previewPath .. baseName .. ".png")
        loader_obj:request(textPath .. baseName .. ".txt")
        loader_obj:request(textPath .. baseName .. ".year")
    end
end

function M.load(global_state, log_func, loader_obj)
    global_state.imageInvalid = true
    global_state.screenshotInvalid = true
    global_state.currentYear = nil
    global_state.currentDescription = ""

    local item = global_state.focusedItem
    if not item then
        if #global_state.files == 0 then
            global_state.previewItem = nil
            return
        end
        item = global_state.files[global_state.selectedIndex]
    end

    if not item or item.isDir then
        global_state.previewItem = nil
        return
    end

    if log_func then log_func("Loading preview for: " .. item.name) end

    local targetItem = item
    if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
        local randomIndex = global_state.love.math.random(1, #item.versions)
        targetItem = item.versions[randomIndex]
        if log_func then log_func("Juego Unico mode: picked random version for preview: " .. targetItem.name) end
    end

    global_state.previewItem = targetItem

    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath =
        filesystem.updateSystemForFile(targetItem, global_state.romPath, global_state.systemName,
                                       global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath)

    requestItemAssets(targetItem, global_state.systemName, log_func, loader_obj, global_state)

    -- Precargar assets de items adyacentes (2 adelante, 2 atrás)
    if not global_state.focusedItem and #global_state.files > 0 then
        local idx = global_state.selectedIndex
        local offsets = {-2, -1, 1, 2}
        for _, off in ipairs(offsets) do
            local adjIdx = idx + off
            if adjIdx >= 1 and adjIdx <= #global_state.files then
                local adjItem = global_state.files[adjIdx]
                if adjItem and not adjItem.isDir then
                    local adjSysName = utils.getSystemNameForItem(adjItem, global_state.systemName, global_state.isVirtualRoot)
                    requestItemAssets(adjItem, adjSysName, nil, loader_obj, global_state)
                end
            end
        end
    end
end

return M