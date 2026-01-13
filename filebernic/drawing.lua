local function drawBottomBar()
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.bottom_bar_background)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(theme.colors.text_bright)
    
    local barCenterY = h - 15
    local textH = fontMedium:getHeight()
    local textY = barCenterY - textH / 2
    
    local x = 20
    local scale = 0.8

    local function drawHint(icon, text)
        local iconH = icon:getHeight() * scale
        local iconY = barCenterY - iconH / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
        x = x + love.graphics.getFont():getWidth(text) + 20
    end

    if state == "LIST" then
        drawHint(buttonIcons.a, "Ok")
        drawHint(buttonIcons.b, "Back")
        drawHint(buttonIcons.y, "Menu")
        drawHint(buttonIcons.x, "Select")
        drawHint(buttonIcons.start, "Opciones")
        -- Select button with offset
        local icon = buttonIcons.select
        local text = "Salir"
        local iconH = icon:getHeight() * scale
        local iconY = barCenterY - iconH / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
    elseif state == "DELETE_MENU" or state == "POST_GAME" then
        drawHint(buttonIcons.a, "Confirmar")
        drawHint(buttonIcons.b, "Cancelar")
    elseif state == "INFO_VIEW" then
        drawHint(buttonIcons.b, "Volver")
    elseif state == "SCRAPER_VIEW" then
        drawHint(buttonIcons.a, "Buscar")
        drawHint(buttonIcons.b, "Volver")
        drawHint(buttonIcons.y, "Opciones")
    elseif state == "SCRAPER_OPTIONS" then
        drawHint(buttonIcons.a, "Seleccionar")
        drawHint(buttonIcons.b, "Volver")
    elseif state == "SCRAPER_RESULTS" then
        drawHint(buttonIcons.a, "Guardar")
        drawHint(buttonIcons.b, "Volver")
    elseif state == "SAVE_MANAGER" then
        drawHint(buttonIcons.a, "Copiar a otra SD")
        drawHint(buttonIcons.b, "Volver")
    elseif state == "CLEANUP_MENU" then
        drawHint(buttonIcons.a, "Acción")
        drawHint(buttonIcons.b, "Salir")
    end
end

