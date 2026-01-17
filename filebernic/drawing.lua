local function drawBottomBar()
    log("drawBottomBar called")
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(State.fontMedium)
    love.graphics.setColor(State.theme.colors.bottom_bar_background)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(State.theme.colors.text_bright)
    
    local barCenterY = h - 15
    local textH = State.fontMedium:getHeight()
    local textY = barCenterY - textH / 2
    
    local x = 20
    -- Ajustar escala para que los iconos tengan 20px de alto (la barra mide 30px)
    local targetH = 20
    local scale = (State.buttonIcons and State.buttonIcons.a) and (targetH / State.buttonIcons.a:getHeight()) or 0.5

    local function drawHint(icon, text)
        local iconH = icon:getHeight() * scale
        local iconY = barCenterY - iconH / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
        x = x + love.graphics.getFont():getWidth(text) + 20
    end

    if State.state == "LIST" then
        drawHint(State.buttonIcons.a, "Ok")
        drawHint(State.buttonIcons.b, "Back")
        drawHint(State.buttonIcons.y, "Menu")
        if State.launchMode ~= "Juego Unico" then
            drawHint(State.buttonIcons.x, "Select")
        end
        drawHint(State.buttonIcons.start, "Opciones")
        -- Select button with offset
        local icon = State.buttonIcons.select
        local text = "Salir"
        local iconH = icon:getHeight() * scale
        local iconY = barCenterY - iconH / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
    elseif State.state == "DELETE_MENU" or State.state == "POST_GAME" then
        drawHint(State.buttonIcons.a, "Confirmar")
        drawHint(State.buttonIcons.b, "Cancelar")
    elseif State.state == "INFO_VIEW" then
        drawHint(State.buttonIcons.b, "Volver")
    elseif State.state == "SCRAPER_VIEW" then
        drawHint(State.buttonIcons.a, "Buscar")
        drawHint(State.buttonIcons.b, "Volver")
        drawHint(State.buttonIcons.y, "Opciones")
    elseif State.state == "SCRAPER_OPTIONS" then
        drawHint(State.buttonIcons.a, "Seleccionar")
        drawHint(State.buttonIcons.b, "Volver")
    elseif State.state == "SCRAPER_RESULTS" then
        drawHint(State.buttonIcons.a, "Guardar")
        drawHint(State.buttonIcons.b, "Volver")
    elseif State.state == "SAVE_MANAGER" then
        drawHint(State.buttonIcons.a, "Copiar a otra SD")
        drawHint(State.buttonIcons.b, "Volver")
    elseif State.state == "CLEANUP_MENU" then
        drawHint(State.buttonIcons.a, "Acción")
        drawHint(State.buttonIcons.b, "Salir")
    end
end

