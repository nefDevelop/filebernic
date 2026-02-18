---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

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
            {0.7, 0, 0.7, 0, 1, 1, 1, 0}, -- 70%: Transparente (deja 30% visible)
            {0.7, 1, 0.7, 1, 1, 1, 1, 0},
            {1, 0, 1, 0, 1, 1, 1, 0}, -- Derecha: Transparente (relleno)
            {1, 1, 1, 1, 1, 1, 1, 0}
        }
        fadeGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    return fadeGradientMesh
end

-- Función para crear una malla de degradado vertical
-- opaquePercentage: El porcentaje de la altura total que debe ser completamente opaco (0-100)
-- fadePercentage: El porcentaje de la altura total sobre el cual el alfa se desvanece de 1 a 0 (0-100)
-- La altura restante (100 - opaquePercentage - fadePercentage) será completamente transparente.
local function createVerticalGradientMesh(opaquePercentage, fadePercentage)
    local vertices = {}
    
    -- Normalizar porcentajes a un rango de 0-1
    local opaqueRatio = opaquePercentage / 100
    local fadeRatio = fadePercentage / 100
    
    local yStartFade = opaqueRatio
    local yEndFade = opaqueRatio + fadeRatio
    
    -- Asegurar que las coordenadas Y estén dentro de [0, 1]
    yStartFade = math.max(0, math.min(1, yStartFade))
    yEndFade = math.max(0, math.min(1, yEndFade))

    -- Sección superior: Completamente opaca (alfa 1)
    table.insert(vertices, {0, 0, 0, 0, 0, 0, 0, 1}) -- Arriba-Izquierda
    table.insert(vertices, {1, 0, 1, 0, 0, 0, 0, 1}) -- Arriba-Derecha

    -- Si hay una sección opaca antes de desvanecerse, añadir vértices al final de esta
    if yStartFade > 0 then
        table.insert(vertices, {0, yStartFade, 0, yStartFade, 0, 0, 0, 1}) -- Fin de sección opaca (Izquierda)
        table.insert(vertices, {1, yStartFade, 1, yStartFade, 0, 0, 0, 1}) -- Fin de sección opaca (Derecha)
    end

    -- Si hay una sección de desvanecimiento, añadir vértices al final de esta (alfa 0)
    if fadeRatio > 0 then
        table.insert(vertices, {0, yEndFade, 0, yEndFade, 0, 0, 0, 0}) -- Fin de sección de desvanecimiento (Izquierda)
        table.insert(vertices, {1, yEndFade, 1, yEndFade, 0, 0, 0, 0}) -- Fin de sección de desvanecimiento (Derecha)
    end
    
    return love.graphics.newMesh(vertices, "strip", "static")
end

local bottomFadeGradientMesh
local function getBottomFadeGradientMesh()
    if not bottomFadeGradientMesh then
        local vertices = {
            {0, 0, 0, 0, 0, 0, 0, 0}, -- Top-Left: Transparent Black
            {1, 0, 1, 0, 0, 0, 0, 0}, -- Top-Right: Transparent Black
            {0, 1, 0, 1, 0, 0, 0, 1}, -- Bottom-Left: Opaque Black
            {1, 1, 1, 1, 0, 0, 0, 1}  -- Bottom-Right: Opaque Black
        }
        bottomFadeGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    return bottomFadeGradientMesh
end

local topFadeGradientMesh
local function getTopFadeGradientMesh()
    if not topFadeGradientMesh then
        -- Crear un degradado que es 40% opaco y luego se desvanece a transparente en el 60% restante
        topFadeGradientMesh = createVerticalGradientMesh(60, 40)
    end
    return topFadeGradientMesh
end

local function drawStar(x, y, size)
    local vertices = {}
    local outerRadius = size
    local innerRadius = size * 0.4
    local steps = 10
    for i = 0, steps - 1 do
        local radius = (i % 2 == 0) and outerRadius or innerRadius
        local angle = (i / steps) * math.pi * 2 - math.pi / 2
        table.insert(vertices, x + math.cos(angle) * radius)
        table.insert(vertices, y + math.sin(angle) * radius)
    end
    love.graphics.polygon("fill", vertices)
