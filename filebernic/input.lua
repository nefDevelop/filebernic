---@diagnostic disable: undefined-global
require "libs.dkjson"
local helpers = require "input_helpers"
local menus = require "input_menus"
local views = require "input_views"
local input_list = require "input_list"

local stateHandlers = {
    SEARCH = views.SEARCH,
    EDIT_TEXT = views.EDIT_TEXT,
    OPTIONS_MENU = menus.OPTIONS_MENU,
    INFO_VIEW = views.INFO_VIEW,
    SCRAPER_OPTIONS = views.SCRAPER_OPTIONS,
    SCRAPER_VIEW = views.SCRAPER_VIEW,
    SCRAPER_RESULTS = views.SCRAPER_RESULTS,
    SAVE_MANAGER = views.SAVE_MANAGER,
    CLEANUP_MENU = menus.CLEANUP_MENU,
    DELETE_MENU = menus.DELETE_MENU,
    POST_GAME = menus.POST_GAME,
}

local function keypressed(key, global_state)
    global_state.log("Key pressed: " .. key .. " (State: " .. global_state.state .. ")")
    if global_state.inputCooldown > 0 then
        global_state.log("Input ignored due to cooldown (" .. string.format("%.2f", global_state.inputCooldown) .. "s)")
        return
    end

    if key == "escape" then
        global_state.log("Select button pressed, quitting application.")
        love.event.quit()
        return
    end

    if global_state.launchMode == "Juego Unico" and global_state.isVirtualRoot and not global_state.romIndex then
        if global_state.state == "OPTIONS_MENU" then
        elseif key == "f1" then
        else
            return
        end
    end

    if global_state.showHelp then
        if key == "f3" or key == "backspace" or key == "b" then
            global_state.showHelp = false
            global_state.closingHelp = true
            global_state.inputCooldown = 0.2
            return
        end
        return
    end

    if key == "f3" then
        global_state.showHelp = true
        return
    end

    if key == "f1" then
        if global_state.state == "OPTIONS_MENU" and global_state.menuTitle == global_state.L.get("config") then
            global_state.closingMenu = true
            global_state.log("Configuration Menu exited")
            global_state.inputCooldown = 0.2
            return
        elseif global_state.state == "LIST" then
            global_state.log("Opening Configuration Menu")
            global_state.state = "OPTIONS_MENU"
            global_state.menuAnim = 0
            global_state.menuTitle = global_state.L.get("config")
            global_state.menuStack = {}
            global_state.menuMessage = ""
            global_state.menuSelection = 1
            global_state.menuOptions = {}
            local displayMode = (global_state.launchMode == "Folder") and global_state.L.get("folder") or global_state.L.get("single_game")
            local displayView = (global_state.viewMode == "LIST") and global_state.L.get("list") or global_state.L.get("grid")
            if global_state.romPath ~= "@Favorites/" then
                table.insert(global_state.menuOptions, {text = global_state.L.get("mode") .. ": " .. displayMode, icon = global_state.iconGame})
            end
            table.insert(global_state.menuOptions, {text = global_state.L.get("view") .. ": " .. displayView, icon = global_state.iconFolder})
            table.insert(global_state.menuOptions, {text = global_state.L.get("hide_empty") .. ": " .. (global_state.hideEmpty and global_state.L.get("on") or global_state.L.get("off")), icon = global_state.iconHide})
            table.insert(global_state.menuOptions, {text = global_state.L.get("mark_played") .. ": " .. (global_state.markPlayed and global_state.L.get("yes") or global_state.L.get("no")), icon = global_state.iconRom})
            table.insert(global_state.menuOptions, {text = global_state.L.get("hide_favorites") .. ": " .. (global_state.hideFavorites and global_state.L.get("on") or global_state.L.get("off")), icon = global_state.iconHide})
            table.insert(global_state.menuOptions, {text = global_state.L.get("random_game"), icon = global_state.iconGame})
            if global_state.isVirtualRoot then
                table.insert(global_state.menuOptions, {text = global_state.L.get("switch_system"), icon = global_state.iconFolder})
            end
            table.insert(global_state.menuOptions, {text = global_state.L.get("reindex"), icon = global_state.iconReload})
            table.insert(global_state.menuOptions, {text = global_state.L.get("cleanup"), icon = global_state.iconTrash})
            table.insert(global_state.menuOptions, {text = global_state.L.get("api_settings"), icon = global_state.iconNetwork})
            global_state.inputCooldown = 0.2
            return
        end
    end

    -- Cancel batch scrape with B button
    if global_state.state == "BATCH_SCRAPING" and (key == "backspace" or key == "escape") then
        if not global_state.scraperCancel then
            global_state.log("Cancelling batch scrape...")
            global_state.scraperCancel = true
            global_state.indexerChannelIn:push({ command = "scrape_cancel" })
            global_state.inputCooldown = 0.2
        end
        return
    end

    local handler = stateHandlers[global_state.state]
    if handler then
        handler(key, global_state)
    else
        input_list.handleListInput(key, global_state)
    end
end

local function gamepadpressed(joystick, button, global_state)
    if button == "a" then
        keypressed("kpenter", global_state)
    elseif button == "b" then
        keypressed("backspace", global_state)
    elseif button == "y" then
        keypressed("tab", global_state)
    elseif button == "x" then
        keypressed("x", global_state)
    elseif button == "dpleft" then
        keypressed("left", global_state)
    elseif button == "dpright" then
        keypressed("right", global_state)
    elseif button == "back" then
        keypressed("f1", global_state)
    elseif button == "start" then
        keypressed("escape", global_state)
    elseif button == "leftshoulder" then
        keypressed("f", global_state)
    elseif button == "triggerleft" then
        keypressed("f2", global_state)
    elseif button == "rightshoulder" then
        keypressed("f3", global_state)
    elseif button == "triggerright" then
        keypressed("f4", global_state)
    end
end

local function joystickpressed(joystick, button, global_state)
    local isGamepad = joystick:isGamepad()

    if button == 4 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f", global_state)
    elseif button == 5 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f3", global_state)
    elseif button == 6 then
        if isGamepad and (joystick:isGamepadDown("a") or joystick:isGamepadDown("b") or joystick:isGamepadDown("x") or joystick:isGamepadDown("y")) then return end
        keypressed("f2", global_state)
    end
end

local function textinput(t, global_state)
    if global_state.showHelp then return end
    if global_state.state == "SEARCH" then
        global_state.searchQuery = global_state.searchQuery .. t
        helpers.filterFiles(global_state)
    elseif global_state.state == "EDIT_TEXT" then
        global_state.textToEdit = global_state.textToEdit .. t
    end
end

return {
    keypressed = keypressed,
    gamepadpressed = gamepadpressed,
    joystickpressed = joystickpressed,
    textinput = textinput,
    jumpToNextLetter = helpers.jumpToNextLetter,
    jumpToPrevLetter = helpers.jumpToPrevLetter,
    refreshFiles = helpers.refreshFiles,
    updateSystemPaths = helpers.updateSystemPaths,
}
