---@diagnostic disable: undefined-global
local M = {}
local bars = require "draw_bars"
local L = _G.L

local function drawScraperLayout(x, y, w, h, img1, img2, desc, isResultView, global_state)
    local margin = 20
    local imgSpacing = 10

    local contentH = h
    local singleImgH = (contentH - imgSpacing) / 2

    local w1 = 0
    if img1 then w1 = img1:getWidth() * (singleImgH / img1:getHeight()) end

    local w2 = 0
    if img2 then w2 = img2:getWidth() * (singleImgH / img2:getHeight()) end

    local maxImgW = math.max(w1, w2)

    if maxImgW < 200 then maxImgW = 200 end

    local maxAllowedW = (w - margin * 3) * 0.70
    if maxImgW > maxAllowedW then maxImgW = maxAllowedW end

    local leftW = maxImgW
    local rightW = w - margin * 3 - leftW

    local leftX = x + margin
    local rightX = leftX + leftW + margin

    love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], 0.5)
    love.graphics.rectangle("line", leftX, y, leftW, singleImgH, 12)

    if img1 then
        love.graphics.setColor(1, 1, 1)
        local scale = math.min(leftW / img1:getWidth(), singleImgH / img1:getHeight())
        local iw = img1:getWidth() * scale
        local ih = img1:getHeight() * scale
        local ix = leftX + (leftW - iw)/2
        local iy = y + (singleImgH - ih)/2

        love.graphics.stencil(function()
            love.graphics.rectangle("fill", leftX, y, leftW, singleImgH, 12)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        love.graphics.draw(img1, ix, iy, 0, scale, scale)
        love.graphics.setStencilTest()
    else
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(L.get("front"), leftX, y + singleImgH/2 - 10, leftW, "center")
    end

    local screenY = y + singleImgH + imgSpacing
    love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], 0.5)
    love.graphics.rectangle("line", leftX, screenY, leftW, singleImgH, 12)

    if img2 then
        love.graphics.setColor(1, 1, 1)
        local scale = math.min(leftW / img2:getWidth(), singleImgH / img2:getHeight())
        local iw = img2:getWidth() * scale
        local ih = img2:getHeight() * scale
        local ix = leftX + (leftW - iw)/2
        local iy = screenY + (singleImgH - ih)/2

        love.graphics.stencil(function()
            love.graphics.rectangle("fill", leftX, screenY, leftW, singleImgH, 12)
        end, "replace", 1)
        love.graphics.setStencilTest("greater", 0)
        love.graphics.draw(img2, ix, iy, 0, scale, scale)
        love.graphics.setStencilTest()
    else
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(L.get("screen"), leftX, screenY + singleImgH/2 - 10, leftW, "center")
    end

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(theme.colors.text_medium)
    local d = desc
    if not d or d == "" then d = L.get("no_info") end
    love.graphics.printf(d, rightX, y, rightW, "left")

    if not isResultView then
        local btnH = 40
        local btnY = y + contentH - btnH
        local spacing2 = 10
        local btnW = (rightW - spacing2) / 2

        love.graphics.setFont(fontMedium)
        if global_state.scraperSelection == 1 then
            love.graphics.setColor(theme.colors.selection_accent)
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.rectangle("fill", rightX, btnY, btnW, btnH, 8)

        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("search_data"), rightX, btnY + (btnH - fontMedium:getHeight())/2, btnW, "center")

        local optX = rightX + btnW + spacing2
        if global_state.scraperSelection == 2 then
            love.graphics.setColor(theme.colors.selection_accent)
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.rectangle("fill", optX, btnY, btnW, btnH, 8)

        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("options"), optX, btnY + (btnH - fontMedium:getHeight())/2, btnW, "center")
    end
end

local function drawScraperSelector(x, y, w, h, isFocused, index, total, drawContentFunc)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x, y, w, h, 8)

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", x, y, w, h, 8)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    drawContentFunc(x, y, w, h)
    love.graphics.setStencilTest()

    if isFocused then
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(theme.colors.side_menu_separator)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, w, h, 8)
    love.graphics.setLineWidth(1)

    if total > 1 then
        local indText = index .. "/" .. total
        love.graphics.setFont(fontSmall)
        local tw = fontSmall:getWidth(indText) + 10
        local th = fontSmall:getHeight() + 4

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x + w - tw - 5, y + h - th - 5, tw, th, 4)

        if isFocused then
            love.graphics.setColor(theme.colors.selection_accent)
        else
            love.graphics.setColor(theme.colors.text_dim)
        end
        love.graphics.print(indText, x + w - tw - 5 + 5, y + h - th - 5 + 2)
    end
end