local function drawSideMenu()
    local w, h = love.graphics.getDimensions()
    
    -- Animación (Slide in)
    local t = menuAnim
    local ease = 1 - (1 - t)^3 -- Cubic ease out
    local offset = (w / 2) * (1 - ease)
    
    -- Calcular ancho dinámico basado en contenido
    love.graphics.setFont(fontList)
    local maxW = 0
    for _, opt in ipairs(menuOptions) do
        local text = type(opt) == "table" and opt.text or opt
        local width = fontList:getWidth(text)
        if type(opt) == "table" and opt.icon then width = width + 35 end
        if width > maxW then maxW = width end
    end
    local menuW = math.max(300, maxW + 60) -- Mínimo 300px, o contenido + padding
    local menuX = w - menuW
    local slideX = menuX + (menuW * (1 - ease))
    
    -- Overlay oscuro (Fade in)
    local r, g, b, a = unpack(theme.colors.overlay_dark)
    love.graphics.setColor(r, g, b, a * ease)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Panel lateral
    love.graphics.setColor(theme.colors.side_menu_background)
    love.graphics.rectangle("fill", slideX, 0, menuW, h)
    
    -- Línea separadora
    love.graphics.setColor(theme.colors.side_menu_separator)
    love.graphics.line(slideX, 0, slideX, h)

    -- Título
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.setFont(fontTitle)
    love.graphics.printf(menuTitle, slideX + 20, 40, menuW - 40, "left")

    -- Mensaje
    local startY = 90
    if menuMessage and menuMessage ~= "" then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.printf(menuMessage, slideX + 20, 80, menuW - 40, "left")
        local width, wrappedtext = fontMedium:getWrap(menuMessage, menuW - 40)
        startY = 80 + (#wrappedtext * fontMedium:getHeight()) + 30
    end

    -- Opciones
    love.graphics.setFont(fontList)
    local rowHeight = 40
    for i, option in ipairs(menuOptions) do
        local rowY = startY + (i-1) * rowHeight
        local centerY = rowY + rowHeight / 2
        
        local text = type(option) == "table" and option.text or option
        local icon = type(option) == "table" and option.icon or nil
        
        local labelColor, valueColor

        if i == menuSelection then
            love.graphics.setColor(theme.colors.selection_accent)
            love.graphics.rectangle("fill", slideX, rowY, menuW, rowHeight)
            labelColor = theme.colors.text_white
            valueColor = theme.colors.text_white
        else
            if type(option) == "table" and option.played and markPlayed then
                local r,g,b,a = unpack(theme.colors.list_played_unselected)
                love.graphics.setColor(r,g,b,a)
                love.graphics.rectangle("fill", slideX, rowY, menuW, rowHeight)
            end

            if type(option) == "string" and option:find("Borrar") then
                labelColor = {1, 0.4, 0.4} -- Rojo suave
            elseif type(option) == "string" and option:find("Limpieza") then
                labelColor = {0.8, 0.1, 0.1} -- Rojo oscuro
            else
                labelColor = theme.colors.text_dim
            end
            valueColor = theme.colors.selection_accent -- Otro tono (Azul claro)
        end

        local label, value = nil, nil
        if type(option) == "string" then
            label, value = option:match("^(.-):%s*(.+)$")
        end

        local textY = centerY - fontList:getHeight() / 2

        if label and value then
            love.graphics.setColor(labelColor)
            love.graphics.print(label .. ":", slideX + 20, textY)
            love.graphics.setColor(valueColor)
            local valW = fontList:getWidth(value)
            love.graphics.print(value, slideX + menuW - 20 - valW, textY)
        elseif icon then
            love.graphics.setColor(1, 1, 1)
            local iconH = 24
            local scale = iconH / icon:getHeight()
            love.graphics.draw(icon, slideX + 20, centerY - iconH/2, 0, scale, scale)
            love.graphics.setColor(labelColor)
            love.graphics.print(text, slideX + 55, textY)
        else
            love.graphics.setColor(labelColor)
            love.graphics.print(text, slideX + 20, textY)
        end
    end
end

local function drawHelpOverlay()
    if not showHelp then return end
    local w, h = love.graphics.getDimensions()
    
    -- Animación (Slide in)
    local t = menuAnim
    local ease = 1 - (1 - t)^3 -- Cubic ease out
    local offset = (w / 2) * (1 - ease)
    
    -- Overlay oscuro (Fade in)
    local r, g, b, a = unpack(theme.colors.overlay_dark)
    love.graphics.setColor(r, g, b, a * ease)
    love.graphics.rectangle("fill", 0, 0, w/2, h)
    
    -- Panel lateral
    love.graphics.setColor(theme.colors.side_menu_background)
    love.graphics.rectangle("fill", w/2 + offset, 0, w/2, h)
    
    -- Línea separadora
    love.graphics.setColor(theme.colors.side_menu_separator)
    love.graphics.line(w/2 + offset, 0, w/2 + offset, h)

    local contentX = w/2 + offset

    love.graphics.setColor(theme.colors.text_white)
    love.graphics.setFont(fontTitle)
    love.graphics.printf("Ayuda - Controles", contentX + 20, 40, w/2 - 40, "left")
    
    local list = helpData[state] or helpData.DEFAULT
    love.graphics.setFont(fontMedium)
    local startY = 90
    for i, item in ipairs(list) do
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.draw(item.icon, contentX + 20, startY + (i-1)*40, 0, 0.8, 0.8)
        love.graphics.print(item.text, contentX + 60, startY + (i-1)*40 + 2)
    end
end

local function drawInfoView()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    local currentItem = focusedItem or files[selectedIndex]
    if not currentItem then return end

    -- Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(currentItem.name, 0, 20, w, "center")

    -- Layout dividido: Frontal (Izq), Screen (Der), Info (Abajo)
    local boxX, boxY, boxW, boxH = 40, 70, 200, 260
    local screenX, screenY, screenW, screenH = 280, 70, 320, 200
    local textX, textY, textW, textH = 280, 280, 320, 180
    
    -- 1. Frontal (Boxart)
    love.graphics.setColor(theme.colors.text_medium)
    love.graphics.print("Frontal", boxX, boxY - 20)
    if currentImage then
        love.graphics.setColor(theme.colors.text_white)
        local scale = math.min(boxW/currentImage:getWidth(), boxH/currentImage:getHeight())
        love.graphics.draw(currentImage, boxX + (boxW - currentImage:getWidth()*scale)/2, boxY + (boxH - currentImage:getHeight()*scale)/2, 0, scale, scale)
    else
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
        love.graphics.printf("No Imagen", boxX, boxY + boxH/2 - 10, boxW, "center")
    end

    -- 2. Screen (Screenshot)
    love.graphics.setColor(theme.colors.text_medium)
    love.graphics.print("Screen", screenX, screenY - 20)
    if currentScreenshot then
        love.graphics.setColor(theme.colors.text_white)
        local scale = math.min(screenW/currentScreenshot:getWidth(), screenH/currentScreenshot:getHeight())
        love.graphics.draw(currentScreenshot, screenX + (screenW - currentScreenshot:getWidth()*scale)/2, screenY + (screenH - currentScreenshot:getHeight()*scale)/2, 0, scale, scale)
    else
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("line", screenX, screenY, screenW, screenH)
        love.graphics.printf("No Preview", screenX, screenY + screenH/2 - 10, screenW, "center")
    end

    -- 3. Info (Description + Year)
    love.graphics.setColor(theme.colors.text_medium)
    local infoTitle = "Info"
    if currentYear then infoTitle = infoTitle .. " (" .. currentYear .. ")" end
    love.graphics.print(infoTitle, textX, textY - 20)
    
    love.graphics.setColor(theme.colors.text_dim)
    love.graphics.setFont(fontSmall)
    if currentDescription and currentDescription ~= "" then
        love.graphics.printf(currentDescription, textX, textY, textW, "left")
    else
        love.graphics.printf("Sin información.", textX, textY, textW, "left")
    end

    -- Hint de volver
    drawBottomBar()
end

local function drawScraperView()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background) -- Fondo de pantalla completa

    local currentItem = focusedItem or files[selectedIndex]
    if not currentItem then return end

    -- Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf("Scraper: " .. currentItem.name, 0, 15, w, "center")

    if state == "SCRAPER_VIEW" then
        -- Layout dividido: Frontal (Izq), Screen (Der), Info (Abajo)
        local boxX, boxY, boxW, boxH = 40, 80, 200, 260
        local screenX, screenY, screenW, screenH = 280, 100, 320, 200
        local textX, textY, textW, textH = 280, 320, 320, 70
        
        -- 1. Frontal (Boxart)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.print("Frontal", boxX, boxY - 20)
        if currentImage then
            love.graphics.setColor(theme.colors.text_white)
            local scale = math.min(boxW/currentImage:getWidth(), boxH/currentImage:getHeight())
            love.graphics.draw(currentImage, boxX + (boxW - currentImage:getWidth()*scale)/2, boxY + (boxH - currentImage:getHeight()*scale)/2, 0, scale, scale)
        else
            love.graphics.setColor(theme.colors.placeholder_background)
            love.graphics.rectangle("line", boxX, boxY, boxW, boxH)
            love.graphics.printf("No Imagen", boxX, boxY + boxH/2 - 10, boxW, "center")
        end

        -- 2. Screen (Screenshot)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.print("Screen", screenX, screenY - 20)
        if currentScreenshot then
            love.graphics.setColor(theme.colors.text_white)
            local scale = math.min(screenW/currentScreenshot:getWidth(), screenH/currentScreenshot:getHeight())
            love.graphics.draw(currentScreenshot, screenX + (screenW - currentScreenshot:getWidth()*scale)/2, screenY + (screenH - currentScreenshot:getHeight()*scale)/2, 0, scale, scale)
        else
            love.graphics.setColor(theme.colors.placeholder_background)
            love.graphics.rectangle("line", screenX, screenY, screenW, screenH)
            love.graphics.printf("No Preview", screenX, screenY + screenH/2 - 10, screenW, "center")
        end

        -- 3. Info (Description)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.print("Info", textX, textY - 20)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.setFont(fontSmall)
        if currentDescription and currentDescription ~= "" then
            love.graphics.printf(currentDescription, textX, textY, textW, "left")
        else
            love.graphics.printf("Sin información.", textX, textY, textW, "left")
        end

        -- Botón de Scrapear
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, 410, 200, 40, 5)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Buscar Datos", w/2 - 100, 420, 200, "center")

    elseif state == "SCRAPING_IN_PROGRESS" then
        love.graphics.printf("Consultando bases de datos...", 0, h/2, w, "center")

    elseif state == "BATCH_SCRAPING" then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Scraping en Lote", 0, h/2 - 60, w, "center")
        
        love.graphics.setFont(fontMedium)
        love.graphics.printf("Procesando: " .. scraperProgress.currentName, 0, h/2 - 20, w, "center")
        
        -- Barra de progreso
        local barW = 400
        local barX = (w - barW) / 2
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", barX, h/2 + 20, barW * (scraperProgress.current / scraperProgress.total), 20)
        
        love.graphics.printf(scraperProgress.current .. " / " .. scraperProgress.total, 0, h/2 + 50, w, "center")
        love.graphics.printf("Éxitos: " .. scraperProgress.successes .. " | Fallos: " .. scraperProgress.failures, 0, h/2 + 80, w, "center")

    elseif state == "SCRAPER_RESULTS" then
        love.graphics.setFont(fontMedium)
        love.graphics.printf("Resultados:", 20, 60, w, "left")
        
        if #scraperResults == 0 then
            love.graphics.printf("No se encontraron resultados.", 20, 100, w, "left")
        else
            -- Lista horizontal de miniaturas
            local listY = 90
            local thumbSize = 80
            local spacing = 10
            local startX = 20
            
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
                love.graphics.print("Frontal", boxX, boxY - 20)
                if sel.image then
                love.graphics.setColor(theme.colors.text_white)
                    local scale = math.min(boxW/sel.image:getWidth(), boxH/sel.image:getHeight())
                    love.graphics.draw(sel.image, boxX + (boxW - sel.image:getWidth()*scale)/2, boxY + (boxH - sel.image:getHeight()*scale)/2, 0, scale, scale)
                end
                
                -- Screen
                love.graphics.setColor(theme.colors.text_medium)
                love.graphics.print("Screen", screenX, screenY - 20)
                if sel.screenshot then
                    love.graphics.setColor(theme.colors.text_white)
                    local scale = math.min(screenW/sel.screenshot:getWidth(), screenH/sel.screenshot:getHeight())
                    love.graphics.draw(sel.screenshot, screenX + (screenW - sel.screenshot:getWidth()*scale)/2, screenY + (screenH - sel.screenshot:getHeight()*scale)/2, 0, scale, scale)
                else
                    love.graphics.setColor(theme.colors.text_dim)
                    love.graphics.printf("No Screen", screenX, screenY + screenH/2, screenW, "center")
                end
                
                -- Info
                love.graphics.setFont(fontSmall)
                love.graphics.setColor(theme.colors.text_white)
                local infoText = sel.description or "Sin descripción"
                if sel.source then
                    infoText = "[" .. sel.source .. "] " .. infoText
                end
                love.graphics.printf(infoText, textX, textY, textW, "left")
                end
            end
        end
    end

    -- Hint de volver
    drawBottomBar()