local function drawSideMenu()
    log("drawSideMenu called")
    local w, h = love.graphics.getDimensions()
    
    -- Animación (Slide in)
    local t = menuAnim
    local ease = 1 - (1 - t)^3 -- Cubic ease out

    -- Determinar si es el menú de un juego para obtener el título y el icono
    local item = focusedItem or files[selectedIndex]
    local isGameOptions = false
    local mainName = ""
    local sysIcon = nil
    local sysName = nil -- Declarar aquí para que sea visible en toda la función
    local iconWidth = 0
    local iconSize = 32 -- Tamaño original del icono

    if state == "OPTIONS_MENU" and item and (not item.isDir or focusedItem) and (menuTitle:match("^Opciones") and menuMessage == item.name) then
        isGameOptions = true
        local name = menuMessage
        mainName = name
        local pStart = name:find("%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "") -- Quitar espacios finales
        end
        
        sysName = utils.getSystemNameForItem(item)

        if sysName then sysIcon = getSystemIcon(sysName) end
        
        -- if sysIcon then
        --     local iconScale = iconSize / sysIcon:getHeight()
        --     iconWidth = sysIcon:getWidth() * iconScale
        -- end
    end

    -- Calcular ancho necesario para las opciones y el título
    love.graphics.setFont(fontList)
    local optionsMaxW = 0
    for _, opt in ipairs(menuOptions) do
        local text = type(opt) == "table" and opt.text or opt
        local width = fontList:getWidth(text)
        if type(opt) == "table" and opt.icon then width = width + 35 end
        if width > optionsMaxW then optionsMaxW = width end
    end

    local coverSpace = 0
    if isGameOptions and currentImage then
        coverSpace = 80 -- 70px ancho estimado + 10px padding
    end
    local titleRequiredW = isGameOptions and (fontTitle:getWidth(mainName) + (iconWidth > 0 and (iconWidth + 10) or 0) + 40 + coverSpace) or 0
    local extraWidth = parentMenuData and 50 or 0 -- Hacer más ancho si es un submenú para efecto de solapado
    local menuW = math.min(w * 0.8, math.max(300, optionsMaxW + 60, titleRequiredW) + extraWidth)

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

    -- -- Boxart en el fondo (Watermark)
    -- if state == "OPTIONS_MENU" and currentImage then
    --     love.graphics.setColor(1, 1, 1, 0.15) -- Opacidad levemente mayor
    --     local availW = menuW - 20
    --     local availH = h * 0.45 -- Max 45% de altura
    --     local scale = math.min(availW / currentImage:getWidth(), availH / currentImage:getHeight())
    --     
    --     local imgW = currentImage:getWidth() * scale
    --     local imgH = currentImage:getHeight() * scale
    --     
    --     love.graphics.draw(currentImage, slideX + (menuW - imgW) / 2, 20, 0, scale, scale)
    -- end

    -- Header (Título y Mensaje/Info)
    -- item ya está definido arriba
    local startY = 90
    -- isGameOptions ya está definido arriba

    if isGameOptions then
        -- Header Personalizado para Juego
        local name = menuMessage
        local mainName = name:gsub("%s*$", "")
        mainName = mainName:gsub("%.[^%.]+$", "") -- Quitar extensión del título
        local extraInfo = ""
        
        local pStart = name:find("%(")
        if pStart then
            mainName = name:sub(1, pStart - 1):gsub("%s*$", "")
            extraInfo = name:sub(pStart)
        end
        
        local headerY = 25
        local baseTextX = slideX + 20
        
        love.graphics.setFont(fontTitle)
        
        -- Lógica para carátula a la izquierda del título
        local coverW = 0
        local titleX = baseTextX
        
        -- 1. Calcular ancho disponible para el título, asumiendo un espacio para la carátula
        local totalAvailW = menuW - 40 - (iconWidth > 0 and (iconWidth + 10) or 0)
        local titleAvailW = totalAvailW
        if currentImage then
            -- Reservar un espacio para la carátula para calcular el alto del texto
            local coverPlaceholderW = 70 
            titleAvailW = totalAvailW - coverPlaceholderW - 10
        end

        -- 2. Obtener el texto del título envuelto y su altura
        local _, wrappedMain = fontTitle:getWrap(mainName, titleAvailW)
        local mainH = #wrappedMain * fontTitle:getHeight()
        
        -- 3. Dibujar la carátula, escalada a la altura del título
        if currentImage then
            love.graphics.setColor(1, 1, 1)
            local coverScale = mainH / currentImage:getHeight()
            coverW = currentImage:getWidth() * coverScale
            love.graphics.draw(currentImage, baseTextX, headerY, 0, coverScale, coverScale)
            titleX = baseTextX + coverW + 10
        end
        
        -- 4. Dibujar el texto del título
        love.graphics.setColor(theme.colors.text_white)
        for i, line in ipairs(wrappedMain) do
            love.graphics.print(line, titleX, headerY + (i-1)*fontTitle:getHeight())
        end
        
        -- 5. Dibujar el icono del sistema a la derecha
        -- if sysIcon then
        --     local iconScale = iconSize / sysIcon:getHeight()
        --     love.graphics.setColor(1, 1, 1)
        --     love.graphics.draw(sysIcon, slideX + menuW - 20 - iconWidth, headerY, 0, iconScale, iconScale)
        -- end
        
        -- 6. Calcular la altura total del contenido para el encabezado
        local contentH = math.max(iconSize, mainH)
        
        -- 7. Preparar y dibujar el nuevo subtítulo
        local regionInfo = extraInfo:gsub("%.[^%.]+$", "") -- quitar extensión
        local displayName = utils.getSystemDisplayName(sysName)
        local newSubtitle = (displayName or "Sistema Desconocido") .. " " .. regionInfo
        
        if newSubtitle:gsub("%s+", "") ~= "" then
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(theme.colors.text_dim)
            love.graphics.printf(newSubtitle, slideX + 20, headerY + contentH + 5, menuW - 40, "left")
            local _, wrappedExtra = fontSmall:getWrap(newSubtitle, menuW - 40)
            startY = headerY + contentH + 5 + (#wrappedExtra * fontSmall:getHeight()) + 20
        else
            startY = headerY + contentH + 20
        end
    else
        -- Header Estándar
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.setFont(fontTitle)
        love.graphics.printf(menuTitle, slideX + 20, 40, menuW - 40, "left")

        if menuMessage and menuMessage ~= "" then
            love.graphics.setFont(fontMedium)
            love.graphics.setColor(theme.colors.text_medium)
            love.graphics.printf(menuMessage, slideX + 20, 80, menuW - 40, "left")
            local width, wrappedtext = fontMedium:getWrap(menuMessage, menuW - 40)
            startY = 80 + (#wrappedtext * fontMedium:getHeight()) + 30
        end
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

    -- Mostrar ruta en DELETE_MENU
    if state == "DELETE_MENU" and itemToDelete then
        local path = itemToDelete.fullPath or ""
        local displayPath = path
        if path:find("ROMS/") then
            displayPath = path:match("ROMS/(.*)")
        elseif path:find("Simulador_SD/") then
            displayPath = path:match("Simulador_SD/(.*)")
        end
        
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(theme.colors.text_dim)
        
        local textY = h - 45
        local availableW = menuW - 40
        
        if fontSmall:getWidth(displayPath) > availableW then
             love.graphics.printf(displayPath, slideX + 20, textY - fontSmall:getHeight(), availableW, "center")
        else
             love.graphics.printf(displayPath, slideX + 20, textY, availableW, "center")
        end
    end
end

local function drawHelpOverlay()
    log("drawHelpOverlay called")
    if not State.showHelp and not State.closingHelp then return end
    local w, h = love.graphics.getDimensions()
    
    -- Animación (Slide in)
    local t = State.menuAnim
    local ease = 1 - (1 - t)^3 -- Cubic ease out
    local offset = (w / 2) * (1 - ease)
    
    -- Overlay oscuro (Fade in)
    local r, g, b, a = unpack(State.theme.colors.overlay_dark)
    love.graphics.setColor(r, g, b, a * ease)
    love.graphics.rectangle("fill", 0, 0, w/2, h)
    
    -- Panel lateral
    love.graphics.setColor(State.theme.colors.side_menu_background)
    love.graphics.rectangle("fill", w/2 + offset, 0, w/2, h)
    
    -- Línea separadora
    love.graphics.setColor(State.theme.colors.side_menu_separator)
    love.graphics.line(w/2 + offset, 0, w/2 + offset, h)

    local contentX = w/2 + offset

    love.graphics.setColor(State.theme.colors.text_white)
    love.graphics.setFont(State.fontTitle)
    love.graphics.printf("Ayuda - Controles", contentX + 20, 40, w/2 - 40, "left")
    
    local list = State.helpData[State.state] or State.helpData.DEFAULT

    -- Filter out 'Select' option in 'Juego Unico' mode
    local filteredList = {}
    if State.state == "LIST" and State.launchMode == "Juego Unico" then
        for _, item in ipairs(list) do
            if item.text ~= "Seleccionar" then
                table.insert(filteredList, item)
            end
        end
    else
        filteredList = list
    end

    love.graphics.setFont(State.fontMedium)
    local startY = 90
    for i, item in ipairs(filteredList) do
        love.graphics.setColor(State.theme.colors.text_white)
        love.graphics.draw(item.icon, contentX + 20, startY + (i-1)*40, 0, 0.8, 0.8)
        love.graphics.print(item.text, contentX + 60, startY + (i-1)*40 + 2)
    end
end

local function drawMediaDetailContent(currentItem, showSearchButton)
    log("drawMediaDetailContent called")
    local w, h = love.graphics.getDimensions()

    -- 1. Extraer datos del subtítulo
    local regionInfo = ""
    local pStart = currentItem.name:find("%(")
    if pStart then
        regionInfo = currentItem.name:sub(pStart)
    end

    local sysName = utils.getSystemNameForItem(currentItem)
    local displayName = utils.getSystemDisplayName(sysName)
    local subtitle = (displayName or "Desconocido") .. " " .. regionInfo

    -- 2. Dibujar Subtítulo
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_dim)
    love.graphics.printf(subtitle, 0, 55, w, "center")

    -- 3. Layout de imágenes
    local contentY = 100
    local imagesY = contentY + fontMedium:getHeight() + 5
    local availableH = h - imagesY - 40 - 120 -- Restar espacio para barra inferior y descripción
    
    local spacing = 20
    local coverW, screenW = 0, 0
    local coverScale, screenScale = 1, 1

    if currentImage then
        coverScale = availableH / currentImage:getHeight()
        coverW = currentImage:getWidth() * coverScale
    end
    if currentScreenshot then
        screenScale = availableH / currentScreenshot:getHeight()
        screenW = currentScreenshot:getWidth() * screenScale
    end

    local totalW = coverW + (currentImage and currentScreenshot and spacing or 0) + screenW
    local startX = (w - totalW) / 2
    
    love.graphics.setFont(fontMedium)
    
    if currentImage then
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.printf("Frontal", startX, contentY, coverW, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentImage, startX, imagesY, 0, coverScale, coverScale)
    end
    
    if currentScreenshot then
        local drawX = startX + (currentImage and (coverW + spacing) or 0)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.printf("Screen", drawX, contentY, screenW, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentScreenshot, drawX, imagesY, 0, screenScale, screenScale)
    end

    -- 4. Dibujar Descripción
    local textY = imagesY + availableH + 15
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.text_medium)
    local infoTitle = "Info"
    if currentYear and currentYear ~= "" then infoTitle = infoTitle .. " (" .. currentYear .. ")" end
    love.graphics.print(infoTitle, 20, textY)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(theme.colors.text_dim)
    local descText = (currentDescription and currentDescription ~= "") and currentDescription or "Sin información."
    love.graphics.printf(descText, 20, textY + 25, w - 40, "left")

    if not currentImage and not currentScreenshot and descText == "Sin información." then
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.printf("No hay imágenes ni información disponible.", 0, h/2, w, "center")
    end
end

local function drawInfoView()
    log("drawInfoView called")
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    local currentItem = focusedItem or files[selectedIndex]
    if not currentItem then return end

    -- 1. Extraer datos
    local mainName = currentItem.name:gsub("%s*$", "")
    local pStart = mainName:find("%(")
    if pStart then
        mainName = mainName:sub(1, pStart - 1):gsub("%s*$", "")
    end
    mainName = mainName:gsub("%.[^%.]+$", "") -- Quitar extensión

    -- Dibujar Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf(mainName, 0, 20, w, "center")

    -- Dibujar contenido
    drawMediaDetailContent(currentItem, false)

    -- Hint de volver
    drawBottomBar()
end

local function drawScraperView()
    log("drawScraperView called")
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background) -- Fondo de pantalla completa

    local currentItem = focusedItem or files[selectedIndex]
    if not currentItem then return end

    -- Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf("Scraper: " .. currentItem.name, 0, 15, w, "center")

    if state == "SCRAPER_VIEW" then
        -- Usar la nueva función de dibujado de contenido
        drawMediaDetailContent(currentItem, true)

        -- Botón de Scrapear
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", w/2 - 100, h - 80, 200, 40, 5)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Buscar Datos", 0, h - 70, w, "center")

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
    log("drawScrollbar called")
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
    log("drawSaveManager called")
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
    log("drawTrimmed called")
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
    log("drawTrimmedStart called")
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
    log("drawCleanupMenu called")
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
        local hasImages = #(cleanupData.orphanedImages or {}) > 0
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
    log("drawGrid called")
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

        local imageToDraw = nil
        if not item.isDir then
            local base = item.name:gsub("%..-$", "")
            
            -- Determinar la ruta de la carátula correcta para el item (considerando virtual root)
            local systemForItem = utils.getSystemNameForItem(item)
            local artPathForItem = filesystem.getArtPathForSystem(systemForItem)

            if artPathForItem then
                local path = artPathForItem .. base .. ".png"
                imageToDraw = loader:getImage(path)
            end
        end

        -- Dibujar imagen o icono
        if imageToDraw then
            love.graphics.setColor(1, 1, 1)
            local scale = math.min(contentWidth / imageToDraw:getWidth(), (cellH - 50) / imageToDraw:getHeight())
            local imgW = imageToDraw:getWidth() * scale
            local imgH = imageToDraw:getHeight() * scale
            local ix = x + 5 + (contentWidth - imgW) / 2
            local iy = y + 10 + ((cellH - 50) - imgH) / 2
            love.graphics.draw(imageToDraw, ix, iy, 0, scale, scale)
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

