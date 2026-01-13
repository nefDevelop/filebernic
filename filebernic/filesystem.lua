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

function M.startIndexingProcess(romIndex, json_decode, love_filesystem_getSource, io_open, log, performBackgroundIndexing, isIndexing, indexStateMessage, validExtensions, json_encode, os_execute, coroutine_create, coroutine_yield, table_insert, table_sort, createMergedVirtualRoot, isVirtualRoot, launchMode, files, secondaryPath, selectedIndex, allFiles, hideEmpty, getSystemIcon, loadPreview)
    local dataDir = love_filesystem_getSource() .. "/data"
    local indexPath = dataDir .. "/rom_index.json"
    local tsPath = dataDir .. "/rom_timestamps.json"

    local indexFile = io_open(indexPath, "r")
    local tsFile = io_open(tsPath, "r")

    if not indexFile or not tsFile then
        if indexFile then indexFile:close() end
        if tsFile then tsFile:close() end
        log("No index found. Starting background indexing.")
        isIndexing, indexStateMessage, romIndex, indexCoroutine = performBackgroundIndexing(isIndexing, indexStateMessage, romIndex, validExtensions, love_filesystem_getSource, json_encode, os_execute, io_open, coroutine_create, coroutine_yield, table_insert, table_sort, createMergedVirtualRoot, isVirtualRoot, launchMode, files, secondaryPath, selectedIndex, allFiles, hideEmpty, getSystemIcon, loadPreview)
        return romIndex
    end

    -- Si los archivos existen, comprobar timestamps
    local needsReindex = false
    local tsContent = tsFile:read("*a")
    tsFile:close()
    local savedTimestamps = json_decode(tsContent)

    for dir, saved_ts in pairs(savedTimestamps) do
        local h = io.popen('stat -c %Y "'..dir..'"')
        if h then
            local current_ts = h:read("*a"):gsub("%s+", "")
            h:close()
            if current_ts ~= saved_ts then
                log("Change detected in " .. dir .. ". Re-indexing.")
                needsReindex = true
                break
            end
        end
    end

    if needsReindex then
        isIndexing, indexStateMessage, romIndex, indexCoroutine = performBackgroundIndexing(isIndexing, indexStateMessage, romIndex, validExtensions, love_filesystem_getSource, json_encode, os_execute, io_open, coroutine_create, coroutine_yield, table_insert, table_sort, createMergedVirtualRoot, isVirtualRoot, launchMode, files, secondaryPath, selectedIndex, allFiles, hideEmpty, getSystemIcon, loadPreview)
    else
        log("Index is up to date. Loading from file.")
        local indexContent = indexFile:read("*a")
        indexFile:close()
        romIndex = json_decode(indexContent)
    end
    return romIndex
end

function M.removeFromIndex(path, romIndex, json_encode, love_filesystem_getSource, io_open)
    if not romIndex then return romIndex end
    local i = 1
    while i <= #romIndex do
        local item = romIndex[i]
        local vIndex = 1
        local changed = false
        while vIndex <= #item.versions do
            if item.versions[vIndex].fullPath == path then
                table.remove(item.versions, vIndex)
                changed = true
            else
                vIndex = vIndex + 1
            end
        end
        
        if changed then
            if #item.versions == 0 then
                table.remove(romIndex, i)
            else
                if #item.versions == 1 then
                    item.sourceLabel = item.versions[1].sourceLabel
                    item.fullPath = item.versions[1].fullPath
                end
                i = i + 1
            end
        else
            i = i + 1
        end
    end
    
    -- Save index to disk to persist deletion
    local dataDir = love_filesystem_getSource() .. "/data"
    local f = io_open(dataDir .. "/rom_index.json", "w")
    if f then
        f:write(json_encode(romIndex))
        f:close()
    end
    return romIndex
end

