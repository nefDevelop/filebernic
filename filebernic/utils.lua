---@diagnostic disable: undefined-global
local M = {}

-- Grupos de variantes de nombres de sistemas (para buscar iconos)
local systemVariants = {
    -- Nintendo
    {"GBA", "gba", "Game Boy Advance", "Nintendo - Game Boy Advance"},
    {"SNES", "snes", "sfc", "Super Nintendo", "Super Famicom", "Nintendo - Super Nintendo Entertainment System"},
    {"NES", "nes", "fc", "Nintendo Entertainment System", "Famicom", "Nintendo - Nintendo Entertainment System"},
    {"GB", "gb", "Game Boy", "Nintendo - Game Boy"},
    {"FDS", "fds", "Famicom Disk System", "Nintendo - Family Computer Disk System"},
    {"GBC", "gbc", "Game Boy Color", "Nintendo - Game Boy Color"},
    {"N64", "n64", "Nintendo 64", "Nintendo - Nintendo 64"},
    {"NDS", "nds", "Nintendo DS", "Nintendo - Nintendo DS", "Nintendo - Nintendo DS Decrypted"},
    {"VB", "vb", "Virtual Boy", "Nintendo - Virtual Boy"},
    {"POKEMINI", "pokemini", "Pokemon Mini"},
    {"WII", "wii", "Nintendo - Wii"},
    {"SATELLAVIEW", "bs", "satellaview", "Nintendo - Satellaview"},
    {"SUFAMI", "sufami", "Nintendo - Sufami Turbo"},
    -- Sega
    {"MD", "md", "gen", "Genesis", "Mega Drive", "Sega - Mega Drive - Genesis"},
    {"SMS", "sms", "Master System", "Sega - Master System - Mark III"},
    {"GG", "gg", "Game Gear", "Sega - Game Gear"},
    {"SEGACD", "cd", "Mega CD", "Sega CD", "Sega - Mega-CD - Sega CD"},
    {"32X", "32x", "Sega 32X", "Sega - 32X"},
    {"DC", "dc", "Dreamcast", "Sega - Dreamcast"},
    {"ATOMISWAVE", "atomiswave", "Atomiswave"},
    {"NAOMI", "naomi", "Naomi"},
    {"PICO", "pico", "Sega Pico"},
    {"SG1000", "sg1000", "Sega SG-1000"},
    {"SATURN", "saturn", "Sega - Saturn"},
    -- Sony
    {"PS", "ps", "ps1", "psx", "PlayStation", "Sony - PlayStation"},
    {"PSP", "psp", "PlayStation Portable", "Sony - PlayStation Portable"},
    -- Arcade / SNK
    {"MAME", "mame", "arcade", "fbneo", "Arcade", "FB Alpha - Arcade Games"},
    {"NEOGEO", "neogeo", "SNK - Neo Geo", "Neo Geo"},
    {"NEOGEOCD", "neogeocd", "ngcd", "Neo Geo CD"},
    {"NGP", "ngp", "Neo Geo Pocket", "SNK - Neo Geo Pocket"},
    {"NGPC", "ngpc", "Neo Geo Pocket Color", "SNK - Neo Geo Pocket Color"},
    -- NEC
    {"PCE", "pce", "PC Engine", "TurboGrafx-16", "NEC - PC Engine - TurboGrafx 16"},
    {"PCECD", "pcecd", "PC Engine CD", "NEC - PC Engine CD - TurboGrafx-CD"},
    {"SGX", "sgx", "SuperGrafx", "NEC - PC Engine SuperGrafx"},
    {"PC88", "pc88", "NEC PC-8800"},
    {"PC98", "pc98", "NEC PC-98"},
    {"PCFX", "pcfx", "NEC PC-FX", "NEC - PC-FX"},
    -- Atari
    {"ATARI2600", "a2600", "a26", "Atari 2600", "Atari - 2600"},
    {"ATARI5200", "a5200", "a52", "Atari 5200"},
    {"ATARI7800", "a7800", "a78", "Atari 7800", "Atari - 7800"},
    {"JAGUAR", "jaguar", "Atari Jaguar", "Atari - Jaguar"},
    {"LYNX", "lynx", "Atari Lynx", "Atari - Lynx"},
    {"ATARIST", "atarist", "st", "Atari ST", "Atari - ST"},
    -- Others
    {"AMSTRAD", "cpc", "amstrad", "Amstrad CPC"},
    {"ARDUBOY", "arduboy", "Arduboy"},
    {"WS", "ws", "WonderSwan", "Bandai - WonderSwan"},
    {"WSC", "wsc", "WonderSwan Color", "Bandai - WonderSwan Color"},
    {"BOOKS", "books", "ebooks", "Book Reader"},
    {"CAVESTORY", "cavestory", "doukutsu", "Cave Story"},
    {"CHAILOVE", "chailove", "ChaiLove"},
    {"CHIP8", "chip8", "CHIP-8"},
    {"COLECO", "coleco", "colecovision", "ColecoVision", "Coleco - ColecoVision"},
    {"PICO8", "pico8", "p8", "PICO-8"},
    {"DOS", "dos", "MS-DOS", "DOS"},
    {"DOOM", "doom", "Doom"},
    {"PORTS", "ports", "Ports"},
    {"CHANNELF", "channelf", "Fairchild Channel F"},
    {"VECTREX", "vectrex", "Vectrex", "GCE - Vectrex"},
    {"GW", "gw", "gameandwatch", "Game & Watch"},
    {"J2ME", "j2me", "java", "Java J2ME"},
    {"LOWRESNX", "lowresnx", "Lowres NX"},
    {"LUTRO", "lutro", "Lutro"},
    {"ODYSSEY2", "odyssey2", "o2", "Magnavox Odyssey 2", "Magnavox - Odyssey2"},
    {"INTELLIVISION", "intellivision", "intv", "Intellivision"},
    {"MEGADUCK", "megaduck", "Mega Duck"},
    {"AMIGA", "amiga", "Commodore Amiga"},
    {"C64", "c64", "Commodore 64"},
    {"C128", "c128", "Commodore 128"},
    {"VIC20", "vic20", "Commodore VIC-20"},
    {"PET", "pet", "Commodore PET"},
    {"MSX", "msx", "msx1", "msx2", "MSX", "Microsoft - MSX", "Microsoft - MSX2"},
    {"SCUMMVM", "scummvm", "ScummVM"},
    {"OPENBOR", "openbor", "OpenBOR"},
    {"CDI", "cdi", "Philips CD-i"},
    {"QUAKE", "quake", "Quake", "Quake1"},
    {"EASYRPG", "easyrpg", "RPG Maker"},
    {"X1", "x1", "Sharp X1"},
    {"X68000", "x68000", "Sharp X68000"},
    {"ZX81", "zx81", "Sinclair ZX81"},
    {"ZXSPECTRUM", "zxspectrum", "spectrum", "ZX Spectrum", "Sinclair - ZX Spectrum +3"},
    {"TIC80", "tic80", "TIC-80"},
    {"TI83", "ti83", "Texas Instruments TI-83"},
    {"3DO", "3do", "3DO", "The 3DO Company - 3DO"},
    {"UZEBOX", "uzebox", "Uzebox"},
    {"VMU", "vmu", "VeMUlator"},
    {"VIRCON32", "vircon32", "Vircon32"},
    {"WASM4", "wasm4", "WASM-4"},
    {"SUPERVISION", "supervision", "Watara Supervision"},
    {"WOLF3D", "wolf3d", "Wolfenstein 3D"}
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
    if not sysName then return {} end
    return variantToGroup[sysName:lower()] or {sysName}
end

function M.getSystemDisplayName(sysName)
    if not sysName then return sysName end
    return variantToDisplay[sysName:lower()] or sysName
end

local systemIconCache = {}

function M.getSystemIcon(sysName, fs_getInfo, gfx_newImage)
    if not sysName then return nil end
    if systemIconCache[sysName] then return systemIconCache[sysName] end

    local variants = M.getSystemVariants(sysName)

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. ".png" -- Construct path
        if fs_getInfo(path) then -- Check if file exists
            local img = gfx_newImage(path) -- Load image
            systemIconCache[sysName] = img
            return img
        end
    end
    return nil
end
local systemContentIconCache = {}

function M.getSystemContentIcon(sysName, fs_getInfo, gfx_newImage)
    if not sysName then return nil end
    if systemContentIconCache[sysName] then return systemContentIconCache[sysName] end
    local variants = M.getSystemVariants(sysName)

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. "-content.png"
        if fs_getInfo(path) then
            local img = gfx_newImage(path)
            systemContentIconCache[sysName] = img
            return img
        end
    end
    return nil
end

function M.getSystemNameForItem(item, globalSystemName, globalIsVirtualRoot)
    if not item then return nil end

    -- 1. Check pre-assigned system property (most reliable, for virtual root)
    if item.system and item.system ~= "UNK" then
        return item.system
    end

    -- 2. Try to detect from full path (case-sensitive to preserve folder name)
    if item.fullPath then
        local fromPath = item.fullPath:match("ROMS/([^/]+)/") or item.fullPath:match("Simulador_SD/([^/]+)/")
        if fromPath then return fromPath end
    end

    -- 3. If not in virtual root, the global systemName is the fallback
    if not globalIsVirtualRoot and globalSystemName and globalSystemName ~= "" then
        return globalSystemName
    end

    -- 4. Fallback to extension (least reliable)
    if item.name then
        local ext = item.name:match("%.([^%.]+)$")
        if ext then return ext end
    end

    return nil
end

-- Utility function to split a string by a delimiter
function M.split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

-- Helper para codificar URL
local function urlencode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w %-%_%.%~])",
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "%%20")
    end
    return str
end
M.urlencode = urlencode

return M