end

local function drawScrollbar()
    love.graphics.setColor(theme.colors.scrollbar_background)
    love.graphics.rectangle("fill", layout.scrollbarX, layout.listY, 4, layout.scrollbarH)
    if #files > 1 then
        local h = layout.scrollbarH / (#files / 14)
        local y = layout.listY + ((selectedIndex - 1) / (#files - 1)) * (layout.scrollbarH - h)
        love.graphics.setColor(theme.colors.scrollbar_handle)
        love.graphics.rectangle("fill", layout.scrollbarX, y, 4, math.max(10, h))
    end
end

local function drawSaveManager()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)
    
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf("Gestor de Partidas (Save Games)", 0, 20, w, "center")
    
    love.graphics.setFont(fontList)
    local startY = 80
    
    if #saveFiles == 0 then
        love.graphics.printf("No se encontraron partidas guardadas.", 0, h/2, w, "center")
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
    love.graphics.printf("Limpieza de Archivos", 0, 15, w, "center")
    
    if not cleanupData.scanned and not cleanupData.scanning then
        -- Pantalla inicial
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h/2 - 25, 200, 50, 10)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("BUSCAR", w/2 - 100, h/2 - 10, 200, "center")
        
    elseif cleanupData.scanning then
        -- Barra de progreso
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Escaneando archivos...", 0, h/2 - 40, w, "center")
        
        love.graphics.setColor(theme.colors.placeholder_background)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300, 20)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 150, h/2, 300 * cleanupData.progress, 20)
        
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(theme.colors.text_dim)
        love.graphics.printf(cleanupData.currentFile or "", 0, h/2 + 25, w, "center")
        
    else
        -- Resultados (2 Columnas)
        local hasImages = #cleanupData.orphanedImages > 0
        local colCount = hasImages and 3 or 2
        local colW = (w - 40 - (colCount-1)*10) / colCount
        
        local col1X = 20
        local col2X = col1X + colW + 10
        local col3X = col2X + colW + 10
        
        -- Cabeceras
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(1, 0.4, 0.4) -- Rojo
        love.graphics.printf("States Huérfanos", col1X, 60, colW, "center")
        love.graphics.setColor(1, 1, 0.4) -- Amarillo
        love.graphics.printf("Juegos Duplicados", col2X, 60, colW, "center")
        if hasImages then
            love.graphics.setColor(0.4, 1, 0.4) -- Verde
            love.graphics.printf("Imágenes Huérfanas", col3X, 60, colW, "center")
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
        love.graphics.printf("BORRAR TODOS LOS STATES", col1X, btnY + 5, colW, "center")
        
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
                selTitle = "Acción: Borrar TODOS los estados huérfanos"
            elseif cleanupData.orphans[cleanupData.cursor.row - 1] then
                selItem = cleanupData.orphans[cleanupData.cursor.row - 1]
                selTitle = "Estado Huérfano"
            end
        elseif cleanupData.cursor.col == 3 then
            if cleanupData.orphanedImages[cleanupData.cursor.row] then
                selItem = cleanupData.orphanedImages[cleanupData.cursor.row]
                selTitle = "Imagen Huérfana"
            end
        else
            if cleanupData.duplicates[cleanupData.cursor.row] then
                selItem = cleanupData.duplicates[cleanupData.cursor.row]
                selTitle = "Juego Duplicado"
            end
        end

        love.graphics.setColor(theme.colors.text_white)
        love.graphics.setFont(fontMedium)
        love.graphics.print(selTitle, 20, infoY + 10)
        
        if selItem then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.text_medium)
            love.graphics.print("Archivo: " .. selItem.name, 20, infoY + 35)
            
            local relPath = selItem.fullPath:match("ROMS/(.*)") or selItem.fullPath
            drawTrimmedStart("Ruta: " .. relPath, 20, infoY + 55, w - 140, fontSmall)
            
            if selItem.system then
                love.graphics.print("Sistema: " .. selItem.system .. " | Ubicación: " .. selItem.location, 20, infoY + 75)
            else
                love.graphics.print("Ubicación: " .. selItem.location, 20, infoY + 75)
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
            love.graphics.printf("¿Confirmar Acción?", mx, my + 20, modalW, "center")
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
            local totalW = buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" Confirmar   ") + buttonIcons.b:getWidth()*iconScale + fontMedium:getWidth(" Cancelar")
            local startX = mx + (modalW - totalW) / 2
            
            love.graphics.draw(buttonIcons.a, startX, iconY, 0, iconScale, iconScale)
            love.graphics.print(" Confirmar   ", startX + buttonIcons.a:getWidth()*iconScale, iconY + 2)
            love.graphics.setColor(1, 1, 1, 1) -- Reset color for B icon
            love.graphics.draw(buttonIcons.b, startX + buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" Confirmar   "), iconY, 0, iconScale, iconScale)
            love.graphics.print(" Cancelar", startX + buttonIcons.a:getWidth()*iconScale + fontMedium:getWidth(" Confirmar   ") + buttonIcons.b:getWidth()*iconScale, iconY + 2)
        end
    end
    drawBottomBar()
    drawHelpOverlay()
