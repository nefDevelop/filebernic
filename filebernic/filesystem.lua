local M = {}
local utils = require "utils"
local core = require "fs_core"
local data = require "fs_data"
local scanner = require "fs_scanner"
local gamelist = require "fs_gamelist"
local media = require "fs_media"

M.isSafePath = core.isSafePath
M.safeRemove = core.safeRemove
M.copyFile = core.copyFile
M.moveFile = core.moveFile
M.saveFavorites = data.saveFavorites
M.loadFavorites = data.loadFavorites
M.addToHistory = data.addToHistory
M.saveLastPlayed = data.saveLastPlayed
M.savePendingHistory = data.savePendingHistory
M.checkPendingHistory = data.checkPendingHistory
M.saveHistory = data.saveHistory
M.logDeletion = data.logDeletion
M.saveViewCache = data.saveViewCache
M.loadViewCache = data.loadViewCache
M.addRecent = data.addRecent
M.loadRecent = data.loadRecent
M.addSearch = data.addSearch
M.loadSearch = data.loadSearch
M.saveCollections = data.saveCollections
M.loadCollections = data.loadCollections
M.addToCollection = data.addToCollection
M.removeFromCollection = data.removeFromCollection
M.getArtPathForSystem = scanner.getArtPathForSystem
M.hasRoms = scanner.hasRoms
M.escapeXML = gamelist.escapeXML
M.findInGamelist = gamelist.findInGamelist
M.updateSystemForFile = media.updateSystemForFile
M.deleteGameMedia = media.deleteGameMedia
M.saveScrapeResult = media.saveScrapeResult

function M.resolveSecondary(item)
    -- Permitir input de tipo string (ruta de carpeta)
    if type(item) == "string" then
        local path = item
        if path == "" then return nil end
        local target = nil
        if path:find("/mnt/mmc") then
            target = path:gsub("/mnt/mmc", "/mnt/sdcard", 1)
        elseif path:find("/mnt/sdcard") then
            target = path:gsub("/mnt/sdcard", "/mnt/mmc", 1)
        end
        if target then
            local f = io.open(target, "r")
            if f then f:close() return target end
        end
        return nil
    end
    if not item or not item.fullPath then return nil end
    if item.secondaryPath then return item.secondaryPath end
    
    local otherSD
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
    
    local f = io.open(secondary, "r")
    if f then
        f:close()
        return secondary
    end
    return nil
end

function M.getTargetSDPath(item, config)
    local targetSD = (config and config.copyToSD2) and "sdcard" or "mmc"
    local targetLabel = (targetSD == "sdcard") and "SD2" or "SD1"
    
    local srcLabel = nil
    if type(item) == "string" then
        if item:find("/mnt/mmc") then srcLabel = "SD1"
        elseif item:find("/mnt/sdcard") then srcLabel = "SD2" end
    elseif item and item.sourceLabel then
        srcLabel = item.sourceLabel
    end

    if srcLabel == "SD1" then
        targetSD = "sdcard"
        targetLabel = "SD2"
    elseif srcLabel == "SD2" then
        targetSD = "mmc"
        targetLabel = "SD1"
    end
    return "/mnt/" .. targetSD, targetLabel
end




