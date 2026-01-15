-- filebernic/state.lua
local State = {
    -- Variables de configuración y estado
    systemName = "",
    romPath = "",
    config = {
        scraperApi = "all", -- Opciones: "all", "libretro", "screenscraper", "thegamesdb"
        screenscraper_devid = "",
        screenscraper_password = "",
        thegamesdb_apikey = ""
    },
    scraperApi = "all",
    secondaryPath = nil,
    muosArtPath = "",
    muosTextPath = "",
    muosPreviewPath = "",
    files = {},
    selectedIndex = 1,
    state = "LIST", -- LIST, POST_GAME, DELETE_MENU, OPTIONS_MENU, SCRAPER_VIEW, SCRAPING_IN_PROGRESS, SCRAPER_RESULTS, SEARCH
    itemToDelete = nil,
    lastPlayedRom = "",
    playedRoms = {},
    iconFolder = nil,
    iconRom = nil,
    currentImage = nil,
    currentScreenshot = nil,
    currentYear = nil,
    buttonIcons = nil,
    currentSystemIcon = nil,
    currentSystemContentIcon = nil,
    currentDescription = "",
    timer = 0,
    delay = 0.05,
    pendingLoad = false,
    inputCooldown = 0, -- Temporizador para evitar doble input
    launching = false, -- Estado de lanzamiento
    launchTimer = 0,
    hideEmpty = false,
    markPlayed = true,
    pageSize = 13,
    viewMode = "LIST", -- "LIST" or "GRID"
    gridCols = 4,
    launchMode = "Folder", -- "Folder" or "Juego Unico"
    selectedFilesCount = 0,
    theme = nil,
    fontList = nil,
    fontTitle = nil,
    fontSmall = nil,
    fontMedium = nil,
    fontHuge = nil,
    menuOptions = {"Borrar"},
    menuSelection = 1,
    menuTitle = "",
    menuMessage = "",
    showHelp = false,
    closingMenu = false,
    closingHelp = false,
    fastScrollTimer = 0,
    jumpLetter = "",
    jumpPanelAnim = 0,
    helpData = {},
    menuAnim = 0,
    saveFiles = {},
    saveManagerSelection = 1,
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false },
    cleanupCoroutine = nil,
    scraperResults = {},
    scraperProgress = { current = 0, total = 0, currentName = "", successes = 0, failures = 0 },
    scraperCoroutine = nil,
    scraperSelection = 1,
    searchQuery = "",
    parentMenuData = nil,
    focusedItem = nil,
    allFiles = {},
    -- Indexing
    romIndex = nil,
    isIndexing = false,
    indexStateMessage = "",
    indexCoroutine = nil,
    -- Virtual Keyboard
    keyboardGrid = {
        {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0"},
        {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "SPACE"},
        {"A", "S", "D", "F", "G", "H", "J", "K", "L", "BACK"},
        {"Z", "X", "C", "V", "B", "N", "M", ".", "-", "OK"}
    },
    keyboardRow = 1,
    keyboardCol = 1,

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
    },

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
    },

    -- Variables para el control de scroll
    scrollTimer = 0,
    initialScrollDelay = 0.4,
    subsequentScrollDelay = 0.1,
    keyHeld = nil, -- ('up' o 'down')
    isVirtualRoot = false,
}

return State
