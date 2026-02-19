---@diagnostic disable: undefined-global
local filesystem = require "filesystem"
local utils = require "utils"

local M = {}

function M.load(global_state, log_func, loader_obj)
    -- Mark current images as invalid to trigger fade out
    global_state.imageInvalid = true
    global_state.screenshotInvalid = true

    global_state.currentYear = nil
    global_state.currentDescription = ""

    local item = global_state.focusedItem
    if not item then
        if #global_state.files == 0 then
            global_state.previewItem = nil -- Clear preview item if list is empty
            return
        end
        item = global_state.files[global_state.selectedIndex]
    end

    if not item or item.isDir then
        global_state.previewItem = nil -- Clear preview item for directories
        return
    end

    if log_func then log_func("Loading preview for: " .. item.name) end

    -- Determine which item to actually show the preview for
    local targetItem = item
    if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
        -- Pick a random version for the preview
        local randomIndex = global_state.love.math.random(1, #item.versions)
        targetItem = item.versions[randomIndex]
        if log_func then log_func("Juego Unico mode: picked random version for preview: " .. targetItem.name) end
    end

    global_state.previewItem = targetItem -- Set the global preview item


    -- Asegurar que el sistema detectado corresponde al archivo seleccionado (para lista mixta)
    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath =
        filesystem.updateSystemForFile(targetItem, global_state.romPath, global_state.systemName,
                                       global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath,
                                       global_state.love.filesystem.getInfo, global_state.love.graphics.newImage,
                                       log_func)

    local baseName = targetItem.name:gsub("%..-$", "")
    local itemSystemName = utils.getSystemNameForItem(targetItem, global_state.systemName, global_state.isVirtualRoot)

    if itemSystemName then
        local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
        if artPathForSystem then
            local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
            local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")
            -- Boxart
            local imgFile = artPathForSystem .. baseName .. ".png"
            if log_func then log_func("Requesting preview boxart: " .. imgFile) end
            if loader_obj then loader_obj:request(imgFile) end
            -- Screenshot
            local scrFile = previewPathForSystem .. baseName .. ".png"
            if log_func then log_func("Requesting preview screenshot: " .. scrFile) end
            if loader_obj then loader_obj:request(scrFile) end
            -- Description
            local txtFile = textPathForSystem .. baseName .. ".txt"
            if loader_obj then loader_obj:request(txtFile) end
            -- Year
            local yearFile = textPathForSystem .. baseName .. ".year"
            if loader_obj then loader_obj:request(yearFile) end
        end
    end
end

return M