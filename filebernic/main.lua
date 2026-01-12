local json = require "libs.dkjson"
-- Utility function to split a string by a delimiter
function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

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
fontList, fontTitle, fontSmall, fontMedium = nil, nil, nil, nil
menuOptions = {"Borrar"}
menuSelection = 1
menuTitle = ""
menuMessage = ""
showHelp = false
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
allFiles = {}
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

local function hasRoms(path)
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

function createMergedVirtualRoot()
    files = {}
    isVirtualRoot = true
    romPath = "" -- Not a real path in this view
    secondaryPath = nil
    selectedIndex = 1

    local dirMap = {} -- Mapa para rastrear directorios y fusionar etiquetas

    local function scanAndAdd(scanPath, label)
        local f = io.open(scanPath, "r")
        if not f then return end
        f:close()

        local handle = io.popen('ls -p "'..scanPath..'"')
        if handle then
            for line in handle:lines() do
                if line:sub(-1) == "/" then
                    local dirName = line:sub(1, -2)
                    -- Excluir carpetas que no son de roms
                    if dirName ~= "BIOS" and dirName ~= "Saves" then
                        if not hideEmpty or hasRoms(scanPath .. line) then
                            if dirMap[dirName] then
                                files[dirMap[dirName]].sourceLabel = "SD½"
                                files[dirMap[dirName]].secondaryPath = scanPath .. line
                            else
                                table.insert(files, {name = dirName, isDir = true, fullPath = scanPath .. line, sourceLabel = label})
                                dirMap[dirName] = #files
                            end
                        end
                    end
                end
            end
            handle:close()
        end
    end

    -- Scan real device paths
    scanAndAdd("/mnt/mmc/ROMS/", "SD1")
    scanAndAdd("/mnt/sdcard/ROMS/", "SD2")

    -- If no device paths found, use simulation
    if #files == 0 then
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local simPath = cwd .. "/../Simulador_SD/"
        -- Check if Simulador_SD exists and add it
        local h = io.popen('ls -d "'..simPath..'"')
        if h and h:read("*a") ~= "" then
            table.insert(files, {name = "Simulador_SD", isDir = true, fullPath = simPath, sourceLabel = "SIM"})
        end
        scanAndAdd(simPath, "SIM")
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

function updateSystemPaths()
    local detectedSystem = romPath:match("ROMS/([^/]+)/") or romPath:match("Simulador_SD/([^/]+)/")
    
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
        currentSystemIcon = nil
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. ".png"
            if love.filesystem.getInfo(path) then
                currentSystemIcon = love.graphics.newImage(path)
                log("System icon found: " .. path)
                break
            end
        end
        if not currentSystemIcon then
            log("System icon NOT found")
        end

        -- Cargar icono de contenido (ROM) (probar todas las variantes)
        currentSystemContentIcon = nil
        for _, v in ipairs(variants) do
            local path = "assets/systems/" .. v .. "-content.png"
            if love.filesystem.getInfo(path) then
                currentSystemContentIcon = love.graphics.newImage(path)
                log("Content icon found: " .. path)
                break
            end
        end
        if not currentSystemContentIcon then
            log("Content icon NOT found")
        end
    end
end

function refreshFiles()
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
                    if isDirectory and hideEmpty and not hasRoms(fullPath) then
                        skip = true
                    end

                    if not skip then
                        local key = cleanName
                        local stem = cleanName
                        if not isDirectory and launchMode == "Juego Unico" then
                            stem = cleanName:gsub("%.[^%.]+$", "")
                            key = stem
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
                                    ext = ext
                                })
                                item.sourceLabel = "Multi"
                            else
                                files[idx].sourceLabel = "SD½"
                                files[idx].secondaryPath = fullPath
                            end
                        else
                            local newItem = {name = (not isDirectory and launchMode == "Juego Unico") and stem or cleanName, isDir = isDirectory, fullPath = fullPath, sourceLabel = label}
                            if not isDirectory and launchMode == "Juego Unico" then
                                newItem.versions = {{name = cleanName, fullPath = fullPath, sourceLabel = label, ext = ext}}
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
    if selectedIndex > #files then selectedIndex = math.max(1, #files) end
    
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