local function drawJumpLetter()
    log("drawJumpLetter called")
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

local function drawMainList(w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)
    log("drawMainList called")
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
    end

    -- Scrollbar
    drawScrollbar()

    -- Columna de Vista Previa (Boxart + Screenshot)
    if showPreview then
        local previewY = layout.listY

        -- Boxart (Frontal)
        if currentImage then
            local scale = previewBoxW / currentImage:getWidth()
            love.graphics.setColor(theme.colors.text_white)
            local imgW = currentImage:getWidth() * scale
            local imgX = previewBoxX + (previewBoxW - imgW) / 2
            love.graphics.draw(currentImage, imgX, previewY, 0, scale, scale)
            previewY = previewY + (currentImage:getHeight() * scale) + 15
        end

        -- Screenshot (Pantalla)
        if currentScreenshot then
            local scale = previewBoxW / currentScreenshot:getWidth()
            love.graphics.setColor(theme.colors.text_white)
            local imgW = currentScreenshot:getWidth() * scale
            local imgX = previewBoxX + (previewBoxW - imgW) / 2
            love.graphics.draw(currentScreenshot, imgX, previewY, 0, scale, scale)
        end
    end
end

local function draw()
    log("draw called")
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if state == "SCRAPER_VIEW" or state == "SCRAPING_IN_PROGRESS" or state == "SCRAPER_RESULTS" or state == "INFO_VIEW" or state == "SCRAPER_OPTIONS" then
        if state == "INFO_VIEW" then
            drawInfoView()
        else
            drawScraperView()
        end
        if state == "SCRAPER_OPTIONS" or closingMenu then
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

    drawMainList(w, h, sdColX, sdColW, previewBoxW, previewBoxX, showPreview)

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" or closingMenu then
        drawSideMenu()
    end

    -- Barra de estado
    drawBottomBar()
    
    -- Dibujar panel de letra al final para que quede encima de todo
    drawJumpLetter()

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
        -- Punto parpadeante
        local alpha = math.abs(math.sin(love.timer.getTime() * 5))
        love.graphics.setColor(theme.colors.selection_accent[1], theme.colors.selection_accent[2], theme.colors.selection_accent[3], alpha)
        love.graphics.circle("fill", w - 20, 20, 6)
    end

    drawHelpOverlay()
end

return draw
