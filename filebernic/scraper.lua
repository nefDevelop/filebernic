---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field


local json = require "libs.dkjson"
local utils = require "utils"
local filesystem = require "filesystem"

local M = {}

function M.getScrapeResults(item, config, log, systemName)
    local results = {}
    
    local cleanName = item.name:gsub("%..-$", "") -- Quitar extensión
    local encodedName = utils.urlencode(cleanName)

    -- 1. Local Gamelist.xml (Prioridad Máxima - Offline)
    local localData = filesystem.findInGamelist(item.fullPath, item.name)
    if localData then
        local tempImgPath = nil
        if localData.imagePath then
            local f = io.open(localData.imagePath, "r")
            if f then
                f:close()
                tempImgPath = "/tmp/scraper_local.png"
                os.execute("cp '" .. localData.imagePath .. "' " .. tempImgPath)
            end
        end
        
        if tempImgPath or localData.description then
             table.insert(results, {
                 imagePath = tempImgPath, description = localData.description, year = localData.year,
                 region = "Local", tempPath = tempImgPath, source = "Local XML"
             })
             return results -- Si encontramos local, no buscamos online
        end
    end

    -- 2. TheGamesDB
    if config.scraperApi == "all" or config.scraperApi == "thegamesdb" then
        local apikey = config.thegamesdb_apikey or ""
        
        local skipTGDB = false
        if apikey == "" then
            if config.scraperApi == "thegamesdb" then
                table.insert(results, {error = true, text = "Error: Falta API Key TGDB"})
            end
            skipTGDB = true
        end

        if not skipTGDB then
            local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=" .. apikey .. "&name=" .. encodedName .. "&fields=overview,release_date&include=boxart,screenshot"
            log("TGDB Request: " .. url)

            local handle = io.popen("curl -s -L --max-time 10 '" .. url .. "'")
            local response = nil
            if handle then
                response = handle:read("*a")
                handle:close()
            end
            log("TGDB Response: " .. (response or "nil"))

            if response and response:sub(1, 1) == "{" then
                local data = json.decode(response)
                if data and data.data and data.data.games then
                    for _, game in ipairs(data.data.games) do
                        local gameId = tostring(game.id)
                        if data.include and data.include.boxart and data.include.boxart.data and data.include.boxart.data[gameId] then
                            for _, art in ipairs(data.include.boxart.data[gameId]) do
                                if art.side == "front" then
                                    local imageUrl = "https://cdn.thegamesdb.net/images/original/" .. art.filename
                                    local tempImgPath = "/tmp/scraper_tgdb_" .. gameId .. ".png"
                                    os.execute("curl -s -L '" .. imageUrl .. "' -o " .. tempImgPath)
                                    
                                    local year = nil
                                    if game.release_date then
                                        year = game.release_date:match("^(%d%d%d%d)")
                                    end
                                    
                                    local tempScreenPath = nil
                                    if data.include.screenshot and data.include.screenshot.data and data.include.screenshot.data[gameId] then
                                        local scr = data.include.screenshot.data[gameId][1]
                                        if scr then
                                            local screenUrl = "https://cdn.thegamesdb.net/images/original/" .. scr.filename
                                            tempScreenPath = "/tmp/scraper_tgdb_scr_" .. gameId .. ".png"
                                            os.execute("curl -s -L '" .. screenUrl .. "' -o " .. tempScreenPath)
                                        end
                                    end

                                    local exists = false
                                    if love.filesystem.getInfo(tempImgPath) then exists = true
                                    else
                                        local f = io.open(tempImgPath, "r")
                                        if f then f:close() exists = true end
                                    end
                                    if exists then
                                        table.insert(results, {
                                            imagePath = tempImgPath,
                                            screenshotPath = tempScreenPath,
                                            tempScreenPath = tempScreenPath,
                                            description = game.overview or "Sin descripción.",
                                            year = year,
                                            region = game.game_title,
                                            tempPath = tempImgPath,
                                            source = "TheGamesDB"
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 3. Libretro
    if config.scraperApi == "all" or config.scraperApi == "libretro" then
        local libretroSystems = {
            gba = "Nintendo - Game Boy Advance", snes = "Nintendo - Super Nintendo Entertainment System", sfc = "Nintendo - Super Nintendo Entertainment System",
            nes = "Nintendo - Nintendo Entertainment System", fc = "Nintendo - Nintendo Entertainment System", gb = "Nintendo - Game Boy", gbc = "Nintendo - Game Boy Color",
            md = "Sega - Mega Drive - Genesis", gen = "Sega - Mega Drive - Genesis", ps = "Sony - PlayStation", ps1 = "Sony - PlayStation", psx = "Sony - PlayStation",
            nds = "Nintendo - Nintendo DS", n64 = "Nintendo - Nintendo 64", sms = "Sega - Master System - Mark III", gg = "Sega - Game Gear",
            neogeo = "SNK - Neo Geo", arcade = "MAME", mame = "MAME", fbneo = "MAME", pce = "NEC - PC Engine", ngp = "SNK - Neo Geo Pocket", ngpc = "SNK - Neo Geo Pocket Color"
        }
        
        local sysName = libretroSystems[systemName:lower()]
        if not sysName then
             local msg = "Sistema no mapeado en Libretro: " .. tostring(systemName)
             log(msg)
             table.insert(results, {error=true, text=msg})
        else
             local sysEncoded = utils.urlencode(sysName):gsub("%+", "%%20")
             
             local function tryLibretro(nameToTry, label, suffix)
                 local fullName = nameToTry .. (suffix or "")
                 local nameEnc = utils.urlencode(fullName):gsub("%+", "%%20")
                 local url = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Boxarts/" .. nameEnc .. ".png"
                 -- log("Libretro Request ("..label.."): " .. url) -- Menos verboso
                 
                 local tempImgPath = "/tmp/scraper_libretro_" .. label:gsub(" ", "_") .. (suffix and suffix:gsub("[^%w]", "") or "") .. ".png"
                 local handle = io.popen("curl -v -s -L -f '" .. url .. "' -o " .. tempImgPath .. " 2>&1")
                 local output = nil
                 if handle then
                     output = handle:read("*a")
                     handle:close()
                 end
                 -- log("Libretro Response ("..label.."): " .. (output or "nil"))
                 
                 local f = io.open(tempImgPath, "rb")
                 local data = nil
                 if f then
                     data = f:read("*a")
                     f:close()
                 end

                 if data and #data > 0 then
                     local snapUrl = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Snaps/" .. nameEnc .. ".png"
                     local tempScreenPath = "/tmp/scraper_libretro_snap_" .. label:gsub(" ", "_") .. ".png"
                     os.execute("curl -s -L -f '" .. snapUrl .. "' -o " .. tempScreenPath)
                     
                     table.insert(results, {
                         imagePath = tempImgPath,
                         screenshotPath = tempScreenPath,
                         tempScreenPath = tempScreenPath,
                         description = "Libretro no proporciona descripciones.",
                         region = "Libretro (" .. label .. "): " .. fullName,
                         tempPath = tempImgPath,
                         source = "Libretro"
                     })
                     return true
                 end
                 return false
             end
             
             -- 1. Intento Exacto
             local found = tryLibretro(cleanName, "Exacto")
             
             -- 2. Intento con Variaciones de Región (Si falla el exacto)
             if not found then
                 -- Limpiar nombre de paréntesis existentes (ej: "Mario (V1)" -> "Mario")
                 local baseName = cleanName:gsub("%b()", ""):gsub("%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                 
                 -- Lista de sufijos probables en orden de prioridad
                 local suffixes = {
                     " (USA, Europe)", " (USA)", " (Europe)", " (Japan)", " (World)", 
                     " (USA) (Rev A)", " (USA, Europe) (Rev A)"
                 }
                 
                 for _, suffix in ipairs(suffixes) do
                     if tryLibretro(baseName, "Fuzzy", suffix) then found = true break end
                 end
             end
             
             if not found then
                 table.insert(results, {error=true, text="Libretro: No encontrado", source="Libretro"})
             end
        end
    end

    if config.scraperApi == "mock" then
        log("Mock Scraping: " .. item.name)
        local mockSrc = love.filesystem.getSource() .. "/assets/roms.png"
        local mockTemp = "/tmp/scraper_mock.png"
        os.execute("cp '" .. mockSrc .. "' " .. mockTemp)
        
        local f = io.open(mockTemp, "r")
        if f then
            f:close()
            table.insert(results, {
                imagePath = mockTemp,
                description = "Esto es una descripción de prueba en modo Mock.",
                region = "Mock Result (Test)",
                tempPath = mockTemp
            })
        end
    end
    return results
end

return M
