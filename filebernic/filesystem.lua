local M = {}

function M.hasRoms(path, validExtensions)
    local h = io.popen('ls -p "'..path..'"')
    if not h then return false end
    for l in h:lines() do
        local ext = l:match("[^%.]+$")
        if l:sub(-1) ~= "/" and ext and validExtensions[ext:lower()] then
            h:close()
            return true
        end
    end
    h:close()
    return false
end

function M.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    local currentPath = item.fullPath or (romPath .. item.name)
    local detectedSystem = currentPath:match("ROMS/([^/]+)/") or currentPath:match("Simulador_SD/([^/]+)/")
    
    if detectedSystem and detectedSystem ~= systemName then
        systemName = detectedSystem
        
        -- log("System detected changed to: " .. systemName) -- Comentado para no saturar log en scroll
        -- Recalcular rutas de arte
        local baseMuosPath = ""
        if io.open("/mnt/mmc", "r") then
             baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
        else
             local cwd = love.filesystem.getSource()
             if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
             local simPath = cwd .. "/../Simulador_SD/"
             baseMuosPath = simPath .. "MUOS/info/catalogue/"
        end
        muosArtPath = baseMuosPath .. systemName .. "/box/"
        muosTextPath = baseMuosPath .. systemName .. "/text/"
        muosPreviewPath = baseMuosPath .. systemName .. "/preview/"
        return systemName, muosArtPath, muosTextPath, muosPreviewPath
    end
    return systemName, muosArtPath, muosTextPath, muosPreviewPath
end

function M.updateSystemPaths(systemName, romPath, systemVariants, log, love_graphics_newImage)
    local detectedSystem = romPath:match("ROMS/([^/]+)/") or romPath:match("Simulador_SD/([^/]+)/")
    
    local muosArtPath = ""
    local muosTextPath = ""
    local muosPreviewPath = ""
    local currentSystemIcon = nil
    local currentSystemContentIcon = nil

    if detectedSystem and detectedSystem ~= systemName then
        systemName = detectedSystem
        log("System detected: " .. systemName)
        
        local baseMuosPath = ""
        if io.open("/mnt/mmc", "r") then
             baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
        else
             local cwd = love.filesystem.getSource()
             if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
             local simPath = cwd .. "/../Simulador_SD/"
             baseMuosPath = simPath .. "MUOS/info/catalogue/"
        end
        muosArtPath = baseMuosPath .. systemName .. "/box/"
        muosTextPath = baseMuosPath .. systemName .. "/text/"
        muosPreviewPath = baseMuosPath .. systemName .. "/preview/"
        -- Year is stored in text path with .year extension

        -- Buscar grupo de variantes para el sistema detectado
        local variants = {systemName}
        local lowerName = systemName:lower()
        
        for _, group in ipairs(systemVariants) do
            local match = false
            for _, v in ipairs(group) do
                if v:lower() == lowerName then
                    match = true
                    break
                end
            end
            if match then
                variants = group
                log("Variant group found for: " .. systemName)
                break
            end
        end

        -- Cargar icono del sistema (probar todas las variantes)
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. ".png"
            if love.filesystem.getInfo(path) then
                currentSystemIcon = love_graphics_newImage(path)
                log("System icon found: " .. path)
                break
            end
        end
        if not currentSystemIcon then
            log("System icon NOT found")
        end

        -- Cargar icono de contenido (ROM) (probar todas las variantes)
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. "-content.png"
            if love.filesystem.getInfo(path) then
                currentSystemContentIcon = love_graphics_newImage(path)
                log("Content icon found: " .. path)
                break
            end
        end
        if not currentSystemContentIcon then
            log("Content icon NOT found")
        end
    end
    return systemName, muosArtPath, muosTextPath, muosPreviewPath, currentSystemIcon, currentSystemContentIcon
end

function M.refreshFiles(updateSystemPaths, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, loadPreview)
    updateSystemPaths()
    files = {}
    selectedFilesCount = 0

    local fileMap = {} -- Key: filename (Folder mode) or stem (Juego Unico mode)

    local function scan(path, label)
        local handle
        local isFind = false
        
        if launchMode == "Juego Unico" then
            -- Búsqueda recursiva solo de archivos
            handle = io.popen('find "'..path..'" -type f')
            isFind = true
        else
            -- Listado estándar de directorio actual
            handle = io.popen('ls -p "'..path..'"')
        end

        if handle then
            for line in handle:lines() do
                local isDirectory = not isFind and (line:sub(-1) == "/")
                local cleanName = isFind and line:match("([^/]+)$") or (isDirectory and line:sub(1, -2) or line)
                local fullPath = isFind and line or (path .. line)

                -- Filtrar archivos ocultos y asegurar nombre válido
                if cleanName and cleanName:sub(1, 1) ~= "." then
                local ext = cleanName:match("[^%.]+$")
                if isDirectory or (ext and validExtensions[ext:lower()]) then
                    local skip = false
                    if isDirectory and hideEmpty and not M.hasRoms(fullPath, validExtensions) then
                        skip = true
                    end

                    if not skip then
                        local key = cleanName
                        local stem = cleanName
                        local system = nil

                        if not isDirectory and launchMode == "Juego Unico" then
                            stem = cleanName:gsub("%.[^%.]+$", "")
                            key = stem:gsub("%s*%b()", ""):gsub("%s*%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                            if key == "" then key = stem end
                            system = fullPath:match("ROMS/([^/]+)/") or fullPath:match("Simulador_SD/([^/]+)/")
                        end

                        if fileMap[key] then
                            local idx = fileMap[key]
                            local item = files[idx]
                            
                            if not isDirectory and launchMode == "Juego Unico" then
                                -- Add as version
                                table.insert(item.versions, {
                                    name = cleanName,
                                    fullPath = fullPath,
                                    sourceLabel = label,
                                    ext = ext,
                                    system = system
                                })
                                item.sourceLabel = "Multi"
                            else
                                files[idx].sourceLabel = "SD½"
                                files[idx].secondaryPath = fullPath
                            end
                        else
                            local newItem = {name = (not isDirectory and launchMode == "Juego Unico") and stem or cleanName, isDir = isDirectory, fullPath = fullPath, sourceLabel = label}
                            if not isDirectory and launchMode == "Juego Unico" then
                                newItem.versions = {{name = cleanName, fullPath = fullPath, sourceLabel = label, ext = ext, system = system}}
                            end
                            table.insert(files, newItem)
                            fileMap[key] = #files
                        end
                    end
                end
                end
            end
            handle:close()
        end
    end

    scan(romPath, romPath:find("/mnt/mmc") and "SD1" or (romPath:find("/mnt/sdcard") and "SD2" or ""))
    if secondaryPath then
        scan(secondaryPath, secondaryPath:find("/mnt/mmc") and "SD1" or (secondaryPath:find("/mnt/sdcard") and "SD2" or ""))
    end
    
    -- Sort files alphabetically
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    
    -- Ensure selectedIndex is within bounds
    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > #files then selectedIndex = math.max(1, #files) end
    
    allFiles = {}
    for _, item in ipairs(files) do
        table.insert(allFiles, item)
    end

    loadPreview()
    return files, selectedFilesCount, selectedIndex, allFiles
end

return M
