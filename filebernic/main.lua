---@diagnostic disable: undefined-global
json = require "libs.dkjson"
utils = require "utils"

Loader = require "loader"
State = require "state"
preview = require "preview"
require "locale" -- Cargar sistema de traducción
input = require "input"

APP_VERSION = "v0.1.1"
updateUrl = "" 
updateAvailable = nil

-- Variables de configuración y estado
DEBUG = 1 -- 0: No logs, 1: Errors only, 2: All logs
DEBUG_SECTIONS = {
    LOADER = false,
    DEFAULT = false
}

systemName = ""
romPath = ""
config = {
    scraperApi = "all", -- Opciones: "all", "libretro", "thegamesdb", "screenscraper" (o combinaciones separadas por coma)
    thegamesdb_apikey = "",
    screenscraper_user = "",
    screenscraper_password = "",
    screenscraper_devid = "",
    screenscraper_devpassword = "",
    language = nil -- Idioma por defecto (nil para auto-detectar)
    }
secondaryPath = nil
muosArtPath = ""
muosTextPath = ""
muosPreviewPath = ""
files = {}
selectedIndex = 1
state = "LIST" -- LIST, POST_GAME, DELETE_MENU, OPTIONS_MENU, SCRAPER_VIEW, SCRAPING_IN_PROGRESS, SCRAPER_RESULTS, SEARCH
itemToDelete = nil -- Item currently selected for deletion

lastPlayedRom = ""
playedRoms = {}
iconFolder, iconRom, iconNetwork, iconReload, iconTrash, iconHide, iconInfo, iconSaveStates, iconList, iconGrid, iconGame, iconKey, imgNoImage, imgOn, imgOff, currentImage, currentScreenshot, currentYear, buttonIcons, currentSystemIcon, currentSystemContentIcon = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
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
animatedSelectionIndex = 1 -- Para animación suave del cursor
selectionAnimationSpeed = 10 -- Velocidad de la animación (ajustar según preferencia)
animGridRow = nil -- Animación fila grid
animGridCol = nil -- Animación columna grid
gridSelectionAnimationSpeed = 25 -- Velocidad de animación para el modo Grid (más rápida)
viewMode = "LIST" -- "LIST" or "GRID"
gridCols = 4
launchMode = "Folder" -- "Folder" or "Juego Unico"
selectedFilesCount = 0
theme = nil
fontList, fontTitle, fontSmall, fontMedium, fontHuge, fontTopBar, fontSelected, fontClock = nil, nil, nil, nil, nil, nil, nil, nil
menuOptions = {} -- Inicializar vacío, se llenará dinámicamente
menuSelection = 1
menuTitle = "" -- Title of the current menu

menuMessage = ""
showHelp = false
closingMenu = false
closingHelp = false
fastScrollTimer = 0
jumpLetter = ""
jumpPanelAnim = 0
helpData = {}
favAnim = 0
favAnimTarget = 0
favAnimIndex = -1
menuAnim = 0
helpAnim = 0
keyboardAnim = 0
saveFiles = {}
saveManagerSelection = 1
cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
cleanupCoroutine = nil -- Coroutine for cleanup scan

scraperResults = {}
scraperProgress = { current = 0, total = 0, currentName = "", successes = 0, failures = 0 }
scraperSelection = 1
scraperFocus = "FRONT"
scraperFrontIndex = 1
scraperScreenIndex = 1
scraperTextIndex = 1
scraperProgressMessage = "" -- New variable for scraper progress messages
scraperWarningMessage = "" -- New variable for scraper warning messages
scraperWarningTimer = 0 -- Timer for how long to display the warning
searchQuery = ""
textToEdit = "" -- Variable for text editing
textEditLabel = "" -- Label for text editing
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
keyboardCol = 1 -- Current column in the virtual keyboard


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
    rar=true, -- Archives
    rom=true -- Generic ROM
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

function forceReindex(global_state)
    log("Forcing re-index...")
    romIndex = nil
    -- Delete index files
    filesystem.safeRemove(love.filesystem.getSource() .. "/data/rom_index.json", global_state.log)
    filesystem.safeRemove(love.filesystem.getSource() .. "/data/rom_timestamps.json", global_state.log)
    filesystem.safeRemove(love.filesystem.getSource() .. "/data/view_cache.json", global_state.log)
    
    -- Vaciar la lista en memoria para forzar la pantalla de "Indexando..."
    if global_state.launchMode == "Juego Unico" and global_state.isVirtualRoot then
        global_state.files = {}
        global_state.allFiles = {}
        global_state.selectedIndex = 1
    else
        refreshFiles()
    end
    
    -- Restart indexing
    isIndexing = true
    global_state.indexStateMessage = "Iniciando indexado..."
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

