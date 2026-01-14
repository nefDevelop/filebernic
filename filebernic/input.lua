local function keypressed(key)
    if inputCooldown > 0 then return end

    -- Modal Help Menu Logic
    if showHelp then
        -- Close with the same help button (f3/R1) or the back button (B)
        if key == "f3" or key == "backspace" or key == "b" or key == "escape" then
            showHelp = false
            closingHelp = true
            inputCooldown = 0.2 -- Evita que la pulsación de B también salga del menú subyacente
            return -- Salir inmediatamente para que no se procese nada más
        end
        -- Block all other inputs while help is visible
        return
    end

    -- If help is not shown, f3 will open it.
    if key == "f3" then
        showHelp = true
        return
    end

    if key == "f1" then -- Start button
        if state == "OPTIONS_MENU" and menuTitle == "Configuración" then
            state = "LIST"
            closingMenu = true
            inputCooldown = 0.3
            return
        elseif state == "LIST" then
            state = "OPTIONS_MENU"
            menuAnim = 0
            menuTitle = "Configuración"
            menuMessage = ""
            menuSelection = 1
            menuOptions = {}
            table.insert(menuOptions, "Modo: " .. launchMode)
            table.insert(menuOptions, "Vista: " .. (viewMode == "LIST" and "Lista" or "Cuadrícula"))
            table.insert(menuOptions, "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF"))
            table.insert(menuOptions, "Marcar Jugado: " .. (markPlayed and "Si" or "No"))
            table.insert(menuOptions, "Limpieza")
            inputCooldown = 0.3
            return
        end
    end

    -- Search mode logic
    if state == "SEARCH" then
        if key == "up" then
            keyboardRow = math.max(1, keyboardRow - 1)
            keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
            inputCooldown = 0.2
        elseif key == "down" then
            keyboardRow = math.min(#keyboardGrid, keyboardRow + 1)
            keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol)
            inputCooldown = 0.2
        elseif key == "left" then
            keyboardCol = math.max(1, keyboardCol - 1)
            inputCooldown = 0.2
        elseif key == "right" then
            keyboardCol = math.min(#keyboardGrid[keyboardRow], keyboardCol + 1)
            inputCooldown = 0.2
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
            inputCooldown = 0.3
        elseif key == "f2" then -- L2: Clear filter
            searchQuery = ""
            filterFiles()
            state = "LIST"
            love.keyboard.setTextInput(false)
            inputCooldown = 0.3
        elseif key == "escape" or key == "backspace" then -- 'b' button (Cancel)
            state = "LIST"
            files = allFiles -- Restore full list
            searchQuery = ""
            love.keyboard.setTextInput(false) -- Disable text input
            inputCooldown = 0.3
        end
        return
    end

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
                 createMergedVirtualRoot()
                 inputCooldown = 0.3
                 return
            end
            romPath = parent
            secondaryPath = resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.3
        else
            return -- Ignore other key presses for empty directory message
        end
    end

    if state == "OPTIONS_MENU" then
        if key == "return" or key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then
            if parentMenuData then
                 -- Acciones del sub-menú de versión
                 local opt = menuOptions[menuSelection]
                 if opt == "Info" then
                     loadPreview()
                     state = "INFO_VIEW"
                 elseif opt == "Scraper" then
                     state = "SCRAPER_VIEW"
                 elseif opt:match("Save Games") then
                     state = "SAVE_MANAGER"
                 elseif opt == "Borrar" then
                     local fullPath = focusedItem.fullPath
                     deleteGameMedia(fullPath)
                     local success, err = os.remove(fullPath)
                     if success then
                         log("Archivo borrado con éxito: " .. fullPath)
                         if romIndex then removeFromIndex(fullPath) end
                     else
                         log("Error al borrar archivo: " .. fullPath .. " - " .. tostring(err))
                     end
                     if playedRoms[fullPath] then playedRoms[fullPath] = nil saveHistory() end
                     if isVirtualRoot and launchMode == "Juego Unico" then
                         createMergedVirtualRoot()
                     else
                         refreshFiles()
                     end
                     state = "LIST"
                     parentMenuData = nil
                     focusedItem = nil
                 end
                 inputCooldown = 0.3
                 return
            end

            if menuTitle == "Seleccionar Versión" then
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
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    menuTitle = "Confirmar Borrado"
                    menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
                    menuOptions = {"Borrar", "Cancelar"}
                    menuSelection = 2
                    state = "DELETE_MENU"
                elseif (not isVirtualRoot or launchMode == "Juego Unico") and files[selectedIndex] and (not files[selectedIndex].isDir or files[selectedIndex].name ~= "..") then
                    itemToDelete = files[selectedIndex]
                    menuTitle = "Confirmar Borrado"
                    menuMessage = "¿Borrar este archivo?\n" .. itemToDelete.name
                    menuOptions = {"Borrar", "Cancelar"}
                    menuSelection = 2
                    state = "DELETE_MENU"
                end
            elseif menuOptions[menuSelection] == "Info" then
                state = "INFO_VIEW"
                inputCooldown = 0.3
            elseif menuOptions[menuSelection] == "Scraper" then
                if selectedFilesCount > 0 then
                    local items = {}
                    for _, f in ipairs(files) do
                        if f.selected then table.insert(items, f) end
                    end
                    performBatchScrape(items)
                    inputCooldown = 0.3
                else
                    state = "SCRAPER_VIEW"
                    inputCooldown = 0.3
                end
            elseif menuOptions[menuSelection] == "Borrar de SD1" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/mmc") and item.fullPath or item.secondaryPath
                deleteGameMedia(pathToDelete)
                local success, err = os.remove(pathToDelete)
                if success then
                    log("Archivo borrado con éxito: " .. pathToDelete)
                    if romIndex then removeFromIndex(pathToDelete) end
                else
                    log("Error al borrar archivo: " .. pathToDelete .. " - " .. tostring(err))
                end
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                if isVirtualRoot and launchMode == "Juego Unico" then
                    createMergedVirtualRoot()
                else
                    refreshFiles()
                end
                state = "LIST"
            elseif menuOptions[menuSelection] == "Borrar de SD2" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/sdcard") and item.fullPath or item.secondaryPath
                deleteGameMedia(pathToDelete)
                local success, err = os.remove(pathToDelete)
                if success then
                    log("Archivo borrado con éxito: " .. pathToDelete)
                    if romIndex then removeFromIndex(pathToDelete) end
                else
                    log("Error al borrar archivo: " .. pathToDelete .. " - " .. tostring(err))
                end
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                if isVirtualRoot and launchMode == "Juego Unico" then
                    createMergedVirtualRoot()
                else
                    refreshFiles()
                end
                state = "LIST"
            elseif menuOptions[menuSelection]:match("Modo:") then
                launchMode = (launchMode == "Folder") and "Juego Unico" or "Folder"
                menuOptions[menuSelection] = "Modo: " .. launchMode
                saveAppState()
                createMergedVirtualRoot()
            elseif menuOptions[menuSelection]:match("Ocultar vacíos") then
                hideEmpty = not hideEmpty
                menuOptions[menuSelection] = "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF")
                if isVirtualRoot then createMergedVirtualRoot() end
            elseif menuOptions[menuSelection]:match("Vista:") then
                viewMode = (viewMode == "LIST") and "GRID" or "LIST"
                menuOptions[menuSelection] = "Vista: " .. (viewMode == "LIST" and "Lista" or "Cuadrícula")
                saveAppState()
            elseif menuOptions[menuSelection] == "Limpieza" then
                state = "CLEANUP_MENU"
                cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
                inputCooldown = 0.3
            elseif menuOptions[menuSelection]:match("Marcar Jugado") then
                markPlayed = not markPlayed
                menuOptions[menuSelection] = "Marcar Jugado: " .. (markPlayed and "Si" or "No")
                saveAppState()
            elseif menuOptions[menuSelection]:match("Copiar") or menuOptions[menuSelection]:match("Mover") then
                local isMove = menuOptions[menuSelection]:match("Mover")
                local targetDir, _ = getTargetSDPath(romPath)
                
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
            elseif menuOptions[menuSelection]:match("Save Games") then
                state = "SAVE_MANAGER"
            end
            inputCooldown = 0.3
        elseif key == "tab" then
             if menuTitle == "Seleccionar Versión" then
                 local item = files[selectedIndex]
                 local ver = item.versions[menuSelection]
                 
                 parentMenuData = {
                     title = menuTitle,
                     message = menuMessage,
                     options = menuOptions,
                     selection = menuSelection
                 }
                 focusedItem = ver
                 
                 menuTitle = "Opciones: " .. ver.name
                 menuMessage = ver.name
                 findSaveFiles(ver)
                 menuOptions = {"Info", "Scraper", "Save Games (" .. #saveFiles .. ")", "Borrar"}
                 menuSelection = 1
                 inputCooldown = 0.3
                 return
             end
        elseif key == "backspace" then
            if parentMenuData then
                 menuTitle = parentMenuData.title
                 menuMessage = parentMenuData.message
                 menuOptions = parentMenuData.options
                 menuSelection = parentMenuData.selection
                 parentMenuData = nil
                 focusedItem = nil
                 inputCooldown = 0.3
            else
                state = "LIST"
                closingMenu = true
                inputCooldown = 0.3
            end
        end
        return
    end

    if state == "INFO_VIEW" then
        if key == "backspace" or key == "b" or key == "escape" then
            if parentMenuData then
                state = "OPTIONS_MENU"
            else
                state = "LIST"
            end
            showHelp = false
            inputCooldown = 0.3
        end
        return
    end

    if state == "SCRAPER_OPTIONS" then
        if key == "return" or key == "kpenter" then
            if menuOptions[menuSelection] == "Limpiar" then
                local item = files[selectedIndex]
                local baseName = item.name:gsub("%..-$", "")
                os.remove(muosArtPath .. baseName .. ".png")
                os.remove(muosTextPath .. baseName .. ".txt")
                os.remove(muosTextPath .. baseName .. ".year")
                os.remove(muosPreviewPath .. baseName .. ".png")
                loadPreview()
                state = "SCRAPER_VIEW"
            end
            inputCooldown = 0.3
        elseif key == "backspace" or key == "x" or key == "escape" then
            state = "SCRAPER_VIEW"
            closingMenu = true
            inputCooldown = 0.3
        end
        return
    end

    if state == "SCRAPER_VIEW" then
        if key == "backspace" then -- 'b' button
            if parentMenuData then
                state = "OPTIONS_MENU"
            else
                state = "LIST"
            end
            showHelp = false
            inputCooldown = 0.3
        elseif key == "return" or key == "kpenter" then -- 'a' button
            startScraping()
        elseif key == "tab" then -- 'y' button
            state = "SCRAPER_OPTIONS"
            menuTitle = "Opciones"
            menuAnim = 0
            menuMessage = ""
            menuOptions = {"Limpiar"}
            menuSelection = 1
            inputCooldown = 0.3
        end
        return
    end

    if state == "SCRAPER_RESULTS" then
        if key == "backspace" then
            state = "SCRAPER_VIEW"
            showHelp = false
            inputCooldown = 0.3
        elseif key == "left" then
            scraperSelection = math.max(1, scraperSelection - 1)
            inputCooldown = 0.2
        elseif key == "right" then
            scraperSelection = math.min(#scraperResults, scraperSelection + 1)
            inputCooldown = 0.2
        elseif (key == "return" or key == "kpenter") and #scraperResults > 0 then
            local sel = scraperResults[scraperSelection]
            if sel and not sel.error then
                saveSelectedArt()
                inputCooldown = 0.3
            end
        end
        return
    end

    if state == "SAVE_MANAGER" then
        if key == "backspace" or key == "escape" then
            if parentMenuData then
                state = "OPTIONS_MENU"
            else
                state = "LIST"
            end
            inputCooldown = 0.3
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
            inputCooldown = 0.3
        end
        return
    end

    if state == "CLEANUP_MENU" then
        if cleanupData.confirming then
            if key == "backspace" or key == "escape" or key == "b" then
                cleanupData.confirming = false
                inputCooldown = 0.3
            elseif key == "return" or key == "kpenter" or key == "space" or key == "a" then
                -- Ejecutar acción de borrado confirmada
                if cleanupData.cursor.col == 1 then
                    -- Columna Huérfanos
                    if cleanupData.cursor.row == 1 then
                        -- Borrar TODOS
                        for _, orphan in ipairs(cleanupData.orphans) do
                            local success, err = os.remove(orphan.fullPath)
                            if success then log("Cleanup: Borrado " .. orphan.fullPath) else log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                        end
                        cleanupData.orphans = {}
                    else
                        -- Borrar Individual
                        local idx = cleanupData.cursor.row - 1
                        local orphan = cleanupData.orphans[idx]
                        if orphan then
                            local success, err = os.remove(orphan.fullPath)
                            if success then log("Cleanup: Borrado " .. orphan.fullPath) else log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
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
                        if success then log("Cleanup: Borrado " .. item.fullPath) else log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) end
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
                inputCooldown = 0.3
            end
            return
        end

        if key == "backspace" or key == "escape" then
            state = "LIST"
            inputCooldown = 0.3
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
                    inputCooldown = 0.3
                end
            end
        end
        return
    end

    if state == "DELETE_MENU" then
        if key == "return" or key == "space" or key == "kpenter" then
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    for _, item in ipairs(files) do
                        if item.selected then
                            local fullPath = item.fullPath or (romPath .. item.name)
                            deleteGameMedia(fullPath)
                            local success, err = os.remove(fullPath)
                            if success then
                                log("Archivo borrado con éxito: " .. fullPath)
                                if romIndex then removeFromIndex(fullPath) end
                            else
                                log("Error al borrar archivo: " .. fullPath .. " - " .. tostring(err))
                            end
                            if playedRoms[fullPath] then
                                playedRoms[fullPath] = nil
                            end
                        end
                    end
                    saveHistory()
                    if isVirtualRoot and launchMode == "Juego Unico" then
                        createMergedVirtualRoot()
                    else
                        refreshFiles()
                    end
                    itemToDelete = nil
                elseif itemToDelete then
                    local fullPath = itemToDelete.fullPath or (romPath .. itemToDelete.name)
                    deleteGameMedia(fullPath)
                    local success, err = os.remove(fullPath)
                    if success then
                        log("Archivo borrado con éxito: " .. fullPath)
                        if romIndex then removeFromIndex(fullPath) end
                    else
                        log("Error al borrar archivo: " .. fullPath .. " - " .. tostring(err))
                    end
                    if playedRoms[fullPath] then
                        playedRoms[fullPath] = nil
                        saveHistory()
                    end
                    -- Deselect to avoid errors, then refresh
                    selectedIndex = math.max(1, selectedIndex - 1)
                    if isVirtualRoot and launchMode == "Juego Unico" then
                        createMergedVirtualRoot()
                    else
                        refreshFiles()
                    end
                    itemToDelete = nil
                end
            end
            inputCooldown = 0.3
            state = "LIST"
            closingMenu = true
        elseif key == "backspace" then -- Cancel
            itemToDelete = nil
            inputCooldown = 0.3
            state = "LIST"
            closingMenu = true
        end
        return
    end

    if state == "POST_GAME" then
        if key == "return" or key == "space" or key == "kpenter" then -- 'a' button
            os.remove(lastPlayedRom) 
            state = "LIST" 
            inputCooldown = 0.3
            refreshFiles()
        elseif key == "backspace" then -- 'b' button
            state = "LIST" 
            inputCooldown = 0.3
        end
        return
    end

    -- From here on, we are in LIST state
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
        inputCooldown = 0.3
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
                inputCooldown = 0.3
            else
                if item.name == ".." then
                    local newPath = romPath:gsub("[^/]+/$", "")
                    if newPath == "/mnt/mmc/ROMS/" or newPath == "/mnt/sdcard/ROMS/" then
                        createMergedVirtualRoot()
                        return
                    end
                    local cwd = love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then -- Simulator path check
                        createMergedVirtualRoot()
                        return
                    end
                    romPath = newPath
                    secondaryPath = resolveSecondary(romPath)
                else
                    romPath = romPath .. item.name .. "/"
                end
                selectedIndex = 1
                refreshFiles()
                inputCooldown = 0.3
            end
        else
            -- Launch ROM
            local romToLaunch = nil
            
            if launchMode == "Juego Unico" and item.versions then
                if #item.versions > 1 then
                    state = "OPTIONS_MENU"
                    menuAnim = 0
                    menuTitle = "Seleccionar Versión"
                    menuMessage = item.name
                    menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = getSystemContentIcon(v.system)
                        table.insert(menuOptions, {
                            text = v.name,
                            icon = icon,
                            system = v.system,
                            played = playedRoms[v.fullPath]
                        })
                    end
                    menuSelection = 1
                    inputCooldown = 0.3
                    return
                elseif #item.versions == 1 then
                    romToLaunch = item.versions[1].fullPath
                end
            else
                romToLaunch = isVirtualRoot and item.fullPath or romPath .. item.name
            end
            
            if romToLaunch then
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
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" then
                 log("Límite alcanzado. Volviendo a Ruta Virtual.")
                 createMergedVirtualRoot()
                 inputCooldown = 0.3
                 return
            end
            romPath = parent
            secondaryPath = resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.3
        end
    elseif key == "escape" then -- 'back' button on controller
        log("Select button pressed, quitting application.")
        love.event.quit() -- The script will handle the rest
    elseif key == "tab" then -- 'Y' button
        local item = files[selectedIndex]
        if item and not item.isDir then
            -- En modo único, si hay versiones, el menú de opciones está dentro de la selección de versión
            if launchMode == "Juego Unico" and item.versions and #item.versions > 1 then
                -- Open the version selection menu, same as 'A'
                state = "OPTIONS_MENU"
                menuAnim = 0
                menuTitle = "Seleccionar Versión"
                menuMessage = item.name
                menuOptions = {}
                for _, v in ipairs(item.versions) do
                    local icon = getSystemContentIcon(v.system)
                    table.insert(menuOptions, {
                        text = v.name,
                        icon = icon,
                        system = v.system,
                        played = playedRoms[v.fullPath]
                    })
                end
                menuSelection = 1
                inputCooldown = 0.3
                return
            end

            state = "OPTIONS_MENU"
            menuAnim = 0
            menuTitle = "Opciones:"
            if selectedFilesCount > 0 then
                menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
            else
                menuMessage = item.name
            end
            menuSelection = 1
            
            menuOptions = {}
            -- 1. Info (Solo individual)
            if selectedFilesCount <= 1 then
                table.insert(menuOptions, "Info")
            end
            table.insert(menuOptions, "Scraper")
            
            -- 2. Copiar / Mover
            if item.sourceLabel ~= "SD½" then
                local _, targetLabel = getTargetSDPath(item.fullPath)
                if targetLabel then
                    table.insert(menuOptions, "Copiar a " .. targetLabel)
                    table.insert(menuOptions, "Mover a " .. targetLabel)
                end
            end
            
            -- 3. Save Games
            findSaveFiles(item)
            table.insert(menuOptions, "Save Games (" .. #saveFiles .. ")")
            
            -- 4. Borrar (Al final)
            if item.sourceLabel == "SD½" then
                table.insert(menuOptions, "Borrar de SD1")
                table.insert(menuOptions, "Borrar de SD2")
            else
                table.insert(menuOptions, "Borrar")
            end
            
            inputCooldown = 0.3
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
    if button == 4 then
        if joystick:isGamepadDown("a") then return end -- Evita conflicto si A es el botón 4
        keypressed("f") -- L1 -> Buscar
    elseif button == 5 then
        keypressed("f3") -- R1 -> Ayuda
    elseif button == 6 then
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
    textinput = textinput
}