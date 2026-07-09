---@diagnostic disable: undefined-global
local M = {}
local helpers = require "draw_helpers"
local bars = require "draw_bars"
local L = _G.L
local unpack = table.unpack or unpack

function M.drawSaveManager(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    local currentItem = global_state.files[global_state.selectedIndex]
    if currentItem then
        local mainName = currentItem.name:gsub("%.[^%.]+$", "")
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(mainName, 0, 15, w, "center")
    end

    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim)
    love.graphics.printf(L.get("save_manager_title"), 0, 50, w, "center")

    local listY = 90
    local listH = h - listY - 40
    local margin = 40
    local listW = w - margin * 2
    local itemH = 40

    love.graphics.setFont(global_state.fontList)

    if #global_state.saveFiles == 0 then
        love.graphics.printf(L.get("no_saves_found"), 0, h/2, w, "center")
    else
        local visibleCount = math.floor(listH / itemH)
        local startIdx = 1
        if global_state.saveManagerSelection > visibleCount then
            startIdx = global_state.saveManagerSelection - visibleCount + 1
        end
        local endIdx = math.min(#global_state.saveFiles, startIdx + visibleCount - 1)

        for i = startIdx, endIdx do
            local item = global_state.saveFiles[i]
            local y = listY + (i - startIdx) * itemH

            if i == global_state.saveManagerSelection then
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", margin, y, listW, itemH - 4, 8)
            else
                love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], 0.3)
                love.graphics.rectangle("fill", margin, y, listW, itemH - 4, 8)
            end

            local icon = (item.type == "SaveRAM") and global_state.iconSaveStates or global_state.iconRom
            if icon then
                local scale = 20 / icon:getHeight()
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(icon, margin + 10, y + (itemH - 4 - icon:getHeight()*scale)/2, 0, scale, scale)
            end

            if i == global_state.saveManagerSelection then
                love.graphics.setColor(theme.colors.text_white)
            else
                love.graphics.setColor(theme.colors.text_medium)
            end

            love.graphics.print(item.name, margin + 40, y + (itemH - 4 - global_state.fontList:getHeight())/2)

            local locText = item.location
            local locColor = {0.7, 0.7, 0.7}
            if locText == "SD1" then locColor = {0.4, 0.8, 1}
            elseif locText == "SD2" then locColor = {1, 0.8, 0.4} end

            love.graphics.setColor(locColor)
            love.graphics.printf(locText, margin + listW - 60, y + (itemH - 4 - global_state.fontList:getHeight())/2, 50, "right")
        end
    end
    bars.drawBottomBar(global_state)
end

