local filesystem = require "filesystem"
local utils = require "utils"
local State = require "state"
local json = require "libs.dkjson"

local function jumpToNextLetter(global_state)
    if #global_state.files == 0 then return end -- Check if files table is empty
    local current = global_state.files[global_state.selectedIndex].name:sub(1,1):upper() -- Get first letter of current item
    for i = global_state.selectedIndex + 1, #global_state.files do -- Iterate from next item
        local c = global_state.files[i].name:sub(1,1):upper() -- Get first letter of iterated item
        if c ~= current then
            global_state.selectedIndex = i
            global_state.jumpLetter = c
            return
        end
    end
    global_state.selectedIndex = #global_state.files
    global_state.jumpLetter = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
end

local function jumpToPrevLetter(global_state)
    if #global_state.files == 0 then return end -- Check if files table is empty
    local current = global_state.files[global_state.selectedIndex].name:sub(1,1):upper() -- Get first letter of current item
    local prevLetterIdx = nil
    for i = global_state.selectedIndex - 1, 1, -1 do -- Iterate backwards from previous item
        local c = global_state.files[i].name:sub(1,1):upper()
        if c ~= current then
            prevLetterIdx = i
            break
        end
    end
    
    if prevLetterIdx then
        local targetChar = global_state.files[prevLetterIdx].name:sub(1,1):upper()
        for i = prevLetterIdx - 1, 1, -1 do
            local c = global_state.files[i].name:sub(1,1):upper()
            if c ~= targetChar then
                global_state.selectedIndex = i + 1
                global_state.jumpLetter = targetChar
                return
            end
        end
        global_state.selectedIndex = 1
    else
        global_state.selectedIndex = 1
    end
    global_state.jumpLetter = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
end