function M.performCleanupScan(cleanupData, validExtensions, love_filesystem_getSource, io_open, coroutine_create, coroutine_yield, table_insert, table_sort)
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = true, progress = 0, cursor = {col=1, row=1}, confirming = false, currentFile = "" }
    
    local cleanupCoroutine = coroutine_create(function()
        local romNames = {} -- Para huérfanos: nombre base -> true
        local romsByStem = {} -- Para duplicados: nombre base -> lista de archivos
        local romsBySystem = {} -- Para imágenes huérfanas: system -> stem -> true

        local totalFiles = 0
        local scannedFiles = 0
        -- local find_exclude_str = [[-not -path "*.svn*" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.txt" -not -name "*.pdf" -not -name "*.db"]]
        -- Excluir patrones usando love.filesystem.getDirectoryItems
        local excluded_extensions = {
            png = true, jpg = true, jpeg = true, txt = true, pdf = true, db = true
        }

        local function countFilesInDir(currentPath)
            local h = io.popen('find ' .. utils.escapeShellArg(currentPath) .. ' -type f 2>/dev/null | wc -l')
            if h then
                local res = h:read("*a")
                h:close()
                return tonumber(res) or 0
            end
            return 0
        end

        -- 1. Contar todos los archivos primero para una barra de progreso precisa
        totalFiles = totalFiles + countFilesInDir("/mnt/mmc/ROMS")
        totalFiles = totalFiles + countFilesInDir("/mnt/sdcard/ROMS")
        -- Fallback para simulador
        if totalFiles == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            totalFiles = totalFiles + countFilesInDir(cwd .. "/../Simulador_SD/")
        end
        coroutine_yield()

        local function scanAndRegisterInDir(currentPath, locationLabel)
            local h = io.popen('find ' .. utils.escapeShellArg(currentPath) .. ' -type f 2>/dev/null')
            if not h then return end
            for full_item_path in h:lines() do
                scannedFiles = scannedFiles + 1
                cleanupData.progress = totalFiles > 0 and (scannedFiles / totalFiles * 0.8) or 0

                if scannedFiles % 20 == 0 then
                    cleanupData.currentFile = full_item_path:match("([^/]+)$") or ""
                    coroutine_yield()
                end
                
                local filename = full_item_path:match("([^/]+)$")
                if filename and filename:sub(1,1) ~= "." then
                    local ext = filename:match("[^%.]+$")
                    if ext then
                        local extLower = ext:lower()
                        if not excluded_extensions[extLower] and validExtensions[extLower] and extLower ~= "state" then
                            local stem = filename:gsub("%.[^%.]+$", "")
                            romNames[stem] = true
                            
                            if not romsByStem[stem] then romsByStem[stem] = {} end
                            
                            local system = full_item_path:match("ROMS/([^/]+)/") or full_item_path:match("Simulador_SD/([^/]+)/") or "UNK"
                            
                            table_insert(romsByStem[stem], {
                                name = stem,
                                filename = filename,
                                fullPath = full_item_path,
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

        scanAndRegisterInDir("/mnt/mmc/ROMS", "SD1")
        scanAndRegisterInDir("/mnt/sdcard/ROMS", "SD2")
        -- Fallback para simulador
        if scannedFiles == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanAndRegisterInDir(cwd .. "/../Simulador_SD/", "SD1")
        end

        -- 2. Buscar Save States Huérfanos
        cleanupData.currentFile = "Buscando save states..."
        cleanupData.progress = 0.85
        coroutine_yield()

        local function scanSaveStates(currentPath)
            local h = io.popen('find ' .. utils.escapeShellArg(currentPath) .. ' -type f 2>/dev/null')
            if not h then return end
            for full_item_path in h:lines() do
                local item_name = full_item_path:match("([^/]+)$")
                if item_name and (item_name:match("%.srm$") or item_name:match("%.state")) then
                    local name = item_name
                    local base = name:gsub("%.srm$", ""):gsub("%.state.*$", "")
                    if not romNames[base] then
                        table_insert(cleanupData.orphans, {
                            name = name,
                            fullPath = full_item_path,
                            location = full_item_path:find("/mnt/mmc") and "SD1" or (full_item_path:find("/mnt/sdcard") and "SD2" or "SD1")
                        })
                    end
                end
            end
            h:close()
        end

        local savePaths = {"/mnt/mmc/MUOS/save", "/mnt/sdcard/MUOS/save"}
        for _, path in ipairs(savePaths) do
            if love.filesystem.isDirectory(path) then
                scanSaveStates(path)
            end
        end
        -- Fallback para simulador
        local cwd = love_filesystem_getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local simSavePath = cwd .. "/../Simulador_SD/MUOS/save"
        if love.filesystem.isDirectory(simSavePath) then
            scanSaveStates(simSavePath)
        end
        
        cleanupData.progress = 0.9
        coroutine_yield()

        -- 3. Procesar Duplicados
        cleanupData.currentFile = "Analizando duplicados..."
        coroutine_yield()
        for _, list in pairs(romsByStem) do
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
        if not love.filesystem.isDirectory("/mnt/mmc") then -- Check if running on device
            catalogueBase = love_filesystem_getSource() .. "/../Simulador_SD/MUOS/info/catalogue/"
        end

        local function scanOrphanedImages(currentPath, systemName)
            local h = io.popen('find ' .. utils.escapeShellArg(currentPath) .. ' -maxdepth 1 -name "*.png" 2>/dev/null')
            if not h then return end
            for full_item_path in h:lines() do
                local item_name = full_item_path:match("([^/]+)$")
                if item_name then
                    local stem = item_name:gsub("%.[^%.]+$", "")
                    if not romsBySystem[systemName] or not romsBySystem[systemName][stem] then
                        table_insert(cleanupData.orphanedImages, {
                            name = item_name,
                            fullPath = full_item_path,
                            system = systemName,
                            type = "Image"
                        })
                    end
                end
            end
            h:close()
        end

        for system in pairs(romsBySystem) do
            local boxPath = catalogueBase .. system .. "/box"
            local h = io.popen('ls -d ' .. utils.escapeShellArg(boxPath) .. ' 2>/dev/null')
            if h then
                local res = h:read("*a")
                h:close()
                if res and res ~= "" then
                    scanOrphanedImages(boxPath, system)
                end
            end
            coroutine_yield()
        end

        cleanupData.progress = 1.0
        cleanupData.scanning = false
        cleanupData.scanned = true
    end)
    return cleanupData, cleanupCoroutine
end

function M.findSaveFiles(item)
    local saveFiles = {}
    local saveManagerSelection = 1
    local baseName = item.name:gsub("%.[^%.]+$", "")
    
    -- Escapar caracteres especiales para el comando find (ej: corchetes)
    local escapedName = baseName:gsub("([%[%]%*%?])", "\\%1")
    
    -- Rutas comunes de guardado en muOS / RetroArch
    local searchPaths = {}
    
    if utils.isDevice() then
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
        local cmd = 'find ' .. utils.escapeShellArg(path) .. ' -maxdepth 1 -name ' .. utils.escapeShellArg(escapedName .. ".*") .. ' 2>/dev/null'
        local h = io.popen(cmd)
        if h then
            for line in h:lines() do
                if line:match("%.srm$") or line:match("%.state") then
                    if not foundMap[line] then
                        foundMap[line] = true
                        local location = "UNK"
                        if line:find("/mnt/mmc") then location = "SD1"
                        elseif line:find("/mnt/sdcard") then location = "SD2"
                        elseif line:find("Simulador_SD") then location = "SD1" end
                        
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

function M.checkIndex(romIndex, json_decode, love_filesystem_getSource, io_open, log)
    local dataDir = love_filesystem_getSource() .. "/data"
    local indexPath = dataDir .. "/rom_index.json"
    local tsPath = dataDir .. "/rom_timestamps.json"

    local indexFile = io_open(indexPath, "r")
    local tsFile = io_open(tsPath, "r")

    if not indexFile or not tsFile then
        if indexFile then indexFile:close() end
        if tsFile then tsFile:close() end
        log("No index found. Indexing needed.")
        return nil, true -- romIndex, needsIndexing
    end

    -- Si los archivos existen, comprobar timestamps
    local needsReindex = false
    local tsContent = tsFile:read("*a")
    tsFile:close()
    local savedTimestamps = json_decode(tsContent)
    
    if not savedTimestamps then
        log("Timestamps file corrupted. Indexing needed.")
        needsReindex = true
    else
        local walker = require "fs_walker"
        for dir, saved_ts in pairs(savedTimestamps) do
            local current_ts = tostring(walker.getDirTimestamp(dir) or "")
            if current_ts ~= "" and current_ts ~= saved_ts then
                log("Change detected in " .. dir .. ". Indexing needed.")
                needsReindex = true
                break
            end
        end
    end

    if needsReindex then
        return nil, true
    else
        log("Index is up to date. Loading from file.")
        local indexContent = indexFile:read("*a")
        indexFile:close()
        local decoded, _, err = json_decode(indexContent)
        if decoded then
            romIndex = decoded
            log("Index loaded successfully. Items: " .. #romIndex)
            return romIndex, false
        else
            log("Error decoding index JSON: " .. tostring(err))
            log("Corrupted index. Indexing needed.")
            return nil, true
        end
    end
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

function M.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, getSystemIcon_func, fs_getInfo, gfx_newImage, allFiles, pathToSelect, favoriteRoms, hideFavorites)
    files = {}
    isVirtualRoot = true
    romPath = "" -- Not a real path in this view
    secondaryPath = nil
    local targetIndex = selectedIndex or 1
    selectedIndex = 1

    if launchMode == "Juego Unico" then
        if romIndex then
            -- El índice está listo, úsalo.
            files = {}
            for _, item in ipairs(romIndex) do
                -- Shallow copy inicial
                local copy = {}
                for k, v in pairs(item) do copy[k] = v end
                
                -- Filtrar versiones si hideFavorites está activo
                if hideFavorites and favoriteRoms then
                    local filteredVersions = {}
                    for _, v in ipairs(copy.versions) do
                        if not favoriteRoms[v.fullPath] then
                            table.insert(filteredVersions, v)
                        end
                    end
                    copy.versions = filteredVersions
                end

                if #copy.versions > 0 then
                    table.insert(files, copy)
                end
            end
        else
            -- El índice no está listo, se mostrará un mensaje de "cargando" en drawing.lua
            -- Dejamos `files` vacío por ahora.
        end

    else
        -- MODO CARPETA: Listar Sistemas (Comportamiento original)
        local dirMap = {} 
        local function scanOnePath(scanPath, label, foundRef)
            local added = 0
            local walker = require "fs_walker"
            local entries = walker.listDir(scanPath)
            if not entries then return 0 end

            for _, entry in ipairs(entries) do
                if walker.isDir(scanPath .. "/" .. entry) then
                    local dirName = entry
                    if dirName ~= "BIOS" and dirName ~= "Saves" and dirName ~= "MUOS" and dirName ~= "System Volume Information" then
                        if not hideEmpty or M.hasRoms(scanPath .. entry .. "/", validExtensions) then
                            if dirMap[dirName] then
                                files[dirMap[dirName]].sourceLabel = "SD½"
                                files[dirMap[dirName]].secondaryPath = scanPath .. entry .. "/"
                            else
                                local icon = getSystemIcon_func and getSystemIcon_func(dirName, fs_getInfo, gfx_newImage) or nil
                                table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. entry .. "/", sourceLabel = label, icon = icon})
                                dirMap[dirName] = #files
                                added = added + 1
                            end
                        end
                    end
                end
            end
            return added
        end

        local function scanWithFallback(scanPath, label)
            local added = scanOnePath(scanPath, label)
            if added > 0 then return added end

            -- Fallback: si love.filesystem falla, intentar io.popen
            local handle = io.popen('ls -p ' .. utils.escapeShellArg(scanPath) .. ' 2>/dev/null')
            if handle then
                for line in handle:lines() do
                    if line:sub(-1) == "/" then
                        local dirName = line:sub(1, -2)
                        if dirName ~= "BIOS" and dirName ~= "Saves" and dirName ~= "MUOS" and dirName ~= "System Volume Information" then
                            if not hideEmpty or M.hasRoms(scanPath .. line, validExtensions) then
                                if dirMap[dirName] then
                                    files[dirMap[dirName]].sourceLabel = "SD½"
                                    files[dirMap[dirName]].secondaryPath = scanPath .. line
                                else
                                    local icon = getSystemIcon_func and getSystemIcon_func(dirName, fs_getInfo, gfx_newImage) or nil
                                    table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. line, sourceLabel = label, icon = icon})
                                    dirMap[dirName] = #files
                                    added = added + 1
                                end
                            end
                        end
                    end
                end
                handle:close()
            end
            return added
        end

        scanWithFallback("/mnt/mmc/ROMS/", "SD1")
        scanWithFallback("/mnt/sdcard/ROMS/", "SD2")

        -- Fallback Simulador
        if #files == 0 then
            local walker = require "fs_walker"
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simPath = cwd .. "/../"
            if walker.isDir(simPath .. "Simulador_SD") then
                scanWithFallback(simPath .. "Simulador_SD/", "SD1")
            end
        end
    end
    
    -- Sort files alphabetically by name
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)

    -- Insert Favorites folder if there are favorites
    local hasFavorites = false
    if favoriteRoms and next(favoriteRoms) ~= nil then hasFavorites = true end
    
    if hasFavorites then
        table.insert(files, 1, {
            name = "Favoritos",
            isDir = true,
            fullPath = "@Favorites/",
            isFavorites = true
        })
    end

    -- Insert Recent folder (always visible)
    local insertPos = 1
    if hasFavorites then insertPos = 2 end
    table.insert(files, insertPos, {
        name = "Recientes",
        isDir = true,
        fullPath = "@Recent/",
        isRecent = true
    })

    -- Insert Collections folder (always visible)
    table.insert(files, hasFavorites and 3 or 2, {
        name = "Colecciones",
        isDir = true,
        fullPath = "@Collections/",
        isCollection = true
    })

    -- After sorting, find the item to select
    if pathToSelect then
        if pathToSelect == "@Favorites/" then
            for i, item in ipairs(files) do
                if item.name == "Favoritos" then
                    selectedIndex = i
                    break
                end
            end
        elseif pathToSelect == "@Recent/" then
            for i, item in ipairs(files) do
                if item.name == "Recientes" then
                    selectedIndex = i
                    break
                end
            end
        end
        if launchMode == "Juego Unico" then
             for i, item in ipairs(files) do
                 if item.fullPath == pathToSelect then
                     selectedIndex = i
                     break
                 end
                 if item.versions then
                     for _, v in ipairs(item.versions) do
                         if v.fullPath == pathToSelect then
                             selectedIndex = i
                             break
                         end
                     end
                 end
                 if selectedIndex == i then break end
             end
        else
            local systemToSelect = pathToSelect:match("ROMS/([^/]+)/") or pathToSelect:match("Simulador_SD/([^/]+)/")
            if systemToSelect then
                for i, item in ipairs(files) do
                    if item.name == systemToSelect then
                        selectedIndex = i
                        break
                    end
                end
            end
        end
    else
        selectedIndex = targetIndex
    end

    -- Ensure selectedIndex is within bounds
    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > #files then selectedIndex = math.max(1, #files) end

    -- Back up the full list
    allFiles = {}
    for _, item in ipairs(files) do
        table.insert(allFiles, item)
    end

    return files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles
