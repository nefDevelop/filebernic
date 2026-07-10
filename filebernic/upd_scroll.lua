---@diagnostic disable: undefined-global
local M = {}
local input = require "input"

function M.getKeys(gs)
    local is_down = gs.love.keyboard.isDown('down') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up = gs.love.keyboard.isDown('up') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))
    local is_left = gs.love.keyboard.isDown('left') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('dpleft'))
    local is_right = gs.love.keyboard.isDown('right') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('dpright'))
    local is_pageup = gs.love.keyboard.isDown('pageup') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('leftshoulder'))
    local is_pagedown = gs.love.keyboard.isDown('pagedown') or
        (gs.love.joystick.getJoystickCount() > 0 and gs.love.joystick.getJoysticks()[1]:isGamepadDown('rightshoulder'))
    return is_down, is_up, is_left, is_right, is_pageup, is_pagedown
end

function M.updateScroll(dt, gs, log_func, loader_obj)
    local is_down_pressed, is_up_pressed, is_left_pressed, is_right_pressed, is_pageup, is_pagedown = M.getKeys(gs)

    local moved = false
    local moveDir = nil

    if is_pageup then
        if gs.keyHeld ~= 'pageup' then
            gs.keyHeld = 'pageup'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; moveDir = 'pageup'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.subsequentScrollDelay
                moved = true; moveDir = 'pageup'
            end
        end
    elseif is_pagedown then
        if gs.keyHeld ~= 'pagedown' then
            gs.keyHeld = 'pagedown'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; moveDir = 'pagedown'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.subsequentScrollDelay
                moved = true; moveDir = 'pagedown'
            end
        end
    elseif is_down_pressed then
        if gs.keyHeld ~= 'down' then
            gs.keyHeld = 'down'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; gs.fastScrollTimer = 0; moveDir = 'down'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            gs.fastScrollTimer = gs.fastScrollTimer + dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.fastScrollTimer > 2 and 0.5 or gs.subsequentScrollDelay
                moved = true; moveDir = 'down'
            end
        end
    elseif is_up_pressed then
        if gs.keyHeld ~= 'up' then
            gs.keyHeld = 'up'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; gs.fastScrollTimer = 0; moveDir = 'up'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            gs.fastScrollTimer = gs.fastScrollTimer + dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.fastScrollTimer > 2 and 0.5 or gs.subsequentScrollDelay
                moved = true; moveDir = 'up'
            end
        end
    elseif is_left_pressed then
        if gs.keyHeld ~= 'left' then
            gs.keyHeld = 'left'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; moveDir = 'left'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.subsequentScrollDelay
                moved = true; moveDir = 'left'
            end
        end
    elseif is_right_pressed then
        if gs.keyHeld ~= 'right' then
            gs.keyHeld = 'right'
            gs.scrollTimer = gs.initialScrollDelay
            moved = true; moveDir = 'right'
        else
            gs.scrollTimer = gs.scrollTimer - dt
            if gs.scrollTimer <= 0 then
                gs.scrollTimer = gs.subsequentScrollDelay
                moved = true; moveDir = 'right'
            end
        end
    else
        gs.keyHeld = nil
        gs.fastScrollTimer = 0
    end

    if not moved then return end

    if gs.state == "LIST" then
        if moveDir == 'pageup' then
            gs.selectedIndex = math.max(1, gs.selectedIndex - gs.pageSize)
        elseif moveDir == 'pagedown' then
            gs.selectedIndex = math.min(#gs.files, gs.selectedIndex + gs.pageSize)
        elseif moveDir == 'down' then
            if gs.fastScrollTimer > 2 then
                input.jumpToNextLetter(gs)
            elseif gs.viewMode == "GRID" then
                if gs.selectedIndex + gs.gridCols <= #gs.files then
                    gs.selectedIndex = gs.selectedIndex + gs.gridCols
                elseif gs.selectedIndex < #gs.files then
                    gs.selectedIndex = #gs.files
                end
            else
                if gs.selectedIndex == #gs.files then return end
                gs.selectedIndex = math.min(#gs.files, gs.selectedIndex + 1)
            end
        elseif moveDir == 'up' then
            if gs.fastScrollTimer > 2 then
                input.jumpToPrevLetter(gs)
            elseif gs.viewMode == "GRID" then
                if gs.selectedIndex > gs.gridCols then
                    gs.selectedIndex = gs.selectedIndex - gs.gridCols
                elseif gs.selectedIndex > 1 then
                    gs.selectedIndex = 1
                end
            else
                if gs.selectedIndex == 1 then return end
                gs.selectedIndex = math.max(1, gs.selectedIndex - 1)
            end
        elseif moveDir == 'left' then
            if gs.viewMode == "GRID" then
                gs.selectedIndex = math.max(1, gs.selectedIndex - 1)
            else
                gs.selectedIndex = math.max(1, gs.selectedIndex - gs.pageSize)
            end
        elseif moveDir == 'right' then
            if gs.viewMode == "GRID" then
                gs.selectedIndex = math.min(#gs.files, gs.selectedIndex + 1)
            else
                gs.selectedIndex = math.min(#gs.files, gs.selectedIndex + gs.pageSize)
            end
        end
        gs.preview.load(gs, log_func, loader_obj)
    elseif gs.state == "OPTIONS_MENU" or gs.state == "DELETE_MENU" or gs.state == "SCRAPER_OPTIONS" then
        if moveDir == 'down' then
            gs.menuSelection = gs.menuSelection + 1
            if gs.menuSelection > #gs.menuOptions then gs.menuSelection = 1 end
        elseif moveDir == 'up' then
            gs.menuSelection = gs.menuSelection - 1
            if gs.menuSelection < 1 then gs.menuSelection = #gs.menuOptions end
        end
    elseif gs.state == "SAVE_MANAGER" then
        if moveDir == 'down' then
            gs.saveManagerSelection = gs.saveManagerSelection + 1
            if gs.saveManagerSelection > #gs.saveFiles then gs.saveManagerSelection = 1 end
        elseif moveDir == 'up' then
            gs.saveManagerSelection = gs.saveManagerSelection - 1
            if gs.saveManagerSelection < 1 then gs.saveManagerSelection = #gs.saveFiles end
        end
    elseif gs.state == "CLEANUP_MENU" and gs.cleanupData.scanned and not gs.cleanupData.confirming then
        local maxRows = 0
        if gs.cleanupData.cursor.col == 1 then maxRows = #gs.cleanupData.orphans + 1
        elseif gs.cleanupData.cursor.col == 2 then maxRows = #gs.cleanupData.duplicates
        elseif gs.cleanupData.cursor.col == 3 then maxRows = #gs.cleanupData.orphanedImages end
        if maxRows > 0 then
            if moveDir == 'down' then
                gs.cleanupData.cursor.row = gs.cleanupData.cursor.row + 1
                if gs.cleanupData.cursor.row > maxRows then gs.cleanupData.cursor.row = 1 end
            elseif moveDir == 'up' then
                gs.cleanupData.cursor.row = gs.cleanupData.cursor.row - 1
                if gs.cleanupData.cursor.row < 1 then gs.cleanupData.cursor.row = maxRows end
            end
        end
    end
end

return M