function M.drawCleanupMenu(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(L.get("cleanup_title"), 0, 15, w, "center")

    if not global_state.cleanupData.scanned and not global_state.cleanupData.scanning then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h/2 - 25, 200, 50, 10)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scan"), w/2 - 100, h/2 - 10, 200, "center")

    elseif global_state.cleanupData.scanning then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scanning_files"), 0, h/2 - 40, w, "center")

        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300 * global_state.cleanupData.progress, 20)

        love.graphics.setFont(fontSmall)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(global_state.cleanupData.currentFile or "", 0, h/2 + 25, w, "center")

    else
        local hasImages = #(cleanupData.orphanedImages or {}) > 0
        local colCount = hasImages and 3 or 2
        local colW = (w - 40 - (colCount-1)*10) / colCount

        local col1X = 20
        local col2X = col1X + colW + 10
        local col3X = col2X + colW + 10

        love.graphics.setFont(fontMedium)
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf(L.get("orphan_states"), col1X, 60, colW, "center")
        love.graphics.setColor(1, 1, 0.4)
        love.graphics.printf(L.get("duplicate_games"), col2X, 60, colW, "center")
        if hasImages then
            love.graphics.setColor(0.4, 1, 0.4)
            love.graphics.printf(L.get("orphan_images"), col3X, 60, colW, "center")
        end

        love.graphics.setFont(fontSmall)
        local listY = 100
        local listH = h - 280
        local maxVisible = math.floor(listH / 20)

        local startIdx1 = 1
        if global_state.cleanupData.cursor.col == 1 and global_state.cleanupData.cursor.row > maxVisible + 1 then
            startIdx1 = global_state.cleanupData.cursor.row - maxVisible
        end
        local endIdx1 = math.min(#global_state.cleanupData.orphans, startIdx1 + maxVisible - 1)

        for i = startIdx1, endIdx1 do
            local item = global_state.cleanupData.orphans[i]
            local displayIndex = i - startIdx1
            local y = listY + displayIndex * 20

            if global_state.cleanupData.cursor.col == 1 and global_state.cleanupData.cursor.row == i + 1 then
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", col1X, y, colW, 18)
            end
            love.graphics.setColor(theme.colors.text_medium)
            helpers.drawTrimmed(item.name, col1X + 5, y, colW - 10, fontSmall)
        end

        local btnY = h - 175
        if global_state.cleanupData.cursor.col == 1 and global_state.cleanupData.cursor.row == 1 then
            love.graphics.setColor(1, 0, 0)
        else
            love.graphics.setColor(0.5, 0, 0)
        end
        love.graphics.rectangle("fill", col1X, btnY, colW, 25, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(global_state.L.get("delete_all_states"), col1X, btnY + 5, colW, "center")

        local startIdx = 1
        if global_state.cleanupData.cursor.col == 2 and global_state.cleanupData.cursor.row > maxVisible then
            startIdx = global_state.cleanupData.cursor.row - maxVisible + 1
        end
        local endIdx = math.min(#global_state.cleanupData.duplicates, startIdx + maxVisible - 1)

        for i = startIdx, endIdx do
            local item = global_state.cleanupData.duplicates[i]
            local displayIndex = i - startIdx
            local y = listY + displayIndex * 20

            if global_state.cleanupData.cursor.col == 2 and global_state.cleanupData.cursor.row == i then
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", col2X, y, colW, 18)
            end

            love.graphics.setColor(theme.colors.text_medium)
            local text = item.name .. " [" .. item.system .. "]"
            helpers.drawTrimmed(text, col2X + 5, y, colW - 45, fontSmall)

            if item.location == "SD1" then love.graphics.setColor(0.4, 0.8, 1)
            else love.graphics.setColor(1, 0.8, 0.4) end
            love.graphics.printf(item.location, col2X + colW - 40, y, 35, "right")
        end

        if hasImages then
            local startIdx3 = 1
            if global_state.cleanupData.cursor.col == 3 and global_state.cleanupData.cursor.row > maxVisible then
                startIdx3 = global_state.cleanupData.cursor.row - maxVisible + 1
            end
            local endIdx3 = math.min(#global_state.cleanupData.orphanedImages, startIdx3 + maxVisible - 1)

            for i = startIdx3, endIdx3 do
                local item = global_state.cleanupData.orphanedImages[i]
                local displayIndex = i - startIdx3
                local y = listY + displayIndex * 20
                if global_state.cleanupData.cursor.col == 3 and global_state.cleanupData.cursor.row == i then
                    love.graphics.setColor(theme.colors.selection_accent)
                    love.graphics.rectangle("fill", col3X, y, colW, 18)
                end
                love.graphics.setColor(theme.colors.text_medium)
                helpers.drawTrimmed(item.name, col3X + 5, y, colW - 10, fontSmall)
            end
        end

        local infoY = h - 140
        love.graphics.setColor(0.15, 0.15, 0.17)
        love.graphics.rectangle("fill", 10, infoY, w - 20, 100, 5)
        love.graphics.setColor(theme.colors.side_menu_separator)
        love.graphics.rectangle("line", 10, infoY, w - 20, 100, 5)

        local selItem = nil
        local selTitle = ""
        if global_state.cleanupData.cursor.col == 1 then
            if global_state.cleanupData.cursor.row == 1 then
                selTitle = global_state.L.get("action_delete_all_orphans")
            elseif global_state.cleanupData.orphans[global_state.cleanupData.cursor.row - 1] then
                selItem = global_state.cleanupData.orphans[global_state.cleanupData.cursor.row - 1]
                selTitle = global_state.L.get("orphan_state")
            end
        elseif global_state.cleanupData.cursor.col == 3 then
            if global_state.cleanupData.orphanedImages[global_state.cleanupData.cursor.row] then
                selItem = global_state.cleanupData.orphanedImages[global_state.cleanupData.cursor.row]
                selTitle = global_state.L.get("orphan_image")
            end
        else
            if global_state.cleanupData.duplicates[global_state.cleanupData.cursor.row] then
                selItem = global_state.cleanupData.duplicates[global_state.cleanupData.cursor.row]
                selTitle = global_state.L.get("duplicate_game")
            end
        end

        love.graphics.setColor(theme.colors.text_white)
        love.graphics.setFont(fontMedium)
        love.graphics.print(selTitle, 20, infoY + 10)

        if selItem then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.text_medium)
            love.graphics.print(L.get("file_label", selItem.name), 20, infoY + 35)

            local relPath = selItem.fullPath:match("ROMS/(.*)") or selItem.fullPath
            helpers.drawTrimmedStart(L.get("path_label", relPath), 20, infoY + 55, w - 140, fontSmall)

            if selItem.system then
                love.graphics.print(L.get("system_label", selItem.system, selItem.location), 20, infoY + 75)
            else
                love.graphics.print(L.get("location_label", selItem.location), 20, infoY + 75)
            end

            local imgPath = nil
            if global_state.cleanupData.cursor.col == 3 then
                imgPath = selItem.fullPath
            elseif selItem.system and selItem.name then
                local baseMuos = "/mnt/mmc/MUOS/info/catalogue/"
                if not io.open("/mnt/mmc", "r") then
                    local cwd = love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    baseMuos = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
                end
                imgPath = baseMuos .. selItem.system .. "/box/" .. selItem.name:gsub("%..-$", "") .. ".png"
            end

            if imgPath then
                local success, img = pcall(global_state.love.graphics.newImage, imgPath)
                if success and img then
                    local pH = 90
                    local scale = pH / img:getHeight()
                    love.graphics.draw(img, w - 100, infoY + 5, 0, scale, scale)
                end
            end
        end

        if global_state.cleanupData.confirming then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, 0, w, h)

            local modalW, modalH = 400, 200
            local mx, my = (w - modalW)/2, (h - modalH)/2

            love.graphics.setColor(theme.colors.side_menu_background)
            love.graphics.rectangle("fill", mx, my, modalW, modalH, 10)
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.rectangle("line", mx, my, modalW, modalH, 10)

            love.graphics.setFont(fontTitle)
            love.graphics.printf(global_state.L.get("confirm_action"), mx, my + 20, modalW, "center")
            love.graphics.setFont(fontMedium)
            love.graphics.printf(selTitle, mx + 20, my + 60, modalW - 40, "center")
            if selItem then
                love.graphics.setFont(fontSmall)
                love.graphics.printf(selItem.name, mx + 20, my + 90, modalW - 40, "center")
            end

            love.graphics.setFont(global_state.fontMedium)
            love.graphics.setColor(theme.colors.selection_accent)

            local iconY = my + 140
            local iconScale = 0.8
            local totalW = global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("confirm") .. "   ") + global_state.buttonIcons.b:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("cancel"))
            local startX = mx + (modalW - totalW) / 2

            love.graphics.draw(global_state.buttonIcons.a, startX, iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. global_state.L.get("confirm") .. "   ", startX + global_state.buttonIcons.a:getWidth()*iconScale, iconY + 2)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(global_state.buttonIcons.b, startX + global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" Confirmar   "), iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. global_state.L.get("cancel"), startX + global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("confirm") .. "   ") + global_state.buttonIcons.b:getWidth()*iconScale, iconY + 2)
        end
    end
    bars.drawBottomBar(global_state)
