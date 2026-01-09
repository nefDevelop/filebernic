local function update(dt)
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
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

    if state ~= "LIST" then return end

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = love.keyboard.isDown('down') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = love.keyboard.isDown('up') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))

    local moved = false
    if is_down_pressed then
        if keyHeld ~= 'down' then
            -- Primera pulsación
            selectedIndex = math.min(#files, selectedIndex + 1)
            keyHeld = 'down'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                selectedIndex = math.min(#files, selectedIndex + 1)
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    elseif is_up_pressed then
        if keyHeld ~= 'up' then
            -- Primera pulsación
            selectedIndex = math.max(1, selectedIndex - 1)
            keyHeld = 'up'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                selectedIndex = math.max(1, selectedIndex - 1)
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    else
        keyHeld = nil
    end

    if moved then
        pendingLoad = true
        timer = 0
    end
end

return update