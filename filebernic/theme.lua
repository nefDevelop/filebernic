---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local theme = {}

-- Path to the new font
local font_path = "assets/JetBrainsMono-Regular.ttf"

--[[
  To change the theme, modify the color values below.
  Colors are defined in a range from 0 to 1 (e.g., 255, 255, 255 -> 1, 1, 1).
]]
theme.colors = {
    background = {0.02, 0.02, 0.02},
    bottom_bar_background = {0.15, 0.15, 0.2},
    text_bright = {0.9, 0.9, 0.9},
    text_white = {1, 1, 1},
    text_medium = {0.8, 0.8, 0.8},
    text_dim = {0.7, 0.7, 0.7},
    text_disabled = {0.5, 0.5, 0.5},

    overlay_dark = {0, 0, 0, 0.75},
    side_menu_background = {0.15, 0.15, 0.17, 1.0},
    side_menu_separator = {0.3, 0.3, 0.3},

    list_selection = {0.2, 0.4, 0.8},
    list_played_selected = {0.05, 0.35, 0.1},
    list_played_unselected = {0.05, 0.35, 0.1},
    
    selection_accent = {0.2, 0.6, 1}, -- Used for menus and selected file text
    
    placeholder_background = {0.4, 0.4, 0.4},

    scrollbar_background = {0.2, 0.2, 0.2},
    scrollbar_handle = {0.3, 0.6, 1},
}

-- Fonts using the new font file
-- If the font file doesn't load, love.graphics.newFont will use the default font.
if love.filesystem.getInfo(font_path) then
    theme.fonts = {
        list = love.graphics.newFont(font_path, 18),
        title = love.graphics.newFont(font_path, 24),
        small = love.graphics.newFont(font_path, 14), -- Increased size for better readability
        medium = love.graphics.newFont(font_path, 16),
        huge = love.graphics.newFont(font_path, 84),
    }
else
    -- Fallback to default font if the custom one is not found
    theme.fonts = {
        list = love.graphics.newFont(18),
        title = love.graphics.newFont(24),
        small = love.graphics.newFont(12),
        medium = love.graphics.newFont(16),
        huge = love.graphics.newFont(84),
    }
end

return theme
