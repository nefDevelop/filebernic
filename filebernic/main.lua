local json = require "libs.dkjson"
local http = require "love.http"

-- Utility function to split a string by a delimiter
function split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- Variables de configuración y estado
local systemName = "GBA"
local romPath = ""
local secondaryPath = nil
local muosArtPath = ""
local muosTextPath = ""
local files = {}
local selectedIndex = 1
local state = "LIST" -- LIST, POST_GAME, DELETE_MENU, OPTIONS_MENU, SCRAPER_VIEW, SCRAPING_IN_PROGRESS, SCRAPER_RESULTS, SEARCH
local itemToDelete = nil
local lastPlayedRom = ""
local playedRoms = {}
local iconFolder, iconRom, currentImage, buttonIcons
local timer, delay, pendingLoad = 0, 0.2, false
local inputCooldown = 0 -- Temporizador para evitar doble input
local launching = false -- Estado de lanzamiento
local launchTimer = 0
local hideEmpty = false
local pageSize = 13
local selectedFilesCount = 0
local theme
local fontList, fontTitle, fontSmall, fontMedium
local menuOptions = {"Borrar"}
local menuSelection = 1
local menuTitle = ""
local menuMessage = ""
local scraperResults = {}
local scraperSelection = 1
local searchQuery = ""
local allFiles = {}