local function updateSystemPaths(global_state)
    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath, global_state.currentSystemIcon, global_state.currentSystemContentIcon = 
        filesystem.updateSystemPaths(global_state.systemName, global_state.romPath, global_state.log, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
end

local function refreshFiles(global_state)
    if global_state.romPath and global_state.romPath ~= "" and global_state.romPath:sub(-1) ~= "/" then global_state.romPath = global_state.romPath .. "/" end
    global_state.romPath = filesystem.fixPathCase(global_state.romPath)
    global_state.log("Refreshing files... Path: " .. global_state.romPath)
    
    local function updatePathsWrapper() -- This wrapper is called by filesystem.refreshFiles
         updateSystemPaths(global_state)
    end
    
    global_state.files, global_state.selectedFilesCount, global_state.selectedIndex, global_state.allFiles = filesystem.refreshFiles(updatePathsWrapper, global_state.files, global_state.selectedFilesCount, global_state.launchMode, global_state.hideEmpty, global_state.validExtensions, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles, global_state.log, global_state.favoriteRoms, global_state.hideFavorites)
    preview.load(global_state, global_state.log, global_state.loader)
end

local function saveHistory(global_state)
    filesystem.saveHistory(global_state.playedRoms)
end

local function saveLastPlayed(path)
    filesystem.saveLastPlayed(path)
end

local function addToHistory(path, global_state)
    global_state.playedRoms = filesystem.addToHistory(path, global_state.playedRoms)
end

local function deleteGameMedia(path)
    filesystem.deleteGameMedia(path)
end

local function removeFromIndex(path, global_state)
    if global_state.romIndex then
        global_state.romIndex = filesystem.removeFromIndex(path, global_state.romIndex, global_state.json.encode, global_state.love.filesystem.getSource, io.open)
    end
end
local function findSaveFiles(item, global_state)
    global_state.saveFiles, global_state.saveManagerSelection = filesystem.findSaveFiles(item)
end

local function performCleanupScan(global_state)
    -- filesystem.performCleanupScan(cleanupData, validExtensions, getSource, io_open, coroutine_create, coroutine_yield, table_insert, table_sort, romPath, muosArtPath, muosTextPath, muosPreviewPath, love_filesystem_getDirectoryItems, love_filesystem_getInfo)
    global_state.cleanupData.orphanedImages = {} -- Initialize here?
    -- Actually, looking at how it was called before... it seems I need to pass more things.
    -- Let's assume I need to pass all these.
    global_state.cleanupData, global_state.cleanupCoroutine = filesystem.performCleanupScan(
        global_state.cleanupData, 
        global_state.validExtensions, 
        global_state.love.filesystem.getSource, 
        io.open, 
        coroutine.create, 
        coroutine.yield, 
        table.insert, 
        table.sort
    )
    if global_state.cleanupData and not global_state.cleanupData.orphanedImages then global_state.cleanupData.orphanedImages = {} end
end

local function filterFiles(global_state)
    global_state.files = {}
    for _, item in ipairs(global_state.allFiles) do
        if item.name:lower():find(global_state.searchQuery:lower(), 1, true) then
            table.insert(global_state.files, item)
        end
    end
    global_state.selectedIndex = 1
end

local function startScraping(global_state)
    local item = global_state.files[global_state.selectedIndex]
    if not item then return end

    if global_state.lastScrapedRom ~= item.fullPath then
        os.execute("rm -f tmp/scraper_*.png")
        global_state.lastScrapedRom = item.fullPath
    end

    global_state.log("Starting interactive scrape for: " .. item.name)
    global_state.state = "SCRAPING_IN_PROGRESS"
    global_state.scraperResults = {}
    global_state.indexerChannelIn:push({ command = "scrape_single", item = item, config = global_state.config, systemName = global_state.systemName })
end

local function performBatchScrape(items)
    log("Starting batch scrape for " .. #items .. " items")
    state = "BATCH_SCRAPING"
    scraperProgress = { current = 0, total = #items, currentName = "", successes = 0, failures = 0 }
    os.execute("rm -f /tmp/scraper_*.png")
    indexerChannelIn:push({ command = "scrape_batch", items = items, config = config, systemName = systemName, romPath = romPath, muosArtPath = muosArtPath, muosTextPath = muosTextPath, muosPreviewPath = muosPreviewPath })
end

local function saveCompositeArt(global_state)
    global_state.log("Saving composite art...")
    local frontRes = global_state.scraperResults[global_state.scraperFrontIndex]
    local screenRes = global_state.scraperResults[global_state.scraperScreenIndex]
    local textRes = global_state.scraperResults[global_state.scraperTextIndex]
    
    local compositeResult = {
        imagePath = frontRes and frontRes.imagePath,
        tempPath = frontRes and frontRes.tempPath,
        screenshotPath = screenRes and screenRes.screenshotPath,
        tempScreenPath = screenRes and screenRes.tempScreenPath,
        description = textRes and textRes.description,
        year = textRes and textRes.year
    }

    local item = global_state.files[global_state.selectedIndex]
    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath = filesystem.updateSystemForFile(item, global_state.romPath, global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath)
    filesystem.saveScrapeResult(item, compositeResult, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath, global_state.log)
    
    local baseName = item.name:gsub("%..-$", "") -- Remove extension
    if global_state.muosArtPath and global_state.muosArtPath ~= "" then
        global_state.loader:invalidate(global_state.muosArtPath .. baseName .. ".png")
        global_state.loader:invalidate(global_state.muosTextPath .. baseName .. ".txt")
        global_state.loader:invalidate(global_state.muosTextPath .. baseName .. ".year")
        global_state.loader:invalidate(global_state.muosPreviewPath .. baseName .. ".png")
    end
    global_state.state = "LIST"
    preview.load(global_state, global_state.log, global_state.loader)
end

local stateHandlers = {}

-- Manejador para el modo Búsqueda
-- Manejador para el modo Búsqueda
function stateHandlers.SEARCH(key, global_state)
    if key == "up" then -- Move up in keyboard grid
        global_state.keyboardRow = math.max(1, global_state.keyboardRow - 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "down" then -- Move down in keyboard grid
        global_state.keyboardRow = math.min(#global_state.keyboardGrid, global_state.keyboardRow + 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "left" then -- Move left in keyboard grid
        global_state.keyboardCol = math.max(1, global_state.keyboardCol - 1)
        global_state.inputCooldown = 0.15
    elseif key == "right" then -- Move right in keyboard grid
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol + 1)
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then -- 'a' button
        local char = global_state.keyboardGrid[global_state.keyboardRow][global_state.keyboardCol] -- Get character from keyboard grid
        if char == "OK" then
            global_state.state = "LIST"
            global_state.love.keyboard.setTextInput(false)
        elseif char == "BACK" then
            global_state.searchQuery = global_state.searchQuery:sub(1, -2)
            filterFiles(global_state)
        elseif char == "SPACE" then
            global_state.searchQuery = global_state.searchQuery .. " "
            filterFiles(global_state)
        else
            global_state.searchQuery = global_state.searchQuery .. char
            filterFiles(global_state)
        end
        global_state.inputCooldown = 0.2
    elseif key == "f" then -- L1: Exit search, keep filter active
        global_state.state = "LIST"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    elseif key == "f2" then -- L2: Clear filter and exit search
        global_state.searchQuery = ""
        filterFiles(global_state)
        global_state.state = "LIST"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then -- 'b' button (Cancel search)
        global_state.state = "LIST"
        global_state.files = global_state.allFiles -- Restore full list
        global_state.searchQuery = ""
        global_state.love.keyboard.setTextInput(false) -- Disable text input
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Edición de Texto (API Key)
function stateHandlers.EDIT_TEXT(key, global_state)
    if key == "up" then
        global_state.keyboardRow = math.max(1, global_state.keyboardRow - 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "down" then
        global_state.keyboardRow = math.min(#global_state.keyboardGrid, global_state.keyboardRow + 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "left" then
        global_state.keyboardCol = math.max(1, global_state.keyboardCol - 1)
        global_state.inputCooldown = 0.15
    elseif key == "right" then
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol + 1)
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then
        local char = global_state.keyboardGrid[global_state.keyboardRow][global_state.keyboardCol]
        if char == "OK" then
            -- Save and exit
            if global_state.textEditKey then
                global_state.config[global_state.textEditKey] = global_state.textToEdit
            else
                global_state.config.thegamesdb_apikey = global_state.textToEdit -- Fallback
            end
            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end
            
            global_state.state = "OPTIONS_MENU"
            global_state.love.keyboard.setTextInput(false)
        elseif char == "BACK" then
            global_state.textToEdit = global_state.textToEdit:sub(1, -2)
        elseif char == "SPACE" then
            global_state.textToEdit = global_state.textToEdit .. " "
        else
            global_state.textToEdit = global_state.textToEdit .. char
        end
        global_state.inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then
        global_state.state = "OPTIONS_MENU"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para el Menú de Opciones
function stateHandlers.OPTIONS_MENU(key, global_state)
    local L = global_state.L
    if key == "return" or key == "kpenter" or (key == "return" and global_state.love.joystick.getJoystickCount() == 0) then -- Confirm selection
        if global_state.menuTitle == "Seleccionar Sistema" then
             local choice = global_state.menuOptions[global_state.menuSelection]
             local core = nil
             if choice == "Arcade (FBNeo)" then core = "fbneo_libretro.so"
             elseif choice == "Super Nintendo" then core = "snes9x_libretro.so"
             elseif choice == "Nintendo (NES)" then core = "fceumm_libretro.so"
             elseif choice == "Sega Genesis/MD" then core = "picodrive_libretro.so"
             elseif choice == "PlayStation" then core = "pcsx_rearmed_libretro.so"
             elseif choice == "GBA" then core = "mgba_libretro.so"
             elseif choice == "GBC/GB" then core = "gambatte_libretro.so"
             end
             
             if core then
                 local f = io.open("/tmp/launch_core", "w")
                 if f then f:write(core) f:close() end
             end
             
             local romToLaunch = global_state.itemToLaunch
             global_state.log("Selected ROM for launch (with core): " .. romToLaunch)
             global_state.lastPlayedRom = romToLaunch
             saveLastPlayed(global_state.lastPlayedRom)
             filesystem.savePendingHistory(global_state.lastPlayedRom)
             global_state.launching = true
             global_state.launchTimer = 0
             return
        end

        if #global_state.menuStack > 0 then
             -- Acciones del sub-menú de versión
             local opt = global_state.menuOptions[global_state.menuSelection]
             local optText = type(opt) == "table" and opt.text or opt
             
             if optText == L.get("info") then
                 preview.load(global_state, global_state.log, global_state.loader)
                 global_state.state = "INFO_VIEW"
             elseif optText == L.get("scraper") then -- Open scraper view
                 global_state.state = "SCRAPER_VIEW"
             elseif optText:match(L.get("save_games")) then
                 global_state.state = "SAVE_MANAGER"
             elseif optText == L.get("delete") then
                 local fullPath = global_state.focusedItem.fullPath
                 deleteGameMedia(fullPath)
                 local success, err = os.remove(fullPath)
                 if not success then
                     global_state.log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                 else
                     global_state.log("Archivo borrado con éxito: " .. fullPath)
                     filesystem.logDeletion(fullPath, global_state.json.encode, global_state.json.decode)
                 end
                 -- Always update internal state
                 if global_state.romIndex then removeFromIndex(fullPath, global_state) end
                 if global_state.playedRoms[fullPath] then global_state.playedRoms[fullPath] = nil; saveHistory(global_state) end
                 if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                     global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                        filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                        global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                        global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                        global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                     global_state.preview.load(global_state, global_state.log, global_state.loader)
                 else -- Not virtual root, refresh files
                     refreshFiles(global_state)
                 end
                 global_state.state = "LIST"
                 global_state.menuStack = {}
                 global_state.focusedItem = nil
             elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
                 local fullPath = global_state.focusedItem.fullPath
                 if global_state.favoriteRoms[fullPath] then
                     global_state.favoriteRoms[fullPath] = nil
                     global_state.favAnimTarget = 0
                     if type(opt) == "table" then opt.text = L.get("add_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("add_favorite") end
                 else
                     global_state.favoriteRoms[fullPath] = true -- Mark as favorite
                     global_state.favAnimTarget = 1
                     if type(opt) == "table" then opt.text = L.get("remove_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("remove_favorite") end
                 end
                 global_state.favAnimIndex = global_state.selectedIndex
                 filesystem.saveFavorites(global_state.favoriteRoms, global_state.json.encode)
                 if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                     global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                        filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                        global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                        global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                        global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                     global_state.preview.load(global_state, global_state.log, global_state.loader)
                 end
             end
             global_state.inputCooldown = 0.3 -- Use global_state.inputCooldown
             return
        end

        if global_state.menuTitle == L.get("version") then
             local item = global_state.files[global_state.selectedIndex]
             if item and item.versions and item.versions[global_state.menuSelection] then
                 local v = item.versions[global_state.menuSelection]
                 global_state.lastPlayedRom = v.fullPath
                 saveLastPlayed(global_state.lastPlayedRom, global_state)
                 addToHistory(global_state.lastPlayedRom, global_state)
                 global_state.launching = true
                 global_state.launchTimer = 0
             end
             return
        end
        
        local opt = global_state.menuOptions[global_state.menuSelection]
        local optText = type(opt) == "table" and opt.text or opt

        if optText == "Borrar" then
            if global_state.selectedFilesCount > 0 then
                global_state.menuTitle = "Confirmar Borrado"
                global_state.menuMessage = "¿Borrar " .. global_state.selectedFilesCount .. " archivos seleccionados?"
                global_state.menuOptions = {"Borrar", "Cancelar"}
                global_state.menuSelection = 2
                global_state.log("Menu opened: " .. global_state.menuTitle)
                global_state.state = "DELETE_MENU"
            elseif (not global_state.isVirtualRoot or global_state.launchMode == "Juego Unico") and global_state.files[global_state.selectedIndex] and (not global_state.files[global_state.selectedIndex].isDir or global_state.files[global_state.selectedIndex].name ~= "..") then
                global_state.itemToDelete = global_state.files[global_state.selectedIndex]
                global_state.menuTitle = "Confirmar Borrado"
                global_state.menuMessage = "¿Borrar este archivo?\n" .. global_state.itemToDelete.name
                global_state.menuOptions = {"Borrar", "Cancelar"}
                global_state.menuSelection = 2
                global_state.log("Menu opened: " .. global_state.menuTitle)
                global_state.state = "DELETE_MENU"
            end
        elseif optText == "Info" then
            global_state.state = "INFO_VIEW"
            global_state.inputCooldown = 0.2
        elseif optText == "Scraper" then
            if global_state.selectedFilesCount > 0 then
                local items = {}
                for _, f in ipairs(global_state.files) do
                    if f.selected then table.insert(items, f) end
                end
                performBatchScrape(items)
                global_state.inputCooldown = 0.2
            else
                global_state.state = "SCRAPER_VIEW"
                global_state.scraperSelection = 1
                global_state.inputCooldown = 0.2
            end
        elseif optText == L.get("delete_sd1") then
            local item = global_state.files[global_state.selectedIndex]
            local pathToDelete = item.fullPath:find("/mnt/mmc") and item.fullPath or item.secondaryPath
            deleteGameMedia(pathToDelete)
            local success, err = os.remove(pathToDelete)
            if not success then
                global_state.log("Error al borrar archivo (o ya no existía): " .. pathToDelete .. " - " .. tostring(err))
            else
                global_state.log("Archivo borrado con éxito: " .. pathToDelete)
                filesystem.logDeletion(pathToDelete, global_state.json.encode, global_state.json.decode)
            end
            if global_state.romIndex then removeFromIndex(pathToDelete, global_state) end -- Remove from index if it exists
            if global_state.playedRoms[pathToDelete] then global_state.playedRoms[pathToDelete] = nil saveHistory(global_state) end
            if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            else
                refreshFiles(global_state)
            end
            global_state.state = "LIST"
        elseif optText == L.get("delete_sd2") then
            local item = global_state.files[global_state.selectedIndex]
            local pathToDelete = item.fullPath:find("/mnt/sdcard") and item.fullPath or item.secondaryPath
            deleteGameMedia(pathToDelete)
            local success, err = os.remove(pathToDelete)
            if not success then
                global_state.log("Error al borrar archivo (o ya no existía): " .. pathToDelete .. " - " .. tostring(err))
            else
                global_state.log("Archivo borrado con éxito: " .. pathToDelete)
                filesystem.logDeletion(pathToDelete, global_state.json.encode, global_state.json.decode)
            end
            if global_state.romIndex then removeFromIndex(pathToDelete, global_state) end -- Remove from index if it exists
            if global_state.playedRoms[pathToDelete] then global_state.playedRoms[pathToDelete] = nil saveHistory(global_state) end
            if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            else
                refreshFiles(global_state)
            end
            global_state.state = "LIST"
        elseif optText:match(L.get("mode") .. ":") then
            global_state.launchMode = (global_state.launchMode == "Folder") and "Juego Unico" or "Folder"
            local displayMode = (global_state.launchMode == "Folder") and L.get("folder") or L.get("single_game")
            local newVal = L.get("mode") .. ": " .. displayMode
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem) -- Save app state
            global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
               filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
               global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
               global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
               global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
            preview.load(global_state, global_state.log, global_state.loader)
        elseif optText:match(L.get("hide_empty")) then
            global_state.hideEmpty = not global_state.hideEmpty
            local newVal = L.get("hide_empty") .. ": " .. (global_state.hideEmpty and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            end
        elseif optText:match(L.get("view")) then
            global_state.viewMode = (global_state.viewMode == "LIST") and "GRID" or "LIST"
            local displayView = (global_state.viewMode == "LIST") and L.get("list") or L.get("grid")
            local newVal = L.get("view") .. ": " .. displayView
            if type(opt) == "table" then
                opt.text = newVal 
            else 
                global_state.menuOptions[global_state.menuSelection] = newVal 
            end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem) -- Save app state
        elseif optText == L.get("cleanup") then
            global_state.state = "CLEANUP_MENU"
            global_state.cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
            global_state.inputCooldown = 0.2 -- Reset cooldown
        elseif optText:match(L.get("mark_played")) then
            global_state.markPlayed = not global_state.markPlayed
            local newVal = L.get("mark_played") .. ": " .. (global_state.markPlayed and L.get("yes") or L.get("no"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
        elseif optText:match(L.get("hide_favorites")) then
            global_state.hideFavorites = not global_state.hideFavorites
            local newVal = L.get("hide_favorites") .. ": " .. (global_state.hideFavorites and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end -- Update option text
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            else
                refreshFiles(global_state)
            end
        elseif optText == L.get("api_settings") then
            table.insert(global_state.menuStack, {
                 title = global_state.menuTitle,
                 message = global_state.menuMessage,
                 options = global_state.menuOptions,
                 selection = global_state.menuSelection
            })
            global_state.menuTitle = L.get("api_settings")
            global_state.menuMessage = (global_state.config.thegamesdb_apikey == "") and L.get("missing_api_key_warn") or ""
            global_state.menuOptions = {
                L.get("scraper_api") .. ": " .. (global_state.config.scraperApi or "all"),
                L.get("api_key") .. ": " .. (global_state.config.thegamesdb_apikey ~= "" and "******" or "Empty")
            }
            table.insert(global_state.menuOptions, L.get("ss_user") .. ": " .. (global_state.config.screenscraper_user ~= "" and global_state.config.screenscraper_user or "Empty"))
            table.insert(global_state.menuOptions, L.get("ss_password") .. ": " .. (global_state.config.screenscraper_password ~= "" and "******" or "Empty"))
            global_state.menuSelection = 1
            global_state.menuAnim = 0
        elseif optText:match(L.get("scraper_api")) then
            local current = global_state.config.scraperApi or "all"
            local nextApi = "all"
            if current == "all" then nextApi = "libretro"
            elseif current == "libretro" then nextApi = "thegamesdb"
            elseif current == "thegamesdb" then nextApi = "all" end
            global_state.config.scraperApi = nextApi
            
            -- Save config
            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end
            
            local newVal = L.get("scraper_api") .. ": " .. nextApi
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
        elseif optText:match(L.get("api_key")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.thegamesdb_apikey or ""
            global_state.textEditLabel = L.get("api_key")
            global_state.textEditKey = "thegamesdb_apikey"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("ss_user")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.screenscraper_user or ""
            global_state.textEditLabel = L.get("ss_user")
            global_state.textEditKey = "screenscraper_user"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("ss_password")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.screenscraper_password or ""
            global_state.textEditLabel = L.get("ss_password")
            global_state.textEditKey = "screenscraper_password"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
            local item = global_state.files[global_state.selectedIndex] -- Get selected item
            local path = item.fullPath
            if global_state.favoriteRoms[path] then
                global_state.favoriteRoms[path] = nil
                global_state.favAnimTarget = 0
                if type(opt) == "table" then opt.text = L.get("add_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("add_favorite") end
            else
                global_state.favoriteRoms[path] = true
                global_state.favAnimTarget = 1
                if type(opt) == "table" then opt.text = L.get("remove_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("remove_favorite") end
            end
            global_state.favAnimIndex = global_state.selectedIndex
            filesystem.saveFavorites(global_state.favoriteRoms, global_state.json.encode)
            
            local inFavoritesView = (global_state.romPath == "@Favorites/")
            
            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites, global_state.log, global_state.loader)
            else
                refreshFiles(global_state)
            end
            
            if inFavoritesView then
                global_state.state = "LIST"
                global_state.closingMenu = true
            end
        elseif optText == L.get("reindex") then
            -- Force reindexing
            if global_state.forceReindex then
                global_state.forceReindex(global_state)
            else
                 global_state.log("Error: forceReindex function not found in global_state")
            end
            global_state.state = "LIST" -- Close menu and return to list (which will show indexing status)
        elseif optText:match(L.get("copy")) or optText:match(L.get("move_to"):match("^(.*)%s")) then -- Match "Mover a" prefix
            local isMove = optText:match(L.get("move_to"):match("^(.*)%s"))
            local targetDir, _ = filesystem.getTargetSDPath(global_state.romPath, global_state.config)
            
            if targetDir then
                os.execute('mkdir -p "' .. targetDir .. '"')
                
                local function processItem(item)
                    local src = global_state.romPath .. item.name
                    local dst = targetDir .. item.name
                    local cmd = (isMove and 'mv "' or 'cp "') .. src .. '" "' .. dst .. '"'
                    os.execute(cmd)
                    if isMove and global_state.playedRoms[src] then
                        global_state.playedRoms[src] = nil
                    end
                end

                if selectedFilesCount > 0 then
                    for _, item in ipairs(files) do
                        if item.selected then processItem(item) end
                    end
                else
                    processItem(files[selectedIndex])
                end

                if isMove then saveHistory(global_state) end
                refreshFiles(global_state)
                global_state.state = "LIST"
            end
        elseif optText:match(L.get("save_games")) then
            global_state.state = "SAVE_MANAGER"
        end
        global_state.inputCooldown = 0.2
    elseif key == "tab" then
         if global_state.menuTitle == L.get("config") then return end -- Don't open submenu from config

         if global_state.menuTitle == L.get("version") then
             local item = global_state.files[global_state.selectedIndex]
             local ver = item.versions[global_state.menuSelection]
             
             table.insert(global_state.menuStack, {
                 title = global_state.menuTitle,
                 message = global_state.menuMessage,
                 options = global_state.menuOptions,
                 selection = global_state.menuSelection,
                 focusedItem = global_state.focusedItem
             })
             global_state.focusedItem = ver -- Set focused item to version
             
             global_state.menuTitle = L.get("options") .. ": " .. ver.name
             global_state.menuMessage = ver.name
             findSaveFiles(ver, global_state)
             global_state.menuOptions = {L.get("info"), L.get("scraper"), L.get("save_games") .. " (" .. #global_state.saveFiles .. ")", L.get("delete")}

             if global_state.favoriteRoms[ver.fullPath] then
                 table.insert(global_state.menuOptions, 2, L.get("remove_favorite"))
             else
                 table.insert(global_state.menuOptions, 2, L.get("add_favorite"))
             end

             global_state.menuSelection = 1
             global_state.menuAnim = 0 -- Reiniciar animación para efecto de entrada del submenú
             global_state.inputCooldown = 0.2
             return
         end

        -- If in a submenu (there's a parent), Tab should not close everything at once
        if #global_state.menuStack > 0 then return end

        global_state.closingMenu = true
        global_state.menuStack = {} -- Limpiar pila para evitar fantasmas al reabrir
        global_state.log("Menu exited: " .. global_state.menuTitle)
        global_state.inputCooldown = 0.2
    elseif key == "backspace" then
        if #global_state.menuStack > 0 then
             global_state.closingMenu = true -- Trigger animation, menu will be popped on completion
             global_state.inputCooldown = 0.2 -- Reset cooldown
        else
            global_state.closingMenu = true
            global_state.log("Menu exited: " .. global_state.menuTitle)
            global_state.inputCooldown = 0.2
        end
    end
end

-- Manejador para la Vista de Información
function stateHandlers.INFO_VIEW(key, global_state)
    if key == "backspace" or key == "b" or key == "escape" then
        if #global_state.menuStack > 0 then -- If there's a parent menu, go back to it
            global_state.state = "OPTIONS_MENU"
        else
            global_state.closingMenu = true
        end
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Opciones de Scraper
function stateHandlers.SCRAPER_OPTIONS(key, global_state)
    local L = global_state.L
    if key == "return" or key == "kpenter" then
        local opt = global_state.menuOptions[global_state.menuSelection]
        local text = type(opt) == "table" and opt.text or opt

        if text == L.get("clean") then -- If "Clean" option is selected
            local item = global_state.files[global_state.selectedIndex]
            local baseName = item.name:gsub("%..-$", "")
            os.remove(global_state.muosArtPath .. baseName .. ".png")
            os.remove(global_state.muosTextPath .. baseName .. ".txt")
            os.remove(global_state.muosTextPath .. baseName .. ".year")
            os.remove(global_state.muosPreviewPath .. baseName .. ".png")
            preview.load(global_state, global_state.log, global_state.loader)
            global_state.state = "SCRAPER_VIEW"
        elseif opt.value == "tgdb" or opt.value == "libretro" or opt.value == "ss" then
            local api = global_state.config.scraperApi or "all"
            local tgdbOn = (api == "all" or api:find("thegamesdb"))
            local libretroOn = (api == "all" or api:find("libretro"))
            local ssOn = (api == "all" or api:find("screenscraper"))

            if opt.value == "tgdb" then tgdbOn = not tgdbOn end
            if opt.value == "libretro" then libretroOn = not libretroOn end
            if opt.value == "ss" then ssOn = not ssOn end

            if tgdbOn and libretroOn and ssOn then
                global_state.config.scraperApi = "all"
            else
                local newApi = {}
                if tgdbOn then table.insert(newApi, "thegamesdb") end
                if libretroOn then table.insert(newApi, "libretro") end
                if ssOn then table.insert(newApi, "screenscraper") end
                
                if #newApi == 0 then global_state.config.scraperApi = "none"
                else global_state.config.scraperApi = table.concat(newApi, ",") end
            end

            -- Update menu text
            global_state.menuOptions[1].text = "TheGamesDB: " .. (tgdbOn and L.get("on") or L.get("off"))
            global_state.menuOptions[2].text = "Libretro: " .. (libretroOn and L.get("on") or L.get("off"))
            global_state.menuOptions[3].text = "ScreenScraper: " .. (ssOn and L.get("on") or L.get("off"))

            -- Save config
            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end
        end
        global_state.inputCooldown = 0.2
    elseif key == "backspace" or key == "x" or key == "escape" then
        global_state.closingMenu = true
        global_state.log("Scraper Options exited")
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Vista de Scraper
function stateHandlers.SCRAPER_VIEW(key, global_state)
    if key == "backspace" then -- 'b' button
        if #global_state.menuStack > 0 then -- If there's a parent menu, go back to it
            global_state.state = "OPTIONS_MENU"
        else
            global_state.state = "LIST"
        end
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    elseif key == "left" or key == "right" then
        if global_state.scraperSelection == 1 then global_state.scraperSelection = 2 else global_state.scraperSelection = 1 end
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" then -- 'a' button
        if global_state.scraperSelection == 1 then
            startScraping(global_state)
        elseif global_state.scraperSelection == 2 then
            global_state.state = "SCRAPER_OPTIONS"
            global_state.menuTitle = global_state.L.get("options") -- Set menu title
            global_state.menuAnim = 0
            global_state.menuMessage = ""
            
            local api = global_state.config.scraperApi or "all"
            local tgdbOn = (api == "all" or api:find("thegamesdb"))
            local libretroOn = (api == "all" or api:find("libretro"))
            local ssOn = (api == "all" or api:find("screenscraper"))
            
            global_state.menuOptions = {
                {text = "TheGamesDB: " .. (tgdbOn and global_state.L.get("on") or global_state.L.get("off")), value = "tgdb"},
                {text = "Libretro: " .. (libretroOn and global_state.L.get("on") or global_state.L.get("off")), value = "libretro"},
                {text = "ScreenScraper: " .. (ssOn and global_state.L.get("on") or global_state.L.get("off")), value = "ss"},
                {text = global_state.L.get("clean")}
            }
            global_state.menuSelection = 1
            global_state.log("Menu opened: " .. global_state.menuTitle)
        end
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Resultados de Scraper
function stateHandlers.SCRAPER_RESULTS(key, global_state)
    local count = #global_state.scraperResults
    if count == 0 then
        if key == "backspace" then global_state.state = "SCRAPER_VIEW" end
        return
    end

    if key == "backspace" then
        global_state.state = "SCRAPER_VIEW"
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    elseif key == "f" or key == "tab" then -- L1 / Tab cycles focus
        if global_state.scraperFocus == "FRONT" then global_state.scraperFocus = "SCREEN"
        elseif global_state.scraperFocus == "SCREEN" then global_state.scraperFocus = "TEXT"
        else global_state.scraperFocus = "FRONT" end
        global_state.inputCooldown = 0.2
    elseif key == "left" then
        if global_state.scraperFocus == "FRONT" then
            global_state.scraperFrontIndex = global_state.scraperFrontIndex - 1
            if global_state.scraperFrontIndex < 1 then global_state.scraperFrontIndex = count end
            global_state.scraperTextIndex = global_state.scraperFrontIndex -- Sync text
            global_state.scraperScreenIndex = global_state.scraperFrontIndex -- Sync screen
        elseif global_state.scraperFocus == "SCREEN" then
            global_state.scraperScreenIndex = global_state.scraperScreenIndex - 1
            if global_state.scraperScreenIndex < 1 then global_state.scraperScreenIndex = count end
        elseif global_state.scraperFocus == "TEXT" then
            global_state.scraperTextIndex = global_state.scraperTextIndex - 1
            if global_state.scraperTextIndex < 1 then global_state.scraperTextIndex = count end
        end
        global_state.inputCooldown = 0.15
    elseif key == "right" then
        if global_state.scraperFocus == "FRONT" then
            global_state.scraperFrontIndex = global_state.scraperFrontIndex + 1
            if global_state.scraperFrontIndex > count then global_state.scraperFrontIndex = 1 end
            global_state.scraperTextIndex = global_state.scraperFrontIndex -- Sync text
            global_state.scraperScreenIndex = global_state.scraperFrontIndex -- Sync screen
        elseif global_state.scraperFocus == "SCREEN" then
            global_state.scraperScreenIndex = global_state.scraperScreenIndex + 1
            if global_state.scraperScreenIndex > count then global_state.scraperScreenIndex = 1 end
        elseif global_state.scraperFocus == "TEXT" then
            global_state.scraperTextIndex = global_state.scraperTextIndex + 1
            if global_state.scraperTextIndex > count then global_state.scraperTextIndex = 1 end
        end
        global_state.inputCooldown = 0.15 -- Reset cooldown
    elseif (key == "return" or key == "kpenter") then
        saveCompositeArt(global_state)
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Gestor de Partidas
function stateHandlers.SAVE_MANAGER(key, global_state)
    if key == "backspace" or key == "escape" then
        if #global_state.menuStack > 0 then -- If there's a parent menu, go back to it
            global_state.state = "OPTIONS_MENU"
        else
            global_state.state = "LIST"
        end
        global_state.inputCooldown = 0.2
    elseif key == "return" or key == "kpenter" then
        -- Copiar save a la otra SD
        local item = global_state.saveFiles[global_state.saveManagerSelection]
        if item then -- If an item is selected
            local targetRoot = item.location == "SD1" and "/mnt/sdcard" or "/mnt/mmc"
            -- Reconstruir ruta destino preservando estructura desde /mnt/xxx/
            local relPath = item.fullPath:match("/mnt/[^/]+/(.*)")
            if relPath then
                local destPath = targetRoot .. "/" .. relPath
                local destDir = destPath:match("(.*/)")
                os.execute('mkdir -p "' .. destDir .. '"')
                os.execute('cp "' .. item.fullPath .. '" "' .. destPath .. '"')
                -- Refrescar lista para ver el nuevo archivo
                findSaveFiles(global_state.files[global_state.selectedIndex], global_state)
            end -- End if relPath
        end
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Menú de Limpieza
function stateHandlers.CLEANUP_MENU(key, global_state)
    if global_state.cleanupData.confirming then
        if key == "backspace" or key == "escape" or key == "b" then
            global_state.cleanupData.confirming = false
            global_state.inputCooldown = 0.2
        elseif key == "return" or key == "kpenter" or key == "space" or key == "a" then -- Confirm action
            -- Ejecutar acción de borrado confirmada
            if global_state.cleanupData.cursor.col == 1 then
                -- Columna Huérfanos
                if global_state.cleanupData.cursor.row == 1 then
                    -- Borrar TODOS
                    for _, orphan in ipairs(global_state.cleanupData.orphans) do
                        local success, err = os.remove(orphan.fullPath)
                        if success then
                            global_state.log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, global_state.json.encode, global_state.json.decode)
                        else global_state.log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                    end
                    global_state.cleanupData.orphans = {}
                else
                    -- Borrar Individual
                    local idx = global_state.cleanupData.cursor.row - 1
                    local orphan = global_state.cleanupData.orphans[idx]
                    if orphan then
                        local success, err = os.remove(orphan.fullPath) -- Delete individual orphan
                        if success then 
                            global_state.log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, global_state.json.encode, global_state.json.decode)
                        else global_state.log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                        table.remove(global_state.cleanupData.orphans, idx)
                        if global_state.cleanupData.cursor.row > #global_state.cleanupData.orphans + 1 then
                            global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.orphans + 1)
                        end
                    end
                end
            elseif global_state.cleanupData.cursor.col == 3 then
                -- Columna Imágenes Huérfanas
                local idx = global_state.cleanupData.cursor.row
                local item = global_state.cleanupData.orphanedImages[idx]
                if item then
                    local success, err = os.remove(item.fullPath) -- Delete orphaned image
                    if success then 
                        global_state.log("Cleanup: Borrado " .. item.fullPath)
                        filesystem.logDeletion(item.fullPath, global_state.json.encode, global_state.json.decode)
                    else global_state.log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) end
                    -- También borrar preview/text/year si existen?
                    -- Por ahora solo borramos el archivo listado (boxart)
                    table.remove(global_state.cleanupData.orphanedImages, idx)
                    
                    if global_state.cleanupData.cursor.row > #global_state.cleanupData.orphanedImages then
                        global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.orphanedImages)
                    end
                end
            else
                -- Columna Duplicados: Borrar archivo seleccionado
                local idx = global_state.cleanupData.cursor.row
                local item = global_state.cleanupData.duplicates[idx]
                if item then
                    local success, err = os.remove(item.fullPath) -- Delete duplicate file
                    if success then
                        global_state.log("Cleanup: Borrado " .. item.fullPath) 
                        filesystem.logDeletion(item.fullPath, global_state.json.encode, global_state.json.decode) -- Log deletion
                        if global_state.romIndex then removeFromIndex(item.fullPath, global_state) end
                    else 
                        global_state.log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) 
                    end
                    table.remove(global_state.cleanupData.duplicates, idx)
                    
                    if global_state.cleanupData.cursor.row > #global_state.cleanupData.duplicates then
                        global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.duplicates)
                    end
                    -- Si estaba en el historial, quitarlo
                    if global_state.playedRoms[item.fullPath] then global_state.playedRoms[item.fullPath] = nil end
                end
            end
            
            global_state.cleanupData.confirming = false
            global_state.inputCooldown = 0.2 -- Reset cooldown
        end
        return
    end

    if key == "backspace" or key == "escape" then
        global_state.state = "LIST"
        global_state.inputCooldown = 0.2
    elseif not global_state.cleanupData.scanned then
        if key == "return" or key == "kpenter" then -- Start scan
            performCleanupScan(global_state)
        end
    else
        -- Navegación en resultados
        if key == "f" then -- L1: Cycle columns
            if global_state.cleanupData.cursor.col == 1 then
                global_state.cleanupData.cursor.col = 2
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.duplicates)
            elseif global_state.cleanupData.cursor.col == 2 and #global_state.cleanupData.orphanedImages > 0 then
                global_state.cleanupData.cursor.col = 3 -- Move to orphaned images column
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.orphanedImages)
            else
                global_state.cleanupData.cursor.col = 1
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.orphans + 1)
            end
        elseif key == "left" then -- Page Up (Pagination)
            local maxRows = (global_state.cleanupData.cursor.col == 1 and #global_state.cleanupData.orphans + 1) or (global_state.cleanupData.cursor.col == 2 and #global_state.cleanupData.duplicates) or #global_state.cleanupData.orphanedImages
            global_state.cleanupData.cursor.row = math.max(1, global_state.cleanupData.cursor.row - global_state.pageSize)
        elseif key == "right" then -- Page Down (Pagination)
            local maxRows = (global_state.cleanupData.cursor.col == 1 and #global_state.cleanupData.orphans + 1) or (global_state.cleanupData.cursor.col == 2 and #global_state.cleanupData.duplicates) or #global_state.cleanupData.orphanedImages -- Max rows for current column
            global_state.cleanupData.cursor.row = math.min(maxRows, global_state.cleanupData.cursor.row + global_state.pageSize)
        elseif key == "return" or key == "kpenter" then
            -- Verificar si hay algo válido seleccionado para borrar
            local valid = false
            if global_state.cleanupData.cursor.col == 1 then
                if global_state.cleanupData.cursor.row == 1 and #global_state.cleanupData.orphans > 0 then valid = true
                elseif global_state.cleanupData.cursor.row > 1 and global_state.cleanupData.orphans[global_state.cleanupData.cursor.row - 1] then valid = true end
            elseif global_state.cleanupData.cursor.col == 3 then
                if global_state.cleanupData.orphanedImages[global_state.cleanupData.cursor.row] then valid = true end
            else
                if global_state.cleanupData.duplicates[global_state.cleanupData.cursor.row] then valid = true end
            end
            
            if valid then
                global_state.cleanupData.confirming = true -- Show confirmation modal
                global_state.inputCooldown = 0.2
            end
        end
    end
end

-- Manejador para Menú de Borrado
function stateHandlers.DELETE_MENU(key, global_state)
    if key == "return" or key == "space" or key == "kpenter" then
        if global_state.menuOptions[global_state.menuSelection] == global_state.L.get("delete") then
            if global_state.selectedFilesCount > 0 then -- Delete multiple selected files
                for _, item in ipairs(global_state.files) do
                    if item.selected then
                        local fullPath = item.fullPath or (global_state.romPath .. item.name)
                        deleteGameMedia(fullPath)
                        local success, err = os.remove(fullPath)
                        if not success then
                            global_state.log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                        else
                            global_state.log("Archivo borrado con éxito: " .. fullPath)
                            filesystem.logDeletion(fullPath, global_state.json.encode, global_state.json.decode)
                        end -- End if success
                        if global_state.romIndex then removeFromIndex(fullPath, global_state) end -- Remove from index if it exists
                        if global_state.playedRoms[fullPath] then
                            global_state.playedRoms[fullPath] = nil
                        end
                    end
                end
                saveHistory(global_state)
                if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                    global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                    preview.load(global_state, global_state.log, global_state.loader) -- Reload preview after deletion
                else
                    refreshFiles(global_state)
                end
                global_state.itemToDelete = nil -- Clear item to delete
            elseif global_state.itemToDelete then
                local fullPath = global_state.itemToDelete.fullPath or (global_state.romPath .. global_state.itemToDelete.name)
                deleteGameMedia(fullPath)
                local success, err = os.remove(fullPath)
                if not success then
                    global_state.log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                else
                    global_state.log("Archivo borrado con éxito: " .. fullPath)
                    filesystem.logDeletion(fullPath, global_state.json.encode, global_state.json.decode)
                end -- End if success
                if global_state.romIndex then removeFromIndex(fullPath, global_state) end -- Remove from index if it exists
                if global_state.playedRoms[fullPath] then
                    global_state.playedRoms[fullPath] = nil
                    saveHistory(global_state)
                end
                -- Deselect to avoid errors, then refresh
                if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                    global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                    preview.load(global_state, global_state.log, global_state.loader) -- Reload preview after deletion
                else
                    refreshFiles(global_state)
                end
                global_state.itemToDelete = nil -- Clear item to delete
            end
        end
        global_state.inputCooldown = 0.2
        global_state.state = "LIST"
        global_state.closingMenu = true
        global_state.log("Delete Menu exited")
    elseif key == "backspace" then -- Cancel
        global_state.itemToDelete = nil
        global_state.inputCooldown = 0.2
        global_state.closingMenu = true
        global_state.log("Delete Menu exited")
    end
end

-- Manejador para Post-Juego
function stateHandlers.POST_GAME(key, global_state)
    if key == "return" or key == "space" or key == "kpenter" then -- 'a' button
        os.remove(global_state.lastPlayedRom)
        global_state.state = "LIST"
        global_state.inputCooldown = 0.2
        refreshFiles(global_state)
    elseif key == "backspace" then -- 'b' button (Cancel)
        global_state.state = "LIST" 
        global_state.inputCooldown = 0.2
    end
end

-- Manejador para Lista (Default)
local function handleListInput(key, global_state)
    -- Comprobación de directorio vacío
    local currentItem = global_state.files[global_state.selectedIndex]
    if currentItem and currentItem.empty then
        if key == "backspace" then -- Allow going back from an empty directory
            local parent = global_state.romPath:gsub("[^/]+/$", "")
            global_state.log("Back (Empty). Verificando ruta: " .. global_state.romPath .. " -> Parent: " .. parent)

            -- Comprobar si el padre es una raíz de sistema para volver al menú virtual
            local cwd = global_state.love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"
            
            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               global_state.romPath == "/mnt/mmc/ROMS/" or global_state.romPath == "/mnt/sdcard/ROMS/" or global_state.romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or global_state.romPath == "@Favorites/" then
                 global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                    filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                    global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                    global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                    global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                 preview.load(global_state, global_state.log, global_state.loader)
                 global_state.inputCooldown = 0.2 -- Reset cooldown
                 return
            end
            global_state.romPath = parent
            global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
            global_state.selectedIndex = 1
            refreshFiles(global_state)
            global_state.inputCooldown = 0.2
        else
            return -- Ignore other key presses for empty directory message
        end
    end -- End if currentItem.empty

    -- Lógica de eliminación de Fantasma (Ghost) al moverse
    if (key == "up" or key == "down" or key == "left" or key == "right" or key == "pageup" or key == "pagedown") and currentItem and currentItem.pendingDelete then
        table.remove(global_state.files, global_state.selectedIndex)
        -- Ajustar selección si nos movíamos hacia arriba/atrás
        if key == "up" or key == "left" or key == "pageup" then
             global_state.selectedIndex = math.max(1, global_state.selectedIndex - 1)
        end
        -- Asegurar límites
        if global_state.selectedIndex > #global_state.files then global_state.selectedIndex = #global_state.files end
        if global_state.selectedIndex < 1 then global_state.selectedIndex = 1 end

        -- Actualizar backup allFiles
        global_state.allFiles = {}
        for _, f in ipairs(global_state.files) do table.insert(global_state.allFiles, f) end
        
        global_state.inputCooldown = 0.2
        preview.load(global_state, global_state.log, global_state.loader)
        return -- Consumir input (el movimiento visual ya ocurrió al borrar el item)
    end -- End if currentItem.pendingDelete

    if key == "f" then
        global_state.state = "SEARCH"
        global_state.searchQuery = ""
        global_state.keyboardRow = 1
        global_state.keyboardCol = 1
        love.keyboard.setTextInput(true) -- Enable text input
        filterFiles(global_state)
        return
    end -- End if key == "f"
    
    if key == "f2" then -- L2: Clear filter
        global_state.searchQuery = ""
        filterFiles(global_state)
        global_state.inputCooldown = 0.2
        return
    end
    
    if key == "pageup" then
        if global_state.viewMode == "GRID" then
            global_state.selectedIndex = math.max(1, global_state.selectedIndex - (global_state.gridCols * 3))
        else
            global_state.selectedIndex = math.max(1, global_state.selectedIndex - global_state.pageSize)
        end
        global_state.pendingLoad = true
        global_state.inputCooldown = 0.2
        global_state.timer = 0 -- Reset timer
    elseif key == "pagedown" then
        if global_state.viewMode == "GRID" then
            global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + (global_state.gridCols * 3))
        else
            global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + global_state.pageSize)
        end
        global_state.pendingLoad = true
        global_state.inputCooldown = 0.2
        global_state.timer = 0 -- Reset timer
    end

    if key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then -- 'a' button (Start envía return, lo ignoramos si hay gamepad)
        if #global_state.files == 0 then return end
        local item = global_state.files[global_state.selectedIndex]
        if item.isDir then
            if global_state.isVirtualRoot then
                global_state.romPath = item.fullPath
                global_state.secondaryPath = item.secondaryPath
                global_state.isVirtualRoot = false
                global_state.selectedIndex = 1
                refreshFiles(global_state)
                global_state.inputCooldown = 0.2
            else
                if item.name == ".." then
                    local newPath = global_state.romPath:gsub("[^/]+/$", "")
                    if newPath == "/mnt/mmc/ROMS/" or newPath == "/mnt/sdcard/ROMS/" then
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                           filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                           global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                           global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                           global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        preview.load(global_state, global_state.log, global_state.loader) -- Reload preview
                        return
                    end -- End if newPath is root
                    local cwd = global_state.love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then -- Simulator path check
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        preview.load(global_state, global_state.log, global_state.loader)
                        return -- Reload preview
                    end
                    global_state.romPath = newPath -- Update romPath
                    global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
                else
                    global_state.romPath = global_state.romPath .. item.name .. "/"
                end
                global_state.selectedIndex = 1
                refreshFiles(global_state)
                global_state.inputCooldown = 0.2
            end
        else
            -- Launch ROM
            local romToLaunch = nil

            if global_state.launchMode == "Juego Unico" and item.versions then
                if #item.versions > 1 then
                    global_state.state = "OPTIONS_MENU" -- Open version selection menu
                    global_state.menuAnim = 0
                    global_state.menuTitle = global_state.L.get("version")
                    global_state.log("Menu opened: " .. global_state.menuTitle .. " for " .. item.name)
                    global_state.menuMessage = item.name
                    global_state.menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system -- Get display name for system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(global_state.menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = global_state.playedRoms[v.fullPath]
                        })
                    end
                    global_state.menuSelection = 1
                    global_state.inputCooldown = 0.2
                    return
                elseif #item.versions == 1 then
                    romToLaunch = item.versions[1].fullPath
                end
            else
                romToLaunch = global_state.isVirtualRoot and item.fullPath or global_state.romPath .. item.name -- Determine ROM to launch
            end
            
            if romToLaunch then
                -- Detección de ambigüedad (zip/7z en carpetas desconocidas)
                local ext = romToLaunch:match("%.([^%.]+)$")
                local isZip = ext and (ext:lower() == "zip" or ext:lower() == "7z")
                
                if isZip then
                    local folder = romToLaunch:match(".*/ROMS/([^/]+)/") or romToLaunch:match(".*/([^/]+)/")
                    local known = false
                    if folder then
                        -- Usar la lista de variantes de utils para comprobar si es un sistema conocido
                        if utils.isKnownSystem(folder) then
                            known = true
                        end
                    end
                    
                    if not known then
                        global_state.state = "OPTIONS_MENU"
                        global_state.menuTitle = "Seleccionar Sistema"
                        global_state.menuMessage = "Archivo ambiguo detectado.\nSelecciona el sistema:"
                        global_state.menuOptions = {"Arcade (FBNeo)", "Super Nintendo", "Nintendo (NES)", "Sega Genesis/MD", "PlayStation", "GBA", "GBC/GB"}
                        global_state.menuSelection = 1
                        global_state.itemToLaunch = romToLaunch
                        global_state.inputCooldown = 0.2
                        return
                    end
                end

                global_state.log("Selected ROM for launch: " .. romToLaunch)
                global_state.lastPlayedRom = romToLaunch
                saveLastPlayed(global_state.lastPlayedRom)
                filesystem.savePendingHistory(global_state.lastPlayedRom)
                -- Iniciamos secuencia de lanzamiento (verde -> espera -> salir)
                global_state.launching = true
                global_state.launchTimer = 0
            end
        end -- End if item.isDir
    elseif key == "backspace" then -- 'b' button
        if global_state.isVirtualRoot then
            global_state.inputCooldown = 0.2 -- Prevent phantom input when actionless
            return -- No hacer nada si ya estamos en la raíz virtual
        else
            local parent = global_state.romPath:gsub("[^/]+/$", "")
            global_state.log("Back. Verificando ruta: " .. global_state.romPath .. " -> Parent: " .. parent)
            
            -- Check if parent is a system root to return to virtual menu
            local cwd = global_state.love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"
            
            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               global_state.romPath == "/mnt/mmc/ROMS/" or global_state.romPath == "/mnt/sdcard/ROMS/" or global_state.romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or
               global_state.romPath == "" or global_state.romPath == "@Favorites/" then
                 global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                    filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                    global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                    global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                    global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                 global_state.log("Virtual Root created. Items: " .. #global_state.files)
                 preview.load(global_state, global_state.log, global_state.loader) -- Reload preview
                 global_state.inputCooldown = 0.2
                 return
            end
            global_state.romPath = parent
            global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
            global_state.selectedIndex = 1
            refreshFiles(global_state)
            global_state.inputCooldown = 0.2
        end
    elseif key == "tab" then -- 'Y' button
        local item = global_state.files[global_state.selectedIndex]
        if item then -- If an item is selected
            if item.isDir then
                -- Es una carpeta, no hacer nada para evitar comportamientos extraños.
                global_state.inputCooldown = 0.2 -- Evita que se abra el menú si se suelta rápido y se detecta otra pulsación
                return
            else
                -- Es un archivo, abrir menú de opciones.
                if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 1 then
                    -- Open the version selection menu, same as 'A'
                    global_state.state = "OPTIONS_MENU"
                    global_state.menuAnim = 0
                    global_state.menuTitle = global_state.L.get("version")
                    global_state.log("Menu opened: " .. global_state.menuTitle .. " for " .. item.name)
                    global_state.menuMessage = item.name
                    global_state.menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system -- Get display name for system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(global_state.menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = global_state.playedRoms[v.fullPath]
                        })
                    end
                    global_state.menuSelection = 1
                    global_state.inputCooldown = 0.15
                    return
                end
                
                global_state.state = "OPTIONS_MENU" -- Open options menu
                global_state.menuAnim = 0
                global_state.menuTitle = global_state.L.get("options") .. ":"
                global_state.menuStack = {}
                if global_state.selectedFilesCount > 0 then
                    global_state.menuMessage = global_state.L.get("delete_selected_msg", global_state.selectedFilesCount)
                else
                    global_state.menuMessage = item.name
                end
                global_state.menuSelection = 1
                
                global_state.menuOptions = {}
                -- 1. Info (Solo individual)
                if global_state.selectedFilesCount <= 1 then -- Only show info for single item
                    table.insert(global_state.menuOptions, {text=global_state.L.get("info"), icon=global_state.iconInfo})
                end
                -- Favoritos
                if global_state.favoriteRoms[item.fullPath] then
                    table.insert(global_state.menuOptions, {text=global_state.L.get("remove_favorite"), icon=global_state.iconFavorite})
                else
                    table.insert(global_state.menuOptions, {text=global_state.L.get("add_favorite"), icon=global_state.iconFavorite})
                end
                table.insert(global_state.menuOptions, {text=global_state.L.get("scraper"), icon=global_state.iconNetwork})
                
                -- 2. Copiar / Mover
                if item.sourceLabel ~= "SD½" then
                    local _, targetLabel = filesystem.getTargetSDPath(item.fullPath, global_state.config)
                    if targetLabel then
                        table.insert(global_state.menuOptions, {text=global_state.L.get("copy_to", targetLabel), icon=global_state.iconFolder})
                        table.insert(global_state.menuOptions, {text=global_state.L.get("move_to", targetLabel), icon=global_state.iconFolder})
                    end
                end
                
                -- 3. Save Games
                findSaveFiles(item, global_state)
                table.insert(global_state.menuOptions, {text=global_state.L.get("save_games") .. " (" .. #global_state.saveFiles .. ")", icon=global_state.iconSaveStates})
                
                -- 4. Borrar (Al final)
                if not item.isFavorites then
                    if item.sourceLabel == "SD½" then
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete_sd1"), icon=global_state.iconTrash}) -- Delete from SD1
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete_sd2"), icon=global_state.iconTrash})
                    else
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete"), icon=global_state.iconTrash})
                    end
                end
                
                global_state.inputCooldown = 0.15 -- Reset cooldown
            end
        end
    elseif key == "x" then
        if global_state.launchMode ~= "Juego Unico" then
            local item = global_state.files[global_state.selectedIndex]
            if item and not item.isDir then
                item.selected = not item.selected
                if item.selected then
                    global_state.selectedFilesCount = global_state.selectedFilesCount + 1
                else
                    global_state.selectedFilesCount = global_state.selectedFilesCount - 1
                end
            end
        end
    end
end

local function keypressed(key, global_state)
    global_state.log("Key pressed: " .. key .. " (State: " .. global_state.state .. ")")
    if global_state.inputCooldown > 0 then
        global_state.log("Input ignored due to cooldown (" .. string.format("%.2f", global_state.inputCooldown) .. "s)")
        return
    end

    if key == "escape" then -- 'select' button on controller
        global_state.log("Select button pressed, quitting application.")
        love.event.quit()
        return
    end

    -- Si se está mostrando la pantalla de indexación, bloquear casi toda la entrada.
    if global_state.launchMode == "Juego Unico" and global_state.isVirtualRoot and not global_state.romIndex then
        if global_state.state == "OPTIONS_MENU" then
            -- Permitir navegación si logramos abrir el menú
        elseif key == "f1" then
            -- Permitir Start para abrir configuración (cambiar vista, etc)
        else
            -- Bloquear cualquier otra tecla
            return -- Block all other inputs
        end
    end

    -- Modal Help Menu Logic
    if global_state.showHelp then
        -- Close with the same help button (f3/R1) or the back button (B)
        if key == "f3" or key == "backspace" or key == "b" then
            global_state.showHelp = false
            closingHelp = true
            inputCooldown = 0.2 -- Evita que la pulsación de B también salga del menú subyacente
            return -- Salir inmediatamente para que no se procese nada más
        end
        -- Block all other inputs while help is visible
        return
    end

    if key == "f3" then
        global_state.showHelp = true
        return
    end

    if key == "f1" then -- Start button
        if global_state.state == "OPTIONS_MENU" and global_state.menuTitle == global_state.L.get("config") then
            global_state.closingMenu = true
            global_state.log("Configuration Menu exited")
            global_state.inputCooldown = 0.2
            return
        elseif global_state.state == "LIST" then
            global_state.log("Opening Configuration Menu")
            global_state.state = "OPTIONS_MENU"
            global_state.menuAnim = 0
            global_state.menuTitle = global_state.L.get("config")
            global_state.menuStack = {}
            global_state.menuMessage = ""
            global_state.menuSelection = 1
            global_state.menuOptions = {}
            local displayMode = (global_state.launchMode == "Folder") and global_state.L.get("folder") or global_state.L.get("single_game")
            local displayView = (global_state.viewMode == "LIST") and global_state.L.get("list") or global_state.L.get("grid")
            if global_state.romPath ~= "@Favorites/" then
                table.insert(global_state.menuOptions, {text = global_state.L.get("mode") .. ": " .. displayMode, icon = global_state.iconGame})
            end
            table.insert(global_state.menuOptions, {text = global_state.L.get("view") .. ": " .. displayView, icon = global_state.iconFolder})
            table.insert(global_state.menuOptions, {text = global_state.L.get("hide_empty") .. ": " .. (global_state.hideEmpty and global_state.L.get("on") or global_state.L.get("off")), icon = global_state.iconHide})
            table.insert(global_state.menuOptions, {text = global_state.L.get("mark_played") .. ": " .. (global_state.markPlayed and global_state.L.get("yes") or global_state.L.get("no")), icon = global_state.iconRom})
            table.insert(global_state.menuOptions, {text = global_state.L.get("hide_favorites") .. ": " .. (global_state.hideFavorites and global_state.L.get("on") or global_state.L.get("off")), icon = global_state.iconHide})
            table.insert(global_state.menuOptions, {text = global_state.L.get("reindex"), icon = global_state.iconReload})
            table.insert(global_state.menuOptions, {text = global_state.L.get("cleanup"), icon = global_state.iconTrash})
            global_state.inputCooldown = 0.2
            return
        end
    end

    -- State Dispatch
    local handler = stateHandlers[global_state.state]
    if handler then
        handler(key, global_state)
    else
        -- Default LIST handler logic (including empty dir check)
        handleListInput(key, global_state)
    end
end

local function gamepadpressed(joystick, button, global_state)
    if button == "a" then
        keypressed("kpenter", global_state) -- Usamos kpenter para mayor compatibilidad
    elseif button == "b" then
        keypressed("backspace", global_state)
    elseif button == "y" then
        keypressed("tab", global_state) -- Physical Y (Left) -> Options
    elseif button == "x" then
        keypressed("x", global_state) -- Physical X (Top) -> Select
    elseif button == "dpleft" then
        keypressed("left", global_state)
    elseif button == "dpright" then
        keypressed("right", global_state)
    elseif button == "back" then
        keypressed("escape", global_state)
    elseif button == "start" then
        keypressed("f1", global_state)
    elseif button == "leftshoulder" then
        keypressed("f", global_state) -- L1 -> Search
    elseif button == "triggerleft" then
        keypressed("f2", global_state) -- L2 -> Clear Filter
    elseif button == "rightshoulder" then
        keypressed("f3", global_state) -- R1 -> Help
    elseif button == "triggerright" then
        keypressed("f4", global_state) -- R2 -> Unused
    end
end

local function joystickpressed(joystick, button, global_state)
    -- Fallback para botones que no se detectan como Gamepad (L1/R1/L2 a veces)
    -- Mapeo común en dispositivos Anbernic/muOS: 4=L1, 5=R1, 6=L2
    local isGamepad = joystick:isGamepad()
    
    if button == 4 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end -- Prevent double input
        keypressed("f", global_state) -- L1 -> Buscar
    elseif button == 5 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end -- Prevent double input
        keypressed("f3", global_state) -- R1 -> Ayuda
    elseif button == 6 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end -- Prevent double input
        keypressed("f2", global_state) -- L2 -> Limpiar Filtro
    end
end

local function textinput(t, global_state)
    if global_state.showHelp then return end
    if global_state.state == "SEARCH" then
        global_state.searchQuery = global_state.searchQuery .. t
        filterFiles(global_state)
    elseif global_state.state == "EDIT_TEXT" then
        global_state.textToEdit = global_state.textToEdit .. t
    end
end

return {
    keypressed = keypressed,
    gamepadpressed = gamepadpressed,
    joystickpressed = joystickpressed,
    textinput = textinput,
    jumpToNextLetter = jumpToNextLetter, -- Used by update.lua
    jumpToPrevLetter = jumpToPrevLetter,   -- Used by update.lua
    refreshFiles = refreshFiles,           -- Exposed for main.lua
    updateSystemPaths = updateSystemPaths  -- Exposed for main.lua
}