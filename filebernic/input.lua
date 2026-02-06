---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field
---@diagnostic disable: lowercase-global

local filesystem = require "filesystem"
local utils = require "utils"
local State = require "state"
local preview = require "preview"
local json = require "libs.dkjson"
local stateHandlers = {}

local function jumpToNextLetter()
    if #files == 0 then return end
    local current = files[selectedIndex].name:sub(1,1):upper()
    for i = selectedIndex + 1, #files do
        local c = files[i].name:sub(1,1):upper()
        if c ~= current then
            selectedIndex = i
            jumpLetter = c
            return
        end
    end
    selectedIndex = #files
    jumpLetter = files[selectedIndex].name:sub(1,1):upper()
end

local function jumpToPrevLetter()
    if #files == 0 then return end
    local current = files[selectedIndex].name:sub(1,1):upper()
    local prevLetterIdx = nil
    for i = selectedIndex - 1, 1, -1 do
        local c = files[i].name:sub(1,1):upper()
        if c ~= current then
            prevLetterIdx = i
            break
        end
    end
    
    if prevLetterIdx then
        local targetChar = files[prevLetterIdx].name:sub(1,1):upper()
        for i = prevLetterIdx - 1, 1, -1 do
            local c = files[i].name:sub(1,1):upper()
            if c ~= targetChar then
                selectedIndex = i + 1
                jumpLetter = targetChar
                return
            end
        end
        selectedIndex = 1
    else
        selectedIndex = 1
    end
    jumpLetter = files[selectedIndex].name:sub(1,1):upper()
end

local function updateSystemPaths()
    systemName, muosArtPath, muosTextPath, muosPreviewPath, currentSystemIcon, currentSystemContentIcon = filesystem.updateSystemPaths(systemName, romPath, log, love.graphics.newImage)
end

local function refreshFiles()
    if romPath and romPath ~= "" and romPath:sub(-1) ~= "/" then romPath = romPath .. "/" end
    romPath = filesystem.fixPathCase(romPath)
    log("Refreshing files... Path: " .. romPath)
    
    local function updatePathsWrapper()
         updateSystemPaths()
    end
    
    files, selectedFilesCount, selectedIndex, allFiles = filesystem.refreshFiles(updatePathsWrapper, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, log, favoriteRoms, hideFavorites)
    preview.load()
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
    
    local baseName = item.name:gsub("%..-$", "")
    if muosArtPath and muosArtPath ~= "" then
        log("Invalidating art paths for: " .. baseName)
        loader:invalidate(muosArtPath .. baseName .. ".png")
        loader:invalidate(muosTextPath .. baseName .. ".txt")
        loader:invalidate(muosTextPath .. baseName .. ".year")
        loader:invalidate(muosPreviewPath .. baseName .. ".png")
    end
    state = "LIST"
    preview.load()
end

-- Manejador para el modo Búsqueda
function stateHandlers.SEARCH(key)
    if key == "up" then
        keyboardRow = math.max(1, keyboardRow - 1)
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
        inputCooldown = 0.15
    elseif key == "down" then
        keyboardRow = math.min(#keyboardGrid, keyboardRow + 1)
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
        inputCooldown = 0.15
    elseif key == "left" then
        keyboardCol = math.max(1, keyboardCol - 1)
        inputCooldown = 0.15
    elseif key == "right" then
        keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol + 1)
        inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then -- 'a' button
        local char = keyboardGrid[keyboardRow][keyboardCol]
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
    elseif key == "f" then -- L1: Exit search, keep filter
        state = "LIST"
        love.keyboard.setTextInput(false)
        inputCooldown = 0.2
    elseif key == "f2" then -- L2: Clear filter
        searchQuery = ""
        filterFiles()
        state = "LIST"
        love.keyboard.setTextInput(false)
        inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then -- 'b' button (Cancel)
        state = "LIST"
        files = allFiles -- Restore full list
        searchQuery = ""
        love.keyboard.setTextInput(false) -- Disable text input
        inputCooldown = 0.2
    end