local function drawScraperEditor(global_state, x, y, w, h)
    local results = global_state.scraperResults
    local total = #results
    if total == 0 then return end

    local colSpacing = 20

    local leftW = w * 0.35
    local rightW = w - leftW - colSpacing

    local imgSpacing = 10
    local topH = (h - imgSpacing) * 0.55
    local botH = h - topH - imgSpacing

    local hasFronts = false
    local hasScreens = false
    for _, r in ipairs(results) do
        if r.imagePath then hasFronts = true end
        if r.screenshotPath then hasScreens = true end
    end

    local frontRes = results[global_state.scraperFrontIndex]
    drawScraperSelector(x, y, leftW, topH, global_state.scraperFocus == "FRONT", global_state.scraperFrontIndex, hasFronts and total or 1, function(bx, by, bw, bh)
        if frontRes and frontRes.image then
            love.graphics.setColor(1, 1, 1)
            local scale = math.min(bw / frontRes.image:getWidth(), bh / frontRes.image:getHeight())
            local iw = frontRes.image:getWidth() * scale
            local ih = frontRes.image:getHeight() * scale
            love.graphics.draw(frontRes.image, bx + (bw - iw)/2, by + (bh - ih)/2, 0, scale, scale)
        else
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_dim)
            love.graphics.printf(L.get("front"), bx, by + bh/2 - 10, bw, "center")
        end
    end)

    local screenRes = results[global_state.scraperScreenIndex]
    drawScraperSelector(x, y + topH + imgSpacing, leftW, botH, global_state.scraperFocus == "SCREEN", global_state.scraperScreenIndex, hasScreens and total or 1, function(bx, by, bw, bh)
        if screenRes and screenRes.screenshot then
            love.graphics.setColor(1, 1, 1)
            local scale = math.min(bw / screenRes.screenshot:getWidth(), bh / screenRes.screenshot:getHeight())
            local iw = screenRes.screenshot:getWidth() * scale
            local ih = screenRes.screenshot:getHeight() * scale
            love.graphics.draw(screenRes.screenshot, bx + (bw - iw)/2, by + (bh - ih)/2, 0, scale, scale)
        else
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_dim)
            love.graphics.printf(L.get("screen"), bx, by + bh/2 - 10, bw, "center")
        end
    end)

    local textRes = results[global_state.scraperTextIndex]
    drawScraperSelector(x + leftW + colSpacing, y, rightW, h, global_state.scraperFocus == "TEXT", global_state.scraperTextIndex, total, function(bx, by, bw, bh)
        local padding = 15
        local tx = bx + padding
        local ty = by + padding
        local tw = bw - padding * 2

        if textRes then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.selection_accent)
            local sourceText = (textRes.region or "") .. (textRes.source and (" [" .. textRes.source .. "]") or "")
            love.graphics.printf(sourceText, tx, ty, tw, "left")
            ty = ty + fontSmall:getHeight() + 5

            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_medium)
            local desc = textRes.description or L.get("no_desc")
            love.graphics.printf(desc, tx, ty, tw, "left")
        else
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_dim)
            love.graphics.printf(L.get("no_info"), tx, ty, tw, "center")
        end
    end)
end

function M.drawScraperView(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    local currentItem = global_state.focusedItem or global_state.files[global_state.selectedIndex]
    if not currentItem then return end

    local mainName = currentItem.name:gsub("%.[^%.]+$", "")
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(mainName, 0, 15, w, "center")

    local sysName = utils.getSystemNameForItem(currentItem)
    local displayName = utils.getSystemDisplayName(sysName)
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim)
    love.graphics.printf(displayName or "System", 0, 50, w, "center")

    if global_state.state == "SCRAPER_VIEW" then
        local topY = 80
        local bottomBarH = 30
        local availableH = h - topY - bottomBarH - 10
        drawScraperLayout(0, topY, w, availableH, global_state.currentImage, global_state.currentScreenshot, global_state.currentDescription, false, global_state)

    elseif global_state.state == "SCRAPING_IN_PROGRESS" then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_white)

        local progressY = h/2 - fontMedium:getHeight()/2

        if global_state.scraperWarningMessage ~= "" and global_state.scraperWarningTimer > 0 then
            local totalBlockHeight = fontMedium:getHeight() + 5 + fontSmall:getHeight()
            progressY = h/2 - totalBlockHeight/2

            love.graphics.setFont(fontSmall)
            love.graphics.setColor(1, 0.4, 0.4)
            local warningY = progressY + fontMedium:getHeight() + 5
            love.graphics.printf(global_state.scraperWarningMessage, 0, warningY, w, "center")

            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_white)
        end
        love.graphics.printf(global_state.scraperProgressMessage, 0, progressY, w, "center")

    elseif global_state.state == "BATCH_SCRAPING" then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scraping_batch"), 0, h/2 - 60, w, "center")

        love.graphics.setFont(fontMedium)
        love.graphics.printf(L.get("processing", global_state.scraperProgress.currentName), 0, h/2 - 20, w, "center")

        local barW = 400
        local barX = (w - barW) / 2
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW * (global_state.scraperProgress.current / global_state.scraperProgress.total), 20)

        love.graphics.printf(global_state.scraperProgress.current .. " / " .. global_state.scraperProgress.total, 0, h/2 + 50, w, "center")
        love.graphics.printf(L.get("successes_failures", global_state.scraperProgress.successes, global_state.scraperProgress.failures), 0, h/2 + 80, w, "center")

    elseif global_state.state == "SCRAPER_RESULTS" then
        love.graphics.setFont(fontMedium)
        love.graphics.printf(L.get("results"), 20, 60, w, "left")

        if #global_state.scraperResults == 0 then
            love.graphics.printf(L.get("no_results"), 20, 100, w, "left")
        else
            local topY = 90
            local bottomBarH = 30
            local availableH = h - topY - bottomBarH - 10
            drawScraperEditor(global_state, 20, topY, w - 40, availableH)
        end
    end

    bars.drawBottomBar(global_state)
end

return M
