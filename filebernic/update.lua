---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local input = require "input"
local filesystem = require "filesystem"
local utils = require "utils"
local unpack = table.unpack or unpack
local Loader = require "loader"
local preview = require "preview"
local State = require "state"
local json = require "libs.dkjson"

-- Fallback lerp function if love.math.lerp is not available (e.g., older LÖVE versions)
local lerp = love.math.lerp or function(a, b, t)
    return a + (b - a) * t
end

local function update(dt)

    loader:update()
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
    -- Lógica para actualizar las variables de previsualización de forma asíncrona
    -- Use previewItem as the source of truth for what to display
    local item = previewItem

    if not item then
        -- If there's no specific preview item, we're in a directory or empty list.
        -- The fade out logic below will handle clearing the images.
        if #files == 0 then
            currentImage = nil
            currentScreenshot = nil
            currentYear = nil
            currentDescription = ""
            currentSystemIcon = nil
            currentSystemContentIcon = nil
        end
    end

    if item and not item.isDir then
        local baseName = item.name:gsub("%..-$", "")
        local itemSystemName = utils.getSystemNameForItem(item, nil, isVirtualRoot)
        
        if itemSystemName then
            local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
            if artPathForSystem then
                local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
                local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

                -- Actualizar currentImage (Boxart)
                local imgFile = artPathForSystem .. baseName .. ".png"
                local loadedImage = loader:getImage(imgFile)
                if loadedImage then
                    if currentImage ~= loadedImage then
                        currentImage = loadedImage
                        currentImageAlpha = 0
                    end
                    imageInvalid = false
                end

                -- Actualizar currentScreenshot
                local scrFile = previewPathForSystem .. baseName .. ".png"
                local loadedScreenshot = loader:getImage(scrFile)
                if loadedScreenshot then
                    if currentScreenshot ~= loadedScreenshot then
                        currentScreenshot = loadedScreenshot
                        currentScreenshotAlpha = 0
                    end
                    screenshotInvalid = false
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
    end

    if imageInvalid then
        currentImageAlpha = math.max(0, currentImageAlpha - dt * 5)
        if currentImageAlpha == 0 then currentImage = nil end
    elseif currentImage then
        currentImageAlpha = math.min(1, currentImageAlpha + dt * 5)
    end

    if screenshotInvalid then
        currentScreenshotAlpha = math.max(0, currentScreenshotAlpha - dt * 5)
        if currentScreenshotAlpha == 0 then currentScreenshot = nil end
    elseif currentScreenshot then
        currentScreenshotAlpha = math.min(1, currentScreenshotAlpha + dt * 5)
    end

    if (state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" or state == "INFO_VIEW") and not closingMenu then
        menuAnim = math.min(1, menuAnim + dt * 6)
    else
        menuAnim = math.max(0, menuAnim - dt * 6)
    end

    if showHelp then
        helpAnim = math.min(1, helpAnim + dt * 6)
    else
        helpAnim = math.max(0, helpAnim - dt * 6)
    end

    if state == "SEARCH" then
        keyboardAnim = math.min(1, keyboardAnim + dt * 6)
    else
        keyboardAnim = math.max(0, keyboardAnim - dt * 6)
    end

    if menuAnim == 0 and closingMenu then
        -- Animation finished.
        if #menuStack > 0 and (state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS") then
            -- This was a submenu closing. Pop it from the stack.
            local parent = table.remove(menuStack)
            menuTitle = parent.title
            menuMessage = parent.message
            menuOptions = parent.options
            menuSelection = parent.selection
            focusedItem = parent.focusedItem
            log("Popped submenu. Parent is now: " .. menuTitle)
            menuAnim = 1 -- Set to final state to prevent re-animation of parent.
        else
            -- Root menu closed
            if state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "INFO_VIEW" then
                state = "LIST"
                focusedItem = nil
                preview.load()
            elseif state == "SCRAPER_OPTIONS" then
                state = "SCRAPER_VIEW"
            end
        end
        closingMenu = false
    elseif menuAnim == 0 then
        closingMenu = false
    end
    if helpAnim == 0 then
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

    -- Comprobar errores fatales en el hilo de indexado
    if indexerThread then
        local err = indexerThread:getError()
        if err then
            log("THREAD ERROR (Indexer): " .. err)
        end
    end

    if indexerChannelOut then
        while true do
            local msg = indexerChannelOut:pop()
            if not msg then break end
            
            if msg.type == "progress" then
                indexStateMessage = msg.message
            elseif msg.type == "done" then
                log("Indexing finished successfully.")
                updateFileList(msg.index)
                isIndexing = false
                indexStateMessage = ""
            elseif msg.type == "log" then
                log(msg.message)
            elseif msg.type == "scrape_result" then
                -- Cargar imágenes en el hilo principal
                scraperResults = msg.results
                for _, res in ipairs(scraperResults) do
                    if res.imagePath then
                        local f = io.open(res.imagePath, "rb")
                        if f then
                            local data = f:read("*a")
                            f:close()
                            if data then
                                local success, img = pcall(love.graphics.newImage, love.filesystem.newFileData(data, "temp.png"))
                                if success then res.image = img end
                            end
                        end
                    end
                    if res.screenshotPath then
                        local f = io.open(res.screenshotPath, "rb")
                        if f then
                            local data = f:read("*a")
                            f:close()
                            if data then
                                local success, img = pcall(love.graphics.newImage, love.filesystem.newFileData(data, "temp_scr.png"))
                                if success then res.screenshot = img end
                            end
                        end
                    end
                end
                scraperSelection = 1
                state = "SCRAPER_RESULTS"
            elseif msg.type == "batch_progress" then
                scraperProgress.current = msg.current
                scraperProgress.total = msg.total
                scraperProgress.currentName = msg.currentName
                scraperProgress.successes = msg.successes
                scraperProgress.failures = msg.failures
            elseif msg.type == "batch_done" then
                log("Batch scraping finished. Successes: " .. msg.successes .. " Failures: " .. msg.failures)
                state = "LIST"
                refreshFiles()
            end
        end
    end


    if launching then
        launchTimer = launchTimer + dt
        if launchTimer > 0.1 then -- Pequeña espera para ver el color verde
            log("Executing launch sequence for: " .. tostring(lastPlayedRom))
            local f, err = io.open("/tmp/launch_rom", "w")
            if f then 
                f:write(lastPlayedRom) 
                f:close() 
            else
                log("FATAL: Failed to write launch file: " .. tostring(err))
            end
            State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
            filesystem.saveViewCache(files, romPath, selectedIndex, isVirtualRoot, json.encode, love.filesystem.getSource, io.open)
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

    -- Animación suave del cursor
    animatedSelectionIndex = lerp(animatedSelectionIndex, selectedIndex, dt * selectionAnimationSpeed)
    animatedSelectionIndex = math.max(1, math.min(#files, animatedSelectionIndex))

    if moved then
        if state == "LIST" then
            if moveDir == 'down' then
                if fastScrollTimer > 2 then
                    input.jumpToNextLetter()
                elseif viewMode == "GRID" then
                    if selectedIndex + gridCols <= #files then -- Normal jump
                        selectedIndex = selectedIndex + gridCols
                    elseif selectedIndex < #files then -- If not enough items for a full jump, go to the last item
                        selectedIndex = #files
                    end
                else
                    -- If at the end of the list, don't increment selectedIndex
                    if selectedIndex == #files then return end
                    selectedIndex = math.min(#files, selectedIndex + 1)
                end
            elseif moveDir == 'up' then
                if fastScrollTimer > 2 then
                    input.jumpToPrevLetter()
                elseif viewMode == "GRID" then
                    if selectedIndex > gridCols then
                        selectedIndex = selectedIndex - gridCols -- Normal jump
                    elseif selectedIndex > 1 then -- If not enough items for a full jump, go to the first item
                        selectedIndex = 1
                    end
                else
                    -- If at the beginning of the list, don't decrement selectedIndex
                    if selectedIndex == 1 then return end
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
            -- Cuando cambia la selección, limpiamos las vistas previas y solicitamos nuevas
            -- Esto ya lo maneja loadPreview() y el loader.
            preview.load()
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