end

function M.updateSystemPaths(systemName, romPath, log, fs_getInfo, gfx_newImage)
    local detectedSystem = romPath:match("ROMS/([^/]+)/") or romPath:match("Simulador_SD/([^/]+)/")
    
    local muosArtPath = ""
    local muosTextPath = ""
    local muosPreviewPath = ""
    local currentSystemIcon = nil
    local currentSystemContentIcon = nil

    if detectedSystem and detectedSystem ~= systemName then
        systemName = detectedSystem
        log("System detected: " .. systemName)
        
        local baseMuosPath = utils.getBaseMuosPath()
        muosArtPath = baseMuosPath .. systemName .. "/box/"
        muosTextPath = baseMuosPath .. systemName .. "/text/"
        muosPreviewPath = baseMuosPath .. systemName .. "/preview/"
        -- Year is stored in text path with .year extension

        -- Buscar grupo de variantes para el sistema detectado
        local variants = utils.getSystemVariants(systemName)
        log("Variant group found for: " .. systemName)

        -- Cargar icono del sistema (probar todas las variantes)
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. ".png" -- Construct path
            if fs_getInfo(path) then -- Check if file exists
                currentSystemIcon = gfx_newImage(path) -- Load image
                log("System icon found: " .. path)
                break
            end
        end
        if not currentSystemIcon then
            log("System icon NOT found")
        end

        -- Cargar icono de contenido (ROM) (probar todas las variantes)
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. "-content.png" -- Construct path
            if fs_getInfo(path) then -- Check if file exists
                currentSystemContentIcon = gfx_newImage(path) -- Load image
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

