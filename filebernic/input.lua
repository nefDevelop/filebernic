local filesystem = require "filesystem"
local utils = require "utils"
local State = require "state"
local preview = require "preview"
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

local function saveHistory()
    filesystem.saveHistory(playedRoms)
end

local function saveLastPlayed(path)
    filesystem.saveLastPlayed(path)
end

local function addToHistory(path)
    playedRoms = filesystem.addToHistory(path, playedRoms)
end

local function deleteGameMedia(path)
    filesystem.deleteGameMedia(path)
end

local function removeFromIndex(path)
    if romIndex then
        romIndex = filesystem.removeFromIndex(path, romIndex, json.encode, love.filesystem.getSource, io.open)
    end
end

local function findSaveFiles(item)
    saveFiles = filesystem.findSaveFiles(item)
end

local function performCleanupScan()
    cleanupData = filesystem.performCleanupScan(cleanupData, validExtensions, love.filesystem.getSource, io.open, coroutine.create, coroutine.yield, table.insert, table.sort)
    if cleanupData and not cleanupData.orphanedImages then cleanupData.orphanedImages = {} end
end

local function filterFiles()
    files = {}
    for _, item in ipairs(allFiles) do
        if item.name:lower():find(searchQuery:lower(), 1, true) then
            table.insert(files, item)
        end
    end
    selectedIndex = 1
end

local function startScraping()
    local item = files[selectedIndex]
    if not item then return end
    log("Starting interactive scrape for: " .. item.name)
    state = "SCRAPING_IN_PROGRESS"
    scraperResults = {}
    os.execute("rm -f /tmp/scraper_*.png")
    indexerChannelIn:push({ command = "scrape_single", item = item, config = config, systemName = systemName })
end

