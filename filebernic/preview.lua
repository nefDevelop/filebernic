---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-field

local filesystem = require "filesystem"
local utils = require "utils"

local M = {}

function M.load()
    -- Mark current images as invalid to trigger fade out
    imageInvalid = true
    screenshotInvalid = true
    
    currentYear = nil
    currentDescription = ""
    
    local item = focusedItem
    if not item then
        if #files == 0 then
            previewItem = nil -- Clear preview item if list is empty
            return
        end
        item = files[selectedIndex]
    end
    
    if not item or item.isDir then
        previewItem = nil -- Clear preview item for directories
        return
    end
    
    if log then log("Loading preview for: " .. item.name) end
    
    -- Determine which item to actually show the preview for
    local targetItem = item
    if launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
        -- Pick a random version for the preview
        local randomIndex = love.math.random(1, #item.versions)
        targetItem = item.versions[randomIndex]
        if log then log("Juego Unico mode: picked random version for preview: " .. targetItem.name) end
    end
    
    previewItem = targetItem -- Set the global preview item

    -- Asegurar que el sistema detectado corresponde al archivo seleccionado (para lista mixta)
    systemName, muosArtPath, muosTextPath, muosPreviewPath = filesystem.updateSystemForFile(targetItem, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    
    local baseName = targetItem.name:gsub("%..-$", "")
    local itemSystemName = utils.getSystemNameForItem(targetItem, systemName, isVirtualRoot)

    if itemSystemName then
        local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
        if artPathForSystem then
            local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
            local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

            -- Boxart
            local imgFile = artPathForSystem .. baseName .. ".png"
            if log then log("Requesting preview boxart: " .. imgFile) end
            if loader then loader:request(imgFile) end

            -- Screenshot
            local scrFile = previewPathForSystem .. baseName .. ".png"
            if log then log("Requesting preview screenshot: " .. scrFile) end
            if loader then loader:request(scrFile) end
            
            -- Description
            local txtFile = textPathForSystem .. baseName .. ".txt"
            if loader then loader:request(txtFile) end
            
            -- Year
            local yearFile = textPathForSystem .. baseName .. ".year"
            if loader then loader:request(yearFile) end
        end
    end
end

return M