---@diagnostic disable: undefined-global
local M = {}
local filesystem = require "filesystem"
local utils = require "utils"
local State = require "state"
local helpers = require "input_helpers"

local function deleteSDFile(global_state, sdPrefix)
    local item = global_state.files[global_state.selectedIndex]
    local pathToDelete = item.fullPath:find(sdPrefix) and item.fullPath or item.secondaryPath
    helpers.deleteGameMedia(pathToDelete)
    local success, err = filesystem.safeRemove(pathToDelete, global_state.log)
    if not success then
        global_state.log("Error al borrar archivo (o ya no existía): " .. pathToDelete .. " - " .. tostring(err))
    else
        global_state.log("Archivo borrado con éxito: " .. pathToDelete)
        filesystem.logDeletion(pathToDelete, global_state.json.encode, global_state.json.decode)
    end
    if global_state.romIndex then helpers.removeFromIndex(pathToDelete, global_state) end
    if global_state.playedRoms[pathToDelete] then global_state.playedRoms[pathToDelete] = nil helpers.saveHistory(global_state) end
    if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
        global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
           filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
           global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
           global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
           global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
        global_state.preview.load(global_state, global_state.log, global_state.loader)
    else
        helpers.refreshFiles(global_state)
    end
    global_state.state = "LIST"
end