local function performBatchScrape(items)
    log("Starting batch scrape for " .. #items .. " items")
    state = "BATCH_SCRAPING"
    scraperProgress = { current = 0, total = #items, currentName = "", successes = 0, failures = 0 }
    os.execute("rm -f /tmp/scraper_*.png")
    indexerChannelIn:push({ command = "scrape_batch", items = items, config = config, systemName = systemName, romPath = romPath, muosArtPath = muosArtPath, muosTextPath = muosTextPath, muosPreviewPath = muosPreviewPath })
end

local function saveSelectedArt()
    log("Saving selected art...")
    local result = scraperResults[scraperSelection]
    local item = files[selectedIndex]
    systemName, muosArtPath, muosTextPath, muosPreviewPath = filesystem.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    filesystem.saveScrapeResult(item, result, muosArtPath, muosTextPath, muosPreviewPath, log)
    
    local baseName = item.name:gsub("%..-$", "") -- Remove extension
    if muosArtPath and muosArtPath ~= "" then
        log("Invalidating art paths for: " .. baseName)
        loader:invalidate(muosArtPath .. baseName .. ".png")
        loader:invalidate(muosTextPath .. baseName .. ".txt")
        loader:invalidate(muosTextPath .. baseName .. ".year")
        loader:invalidate(muosPreviewPath .. baseName .. ".png")
    end
    state = "LIST"
    preview.load(_G, log, loader)
end

local stateHandlers = {}

-- Manejador para el modo Búsqueda
function stateHandlers.SEARCH(key, global_state)
    if key == "up" then -- Move up in keyboard grid
        keyboardRow = math.max(1, keyboardRow - 1)
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
        inputCooldown = 0.15
    elseif key == "down" then -- Move down in keyboard grid
        keyboardRow = math.min(#keyboardGrid, keyboardRow + 1)
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
        inputCooldown = 0.15
    elseif key == "left" then -- Move left in keyboard grid
        keyboardCol = math.max(1, keyboardCol - 1)
        inputCooldown = 0.15
    elseif key == "right" then -- Move right in keyboard grid
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol + 1)
        inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then -- 'a' button
        local char = keyboardGrid[keyboardRow][keyboardCol] -- Get character from keyboard grid
        if char == "OK" then
            state = "LIST"
            love.keyboard.setTextInput(false)
        elseif char == "BACK" then
            searchQuery = searchQuery:sub(1, -2)
            filterFiles()
        elseif char == "SPACE" then
            searchQuery = searchQuery .. " "
            filterFiles()
        else
            searchQuery = searchQuery .. char
            filterFiles()
        end
        inputCooldown = 0.2
    elseif key == "f" then -- L1: Exit search, keep filter active
        state = "LIST"
        love.keyboard.setTextInput(false)
        inputCooldown = 0.2
    elseif key == "f2" then -- L2: Clear filter and exit search
        searchQuery = ""
        filterFiles()
        state = "LIST"
        love.keyboard.setTextInput(false)
        inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then -- 'b' button (Cancel search)
        state = "LIST"
        files = allFiles -- Restore full list
        searchQuery = ""
        love.keyboard.setTextInput(false) -- Disable text input
        inputCooldown = 0.2
    end
end

-- Manejador para el Menú de Opciones
function stateHandlers.OPTIONS_MENU(key, global_state)
    local L = global_state.L
    if key == "return" or key == "kpenter" or (key == "return" and global_state.love.joystick.getJoystickCount() == 0) then -- Confirm selection
        if #menuStack > 0 then
             -- Acciones del sub-menú de versión
             local opt = menuOptions[menuSelection]
             local optText = type(opt) == "table" and opt.text or opt
             
             if optText == L.get("info") then
                 preview.load(global_state, global_state.log, global_state.loader)
                 global_state.state = "INFO_VIEW"
             elseif optText == L.get("scraper") then -- Open scraper view
                 state = "SCRAPER_VIEW"
             elseif optText:match(L.get("save_games")) then
                 state = "SAVE_MANAGER"
             elseif optText == L.get("delete") then
                 local fullPath = focusedItem.fullPath
                 deleteGameMedia(fullPath)
                 local success, err = os.remove(fullPath)
                 if not success then
                     log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                 else
                     log("Archivo borrado con éxito: " .. fullPath)
                     filesystem.logDeletion(fullPath, json.encode, json.decode)
                 end
                 -- Always update internal state
                 if romIndex then removeFromIndex(fullPath) end
                 if playedRoms[fullPath] then playedRoms[fullPath] = nil; saveHistory() end
                 if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                     global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                        filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                        global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                        global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                        global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                     preview.load(_G, log, loader)
                 else -- Not virtual root, refresh files
                     refreshFiles()
                 end
                 state = "LIST"
                 menuStack = {}
                 focusedItem = nil
             elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
                 local fullPath = focusedItem.fullPath
                 if favoriteRoms[fullPath] then
                     favoriteRoms[fullPath] = nil
                     if type(opt) == "table" then opt.text = L.get("add_favorite") else menuOptions[menuSelection] = L.get("add_favorite") end
                 else
                     favoriteRoms[fullPath] = true -- Mark as favorite
                     if type(opt) == "table" then opt.text = L.get("remove_favorite") else menuOptions[menuSelection] = L.get("remove_favorite") end
                 end
                 filesystem.saveFavorites(favoriteRoms, json.encode)
                 if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                     global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                        filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                        global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                        global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                        global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                     preview.load(_G, log, loader)
                 end
             end
             inputCooldown = 0.3
             return
        end

        if menuTitle == L.get("version") then
             local item = files[selectedIndex]
             if item and item.versions and item.versions[menuSelection] then
                 local v = item.versions[menuSelection]
                 lastPlayedRom = v.fullPath
                 saveLastPlayed(lastPlayedRom)
                 addToHistory(lastPlayedRom)
                 launching = true
                 launchTimer = 0
             end
             return
        end
        
        local opt = menuOptions[menuSelection]
        local optText = type(opt) == "table" and opt.text or opt

        if optText == "Borrar" then
            if selectedFilesCount > 0 then
                menuTitle = "Confirmar Borrado"
                menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
                menuOptions = {"Borrar", "Cancelar"}
                menuSelection = 2
                log("Menu opened: " .. menuTitle)
                state = "DELETE_MENU"
            elseif (not isVirtualRoot or launchMode == "Juego Unico") and files[selectedIndex] and (not files[selectedIndex].isDir or files[selectedIndex].name ~= "..") then
                itemToDelete = files[selectedIndex]
                menuTitle = "Confirmar Borrado"
                menuMessage = "¿Borrar este archivo?\n" .. itemToDelete.name
                menuOptions = {"Borrar", "Cancelar"}
                menuSelection = 2
                log("Menu opened: " .. menuTitle)
                state = "DELETE_MENU"
            end
        elseif optText == "Info" then
            state = "INFO_VIEW"
            inputCooldown = 0.2
        elseif optText == "Scraper" then
            if selectedFilesCount > 0 then
                local items = {}
                for _, f in ipairs(files) do
                    if f.selected then table.insert(items, f) end
                end
                performBatchScrape(items)
                inputCooldown = 0.2
            else
                state = "SCRAPER_VIEW"
                inputCooldown = 0.2
            end
        elseif optText == L.get("delete_sd1") then
            local item = files[selectedIndex]
            local pathToDelete = item.fullPath:find("/mnt/mmc") and item.fullPath or item.secondaryPath
            deleteGameMedia(pathToDelete)
            local success, err = os.remove(pathToDelete)
            if not success then
                log("Error al borrar archivo (o ya no existía): " .. pathToDelete .. " - " .. tostring(err))
            else
                log("Archivo borrado con éxito: " .. pathToDelete)
                filesystem.logDeletion(pathToDelete, json.encode, json.decode)
            end
            if romIndex then removeFromIndex(pathToDelete) end -- Remove from index if it exists
            if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
            if isVirtualRoot and launchMode == "Juego Unico" then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            else
                refreshFiles()
            end
            state = "LIST"
        elseif optText == L.get("delete_sd2") then
            local item = files[selectedIndex]
            local pathToDelete = item.fullPath:find("/mnt/sdcard") and item.fullPath or item.secondaryPath
            deleteGameMedia(pathToDelete)
            local success, err = os.remove(pathToDelete)
            if not success then
                log("Error al borrar archivo (o ya no existía): " .. pathToDelete .. " - " .. tostring(err))
            else
                log("Archivo borrado con éxito: " .. pathToDelete)
                filesystem.logDeletion(pathToDelete, json.encode, json.decode)
            end
            if romIndex then removeFromIndex(pathToDelete) end -- Remove from index if it exists
            if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
            if isVirtualRoot and launchMode == "Juego Unico" then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            else
                refreshFiles()
            end
            state = "LIST"
        elseif optText:match(L.get("mode") .. ":") then
            launchMode = (launchMode == "Folder") and "Juego Unico" or "Folder"
            local displayMode = (launchMode == "Folder") and L.get("folder") or L.get("single_game")
            local newVal = L.get("mode") .. ": " .. displayMode
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem) -- Save app state
            global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
               filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
               global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
               global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
               global_state.love.graphics.newImage, global_state.allFiles, pathForSelection, global_state.favoriteRoms, global_state.hideFavorites)
            preview.load(global_state, global_state.log, global_state.loader)
        elseif optText:match(L.get("hide_empty")) then
            hideEmpty = not hideEmpty
            local newVal = L.get("hide_empty") .. ": " .. (hideEmpty and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            if isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                preview.load(global_state, global_state.log, global_state.loader)
            end
        elseif optText:match(L.get("view")) then
            viewMode = (viewMode == "LIST") and "GRID" or "LIST"
            local displayView = (viewMode == "LIST") and L.get("list") or L.get("grid")
            local newVal = L.get("view") .. ": " .. displayView
            if type(opt) == "table" then
                opt.text = newVal 
            else 
                menuOptions[menuSelection] = newVal 
            end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites, love.filesystem) -- Save app state
        elseif optText == L.get("cleanup") then
            state = "CLEANUP_MENU"
            cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
            inputCooldown = 0.2 -- Reset cooldown
        elseif optText:match(L.get("mark_played")) then
            markPlayed = not markPlayed
            local newVal = L.get("mark_played") .. ": " .. (markPlayed and L.get("yes") or L.get("no"))
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites, love.filesystem)
        elseif optText:match(L.get("hide_favorites")) then
            hideFavorites = not hideFavorites
            local newVal = L.get("hide_favorites") .. ": " .. (hideFavorites and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end -- Update option text
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites, love.filesystem)
            refreshFiles()
        elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
            local item = files[selectedIndex] -- Get selected item
            local path = item.fullPath
            if favoriteRoms[path] then
                favoriteRoms[path] = nil
                if type(opt) == "table" then opt.text = L.get("add_favorite") else menuOptions[menuSelection] = L.get("add_favorite") end
            else
                favoriteRoms[path] = true
                if type(opt) == "table" then opt.text = L.get("remove_favorite") else menuOptions[menuSelection] = L.get("remove_favorite") end
            end
            filesystem.saveFavorites(favoriteRoms, json.encode)
            if isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
            else
                refreshFiles()
            end
        elseif optText == L.get("reindex") then
            forceReindex()
            state = "LIST" -- Close menu and return to list (which will show indexing status)
        elseif optText:match(L.get("copy")) or optText:match(L.get("move_to"):match("^(.*)%s")) then -- Match "Mover a" prefix
            local isMove = optText:match(L.get("move_to"):match("^(.*)%s"))
            local targetDir, _ = filesystem.getTargetSDPath(romPath, config)
            
            if targetDir then
                os.execute('mkdir -p "' .. targetDir .. '"')
                
                local function processItem(item)
                    local src = romPath .. item.name
                    local dst = targetDir .. item.name
                    local cmd = (isMove and 'mv "' or 'cp "') .. src .. '" "' .. dst .. '"'
                    os.execute(cmd)
                    if isMove and playedRoms[src] then
                        playedRoms[src] = nil
                    end
                end

                if selectedFilesCount > 0 then
                    for _, item in ipairs(files) do
                        if item.selected then processItem(item) end
                    end
                else
                    processItem(files[selectedIndex])
                end

                if isMove then saveHistory() end
                refreshFiles()
                state = "LIST"
            end
        elseif optText:match(L.get("save_games")) then
            state = "SAVE_MANAGER"
        end
        inputCooldown = 0.2
    elseif key == "tab" then
         if menuTitle == L.get("config") then return end -- Don't open submenu from config

         if menuTitle == L.get("version") then
             local item = files[selectedIndex]
             local ver = item.versions[menuSelection]
             
             table.insert(menuStack, {
                 title = menuTitle,
                 message = menuMessage,
                 options = menuOptions,
                 selection = menuSelection,
                 focusedItem = focusedItem
             })
             focusedItem = ver -- Set focused item to version
             
             menuTitle = L.get("options") .. ": " .. ver.name
             menuMessage = ver.name
             findSaveFiles(ver)
             menuOptions = {L.get("info"), L.get("scraper"), L.get("save_games") .. " (" .. #saveFiles .. ")", L.get("delete")}

             if favoriteRoms[ver.fullPath] then
                 table.insert(menuOptions, 2, L.get("remove_favorite"))
             else
                 table.insert(menuOptions, 2, L.get("add_favorite"))
             end

             menuSelection = 1
             menuAnim = 0 -- Reiniciar animación para efecto de entrada del submenú
             inputCooldown = 0.2
             return
         end

        -- If in a submenu (there's a parent), Tab should not close everything at once
        if #menuStack > 0 then return end

        closingMenu = true
        menuStack = {} -- Limpiar pila para evitar fantasmas al reabrir
        log("Menu exited: " .. menuTitle)
        inputCooldown = 0.2
    elseif key == "backspace" then
        if #menuStack > 0 then
             closingMenu = true -- Trigger animation, menu will be popped on completion
             inputCooldown = 0.2 -- Reset cooldown
        else
            closingMenu = true
            log("Menu exited: " .. menuTitle)
            inputCooldown = 0.2
        end
    end
end

-- Manejador para la Vista de Información
function stateHandlers.INFO_VIEW(key)
    if key == "backspace" or key == "b" or key == "escape" then
        if #menuStack > 0 then -- If there's a parent menu, go back to it
            state = "OPTIONS_MENU"
        else
            closingMenu = true
        end
        showHelp = false
        inputCooldown = 0.2
    end
end

-- Manejador para Opciones de Scraper
function stateHandlers.SCRAPER_OPTIONS(key)
    if key == "return" or key == "kpenter" then
        if menuOptions[menuSelection] == L.get("clean") then -- If "Clean" option is selected
            local item = files[selectedIndex]
            local baseName = item.name:gsub("%..-$", "")
            os.remove(muosArtPath .. baseName .. ".png")
            os.remove(muosTextPath .. baseName .. ".txt")
            os.remove(muosTextPath .. baseName .. ".year")
            os.remove(muosPreviewPath .. baseName .. ".png")
            preview.load(global_state, global_state.log, global_state.loader)
            state = "SCRAPER_VIEW"
        end -- End if "Clean" option
        inputCooldown = 0.2
    elseif key == "backspace" or key == "x" or key == "escape" then
        closingMenu = true
        log("Scraper Options exited")
        inputCooldown = 0.2
    end
end

-- Manejador para Vista de Scraper
function stateHandlers.SCRAPER_VIEW(key)
    if key == "backspace" then -- 'b' button
        if #menuStack > 0 then -- If there's a parent menu, go back to it
            state = "OPTIONS_MENU"
        else
            state = "LIST"
        end
        showHelp = false
        inputCooldown = 0.2
    elseif key == "return" or key == "kpenter" then -- 'a' button
        startScraping()
    elseif key == "tab" then -- 'y' button
        state = "SCRAPER_OPTIONS"
        menuTitle = L.get("options") -- Set menu title
        menuAnim = 0
        menuMessage = ""
        menuOptions = {L.get("clean")}
        menuSelection = 1
        log("Menu opened: " .. menuTitle)
        inputCooldown = 0.2
    end
end

-- Manejador para Resultados de Scraper
function stateHandlers.SCRAPER_RESULTS(key)
    if key == "backspace" then
        state = "SCRAPER_VIEW"
        showHelp = false
        inputCooldown = 0.2
    elseif key == "left" then
        scraperSelection = math.max(1, scraperSelection - 1)
        inputCooldown = 0.15
    elseif key == "right" then
        scraperSelection = math.min(#scraperResults, scraperSelection + 1)
        inputCooldown = 0.15 -- Reset cooldown
    elseif (key == "return" or key == "kpenter") and #scraperResults > 0 then
        local sel = scraperResults[scraperSelection]
        if sel and not sel.error then
            saveSelectedArt()
            inputCooldown = 0.2
        end
    end
end

-- Manejador para Gestor de Partidas
function stateHandlers.SAVE_MANAGER(key)
    if key == "backspace" or key == "escape" then
        if #menuStack > 0 then -- If there's a parent menu, go back to it
            state = "OPTIONS_MENU"
        else
            state = "LIST"
        end
        inputCooldown = 0.2
    elseif key == "return" or key == "kpenter" then
        -- Copiar save a la otra SD
        local item = saveFiles[saveManagerSelection]
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
                findSaveFiles(files[selectedIndex])
            end -- End if relPath
        end
        inputCooldown = 0.2
    end
end

-- Manejador para Menú de Limpieza
function stateHandlers.CLEANUP_MENU(key)
    if cleanupData.confirming then
        if key == "backspace" or key == "escape" or key == "b" then
            cleanupData.confirming = false
            inputCooldown = 0.2
        elseif key == "return" or key == "kpenter" or key == "space" or key == "a" then -- Confirm action
            -- Ejecutar acción de borrado confirmada
            if cleanupData.cursor.col == 1 then
                -- Columna Huérfanos
                if cleanupData.cursor.row == 1 then
                    -- Borrar TODOS
                    for _, orphan in ipairs(cleanupData.orphans) do
                        local success, err = os.remove(orphan.fullPath)
                        if success then
                            log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, json.encode, json.decode)
                        else log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                    end
                    cleanupData.orphans = {}
                else
                    -- Borrar Individual
                    local idx = cleanupData.cursor.row - 1
                    local orphan = cleanupData.orphans[idx]
                    if orphan then
                        local success, err = os.remove(orphan.fullPath) -- Delete individual orphan
                        if success then 
                            log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, json.encode, json.decode)
                        else log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                        table.remove(cleanupData.orphans, idx)
                        if cleanupData.cursor.row > #cleanupData.orphans + 1 then
                            cleanupData.cursor.row = math.max(1, #cleanupData.orphans + 1)
                        end
                    end
                end
            elseif cleanupData.cursor.col == 3 then
                -- Columna Imágenes Huérfanas
                local idx = cleanupData.cursor.row
                local item = cleanupData.orphanedImages[idx]
                if item then
                    local success, err = os.remove(item.fullPath) -- Delete orphaned image
                    if success then 
                        log("Cleanup: Borrado " .. item.fullPath)
                        filesystem.logDeletion(item.fullPath, json.encode, json.decode)
                    else log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) end
                    -- También borrar preview/text/year si existen?
                    -- Por ahora solo borramos el archivo listado (boxart)
                    table.remove(cleanupData.orphanedImages, idx)
                    
                    if cleanupData.cursor.row > #cleanupData.orphanedImages then
                        cleanupData.cursor.row = math.max(1, #cleanupData.orphanedImages)
                    end
                end
            else
                -- Columna Duplicados: Borrar archivo seleccionado
                local idx = cleanupData.cursor.row
                local item = cleanupData.duplicates[idx]
                if item then
                    local success, err = os.remove(item.fullPath) -- Delete duplicate file
                    if success then
                        log("Cleanup: Borrado " .. item.fullPath) 
                        filesystem.logDeletion(item.fullPath, json.encode, json.decode) -- Log deletion
                        if romIndex then removeFromIndex(item.fullPath) end
                    else 
                        log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) 
                    end
                    table.remove(cleanupData.duplicates, idx)
                    
                    if cleanupData.cursor.row > #cleanupData.duplicates then
                        cleanupData.cursor.row = math.max(1, #cleanupData.duplicates)
                    end
                    -- Si estaba en el historial, quitarlo
                    if playedRoms[item.fullPath] then playedRoms[item.fullPath] = nil end
                end
            end
            
            cleanupData.confirming = false
            inputCooldown = 0.2 -- Reset cooldown
        end
        return
    end

    if key == "backspace" or key == "escape" then
        state = "LIST"
        inputCooldown = 0.2
    elseif not cleanupData.scanned then
        if key == "return" or key == "kpenter" then -- Start scan
            performCleanupScan()
        end
    else
        -- Navegación en resultados
        if key == "f" then -- L1: Cycle columns
            if cleanupData.cursor.col == 1 then
                cleanupData.cursor.col = 2
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.duplicates)
            elseif cleanupData.cursor.col == 2 and #cleanupData.orphanedImages > 0 then
                cleanupData.cursor.col = 3 -- Move to orphaned images column
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.orphanedImages)
            else
                cleanupData.cursor.col = 1
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.orphans + 1)
            end
        elseif key == "left" then -- Page Up (Pagination)
            local maxRows = (cleanupData.cursor.col == 1 and #cleanupData.orphans + 1) or (cleanupData.cursor.col == 2 and #cleanupData.duplicates) or #cleanupData.orphanedImages
            cleanupData.cursor.row = math.max(1, cleanupData.cursor.row - pageSize)
        elseif key == "right" then -- Page Down (Pagination)
            local maxRows = (cleanupData.cursor.col == 1 and #cleanupData.orphans + 1) or (cleanupData.cursor.col == 2 and #cleanupData.duplicates) or #cleanupData.orphanedImages -- Max rows for current column
            cleanupData.cursor.row = math.min(maxRows, cleanupData.cursor.row + pageSize)
        elseif key == "return" or key == "kpenter" then
            -- Verificar si hay algo válido seleccionado para borrar
            local valid = false
            if cleanupData.cursor.col == 1 then
                if cleanupData.cursor.row == 1 and #cleanupData.orphans > 0 then valid = true
                elseif cleanupData.cursor.row > 1 and cleanupData.orphans[cleanupData.cursor.row - 1] then valid = true end
            elseif cleanupData.cursor.col == 3 then
                if cleanupData.orphanedImages[cleanupData.cursor.row] then valid = true end
            else
                if cleanupData.duplicates[cleanupData.cursor.row] then valid = true end
            end
            
            if valid then
                cleanupData.confirming = true -- Show confirmation modal
                inputCooldown = 0.2
            end
        end
    end
end

-- Manejador para Menú de Borrado
function stateHandlers.DELETE_MENU(key)
    if key == "return" or key == "space" or key == "kpenter" then
        if menuOptions[menuSelection] == L.get("delete") then
            if selectedFilesCount > 0 then -- Delete multiple selected files
                for _, item in ipairs(files) do
                    if item.selected then
                        local fullPath = item.fullPath or (romPath .. item.name)
                        deleteGameMedia(fullPath)
                        local success, err = os.remove(fullPath)
                        if not success then
                            log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                        else
                            log("Archivo borrado con éxito: " .. fullPath)
                            filesystem.logDeletion(fullPath, json.encode, json.decode)
                        end -- End if success
                if romIndex then removeFromIndex(fullPath) end -- Remove from index if it exists
                        if playedRoms[fullPath] then
                            playedRoms[fullPath] = nil
                        end
                    end
                end
                saveHistory()
                if isVirtualRoot and launchMode == "Juego Unico" then
                    files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                    preview.load(global_state, global_state.log, global_state.loader) -- Reload preview after deletion
                else
                    refreshFiles()
                end
                itemToDelete = nil -- Clear item to delete
            elseif itemToDelete then
                local fullPath = itemToDelete.fullPath or (romPath .. itemToDelete.name)
                deleteGameMedia(fullPath)
                local success, err = os.remove(fullPath)
                if not success then
                    log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                else
                    log("Archivo borrado con éxito: " .. fullPath)
                    filesystem.logDeletion(fullPath, json.encode, json.decode)
                end -- End if success
                if romIndex then removeFromIndex(fullPath) end -- Remove from index if it exists
                if playedRoms[fullPath] then
                    playedRoms[fullPath] = nil
                    saveHistory()
                end
                -- Deselect to avoid errors, then refresh
                if isVirtualRoot and launchMode == "Juego Unico" then
                    files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                    preview.load(global_state, global_state.log, global_state.loader) -- Reload preview after deletion
                else
                    refreshFiles()
                end
                itemToDelete = nil -- Clear item to delete
            end
        end
        inputCooldown = 0.2
        state = "LIST"
        closingMenu = true
        log("Delete Menu exited")
    elseif key == "backspace" then -- Cancel
        itemToDelete = nil
        inputCooldown = 0.2
        closingMenu = true
        log("Delete Menu exited")
    end
end

-- Manejador para Post-Juego
function stateHandlers.POST_GAME(key)
    if key == "return" or key == "space" or key == "kpenter" then -- 'a' button
        os.remove(lastPlayedRom)
        state = "LIST"
        inputCooldown = 0.2
        refreshFiles()
    elseif key == "backspace" then -- 'b' button (Cancel)
        state = "LIST" 
        inputCooldown = 0.2
    end
end

-- Manejador para Lista (Default)
local function handleListInput(key)
    -- Comprobación de directorio vacío
    local currentItem = files[selectedIndex]
    if currentItem and currentItem.empty then
        if key == "backspace" then -- Allow going back from an empty directory
            local parent = romPath:gsub("[^/]+/$", "")
            log("Back (Empty). Verificando ruta: " .. romPath .. " -> Parent: " .. parent)

            -- Comprobar si el padre es una raíz de sistema para volver al menú virtual
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"
            
            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" or romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or romPath == "@Favorites/" then
                 global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                    filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                    global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                    global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                    global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                 preview.load(global_state, global_state.log, global_state.loader)
                 inputCooldown = 0.2 -- Reset cooldown
                 return
            end
            romPath = parent
            secondaryPath = filesystem.resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.2
        else
            return -- Ignore other key presses for empty directory message
        end
    end -- End if currentItem.empty

    -- Lógica de eliminación de Fantasma (Ghost) al moverse
    if (key == "up" or key == "down" or key == "left" or key == "right" or key == "pageup" or key == "pagedown") and currentItem and currentItem.pendingDelete then
        table.remove(files, selectedIndex)
        -- Ajustar selección si nos movíamos hacia arriba/atrás
        if key == "up" or key == "left" or key == "pageup" then
             selectedIndex = math.max(1, selectedIndex - 1)
        end
        -- Asegurar límites
        if selectedIndex > #files then selectedIndex = #files end
        if selectedIndex < 1 then selectedIndex = 1 end

        -- Actualizar backup allFiles
        allFiles = {}
        for _, f in ipairs(files) do table.insert(allFiles, f) end
        
        inputCooldown = 0.2
        preview.load(global_state, global_state.log, global_state.loader)
        return -- Consumir input (el movimiento visual ya ocurrió al borrar el item)
    end -- End if currentItem.pendingDelete

    if key == "f" then
        state = "SEARCH"
        searchQuery = ""
        keyboardRow = 1
        keyboardCol = 1
        love.keyboard.setTextInput(true) -- Enable text input
        filterFiles()
        return
    end -- End if key == "f"
    
    if key == "f2" then -- L2: Clear filter
        searchQuery = ""
        filterFiles()
        inputCooldown = 0.2
        return
    end
    
    if key == "pageup" then
        if viewMode == "GRID" then
            selectedIndex = math.max(1, selectedIndex - (gridCols * 3))
        else
            selectedIndex = math.max(1, selectedIndex - pageSize)
        end
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0 -- Reset timer
    elseif key == "pagedown" then
        if viewMode == "GRID" then
            selectedIndex = math.min(#files, selectedIndex + (gridCols * 3))
        else
            selectedIndex = math.min(#files, selectedIndex + pageSize)
        end
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0 -- Reset timer
    end

    if key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then -- 'a' button (Start envía return, lo ignoramos si hay gamepad)
        if #files == 0 then return end
        local item = files[selectedIndex]
        if item.isDir then
            if isVirtualRoot then
                romPath = item.fullPath
                secondaryPath = item.secondaryPath
                isVirtualRoot = false
                selectedIndex = 1
                refreshFiles()
                inputCooldown = 0.2
            else
                if item.name == ".." then
                    local newPath = romPath:gsub("[^/]+/$", "")
                    if newPath == "/mnt/mmc/ROMS/" or newPath == "/mnt/sdcard/ROMS/" then
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                           filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                           global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                           global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                           global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        preview.load(global_state, global_state.log, global_state.loader) -- Reload preview
                        return
                end -- End if newPath is root
                    local cwd = love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then -- Simulator path check
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        preview.load(global_state, global_state.log, global_state.loader)
                        return -- Reload preview
                    end
                    romPath = newPath -- Update romPath
                    secondaryPath = filesystem.resolveSecondary(romPath)
                else
                    romPath = romPath .. item.name .. "/"
                end
                selectedIndex = 1
                refreshFiles()
                inputCooldown = 0.2
            end
        else
            -- Launch ROM
            local romToLaunch = nil

            if launchMode == "Juego Unico" and item.versions then
                if #item.versions > 1 then
                    state = "OPTIONS_MENU" -- Open version selection menu
                    menuAnim = 0
                    menuTitle = L.get("version")
                    log("Menu opened: " .. menuTitle .. " for " .. item.name)
                    menuMessage = item.name
                    menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system -- Get display name for system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = playedRoms[v.fullPath]
                        })
                    end
                    menuSelection = 1
                    inputCooldown = 0.2
                    return
                elseif #item.versions == 1 then
                    romToLaunch = item.versions[1].fullPath
                end
            else
                romToLaunch = isVirtualRoot and item.fullPath or romPath .. item.name -- Determine ROM to launch
            end
            
            if romToLaunch then
                log("Selected ROM for launch: " .. romToLaunch)
                lastPlayedRom = romToLaunch
                saveLastPlayed(lastPlayedRom)
                addToHistory(lastPlayedRom)
                -- Iniciamos secuencia de lanzamiento (verde -> espera -> salir)
                launching = true
                launchTimer = 0
            end
        end -- End if item.isDir
    elseif key == "backspace" then -- 'b' button
        if isVirtualRoot then
            inputCooldown = 0.2 -- Prevent phantom input when actionless
            return -- No hacer nada si ya estamos en la raíz virtual
        else
            local parent = romPath:gsub("[^/]+/$", "")
            log("Back. Verificando ruta: " .. romPath .. " -> Parent: " .. parent)
            
            -- Check if parent is a system root to return to virtual menu
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"
            
            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" or romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or
               romPath == "" or romPath == "@Favorites/" then
                 global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = 
                    filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, 
                    global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, 
                    global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, 
                    global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                 log("Virtual Root created. Items: " .. #files)
                 preview.load(global_state, global_state.log, global_state.loader) -- Reload preview
                 inputCooldown = 0.2
                 return
            end
            romPath = parent
            secondaryPath = filesystem.resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.2
        end
    elseif key == "tab" then -- 'Y' button
        local item = files[selectedIndex]
        if item then -- If an item is selected
            if item.isDir then
                -- Es una carpeta, no hacer nada para evitar comportamientos extraños.
                inputCooldown = 0.2 -- Evita que se abra el menú si se suelta rápido y se detecta otra pulsación
                return
            else
                -- Es un archivo, abrir menú de opciones.
                if launchMode == "Juego Unico" and item.versions and #item.versions > 1 then
                    -- Open the version selection menu, same as 'A'
                    state = "OPTIONS_MENU"
                    menuAnim = 0
                    menuTitle = L.get("version")
                    log("Menu opened: " .. menuTitle .. " for " .. item.name)
                    menuMessage = item.name
                    menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system -- Get display name for system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = playedRoms[v.fullPath]
                        })
                    end
                    menuSelection = 1
                    inputCooldown = 0.15
                    return
                end
                
                state = "OPTIONS_MENU" -- Open options menu
                menuAnim = 0
                menuTitle = L.get("options") .. ":"
                menuStack = {}
                if selectedFilesCount > 0 then
                    menuMessage = L.get("delete_selected_msg", selectedFilesCount)
                else
                    menuMessage = item.name
                end
                menuSelection = 1
                
                menuOptions = {}
                -- 1. Info (Solo individual)
                if selectedFilesCount <= 1 then -- Only show info for single item
                    table.insert(menuOptions, {text=L.get("info"), icon=iconInfo})
                end
                -- Favoritos
                if favoriteRoms[item.fullPath] then
                    table.insert(menuOptions, {text=L.get("remove_favorite"), icon=iconFavorite})
                else
                    table.insert(menuOptions, {text=L.get("add_favorite"), icon=iconFavorite})
                end
                table.insert(menuOptions, {text=L.get("scraper"), icon=iconNetwork})
                
                -- 2. Copiar / Mover
                if item.sourceLabel ~= "SD½" then
                    local _, targetLabel = filesystem.getTargetSDPath(item.fullPath, config)
                    if targetLabel then
                        table.insert(menuOptions, {text=L.get("copy_to", targetLabel), icon=iconFolder})
                        table.insert(menuOptions, {text=L.get("move_to", targetLabel), icon=iconFolder})
                    end
                end
                
                -- 3. Save Games
                findSaveFiles(item)
                table.insert(menuOptions, {text=L.get("save_games") .. " (" .. #saveFiles .. ")", icon=iconSaveStates})
                
                -- 4. Borrar (Al final)
                if not item.isFavorites then
                    if item.sourceLabel == "SD½" then
                        table.insert(menuOptions, {text=L.get("delete_sd1"), icon=iconTrash}) -- Delete from SD1
                        table.insert(menuOptions, {text=L.get("delete_sd2"), icon=iconTrash})
                    else
                        table.insert(menuOptions, {text=L.get("delete"), icon=iconTrash})
                    end
                end
                
                inputCooldown = 0.15 -- Reset cooldown
            end
        end
    elseif key == "x" then
        if launchMode ~= "Juego Unico" then
            local item = files[selectedIndex]
            if item and not item.isDir then
                item.selected = not item.selected
                if item.selected then
                    selectedFilesCount = selectedFilesCount + 1
                else
                    selectedFilesCount = selectedFilesCount - 1
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
        filterFiles()
    end
end

return {
    keypressed = keypressed,
    gamepadpressed = gamepadpressed,
    joystickpressed = joystickpressed,
    textinput = textinput,
    jumpToNextLetter = jumpToNextLetter,
    jumpToPrevLetter = jumpToPrevLetter
}