local function update(dt)
    log("update called with dt: " .. tostring(dt))
    loader:update()
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
    -- Lógica para actualizar las variables de previsualización de forma asíncrona
    local item = focusedItem
    if not item then
        if #files == 0 then
            -- Clear all previews if no files
            currentImage = nil
            currentScreenshot = nil
            currentYear = nil
            currentDescription = ""
            currentSystemIcon = nil
            currentSystemContentIcon = nil
            return -- Exit early if no files
        end
        item = files[selectedIndex]
    end

    if item and not item.isDir then
        local baseName = item.name:gsub("%..-$", "")
        local itemSystemName = utils.getSystemNameForItem(item)
        
        if itemSystemName then
            local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
            local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
            local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

            -- Actualizar currentImage (Boxart)
            local imgFile = artPathForSystem .. baseName .. ".png"
            local loadedImage = loader:getImage(imgFile)
            if loadedImage then
                currentImage = loadedImage
            end

            -- Actualizar currentScreenshot
            local scrFile = previewPathForSystem .. baseName .. ".png"
            local loadedScreenshot = loader:getImage(scrFile)
            if loadedScreenshot then
                currentScreenshot = loadedScreenshot
            end

            -- Actualizar currentDescription
            local txtFile = textPathForSystem .. baseName .. ".txt"
            local loadedDescription = loader:getText(txtFile)
            if loadedDescription then
                currentDescription = loadedDescription
            end

            -- Actualizar currentYear
            local yearFile = textPathForSystem .. baseName .. ".year"
            local loadedYear = loader:getText(yearFile)
            if loadedYear then
                currentYear = loadedYear
            end
        end
    end

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" or showHelp then
        menuAnim = math.min(1, menuAnim + dt * 8)
    else
        menuAnim = math.max(0, menuAnim - dt * 8)
    end

    if menuAnim == 0 then
        closingMenu = false
        closingHelp = false
    end

    if cleanupData.scanning and cleanupCoroutine then
        local status = coroutine.status(cleanupCoroutine)
        if status == "suspended" then
            local ok, err = coroutine.resume(cleanupCoroutine)
            if not ok then
                cleanupData.scanning = false
            end
        elseif status == "dead" then
            cleanupCoroutine = nil
        end
    end

    if isIndexing and indexCoroutine then
        local status = coroutine.status(indexCoroutine)
        if status == "suspended" then
            local ok, result = coroutine.resume(indexCoroutine)
            if not ok then
                log("Index Coroutine Error: " .. tostring(result))
                isIndexing = false
            else
                if coroutine.status(indexCoroutine) == "dead" then
                    -- Coroutine finished, result is the returned index
                    if type(result) == "table" then
                        romIndex = result
                    end
                    isIndexing = false
                    indexStateMessage = ""
                    indexCoroutine = nil
                    if launchMode == "Juego Unico" and isVirtualRoot then
                        createMergedVirtualRoot()
                    end
                elseif type(result) == "string" and result ~= "" then
                    indexStateMessage = result
                end
            end
        end
    end

    if state == "BATCH_SCRAPING" and scraperCoroutine then
        local status = coroutine.status(scraperCoroutine)
        if status == "suspended" then
            local ok, err = coroutine.resume(scraperCoroutine)
            if not ok then
                log("Scraper Coroutine Error: " .. tostring(err))
                state = "LIST"
            end
        elseif status == "dead" then
            scraperCoroutine = nil
            state = "LIST"
        end
    end

    if launching then
        launchTimer = launchTimer + dt
        if launchTimer > 0.1 then -- Pequeña espera para ver el color verde
            local f = io.open("/tmp/launch_rom", "w")
            if f then f:write(lastPlayedRom) f:close() end
            saveAppState()
            love.event.quit()
            os.exit(0)
        end
        return
    end

    -- Remover lógica de pendingLoad y timer

    if showHelp then return end

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = love.keyboard.isDown('down') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = love.keyboard.isDown('up') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))
    local is_left_pressed = love.keyboard.isDown('left') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpleft'))
    local is_right_pressed = love.keyboard.isDown('right') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpright'))

    local moved = false
    local moveDir = nil

    if is_down_pressed then
        if keyHeld ~= 'down' then
            -- Primera pulsación
            keyHeld = 'down'
            scrollTimer = initialScrollDelay
            moved = true
            fastScrollTimer = 0
            moveDir = 'down'
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            fastScrollTimer = fastScrollTimer + dt
            if scrollTimer <= 0 then
                if fastScrollTimer > 2 then
                    scrollTimer = 0.5 -- Velocidad de salto entre letras
                else
                    scrollTimer = subsequentScrollDelay
                end
                moved = true
                moveDir = 'down'
            end
        end
    elseif is_up_pressed then
        if keyHeld ~= 'up' then
            -- Primera pulsación
            keyHeld = 'up'
            scrollTimer = initialScrollDelay
            moved = true
            fastScrollTimer = 0
            moveDir = 'up'
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            fastScrollTimer = fastScrollTimer + dt
            if scrollTimer <= 0 then
                if fastScrollTimer > 2 then
                    scrollTimer = 0.5 -- Velocidad de salto entre letras
                else
                    scrollTimer = subsequentScrollDelay
                end
                moved = true
                moveDir = 'up'
            end
        end
    elseif is_left_pressed then
        if keyHeld ~= 'left' then
            keyHeld = 'left'
            scrollTimer = initialScrollDelay
            moved = true
            moveDir = 'left'
        else
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
                moveDir = 'left'
            end
        end
    elseif is_right_pressed then
        if keyHeld ~= 'right' then
            keyHeld = 'right'
            scrollTimer = initialScrollDelay
            moved = true
            moveDir = 'right'
        else
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
                moveDir = 'right'
            end
        end
    else
        keyHeld = nil
        fastScrollTimer = 0
    end

    if fastScrollTimer > 2 then
        if files[selectedIndex] then
            local name = files[selectedIndex].name
            if name and name ~= "" then 
                local l = name:sub(1,1):upper()
                if l ~= jumpLetter then
                    jumpLetter = l
                end
            end
        end
        jumpPanelAnim = math.min(1, jumpPanelAnim + dt * 6)
    else
        jumpPanelAnim = math.max(0, jumpPanelAnim - dt * 6)
        if jumpPanelAnim == 0 then
            jumpLetter = ""
        end
    end