local validExtensions = {
    -- Nintendo
    gb=true, gbc=true, gba=true, nes=true, fds=true, unf=true, unif=true,
    snes=true, smc=true, sfc=true, fig=true, swc=true, bs=true, bml=true,
    n64=true, v64=true, z64=true, ndd=true, u1=true,
    nds=true, ids=true, dsi=true,
    vb=true, vboy=true, min=true,
    -- Sega
    md=true, gen=true, smd=true, bin=true, mdx=true,
    sms=true, gg=true, sg=true,
    cdi=true, gdi=true, elf=true, lst=true, dat=true,
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
    cbr=true, cbz=true, epub=true, pdf=true, -- Books
    exe=true, -- Cave Story / DOS / Ports
    chai=true, chailove=true, -- ChaiLove
    ch8=true, sc8=true, xo8=true, -- CHIP-8
    col=true, cv=true, ri=true, mx1=true, mx2=true, -- Coleco / MSX
    adf=true, adz=true, dms=true, fdi=true, hdf=true, hdz=true, lha=true, slave=true, info=true, nrg=true, rp9=true, wrp=true, -- Amiga
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
    p8=true, png=true, -- PICO-8
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
local layout = {
    listY = 60,           -- Posición Y inicial de la lista
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
local scrollTimer = 0
local initialScrollDelay = 0.4
local subsequentScrollDelay = 0.1
local keyHeld = nil -- ('up' o 'down')
local isVirtualRoot = false

function createMergedVirtualRoot()
    files = {}
    isVirtualRoot = true
    romPath = "" -- Not a real path in this view
    secondaryPath = nil
    selectedIndex = 1

    local dirMap = {} -- Mapa para rastrear directorios y fusionar etiquetas

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
                                files[dirMap[dirName]].sourceLabel = "SD1-SD2"
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

function refreshFiles()
    files = {}
    selectedFilesCount = 0
    -- Botón para subir nivel si no estamos en la raíz
    local cwd = love.filesystem.getSource()
    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
    local simuladorSdRoot = cwd .. "/../Simulador_SD/"
    if romPath ~= "" and romPath ~= simuladorSdRoot then
        table.insert(files, {name = "..", isDir = true})
    end

    local fileMap = {}

    local function scan(path, label)
        local handle = io.popen('ls -p "'..path..'"')
        if handle then
            for line in handle:lines() do
                local isDirectory = line:sub(-1) == "/"
                local cleanName = isDirectory and line:sub(1, -2) or line
                local ext = cleanName:match("[^%.]+$")
                if isDirectory or (ext and validExtensions[ext:lower()]) then
                    if fileMap[cleanName] then
                        files[fileMap[cleanName]].sourceLabel = "SD1-SD2"
                        files[fileMap[cleanName]].secondaryPath = path .. line
                    else
                        table.insert(files, {name = cleanName, isDir = isDirectory, fullPath = path .. line, sourceLabel = label})
                        fileMap[cleanName] = #files
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

function loadPreview()
    currentImage = nil
    if #files == 0 or files[selectedIndex].isDir then return end
    
    local baseName = files[selectedIndex].name:gsub("%..-$", "")
    local imgFile = muosArtPath .. baseName .. ".png"
    
    local f = io.open(imgFile, "r")
    if f then
        f:close()
        currentImage = love.graphics.newImage(imgFile)
    end
end

local function saveHistory()
    local dataDir = love.filesystem.getSource() .. "/data"
    local f = io.open(dataDir .. "/played_roms.txt", "w")
    if f then
        for path, _ in pairs(playedRoms) do
            f:write(path .. "\n")
        end
        f:close()
    end
end

local function getTargetSDPath(currentPath)
    if currentPath:find("/mnt/mmc") then
        return currentPath:gsub("/mnt/mmc", "/mnt/sdcard"), "SD2"
    elseif currentPath:find("/mnt/sdcard") then
        return currentPath:gsub("/mnt/sdcard", "/mnt/mmc"), "SD1"
    end
    return nil, nil
end

local function resolveSecondary(path)
    local p2 = nil
    if path:find("/mnt/mmc") then
        p2 = path:gsub("/mnt/mmc", "/mnt/sdcard")
    elseif path:find("/mnt/sdcard") then
        p2 = path:gsub("/mnt/sdcard", "/mnt/mmc")
    end
    
    if p2 and os.execute('test -d "' .. p2 .. '"') then return p2 end
    return nil
end

local function saveLastPlayed(path)
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/last_played.txt", "w")
    if f then
        f:write(path)
        f:close()
    end
end

local function addToHistory(path)
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

local function log(message)
    local logPath = love.filesystem.getSource() .. "/data/log/filebernic.log"
    local f = io.open(logPath, "a")
    if f then
        f:write("[LUA DEBUG] " .. os.date() .. ": " .. message .. "\n")
        f:close()
    end
end

local function saveAppState()
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/app_state.json", "w")
    if f then
        local stateToSave = {
            romPath = romPath,
            selectedIndex = selectedIndex,
            hideEmpty = hideEmpty
        }
        f:write(json.encode(stateToSave))
        f:close()
    end
end

function love.quit()
    saveAppState()
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
    
    iconFolder = love.graphics.newImage("assets/folder.png")
    iconRom = love.graphics.newImage("assets/roms.png")
    
    buttonIcons = {
        a = love.graphics.newImage("assets/button/gamepad/small/a.png"),
        b = love.graphics.newImage("assets/button/gamepad/small/b.png"),
        y = love.graphics.newImage("assets/button/gamepad/small/y.png"),
        x = love.graphics.newImage("assets/button/gamepad/small/x.png"),
        select = love.graphics.newImage("assets/button/gamepad/small/select.png"),
        start = love.graphics.newImage("assets/button/gamepad/small/start.png")
    }

    -- Load theme and fonts
    theme = require "theme"
    fontList = theme.fonts.list
    fontTitle = theme.fonts.title
    fontSmall = theme.fonts.small
    fontMedium = theme.fonts.medium

    -- Cargar configuración guardada
    local f = io.open(love.filesystem.getSource() .. "/data/app_state.json", "r")
    if f then
        local content = f:read("*all")
        f:close()
        local loadedState = json.decode(content)
        if loadedState then
            if loadedState.hideEmpty ~= nil then hideEmpty = loadedState.hideEmpty end
            if loadedState.romPath then romPath = loadedState.romPath end
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