-- Expose input.refreshFiles and input.updateSystemPaths to global scope
-- These will be called by main.lua's global refreshFiles and updateSystemPaths
-- after input.lua is required.
function refreshFiles()
    input.refreshFiles(_G)
end

function updateSystemPaths()
    input.updateSystemPaths(_G)
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
    
    preview.load(_G, log, loader) -- Pass global state to preview.load
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
    State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites, love.filesystem)
    filesystem.saveViewCache(files, romPath, selectedIndex, isVirtualRoot, json.encode, love.filesystem.getSource, io.open)
    loader:quit()
    if indexerChannelIn then indexerChannelIn:push({command="quit"}) end
    
    -- Log content of art folders on exit
    if muosArtPath and muosArtPath ~= "" and systemName and systemName ~= "" then
        log("Listing Boxart folder content: " .. muosArtPath)
        local h = io.popen('ls -1 ' .. utils.escapeShellArg(muosArtPath) .. ' 2>/dev/null')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
    
    if muosPreviewPath and muosPreviewPath ~= "" and systemName and systemName ~= "" then
        log("Listing Preview folder content: " .. muosPreviewPath)
        local h = io.popen('ls -1 ' .. utils.escapeShellArg(muosPreviewPath) .. ' 2>/dev/null')
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
    os.execute("mkdir -p " .. utils.escapeShellArg(love.filesystem.getSource() .. "/data/log"))
    os.execute("mkdir -p " .. utils.escapeShellArg("tmp"))

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
    scraperApi = config.scraperApi -- Initialize scraperApi after config is loaded

    loader = Loader:new(log, {
        thread = love.thread, -- Pass love.thread module
        filesystem = love.filesystem,
        image = love.image,
        graphics = love.graphics
    })
    
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
            local h = io.popen('ls -d ' .. utils.escapeShellArg(pathSD1) .. ' 2>/dev/null')
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
    
    iconFolder = love.graphics.newImage("assets/ui/folder.png")
    iconRom = love.graphics.newImage("assets/ui/roms.png")
    iconFavorite = love.graphics.newImage("assets/ui/favorites-content.png")
    iconNetwork = love.graphics.newImage("assets/ui/network.png")
    iconReload = love.graphics.newImage("assets/ui/reload.png")
    iconTrash = love.graphics.newImage("assets/ui/trash.png")
    iconHide = love.graphics.newImage("assets/ui/hide.png")
    iconInfo = love.graphics.newImage("assets/ui/info.png")
    iconSaveStates = love.graphics.newImage("assets/ui/savestates.png")
    iconList = love.graphics.newImage("assets/ui/list.png")
    iconGrid = love.graphics.newImage("assets/ui/grid.png")
    iconGame = love.graphics.newImage("assets/ui/game.png")
    if love.filesystem.getInfo("assets/ui/key.png") then
        iconKey = love.graphics.newImage("assets/ui/key.png")
    end
    imgNoImage = love.graphics.newImage("assets/ui/noImage.png")
    imgOn = love.graphics.newImage("assets/ui/on.png")
    imgOff = love.graphics.newImage("assets/ui/off.png")
    
    buttonIcons = {
        a = love.graphics.newImage("assets/button/a.png"),
        b = love.graphics.newImage("assets/button/b.png"),
        y = love.graphics.newImage("assets/button/y.png"),
        x = love.graphics.newImage("assets/button/x.png"),
        select = love.graphics.newImage("assets/button/select.png"),
        start = love.graphics.newImage("assets/button/start.png"),
        l1 = love.graphics.newImage("assets/button/l1.png"),
        r1 = love.graphics.newImage("assets/button/r1.png")
    }

    -- Load theme and fonts
    theme = require "theme"

    -- Configuración de Fuentes
    local mainFontPath = "assets/fonts/SNPro-Regular.ttf"
    local selectedFontPath = "assets/fonts/SNPro-Black.ttf"
    local topBarFontPath = "assets/fonts/JetBrainsMono-Regular.ttf"
    local clockFontPath = "assets/fonts/JetBrainsMono-Bold.ttf"

    fontSmall = love.graphics.newFont(mainFontPath, 16)    -- Textos pequeños, ayudas
    fontMedium = love.graphics.newFont(mainFontPath, 20)   -- Textos generales
    fontList = love.graphics.newFont(mainFontPath, 24)   -- Lista de juegos (importante que sea legible)
    fontTitle = love.graphics.newFont(mainFontPath, 30)    -- Títulos de menús
    fontHuge = love.graphics.newFont(mainFontPath, 80)     -- Letra grande de salto rápido
    fontTopBar = love.graphics.newFont(topBarFontPath, 24) -- Fuente para la barra de título
    fontClock = love.graphics.newFont(clockFontPath, 20)  -- Fuente para el reloj
    fontSelected = love.graphics.newFont(selectedFontPath, 20) -- Fuente para elemento seleccionado (900)

    -- Define Help Data
    helpData = {
        LIST = { -- Help data for LIST state
            {icon=buttonIcons.a, text="accept"},
            {icon=buttonIcons.b, text="back"},
            {icon=buttonIcons.y, text="options"},
            {icon=buttonIcons.x, text="mark"},
            {icon=buttonIcons.start, text="config"},
            {icon=buttonIcons.select, text="exit"},
            {icon=buttonIcons.l1, text="search"},
            {icon=buttonIcons.r1, text="help"}
        },
        CLEANUP_MENU = { -- Help data for CLEANUP_MENU state
            {icon=buttonIcons.l1, text="change_col"},
            {icon=buttonIcons.a, text="delete"},
            {icon=buttonIcons.b, text="back"},
            {icon=buttonIcons.r1, text="help"}
        },
        INFO_VIEW = {
            {icon=buttonIcons.b, text="back"},
            {icon=buttonIcons.r1, text="help"} -- Help data for INFO_VIEW state
        },
        SCRAPER_VIEW = {
            {icon=buttonIcons.a, text="search"},
            {icon=buttonIcons.y, text="options"},
            {icon=buttonIcons.b, text="back"},
            {icon=buttonIcons.r1, text="help"} -- Help data for SCRAPER_VIEW state
        },
        OPTIONS_MENU = {
            {icon=buttonIcons.a, text="accept"},
            {icon=buttonIcons.b, text="back"},
            {icon=buttonIcons.r1, text="help"} -- Help data for OPTIONS_MENU state
        },
        DEFAULT = {
            {icon=buttonIcons.a, text="confirm"},
            {icon=buttonIcons.b, text="cancel"},
            {icon=buttonIcons.r1, text="help"}
        }
    }

    -- Cargar configuración global (API keys, etc)
    config = State.loadConfig(config, love.filesystem) -- Load config with love.filesystem
    scraperApi = config.scraperApi

    -- Detectar idioma si no está forzado en config
    if not config.language then
        local sysLang = os.getenv("LANG")
        if sysLang then
            local lowerLang = sysLang:lower()
            if lowerLang:match("^es") then config.language = "es"
            elseif lowerLang:match("^en") then config.language = "en"
            end
        end
    end
    L.current = config.language or "es" -- Establecer idioma actual (fallback a español)
    
    -- Load saved application state
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
                -- Forzar raíz virtual en Modo Único
                romPath = ""
            elseif loadedState.romPath then 
                romPath = normalizePath(loadedState.romPath)
                if romPath and romPath ~= "" and romPath:sub(-1) ~= "/" then romPath = romPath .. "/" end
            end
            if loadedState.selectedIndex then selectedIndex = loadedState.selectedIndex end
        end
    end

    -- Cargar historial de juegos jugados (this populates playedRoms, keep it)
    local f = io.open(love.filesystem.getSource() .. "/data/played_roms.txt", "r") -- Load played ROMs history
    if f then
        for line in f:lines() do
            playedRoms[line] = true
        end
        f:close()
    end

    -- Check for pending history from previous session (post-game)
    playedRoms = filesystem.checkPendingHistory(playedRoms, filesystem.saveHistory)

    -- Load Favorites
    favoriteRoms = filesystem.loadFavorites(json.decode) -- Load favorite ROMs

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
            -- Ensure the last played is marked
            playedRoms[lastPlayedRom] = true
            romPath = lastPlayedRom:match("(.*/)")
            -- selectedIndex will be updated after refreshFiles
        end -- End if lastPlayedRom
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
        end -- End if lastPlayedRom
        preview.load(_G, log, loader) -- Pass global state to preview.load
    else
        log("Creating merged virtual root...")
        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles =
            filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, love.filesystem.getInfo, love.graphics.newImage, allFiles, nil, favoriteRoms, hideFavorites, log, loader)
        preview.load(_G, log, loader) -- Pass global state to preview.load
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
                preview.load(_G, log, loader) -- Pass global state to preview.load
             end
        end -- End if lastPlayedRom
    end

    -- Load modules
    local drawing = require "drawing"
    love.draw = function() drawing(_G) end
    local update_function = require "update" -- Store update module locally
    love.keypressed = function(key) input.keypressed(key, _G) end
    -- Pass global state to update function
    love.update = function(dt)
        update_function(dt, _G, log, loader, updateFileList)
    end
    love.gamepadpressed = function(j, b) input.gamepadpressed(j, b, _G) end
    love.joystickpressed = function(j, b) input.joystickpressed(j, b, _G) end -- Pass global state to joystickpressed
    love.textinput = function(t) input.textinput(t, _G) end

    -- Intentar cargar el índice ANTES de crear la vista inicial.
    -- Esto evita que la lista aparezca vacía (Files count: 0) si el índice ya existe y es válido.
    local needsIndexing = false
    
    -- 1. Intentar cargar Caché de Vista para arranque instantáneo
    local cachedFiles, cachedIndex, cachedPath, cachedVirtual =
        filesystem.loadViewCache(json.decode, love.filesystem.getSource, io.open, utils.getSystemIcon, utils.getSystemContentIcon, love.filesystem.getInfo, love.graphics.newImage)
    if cachedFiles and #cachedFiles > 0 then
        log("View Cache loaded. Items: " .. #cachedFiles)
        files = cachedFiles
        selectedIndex = cachedIndex or 1
        romPath = cachedPath or ""
        isVirtualRoot = cachedVirtual
        allFiles = {} -- Reconstruir allFiles
        for _, f in ipairs(files) do table.insert(allFiles, f) end -- Populate allFiles from cache
    end

    -- Delegar la carga/comprobación del índice al hilo de fondo para no bloquear la UI
    -- If the index is large (20MB+), this will prevent the app from freezing at startup.
    isIndexing = true
    indexStateMessage = "Cargando base de datos..."
    indexerChannelIn:push({command="check_index", validExtensions=validExtensions, sourceDir=love.filesystem.getSource(), priorityPath=romPath})
    
    -- Comprobar actualizaciones en segundo plano (OTA) al iniciar
    indexerChannelIn:push({command="check_update_ota", currentVersion=APP_VERSION})
    
    -- Determine initial view: app_state.json -> lastPlayedRom -> createMergedVirtualRoot
    -- Si cargamos caché, romPath ya tiene valor, así que esto se salta si ya tenemos vista.
    if #files == 0 and romPath == "" and launchMode ~= "Juego Unico" then 
        if lastPlayedRom and lastPlayedRom ~= "" then -- If there's a last played ROM
            -- Ensure the last played is marked
            playedRoms[lastPlayedRom] = true -- Ensure the last played is marked
            romPath = lastPlayedRom:match("(.*/)")
            -- selectedIndex will be updated after refreshFiles
        end -- End if lastPlayedRom
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
        end -- End if lastPlayedRom
        preview.load(_G, log, loader) -- Pass global state to preview.load
    elseif #files == 0 then
        log("Creating merged virtual root...")
        files, isVirtualRoot, romPath, secondaryPath, selectedIndex, allFiles =
            filesystem.createMergedVirtualRoot(files, isVirtualRoot, romPath, secondaryPath, selectedIndex, launchMode, romIndex, hideEmpty, validExtensions, utils.getSystemIcon, love.filesystem.getInfo, love.graphics.newImage, allFiles, nil, favoriteRoms, hideFavorites, log, loader)
        preview.load(_G, log, loader) -- Pass global state to preview.load
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
                preview.load(_G, log, loader) -- Pass global state to preview.load
             end
        end -- End if lastPlayedRom
    end
    
    -- Si cargamos desde caché, asegurar que cargamos previews
    if #files > 0 then
        preview.load(_G, log, loader)
    end
end