local function update(dt)
    log("update called with dt: " .. tostring(dt))
    loader:update()
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
    local layout = State.layout -- Make layout accessible
    local scrollSpeed = 10 -- Adjust for desired scroll speed

    -- Lógica para actualizar las variables de previsualización de forma asíncrona
    local item = focusedItem
    if not item then
        if #files == 0 then
            -- Clear all previews if no files
            currentImage = nil
            currentScreenshot = nil
            currentYear = nil
            currentDescription = ""
            currentSystemIcon = nil
            currentSystemContentIcon = nil
            return -- Exit early if no files
        end
        item = files[selectedIndex]
    end

    if item and not item.isDir then
        local baseName = item.name:gsub("%..-$", "")
        local itemSystemName = utils.getSystemNameForItem(item)
        
        if itemSystemName then
            local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
            local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
            local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

            -- Actualizar currentImage (Boxart)
            local imgFile = artPathForSystem .. baseName .. ".png"
            local loadedImage = loader:getImage(imgFile)
            if loadedImage then
                currentImage = loadedImage
            end

            -- Actualizar currentScreenshot
            local scrFile = previewPathForSystem .. baseName .. ".png"
            local loadedScreenshot = loader:getImage(scrFile)
            if loadedScreenshot then
                currentScreenshot = loadedScreenshot
            end

            -- Actualizar currentDescription
            local txtFile = textPathForSystem .. baseName .. ".txt"
            local loadedDescription = loader:getText(txtFile)
            if loadedDescription then
                currentDescription = loadedDescription
            end

            -- Actualizar currentYear
            local yearFile = textPathForSystem .. baseName .. ".year"
            local loadedYear = loader:getText(yearFile)
            if loadedYear then
                currentYear = loadedYear
            end
        end
    end

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" or showHelp then
        menuAnim = math.min(1, menuAnim + dt * 8)
    else
        menuAnim = math.max(0, menuAnim - dt * 8)
    end

    if menuAnim == 0 then
        closingMenu = false
        closingHelp = false
    end

    if cleanupData.scanning and cleanupCoroutine then
        local status = coroutine.status(cleanupCoroutine)
        if status == "suspended" then
            local ok, err = coroutine.resume(cleanupCoroutine)
            if not ok then
                cleanupData.scanning = false
            end
        elseif status == "dead" then
            cleanupCoroutine = nil
        end
    end

    if isIndexing and indexCoroutine then
        local status = coroutine.status(indexCoroutine)
        if status == "suspended" then
            local ok, result = coroutine.resume(indexCoroutine)
            if not ok then
                log("Index Coroutine Error: " .. tostring(result))
                isIndexing = false
            else
                if coroutine.status(indexCoroutine) == "dead" then
                    -- Coroutine finished, result is the returned index
                    if type(result) == "table" then
                        romIndex = result
                    end
                    isIndexing = false
                    indexStateMessage = ""
                    indexCoroutine = nil
                    if launchMode == "Juego Unico" and isVirtualRoot then
                        createMergedVirtualRoot()
                    end
                elseif type(result) == "string" and result ~= "" then
                    indexStateMessage = result
                end
            end
        end
    end

    if state == "BATCH_SCRAPING" and scraperCoroutine then
        local status = coroutine.status(scraperCoroutine)
        if status == "suspended" then
            local ok, err = coroutine.resume(scraperCoroutine)
            if not ok then
                log("Scraper Coroutine Error: " .. tostring(err))
                state = "LIST"
            end
        elseif status == "dead" then
            scraperCoroutine = nil
            state = "LIST"
        end
    end

    if launching then
        launchTimer = launchTimer + dt
        if launchTimer > 0.1 then -- Pequeña espera para ver el color verde
            local f = io.open("/tmp/launch_rom", "w")
            if f then f:write(lastPlayedRom) f:close() end
            saveAppState()
            love.event.quit()
            os.exit(0)
        end
        return
    end

    -- Remover lógica de pendingLoad y timer

    if showHelp then return end

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = love.keyboard.isDown('down') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = love.keyboard.isDown('up') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))
    local is_left_pressed = love.keyboard.isDown('left') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpleft'))
    local is_right_pressed = love.keyboard.isDown('right') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpright'))

    local moved = false
    local moveDir = nil
    local oldSelectedIndex = selectedIndex -- Store old index to detect changes

    if is_down_pressed then
        if keyHeld ~= 'down' then
            -- Primera pulsación
            keyHeld = 'down'
            scrollTimer = initialScrollDelay
            moved = true
            fastScrollTimer = 0
            moveDir = 'down'
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            fastScrollTimer = fastScrollTimer + dt
            if scrollTimer <= 0 then
                if fastScrollTimer > 2 then
                    scrollTimer = 0.5 -- Velocidad de salto entre letras
                else
                    scrollTimer = subsequentScrollDelay
                end
                moved = true
                moveDir = 'down'
            end
        end
    elseif is_up_pressed then
        if keyHeld ~= 'up' then
            -- Primera pulsación
            keyHeld = 'up'
            scrollTimer = initialScrollDelay
            moved = true
            fastScrollTimer = 0
            moveDir = 'up'
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            fastScrollTimer = fastScrollTimer + dt
            if scrollTimer <= 0 then
                if fastScrollTimer > 2 then
                    scrollTimer = 0.5 -- Velocidad de salto entre letras
                else
                    scrollTimer = subsequentScrollDelay
                end
                moved = true
                moveDir = 'up'
            end
        end
    elseif is_left_pressed then
        if keyHeld ~= 'left' then
            keyHeld = 'left'
            scrollTimer = initialScrollDelay
            moved = true
            moveDir = 'left'
        else
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
                moveDir = 'left'
            end
        end
    elseif is_right_pressed then
        if keyHeld ~= 'right' then
            keyHeld = 'right'
            scrollTimer = initialScrollDelay
            moved = true
            moveDir = 'right'
        else
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
                moveDir = 'right'
            end
        end
    else
        keyHeld = nil
        fastScrollTimer = 0
    end

    if fastScrollTimer > 2 then
        if files[selectedIndex] then
            local name = files[selectedIndex].name
            if name and name ~= "" then 
                local l = name:sub(1,1):upper()
                if l ~= jumpLetter then
                    jumpLetter = l
                end
            end
        end
        jumpPanelAnim = math.min(1, jumpPanelAnim + dt * 6)
    else
        jumpPanelAnim = math.max(0, jumpPanelAnim - dt * 6)
        if jumpPanelAnim == 0 then
            jumpLetter = ""
        end
    end

    if moved then
        if state == "LIST" then
            if moveDir == 'down' then
                if fastScrollTimer > 2 then
                    jumpToNextLetter()
                elseif viewMode == "GRID" then
                    if selectedIndex + gridCols <= #files then
                        selectedIndex = selectedIndex + gridCols
                    end
                else
                    selectedIndex = math.min(#files, selectedIndex + 1)
                end
            elseif moveDir == 'up' then
                if fastScrollTimer > 2 then
                    jumpToPrevLetter()
                elseif viewMode == "GRID" then
                    if selectedIndex > gridCols then
                        selectedIndex = selectedIndex - gridCols
                    end
                else
                    selectedIndex = math.max(1, selectedIndex - 1)
                end
            elseif moveDir == 'left' then
                if viewMode == "GRID" then
                    selectedIndex = math.max(1, selectedIndex - 1)
                else
                    selectedIndex = math.max(1, selectedIndex - pageSize)
                end
            elseif moveDir == 'right' then
                if viewMode == "GRID" then
                    selectedIndex = math.min(#files, selectedIndex + 1)
                else
                    selectedIndex = math.min(#files, selectedIndex + pageSize)
                end
            end
            
            if selectedIndex ~= oldSelectedIndex then -- Only update target scroll if selection changed
                if viewMode == "LIST" then
                    -- Calculate target scroll for list view
                    State.scrollTo = (selectedIndex - 1) * layout.rowHeight
                elseif viewMode == "GRID" then
                    -- Calculate target scroll for grid view (more complex, for later)
                    local currentRow = math.ceil(selectedIndex / gridCols)
                    State.scrollTo = (currentRow - 1) * layout.rowHeight -- Assuming layout.rowHeight is also cellH for grid
                end
            end
            loadPreview()
        elseif state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" then
            if moveDir == 'down' then
                menuSelection = menuSelection + 1
                if menuSelection > #menuOptions then menuSelection = 1 end
            elseif moveDir == 'up' then
                menuSelection = menuSelection - 1
                if menuSelection < 1 then menuSelection = #menuOptions end
            end
        elseif state == "SAVE_MANAGER" then
            if moveDir == 'down' then
                saveManagerSelection = saveManagerSelection + 1
                if saveManagerSelection > #saveFiles then saveManagerSelection = 1 end
            elseif moveDir == 'up' then
                saveManagerSelection = saveManagerSelection - 1
                if saveManagerSelection < 1 then saveManagerSelection = #saveFiles end
            end
        elseif state == "CLEANUP_MENU" and cleanupData.scanned and not cleanupData.confirming then
            local maxRows = 0
            if cleanupData.cursor.col == 1 then maxRows = #cleanupData.orphans + 1
            elseif cleanupData.cursor.col == 2 then maxRows = #cleanupData.duplicates
            elseif cleanupData.cursor.col == 3 then maxRows = #cleanupData.orphanedImages end
            
            if maxRows > 0 then
                if moveDir == 'down' then
                    cleanupData.cursor.row = cleanupData.cursor.row + 1
                    if cleanupData.cursor.row > maxRows then cleanupData.cursor.row = 1 end
                elseif moveData.cursor.row < 1 then cleanupData.cursor.row = maxRows end
                end
            end
        end
    end

    -- Smooth scroll interpolation
    if State.scroll ~= State.scrollTo then
        State.scroll = State.scroll + (State.scrollTo - State.scroll) * scrollSpeed * dt
        -- Snap to target if very close to avoid endless small movements
        if math.abs(State.scrollTo - State.scroll) < 1 then
            State.scroll = State.scrollTo
        end
    end
end

return update