local function drawBottomBar()
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.bottom_bar_background)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(theme.colors.text_bright)
    
    local x = 20
    local y = h - 27
    local scale = 0.8

    local function drawHint(icon, text)
        love.graphics.draw(icon, x, y, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, y + 2)
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
        love.graphics.draw(icon, x, y + 5, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, y + 2)
    elseif state == "DELETE_MENU" or state == "POST_GAME" then
        drawHint(buttonIcons.a, "Confirmar")
        drawHint(buttonIcons.b, "Cancelar")
    elseif state == "SCRAPER_VIEW" then
        drawHint(buttonIcons.a, "Buscar")
        drawHint(buttonIcons.b, "Volver")
    elseif state == "SCRAPER_RESULTS" then
        drawHint(buttonIcons.a, "Guardar")
        drawHint(buttonIcons.b, "Volver")
    end
end

local function drawSideMenu()
    local w, h = love.graphics.getDimensions()
    
    -- Overlay oscuro
    love.graphics.setColor(theme.colors.overlay_dark)
    love.graphics.rectangle("fill", 0, 0, w/2, h)

    -- Panel lateral
    love.graphics.setColor(theme.colors.side_menu_background)
    love.graphics.rectangle("fill", w/2, 0, w/2, h)
    
    -- Línea separadora
    love.graphics.setColor(theme.colors.side_menu_separator)
    love.graphics.line(w/2, 0, w/2, h)

    -- Título
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.setFont(fontTitle)
    love.graphics.printf(menuTitle, w/2 + 20, 40, w/2 - 40, "left")

    -- Mensaje
    local startY = 90
    if menuMessage and menuMessage ~= "" then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_medium)
        love.graphics.printf(menuMessage, w/2 + 20, 80, w/2 - 40, "left")
        local width, wrappedtext = fontMedium:getWrap(menuMessage, w/2 - 40)
        startY = 80 + (#wrappedtext * fontMedium:getHeight()) + 30
    end

    -- Opciones
    love.graphics.setFont(fontList)
    for i, option in ipairs(menuOptions) do
        local y = startY + (i-1) * 40
        if i == menuSelection then
            love.graphics.setColor(theme.colors.selection_accent)
            love.graphics.rectangle("fill", w/2 + 10, y - 5, w/2 - 20, 30, 5)
            love.graphics.setColor(theme.colors.text_white)
        else
            love.graphics.setColor(theme.colors.text_dim)
        end
        love.graphics.print(option, w/2 + 20, y)
    end
end

local function drawScraperView()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background) -- Fondo de pantalla completa

    local currentItem = files[selectedIndex]
    if not currentItem then return end

    -- Título
    love.graphics.setFont(fontTitle)
    love.graphics.setColor(theme.colors.text_white)
    love.graphics.printf("Scraper: " .. currentItem.name, 0, 20, w, "center")

    if state == "SCRAPER_VIEW" then
        -- Imagen Actual
        love.graphics.printf("Carátula Actual", 50, 80, w, "left")
        if currentImage then
            local scale = math.min(200 / currentImage:getWidth(), 200 / currentImage:getHeight())
            love.graphics.draw(currentImage, 50, 120, 0, scale, scale)
        else
            love.graphics.setColor(theme.colors.placeholder_background)
            love.graphics.rectangle("fill", 50, 120, 200, 200)
            love.graphics.setColor(theme.colors.text_white)
            love.graphics.printf("No encontrada", 50, 120 + 90, 200, "center")
        end

        -- Botón de Scrapear
        love.graphics.setColor(theme.colors.selection_accent)
        love.graphics.rectangle("fill", 50, 350, 200, 40, 5)
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.printf("Buscar Carátulas", 50, 360, 200, "center")

    elseif state == "SCRAPING_IN_PROGRESS" then
        love.graphics.printf("Buscando, por favor espere...", 0, h/2, w, "center")

    elseif state == "SCRAPER_RESULTS" then
        love.graphics.printf("Resultados:", 50, 80, w, "left")
        if #scraperResults == 0 then
            love.graphics.printf("No se encontraron resultados.", 50, 120, w - 100, "left")
        else
            local x, y = 50, 120
            local spacing = 160
            for i, result in ipairs(scraperResults) do
                if result.image then
                    if i == scraperSelection then
                        love.graphics.setColor(theme.colors.selection_accent)
                        love.graphics.rectangle("fill", x - 5, y - 5, 150, 150, 5)
                    end
                    love.graphics.setColor(theme.colors.text_white)
                    local scale = math.min(140 / result.image:getWidth(), 140 / result.image:getHeight())
                    love.graphics.draw(result.image, x, y, 0, scale, scale)
                    love.graphics.printf(result.region, x, y + 145, 140, "center")
                end
                x = x + spacing
                if x + spacing > w then
                    x = 50
                    y = y + spacing + 20
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

