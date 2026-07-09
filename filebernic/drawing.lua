---@diagnostic disable: undefined-global
local helpers = require "draw_helpers"
local bars = require "draw_bars"
local menus = require "draw_menus"
local scraper = require "draw_scraper"
local views = require "draw_views"
local list = require "draw_list"
local unpack = table.unpack or unpack
local L = _G.L

local function draw(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if global_state.state == "SCRAPER_VIEW" or global_state.state == "SCRAPING_IN_PROGRESS" or global_state.state == "SCRAPER_RESULTS" or global_state.state == "SCRAPER_OPTIONS" then
        scraper.drawScraperView(global_state)
        if global_state.state == "SCRAPER_OPTIONS" or global_state.closingMenu then
            menus.drawOverlayMenus(global_state)
        end
        menus.drawOverlayMenus(global_state)
        return
    end

    if global_state.state == "SAVE_MANAGER" then
        views.drawSaveManager(global_state)
        menus.drawOverlayMenus(global_state)
        return
    end

    if global_state.state == "CLEANUP_MENU" then
        views.drawCleanupMenu(global_state)
        menus.drawOverlayMenus(global_state)
        return
    end

    layout.scrollbarX = w - 2
    layout.scrollbarH = h - layout.listY - 30

    local margin = 30
    layout.selX = margin
    layout.selWidth = (w - margin) - layout.selX

    local sdColW = 40
    local cursorRight = layout.selX + layout.selWidth
    local sdColX = cursorRight - sdColW - 20

    local showPreview = (global_state.currentImage ~= nil or global_state.currentScreenshot ~= nil)
    local previewBoxW = 200

    if showPreview then
        local maxPreviewW = w * 0.5
        local availableH = h - layout.listY - 40

        local ar1 = global_state.currentImage and (global_state.currentImage:getWidth() / global_state.currentImage:getHeight()) or 0
        local ar2 = global_state.currentScreenshot and (global_state.currentScreenshot:getWidth() / global_state.currentScreenshot:getHeight()) or 0
        local padding = (global_state.currentImage and global_state.currentScreenshot) and 15 or 0

        local calculatedW = maxPreviewW

        if global_state.currentImage and global_state.currentScreenshot then
            local combinedInvAr = (1/ar1) + (1/ar2)
            calculatedW = (availableH - padding) / combinedInvAr
        elseif global_state.currentImage then
             calculatedW = availableH * ar1
        elseif global_state.currentScreenshot then
             calculatedW = availableH * ar2
        end

        previewBoxW = math.min(maxPreviewW, calculatedW)
        previewBoxW = math.max(100, previewBoxW)
    end

    local previewBoxX = sdColX - previewBoxW - 10
    if global_state.romPath == "@Favorites/" then
         previewBoxX = layout.scrollbarX - previewBoxW - 10
    end

    if global_state.launchMode == "Juego Unico" and global_state.isVirtualRoot and not global_state.romIndex and #global_state.files == 0 then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("indexing"), 0, h/2 - 20, w, "center")
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        local msg = global_state.isIndexing and global_state.indexStateMessage or L.get("loading_index")
        love.graphics.printf(msg, 0, h/2 + 20, w, "center")

        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.setFont(fontTopBar)
        love.graphics.printf(L.get("app_title"), 0, 15, w, "center")
        love.graphics.setFont(fontClock)
        love.graphics.print(os.date("%H:%M"), 20, 17)
        helpers.drawBattery(global_state, w - 25, 20)
        love.graphics.setFont(global_state.fontSmall)
        local displayPath = global_state.isVirtualRoot and global_state.L.get("all_systems") or global_state.romPath
        if not global_state.isVirtualRoot then
            local shortened = displayPath:match("ROMS/.*")
            if shortened then
                displayPath = shortened
            elseif displayPath:find("Simulador_SD") then
                displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
            end
        end
        love.graphics.printf(displayPath, 0, 45, w, "center")

        menus.drawOverlayMenus(global_state)

        bars.drawBottomBar(global_state)
        return
    end

    if #global_state.files == 0 and not global_state.isIndexing then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(L.get("no_items"), 0, h/2, w, "center")
    end

    list.drawMainList(global_state, w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)

    if not helpers.bottomGradientMesh then
        local r, g, b = unpack(theme.colors.background)
        local gradientLength = 20
        local opaquePercentage = 40
        local w_screen, _ = love.graphics.getDimensions()
        local vertices = utils.createGradientVertices("bottom", opaquePercentage, gradientLength, w_screen, r, g, b, 1.0)
        helpers.bottomGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    love.graphics.setColor(1, 1, 1, 1)
    local bottomY = h - 30 - 20
    helpers.ditherShader:send("objPos", {0, bottomY})
    love.graphics.setShader(helpers.ditherShader)
    love.graphics.draw(helpers.bottomGradientMesh, 0, bottomY)
    love.graphics.setShader()

    if not helpers.topGradientMesh then
        local r, g, b = unpack(theme.colors.background)
        local topBarHeight = layout.listY
        local fadeLength = 54
        local gradientLength = topBarHeight + fadeLength
        local opaquePercentage = 50
        local w_screen, _ = love.graphics.getDimensions()
        local vertices = utils.createGradientVertices("top", opaquePercentage, gradientLength, w_screen, r, g, b, 1.0)
        helpers.topGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    love.graphics.setColor(1, 1, 1, 1)
    helpers.ditherShader:send("objPos", {0, 0})
    love.graphics.setShader(helpers.ditherShader)
    love.graphics.draw(helpers.topGradientMesh, 0, 0)
    love.graphics.setShader()

    bars.drawTopBar(global_state, w, h)

    love.graphics.setFont(fontSmall)
    local displayPath = global_state.isVirtualRoot and global_state.L.get("all_systems") or global_state.romPath
    if not global_state.isVirtualRoot then
        local shortened = displayPath:match("ROMS/.*")
        if shortened then
            displayPath = shortened
        elseif displayPath:find("Simulador_SD") then
            displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
        end
    end
    love.graphics.printf(displayPath, 0, 45, w, "center")

    menus.drawOverlayMenus(global_state)

    bars.drawBottomBar(global_state)

    helpers.drawJumpLetter(global_state)

    if global_state.state == "SEARCH" or global_state.state == "EDIT_TEXT" or global_state.keyboardAnim > 0 then
        local t = global_state.keyboardAnim
        local ease = 1 - (1 - t)^3
        local panelH = 250
        local currentY = h - (panelH * ease)

        love.graphics.setColor(0, 0, 0, 0.9 * ease)
        love.graphics.rectangle("fill", 0, currentY, w, panelH)

        local r, g, b2 = unpack(global_state.theme.colors.text_white)
        love.graphics.setColor(r, g, b2, ease)
        love.graphics.setFont(fontTitle)
        if global_state.state == "EDIT_TEXT" then
            love.graphics.printf(global_state.textEditLabel .. ": " .. global_state.textToEdit .. "_", 20, currentY + 10, w - 40, "left")
        else
            love.graphics.printf(L.get("search_label", global_state.searchQuery), 20, currentY + 10, w - 40, "left")
        end

        love.graphics.setFont(fontMedium)
        local keySize = 40
        local spacing = 5
        local startY = currentY + 50

        local mainBlockWidth = 10 * (keySize + spacing) - spacing
        local mainBlockStartX = (w - 100 - mainBlockWidth) / 2
        if mainBlockStartX < 10 then mainBlockStartX = 10 end

        for rowIdx, row in ipairs(global_state.keyboardGrid) do
            for colIdx, key in ipairs(row) do
                local x, y, kW, kH

                if key == "SPACE" or key == "BACK" or key == "OK" then
                    kW = 80
                    kH = keySize
                    x = w - kW - 20
                    y = startY + (rowIdx-1) * (keySize + spacing)
                else
                    kW = keySize
                    kH = keySize
                    x = mainBlockStartX + (colIdx-1) * (keySize + spacing)
                y = startY + (rowIdx-1) * (keySize + spacing)
                    if rowIdx == 3 then x = x + (keySize/2) end
                    if rowIdx == 4 then x = x + (keySize/2) end
                end

                local col
                if rowIdx == global_state.keyboardRow and colIdx == global_state.keyboardCol then
                    col = theme.colors.selection_accent
                else
                    col = theme.colors.placeholder_background
                end
                local cr, cg, cb = unpack(col)
                love.graphics.setColor(cr, cg, cb, ease)
                love.graphics.rectangle("fill", x, y, kW, kH, 5)

                local tr, tg, tb = unpack(theme.colors.text_white)
                love.graphics.setColor(tr, tg, tb, ease)
                love.graphics.printf(key, x, y + 10, kW, "center")
            end
        end
    end

    if global_state.isIndexing then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.selection_accent)

        local current_time = love.timer.getTime()
        local blink = (math.sin(current_time * 8) + 1) / 2

        love.graphics.setColor(theme.colors.selection_accent[1], theme.colors.selection_accent[2], theme.colors.selection_accent[3], blink)
        love.graphics.print("•", w - 30, 5)
    end
end

return draw
