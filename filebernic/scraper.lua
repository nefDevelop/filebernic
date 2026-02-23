---@diagnostic disable: undefined-global
local json = require "libs.dkjson"
local utils = require "utils"
local filesystem = require "filesystem"

local M = {}
local L = _G.L or { get = function(key, ...) return string.format(key, ...) end } -- Acceso a la función de localización, con fallback para tests

-- Helper function to download an image with curl and check its success
local function downloadImage(imageUrl, tempPath, log_func, progress_callback)
    log_func("Downloading image: " .. imageUrl)
    local max_retries = 3
    local retry_delay = 1 -- seconds
    
    for attempt = 1, max_retries do
        -- Add --max-time for image downloads to prevent hanging
        -- --fail-with-body will make curl exit with error code on HTTP errors, but still output body.
        -- We want to capture HTTP code from stdout, and any curl errors from stderr.
        -- Add a user-agent to look more like a browser and avoid being blocked by CDNs.
        -- Add -k to ignore SSL certificate verification, which often fails on embedded devices.
        local curl_cmd = "curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output '" .. tempPath .. "' --write-out '%{http_code}' '" .. imageUrl .. "'"
        local curl_handle = io.popen(curl_cmd)
        local http_code = nil
        if curl_handle then
            local output = curl_handle:read("*a")
            -- The HTTP code is the last 3 digits of the output
            http_code = output:match("(%d%d%d)$")
            curl_handle:close()
        end

        if http_code and tonumber(http_code) and tonumber(http_code) >= 200 and tonumber(http_code) < 300 then
            -- Check if the downloaded file actually exists and has content
            local f = io.open(tempPath, "rb")
            local size = 0
            if f then
                size = f:seek("end")
                f:close()
            end
            local exists = (size > 0)
            if not exists then
                local msg = "Downloaded file " .. tempPath .. " is empty or invalid despite HTTP " .. http_code .. " status. (Attempt " .. attempt .. "/" .. max_retries .. ")"
                log_func("Warning: " .. msg)
                if progress_callback then progress_callback({type="scraper_warning", message=msg}) end
            end
            return exists
        elseif http_code == nil or http_code == "" then
            local msg = "Image download failed for " .. imageUrl .. " (No HTTP Code received, possibly curl error. Attempt " .. attempt .. "/" .. max_retries .. ")"
            log_func("Warning: " .. msg)
            if progress_callback then progress_callback({type="scraper_warning", message=msg}) end
        else
            local msg = "Image download failed for " .. imageUrl .. " (HTTP Code: " .. (http_code or "N/A") .. ", Attempt " .. attempt .. "/" .. max_retries .. ")"
            log_func("Warning: " .. msg)
            if progress_callback then progress_callback({type="scraper_warning", message=msg}) end
            
            if attempt < max_retries then
                love.timer.sleep(retry_delay) -- Wait before retrying
            end
        end
    end
    return false -- All retries failed
end

