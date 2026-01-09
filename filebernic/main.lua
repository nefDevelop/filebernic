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
local systemName = "GBA"
local romPath = ""
local secondaryPath = nil
local muosArtPath = ""
local files = {}
local selectedIndex = 1
local state = "LIST" -- LIST, POST_GAME, DELETE_MENU
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
local fontList, fontTitle, fontSmall, fontMedium
local menuOptions = {"Borrar"}
local menuSelection = 1
local menuTitle = ""
local menuMessage = ""

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
    
    -- Si la carpeta está vacía (solo contiene ".."), añadir un mensaje
    if #files == 1 and files[1].name == ".." then
        table.insert(files, {name = "[Directorio vacío]", isDir = false, empty = true})
    end

    loadPreview()
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
    
    -- This logic seems to be for backwards compatibility or a different launch method.
    -- We are now using the launch script to define the path.
    -- For now, we'll keep the simulation path for local testing.
    local f = io.open("/mnt/mmc", "r")
    if f then
        f:close()
        -- Running on a real device
        if arg and arg[4] then systemName = arg[4] end
        muosArtPath = "/mnt/mmc/MUOS/info/catalogue/" .. systemName .. "/boxart/"
    else
        -- Running in simulation on Fedora
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local simPath = cwd .. "/../Simulador_SD/"
        muosArtPath = simPath .. "MUOS/info/catalogue/"
    end
    
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

    fontList = love.graphics.newFont(18)
    fontTitle = love.graphics.newFont(24)
    fontSmall = love.graphics.newFont(12)
    fontMedium = love.graphics.newFont(16)

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
end
function love.update(dt)
    if inputCooldown > 0 then inputCooldown = inputCooldown - dt end
    
    if launching then
        launchTimer = launchTimer + dt
        if launchTimer > 0.1 then -- Pequeña espera para ver el color verde
            local f = io.open("/tmp/launch_rom", "w")
            if f then f:write(lastPlayedRom) f:close() end
            saveAppState()
            love.event.quit()
            os.exit(0)
        end
        return
    end

    if pendingLoad then
        timer = timer + dt
        if timer >= delay then
            loadPreview()
            pendingLoad = false
            timer = 0
        end
    end

    if state ~= "LIST" then return end

    -- Control de repetición de tecla manual para el scroll
    local is_down_pressed = love.keyboard.isDown('down') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpdown'))
    local is_up_pressed = love.keyboard.isDown('up') or (love.joystick.getJoystickCount() > 0 and love.joystick.getJoysticks()[1]:isGamepadDown('dpup'))

    local moved = false
    if is_down_pressed then
        if keyHeld ~= 'down' then
            -- Primera pulsación
            selectedIndex = math.min(#files, selectedIndex + 1)
            keyHeld = 'down'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                selectedIndex = math.min(#files, selectedIndex + 1)
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    elseif is_up_pressed then
        if keyHeld ~= 'up' then
            -- Primera pulsación
            selectedIndex = math.max(1, selectedIndex - 1)
            keyHeld = 'up'
            scrollTimer = initialScrollDelay
            moved = true
        else
            -- Tecla mantenida
            scrollTimer = scrollTimer - dt
            if scrollTimer <= 0 then
                selectedIndex = math.max(1, selectedIndex - 1)
                scrollTimer = subsequentScrollDelay
                moved = true
            end
        end
    else
        keyHeld = nil
    end

    if moved then
        pendingLoad = true
        timer = 0
    end
end

function drawBottomBar()
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(0.9, 0.9, 0.9)
    
    local x = 20
    local y = h - 27
    local scale = 0.8

    local function drawHint(icon, text)
        love.graphics.draw(icon, x, y, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, y + 2)
        x = x + love.graphics.getFont():getWidth(text) + 20
    end

    if state == "LIST" then
        drawHint(buttonIcons.a, "Ok")
        drawHint(buttonIcons.b, "Back")
        drawHint(buttonIcons.y, "Menu")
        drawHint(buttonIcons.x, "Select")
        drawHint(buttonIcons.start, "Opciones")
        -- Select button with offset
        local icon = buttonIcons.select
        local text = "Salir"
        love.graphics.draw(icon, x, y + 5, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, y + 2)
    elseif state == "DELETE_MENU" or state == "POST_GAME" then
        drawHint(buttonIcons.a, "Confirmar")
        drawHint(buttonIcons.b, "Cancelar")
    end
end

function drawSideMenu()
    local w, h = love.graphics.getDimensions()
    
    -- Overlay oscuro
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, w/2, h)

    -- Panel lateral
    love.graphics.setColor(0.15, 0.15, 0.17, 0.98)
    love.graphics.rectangle("fill", w/2, 0, w/2, h)
    
    -- Línea separadora
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.line(w/2, 0, w/2, h)

    -- Título
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontTitle)
    love.graphics.printf(menuTitle, w/2 + 20, 40, w/2 - 40, "left")

    -- Mensaje
    local startY = 90
    if menuMessage and menuMessage ~= "" then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(menuMessage, w/2 + 20, 80, w/2 - 40, "left")
        local width, wrappedtext = fontMedium:getWrap(menuMessage, w/2 - 40)
        startY = 80 + (#wrappedtext * fontMedium:getHeight()) + 30
    end

    -- Opciones
    love.graphics.setFont(fontList)
    for i, option in ipairs(menuOptions) do
        local y = startY + (i-1) * 40
        if i == menuSelection then
            love.graphics.setColor(0.2, 0.6, 1)
            love.graphics.rectangle("fill", w/2 + 10, y - 5, w/2 - 20, 30, 5)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
        end
        love.graphics.print(option, w/2 + 20, y)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.clear(0.1, 0.1, 0.12)
    
    -- Layout dinámico
    if currentImage then
        layout.selWidth = 300
    else
        layout.selWidth = w - 40
    end
    layout.scrollbarX = 15 + layout.selWidth

    -- Título
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(fontTitle)
    love.graphics.printf("FileBernic Rom Manager", 0, 15, w, "center")
    
    -- Path actual
    love.graphics.setFont(fontSmall)
    local displayPath = isVirtualRoot and "Todos los Sistemas" or romPath
    love.graphics.printf(displayPath, 0, 45, w, "center")

    -- Lista de Archivos
    love.graphics.setFont(fontList)
    local startLine = math.max(1, selectedIndex - 7)
    for i = startLine, math.min(#files, startLine + pageSize) do
        local y = layout.listY + (i - startLine) * layout.rowHeight
        local item = files[i]
        
        -- Verificar si es el último juego jugado
        local checkPath = item.fullPath or (romPath .. item.name)
        local isLastPlayed = (not item.isDir) and playedRoms[checkPath]
        
        if i == selectedIndex then
            if isLastPlayed then
                love.graphics.setColor(0.2, 0.7, 0.3) -- Verde para el jugado
            else
                love.graphics.setColor(0.2, 0.4, 0.8) -- Azul normal
            end
            love.graphics.rectangle("fill", 15, y - 4, layout.selWidth, layout.selHeight, 4)
            love.graphics.setColor(0.2, 0.6, 1) -- Azul para texto/icono seleccionado
        else
            if isLastPlayed then
                love.graphics.setColor(0.2, 0.7, 0.3, 0.4) -- Verde transparente si no está seleccionado
                love.graphics.rectangle("fill", 15, y - 4, layout.selWidth, layout.selHeight, 4)
            end
            love.graphics.setColor(0.8, 0.8, 0.8) -- Color para el texto/icono siguiente
        end

        
        if item.empty then
            love.graphics.setColor(0.5, 0.5, 0.5) -- Color gris para el mensaje
            love.graphics.printf(item.name, 55, y, layout.selWidth - 10, "left")
        else
            if item.selected then
                love.graphics.setColor(0.2, 0.6, 1) -- Azul para seleccionados
            end
            
            love.graphics.draw(item.isDir and iconFolder or iconRom, 25, y, 0, layout.iconScale, layout.iconScale)
            local maxChars = math.floor(layout.selWidth / 11)
            
            if i == selectedIndex then
                -- Simular negrita dibujando dos veces con offset
                love.graphics.print(item.name:sub(1, maxChars), 55, y)
                love.graphics.print(item.name:sub(1, maxChars), 56, y)
            else
                love.graphics.print(item.name:sub(1, maxChars), 55, y)
            end

            if item.sourceLabel then
                love.graphics.printf(item.sourceLabel, 15, y, layout.selWidth - 10, "right")
            else
                local label = ""
                if romPath:find("/mnt/mmc") then label = "SD1"
                elseif romPath:find("/mnt/sdcard") then label = "SD2" end
                if label ~= "" then love.graphics.printf(label, 15, y, layout.selWidth - 10, "right") end
            end
        end
    end

    -- Scrollbar
    drawScrollbar()

    -- Boxart
    if currentImage then
        local scale = math.min(layout.boxartMaxW/currentImage:getWidth(), layout.boxartMaxH/currentImage:getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(currentImage, 340, layout.listY, 0, scale, scale)
    end

    if state == "OPTIONS_MENU" or state == "DELETE_MENU" then
        drawSideMenu()
    end

    -- Barra de estado
    drawBottomBar()
end

function drawScrollbar()
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", layout.scrollbarX, layout.listY, 4, layout.scrollbarH)
    if #files > 1 then
        local h = layout.scrollbarH / (#files / 14)
        local y = layout.listY + ((selectedIndex - 1) / (#files - 1)) * (layout.scrollbarH - h)
        love.graphics.setColor(0.3, 0.6, 1)
        love.graphics.rectangle("fill", layout.scrollbarX, y, 4, math.max(10, h))
    end
end

function love.keypressed(key)
    if inputCooldown > 0 then return end

    local currentItem = files[selectedIndex]
    if currentItem and currentItem.empty then
        if key == "backspace" then -- Allow going back from an empty directory
            local parent = romPath:gsub("[^/]+/$", "")
            if romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" then
                 createMergedVirtualRoot()
                 return
            end
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            if romPath == cwd .. "/../Simulador_SD/" then
                 createMergedVirtualRoot()
                 return
            end
            romPath = parent
            secondaryPath = resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.3
        else
            return -- Ignore other key presses for empty directory message
        end
    end

    if state == "OPTIONS_MENU" then
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(#menuOptions, menuSelection + 1)
        elseif key == "return" or key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    menuTitle = "Confirmar Borrado"
                    menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
                    menuOptions = {"Borrar", "Cancelar"}
                    menuSelection = 2
                    state = "DELETE_MENU"
                elseif not isVirtualRoot and files[selectedIndex] and (not files[selectedIndex].isDir or files[selectedIndex].name ~= "..") then
                    itemToDelete = files[selectedIndex]
                    menuTitle = "Confirmar Borrado"
                    menuMessage = "¿Borrar este archivo?\n" .. itemToDelete.name
                    menuOptions = {"Borrar", "Cancelar"}
                    menuSelection = 2
                    state = "DELETE_MENU"
                end
            elseif menuOptions[menuSelection] == "Borrar de SD1" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/mmc") and item.fullPath or item.secondaryPath
                os.remove(pathToDelete)
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                refreshFiles()
                state = "LIST"
            elseif menuOptions[menuSelection] == "Borrar de SD2" then
                local item = files[selectedIndex]
                local pathToDelete = item.fullPath:find("/mnt/sdcard") and item.fullPath or item.secondaryPath
                os.remove(pathToDelete)
                if playedRoms[pathToDelete] then playedRoms[pathToDelete] = nil saveHistory() end
                refreshFiles()
                state = "LIST"
            elseif menuOptions[menuSelection]:match("Ocultar vacíos") then
                hideEmpty = not hideEmpty
                menuOptions[menuSelection] = "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF")
                if isVirtualRoot then createMergedVirtualRoot() end
            elseif menuOptions[menuSelection]:match("Copiar") or menuOptions[menuSelection]:match("Mover") then
                local isMove = menuOptions[menuSelection]:match("Mover")
                local targetDir, _ = getTargetSDPath(romPath)
                
                if targetDir then
                    os.execute('mkdir -p "' .. targetDir .. '"')
                    
                    local function processItem(item)
                        local src = romPath .. item.name
                        local dst = targetDir .. item.name
                        local cmd = (isMove and 'mv "' or 'cp "') .. src .. '" "' .. dst .. '"'
                        os.execute(cmd)
                        if isMove and playedRoms[src] then
                            playedRoms[src] = nil
                        end
                    end

                    if selectedFilesCount > 0 then
                        for _, item in ipairs(files) do
                            if item.selected then processItem(item) end
                        end
                    else
                        processItem(files[selectedIndex])
                    end
                    
                    if isMove then saveHistory() end
                    refreshFiles()
                    state = "LIST"
                end
            end
            inputCooldown = 0.3
        elseif key == "backspace" or key == "tab" then
            state = "LIST"
            inputCooldown = 0.3
        end
        return
    end

    if state == "DELETE_MENU" then
        if key == "up" then
            menuSelection = math.max(1, menuSelection - 1)
        elseif key == "down" then
            menuSelection = math.min(#menuOptions, menuSelection + 1)
        elseif key == "return" or key == "space" or key == "kpenter" then
            if menuOptions[menuSelection] == "Borrar" then
                if selectedFilesCount > 0 then
                    for _, item in ipairs(files) do
                        if item.selected then
                            local fullPath = romPath .. item.name
                            os.remove(fullPath)
                            if playedRoms[fullPath] then
                                playedRoms[fullPath] = nil
                            end
                        end
                    end
                    saveHistory()
                    refreshFiles()
                    itemToDelete = nil
                elseif itemToDelete then
                    os.remove(romPath .. itemToDelete.name)
                    if playedRoms[romPath .. itemToDelete.name] then
                        playedRoms[romPath .. itemToDelete.name] = nil
                        saveHistory()
                    end
                    -- Deselect to avoid errors, then refresh
                    selectedIndex = math.max(1, selectedIndex - 1)
                    refreshFiles()
                    itemToDelete = nil
                end
            end
            inputCooldown = 0.3
            state = "LIST"
        elseif key == "backspace" then -- Cancel
            itemToDelete = nil
            inputCooldown = 0.3
            state = "LIST"
        end
        return
    end

    if state == "POST_GAME" then
        if key == "return" or key == "space" or key == "kpenter" then -- 'a' button
            os.remove(lastPlayedRom) 
            state = "LIST" 
            inputCooldown = 0.3
            refreshFiles()
        elseif key == "backspace" then -- 'b' button
            state = "LIST" 
            inputCooldown = 0.3
        end
        return
    end

    if key == "left" then 
        selectedIndex = math.max(1, selectedIndex - pageSize)
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0
    elseif key == "right" then 
        selectedIndex = math.min(#files, selectedIndex + pageSize)
        pendingLoad = true
        inputCooldown = 0.2
        timer = 0
    elseif key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then -- 'a' button (Start envía return, lo ignoramos si hay gamepad)
        if #files == 0 then return end
        local item = files[selectedIndex]
        if item.isDir then
            if isVirtualRoot then
                romPath = item.fullPath
                secondaryPath = item.secondaryPath
                isVirtualRoot = false
                selectedIndex = 1
                refreshFiles()
                inputCooldown = 0.3
            else
                if item.name == ".." then
                    local newPath = romPath:gsub("[^/]+/$", "")
                    if newPath == "/mnt/mmc/ROMS/" or newPath == "/mnt/sdcard/ROMS/" then
                        createMergedVirtualRoot()
                        return
                    end
                    local cwd = love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then -- Simulator path check
                        createMergedVirtualRoot()
                        return
                    end
                    romPath = newPath
                    secondaryPath = resolveSecondary(romPath)
                else
                    romPath = romPath .. item.name .. "/"
                end
                selectedIndex = 1
                refreshFiles()
                inputCooldown = 0.3
            end
        else
            -- Launch ROM
            lastPlayedRom = isVirtualRoot and item.fullPath or romPath .. item.name
            saveLastPlayed(lastPlayedRom)
            addToHistory(lastPlayedRom)
            -- Iniciamos secuencia de lanzamiento (verde -> espera -> salir)
            launching = true
            launchTimer = 0
        end
    elseif key == "backspace" then -- 'b' button
        if isVirtualRoot then
            love.event.quit() -- Salir de la app desde el menú principal virtual
        else
            local parent = romPath:gsub("[^/]+/$", "")
            if romPath == "/mnt/mmc/ROMS/" or romPath == "/mnt/sdcard/ROMS/" then
                 createMergedVirtualRoot()
                 return
            end
            local cwd = love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            if romPath == cwd .. "/../Simulador_SD/" then
                 createMergedVirtualRoot()
                 return
            end
            romPath = parent
            secondaryPath = resolveSecondary(romPath)
            selectedIndex = 1
            refreshFiles()
            inputCooldown = 0.3
        end
    elseif key == "escape" then -- 'back' button on controller
        log("Select button pressed, quitting application.")
        love.event.quit() -- The script will handle the rest
    elseif key == "tab" then -- 'Y' button
        local item = files[selectedIndex]
        if item and not item.isDir then
            state = "OPTIONS_MENU"
            menuTitle = "Opciones de Archivo"
            if selectedFilesCount > 1 then
                menuMessage = "¿Borrar " .. selectedFilesCount .. " archivos seleccionados?"
            else
                menuMessage = item.name
            end
            menuSelection = 1
            menuOptions = {"Borrar"}
            
            if item.sourceLabel == "SD1-SD2" then
                menuOptions = {"Borrar de SD1", "Borrar de SD2"}
                -- Copy/Move disabled as it exists in both
            else
                local _, targetLabel = getTargetSDPath(item.fullPath)
                if targetLabel then
                    table.insert(menuOptions, "Copiar a " .. targetLabel)
                    table.insert(menuOptions, "Mover a " .. targetLabel)
                end
            end
            inputCooldown = 0.3
        end
    elseif key == "x" then
        local item = files[selectedIndex]
        if item and not item.isDir then
            item.selected = not item.selected
            if item.selected then
                selectedFilesCount = selectedFilesCount + 1
            else
                selectedFilesCount = selectedFilesCount - 1
            end
        end
    elseif key == "f1" then -- Start button
        state = "OPTIONS_MENU"
        menuTitle = "Configuración"
        menuMessage = ""
        menuSelection = 1
        menuOptions = {}
        table.insert(menuOptions, "Ocultar vacíos: " .. (hideEmpty and "ON" or "OFF"))
        inputCooldown = 0.3
    end
end

function love.gamepadpressed(joystick, button)
    if button == "a" then
        love.keypressed("kpenter") -- Usamos kpenter para mayor compatibilidad
    elseif button == "b" then
        love.keypressed("backspace")
    elseif button == "y" then
        love.keypressed("tab")
    elseif button == "x" then
        love.keypressed("x")
    elseif button == "dpleft" then
        love.keypressed("left")
    elseif button == "dpright" then
        love.keypressed("right")
    elseif button == "back" then
        love.keypressed("escape")
    elseif button == "start" then
        love.keypressed("f1")
    end
end