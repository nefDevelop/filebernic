---@diagnostic disable: undefined-global
local json = require "libs.dkjson"
local utils = require "utils"
local filesystem = require "filesystem"

local M = {}
local L = _G.L or { get = function(key, ...) return string.format(key, ...) end } -- Acceso a la función de localización, con fallback para tests

-- Helper function to download an image with curl and check its success
local function downloadImage(imageUrl, tempPath, log_func, progress_callback)
    local shortUrl = imageUrl
    if #shortUrl > 50 then shortUrl = shortUrl:sub(1, 47) .. "..." end
    log_func("Downloading image: " .. shortUrl)
    local max_retries = 3
    local retry_delay = 1 -- seconds
    
    for attempt = 1, max_retries do
        -- Add --max-time for image downloads to prevent hanging
        -- --fail-with-body will make curl exit with error code on HTTP errors, but still output body.
        -- We want to capture HTTP code from stdout, and any curl errors from stderr.
        -- Add a user-agent to look more like a browser and avoid being blocked by CDNs.
        -- Add -k to ignore SSL certificate verification, which often fails on embedded devices.
        local curl_cmd = "curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg(tempPath) .. " --write-out '%{http_code}' " .. utils.escapeShellArg(imageUrl)
        local curl_handle = io.popen(curl_cmd)
        local http_code = nil
        if curl_handle then
            local output = curl_handle:read("*a")
            -- The HTTP code is usually the last 3 digits of the output.
            -- Using %s* to handle potential newlines.
            http_code = output:match("(%d%d%d)%s*$")
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
            local is404 = (tostring(http_code) == "404")
            local msg = "Image download failed for " .. imageUrl .. " (HTTP Code: " .. (http_code or "N/A") .. ", Attempt " .. attempt .. "/" .. max_retries .. ")"
            
            if not is404 then
                log_func("Warning: " .. msg)
                if progress_callback then progress_callback({type="scraper_warning", message=msg}) end
            else
                log_func("Info: Image not found (404) for " .. shortUrl)
            end
            
            if is404 then
                return false -- No tiene sentido reintentar un 404, abortamos y ahorramos tiempo
            elseif attempt < max_retries then
                love.timer.sleep(retry_delay) -- Wait before retrying
            end
        end
    end
    return false -- All retries failed
end

-- Mapeo de sistemas para ScreenScraper (IDs)
local screenScraperSystems = {
    gba = 12, snes = 4, sfc = 4, nes = 3, fc = 3, gb = 9, gbc = 10,
    md = 1, gen = 1, sms = 2, gg = 21, ps = 57, ps1 = 57, psx = 57,
    nds = 15, n64 = 14, neogeo = 142, arcade = 75, mame = 75, fbneo = 75,
    pce = 31, tg16 = 31, ngp = 82, ngpc = 82,
    ws = 45, wsc = 46, vb = 11, segacd = 20, ["32x"] = 19,
    dc = 23, saturn = 22, psp = 150,
    atari2600 = 26, a2600 = 26, atari7800 = 28, a7800 = 28,
    lynx = 29, jaguar = 30,
    amiga = 64, c64 = 66, zxspectrum = 76,
    msx = 113, msx2 = 116,
    dos = 135, scummvm = 123
}

