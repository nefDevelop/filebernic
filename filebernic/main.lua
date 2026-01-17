-- Initialize globals early to prevent nil errors in modules capturing them at require time
DEBUG = true
scrollTimer = 0
keyRepeatTimer = 0
inputCooldown = 0
menuAnim = 0
jumpPanelAnim = 0
jumpLetter = ""
searchQuery = ""
jumpLetterTimer = 0
pageSize = 0
viewMode = 1
launchMode = "Juego Unico"
hideEmpty = false
markPlayed = true

local json = require "libs.dkjson"
utils = require "utils"
Loader = require "loader"


State = require "state"
theme = require "theme"
State.theme = theme

local draw = require "drawing"
local update = require "update"
local input = require "input"


filesystem = require "filesystem"

function getSystemIcon(sysName)
    log("getSystemIcon called with sysName: " .. tostring(sysName))
    if not sysName then return nil end
    local variants = utils.getSystemVariants(sysName)

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
    log("getSystemContentIcon called with sysName: " .. tostring(sysName))
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
    log("jumpToNextLetter called")
    if #State.files == 0 then return end
    local current = State.files[State.selectedIndex].name:sub(1,1):upper()
    for i = State.selectedIndex + 1, #State.files do
        local c = State.files[i].name:sub(1,1):upper()
        if c ~= current then
            State.selectedIndex = i
            State.jumpLetter = c
            return
        end
    end
    State.selectedIndex = #State.files
    State.jumpLetter = State.files[State.selectedIndex].name:sub(1,1):upper()
end

function jumpToPrevLetter()
    log("jumpToPrevLetter called")
    if #State.files == 0 then return end
    local current = State.files[State.selectedIndex].name:sub(1,1):upper()
    local prevLetterIdx = nil
    for i = State.selectedIndex - 1, 1, -1 do
        local c = State.files[i].name:sub(1,1):upper()
        if c ~= current then
            prevLetterIdx = i
            break
        end
    end
    
    if prevLetterIdx then
        local targetChar = State.files[prevLetterIdx].name:sub(1,1):upper()
        for i = prevLetterIdx - 1, 1, -1 do
            local c = State.files[i].name:sub(1,1):upper()
            if c ~= targetChar then
                State.selectedIndex = i + 1
                State.jumpLetter = targetChar
                return
            end
        end
        State.selectedIndex = 1
    else
        State.selectedIndex = 1
    end
    State.jumpLetter = State.files[State.selectedIndex].name:sub(1,1):upper()
end

function updateSystemPaths()
    log("updateSystemPaths called")
    State.systemName, State.muosArtPath, State.muosTextPath, State.muosPreviewPath, State.currentSystemIcon, State.currentSystemContentIcon = filesystem.updateSystemPaths(State.systemName, State.romPath, log, love.graphics.newImage)
    -- Sync globals
    systemName = State.systemName
    muosArtPath = State.muosArtPath
    muosTextPath = State.muosTextPath
    muosPreviewPath = State.muosPreviewPath
    currentSystemIcon = State.currentSystemIcon
    currentSystemContentIcon = State.currentSystemContentIcon
end

function refreshFiles()
    log("refreshFiles called")
    State.files, State.selectedFilesCount, State.selectedIndex, State.allFiles = filesystem.refreshFiles(updateSystemPaths, State.files, State.selectedFilesCount, State.launchMode, State.hideEmpty, State.validExtensions, State.romPath, State.secondaryPath, State.selectedIndex, State.allFiles)
    -- Sync globals
    files = State.files
    selectedFilesCount = State.selectedFilesCount
    selectedIndex = State.selectedIndex
    allFiles = State.allFiles
    loadPreview()
end

function createMergedVirtualRoot(pathToSelect)
    log("createMergedVirtualRoot called")
    State.files, State.isVirtualRoot, State.romPath, State.secondaryPath, State.selectedIndex, State.allFiles = filesystem.createMergedVirtualRoot(State.files, State.isVirtualRoot, State.romPath, State.secondaryPath, State.selectedIndex, State.launchMode, State.romIndex, State.hideEmpty, State.validExtensions, getSystemIcon, State.allFiles, pathToSelect)
    -- Sync globals
    files = State.files
    isVirtualRoot = State.isVirtualRoot
    romPath = State.romPath
    secondaryPath = State.secondaryPath
    selectedIndex = State.selectedIndex
    allFiles = State.allFiles
    
    State.selectedFilesCount = #State.files
    selectedFilesCount = State.selectedFilesCount
    loadPreview()
end

function getTargetSDPath(path)
    log("getTargetSDPath called")
    return filesystem.getTargetSDPath(path, State.config)
end

function resolveSecondary(path)
    log("resolveSecondary called")
    return filesystem.resolveSecondary(path)
