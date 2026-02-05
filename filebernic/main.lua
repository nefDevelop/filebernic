---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global
---@diagnostic disable: undefined-field

local json = require "libs.dkjson"
utils = require "utils"
Loader = require "loader"
State = require "state"
preview = require "preview"

-- Variables de configuración y estado
DEBUG = 2 -- 0: No logs, 1: Errors only, 2: All logs
DEBUG_SECTIONS = {
    LOADER = false,
    DEFAULT = true
}

systemName = ""
romPath = ""
config = {
    scraperApi = "all", -- Opciones: "all", "libretro", "thegamesdb"
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
iconFolder, iconRom, iconNetwork, currentImage, currentScreenshot, currentYear, buttonIcons, currentSystemIcon, currentSystemContentIcon = nil, nil, nil, nil, nil, nil, nil, nil, nil
currentImageAlpha, currentScreenshotAlpha, imageInvalid, screenshotInvalid = 0, 0, false, false
currentDescription = ""
timer, delay, pendingLoad = 0, 0.05, false
inputCooldown = 0 -- Temporizador para evitar doble input
launching = false -- Estado de lanzamiento
launchTimer = 0
hideEmpty = false
markPlayed = true
hideFavorites = false
favoriteRoms = {}
pageSize = 7
viewMode = "LIST" -- "LIST" or "GRID"
gridCols = 4
launchMode = "Folder" -- "Folder" or "Juego Unico"
selectedFilesCount = 0
theme = nil
fontList, fontTitle, fontSmall, fontMedium, fontHuge, fontTopBar, fontSelected, fontClock = nil, nil, nil, nil, nil, nil, nil, nil
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
helpAnim = 0
keyboardAnim = 0
saveFiles = {}
saveManagerSelection = 1
cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
cleanupCoroutine = nil
scraperResults = {}
scraperProgress = { current = 0, total = 0, currentName = "", successes = 0, failures = 0 }
scraperSelection = 1
searchQuery = ""
menuStack = {}
focusedItem = nil
allFiles = {}
previewItem = nil -- For storing the item whose preview is being displayed
-- Indexing
romIndex = nil
isIndexing = false
indexStateMessage = ""
indexerThread = nil
indexerChannelIn = nil
indexerChannelOut = nil
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
    rowHeight = 54,       -- Altura de cada fila
    selWidth = 320,       -- Ancho del selector
    selHeight = 44,       -- Alto del selector
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

filesystem = require "filesystem"

local systemIconCache = {}

function getSystemIcon(sysName)
    if not sysName then return nil end
    if systemIconCache[sysName] then return systemIconCache[sysName] end
    
    local variants = utils.getSystemVariants(sysName)

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. ".png"
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            systemIconCache[sysName] = img
            return img
        end
    end
    return nil
end

local systemContentIconCache = {}

function getSystemContentIcon(sysName)
    if not sysName then return nil end
    if systemContentIconCache[sysName] then return systemContentIconCache[sysName] end
    local variants = utils.getSystemVariants(sysName)

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

function forceReindex()
    log("Forcing re-index...")
    romIndex = nil
    -- Delete index files
    os.remove(love.filesystem.getSource() .. "/data/rom_index.json")
    os.remove(love.filesystem.getSource() .. "/data/rom_timestamps.json")
    
    -- Restart indexing
    isIndexing = true
    indexStateMessage = "Iniciando indexado..."
    indexerChannelIn:push({command="start", validExtensions=validExtensions, sourceDir=love.filesystem.getSource(), priorityPath=romPath})
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
    systemName, muosArtPath, muosTextPath, muosPreviewPath, currentSystemIcon, currentSystemContentIcon = filesystem.updateSystemPaths(systemName, romPath, log, love.graphics.newImage)
end

function refreshFiles()
    if romPath and romPath ~= "" and romPath:sub(-1) ~= "/" then romPath = romPath .. "/" end
    romPath = filesystem.fixPathCase(romPath) -- Corregir mayúsculas/minúsculas de la ruta
    log("Refreshing files... Path: " .. romPath)
    files, selectedFilesCount, selectedIndex, allFiles = filesystem.refreshFiles(updateSystemPaths, files, selectedFilesCount, launchMode, hideEmpty, validExtensions, romPath, secondaryPath, selectedIndex, allFiles, log)
    preview.load()
end

function updateFileList(newIndex)
    if launchMode ~= "Juego Unico" or not isVirtualRoot then
        romIndex = newIndex
        return
    end

    local oldFiles = files
    local oldSelection = files[selectedIndex]
    
    -- Generate new list from newIndex
    local newFiles = {}
    for _, item in ipairs(newIndex) do
        local copy = {}
        for k, v in pairs(item) do copy[k] = v end
        table.insert(newFiles, copy)
    end
    
    -- Map new files for quick lookup
    local newMap = {}
    for i, item in ipairs(newFiles) do
        newMap[item.name] = item
    end
    
    -- Rebuild 'files' merging old state
    local mergedFiles = {}
    
    -- 1. Keep existing items (to preserve order/state) if they exist in new, OR if they are the selected ghost
    for i, item in ipairs(oldFiles) do
        if newMap[item.name] then
            -- Update data but keep UI state if any (like selection)
            local newItem = newMap[item.name]
            -- Merge properties
            for k,v in pairs(newItem) do item[k] = v end
            item.pendingDelete = false -- Confirmed existence
            table.insert(mergedFiles, item)
            newMap[item.name] = nil -- Mark as processed
        elseif i == selectedIndex then
            -- This is the selected item, but it's gone from index. Mark as Ghost.
            item.pendingDelete = true
            table.insert(mergedFiles, item)
        end
    end
    
    -- 2. Add remaining new items
    for _, item in pairs(newMap) do
        table.insert(mergedFiles, item)
    end
    
    -- 3. Sort
    table.sort(mergedFiles, function(a, b) return a.name:lower() < b.name:lower() end)
    
    files = mergedFiles
    romIndex = newIndex
    
    -- 4. Restore selection
    local found = false
    for i, item in ipairs(files) do
        if item == oldSelection then
            selectedIndex = i
            found = true
            break
        end
    end
    
    if not found then
        selectedIndex = math.min(selectedIndex, #files)
        if selectedIndex < 1 then selectedIndex = 1 end
    end
    
    -- Update allFiles backup
    allFiles = {}
    for _, item in ipairs(files) do table.insert(allFiles, item) end
    
    preview.load()
end

function log(message)
    if DEBUG == 0 then return end
    
    -- Nivel 1: Solo Errores
    if DEBUG == 1 then
        local lowerMsg = message:lower()
        if not (lowerMsg:find("error") or lowerMsg:find("fatal") or lowerMsg:find("failed")) then
            return
        end
    end

    if DEBUG >= 2 then
        if message:find("^%[LOADER%]") then
            if not DEBUG_SECTIONS.LOADER then return end
        elseif not DEBUG_SECTIONS.DEFAULT then
            return
        end
    end

    local logPath = love.filesystem.getSource() .. "/data/log/filebernic.log"
    local f = io.open(logPath, "a")
    if f then
        f:write("[LUA DEBUG] " .. os.date() .. ": " .. message .. "\n")
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
    log("Quitting application...")
    State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
    filesystem.saveViewCache(files, romPath, selectedIndex, isVirtualRoot, json.encode, love.filesystem.getSource, io.open)
    loader:quit()
    if indexerChannelIn then indexerChannelIn:push({command="quit"}) end
    
    -- Log content of art folders on exit
    if muosArtPath and muosArtPath ~= "" and systemName and systemName ~= "" then
        log("Listing Boxart folder content: " .. muosArtPath)
        local h = io.popen('ls -1 "'..muosArtPath..'" 2>/dev/null')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
    
    if muosPreviewPath and muosPreviewPath ~= "" and systemName and systemName ~= "" then
        log("Listing Preview folder content: " .. muosPreviewPath)
        local h = io.popen('ls -1 "'..muosPreviewPath..'" 2>/dev/null')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
end

function love.load(arg)
    log("Loading application...")
    local cores = love.system.getProcessorCount()
    log("Hardware info: " .. cores .. " cores detected.")
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
    
    loader = Loader:new(log)
    
    -- Inicializar hilo de indexado
    indexerThread = love.thread.newThread("indexer.lua")
    indexerChannelIn = love.thread.getChannel("indexer_in")
    indexerChannelOut = love.thread.getChannel("indexer_out")
    indexerThread:start()

    -- Detectar entorno (Dispositivo vs Simulador)
    local isDevice = false
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
        isDevice = true
    end

    local function normalizePath(path)
        if not path or path == "" then return "" end
        local relPath = nil
        if path:find("ROMS/") then
            relPath = path:match("ROMS/(.*)")
        elseif path:find("Simulador_SD/") then
            relPath = path:match("Simulador_SD/(.*)")
        end
        
        if not relPath then 
             if path:sub(1,1) ~= "/" then relPath = path else return path end
        end

        if isDevice then
            local pathSD1 = "/mnt/mmc/ROMS/" .. relPath
            local h = io.popen('ls -d "'..pathSD1..'" 2>/dev/null')
            local res = h:read("*a")
            h:close()
            if res and res ~= "" then return pathSD1 end
            return "/mnt/sdcard/ROMS/" .. relPath
        else
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            return cwd .. "/../Simulador_SD/" .. relPath
        end
    end

    local baseMuosPath = ""
    if isDevice then
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
    iconFavorite = love.graphics.newImage("assets/media/favorites-content.png")
    iconNetwork = love.graphics.newImage("assets/media/network.png")
    
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

    -- Configuración de Fuentes
    local mainFontPath = "assets/fonts/SNPro-Regular.ttf"
    local selectedFontPath = "assets/fonts/SNPro-Black.ttf"
    local topBarFontPath = "assets/fonts/JetBrainsMono-Regular.ttf"

    fontSmall = love.graphics.newFont(mainFontPath, 16)    -- Textos pequeños, ayudas
    fontMedium = love.graphics.newFont(mainFontPath, 20)   -- Textos generales
    fontList = love.graphics.newFont(mainFontPath, 24)   -- Lista de juegos (importante que sea legible)
    fontTitle = love.graphics.newFont(mainFontPath, 30)    -- Títulos de menús
    fontHuge = love.graphics.newFont(mainFontPath, 80)     -- Letra grande de salto rápido
    fontTopBar = love.graphics.newFont(topBarFontPath, 24) -- Fuente para la barra de título
    fontClock = love.graphics.newFont(topBarFontPath, 20)  -- Fuente para el reloj
    fontSelected = love.graphics.newFont(selectedFontPath, 20) -- Fuente para elemento seleccionado (900)

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
    config = State.loadConfig(config)
    scraperApi = config.scraperApi

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
            if loadedState.hideFavorites ~= nil then hideFavorites = loadedState.hideFavorites end
            if launchMode == "Juego Unico" then
                romPath = "" -- Forzar raíz virtual en Modo Único
            elseif loadedState.romPath then 
                romPath = normalizePath(loadedState.romPath)
                if romPath and romPath ~= "" and romPath:sub(-1) ~= "/" then romPath = romPath .. "/" end
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

    -- Load Favorites
    favoriteRoms = filesystem.loadFavorites(json.decode)

    -- Load last played ROM (separate from app_state)
    local f = io.open(love.filesystem.getSource() .. "/data/last_played.txt", "r")
    if f then
        local raw = f:read("*all")
        f:close()
        lastPlayedRom = normalizePath(raw)
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
        preview.load()
    else
        log("Creating merged virtual root...")
        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, getSystemIcon, allFiles, nil, favoriteRoms, hideFavorites)
        preview.load()
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
             if found then
                preview.load()
             end
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

    -- Intentar cargar el índice ANTES de crear la vista inicial.
    -- Esto evita que la lista aparezca vacía (Files count: 0) si el índice ya existe y es válido.
    local needsIndexing = false
    
    -- 1. Intentar cargar Caché de Vista para arranque instantáneo
    local cachedFiles, cachedIndex, cachedPath, cachedVirtual = filesystem.loadViewCache(json.decode, love.filesystem.getSource, io.open, getSystemIcon, getSystemContentIcon)
    if cachedFiles and #cachedFiles > 0 then
        log("View Cache loaded. Items: " .. #cachedFiles)
        files = cachedFiles
        selectedIndex = cachedIndex or 1
        romPath = cachedPath or ""
        isVirtualRoot = cachedVirtual
        allFiles = {} -- Reconstruir allFiles
        for _, f in ipairs(files) do table.insert(allFiles, f) end
    end

    -- Delegar la carga/comprobación del índice al hilo de fondo para no bloquear la UI
    -- Si el índice es grande (20MB+), esto evitará que la app se congele al inicio.
    isIndexing = true
    indexStateMessage = "Cargando base de datos..."
    indexerChannelIn:push({command="check_index", validExtensions=validExtensions, sourceDir=love.filesystem.getSource(), priorityPath=romPath})
    
    -- Determine initial view: app_state.json -> lastPlayedRom -> createMergedVirtualRoot
    -- Si cargamos caché, romPath ya tiene valor, así que esto se salta si ya tenemos vista.
    if #files == 0 and romPath == "" and launchMode ~= "Juego Unico" then 
        if lastPlayedRom and lastPlayedRom ~= "" then
            playedRoms[lastPlayedRom] = true -- Ensure the last played is marked
            romPath = lastPlayedRom:match("(.*/)")
            -- selectedIndex will be updated after refreshFiles
        end
    end

    if #files == 0 and romPath ~= "" then
        refreshFiles()
        -- If romPath was from lastPlayedRom, try to find and set selectedIndex
        if lastPlayedRom and lastPlayedRom ~= "" and romPath == lastPlayedRom:match("(.*/)") then
            for i, item in ipairs(files) do
                if item.fullPath == lastPlayedRom or (romPath .. item.name) == lastPlayedRom then
                    selectedIndex = i
                    break
                end
            end
        end
        preview.load()
    elseif #files == 0 then
        log("Creating merged virtual root...")
        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles = filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, nil, allFiles, nil, favoriteRoms, hideFavorites)
        preview.load()
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
             if found then
                preview.load()
             end
        end
    end
    
    -- Si cargamos desde caché, asegurar que cargamos previews
    if #files > 0 then
        preview.load()
    end
end