end

-- Manejador para el Menú de Opciones
function stateHandlers.OPTIONS_MENU(key)
    if key == "return" or key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then
        if #menuStack > 0 then
             -- Acciones del sub-menú de versión
             local opt = menuOptions[menuSelection]
             local optText = type(opt) == "table" and opt.text or opt
             
             if optText == "Info" then
                 preview.load()
                 state = "INFO_VIEW"
             elseif optText == "Scraper" then
                 state = "SCRAPER_VIEW"
             elseif optText:match("Save Games") then
                 state = "SAVE_MANAGER"
             elseif optText == "Borrar" then
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
                 if playedRoms[fullPath] then playedRoms[fullPath] = nil saveHistory() end
                 if isVirtualRoot and launchMode == "Juego Unico" then
                     files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                     preview.load()
                 else
                     refreshFiles()
                 end
                 state = "LIST"
                 menuStack = {}
                 focusedItem = nil
             elseif optText:match("Favorito") then
                 local fullPath = focusedItem.fullPath
                 if favoriteRoms[fullPath] then
                     favoriteRoms[fullPath] = nil
                     if type(opt) == "table" then opt.text = "Añadir a Favoritos" else menuOptions[menuSelection] = "Añadir a Favoritos" end
                 else
                     favoriteRoms[fullPath] = true
                     if type(opt) == "table" then opt.text = "Quitar de Favoritos" else menuOptions[menuSelection] = "Quitar de Favoritos" end
                 end
                 filesystem.saveFavorites(favoriteRoms, json.encode)
                 if isVirtualRoot and launchMode == "Juego Unico" then
                     files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                     preview.load()
                 end
             end
             inputCooldown = 0.3
             return
        end

        if menuTitle == "Versión" then
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
        elseif optText == "Borrar de SD1" then
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
            if romIndex then removeFromIndex(pathToDelete) end
            if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
            if isVirtualRoot and launchMode == "Juego Unico" then
                files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                preview.load()
            else
                refreshFiles()
            end
            state = "LIST"
        elseif optText == "Borrar de SD2" then
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
            if romIndex then removeFromIndex(pathToDelete) end
            if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
            if isVirtualRoot and launchMode == "Juego Unico" then
                files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                preview.load()
            else
                refreshFiles()
            end
            state = "LIST"
        elseif optText:match("Modo:") then
            launchMode = (launchMode == "Folder") and "Juego Unico" or "Folder"
            local newVal = "Modo: " .. launchMode
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
            files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, pathForSelection, favoriteRoms, hideFavorites)
            preview.load()
        elseif optText:match("Ocultar vacíos") then
            hideEmpty = not hideEmpty
            local newVal = "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF")
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            if isVirtualRoot then 
                files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                preview.load()
            end
        elseif optText:match("Vista:") then
            viewMode = (viewMode == "LIST") and "GRID" or "LIST"
            local newVal = "Vista: " .. (viewMode == "LIST" and "Lista" or "Cuadrícula")
            local newIcon = (viewMode == "LIST") and iconList or iconGrid
            if type(opt) == "table" then 
                opt.text = newVal 
                opt.icon = newIcon
            else 
                menuOptions[menuSelection] = newVal 
            end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
        elseif optText == "Limpieza" then
            state = "CLEANUP_MENU"
            cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
            inputCooldown = 0.2
        elseif optText:match("Marcar Jugado") then
            markPlayed = not markPlayed
            local newVal = "Marcar Jugado: " .. (markPlayed and "Si" or "No")
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
        elseif optText:match("Ocultar Favoritos") then
            hideFavorites = not hideFavorites
            local newVal = "Ocultar Favoritos: " .. (hideFavorites and "ON" or "OFF")
            if type(opt) == "table" then opt.text = newVal else menuOptions[menuSelection] = newVal end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
            refreshFiles()
        elseif optText:match("Favorito") then
            local item = files[selectedIndex]
            local path = item.fullPath
            if favoriteRoms[path] then
                favoriteRoms[path] = nil
                if type(opt) == "table" then opt.text = "Añadir a Favoritos" else menuOptions[menuSelection] = "Añadir a Favoritos" end
            else
                favoriteRoms[path] = true
                if type(opt) == "table" then opt.text = "Quitar de Favoritos" else menuOptions[menuSelection] = "Quitar de Favoritos" end
            end
            filesystem.saveFavorites(favoriteRoms, json.encode)
            if isVirtualRoot then
                files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
            else
                refreshFiles()
            end
        elseif optText == "Re-indexar" then
            forceReindex()
            state = "LIST" -- Cerrar menú y volver a lista (que mostrará estado de indexación)
        elseif optText:match("Copiar") or optText:match("Mover") then
            local isMove = optText:match("Mover")
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
        elseif optText:match("Save Games") then
            state = "SAVE_MANAGER"
        end
        inputCooldown = 0.2
    elseif key == "tab" then
         if menuTitle == "Configuración" then return end

         if menuTitle == "Versión" then
             local item = files[selectedIndex]
             local ver = item.versions[menuSelection]
             
             table.insert(menuStack, {
                 title = menuTitle,
                 message = menuMessage,
                 options = menuOptions,
                 selection = menuSelection,
                 focusedItem = focusedItem
             })
             focusedItem = ver
             
             menuTitle = "Opciones: " .. ver.name
             menuMessage = ver.name
             findSaveFiles(ver)
             menuOptions = {"Info", "Scraper", "Save Games (" .. #saveFiles .. ")", "Borrar"}
             
             if favoriteRoms[ver.fullPath] then
                 table.insert(menuOptions, 2, "Quitar de Favoritos")
             else
                 table.insert(menuOptions, 2, "Añadir a Favoritos")
             end

             menuSelection = 1
             menuAnim = 0 -- Reiniciar animación para efecto de entrada del submenú
             inputCooldown = 0.2
             return
         end

        -- Si estamos en un submenú (hay padre), Tab no debe cerrar todo de golpe
        if #menuStack > 0 then return end

        closingMenu = true
        menuStack = {} -- Limpiar pila para evitar fantasmas al reabrir
        log("Menu exited: " .. menuTitle)
        inputCooldown = 0.2
    elseif key == "backspace" then
        if #menuStack > 0 then
             closingMenu = true -- Trigger animation, menu will be popped on completion
             inputCooldown = 0.2
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
        if #menuStack > 0 then
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
        if menuOptions[menuSelection] == "Limpiar" then
            local item = files[selectedIndex]
            local baseName = item.name:gsub("%..-$", "")
            os.remove(muosArtPath .. baseName .. ".png")
            os.remove(muosTextPath .. baseName .. ".txt")
            os.remove(muosTextPath .. baseName .. ".year")
            os.remove(muosPreviewPath .. baseName .. ".png")
            preview.load()
            state = "SCRAPER_VIEW"
        end
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
        if #menuStack > 0 then
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
        menuTitle = "Opciones"
        menuAnim = 0
        menuMessage = ""
        menuOptions = {"Limpiar"}
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
        inputCooldown = 0.15
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
        if #menuStack > 0 then
            state = "OPTIONS_MENU"
        else
            state = "LIST"
        end
        inputCooldown = 0.2
    elseif key == "return" or key == "kpenter" then
        -- Copiar save a la otra SD
        local item = saveFiles[saveManagerSelection]
        if item then
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
            end
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
        elseif key == "return" or key == "kpenter" or key == "space" or key == "a" then
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
                        local success, err = os.remove(orphan.fullPath)
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
                    local success, err = os.remove(item.fullPath)
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
                    local success, err = os.remove(item.fullPath)
                    if success then 
                        log("Cleanup: Borrado " .. item.fullPath) 
                        filesystem.logDeletion(item.fullPath, json.encode, json.decode)
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
            inputCooldown = 0.2
        end
        return
    end

    if key == "backspace" or key == "escape" then
        state = "LIST"
        inputCooldown = 0.2
    elseif not cleanupData.scanned then
        if key == "return" or key == "kpenter" then
            performCleanupScan()
        end
    else
        -- Navegación en resultados
        if key == "f" then -- L1: Cycle columns
            if cleanupData.cursor.col == 1 then
                cleanupData.cursor.col = 2
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.duplicates)
            elseif cleanupData.cursor.col == 2 and #cleanupData.orphanedImages > 0 then
                cleanupData.cursor.col = 3
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.orphanedImages)
            else
                cleanupData.cursor.col = 1
                cleanupData.cursor.row = math.min(cleanupData.cursor.row, #cleanupData.orphans + 1)
            end
        elseif key == "left" then -- Page Up (Pagination)
            local maxRows = (cleanupData.cursor.col == 1 and #cleanupData.orphans + 1) or (cleanupData.cursor.col == 2 and #cleanupData.duplicates) or #cleanupData.orphanedImages
            cleanupData.cursor.row = math.max(1, cleanupData.cursor.row - pageSize)
        elseif key == "right" then -- Page Down (Pagination)
            local maxRows = (cleanupData.cursor.col == 1 and #cleanupData.orphans + 1) or (cleanupData.cursor.col == 2 and #cleanupData.duplicates) or #cleanupData.orphanedImages
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
                cleanupData.confirming = true
                inputCooldown = 0.2
            end
        end
    end
end

-- Manejador para Menú de Borrado
function stateHandlers.DELETE_MENU(key)
    if key == "return" or key == "space" or key == "kpenter" then
        if menuOptions[menuSelection] == "Borrar" then
            if selectedFilesCount > 0 then
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
                        end
                        if romIndex then removeFromIndex(fullPath) end
                        if playedRoms[fullPath] then
                            playedRoms[fullPath] = nil
                        end
                    end
                end
                saveHistory()
                if isVirtualRoot and launchMode == "Juego Unico" then
                    files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                    preview.load()
                else
                    refreshFiles()
                end
                itemToDelete = nil
            elseif itemToDelete then
                local fullPath = itemToDelete.fullPath or (romPath .. itemToDelete.name)
                deleteGameMedia(fullPath)
                local success, err = os.remove(fullPath)
                if not success then
                    log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                else
                    log("Archivo borrado con éxito: " .. fullPath)
                    filesystem.logDeletion(fullPath, json.encode, json.decode)
                end
                if romIndex then removeFromIndex(fullPath) end
                if playedRoms[fullPath] then
                    playedRoms[fullPath] = nil
                    saveHistory()
                end
                -- Deselect to avoid errors, then refresh
                if isVirtualRoot and launchMode == "Juego Unico" then
                    files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                    preview.load()
                else
                    refreshFiles()
                end
                itemToDelete = nil
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
    elseif key == "backspace" then -- 'b' button
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
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" then
                 log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, romPath, favoriteRoms, hideFavorites)
                 preview.load()
                 inputCooldown = 0.2
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
    end

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
        preview.load()
        return -- Consumir input (el movimiento visual ya ocurrió al borrar el item)
    end

    if key == "f" then
        state = "SEARCH"
        searchQuery = ""
        keyboardRow = 1
        keyboardCol = 1
        love.keyboard.setTextInput(true) -- Enable text input
        filterFiles()
        return
    end
    
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
        timer = 0
    elseif key == "pagedown" then
        if viewMode == "GRID" then
            selectedIndex = math.min(#files, selectedIndex + (gridCols * 3))
        else
            selectedIndex = math.min(#files, selectedIndex + pageSize)
        end
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0
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
                        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                        preview.load()
                        return
                    end
                    local cwd = love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then -- Simulator path check
                        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
                        preview.load()
                        return
                    end
                    romPath = newPath
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
                    state = "OPTIONS_MENU"
                    menuAnim = 0
                    menuTitle = "Versión"
                    log("Menu opened: " .. menuTitle .. " for " .. item.name)
                    menuMessage = item.name
                    menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system
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
                romToLaunch = isVirtualRoot and item.fullPath or romPath .. item.name
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
        end
    elseif key == "backspace" then -- 'b' button
        if isVirtualRoot then
            inputCooldown = 0.2 -- Prevent phantom input when actionless
            return -- No hacer nada si ya estamos en la raíz virtual
        else
            local parent = romPath:gsub("[^/]+/$", "")
            log("Back. Verificando ruta: " .. romPath .. " -> Parent: " .. parent)
            
            -- Comprobar si el padre es una raíz de sistema para volver al menú virtual
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"
            
            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" or romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or
               romPath == "" or romPath == "@Favorites/" then
                 log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, allFiles, romPath, favoriteRoms, hideFavorites)
                 log("Virtual Root created. Items: " .. #files)
                 preview.load()
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
        if item then
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
                    menuTitle = "Versión"
                    log("Menu opened: " .. menuTitle .. " for " .. item.name)
                    menuMessage = item.name
                    menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system
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

                state = "OPTIONS_MENU"
                menuAnim = 0
                menuTitle = "Opciones:"
                menuStack = {}
                if selectedFilesCount > 0 then
                    menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
                else
                    menuMessage = item.name
                end
                menuSelection = 1
                
                menuOptions = {}
                -- 1. Info (Solo individual)
                if selectedFilesCount <= 1 then
                    table.insert(menuOptions, {text="Info", icon=iconInfo})
                end
                -- Favoritos
                if favoriteRoms[item.fullPath] then
                    table.insert(menuOptions, {text="Quitar de Favoritos", icon=iconFavorite})
                else
                    table.insert(menuOptions, {text="Añadir a Favoritos", icon=iconFavorite})
                end
                table.insert(menuOptions, {text="Scraper", icon=iconNetwork})
                
                -- 2. Copiar / Mover
                if item.sourceLabel ~= "SD½" then
                    local _, targetLabel = filesystem.getTargetSDPath(item.fullPath, config)
                    if targetLabel then
                        table.insert(menuOptions, {text="Copiar a " .. targetLabel, icon=iconFolder})
                        table.insert(menuOptions, {text="Mover a " .. targetLabel, icon=iconFolder})
                    end
                end
                
                -- 3. Save Games
                findSaveFiles(item)
                table.insert(menuOptions, {text="Save Games (" .. #saveFiles .. ")", icon=iconSaveStates})
                
                -- 4. Borrar (Al final)
                if not item.isFavorites then
                    if item.sourceLabel == "SD½" then
                        table.insert(menuOptions, {text="Borrar de SD1", icon=iconTrash})
                        table.insert(menuOptions, {text="Borrar de SD2", icon=iconTrash})
                    else
                        table.insert(menuOptions, {text="Borrar", icon=iconTrash})
                    end
                end
                
                inputCooldown = 0.15
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

local function keypressed(key)
    log("Key pressed: " .. key .. " (State: " .. state .. ")")
    if inputCooldown > 0 then
        log("Input ignored due to cooldown (" .. string.format("%.2f", inputCooldown) .. "s)")
        return
    end

    if key == "escape" then -- 'select' button on controller
        log("Select button pressed, quitting application.")
        love.event.quit()
        return
    end

    -- Si se está mostrando la pantalla de indexación, bloquear casi toda la entrada.
    if launchMode == "Juego Unico" and isVirtualRoot and not romIndex then
        if state == "OPTIONS_MENU" then
            -- Permitir navegación si logramos abrir el menú
        elseif key == "f1" then
            -- Permitir Start para abrir configuración (cambiar vista, etc)
        else
            -- Bloquear cualquier otra tecla
            return
        end
    end

    -- Modal Help Menu Logic
    if showHelp then
        -- Close with the same help button (f3/R1) or the back button (B)
        if key == "f3" or key == "backspace" or key == "b" then
            showHelp = false
            closingHelp = true
            inputCooldown = 0.2 -- Evita que la pulsación de B también salga del menú subyacente
            return -- Salir inmediatamente para que no se procese nada más
        end
        -- Block all other inputs while help is visible
        return
    end

    if key == "f3" then
        showHelp = true
        return
    end

    if key == "f1" then -- Start button
        if state == "OPTIONS_MENU" and menuTitle == "Configuración" then
            closingMenu = true
            log("Configuration Menu exited")
            inputCooldown = 0.2
            return
        elseif state == "LIST" then
            log("Opening Configuration Menu")
            state = "OPTIONS_MENU"
            menuAnim = 0
            menuTitle = "Configuración"
            menuStack = {}
            menuMessage = ""
            menuSelection = 1
            menuOptions = {}
            if romPath ~= "@Favorites/" then
                table.insert(menuOptions, {text = "Modo: " .. launchMode, icon = iconGame})
            end
            local viewIcon = (viewMode == "LIST") and iconList or iconGrid
            table.insert(menuOptions, {text = "Vista: " .. (viewMode == "LIST" and "Lista" or "Cuadrícula"), icon = viewIcon})
            table.insert(menuOptions, {text = "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF"), icon = iconHide})
            table.insert(menuOptions, {text = "Marcar Jugado: " .. (markPlayed and "Si" or "No"), icon = iconRom})
            table.insert(menuOptions, {text = "Ocultar Favoritos: " .. (hideFavorites and "ON" or "OFF"), icon = iconHide})
            table.insert(menuOptions, {text = "Re-indexar", icon = iconReload})
            table.insert(menuOptions, {text = "Limpieza", icon = iconTrash})
            inputCooldown = 0.2
            return
        end
    end

    -- State Dispatch
    local handler = stateHandlers[state]
    if handler then
        handler(key)
    else
        -- Default LIST handler logic (including empty dir check)
        handleListInput(key)
    end
end

local function gamepadpressed(joystick, button)
    if button == "a" then
        keypressed("kpenter") -- Usamos kpenter para mayor compatibilidad
    elseif button == "b" then
        keypressed("backspace")
    elseif button == "y" then
        keypressed("tab") -- Physical Y (Left) -> Options
    elseif button == "x" then
        keypressed("x") -- Physical X (Top) -> Select
    elseif button == "dpleft" then
        keypressed("left")
    elseif button == "dpright" then
        keypressed("right")
    elseif button == "back" then
        keypressed("escape")
    elseif button == "start" then
        keypressed("f1")
    elseif button == "leftshoulder" then
        keypressed("f") -- L1 -> Search
    elseif button == "triggerleft" then
        keypressed("f2") -- L2 -> Clear Filter
    elseif button == "rightshoulder" then
        keypressed("f3") -- R1 -> Help
    elseif button == "triggerright" then
        keypressed("f4") -- R2 -> Unused
    end
end

local function joystickpressed(joystick, button)
    -- Fallback para botones que no se detectan como Gamepad (L1/R1/L2 a veces)
    -- Mapeo común en dispositivos Anbernic/muOS: 4=L1, 5=R1, 6=L2
    local isGamepad = joystick:isGamepad()
    
    if button == 4 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f") -- L1 -> Buscar
    elseif button == 5 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f3") -- R1 -> Ayuda
    elseif button == 6 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f2") -- L2 -> Limpiar Filtro
    end
end

local function textinput(t)
    if showHelp then return end
    if state == "SEARCH" then
        searchQuery = searchQuery .. t
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