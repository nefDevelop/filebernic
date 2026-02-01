---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-field

local filesystem = require "filesystem"
local utils = require "utils"

local M = {}

function M.load()
    -- Clear current preview data immediately to show loading state
    currentImage = nil
    currentScreenshot = nil
    currentYear = nil
    currentDescription = ""
    
    local item = focusedItem
    if not item then
        if #files == 0 then return end
        item = files[selectedIndex]
    end
    
    if not item or item.isDir then return end
    
    if log then log("Loading preview for: " .. item.name) end
    
    -- Asegurar que el sistema detectado corresponde al archivo seleccionado (para lista mixta)
    systemName, muosArtPath, muosTextPath, muosPreviewPath = filesystem.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    
    local baseName = item.name:gsub("%..-$", "")
    local itemSystemName = utils.getSystemNameForItem(item, systemName, isVirtualRoot)

    if itemSystemName then
        local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
        if artPathForSystem then
            local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
            local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

            -- Boxart
            local imgFile = artPathForSystem .. baseName .. ".png"
            if log then log("Requesting preview image: " .. imgFile) end
            if loader then loader:request(imgFile) end

            -- Screenshot
            local scrFile = previewPathForSystem .. baseName .. ".png"
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