end

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
local function calculateItemDisplayWidth(item, layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX)
    if not item then return layout.selWidth + 2 end -- Default width if item is nil
    
    -- OPTIMIZACIÓN: Caché para evitar recálculos costosos cada frame
    local isFav = (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/"
    local cacheKey = tostring(launchMode) .. "_" .. tostring(isFav) .. "_" .. tostring(sdColX)
    if item._widthCacheVal and item._widthCacheKey == cacheKey then
        return item._widthCacheVal
    end
    
    local nameToMeasure = item.name
    if not item.isDir then
        nameToMeasure = nameToMeasure:gsub("%.[^%.]+$", "")
    end

    local itemFavOffset = 0
    if (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/" then
        itemFavOffset = (iconFavorite:getWidth() * favScale) + 5
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
    item._widthCacheVal = calculatedWidth + 2
    item._widthCacheKey = cacheKey
    return item._widthCacheVal
end

local function drawBottomBar()
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

    if state == "LIST" then
        drawHint(buttonIcons.a, L.get("accept"))
        drawHint(buttonIcons.b, L.get("back"))
        drawHint(buttonIcons.y, L.get("options"))
        -- drawHint(buttonIcons.start, L.get("config")) -- Eliminado según la solicitud
        -- Select button with offset
        local icon = buttonIcons.select
        local scale = desiredIconHeight / icon:getHeight()
        local text = L.get("exit")
        local iconY = barCenterY - (icon:getHeight() * scale) / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
    elseif state == "DELETE_MENU" or state == "POST_GAME" then
        drawHint(buttonIcons.a, L.get("confirm"))
        drawHint(buttonIcons.b, L.get("cancel"))
    elseif state == "INFO_VIEW" then
        drawHint(buttonIcons.b, L.get("back"))
    elseif state == "OPTIONS_MENU" then
        drawHint(buttonIcons.a, L.get("accept")) -- Siempre "Aceptar" en menús
        drawHint(buttonIcons.b, L.get("back"))
        drawHint(buttonIcons.r1, L.get("help"))
        drawHint(buttonIcons.select, L.get("exit"))
    elseif state == "SCRAPER_VIEW" then
        drawHint(buttonIcons.a, L.get("search"))
        drawHint(buttonIcons.b, L.get("back"))
        drawHint(buttonIcons.y, L.get("options"))
    elseif state == "SCRAPER_OPTIONS" then
        drawHint(buttonIcons.a, L.get("accept"))
        drawHint(buttonIcons.b, L.get("back"))
    elseif state == "SCRAPER_RESULTS" then
        drawHint(buttonIcons.a, L.get("save"))
        drawHint(buttonIcons.b, L.get("back"))
    elseif state == "SAVE_MANAGER" then
        drawHint(buttonIcons.a, L.get("copy"))
        drawHint(buttonIcons.b, L.get("back"))
    elseif state == "CLEANUP_MENU" then
        drawHint(buttonIcons.a, L.get("delete"))
        drawHint(buttonIcons.b, L.get("back"))
    end
end

local function drawMenuContent(title, message, options, selection, item, x, w, h, alpha, isFocused, dimProgress, isFile)
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
        if pStart then
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
        
        if currentImage then
            titleX = baseTextX + maxCoverW + 10
            titleAvailW = w - (baseTextX - x) - (maxCoverW + 10) - 20 -- panel_width - left_margin - cover_width - cover_margin - right_margin
        end

        -- Obtener el texto del título envuelto y su altura
        local _, wrappedMain = fontTitle:getWrap(mainName, titleAvailW)
        local visibleLines = math.min(#wrappedMain, 2)
        local mainH = visibleLines * fontTitle:getHeight()
        
        -- Dibujar la carátula
        if currentImage then
            love.graphics.setColor(1, 1, 1)
            local maxH = 120
            local coverScale = math.min(maxCoverW / currentImage:getWidth(), maxH / currentImage:getHeight())
            
            coverW = currentImage:getWidth() * coverScale
            coverH = currentImage:getHeight() * coverScale
            
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
        local regionInfo = extraInfo:gsub("%.[^%.]+$", "") -- quitar extensión
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
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
            love.graphics.printf(message, x + 20, 80, w - 40, "left")
            local width, wrappedtext = fontMedium:getWrap(message, w - 40)
            startY = 80 + (#wrappedtext * fontMedium:getHeight()) + 30
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
            if isFocused then
                local c = theme.colors.selection_accent
                love.graphics.setColor(c[1], c[2], c[3], alpha)
            else
                love.graphics.setColor(0.3, 0.3, 0.3, alpha) -- Selección gris en menú inactivo
            end
            love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            labelColor = theme.colors.text_white
            valueColor = theme.colors.text_white
        else
            if type(option) == "table" and option.played and markPlayed then
                local c = theme.colors.list_played_unselected
                love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
                love.graphics.rectangle("fill", x, rowY, w, rowHeight)
            end

            if text:find(L.get("delete")) then
                labelColor = {1, 0.4, 0.4} -- Rojo suave
            elseif text:find(L.get("cleanup")) then
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
             if not img then return end
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
                local toggleIcon = (value == L.get("on") or value == L.get("yes")) and imgOn or imgOff
                local toggleColor = (value == L.get("on") or value == L.get("yes")) and {0.2, 1, 0.2} or {0.6, 0.6, 0.6}
                drawIconCentered(toggleIcon, 2, toggleColor)
            elseif label == L.get("view") then
                local gridColor = (value == L.get("grid")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                local listColor = (value == L.get("list")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                drawIconCentered(iconList, 1, listColor)
                drawIconCentered(iconGrid, 2, gridColor)
            elseif label == L.get("mode") then
                local gameColor = (value == L.get("single_game")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                local folderColor = (value == L.get("folder")) and {1, 1, 1} or {0.4, 0.4, 0.4}
                drawIconCentered(iconFolder, 1, folderColor)
                drawIconCentered(iconGame, 2, gameColor)
            else
                love.graphics.setColor(vc)
                local valW = fontMedium:getWidth(value)
                love.graphics.print(value, x + w - 20 - valW, textY)
            end
        else
            love.graphics.setColor(lc)
            local rightMargin = 20
            if icon then
                local baseColor = theme.colors.selection_accent
                if icon == iconTrash then baseColor = {1, 0.4, 0.4} end
                
                local iconColor = (i == selection and isFocused) and theme.colors.text_white or baseColor
     
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

local function calculateMenuWidth(title, message, options, item, isGameOptions)
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    local optionsMaxW = 0
    for _, opt in ipairs(options) do
        local text = type(opt) == "table" and opt.text or opt
        local width = 0
        
        -- Estabilizar ancho para interruptores (evita que el panel cambie de tamaño entre ON/OFF)
        local label, val = text:match("^(.-):%s*(.+)$")
        if label and (val == L.get("on") or val == L.get("off") or val == L.get("yes") or val == L.get("no")) then
             width = fontMedium:getWidth(label .. ":") + 50 -- Ancho etiqueta + espacio fijo para icono
        elseif label == L.get("view") then
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
        local name = message
        mainName = name:gsub("%.[^%.]+$", ""):gsub("%s*$", "")
        local pStart = name:find("%s*%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
        end
        
        if currentImage then
            -- Espacio reservado para carátula (80px) + margen (10px)
            coverSpace = 90
        end
    end
    
    local titleRequiredW = fontTitle:getWidth(mainName) + 40 + coverSpace
    
    -- Ancho mínimo mayor si hay carátula para que no quede apretado
    local minW = (isGameOptions and currentImage) and 320 or 200
    
    local calculatedW = math.max(minW, optionsMaxW + 60, titleRequiredW)
    
    return math.min(w * 0.75, calculatedW)
end

local function drawHelpPanel(x, w, h, alpha)
    local bg = theme.colors.side_menu_background
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * alpha)
    love.graphics.rectangle("fill", x, 0, w, h)
    
    local sep = theme.colors.side_menu_separator
    love.graphics.setColor(sep[1], sep[2], sep[3], alpha)
    love.graphics.line(x, 0, x, h)

    local contentX = x
    love.graphics.setColor(theme.colors.text_white[1], theme.colors.text_white[2], theme.colors.text_white[3], alpha)
    love.graphics.setFont(fontTitle)
    love.graphics.printf("Ayuda - Controles", contentX + 20, 40, w - 40, "left")
    
    local list = helpData[state] or helpData.DEFAULT
    local filteredList = {}
    if state == "LIST" and launchMode == "Juego Unico" then
        for _, item in ipairs(list) do
            if item.text ~= "Seleccionar" then table.insert(filteredList, item) end
        end
    else
        filteredList = list
    end

    love.graphics.setFont(fontMedium)
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
        love.graphics.print(L.get(item.text), contentX + 20, textY)
        love.graphics.draw(item.icon, contentX + w - 20 - iconW, iconY, 0, iconScale, iconScale)
    end
end

local function drawMediaDetailContent(currentItem, x, y, w, h, alpha)
    local regionInfo = ""
    local pStart = currentItem.name:find("%(")
    if pStart then regionInfo = currentItem.name:sub(pStart) end

    local sysName = utils.getSystemNameForItem(currentItem)
    local displayName = utils.getSystemDisplayName(sysName)
    local subtitle = (displayName or "Desconocido") .. " " .. regionInfo

    local coverImg = currentImage or imgNoImage

    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
    love.graphics.printf(subtitle, x, y + 55, w, "center")

    local contentY = y + 100
    local imagesY = contentY + fontMedium:getHeight() + 15
    local availableH = h - imagesY - 40 - 120
    
    local spacing = 20
    local coverW, screenW = 0, 0
    local coverScale, screenScale = 0, 0
    local finalImageH = 0

    if coverImg and currentScreenshot then
        local ar1 = coverImg:getWidth() / coverImg:getHeight()
        local ar2 = currentScreenshot:getWidth() / currentScreenshot:getHeight()
        local totalAvailW = w - 40
        
        -- Calcular la altura si las imágenes llenaran el ancho disponible
        local heightForWidth = (totalAvailW - spacing) / (ar1 + ar2)
        
        -- La altura final es el mínimo entre el espacio vertical y el calculado para el ancho
        finalImageH = math.min(availableH, heightForWidth)
        
        coverScale = finalImageH / coverImg:getHeight()
        screenScale = finalImageH / currentScreenshot:getHeight()
    elseif coverImg then
        coverScale = math.min(1, availableH / coverImg:getHeight())
        local maxW = w - 40
        if coverImg:getWidth() * coverScale > maxW then
            coverScale = maxW / coverImg:getWidth()
        end
        finalImageH = coverImg:getHeight() * coverScale
    elseif currentScreenshot then
        screenScale = math.min(1, availableH / currentScreenshot:getHeight())
        local maxW = w - 40
        if currentScreenshot:getWidth() * screenScale > maxW then
            screenScale = maxW / currentScreenshot:getWidth()
        end
        finalImageH = currentScreenshot:getHeight() * screenScale
    end

    if coverImg then
        coverW = coverImg:getWidth() * coverScale
    end
    if currentScreenshot then
        screenW = currentScreenshot:getWidth() * screenScale
    end

    local totalW = coverW + (coverImg and currentScreenshot and spacing or 0) + screenW
    local startX = x + (w - totalW) / 2
    local drawY = imagesY + (availableH - finalImageH) / 2
    
    love.graphics.setFont(fontMedium)
    if coverImg then
        love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
        love.graphics.printf(L.get("front"), startX, contentY, coverW, "center")
        love.graphics.setColor(1, 1, 1, alpha * (currentImage and currentImageAlpha or 1))
        love.graphics.draw(coverImg, startX, drawY, 0, coverScale, coverScale)
    end
    if currentScreenshot then
        local drawX = startX + (coverImg and (coverW + spacing) or 0)
        love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
        love.graphics.printf(L.get("screen"), drawX, contentY, screenW, "center")
        love.graphics.setColor(1, 1, 1, alpha * currentScreenshotAlpha)
        love.graphics.draw(currentScreenshot, drawX, drawY, 0, screenScale, screenScale)
    end

    local textY = imagesY + availableH + 15
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
    local infoTitle = L.get("info")
    if currentYear and currentYear ~= "" then infoTitle = infoTitle .. " (" .. currentYear .. ")" end
    love.graphics.print(infoTitle, x + 20, textY)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(theme.colors.text_dim[1], theme.colors.text_dim[2], theme.colors.text_dim[3], alpha)
    local descText = (currentDescription and currentDescription ~= "") and currentDescription or L.get("no_info")
    love.graphics.printf(descText, x + 20, textY + 25, w - 40, "left")

    if not currentImage and not currentScreenshot and descText == L.get("no_info") then
        love.graphics.setColor(theme.colors.text_medium[1], theme.colors.text_medium[2], theme.colors.text_medium[3], alpha)
        love.graphics.printf(L.get("no_images_info"), x, y + h/2, w, "center")
    end
end

local function drawInfoPanel(item, x, w, h, alpha)
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

    drawMediaDetailContent(item, x, 0, w, h, alpha, 0) -- No scroll for INFO_VIEW
end

local function drawOverlayMenus()
    local w, h = love.graphics.getDimensions()
    local menusToDraw = {}
    
    -- 1. Stacked menus
    for _, m in ipairs(menuStack) do
        table.insert(menusToDraw, { type = "MENU", data = m, isCurrent = false })
    end
    
    -- 2. Current State Menu
    if state == "OPTIONS_MENU" or state == "DELETE_MENU" or state == "SCRAPER_OPTIONS" then
        table.insert(menusToDraw, { type = "MENU", data = { title = menuTitle, message = menuMessage, options = menuOptions, selection = menuSelection, focusedItem = focusedItem }, isCurrent = true })
    elseif state == "INFO_VIEW" then
        table.insert(menusToDraw, { type = "INFO", data = { focusedItem = focusedItem or files[selectedIndex] }, isCurrent = true })
    end

    -- 3. Help Menu
    if showHelp or closingHelp then
        table.insert(menusToDraw, { type = "HELP", data = {}, isCurrent = true })
    end

    -- Calculate Widths
    for _, m in ipairs(menusToDraw) do
        if m.type == "MENU" then
            local item = m.data.focusedItem or files[selectedIndex]
            local isGameOpts = false
            if item then
                isGameOpts = (m.data.title:match("^" .. L.get("options")) and m.data.message == item.name)
            end
            m.naturalWidth = calculateMenuWidth(m.data.title, m.data.message, m.data.options, item, isGameOpts)
        elseif m.type == "INFO" then
            m.naturalWidth = math.max(w * 0.5, 400)
        elseif m.type == "HELP" then
            m.naturalWidth = math.max(w * 0.4, 300)
        end
    end
    
    -- Determine animation progress
    local activeMenu = #menusToDraw > 0 and menusToDraw[#menusToDraw] or nil
    local t = 0
    if activeMenu then
        if activeMenu.type == "HELP" then
            t = helpAnim
        else -- MENU, INFO
            t = menuAnim
        end
    end
    local ease = 1 - (1 - t)^3

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
            m.isFocused = (i == #menusToDraw)
        end

        for _, m in ipairs(menusToDraw) do
            if m.type == "MENU" then
                local item = m.data.focusedItem or files[selectedIndex]
                -- Usamos 'ease' para que el oscurecimiento del padre sea progresivo
                drawMenuContent(m.data.title, m.data.message, m.data.options, m.data.selection, item, m.x, m.width, h, m.alpha, m.isFocused, ease)
            elseif m.type == "INFO" then
                drawInfoPanel(m.data.focusedItem, m.x, m.width, h, m.alpha)
            elseif m.type == "HELP" then
                drawHelpPanel(m.x, m.width, h, m.alpha)
            end
        end
        
        if state == "DELETE_MENU" and itemToDelete then
             local activeMenu = nil
             for _, m in ipairs(menusToDraw) do if m.type == "MENU" and m.isCurrent then activeMenu = m break end end
             if activeMenu then
                local path = itemToDelete.fullPath or ""
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

local function drawScraperView()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background) -- Fondo de pantalla completa

    local currentItem = focusedItem or files[selectedIndex]
    if not currentItem then return end

    -- Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(L.get("scraper_title", currentItem.name), 0, 15, w, "center")

    if state == "SCRAPER_VIEW" then
        -- Usar la nueva función de dibujado de contenido
        drawMediaDetailContent(currentItem, 0, 0, w, h, 1, 0) -- No scroll for SCRAPER_VIEW

        -- Botón de Scrapear
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h - 120, 200, 40, 5) -- Moved up
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("search_data"), 0, h - 110, w, "center") -- Moved up

    elseif state == "SCRAPING_IN_PROGRESS" then
        love.graphics.printf(L.get("scraping_db"), 0, h/2, w, "center")

    elseif state == "BATCH_SCRAPING" then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scraping_batch"), 0, h/2 - 60, w, "center")
        
        love.graphics.setFont(fontMedium)
        love.graphics.printf(L.get("processing", scraperProgress.currentName), 0, h/2 - 20, w, "center")
        
        -- Barra de progreso
        local barW = 400
        local barX = (w - barW) / 2
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW * (scraperProgress.current / scraperProgress.total), 20)
        
        love.graphics.printf(scraperProgress.current .. " / " .. scraperProgress.total, 0, h/2 + 50, w, "center")
        love.graphics.printf(L.get("successes_failures", scraperProgress.successes, scraperProgress.failures), 0, h/2 + 80, w, "center")

    elseif state == "SCRAPER_RESULTS" then
        love.graphics.setFont(fontMedium)
        love.graphics.printf(L.get("results"), 20, 60, w, "left")
        
        if #scraperResults == 0 then
            love.graphics.printf(L.get("no_results"), 20, 100, w, "left")
        else
            -- Lista horizontal de miniaturas
            local listY = 90
            local thumbSize = 80
            local spacing = 10
            local startX = 20 - scraperScrollOffset -- Apply horizontal scroll offset
            
            for i, result in ipairs(scraperResults) do
                local x = startX + (i-1) * (thumbSize + spacing)
                if x > w - thumbSize then break end
                
                if i == scraperSelection then
                    love.graphics.setColor(theme.colors.selection_accent)
                    love.graphics.rectangle("fill", x - 2, listY - 2, thumbSize + 4, thumbSize + 4)
                end
                
                love.graphics.setColor(theme.colors.text_white)
                if result.image then
                    local scale = math.min(thumbSize/result.image:getWidth(), thumbSize/result.image:getHeight())
                    love.graphics.draw(result.image, x + (thumbSize - result.image:getWidth()*scale)/2, listY + (thumbSize - result.image:getHeight()*scale)/2, 0, scale, scale)
                elseif result.error then
                    love.graphics.setColor(1, 0.4, 0.4)
                    love.graphics.rectangle("line", x, listY, thumbSize, thumbSize)
                    love.graphics.setFont(fontTitle)
                    love.graphics.printf("!", x, listY + thumbSize/2 - 12, thumbSize, "center")
                else
                    love.graphics.rectangle("line", x, listY, thumbSize, thumbSize)
                end
            end
            
            -- Vista previa del resultado seleccionado (Layout dividido)
            local sel = scraperResults[scraperSelection]
            if sel then
                if sel.error then
                    love.graphics.setColor(1, 0.4, 0.4)
                    love.graphics.setFont(fontMedium)
                    love.graphics.printf(sel.text or "Error", 40, 300, w - 80, "center")
                else
                local boxX, boxY, boxW, boxH = 40, 200, 160, 220
                local screenX, screenY, screenW, screenH = 240, 200, 360, 200
                local textX, textY, textW, textH = 40, 430, 560, 40
                
                -- Frontal
                love.graphics.setColor(theme.colors.text_medium)
                love.graphics.print(L.get("front"), boxX, boxY - 20)
                if sel.image then
                love.graphics.setColor(theme.colors.text_white)
                    local scale = math.min(boxW/sel.image:getWidth(), boxH/sel.image:getHeight())
                    love.graphics.draw(sel.image, boxX + (boxW - sel.image:getWidth()*scale)/2, boxY + (boxH - sel.image:getHeight()*scale)/2, 0, scale, scale)
                end
                
                -- Screen
                love.graphics.setColor(theme.colors.text_medium)
                love.graphics.print(L.get("screen"), screenX, screenY - 20)
                if sel.screenshot then
                    love.graphics.setColor(theme.colors.text_white)
                    local scale = math.min(screenW/sel.screenshot:getWidth(), screenH/sel.screenshot:getHeight())
                    love.graphics.draw(sel.screenshot, screenX + (screenW - sel.screenshot:getWidth()*scale)/2, screenY + (screenH - sel.screenshot:getHeight()*scale)/2, 0, scale, scale)
                else
                    love.graphics.setColor(theme.colors.text_dim)
                    love.graphics.printf(L.get("no_screen"), screenX, screenY + screenH/2, screenW, "center")
                end
                
                -- Info
                love.graphics.setFont(fontSmall)
                love.graphics.setColor(theme.colors.text_white)
                local infoText = sel.description or L.get("no_desc")
                if sel.source then
                    infoText = "[" .. sel.source .. "] " .. infoText
                end
                love.graphics.printf(infoText, textX, textY - descriptionScrollOffset, textW, "left") -- Apply vertical scroll offset
                end
            end
        end
    end

    -- Hint de volver
    drawBottomBar()
end

local function drawScrollbar()
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

local function drawSaveManager()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(L.get("save_manager_title"), 0, 20, w, "center")
    
    love.graphics.setFont(fontList)
    local startY = 80
    
    if #saveFiles == 0 then
        love.graphics.printf(L.get("no_saves_found"), 0, h/2, w, "center")
    else
        for i, item in ipairs(saveFiles) do
            local y = startY + (i-1) * 35
            
            if i == saveManagerSelection then
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", 20, y - 2, w - 40, 30, 5)
                love.graphics.setColor(theme.colors.text_white)
            else
                love.graphics.setColor(theme.colors.text_medium)
            end
            
            love.graphics.print(item.name, 30, y)
            love.graphics.printf(item.type, w - 200, y, 100, "right")
            
            -- Etiqueta SD
            if item.location == "SD1" then love.graphics.setColor(0.4, 0.8, 1)
            elseif item.location == "SD2" then love.graphics.setColor(1, 0.8, 0.4)
            else love.graphics.setColor(0.7, 0.7, 0.7) end
            love.graphics.print(item.location, w - 80, y)
        end
    end
    drawBottomBar()
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

local function drawCleanupMenu()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(L.get("cleanup_title"), 0, 15, w, "center")
    
    if not cleanupData.scanned and not cleanupData.scanning then
        -- Pantalla inicial
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h/2 - 25, 200, 50, 10)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scan"), w/2 - 100, h/2 - 10, 200, "center")
        
    elseif cleanupData.scanning then
        -- Barra de progreso
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("scanning_files"), 0, h/2 - 40, w, "center")
        
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300 * cleanupData.progress, 20)
        
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(cleanupData.currentFile or "", 0, h/2 + 25, w, "center")
        
    else
        -- Resultados (2 Columnas)
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
        local startIdx1 = 1
        if cleanupData.cursor.col == 1 and cleanupData.cursor.row > maxVisible + 1 then
            startIdx1 = cleanupData.cursor.row - maxVisible
        end
        local endIdx1 = math.min(#cleanupData.orphans, startIdx1 + maxVisible - 1)

        for i = startIdx1, endIdx1 do
            local item = cleanupData.orphans[i]
            local displayIndex = i - startIdx1
            local y = listY + displayIndex * 20
            
            if cleanupData.cursor.col == 1 and cleanupData.cursor.row == i + 1 then 
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", col1X, y, colW, 18)
            end
            love.graphics.setColor(theme.colors.text_medium)
            drawTrimmed(item.name, col1X + 5, y, colW - 10, fontSmall)
        end
        
        -- Botón Borrar Todo (Debajo de la lista)
        local btnY = h - 175
        if cleanupData.cursor.col == 1 and cleanupData.cursor.row == 1 then
            love.graphics.setColor(1, 0, 0)
        else
            love.graphics.setColor(0.5, 0, 0)
        end
        love.graphics.rectangle("fill", col1X, btnY, colW, 25, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(L.get("delete_all_states"), col1X, btnY + 5, colW, "center")
        
        -- Columna 2: Duplicados
        local startIdx = 1
        if cleanupData.cursor.col == 2 and cleanupData.cursor.row > maxVisible then
            startIdx = cleanupData.cursor.row - maxVisible + 1
        end
        local endIdx = math.min(#cleanupData.duplicates, startIdx + maxVisible - 1)

        for i = startIdx, endIdx do
            local item = cleanupData.duplicates[i]
            local displayIndex = i - startIdx
            local y = listY + displayIndex * 20
            
            if cleanupData.cursor.col == 2 and cleanupData.cursor.row == i then 
                love.graphics.setColor(theme.colors.selection_accent)
                love.graphics.rectangle("fill", col2X, y, colW, 18)
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
            local startIdx3 = 1
            if cleanupData.cursor.col == 3 and cleanupData.cursor.row > maxVisible then
                startIdx3 = cleanupData.cursor.row - maxVisible + 1
            end
            local endIdx3 = math.min(#cleanupData.orphanedImages, startIdx3 + maxVisible - 1)
            
            for i = startIdx3, endIdx3 do
                local item = cleanupData.orphanedImages[i]
                local displayIndex = i - startIdx3
                local y = listY + displayIndex * 20
                if cleanupData.cursor.col == 3 and cleanupData.cursor.row == i then
                    love.graphics.setColor(theme.colors.selection_accent)
                    love.graphics.rectangle("fill", col3X, y, colW, 18)
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
        local selTitle = ""
        if cleanupData.cursor.col == 1 then
            if cleanupData.cursor.row == 1 then
                selTitle = L.get("action_delete_all_orphans")
            elseif cleanupData.orphans[cleanupData.cursor.row - 1] then
                selItem = cleanupData.orphans[cleanupData.cursor.row - 1]
                selTitle = L.get("orphan_state")
            end
        elseif cleanupData.cursor.col == 3 then
            if cleanupData.orphanedImages[cleanupData.cursor.row] then
                selItem = cleanupData.orphanedImages[cleanupData.cursor.row]
                selTitle = L.get("orphan_image")
            end
        else
            if cleanupData.duplicates[cleanupData.cursor.row] then
                selItem = cleanupData.duplicates[cleanupData.cursor.row]
                selTitle = L.get("duplicate_game")
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
                local success, img = pcall(love.graphics.newImage, imgPath)
                if success and img then
                    local pH = 90
                    local scale = pH / img:getHeight()
                    love.graphics.draw(img, w - 100, infoY + 5, 0, scale, scale)
                end
            end
        end

        -- Modal de Confirmación
        if cleanupData.confirming then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, 0, w, h)
            
            local modalW, modalH = 400, 200
            local mx, my = (w - modalW)/2, (h - modalH)/2
            
            love.graphics.setColor(theme.colors.side_menu_background)
            love.graphics.rectangle("fill", mx, my, modalW, modalH, 10)
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.rectangle("line", mx, my, modalW, modalH, 10)
            
            love.graphics.setFont(fontTitle)
            love.graphics.printf(L.get("confirm_action"), mx, my + 20, modalW, "center")
            love.graphics.setFont(fontMedium)
            love.graphics.printf(selTitle, mx + 20, my + 60, modalW - 40, "center")
            if selItem then
                love.graphics.setFont(fontSmall)
                love.graphics.printf(selItem.name, mx + 20, my + 90, modalW - 40, "center")
            end
            
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.selection_accent)
            
            local iconY = my + 140
            local iconScale = 0.8
            local totalW = buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" " .. L.get("confirm") .. "   ") + buttonIcons.b:getWidth()*iconScale + fontMedium:getWidth(" " .. L.get("cancel"))
            local startX = mx + (modalW - totalW) / 2
            
            love.graphics.draw(buttonIcons.a, startX, iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. L.get("confirm") .. "   ", startX + buttonIcons.a:getWidth()*iconScale, iconY + 2)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color for B icon
            love.graphics.draw(buttonIcons.b, startX + buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" Confirmar   "), iconY, 0, iconScale, iconScale)
            love.graphics.print(" " .. L.get("cancel"), startX + buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" " .. L.get("confirm") .. "   ") + buttonIcons.b:getWidth()*iconScale, iconY + 2)
        end
    end
    drawBottomBar()