end

function deleteGameMedia(path)
    log("deleteGameMedia called")
    filesystem.deleteGameMedia(path, State.muosArtPath, State.muosTextPath, State.muosPreviewPath)
end

function removeFromIndex(path)
    log("removeFromIndex called")
    if State.romIndex then
        State.romIndex = filesystem.removeFromIndex(path, State.romIndex, json.encode, love.filesystem.getSource, io.open)
    end
end

function saveHistory()
    log("saveHistory called")
    filesystem.saveHistory(State.playedRoms)
end

function saveLastPlayed(path)
    log("saveLastPlayed called")
    filesystem.saveLastPlayed(path)
end

function addToHistory(path)
    log("addToHistory called")
    State.playedRoms = filesystem.addToHistory(path, State.playedRoms)
end

function findSaveFiles(item)
    log("findSaveFiles called")
    State.saveFiles = filesystem.findSaveFiles(item)
end

function performCleanupScan()
    log("performCleanupScan called")
    State.cleanupData = filesystem.performCleanupScan(State.cleanupData, State.romPath, State.validExtensions, State.muosArtPath, State.muosPreviewPath, State.muosTextPath)
    if State.cleanupData and not State.cleanupData.orphanedImages then State.cleanupData.orphanedImages = {} end
    -- Sync global
    cleanupData = State.cleanupData
end

function filterFiles()
    log("filterFiles called")
    State.files = {}
    for _, item in ipairs(State.allFiles) do
        if item.name:lower():find(State.searchQuery:lower(), 1, true) then
            table.insert(State.files, item)
        end
    end
    State.selectedIndex = 1
end

