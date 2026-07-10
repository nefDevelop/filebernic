---@diagnostic disable: undefined-global
local M = {}
local filesystem = require "filesystem"
local utils = require "utils"
local helpers = require "input_helpers"

function M.handleListInput(key, global_state)
    local currentItem = global_state.files[global_state.selectedIndex]
    if currentItem and currentItem.empty then
        if key == "backspace" then
            local parent = global_state.romPath:gsub("[^/]+/$", "")
            global_state.log("Back (Empty). Verificando ruta: " .. global_state.romPath .. " -> Parent: " .. parent)

            local cwd = global_state.love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"

            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               global_state.romPath == "/mnt/mmc/ROMS/" or global_state.romPath == "/mnt/sdcard/ROMS/" or global_state.romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or global_state.romPath == "@Favorites/" or global_state.romPath == "@Recent/" or global_state.romPath == "@Collections/" or global_state.romPath:find("^@Collections/") then
                  global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                  global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                     filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                     global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                     global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                     global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                  global_state.preview.load(global_state, global_state.log, global_state.loader)
                  global_state.inputCooldown = 0.2
                  return
            end
            global_state.romPath = parent
            global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
            global_state.selectedIndex = 1
            helpers.refreshFiles(global_state)
            global_state.inputCooldown = 0.2
        else
            return
        end
    end

    if (key == "up" or key == "down" or key == "left" or key == "right" or key == "pageup" or key == "pagedown") and currentItem and currentItem.pendingDelete then
        table.remove(global_state.files, global_state.selectedIndex)
        if key == "up" or key == "left" or key == "pageup" then
             global_state.selectedIndex = math.max(1, global_state.selectedIndex - 1)
        end
        if global_state.selectedIndex > #global_state.files then global_state.selectedIndex = #global_state.files end
        if global_state.selectedIndex < 1 then global_state.selectedIndex = 1 end

        global_state.allFiles = {}
        for _, f in ipairs(global_state.files) do table.insert(global_state.allFiles, f) end

        global_state.inputCooldown = 0.2
        global_state.preview.load(global_state, global_state.log, global_state.loader)
        return
    end

    if key == "f" then
        global_state.state = "SEARCH"
        global_state.searchQuery = ""
        global_state.searchHistory = filesystem.loadSearch(global_state.json.decode)
        global_state.keyboardRow = 1
        global_state.keyboardCol = 1
        global_state.keyboardShift = false
        global_state.keyboardNum = false
        love.keyboard.setTextInput(true)
        helpers.filterFiles(global_state)
        return
    end

    if key == "f2" then
        global_state.searchQuery = ""
        helpers.filterFiles(global_state)
        global_state.inputCooldown = 0.2
        return
    end

    if key == "pageup" then
        if global_state.viewMode == "GRID" then
            global_state.selectedIndex = math.max(1, global_state.selectedIndex - (global_state.gridCols * 3))
        else
            global_state.selectedIndex = math.max(1, global_state.selectedIndex - global_state.pageSize)
        end
        global_state.pendingLoad = true
        global_state.inputCooldown = 0.2
        global_state.timer = 0
    elseif key == "pagedown" then
        if global_state.viewMode == "GRID" then
            global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + (global_state.gridCols * 3))
        else
            global_state.selectedIndex = math.min(#global_state.files, global_state.selectedIndex + global_state.pageSize)
        end
        global_state.pendingLoad = true
        global_state.inputCooldown = 0.2
        global_state.timer = 0
    end

    if key == "kpenter" or (key == "return" and love.joystick.getJoystickCount() == 0) then
        if #global_state.files == 0 then return end
        local item = global_state.files[global_state.selectedIndex]
        if item.isDir then
            if global_state.isVirtualRoot then
                global_state.romPath = item.fullPath
                global_state.secondaryPath = item.secondaryPath
                global_state.isVirtualRoot = false
                global_state.selectedIndex = 1
                helpers.refreshFiles(global_state)
                global_state.inputCooldown = 0.2
            else
                if item.name == ".." then
                    local newPath = global_state.romPath:gsub("[^/]+/$", "")
                    if newPath == "/mnt/mmc/ROMS/" or newPath == "/mnt/sdcard/ROMS/" then
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                           filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                           global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                           global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                           global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        global_state.preview.load(global_state, global_state.log, global_state.loader)
                        return
                    end
                    local cwd = global_state.love.filesystem.getSource()
                    if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
                    if newPath == cwd .. "/../" then
                        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                        global_state.preview.load(global_state, global_state.log, global_state.loader)
                        return
                    end
                    global_state.romPath = newPath
                    global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
                else
                    global_state.romPath = global_state.romPath .. item.name .. "/"
                end
                global_state.selectedIndex = 1
                helpers.refreshFiles(global_state)
                global_state.inputCooldown = 0.2
            end
        else
            local romToLaunch = nil

            if global_state.launchMode == "Juego Unico" and item.versions then
                if #item.versions > 1 then
                    global_state.state = "OPTIONS_MENU"
                    global_state.menuAnim = 0
                    global_state.menuTitle = global_state.L.get("version")
                    global_state.log("Menu opened: " .. global_state.menuTitle .. " for " .. item.name)
                    global_state.menuMessage = item.name
                    global_state.menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(global_state.menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = global_state.playedRoms[v.fullPath]
                        })
                    end
                    global_state.menuSelection = 1
                    global_state.inputCooldown = 0.2
                    return
                elseif #item.versions == 1 then
                    romToLaunch = item.versions[1].fullPath
                end
            else
                romToLaunch = global_state.isVirtualRoot and item.fullPath or global_state.romPath .. item.name
            end

            if romToLaunch then
                local ext = romToLaunch:match("%.([^%.]+)$")
                local isZip = ext and (ext:lower() == "zip" or ext:lower() == "7z")

                if isZip then
                    local folder = romToLaunch:match(".*/ROMS/([^/]+)/") or romToLaunch:match(".*/([^/]+)/")
                    local known = false
                    if folder then
                        if utils.isKnownSystem(folder) then
                            known = true
                        end
                    end

                    if not known then
                        global_state.state = "OPTIONS_MENU"
                        global_state.menuTitle = global_state.L.get("select_system")
                        global_state.menuMessage = global_state.L.get("ambiguous_rom")
                        global_state.menuOptions = {"Arcade (FBNeo)", "Super Nintendo", "Nintendo (NES)", "Sega Genesis/MD", "PlayStation", "GBA", "GBC/GB"}
                        global_state.menuSelection = 1
                        global_state.itemToLaunch = romToLaunch
                        global_state.inputCooldown = 0.2
                        return
                    end
                end

                global_state.log("Selected ROM for launch: " .. romToLaunch)
                global_state.lastPlayedRom = romToLaunch
                helpers.saveLastPlayed(global_state.lastPlayedRom)
                filesystem.savePendingHistory(global_state.lastPlayedRom)
                filesystem.addRecent(romToLaunch, global_state.json.encode, global_state.json.decode)
                global_state.launching = true
                global_state.launchTimer = 0
            end
        end
    elseif key == "backspace" then
        if global_state.isVirtualRoot then
            global_state.inputCooldown = 0.2
            return
        else
            local parent = global_state.romPath:gsub("[^/]+/$", "")
            global_state.log("Back. Verificando ruta: " .. global_state.romPath .. " -> Parent: " .. parent)

            local cwd = global_state.love.filesystem.getSource()
            if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
            local simRoot = cwd .. "/../Simulador_SD/"

            if parent == "/mnt/mmc/ROMS/" or parent == "/mnt/sdcard/ROMS/" or parent == simRoot or
               global_state.romPath == "/mnt/mmc/ROMS/" or global_state.romPath == "/mnt/sdcard/ROMS/" or global_state.romPath == simRoot or
               parent == "/" or parent == "/mnt/" or parent == "/mnt/mmc/" or parent == "/mnt/sdcard/" or
               global_state.romPath == "" or global_state.romPath == "@Favorites/" or global_state.romPath == "@Recent/" or global_state.romPath == "@Collections/" or global_state.romPath:find("^@Collections/") then
                  global_state.log("Límite alcanzado. Volviendo a Ruta Virtual.")
                  global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                     filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                     global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                     global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                     global_state.love.graphics.newImage, global_state.allFiles, global_state.romPath, global_state.favoriteRoms, global_state.hideFavorites)
                  global_state.log("Virtual Root created. Items: " .. #global_state.files)
                  global_state.preview.load(global_state, global_state.log, global_state.loader)
                 global_state.inputCooldown = 0.2
                 return
            end
            global_state.romPath = parent
            global_state.secondaryPath = filesystem.resolveSecondary(global_state.romPath)
            global_state.selectedIndex = 1
            helpers.refreshFiles(global_state)
            global_state.inputCooldown = 0.2
        end
    elseif key == "tab" then
        local item = global_state.files[global_state.selectedIndex]
        if item then
            if item.isDir then
                global_state.inputCooldown = 0.2
                return
            else
                if global_state.launchMode == "Juego Unico" and item.versions and #item.versions > 1 then
                    global_state.state = "OPTIONS_MENU"
                    global_state.menuAnim = 0
                    global_state.menuTitle = global_state.L.get("version")
                    global_state.log("Menu opened: " .. global_state.menuTitle .. " for " .. item.name)
                    global_state.menuMessage = item.name
                    global_state.menuOptions = {}
                    for _, v in ipairs(item.versions) do
                        local icon = utils.getSystemIcon(v.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                        local sysDisplay = utils.getSystemDisplayName(v.system) or v.system
                        local tags = ""
                        local stem = v.name:gsub("%.[^%.]+$", "")
                        for tag in stem:gmatch("%s*(%b())") do tags = tags .. " " .. tag end
                        for tag in stem:gmatch("%s*(%b[])") do tags = tags .. " " .. tag end
                        table.insert(global_state.menuOptions, {
                            text = sysDisplay .. tags,
                            icon = icon,
                            system = v.system,
                            played = global_state.playedRoms[v.fullPath]
                        })
                    end
                    global_state.menuSelection = 1
                    global_state.inputCooldown = 0.15
                    return
                end

                global_state.state = "OPTIONS_MENU"
                global_state.menuAnim = 0
                global_state.menuTitle = global_state.L.get("options") .. ":"
                global_state.menuStack = {}
                if global_state.selectedFilesCount > 0 then
                    global_state.menuMessage = global_state.L.get("delete_selected_msg", global_state.selectedFilesCount)
                else
                    global_state.menuMessage = item.name
                end
                global_state.menuSelection = 1

                global_state.menuOptions = {}
                if global_state.selectedFilesCount <= 1 then
                    table.insert(global_state.menuOptions, {text=global_state.L.get("info"), icon=global_state.iconInfo})
                end
                if global_state.favoriteRoms[item.fullPath] then
                    table.insert(global_state.menuOptions, {text=global_state.L.get("remove_favorite"), icon=global_state.iconFavorite})
                else
                    table.insert(global_state.menuOptions, {text=global_state.L.get("add_favorite"), icon=global_state.iconFavorite})
                end
                local inCollection = global_state.romPath and global_state.romPath:find("^@Collections/")
                if inCollection then
                    table.insert(global_state.menuOptions, {text=global_state.L.get("remove_from_collection"), icon=global_state.iconTrash})
                else
                    table.insert(global_state.menuOptions, {text=global_state.L.get("add_to_collection"), icon=global_state.iconFolder})
                end
                table.insert(global_state.menuOptions, {text=global_state.L.get("scraper"), icon=global_state.iconNetwork})

                if item.sourceLabel ~= "SD½" then
                    local _, targetLabel = filesystem.getTargetSDPath(item.fullPath, global_state.config)
                    if targetLabel then
                        table.insert(global_state.menuOptions, {text=global_state.L.get("copy_to", targetLabel), icon=global_state.iconFolder})
                        table.insert(global_state.menuOptions, {text=global_state.L.get("move_to", targetLabel), icon=global_state.iconFolder})
                    end
                end

                helpers.findSaveFiles(item, global_state)
                table.insert(global_state.menuOptions, {text=global_state.L.get("save_games") .. " (" .. #global_state.saveFiles .. ")", icon=global_state.iconSaveStates})

                if not item.isFavorites then
                    if item.sourceLabel == "SD½" then
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete_sd1"), icon=global_state.iconTrash})
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete_sd2"), icon=global_state.iconTrash})
                    else
                        table.insert(global_state.menuOptions, {text=global_state.L.get("delete"), icon=global_state.iconTrash})
                    end
                end

                global_state.inputCooldown = 0.15
            end
        end
    elseif key == "x" then
        if global_state.launchMode ~= "Juego Unico" then
            local item = global_state.files[global_state.selectedIndex]
            if item and not item.isDir then
                item.selected = not item.selected
                if item.selected then
                    global_state.selectedFilesCount = global_state.selectedFilesCount + 1
                else
                    global_state.selectedFilesCount = global_state.selectedFilesCount - 1
                end
            end
        end
    end
end

return M
