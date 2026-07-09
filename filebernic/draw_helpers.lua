---@diagnostic disable: undefined-global
local M = {}

local round = math.round or love.math.round or function(x)
    return math.floor(x + 0.5)
end

local lerp = love.math.lerp or function(a, b, t)
    return a + (b - a) * t
end

M.ditherShader = love.graphics.newShader[[
    extern vec2 objPos;
    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 p = floor((screen_coords.xy - objPos) / 3.0);
        int x = int(mod(p.x, 4.0));
        int y = int(mod(p.y, 4.0));
        float t = 0.0;
        if (x == 0) { if (y == 0) t = 0.0; else if (y == 1) t = 12.0; else if (y == 2) t = 3.0; else t = 15.0; }
        else if (x == 1) { if (y == 0) t = 8.0; else if (y == 1) t = 4.0; else if (y == 2) t = 11.0; else t = 7.0; }
        else if (x == 2) { if (y == 0) t = 2.0; else if (y == 1) t = 14.0; else if (y == 2) t = 1.0; else t = 13.0; }
        else { if (y == 0) t = 10.0; else if (y == 1) t = 6.0; else if (y == 2) t = 9.0; else t = 5.0; }
        if (color.a <= (t / 16.0)) {
            discard;
        }
        return vec4(color.rgb, 1.0);
    }
]]

local gradientMesh
function M.getGradientMesh()
    if not gradientMesh then
        local vertices = {
            {0, 0, 0, 0, 1, 1, 1, 0},
            {1, 0, 1, 0, 1, 1, 1, 1},
            {1, 1, 1, 1, 1, 1, 1, 1},
            {0, 1, 0, 1, 1, 1, 1, 0}
        }
        gradientMesh = love.graphics.newMesh(vertices, "fan", "static")
    end
    return gradientMesh
end

local fadeGradientMesh
function M.getFadeGradientMesh()
    if not fadeGradientMesh then
        local vertices = utils.createGradientVertices("left", 0, 1, 1, 1, 1, 1, 1.0, 40)
        fadeGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    return fadeGradientMesh
end

local playedGameGradientMesh
function M.getPlayedGameGradientMesh()
    if not playedGameGradientMesh then
        local vertices = utils.createGradientVertices("left", 25, 1, 1, 1, 1, 1, 1.0, 60)
        playedGameGradientMesh = love.graphics.newMesh(vertices, "strip", "static")
    end
    return playedGameGradientMesh
end

M.topGradientMesh = nil
M.bottomGradientMesh = nil

function M.drawTrimmed(text, x, y, limit, font)
    local dText = text
    if font:getWidth(dText) > limit then
        while font:getWidth(dText .. "...") > limit and #dText > 0 do
            dText = dText:sub(1, -2)
        end
        dText = dText .. "..."
    end
    love.graphics.print(dText, x, y)
end

function M.drawTrimmedStart(text, x, y, limit, font)
    local dText = text
    if font:getWidth(dText) > limit then
        while font:getWidth("..." .. dText) > limit and #dText > 0 do
            dText = dText:sub(2)
        end
        dText = "..." .. dText
    end
    love.graphics.print(dText, x, y)
end

function M.calculateItemDisplayWidth(item, layout, fontList, launchMode, romPath, iconFavorite, favScale, favoriteRoms, sdColX, itemIndex, favAnimState)
    if not item then return layout.selWidth + 2 end

    local isActuallyFav = (favoriteRoms[item.fullPath]) and romPath ~= "@Favorites/"
    local isAnimating = favAnimState and itemIndex and itemIndex == favAnimState.index

    if not isAnimating then
        local cacheKey = tostring(launchMode) .. "_" .. tostring(isActuallyFav) .. "_" .. tostring(sdColX)
        if item._widthCacheVal and item._widthCacheKey == cacheKey then
            return item._widthCacheVal
        end
    end

    local nameToMeasure = item.name
    if not item.isDir then
        nameToMeasure = nameToMeasure:gsub("%.[^%.]+$", "")
    end

    local animFactor = 0
    if isActuallyFav then animFactor = 1 end
    if isAnimating then
        animFactor = favAnimState.anim
    end

    local itemFavOffset = 0
    if animFactor > 0 then
        itemFavOffset = ((iconFavorite:getWidth() * favScale) + 10) * animFactor
    end

    local calculatedWidth = layout.selWidth
    if (launchMode == "Folder" or launchMode == "Juego Unico") then
        local textRightBoundary = sdColX or (layout.selX + layout.selWidth)
        local tempAvailableWidth = textRightBoundary - (layout.selX + 70) - 10

        local trimmedName = nameToMeasure
        if fontList:getWidth(trimmedName) > tempAvailableWidth then
            local avgCharW = 10
            local maxChars = math.ceil(tempAvailableWidth / avgCharW) + 10
            if #trimmedName > maxChars then trimmedName = trimmedName:sub(1, maxChars) end

            while fontList:getWidth(trimmedName .. "...") > tempAvailableWidth and #trimmedName > 0 do
                trimmedName = trimmedName:sub(1, -2)
            end
            trimmedName = trimmedName .. "..."
        end
        local textW = fontList:getWidth(trimmedName)
        calculatedWidth = 70 + itemFavOffset + textW + 20
        if calculatedWidth > layout.selWidth then calculatedWidth = layout.selWidth end
    end

    if not isAnimating then
        item._widthCacheVal = calculatedWidth + 2
        item._widthCacheKey = tostring(launchMode) .. "_" .. tostring(isActuallyFav) .. "_" .. tostring(sdColX)
    end
    return calculatedWidth + 2