function State.loadConfig()
    log("State.loadConfig called")
    local configPath = love.filesystem.getSource() .. "/data/config.json"
    local f = io.open(configPath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local loaded = json.decode(content)
        if loaded then
            for k, v in pairs(loaded) do State.config[k] = v end
        end
    else
        f = io.open(configPath, "w")
        if f then
            f:write(json.encode(State.config))
            f:close()
        end
    end
    State.scraperApi = State.config.scraperApi
end

local scraper = require "scraper"

function startScraping()
    log("startScraping called")
    local item = State.files[State.selectedIndex]
    if not item then return end
    
    log("Starting interactive scrape for: " .. item.name)
    
    State.state = "SCRAPING_IN_PROGRESS"
    love.graphics.present() -- Forzar dibujado
    
    -- Limpiar temporales
    os.execute("rm -f /tmp/scraper_*.png")
    
    State.scraperResults = scraper.getScrapeResults(item, State.config, log, State.systemName)
    State.scraperSelection = 1
    State.state = "SCRAPER_RESULTS"
end

function performBatchScrape(items)
    log("performBatchScrape called")
    State.state = "BATCH_SCRAPING"
    State.scraperProgress = { current = 0, total = #items, currentName = "", successes = 0, failures = 0 }
    
    -- Limpiar temporales
    os.execute("rm -f /tmp/scraper_*.png")
    
    State.scraperCoroutine = coroutine.create(function()
        for i, item in ipairs(items) do
            State.scraperProgress.current = i
            State.scraperProgress.currentName = item.name
            coroutine.yield()
            
            local results = scraper.getScrapeResults(item, State.config, log, State.systemName)
            if results and #results > 0 and not results[1].error then
                filesystem.saveScrapeResult(item, results[1], State.muosArtPath, State.muosTextPath, State.muosPreviewPath, log)
                State.scraperProgress.successes = State.scraperProgress.successes + 1
            else
                State.scraperProgress.failures = State.scraperProgress.failures + 1
            end
        end
        State.state = "LIST"
        State.files, State.selectedFilesCount, State.selectedIndex, State.allFiles = filesystem.refreshFiles(updateSystemPaths, State.files, State.selectedFilesCount, State.launchMode, State.hideEmpty, State.validExtensions, State.romPath, State.secondaryPath, State.selectedIndex, State.allFiles, loadPreview)
    end)
end

function saveSelectedArt()
    log("saveSelectedArt called")
    local result = State.scraperResults[State.scraperSelection]
    local item = State.files[State.selectedIndex]
    filesystem.saveScrapeResult(item, result, State.muosArtPath, State.muosTextPath, State.muosPreviewPath, log)
    
    State.state = "LIST"
    loadPreview()
end

function loadPreview()
    log("loadPreview called")
    -- Clear current preview data immediately to show loading state
    State.currentImage = nil
    State.currentScreenshot = nil
    State.currentYear = nil
    State.currentDescription = ""
    
    local item = State.focusedItem
    if not item then
        if #State.files == 0 then return end
        item = State.files[State.selectedIndex]
    end
    
    if not item or item.isDir then return end
    
    -- Asegurar que el sistema detectado corresponde al archivo seleccionado (para lista mixta)
    State.systemName, State.muosArtPath, State.muosTextPath, State.muosPreviewPath = filesystem.updateSystemForFile(item, State.romPath, State.systemName, State.muosArtPath, State.muosTextPath, State.muosPreviewPath)
    
    local baseName = item.name:gsub("%..-$", "")
    local itemSystemName = utils.getSystemNameForItem(item)

    if itemSystemName then
        local artPathForSystem = filesystem.getArtPathForSystem(itemSystemName)
        local textPathForSystem = artPathForSystem:gsub("/box/", "/text/")
        local previewPathForSystem = artPathForSystem:gsub("/box/", "/preview/")

        -- Boxart
        local imgFile = artPathForSystem .. baseName .. ".png"
        loader:request(imgFile) -- Request, will be fetched by update.lua

        -- Screenshot
        local scrFile = previewPathForSystem .. baseName .. ".png"
        loader:request(scrFile) -- Request, will be fetched by update.lua
        
        -- Description
        local txtFile = textPathForSystem .. baseName .. ".txt"
        loader:request(txtFile) -- Request, will be fetched by update.lua
        
        -- Year
        local yearFile = textPathForSystem .. baseName .. ".year"
        loader:request(yearFile) -- Request, will be fetched by update.lua
    end
end



function log(message)
    if not DEBUG then return end
    local logPath = love.filesystem.getSource() .. "/data/log/filebernic.log"
    print("[CONSOLE] " .. message)
    local f = io.open(logPath, "a")
    if f then
        f:write("[LUA DEBUG] " .. os.date() .. ": " .. message .. "\n")
        f:close()
    end
end

function State.loadAppState()
    log("State.loadAppState called")
    local statePath = love.filesystem.getSource() .. "/data/app_state.json"
    local f = io.open(statePath, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local loaded, _, err = json.decode(content)
        if loaded then
            -- Restore state, with defaults
            -- The loaded romPath is virtual, like "ROMS/GB". createMergedVirtualRoot will use it to select the system.
            State.romPath = loaded.romPath
            State.selectedIndex = loaded.selectedIndex or 1
            State.hideEmpty = loaded.hideEmpty == true -- ensure boolean
            State.markPlayed = loaded.markPlayed == nil and true or loaded.markPlayed -- default to true
            State.viewMode = loaded.viewMode or 1
            State.launchMode = loaded.launchMode or "Juego Unico"
        else
            log("Could not decode app_state.json: " .. (err or "unknown error"))
        end
    else
        -- Set defaults if no state file exists
        State.hideEmpty = false
        State.markPlayed = true
        State.viewMode = 1
        State.launchMode = "Juego Unico"
    end
end

function State.saveAppState()
    log("State.saveAppState called")
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/app_state.json", "w")
    if f then
        -- Normalizar ruta para guardar (convertir a virtual ROMS/...)
        local savedPath = State.romPath
        if savedPath:find("/mnt/mmc/ROMS/") then
            savedPath = savedPath:gsub("/mnt/mmc/ROMS/", "ROMS/")
        elseif savedPath:find("/mnt/sdcard/ROMS/") then
            savedPath = savedPath:gsub("/mnt/sdcard/ROMS/", "ROMS/")
        elseif savedPath:find("Simulador_SD") then
            savedPath = savedPath:gsub(".*Simulador_SD/", "ROMS/")
        end

        local stateToSave = {
            romPath = savedPath,
            selectedIndex = State.selectedIndex,
            hideEmpty = State.hideEmpty,
            markPlayed = State.markPlayed,
            viewMode = State.viewMode,
            launchMode = State.launchMode
        }
        f:write(json.encode(stateToSave))
        f:close()
    end
end

function love.errorhandler(msg)
    if not DEBUG then return end
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
    State.saveAppState()
    if loader then
        loader:quit()
    end
    
    if not DEBUG then return end
    -- Log content of art folders on exit
    if State.muosArtPath and State.muosArtPath ~= "" then
        log("Listing Boxart folder content: " .. State.muosArtPath)
        local h = io.popen('ls -1 "'..State.muosArtPath..'"')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
    
    if State.muosPreviewPath and State.muosPreviewPath ~= "" then
        log("Listing Preview folder content: " .. State.muosPreviewPath)
        local h = io.popen('ls -1 "'..State.muosPreviewPath..'"')
        if h then 
            local content = h:read("*a")
            log(content and content ~= "" and content or "[Empty]") 
            h:close() 
        end
    end
end

function love.load()
    log("love.load called")
    loader = Loader:new()
    if not State.config then State.config = {} end
    State.loadConfig()
    State.loadAppState()
    
    -- Sync configuration globals
    launchMode = State.launchMode
    viewMode = State.viewMode
    hideEmpty = State.hideEmpty
    markPlayed = State.markPlayed
    saveAppState = State.saveAppState
    
    -- Initialize fonts if not present
    if not State.fontTitle then
        if theme.fonts then
            State.fontTitle = theme.fonts.title
            State.fontMedium = theme.fonts.medium
            State.fontSmall = theme.fonts.small
            State.fontList = theme.fonts.list
            State.fontHuge = theme.fonts.huge
        else
            State.fontTitle = love.graphics.newFont(24)
            State.fontMedium = love.graphics.newFont(18)
            State.fontSmall = love.graphics.newFont(14)
            State.fontList = love.graphics.newFont(20)
            State.fontHuge = love.graphics.newFont(72)
        end
    end
    fontTitle = State.fontTitle
    fontMedium = State.fontMedium
    fontSmall = State.fontSmall
    fontList = State.fontList
    fontHuge = State.fontHuge
    
    local function safeLoad(path)
        if love.filesystem.getInfo(path) then
            return love.graphics.newImage(path)
        else
            log("Asset missing: " .. path)
            return love.graphics.newImage(love.image.newImageData(1,1))
        end
    end
    
    if not State.buttonIcons then
        State.buttonIcons = {
            a = safeLoad("assets/buttons/a.png"),
            b = safeLoad("assets/buttons/b.png"),
            x = safeLoad("assets/buttons/x.png"),
            y = safeLoad("assets/buttons/y.png"),
            start = safeLoad("assets/buttons/start.png"),
            select = safeLoad("assets/buttons/select.png")
        }
    end
    buttonIcons = State.buttonIcons
    
    if not State.iconFolder then 
        if love.filesystem.getInfo("assets/icons/folder.png") then
            State.iconFolder = safeLoad("assets/icons/folder.png")
        else
            State.iconFolder = safeLoad("assets/icons/folder.png")
        end
    end
    iconFolder = State.iconFolder
    if not State.iconRom then 
        if love.filesystem.getInfo("assets/icons/rom.png") then
            State.iconRom = safeLoad("assets/icons/rom.png")
        else
            State.iconRom = safeLoad("assets/icons/rom.png")
        end
    end
    iconRom = State.iconRom
    
    -- Initialize globals used in update/drawing to prevent nil errors
    menuAnim = 0
    State.menuAnim = 0
    jumpPanelAnim = 0
    State.jumpPanelAnim = 0
    jumpLetter = ""
    State.jumpLetter = ""
    searchQuery = ""
    State.searchQuery = ""
    jumpLetterTimer = 0
    
    inputCooldown = 0
    State.jumpLetterTimer = 0
    scrollTimer = 0
    State.scrollTimer = 0
    
    cleanupData = { scanned = false, scanning = false, progress = 0, orphans = {}, duplicates = {}, orphanedImages = {} }
    State.cleanupData = cleanupData
    
    layout = State.layout
    
    menuOptions = State.menuOptions
    menuTitle = State.menuTitle
    menuMessage = State.menuMessage
    
    scraperResults = State.scraperResults
    scraperProgress = State.scraperProgress
    scraperSelection = State.scraperSelection
    
    saveFiles = State.saveFiles
    saveManagerSelection = State.saveManagerSelection
    
    -- Initialize scroll and list state to prevent nil errors in update
    State.scroll = 0
    State.scrollTo = 0
    State.selectedFilesCount = 0
    pageSize = 0 -- Default, will be calculated in drawing.lua
    State.pageSize = 0
    
    -- Initialize core state machine and UI variables
    state = "LIST"
    State.state = "LIST" -- Global mirror for modules using State table
    menuSelection = 1
    State.menuSelection = 1
    
    -- Initialize help data to prevent crashes
    State.helpData = { DEFAULT = {} }
    
    createMergedVirtualRoot(State.romPath)
end

function love.update(dt)
    log("love.update called with dt: " .. tostring(dt))
    -- Safety check for globals to prevent crashes
    if not scrollTimer then scrollTimer = 0 end
    if not keyRepeatTimer then keyRepeatTimer = 0 end
    if not inputCooldown then inputCooldown = 0 end
    update(dt)
end

function love.draw()
    log("love.draw called")
    draw()
end

function love.keypressed(key)
    log("love.keypressed called with key: " .. tostring(key))
    input.keypressed(key)
end

function love.gamepadpressed(joystick, button)
    log("love.gamepadpressed called with button: " .. tostring(button))
    input.gamepadpressed(joystick, button)
end

function love.joystickpressed(joystick, button)
    log("love.joystickpressed called with button: " .. tostring(button))
    input.joystickpressed(joystick, button)
end

function love.textinput(t)
    log("love.textinput called with text: " .. tostring(t))
    input.textinput(t)
end