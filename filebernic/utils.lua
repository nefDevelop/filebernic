---@diagnostic disable: undefined-global
local M = {}

-- Rutas de dispositivo
M.SD1_ROOT = "/mnt/mmc"
M.SD2_ROOT = "/mnt/sdcard"
M.SIM_PREFIX = "Simulador_SD"
M.MUOS_CATALOGUE = "MUOS/info/catalogue/"
M.MUOS_SAVE = "MUOS/save/"
M.ROMS_DIR = "ROMS"

function M.isDevice()
    local f = io.open(M.SD1_ROOT, "r")
    if f then f:close(); return true end
    return false
end

function M.getBaseMuosPath()
    if M.isDevice() then
        return M.SD1_ROOT .. "/" .. M.MUOS_CATALOGUE
    else
        local cwd = love.filesystem.getSource()
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        return cwd .. "/../" .. M.SIM_PREFIX .. "/" .. M.MUOS_CATALOGUE
    end
end

-- Grupos de variantes de nombres de sistemas (para buscar iconos)
local systemVariants = {
    -- Nintendo
    {"GBA", "gba", "Game Boy Advance", "Nintendo - Game Boy Advance"},
    {"SNES", "snes", "sfc", "Super Nintendo", "Super Famicom", "Nintendo - Super Nintendo Entertainment System"},
    {"NES", "nes", "fc", "Nintendo Entertainment System", "Famicom", "Nintendo - Nintendo Entertainment System"},
    {"GB", "gb", "Game Boy", "Nintendo - Game Boy"},
    {"FDS", "fds", "Famicom Disk System", "Nintendo - Family Computer Disk System", "Family Computer"},
    {"GBC", "gbc", "Game Boy Color", "Nintendo - Game Boy Color"},
    {"N64", "n64", "Nintendo 64", "Nintendo - Nintendo 64"},
    {"NDS", "nds", "Nintendo DS", "Nintendo - Nintendo DS", "Nintendo - Nintendo DS Decrypted"},
    {"VB", "vb", "Virtual Boy", "Nintendo - Virtual Boy"},
    {"POKEMINI", "pokemini", "Pokemon Mini"},
    {"WII", "wii", "Nintendo - Wii"},
    {"SATELLAVIEW", "bs", "satellaview", "Nintendo - Satellaview"},
    {"SUFAMI", "sufami", "Nintendo - Sufami Turbo"},
    -- Sega
    {"MD", "md", "gen", "Genesis", "Mega Drive", "Mega", "Sega - Mega Drive - Genesis"},
    {"SMS", "sms", "Master System", "Sega - Master System - Mark III"},
    {"GG", "gg", "Game Gear", "Sega - Game Gear"},
    {"SEGACD", "cd", "Mega CD", "Sega CD", "Sega - Mega-CD - Sega CD"},
    {"32X", "32x", "Sega 32X", "Sega - 32X"},
    {"DC", "dc", "Dreamcast", "Sega - Dreamcast"},
    {"ATOMISWAVE", "atomiswave", "Naomi", "Atomiswave"},
    {"NAOMI", "naomi", "Atomiswave", "Naomi"},
    {"PICO", "pico", "Sega Pico"},
    {"SG1000", "sg1000", "Sega SG-1000"},
    {"SATURN", "saturn", "Sega - Saturn"},
    -- Sony
    {"PS", "ps", "ps1", "psx", "PlayStation", "Sony", "Sony - PlayStation"},
    {"PSP", "psp", "PlayStation Portable", "Sony - PlayStation Portable"},
    -- Arcade / SNK
    {"MAME", "mame", "arcade", "fbneo", "Arcade", "FB Alpha - Arcade Games"},
    {"NEOGEO", "neogeo", "SNK - Neo Geo", "Neo Geo"},
    {"NEOGEOCD", "neogeocd", "ngcd", "Neo Geo CD"},
    {"NGP", "ngp", "Neo Geo Pocket", "SNK - Neo Geo Pocket"},
    {"NGPC", "ngpc", "Neo Geo Pocket Color", "SNK - Neo Geo Pocket Color"},
    -- NEC
    {"PCE", "pce", "PC Engine", "TurboGrafx-16", "Turbo", "NEC - PC Engine - TurboGrafx 16"},
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

function M.isKnownSystem(sysName)
    if not sysName then return false end
    return variantToGroup[sysName:lower()] ~= nil
end

function M.getSystemDisplayName(sysName)
    if not sysName then return sysName end
    return variantToDisplay[sysName:lower()] or sysName
end

local systemIconCache = {} -- Cache for system icons

function M.getSystemIcon(sysName, fs_getInfo, gfx_newImage) -- Now accepts fs_getInfo and gfx_newImage
    if not sysName then return nil end
    if systemIconCache[sysName] then return systemIconCache[sysName] end

    local variants = M.getSystemVariants(sysName)

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. ".png"
        if fs_getInfo(path) then -- Check if file exists
            local img = gfx_newImage(path) -- Load image
            systemIconCache[sysName] = img
            return img
        end
    end
    return nil
end
local systemContentIconCache = {} -- Cache for system content icons

function M.getSystemContentIcon(sysName, fs_getInfo, gfx_newImage) -- Now accepts fs_getInfo and gfx_newImage
    if not sysName then return nil end
    if systemContentIconCache[sysName] then return systemContentIconCache[sysName] end
    local variants = M.getSystemVariants(sysName)

    for _, v in ipairs(variants) do
        local path = "assets/systems/" .. v .. "-content.png"
        if fs_getInfo(path) then -- Check if file exists
            local img = gfx_newImage(path)
            systemContentIconCache[sysName] = img
            return img
        end
    end
    return nil
end

function M.getSystemNameForItem(item, globalSystemName, globalIsVirtualRoot) -- Now accepts globalSystemName and globalIsVirtualRoot
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

-- Escapa de forma segura un argumento para Bash/sh
function M.escapeShellArg(str)
    if not str then return "''" end
    return "'" .. tostring(str):gsub("'", "'\"'\"'") .. "'"
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

function M.atomicWrite(path, content)
    local tmpPath = path .. ".tmp"
    local f = io.open(tmpPath, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return os.rename(tmpPath, path)
end

-- Function to create vertices for a gradient mesh (type "strip")
-- direction: "top", "bottom", "left", "right"
-- opaque_percentage: 0-100 (percentage of length that is fully opaque before fading)
-- length: total length of the gradient (e.g., height for "top"/"bottom", width for "left"/"right")
-- width: perpendicular width of the gradient (e.g., width for "top"/"bottom", height for "left"/"right")
-- r, g, b: color components (0-1) for the opaque part of the gradient
function M.createGradientVertices(direction, opaque_percentage, length, width, r, g, b, max_alpha, fade_end_percentage)
    local vertices = {}
    local p = math.max(0, math.min(1, opaque_percentage / 100)) -- Opaque percentage as a fraction
    local p_end = fade_end_percentage and math.max(0, math.min(1, fade_end_percentage / 100)) or 1
    local a = max_alpha or 1

    -- Ensure color components are valid
    r = r or 1
    g = g or 1
    b = b or 1

    if direction == "top" then
        local y_opaque_end = length * p
        -- Vertices for a strip mesh (x, y, u, v, r, g, b, a)
        -- Top-Left, Opaque
        table.insert(vertices, {0, 0, 0, 0, r, g, b, a})
        -- Top-Right, Opaque
        table.insert(vertices, {width, 0, 1, 0, r, g, b, a})
        -- Transition-Left, Opaque
        table.insert(vertices, {0, y_opaque_end, 0, p, r, g, b, a})
        -- Transition-Right, Opaque
        table.insert(vertices, {width, y_opaque_end, 1, p, r, g, b, a})
        -- Bottom-Left, Transparent
        table.insert(vertices, {0, length, 0, 1, r, g, b, 0})
        -- Bottom-Right, Transparent
        table.insert(vertices, {width, length, 1, 1, r, g, b, 0})
    elseif direction == "bottom" then
        local y_opaque_start = length * (1 - p)
        -- Top-Left, Transparent
        table.insert(vertices, {0, 0, 0, 0, r, g, b, 0})
        -- Top-Right, Transparent
        table.insert(vertices, {width, 0, 1, 0, r, g, b, 0})
        -- Transition-Left, Opaque
        table.insert(vertices, {0, y_opaque_start, 0, 1 - p, r, g, b, a})
        -- Transition-Right, Opaque
        table.insert(vertices, {width, y_opaque_start, 1, 1 - p, r, g, b, a})
        -- Bottom-Left, Opaque
        table.insert(vertices, {0, length, 0, 1, r, g, b, a})
        -- Bottom-Right, Opaque
        table.insert(vertices, {width, length, 1, 1, r, g, b, a})
    elseif direction == "left" then
        local x_opaque_end = width * p
        local x_fade_end = width * p_end
        table.insert(vertices, {0, 0, 0, 0, r, g, b, a})
        table.insert(vertices, {0, length, 0, 1, r, g, b, a})
        table.insert(vertices, {x_opaque_end, 0, p, 0, r, g, b, a})
        table.insert(vertices, {x_opaque_end, length, p, 1, r, g, b, a})
        table.insert(vertices, {x_fade_end, 0, p_end, 0, r, g, b, 0})
        table.insert(vertices, {x_fade_end, length, p_end, 1, r, g, b, 0})
        if p_end < 1 then
            table.insert(vertices, {width, 0, 1, 0, r, g, b, 0})
            table.insert(vertices, {width, length, 1, 1, r, g, b, 0})
        end
    elseif direction == "right" then
        local x_opaque_start = width * (1 - p)
        table.insert(vertices, {0, 0, 0, 0, r, g, b, 0})
        table.insert(vertices, {0, length, 0, 1, r, g, b, 0})
        table.insert(vertices, {x_opaque_start, 0, 1 - p, 0, r, g, b, a})
        table.insert(vertices, {x_opaque_start, length, 1 - p, 1, r, g, b, a})
        table.insert(vertices, {width, 0, 1, 0, r, g, b, a})
        table.insert(vertices, {width, length, 1, 1, r, g, b, a})
    end
    return vertices
end

function M.semverCompare(v1, v2)
    local function split(v)
        local parts = {}
        for p in v:gmatch("%d+") do table.insert(parts, tonumber(p)) end
        return parts
    end
    local a, b = split(v1), split(v2)
    for i = 1, math.max(#a, #b) do
        local na, nb = a[i] or 0, b[i] or 0
        if na ~= nb then return na > nb end
    end
    return false
end

function M.checkGitHubUpdate(currentVersion, customRepo)
    local json = require "libs.dkjson"
    local repo = customRepo or "nef734/filebernic"
    local url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local cmd = "curl -s -L -k --max-time 10 -A 'Mozilla/5.0' '" .. url .. "' 2>/dev/null"

    local handle = io.popen(cmd)
    local response = handle and handle:read("*a") or ""
    if handle then handle:close() end

    if response ~= "" and response:sub(1,1) == "{" then
        local data = json.decode(response)
        if data and data.tag_name then
            local latestVersion = data.tag_name
            if M.semverCompare(latestVersion, currentVersion) then
                local downloadUrl = nil
                if data.assets then
                    for _, asset in ipairs(data.assets) do
                        if asset.name:match("%.zip$") or asset.name:match("%.muxapp$") then
                            downloadUrl = asset.browser_download_url
                            break
                        end
                    end
                end
                return latestVersion, downloadUrl
            end
        end
    end
    return nil, nil
end

return M
