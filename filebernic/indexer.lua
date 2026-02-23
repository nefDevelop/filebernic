---@diagnostic disable: undefined-global
require "love.filesystem"
require "love.timer"

local locale = require "locale" -- Ensure locale is loaded in the thread's environment
local json = require "libs.dkjson"
local scraper = require "scraper"
local filesystem = require "filesystem"

local channel_in = love.thread.getChannel("indexer_in")
local channel_out = love.thread.getChannel("indexer_out")

local function scanRoot(rootPath, validExtensions, newIndex, fileMap, romDirs)
    local f = io.open(rootPath, "r")
    if not f then return end
    f:close()
    
    table.insert(romDirs, rootPath)
    channel_out:push({type="progress", message="Escaneando: " .. rootPath})

    local h = io.popen('find "'..rootPath..'" -type f')
    if h then
        for fLine in h:lines() do
            local filename = fLine:match("([^/]+)$")
            if filename and filename:sub(1, 1) ~= "." then
                local ext = filename:match("[^%.]+$")
                if ext and validExtensions[ext:lower()] then
                    local stem = filename:gsub("%.[^%.]+$", "")
                    local groupKey = stem:gsub("%s*%b()", ""):gsub("%s*%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                    if groupKey == "" then groupKey = stem end
                    
                    local sysName = fLine:match("ROMS/([^/]+)/") or fLine:match("Simulador_SD/([^/]+)/") or "UNK"

                    if fileMap[groupKey] then
                        local idx = fileMap[groupKey]
                        local item = newIndex[idx]
                        
                        -- Verificar duplicados (mismo fullPath) antes de añadir
                        local exists = false
                        for _, v in ipairs(item.versions) do
                            if v.fullPath == fLine then exists = true break end
                        end
                        
                        if not exists then
                        table.insert(item.versions, {
                            name = filename,
                            fullPath = fLine,
                            sourceLabel = sysName,
                            system = sysName
                        })
                        item.sourceLabel = "Multi"
                        end
                    else
                        local newItem = {
                            name = groupKey,
                            isDir = false,
                            fullPath = fLine,
                            sourceLabel = sysName, -- This is already set
                            system = sysName, -- Add this line to set the system on the top-level item
                            versions = {{
                                name = filename,
                                fullPath = fLine,
                                sourceLabel = sysName,
                                system = sysName
                            }}
                        }
                        table.insert(newIndex, newItem)
                        fileMap[groupKey] = #newIndex
                    end
                end
            end
        end
        h:close()
    end
end

local function log(msg)
    channel_out:push({type="log", message=msg})
end

local function performIndexing(validExtensions, sourceDir, priorityPath)
    local newIndex = {}
    local fileMap = {}
    local romDirs = {}
    
    -- 1. Escanear ruta prioritaria (donde está el usuario)
    if priorityPath and priorityPath ~= "" and priorityPath ~= "/mnt/mmc/ROMS/" and priorityPath ~= "/mnt/sdcard/ROMS/" then
        scanRoot(priorityPath, validExtensions, newIndex, fileMap, romDirs)
    end
    
    scanRoot("/mnt/mmc/ROMS/", validExtensions, newIndex, fileMap, romDirs)
    scanRoot("/mnt/sdcard/ROMS/", validExtensions, newIndex, fileMap, romDirs)
    
    -- Fallback Simulador
    if #newIndex == 0 then
        local cwd = sourceDir
        if cwd:sub(-1) == "/" then cwd = cwd:sub(1, -2) end
        scanRoot(cwd .. "/../Simulador_SD/", validExtensions, newIndex, fileMap, romDirs)
    end
    
    channel_out:push({type="progress", message="Ordenando y guardando..."})
    table.sort(newIndex, function(a, b) return a.name:lower() < b.name:lower() end)
    
    -- Codificar JSON en memoria primero para evitar escrituras parciales si se cierra la app
    local indexJson = json.encode(newIndex)
    
    -- Guardar índice
    local dataDir = sourceDir .. "/data"
    os.execute("mkdir -p " .. dataDir)
    local f = io.open(dataDir .. "/rom_index.json", "w")
    if f then
        f:write(indexJson)
        f:close()
    end
    
    -- Guardar timestamps
    local timestamps = {}
    for _, dir in ipairs(romDirs) do
        local h = io.popen('date -r "'..dir..'" +%s 2>/dev/null')
        if h then timestamps[dir] = h:read("*a"):gsub("%s+", "") h:close() end
    end
    local tsJson = json.encode(timestamps)
    local f_ts = io.open(dataDir .. "/rom_timestamps.json", "w")
    if f_ts then
        f_ts:write(tsJson)
        f_ts:close()
    end
    
    channel_out:push({type="done", index=newIndex})
end

while true do
    local msg = channel_in:demand()

    if msg.command == "quit" then
        break
    elseif msg.command == "check_index" then
        -- Intentar cargar y verificar índice en segundo plano
        local validExtensions = msg.validExtensions
        local sourceDir = msg.sourceDir
        local priorityPath = msg.priorityPath
        
        -- Usamos la función checkIndex de filesystem.lua
        -- Nota: checkIndex devuelve (index, false) si está OK, o (nil, true) si necesita reindexar
        local loadedIndex, needsIndexing = filesystem.checkIndex(nil, json.decode, function() return sourceDir end, io.open, log)
        
        if loadedIndex then
            channel_out:push({type="done", index=loadedIndex})
        elseif needsIndexing then
            channel_out:push({type="progress", message="Cambios detectados. Actualizando..."})
            performIndexing(validExtensions, sourceDir, priorityPath)
        end

    elseif msg.command == "start" then
        performIndexing(msg.validExtensions, msg.sourceDir, msg.priorityPath)

    elseif msg.command == "scrape_single" then
        local item = msg.item
        local config = msg.config
        local systemName = msg.systemName
        
        local scraper_callback = function(data) -- Now accepts a table {type, message}
            channel_out:push(data)
        end
        -- Protect the scraper call to prevent thread termination on failure
        local status, results = pcall(scraper.getScrapeResults, item, config, log, systemName, love.filesystem.getInfo, scraper_callback)
        if status then
            channel_out:push({type="scrape_result", results=results})
        else
            log("Error crítico en scraper (Single): " .. tostring(results))
            channel_out:push({type="scrape_result", results={{error=true, text="Error interno del scraper"}}})
        end
        
    elseif msg.command == "scrape_batch" then
        local items = msg.items
        local config = msg.config
        local systemName = msg.systemName
        local romPath = msg.romPath
        local muosArtPath = msg.muosArtPath
        local muosTextPath = msg.muosTextPath
        local muosPreviewPath = msg.muosPreviewPath
        
        local successes = 0
        local failures = 0
        
        for i, item in ipairs(items) do
            channel_out:push({type="batch_progress", current=i, total=#items, currentName=item.name, successes=successes, failures=failures})
            
            -- Actualizar rutas si es necesario (para listas mixtas)
            local sName, mArt, mText, mPreview = filesystem.updateSystemForFile(item, romPath, systemName, muosArtPath, muosTextPath, muosPreviewPath)
            
            local status, results = pcall(scraper.getScrapeResults, item, config, log, sName, love.filesystem.getInfo)
            
            if status then
                if results and #results > 0 and not results[1].error then
                    filesystem.saveScrapeResult(item, results[1], mArt, mText, mPreview, log)
                    successes = successes + 1
                else
                    failures = failures + 1
                end
            else
                log("Error crítico en scraper (Batch) para " .. item.name .. ": " .. tostring(results))
                failures = failures + 1
            end
        end
        channel_out:push({type="batch_done", successes=successes, failures=failures})
    end
end
