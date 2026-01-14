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

function M.deleteGameMedia(romPath)
    local system = romPath:match("ROMS/([^/]+)/")
    if not system then return end
    
    local filename = romPath:match("([^/]+)$")
    local baseName = filename:gsub("%..-$", "")
    
    -- Base path for catalogue (usually on SD1 in muOS)
    local cataloguePath = "/mnt/mmc/MUOS/info/catalogue/"
    if not io.open("/mnt/mmc", "r") then
        -- Simulator fallback
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        cataloguePath = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
    end
    
    local artPath = cataloguePath .. system .. "/box/" .. baseName .. ".png"
    local textPath = cataloguePath .. system .. "/text/" .. baseName .. ".txt"
    local yearPath = cataloguePath .. system .. "/text/" .. baseName .. ".year"
    local prevPath = cataloguePath .. system .. "/preview/" .. baseName .. ".png"
    
    os.remove(artPath)
    os.remove(textPath)
    os.remove(yearPath)
    os.remove(prevPath)
end

function M.addToHistory(path, playedRoms)
    playedRoms[path] = true
    M.saveHistory(playedRoms)
end

function M.saveLastPlayed(path)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/last_played.txt", "w")
    if f then
        f:write(path)
        f:close()
    end
end

function M.resolveSecondary(item)
    if item.secondaryPath then return item.secondaryPath end
    
    local otherSD = ""
    if item.fullPath:find("/mnt/mmc") then
        otherSD = "/mnt/sdcard"
    elseif item.fullPath:find("/mnt/sdcard") then
        otherSD = "/mnt/mmc"
    else
        return nil
    end
    
    local system = item.fullPath:match("ROMS/([^/]+)/")
    if not system then return nil end
    
    local secondary = otherSD .. "/ROMS/" .. system .. "/" .. item.name
    
    if io.open(secondary, "r") then
        return secondary
    end
    return nil
end

function M.getTargetSDPath(item, config)
    local targetSD = config.copyToSD2 and "sdcard" or "mmc"
    if item.sourceLabel == "SD1" then
        targetSD = "sdcard"
    elseif item.sourceLabel == "SD2" then
        targetSD = "mmc"
    end
    return "/mnt/" .. targetSD
end

function M.saveHistory(playedRoms)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/played_roms.txt", "w")
    if f then
        for path, _ in pairs(playedRoms) do
            f:write(path .. "\n")
        end
        f:close()
    end
end

function M.saveScrapeResult(item, result, muosArtPath, muosTextPath, muosPreviewPath, log)
    if result and result.tempPath then
        local baseName = item.name:gsub("%..-$", "")
        
        -- Asegurar directorio de destino
        os.execute("mkdir -p '" .. muosArtPath .. "'")
        
        -- Mover archivo temporal a destino final
        local destPath = muosArtPath .. baseName .. ".png"
        log("Saving boxart to: " .. destPath)
        os.execute("cp '" .. result.tempPath .. "' '" .. destPath .. "'")
        
        -- Guardar descripción
        if result.description then
            os.execute("mkdir -p '" .. muosTextPath .. "'")
            local txtPath = muosTextPath .. baseName .. ".txt"
            log("Saving description to: " .. txtPath)
            local f = io.open(txtPath, "w")
            if f then
                f:write(result.description)
                f:close()
            end
        end
        
        -- Guardar año
        if result.year then
            os.execute("mkdir -p '" .. muosTextPath .. "'")
            local yearPath = muosTextPath .. baseName .. ".year"
            log("Saving year to: " .. yearPath)
            local f = io.open(yearPath, "w")
            if f then
                f:write(result.year)
                f:close()
            end
        end
        
        -- Guardar screenshot (si existe carpeta preview)
        if result.tempScreenPath and muosPreviewPath ~= "" then
            os.execute("mkdir -p '" .. muosPreviewPath .. "'")
            local destScreen = muosPreviewPath .. baseName .. ".png"
            log("Saving preview to: " .. destScreen)
            os.execute("cp '" .. result.tempScreenPath .. "' '" .. destScreen .. "'")
        end
    end
end

