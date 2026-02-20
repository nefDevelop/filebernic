local M = {}
local utils = require "utils"

local artPathCache = {}
function M.getArtPathForSystem(systemName)
    if not systemName or systemName == "" then return nil end
    if artPathCache[systemName] then return artPathCache[systemName] end
    
    local baseMuosPath
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
        baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
    else
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        baseMuosPath = cwd .. "/../Simulador_SD/MUOS/info/catalogue/"
    end
    
    -- Resolver mayúsculas/minúsculas del directorio del sistema
    local h = io.popen('ls -p "'..baseMuosPath..'" 2>/dev/null')
    if h then
        for line in h:lines() do
            if line:sub(-1) == "/" then
                local dir = line:sub(1, -2)
                if dir:lower() == systemName:lower() then
                    local res = baseMuosPath .. dir .. "/box/"
                    h:close()
                    artPathCache[systemName] = res
                    return res
                end
            end
        end
        h:close()
    end
    local res = baseMuosPath .. systemName .. "/box/"
    artPathCache[systemName] = res
    return res
end

function M.hasRoms(path, validExtensions)
    local handle = io.popen('ls -p "'..path..'"')
    if handle then
        for line in handle:lines() do
            if line:sub(-1) ~= "/" then
                local ext = line:match("[^%.]+$")
                if ext and validExtensions[ext:lower()] then
                    handle:close()
                    return true
                end
            end
        end
        handle:close()
        return false
    end
    
    -- Fallback: os.execute to temp file (if popen fails due to resource limits)
    local tmpFile = "/tmp/filebernic_hasroms.txt"
    os.execute('ls -p "'..path..'" > '..tmpFile..' 2>/dev/null')
    local f = io.open(tmpFile, "r")
    if f then
        for line in f:lines() do
            if line:sub(-1) ~= "/" then
                local ext = line:match("[^%.]+$")
                if ext and validExtensions[ext:lower()] then
                    f:close()
                    return true
                end
            end
        end
        f:close()
        return false
    end

    -- Fallback: Intentar usar love.filesystem si io.popen falla
    local items = love.filesystem.getDirectoryItems(path)
    if items then
        for _, item in ipairs(items) do
            local ext = item:match("[^%.]+$")
            if ext and validExtensions[ext:lower()] then
                if love.filesystem.isFile(path .. item) then return true end
            end
        end
    end
    return false
end

-- Helper para escapar caracteres XML
local function escapeXML(s)
    if not s then return "" end
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub("\"", "&quot;")
    s = s:gsub("'", "&apos;")
    return s
end
M.escapeXML = escapeXML

function M.findInGamelist(romFullPath, romFilename)
    if not romFullPath then return nil end
    local dir = romFullPath:match("(.*/)")
    if not dir then return nil end
    local xmlPath = dir .. "gamelist.xml"
    
    local f = io.open(xmlPath, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    
    -- Buscar bloque del juego específico
    local searchPath = "./" .. romFilename
    local escapedPath = searchPath:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    
    local gameBlock = nil
    for block in content:gmatch("<game>(.-)</game>") do
        if block:find("<path>%s*" .. escapedPath .. "%s*</path>") then
            gameBlock = block
            break
        end
    end
    
    if gameBlock then
        local desc = gameBlock:match("<desc>(.-)</desc>")
        local year = gameBlock:match("<releasedate>(%d%d%d%d)")
        local img = gameBlock:match("<image>(.-)</image>")
        
        if desc then desc = desc:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\""):gsub("&apos;", "'") end
        
        local absImgPath = nil
        if img then
            -- Resolver ruta relativa de la imagen
            if img:sub(1,2) == "./" then absImgPath = dir .. img:sub(3)
            elseif img:sub(1,1) ~= "/" then absImgPath = dir .. img
            else absImgPath = img end
        end
        
        return { description = desc, year = year, imagePath = absImgPath, source = "Gamelist.xml" }
    end
    return nil
end