end

local function drawGrid(w, h)
    local cols = gridCols
    local rows = 3
    local cellW = w / cols
    local cellH = (h - 110) / rows -- Restar header/footer (Aumentado margen inferior para evitar solape y texto)
    local startY = 50
    
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
        
        local x = c * cellW
        local y = startY + r * cellH
        local item = files[i]
        
        -- Fondo selección
        if i == selectedIndex then
            love.graphics.setColor(theme.colors.selection_accent)
            love.graphics.rectangle("fill", x + 5, y + 8, cellW - 10, cellH - 5, 5)
        end
        
        local contentWidth = cellW - 10

        -- Cargar imagen si no se ha intentado
        if not item.isDir and not item.gridImage and not item.triedGridImage then
            item.triedGridImage = true
            local base = item.name:gsub("%..-$", "")
            local path = muosArtPath .. base .. ".png"
            local f = io.open(path, "rb")
            if f then
                local data = f:read("*a")
                f:close()
                if data then
                    local success, img = pcall(function() return love.graphics.newImage(love.filesystem.newFileData(data, "cover.png")) end)
                    if success then item.gridImage = img end
                end
            end
        end

        -- Dibujar imagen o icono
        if item.gridImage then
            love.graphics.setColor(1, 1, 1)
            local scale = math.min(contentWidth / item.gridImage:getWidth(), (cellH - 50) / item.gridImage:getHeight())
            local imgW = item.gridImage:getWidth() * scale
            local imgH = item.gridImage:getHeight() * scale
            local ix = x + 5 + (contentWidth - imgW) / 2
            local iy = y + 10 + ((cellH - 50) - imgH) / 2
            love.graphics.draw(item.gridImage, ix, iy, 0, scale, scale)
        else
            love.graphics.setColor(1, 1, 1)
            local icon = item.icon or (item.isDir and iconFolder)
            
            if not icon then
                if item.system then
                    icon = getSystemContentIcon(item.system)
                end
                if not icon then icon = currentSystemContentIcon or iconRom end
            end
            
            local availableH = cellH - 45 -- Espacio disponible restando texto y márgenes
            local availableW = cellW - 10
            local scale = math.min(availableW / icon:getWidth(), availableH / icon:getHeight()) * 0.85
            local ix = x + (cellW - icon:getWidth()*scale)/2
            local iy = y + 5 + (availableH - icon:getHeight()*scale)/2
            love.graphics.draw(icon, ix, iy, 0, scale, scale)
        end
        
        -- Texto
        love.graphics.setFont(fontMedium)
        local textFont = fontMedium
        local _, wrappedLines = textFont:getWrap(item.name, contentWidth)

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
        local textY = y + cellH - 40 + (40 - textBlockHeight) / 2
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf(textToPrint, x + 5, textY, contentWidth, "center")
    end