local function draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(theme.colors.background)

    if state == "SCRAPER_VIEW" or state == "SCRAPING_IN_PROGRESS" or state == "SCRAPER_RESULTS" then
        drawScraperView()
        return -- No dibujar la lista debajo
    end
    
    -- Layout dinámico
    if currentImage then
        layout.selWidth = 300
    else
        layout.selWidth = w - 40
    end
    layout.scrollbarX = 15 + layout.selWidth

    -- Título
    love.graphics.setColor(theme.colors.text_bright)
    love.graphics.setFont(fontTitle)
    love.graphics.printf("FileBernic Rom Manager", 0, 15, w, "center")
    
    -- Path actual
    love.graphics.setFont(fontSmall)
    local displayPath = isVirtualRoot and "Todos los Sistemas" or romPath
    love.graphics.printf(displayPath, 0, 45, w, "center")

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
            if isLastPlayed then
                love.graphics.setColor(theme.colors.list_played_selected)
            else
                love.graphics.setColor(theme.colors.list_selection)
            end
            love.graphics.rectangle("fill", 15, y - 4, layout.selWidth, layout.selHeight, 4)
            love.graphics.setColor(theme.colors.selection_accent)
        else
            if isLastPlayed then
                love.graphics.setColor(theme.colors.list_played_unselected)
                love.graphics.rectangle("fill", 15, y - 4, layout.selWidth, layout.selHeight, 4)
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
            
            love.graphics.draw(item.isDir and iconFolder or iconRom, 25, y, 0, layout.iconScale, layout.iconScale)
            local maxChars = math.floor(layout.selWidth / 11)
            
            if i == selectedIndex then
                -- Simular negrita dibujando dos veces con offset
                love.graphics.print(item.name:sub(1, maxChars), 55, y)
                love.graphics.print(item.name:sub(1, maxChars), 56, y)
            else
                love.graphics.print(item.name:sub(1, maxChars), 55, y)
            end

            if item.sourceLabel then
                love.graphics.printf(item.sourceLabel, 15, y, layout.selWidth - 10, "right")
            else
                local label = ""
                if romPath:find("/mnt/mmc") then label = "SD1"
                elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                if label ~= "" then love.graphics.printf(label, 15, y, layout.selWidth - 10, "right") end
            end
        end
    end

    -- Scrollbar
    drawScrollbar()

    -- Boxart
    if currentImage then
        local scale = math.min(layout.boxartMaxW/currentImage:getWidth(), layout.boxartMaxH/currentImage:getHeight())
        love.graphics.setColor(theme.colors.text_white)
        love.graphics.draw(currentImage, 340, layout.listY, 0, scale, scale)
    end

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" then
        drawSideMenu()
    end

    -- Draw Search UI if active
    if state == "SEARCH" then
        local barHeight = 30
        local barY = h - barHeight - 30 -- Place it above the bottom bar
        
        -- Draw search bar background
        love.graphics.setColor(theme.colors.bottom_bar_background)
        love.graphics.rectangle("fill", 0, barY, w, barHeight)
        
        -- Draw search text
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.print("Buscar: " .. searchQuery .. "_", 20, barY + 5)
    end

    -- Barra de estado
    drawBottomBar()
end

return draw
