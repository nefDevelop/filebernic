local json = require "libs.dkjson"
local utils = require "utils"

-- Variables de configuración y estado
systemName = ""
romPath = ""
config = {
    scraperApi = "all", -- Opciones: "all", "libretro", "screenscraper", "thegamesdb"
    screenscraper_devid = "",
    screenscraper_password = "",
    thegamesdb_apikey = ""
}
scraperApi = config.scraperApi
secondaryPath = nil
muosArtPath = ""
muosTextPath = ""
muosPreviewPath = ""
files = {}
selectedIndex = 1
state = "LIST" -- LIST, POST_GAME, DELETE_MENU, OPTIONS_MENU, SCRAPER_VIEW, SCRAPING_IN_PROGRESS, SCRAPER_RESULTS, SEARCH
itemToDelete = nil
lastPlayedRom = ""
playedRoms = {}
iconFolder, iconRom, currentImage, currentScreenshot, currentYear, buttonIcons, currentSystemIcon, currentSystemContentIcon = nil, nil, nil, nil, nil, nil, nil, nil
currentDescription = ""
timer, delay, pendingLoad = 0, 0.05, false
inputCooldown = 0 -- Temporizador para evitar doble input
launching = false -- Estado de lanzamiento
launchTimer = 0
hideEmpty = false
markPlayed = true
pageSize = 13
viewMode = "LIST" -- "LIST" or "GRID"
gridCols = 4
launchMode = "Folder" -- "Folder" or "Juego Unico"
selectedFilesCount = 0
theme = nil
fontList, fontTitle, fontSmall, fontMedium, fontHuge = nil, nil, nil, nil, nil
menuOptions = {"Borrar"}
menuSelection = 1
menuTitle = ""
menuMessage = ""
showHelp = false
closingMenu = false
closingHelp = false
fastScrollTimer = 0
jumpLetter = ""
jumpPanelAnim = 0
helpData = {}
menuAnim = 0
saveFiles = {}
saveManagerSelection = 1
cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
cleanupCoroutine = nil
scraperResults = {}
scraperProgress = { current = 0, total = 0, currentName = "", successes = 0, failures = 0 }
scraperCoroutine = nil
scraperSelection = 1
searchQuery = ""
parentMenuData = nil
focusedItem = nil
allFiles = {}
-- Indexing
romIndex = nil
isIndexing = false
indexStateMessage = ""
indexCoroutine = nil
-- Virtual Keyboard
keyboardGrid = {
    {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
    {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "SPACE"},
    {"A", "S", "D", "F", "G", "H", "J", "K", "L", "BACK"},
    {"Z", "X", "C", "V", "B", "N", "M", ".", "-", "OK"}
}
keyboardRow = 1
keyboardCol = 1

validExtensions = {
    -- Nintendo
    gb=true, gbc=true, gba=true, nes=true, fds=true, unf=true, unif=true,
    snes=true, smc=true, sfc=true, fig=true, swc=true, bs=true, bml=true,
    n64=true, v64=true, z64=true, ndd=true, u1=true,
    nds=true, ids=true, dsi=true,
    vb=true, vboy=true, min=true,
    -- Sega
    md=true, gen=true, smd=true, bin=true, mdx=true,
    sms=true, gg=true, sg=true,
    cdi=true, gdi=true, elf=true,
    ["32x"]=true, ["68k"]=true, sgd=true, pco=true,
    -- Sony
    ps=true, pbp=true, chd=true, cue=true, iso=true, m3u=true, cbn=true, mdf=true, img=true,
    psp=true, cso=true, prx=true, psf=true, ecm=true, mds=true,
    -- Atari
    a26=true, a52=true, a78=true, cdf=true,
    lnx=true, lyx=true, o=true,
    jag=true, j64=true, cof=true, abs=true, prg=true,
    st=true, msa=true, dim=true, stx=true, ipf=true, ctr=true, m3u8=true, gz=true, acsi=true, ahd=true, vhd=true, scsi=true, shd=true, ide=true, gem=true,
    xfd=true, atr=true, dcm=true, cas=true, atx=true, car=true, com=true, xex=true,
    -- Arcade / Otros
    zip=true, ["7z"]=true, cmd=true, neo=true,
    dsk=true, sna=true, kcr=true, tap=true, cdt=true, voc=true, cpr=true, -- Amstrad
    hex=true, arduboy=true, -- Arduboy
    ws=true, wsc=true, pc2=true, pcv2=true, -- WonderSwan
    -- cbr=true, cbz=true, epub=true, pdf=true, -- Books
    exe=true, -- Cave Story / DOS / Ports
    chai=true, chailove=true, -- ChaiLove
    ch8=true, sc8=true, xo8=true, -- CHIP-8
    col=true, cv=true, ri=true, mx1=true, mx2=true, -- Coleco / MSX
    adf=true, adz=true, dms=true, fdi=true, hdf=true, hdz=true, lha=true, slave=true, nrg=true, rp9=true, wrp=true, -- Amiga
    d64=true, d71=true, d80=true, d81=true, d82=true, g64=true, g41=true, x64=true, t64=true, p00=true, crt=true, d6z=true, d7z=true, d8z=true, g6z=true, g4z=true, x6z=true, vfl=true, vsf=true, nib=true, nbz=true, d2m=true, d4m=true, -- Commodore
    dosz=true, bat=true, ins=true, ima=true, jrc=true, tc=true, conf=true, -- DOS
    doom=true, -- Doom
    sh=true, -- Ports
    chf=true, -- Channel F
    vec=true, -- Vectrex
    gal=true, -- Galaksija
    mgw=true, -- Game & Watch
    jar=true, -- J2ME
    cdg=true, -- Karaoke
    nx=true, -- Lowres NX
    lutro=true, lua=true, love=true, -- Lutro/Love
    int=true, -- Intellivision
    pce=true, sgx=true, toc=true, -- PC Engine
    d88=true, u88=true, -- PC-8800
    d98=true, ["98d"]=true, fdd=true, ["2hd"]=true, tfd=true, ["88d"]=true, hdm=true, xdf=true, dup=true, hdi=true, thd=true, nhd=true, hdd=true, hdn=true, -- PC98
    pak=true, -- OpenBOR / Quake
    p8=true, -- PICO-8
    ldb=true, easyrpg=true, -- RPG Maker
    ngp=true, ngc=true, ngpc=true, npc=true, -- Neo Geo Pocket
    scummvm=true, -- ScummVM
    dx1=true, ["2d"]=true, -- Sharp X1
    p=true, tzx=true, t81=true, -- ZX81
    rzx=true, scl=true, trd=true, -- ZX Spectrum
    tic=true, -- TIC-80
    ["8xp"]=true, ["8xk"]=true, ["8xg"]=true, -- TI-83
    uze=true, -- Uzebox
    vms=true, dci=true, -- VeMUlator
    v32=true, V32=true, -- Vircon32
    wasm=true, -- WASM-4
    sv=true, -- Supervision
    wl6=true, n3d=true, sod=true, sdm=true, wl1=true, pk3=true, -- Wolfenstein
    rar=true -- Archives
}

-- Configuración de diseño (Layout)
layout = {
    listY = 64,           -- Posición Y inicial de la lista
    rowHeight = 30,       -- Altura de cada fila
    selWidth = 300,       -- Ancho del selector
    selHeight = 28,       -- Alto del selector
    iconScale = 0.9,      -- Escala de los iconos de carpeta/rom
    boxartMaxW = 280,     -- Ancho máximo del boxart
    boxartMaxH = 360,     -- Alto máximo del boxart
    scrollbarX = 315,     -- Posición X de la barra de scroll
    scrollbarH = 360      -- Altura de la barra de scroll
}

-- Variables para el control de scroll
scrollTimer = 0
initialScrollDelay = 0.4
subsequentScrollDelay = 0.1
keyHeld = nil -- ('up' o 'down')
isVirtualRoot = false

local filesystem = require "filesystem"

-- Grupos de variantes de nombres de sistemas (para buscar iconos)
local systemVariants = {
    -- Nintendo
    {"GBA", "gba", "Game Boy Advance", "Nintendo - Game Boy Advance"},
    {"SNES", "snes", "sfc", "Super Nintendo", "Super Famicom", "Nintendo - Super Nintendo Entertainment System"},
    {"NES", "nes", "fc", "Nintendo Entertainment System", "Famicom", "Nintendo - Nintendo Entertainment System"},
    {"GB", "gb", "Game Boy", "Nintendo - Game Boy"},
    {"GBC", "gbc", "Game Boy Color", "Nintendo - Game Boy Color"},
    {"N64", "n64", "Nintendo 64", "Nintendo - Nintendo 64"},
    {"NDS", "nds", "Nintendo DS", "Nintendo - Nintendo DS"},
    {"VB", "vb", "Virtual Boy"},
    {"POKEMINI", "pokemini", "Pokemon Mini"},
    -- Sega
    {"MD", "md", "gen", "Genesis", "Mega Drive", "Sega - Mega Drive - Genesis"},
    {"SMS", "sms", "Master System", "Sega - Master System - Mark III"},
    {"GG", "gg", "Game Gear", "Sega - Game Gear"},
    {"SEGACD", "cd", "Sega CD", "Mega CD"},
    {"32X", "32x", "Sega 32X"},
    {"DC", "dc", "Dreamcast", "Sega - Dreamcast"},
    {"SATURN", "saturn", "Sega - Saturn"},
    -- Sony
    {"PS", "ps", "ps1", "psx", "PlayStation", "Sony - PlayStation"},
    {"PSP", "psp", "PlayStation Portable", "Sony - PlayStation Portable"},
    -- Arcade / SNK
    {"MAME", "mame", "arcade", "fbneo"},
    {"NEOGEO", "neogeo", "SNK - Neo Geo"},
    {"NGP", "ngp", "Neo Geo Pocket"},
    {"NGPC", "ngpc", "Neo Geo Pocket Color"},
    -- NEC
    {"PCE", "pce", "PC Engine", "TurboGrafx-16", "NEC - PC Engine - TurboGrafx 16"},
    {"PCECD", "pcecd", "PC Engine CD"},
    -- Atari
    {"ATARI2600", "a2600", "Atari 2600", "a26"},
    {"ATARI7800", "a7800", "Atari 7800", "a78"},
    {"LYNX", "lynx", "Atari Lynx"},
    -- Others
    {"WS", "ws", "WonderSwan"},
    {"WSC", "wsc", "WonderSwan Color"},
    {"PICO8", "pico8", "p8"},
    {"DOS", "dos", "MS-DOS"},
    {"AMIGA", "amiga", "Commodore Amiga"},
    {"C64", "c64", "Commodore 64"},
    {"MSX", "msx", "msx1", "msx2"},
    {"SCUMMVM", "scummvm"},
    {"OPENBOR", "openbor"}
}

function getSystemIcon(sysName)
    local variants = {sysName}
    local lowerName = sysName:lower()
    
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
            break
        end
    end

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. ".png"
        if love.filesystem.getInfo(path) then
            return love.graphics.newImage(path)
        end
    end
    return nil
end

local systemContentIconCache = {}

function getSystemContentIcon(sysName)
    if not sysName then return nil end
    if systemContentIconCache[sysName] then return systemContentIconCache[sysName] end

    local variants = {sysName}
    local lowerName = sysName:lower()
    
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
            break
        end
    end

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. "-content.png"
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            systemContentIconCache[sysName] = img
            return img
        end
    end
    return nil
end

function performBackgroundIndexing()
    isIndexing = true
    indexStateMessage = "Iniciando escaneo..."

    indexCoroutine = coroutine.create(function()
        local newIndex = {}
        local fileMap = {} -- Key: stem -> index in newIndex
        local romDirs = {}

        local function scanRoot(rootPath)
            if not io.open(rootPath, "r") then return end
            table.insert(romDirs, rootPath)
            
            indexStateMessage = "Escaneando: " .. rootPath
            coroutine.yield()

            local h = io.popen('find "'..rootPath..'" -type f')
            if h then
                local count = 0
                for fLine in h:lines() do
                    count = count + 1
                    if count % 100 == 0 then coroutine.yield() end -- Ceder control para no congelar

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
                                table.insert(item.versions, {
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
                                table.insert(newIndex, newItem)
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
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanRoot(cwd .. "/../Simulador_SD/")
        end

        indexStateMessage = "Ordenando y guardando..."
        coroutine.yield()

        table.sort(newIndex, function(a, b) return a.name:lower() < b.name:lower() end)
        romIndex = newIndex

        -- Guardar índice en archivo
        local dataDir = love.filesystem.getSource() .. "/data"
        os.execute("mkdir -p " .. dataDir)
        local f = io.open(dataDir .. "/rom_index.json", "w")
        if f then
            f:write(json.encode(romIndex))
            f:close()
        end

        -- Guardar timestamps de los directorios
        local timestamps = {}
        for _, dir in ipairs(romDirs) do
            local h = io.popen('stat -c %Y "'..dir..'"')
            if h then timestamps[dir] = h:read("*a"):gsub("%s+", "") h:close() end
        end
        local f_ts = io.open(dataDir .. "/rom_timestamps.json", "w")
        if f_ts then
            f_ts:write(json.encode(timestamps))
            f_ts:close()
        end

        isIndexing = false
        indexStateMessage = ""
        
        -- Si estamos en la vista de raíz virtual y modo juego único, refrescar
        if isVirtualRoot and launchMode == "Juego Unico" then
             createMergedVirtualRoot()
        end
    end)
end

function removeFromIndex(path)
    if not romIndex then return end
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
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/rom_index.json", "w")
    if f then
        f:write(json.encode(romIndex))
        f:close()
    end
end

function jumpToNextLetter()
    if #files == 0 then return end
    local current = files[selectedIndex].name:sub(1,1):upper()
    for i = selectedIndex + 1, #files do
        local c = files[i].name:sub(1,1):upper()
        if c ~= current then
            selectedIndex = i
            jumpLetter = c
            return
        end
    end
    selectedIndex = #files
    jumpLetter = files[selectedIndex].name:sub(1,1):upper()
end

function jumpToPrevLetter()
    if #files == 0 then return end
    local current = files[selectedIndex].name:sub(1,1):upper()
    local prevLetterIdx = nil
    for i = selectedIndex - 1, 1, -1 do
        local c = files[i].name:sub(1,1):upper()
        if c ~= current then
            prevLetterIdx = i
            break
        end
    end
    
    if prevLetterIdx then
        local targetChar = files[prevLetterIdx].name:sub(1,1):upper()
        for i = prevLetterIdx - 1, 1, -1 do
            local c = files[i].name:sub(1,1):upper()
            if c ~= targetChar then
                selectedIndex = i + 1
                jumpLetter = targetChar
                return
            end
        end
        selectedIndex = 1
    else
        selectedIndex = 1
    end
    jumpLetter = files[selectedIndex].name:sub(1,1):upper()
end

function createMergedVirtualRoot()
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
                            if not hideEmpty or filesystem.hasRoms(scanPath .. line, validExtensions) then
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
end

function filterFiles()
    files = {}
    for _, item in ipairs(allFiles) do
        if item.name:lower():find(searchQuery:lower(), 1, true) then
            table.insert(files, item)
        end
    end
    selectedIndex = 1
end

function loadConfig()
    local configPath = love.filesystem.getSource() .. "/data/config.json"
    local f = io.open(configPath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local loaded = json.decode(content)
        if loaded then
            for k, v in pairs(loaded) do config[k] = v end
        end
    else
        f = io.open(configPath, "w")
        if f then
            f:write(json.encode(config))
            f:close()
        end
    end
    scraperApi = config.scraperApi
end

local scraper = require "scraper"

function findSaveFiles(item)
    saveFiles = {}
    saveManagerSelection = 1
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
end

function deleteGameMedia(romPath)
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

function performCleanupScan()
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = true, progress = 0, cursor = {col=1, row=1}, confirming = false, currentFile = "" }
    
    cleanupCoroutine = coroutine.create(function()
        local romNames = {} -- Para huérfanos: nombre base -> true
        local romsByStem = {} -- Para duplicados: nombre base -> lista de archivos
        local romsBySystem = {} -- Para imágenes huérfanas: system -> stem -> true

        local totalFiles = 0
        local scannedFiles = 0
        local find_exclude_str = [[-not -path "*.svn*" -not -name "*.png" -not -name "*.jpg" -not -name "*.jpeg" -not -name "*.txt" -not -name "*.pdf" -not -name "*.db"]]

        local function countFiles(path)
            if not io.open(path, "r") then return end
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
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            countFiles(cwd .. "/../Simulador_SD/")
        end
        coroutine.yield()

        local function scanAndRegister(path, locationLabel)
            if not io.open(path, "r") then return end
            local cmd = 'find "'..path..'" -type f ' .. find_exclude_str
            local h = io.popen(cmd)
            if h then
                for line in h:lines() do
                    scannedFiles = scannedFiles + 1
                    cleanupData.progress = totalFiles > 0 and (scannedFiles / totalFiles * 0.8) or 0 -- Escaneo de ROMs es el 80% del trabajo

                    if scannedFiles % 20 == 0 then
                        cleanupData.currentFile = line:match("([^/]+)$")
                        coroutine.yield()
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
                                
                                table.insert(romsByStem[stem], {
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
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            scanAndRegister(cwd .. "/../Simulador_SD/", "SIM")
        end

        -- 2. Buscar Save States Huérfanos
        cleanupData.currentFile = "Buscando save states..."
        cleanupData.progress = 0.85
        coroutine.yield()
        local savePaths = {"/mnt/mmc/MUOS/save", "/mnt/sdcard/MUOS/save"}
        for _, path in ipairs(savePaths) do
            local h = io.popen('find "'..path..'" -name "*.state*"')
            if h then
                for line in h:lines() do
                    local name = line:match("([^/]+)$")
                    local base = name:gsub("%.state.*$", "")
                    if not romNames[base] then
                        table.insert(cleanupData.orphans, {
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
        coroutine.yield()

        -- 3. Procesar Duplicados
        cleanupData.currentFile = "Analizando duplicados..."
        coroutine.yield()
        for stem, list in pairs(romsByStem) do
            if #list > 1 then
                for _, item in ipairs(list) do
                    table.insert(cleanupData.duplicates, item)
                end
            end
        end

        table.sort(cleanupData.duplicates, function(a, b)
            if a.name == b.name then
                if a.system == b.system then
                    return a.location < b.location
                end
                return a.system < b.system
            end
            return a.name < b.name
        end)

        cleanupData.progress = 0.95
        coroutine.yield()

        -- 4. Buscar Imágenes Huérfanas
        cleanupData.currentFile = "Buscando imágenes huérfanas..."
        coroutine.yield()
        local catalogueBase = "/mnt/mmc/MUOS/info/catalogue/"
        if not io.open("/mnt/mmc", "r") then
            local cwd = love.filesystem.getSource()
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
                        table.insert(cleanupData.orphanedImages, {
                            name = filename,
                            fullPath = line,
                            system = system,
                            type = "Image"
                        })
                    end
                end
                h:close()
            end
            coroutine.yield()
        end

        cleanupData.progress = 1.0
        cleanupData.scanning = false
        cleanupData.scanned = true
    end)
end

function saveScrapeResult(item, result)
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

function startScraping()
    local item = files[selectedIndex]
    if not item then return end
    
    log("Starting interactive scrape for: " .. item.name)
    
    state = "SCRAPING_IN_PROGRESS"
    love.graphics.present() -- Forzar dibujado
    
    -- Limpiar temporales
    os.execute("rm -f /tmp/scraper_*.png")
    
    scraperResults = scraper.getScrapeResults(item, config, log, systemName)
    scraperSelection = 1
    state = "SCRAPER_RESULTS"
end

function performBatchScrape(items)
    state = "BATCH_SCRAPING"
    scraperProgress = { current = 0, total = #items, currentName = "", successes = 0, failures = 0 }
    
    -- Limpiar temporales
    os.execute("rm -f /tmp/scraper_*.png")
    
    scraperCoroutine = coroutine.create(function()
        for i, item in ipairs(items) do
            scraperProgress.current = i
            scraperProgress.currentName = item.name
            coroutine.yield()
            
            local results = scraper.getScrapeResults(item, config, log, systemName)
            if results and #results > 0 and not results[1].error then
                saveScrapeResult(item, results[1])
                scraperProgress.successes = scraperProgress.successes + 1
            else
                scraperProgress.failures = scraperProgress.failures + 1
            end
        end
        state = "LIST"
        files, selectedFilesCount, selectedIndex, allFiles = filesystem.refreshFiles(updateSystemPaths, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, loadPreview)
    end)
end

function saveSelectedArt()
    local result = scraperResults[scraperSelection]
    local item = files[selectedIndex]
    saveScrapeResult(item, result)
    
    state = "LIST"
    loadPreview()
end

function loadPreview()
    currentImage = nil
    currentScreenshot = nil
    currentYear = nil
    currentDescription = ""
    
    local item = focusedItem
    if not item then
        if #files == 0 then return end
        item = files[selectedIndex]
    end
    
    if not item or item.isDir then return end
    
    -- Asegurar que el sistema detectado corresponde al archivo seleccionado (para lista mixta)
    systemName, muosArtPath, muosTextPath, muosPreviewPath = filesystem.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
    
    local baseName = item.name:gsub("%..-$", "")
    
    -- Boxart
    local imgFile = muosArtPath .. baseName .. ".png"
    local f = io.open(imgFile, "rb")
    if f then
        local data = f:read("*a")
        f:close()
        if data then
            local fileData = love.filesystem.newFileData(data, "boxart.png")
            currentImage = love.graphics.newImage(fileData)
        end
    end
    
    -- Screenshot
    local scrFile = muosPreviewPath .. baseName .. ".png"
    local fScr = io.open(scrFile, "rb")
    if fScr then
        local data = fScr:read("*a")
        fScr:close()
        if data then
            local fileData = love.filesystem.newFileData(data, "preview.png")
            currentScreenshot = love.graphics.newImage(fileData)
        end
    end
    
    -- Description
    local txtFile = muosTextPath .. baseName .. ".txt"
    local fTxt = io.open(txtFile, "r")
    if fTxt then
        currentDescription = fTxt:read("*all")
        fTxt:close()
    end
    
    -- Year
    local yearFile = muosTextPath .. baseName .. ".year"
    local fYear = io.open(yearFile, "r")
    if fYear then
        currentYear = fYear:read("*all")
        fYear:close()
    end
end

function saveHistory()
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/played_roms.txt", "w")
    if f then
        for path, _ in pairs(playedRoms) do
            f:write(path .. "\n")
        end
        f:close()
    end
end

function getTargetSDPath(currentPath)
    if currentPath:find("/mnt/mmc") then
        return currentPath:gsub("/mnt/mmc", "/mnt/sdcard"), "SD2"
    elseif currentPath:find("/mnt/sdcard") then
        return currentPath:gsub("/mnt/sdcard", "/mnt/mmc"), "SD1"
    end
    return nil, nil
end

function resolveSecondary(path)
    local p2 = nil
    if path:find("/mnt/mmc") then
        p2 = path:gsub("/mnt/mmc", "/mnt/sdcard")
    elseif path:find("/mnt/sdcard") then
        p2 = path:gsub("/mnt/sdcard", "/mnt/mmc")
    end
    
    if p2 and os.execute('test -d "' .. p2 .. '"') then return p2 end
    return nil
end

function saveLastPlayed(path)
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/last_played.txt", "w")
    if f then
        f:write(path)
        f:close()
    end
end

function addToHistory(path)
    if playedRoms[path] then return end
    playedRoms[path] = true
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/played_roms.txt", "a")
    if f then
        f:write(path .. "\n")
        f:close()
    end
end

function log(message)
    local logPath = love.filesystem.getSource() .. "/data/log/filebernic.log"
    print("[CONSOLE] " .. message)
    local f = io.open(logPath, "a")
    if f then
        f:write("[LUA DEBUG] " .. os.date() .. ": " .. message .. "\n")
        f:close()
    end
end

function saveAppState()
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/app_state.json", "w")
    if f then
        -- Normalizar ruta para guardar (convertir a virtual ROMS/...)
        local savedPath = romPath
        if savedPath:find("/mnt/mmc/ROMS/") then
            savedPath = savedPath:gsub("/mnt/mmc/ROMS/", "ROMS/")
        elseif savedPath:find("/mnt/sdcard/ROMS/") then
            savedPath = savedPath:gsub("/mnt/sdcard/ROMS/", "ROMS/")
        elseif savedPath:find("Simulador_SD") then
            savedPath = savedPath:gsub(".*Simulador_SD/", "ROMS/")
        end

        local stateToSave = {
            romPath = savedPath,
            selectedIndex = selectedIndex,
            hideEmpty = hideEmpty,
            markPlayed = markPlayed,
            viewMode = viewMode,
            launchMode = launchMode
        }
        f:write(json.encode(stateToSave))
        f:close()
    end
end

function love.errorhandler(msg)
    local err = tostring(msg)
    local trace = debug.traceback()
    
    -- Log to file
    local logPath = love.filesystem.getSource() .. "/data/log/filebernic.log"
    local f = io.open(logPath, "a")
    if f then
        f:write("\n========================================\n")
        f:write("[FATAL ERROR] " .. os.date() .. "\n")
        f:write("Error: " .. err .. "\n")
        f:write("Traceback:\n" .. trace .. "\n")
        f:write("========================================\n")
        f:close()
    end

    -- Standard LÖVE error handler logic
    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.graphics.isCreated() or not love.window.isOpen() then
        local success, status = pcall(love.window.setMode, 800, 600)
        if not success or not status then
            return
        end
    end

    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
    end

    love.graphics.reset()
    local font = love.graphics.setNewFont(14)
    love.graphics.setColor(1, 1, 1, 1)

    local function draw()
        love.graphics.clear(89/255, 157/255, 220/255)
        love.graphics.printf(err, 70, 70, love.graphics.getWidth() - 140)
        love.graphics.printf(trace, 70, 70 + font:getHeight() + 10, love.graphics.getWidth() - 140)
        love.graphics.present()
    end

    return function()
        love.event.pump()
        for e, a, b, c in love.event.poll() do
            if e == "quit" or (e == "keypressed" and a == "escape") then
                return 1
            end
        end
        draw()
        if love.timer then love.timer.sleep(0.1) end
    end
end

function startIndexingProcess()
    local dataDir = love.filesystem.getSource() .. "/data"
    local indexPath = dataDir .. "/rom_index.json"
    local tsPath = dataDir .. "/rom_timestamps.json"

    local indexFile = io.open(indexPath, "r")
    local tsFile = io.open(tsPath, "r")

    if not indexFile or not tsFile then
        if indexFile then indexFile:close() end
        if tsFile then tsFile:close() end
        log("No index found. Starting background indexing.")
        performBackgroundIndexing()
        return
    end

    -- Si los archivos existen, comprobar timestamps
    local needsReindex = false
    local tsContent = tsFile:read("*a")
    tsFile:close()
    local savedTimestamps = json.decode(tsContent)

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
        performBackgroundIndexing()
    else
        log("Index is up to date. Loading from file.")
        local indexContent = indexFile:read("*a")
        indexFile:close()
        romIndex = json.decode(indexContent)
    end
end

function love.quit()
    saveAppState()
    
    -- Log content of art folders on exit
    if muosArtPath and muosArtPath ~= "" then
        log("Listing Boxart folder content: " .. muosArtPath)
        local h = io.popen('ls -1 "'..muosArtPath..'"')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
    
    if muosPreviewPath and muosPreviewPath ~= "" then
        log("Listing Preview folder content: " .. muosPreviewPath)
        local h = io.popen('ls -1 "'..muosPreviewPath..'"')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
end

function love.load(arg)
    -- Create data directories
    os.execute("mkdir -p " .. love.filesystem.getSource() .. "/data/log")

    -- Handle screen resolution from launch script
    if arg[1] then
        local res = arg[1]
        local parts = utils.split(res, "x")
        local w, h = tonumber(parts[1]), tonumber(parts[2])
        if w and h then
            love.window.setMode(w, h)
        end
    end
    
    love.keyboard.setKeyRepeat(false) -- Desactivado para control manual
    
    local baseMuosPath = ""
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
        -- Running on a real device
        if arg and arg[4] then systemName = arg[4] end
        baseMuosPath = "/mnt/mmc/MUOS/info/catalogue/"
    else
        -- Running in simulation on Fedora
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local simPath = cwd .. "/../Simulador_SD/"
        baseMuosPath = simPath .. "MUOS/info/catalogue/"
    end
    
    muosArtPath = baseMuosPath .. systemName .. "/box/"
    muosTextPath = baseMuosPath .. systemName .. "/text/"
    muosPreviewPath = baseMuosPath .. systemName .. "/preview/"
    
    iconFolder = love.graphics.newImage("assets/folder.png")
    iconRom = love.graphics.newImage("assets/roms.png")
    
    buttonIcons = {
        a = love.graphics.newImage("assets/button/gamepad/small/a.png"),
        b = love.graphics.newImage("assets/button/gamepad/small/b.png"),
        y = love.graphics.newImage("assets/button/gamepad/small/y.png"),
        x = love.graphics.newImage("assets/button/gamepad/small/x.png"),
        select = love.graphics.newImage("assets/button/gamepad/small/select.png"),
        start = love.graphics.newImage("assets/button/gamepad/small/start.png"),
        l1 = love.graphics.newImage("assets/button/gamepad/small/l1.png"),
        r1 = love.graphics.newImage("assets/button/gamepad/small/r1.png")
    }

    -- Load theme and fonts
    theme = require "theme"
    fontList = theme.fonts.list
    fontTitle = theme.fonts.title
    fontSmall = theme.fonts.small
    fontMedium = theme.fonts.medium
    fontHuge = theme.fonts.huge

    -- Define Help Data
    helpData = {
        LIST = {
            {icon=buttonIcons.a, text="Entrar/Jugar"},
            {icon=buttonIcons.b, text="Subir/Atrás"},
            {icon=buttonIcons.y, text="Opciones"},
            {icon=buttonIcons.x, text="Seleccionar"},
            {icon=buttonIcons.start, text="Config"},
            {icon=buttonIcons.select, text="Salir"},
            {icon=buttonIcons.l1, text="Buscar"},
            {icon=buttonIcons.r1, text="Ayuda"}
        },
        CLEANUP_MENU = {
            {icon=buttonIcons.l1, text="Cambiar Columna"},
            {icon=buttonIcons.a, text="Acción"},
            {icon=buttonIcons.b, text="Salir"},
            {icon=buttonIcons.r1, text="Ayuda"}
        },
        INFO_VIEW = {
            {icon=buttonIcons.b, text="Volver"},
            {icon=buttonIcons.r1, text="Ayuda"}
        },
        SCRAPER_VIEW = {
            {icon=buttonIcons.a, text="Buscar"},
            {icon=buttonIcons.y, text="Opciones"},
            {icon=buttonIcons.b, text="Volver"},
            {icon=buttonIcons.r1, text="Ayuda"}
        },
        OPTIONS_MENU = {
            {icon=buttonIcons.a, text="Seleccionar"},
            {icon=buttonIcons.b, text="Cerrar"},
            {icon=buttonIcons.r1, text="Ayuda"}
        },
        DEFAULT = {
            {icon=buttonIcons.a, text="Aceptar"},
            {icon=buttonIcons.b, text="Cancelar"},
            {icon=buttonIcons.r1, text="Ayuda"}
        }
    }

    -- Cargar configuración global (API keys, etc)
    loadConfig()

    -- Cargar configuración guardada
    local f = io.open(love.filesystem.getSource() .. "/data/app_state.json", "r")
    if f then
        local content = f:read("*all")
        f:close()
        local loadedState = json.decode(content)
        if loadedState then
            if loadedState.hideEmpty ~= nil then hideEmpty = loadedState.hideEmpty end
            if loadedState.markPlayed ~= nil then markPlayed = loadedState.markPlayed end
            if loadedState.viewMode then viewMode = loadedState.viewMode end
            if loadedState.launchMode then launchMode = loadedState.launchMode end
            if launchMode == "Juego Unico" then
                romPath = "" -- Forzar raíz virtual en Modo Único
            elseif loadedState.romPath then 
                local p = loadedState.romPath
                -- Restaurar ruta real desde virtual (ROMS/...)
                if p:match("^ROMS/") then
                    local suffix = p:gsub("^ROMS/", "")
                    
                    -- Detectar entorno (Dispositivo vs Simulador)
                    local fCheck = io.open("/mnt/mmc", "r")
                    if fCheck then
                        fCheck:close()
                        -- Estamos en dispositivo (muOS)
                        local pathSD1 = "/mnt/mmc/ROMS/" .. suffix
                        -- Verificar si existe en SD1, sino asumir SD2
                        local h = io.popen('ls -d "'..pathSD1..'" 2>/dev/null')
                        local res = h:read("*a")
                        h:close()
                        romPath = (res and res ~= "") and pathSD1 or ("/mnt/sdcard/ROMS/" .. suffix)
                    else
                        -- Estamos en simulador
                        local cwd = love.filesystem.getSource()
                        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                        romPath = cwd .. "/../Simulador_SD/" .. suffix
                    end
                else
                    romPath = p
                end
            end
            if loadedState.selectedIndex then selectedIndex = loadedState.selectedIndex end
        end
    end

    -- Cargar historial de juegos jugados (this populates playedRoms, keep it)
    local f = io.open(love.filesystem.getSource() .. "/data/played_roms.txt", "r")
    if f then
        for line in f:lines() do
            playedRoms[line] = true
        end
        f:close()
    end

    -- Load last played ROM (separate from app_state)
    local f = io.open(love.filesystem.getSource() .. "/data/last_played.txt", "r")
    if f then
        lastPlayedRom = f:read("*all")
        f:close()
    end

    -- Determine initial view: app_state.json -> lastPlayedRom -> createMergedVirtualRoot
    if romPath == "" and launchMode ~= "Juego Unico" then -- Solo auto-navegar a carpeta en Modo Carpeta
        if lastPlayedRom and lastPlayedRom ~= "" then
            playedRoms[lastPlayedRom] = true -- Ensure the last played is marked
            romPath = lastPlayedRom:match("(.*/)")
            -- selectedIndex will be updated after refreshFiles
        end
    end

    if romPath ~= "" then
        files, selectedFilesCount, selectedIndex, allFiles = filesystem.refreshFiles(updateSystemPaths, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, loadPreview)
        -- If romPath was from lastPlayedRom, try to find and set selectedIndex
        if lastPlayedRom and lastPlayedRom ~= "" and romPath == lastPlayedRom:match("(.*/)") then
            for i, item in ipairs(files) do
                if (romPath .. item.name) == lastPlayedRom then
                    selectedIndex = i
                    break
                end
            end
        end
    else
        createMergedVirtualRoot()
        -- En Modo Único, buscar y seleccionar el último juego en la lista global
        if lastPlayedRom and lastPlayedRom ~= "" then
             local found = false
             for i, item in ipairs(files) do
                 if item.fullPath == lastPlayedRom then
                     selectedIndex = i
                     found = true
                 elseif item.versions then
                     for _, v in ipairs(item.versions) do
                         if v.fullPath == lastPlayedRom then
                             selectedIndex = i
                             found = true
                             break
                         end
                     end
                 end
                 if found then break end
             end
             loadPreview()
        end
    end

    -- Load modules
    love.draw = require "drawing"
    love.update = require "update"
    local input = require "input"
    love.keypressed = input.keypressed
    love.gamepadpressed = input.gamepadpressed
    love.joystickpressed = input.joystickpressed
    love.textinput = input.textinput
end

love.load_final = love.load
love.load = function(arg)
    love.load_final(arg)
    startIndexingProcess()
end