end

function M.drawGrid(global_state, w, h)
    local tStart = love.timer.getTime()
    local cols = global_state.gridCols
    local rows = 3
    local startY = 80
    local marginX = 30
    local availableW = w - (marginX * 2)
    local cellW = availableW / cols
    local cellH = (h - startY - 40) / rows

    local bgImage = global_state.currentScreenshot or global_state.currentImage
    if bgImage then
        local alpha = 1
        if bgImage == global_state.currentScreenshot then alpha = global_state.currentScreenshotAlpha
        elseif bgImage == global_state.currentImage then alpha = global_state.currentImageAlpha end

        local scale = h / bgImage:getHeight()
        love.graphics.setColor(1, 1, 1, 0.15 * alpha)
        local imgW = bgImage:getWidth() * scale
        local imgX = w - imgW
        love.graphics.draw(bgImage, imgX, 0, 0, scale, scale)

        local r, g, b = unpack(theme.colors.background)
        love.graphics.setColor(r, g, b, 1)
        helpers.ditherShader:send("objPos", {imgX, 0})
        love.graphics.setShader(helpers.ditherShader)
        love.graphics.draw(helpers.getFadeGradientMesh(), imgX, 0, 0, imgW, h)
        love.graphics.setShader()
    end

    local target_row_float = global_state.animGridRow or math.ceil(global_state.animatedSelectionIndex / cols)
    local target_visual_row_float = rows / 2
    local gridScrollOffset = (target_row_float - target_visual_row_float) * cellH

    local minGridScrollOffset = (1 - target_visual_row_float) * cellH
    local maxGridScrollOffset = math.max(minGridScrollOffset, (math.ceil(#global_state.files / cols) - rows) * cellH)
    if #global_state.files <= rows * cols then
        gridScrollOffset = minGridScrollOffset
    end
    gridScrollOffset = math.max(minGridScrollOffset, math.min(maxGridScrollOffset, gridScrollOffset))

    local firstVisibleRow = math.floor(gridScrollOffset / cellH) - 1
    local startIndex = math.max(1, firstVisibleRow * cols + 1)
    local numVisibleRows = rows + 4
    local endIndex = math.min(#global_state.files, startIndex + (cols * numVisibleRows) - 1)

    for i = startIndex, endIndex do
        local r_abs = math.ceil(i / cols) - 1
        local c_abs = (i - 1) % cols
        local x = marginX + c_abs * cellW
        local y = startY + r_abs * cellH - gridScrollOffset
        local item = global_state.files[i]

        local checkPath = item.fullPath or (global_state.romPath .. item.name)
        local isLastPlayed = (not item.isDir) and global_state.playedRoms[checkPath]
        local playedSystem = item.system

        if global_state.launchMode == "Juego Unico" and item.versions then
             for _, v in ipairs(item.versions) do
                 if global_state.playedRoms[v.fullPath] then isLastPlayed = true playedSystem = v.system break end
             end
        end

        local contentWidth = cellW - 20

        local imageToDraw = nil
        if not item.isDir then
            local base = item.name:gsub("%..-$", "")

            local systemForItem = utils.getSystemNameForItem(item, global_state.systemName, global_state.isVirtualRoot)

            if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
                local v = item.versions[1]
                base = v.name:gsub("%..-$", "")
                systemForItem = v.system or systemForItem
            end

            local artPathForItem = filesystem.getArtPathForSystem(systemForItem)

            if artPathForItem then
                local path = artPathForItem .. base .. ".png"
                imageToDraw = global_state.loader:getImage(path)

                if not imageToDraw then
                    imageToDraw = global_state.imgNoImage
                end
            end
        end

        if imageToDraw then
            if not item.alpha then item.alpha = 0 end
            item.alpha = math.min(1, item.alpha + love.timer.getDelta() * 5)
            love.graphics.setColor(1, 1, 1, item.alpha)
            local scale = math.min(contentWidth / imageToDraw:getWidth(), (cellH - 80) / imageToDraw:getHeight())
            if imageToDraw == global_state.imgNoImage then
                scale = scale * 0.5
            end
            local imgW = imageToDraw:getWidth() * scale
            local imgH = imageToDraw:getHeight() * scale
            local ix = x + 10 + (contentWidth - imgW) / 2
            local iy = y + 10 + ((cellH - 80) - imgH) / 2

            love.graphics.stencil(function()
                love.graphics.rectangle("fill", ix, iy, imgW, imgH, 8)
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)
            love.graphics.draw(imageToDraw, ix, iy, 0, scale, scale)
            love.graphics.setStencilTest()
        else
            item.alpha = 0
            love.graphics.setColor(1, 1, 1)
            local icon = item.icon
            if not icon and item.isDir then
                icon = utils.getSystemIcon(item.name, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
            end
            icon = icon or (item.isDir and global_state.iconFolder)

            if not icon then
                if item.system then
                    icon = utils.getSystemContentIcon(item.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                end
                if not icon then icon = global_state.currentSystemContentIcon or global_state.iconRom end
            end

            local availableH = cellH - 65
            local iconAvailW = cellW - 20
            local scale = math.min(iconAvailW / icon:getWidth(), availableH / icon:getHeight()) * 0.7
            if icon == global_state.iconFolder then
                scale = scale * 0.7
            end
            local ix = x + (cellW - icon:getWidth()*scale)/2
            local iy = y + 5 + (availableH - icon:getHeight()*scale)/2
            love.graphics.draw(icon, ix, iy, 0, scale, scale)
        end

        local textFont = fontMedium
        love.graphics.setFont(textFont)
        local displayName = item.name
        if not item.isDir then
            displayName = displayName:gsub("%.[^%.]+$", "")
        end
        local _, wrappedLines = textFont:getWrap(displayName, contentWidth)

        local textToPrint = ""
        if #wrappedLines == 1 then
            textToPrint = wrappedLines[1]
        elseif #wrappedLines >= 2 then
            local line2 = wrappedLines[2]
            if #wrappedLines > 2 then
                while textFont:getWidth(line2 .. "...") > contentWidth - 5 and #line2 > 0 do
                    line2 = line2:sub(1, -2)
                end
                line2 = line2 .. "..."
            end
            textToPrint = wrappedLines[1] .. "\n" .. line2
        end

        local numLines = (#wrappedLines >= 2) and 2 or 1
        local textBlockHeight = textFont:getHeight() * numLines
        local textY = y + cellH - 50 + (50 - textBlockHeight) / 2
        love.graphics.setColor(theme.colors.text_white)
        if i == helpers.round(global_state.animatedSelectionIndex) then
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
            love.graphics.printf(textToPrint, x + 11, textY, contentWidth, "center")
        else
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
        end

        local statusIconSize = 18
        local iconPadding = 4
        local rightOffset = 10
        local iconY2 = y + cellH - 50 - statusIconSize

        if global_state.favoriteRoms[item.fullPath] then
            local icon = global_state.iconFavorite
            local scale = statusIconSize / icon:getHeight()
            local ix = x + cellW - rightOffset - (icon:getWidth() * scale)
            love.graphics.setColor(theme.colors.selection_accent)
            love.graphics.draw(icon, ix, iconY2, 0, scale, scale)
            rightOffset = rightOffset + (icon:getWidth() * scale) + iconPadding
        end

        if isLastPlayed and global_state.markPlayed and global_state.launchMode ~= "Juego Unico" then
            local pIcon = global_state.iconRom
            local sys = playedSystem
            if not sys then sys = utils.getSystemNameForItem(item, global_state.systemName, global_state.isVirtualRoot) end
            if sys then pIcon = utils.getSystemIcon(sys, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage) or global_state.iconRom end

            local scale = statusIconSize / pIcon:getHeight()
            local ix = x + cellW - rightOffset - (pIcon:getWidth() * scale)
            love.graphics.setColor(0.2, 0.8, 0.3)
            love.graphics.draw(pIcon, ix, iconY2, 0, scale, scale)
        end
    end
    local tEnd = love.timer.getTime()
    if tEnd - tStart > 0.033 then
        global_state.log("Slow Grid Draw: " .. string.format("%.4f", tEnd - tStart) .. "s")
    end

    local animRow = global_state.animGridRow or 1
    local animCol = global_state.animGridCol or 1

    local r_abs = animRow - 1
    local c_abs = animCol - 1

    local animX = marginX + c_abs * cellW
    local animY = startY + r_abs * cellH - gridScrollOffset

    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill", animX + 2, animY + 2, cellW - 4, cellH + 1, 15)
end

return M