end

function M.drawScrollbar(global_state)
    local scrollW = 2
    love.graphics.setColor(theme.colors.scrollbar_background)
    love.graphics.rectangle("fill", global_state.layout.scrollbarX, global_state.layout.listY, scrollW, global_state.layout.scrollbarH)
    if #global_state.files > 1 then
        local visibleRows = global_state.pageSize + 1
        local h = global_state.layout.scrollbarH / (#global_state.files / visibleRows)
        local y = global_state.layout.listY + ((global_state.animatedSelectionIndex - 1) / (#global_state.files - 1)) * (global_state.layout.scrollbarH - h)
        love.graphics.setColor(theme.colors.scrollbar_handle)
        love.graphics.rectangle("fill", global_state.layout.scrollbarX, y, scrollW, math.max(10, h))
    end
end

local internetStatus = false
local lastInternetCheck = -10
local batteryImageCache = {}

function M.drawBattery(global_state, x, centerY)
    local now = love.timer.getTime()
    if now - lastInternetCheck > 15 then
        lastInternetCheck = now
        local f = io.open("/sys/class/net/wlan0/operstate", "r")
        if f then
            local status = f:read("*a")
            f:close()
            internetStatus = (status and status:match("up")) ~= nil
        else
            internetStatus = false
        end
    end

    if global_state.iconNetwork then
        if internetStatus then love.graphics.setColor(1, 1, 1, 1)
        else love.graphics.setColor(0.5, 0.5, 0.5, 1) end
        local targetH = 18
        local scale = targetH / global_state.iconNetwork:getHeight()
        local nw = global_state.iconNetwork:getWidth() * scale
        love.graphics.draw(global_state.iconNetwork, x - 26 - 8 - nw, centerY - (global_state.iconNetwork:getHeight() * scale) / 2, 0, scale, scale)
    end

    local state, percent = love.system.getPowerInfo()
    if state == "nobattery" or not percent then
        percent = 100
        state = "charged"
    end

    local imageName
    if state == "charging" then
        imageName = "charging"
    else
        if percent > 80 then imageName = "100"
        elseif percent > 60 then imageName = "80"
        elseif percent > 40 then imageName = "60"
        elseif percent > 20 then imageName = "40"
        else imageName = "20"
        end
    end

    local imagePath = "assets/battery/battery_" .. imageName .. ".png"

    if not batteryImageCache[imagePath] then
        local success, img = pcall(love.graphics.newImage, imagePath)
        if success then
            batteryImageCache[imagePath] = img
        else
            batteryImageCache[imagePath] = "error"
        end
    end

    local img = batteryImageCache[imagePath]
    if img and img ~= "error" then
        local r, g, b, a = 1, 1, 1, 1
        if state == "charging" then
            r, g, b = 0.2, 1, 0.2
        else
            if percent <= 10 then
                r, g, b = 1, 0.2, 0.2
                a = (math.sin(love.timer.getTime() * 10) + 1) / 2
            elseif percent <= 20 then
                r, g, b = 1, 0.2, 0.2
            end
        end
        love.graphics.setColor(r, g, b, a)
        local imgW, imgH = img:getWidth(), img:getHeight()
        love.graphics.draw(img, x - imgW, centerY - imgH/2)
    else
        local batW, batH = 26, 14
        local nippleW, nippleH = 3, 6
        local batY = centerY - batH/2
        love.graphics.setColor(theme.colors.text_bright)
        love.graphics.rectangle("line", x - batW, batY, batW, batH, 2)
        love.graphics.rectangle("fill", x, batY + (batH - nippleH)/2, nippleW, nippleH)
        local margin = 2; local maxFill = batW - (margin * 2); local fill = math.max(0, maxFill * (percent / 100))
        if state == "charging" then
            love.graphics.setColor(0.2, 1, 0.2)
        elseif percent <= 20 then
            local a = 1
            if percent <= 10 then a = (math.sin(love.timer.getTime() * 10) + 1) / 2 end
            love.graphics.setColor(1, 0.2, 0.2, a)
        end
        love.graphics.rectangle("fill", x - batW + margin, batY + margin, fill, batH - (margin * 2))
    end
end

function M.drawJumpLetter(global_state)
    if global_state.jumpPanelAnim <= 0 or global_state.jumpLetter == "" then return end

    local w, h = love.graphics.getDimensions()

    local t = global_state.jumpPanelAnim
    local ease = 1 - (1 - t)^3
    local slide = (1 - ease) * 140

    local panelW = 120
    local panelH = 120
    local x = w - panelW + slide
    local y = h - 160

    love.graphics.setColor(0.15, 0.15, 0.17, 0.9)
    love.graphics.rectangle("fill", x, y, panelW + 10, panelH, 10)
    love.graphics.setColor(theme.colors.selection_accent)
    love.graphics.rectangle("line", x, y, panelW + 10, panelH, 10)

    love.graphics.setFont(global_state.fontHuge)

    local scale = 1
    local textW = global_state.fontHuge:getWidth(global_state.jumpLetter)
    local textH = global_state.fontHuge:getHeight()

    local drawX = x + panelW / 2
    local drawY = y + panelH / 2

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(global_state.jumpLetter, drawX, drawY, 0, scale, scale, textW / 2, textH / 2)
end

M.round = round
M.lerp = lerp

return M