function M.performBackgroundIndexing(isIndexing, indexStateMessage, romIndex, validExtensions, love_filesystem_getSource, json_encode, os_execute, io_open, coroutine_create, coroutine_yield, table_insert, table_sort, createMergedVirtualRoot, isVirtualRoot, launchMode, files, secondaryPath, selectedIndex, allFiles, hideEmpty, getSystemIcon, loadPreview)
    isIndexing = true
    indexStateMessage = "Iniciando escaneo..."

    local indexCoroutine = coroutine_create(function()
        local newIndex = {}
        local fileMap = {} -- Key: stem -> index in newIndex
        local romDirs = {}

        local function scanRoot(rootPath)
            if not io_open(rootPath, "r") then return end
            table_insert(romDirs, rootPath)
            
            indexStateMessage = "Escaneando: " .. rootPath
            coroutine_yield()

            local h = io.popen('find "'..rootPath..'" -type f')
            if h then
                local count = 0
                for fLine in h:lines() do
                    count = count + 1
                    if count % 100 == 0 then coroutine_yield() end -- Ceder control para no congelar

                    local filename = fLine:match("([^/]+)$")
                    if filename and filename:sub(1, 1) ~= "." then
                        local ext = filename:match("[^%.]+$")
                        if ext and validExtensions[ext:lower()] then
                            local stem = filename:gsub("%.[^%.]+$", "")
                            local groupKey = stem:gsub("%s*%b()", ""):gsub("%s*%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                            if groupKey == "" then groupKey = stem end
                            
                            local sysName = fLine:match("ROMS/([^/]+)/") or fLine:match("Simulador_SD/([^/]+)/") or "UNK"

                            if fileMap[groupKey] then
                                local idx = fileMap[groupKey]
                                local item = newIndex[idx]
                                table_insert(item.versions, {
                                    name = filename,
                                    fullPath = fLine,
                                    sourceLabel = sysName,
                                    ext = ext,
                                    system = sysName
                                })
                                item.sourceLabel = "Multi"
                            else
                                local newItem = {
                                    name = groupKey,
                                    isDir = false,
                                    fullPath = fLine,
                                    sourceLabel = sysName,
                                    icon = nil, -- Iconos se cargan bajo demanda
                                    versions = {{
                                        name = filename,
                                        fullPath = fLine,
                                        sourceLabel = sysName,
                                        ext = ext,
                                        system = sysName
                                    }}
                                }
                                table_insert(newIndex, newItem)
                                fileMap[groupKey] = #newIndex
                            end
                        end
                    end
                end
                h:close()
            end
        end

        scanRoot("/mnt/mmc/ROMS/")
        scanRoot("/mnt/sdcard/ROMS/")
        -- Fallback Simulador
        if #newIndex == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanRoot(cwd .. "/../Simulador_SD/")
        end

        indexStateMessage = "Ordenando y guardando..."
        coroutine_yield()

        table_sort(newIndex, function(a, b) return a.name:lower() < b.name:lower() end)
        romIndex = newIndex

        -- Guardar índice en archivo
        local dataDir = love_filesystem_getSource() .. "/data"
        os_execute("mkdir -p " .. dataDir)
        local f = io_open(dataDir .. "/rom_index.json", "w")
        if f then
            f:write(json_encode(romIndex))
            f:close()
        end

        -- Guardar timestamps de los directorios
        local timestamps = {}
        for _, dir in ipairs(romDirs) do
            local h = io.popen('stat -c %Y "'..dir..'"')
            if h then timestamps[dir] = h:read("*a"):gsub("%s+", "") h:close() end
        end
        local f_ts = io_open(dataDir .. "/rom_timestamps.json", "w")
        if f_ts then
            f_ts:write(json_encode(timestamps))
            f_ts:close()
        end

        isIndexing = false
        indexStateMessage = ""
        
        -- Si estamos en la vista de raíz virtual y modo juego único, refrescar
        if isVirtualRoot and launchMode == "Juego Unico" then
             files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, getSystemIcon, allFiles, loadPreview)
        end
    end)
    return isIndexing, indexStateMessage, romIndex, indexCoroutine
end

function M.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, getSystemIcon, allFiles, loadPreview)
    files = {}
    isVirtualRoot = true
    romPath = "" -- Not a real path in this view
    secondaryPath = nil
    selectedIndex = 1

    if launchMode == "Juego Unico" then
        if romIndex then
            -- El índice está listo, úsalo.
            files = {}
            for _, item in ipairs(romIndex) do
                -- Deep copy para evitar modificar el índice original con estados temporales (ej: .selected)
                local copy = {}
                for k, v in pairs(item) do copy[k] = v end
                table.insert(files, copy)
            end
        else
            -- El índice no está listo, se mostrará un mensaje de "cargando" en drawing.lua
            -- Dejamos `files` vacío por ahora.
        end

    else
        -- MODO CARPETA: Listar Sistemas (Comportamiento original)
        local dirMap = {} 
        local function scanAndAdd(scanPath, label)
            local f = io.open(scanPath, "r")
            if not f then return end
            f:close()

            local handle = io.popen('ls -p "'..scanPath..'"')
            if handle then
                for line in handle:lines() do
                    if line:sub(-1) == "/" then
                        local dirName = line:sub(1, -2)
                        if dirName ~= "BIOS" and dirName ~= "Saves" then
                            if not hideEmpty or M.hasRoms(scanPath .. line, validExtensions) then
                                if dirMap[dirName] then
                                    files[dirMap[dirName]].sourceLabel = "SD½"
                                    files[dirMap[dirName]].secondaryPath = scanPath .. line
                                else
                                    local icon = getSystemIcon(dirName)
                                    table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. line, sourceLabel = label, icon = icon})
                                    dirMap[dirName] = #files
                                end
                            end
                        end
                    end
                end
                handle:close()
            end
        end

        scanAndAdd("/mnt/mmc/ROMS/", "SD1")
        scanAndAdd("/mnt/sdcard/ROMS/", "SD2")

        if #files == 0 then
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simPath = cwd .. "/../Simulador_SD/"
            local h = io.popen('ls -d "'..simPath..'"')
            if h and h:read("*a") ~= "" then
                table.insert(files, {name = "Simulador_SD", isDir = true, fullPath = simPath, sourceLabel = "SIM"})
            end
            scanAndAdd(simPath, "SIM")
        end
    end
    
    -- Sort files alphabetically by name
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)

    -- Back up the full list
    allFiles = {}
    for _, item in ipairs(files) do
        table.insert(allFiles, item)
    end

    loadPreview()
    return files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles
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