end

local function draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if state == "SCRAPER_VIEW" or state == "SCRAPING_IN_PROGRESS" or state == "SCRAPER_RESULTS" or state == "INFO_VIEW" or state == "SCRAPER_OPTIONS" then
        if state == "INFO_VIEW" then
            drawInfoView()
        else
            drawScraperView()
        end
        if state == "SCRAPER_OPTIONS" then
            drawSideMenu()
        end
        drawHelpOverlay()
        return -- No dibujar la lista debajo
    end
    
    if state == "SAVE_MANAGER" then
        drawSaveManager()
        return
    end
    
    if state == "CLEANUP_MENU" then
        drawCleanupMenu()
        return
    end
    
    -- Layout dinámico
    -- Scrollbar fija a la derecha
    local scrollbarMargin = 10
    layout.scrollbarX = w - scrollbarMargin
    
    -- Columna SD (derecha de la imagen, izquierda del scroll)
    local sdColW = 40
    local sdColX = layout.scrollbarX - sdColW - 5
    
    -- Columna Preview (izquierda de SD)
    local previewBoxW = 200 -- Reducido para evitar exceso de espacio
    local previewBoxX = sdColX - previewBoxW - 10
    
    local showPreview = (currentImage ~= nil or currentScreenshot ~= nil)

    if showPreview then
        layout.selWidth = previewBoxX - 20 -- Ajustar lista al espacio restante
    else
        if launchMode == "Juego Unico" then
            layout.selWidth = layout.scrollbarX - 15
        else
            layout.selWidth = sdColX - 20
        end
    end

    -- Título
    love.graphics.setColor(theme.colors.text_bright)
    love.graphics.setFont(fontTitle)
    love.graphics.printf("FileBernic Rom Manager", 0, 15, w, "center")
    
    -- Path actual
    love.graphics.setFont(fontSmall)
    local displayPath = isVirtualRoot and "Todos los Sistemas" or romPath
    if not isVirtualRoot then
        local shortened = displayPath:match("ROMS/.*")
        if shortened then
            displayPath = shortened
        elseif displayPath:find("Simulador_SD") then
            displayPath = displayPath:gsub(".*Simulador_SD/", "ROMS/")
        end
    end
    love.graphics.printf(displayPath, 0, 45, w, "center")

    -- Mensaje de indexación en "Modo Único" si el índice no está listo
    if launchMode == "Juego Unico" and isVirtualRoot and not romIndex then
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Indexando ROMs...", 0, h/2 - 20, w, "center")
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_dim)
        local msg = isIndexing and indexStateMessage or "Cargando índice..."
        love.graphics.printf(msg, 0, h/2 + 20, w, "center")
        drawBottomBar()
        drawHelpOverlay()
        return
    end

    if viewMode == "GRID" then
        drawGrid(w, h)
        -- Mostrar nombre completo del archivo seleccionado encima de la barra de estado
        if files[selectedIndex] then
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.printf(files[selectedIndex].name, 10, h - 55, w - 20, "center")
        end
    else

    -- Lista de Archivos
    love.graphics.setFont(fontList)
    local startLine = math.max(1, selectedIndex - 7)
    for i = startLine, math.min(#files, startLine + pageSize) do
        local y = layout.listY + (i - startLine) * layout.rowHeight
        local item = files[i]
        
        -- Verificar si es el último juego jugado
        local checkPath = item.fullPath or (romPath .. item.name)
        local isLastPlayed = (not item.isDir) and playedRoms[checkPath]
        
        if i == selectedIndex then
            -- Cursor gris claro
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.rectangle("fill", 15, y + (layout.rowHeight - layout.selHeight) / 2, layout.selWidth, layout.selHeight, 4)
            -- Texto e iconos en negro
            love.graphics.setColor(0, 0, 0)
        else
            if isLastPlayed and markPlayed then
                love.graphics.setColor(theme.colors.list_played_unselected)
                love.graphics.rectangle("fill", 15, y + (layout.rowHeight - layout.selHeight) / 2, layout.selWidth, layout.selHeight, 4)
            end
            love.graphics.setColor(theme.colors.text_medium)
        end

        
        if item.empty then
            love.graphics.setColor(theme.colors.text_disabled)
            love.graphics.printf(item.name, 55, y, layout.selWidth - 10, "left")
        else
            if item.selected then
                love.graphics.setColor(theme.colors.selection_accent)
            end
            
            local iconToDraw = item.icon or (item.isDir and iconFolder) or (currentSystemContentIcon or iconRom)
            local drawScale = layout.iconScale
            
            if iconToDraw == currentSystemContentIcon or iconToDraw == item.icon then
                drawScale = (layout.rowHeight * 0.8) / iconToDraw:getHeight()
            end
            
            local drawY = y + (layout.rowHeight - iconToDraw:getHeight() * drawScale) / 2
            love.graphics.draw(iconToDraw, 25, drawY, 0, drawScale, drawScale)
            
            local availableWidth
            if launchMode == "Juego Unico" then
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
                
                local startX = layout.scrollbarX - totalW - 5
                availableWidth = startX - 55 - 10
            else
                -- Calcular etiqueta SD
                local label = item.sourceLabel
                if not label then
                    if romPath:find("/mnt/mmc") then label = "SD1"
                    elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                end
                
                local labelWidth = 0
                if label then labelWidth = fontList:getWidth(label) end
                
                -- Calcular espacio disponible para el nombre: Ancho total - icono(55) - label - padding(5)
                availableWidth = layout.selWidth - 55 - labelWidth - 5
            end

            local nameToDraw = item.name
            
            if fontList:getWidth(nameToDraw) > availableWidth then
                while fontList:getWidth(nameToDraw .. "...") > availableWidth and #nameToDraw > 0 do
                    nameToDraw = nameToDraw:sub(1, -2)
                end
                nameToDraw = nameToDraw .. "..."
            end
            
            -- Centrar el texto verticalmente en la fila
            local textY = y + (layout.rowHeight - fontList:getHeight()) / 2
            
            if i == selectedIndex then
                love.graphics.print(nameToDraw, 55, textY)
                love.graphics.print(nameToDraw, 56, textY)
            else
                love.graphics.print(nameToDraw, 55, textY)
            end

            if launchMode == "Juego Unico" then
                -- Dibujar iconos de sistemas apilados a la derecha
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
                local startX = layout.scrollbarX - totalW - 5
                
                for idx, sys in ipairs(systems) do
                    local icon = getSystemIcon(sys)
                    if icon then
                        love.graphics.setColor(1, 1, 1)
                        local scale = iconSize / icon:getHeight()
                        love.graphics.draw(icon, startX + (idx-1)*(iconSize+spacing), y + (layout.rowHeight - iconSize)/2, 0, scale, scale)
                    end
                end
            else
                local label = item.sourceLabel
                if not label then
                    if romPath:find("/mnt/mmc") then label = "SD1"
                    elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                end
                if label then
                -- Colores distintivos para SD
                if label == "SD1" then love.graphics.setColor(0.4, 0.8, 1)
                elseif label == "SD2" then love.graphics.setColor(1, 0.8, 0.4)
                elseif label == "SD½" then love.graphics.setColor(0.8, 0.5, 1)
                else love.graphics.setColor(theme.colors.text_dim) end

                if i == selectedIndex then
                    -- Oscurecer un poco para contraste sobre fondo claro
                    local r, g, b = love.graphics.getColor()
                    love.graphics.setColor(r * 0.5, g * 0.5, b * 0.5)
                end
                love.graphics.printf(label, sdColX, y, sdColW, "center")
                end
            end
        end
    end

    -- Scrollbar
    drawScrollbar()

    -- Columna de Vista Previa (Boxart + Screenshot)
    if showPreview then
        local previewY = layout.listY

        -- Boxart (Frontal)
        if currentImage then
            local boxMaxH = 165
            local scale = math.min(previewBoxW/currentImage:getWidth(), boxMaxH/currentImage:getHeight())
            love.graphics.setColor(theme.colors.text_white)
            local imgW = currentImage:getWidth() * scale
            local imgX = previewBoxX + (previewBoxW - imgW) / 2
            love.graphics.draw(currentImage, imgX, previewY, 0, scale, scale)
            previewY = previewY + (currentImage:getHeight() * scale) + 15
        else
            previewY = previewY + 180
        end

        -- Screenshot (Pantalla)
        if currentScreenshot then
            local screenMaxH = 125
            local scale = math.min(previewBoxW/currentScreenshot:getWidth(), screenMaxH/currentScreenshot:getHeight())
            love.graphics.setColor(theme.colors.text_white)
            local imgW = currentScreenshot:getWidth() * scale
            local imgX = previewBoxX + (previewBoxW - imgW) / 2
            love.graphics.draw(currentScreenshot, imgX, previewY, 0, scale, scale)
        end
    end
    end

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" then
        drawSideMenu()
    end

    -- Barra de estado
    drawBottomBar()

    -- Draw Search UI if active
    if state == "SEARCH" then
        -- Fondo oscuro para el teclado
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, h - 280, w, 280)
        
        -- Barra de búsqueda
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.setFont(fontTitle)
        love.graphics.printf("Buscar: " .. searchQuery .. "_", 0, h - 270, w, "center")
        
        -- Teclado Virtual
        love.graphics.setFont(fontMedium)
        local keySize = 40
        local spacing = 5
        local startY = h - 230
        
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
                
                if r == keyboardRow and c == keyboardCol then
                    love.graphics.setColor(theme.colors.selection_accent)
                else
                    love.graphics.setColor(theme.colors.placeholder_background)
                end
                love.graphics.rectangle("fill", x, y, kW, kH, 5)
                
                love.graphics.setColor(theme.colors.text_white)
                love.graphics.printf(key, x, y + 10, kW, "center")
            end
        end
    end

    -- Indicador de indexación en segundo plano
    if isIndexing then
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(theme.colors.selection_accent)
        local text = "Indexando en segundo plano..."
        love.graphics.print(text, w - fontSmall:getWidth(text) - 5, 5)
    end

    drawHelpOverlay()
end

return draw
