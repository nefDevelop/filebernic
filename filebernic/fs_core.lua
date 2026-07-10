---@diagnostic disable: undefined-global
local M = {}
local utils = require "utils"

function M.isSafePath(path)
    if not path or type(path) ~= "string" then return false end

    local normPath = path
    while normPath:find("/[^/]+/%.%./") do
        normPath = normPath:gsub("/[^/]+/%.%./", "/")
    end

    if normPath:find("%.%.") then return false end

    local allowed_prefixes = {
        "/mnt/mmc/ROMS/",
        "/mnt/sdcard/ROMS/",
        "/mnt/mmc/MUOS/save/",
        "/mnt/sdcard/MUOS/save/",
        "/mnt/mmc/MUOS/info/catalogue/",
        "/mnt/sdcard/MUOS/info/catalogue/",
        "Simulador_SD/ROMS/",
        "Simulador_SD/MUOS/save/",
        "Simulador_SD/MUOS/info/catalogue/"
    }

    table.insert(allowed_prefixes, "/tmp/")
    table.insert(allowed_prefixes, "tmp/")
    if love and love.filesystem then
        local app_dir = love.filesystem.getSource()
        while app_dir:find("/[^/]+/%.%./") do
            app_dir = app_dir:gsub("/[^/]+/%.%./", "/")
        end

        table.insert(allowed_prefixes, app_dir .. "/data/")
        table.insert(allowed_prefixes, app_dir .. "/tmp/")

        local cwd = app_dir
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        local sim_dir = cwd .. "/../Simulador_SD/"
        while sim_dir:find("/[^/]+/%.%./") do
            sim_dir = sim_dir:gsub("/[^/]+/%.%./", "/")
        end
        table.insert(allowed_prefixes, sim_dir .. "ROMS/")
        table.insert(allowed_prefixes, sim_dir .. "MUOS/save/")
        table.insert(allowed_prefixes, sim_dir .. "MUOS/info/catalogue/")
    end

    for _, prefix in ipairs(allowed_prefixes) do
        if normPath:find("^" .. prefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
            return true
        end
    end

    return false
end

function M.safeRemove(path, log_func)
    if not M.isSafePath(path) then
        if log_func then log_func("SECURITY BLOCK: Intento de borrado no autorizado -> " .. tostring(path)) end
        return false, "Ruta no autorizada por seguridad"
    end
    return os.remove(path)
end

function M.copyFile(src, dest, log_func)
    if not src or not dest then return false, "Rutas inválidas" end
    local infile, err = io.open(src, "rb")
    if not infile then return false, "Error leyendo origen: " .. tostring(err) end
    local outfile, err2 = io.open(dest, "wb")
    if not outfile then
        infile:close()
        return false, "Error escribiendo destino: " .. tostring(err2)
    end

    local chunkSize = 1024 * 1024
    while true do
        local block = infile:read(chunkSize)
        if not block then break end
        outfile:write(block)
    end

    infile:close()
    outfile:close()
    if log_func then log_func("Copiado nativo exitoso: " .. src .. " -> " .. dest) end
    return true
end

function M.moveFile(src, dest, log_func)
    local success, err = M.copyFile(src, dest, log_func)
    if success then
        M.safeRemove(src, log_func)
        return true
    end
    return false, err
end

return M
