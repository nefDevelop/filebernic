local function update(dt)
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
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
            local ok, err = coroutine.resume(indexCoroutine)
            if not ok then
                log("Index Coroutine Error: " .. tostring(err))
                isIndexing = false
            end
        elseif status == "dead" then
            indexCoroutine = nil
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

    if pendingLoad then
        timer = timer + dt
        if timer >= delay then
            loadPreview()
            pendingLoad = false
            timer = 0
        end
    end

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
            pendingLoad = true
            timer = 0
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
                elseif moveDir == 'up' then
                    cleanupData.cursor.row = cleanupData.cursor.row - 1
                    if cleanupData.cursor.row < 1 then cleanupData.cursor.row = maxRows end
                end
            end
        end
    end
end

return update