-- Función para actualizar gamelist.xml
local function updateGamelistXML(romPath, metadata, action)
    local dir = romPath:match("(.*/)")
    if not dir then return end
    local filename = romPath:match("([^/]+)$")
    local xmlPath = dir .. "gamelist.xml"
    
    local content = ""
    local f = io.open(xmlPath, "r")
    if f then
        content = f:read("*all")
        f:close()
    else
        if action == "delete" then return end -- No hay nada que borrar
        content = "<?xml version=\"1.0\"?>\n<gameList>\n</gameList>"
    end
    
    local relPath = "./" .. filename
    local escapedPath = relPath:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    
    local games = {}
    -- Iterar sobre juegos existentes y filtrar el actual
    for game in content:gmatch("<game>(.-)</game>") do
        if not game:find("<path>%s*" .. escapedPath .. "%s*</path>") then
            table.insert(games, "<game>" .. game .. "</game>")
        end
    end
    
    if action == "add" and metadata then
        local name = metadata.name or filename:gsub("%..-$", "")
        local entry = "  <game>\n"
        entry = entry .. "    <path>" .. relPath .. "</path>\n"
        entry = entry .. "    <name>" .. escapeXML(name) .. "</name>\n"
        if metadata.image then entry = entry .. "    <image>" .. escapeXML(metadata.image) .. "</image>\n" end
        if metadata.desc then entry = entry .. "    <desc>" .. escapeXML(metadata.desc) .. "</desc>\n" end
        if metadata.year then entry = entry .. "    <releasedate>" .. metadata.year .. "0101T000000</releasedate>\n" end
        entry = entry .. "  </game>"
        table.insert(games, entry)
    end
    
    local f = io.open(xmlPath, "w")
    if f then
        f:write("<?xml version=\"1.0\"?>\n<gameList>\n")
        for _, g in ipairs(games) do f:write(g .. "\n") end
        f:write("</gameList>")
        f:close()
    end
end

function M.saveFavorites(favoriteRoms, json_encode)
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/favorites.json", "w")
    if f then
        f:write(json_encode(favoriteRoms))
        f:close()
    end
end

function M.loadFavorites(json_decode)
    local path = love.filesystem.getSource() .. "/data/favorites.json"
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        return json_decode(content) or {}
    end
    return {}
end

function M.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    local currentPath = item.fullPath or (romPath .. item.name)
    local detectedSystem = currentPath:match("ROMS/([^/]+)/") or currentPath:match("Simulador_SD/([^/]+)/")
    
    if detectedSystem and (detectedSystem ~= systemName or not muosArtPath or muosArtPath == "") then
        systemName = detectedSystem
        
        -- log("System detected changed to: " .. systemName) -- Comentado para no saturar log en scroll
        -- Recalcular rutas de arte
        local baseMuosPath = ""
        local f = io.open("/mnt/mmc", "r")
        if f then
             f:close()
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
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
    else
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
    
    -- Eliminar entrada de gamelist.xml
    updateGamelistXML(romPath, nil, "delete")
end

