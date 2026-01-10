local function keypressed(key)
    if inputCooldown > 0 then return end

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
            if romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" then
                 createMergedVirtualRoot()
                 return
            end
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            if romPath == cwd .. "/../Simulador_SD/" then
                 createMergedVirtualRoot()
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
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(#menuOptions, menuSelection + 1)
        elseif key == "return" or key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    menuTitle = "Confirmar Borrado"
                    menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
                    menuOptions = {"Borrar", "Cancelar"}
                    menuSelection = 2
                    state = "DELETE_MENU"
                elseif not isVirtualRoot and files[selectedIndex] and (not files[selectedIndex].isDir or files[selectedIndex].name ~= "..") then
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
                state = "SCRAPER_VIEW"
                inputCooldown = 0.3
            elseif menuOptions[menuSelection] == "Borrar de SD1" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/mmc") and item.fullPath or item.secondaryPath
                os.remove(pathToDelete)
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                refreshFiles()
                state = "LIST"
            elseif menuOptions[menuSelection] == "Borrar de SD2" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/sdcard") and item.fullPath or item.secondaryPath
                os.remove(pathToDelete)
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                refreshFiles()
                state = "LIST"
            elseif menuOptions[menuSelection]:match("Ocultar vacíos") then
                hideEmpty = not hideEmpty
                menuOptions[menuSelection] = "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF")
                if isVirtualRoot then createMergedVirtualRoot() end
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
            end
            inputCooldown = 0.3
        elseif key == "backspace" or key == "tab" then
            state = "LIST"
            inputCooldown = 0.3
        end
        return
    end

    if state == "INFO_VIEW" then
        if key == "backspace" or key == "b" or key == "escape" then
            state = "LIST"
            inputCooldown = 0.3
        end
        return
    end

    if state == "SCRAPER_OPTIONS" then
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(#menuOptions, menuSelection + 1)
        elseif key == "return" or key == "kpenter" then
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
            inputCooldown = 0.3
        end
        return
    end

    if state == "SCRAPER_VIEW" then
        if key == "backspace" then -- 'b' button
            state = "LIST"
            inputCooldown = 0.3
        elseif key == "return" or key == "kpenter" then -- 'a' button
            startScraping()
        elseif key == "tab" then -- 'y' button
            state = "SCRAPER_OPTIONS"
            menuTitle = "Opciones"
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
            inputCooldown = 0.3
        elseif key == "left" then
            scraperSelection = math.max(1, scraperSelection - 1)
            inputCooldown = 0.2
        elseif key == "right" then
            scraperSelection = math.min(#scraperResults, scraperSelection + 1)
            inputCooldown = 0.2
        elseif (key == "return" or key == "kpenter") and #scraperResults > 0 then
            saveSelectedArt()
            inputCooldown = 0.3
        end
        return
    end

    if state == "DELETE_MENU" then
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(#menuOptions, menuSelection + 1)
        elseif key == "return" or key == "space" or key == "kpenter" then
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    for _, item in ipairs(files) do
                        if item.selected then
                            local fullPath = romPath .. item.name
                            os.remove(fullPath)
                            if playedRoms[fullPath] then
                                playedRoms[fullPath] = nil
                            end
                        end
                    end
                    saveHistory()
                    refreshFiles()
                    itemToDelete = nil
                elseif itemToDelete then
                    os.remove(romPath .. itemToDelete.name)
                    if playedRoms[romPath .. itemToDelete.name] then
                        playedRoms[romPath .. itemToDelete.name] = nil
                        saveHistory()
                    end
                    -- Deselect to avoid errors, then refresh
                    selectedIndex = math.max(1, selectedIndex - 1)
                    refreshFiles()
                    itemToDelete = nil
                end
            end
            inputCooldown = 0.3
            state = "LIST"
        elseif key == "backspace" then -- Cancel
            itemToDelete = nil
            inputCooldown = 0.3
            state = "LIST"
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

    if key == "left" then 
        selectedIndex = math.max(1, selectedIndex - pageSize)
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0
    elseif key == "right" then 
        selectedIndex = math.min(#files, selectedIndex + pageSize)
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0
    elseif key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then -- 'a' button (Start envía return, lo ignoramos si hay gamepad)
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
            lastPlayedRom = isVirtualRoot and item.fullPath or romPath .. item.name
            saveLastPlayed(lastPlayedRom)
            addToHistory(lastPlayedRom)
            -- Iniciamos secuencia de lanzamiento (verde -> espera -> salir)
            launching = true
            launchTimer = 0
        end
    elseif key == "backspace" then -- 'b' button
        if isVirtualRoot then
            love.event.quit() -- Salir de la app desde el menú principal virtual
        else
            local parent = romPath:gsub("[^/]+/$", "")
            if romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" then
                 createMergedVirtualRoot()
                 return
            end
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            if romPath == cwd .. "/../Simulador_SD/" then
                 createMergedVirtualRoot()
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
            state = "OPTIONS_MENU"
            menuTitle = "Opciones de Archivo"
            if selectedFilesCount > 1 then
                menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
            else
                menuMessage = item.name
            end
            menuSelection = 1
            
            menuOptions = {}
            -- 1. Scraper
            if selectedFilesCount <= 1 then
                table.insert(menuOptions, "Info")
                table.insert(menuOptions, "Scraper")
            end
            
            -- 2. Copiar / Mover
            if item.sourceLabel ~= "SD1-SD2" then
                local _, targetLabel = getTargetSDPath(item.fullPath)
                if targetLabel then
                    table.insert(menuOptions, "Copiar a " .. targetLabel)
                    table.insert(menuOptions, "Mover a " .. targetLabel)
                end
            end
            
            -- 3. Borrar (Al final)
            if item.sourceLabel == "SD1-SD2" then
                table.insert(menuOptions, "Borrar de SD1")
                table.insert(menuOptions, "Borrar de SD2")
            else
                table.insert(menuOptions, "Borrar")
            end
            
            inputCooldown = 0.3
        end
    elseif key == "x" then
        local item = files[selectedIndex]
        if item and not item.isDir then
            item.selected = not item.selected
            if item.selected then
                selectedFilesCount = selectedFilesCount + 1
            else
                selectedFilesCount = selectedFilesCount - 1
            end
        end
    elseif key == "f1" then -- Start button
        state = "OPTIONS_MENU"
        menuTitle = "Configuración"
        menuMessage = ""
        menuSelection = 1
        menuOptions = {}
        table.insert(menuOptions, "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF"))
        inputCooldown = 0.3
    end
end

local function gamepadpressed(joystick, button)
    if button == "a" then
        keypressed("kpenter") -- Usamos kpenter para mayor compatibilidad
    elseif button == "b" then
        keypressed("backspace")
    elseif button == "y" then
        keypressed("tab")
    elseif button == "x" then
        keypressed("x")
    elseif button == "dpleft" then
        keypressed("left")
    elseif button == "dpright" then
        keypressed("right")
    elseif button == "back" then
        keypressed("escape")
    elseif button == "start" then
        keypressed("f1")
    elseif button == "leftshoulder" then
        keypressed("f")
    elseif button == "triggerleft" then
        keypressed("f2")
    end
end

local function textinput(t)
    if state == "SEARCH" then
        searchQuery = searchQuery .. t
        filterFiles()
    end
end

return {
    keypressed = keypressed,
    gamepadpressed = gamepadpressed,
    textinput = textinput
}