end

local function drawGrid(w, h)
    local cols = gridCols
    local rows = 3
    local startY = 80 -- Bajamos el inicio para no pisar "Todos los sistemas"
    local marginX = 30
    local availableW = w - (marginX * 2)
    local cellW = availableW / cols
    local cellH = (h - startY - 40) / rows -- Ajustamos altura de celda al nuevo espacio
    
    -- Dibujar imagen de fondo global con dithering (basada en selección)
    local bgImage = currentScreenshot or currentImage
    if bgImage then
        local alpha = 1
        if bgImage == currentScreenshot then alpha = currentScreenshotAlpha
        elseif bgImage == currentImage then alpha = currentImageAlpha end
        
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

    -- Calcular fila inicial para scroll
    local currentRow = math.ceil(selectedIndex / cols)
    local startRow = math.max(1, currentRow - rows + 1)
    if currentRow <= rows then startRow = 1 end
    
    local startIndex = (startRow - 1) * cols + 1
    local endIndex = math.min(#files, startIndex + (cols * rows) - 1)
    
    for i = startIndex, endIndex do
        local relIndex = i - startIndex
        local r = math.floor(relIndex / cols)
        local c = relIndex % cols
        
        local x = marginX + c * cellW
        local y = startY + r * cellH
        local item = files[i]
        
        local checkPath = item.fullPath or (romPath .. item.name)
        local isLastPlayed = (not item.isDir) and playedRoms[checkPath]
        local playedSystem = item.system

        if launchMode == "Juego Unico" and item.versions then
             for _, v in ipairs(item.versions) do
                 if playedRoms[v.fullPath] then isLastPlayed = true playedSystem = v.system break end
             end
        end

        local contentWidth = cellW - 20 -- Más margen lateral (elementos más pequeños)

        local imageToDraw = nil
        if not item.isDir then
            local base = item.name:gsub("%..-$", "")
            
            -- Determinar la ruta de la carátula correcta para el item (considerando virtual root)
            local systemForItem = utils.getSystemNameForItem(item, systemName, isVirtualRoot)

            if launchMode == "Juego Unico" and item.versions and #item.versions > 0 then
                local v = item.versions[1]
                base = v.name:gsub("%..-$", "")
                systemForItem = v.system or systemForItem
            end

            local artPathForItem = filesystem.getArtPathForSystem(systemForItem)

            if artPathForItem then
                local path = artPathForItem .. base .. ".png"
                imageToDraw = loader:getImage(path)
                
                -- Si no hay imagen y no es directorio, usar noImage
                if not imageToDraw then
                    imageToDraw = imgNoImage
                end
            end
        end

        -- Dibujar imagen o icono
        if imageToDraw then
            if not item.alpha then item.alpha = 0 end
            item.alpha = math.min(1, item.alpha + love.timer.getDelta() * 5)
            love.graphics.setColor(1, 1, 1, item.alpha)
            local scale = math.min(contentWidth / imageToDraw:getWidth(), (cellH - 80) / imageToDraw:getHeight())
            if imageToDraw == imgNoImage then
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
            local icon = item.icon
            if not icon and item.isDir then
                icon = utils.getSystemIcon(item.name)
            end
            icon = icon or (item.isDir and iconFolder)
            
            if not icon then
                if item.system then
                    icon = utils.getSystemContentIcon(item.system)
                end
                if not icon then icon = currentSystemContentIcon or iconRom end
            end
            
            local availableH = cellH - 65 -- Menos altura disponible para el icono
            local availableW = cellW - 20
            local scale = math.min(availableW / icon:getWidth(), availableH / icon:getHeight()) * 0.7
            if icon == iconFolder then
                scale = scale * 0.7 -- Reducir tamaño de carpetas
            end
            local ix = x + (cellW - icon:getWidth()*scale)/2
            local iy = y + 5 + (availableH - icon:getHeight()*scale)/2
            love.graphics.draw(icon, ix, iy, 0, scale, scale)
        end

        if launchMode == "Juego Unico" and item.versions then
            local systems = {}
            local seen = {}
            for _, v in ipairs(item.versions) do
                if v.system and not seen[v.system] then
                    seen[v.system] = true
                    table.insert(systems, v.system)
                end
            end
            
            local iconSize = 16
            local iconY = y + cellH - 45 - iconSize
            local iconX = x + cellW - 10
            
            for idx = #systems, 1, -1 do
                local sys = systems[idx]
                local sIcon = utils.getSystemIcon(sys)
                if sIcon then
                    if isLastPlayed and markPlayed and sys == playedSystem then
                        love.graphics.setColor(0.2, 0.8, 0.3) -- Verde más brillante para que se vea el icono
                    else
                        love.graphics.setColor(1, 1, 1, 0.9)
                    end
                    local scale = iconSize / sIcon:getHeight()
                    love.graphics.draw(sIcon, iconX - iconSize, iconY, 0, scale, scale)
                    iconX = iconX - iconSize - 2
                end
            end
        end

        -- Fondo selección (Dibujado DESPUÉS de la imagen para que esta quede al fondo)
        if i == selectedIndex then
            love.graphics.setColor(1, 1, 1, 0.2) -- Blanco translúcido
            love.graphics.rectangle("fill", x + 2, y + 2, cellW - 4, cellH - 2, 15)
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
        if i == selectedIndex then
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
            love.graphics.printf(textToPrint, x + 11, textY, contentWidth, "center")
        else
            love.graphics.printf(textToPrint, x + 10, textY, contentWidth, "center")
        end

        if isLastPlayed and markPlayed and launchMode ~= "Juego Unico" then
             local pIcon = iconRom
             local sys = playedSystem
             if not sys then sys = utils.getSystemNameForItem(item) end
             if sys then pIcon = utils.getSystemIcon(sys) or iconRom end
             
             local iconSize = 24
             local iconX = x + cellW - iconSize - 8
             local iconY = y + cellH - 40 - iconSize
             
             love.graphics.setColor(0.2, 0.8, 0.3) -- Verde más brillante para que se vea el icono
             local scale = iconSize / pIcon:getHeight()
             love.graphics.draw(pIcon, iconX, iconY, 0, scale, scale)
        end
    end
end

local function drawJumpLetter()
    if jumpPanelAnim <= 0 or jumpLetter == "" then return end
    
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
    local textW = fontHuge:getWidth(jumpLetter)
    local textH = fontHuge:getHeight()
    
    local drawX = x + panelW / 2
    local drawY = y + panelH / 2

    -- Letra blanca con opacidad
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(jumpLetter, drawX, drawY, 0, scale, scale, textW / 2, textH / 2)
end

local internetStatus = false
local lastInternetCheck = -10

local batteryImageCache = {}

local function drawBattery(x, centerY)
    local now = love.timer.getTime()
    if now - lastInternetCheck > 5 then
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

    if iconNetwork then
        if internetStatus then love.graphics.setColor(1, 1, 1, 1)
        else love.graphics.setColor(0.5, 0.5, 0.5, 1) end
        local targetH = 18
        local scale = targetH / iconNetwork:getHeight()
        local nw = iconNetwork:getWidth() * scale
        love.graphics.draw(iconNetwork, x - 26 - 8 - nw, centerY - (iconNetwork:getHeight() * scale) / 2, 0, scale, scale)
    end

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
        if state ~= "charging" then
            if percent < 5 then
                r, g, b = 1, 0.2, 0.2
                a = (math.sin(love.timer.getTime() * 10) + 1) / 2
            elseif percent < 10 then
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
        if state == "charging" then love.graphics.setColor(0.2, 1, 0.2)
        elseif percent <= 20 then love.graphics.setColor(1, 0.2, 0.2) end
        love.graphics.rectangle("fill", x - batW + margin, batY + margin, fill, batH - (margin * 2))
    end
end

local function drawTopBar(w, h)
    local topBarCenterY = 22
    -- Título
    love.graphics.setColor(theme.colors.text_bright)
    love.graphics.setFont(fontTopBar)
    love.graphics.printf(L.get("app_title"), 0, topBarCenterY - fontTopBar:getHeight()/2, w, "center")
    -- Reloj
    love.graphics.setFont(fontClock)
    love.graphics.print(os.date("%H:%M"), 20, topBarCenterY - fontClock:getHeight()/2)
    -- Batería
    drawBattery(w - 20, topBarCenterY + 3)
end

local function drawMainList(w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)
    if viewMode == "GRID" then


        drawGrid(w, h)
    else
        -- Columna de Vista Previa (Boxart + Screenshot) - DIBUJADO AL FONDO
        if showPreview then
            local bgImage = currentScreenshot or currentImage
            if bgImage then
                local alpha = 1
                if bgImage == currentScreenshot then alpha = currentScreenshotAlpha
                elseif bgImage == currentImage then alpha = currentImageAlpha end

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
        local favScale = (iconFavorite and iconFavorite:getHeight() ~= 0) and ((40 * 0.55) / iconFavorite:getHeight()) or 1

        -- Calcular startLine aquí para que esté disponible para el selector animado
        local visibleRows = pageSize + 1
        local targetVisualRow = math.floor(visibleRows / 2) -- Try to keep selected item in the middle
        
        -- Calculate the overall scroll offset for the list content
        -- This offset determines how much the entire list shifts up/down
        local listScrollOffset = (animatedSelectionIndex - targetVisualRow) * layout.rowHeight

        -- Clamp the listScrollOffset so that the list doesn't scroll past its bounds
        local minListOffset = math.min(0, (1 - targetVisualRow) * layout.rowHeight)
        local maxListOffset = math.max(0, (#files - visibleRows) * layout.rowHeight)

        if #files <= visibleRows then
            listScrollOffset = 0 -- No scrolling needed if list is smaller than visible area
        else
            listScrollOffset = math.max(minListOffset, math.min(maxListOffset, listScrollOffset))
        end

        -- The visual position of the animated selection rectangle (fixed in the middle)
        local visualSelY = layout.listY + (targetVisualRow - 1) * layout.rowHeight + (layout.rowHeight - layout.selHeight) / 2

        -- Calculate target widths for interpolation
        local currentItemIndex = math.floor(animatedSelectionIndex)
        local nextItemIndex = math.ceil(animatedSelectionIndex)
        local interpolationFactor = animatedSelectionIndex - currentItemIndex

        local width1 = calculateItemDisplayWidth(files[currentItemIndex], layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX)
        local width2 = calculateItemDisplayWidth(files[nextItemIndex], layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX)
        
        local animatedSelectionWidth = lerp(width1, width2, interpolationFactor)
        
        -- Dibujar el rectángulo de selección animado
        love.graphics.setColor(1, 1, 1, 0.15) -- Blanco más translúcido (ligeramente más brillante)
        love.graphics.rectangle("fill", layout.selX, visualSelY, animatedSelectionWidth, layout.selHeight, 22)

        -- Lista de Archivos
        love.graphics.setFont(fontList)
        -- Determine the range of items to draw based on the clamped listScrollOffset
        local firstVisibleItemIndex = math.max(1, math.floor(1 + listScrollOffset / layout.rowHeight))
        local lastVisibleItemIndex = math.min(#files, firstVisibleItemIndex + visibleRows + 1) -- +1 for smooth transition
        for i = firstVisibleItemIndex, lastVisibleItemIndex do
            local y = layout.listY + (i - 1) * layout.rowHeight - (listScrollOffset or 0) -- Ensure listScrollOffset is not nil
            local item = files[i]
            
            -- Verificar si es el último juego jugado
            local playedSystem = nil
            if launchMode == "Juego Unico" and item.versions then
                for _, v in ipairs(item.versions) do if playedRoms[v.fullPath] then playedSystem = v.system break end end
            elseif isLastPlayed and markPlayed then -- Para modo Folder o ROMs individuales en Juego Unico
                playedSystem = utils.getSystemNameForItem(item)
            end

            local checkPath = item.fullPath or (romPath .. item.name)
            local isLastPlayed = (not item.isDir) and playedRoms[checkPath]
            
            if item.empty then
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

                local isFav = (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/"
                local favOffset = 0
                if isFav then
                    favOffset = (iconFavorite:getWidth() * favScale) + 5
                end

                local currentItemStaticWidth = calculateItemDisplayWidth(item, layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX)

                -- NEW: Dibujar fondo con trama para elementos jugados (independientemente de la selección)
                -- Determinar icono a dibujar
                if item.fullPath == "@Favorites/" then
                    iconToDraw = iconFavorite
                end
                if not iconToDraw and item.system then
                    iconToDraw = utils.getSystemContentIcon(item.system) or utils.getSystemIcon(item.system)
                end
                iconToDraw = iconToDraw or (item.isDir and iconFolder) or (currentSystemContentIcon or iconRom)
                local drawScale = layout.iconScale
                if iconToDraw == iconFavorite then drawScale = favScale -- Usar favScale precalculado
                elseif iconToDraw ~= iconFolder and iconToDraw ~= iconRom then -- Reducido de 0.8 para hacer el icono ~4px más pequeño
                    drawScale = (40 * 0.80) / iconToDraw:getHeight() -- Reducido de 0.8 para hacer el icono ~4px más pequeño
                end
                local drawY = y + (layout.rowHeight - iconToDraw:getHeight() * drawScale) / 2
                
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
                    local label = item.sourceLabel
                    if not label then
                        if romPath:find("/mnt/mmc") then label = "SD1"
                        elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                    end
                    
                    -- Calcular espacio disponible para el nombre: Ancho total - offset(70) - padding(5)
                    availableWidth = sdColX - (layout.selX + 70) - 10
                end

               -- NEW: Dibujar fondo con trama para elementos jugados (independientemente de la selección)
                if isLastPlayed and markPlayed then
                    -- Usar el color de "seleccionado" si el elemento está actualmente seleccionado (animado), sino el de "no seleccionado".
                    local ditherColor = (i == selectedIndex) and theme.colors.list_played_selected or theme.colors.list_played_unselected
                    love.graphics.setColor(ditherColor)
                    local inset = 8 -- 2px por cada lado (arriba, abajo, izquierda, derecha)
                    local rx = layout.selX + inset/2 -- Inicia en la misma X que el selector, más 2px
                    local ry = y + (layout.rowHeight - layout.selHeight) / 2 + inset/2 -- Inicia en la misma Y que el selector, más 2px
                    
                    -- Determine the width for the dithered background
                    local ditherWidth
                    if i == round(animatedSelectionIndex) then
                        ditherWidth = animatedSelectionWidth -- Usar el ancho precalculado para el elemento seleccionado
                    else
                        ditherWidth = currentItemStaticWidth -- Usar el ancho calculado para este elemento específico
                    end
                    
                    local rw = ditherWidth - inset -- El ancho del dithering es el mismo que el del selector, menos 4px
                    local rh = layout.selHeight - inset -- La altura del dithering es la misma que la del selector, menos 4px
                    
                    love.graphics.stencil(function()
                        love.graphics.rectangle("fill", rx, ry, rw, rh, 22 - inset/2) -- Usar el mismo radio de esquina que el selector, ajustado
                    end, "replace", 1)
                    love.graphics.setStencilTest("greater", 0)
                    ditherShader:send("objPos", {rx, ry})
                    love.graphics.setShader(ditherShader)
                    love.graphics.draw(getFadeGradientMesh(), rx, ry, 0, rw, rh)
                    love.graphics.setShader()
                    love.graphics.setStencilTest()
                end

                -- Dibujar icono principal (carpeta/rom/sistema)
                love.graphics.setColor(1, 1, 1, 1) -- Siempre blanco opaco para el icono
                local iconX = layout.selX + (70 - iconToDraw:getWidth() * drawScale) / 2
                love.graphics.draw(iconToDraw, iconX, drawY, 0, drawScale, drawScale)

                local textX = layout.selX + 70
                local nameToDraw = item.name
                if not item.isDir then
                    nameToDraw = nameToDraw:gsub("%.[^%.]+$", "")
                end

                -- Determinar color de texto
                local textColor = theme.colors.text_medium -- Por defecto para no seleccionado, no marcado, no jugados
                if i == selectedIndex then -- Prioridad máxima: si está seleccionado, el texto es blanco
                    textColor = theme.colors.text_bright
                elseif item.pendingDelete then -- Si no está seleccionado, pero está pendiente de borrar
                    textColor = {0.8, 0.2, 0.2} -- Rojo desaturado
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
                if i == round(animatedSelectionIndex) then -- Bolding should follow the rounded animated cursor
                    love.graphics.print(nameToDraw, textX, textY)
                    love.graphics.print(nameToDraw, textX + 1, textY)
                else
                    love.graphics.print(nameToDraw, textX, textY)
                end

                if showSystemIcons then
                    -- Dibujar iconos de sistemas apilados a la derecha
                    local systems = {}
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
                        local icon = utils.getSystemIcon(sys)
                        if icon then -- Asegurar que el icono existe
                            local iconColor = (isLastPlayed and markPlayed and sys == playedSystem) and {0.2, 0.8, 0.3, 1} or {1, 1, 1, 1}
                            love.graphics.setColor(iconColor)
                            local scale = iconSize / icon:getHeight() -- Escala para los iconos de sistema apilados
                            love.graphics.draw(icon, startX + (idx-1)*(iconSize+spacing), y + (layout.rowHeight - iconSize)/2, 0, scale, scale)
                        end
                    end
                else
                    local label = item.sourceLabel
                    if not label then
                        if romPath:find("/mnt/mmc") then label = "SD1"
                        elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                    end
                    if label and label ~= "Fav" then
                    -- Colores distintivos para SD
                    local baseColor
                    if label == "SD1" then baseColor = {0.4, 0.8, 1}
                    elseif label == "SD2" then baseColor = {1, 0.8, 0.4}
                    elseif label == "SD½" then baseColor = {0.8, 0.5, 1}
                    else baseColor = theme.colors.text_dim end

                    if i == selectedIndex then love.graphics.setColor(baseColor)
                    else love.graphics.setColor(baseColor[1] * 0.5, baseColor[2] * 0.5, baseColor[3] * 0.5) end

                    love.graphics.setFont(fontSmall) -- Usar fuente más pequeña para las etiquetas SD
                    love.graphics.printf(label, sdColX, textY, sdColW, "center")
                    love.graphics.setFont(fontList) -- Restaurar fuente original de la lista
                    end
                end
            end
        end
    end
    
    -- Scrollbar
    drawScrollbar()

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

local function draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if state == "SCRAPER_VIEW" or state == "SCRAPING_IN_PROGRESS" or state == "SCRAPER_RESULTS" or state == "SCRAPER_OPTIONS" then
        drawScraperView()
        if state == "SCRAPER_OPTIONS" or closingMenu then
            drawOverlayMenus()
        end
        drawOverlayMenus() -- For Help
        return -- No dibujar la lista debajo
    end
    
    if state == "SAVE_MANAGER" then
        drawSaveManager()
        drawOverlayMenus() -- For Help
        return
    end
    
    if state == "CLEANUP_MENU" then
        drawCleanupMenu()
        drawOverlayMenus() -- For Help
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
    
    local showPreview = (currentImage ~= nil or currentScreenshot ~= nil)
    local previewBoxW = 200 -- Valor por defecto
    
    if showPreview then
        local maxPreviewW = w * 0.5
        local availableH = h - layout.listY - 40 -- Espacio vertical disponible
        
        local ar1 = currentImage and (currentImage:getWidth() / currentImage:getHeight()) or 0
        local ar2 = currentScreenshot and (currentScreenshot:getWidth() / currentScreenshot:getHeight()) or 0
        local padding = (currentImage and currentScreenshot) and 15 or 0
        
        local calculatedW = maxPreviewW
        
        if currentImage and currentScreenshot then
            local combinedInvAr = (1/ar1) + (1/ar2)
            calculatedW = (availableH - padding) / combinedInvAr
        elseif currentImage then
             calculatedW = availableH * ar1
        elseif currentScreenshot then
             calculatedW = availableH * ar2
        end
        
        previewBoxW = math.min(maxPreviewW, calculatedW)
        previewBoxW = math.max(100, previewBoxW) -- Mínimo razonable
    end

    local previewBoxX = sdColX - previewBoxW - 10
    if romPath == "@Favorites/" then
         previewBoxX = layout.scrollbarX - previewBoxW - 10
    end

    -- Mensaje de indexación en "Modo Único" si el índice no está listo
    if launchMode == "Juego Unico" and isVirtualRoot and not romIndex and #files == 0 then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(L.get("indexing"), 0, h/2 - 20, w, "center")
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        local msg = isIndexing and indexStateMessage or L.get("loading_index")
        love.graphics.printf(msg, 0, h/2 + 20, w, "center")

        -- Título (Indexación)
        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.setFont(fontTopBar)
        love.graphics.printf(L.get("app_title"), 0, 15, w, "center")
        love.graphics.setFont(fontClock)
        love.graphics.print(os.date("%H:%M"), 20, 17)
        drawBattery(w - 25, 20)
        love.graphics.setFont(fontSmall)
        local displayPath = isVirtualRoot and L.get("all_systems") or romPath
        if not isVirtualRoot then
            local shortened = displayPath:match("ROMS/.*")
            if shortened then
                displayPath = shortened
            elseif displayPath:find("Simulador_SD") then
                displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
            end
        end
        love.graphics.printf(displayPath, 0, 45, w, "center")
        
        drawOverlayMenus()
        
        drawBottomBar()
        return
    end

    -- Mensaje si la lista está vacía (y no estamos indexando)
    if #files == 0 and not isIndexing then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(L.get("no_items"), 0, h/2, w, "center")
    end

    drawMainList(w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)

    -- Dibujar el degradado superior sobre la lista de ROMs
    -- Posicionalmente: encima de la lista de roms, debajo de los titulos reloj etc.
    local gradientHeight = 100 -- Altura del degradado en píxeles (según la solicitud original "100px 70% negro")
    love.graphics.setColor(0, 0, 0, 1) -- Usar color negro para la malla, el alfa está en los vértices (el alfa del degradado está en los vértices de la malla)
    love.graphics.draw(getTopFadeGradientMesh(), 0, 0, 0, w, gradientHeight)

    -- NEW: Dibujar el degradado inferior encima de la barra de estado
    local bottomGradientHeight = 20 -- Altura de 20 píxeles
    local bottomBarHeight = 30 -- Altura de la barra inferior (definida en drawBottomBar)
    local gradientY = h - bottomBarHeight - bottomGradientHeight
    love.graphics.setColor(0, 0, 0, 1) -- Usar color negro para la malla, el alfa está en los vértices
    love.graphics.draw(getBottomFadeGradientMesh(), 0, gradientY, 0, w, bottomGradientHeight)

    -- Título (Dibujado después de la lista para quedar encima del fondo/dithering)
    drawTopBar(w, h)
    
    -- Path actual
    love.graphics.setFont(fontSmall)
    local displayPath = isVirtualRoot and L.get("all_systems") or romPath
    if not isVirtualRoot then
        local shortened = displayPath:match("ROMS/.*")
        if shortened then
            displayPath = shortened
        elseif displayPath:find("Simulador_SD") then
            displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
        end
    end
    love.graphics.printf(displayPath, 0, 45, w, "center")

    drawOverlayMenus()

    -- Barra de estado
    drawBottomBar()
    
    -- Dibujar panel de letra al final para que quede encima de todo
    drawJumpLetter()

    -- Draw Search UI if active
    if state == "SEARCH" or keyboardAnim > 0 then
        local t = keyboardAnim
        local ease = 1 - (1 - t)^3
        local panelH = 250
        local currentY = h - (panelH * ease)

        -- Fondo oscuro para el teclado
        love.graphics.setColor(0, 0, 0, 0.9 * ease)
        love.graphics.rectangle("fill", 0, currentY, w, panelH)
        
        -- Barra de búsqueda
        local r, g, b = unpack(theme.colors.text_white)
        love.graphics.setColor(r, g, b, ease)
        love.graphics.setFont(fontTitle)
        love.graphics.printf(L.get("search_label", searchQuery), 20, currentY + 10, w - 40, "left")
        
        -- Teclado Virtual
        love.graphics.setFont(fontMedium)
        local keySize = 40
        local spacing = 5
        local startY = currentY + 50
        
        -- Calcular ancho del bloque principal (10 teclas)
        local mainBlockWidth = 10 * (keySize + spacing) - spacing
        -- Centrar bloque principal en el espacio disponible a la izquierda (reservando 100px para botones laterales)
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
                    y = startY + (r-1) * (keySize + spacing)
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
    if isIndexing then
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