function M.addToHistory(path, playedRoms)
    playedRoms[path] = true
    M.saveHistory(playedRoms)
    return playedRoms
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
    if not muosArtPath or muosArtPath == "" then
        if log then log("Error: muosArtPath is empty. Cannot save art.") end
        return
    end
    if result and result.tempPath then
        local baseName = item.name:gsub("%..-$", "")
        
        -- Asegurar directorio de destino para boxart
        os.execute("mkdir -p '" .. muosArtPath .. "'")
        
        -- Mover archivo temporal a destino final para boxart
        local destPath = muosArtPath .. baseName .. ".png"
        local finalImagePath = destPath -- Guardamos ruta absoluta para el XML
        log("Saving boxart to: " .. destPath)
        
        local inp = io.open(result.tempPath, "rb")
        if inp then
            local content = inp:read("*a")
            inp:close()
            local out = io.open(destPath, "wb")
            if out then
                out:write(content)
                out:close()
            else
                log("Error writing boxart file: " .. destPath)
            end
        else
            log("Error reading temp boxart file: " .. result.tempPath)
        end
        
        -- Guardar descripción
        if result.description then
            os.execute("mkdir -p '" .. muosTextPath .. "'")
            local txtPath = muosTextPath .. baseName .. ".txt"
            log("Saving description to: " .. txtPath)
            local f = io.open(txtPath, "w")
            if f then f:write(result.description) f:close() end
        end
        
        -- Guardar año
        if result.year then
            os.execute("mkdir -p '" .. muosTextPath .. "'")
            local yearPath = muosTextPath .. baseName .. ".year"
            log("Saving year to: " .. yearPath)
            local f = io.open(yearPath, "w")
            if f then f:write(result.year) f:close() end
        end
        
        -- Guardar screenshot (si existe carpeta preview)
        if result.tempScreenPath and muosPreviewPath ~= "" then
            os.execute("mkdir -p '" .. muosPreviewPath .. "'")
            local destScreen = muosPreviewPath .. baseName .. ".png"
            log("Saving preview to: " .. destScreen)

            local inp = io.open(result.tempScreenPath, "rb")
            if inp then
                local content = inp:read("*a")
                inp:close()
                local out = io.open(destScreen, "wb")
                if out then
                    out:write(content)
                    out:close()
                end
            else
                log("Error reading temp screenshot file: " .. result.tempScreenPath)
            end
        end
        
        -- Actualizar gamelist.xml
        local meta = {
            name = baseName, -- O usar result.name si el scraper lo devolvera
            desc = result.description,
            year = result.year,
            image = finalImagePath
        }
        updateGamelistXML(item.fullPath or (item.name), meta, "add")
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
        -- local find_exclude_str = [[-not -path "*.svn*" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.txt" -not -name "*.pdf" -not -name "*.db"]]
        -- Excluir patrones usando love.filesystem.getDirectoryItems
        local excluded_extensions = {
            png = true, jpg = true, jpeg = true, txt = true, pdf = true, db = true
        }

        local function countFilesInDir(currentPath)
            local count = 0
            local items = love.filesystem.getDirectoryItems(currentPath)
            for _, item_name in ipairs(items) do
                local full_item_path = currentPath .. "/" .. item_name
                if love.filesystem.isFile(full_item_path) then
                    local ext = item_name:match("[^%.]+$")
                    if not (ext and excluded_extensions[ext:lower()]) then
                        count = count + 1
                    end
                elseif love.filesystem.isDirectory(full_item_path) then
                    -- Excluir directorios .svn (si LÖVE los expone) y otros
                    if item_name ~= ".svn" then
                        count = count + countFilesInDir(full_item_path)
                    end
                end
            end
            return count
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
            local items = love.filesystem.getDirectoryItems(currentPath)
            for _, item_name in ipairs(items) do
                local full_item_path = currentPath .. "/" .. item_name
                if love.filesystem.isFile(full_item_path) then
                    scannedFiles = scannedFiles + 1
                    cleanupData.progress = totalFiles > 0 and (scannedFiles / totalFiles * 0.8) or 0 -- Escaneo de ROMs es el 80% del trabajo

                    if scannedFiles % 20 == 0 then
                        cleanupData.currentFile = item_name
                        coroutine_yield()
                    end
                    
                    local filename = item_name
                    if filename then
                        local ext = filename:match("[^%.]+$")
                        if ext then
                            local extLower = ext:lower()
                            if not excluded_extensions[extLower] and validExtensions[extLower] and extLower ~= "state" then
                                local stem = filename:gsub("%..-$", "")
                                romNames[stem] = true
                                
                                if not romsByStem[stem] then romsByStem[stem] = {} end
                                
                                local system = full_item_path:match("ROMS/([^/]+)/") or "UNK"
                                
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
                elseif love.filesystem.isDirectory(full_item_path) then
                    if item_name ~= ".svn" then
                        scanAndRegisterInDir(full_item_path, locationLabel)
                    end
                end
            end
        end

        scanAndRegisterInDir("/mnt/mmc/ROMS", "SD1")
        scanAndRegisterInDir("/mnt/sdcard/ROMS", "SD2")
        -- Fallback para simulador
        if scannedFiles == 0 then
            local cwd = love_filesystem_getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanAndRegisterInDir(cwd .. "/../Simulador_SD/", "SIM")
        end

        -- 2. Buscar Save States Huérfanos
        cleanupData.currentFile = "Buscando save states..."
        cleanupData.progress = 0.85
        coroutine_yield()

        local function scanSaveStates(currentPath)
            local items = love.filesystem.getDirectoryItems(currentPath)
            for _, item_name in ipairs(items) do
                local full_item_path = currentPath .. "/" .. item_name
                if love.filesystem.isFile(full_item_path) then
                    if item_name:match("%.srm$") or item_name:match("%.state") then
                        local name = item_name
                        local base = name:gsub("%.srm$", ""):gsub("%.state.*$", "")
                        if not romNames[base] then
                            table_insert(cleanupData.orphans, {
                                name = name,
                                fullPath = full_item_path,
                                location = full_item_path:find("/mnt/mmc") and "SD1" or (full_item_path:find("/mnt/sdcard") and "SD2" or "SIM")
                            })
                        end
                    end
                elseif love.filesystem.isDirectory(full_item_path) then
                    scanSaveStates(full_item_path)
                end
            end
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
        if not love.filesystem.isDirectory("/mnt/mmc") then -- Check if running on device
            catalogueBase = love_filesystem_getSource() .. "/../Simulador_SD/MUOS/info/catalogue/"
        end

        local function scanOrphanedImages(currentPath, systemName)
            local items = love.filesystem.getDirectoryItems(currentPath)
            for _, item_name in ipairs(items) do
                local full_item_path = currentPath .. "/" .. item_name
                if love.filesystem.isFile(full_item_path) then
                    if item_name:match("%.png$") then
                        local stem = item_name:gsub("%..-$", "")
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
            end
        end

        for system, stems in pairs(romsBySystem) do
            local boxPath = catalogueBase .. system .. "/box"
            if love.filesystem.isDirectory(boxPath) then
                scanOrphanedImages(boxPath, system)
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
    local baseName = item.name:gsub("%..-$", "")
    
    -- Escapar caracteres especiales para el comando find (ej: corchetes)
    local escapedName = baseName:gsub("([%[%]%*%?])", "\\%1")
    
    -- Rutas comunes de guardado en muOS / RetroArch
    local searchPaths = {}
    
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
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
        for dir, saved_ts in pairs(savedTimestamps) do
            local h = io.popen('date -r "'..dir..'" +%s 2>/dev/null')
            if h then
                local current_ts = h:read("*a"):gsub("%s+", "")
                h:close()
                if current_ts ~= "" and current_ts ~= saved_ts then
                    log("Change detected in " .. dir .. ". Indexing needed.")
                    needsReindex = true
                    break
                end
            end
        end
    end

    if needsReindex then
        return nil, true
    else
        log("Index is up to date. Loading from file.")
        local indexContent = indexFile:read("*a")
        indexFile:close()
        local decoded, pos, err = json_decode(indexContent)
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
        local function scanAndAdd(scanPath, label)
            if log then log("Scanning root: " .. scanPath) end

            local handle = io.popen('ls -p "'..scanPath..'"')
            if handle then
                local foundCount = 0
                for line in handle:lines() do
                    if line:sub(-1) == "/" then
                        local dirName = line:sub(1, -2)
                        if dirName ~= "BIOS" and dirName ~= "Saves" then
                            if not hideEmpty or M.hasRoms(scanPath .. line, validExtensions) then
                                if dirMap[dirName] then
                                    files[dirMap[dirName]].sourceLabel = "SD½"
                                    files[dirMap[dirName]].secondaryPath = scanPath .. line
                                else
                                    local icon = getSystemIcon_func and getSystemIcon_func(dirName, fs_getInfo, gfx_newImage) or nil
                                    table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. line, sourceLabel = label, icon = icon})
                                    dirMap[dirName] = #files
                                    foundCount = foundCount + 1
                                end
                            end
                        end
                    end
                end
                handle:close()
                if log then log("Scan complete for " .. scanPath .. ". Added: " .. foundCount) end
            else
                if log then log("Error: Failed to open pipe for " .. scanPath .. ". Trying os.execute fallback.") end
                local tmpFile = "/tmp/filebernic_scan.txt"
                os.execute('ls -p "'..scanPath..'" > '..tmpFile..' 2>/dev/null')
                local f = io.open(tmpFile, "r")
                if f then
                    local foundCount = 0
                    for line in f:lines() do
                        if line:sub(-1) == "/" then
                            local dirName = line:sub(1, -2)
                            if dirName ~= "BIOS" and dirName ~= "Saves" then
                                if not hideEmpty or M.hasRoms(scanPath .. line, validExtensions) then
                                    if dirMap[dirName] then
                                        files[dirMap[dirName]].sourceLabel = "SD½"
                                        files[dirMap[dirName]].secondaryPath = scanPath .. line
                                    else
                                        local icon = getSystemIcon_func and getSystemIcon_func(dirName, fs_getInfo, gfx_newImage) or nil
                                        table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. line, sourceLabel = label, icon = icon})
                                        dirMap[dirName] = #files
                                        foundCount = foundCount + 1
                                    end
                                end
                            end
                        end
                    end
                    f:close()
                    if log then log("os.execute Scan complete for " .. scanPath .. ". Added: " .. foundCount) end
                else
                if log then log("Error: Failed to open pipe for " .. scanPath) end
                -- Fallback: Intentar usar love.filesystem si io.popen falla
                local items = love.filesystem.getDirectoryItems(scanPath)
                if items then
                    local foundCount = 0
                    for _, item in ipairs(items) do
                        local fullPath = scanPath .. item
                        if love.filesystem.isDirectory(fullPath) then
                            local dirName = item
                            if dirName ~= "BIOS" and dirName ~= "Saves" and dirName:sub(1,1) ~= "." then
                                if not hideEmpty or M.hasRoms(fullPath .. "/", validExtensions) then
                                    if dirMap[dirName] then
                                        files[dirMap[dirName]].sourceLabel = "SD½"
                                        files[dirMap[dirName]].secondaryPath = fullPath
                                    else
                                        local icon = getSystemIcon_func and getSystemIcon_func(dirName, fs_getInfo, gfx_newImage) or nil
                                        table.insert(files, {name = dirName, isDir = true, fullPath = fullPath, sourceLabel = label, icon = icon})
                                        dirMap[dirName] = #files
                                        foundCount = foundCount + 1
                                    end
                                end
                            end
                        end
                    end
                    if log then log("Fallback Scan complete for " .. scanPath .. ". Added: " .. foundCount) end
                end
            end
            end
        end

        scanAndAdd("/mnt/mmc/ROMS/", "SD1")
        scanAndAdd("/mnt/sdcard/ROMS/", "SD2")

        -- Fallback Simulador
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

    -- Insert Favorites folder if there are favorites
    local hasFavorites = false
    if favoriteRoms then for k,v in pairs(favoriteRoms) do hasFavorites = true break end end
    
    if hasFavorites and not hideFavorites then
        table.insert(files, 1, {
            name = "Favoritos",
            isDir = true,
            fullPath = "@Favorites/",
            isFavorites = true
        })
    end

    -- After sorting, find the item to select
    if pathToSelect then
        if pathToSelect == "@Favorites/" then
            for i, item in ipairs(files) do
                if item.name == "Favoritos" then
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
        
        local baseMuosPath = ""
        local f = io.open("/mnt/mmc", "r")
        if f then
             f:close()
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
        local h = io.popen('ls -p "'..prefix..'" 2>/dev/null')
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

    local currentSystem = romPath:match("ROMS/([^/]+)/") or romPath:match("Simulador_SD/([^/]+)/")

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

    return files, selectedFilesCount, selectedIndex, allFiles
