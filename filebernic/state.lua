---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

local json = require "libs.dkjson"
local State = {}

function State.saveAppState(romPath, selectedIndex, hideEmpty, markPlayed, viewMode, launchMode, hideFavorites)
    local dataDir = love.filesystem.getSource() .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/app_state.json", "w")
    if f then
        -- Normalizar ruta para guardar (convertir a virtual ROMS/...)
        local savedPath = romPath
        if savedPath:find("/mnt/mmc/ROMS/") then
            savedPath = savedPath:gsub("/mnt/mmc/ROMS/", "ROMS/")
        elseif savedPath:find("/mnt/sdcard/ROMS/") then
            savedPath = savedPath:gsub("/mnt/sdcard/ROMS/", "ROMS/")
        elseif savedPath:find("Simulador_SD") then
            savedPath = savedPath:gsub(".*Simulador_SD/", "ROMS/")
        end

        local stateToSave = {
            romPath = savedPath,
            selectedIndex = selectedIndex,
            hideEmpty = hideEmpty,
            markPlayed = markPlayed,
            viewMode = viewMode,
            launchMode = launchMode,
            hideFavorites = hideFavorites
        }
        f:write(json.encode(stateToSave))
        f:close()
    end
end

function State.loadConfig(defaultConfig)
    local config = {}
    for k,v in pairs(defaultConfig) do config[k] = v end
    
    local configPath = love.filesystem.getSource() .. "/data/config.json"
    local f = io.open(configPath, "r")
    local loaded = nil
    if f then
        local content = f:read("*all")
        f:close()
        if content and content ~= "" then -- Solo intentar decodificar si el contenido no está vacío
            loaded = json.decode(content)
        end
    end

    if loaded then
        for k, v in pairs(loaded) do config[k] = v end
    else -- Si el archivo no existía, o estaba vacío/inválido, lo creamos/rescribimos con la configuración por defecto
        local f_write = io.open(configPath, "w")
        if f_write then
            f_write:write(json.encode(config))
            f_write:close()
        end
    end
    return config
end

return State