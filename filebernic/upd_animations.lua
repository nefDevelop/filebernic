---@diagnostic disable: undefined-global
local M = {}

local lerp_fallback = function(a, b, t)
    return a + (b - a) * t
end

local function easeInOut(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - (-2 * t + 2) * (-2 * t + 2) / 2
end

function M.updateFavAnim(dt, gs)
    if gs.favAnim ~= gs.favAnimTarget then
        local speed = gs.layout.favAnimSpeed
        if math.abs(gs.favAnim - gs.favAnimTarget) < 0.01 then
            gs.favAnim = gs.favAnimTarget
        elseif gs.favAnim < gs.favAnimTarget then
            gs.favAnim = math.min(gs.favAnimTarget, gs.favAnim + dt * speed)
        else
            gs.favAnim = math.max(gs.favAnimTarget, gs.favAnim - dt * speed)
        end
    end
end

function M.updateImageFade(dt, gs)
    local speed = gs.layout.fadeAnimSpeed
    if gs.imageInvalid then
        if gs.currentImageAlpha > 0 then
            gs.currentImageAlpha = math.max(0, gs.currentImageAlpha - dt * speed)
            if gs.currentImageAlpha <= 0 then gs.currentImage = nil end
        end
    elseif gs.currentImage and gs.currentImageAlpha < 1 then
        gs._imgFadeT = (gs._imgFadeT or 0) + dt * speed
        gs.currentImageAlpha = easeInOut(math.min(1, gs._imgFadeT))
        if gs._imgFadeT >= 1 then gs._imgFadeT = nil end
    end

    if gs.screenshotInvalid then
        if gs.currentScreenshotAlpha > 0 then
            gs.currentScreenshotAlpha = math.max(0, gs.currentScreenshotAlpha - dt * speed)
            if gs.currentScreenshotAlpha <= 0 then gs.currentScreenshot = nil end
        end
    elseif gs.currentScreenshot and gs.currentScreenshotAlpha < 1 then
        gs._scrFadeT = (gs._scrFadeT or 0) + dt * speed
        gs.currentScreenshotAlpha = easeInOut(math.min(1, gs._scrFadeT))
        if gs._scrFadeT >= 1 then gs._scrFadeT = nil end
    end
end

function M.updateMenuAnim(dt, gs)
    local targetMenuAnim = ((gs.state == "OPTIONS_MENU" or gs.state == "DELETE_MENU" or
        gs.state == "SCRAPER_OPTIONS" or gs.state == "INFO_VIEW") and
        not gs.closingMenu) and 1 or 0

    if gs.menuAnim ~= targetMenuAnim then
        if math.abs(gs.menuAnim - targetMenuAnim) < 0.01 then
            gs.menuAnim = targetMenuAnim
        elseif gs.menuAnim < targetMenuAnim then
            gs.menuAnim = math.min(targetMenuAnim, gs.menuAnim + dt * gs.layout.menuAnimSpeed)
        else
            gs.menuAnim = math.max(targetMenuAnim, gs.menuAnim - dt * gs.layout.menuAnimSpeed)
        end
    end
end

function M.updateHelpAnim(dt, gs)
    local targetHelpAnim = gs.showHelp and 1 or 0
    if gs.helpAnim ~= targetHelpAnim then
        if math.abs(gs.helpAnim - targetHelpAnim) < 0.01 then
            gs.helpAnim = targetHelpAnim
        elseif gs.helpAnim < targetHelpAnim then
            gs.helpAnim = math.min(targetHelpAnim, gs.helpAnim + dt * gs.layout.helpAnimSpeed)
        else
            gs.helpAnim = math.max(targetHelpAnim, gs.helpAnim - dt * gs.layout.helpAnimSpeed)
        end
    end
end

function M.updateKeyboardAnim(dt, gs)
    if gs.state == "SEARCH" or gs.state == "EDIT_TEXT" then
        gs.keyboardAnim = math.min(1, gs.keyboardAnim + dt * gs.layout.keyboardAnimSpeed)
    else
        gs.keyboardAnim = math.max(0, gs.keyboardAnim - dt * gs.layout.keyboardAnimSpeed)
    end
end

function M.updateJumpPanelAnim(dt, gs)
    local threshold = gs.layout.jumpPanelThreshold or 0.75
    if gs.fastScrollTimer > threshold and gs.files[gs.selectedIndex] then
        local name = gs.files[gs.selectedIndex].name
        if name and name ~= "" then
            local l = name:sub(1,1):upper()
            if l ~= gs.jumpLetter then gs.jumpLetter = l end
        end
        gs.jumpPanelAnim = math.min(1, gs.jumpPanelAnim + dt * gs.layout.jumpPanelSpeed)
    else
        gs.jumpPanelAnim = math.max(0, gs.jumpPanelAnim - dt * gs.layout.jumpPanelSpeed)
        if gs.jumpPanelAnim == 0 then gs.jumpLetter = "" end
    end
end

function M.updateCursorAnim(dt, gs)
    local lerp = gs.love.math.lerp or lerp_fallback
    local speed = gs.layout.selectionSpeed
    if gs.viewMode == "GRID" then speed = gs.layout.gridSelectionSpeed end

    local t_sel = math.min(1.0, dt * speed)
    if math.abs(gs.animatedSelectionIndex - gs.selectedIndex) < 0.01 then
        gs.animatedSelectionIndex = gs.selectedIndex
    else
        gs.animatedSelectionIndex = lerp(gs.animatedSelectionIndex, gs.selectedIndex, t_sel)
        gs.animatedSelectionIndex = math.max(1, math.min(#gs.files, gs.animatedSelectionIndex))
    end

    if gs.viewMode == "GRID" then
        local cols = gs.gridCols
        local targetRow = math.ceil(gs.selectedIndex / cols)
        local targetCol = (gs.selectedIndex - 1) % cols + 1
        if not gs.animGridRow then gs.animGridRow = targetRow end
        if not gs.animGridCol then gs.animGridCol = targetCol end
        local gridSpeed = gs.layout.gridSelectionSpeed
        local t_grid = math.min(1.0, dt * gridSpeed)
        if math.abs(gs.animGridRow - targetRow) < 0.01 then gs.animGridRow = targetRow
        else gs.animGridRow = lerp(gs.animGridRow, targetRow, t_grid) end
        if math.abs(gs.animGridCol - targetCol) < 0.01 then gs.animGridCol = targetCol
        else gs.animGridCol = lerp(gs.animGridCol, targetCol, t_grid) end
    else
        gs.animGridRow = nil
        gs.animGridCol = nil
    end
end

function M.handleMenuClose(dt, gs, log_func, loader_obj)
    if gs.menuAnim == 0 and gs.closingMenu then
        if #gs.menuStack > 0 and (gs.state == "OPTIONS_MENU" or gs.state == "DELETE_MENU" or gs.state == "SCRAPER_OPTIONS") then
            local parent = table.remove(gs.menuStack)
            gs.menuTitle = parent.title
            gs.menuMessage = parent.message
            gs.menuOptions = parent.options
            gs.menuSelection = parent.selection
            gs.focusedItem = parent.focusedItem
            log_func("Popped submenu. Parent is now: " .. gs.menuTitle)
            gs.menuAnim = 1
        else
            if gs.state == "OPTIONS_MENU" or gs.state == "DELETE_MENU" or gs.state == "INFO_VIEW" then
                gs.state = "LIST"
                gs.focusedItem = nil
                gs.preview.load(gs, log_func, loader_obj)
            elseif gs.state == "SCRAPER_OPTIONS" then
                gs.state = "SCRAPER_VIEW"
            end
        end
        gs.closingMenu = false
    elseif gs.menuAnim == 0 then
        gs.closingMenu = false
    end
    if gs.helpAnim == 0 then gs.closingHelp = false end
end

return M