function M.getScrapeResults(item, config, log, systemName, fs_getInfo, progress_callback)
    local results = {}
    
    local cleanName = item.name:gsub("%.[^%.]+$", "") -- Quitar extensión
    local encodedName = utils.urlencode(cleanName)

    -- 1. Local Gamelist.xml (Prioridad Máxima - Offline)
    local localData = filesystem.findInGamelist(item.fullPath, item.name)
    if localData then
        local tempImgPath = nil
        if localData.imagePath then
            local f = io.open(localData.imagePath, "r")
            if f then
                f:close()
                tempImgPath = "tmp/scraper_local.png"
                filesystem.copyFile(localData.imagePath, tempImgPath, log)
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
    if config.scraperApi == "all" or config.scraperApi:find("thegamesdb") then
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
            
            log("TGDB Request: " .. (url:sub(1, 60)) .. "...")

            local handle = io.popen("curl -s -L -k --max-time 10 -A 'Mozilla/5.0' " .. utils.escapeShellArg(url))
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
                        
                        -- Collect Fronts
                        local downloadedFronts = {}
                        if data.include and data.include.boxart and data.include.boxart.data and data.include.boxart.data[gameId] then
                            for _, art in ipairs(data.include.boxart.data[gameId]) do
                                if art.side == "front" and #downloadedFronts < 4 then
                                    local boxartBaseUrl = (data.include.boxart.base_url and data.include.boxart.base_url.original) or "https://cdn.thegamesdb.net/images/original/"
                                    local imageUrl = boxartBaseUrl .. art.filename
                                    local ext = imageUrl:match("%.([^%.]+)$") or "png"
                                    local tempImgPath = "tmp/scraper_tgdb_" .. gameId .. "_front_" .. #downloadedFronts .. "." .. ext
                                    if progress_callback then progress_callback({type="scraper_progress", message=L.get("downloading_images", "TheGamesDB")}) end
                                    if downloadImage(imageUrl, tempImgPath, log, progress_callback) then
                                        table.insert(downloadedFronts, tempImgPath)
                                    end
                                end
                            end
                        end
                        
                        -- Collect Screens
                        local downloadedScreens = {}
                        if data.include and data.include.screenshot and data.include.screenshot.data and data.include.screenshot.data[gameId] then
                            for _, scr in ipairs(data.include.screenshot.data[gameId]) do
                                if #downloadedScreens < 4 then
                                    local screenshotBaseUrl = (data.include.screenshot.base_url and data.include.screenshot.base_url.original) or "https://cdn.thegamesdb.net/images/original/"
                                    local screenUrl = screenshotBaseUrl .. scr.filename
                                    local ext = screenUrl:match("%.([^%.]+)$") or "png"
                                    local tempScreenPath = "tmp/scraper_tgdb_scr_" .. gameId .. "_" .. #downloadedScreens .. "." .. ext
                                    if progress_callback then progress_callback({type="scraper_progress", message=L.get("downloading_images", "TheGamesDB")}) end
                                    if downloadImage(screenUrl, tempScreenPath, log, progress_callback) then
                                        table.insert(downloadedScreens, tempScreenPath)
                                    end
                                end
                            end
                        end
                        
                        local loopCount = math.max(#downloadedFronts, #downloadedScreens)
                        if loopCount == 0 then loopCount = 1 end -- Allow text-only result if no images found
                        
                        for i = 1, loopCount do
                            -- Obtener imagen rellenando huecos repetidos si faltan
                            local fPath = #downloadedFronts > 0 and downloadedFronts[(i - 1) % #downloadedFronts + 1] or nil
                            local sPath = #downloadedScreens > 0 and downloadedScreens[(i - 1) % #downloadedScreens + 1] or nil
                            
                            if fPath or sPath or (i == 1) then
                                        table.insert(results, {
                                            imagePath = fPath,
                                            screenshotPath = sPath,
                                            tempScreenPath = sPath,
                                            tempPath = fPath,
                                            description = game.overview or "Sin descripción.",
                                            year = game.release_date and game.release_date:match("^(%d%d%d%d)"),
                                            region = game.game_title,
                                            source = "TheGamesDB"
                                        })
                            end
                        end
                    end
                end
            end -- End of else (valid JSON response)
        end -- End of else (API key exists)
    end

    -- 3. Libretro
    if config.scraperApi == "all" or config.scraperApi:find("libretro") then
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

    -- 4. ScreenScraper
    if config.scraperApi == "all" or config.scraperApi:find("screenscraper") then
        local ssUser = config.screenscraper_user or ""
        local ssPass = config.screenscraper_password or ""
        local devId = config.screenscraper_devid or ""
        local devPass = config.screenscraper_devpassword or ""
        
        -- ScreenScraper requiere credenciales de desarrollador o usuario.
        -- Si no hay devid configurado, intentamos sin él (aunque probablemente falle o esté limitado)
        -- o usamos las credenciales de usuario si están presentes.
        
        local sysId = screenScraperSystems[systemName:lower()]
        if sysId then
            local url = "https://www.screenscraper.fr/api2/jeuInfos.php?output=json&romNom=" .. encodedName .. "&systeme=" .. sysId
            
            if ssUser ~= "" and ssPass ~= "" then
                url = url .. "&ssid=" .. utils.urlencode(ssUser) .. "&sspassword=" .. utils.urlencode(ssPass)
            end
            if devId ~= "" and devPass ~= "" then
                url = url .. "&devid=" .. utils.urlencode(devId) .. "&devpassword=" .. utils.urlencode(devPass)
            end
            
            if progress_callback then progress_callback({type="scraper_progress", message=L.get("querying_api", "ScreenScraper")}) end
            love.timer.sleep(0.05)
            
            log("ScreenScraper Request: " .. (url:sub(1, 80)) .. "...")
            
            local handle = io.popen("curl -s -L -k --max-time 15 -A 'Mozilla/5.0' " .. utils.escapeShellArg(url))
            local response = nil
            if handle then
                response = handle:read("*a")
                handle:close()
            end
            
            if response and response:sub(1, 1) == "{" then
                local data = json.decode(response)
                if data and data.response and data.response.jeu then
                    local game = data.response.jeu
                    
                    local downloadedFronts = {}
                    local downloadedScreens = {}
                    
                    if game.medias then
                        for _, media in ipairs(game.medias) do
                            local mType = media.type and media.type:lower() or ""
                            if (mType == "box-2d" or mType == "box-3d") and #downloadedFronts < 4 then
                                local ext = media.url:match("%.([^%.]+)$") or "png"
                                local tempImgPath = "tmp/scraper_ss_" .. game.id .. "_front_" .. #downloadedFronts .. "." .. ext
                                if progress_callback then progress_callback({type="scraper_progress", message=L.get("downloading_images", "ScreenScraper")}) end
                                if downloadImage(media.url, tempImgPath, log, progress_callback) then
                                    table.insert(downloadedFronts, tempImgPath)
                                end
                            elseif (mType == "screenjeu" or mType == "screentitre" or mType == "ss" or mType == "screenshot") and #downloadedScreens < 4 then
                                local ext = media.url:match("%.([^%.]+)$") or "png"
                                local tempScreenPath = "tmp/scraper_ss_" .. game.id .. "_scr_" .. #downloadedScreens .. "." .. ext
                                if progress_callback then progress_callback({type="scraper_progress", message=L.get("downloading_images", "ScreenScraper")}) end
                                if downloadImage(media.url, tempScreenPath, log, progress_callback) then
                                    table.insert(downloadedScreens, tempScreenPath)
                                end
                            end
                        end
                    end
                    
                    local loopCount = math.max(#downloadedFronts, #downloadedScreens)
                    if loopCount == 0 then loopCount = 1 end
                    
                    for i = 1, loopCount do
                        local fPath = #downloadedFronts > 0 and downloadedFronts[(i - 1) % #downloadedFronts + 1] or nil
                        local sPath = #downloadedScreens > 0 and downloadedScreens[(i - 1) % #downloadedScreens + 1] or nil
                        
                        local desc = (game.synopsis and game.synopsis[1] and game.synopsis[1].text) or L.get("no_desc")
                        if game.synopsis then
                            for _, s in ipairs(game.synopsis) do
                                if s.langue == "es" then desc = s.text break end
                            end
                        end
                        
                        table.insert(results, {
                            imagePath = fPath,
                            screenshotPath = sPath,
                            tempScreenPath = sPath,
                            tempPath = fPath,
                            description = desc,
                            year = game.dates and game.dates[1] and game.dates[1].text and game.dates[1].text:match("^(%d%d%d%d)"),
                            region = game.noms and game.noms[1] and game.noms[1].text,
                            source = "ScreenScraper"
                        })
                    end
                end
            end
        else
            log("ScreenScraper: Sistema no mapeado ID para " .. systemName)
        end
    end

    if config.scraperApi == "mock" then
        log("Mock Scraping: " .. item.name)
        local mockSrc = love.filesystem.getSource() .. "/assets/roms.png"
        local mockTemp = "tmp/scraper_mock.png" -- Temporary file path

        filesystem.copyFile(mockSrc, mockTemp, log)
        
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
