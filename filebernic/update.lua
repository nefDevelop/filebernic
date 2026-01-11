local function update(dt)
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
    if state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" then
        menuAnim = math.min(1, menuAnim + dt * 8)
    else
        menuAnim = 0
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

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = love.keyboard.isDown('down') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = love.keyboard.isDown('up') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))

    local moved = false
    if is_down_pressed then
        if keyHeld ~= 'down' then
            -- Primera pulsación
            keyHeld = 'down'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    elseif is_up_pressed then
        if keyHeld ~= 'up' then
            -- Primera pulsación
            keyHeld = 'up'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    else
        keyHeld = nil
    end

    if moved then
        if state == "LIST" then
            if is_down_pressed then
                selectedIndex = math.min(#files, selectedIndex + 1)
            else
                selectedIndex = math.max(1, selectedIndex - 1)
            end
            pendingLoad = true
            timer = 0
        elseif state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" then
            if is_down_pressed then
                menuSelection = menuSelection + 1
                if menuSelection > #menuOptions then menuSelection = 1 end
            else
                menuSelection = menuSelection - 1
                if menuSelection < 1 then menuSelection = #menuOptions end
            end
        elseif state == "SAVE_MANAGER" then
            if is_down_pressed then
                saveManagerSelection = saveManagerSelection + 1
                if saveManagerSelection > #saveFiles then saveManagerSelection = 1 end
            else
                saveManagerSelection = saveManagerSelection - 1
                if saveManagerSelection < 1 then saveManagerSelection = #saveFiles end
            end
        elseif state == "CLEANUP_MENU" and cleanupData.scanned and not cleanupData.confirming then
            local maxRows = 0
            if cleanupData.cursor.col == 1 then maxRows = #cleanupData.orphans + 1
            elseif cleanupData.cursor.col == 2 then maxRows = #cleanupData.duplicates
            elseif cleanupData.cursor.col == 3 then maxRows = #cleanupData.orphanedImages end
            
            if maxRows > 0 then
                if is_down_pressed then
                    cleanupData.cursor.row = cleanupData.cursor.row + 1
                    if cleanupData.cursor.row > maxRows then cleanupData.cursor.row = 1 end
                else
                    cleanupData.cursor.row = cleanupData.cursor.row - 1
                    if cleanupData.cursor.row < 1 then cleanupData.cursor.row = maxRows end
                end
            end
        end
    end
end

return update