function M.OPTIONS_MENU(key, global_state)
    local L = global_state.L
    if key == "return" or key == "kpenter" or (key == "return" and global_state.love.joystick.getJoystickCount() == 0) then
        if global_state.menuTitle == L.get("select_system") then
             local choice = global_state.menuOptions[global_state.menuSelection]
             local core = nil
             if choice == "Arcade (FBNeo)" then core = "fbneo_libretro.so"
             elseif choice == "Super Nintendo" then core = "snes9x_libretro.so"
             elseif choice == "Nintendo (NES)" then core = "fceumm_libretro.so"
             elseif choice == "Sega Genesis/MD" then core = "picodrive_libretro.so"
             elseif choice == "PlayStation" then core = "pcsx_rearmed_libretro.so"
             elseif choice == "GBA" then core = "mgba_libretro.so"
             elseif choice == "GBC/GB" then core = "gambatte_libretro.so"
             end

             if core then
                 local f = io.open("/tmp/launch_core", "w")
                 if f then f:write(core) f:close() end
             end

             local romToLaunch = global_state.itemToLaunch
             global_state.log("Selected ROM for launch (with core): " .. romToLaunch)
             global_state.lastPlayedRom = romToLaunch
             helpers.saveLastPlayed(global_state.lastPlayedRom)
             filesystem.savePendingHistory(global_state.lastPlayedRom)
             global_state.launching = true
             global_state.launchTimer = 0
             return
        end

        if #global_state.menuStack > 0 then
             local opt = global_state.menuOptions[global_state.menuSelection]
             local optText = type(opt) == "table" and opt.text or opt

             if optText == L.get("info") then
                 global_state.preview.load(global_state, global_state.log, global_state.loader)
                 global_state.state = "INFO_VIEW"
             elseif optText == L.get("scraper") then
                 global_state.state = "SCRAPER_VIEW"
             elseif optText:match(L.get("save_games")) then
                 global_state.state = "SAVE_MANAGER"
             elseif optText == L.get("delete") then
                 global_state.itemToDelete = global_state.focusedItem
                 global_state.menuTitle = L.get("confirm_delete")
                 global_state.menuMessage = L.get("delete_file_msg", global_state.itemToDelete.name)
                 global_state.menuOptions = {L.get("delete"), L.get("cancel")}
                 global_state.menuSelection = 2
                 global_state.log("Menu opened: " .. global_state.menuTitle)
                 global_state.state = "DELETE_MENU"
             elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
                 local fullPath = global_state.focusedItem.fullPath
                 if global_state.favoriteRoms[fullPath] then
                     global_state.favoriteRoms[fullPath] = nil
                     global_state.favAnimTarget = 0
                     if type(opt) == "table" then opt.text = L.get("add_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("add_favorite") end
                 else
                     global_state.favoriteRoms[fullPath] = true
                     global_state.favAnimTarget = 1
                     if type(opt) == "table" then opt.text = L.get("remove_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("remove_favorite") end
                 end
                 global_state.favAnimIndex = global_state.selectedIndex
                 filesystem.saveFavorites(global_state.favoriteRoms, global_state.json.encode)
                 if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                     global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                        filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                        global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                        global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                        global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                    global_state.preview.load(global_state, global_state.log, global_state.loader)
                 end
              elseif optText == L.get("remove_from_collection") then
                  local gamePath = global_state.focusedItem and global_state.focusedItem.fullPath
                  if gamePath and global_state.romPath then
                      local colName = global_state.romPath:match("^@Collections/(.+)/$")
                      if colName then
                          filesystem.removeFromCollection(colName, gamePath, global_state.json.encode, global_state.json.decode)
                          global_state.log("Removed from collection: " .. colName)
                          global_state.closingMenu = true
                          global_state.menuStack = {}
                          helpers.refreshFiles(global_state)
                      end
                  end
              elseif optText == L.get("add_to_collection") then
                  local collections = {}
                  local f = io.open(global_state.love.filesystem.getSource() .. "/data/collections.json", "r")
                  if f then
                      local c = f:read("*a")
                      f:close()
                      if c and c ~= "" then collections = global_state.json.decode(c) or {} end
                  end
                  table.insert(global_state.menuStack, {
                      title = global_state.menuTitle, message = global_state.menuMessage,
                      options = global_state.menuOptions, selection = global_state.menuSelection,
                      focusedItem = global_state.focusedItem
                  })
                  global_state.menuTitle = L.get("add_to_collection")
                  global_state.menuMessage = ""
                  global_state.menuOptions = {}
                  for name, _ in pairs(collections) do
                      table.insert(global_state.menuOptions, { text = name, collectionName = name })
                  end
                  table.insert(global_state.menuOptions, { text = L.get("new_collection"), isNew = true })
                  global_state.menuSelection = 1
                  global_state.menuAnim = 0
              elseif type(opt) == "table" and opt.collectionName then
                  local gamePath = global_state.focusedItem and global_state.focusedItem.fullPath
                  if gamePath then
                      filesystem.addToCollection(opt.collectionName, gamePath, global_state.json.encode, global_state.json.decode)
                      global_state.log("Added to collection: " .. opt.collectionName)
                      global_state.closingMenu = true
                      global_state.menuStack = {}
                  end
              elseif type(opt) == "table" and opt.isNew then
                  global_state.menuTitle = L.get("new_collection")
                  global_state.menuMessage = L.get("enter_name")
                  global_state.menuOptions = {}
                  global_state.menuSelection = 1
                  global_state.menuAnim = 0
                  global_state.state = "EDIT_TEXT"
                  global_state.textToEdit = ""
                  global_state.textEditLabel = L.get("collection_name")
                  global_state.textEditKey = "new_collection_name"
                  global_state.keyboardRow = 1
                  global_state.keyboardCol = 1
                  global_state.love.keyboard.setTextInput(true)
              elseif type(opt) == "table" and opt.fullPath then
                  -- System switcher: navigate to the selected system
                  global_state.romPath = opt.fullPath
                  global_state.isVirtualRoot = false
                  global_state.selectedIndex = 1
                  global_state.state = "LIST"
                  global_state.closingMenu = true
                  global_state.menuStack = {}
                  global_state.inputCooldown = 0.2
                  helpers.refreshFiles(global_state)
              end
              global_state.inputCooldown = 0.3
              return
         end

        if global_state.menuTitle == L.get("version") then
             local item = global_state.files[global_state.selectedIndex]
             if item and item.versions and item.versions[global_state.menuSelection] then
                 local v = item.versions[global_state.menuSelection]
                 global_state.lastPlayedRom = v.fullPath
                 helpers.saveLastPlayed(global_state.lastPlayedRom, global_state)
                 helpers.addToHistory(global_state.lastPlayedRom, global_state)
                 global_state.launching = true
                 global_state.launchTimer = 0
             end
             return
        end

        local opt = global_state.menuOptions[global_state.menuSelection]
        local optText = type(opt) == "table" and opt.text or opt

        if optText == L.get("delete") then
            if global_state.selectedFilesCount > 0 then
                global_state.menuTitle = L.get("confirm_delete")
                global_state.menuMessage = L.get("delete_selected_msg", global_state.selectedFilesCount)
                global_state.menuOptions = {L.get("delete"), L.get("cancel")}
                global_state.menuSelection = 2
                global_state.log("Menu opened: " .. global_state.menuTitle)
                global_state.state = "DELETE_MENU"
            elseif (not global_state.isVirtualRoot or global_state.launchMode == "Juego Unico") and global_state.files[global_state.selectedIndex] and (not global_state.files[global_state.selectedIndex].isDir or global_state.files[global_state.selectedIndex].name ~= "..") then
                global_state.itemToDelete = global_state.files[global_state.selectedIndex]
                global_state.menuTitle = L.get("confirm_delete")
                global_state.menuMessage = L.get("delete_file_msg", global_state.itemToDelete.name)
                global_state.menuOptions = {L.get("delete"), L.get("cancel")}
                global_state.menuSelection = 2
                global_state.log("Menu opened: " .. global_state.menuTitle)
                global_state.state = "DELETE_MENU"
            end
        elseif optText == L.get("info") then
            global_state.state = "INFO_VIEW"
            global_state.inputCooldown = 0.2
        elseif optText == L.get("scraper") then
            if global_state.selectedFilesCount > 0 then
                local items = {}
                for _, f in ipairs(global_state.files) do
                    if f.selected then table.insert(items, f) end
                end
                helpers.performBatchScrape(global_state, items)
                global_state.inputCooldown = 0.2
            else
                global_state.state = "SCRAPER_VIEW"
                global_state.scraperSelection = 1
                global_state.inputCooldown = 0.2
            end
        elseif optText == L.get("delete_sd1") then
            deleteSDFile(global_state, "/mnt/mmc")
        elseif optText == L.get("delete_sd2") then
            deleteSDFile(global_state, "/mnt/sdcard")
        elseif optText:match(L.get("mode") .. ":") then
            global_state.launchMode = (global_state.launchMode == "Folder") and "Juego Unico" or "Folder"
            local displayMode = (global_state.launchMode == "Folder") and L.get("folder") or L.get("single_game")
            local newVal = L.get("mode") .. ": " .. displayMode
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
            global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
               filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
               global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
               global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
               global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
            global_state.preview.load(global_state, global_state.log, global_state.loader)
        elseif optText:match(L.get("hide_empty")) then
            global_state.hideEmpty = not global_state.hideEmpty
            local newVal = L.get("hide_empty") .. ": " .. (global_state.hideEmpty and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                global_state.preview.load(global_state, global_state.log, global_state.loader)
            end
        elseif optText:match(L.get("view")) then
            global_state.viewMode = (global_state.viewMode == "LIST") and "GRID" or "LIST"
            local displayView = (global_state.viewMode == "LIST") and L.get("list") or L.get("grid")
            local newVal = L.get("view") .. ": " .. displayView
            if type(opt) == "table" then
                opt.text = newVal
            else
                global_state.menuOptions[global_state.menuSelection] = newVal
            end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
        elseif optText == L.get("cleanup") then
            global_state.state = "CLEANUP_MENU"
            global_state.cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, progress = 0, cursor = {col=1, row=1}, confirming = false }
            global_state.inputCooldown = 0.2
        elseif optText:match(L.get("mark_played")) then
            global_state.markPlayed = not global_state.markPlayed
            local newVal = L.get("mark_played") .. ": " .. (global_state.markPlayed and L.get("yes") or L.get("no"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
        elseif optText:match(L.get("hide_favorites")) then
            global_state.hideFavorites = not global_state.hideFavorites
            local newVal = L.get("hide_favorites") .. ": " .. (global_state.hideFavorites and L.get("on") or L.get("off"))
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
            State.saveAppState(global_state.romPath, global_state.selectedIndex, global_state.hideEmpty, global_state.markPlayed, global_state.viewMode, global_state.launchMode, global_state.hideFavorites, global_state.love.filesystem)
            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                global_state.preview.load(global_state, global_state.log, global_state.loader)
            else
                helpers.refreshFiles(global_state)
            end
        elseif optText == L.get("api_settings") then
            table.insert(global_state.menuStack, {
                 title = global_state.menuTitle,
                 message = global_state.menuMessage,
                 options = global_state.menuOptions,
                 selection = global_state.menuSelection
            })
            global_state.menuTitle = L.get("api_settings")
            global_state.menuMessage = (global_state.config.thegamesdb_apikey == "") and L.get("missing_api_key_warn") or ""
            global_state.menuOptions = {
                L.get("scraper_api") .. ": " .. (global_state.config.scraperApi or "all"),
                L.get("api_key") .. ": " .. (global_state.config.thegamesdb_apikey ~= "" and "******" or "Empty")
            }
            table.insert(global_state.menuOptions, L.get("ss_user") .. ": " .. (global_state.config.screenscraper_user ~= "" and global_state.config.screenscraper_user or "Empty"))
            table.insert(global_state.menuOptions, L.get("ss_password") .. ": " .. (global_state.config.screenscraper_password ~= "" and "******" or "Empty"))
            global_state.menuSelection = 1
            global_state.menuAnim = 0
        elseif optText:match(L.get("scraper_api")) then
            local current = global_state.config.scraperApi or "all"
            local nextApi = "all"
            if current == "all" then nextApi = "libretro"
            elseif current == "libretro" then nextApi = "thegamesdb"
            elseif current == "thegamesdb" then nextApi = "all" end
            global_state.config.scraperApi = nextApi

            local f = io.open(global_state.love.filesystem.getSource() .. "/data/config.json", "w")
            if f then f:write(global_state.json.encode(global_state.config)) f:close() end

            local newVal = L.get("scraper_api") .. ": " .. nextApi
            if type(opt) == "table" then opt.text = newVal else global_state.menuOptions[global_state.menuSelection] = newVal end
        elseif optText:match(L.get("api_key")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.thegamesdb_apikey or ""
            global_state.textEditLabel = L.get("api_key")
            global_state.textEditKey = "thegamesdb_apikey"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("ss_user")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.screenscraper_user or ""
            global_state.textEditLabel = L.get("ss_user")
            global_state.textEditKey = "screenscraper_user"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("ss_password")) then
            global_state.state = "EDIT_TEXT"
            global_state.textToEdit = global_state.config.screenscraper_password or ""
            global_state.textEditLabel = L.get("ss_password")
            global_state.textEditKey = "screenscraper_password"
            global_state.keyboardRow = 1
            global_state.keyboardCol = 1
            global_state.love.keyboard.setTextInput(true)
        elseif optText:match(L.get("add_favorite")) or optText:match(L.get("remove_favorite")) then
            local item = global_state.files[global_state.selectedIndex]
            local path = item.fullPath
            if global_state.favoriteRoms[path] then
                global_state.favoriteRoms[path] = nil
                global_state.favAnimTarget = 0
                if type(opt) == "table" then opt.text = L.get("add_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("add_favorite") end
            else
                global_state.favoriteRoms[path] = true
                global_state.favAnimTarget = 1
                if type(opt) == "table" then opt.text = L.get("remove_favorite") else global_state.menuOptions[global_state.menuSelection] = L.get("remove_favorite") end
            end
            global_state.favAnimIndex = global_state.selectedIndex
            filesystem.saveFavorites(global_state.favoriteRoms, global_state.json.encode)

            local inFavoritesView = (global_state.romPath == "@Favorites/")

            if global_state.isVirtualRoot then
                global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles =
                   filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath,
                   global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex,
                   global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.love.filesystem.getInfo,
                   global_state.love.graphics.newImage, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites, global_state.log, global_state.loader)
            else
                helpers.refreshFiles(global_state)
            end

            if inFavoritesView then
                global_state.state = "LIST"
                global_state.closingMenu = true
            end
        elseif optText == L.get("random_game") then
            if #global_state.files > 0 then
                local rand = global_state.love.math.random(1, #global_state.files)
                global_state.selectedIndex = rand
                global_state.animatedSelectionIndex = rand
                global_state.state = "LIST"
                global_state.closingMenu = true
                global_state.preview.load(global_state, global_state.log, global_state.loader)
                global_state.log("Random game selected: " .. global_state.files[rand].name)
            end
        elseif optText == L.get("switch_system") then
            local systems = {}
            local seen = {}
            for _, item in ipairs(global_state.allFiles) do
                if item.isDir and item.name ~= ".." then
                    local sysName = item.system or item.name
                    if not seen[sysName] then
                        seen[sysName] = true
                        table.insert(systems, {
                            text = utils.getSystemDisplayName(sysName) or sysName,
                            system = sysName,
                            fullPath = item.fullPath
                        })
                    end
                end
            end
            table.sort(systems, function(a, b) return a.text:lower() < b.text:lower() end)
            table.insert(global_state.menuStack, {
                title = global_state.menuTitle, message = global_state.menuMessage,
                options = global_state.menuOptions, selection = global_state.menuSelection
            })
            global_state.menuTitle = global_state.L.get("switch_system")
            global_state.menuMessage = ""
            global_state.menuOptions = {}
            for _, sys in ipairs(systems) do
                local icon = utils.getSystemIcon(sys.system, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
                table.insert(global_state.menuOptions, {text = sys.text, icon = icon, fullPath = sys.fullPath})
            end
            global_state.menuSelection = 1
            global_state.menuAnim = 0
        elseif optText == L.get("reindex") then
            if global_state.forceReindex then
                global_state.forceReindex(global_state)
            else
                 global_state.log("Error: forceReindex function not found in global_state")
            end
            global_state.state = "LIST"
        elseif optText == L.get("update_now") then
            local f = io.open("/tmp/filebernic_update", "w")
            if f then f:write(global_state.updateUrl); f:close() end
            global_state.log("Triggering OTA update...")
            global_state.love.event.quit()
        elseif optText == L.get("cancel") then
            global_state.closingMenu = true
        elseif optText:match(L.get("copy")) or optText:match(L.get("move_to"):match("^(.*)%s")) then
            local isMove = optText:match(L.get("move_to"):match("^(.*)%s"))
            local targetDir, _ = filesystem.getTargetSDPath(global_state.romPath, global_state.config)

            if targetDir then
                local ok = os.execute('mkdir -p "' .. targetDir .. '"')
                if not ok then global_state.log("Failed to create target directory: " .. targetDir) end

                local function processItem(item)
                    local src = global_state.romPath .. item.name
                    local dst = targetDir .. item.name
                    if isMove then
                        filesystem.moveFile(src, dst, global_state.log)
                    else
                        filesystem.copyFile(src, dst, global_state.log)
                    end
                    if isMove and global_state.playedRoms[src] then
                        global_state.playedRoms[src] = nil
                    end
                end

                if global_state.selectedFilesCount > 0 then
                    for _, item in ipairs(global_state.files) do
                        if item.selected then processItem(item) end
                    end
                else
                    processItem(global_state.files[global_state.selectedIndex])
                end

                if isMove then helpers.saveHistory(global_state) end
                helpers.refreshFiles(global_state)
                global_state.state = "LIST"
            end
        elseif optText:match(L.get("save_games")) then
            global_state.state = "SAVE_MANAGER"
        end
        global_state.inputCooldown = 0.2
    elseif key == "tab" then
         if global_state.menuTitle == L.get("config") then return end

         if global_state.menuTitle == L.get("version") then
             local item = global_state.files[global_state.selectedIndex]
             local ver = item.versions[global_state.menuSelection]

             table.insert(global_state.menuStack, {
                 title = global_state.menuTitle,
                 message = global_state.menuMessage,
                 options = global_state.menuOptions,
                 selection = global_state.menuSelection,
                 focusedItem = global_state.focusedItem
             })
             global_state.focusedItem = ver

             global_state.menuTitle = L.get("options") .. ": " .. ver.name
             global_state.menuMessage = ver.name
             helpers.findSaveFiles(ver, global_state)
             global_state.menuOptions = {L.get("info"), L.get("scraper"), L.get("save_games") .. " (" .. #global_state.saveFiles .. ")", L.get("delete")}

             if global_state.favoriteRoms[ver.fullPath] then
                 table.insert(global_state.menuOptions, 2, L.get("remove_favorite"))
             else
                 table.insert(global_state.menuOptions, 2, L.get("add_favorite"))
             end

             global_state.menuSelection = 1
             global_state.menuAnim = 0
             global_state.inputCooldown = 0.2
             return
         end

        if #global_state.menuStack > 0 then return end

        global_state.closingMenu = true
        global_state.menuStack = {}
        global_state.log("Menu exited: " .. global_state.menuTitle)
        global_state.inputCooldown = 0.2
    elseif key == "backspace" then
        if #global_state.menuStack > 0 then
             global_state.closingMenu = true
             global_state.inputCooldown = 0.2
        else
            global_state.closingMenu = true
            global_state.log("Menu exited: " .. global_state.menuTitle)
            global_state.inputCooldown = 0.2
        end
    end
end

function M.DELETE_MENU(key, global_state)
    if key == "return" or key == "space" or key == "kpenter" then
        if global_state.menuOptions[global_state.menuSelection] == global_state.L.get("delete") then
            if global_state.selectedFilesCount > 0 then
                for _, item in ipairs(global_state.files) do
                    if item.selected then
                        local fullPath = item.fullPath or (global_state.romPath .. item.name)
                        helpers.deleteGameMedia(fullPath)
                        local success, err = filesystem.safeRemove(fullPath, global_state.log)
                        if not success then
                            global_state.log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                        else
                            global_state.log("Archivo borrado con éxito: " .. fullPath)
                            filesystem.logDeletion(fullPath, global_state.json.encode, global_state.json.decode)
                        end
                        if global_state.romIndex then helpers.removeFromIndex(fullPath, global_state) end
                        if global_state.playedRoms[fullPath] then
                            global_state.playedRoms[fullPath] = nil
                        end
                    end
                end
                helpers.saveHistory(global_state)
                if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                    global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                    global_state.preview.load(global_state, global_state.log, global_state.loader)
                else
                    helpers.refreshFiles(global_state)
                end
                global_state.itemToDelete = nil
            elseif global_state.itemToDelete then
                local fullPath = global_state.itemToDelete.fullPath or (global_state.romPath .. global_state.itemToDelete.name)
                helpers.deleteGameMedia(fullPath)
                local success, err = filesystem.safeRemove(fullPath, global_state.log)
                if not success then
                    global_state.log("Error al borrar archivo (o ya no existía): " .. fullPath .. " - " .. tostring(err))
                else
                    global_state.log("Archivo borrado con éxito: " .. fullPath)
                    filesystem.logDeletion(fullPath, global_state.json.encode, global_state.json.decode)
                end
                if global_state.romIndex then helpers.removeFromIndex(fullPath, global_state) end
                if global_state.playedRoms[fullPath] then
                    global_state.playedRoms[fullPath] = nil
                    helpers.saveHistory(global_state)
                end
                if global_state.isVirtualRoot and global_state.launchMode == "Juego Unico" then
                    global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles = filesystem.createMergedVirtualRoot(global_state.files, global_state.isVirtualRoot, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.launchMode, global_state.romIndex, global_state.hideEmpty, global_state.validExtensions, utils.getSystemIcon, global_state.allFiles, nil, global_state.favoriteRoms, global_state.hideFavorites)
                    global_state.preview.load(global_state, global_state.log, global_state.loader)
                else
                    helpers.refreshFiles(global_state)
                end
                global_state.itemToDelete = nil
            end
        end
        global_state.inputCooldown = 0.2
        global_state.state = "LIST"
        global_state.closingMenu = true
        global_state.log("Delete Menu exited")
    elseif key == "backspace" then
        global_state.itemToDelete = nil
        global_state.inputCooldown = 0.2
        global_state.closingMenu = true
        global_state.log("Delete Menu exited")
    end
end

function M.CLEANUP_MENU(key, global_state)
    if global_state.cleanupData.confirming then
        if key == "backspace" or key == "escape" or key == "b" then
            global_state.cleanupData.confirming = false
            global_state.inputCooldown = 0.2
        elseif key == "return" or key == "kpenter" or key == "space" or key == "a" then
            if global_state.cleanupData.cursor.col == 1 then
                if global_state.cleanupData.cursor.row == 1 then
                    for _, orphan in ipairs(global_state.cleanupData.orphans) do
                        local success, err = filesystem.safeRemove(orphan.fullPath, global_state.log)
                        if success then
                            global_state.log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, global_state.json.encode, global_state.json.decode)
                        else global_state.log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                    end
                    global_state.cleanupData.orphans = {}
                else
                    local idx = global_state.cleanupData.cursor.row - 1
                    local orphan = global_state.cleanupData.orphans[idx]
                    if orphan then
                        local success, err = filesystem.safeRemove(orphan.fullPath, global_state.log)
                        if success then
                            global_state.log("Cleanup: Borrado " .. orphan.fullPath)
                            filesystem.logDeletion(orphan.fullPath, global_state.json.encode, global_state.json.decode)
                        else global_state.log("Cleanup Error: " .. orphan.fullPath .. " " .. tostring(err)) end
                        table.remove(global_state.cleanupData.orphans, idx)
                        if global_state.cleanupData.cursor.row > #global_state.cleanupData.orphans + 1 then
                            global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.orphans + 1)
                        end
                    end
                end
            elseif global_state.cleanupData.cursor.col == 3 then
                local idx = global_state.cleanupData.cursor.row
                local item = global_state.cleanupData.orphanedImages[idx]
                if item then
                    local success, err = filesystem.safeRemove(item.fullPath, global_state.log)
                    if success then
                        global_state.log("Cleanup: Borrado " .. item.fullPath)
                        filesystem.logDeletion(item.fullPath, global_state.json.encode, global_state.json.decode)
                    else global_state.log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err)) end
                    table.remove(global_state.cleanupData.orphanedImages, idx)
                    if global_state.cleanupData.cursor.row > #global_state.cleanupData.orphanedImages then
                        global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.orphanedImages)
                    end
                end
            else
                local idx = global_state.cleanupData.cursor.row
                local item = global_state.cleanupData.duplicates[idx]
                if item then
                    local success, err = filesystem.safeRemove(item.fullPath, global_state.log)
                    if success then
                        global_state.log("Cleanup: Borrado " .. item.fullPath)
                        filesystem.logDeletion(item.fullPath, global_state.json.encode, global_state.json.decode)
                        if global_state.romIndex then helpers.removeFromIndex(item.fullPath, global_state) end
                    else
                        global_state.log("Cleanup Error: " .. item.fullPath .. " " .. tostring(err))
                    end
                    table.remove(global_state.cleanupData.duplicates, idx)
                    if global_state.cleanupData.cursor.row > #global_state.cleanupData.duplicates then
                        global_state.cleanupData.cursor.row = math.max(1, #global_state.cleanupData.duplicates)
                    end
                    if global_state.playedRoms[item.fullPath] then global_state.playedRoms[item.fullPath] = nil end
                end
            end

            global_state.cleanupData.confirming = false
            global_state.inputCooldown = 0.2
        end
        return
    end

    if key == "backspace" or key == "escape" then
        global_state.state = "LIST"
        global_state.inputCooldown = 0.2
    elseif not global_state.cleanupData.scanned then
        if key == "return" or key == "kpenter" then
            helpers.performCleanupScan(global_state)
        end
    else
        if key == "f" then
            if global_state.cleanupData.cursor.col == 1 then
                global_state.cleanupData.cursor.col = 2
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.duplicates)
            elseif global_state.cleanupData.cursor.col == 2 and #global_state.cleanupData.orphanedImages > 0 then
                global_state.cleanupData.cursor.col = 3
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.orphanedImages)
            else
                global_state.cleanupData.cursor.col = 1
                global_state.cleanupData.cursor.row = math.min(global_state.cleanupData.cursor.row, #global_state.cleanupData.orphans + 1)
            end
        elseif key == "left" then
            global_state.cleanupData.cursor.row = math.max(1, global_state.cleanupData.cursor.row - global_state.pageSize)
        elseif key == "right" then
            local maxRows = (global_state.cleanupData.cursor.col == 1 and #global_state.cleanupData.orphans + 1) or (global_state.cleanupData.cursor.col == 2 and #global_state.cleanupData.duplicates) or #global_state.cleanupData.orphanedImages
            global_state.cleanupData.cursor.row = math.min(maxRows, global_state.cleanupData.cursor.row + global_state.pageSize)
        elseif key == "return" or key == "kpenter" then
            local valid = false
            if global_state.cleanupData.cursor.col == 1 then
                if global_state.cleanupData.cursor.row == 1 and #global_state.cleanupData.orphans > 0 then valid = true
                elseif global_state.cleanupData.cursor.row > 1 and global_state.cleanupData.orphans[global_state.cleanupData.cursor.row - 1] then valid = true end
            elseif global_state.cleanupData.cursor.col == 3 then
                if global_state.cleanupData.orphanedImages[global_state.cleanupData.cursor.row] then valid = true end
            else
                if global_state.cleanupData.duplicates[global_state.cleanupData.cursor.row] then valid = true end
            end

            if valid then
                global_state.cleanupData.confirming = true
                global_state.inputCooldown = 0.2
            end
        end
    end
end

function M.POST_GAME(key, global_state)
    if key == "return" or key == "space" or key == "kpenter" then
        filesystem.safeRemove(global_state.lastPlayedRom, global_state.log)
        global_state.state = "LIST"
        global_state.inputCooldown = 0.2
        helpers.refreshFiles(global_state)
    elseif key == "backspace" then
        global_state.state = "LIST"
        global_state.inputCooldown = 0.2
    end
end

return M
