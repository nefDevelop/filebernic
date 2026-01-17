local M = {}

-- Grupos de variantes de nombres de sistemas (para buscar iconos)
local systemVariants = {
    -- Nintendo
    {"GBA", "gba", "Nintendo - Game Boy Advance", "Game Boy Advance"},
    {"SNES", "snes", "sfc", "Super Nintendo", "Super Famicom", "Nintendo - Super Nintendo Entertainment System"},
    {"NES", "nes", "fc", "Nintendo Entertainment System", "Famicom", "Nintendo - Nintendo Entertainment System"},
    {"GB", "gb", "Game Boy", "Nintendo - Game Boy"},
    {"GBC", "gbc", "Game Boy Color", "Nintendo - Game Boy Color"},
    {"N64", "n64", "Nintendo 64", "Nintendo - Nintendo 64"},
    {"NDS", "nds", "Nintendo DS", "Nintendo - Nintendo DS"},
    {"VB", "vb", "Virtual Boy"},
    {"POKEMINI", "pokemini", "Pokemon Mini"},
    -- Sega
    {"MD", "md", "gen", "Genesis", "Mega Drive", "Sega - Mega Drive - Genesis"},
    {"SMS", "sms", "Master System", "Sega - Master System - Mark III"},
    {"GG", "gg", "Game Gear", "Sega - Game Gear"},
    {"SEGACD", "cd", "Mega CD", "Sega CD"},
    {"32X", "32x", "Sega 32X"},
    {"DC", "dc", "Dreamcast", "Sega - Dreamcast"},
    {"SATURN", "saturn", "Sega - Saturn"},
    -- Sony
    {"PS", "ps", "ps1", "psx", "PlayStation", "Sony - PlayStation"},
    {"PSP", "psp", "PlayStation Portable", "Sony - PlayStation Portable"},
    -- Arcade / SNK
    {"MAME", "mame", "arcade", "fbneo", "Arcade"},
    {"NEOGEO", "neogeo", "SNK - Neo Geo"},
    {"NGP", "ngp", "Neo Geo Pocket"},
    {"NGPC", "ngpc", "Neo Geo Pocket Color"},
    -- NEC
    {"PCE", "pce", "PC Engine", "TurboGrafx-16", "NEC - PC Engine - TurboGrafx 16"},
    {"PCECD", "pcecd", "PC Engine CD"},
    -- Atari
    {"ATARI2600", "a2600", "a26", "Atari 2600"},
    {"ATARI7800", "a7800", "a78", "Atari 7800"},
    {"LYNX", "lynx", "Atari Lynx"},
    -- Others
    {"WS", "ws", "WonderSwan"},
    {"WSC", "wsc", "WonderSwan Color"},
    {"PICO8", "pico8", "p8", "PICO-8"},
    {"DOS", "dos", "MS-DOS"},
    {"AMIGA", "amiga", "Commodore Amiga"},
    {"C64", "c64", "Commodore 64"},
    {"MSX", "msx", "msx1", "msx2", "MSX"},
    {"SCUMMVM", "scummvm", "ScummVM"},
    {"OPENBOR", "openbor", "OpenBOR"}
}

-- Pre-calcular tablas de búsqueda para rendimiento O(1)
local variantToGroup = {}
local variantToDisplay = {}

for _, group in ipairs(systemVariants) do
    local display = group[#group]
    for _, v in ipairs(group) do
        local lowerV = v:lower()
        variantToGroup[lowerV] = group
        variantToDisplay[lowerV] = display
    end
end

function M.getSystemVariants(sysName)
    log("M.getSystemVariants called with sysName: " .. tostring(sysName))
    if not sysName then return {} end
    return variantToGroup[sysName:lower()] or {sysName}
end

function M.getSystemDisplayName(sysName)
    log("M.getSystemDisplayName called with sysName: " .. tostring(sysName))
    if not sysName then return sysName end
    return variantToDisplay[sysName:lower()] or sysName
end

function M.getSystemNameForItem(item)
    log("M.getSystemNameForItem called")
    if not item then return nil end

    -- 1. Check pre-assigned system property (most reliable, for virtual root)
    if item.system and item.system ~= "UNK" then
        return item.system
    end

    -- 2. Try to detect from full path (case-insensitive)
    if item.fullPath then
        local lowerPath = item.fullPath:lower()
        local fromPath = lowerPath:match("roms/([^/]+)/") or lowerPath:match("simulador_sd/([^/]+)/")
        if fromPath then return fromPath end
    end

    -- 3. If not in virtual root, the global systemName is the fallback
    if not isVirtualRoot and systemName and systemName ~= "" then
        return systemName
    end

    -- 4. Fallback to extension (least reliable)
    if item.name then
        local ext = item.name:match("%.([^%.]+)$")
        if ext then return ext:lower() end
    end

    return nil
end

-- Utility function to split a string by a delimiter
function M.split(s, delimiter)
    log("M.split called")
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- Helper para codificar URL
local function urlencode(str)
    log("urlencode called")
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w %-%_%.%~])",
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
    end
    return str
end
M.urlencode = urlencode

return M