function M.fixPathCase(path)
    if not path or path == "" then return path end
    
    -- Detectar si estamos en una ruta de sistema (ROMS/Sys/ o Simulador_SD/Sys/)
    local prefix, sys, suffix = path:match("^(.*ROMS/)([^/]+)(/.*)$")
    if not prefix then
        prefix, sys, suffix = path:match("^(.*Simulador_SD/)([^/]+)(/.*)$")
    end
    
    if prefix and sys then
        -- Listar el directorio padre para encontrar el nombre real (con mayúsculas correctas)
        local h = io.popen('ls -p ' .. utils.escapeShellArg(prefix) .. ' 2>/dev/null')
        if h then
            for line in h:lines() do
                if line:sub(-1) == "/" then
                    local realDir = line:sub(1, -2)
                    if realDir:lower() == sys:lower() and realDir ~= sys then
                        h:close()
                        return prefix .. realDir .. suffix
                    end
                end
            end
            h:close()
        end
    end
    return path
end

function M.refreshFiles(updateSystemPaths, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, log, favoriteRoms, hideFavorites)
    updateSystemPaths()
    if romPath and romPath ~= "" and romPath:sub(-1) ~= "/" then romPath = romPath .. "/" end
    files = {}
    selectedFilesCount = 0

    if romPath == "@Favorites/" then
        for path, _ in pairs(favoriteRoms) do
            local name = path:match("([^/]+)$")
            local stem = name:gsub("%.[^%.]+$", "")
            local system = path:match("ROMS/([^/]+)/") or path:match("Simulador_SD/([^/]+)/")
            table.insert(files, {
                name = stem,
                fullPath = path,
                isDir = false,
                system = system,
                sourceLabel = "Fav"
            })
        end
        table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
        if selectedIndex < 1 then selectedIndex = 1 end
        if selectedIndex > #files then selectedIndex = math.max(1, #files) end
        allFiles = {}
        for _, item in ipairs(files) do table.insert(allFiles, item) end
        return files, selectedFilesCount, selectedIndex, allFiles
    end

    if romPath == "@Recent/" then
        local recent = {}
        local f = io.open(love.filesystem.getSource() .. "/data/recent.json", "r")
        if f then
            local c = f:read("*a")
            f:close()
            if c and c ~= "" then recent = json.decode(c) or {} end
        end
        for _, path in ipairs(recent) do
            local name = path:match("([^/]+)$")
            if name then
                local stem = name:gsub("%.[^%.]+$", "")
                local system = path:match("ROMS/([^/]+)/") or path:match("Simulador_SD/([^/]+)/")
                table.insert(files, {
                    name = stem,
                    fullPath = path,
                    isDir = false,
                    system = system,
                    sourceLabel = "Rec"
                })
            end
        end
        allFiles = {}
        for _, item in ipairs(files) do table.insert(allFiles, item) end
        return files, selectedFilesCount, selectedIndex, allFiles
    end

    if romPath == "@Collections/" then
        local collections = {}
        local f = io.open(love.filesystem.getSource() .. "/data/collections.json", "r")
        if f then
            local c = f:read("*a")
            f:close()
            if c and c ~= "" then collections = json.decode(c) or {} end
        end
        for name, _ in pairs(collections) do
            table.insert(files, {
                name = name,
                isDir = true,
                fullPath = "@Collections/" .. name .. "/",
                sourceLabel = "Col"
            })
        end
        table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
        allFiles = {}
        for _, item in ipairs(files) do table.insert(allFiles, item) end
        return files, selectedFilesCount, selectedIndex, allFiles
    end

    local colMatch = romPath:match("^@Collections/(.+)/$")
    if colMatch then
        local colName = colMatch
        local collections = {}
        local f = io.open(love.filesystem.getSource() .. "/data/collections.json", "r")
        if f then
            local c = f:read("*a")
            f:close()
            if c and c ~= "" then collections = json.decode(c) or {} end
        end
        if collections[colName] then
            for _, path in ipairs(collections[colName]) do
                local name = path:match("([^/]+)$")
                if name then
                    local stem = name:gsub("%.[^%.]+$", "")
                    local system = path:match("ROMS/([^/]+)/") or path:match("Simulador_SD/([^/]+)/")
                    table.insert(files, {
                        name = stem,
                        fullPath = path,
                        isDir = false,
                        system = system,
                        sourceLabel = "Col"
                    })
                end
            end
        end
        allFiles = {}
        for _, item in ipairs(files) do table.insert(allFiles, item) end
        return files, selectedFilesCount, selectedIndex, allFiles
    end

    local currentSystem = romPath:match("ROMS/([^/]+)/") or romPath:match("Simulador_SD/([^/]+)/")

    local fileMap = {} -- Key: filename (Folder mode) or stem (Juego Unico mode)

    local function scan(path, label)
        local handle
        local isFind = false
        
        if launchMode == "Juego Unico" then
            -- Búsqueda recursiva solo de archivos
            handle = io.popen('find ' .. utils.escapeShellArg(path) .. ' -type f 2>/dev/null')
            isFind = true
        else
            -- Listado estándar de directorio actual
            handle = io.popen('ls -p ' .. utils.escapeShellArg(path) .. ' 2>/dev/null')
            if log then log("Scanning dir: " .. path) end
        end

        if handle then
            for line in handle:lines() do
                -- if log then log("Found item: " .. line) end
                local isDirectory = not isFind and (line:sub(-1) == "/")
                local cleanName = isFind and line:match("([^/]+)$") or (isDirectory and line:sub(1, -2) or line)
                local fullPath = isFind and line or (path .. line)

                -- Filtrar archivos ocultos y asegurar nombre válido
                if cleanName and cleanName:sub(1, 1) ~= "." and cleanName ~= "MUOS" and cleanName ~= "BIOS" and cleanName ~= "Saves" and cleanName ~= "System Volume Information" then
                local ext = cleanName:match("[^%.]+$")
                if isDirectory or (ext and validExtensions[ext:lower()]) then
                    local skip = false
                    if isDirectory and hideEmpty and not M.hasRoms(fullPath, validExtensions) then
                        skip = true
                        if log then log("Skipping empty dir: " .. cleanName) end
                    end

                    if not isDirectory and hideFavorites and favoriteRoms and favoriteRoms[fullPath] then
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
                                    system = system
                                })
                                item.sourceLabel = "Multi"
                            else
                                files[idx].sourceLabel = "SD½"
                                files[idx].secondaryPath = fullPath
                            end
                        else
                            local newItem = {name = (not isDirectory and launchMode == "Juego Unico") and stem or cleanName, isDir = isDirectory, fullPath = fullPath, sourceLabel = label, system = not isDirectory and currentSystem or nil}
                            if not isDirectory and launchMode == "Juego Unico" then
                                newItem.versions = {{name = cleanName, fullPath = fullPath, sourceLabel = label, system = system}}
                            end
                            table.insert(files, newItem)
                            fileMap[key] = #files
                            -- if log then log("Added to list: " .. newItem.name) end
                        end
                    end
                else
                    if log then log("Skipping invalid ext/dir: " .. cleanName) end
                end
                else
                    if log then log("Skipping filtered: " .. cleanName) end
                end
            end
            handle:close()
        end
    end

    scan(romPath, romPath:find("/mnt/mmc") and "SD1" or (romPath:find("/mnt/sdcard") and "SD2" or "SD1"))
    if secondaryPath then
        scan(secondaryPath, secondaryPath:find("/mnt/mmc") and "SD1" or (secondaryPath:find("/mnt/sdcard") and "SD2" or "SD1"))
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

    return files, selectedFilesCount, selectedIndex, allFiles
end

return M
