---@diagnostic disable: undefined-global
local M = {}
local helpers = require "draw_helpers"

function M.drawBottomBar(global_state)
    local w, h = love.graphics.getDimensions()
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(theme.colors.bottom_bar_background)
    love.graphics.rectangle("fill", 0, h - 30, w, 30)
    love.graphics.setColor(theme.colors.text_bright)

    local barCenterY = h - 15
    local textH = fontMedium:getHeight()
    local textY = barCenterY - textH / 2

    local desiredIconHeight = 22
    local x = 20

    local function drawHint(icon, text)
        local scale = desiredIconHeight / icon:getHeight()
        local iconY = barCenterY - (icon:getHeight() * scale) / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
        x = x + love.graphics.getFont():getWidth(text) + 20
    end

    if global_state.state == "LIST" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
        drawHint(global_state.buttonIcons.y, global_state.L.get("options"))
        local icon = global_state.buttonIcons.select
        local scale = desiredIconHeight / icon:getHeight()
        local text = global_state.L.get("exit")
        local iconY = barCenterY - (icon:getHeight() * scale) / 2
        love.graphics.draw(icon, x, iconY, 0, scale, scale)
        x = x + (icon:getWidth() * scale) + 5
        love.graphics.print(text, x, textY)
    elseif global_state.state == "DELETE_MENU" or global_state.state == "POST_GAME" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("confirm"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("cancel"))
    elseif global_state.state == "INFO_VIEW" then
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "OPTIONS_MENU" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
        drawHint(global_state.buttonIcons.r1, global_state.L.get("help"))
        drawHint(global_state.buttonIcons.select, global_state.L.get("exit"))
    elseif global_state.state == "SCRAPER_VIEW" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "EDIT_TEXT" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("cancel"))
    elseif global_state.state == "SCRAPER_OPTIONS" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("accept"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "SCRAPER_RESULTS" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("save"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "SAVE_MANAGER" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("copy"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    elseif global_state.state == "CLEANUP_MENU" then
        drawHint(global_state.buttonIcons.a, global_state.L.get("delete"))
        drawHint(global_state.buttonIcons.b, global_state.L.get("back"))
    end
end

function M.drawTopBar(global_state, w, h)
    local topBarCenterY = 22
    love.graphics.setColor(theme.colors.text_bright)
    love.graphics.setFont(fontTopBar)
    love.graphics.printf(L.get("app_title"), 0, topBarCenterY - fontTopBar:getHeight()/2, w, "center")
    love.graphics.setFont(global_state.fontClock)
    love.graphics.print(os.date("%H:%M"), 20, topBarCenterY - fontClock:getHeight()/2)
    helpers.drawBattery(global_state, w - 20, topBarCenterY + 3)
end

return M
