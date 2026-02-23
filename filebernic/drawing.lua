---@diagnostic disable: undefined-global
-- Define a local round function for compatibility with older Lua versions
local round = math.round or love.math.round or function(x)
    return math.floor(x + 0.5)
end

-- Fallback lerp function if love.math.lerp is not available
local lerp = love.math.lerp or function(a, b, t)
    return a + (b - a) * t
end

local utils = require "utils"
local unpack = table.unpack or unpack
local L = _G.L -- Access global L for localization
local ditherShader = love.graphics.newShader[[
    extern vec2 objPos;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 p = floor((screen_coords.xy - objPos) / 3.0);
        int x = int(mod(p.x, 4.0));
        int y = int(mod(p.y, 4.0));
        float t = 0.0;
        
        // Matriz Bayer 4x4 manual para compatibilidad
        if (x == 0) { if (y == 0) t = 0.0; else if (y == 1) t = 12.0; else if (y == 2) t = 3.0; else t = 15.0; }
        else if (x == 1) { if (y == 0) t = 8.0; else if (y == 1) t = 4.0; else if (y == 2) t = 11.0; else t = 7.0; }
        else if (x == 2) { if (y == 0) t = 2.0; else if (y == 1) t = 14.0; else if (y == 2) t = 1.0; else t = 13.0; }
        else { if (y == 0) t = 10.0; else if (y == 1) t = 6.0; else if (y == 2) t = 9.0; else t = 5.0; }
        
        if (color.a <= (t / 16.0)) {
            discard;
        }
        return vec4(color.rgb, 1.0);
    }
]]

local gradientMesh
local function getGradientMesh()
    if not gradientMesh then
        local vertices = {
            {0, 0, 0, 0, 1, 1, 1, 0}, -- Izquierda: Transparente
            {1, 0, 1, 0, 1, 1, 1, 1}, -- Derecha: Opaco (se teñirá de negro)
            {1, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 0, 1, 1, 1, 1, 0}
        }
        gradientMesh = love.graphics.newMesh(vertices, "fan", "static")
    end
    return gradientMesh
end

local fadeGradientMesh
local function getFadeGradientMesh()
    if not fadeGradientMesh then
        local vertices = {
            {0, 0, 0, 0, 1, 1, 1, 1}, -- Izquierda: Opaco
            {0, 1, 0, 1, 1, 1, 1, 1},
            {0.15, 0, 0.15, 0, 1, 1, 1, 1}, -- 15%: Sigue Opaco
            {0.15, 1, 0.15, 1, 1, 1, 1, 1},
            {0.85, 0, 0.85, 0, 1, 1, 1, 0}, -- 85%: Transparente
            {0.85, 1, 0.85, 1, 1, 1, 1, 0},
            {1, 0, 1, 0, 1, 1, 1, 0}, -- Derecha: Transparente (relleno)
            {1, 1, 1, 1, 1, 1, 1, 0}
        }
        fadeGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    return fadeGradientMesh
end

local topGradientMesh = nil -- Cache for the top gradient mesh
local bottomGradientMesh = nil -- Cache for the bottom gradient mesh

local function drawTrimmed(text, x, y, limit, font)
    local dText = text
    if font:getWidth(dText) > limit then
        while font:getWidth(dText .. "...") > limit and #dText > 0 do
            dText = dText:sub(1, -2)
        end
        dText = dText .. "..."
    end
    love.graphics.print(dText, x, y)
end

