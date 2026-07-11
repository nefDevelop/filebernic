---@diagnostic disable: undefined-global
local M = {}
local helpers = require "draw_helpers"
local unpack = table.unpack or unpack
local L = _G.L

function M.drawMenuContent(global_state, title, message, options, selection, item, x, w, h, alpha, isFocused, dimProgress, isFile)
    local startY = 90
    local isGameOptions = false
    local sysName = nil

    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)

    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    if item and (title:match("^" .. L.get("options")) and message == item.name) then
        isGameOptions = true
        sysName = utils.getSystemNameForItem(item)
    end

    if isGameOptions then
        local name = message
        local mainName = name:gsub("%.[^%.]+$", ""):gsub("%s*$", "")
        local extraInfo = ""

        local pStart = name:find("%s*%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
            extraInfo = name:sub(pStart)
        end

        local headerY = 25
        local baseTextX = x + 20
        local titleX = baseTextX

        love.graphics.setFont(fontTitle)

        local titleAvailW = w - 40
        local maxCoverW = 80
        local coverW, coverH

        if global_state.currentImage then
            titleX = baseTextX + maxCoverW + 10
            titleAvailW = w - (baseTextX - x) - (maxCoverW + 10) - 20
        end

        local _, wrappedMain = fontTitle:getWrap(mainName, titleAvailW)
        local visibleLines = math.min(#wrappedMain, 2)
        local mainH = visibleLines * fontTitle:getHeight()

        if global_state.currentImage then
            love.graphics.setColor(1, 1, 1)
            local maxH = 120
            local coverScale = math.min(maxCoverW / global_state.currentImage:getWidth(), maxH / global_state.currentImage:getHeight())

            coverW = global_state.currentImage:getWidth() * coverScale
            coverH = global_state.currentImage:getHeight() * coverScale

            love.graphics.draw(global_state.currentImage, baseTextX + (maxCoverW - coverW)/2, headerY, 0, coverScale, coverScale)
        end

        love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)

        local textStartY = headerY
        if coverH > mainH then
            textStartY = headerY + (coverH - mainH) / 2
        end

        for i = 1, visibleLines do
            local line = wrappedMain[i]
            if i == visibleLines and #wrappedMain > visibleLines then
                while fontTitle:getWidth(line .. "...") > titleAvailW and #line > 0 do
                    line = line:sub(1, -2)
                end
                line = line .. "..."
            end
            love.graphics.print(line, titleX, textStartY + (i-1)*fontTitle:getHeight())
        end
        local contentH = math.max(mainH, coverH)

        local regionInfo = extraInfo:gsub("%.[^%.]+$", "")
        local displayName = utils.getSystemDisplayName(sysName)
        local newSubtitle = (displayName or "Sistema Desconocido") .. " " .. regionInfo

        if newSubtitle:gsub("%s+", "") ~= "" then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
            local subtitleY = headerY + contentH + 5
            love.graphics.printf(newSubtitle, x + 20, subtitleY, w - 40, "left")
            local _, wrappedExtra = fontSmall:getWrap(newSubtitle, w - 40)
            startY = subtitleY + (#wrappedExtra * fontSmall:getHeight()) + 20
        else
            startY = headerY + contentH + 20
        end
    else
        love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
        love.graphics.setFont(global_state.fontTitle)
        love.graphics.printf(title, x + 20, 40, w - 40, "left")

        if message and message ~= "" then
            love.graphics.setFont(global_state.fontMedium)
            love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
            love.graphics.printf(message, x + 20, 80, w - 40, "left")
            local _, wrappedtext = global_state.fontMedium:getWrap(message, w - 40)
            startY = 80 + (#wrappedtext * global_state.fontMedium:getHeight()) + 30
        end
    end

    love.graphics.setFont(fontMedium)
    local rowHeight = 40
    for i, option in ipairs(options) do
        local rowY = startY + (i-1) * rowHeight
        local centerY = rowY + rowHeight / 2

        local text = type(option) == "table" and option.text or option
        local icon = type(option) == "table" and option.icon or nil

        local labelColor, valueColor

        if i == selection then
            if isFocused then
                local c = theme.colors.selection_accent
                love.graphics.setColor(c[1], c[2], c[3], alpha)
            else
                love.graphics.setColor(0.3, 0.3, 0.3, alpha)
            end
            love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            labelColor = theme.colors.text_white
            valueColor = theme.colors.text_white
        else
            if type(option) == "table" and option.played and global_state.markPlayed then
                local c = theme.colors.list_played_unselected
                love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
                love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            end

            if text:find(global_state.L.get("delete")) then
                labelColor = {1, 0.4, 0.4}
            elseif text:find(global_state.L.get("cleanup")) then
                labelColor = {0.8, 0.1, 0.1}
            else
                labelColor = theme.colors.text_dim
            end
            valueColor = theme.colors.selection_accent
        end

        local label, value = text:match("^(.-):%s*(.+)$")

        local textY = centerY - fontMedium:getHeight() / 2

        local lc = {labelColor[1], labelColor[2], labelColor[3], (labelColor[4] or 1) * alpha}
        local vc = {valueColor[1], valueColor[2], valueColor[3], (valueColor[4] or 1) * alpha}

        local textX = x + 20

        local iconSlotW = 30
        local slotSpacing = 5
        local marginRight = 20

        local function drawIconCentered(img, slotIdx, color)
             if not img then return end
             local iconH = 18
             if img == iconReload then iconH = 15 end

             local scale = iconH / img:getHeight()
             local iconW = img:getWidth() * scale

             local slotCenterX
             if slotIdx == 2 then
                 slotCenterX = x + w - marginRight - (iconSlotW / 2)
             else
                 slotCenterX = x + w - marginRight - iconSlotW - slotSpacing - (iconSlotW / 2)
             end

             love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
             love.graphics.draw(img, slotCenterX - (iconW / 2), centerY - iconH/2, 0, scale, scale)
        end

        if label and value then
            love.graphics.setColor(lc)
            love.graphics.print(label .. ":", textX, textY)

            if value == L.get("on") or value == L.get("yes") or value == L.get("off") or value == L.get("no") then
                local toggleIcon = (value == global_state.L.get("on") or value == global_state.L.get("yes")) and global_state.imgOn or global_state.imgOff
                local toggleColor = (value == L.get("on") or value == L.get("yes")) and {0.2, 1, 0.2} or {0.6, 0.6, 0.6}
                drawIconCentered(toggleIcon, 2, toggleColor)
            elseif label == global_state.L.get("view") then
                local gridColor = (value == global_state.L.get("grid")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                local listColor = (value == global_state.L.get("list")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                drawIconCentered(global_state.iconList, 1, listColor)
                drawIconCentered(global_state.iconGrid, 2, gridColor)
            elseif label == global_state.L.get("mode") then
                local gameColor = (value == global_state.L.get("single_game")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                local folderColor = (value == global_state.L.get("folder")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                drawIconCentered(global_state.iconFolder, 1, folderColor)
                drawIconCentered(global_state.iconGame, 2, gameColor)
            else
                love.graphics.setColor(vc)
                local valW = fontMedium:getWidth(value)
                love.graphics.print(value, x + w - 20 - valW, textY)
            end
        else
            love.graphics.setColor(lc)
            local rightMargin = 20
            if icon then
                local baseColor = global_state.theme.colors.selection_accent
                if icon == global_state.iconTrash then baseColor = {1, 0.4, 0.4} end

                local iconColor = (i == selection and isFocused) and global_state.theme.colors.text_white or baseColor

                drawIconCentered(icon, 2, iconColor)
                rightMargin = marginRight + iconSlotW + 10
            end
            love.graphics.setColor(lc)
            helpers.drawTrimmed(text, textX, textY, w - (textX - x) - rightMargin, fontMedium)
        end
    end

    if not isFocused then
        local dp = dimProgress or 1
        love.graphics.setColor(0, 0, 0, 0.5 * alpha * dp)
        love.graphics.rectangle("fill", x, 0, w, h)
        love.graphics.setColor(0, 0, 0, 0.5 * alpha * dp)
        love.graphics.draw(helpers.getGradientMesh(), x, 0, 0, w, h)
    end
end

function M.calculateMenuWidth(global_state, title, message, options, item, isGameOptions)
    local w = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    local optionsMaxW = 0
    for _, opt in ipairs(options) do
        local text = type(opt) == "table" and opt.text or opt
        local width

        local label, val = text:match("^(.-):%s*(.+)$")
        if text == L.get("add_favorite") or text == L.get("remove_favorite") then
            local addWidth = fontMedium:getWidth(L.get("add_favorite"))
            local removeWidth = fontMedium:getWidth(L.get("remove_favorite"))
            width = math.max(addWidth, removeWidth)
        elseif label and (val == global_state.L.get("on") or val == global_state.L.get("off") or val == global_state.L.get("yes") or val == global_state.L.get("no")) then
             width = fontMedium:getWidth(label .. ":") + 50
        elseif label == global_state.L.get("view") then
             width = fontMedium:getWidth(label .. ":") + 80
        elseif label == L.get("mode") then
             width = fontMedium:getWidth(label .. ":") + 80
        else
             width = fontMedium:getWidth(text)
        end

        if type(opt) == "table" and opt.icon then width = width + 35 end
        if width > optionsMaxW then optionsMaxW = width end
    end

    local mainName = title
    local coverSpace = 0

    if isGameOptions and message then
        local name = message
        mainName = name:gsub("%.[^%.]+$", ""):gsub("%s*$", "")
        local pStart = name:find("%s*%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
        end

        if global_state.currentImage then
            coverSpace = 90
        end
    end

    local titleRequiredW = fontTitle:getWidth(mainName) + 40 + coverSpace

    local minW = (isGameOptions and global_state.currentImage) and 320 or 200

    local calculatedW = math.max(minW, optionsMaxW + 60, titleRequiredW)

    return math.min(w * 0.75, calculatedW)
end

function M.drawHelpPanel(global_state, x, w, h, alpha)
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)

    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    local contentX = x
    love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
    love.graphics.setFont(global_state.fontTitle)
    love.graphics.printf("Ayuda - Controles", contentX + 20, 40, w - 40, "left")

    local list = global_state.helpData[global_state.state] or global_state.helpData.DEFAULT
    local filteredList = {}
    if global_state.state == "LIST" and global_state.launchMode == "Juego Unico" then
        for _, item in ipairs(list) do
            if item.text ~= "Seleccionar" then table.insert(filteredList, item) end
        end
    else
        filteredList = list
    end

    love.graphics.setFont(global_state.fontMedium)
    local startY = 90
    for i, item in ipairs(filteredList) do
        local rowY = startY + (i-1)*40
        local centerY = rowY + 20
        local iconScale = 0.8
        local iconH = item.icon:getHeight() * iconScale
        local iconY = centerY - iconH / 2
        local textY = centerY - fontMedium:getHeight() / 2
        local iconW = item.icon:getWidth() * iconScale

        love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
        love.graphics.print(global_state.L.get(item.text), contentX + 20, textY)
        love.graphics.draw(item.icon, contentX + w - 20 - iconW, iconY, 0, iconScale, iconScale)
    end
end

function M.drawMediaDetailContent(global_state, currentItem, x, y, w, h, alpha)
    local regionInfo = ""
    local pStart = currentItem.name:find("%(")
    if pStart then regionInfo = currentItem.name:sub(pStart) end

    local sysName = utils.getSystemNameForItem(currentItem)
    local displayName = utils.getSystemDisplayName(sysName)
    local subtitle = (displayName or "Desconocido") .. " " .. regionInfo

    local coverImg = global_state.currentImage

    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
    love.graphics.printf(subtitle, x, y + 55, w, "center")

    local contentY = y + 100
    local imagesY = contentY + fontMedium:getHeight() + 15
    local availableH = h - imagesY - 40 - 120

    local spacing = 20

    local ar1 = coverImg and (coverImg:getWidth() / coverImg:getHeight()) or 0.7
    local ar2 = global_state.currentScreenshot and (global_state.currentScreenshot:getWidth() / global_state.currentScreenshot:getHeight()) or 1.33

    local totalAvailW = w - 40
    local heightForWidth = (totalAvailW - spacing) / (ar1 + ar2)
    local finalImageH = math.min(availableH, heightForWidth)

    local coverW = finalImageH * ar1
    local screenW = finalImageH * ar2

    local totalW = coverW + spacing + screenW
    local startX = x + (w - totalW) / 2
    local drawY = imagesY + (availableH - finalImageH) / 2
    local placeholderRadius = 12

    love.graphics.setFont(fontMedium)

    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local frontText = global_state.L.get("front")
    local textW = fontMedium:getWidth(frontText)
    love.graphics.print(frontText, startX + (coverW - textW) / 2, contentY)

    love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], alpha * 0.5)
    love.graphics.rectangle("line", startX, drawY, coverW, finalImageH, placeholderRadius)

    if coverImg then
        love.graphics.setColor(1, 1, 1, alpha * (global_state.currentImage and global_state.currentImageAlpha or 1))
        local coverScale = finalImageH / coverImg:getHeight()
        local imgW = coverImg:getWidth() * coverScale
        local imgX = startX + (coverW - imgW) / 2
        love.graphics.draw(coverImg, imgX, drawY, 0, coverScale, coverScale)
    end

    local drawX = startX + coverW + spacing

    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local screenText = global_state.L.get("screen")
    local textW2 = fontMedium:getWidth(screenText)
    love.graphics.print(screenText, drawX + (screenW - textW2) / 2, contentY)

    love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], alpha * 0.5)
    love.graphics.rectangle("line", drawX, drawY, screenW, finalImageH, placeholderRadius)

    if global_state.currentScreenshot then
        love.graphics.setColor(1, 1, 1, alpha * global_state.currentScreenshotAlpha)
        local screenScale = finalImageH / global_state.currentScreenshot:getHeight()
        local imgW = global_state.currentScreenshot:getWidth() * screenScale
        local imgX = drawX + (screenW - imgW) / 2
        love.graphics.draw(global_state.currentScreenshot, imgX, drawY, 0, screenScale, screenScale)
    end

    local textY = imagesY + availableH + 15
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local infoTitle = global_state.L.get("info")
    if global_state.currentYear and global_state.currentYear ~= "" then infoTitle = infoTitle .. " (" .. global_state.currentYear .. ")" end
    love.graphics.print(infoTitle, x + 20, textY)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
    local descText = (global_state.currentDescription and global_state.currentDescription ~= "") and global_state.currentDescription or L.get("no_info")
    love.graphics.printf(descText, x + 20, textY + 25, w - 40, "left")

    if not coverImg and not global_state.currentScreenshot and descText == L.get("no_info") then
        love.graphics.setColor(global_state.theme.colors.text_medium[1], global_state.theme.colors.text_medium[2], global_state.theme.colors.text_medium[3], alpha)
        love.graphics.printf(global_state.L.get("no_images_info"), x, y + h/2, w, "center")
    end
end

function M.drawInfoPanel(global_state, item, x, w, h, alpha)
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)
    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    if not item then return end
    local mainName = item.name:gsub("%s*$", "")
    local pStart = mainName:find("%(")
    if pStart then mainName = mainName:sub(1, pStart - 1):gsub("%s*$", "") end
    mainName = mainName:gsub("%.[^%.]+$", "")

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
    love.graphics.printf(mainName, x, 20, w, "center")

    M.drawMediaDetailContent(global_state, item, x, 0, w, h, alpha)
end

function M.drawOverlayMenus(global_state)
    local w, h = love.graphics.getDimensions()
    local menusToDraw = {}

    for _, m in ipairs(global_state.menuStack) do
        table.insert(menusToDraw, { type = "MENU", data = m, isCurrent = false })
    end

    if global_state.state == "OPTIONS_MENU" or global_state.state == "DELETE_MENU" or global_state.state == "SCRAPER_OPTIONS" then
        table.insert(menusToDraw, { type = "MENU", data = { title = global_state.menuTitle, message = global_state.menuMessage, options = global_state.menuOptions, selection = global_state.menuSelection, focusedItem = global_state.focusedItem }, isCurrent = true })
    elseif global_state.state == "INFO_VIEW" then
        table.insert(menusToDraw, { type = "INFO", data = { focusedItem = global_state.focusedItem or global_state.files[global_state.selectedIndex] }, isCurrent = true })
    end

    if global_state.showHelp or global_state.closingHelp then
        table.insert(menusToDraw, { type = "HELP", data = {}, isCurrent = true })
    end

    for _, m in ipairs(menusToDraw) do
        if m.type == "MENU" then
            local item = m.data.focusedItem or global_state.files[global_state.selectedIndex]
            local isGameOpts = false
            if item then
                isGameOpts = (m.data.title:match("^" .. global_state.L.get("options")) and m.data.message == item.name)
            end
            m.naturalWidth = M.calculateMenuWidth(global_state, m.data.title, m.data.message, m.data.options, item, isGameOpts)
        elseif m.type == "INFO" then
            m.naturalWidth = math.max(w * 0.5, 400)
        elseif m.type == "HELP" then
            m.naturalWidth = math.max(w * 0.4, 300)
        end
    end

    local activeMenu = #menusToDraw > 0 and menusToDraw[#menusToDraw] or nil
    local t = 0
    if activeMenu then
        if activeMenu.type == "HELP" then
            t = global_state.helpAnim
        else
            t = global_state.menuAnim
        end
    end
    local ease = 1 - (1 - t)^3

    local stackMax = 0
    for i = 1, #menusToDraw - 1 do
        if menusToDraw[i].naturalWidth > stackMax then stackMax = menusToDraw[i].naturalWidth end
    end

    local totalMax = stackMax
    if activeMenu and activeMenu.naturalWidth > totalMax then totalMax = activeMenu.naturalWidth end

    for i, m in ipairs(menusToDraw) do
        if i == #menusToDraw then
            m.width = totalMax
        else
            m.width = stackMax + (totalMax - stackMax) * ease
        end
    end

    local flapSize = 30
    if #menusToDraw > 0 then
        local last = menusToDraw[#menusToDraw]
        last.finalX = w - last.width
        for i = #menusToDraw - 1, 1, -1 do
            menusToDraw[i].finalX = menusToDraw[i+1].finalX - flapSize
        end
    end

    for i, menu in ipairs(menusToDraw) do
        local startX
        if i == #menusToDraw then
            startX = w
            menu.alpha = ease
        else
            startX = w - stackMax
            menu.alpha = 1
        end

        menu.x = startX + (menu.finalX - startX) * ease
    end

    if #menusToDraw > 0 then
        local isDelete = (global_state.state == "DELETE_MENU")
        local r, g, b
        if isDelete then
            r, g, b = 0.3, 0.05, 0.05
        else
            r, g, b = unpack(theme.colors.overlay_dark)
        end
        love.graphics.setColor(r, g, b, 0.6 * ease)
        love.graphics.draw(helpers.getGradientMesh(), 0, 0, 0, w, h)

        for i, m in ipairs(menusToDraw) do
            m.isFocused = (i == #menusToDraw)
        end

        for _, m in ipairs(menusToDraw) do
            if m.type == "MENU" then
                local item = m.data.focusedItem or global_state.files[global_state.selectedIndex]
                M.drawMenuContent(global_state, m.data.title, m.data.message, m.data.options, m.data.selection, item, m.x, m.width, h, m.alpha, m.isFocused, ease)
            elseif m.type == "INFO" then
                M.drawInfoPanel(global_state, m.data.focusedItem, m.x, m.width, h, m.alpha)
            elseif m.type == "HELP" then
                M.drawHelpPanel(global_state, m.x, m.width, h, m.alpha)
            end
        end

        if global_state.state == "DELETE_MENU" and global_state.itemToDelete then
             local delMenu = nil
             for _, m in ipairs(menusToDraw) do if m.type == "MENU" and m.isCurrent then delMenu = m break end end
             if delMenu then
                if global_state.deleteHoldTimer > 0 then
                    local barW = delMenu.width - 60
                    local barH = 6
                    local barX = delMenu.x + 30
                    local barY = h - 70
                    local progress = math.min(global_state.deleteHoldTimer / 0.5, 1)

                    love.graphics.setColor(0.3, 0.05, 0.05, delMenu.alpha)
                    love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)

                    love.graphics.setColor(1, 0.2, 0.2, delMenu.alpha)
                    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 3, 3)

                    love.graphics.setFont(fontSmall)
                    love.graphics.setColor(1, 0.4, 0.4, delMenu.alpha)
                    love.graphics.printf(L.get("hold_to_delete"), barX, barY + barH + 4, barW, "center")
                end

                local path = global_state.itemToDelete.fullPath or ""
                local displayPath = path
                if path:find("ROMS/") then displayPath = path:match("ROMS/(.*)")
                elseif path:find("Simulador_SD/") then displayPath = path:match("Simulador_SD/(.*)") end
                love.graphics.setFont(fontSmall)
                love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], delMenu.alpha)
                local textY = h - 45
                local availableW = delMenu.width - 40
                if fontSmall:getWidth(displayPath) > availableW then
                     love.graphics.printf(displayPath, delMenu.x + 20, textY - fontSmall:getHeight(), availableW, "center")
                else
                     love.graphics.printf(displayPath, delMenu.x + 20, textY, availableW, "center")
                end
             end
        end
    end
end

return M
