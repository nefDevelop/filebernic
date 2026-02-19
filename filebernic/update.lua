---@diagnostic disable: undefined-global
local input = require "input"

local filesystem = require "filesystem"
local utils = require "utils"
local json = require "libs.dkjson"

-- Fallback lerp function if love.math.lerp is not available
local lerp_fallback = function(a, b, t)
    return a + (b - a) * t
end

local function update(dt, global_state, log_func, loader_obj, updateFileList_func)

    -- Access global state variables via the passed global_state table
    local inputCooldown = global_state.inputCooldown
    local previewItem = global_state.previewItem

    loader_obj:update()
    -- Favorite animation
    if global_state.favAnim ~= global_state.favAnimTarget then
        local speed = 7 -- Animation speed for the star
        if global_state.favAnim < global_state.favAnimTarget then
            global_state.favAnim = math.min(global_state.favAnimTarget, global_state.favAnim + dt * speed)
        else
            global_state.favAnim = math.max(global_state.favAnimTarget, global_state.favAnim - dt * speed)
        end
    end

    if inputCooldown > 0 then global_state.inputCooldown = inputCooldown - dt end
    
    -- Lógica para actualizar las variables de previsualización de forma asíncrona
    -- Use previewItem as the source of truth for what to display
    local item = previewItem

    if not item then
        -- If there's no specific preview item, we're in a directory or empty list.
        -- The fade out logic below will handle clearing the images. (global_state.files)
        if #global_state.files == 0 then
            global_state.currentImage = nil
            global_state.currentScreenshot = nil
            global_state.currentYear = nil
            global_state.currentDescription = ""
            global_state.currentSystemIcon = nil
            global_state.currentSystemContentIcon = nil
        end
    end

    if item and not item.isDir then -- Only process if it's a file
        local baseName = item.name:gsub("%..-$", "")
        local itemSystemName = utils.getSystemNameForItem(item, nil, global_state.isVirtualRoot)
        
        if itemSystemName then
            local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
            if artPathForSystem then
                local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
                local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

                -- Actualizar currentImage (Boxart)
                local imgFile = artPathForSystem .. baseName .. ".png" -- Construct image file path
                local loadedImage = loader_obj:getImage(imgFile) -- Get image from loader
                if loadedImage then
                    if global_state.currentImage ~= loadedImage then
                        global_state.currentImage = loadedImage
                        global_state.currentImageAlpha = 0
                    end
                    global_state.imageInvalid = false
                end

                -- Actualizar currentScreenshot
                local scrFile = previewPathForSystem .. baseName .. ".png" -- Construct screenshot file path
                local loadedScreenshot = loader_obj:getImage(scrFile) -- Get screenshot from loader
                if loadedScreenshot then
                    if global_state.currentScreenshot ~= loadedScreenshot then
                        global_state.currentScreenshot = loadedScreenshot
                        global_state.currentScreenshotAlpha = 0
                    end
                    global_state.screenshotInvalid = false
                end

                -- Actualizar currentDescription
                local txtFile = textPathForSystem .. baseName .. ".txt" -- Construct text file path
                local loadedDescription = loader_obj:getText(txtFile) -- Get text from loader
                if loadedDescription then
                    global_state.currentDescription = loadedDescription
                end

                -- Actualizar currentYear
                local yearFile = textPathForSystem .. baseName .. ".year" -- Construct year file path
                local loadedYear = loader_obj:getText(yearFile) -- Get year from loader
                if loadedYear then
                    global_state.currentYear = loadedYear
                end
            end
        end
    end

    if global_state.imageInvalid then
        global_state.currentImageAlpha = math.max(0, global_state.currentImageAlpha - dt * 5)
        if global_state.currentImageAlpha == 0 then global_state.currentImage = nil end
    elseif global_state.currentImage then
        global_state.currentImageAlpha = math.min(1, global_state.currentImageAlpha + dt * 5)
    end

    if global_state.screenshotInvalid then
        global_state.currentScreenshotAlpha = math.max(0, global_state.currentScreenshotAlpha - dt * 5)
        if global_state.currentScreenshotAlpha == 0 then global_state.currentScreenshot = nil end
    elseif global_state.currentScreenshot then
        global_state.currentScreenshotAlpha = math.min(1, global_state.currentScreenshotAlpha + dt * 5)
    end

    if (global_state.state == "OPTIONS_MENU" or global_state.state == "DELETE_MENU" or
        global_state.state == "SCRAPER_OPTIONS" or global_state.state == "INFO_VIEW") and
        not global_state.closingMenu then
        global_state.menuAnim = math.min(1, global_state.menuAnim + dt * 6)
    else
        global_state.menuAnim = math.max(0, global_state.menuAnim - dt * 6)
    end

    if global_state.showHelp then
        global_state.helpAnim = math.min(1, global_state.helpAnim + dt * 6)
    else
        global_state.helpAnim = math.max(0, global_state.helpAnim - dt * 6)
    end

    if global_state.state == "SEARCH" then
        global_state.keyboardAnim = math.min(1, global_state.keyboardAnim + dt * 6)
    else
        global_state.keyboardAnim = math.max(0, global_state.keyboardAnim - dt * 6)
    end

    if global_state.menuAnim == 0 and global_state.closingMenu then
        -- Animation finished.
        if #global_state.menuStack > 0 and (global_state.state == "OPTIONS_MENU" or
                                            global_state.state == "DELETE_MENU" or
                                            global_state.state == "SCRAPER_OPTIONS") then
            -- This was a submenu closing. Pop it from the stack.
            local parent = table.remove(global_state.menuStack)
            global_state.menuTitle = parent.title
            global_state.menuMessage = parent.message
            global_state.menuOptions = parent.options
            global_state.menuSelection = parent.selection
            global_state.focusedItem = parent.focusedItem
            log_func("Popped submenu. Parent is now: " .. global_state.menuTitle)
            global_state.menuAnim = 1 -- Set to final state to prevent re-animation of parent.
        else
            -- Root menu closed
            if global_state.state == "OPTIONS_MENU" or global_state.state == "DELETE_MENU" or
                global_state.state == "INFO_VIEW" then
                global_state.state = "LIST"
                global_state.focusedItem = nil
                global_state.preview.load(global_state, log_func, loader_obj)
            elseif global_state.state == "SCRAPER_OPTIONS" then
                global_state.state = "SCRAPER_VIEW"
            end
        end
        global_state.closingMenu = false
    elseif global_state.menuAnim == 0 then
        global_state.closingMenu = false
    end
    if global_state.helpAnim == 0 then
        global_state.closingHelp = false
    end

    if global_state.cleanupData.scanning and global_state.cleanupCoroutine then
        local status = coroutine.status(global_state.cleanupCoroutine)
        if status == "suspended" then
            local ok = coroutine.resume(global_state.cleanupCoroutine)
            if not ok then
                global_state.cleanupData.scanning = false
            end
        elseif status == "dead" then
            global_state.cleanupCoroutine = nil
        end
    end

    -- Check for fatal errors in the indexer thread
    if global_state.indexerThread then
        local err = global_state.indexerThread:getError()
        if err then
            log_func("THREAD ERROR (Indexer): " .. err)
        end
    end

    if global_state.indexerChannelOut then
        while true do
            local msg = global_state.indexerChannelOut:pop()
            if not msg then break end
            
            if msg.type == "progress" then
                global_state.indexStateMessage = msg.message
            elseif msg.type == "done" then
                log_func("Indexing finished successfully.")
                updateFileList_func(msg.index)
                global_state.isIndexing = false
                global_state.indexStateMessage = ""
            elseif msg.type == "log" then
                log_func(msg.message)
            elseif msg.type == "scrape_result" then
                -- Cargar imágenes en el hilo principal
                global_state.scraperResults = msg.results
                for _, res in ipairs(global_state.scraperResults) do
                    if res.imagePath then
                        local f = io.open(res.imagePath, "rb")
                        if f then
                            local data = f:read("*a")
                            f:close()
                            if data then
                                local success, img = pcall(global_state.love.graphics.newImage,
                                                           global_state.love.filesystem.newFileData(data, "temp.png"))
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
                                local success, img = pcall(global_state.love.graphics.newImage,
                                                           global_state.love.filesystem.newFileData(data, "temp_scr.png"))
                                if success then res.screenshot = img end
                            end
                        end
                    end
                end
                global_state.scraperSelection = 1
                global_state.state = "SCRAPER_RESULTS"
            elseif msg.type == "batch_progress" then
                global_state.scraperProgress.current = msg.current
                global_state.scraperProgress.total = msg.total
                global_state.scraperProgress.currentName = msg.currentName
                global_state.scraperProgress.successes = msg.successes
                global_state.scraperProgress.failures = msg.failures
            elseif msg.type == "batch_done" then
                log_func("Batch scraping finished. Successes: " .. msg.successes ..
                         " Failures: " .. msg.failures)
                global_state.state = "LIST"
                global_state.refreshFiles() -- Assuming refreshFiles is a global function
            end
        end
    end

    if global_state.launching then
        global_state.launchTimer = global_state.launchTimer + dt
        if global_state.launchTimer > 0.1 then -- Small wait to see the green color
            log_func("Executing launch sequence for: " .. tostring(global_state.lastPlayedRom))
            local f, err = io.open("/tmp/launch_rom", "w")
            if f then 
                f:write(global_state.lastPlayedRom)
                f:close() 
            else
                log_func("FATAL: Failed to write launch file: " .. tostring(err))
            end
            global_state.State.saveAppState(global_state.romPath, global_state.selectedIndex,
                                            global_state.hideEmpty, global_state.markPlayed,
                                            global_state.viewMode, global_state.launchMode,
                                            global_state.hideFavorites, global_state.love.filesystem)
            global_state.filesystem.saveViewCache(global_state.files, global_state.romPath,
                                                  global_state.selectedIndex, global_state.isVirtualRoot,
                                                  json.encode, global_state.love.filesystem.getSource, io.open)
            global_state.love.event.quit()
            os.exit(0)
        end
        return
    end

    -- Remover lógica de pendingLoad y timer

    if showHelp then return end

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = global_state.love.keyboard.isDown('down') or
                            (global_state.love.joystick.getJoystickCount() > 0 and
                             global_state.love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = global_state.love.keyboard.isDown('up') or
                          (global_state.love.joystick.getJoystickCount() > 0 and
                           global_state.love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))
    local is_left_pressed = global_state.love.keyboard.isDown('left') or
                            (global_state.love.joystick.getJoystickCount() > 0 and
                             global_state.love.joystick.getJoysticks()[1]:isGamepadDown('dpleft'))
    local is_right_pressed = global_state.love.keyboard.isDown('right') or
                             (global_state.love.joystick.getJoystickCount() > 0 and
                              global_state.love.joystick.getJoysticks()[1]:isGamepadDown('dpright'))

    local moved = false
    local moveDir = nil

    if is_down_pressed then
        if global_state.keyHeld ~= 'down' then
            -- Primera pulsación
            global_state.keyHeld = 'down'
            global_state.scrollTimer = global_state.initialScrollDelay
            moved = true
            global_state.fastScrollTimer = 0
            moveDir = 'down'
        else
            -- Tecla mantenida
            global_state.scrollTimer = global_state.scrollTimer - dt
            global_state.fastScrollTimer = global_state.fastScrollTimer + dt
            if global_state.scrollTimer <= 0 then
                if global_state.fastScrollTimer > 2 then
                    global_state.scrollTimer = 0.5 -- Letter jump speed
                else
                    global_state.scrollTimer = global_state.subsequentScrollDelay
                end
                moved = true
                moveDir = 'down'
            end
        end
    elseif is_up_pressed then
        if global_state.keyHeld ~= 'up' then
            -- Primera pulsación
            global_state.keyHeld = 'up'
            global_state.scrollTimer = global_state.initialScrollDelay
            moved = true
            global_state.fastScrollTimer = 0
            moveDir = 'up'
        else
            -- Tecla mantenida
            global_state.scrollTimer = global_state.scrollTimer - dt
            global_state.fastScrollTimer = global_state.fastScrollTimer + dt
            if global_state.scrollTimer <= 0 then
                if global_state.fastScrollTimer > 2 then
                    global_state.scrollTimer = 0.5 -- Letter jump speed
                else
                    global_state.scrollTimer = global_state.subsequentScrollDelay
                end
                moved = true
                moveDir = 'up'
            end
        end
    elseif is_left_pressed then
        if global_state.keyHeld ~= 'left' then
            global_state.keyHeld = 'left'
            global_state.scrollTimer = global_state.initialScrollDelay
            moved = true
            moveDir = 'left'
        else
            global_state.scrollTimer = global_state.scrollTimer - dt
            if global_state.scrollTimer <= 0 then
                global_state.scrollTimer = global_state.subsequentScrollDelay
                moved = true
                moveDir = 'left'
            end
        end
    elseif is_right_pressed then
        if global_state.keyHeld ~= 'right' then
            global_state.keyHeld = 'right'
            global_state.scrollTimer = global_state.initialScrollDelay
            moved = true
            moveDir = 'right'
        else
            global_state.scrollTimer = global_state.scrollTimer - dt
            if global_state.scrollTimer <= 0 then
                global_state.scrollTimer = global_state.subsequentScrollDelay
                moved = true
                moveDir = 'right'
            end
        end
    else
        global_state.keyHeld = nil
        global_state.fastScrollTimer = 0
    end

    if global_state.fastScrollTimer > 2 then
        if global_state.files[global_state.selectedIndex] then
            local name = global_state.files[global_state.selectedIndex].name
            if name and name ~= "" then 
                local l = name:sub(1,1):upper()
                if l ~= global_state.jumpLetter then
                    global_state.jumpLetter = l
                end
            end
        end
        global_state.jumpPanelAnim = math.min(1, global_state.jumpPanelAnim + dt * 6)
    else
        global_state.jumpPanelAnim = math.max(0, global_state.jumpPanelAnim - dt * 6)
        if global_state.jumpPanelAnim == 0 then
            global_state.jumpLetter = ""
        end
    end

    -- Smooth cursor animation
    local lerp = global_state.love.math.lerp or lerp_fallback
    global_state.animatedSelectionIndex = lerp(global_state.animatedSelectionIndex,
                                                                      global_state.selectedIndex,
                                                                      dt * global_state.selectionAnimationSpeed)
    global_state.animatedSelectionIndex = math.max(1, math.min(#global_state.files,
                                                               global_state.animatedSelectionIndex)) -- Line too long

    if moved then
        if global_state.state == "LIST" then
            if moveDir == 'down' then
                if global_state.fastScrollTimer > 2 then
                    input.jumpToNextLetter(global_state)
                elseif global_state.viewMode == "GRID" then
                    if global_state.selectedIndex + global_state.gridCols <= #global_state.files then -- Normal jump
                        global_state.selectedIndex = global_state.selectedIndex + global_state.gridCols
                    elseif global_state.selectedIndex < #global_state.files then
                        -- If not enough items for a full jump, go to the last item
                        global_state.selectedIndex = #global_state.files
                    end
                else
                    -- If at the end of the list, don't increment selectedIndex
                    if global_state.selectedIndex == #global_state.files then return end
                    global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + 1)
                end
            elseif moveDir == 'up' then
                if global_state.fastScrollTimer > 2 then
                    input.jumpToPrevLetter(global_state)
                elseif global_state.viewMode == "GRID" then
                    if global_state.selectedIndex > global_state.gridCols then
                        global_state.selectedIndex = global_state.selectedIndex - global_state.gridCols -- Normal jump
                    elseif global_state.selectedIndex > 1 then
                        -- If not enough items for a full jump, go to the first item
                        global_state.selectedIndex = 1
                    end
                else
                    -- If at the beginning of the list, don't decrement selectedIndex
                    if global_state.selectedIndex == 1 then return end
                    global_state.selectedIndex = math.max(1, global_state.selectedIndex - 1)
                end
            elseif moveDir == 'left' then
                if global_state.viewMode == "GRID" then
                    global_state.selectedIndex = math.max(1, global_state.selectedIndex - 1)
                else
                    global_state.selectedIndex = math.max(1, global_state.selectedIndex - global_state.pageSize)
                end
            elseif moveDir == 'right' then
                if global_state.viewMode == "GRID" then
                    global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + 1)
                else
                    global_state.selectedIndex = math.min(#global_state.files,
                                                          global_state.selectedIndex + global_state.pageSize)
                end
            end
            -- When selection changes, clear previews and request new ones
            -- This is handled by preview.load() and the loader.
            global_state.preview.load(global_state, log_func, loader_obj)
        elseif global_state.state == "OPTIONS_MENU" or global_state.state == "DELETE_MENU" or
               global_state.state == "SCRAPER_OPTIONS" then
            if moveDir == 'down' then
                global_state.menuSelection = global_state.menuSelection + 1
                if global_state.menuSelection > #global_state.menuOptions then global_state.menuSelection = 1 end
            elseif moveDir == 'up' then
                global_state.menuSelection = global_state.menuSelection - 1
                if global_state.menuSelection < 1 then
                    global_state.menuSelection = #global_state.menuOptions
                end
            end
        elseif global_state.state == "SAVE_MANAGER" then
            if moveDir == 'down' then
                global_state.saveManagerSelection = global_state.saveManagerSelection + 1
                if global_state.saveManagerSelection > #global_state.saveFiles then
                    global_state.saveManagerSelection = 1
                end
            elseif moveDir == 'up' then
                global_state.saveManagerSelection = global_state.saveManagerSelection - 1
                if global_state.saveManagerSelection < 1 then
                    global_state.saveManagerSelection = #global_state.saveFiles
                end
            end
        elseif global_state.state == "CLEANUP_MENU" and global_state.cleanupData.scanned and
               not global_state.cleanupData.confirming then
            local maxRows = 0
            if global_state.cleanupData.cursor.col == 1 then
                maxRows = #global_state.cleanupData.orphans + 1
            elseif global_state.cleanupData.cursor.col == 2 then
                maxRows = #global_state.cleanupData.duplicates
            elseif global_state.cleanupData.cursor.col == 3 then
                maxRows = #global_state.cleanupData.orphanedImages
            end
            
            if maxRows > 0 then
                if moveDir == 'down' then
                    global_state.cleanupData.cursor.row = global_state.cleanupData.cursor.row + 1
                    if global_state.cleanupData.cursor.row > maxRows then
                        global_state.cleanupData.cursor.row = 1
                    end
                elseif moveDir == 'up' then
                    global_state.cleanupData.cursor.row = global_state.cleanupData.cursor.row - 1
                    if global_state.cleanupData.cursor.row < 1 then
                        global_state.cleanupData.cursor.row = maxRows
                    end
                end
            end
        end
    end
end

return update