-- Helper function to calculate the display width of a list item
-- This logic was previously duplicated or implicitly calculated.
local function calculateItemDisplayWidth(item, layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX, itemIndex, favAnimState)
    if not item then return layout.selWidth + 2 end -- Default width if item is nil
    
    local isActuallyFav = (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/"
    local isAnimating = favAnimState and itemIndex and itemIndex == favAnimState.index

    -- OPTIMIZACIÓN: Caché para evitar recálculos costosos cada frame
    if not isAnimating then
        local cacheKey = tostring(launchMode) .. "_" .. tostring(isActuallyFav) .. "_" .. tostring(sdColX)
        if item._widthCacheVal and item._widthCacheKey == cacheKey then
            return item._widthCacheVal
        end
    end
    
    local nameToMeasure = item.name
    if not item.isDir then
        nameToMeasure = nameToMeasure:gsub("%.[^%.]+$", "")
    end

    local animFactor = 0
    if isActuallyFav then animFactor = 1 end
    if isAnimating then
        animFactor = favAnimState.anim
    end

    local itemFavOffset = 0
    if animFactor > 0 then
        itemFavOffset = ((iconFavorite:getWidth() * favScale) + 10) * animFactor
    end

    local calculatedWidth = layout.selWidth
    if (launchMode == "Folder" or launchMode == "Juego Unico") then
        -- Use sdColX if available, otherwise calculate a reasonable default
        local textRightBoundary = sdColX or (layout.selX + layout.selWidth)
        local tempAvailableWidth = textRightBoundary - (layout.selX + 70) - 10

        local trimmedName = nameToMeasure
        if fontList:getWidth(trimmedName) > tempAvailableWidth then
            -- Pre-recorte estimativo para evitar bucles largos
            local avgCharW = 10 -- Estimación conservadora
            local maxChars = math.ceil(tempAvailableWidth / avgCharW) + 10
            if #trimmedName > maxChars then trimmedName = trimmedName:sub(1, maxChars) end
            
            while fontList:getWidth(trimmedName .. "...") > tempAvailableWidth and #trimmedName > 0 do
                trimmedName = trimmedName:sub(1, -2)
            end
            trimmedName = trimmedName .. "..."
        end
        local textW = fontList:getWidth(trimmedName)
        calculatedWidth = 70 + itemFavOffset + textW + 20
        if calculatedWidth > layout.selWidth then calculatedWidth = layout.selWidth end
    end
    
    -- Guardar en caché
    if not isAnimating then
        item._widthCacheVal = calculatedWidth + 2
        item._widthCacheKey = tostring(launchMode) .. "_" .. tostring(isActuallyFav) .. "_" .. tostring(sdColX)
    end
    return calculatedWidth + 2
end

local function drawBottomBar(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.bottom_bar_background)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(theme.colors.text_bright)
    
    local barCenterY = h - 15
    local textH = fontMedium:getHeight()
    local textY = barCenterY - textH / 2
    
    -- Altura deseada en píxeles para los iconos en la barra inferior.
    -- Esto asegura que se vean del mismo tamaño en cualquier resolución.
    local desiredIconHeight = 22
    local x = 20

    local function drawHint(icon, text)
        local scale = desiredIconHeight / icon:getHeight()
        local iconY = barCenterY - (icon:getHeight() * scale) / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
        x = x + love.graphics.getFont():getWidth(text) + 20
    end

    if global_state.state == "LIST" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
        drawHint(global_state.buttonIcons.y, global_state.L.get("options"))
        -- drawHint(buttonIcons.start, L.get("config")) -- Eliminado según la solicitud
        -- Select button with offset
        local icon = global_state.buttonIcons.select
        local scale = desiredIconHeight / icon:getHeight()
        local text = global_state.L.get("exit")
        local iconY = barCenterY - (icon:getHeight() * scale) / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
    elseif global_state.state == "DELETE_MENU" or global_state.state == "POST_GAME" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("confirm"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("cancel"))
    elseif global_state.state == "INFO_VIEW" then
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "OPTIONS_MENU" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept")) -- Always "Accept" in menus
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
        drawHint(global_state.buttonIcons.r1, global_state.L.get("help"))
        drawHint(global_state.buttonIcons.select, global_state.L.get("exit"))
    elseif global_state.state == "SCRAPER_VIEW" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "EDIT_TEXT" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("cancel"))
    elseif global_state.state == "SCRAPER_OPTIONS" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "SCRAPER_RESULTS" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("save"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "SAVE_MANAGER" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("copy"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "CLEANUP_MENU" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("delete"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    end
end

local function drawMenuContent(global_state, title, message, options, selection, item, x, w, h, alpha, isFocused, dimProgress, isFile)
    -- Header Logic
    local startY = 90
    local isGameOptions = false
    local mainName = ""
    local iconWidth = 0
    local iconSize = 32 -- Tamaño original del icono
    local sysName = nil

    -- Panel lateral
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)
    
    -- Línea separadora
    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    if item and (title:match("^" .. L.get("options")) and message == item.name) then
        isGameOptions = true
        local name = message
        mainName = name
        local pStart = name:find("%s*%(") -- find parenthesis with optional space
        if pStart then -- If parenthesis found
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
        end
        sysName = utils.getSystemNameForItem(item)
    end

    if isGameOptions then
        -- Header Personalizado para Juego
        local name = message
        local mainName = name:gsub("%.[^%.]+$", ""):gsub("%s*$", "") -- Quitar extensión y espacios
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
        
        -- Lógica para carátula a la izquierda del título
        local coverW, coverH = 0, 0
        local titleAvailW = w - 40 -- Ancho total del panel menos paddings laterales
        local maxCoverW = 80
        
        if global_state.currentImage then
            titleX = baseTextX + maxCoverW + 10
            titleAvailW = w - (baseTextX - x) - (maxCoverW + 10) - 20 -- panel_width - left_margin - cover_width - cover_margin - right_margin
        end

        -- Obtener el texto del título envuelto y su altura
        local _, wrappedMain = fontTitle:getWrap(mainName, titleAvailW)
        local visibleLines = math.min(#wrappedMain, 2)
        local mainH = visibleLines * fontTitle:getHeight()
        
        -- Draw cover art
        if global_state.currentImage then
            love.graphics.setColor(1, 1, 1)
            local maxH = 120
            local coverScale = math.min(maxCoverW / global_state.currentImage:getWidth(), maxH / global_state.currentImage:getHeight())
            
            coverW = global_state.currentImage:getWidth() * coverScale
            coverH = global_state.currentImage:getHeight() * coverScale
            
            -- Centrar imagen en su slot de 80px
            love.graphics.draw(currentImage, baseTextX + (maxCoverW - coverW)/2, headerY, 0, coverScale, coverScale)
        end
        
        -- Dibujar el texto del título
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
        -- Calcular la altura total del contenido para el encabezado
        local contentH = math.max(mainH, coverH)
        
        -- Preparar y dibujar el nuevo subtítulo
        local regionInfo = extraInfo:gsub("%.[^%.]+$", "") -- remove extension
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
        -- Header Estándar
        love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
        love.graphics.setFont(fontTitle)
        love.graphics.printf(title, x + 20, 40, w - 40, "left")

        if message and message ~= "" then
            love.graphics.setFont(global_state.fontMedium)
            love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
            love.graphics.printf(message, x + 20, 80, w - 40, "left")
            local width, wrappedtext = global_state.fontMedium:getWrap(message, w - 40)
            startY = 80 + (#wrappedtext * global_state.fontMedium:getHeight()) + 30
        end
    end

    -- Opciones
    love.graphics.setFont(fontMedium)
    local rowHeight = 40
    for i, option in ipairs(options) do
        local rowY = startY + (i-1) * rowHeight
        local centerY = rowY + rowHeight / 2
        
        local text = type(option) == "table" and option.text or option
        local icon = type(option) == "table" and option.icon or nil
        
        local labelColor, valueColor

        if i == selection then
            if isFocused then -- If menu is focused
                local c = theme.colors.selection_accent
                love.graphics.setColor(c[1], c[2], c[3], alpha)
            else -- If menu is not focused
                love.graphics.setColor(0.3, 0.3, 0.3, alpha) -- Selección gris en menú inactivo
            end
            love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            labelColor = theme.colors.text_white
            valueColor = theme.colors.text_white
        else
            if type(option) == "table" and option.played and markPlayed then
                local c = theme.colors.list_played_unselected -- Color for unselected played item
                love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
                love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            end

            if text:find(global_state.L.get("delete")) then
                labelColor = {1, 0.4, 0.4} -- Rojo suave
            elseif text:find(global_state.L.get("cleanup")) then
                labelColor = {0.8, 0.1, 0.1} -- Rojo oscuro
            else
                labelColor = theme.colors.text_dim
            end
            valueColor = theme.colors.selection_accent -- Otro tono (Azul claro)
        end

        local label, value = text:match("^(.-):%s*(.+)$")

        local textY = centerY - fontMedium:getHeight() / 2

        -- Aplicar alpha a los colores de texto
        local lc = {labelColor[1], labelColor[2], labelColor[3], (labelColor[4] or 1) * alpha}
        local vc = {valueColor[1], valueColor[2], valueColor[3], (valueColor[4] or 1) * alpha}

        local textX = x + 20
        
        local iconSlotW = 30
        local slotSpacing = 5
        local marginRight = 20

        local function drawIconCentered(img, slotIdx, color)
             if not img then return end -- Don't draw if image is nil
             local iconH = 18
             if img == iconReload then iconH = 15 end
             
             local scale = iconH / img:getHeight()
             local iconW = img:getWidth() * scale
             
             local slotCenterX
             if slotIdx == 2 then -- Rightmost
                 slotCenterX = x + w - marginRight - (iconSlotW / 2)
             else -- Left of Rightmost
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
            drawTrimmed(text, textX, textY, w - (textX - x) - rightMargin, fontMedium)
        end
    end

    if not isFocused then
        local dp = dimProgress or 1
        -- Oscurecer todo el panel si no tiene foco
        love.graphics.setColor(0, 0, 0, 0.5 * alpha * dp)
        love.graphics.rectangle("fill", x, 0, w, h)
        love.graphics.setColor(0, 0, 0, 0.5 * alpha * dp)
        love.graphics.draw(getGradientMesh(), x, 0, 0, w, h)
    end
end

local function calculateMenuWidth(global_state, title, message, options, item, isGameOptions)
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    local optionsMaxW = 0
    for _, opt in ipairs(options) do
        local text = type(opt) == "table" and opt.text or opt
        local width = 0
        
        local label, val = text:match("^(.-):%s*(.+)$")
        if text == L.get("add_favorite") or text == L.get("remove_favorite") then
            -- Stabilize width for favorite toggle to prevent panel resizing
            local addWidth = fontMedium:getWidth(L.get("add_favorite"))
            local removeWidth = fontMedium:getWidth(L.get("remove_favorite"))
            width = math.max(addWidth, removeWidth)
        elseif label and (val == global_state.L.get("on") or val == global_state.L.get("off") or val == global_state.L.get("yes") or val == global_state.L.get("no")) then
            -- Stabilize width for switches (prevents panel from changing size between ON/OFF)
             width = fontMedium:getWidth(label .. ":") + 50 -- Ancho etiqueta + espacio fijo para icono
        elseif label == global_state.L.get("view") then
             width = fontMedium:getWidth(label .. ":") + 80 -- Espacio para dos iconos
        elseif label == L.get("mode") then
             width = fontMedium:getWidth(label .. ":") + 80 -- Espacio para dos iconos
        else
             width = fontMedium:getWidth(text)
        end

        if type(opt) == "table" and opt.icon then width = width + 35 end
        if width > optionsMaxW then optionsMaxW = width end
    end

    local mainName = title
    local coverSpace = 0
    
    if isGameOptions and message then
        -- Usar el nombre real del juego para el cálculo, no "Opciones"
        local name = message -- Use message as name
        mainName = name:gsub("%.[^%.]+$", ""):gsub("%s*$", "")
        local pStart = name:find("%s*%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
        end
        
        if global_state.currentImage then
            -- Espacio reservado para carátula (80px) + margen (10px)
            coverSpace = 90
        end
    end
    
    local titleRequiredW = fontTitle:getWidth(mainName) + 40 + coverSpace
    
    -- Minimum width is larger if there's cover art to prevent it from being too cramped
    local minW = (isGameOptions and global_state.currentImage) and 320 or 200
    
    local calculatedW = math.max(minW, optionsMaxW + 60, titleRequiredW)
    
    return math.min(w * 0.75, calculatedW)
end

local function drawHelpPanel(global_state, x, w, h, alpha)
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)
    
    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    local contentX = x
    love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
    love.graphics.setFont(global_state.fontTitle)
    love.graphics.printf("Ayuda - Controles", contentX + 20, 40, w - 40, "left") -- Help title
    
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
        local iconW = item.icon:getWidth() * iconScale -- Icon width

        love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
        love.graphics.print(global_state.L.get(item.text), contentX + 20, textY)
        love.graphics.draw(item.icon, contentX + w - 20 - iconW, iconY, 0, iconScale, iconScale)
    end
end

local function drawMediaDetailContent(global_state, currentItem, x, y, w, h, alpha)
    local regionInfo = ""
    local pStart = currentItem.name:find("%(")
    if pStart then regionInfo = currentItem.name:sub(pStart) end

    local sysName = utils.getSystemNameForItem(currentItem)
    local displayName = utils.getSystemDisplayName(sysName)
    local subtitle = (displayName or "Desconocido") .. " " .. regionInfo
    
    local coverImg = global_state.currentImage -- Puede ser nil

    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
    love.graphics.printf(subtitle, x, y + 55, w, "center")

    local contentY = y + 100
    local imagesY = contentY + fontMedium:getHeight() + 15
    local availableH = h - imagesY - 40 - 120
    
    local spacing = 20
    local coverW, screenW = 0, 0
    local finalImageH = 0
    
    -- Relaciones de aspecto por defecto si no hay imagen (Boxart ~0.7, Screen ~1.33)
    local ar1 = coverImg and (coverImg:getWidth() / coverImg:getHeight()) or 0.7
    local ar2 = global_state.currentScreenshot and (global_state.currentScreenshot:getWidth() / global_state.currentScreenshot:getHeight()) or 1.33
    
    local totalAvailW = w - 40
    -- Calcular altura asumiendo que mostramos ambos espacios
    local heightForWidth = (totalAvailW - spacing) / (ar1 + ar2)
    finalImageH = math.min(availableH, heightForWidth)
    
    coverW = finalImageH * ar1
    screenW = finalImageH * ar2

    local totalW = coverW + spacing + screenW
    local startX = x + (w - totalW) / 2
    local drawY = imagesY + (availableH - finalImageH) / 2 -- Y position to draw images
    local placeholderRadius = 12
    
    love.graphics.setFont(fontMedium)
    
    -- Dibujar Boxart (o placeholder)
    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local frontText = global_state.L.get("front")
    local textW = fontMedium:getWidth(frontText)
    love.graphics.print(frontText, startX + (coverW - textW) / 2, contentY)
    
    -- Marco redondeado para Boxart
    love.graphics.setColor(theme.colors.side_menu_separator[1], theme.colors.side_menu_separator[2], theme.colors.side_menu_separator[3], alpha * 0.5)
    love.graphics.rectangle("line", startX, drawY, coverW, finalImageH, placeholderRadius)

    if coverImg then
        love.graphics.setColor(1, 1, 1, alpha * (global_state.currentImage and global_state.currentImageAlpha or 1))
        local coverScale = finalImageH / coverImg:getHeight()
        -- Centrar imagen dentro del marco si la relación de aspecto difiere ligeramente
        local imgW = coverImg:getWidth() * coverScale
        local imgX = startX + (coverW - imgW) / 2
        love.graphics.draw(coverImg, imgX, drawY, 0, coverScale, coverScale)
    end

    -- Dibujar Screenshot (o placeholder)
    local drawX = startX + coverW + spacing
    
    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local screenText = global_state.L.get("screen")
    local textW2 = fontMedium:getWidth(screenText)
    love.graphics.print(screenText, drawX + (screenW - textW2) / 2, contentY)
    
    -- Marco redondeado para Screenshot
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
    local descText = (currentDescription and currentDescription ~= "") and currentDescription or L.get("no_info")
    love.graphics.printf(descText, x + 20, textY + 25, w - 40, "left")

    if not coverImg and not global_state.currentScreenshot and descText == L.get("no_info") then
        love.graphics.setColor(global_state.theme.colors.text_medium[1], global_state.theme.colors.text_medium[2], global_state.theme.colors.text_medium[3], alpha)
        love.graphics.printf(global_state.L.get("no_images_info"), x, y + h/2, w, "center")
    end
end

local function drawInfoPanel(global_state, item, x, w, h, alpha)
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha) -- Background color
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

    drawMediaDetailContent(global_state, item, x, 0, w, h, alpha)
end

local function drawOverlayMenus(global_state)
    local w, h = love.graphics.getDimensions()
    local menusToDraw = {}
    
    -- 1. Stacked menus
    for _, m in ipairs(global_state.menuStack) do
        table.insert(menusToDraw, { type = "MENU", data = m, isCurrent = false })
    end
    
    -- 2. Current State Menu
    if global_state.state == "OPTIONS_MENU" or global_state.state == "DELETE_MENU" or global_state.state == "SCRAPER_OPTIONS" then
        table.insert(menusToDraw, { type = "MENU", data = { title = global_state.menuTitle, message = global_state.menuMessage, options = global_state.menuOptions, selection = global_state.menuSelection, focusedItem = global_state.focusedItem }, isCurrent = true })
    elseif global_state.state == "INFO_VIEW" then
        table.insert(menusToDraw, { type = "INFO", data = { focusedItem = global_state.focusedItem or global_state.files[global_state.selectedIndex] }, isCurrent = true })
    end

    -- 3. Help Menu
    if global_state.showHelp or global_state.closingHelp then
        table.insert(menusToDraw, { type = "HELP", data = {}, isCurrent = true })
    end

    -- Calculate Widths
    for _, m in ipairs(menusToDraw) do
        if m.type == "MENU" then
            local item = m.data.focusedItem or global_state.files[global_state.selectedIndex]
            local isGameOpts = false
            if item then
                isGameOpts = (m.data.title:match("^" .. global_state.L.get("options")) and m.data.message == item.name)
            end
            m.naturalWidth = calculateMenuWidth(global_state, m.data.title, m.data.message, m.data.options, item, isGameOpts)
        elseif m.type == "INFO" then
            m.naturalWidth = math.max(w * 0.5, 400)
        elseif m.type == "HELP" then
            m.naturalWidth = math.max(w * 0.4, 300) -- Natural width for help panel
        end
    end
    
    -- Determine animation progress
    local activeMenu = #menusToDraw > 0 and menusToDraw[#menusToDraw] or nil
    local t = 0
    if activeMenu then
        if activeMenu.type == "HELP" then -- If active menu is help
            t = global_state.helpAnim
        else -- MENU, INFO
            t = global_state.menuAnim
        end
    end
    local ease = 1 - (1 - t)^3 -- Ease-out cubic function

    -- Calculate Stack Max (parents) and Total Max (all)
    local stackMax = 0
    for i = 1, #menusToDraw - 1 do
        if menusToDraw[i].naturalWidth > stackMax then stackMax = menusToDraw[i].naturalWidth end
    end
    
    local totalMax = stackMax
    if activeMenu and activeMenu.naturalWidth > totalMax then totalMax = activeMenu.naturalWidth end

    -- Apply Animated Widths
    for i, m in ipairs(menusToDraw) do
        if i == #menusToDraw then
            m.width = totalMax
        else
            m.width = stackMax + (totalMax - stackMax) * ease
        end
    end
    
    -- Flap Logic (Positions)
    local flapSize = 30
    if #menusToDraw > 0 then
        local last = menusToDraw[#menusToDraw]
        last.finalX = w - last.width
        for i = #menusToDraw - 1, 1, -1 do
            menusToDraw[i].finalX = menusToDraw[i+1].finalX - flapSize
        end
    end

    -- Animation (X Position)
    for i, menu in ipairs(menusToDraw) do
        local startX
        if i == #menusToDraw then
            startX = w
            menu.alpha = ease -- Solo el menú nuevo se desvanece/entra
        else
            startX = w - stackMax
            menu.alpha = 1 -- Los padres se mantienen visibles
        end
        
        menu.x = startX + (menu.finalX - startX) * ease
    end

    -- Draw
    if #menusToDraw > 0 then
        -- Draw a stacking, blended overlay for each menu
        local r, g, b, base_a = unpack(theme.colors.overlay_dark)
        for _, m in ipairs(menusToDraw) do
            love.graphics.setColor(r, g, b, base_a * m.alpha)
            love.graphics.draw(getGradientMesh(), 0, 0, 0, w, h)
        end

        -- Only the topmost menu is truly "current" for input focus
        for i, m in ipairs(menusToDraw) do
            m.isFocused = (i == #menusToDraw) -- Mark topmost menu as focused
        end

        for _, m in ipairs(menusToDraw) do
            if m.type == "MENU" then
                local item = m.data.focusedItem or global_state.files[global_state.selectedIndex]
                -- Usamos 'ease' para que el oscurecimiento del padre sea progresivo
                drawMenuContent(global_state, m.data.title, m.data.message, m.data.options, m.data.selection, item, m.x, m.width, h, m.alpha, m.isFocused, ease)
            elseif m.type == "INFO" then
                drawInfoPanel(global_state, m.data.focusedItem, m.x, m.width, h, m.alpha)
            elseif m.type == "HELP" then
                drawHelpPanel(global_state, m.x, m.width, h, m.alpha)
            end
        end
        
        if global_state.state == "DELETE_MENU" and global_state.itemToDelete then
             local activeMenu = nil
             for _, m in ipairs(menusToDraw) do if m.type == "MENU" and m.isCurrent then activeMenu = m break end end
             if activeMenu then
                local path = global_state.itemToDelete.fullPath or ""
                local displayPath = path
                if path:find("ROMS/") then displayPath = path:match("ROMS/(.*)")
                elseif path:find("Simulador_SD/") then displayPath = path:match("Simulador_SD/(.*)") end
                love.graphics.setFont(fontSmall)
                love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], activeMenu.alpha)
                local textY = h - 45
                local availableW = activeMenu.width - 40
                if fontSmall:getWidth(displayPath) > availableW then
                     love.graphics.printf(displayPath, activeMenu.x + 20, textY - fontSmall:getHeight(), availableW, "center")
                else
                     love.graphics.printf(displayPath, activeMenu.x + 20, textY, availableW, "center")
                end
             end
        end
    end
end

local function drawScraperLayout(x, y, w, h, img1, img2, desc, isResultView, global_state)
    local margin = 20
    local imgSpacing = 10
    
    -- Calculate available height for images
    local contentH = h
    local singleImgH = (contentH - imgSpacing) / 2
    
    -- Calculate widths based on aspect ratio to fit height
    local w1 = 0
    if img1 then w1 = img1:getWidth() * (singleImgH / img1:getHeight()) end
    
    local w2 = 0
    if img2 then w2 = img2:getWidth() * (singleImgH / img2:getHeight()) end
    
    -- Determine column width based on the widest image
    local maxImgW = math.max(w1, w2)
    
    -- Default width if no images (or very thin)
    if maxImgW < 200 then maxImgW = 200 end
    
    -- Clamp max width to 70% of screen width to ensure text space
    local maxAllowedW = (w - margin * 3) * 0.70
    if maxImgW > maxAllowedW then maxImgW = maxAllowedW end
    
    local leftW = maxImgW
    local rightW = w - margin * 3 - leftW
    
    local leftX = x + margin
    local rightX = leftX + leftW + margin
    
    -- Draw Images Column
    -- Boxart
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
    
    -- Screenshot
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
    
    -- Info Column
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(theme.colors.text_medium)
    local d = desc
    if not d or d == "" then d = L.get("no_info") end
    -- Text adapts to the calculated rightW
    love.graphics.printf(d, rightX, y, rightW, "left")
    
    -- Search Button (Only in View mode)
    if not isResultView then
        local btnH = 40
        local btnY = y + contentH - btnH
        local spacing = 10
        local btnW = (rightW - spacing) / 2
        
        -- Search Button (1)
        love.graphics.setFont(fontMedium)
        if global_state.scraperSelection == 1 then
            love.graphics.setColor(theme.colors.selection_accent)
        else
            love.graphics.setColor(0.25, 0.25, 0.25)
        end
        love.graphics.rectangle("fill", rightX, btnY, btnW, btnH, 8)
        
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("search_data"), rightX, btnY + (btnH - fontMedium:getHeight())/2, btnW, "center")

        -- Options Button (2)
        local optX = rightX + btnW + spacing
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
    -- Background
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", x, y, w, h, 8)

    -- Content
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", x, y, w, h, 8)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    drawContentFunc(x, y, w, h)
    love.graphics.setStencilTest()

    -- Border
    if isFocused then
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(theme.colors.side_menu_separator)
        love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", x, y, w, h, 8)
    love.graphics.setLineWidth(1)

    -- Indicator (e.g. 1/4)
    if total > 1 then
        local indText = index .. "/" .. total
        love.graphics.setFont(fontSmall)
        local tw = fontSmall:getWidth(indText) + 10
        local th = fontSmall:getHeight() + 4
        
        -- Draw indicator background pill
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x + w - tw - 5, y + h - th - 5, tw, th, 4)
        
        -- Draw text
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
    
    -- Layout: Left Col (Images) 35%, Right Col (Text) Rest
    local leftW = w * 0.35
    local rightW = w - leftW - colSpacing
    
    local imgSpacing = 10
    local topH = (h - imgSpacing) * 0.55 -- Front box height
    local botH = h - topH - imgSpacing -- Screen box height
    
    -- Front Box (Top Left)
    local frontRes = results[global_state.scraperFrontIndex]
    drawScraperSelector(x, y, leftW, topH, global_state.scraperFocus == "FRONT", global_state.scraperFrontIndex, total, function(bx, by, bw, bh)
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
    
    -- Screen Box (Bottom Left)
    local screenRes = results[global_state.scraperScreenIndex]
    drawScraperSelector(x, y + topH + imgSpacing, leftW, botH, global_state.scraperFocus == "SCREEN", global_state.scraperScreenIndex, total, function(bx, by, bw, bh)
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
    
    -- Text Box (Right)
    local textRes = results[global_state.scraperTextIndex]
    drawScraperSelector(x + leftW + colSpacing, y, rightW, h, global_state.scraperFocus == "TEXT", global_state.scraperTextIndex, total, function(bx, by, bw, bh)
        local padding = 15
        local tx = bx + padding
        local ty = by + padding
        local tw = bw - padding * 2
        
        if textRes then
            -- Source / Region
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.selection_accent)
            local sourceText = (textRes.region or "") .. (textRes.source and (" [" .. textRes.source .. "]") or "")
            love.graphics.printf(sourceText, tx, ty, tw, "left")
            ty = ty + fontSmall:getHeight() + 5
            
            -- Description
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

local function drawScraperView(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background) -- Fondo de pantalla completa

    local currentItem = global_state.focusedItem or global_state.files[global_state.selectedIndex]
    if not currentItem then return end

    -- Title: Just the game name (no "Scraper: " prefix)
    local mainName = currentItem.name:gsub("%.[^%.]+$", "")
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(mainName, 0, 15, w, "center")

    -- Subtitle: System Name only (Clean)
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
            -- Si hay una advertencia, centrar el bloque completo (progreso + advertencia)
            local totalBlockHeight = fontMedium:getHeight() + 5 + fontSmall:getHeight()
            progressY = h/2 - totalBlockHeight/2
            
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(1, 0.4, 0.4) -- Red for warnings
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
        
        -- Barra de progreso
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
            -- Editor de resultados (Composite)
            local topY = 90
            local bottomBarH = 30
            local availableH = h - topY - bottomBarH - 10
            drawScraperEditor(global_state, 20, topY, w - 40, availableH)
        end
    end

    -- Hint de volver
    drawBottomBar(global_state)
end

local function drawScrollbar(global_state)
    local scrollW = 2
    love.graphics.setColor(theme.colors.scrollbar_background)
    love.graphics.rectangle("fill", layout.scrollbarX, layout.listY, scrollW, layout.scrollbarH) -- Fondo de la barra
    if #files > 1 then
        local visibleRows = pageSize + 1 -- Calculate visibleRows here for drawScrollbar's scope
        local h = layout.scrollbarH / (#files / visibleRows) -- Altura del "handle" de la barra
        local y = layout.listY + ((animatedSelectionIndex - 1) / (#files - 1)) * (layout.scrollbarH - h) -- Posición animada
        love.graphics.setColor(theme.colors.scrollbar_handle)
        love.graphics.rectangle("fill", layout.scrollbarX, y, scrollW, math.max(10, h))
    end
end

local function drawSaveManager(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)
    
    -- Header style from Scraper
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
            
            -- Icon
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
    end -- End if #saveFiles == 0
    drawBottomBar(global_state)
end

local function drawTrimmedStart(text, x, y, limit, font)
    local dText = text
    if font:getWidth(dText) > limit then
        while font:getWidth("..." .. dText) > limit and #dText > 0 do
            dText = dText:sub(2)
        end
        dText = "..." .. dText
    end
    love.graphics.print(dText, x, y)
end

local function drawCleanupMenu(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(L.get("cleanup_title"), 0, 15, w, "center")
    
    if not global_state.cleanupData.scanned and not global_state.cleanupData.scanning then
        -- Pantalla inicial
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h/2 - 25, 200, 50, 10)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scan"), w/2 - 100, h/2 - 10, 200, "center")
        
    elseif global_state.cleanupData.scanning then
        -- Barra de progreso
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
        -- Results (2 Columns)
        local hasImages = #(cleanupData.orphanedImages or {}) > 0
        local colCount = hasImages and 3 or 2
        local colW = (w - 40 - (colCount-1)*10) / colCount
        
        local col1X = 20
        local col2X = col1X + colW + 10
        local col3X = col2X + colW + 10
        
        -- Cabeceras
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(1, 0.4, 0.4) -- Rojo
        love.graphics.printf(L.get("orphan_states"), col1X, 60, colW, "center")
        love.graphics.setColor(1, 1, 0.4) -- Amarillo
        love.graphics.printf(L.get("duplicate_games"), col2X, 60, colW, "center")
        if hasImages then
            love.graphics.setColor(0.4, 1, 0.4) -- Verde
            love.graphics.printf(L.get("orphan_images"), col3X, 60, colW, "center")
        end
        
        love.graphics.setFont(fontSmall)
        local listY = 100
        local listH = h - 280 -- Reducir altura para dejar espacio al panel de info y botón
        local maxVisible = math.floor(listH / 20)
        
        -- Columna 1: Huérfanos
        -- Scroll para huérfanos
        local startIdx1 = 1 -- Start index for orphans
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
                love.graphics.rectangle("fill", col1X, y, colW, 18) -- Highlight selected orphan
            end
            love.graphics.setColor(theme.colors.text_medium)
            drawTrimmed(item.name, col1X + 5, y, colW - 10, fontSmall)
        end
        
        -- Botón Borrar Todo (Debajo de la lista)
        local btnY = h - 175
        if global_state.cleanupData.cursor.col == 1 and global_state.cleanupData.cursor.row == 1 then
            love.graphics.setColor(1, 0, 0)
        else
            love.graphics.setColor(0.5, 0, 0)
        end
        love.graphics.rectangle("fill", col1X, btnY, colW, 25, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(global_state.L.get("delete_all_states"), col1X, btnY + 5, colW, "center")
        
        -- Columna 2: Duplicados
        local startIdx = 1 -- Start index for duplicates
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
                love.graphics.rectangle("fill", col2X, y, colW, 18) -- Highlight selected duplicate
            end
            
            love.graphics.setColor(theme.colors.text_medium)
            -- Formato: Nombre [SYSTEM] SDx
            local text = item.name .. " [" .. item.system .. "]"
            drawTrimmed(text, col2X + 5, y, colW - 45, fontSmall)
            
            if item.location == "SD1" then love.graphics.setColor(0.4, 0.8, 1)
            else love.graphics.setColor(1, 0.8, 0.4) end
            love.graphics.printf(item.location, col2X + colW - 40, y, 35, "right")
        end
        
        -- Columna 3: Imágenes Huérfanas
        if hasImages then
            local startIdx3 = 1 -- Start index for orphaned images
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
                    love.graphics.rectangle("fill", col3X, y, colW, 18) -- Highlight selected orphaned image
                end
                love.graphics.setColor(theme.colors.text_medium)
                drawTrimmed(item.name, col3X + 5, y, colW - 10, fontSmall)
            end
        end

        -- Panel de Información (Abajo)
        local infoY = h - 140
        love.graphics.setColor(0.15, 0.15, 0.17)
        love.graphics.rectangle("fill", 10, infoY, w - 20, 100, 5)
        love.graphics.setColor(theme.colors.side_menu_separator)
        love.graphics.rectangle("line", 10, infoY, w - 20, 100, 5)
        
        local selItem = nil
        local selTitle = "" -- Selected item title
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
        love.graphics.print(selTitle, 20, infoY + 10) -- Print selected item title
        
        if selItem then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.text_medium)
            love.graphics.print(L.get("file_label", selItem.name), 20, infoY + 35)
            
            local relPath = selItem.fullPath:match("ROMS/(.*)") or selItem.fullPath
            drawTrimmedStart(L.get("path_label", relPath), 20, infoY + 55, w - 140, fontSmall)
            
            if selItem.system then
                love.graphics.print(L.get("system_label", selItem.system, selItem.location), 20, infoY + 75)
            else
                love.graphics.print(L.get("location_label", selItem.location), 20, infoY + 75)
            end
            
            -- Preview de imagen
            local imgPath = nil
            if cleanupData.cursor.col == 3 then
                imgPath = selItem.fullPath
            elseif selItem.system and selItem.name then
                -- Intentar construir ruta de arte para duplicados
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

        -- Confirmation Modal
        if global_state.cleanupData.confirming then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, 0, w, h)
            
            local modalW, modalH = 400, 200
            local mx, my = (w - modalW)/2, (h - modalH)/2
            
            love.graphics.setColor(theme.colors.side_menu_background)
            love.graphics.rectangle("fill", mx, my, modalW, modalH, 10)
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.rectangle("line", mx, my, modalW, modalH, 10) -- Modal border
            
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
            
            local iconY = my + 140 -- Y position for buttons
            local iconScale = 0.8 -- Scale for button icons
            local totalW = global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("confirm") .. "   ") + global_state.buttonIcons.b:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("cancel"))
            local startX = mx + (modalW - totalW) / 2
            
            love.graphics.draw(global_state.buttonIcons.a, startX, iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. global_state.L.get("confirm") .. "   ", startX + global_state.buttonIcons.a:getWidth()*iconScale, iconY + 2)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color for B icon
            love.graphics.draw(global_state.buttonIcons.b, startX + global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" Confirmar   "), iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. global_state.L.get("cancel"), startX + global_state.buttonIcons.a:getWidth()*iconScale + global_state.fontMedium:getWidth(" " .. global_state.L.get("confirm") .. "   ") + global_state.buttonIcons.b:getWidth()*iconScale, iconY + 2)
        end
    end
    drawBottomBar(global_state)
end

local function drawGrid(global_state, w, h)
    local tStart = love.timer.getTime()
    local cols = global_state.gridCols
    local rows = 3
    local startY = 80 -- Bajamos el inicio para no pisar "Todos los sistemas"
    local marginX = 30
    local availableW = w - (marginX * 2)
    local cellW = availableW / cols
    local cellH = (h - startY - 40) / rows -- Ajustamos altura de celda al nuevo espacio
    
    -- Dibujar imagen de fondo global con dithering (basada en selección)
    local bgImage = global_state.currentScreenshot or global_state.currentImage
    if bgImage then
        local alpha = 1
        if bgImage == global_state.currentScreenshot then alpha = global_state.currentScreenshotAlpha
        elseif bgImage == global_state.currentImage then alpha = global_state.currentImageAlpha end
        
        local scale = h / bgImage:getHeight()
        love.graphics.setColor(1, 1, 1, 0.15 * alpha) -- Más translúcido
        local imgW = bgImage:getWidth() * scale
        local imgX = w - imgW
        love.graphics.draw(bgImage, imgX, 0, 0, scale, scale)
        
        local r, g, b = unpack(theme.colors.background)
        love.graphics.setColor(r, g, b, 1)
        ditherShader:send("objPos", {imgX, 0})
        love.graphics.setShader(ditherShader)
        love.graphics.draw(getFadeGradientMesh(), imgX, 0, 0, imgW, h)
        love.graphics.setShader()
    end

    -- Animated scroll offset for the grid
    local target_row_float = global_state.animGridRow or math.ceil(global_state.animatedSelectionIndex / cols)
    local target_visual_row_float = rows / 2 -- Center point
    local gridScrollOffset = (target_row_float - target_visual_row_float) * cellH

    -- Clamp scroll offset
    local minGridScrollOffset = (1 - target_visual_row_float) * cellH
    local maxGridScrollOffset = math.max(minGridScrollOffset, (math.ceil(#global_state.files / cols) - rows) * cellH)
    if #global_state.files <= rows * cols then
        gridScrollOffset = minGridScrollOffset
    end
    gridScrollOffset = math.max(minGridScrollOffset, math.min(maxGridScrollOffset, gridScrollOffset))

    -- Determine visible items
    local firstVisibleRow = math.floor(gridScrollOffset / cellH) - 1
    local startIndex = math.max(1, firstVisibleRow * cols + 1)
    local numVisibleRows = rows + 4 -- Draw a couple extra for smooth scrolling
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

        local contentWidth = cellW - 20 -- Más margen lateral (elementos más pequeños)

        local imageToDraw = nil
        if not item.isDir then
            local base = item.name:gsub("%..-$", "")
            
            -- Determinar la ruta de la carátula correcta para el item (considerando virtual root)
            local systemForItem = utils.getSystemNameForItem(item, global_state.systemName, global_state.isVirtualRoot)

            if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
                local v = item.versions[1]
                base = v.name:gsub("%..-$", "")
                systemForItem = v.system or systemForItem -- Use version's system if available
            end

            local artPathForItem = filesystem.getArtPathForSystem(systemForItem)
            
            if artPathForItem then
                local path = artPathForItem .. base .. ".png"
                imageToDraw = global_state.loader:getImage(path)
                
                -- Si no hay imagen y no es directorio, usar noImage
                if not imageToDraw then
                    imageToDraw = global_state.imgNoImage
                end
            end
        end

        -- Dibujar imagen o icono
        if imageToDraw then -- If there's an image to draw
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
            item.alpha = 0 -- Reset alpha if image is lost/loading
            love.graphics.setColor(1, 1, 1)
            local icon = item.icon -- Icon for item
            if not icon and item.isDir then -- If no icon and it's a directory
                icon = utils.getSystemIcon(item.name, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
            end
            icon = icon or (item.isDir and global_state.iconFolder)
            
            if not icon then -- If still no icon
                if item.system then
                    icon = utils.getSystemContentIcon(item.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                end
                if not icon then icon = global_state.currentSystemContentIcon or global_state.iconRom end
            end -- End if not icon

            local availableH = cellH - 65 -- Menos altura disponible para el icono
            local availableW = cellW - 20
            local scale = math.min(availableW / icon:getWidth(), availableH / icon:getHeight()) * 0.7
            if icon == global_state.iconFolder then
                scale = scale * 0.7 -- Reducir tamaño de carpetas
            end
            local ix = x + (cellW - icon:getWidth()*scale)/2
            local iy = y + 5 + (availableH - icon:getHeight()*scale)/2
            love.graphics.draw(icon, ix, iy, 0, scale, scale)
        end

        -- Texto
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
                -- Truncate line 2 and add ellipsis
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
        if i == round(global_state.animatedSelectionIndex) then
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
            love.graphics.printf(textToPrint, x + 11, textY, contentWidth, "center")
        else
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
        end

        -- Draw status icons (Favorite / Played) side-by-side
        local statusIconSize = 18
        local iconPadding = 4
        local rightOffset = 10
        local iconY = y + cellH - 50 - statusIconSize

        if global_state.favoriteRoms[item.fullPath] then
            local icon = global_state.iconFavorite
            local scale = statusIconSize / icon:getHeight()
            local ix = x + cellW - rightOffset - (icon:getWidth() * scale)
            love.graphics.setColor(theme.colors.selection_accent)
            love.graphics.draw(icon, ix, iconY, 0, scale, scale)
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
            love.graphics.draw(pIcon, ix, iconY, 0, scale, scale)
        end
    end
    local tEnd = love.timer.getTime()
    if tEnd - tStart > 0.033 then -- Log si baja de 30fps (33ms)
        global_state.log("Slow Grid Draw: " .. string.format("%.4f", tEnd - tStart) .. "s")
    end

    -- Animated selection box (drawn after all items)
    local animRow = global_state.animGridRow or 1
    local animCol = global_state.animGridCol or 1
    
    local r_abs = animRow - 1
    local c_abs = animCol - 1
    
    local animX = marginX + c_abs * cellW
    local animY = startY + r_abs * cellH - gridScrollOffset

    love.graphics.setColor(1, 1, 1, 0.2) -- Translucent white
    love.graphics.rectangle("fill", animX + 2, animY + 2, cellW - 4, cellH + 1, 15)
end

local function drawJumpLetter(global_state)
    if global_state.jumpPanelAnim <= 0 or global_state.jumpLetter == "" then return end

    local w, h = love.graphics.getDimensions()
    
    -- Animación de deslizamiento (Slide in/out) usando jumpPanelAnim (0 a 1)
    local t = jumpPanelAnim
    local ease = 1 - (1 - t)^3 -- Cubic ease out
    local slide = (1 - ease) * 140
    
    local panelW = 120
    local panelH = 120
    local x = w - panelW + slide
    local y = h - 160 -- Encima de la barra de estado
    
    -- Fondo del panel
    love.graphics.setColor(0.15, 0.15, 0.17, 0.9)
    love.graphics.rectangle("fill", x, y, panelW + 10, panelH, 10)
    love.graphics.setColor(theme.colors.selection_accent)
    love.graphics.rectangle("line", x, y, panelW + 10, panelH, 10)
    
    -- Letra grande
    love.graphics.setFont(fontHuge)

    local scale = 1
    local textW = fontHuge:getWidth(global_state.jumpLetter)
    local textH = fontHuge:getHeight()
    
    local drawX = x + panelW / 2
    local drawY = y + panelH / 2

    -- Letra blanca con opacidad
    love.graphics.setColor(1, 1, 1, 0.85) -- White color with opacity
    love.graphics.print(global_state.jumpLetter, drawX, drawY, 0, scale, scale, textW / 2, textH / 2)
end

local internetStatus = false
local lastInternetCheck = -10

local batteryImageCache = {}

local function drawBattery(global_state, x, centerY)
    local now = love.timer.getTime()
    if now - lastInternetCheck > 15 then -- Check less frequently (15s) to reduce stutter
        lastInternetCheck = now
        local f = io.open("/sys/class/net/wlan0/operstate", "r")
        if f then
            local status = f:read("*a")
            f:close()
            internetStatus = (status and status:match("up")) ~= nil
        else
            internetStatus = false
        end
    end

    if global_state.iconNetwork then
        if internetStatus then love.graphics.setColor(1, 1, 1, 1)
        else love.graphics.setColor(0.5, 0.5, 0.5, 1) end
        local targetH = 18
        local scale = targetH / global_state.iconNetwork:getHeight()
        local nw = global_state.iconNetwork:getWidth() * scale
        love.graphics.draw(global_state.iconNetwork, x - 26 - 8 - nw, centerY - (global_state.iconNetwork:getHeight() * scale) / 2, 0, scale, scale)
    end -- End if iconNetwork

    local state, percent = love.system.getPowerInfo()
    if state == "nobattery" or not percent then
        percent = 100
        state = "charged"
    end

    local imageName
    if state == "charging" then
        imageName = "charging"
    else
        if percent > 80 then imageName = "100"
        elseif percent > 60 then imageName = "80"
        elseif percent > 40 then imageName = "60"
        elseif percent > 20 then imageName = "40"
        else imageName = "20"
        end
    end

    local imagePath = "assets/battery/battery_" .. imageName .. ".png"

    if not batteryImageCache[imagePath] then
        local success, img = pcall(love.graphics.newImage, imagePath)
        if success then
            batteryImageCache[imagePath] = img
        else
            batteryImageCache[imagePath] = "error"
        end
    end

    local img = batteryImageCache[imagePath]
    if img and img ~= "error" then
        local r, g, b, a = 1, 1, 1, 1
        if state == "charging" then
            r, g, b = 0.2, 1, 0.2
        else
            if percent <= 10 then
                r, g, b = 1, 0.2, 0.2
                a = (math.sin(love.timer.getTime() * 10) + 1) / 2
            elseif percent <= 20 then
                r, g, b = 1, 0.2, 0.2
            end
        end
        love.graphics.setColor(r, g, b, a)
        local imgW, imgH = img:getWidth(), img:getHeight()
        love.graphics.draw(img, x - imgW, centerY - imgH/2)
    else
        -- Fallback: Dibujar icono programáticamente sin texto
        local batW, batH = 26, 14
        local nippleW, nippleH = 3, 6
        local batY = centerY - batH/2
        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.rectangle("line", x - batW, batY, batW, batH, 2)
        love.graphics.rectangle("fill", x, batY + (batH - nippleH)/2, nippleW, nippleH)
        local margin = 2; local maxFill = batW - (margin * 2); local fill = math.max(0, maxFill * (percent / 100))
        if state == "charging" then 
            love.graphics.setColor(0.2, 1, 0.2)
        elseif percent <= 20 then 
            local a = 1
            if percent <= 10 then a = (math.sin(love.timer.getTime() * 10) + 1) / 2 end
            love.graphics.setColor(1, 0.2, 0.2, a) 
        end
        love.graphics.rectangle("fill", x - batW + margin, batY + margin, fill, batH - (margin * 2))
    end
end

local function drawTopBar(global_state, w, h)
    local topBarCenterY = 22
    -- Título
    love.graphics.setColor(theme.colors.text_bright)
    love.graphics.setFont(fontTopBar)
    love.graphics.printf(L.get("app_title"), 0, topBarCenterY - fontTopBar:getHeight()/2, w, "center")
    -- Reloj
    love.graphics.setFont(global_state.fontClock)
    love.graphics.print(os.date("%H:%M"), 20, topBarCenterY - fontClock:getHeight()/2)
    -- Batería
    drawBattery(global_state, w - 20, topBarCenterY + 3)
end

local function drawMainList(global_state, w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)
    if global_state.viewMode == "GRID" then


        drawGrid(global_state, w, h)
    else
        -- Columna de Vista Previa (Boxart + Screenshot) - DIBUJADO AL FONDO
        if showPreview then
            local bgImage = currentScreenshot or currentImage
            if bgImage then -- If there's a background image
                local alpha = 1
                if bgImage == global_state.currentScreenshot then alpha = global_state.currentScreenshotAlpha
                elseif bgImage == global_state.currentImage then alpha = global_state.currentImageAlpha end

                local scale = h / bgImage:getHeight()
                love.graphics.setColor(1, 1, 1, 0.15 * alpha) -- Más translúcido
                local imgW = bgImage:getWidth() * scale
                local imgX = w - imgW
                love.graphics.draw(bgImage, imgX, 0, 0, scale, scale)
                
                local r, g, b = unpack(theme.colors.background)
                love.graphics.setColor(r, g, b, 1)
                ditherShader:send("objPos", {imgX, 0})
                love.graphics.setShader(ditherShader)
                love.graphics.draw(getFadeGradientMesh(), imgX, 0, 0, imgW, h)
                love.graphics.setShader()
            end
        end

        -- Calcular propiedades para el elemento *realmente* seleccionado (files[selectedIndex])
        -- Definir favScale aquí para que esté disponible globalmente en drawMainList
        local favScale = (global_state.iconFavorite and global_state.iconFavorite:getHeight() ~= 0) and ((40 * 0.35) / global_state.iconFavorite:getHeight()) or 1
        local favAnimState = { index = global_state.favAnimIndex, anim = global_state.favAnim }

        -- Calcular startLine aquí para que esté disponible para el selector animado
        local visibleRows = global_state.pageSize + 1
        local targetVisualRow = math.floor(visibleRows / 2) -- Try to keep selected item in the middle
        
        -- Calculate the overall scroll offset for the list content
        -- This offset determines how much the entire list shifts up/down
        local listScrollOffset = (global_state.animatedSelectionIndex - targetVisualRow) * global_state.layout.rowHeight

        -- Clamp the listScrollOffset so that the list doesn't scroll past its bounds
        local minListOffset = (1 - targetVisualRow) * global_state.layout.rowHeight
        local maxListOffset = math.max(0, (#global_state.files - targetVisualRow) * global_state.layout.rowHeight)

        listScrollOffset = math.max(minListOffset, math.min(maxListOffset, listScrollOffset))

        -- The visual position of the animated selection rectangle
        local visualSelY = layout.listY + (global_state.animatedSelectionIndex - 1) * layout.rowHeight - listScrollOffset + (layout.rowHeight - layout.selHeight) / 2

        -- Calculate target widths for interpolation
        local currentItemIndex = math.floor(global_state.animatedSelectionIndex)
        local nextItemIndex = math.ceil(global_state.animatedSelectionIndex)
        local interpolationFactor = global_state.animatedSelectionIndex - currentItemIndex

        local width1 = calculateItemDisplayWidth(global_state.files[currentItemIndex], global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, currentItemIndex, favAnimState)
        local width2 = calculateItemDisplayWidth(global_state.files[nextItemIndex], global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, nextItemIndex, favAnimState)
        
        local animatedSelectionWidth = lerp(width1, width2, interpolationFactor)
        
        -- Dibujar el rectángulo de selección animado
        love.graphics.setColor(1, 1, 1, 0.15) -- Blanco más translúcido (ligeramente más brillante)
        love.graphics.rectangle("fill", global_state.layout.selX, visualSelY, animatedSelectionWidth, global_state.layout.selHeight, 22)

        -- Lista de Archivos
        love.graphics.setFont(global_state.fontList)
        -- Determine the range of items to draw based on the clamped listScrollOffset
        local firstVisibleItemIndex = math.max(1, math.floor(1 + listScrollOffset / layout.rowHeight))
        local lastVisibleItemIndex = math.min(#global_state.files, firstVisibleItemIndex + visibleRows + 1) -- +1 for smooth transition
        for i = firstVisibleItemIndex, lastVisibleItemIndex do
            local y = layout.listY + (i - 1) * layout.rowHeight - (listScrollOffset or 0) -- Ensure listScrollOffset is not nil
            local item = global_state.files[i]
            
            local checkPath = item.fullPath or (global_state.romPath .. item.name)
            local isLastPlayed = (not item.isDir) and global_state.playedRoms[checkPath]

            -- Verificar si es el último juego jugado
            local playedSystem = nil
            if global_state.launchMode == "Juego Unico" and item.versions then
                for _, v in ipairs(item.versions) do if global_state.playedRoms[v.fullPath] then isLastPlayed = true; playedSystem = v.system break end end
            elseif isLastPlayed and global_state.markPlayed then -- Para modo Folder o ROMs individuales en Juego Unico
                playedSystem = utils.getSystemNameForItem(item)
            end
            
            if item.empty then -- If item is empty
                love.graphics.setColor(theme.colors.text_disabled)
                local textY = y + (layout.rowHeight - fontList:getHeight()) / 2
                love.graphics.printf(item.name, 100, textY, layout.selWidth - 80, "left")
                -- No dibujar nada más para elementos vacíos
            else
                -- Pre-calcular nameToDraw y favOffset para este item para calcular el ancho del selector
                local nameToDrawForWidth = item.name
                if not item.isDir then
                    nameToDrawForWidth = nameToDrawForWidth:gsub("%.[^%.]+$", "")
                end

                local isActuallyFav = (global_state.favoriteRoms[item.fullPath]) and global_state.romPath ~= "@Favorites/"
                local animFactor = 0
                if isActuallyFav then animFactor = 1 end
                if i == global_state.favAnimIndex then
                    animFactor = global_state.favAnim
                end

                local favOffset = 0
                if animFactor > 0 then
                    -- This is the full offset including padding
                    favOffset = ((global_state.iconFavorite:getWidth() * favScale) + 10) * animFactor
                end


                local currentItemStaticWidth = calculateItemDisplayWidth(item, global_state.layout, global_state.fontList, global_state.launchMode, global_state.romPath, global_state.iconFavorite, favScale, global_state.favoriteRoms, sdColX, i, favAnimState)

                -- NEW: Dibujar fondo con trama para elementos jugados (independientemente de la selección)
                -- Determinar icono a dibujar
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
                    -- Calcular etiqueta SD
                    local label = item.sourceLabel -- Source label for item
                    if not label then
                        if global_state.romPath:find("/mnt/mmc") then label = "SD1"
                        elseif global_state.romPath:find("/mnt/sdcard") then label = "SD2" end
                    end
                    
                    -- Calcular espacio disponible para el nombre: Ancho total - offset(70) - padding(5)
                    availableWidth = sdColX - (layout.selX + 70) - 10
                end

                if animFactor > 0 then
                    availableWidth = availableWidth - favOffset
                end

               -- NEW: Dibujar fondo con trama para elementos jugados (independientemente de la selección)
                if isLastPlayed and global_state.markPlayed then
                    love.graphics.setColor(theme.colors.list_played_unselected)
                    local adjustedH = global_state.layout.selHeight - 6
                    local adjustedY = y + (global_state.layout.rowHeight - adjustedH) / 2
                    local adjustedX = global_state.layout.selX + 3
                    local adjustedW = currentItemStaticWidth - 6
                    
                    ditherShader:send("objPos", {adjustedX, adjustedY})
                    love.graphics.setShader(ditherShader)
                    love.graphics.stencil(function()
                        love.graphics.rectangle("fill", adjustedX, adjustedY, adjustedW, adjustedH, 22)
                    end, "replace", 1)
                    love.graphics.setStencilTest("greater", 0)
                    love.graphics.draw(getFadeGradientMesh(), adjustedX, adjustedY, 0, adjustedW, adjustedH)
                    love.graphics.setStencilTest()
                    love.graphics.setShader()
                end

                love.graphics.setColor(1, 1, 1, 1) -- Always opaque white for icon
                local iconX = layout.selX + (70 - iconToDraw:getWidth() * drawScale) / 2
                love.graphics.draw(iconToDraw, iconX, drawY, 0, drawScale, drawScale)

                local textX = layout.selX + 70

                if animFactor > 0 then
                    love.graphics.setColor(theme.colors.selection_accent)
                    local currentScale = favScale * animFactor
                    local iconH = global_state.iconFavorite:getHeight() * currentScale
                    local favIconY = y + (layout.rowHeight - iconH) / 2
                    
                    love.graphics.draw(global_state.iconFavorite, textX, favIconY, 0, currentScale, currentScale)
                    -- The offset for the text is the animated width of the star plus padding
                    textX = textX + (global_state.iconFavorite:getWidth() * currentScale) + 10
                end

                local nameToDraw = item.name
                if not item.isDir then
                    nameToDraw = nameToDraw:gsub("%.[^%.]+$", "")
                end

                -- Determinar color de texto
                local textColor = global_state.theme.colors.text_medium -- Default for unselected, unmarked, unplayed
                if i == global_state.selectedIndex then -- Highest priority: if selected, text is white
                    textColor = theme.colors.text_bright
                elseif item.pendingDelete then -- Si no está seleccionado, pero está pendiente de borrar
                    textColor = {0.8, 0.2, 0.2} -- Desaturated red
                elseif item.selected then -- Si no está seleccionado, pero está marcado con 'X'
                    textColor = {0.8, 0.6, 0.3} -- Naranja/Amarillo desaturado
                end
                love.graphics.setColor(textColor)

                -- OPTIMIZACIÓN: Caché para el texto recortado
                local cacheKeyText = tostring(availableWidth) .. "_" .. nameToDraw
                if item._textCacheVal and item._textCacheKey == cacheKeyText then
                    nameToDraw = item._textCacheVal
                else
                    if fontList:getWidth(nameToDraw) > availableWidth then
                        -- Pre-recorte estimativo
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
                
                -- Centrar el texto verticalmente en la fila
                local textY = y + (layout.rowHeight - fontList:getHeight()) / 2

                -- Dibujar texto (siempre, independientemente de la selección, el color ya está establecido)
                if i == round(global_state.animatedSelectionIndex) then -- Bolding should follow the rounded animated cursor
                    love.graphics.print(nameToDraw, textX, textY)
                    love.graphics.print(nameToDraw, textX + 1, textY)
                else
                    love.graphics.print(nameToDraw, textX, textY)
                end

                if showSystemIcons then
                    -- Dibujar iconos de sistemas apilados a la derecha
                    local systems = {} -- List of systems for this item
                    local seen = {} -- Para evitar duplicados
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
                        if icon then -- Ensure the icon exists (use global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                            local iconColor = (isLastPlayed and markPlayed and sys == playedSystem) and {0.2, 0.8, 0.3, 1} or {1, 1, 1, 1}
                            love.graphics.setColor(iconColor)
                            local scale = iconSize / icon:getHeight() -- Escala para los iconos de sistema apilados
                            love.graphics.draw(icon, startX + (idx-1)*(iconSize+spacing), y + (layout.rowHeight - iconSize)/2, 0, scale, scale)
                        end
                    end
                else
                    local label = item.sourceLabel
                    if not label then
                        if global_state.romPath:find("/mnt/mmc") then label = "SD1"
                        elseif global_state.romPath:find("/mnt/sdcard") then label = "SD2" end
                    end
                    if label and label ~= "Fav" then -- If label exists and is not "Fav"
                    -- Colores distintivos para SD
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

                    love.graphics.setFont(fontSmall) -- Usar fuente más pequeña para las etiquetas SD
                    local labelY = y + (layout.rowHeight - fontSmall:getHeight()) / 2
                    love.graphics.printf(label, sdColX, labelY, sdColW, "center")
                    love.graphics.setFont(fontList) -- Restaurar fuente original de la lista
                    end
                end
            end
        end
    end

    -- Scrollbar
    drawScrollbar(global_state)
    
    -- Mostrar nombre completo del archivo seleccionado encima de la barra de estado (Overlay)
    if files[round(animatedSelectionIndex)] then -- Overlay should follow the rounded animated cursor
        local item = files[selectedIndex]
        local rawName = item.name
        local nameNoExt = rawName:gsub("%.[^%.]+$", "")
        
        -- Recalcular el ancho disponible para el texto para decidir si mostrar el overlay
        local availableWidth
        local showSystemIcons = (launchMode == "Juego Unico" and item.versions)

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

        local isFav = (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/"
        if isFav then
            local favH = 16
            local favScale = favH / iconFavorite:getHeight()
            local favOffset = (iconFavorite:getWidth() * favScale) + 5 -- Usar favScale precalculado
            availableWidth = availableWidth - favOffset
        end
        
        if fontList:getWidth(nameNoExt) > availableWidth then
            love.graphics.setFont(fontMedium)
            local width, wrapped = fontMedium:getWrap(nameNoExt, w - 20)
            local textH = #wrapped * fontMedium:getHeight()
            local padding = 8
            local bgH = textH + padding * 2
            local bgY = h - 35 - bgH -- Position above bottom bar
            
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, bgY, w, bgH)
            
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.printf(nameNoExt, 10, bgY + padding, w - 20, "center")
        end
    end
end

local function draw(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if global_state.state == "SCRAPER_VIEW" or global_state.state == "SCRAPING_IN_PROGRESS" or global_state.state == "SCRAPER_RESULTS" or global_state.state == "SCRAPER_OPTIONS" then
        drawScraperView(global_state)
        if global_state.state == "SCRAPER_OPTIONS" or global_state.closingMenu then
            drawOverlayMenus(global_state)
        end
        drawOverlayMenus(global_state) -- For Help
        return -- No dibujar la lista debajo
    end
    
    if global_state.state == "SAVE_MANAGER" then
        drawSaveManager(global_state)
        drawOverlayMenus(global_state) -- For Help
        return
    end
    
    if global_state.state == "CLEANUP_MENU" then
        drawCleanupMenu(global_state)
        drawOverlayMenus(global_state) -- For Help
        return
    end
    
    -- Layout dinámico
    -- Scrollbar fija a la derecha
    layout.scrollbarX = w - 2
    layout.scrollbarH = h - layout.listY - 30
    
    local margin = 30
    layout.selX = margin
    layout.selWidth = (w - margin) - layout.selX

    -- Columna SD (alineada a la derecha dentro del cursor)
    local sdColW = 40
    local cursorRight = layout.selX + layout.selWidth
    local sdColX = cursorRight - sdColW - 20

    local showPreview = (global_state.currentImage ~= nil or global_state.currentScreenshot ~= nil)
    local previewBoxW = 200 -- Valor por defecto
    
    if showPreview then
        local maxPreviewW = w * 0.5
        local availableH = h - layout.listY - 40 -- Espacio vertical disponible
        
        local ar1 = global_state.currentImage and (global_state.currentImage:getWidth() / global_state.currentImage:getHeight()) or 0
        local ar2 = currentScreenshot and (currentScreenshot:getWidth() / currentScreenshot:getHeight()) or 0
        local padding = (currentImage and currentScreenshot) and 15 or 0
        
        local calculatedW = maxPreviewW
        
        if currentImage and currentScreenshot then
            local combinedInvAr = (1/ar1) + (1/ar2)
            calculatedW = (availableH - padding) / combinedInvAr -- Calculated width
        elseif currentImage then
             calculatedW = availableH * ar1 -- Calculated width
        elseif currentScreenshot then
             calculatedW = availableH * ar2
        end
        
        previewBoxW = math.min(maxPreviewW, calculatedW)
        previewBoxW = math.max(100, previewBoxW) -- Mínimo razonable
    end

    local previewBoxX = sdColX - previewBoxW - 10 -- X position for preview box
    if global_state.romPath == "@Favorites/" then
         previewBoxX = layout.scrollbarX - previewBoxW - 10
    end

    -- Mensaje de indexación en "Modo Único" si el índice no está listo
    if global_state.launchMode == "Juego Unico" and global_state.isVirtualRoot and not global_state.romIndex and #global_state.files == 0 then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("indexing"), 0, h/2 - 20, w, "center")
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        local msg = global_state.isIndexing and global_state.indexStateMessage or L.get("loading_index")
        love.graphics.printf(msg, 0, h/2 + 20, w, "center")

        -- Título (Indexación)
        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.setFont(fontTopBar)
        love.graphics.printf(L.get("app_title"), 0, 15, w, "center")
        love.graphics.setFont(fontClock)
        love.graphics.print(os.date("%H:%M"), 20, 17)
        drawBattery(global_state, w - 25, 20)
        love.graphics.setFont(global_state.fontSmall)
        local displayPath = global_state.isVirtualRoot and global_state.L.get("all_systems") or global_state.romPath
        if not global_state.isVirtualRoot then
            local shortened = displayPath:match("ROMS/.*")
            if shortened then
                displayPath = shortened
            elseif displayPath:find("Simulador_SD") then
                displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
            end
        end -- End if not isVirtualRoot
        love.graphics.printf(displayPath, 0, 45, w, "center") -- Print display path
        
        drawOverlayMenus(global_state)
        
        drawBottomBar(global_state)
        return
    end

    -- Mensaje si la lista está vacía (y no estamos indexando)
    if #global_state.files == 0 and not global_state.isIndexing then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(L.get("no_items"), 0, h/2, w, "center")
    end

    drawMainList(global_state, w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)

    -- Draw the bottom gradient (between the list and the bottom bar)
    -- Initialize bottomGradientMesh once
    if not bottomGradientMesh then
        local r, g, b = 0, 0, 0 -- Use black for the gradient to make it visible
        local gradientLength = 20 -- As per request
        local opaquePercentage = 40 -- As per request
        local w_screen, _ = love.graphics.getDimensions()
        local vertices = utils.createGradientVertices("bottom", opaquePercentage, gradientLength, w_screen, r, g, b)
        bottomGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset color, mesh vertices handle alpha
    local bottomY = h - 30 - 20
    ditherShader:send("objPos", {0, bottomY})
    love.graphics.setShader(ditherShader)
    -- Position it 20 pixels above the bottom bar (which starts at h - 30)
    love.graphics.draw(bottomGradientMesh, 0, bottomY)
    love.graphics.setShader()

    -- Draw the top gradient (moved here to be in front of the list but behind the top bar)
    -- Initialize topGradientMesh once, covering the top bar and fading below it
    if not topGradientMesh then
        local r, g, b = 0, 0, 0 -- Use black for the gradient to make it visible
        local topBarHeight = layout.listY -- The height of the top bar area (where title/subtitle ends)
        local fadeLength = 54 -- Reduced by 10% (was 60)
        local gradientLength = topBarHeight + fadeLength -- Total length of the gradient
        local opaquePercentage = 35 -- Percentage of the total length that is fully opaque
        local w_screen, _ = love.graphics.getDimensions()
        local vertices = utils.createGradientVertices("top", opaquePercentage, gradientLength, w_screen, r, g, b)
        topGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
    ditherShader:send("objPos", {0, 0})
    love.graphics.setShader(ditherShader)
    love.graphics.draw(topGradientMesh, 0, 0) -- Draw at the very top of the screen
    love.graphics.setShader()

    -- Title (Drawn after the list to be on top of background/dithering)
    drawTopBar(global_state, w, h)
    
    -- Path actual
    love.graphics.setFont(fontSmall)
    local displayPath = global_state.isVirtualRoot and global_state.L.get("all_systems") or global_state.romPath
    if not global_state.isVirtualRoot then
        local shortened = displayPath:match("ROMS/.*")
        if shortened then
            displayPath = shortened
        elseif displayPath:find("Simulador_SD") then
            displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
        end
    end -- End if not isVirtualRoot
    love.graphics.printf(displayPath, 0, 45, w, "center") -- Print display path

    drawOverlayMenus(global_state)

    -- Status bar
    drawBottomBar(global_state)
    
    -- Dibujar panel de letra al final para que quede encima de todo
    drawJumpLetter(global_state)

    -- Draw Search UI if active
    if state == "SEARCH" or state == "EDIT_TEXT" or keyboardAnim > 0 then
        local t = keyboardAnim
        local ease = 1 - (1 - t)^3
        local panelH = 250 -- Height of keyboard panel
        local currentY = h - (panelH * ease)

        -- Fondo oscuro para el teclado
        love.graphics.setColor(0, 0, 0, 0.9 * ease)
        love.graphics.rectangle("fill", 0, currentY, w, panelH)
        
        -- Barra de búsqueda
        local r, g, b = unpack(global_state.theme.colors.text_white)
        love.graphics.setColor(r, g, b, ease)
        love.graphics.setFont(fontTitle)
        if state == "EDIT_TEXT" then
            love.graphics.printf(global_state.textEditLabel .. ": " .. global_state.textToEdit .. "_", 20, currentY + 10, w - 40, "left")
        else
            love.graphics.printf(L.get("search_label", searchQuery), 20, currentY + 10, w - 40, "left")
        end
        
        -- Virtual Keyboard
        love.graphics.setFont(fontMedium)
        local keySize = 40
        local spacing = 5
        local startY = currentY + 50
        
        -- Calcular ancho del bloque principal (10 teclas)
        local mainBlockWidth = 10 * (keySize + spacing) - spacing
        -- Center main block in available space to the left (reserving 100px for side buttons)
        local mainBlockStartX = (w - 100 - mainBlockWidth) / 2
        if mainBlockStartX < 10 then mainBlockStartX = 10 end
        
        for r, row in ipairs(keyboardGrid) do
            for c, key in ipairs(row) do
                local x, y, kW, kH
                
                if key == "SPACE" or key == "BACK" or key == "OK" then
                    kW = 80
                    kH = keySize
                    x = w - kW - 20
                    y = startY + (r-1) * (keySize + spacing)
                else
                    kW = keySize
                    kH = keySize
                    x = mainBlockStartX + (c-1) * (keySize + spacing)
                y = startY + (r-1) * (keySize + spacing) -- Y position for key
                    -- Indentar filas 3 y 4
                    if r == 3 then x = x + (keySize/2) end
                    if r == 4 then x = x + (keySize/2) end
                end
                
                local col
                if r == keyboardRow and c == keyboardCol then
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

    -- Indicador de indexación en segundo plano
    if global_state.isIndexing then
        -- Punto parpadeante en la esquina superior derecha
        love.graphics.setFont(fontTitle) -- Usar fuente grande para el punto
        love.graphics.setColor(theme.colors.selection_accent)
        
        local current_time = love.timer.getTime()
        local blink = (math.sin(current_time * 8) + 1) / 2 -- Parpadeo suave

        love.graphics.setColor(theme.colors.selection_accent[1], theme.colors.selection_accent[2], theme.colors.selection_accent[3], blink)
        love.graphics.print("•", w - 30, 5)
    end
end

return draw
