---@diagnostic disable: undefined-global
local filesystem = require "filesystem"
local utils = require "utils"
local json = require "libs.dkjson"
local anim = require "upd_animations"
local scroll = require "upd_scroll"
local messages = require "upd_messages"

local function update(dt, global_state, log_func, loader_obj, updateFileList_func)
    if dt > 0.05 then
        log_func("Lag spike in update: " .. string.format("%.4f", dt) .. "s")
    end

    local inputCooldown = global_state.inputCooldown
    local previewItem = global_state.previewItem

    -- Periodic state save (cada 30s si hubo navegación)
    global_state._autoSaveTimer = (global_state._autoSaveTimer or 0) + dt
    if global_state._autoSaveTimer >= 30 and global_state.state == "LIST" then
        global_state._autoSaveTimer = 0
        global_state.State.saveAppState(global_state.romPath, global_state.selectedIndex,
            global_state.hideEmpty, global_state.markPlayed, global_state.viewMode,
            global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
    end

    loader_obj:update()

    -- Memory pressure monitor (cada ~1s)
    if global_state.layout.totalRamMB then
        global_state._memTimer = (global_state._memTimer or 0) + dt
        if global_state._memTimer >= 1 then
            global_state._memTimer = 0
            local memMB = collectgarbage("count") / 1024
            local threshold = global_state.layout.totalRamMB * 0.75
            if memMB > threshold then
                loader_obj:flushCache()
                log_func("Mem: " .. string.format("%.0f", memMB) .. "/" .. global_state.layout.totalRamMB .. "MB — cache flushed")
            end
        end
    end

    anim.updateFavAnim(dt, global_state)

    if inputCooldown > 0 then global_state.inputCooldown = inputCooldown - dt end

    if global_state.scraperWarningTimer > 0 then
        global_state.scraperWarningTimer = global_state.scraperWarningTimer - dt
        if global_state.scraperWarningTimer <= 0 then global_state.scraperWarningMessage = "" end
    end

    if global_state.undoData and global_state.undoData.timer > 0 then
        global_state.undoData.timer = global_state.undoData.timer - dt
        if global_state.undoData.timer <= 0 then global_state.undoData = nil end
    end

    -- Preview loading from async loader
    local item = previewItem
    if not item then
        if #global_state.files == 0 then
            global_state.currentImage = nil
            global_state.currentScreenshot = nil
            global_state.currentYear = nil
            global_state.currentDescription = ""
            global_state.currentSystemIcon = nil
            global_state.currentSystemContentIcon = nil
        end
    end

    if item and not item.isDir then
        local baseName = item.name:gsub("%.[^%.]+$", "")
        local itemSystemName = utils.getSystemNameForItem(item, nil, global_state.isVirtualRoot)
        if itemSystemName then
            local artPath = filesystem.getArtPathForSystem(itemSystemName)
            if artPath then
                local textPath = artPath:gsub("/box/", "/text/")
                local previewPath = artPath:gsub("/box/", "/preview/")

                local loadedImage = loader_obj:getImage(artPath .. baseName .. ".png")
                if loadedImage then
                    if global_state.currentImage ~= loadedImage then
                        global_state.currentImage = loadedImage
                        global_state.currentImageAlpha = 0
                    end
                    global_state.imageInvalid = false
                end

                local loadedScreenshot = loader_obj:getImage(previewPath .. baseName .. ".png")
                if loadedScreenshot then
                    if global_state.currentScreenshot ~= loadedScreenshot then
                        global_state.currentScreenshot = loadedScreenshot
                        global_state.currentScreenshotAlpha = 0
                    end
                    global_state.screenshotInvalid = false
                end

                local loadedDesc = loader_obj:getText(textPath .. baseName .. ".txt")
                if loadedDesc then global_state.currentDescription = loadedDesc end

                local loadedYear = loader_obj:getText(textPath .. baseName .. ".year")
                if loadedYear then global_state.currentYear = loadedYear end
            end
        end
    end

    anim.updateImageFade(dt, global_state)
    anim.updateMenuAnim(dt, global_state)
    anim.updateHelpAnim(dt, global_state)
    anim.updateKeyboardAnim(dt, global_state)
    anim.handleMenuClose(dt, global_state, log_func, loader_obj)

    -- Cleanup coroutine
    if global_state.cleanupData.scanning and global_state.cleanupCoroutine then
        local status = coroutine.status(global_state.cleanupCoroutine)
        if status == "suspended" then
            local ok = coroutine.resume(global_state.cleanupCoroutine)
            if not ok then global_state.cleanupData.scanning = false end
        elseif status == "dead" then
            global_state.cleanupCoroutine = nil
        end
    end

    -- Thread error check
    if global_state.indexerThread then
        local err = global_state.indexerThread:getError()
        if err then log_func("THREAD ERROR (Indexer): " .. err) end
    end

    messages.processMessages(global_state, log_func, updateFileList_func)

    -- Launch sequence
    if global_state.launching then
        global_state.launchTimer = global_state.launchTimer + dt
        if global_state.launchTimer > 0.1 then
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
        end
        return
    end

    if global_state.showHelp then return end

    scroll.updateScroll(dt, global_state, log_func, loader_obj)
    anim.updateJumpPanelAnim(dt, global_state)
    anim.updateCursorAnim(dt, global_state)
end

return update
