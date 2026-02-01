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

    State.fadeShader = love.graphics.newShader([[
        extern vec4 backgroundColor;
        extern float fadeWidth;
        extern float imageXCoord;
        extern float imageWidthCoord;
        extern float imageOpacity;

        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec4 pixel = Texel(texture, texture_coords);
            
            // Adjust pixel opacity first
            pixel.a *= imageOpacity;

            float distFromLeft = screen_coords.x - imageXCoord;
            float alphaFactor = clamp(distFromLeft / fadeWidth, 0.0, 1.0);
            
            // Blend pixel color with background color based on alphaFactor
            pixel.rgb = mix(backgroundColor.rgb, pixel.rgb, alphaFactor);
            
            // Final pixel alpha is a blend of background alpha and pixel alpha, weighted by alphaFactor
            // Not directly fading to background alpha, but to transparent if pixel alpha is 0
            pixel.a = mix(backgroundColor.a, pixel.a, alphaFactor); 
            
            return pixel;
        }
    ]])
    fadeShader = State.fadeShader
    
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