function M.performCleanupScan(cleanupData, validExtensions, love_filesystem_getSource, io_open, coroutine_create, coroutine_yield, table_insert, table_sort)
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = true, progress = 0, cursor = {col=1, row=1}, confirming = false, currentFile = "" }
    
    local cleanupCoroutine = coroutine_create(function()
        local romNames = {} -- Para huérfanos: nombre base -> true
        local romsByStem = {} -- Para duplicados: nombre base -> lista de archivos
        local romsBySystem = {} -- Para imágenes huérfanas: system -> stem -> true

        local totalFiles = 0
        local scannedFiles = 0
        local find_exclude_str = [[-not -path "*.svn*" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.txt" -not -name "*.pdf" -not -name "*.db"]]

        local function countFiles(path)
            if not io_open(path, "r") then return end
            local cmd = 'find "'..path..'" -type f ' .. find_exclude_str .. ' | wc -l'
            local h = io.popen(cmd)
            if h then
                local count = tonumber(h:read("*a"))
                h:close()
                if count then totalFiles = totalFiles + count end
            end
        end

        -- 1. Contar todos los archivos primero para una barra de progreso precisa
        countFiles("/mnt/mmc/ROMS")
        countFiles("/mnt/sdcard/ROMS")
        -- Fallback para simulador
        if totalFiles == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            countFiles(cwd .. "/../Simulador_SD/")
        end
        coroutine_yield()

        local function scanAndRegister(path, locationLabel)
            if not io_open(path, "r") then return end
            local cmd = 'find "'..path..'" -type f ' .. find_exclude_str
            local h = io.popen(cmd)
            if h then
                for line in h:lines() do
                    scannedFiles = scannedFiles + 1
                    cleanupData.progress = totalFiles > 0 and (scannedFiles / totalFiles * 0.8) or 0 -- Escaneo de ROMs es el 80% del trabajo

                    if scannedFiles % 20 == 0 then
                        cleanupData.currentFile = line:match("([^/]+)$")
                        coroutine_yield()
                    end
                    
                    local filename = line:match("([^/]+)$")
                    if filename then
                        local ext = filename:match("[^%.]+$")
                        if ext then
                            local extLower = ext:lower()
                            -- La comprobación aquí es redundante por el `find` pero la dejamos como doble seguro
                            if validExtensions[extLower] and extLower ~= "state" then
                                local stem = filename:gsub("%..-$", "")
                                romNames[stem] = true
                                
                                if not romsByStem[stem] then romsByStem[stem] = {} end
                                
                                local system = line:match("ROMS/([^/]+)/") or "UNK"
                                
                                table_insert(romsByStem[stem], {
                                    name = stem,
                                    filename = filename,
                                    fullPath = line,
                                    system = system,
                                    location = locationLabel
                                })

                                if system ~= "UNK" then
                                    if not romsBySystem[system] then romsBySystem[system] = {} end
                                    romsBySystem[system][stem] = true
                                end
                            end
                        end
                    end
                end
                h:close()
            end
        end

        scanAndRegister("/mnt/mmc/ROMS", "SD1")
        scanAndRegister("/mnt/sdcard/ROMS", "SD2")
        -- Fallback para simulador
        if scannedFiles == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanAndRegister(cwd .. "/../Simulador_SD/", "SIM")
        end

        -- 2. Buscar Save States Huérfanos
        cleanupData.currentFile = "Buscando save states..."
        cleanupData.progress = 0.85
        coroutine_yield()
        local savePaths = {"/mnt/mmc/MUOS/save", "/mnt/sdcard/MUOS/save"}
        for _, path in ipairs(savePaths) do
            local h = io.popen('find "'..path..'" -name "*.state*"')
            if h then
                for line in h:lines() do
                    local name = line:match("([^/]+)$")
                    local base = name:gsub("%.state.*$", "")
                    if not romNames[base] then
                        table_insert(cleanupData.orphans, {
                            name = name,
                            fullPath = line,
                            location = line:find("/mnt/mmc") and "SD1" or "SD2"
                        })
                    end
                end
                h:close()
            end
        end
        
        cleanupData.progress = 0.9
        coroutine_yield()

        -- 3. Procesar Duplicados
        cleanupData.currentFile = "Analizando duplicados..."
        coroutine_yield()
        for stem, list in pairs(romsByStem) do
            if #list > 1 then
                for _, item in ipairs(list) do
                    table_insert(cleanupData.duplicates, item)
                end
            end
        end

        table_sort(cleanupData.duplicates, function(a, b)
            if a.name == b.name then
                if a.system == b.system then
                    return a.location < b.location
                end
                return a.system < b.system
            end
            return a.name < b.name
        end)

        cleanupData.progress = 0.95
        coroutine_yield()

        -- 4. Buscar Imágenes Huérfanas
        cleanupData.currentFile = "Buscando imágenes huérfanas..."
        coroutine_yield()
        local catalogueBase = "/mnt/mmc/MUOS/info/catalogue/"
        if not io_open("/mnt/mmc", "r") then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            catalogueBase = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
        end

        for system, stems in pairs(romsBySystem) do
            local boxPath = catalogueBase .. system .. "/box"
            local h = io.popen('find "'..boxPath..'" -maxdepth 1 -name "*.png" 2>/dev/null')
            if h then
                for line in h:lines() do
                    local filename = line:match("([^/]+)$")
                    local stem = filename:gsub("%..-$", "")
                    if not stems[stem] then
                        table_insert(cleanupData.orphanedImages, {
                            name = filename,
                            fullPath = line,
                            system = system,
                            type = "Image"
                        })
                    end
                end
                h:close()
            end
            coroutine_yield()
        end

        cleanupData.progress = 1.0
        cleanupData.scanning = false
        cleanupData.scanned = true
    end)
    return cleanupData, cleanupCoroutine
end

function M.deleteGameMedia(romPath)
    local system = romPath:match("ROMS/([^/]+)/")
    if not system then return end
    
    local filename = romPath:match("([^/]+)$")
    local baseName = filename:gsub("%..-$", "")
    
    -- Base path for catalogue (usually on SD1 in muOS)
    local cataloguePath = "/mnt/mmc/MUOS/info/catalogue/"
    if not io.open("/mnt/mmc", "r") then
        -- Simulator fallback
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        cataloguePath = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
    end
    
    local artPath = cataloguePath .. system .. "/box/" .. baseName .. ".png"
    local textPath = cataloguePath .. system .. "/text/" .. baseName .. ".txt"
    local yearPath = cataloguePath .. system .. "/text/" .. baseName .. ".year"
    local prevPath = cataloguePath .. system .. "/preview/" .. baseName .. ".png"
    
    os.remove(artPath)
    os.remove(textPath)
    os.remove(yearPath)
    os.remove(prevPath)
end

function M.findSaveFiles(item)
    local saveFiles = {}
    local saveManagerSelection = 1
    local baseName = item.name:gsub("%..-$", "")
    
    -- Escapar caracteres especiales para el comando find (ej: corchetes)
    local escapedName = baseName:gsub("([%[%]%*%?])", "\\%1")
    
    -- Rutas comunes de guardado en muOS / RetroArch
    local searchPaths = {}
    
    if io.open("/mnt/mmc", "r") then
        table.insert(searchPaths, "/mnt/mmc/MUOS/save")
        table.insert(searchPaths, "/mnt/sdcard/MUOS/save")
        table.insert(searchPaths, "/mnt/mmc/MUOS/save/state")
        table.insert(searchPaths, "/mnt/sdcard/MUOS/save/state")
    else
        -- Fallback Simulador
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local simPath = cwd .. "/../Simulador_SD/"
        table.insert(searchPaths, simPath .. "MUOS/save")
        table.insert(searchPaths, simPath .. "MUOS/save/state")
    end
    
    if item.fullPath then
        local romDir = item.fullPath:match("(.*/)")
        if romDir then table.insert(searchPaths, romDir) end
    end
    
    local foundMap = {}

    for _, path in ipairs(searchPaths) do
        -- Listar archivos que empiecen por el nombre de la ROM
        local cmd = 'find "'..path..'" -maxdepth 1 -name "'..escapedName..'.*" 2>/dev/null'
        local h = io.popen(cmd)
        if h then
            for line in h:lines() do
                if line:match("%.srm$") or line:match("%.state") then
                    if not foundMap[line] then
                        foundMap[line] = true
                        local location = "UNK"
                        if line:find("/mnt/mmc") then location = "SD1"
                        elseif line:find("/mnt/sdcard") then location = "SD2" end
                        
                        table.insert(saveFiles, {
                            name = line:match("([^/]+)$"),
                            fullPath = line,
                            location = location,
                            type = line:match("%.srm$") and "SaveRAM" or "State"
                        })
                    end
                end
            end
            h:close()
        end
    end
    return saveFiles, saveManagerSelection
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