end

function M.logDeletion(path, json_encode, json_decode) -- Log deleted files for debugging/recovery
    local dataDir = love.filesystem.getSource() .. "/data"
    local logPath = dataDir .. "/deleted_roms.json"
    
    local logData = {}
    local f = io.open(logPath, "r")
    if f then
        local content = f:read("*a")
        f:close()
        if content and content ~= "" then
            logData = json_decode(content) or {}
        end
    end
    
    table.insert(logData, {
        date = os.date("%Y-%m-%d %H:%M:%S"),
        path = path
    })
    
    local f = io.open(logPath, "w")
    if f then
        f:write(json_encode(logData, {indent = true}))
        f:close()
    end
end

function M.saveViewCache(files, romPath, selectedIndex, isVirtualRoot, json_encode, love_filesystem_getSource, io_open) -- Save current view state to cache
    -- Crear una copia limpia de los archivos sin Userdata (imágenes) para el JSON
    
    -- Optimización: En modo Virtual Root (Juego Unico), guardar solo una ventana alrededor del cursor
    local startIdx = 1
    local endIdx = #files
    local savedIndex = selectedIndex

    if isVirtualRoot and #files > 100 then
        startIdx = math.max(1, selectedIndex - 25)
        endIdx = math.min(#files, selectedIndex + 25)
        savedIndex = selectedIndex - startIdx + 1
    end

    local cache = {
        romPath = romPath,
        selectedIndex = savedIndex,
        isVirtualRoot = isVirtualRoot,
        files = {}
    }
    
    for i = startIdx, endIdx do
        local item = files[i]
        local cleanItem = {}
        for k, v in pairs(item) do
            -- Excluir iconos y cualquier otro userdata
            if type(v) ~= "userdata" then
                cleanItem[k] = v
            end
        end
        table.insert(cache.files, cleanItem)
    end
    
    local dataDir = love_filesystem_getSource() .. "/data"
    local f = io_open(dataDir .. "/view_cache.json", "w")
    if f then
        f:write(json_encode(cache))
        f:close()
    end
end

function M.loadViewCache(json_decode, love_filesystem_getSource, io_open, getSystemIcon_func, getSystemContentIcon_func, fs_getInfo, gfx_newImage) -- Load cached view state
    local path = love_filesystem_getSource() .. "/data/view_cache.json"
    local f = io_open(path, "r")
    if not f then return nil, nil, nil end
    
    local content = f:read("*a")
    f:close()
    
    local cache = json_decode(content)
    if not cache or not cache.files then return nil, nil, nil end
    
    -- Restaurar iconos básicos
    for _, item in ipairs(cache.files) do
        if item.isDir and getSystemIcon_func then item.icon = getSystemIcon_func(item.name, fs_getInfo, gfx_newImage) end
    end
    
    return cache.files, cache.selectedIndex, cache.romPath, cache.isVirtualRoot
end

return M