-- Helper para codificar URL
local function urlencode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w %-%_%.%~])",
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
    end
    return str
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

function updateSystemForFile(item)
    local currentPath = item.fullPath or (romPath .. item.name)
    local detectedSystem = currentPath:match("ROMS/([^/]+)/") or currentPath:match("Simulador_SD/([^/]+)/")
    
    if detectedSystem and detectedSystem ~= systemName then
        systemName = detectedSystem
        
        log("System detected changed to: " .. systemName)
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
        return true
    end
    return false
end

function getScrapeResults(item)
    local results = {}
    updateSystemForFile(item)
    
    local cleanName = item.name:gsub("%..-$", "") -- Quitar extensión
    local encodedName = urlencode(cleanName)

    -- 1. ScreenScraper
    if scraperApi == "all" or scraperApi == "screenscraper" then
    -- Configuración API ScreenScraper
    local devid = config.screenscraper_devid
    local devpassword = config.screenscraper_password
    local softname = "FileBernic"
    
    local skipSS = false
    if devid == "" or devpassword == "" then
        if scraperApi == "screenscraper" then
            table.insert(results, {error = true, text = "Error: Faltan credenciales SS"})
        end
        skipSS = true
    end

    if not skipSS then
    -- Construir URL para buscar por nombre de archivo (romNom)
    local url = "https://www.screenscraper.fr/api2/jeuInfos.php?output=json&romNom=" .. encodedName
    if devid ~= "" then
        url = url .. "&devid=" .. devid .. "&devpassword=" .. devpassword .. "&softname=" .. softname
    else
        -- Intento sin credenciales (puede requerir softname registrado)
        url = url .. "&softname=" .. softname
    end

    log("Scraping Request URL: " .. url)

    -- Ejecutar curl
    local handle = io.popen("curl -s -L --max-time 10 '" .. url .. "'")
    local response = handle:read("*a")
    handle:close()
    log("Scraping Response: " .. (response or "nil"))

    if response and response ~= "" then
        if response:sub(1, 1) ~= "{" then
            table.insert(results, {
                error = true,
                text = "API Error: " .. response
            })
        else
            local data, pos, err = json.decode(response)
            if data and data.response and data.response.jeu then
            local game = data.response.jeu
            -- ScreenScraper a veces devuelve un array o un objeto único
            -- Aquí asumimos respuesta simple por nombre exacto o procesamos el primero
            
            -- Buscar imagen (boxart 2d o 3d)
            local imageUrl = nil
            local screenUrl = nil
            local region = "Mundo"
            local description = "Sin descripción."
            local year = nil
            
            if game.synopsis then
                if type(game.synopsis) == "table" and #game.synopsis > 0 then
                    for _, s in ipairs(game.synopsis) do
                        if s.langue == "es" then description = s.text break end
                        if s.langue == "en" and description == "Sin descripción." then description = s.text end
                    end
                elseif type(game.synopsis) == "string" then
                    description = game.synopsis
                elseif type(game.synopsis) == "table" and game.synopsis.text then
                    description = game.synopsis.text
                end
            end
            
            if game.dates then
                for _, d in ipairs(game.dates) do
                    if d.text then
                        year = d.text:match("^(%d%d%d%d)")
                        if year then break end
                    end
                end
            end
            
            if game.medias and game.medias.media then
                local medias = game.medias.media
                if not medias[1] then medias = {medias} end
                for _, media in ipairs(medias) do
                    if media.type == "box-2d" or media.type == "box-3d" then
                        imageUrl = media.url
                        region = media.region or region
                    elseif media.type == "ss" then
                        screenUrl = media.url
                    end
                end
            end

            if imageUrl then
                -- Descargar imagen temporal
                local tempImgPath = "/tmp/scraper_temp.png"
                os.execute("curl -s -L '" .. imageUrl .. "' -o " .. tempImgPath)
                
                local tempScreenPath = nil
                local screenImg = nil
                if screenUrl then
                    tempScreenPath = "/tmp/scraper_temp_screen.png"
                    os.execute("curl -s -L '" .. screenUrl .. "' -o " .. tempScreenPath)
                    if love.filesystem.getInfo(tempScreenPath) or io.open(tempScreenPath, "r") then
                         local sData = love.image.newImageData(tempScreenPath)
                         screenImg = love.graphics.newImage(sData)
                    end
                end

                -- Cargar en LÖVE
                if love.filesystem.getInfo(tempImgPath) or io.open(tempImgPath, "r") then
                    local imgData = love.image.newImageData(tempImgPath)
                    local img = love.graphics.newImage(imgData)
                    table.insert(results, {
                        image = img,
                        screenshot = screenImg,
                        tempScreenPath = tempScreenPath,
                        description = description,
                        year = year,
                        region = region,
                        tempPath = tempImgPath,
                        source = "ScreenScraper"
                    })
                end
            end
            end
        end
    end
    end
    end

    -- 2. TheGamesDB
    if scraperApi == "all" or scraperApi == "thegamesdb" then
        -- Configuración API TheGamesDB
        local apikey = config.thegamesdb_apikey
        
        local skipTGDB = false
        if apikey == "" then
            if scraperApi == "thegamesdb" then
                table.insert(results, {error = true, text = "Error: Falta API Key TGDB"})
            end
            skipTGDB = true
        end

        if not skipTGDB then
        local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=" .. apikey .. "&name=" .. encodedName .. "&fields=overview,release_date&include=boxart,screenshot"
        log("TGDB Request: " .. url)

        local handle = io.popen("curl -s -L --max-time 10 '" .. url .. "'")
        local response = handle:read("*a")
        handle:close()
        log("TGDB Response: " .. (response or "nil"))

        if response and response:sub(1, 1) == "{" then
            local data = json.decode(response)
            if data and data.data and data.data.games then
                for _, game in ipairs(data.data.games) do
                    local gameId = tostring(game.id)
                    -- Buscar imagen en los datos incluidos (sideloaded)
                    if data.include and data.include.boxart and data.include.boxart.data and data.include.boxart.data[gameId] then
                        for _, art in ipairs(data.include.boxart.data[gameId]) do
                            if art.side == "front" then
                                local imageUrl = "https://cdn.thegamesdb.net/images/original/" .. art.filename
                                local tempImgPath = "/tmp/scraper_tgdb_" .. gameId .. ".png"
                                os.execute("curl -s -L '" .. imageUrl .. "' -o " .. tempImgPath)
                                
                                local year = nil
                                if game.release_date then
                                    year = game.release_date:match("^(%d%d%d%d)")
                                end
                                
                                local screenImg = nil
                                local tempScreenPath = nil
                                if data.include.screenshot and data.include.screenshot.data and data.include.screenshot.data[gameId] then
                                    local scr = data.include.screenshot.data[gameId][1]
                                    if scr then
                                        local screenUrl = "https://cdn.thegamesdb.net/images/original/" .. scr.filename
                                        tempScreenPath = "/tmp/scraper_tgdb_scr_" .. gameId .. ".png"
                                        os.execute("curl -s -L '" .. screenUrl .. "' -o " .. tempScreenPath)
                                        if love.filesystem.getInfo(tempScreenPath) or io.open(tempScreenPath, "r") then
                                            screenImg = love.graphics.newImage(tempScreenPath)
                                        end
                                    end
                                end

                                if love.filesystem.getInfo(tempImgPath) or io.open(tempImgPath, "r") then
                                    local imgData = love.image.newImageData(tempImgPath)
                                    local img = love.graphics.newImage(imgData)
                                    table.insert(results, {
                                        image = img,
                                        screenshot = screenImg,
                                        tempScreenPath = tempScreenPath,
                                        description = game.overview or "Sin descripción.",
                                        year = year,
                                        region = game.game_title, -- Usamos el título como info
                                        tempPath = tempImgPath,
                                        source = "TheGamesDB"
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
        end
    end

    -- 3. Libretro
    if scraperApi == "all" or scraperApi == "libretro" then
        -- Repositorio de miniaturas de Libretro (Sin API Key, basado en nombres No-Intro)
        local libretroSystems = {
            gba = "Nintendo - Game Boy Advance",
            snes = "Nintendo - Super Nintendo Entertainment System",
            sfc = "Nintendo - Super Nintendo Entertainment System",
            nes = "Nintendo - Nintendo Entertainment System",
            fc = "Nintendo - Nintendo Entertainment System",
            gb = "Nintendo - Game Boy",
            gbc = "Nintendo - Game Boy Color",
            md = "Sega - Mega Drive - Genesis",
            gen = "Sega - Mega Drive - Genesis",
            ps = "Sony - PlayStation",
            ps1 = "Sony - PlayStation",
            psx = "Sony - PlayStation",
            nds = "Nintendo - Nintendo DS",
            n64 = "Nintendo - Nintendo 64",
            sms = "Sega - Master System - Mark III",
            gg = "Sega - Game Gear",
            neogeo = "SNK - Neo Geo",
            arcade = "MAME",
            mame = "MAME",
            fbneo = "MAME",
            pce = "NEC - PC Engine",
            ngp = "SNK - Neo Geo Pocket",
            ngpc = "SNK - Neo Geo Pocket Color"
        }
        
        local sysName = libretroSystems[systemName:lower()]
        if not sysName then
             local msg = "Sistema no mapeado en Libretro: " .. tostring(systemName)
             log(msg)
             table.insert(results, {error=true, text=msg})
        else
             -- Ajustar encoding para URL de Libretro (espacios como %20 en lugar de +)
             local sysEncoded = urlencode(sysName):gsub("%+", "%%20")
             
             -- Función local para intentar descargar de Libretro
             local function tryLibretro(nameToTry, label)
                 local nameEnc = urlencode(nameToTry):gsub("%+", "%%20")
                 local url = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Boxarts/" .. nameEnc .. ".png"
                 log("Libretro Request ("..label.."): " .. url)
                 
                 local tempImgPath = "/tmp/scraper_libretro_" .. label:gsub(" ", "_") .. ".png"
                 -- Usamos curl -v y capturamos stderr para ver la respuesta en el log
                 local handle = io.popen("curl -v -s -L -f '" .. url .. "' -o " .. tempImgPath .. " 2>&1")
                 local output = handle:read("*a")
                 handle:close()
                 log("Libretro Response ("..label.."): " .. (output or "nil"))
                 
                 -- Verificar si el archivo existe y tiene contenido
                 local f = io.open(tempImgPath, "rb")
                 local data = nil
                 if f then
                     data = f:read("*a")
                     f:close()
                 end

                 if data and #data > 0 then
                     -- Try to fetch snap (Screenshot)
                     local snapUrl = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Snaps/" .. nameEnc .. ".png"
                     local tempScreenPath = "/tmp/scraper_libretro_snap_" .. label:gsub(" ", "_") .. ".png"
                     local screenImg = nil
                     os.execute("curl -s -L -f '" .. snapUrl .. "' -o " .. tempScreenPath)
                     
                     local fSnap = io.open(tempScreenPath, "rb")
                     if fSnap then
                         local sData = fSnap:read("*a")
                         fSnap:close()
                         if sData and #sData > 0 then
                             screenImg = love.graphics.newImage(love.filesystem.newFileData(sData, "snap.png"))
                         end
                     end

                     local fileData = love.filesystem.newFileData(data, "scraper.png")
                     local img = love.graphics.newImage(fileData)
                     table.insert(results, {
                         image = img,
                         screenshot = screenImg,
                         tempScreenPath = tempScreenPath,
                         description = "Libretro no proporciona descripciones.",
                         region = "Libretro ("..label..")",
                         tempPath = tempImgPath,
                         source = "Libretro"
                     })
                     return true
                 end
                 return false
             end
             
             -- 1. Intento Exacto
             local found = tryLibretro(cleanName, "Exacto")
             
             -- 2. Intento Limpio (sin paréntesis ni corchetes)
             if not found then
                 local clean = cleanName:gsub("%b()", ""):gsub("%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                 if clean ~= cleanName then
                     found = tryLibretro(clean, "Limpio")
                 end
             end
             
             if not found then
                 table.insert(results, {error=true, text="Libretro: No encontrado", source="Libretro"})
             end
        end
    end

    if scraperApi == "mock" then
        -- Modo de prueba sin API Key
        log("Mock Scraping: " .. item.name)
        
        -- Usamos un asset existente como resultado falso
        local mockSrc = love.filesystem.getSource() .. "/assets/roms.png"
        local mockTemp = "/tmp/scraper_mock.png"
        
        os.execute("cp '" .. mockSrc .. "' " .. mockTemp)
        
        if io.open(mockTemp, "r") then
            local img = love.graphics.newImage(mockTemp)
            table.insert(results, {
                image = img,
                description = "Esto es una descripción de prueba en modo Mock.",
                region = "Mock Result (Test)",
                tempPath = mockTemp
            })
        end
    end
    return results
end

function findSaveFiles(item)
    saveFiles = {}
    saveManagerSelection = 1
    local baseName = item.name:gsub("%..-$", "")
    
    -- Rutas comunes de guardado en muOS / RetroArch
    local searchPaths = {
        "/mnt/mmc/MUOS/save",
        "/mnt/sdcard/MUOS/save",
        "/mnt/mmc/MUOS/save/state",
        "/mnt/sdcard/MUOS/save/state",
        item.fullPath:match("(.*/)") -- Carpeta de la ROM
    }
    
    local foundMap = {}

    for _, path in ipairs(searchPaths) do
        -- Listar archivos que empiecen por el nombre de la ROM
        local h = io.popen('find "'..path..'" -maxdepth 1 -name "'..baseName..'.*" 2>/dev/null')
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
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = true, progress = 0, cursor = {col=1, row=1}, confirming = false }
    
    cleanupCoroutine = coroutine.create(function()
        local romNames = {} -- Para huérfanos: nombre base -> true
        local romsByStem = {} -- Para duplicados: nombre base -> lista de archivos
        local romsBySystem = {} -- Para imágenes huérfanas: system -> stem -> true

        local function scanAndRegister(path, locationLabel)
            local h = io.popen('find "'..path..'" -type f')
            if h then
                local count = 0
                for line in h:lines() do
                    count = count + 1
                    if count % 50 == 0 then coroutine.yield() end
                    
                    local filename = line:match("([^/]+)$")
                    if filename then
                        local ext = filename:match("[^%.]+$")
                        if ext then
                            local extLower = ext:lower()
                            -- Excluir imágenes y states de la búsqueda de duplicados
                            if validExtensions[extLower] and extLower ~= "png" and extLower ~= "jpg" and extLower ~= "jpeg" and extLower ~= "state" then
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
        cleanupData.progress = 0.4
        coroutine.yield()
        
        scanAndRegister("/mnt/sdcard/ROMS", "SD2")
        cleanupData.progress = 0.7
        coroutine.yield()

        -- 2. Buscar Save States Huérfanos
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
    
    scraperResults = getScrapeResults(item)
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
            
            local results = getScrapeResults(item)
            if results and #results > 0 and not results[1].error then
                saveScrapeResult(item, results[1])
                scraperProgress.successes = scraperProgress.successes + 1
            else
                scraperProgress.failures = scraperProgress.failures + 1
            end
        end
        state = "LIST"
        refreshFiles()
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
    if #files == 0 or files[selectedIndex].isDir then return end
    
    local baseName = files[selectedIndex].name:gsub("%..-$", "")
    
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
        local parts = split(res, "x")
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
            if loadedState.romPath then 
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
    if romPath == "" then -- If romPath wasn't loaded from app_state.json
        if lastPlayedRom and lastPlayedRom ~= "" then
            playedRoms[lastPlayedRom] = true -- Ensure the last played is marked
            romPath = lastPlayedRom:match("(.*/)")
            -- selectedIndex will be updated after refreshFiles
        end
    end

    if romPath ~= "" then
        refreshFiles()
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
    end

    -- Load modules
    love.draw = require "drawing"
    love.update = require "update"
    local input = require "input"
    love.keypressed = input.keypressed
    love.gamepadpressed = input.gamepadpressed
    love.textinput = input.textinput
end