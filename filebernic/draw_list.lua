---@diagnostic disable: undefined-global
local M = {}
local helpers = require "draw_helpers"
local views = require "draw_views"
local unpack = table.unpack or unpack

function M.drawMainList(global_state, w, h, sdColX, sdColW, _, _, showPreview)
    if global_state.viewMode == "GRID" then
        views.drawGrid(global_state, w, h)
    else
        if showPreview then
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
        end

        local favScale = (global_state.iconFavorite and global_state.iconFavorite:getHeight() ~= 0) and ((40 * 0.35) / global_state.iconFavorite:getHeight()) or 1
        local favAnimState = { index = global_state.favAnimIndex, anim = global_state.favAnim }

        local visibleRows = global_state.pageSize + 1
        local targetVisualRow = math.floor(visibleRows / 2)

        local listScrollOffset = (global_state.animatedSelectionIndex - targetVisualRow) * global_state.layout.rowHeight

        local minListOffset = (1 - targetVisualRow) * global_state.layout.rowHeight
        local maxListOffset = math.max(0, (#global_state.files - targetVisualRow) * global_state.layout.rowHeight)

        listScrollOffset = math.max(minListOffset, math.min(maxListOffset, listScrollOffset))

        local visualSelY = layout.listY + (global_state.animatedSelectionIndex - 1) * layout.rowHeight - listScrollOffset + (layout.rowHeight - layout.selHeight) / 2

        local currentItemIndex = math.floor(global_state.animatedSelectionIndex)
        local nextItemIndex = math.ceil(global_state.animatedSelectionIndex)
        local interpolationFactor = global_state.animatedSelectionIndex - currentItemIndex

        local width1 = helpers.calculateItemDisplayWidth(global_state.files[currentItemIndex], global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, currentItemIndex, favAnimState)
        local width2 = helpers.calculateItemDisplayWidth(global_state.files[nextItemIndex], global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, nextItemIndex, favAnimState)

        local animatedSelectionWidth = helpers.lerp(width1, width2, interpolationFactor)

        local selColor = theme.colors.selection_accent
        love.graphics.setColor(selColor[1], selColor[2], selColor[3], 0.15)
        love.graphics.rectangle("fill", global_state.layout.selX, visualSelY, animatedSelectionWidth, global_state.layout.selHeight, 22)

        love.graphics.setFont(global_state.fontList)
        local firstVisibleItemIndex = math.max(1, math.floor(1 + listScrollOffset / layout.rowHeight))
        local lastVisibleItemIndex = math.min(#global_state.files, firstVisibleItemIndex + visibleRows + 1)
        for i = firstVisibleItemIndex, lastVisibleItemIndex do
            local y = layout.listY + (i - 1) * layout.rowHeight - (listScrollOffset or 0)
            local item = global_state.files[i]

            local checkPath = item.fullPath or (global_state.romPath .. item.name)
            local isLastPlayed = (not item.isDir) and global_state.playedRoms[checkPath]

            local playedSystem = nil
            if global_state.launchMode == "Juego Unico" and item.versions then
                for _, v in ipairs(item.versions) do if global_state.playedRoms[v.fullPath] then isLastPlayed = true; playedSystem = v.system break end end
            elseif isLastPlayed and global_state.markPlayed then
                playedSystem = utils.getSystemNameForItem(item)
            end

            if item.empty then
                love.graphics.setColor(theme.colors.text_disabled)
                local textY = y + (layout.rowHeight - fontList:getHeight()) / 2
                love.graphics.printf(item.name, 100, textY, layout.selWidth - 80, "left")
            else
                local isActuallyFav = (global_state.favoriteRoms[item.fullPath]) and global_state.romPath ~= "@Favorites/"
                local animFactor = 0
                if isActuallyFav then animFactor = 1 end
                if i == global_state.favAnimIndex then
                    animFactor = global_state.favAnim
                end

                local favOffset = 0
                if animFactor > 0 then
                    favOffset = ((global_state.iconFavorite:getWidth() * favScale) + 10) * animFactor
                end

                local currentItemStaticWidth = helpers.calculateItemDisplayWidth(item, global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, i, favAnimState)

                local iconToDraw = nil
                if item.fullPath == "@Favorites/" then
                    iconToDraw = global_state.iconFavorite
                elseif item.icon then
                    iconToDraw = item.icon
                elseif item.system then
                    iconToDraw = utils.getSystemContentIcon(item.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                    if not iconToDraw then
                        iconToDraw = utils.getSystemIcon(item.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                    end
                end
                if not iconToDraw and item.isDir then
                    iconToDraw = utils.getSystemIcon(item.name, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                end
                if not iconToDraw then
                    iconToDraw = (item.isDir and global_state.iconFolder) or (global_state.currentSystemContentIcon or global_state.iconRom)
                end

                local targetH = 28
                local drawScale = targetH / iconToDraw:getHeight()
                if iconToDraw == global_state.iconFavorite and item.fullPath ~= "@Favorites/" then
                    drawScale = favScale
                end
                local drawY = y + (global_state.layout.rowHeight - iconToDraw:getHeight() * drawScale) / 2

                local showSystemIcons = (launchMode == "Juego Unico" and item.versions)

                local availableWidth
                if showSystemIcons then
                    local systems = {}
                    local seen = {}
                    for _, v in ipairs(item.versions) do
                        if v.system and not seen[v.system] then
                            seen[v.system] = true
                            table.insert(systems, v.system)
                        end
                    end

                    local iconSize = 20
                    local spacing = 2
                    local totalW = #systems * (iconSize + spacing) - spacing

                    local cursorRight = layout.selX + layout.selWidth
                    local startX = cursorRight - totalW - 20
                    availableWidth = startX - 85 - 10
                else
                    availableWidth = sdColX - (layout.selX + 70) - 10
                end

                if animFactor > 0 then
                    availableWidth = availableWidth - favOffset
                end

                if isLastPlayed and global_state.markPlayed then
                    love.graphics.setColor(theme.colors.list_played_unselected)
                    local adjustedH = global_state.layout.selHeight - 6
                    local adjustedY = y + (global_state.layout.rowHeight - adjustedH) / 2
                    local adjustedX = global_state.layout.selX + 3
                    local adjustedW = currentItemStaticWidth - 6

                    helpers.ditherShader:send("objPos", {adjustedX, adjustedY})
                    love.graphics.setShader(helpers.ditherShader)
                    love.graphics.stencil(function()
                        love.graphics.rectangle("fill", adjustedX, adjustedY, adjustedW, adjustedH, 22)
                    end, "replace", 1)
                    love.graphics.setStencilTest("greater", 0)
                    love.graphics.draw(helpers.getPlayedGameGradientMesh(), adjustedX, adjustedY, 0, adjustedW, adjustedH)
                    love.graphics.setStencilTest()
                    love.graphics.setShader()
                end

                love.graphics.setColor(1, 1, 1, 1)
                local iconX = layout.selX + (70 - iconToDraw:getWidth() * drawScale) / 2
                love.graphics.draw(iconToDraw, iconX, drawY, 0, drawScale, drawScale)

                local textX = layout.selX + 70

                if animFactor > 0 then
                    love.graphics.setColor(theme.colors.selection_accent)
                    local currentScale = favScale * animFactor
                    local iconH = global_state.iconFavorite:getHeight() * currentScale
                    local favIconY = y + (layout.rowHeight - iconH) / 2

                    love.graphics.draw(global_state.iconFavorite, textX, favIconY, 0, currentScale, currentScale)
                    textX = textX + (global_state.iconFavorite:getWidth() * currentScale) + 10
                end

                local nameToDraw = item.name
                if not item.isDir then
                    nameToDraw = nameToDraw:gsub("%.[^%.]+$", "")
                end

                local textColor = global_state.theme.colors.text_medium
                if i == global_state.selectedIndex then
                    textColor = theme.colors.text_bright
                elseif item.pendingDelete then
                    textColor = {0.8, 0.2, 0.2}
                elseif item.selected then
                    textColor = {0.8, 0.6, 0.3}
                end
                love.graphics.setColor(textColor)

                local cacheKeyText = tostring(availableWidth) .. "_" .. nameToDraw
                if item._textCacheVal and item._textCacheKey == cacheKeyText then
                    nameToDraw = item._textCacheVal
                else
                    if fontList:getWidth(nameToDraw) > availableWidth then
                        local avgCharW = 10
                        local maxChars = math.ceil(availableWidth / avgCharW) + 10
                        if #nameToDraw > maxChars then nameToDraw = nameToDraw:sub(1, maxChars) end

                        while fontList:getWidth(nameToDraw .. "...") > availableWidth and #nameToDraw > 0 do
                            nameToDraw = nameToDraw:sub(1, -2)
                        end
                        nameToDraw = nameToDraw .. "..."
                    end
                    item._textCacheVal = nameToDraw
                    item._textCacheKey = cacheKeyText
                end

                local textY = y + (layout.rowHeight - fontList:getHeight()) / 2

                if i == helpers.round(global_state.animatedSelectionIndex) then
                    love.graphics.print(nameToDraw, textX, textY)
                    love.graphics.print(nameToDraw, textX + 1, textY)
                else
                    love.graphics.print(nameToDraw, textX, textY)
                end

                if showSystemIcons then
                    local systems = {}
                    local seen = {}
                    for _, v in ipairs(item.versions) do
                        if v.system and not seen[v.system] then
                            seen[v.system] = true
                            table.insert(systems, v.system)
                        end
                    end

                    local iconSize = 20
                    local spacing = 2
                    local totalW = #systems * (iconSize + spacing) - spacing
                    local startX = layout.selX + layout.selWidth - totalW - 20

                    for idx, sys in ipairs(systems) do
                        local icon = utils.getSystemIcon(sys, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                        if icon then
                            local iconColor = (isLastPlayed and markPlayed and sys == playedSystem) and {0.2, 0.8, 0.3, 1} or {1, 1, 1, 1}
                            love.graphics.setColor(iconColor)
                            local scale = iconSize / icon:getHeight()
                            love.graphics.draw(icon, startX + (idx-1)*(iconSize+spacing), y + (layout.rowHeight - iconSize)/2, 0, scale, scale)
                        end
                    end
                else
                    local label = item.sourceLabel
                    if not label then
                        if global_state.romPath:find("/mnt/mmc") then label = "SD1"
                        elseif global_state.romPath:find("/mnt/sdcard") then label = "SD2"
                        elseif global_state.romPath:find("Simulador_SD") then label = "SD1" end
                    end
                    if label and label ~= "Fav" then
                    local baseColor
                    if label == "SD1" then baseColor = {0.4, 0.8, 1}
                    elseif label == "SD2" then baseColor = {1, 0.8, 0.4}
                    elseif label == "SD½" then baseColor = {0.8, 0.5, 1}
                    else baseColor = theme.colors.text_dim end

                    if i == global_state.selectedIndex then
                        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.6)
                    else
                        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 0.3)
                    end

                    love.graphics.setFont(fontSmall)
                    local labelY = y + (layout.rowHeight - fontSmall:getHeight()) / 2
                    love.graphics.printf(label, sdColX, labelY, sdColW, "center")
                    love.graphics.setFont(fontList)
                    end
                end
            end
        end
    end

    helpers.drawScrollbar(global_state)

    if global_state.files[helpers.round(global_state.animatedSelectionIndex)] then
        local item = global_state.files[global_state.selectedIndex]
        local rawName = item.name
        local nameNoExt = rawName:gsub("%.[^%.]+$", "")

        local availableWidth
        local showSystemIcons = (global_state.launchMode == "Juego Unico" and item.versions)

        if showSystemIcons then
            local systems = {}
            local seen = {}
            if item.versions then
                for _, v in ipairs(item.versions) do
                    if v.system and not seen[v.system] then
                        seen[v.system] = true
                        table.insert(systems, v.system)
                    end
                end
            end
            local iconSize = 20
            local spacing = 2
            local totalW = #systems * (iconSize + spacing) - spacing
            if totalW < 0 then totalW = 0 end

            local cursorRight = layout.selX + layout.selWidth
            local startX = cursorRight - totalW - 20
            availableWidth = startX - 85 - 10
        else
            availableWidth = sdColX - (layout.selX + 70) - 10
        end

        local isFav = (global_state.favoriteRoms[item.fullPath]) and global_state.romPath ~= "@Favorites/"
        if isFav then
            local favH = 16
            local favScale2 = favH / global_state.iconFavorite:getHeight()
            local favOffset = (global_state.iconFavorite:getWidth() * favScale2) + 5
            availableWidth = availableWidth - favOffset
        end

        if fontList:getWidth(nameNoExt) > availableWidth then
            love.graphics.setFont(fontMedium)
            local _, wrapped = fontMedium:getWrap(nameNoExt, w - 20)
            local textH = #wrapped * fontMedium:getHeight()
            local padding = 8
            local bgH = textH + padding * 2
            local bgY = h - 35 - bgH

            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, bgY, w, bgH)

            love.graphics.setColor(theme.colors.text_white)
            love.graphics.printf(nameNoExt, 10, bgY + padding, w - 20, "center")
        end
    end
end

return M
