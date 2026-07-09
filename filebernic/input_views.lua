---@diagnostic disable: undefined-global
local M = {}
local filesystem = require "filesystem"
local utils = require "utils"
local helpers = require "input_helpers"

function M.SEARCH(key, global_state)
    if key == "up" then
        global_state.keyboardRow = math.max(1, global_state.keyboardRow - 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "down" then
        global_state.keyboardRow = math.min(#global_state.keyboardGrid, global_state.keyboardRow + 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "left" then
        global_state.keyboardCol = math.max(1, global_state.keyboardCol - 1)
        global_state.inputCooldown = 0.15
    elseif key == "right" then
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol + 1)
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then
        local char = global_state.keyboardGrid[global_state.keyboardRow][global_state.keyboardCol]
        if char == "OK" then
            global_state.state = "LIST"
            global_state.love.keyboard.setTextInput(false)
        elseif char == "BACK" then
            global_state.searchQuery = global_state.searchQuery:sub(1, -2)
            helpers.filterFiles(global_state)
        elseif char == "SPACE" then
            global_state.searchQuery = global_state.searchQuery .. " "
            helpers.filterFiles(global_state)
        else
            global_state.searchQuery = global_state.searchQuery .. char
            helpers.filterFiles(global_state)
        end
        global_state.inputCooldown = 0.2
    elseif key == "f" then
        global_state.state = "LIST"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    elseif key == "f2" then
        global_state.searchQuery = ""
        helpers.filterFiles(global_state)
        global_state.state = "LIST"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then
        global_state.state = "LIST"
        global_state.files = global_state.allFiles
        global_state.searchQuery = ""
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    end
end

function M.EDIT_TEXT(key, global_state)
    if key == "up" then
        global_state.keyboardRow = math.max(1, global_state.keyboardRow - 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "down" then
        global_state.keyboardRow = math.min(#global_state.keyboardGrid, global_state.keyboardRow + 1)
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol)
        global_state.inputCooldown = 0.15
    elseif key == "left" then
        global_state.keyboardCol = math.max(1, global_state.keyboardCol - 1)
        global_state.inputCooldown = 0.15
    elseif key == "right" then
        global_state.keyboardCol = math.min(#global_state.keyboardGrid[global_state.keyboardRow], global_state.keyboardCol + 1)
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" or key == "space" then
        local char = global_state.keyboardGrid[global_state.keyboardRow][global_state.keyboardCol]
        if char == "OK" then
            if global_state.textEditKey then
                global_state.config[global_state.textEditKey] = global_state.textToEdit
            else
                global_state.config.thegamesdb_apikey = global_state.textToEdit
            end
            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end

            global_state.state = "OPTIONS_MENU"
            global_state.love.keyboard.setTextInput(false)
        elseif char == "BACK" then
            global_state.textToEdit = global_state.textToEdit:sub(1, -2)
        elseif char == "SPACE" then
            global_state.textToEdit = global_state.textToEdit .. " "
        else
            global_state.textToEdit = global_state.textToEdit .. char
        end
        global_state.inputCooldown = 0.2
    elseif key == "escape" or key == "backspace" then
        global_state.state = "OPTIONS_MENU"
        global_state.love.keyboard.setTextInput(false)
        global_state.inputCooldown = 0.2
    end
end

function M.INFO_VIEW(key, global_state)
    if key == "backspace" or key == "b" or key == "escape" then
        if #global_state.menuStack > 0 then
            global_state.state = "OPTIONS_MENU"
        else
            global_state.closingMenu = true
        end
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    end
end

function M.SCRAPER_OPTIONS(key, global_state)
    local L = global_state.L
    if key == "return" or key == "kpenter" then
        local opt = global_state.menuOptions[global_state.menuSelection]
        local text = type(opt) == "table" and opt.text or opt

        if text == L.get("clean") then
            local item = global_state.files[global_state.selectedIndex]
            local baseName = item.name:gsub("%..-$", "")
            filesystem.safeRemove(global_state.muosArtPath .. baseName .. ".png", global_state.log)
            filesystem.safeRemove(global_state.muosTextPath .. baseName .. ".txt", global_state.log)
            filesystem.safeRemove(global_state.muosTextPath .. baseName .. ".year", global_state.log)
            filesystem.safeRemove(global_state.muosPreviewPath .. baseName .. ".png", global_state.log)
            global_state.preview.load(global_state, global_state.log, global_state.loader)
            global_state.state = "SCRAPER_VIEW"
        elseif opt.value == "tgdb" or opt.value == "libretro" or opt.value == "ss" then
            local api = global_state.config.scraperApi or "all"
            local tgdbOn = (api == "all" or api:find("thegamesdb"))
            local libretroOn = (api == "all" or api:find("libretro"))
            local ssOn = (api == "all" or api:find("screenscraper"))

            if opt.value == "tgdb" then tgdbOn = not tgdbOn end
            if opt.value == "libretro" then libretroOn = not libretroOn end
            if opt.value == "ss" then ssOn = not ssOn end

            if tgdbOn and libretroOn and ssOn then
                global_state.config.scraperApi = "all"
            else
                local newApi = {}
                if tgdbOn then table.insert(newApi, "thegamesdb") end
                if libretroOn then table.insert(newApi, "libretro") end
                if ssOn then table.insert(newApi, "screenscraper") end

                if #newApi == 0 then global_state.config.scraperApi = "none"
                else global_state.config.scraperApi = table.concat(newApi, ",") end
            end

            global_state.menuOptions[1].text = "TheGamesDB: " .. (tgdbOn and L.get("on") or L.get("off"))
            global_state.menuOptions[2].text = "Libretro: " .. (libretroOn and L.get("on") or L.get("off"))
            global_state.menuOptions[3].text = "ScreenScraper: " .. (ssOn and L.get("on") or L.get("off"))

            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end
        end
        global_state.inputCooldown = 0.2
    elseif key == "backspace" or key == "x" or key == "escape" then
        global_state.closingMenu = true
        global_state.log("Scraper Options exited")
        global_state.inputCooldown = 0.2
    end
end

function M.SCRAPER_VIEW(key, global_state)
    if key == "backspace" then
        if #global_state.menuStack > 0 then
            global_state.state = "OPTIONS_MENU"
        else
            global_state.state = "LIST"
        end
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    elseif key == "left" or key == "right" then
        if global_state.scraperSelection == 1 then global_state.scraperSelection = 2 else global_state.scraperSelection = 1 end
        global_state.inputCooldown = 0.15
    elseif key == "return" or key == "kpenter" then
        if global_state.scraperSelection == 1 then
            helpers.startScraping(global_state)
        elseif global_state.scraperSelection == 2 then
            global_state.state = "SCRAPER_OPTIONS"
            global_state.menuTitle = global_state.L.get("options")
            global_state.menuAnim = 0
            global_state.menuMessage = ""

            local api = global_state.config.scraperApi or "all"
            local tgdbOn = (api == "all" or api:find("thegamesdb"))
            local libretroOn = (api == "all" or api:find("libretro"))
            local ssOn = (api == "all" or api:find("screenscraper"))

            global_state.menuOptions = {
                {text = "TheGamesDB: " .. (tgdbOn and global_state.L.get("on") or global_state.L.get("off")), value = "tgdb"},
                {text = "Libretro: " .. (libretroOn and global_state.L.get("on") or global_state.L.get("off")), value = "libretro"},
                {text = "ScreenScraper: " .. (ssOn and global_state.L.get("on") or global_state.L.get("off")), value = "ss"},
                {text = global_state.L.get("clean")}
            }
            global_state.menuSelection = 1
            global_state.log("Menu opened: " .. global_state.menuTitle)
        end
        global_state.inputCooldown = 0.2
    end
end

function M.SCRAPER_RESULTS(key, global_state)
    local count = #global_state.scraperResults
    if count == 0 then
        if key == "backspace" then global_state.state = "SCRAPER_VIEW" end
        return
    end

    if key == "backspace" then
        global_state.state = "SCRAPER_VIEW"
        global_state.showHelp = false
        global_state.inputCooldown = 0.2
    elseif key == "f" or key == "tab" then
        if global_state.scraperFocus == "FRONT" then global_state.scraperFocus = "SCREEN"
        elseif global_state.scraperFocus == "SCREEN" then global_state.scraperFocus = "TEXT"
        else global_state.scraperFocus = "FRONT" end
        global_state.inputCooldown = 0.2
    elseif key == "left" then
        if global_state.scraperFocus == "FRONT" then
            global_state.scraperFrontIndex = global_state.scraperFrontIndex - 1
            if global_state.scraperFrontIndex < 1 then global_state.scraperFrontIndex = count end
            global_state.scraperTextIndex = global_state.scraperFrontIndex
            global_state.scraperScreenIndex = global_state.scraperFrontIndex
        elseif global_state.scraperFocus == "SCREEN" then
            global_state.scraperScreenIndex = global_state.scraperScreenIndex - 1
            if global_state.scraperScreenIndex < 1 then global_state.scraperScreenIndex = count end
        elseif global_state.scraperFocus == "TEXT" then
            global_state.scraperTextIndex = global_state.scraperTextIndex - 1
            if global_state.scraperTextIndex < 1 then global_state.scraperTextIndex = count end
        end
        global_state.inputCooldown = 0.15
    elseif key == "right" then
        if global_state.scraperFocus == "FRONT" then
            global_state.scraperFrontIndex = global_state.scraperFrontIndex + 1
            if global_state.scraperFrontIndex > count then global_state.scraperFrontIndex = 1 end
            global_state.scraperTextIndex = global_state.scraperFrontIndex
            global_state.scraperScreenIndex = global_state.scraperFrontIndex
        elseif global_state.scraperFocus == "SCREEN" then
            global_state.scraperScreenIndex = global_state.scraperScreenIndex + 1
            if global_state.scraperScreenIndex > count then global_state.scraperScreenIndex = 1 end
        elseif global_state.scraperFocus == "TEXT" then
            global_state.scraperTextIndex = global_state.scraperTextIndex + 1
            if global_state.scraperTextIndex > count then global_state.scraperTextIndex = 1 end
        end
        global_state.inputCooldown = 0.15
    elseif (key == "return" or key == "kpenter") then
        helpers.saveCompositeArt(global_state)
        global_state.inputCooldown = 0.2
    end
end

function M.SAVE_MANAGER(key, global_state)
    if key == "backspace" or key == "escape" then
        if #global_state.menuStack > 0 then
            global_state.state = "OPTIONS_MENU"
        else
            global_state.state = "LIST"
        end
        global_state.inputCooldown = 0.2
    elseif key == "return" or key == "kpenter" then
        local item = global_state.saveFiles[global_state.saveManagerSelection]
        if item then
            local targetRoot = item.location == "SD1" and "/mnt/sdcard" or "/mnt/mmc"
            local relPath = item.fullPath:match("/mnt/[^/]+/(.*)")
            if relPath then
                local destPath = targetRoot .. "/" .. relPath
                local destDir = destPath:match("(.*/)")
                local ok = os.execute('mkdir -p ' .. utils.escapeShellArg(destDir))
                if not ok then global_state.log("Failed to create save directory: " .. destDir) end
                filesystem.copyFile(item.fullPath, destPath, global_state.log)
                helpers.findSaveFiles(global_state.files[global_state.selectedIndex], global_state)
            end
        end
        global_state.inputCooldown = 0.2
    end
end

return M