function M.getScrapeResults(item, config, log, systemName, fs_getInfo, progress_callback)
    local results = {}
    
    local cleanName = item.name:gsub("%..-$", "") -- Quitar extensión
    local encodedName = utils.urlencode(cleanName)

    -- 1. Local Gamelist.xml (Prioridad Máxima - Offline)
    local localData = filesystem.findInGamelist(item.fullPath, item.name)
    if localData then
        local tempImgPath = nil
        if localData.imagePath and fs_getInfo(localData.imagePath) then
            local f = io.open(localData.imagePath, "r")
            if f then
                f:close()
                tempImgPath = "tmp/scraper_local.png"
                os.execute("cp '" .. localData.imagePath .. "' '" .. tempImgPath .. "'")
            end
        end
        
        if tempImgPath or localData.description then
             table.insert(results, {
                 imagePath = tempImgPath, description = localData.description, year = localData.year,
                 region = "Local", tempPath = tempImgPath, source = "Local XML"
             })
             return results -- If local data is found, no need to search online
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
            local platformParam = ""
            if systemName and systemName ~= "" then
                local displaySystemName = utils.getSystemDisplayName(systemName)
                platformParam = "&platform=" .. utils.urlencode(displaySystemName)
            end
            local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=" .. apikey .. "&name=" .. encodedName ..
                        platformParam .. "&fields=overview,release_date&include=boxart,screenshot"
            if progress_callback then progress_callback({type="scraper_progress", message=L.get("querying_api", "TheGamesDB")}) end
            love.timer.sleep(0.05) -- Pausa para que la UI se actualice
            
            log("TGDB Request: " .. url)

            local handle = io.popen("curl -s -L -k --max-time 10 -A 'Mozilla/5.0' '" .. url .. "'")
            local response = nil
            if handle then
                response = handle:read("*a")
                handle:close()
            end

            if not response or response == "" then
                table.insert(results, {error = true, text = L.get("error_no_response_tgdb")})
            elseif response:sub(1, 1) ~= "{" then
                table.insert(results, {error = true, text = L.get("error_invalid_response_tgdb")})
            else
                -- log("TGDB Response: " .. (response or "nil")) -- Commented for less verbosity
                
                local data = json.decode(response)
                if data and data.data and data.data.games and #data.data.games > 0 then
                    if progress_callback then progress_callback({type="scraper_progress", message=L.get("processing_results", #data.data.games, "TheGamesDB")}) end
                    love.timer.sleep(0.5) -- Pausa para que el usuario vea el número de resultados
                end
                if data and data.data and data.data.games then
                    for _, game in ipairs(data.data.games) do
                        local gameId = tostring(game.id)
                        if data.include and data.include.boxart and data.include.boxart.base_url and data.include.boxart.data and data.include.boxart.data[gameId] then
                            local boxartBaseUrl = data.include.boxart.base_url.original or "https://cdn.thegamesdb.net/images/original/"
                            for _, art in ipairs(data.include.boxart.data[gameId]) do
                                if art.side == "front" then
                                    if progress_callback then progress_callback({type="scraper_progress", message=L.get("downloading_images", "TheGamesDB")}) end
                                    local imageUrl = boxartBaseUrl .. art.filename
                                    local tempImgPath = "tmp/scraper_tgdb_" .. gameId .. ".png"
                                    local imageDownloaded = downloadImage(imageUrl, tempImgPath, log, progress_callback)
                                    
                                    local year = nil
                                    if game.release_date then
                                        year = game.release_date:match("^(%d%d%d%d)")
                                    end
                                    
                                    local tempScreenPath = nil
                                    if data.include.screenshot and data.include.screenshot.base_url and data.include.screenshot.data and data.include.screenshot.data[gameId] then
                                        local screenshotBaseUrl = data.include.screenshot.base_url.original or "https://cdn.thegamesdb.net/images/original/"
                                        local scr = data.include.screenshot.data[gameId][1]
                                        if scr then
                                            local screenUrl = screenshotBaseUrl .. scr.filename
                                            tempScreenPath = "tmp/scraper_tgdb_scr_" .. gameId .. ".png" -- Construct path
                                            if not downloadImage(screenUrl, tempScreenPath, log, progress_callback) then
                                                tempScreenPath = nil -- Clear path if download failed
                                            end
                                        end
                                    end
                                    if imageDownloaded then
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
            end -- End of else (valid JSON response)
        end -- End of else (API key exists)
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
             local msg = "Sistema no mapeado en Libretro: " .. tostring(systemName) -- Log message

             log(msg)
             table.insert(results, {error=true, text=msg})
        else
             local sysEncoded = utils.urlencode(sysName):gsub("%+", "%%20")
             
             local function tryLibretro(nameToTry, label, suffix)
                 local fullName = nameToTry .. (suffix or "")
                 local nameEnc = utils.urlencode(fullName):gsub("%+", "%%20") -- Encode name for URL
                 local url = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Boxarts/" .. nameEnc .. ".png"
                 -- log("Libretro Request ("..label.."): " .. url) -- Menos verboso
                 if progress_callback then progress_callback({type="scraper_progress", message=L.get("querying_api_libretro", label)}) end
                 love.timer.sleep(0.05) -- Pausa para que la UI se actualice
                 
                 local tempImgPath = "tmp/scraper_libretro_" .. label:gsub(" ", "_") .. (suffix and suffix:gsub("[^%w]", "") or "") .. ".png"
                 local imageDownloaded = downloadImage(url, tempImgPath, log, progress_callback)

                 if imageDownloaded then
                     if progress_callback then progress_callback({type="scraper_progress", message=L.get("libretro_found", label)}) end
                     love.timer.sleep(0.5)
                     local snapUrl = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Snaps/" .. nameEnc .. ".png"
                     local tempScreenPath = "tmp/scraper_libretro_snap_" .. label:gsub(" ", "_") .. ".png" -- Construct path

                     -- Download screenshot, using the same helper
                     if not downloadImage(snapUrl, tempScreenPath, log, progress_callback) then
                         tempScreenPath = nil -- Clear path if download failed
                     end
                 end
                 
                 if imageDownloaded then
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
                 local suffixes = { -- Common suffixes for regional variations

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
        local mockTemp = "tmp/scraper_mock.png" -- Temporary file path

        os.execute("cp '" .. mockSrc .. "' '" .. mockTemp .. "'")
        
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
