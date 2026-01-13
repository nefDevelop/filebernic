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

function updateSystemPaths()

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
                filesystem.saveScrapeResult(item, results[1], muosArtPath, muosTextPath, muosPreviewPath, log)
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
    filesystem.saveScrapeResult(item, result, muosArtPath, muosTextPath, muosPreviewPath, log)
    
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
            loadPreview()
        end
    else
        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, getSystemIcon, allFiles, loadPreview)
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
    romIndex = filesystem.startIndexingProcess(romIndex, json.decode, love.filesystem.getSource, io.open, log, filesystem.performBackgroundIndexing, isIndexing, indexStateMessage, validExtensions, json.encode, os.execute, coroutine.create, coroutine.yield, table.insert, table.sort, filesystem.createMergedVirtualRoot, isVirtualRoot, launchMode, files, secondaryPath, selectedIndex, allFiles, hideEmpty, getSystemIcon, loadPreview)
end