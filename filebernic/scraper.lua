local json = require "libs.dkjson"
local utils = require "utils"

local M = {}

function M.getScrapeResults(item, config, log, systemName)
    log("M.getScrapeResults called with item: " .. tostring(item.name) .. ", systemName: " .. tostring(systemName))
    local results = {}
    
    local cleanName = item.name:gsub("%..-$", "") -- Quitar extensión
    local encodedName = utils.urlencode(cleanName)

    -- 1. ScreenScraper
    if config.scraperApi == "all" or config.scraperApi == "screenscraper" then
        -- Configuración API ScreenScraper
        local devid = config.screenscraper_devid
        local devpassword = config.screenscraper_password
        local softname = "FileBernic"
        
        local skipSS = false
        if devid == "" or devpassword == "" then
            if config.scraperApi == "screenscraper" then
                table.insert(results, {error = true, text = "Error: Faltan credenciales SS"})
            end
            skipSS = true
        end

        if not skipSS then
            -- Construir URL para buscar por nombre de archivo (romNom)
            local url = "https://www.screenscraper.fr/api2/jeuInfos.php?output=json&romNom=" .. encodedName
            if devid ~= "" then
                url = url .. "&devid=" .. devid .. "&devpassword=" .. devpassword .. "&softname=" .. softname
            else
                -- Intento sin credenciales (puede requerir softname registrado)
                url = url .. "&softname=" .. softname
            end

            log("Scraping Request URL: " .. url)

            -- Ejecutar curl
            local handle = io.popen("curl -s -L --max-time 10 '" .. url .. "'")
            local response = handle:read("*a")
            handle:close()
            log("Scraping Response: " .. (response or "nil"))

            if response and response ~= "" then
                if response:sub(1, 1) ~= "{" then
                    table.insert(results, {
                        error = true,
                        text = "API Error: " .. response
                    })
                else
                    local data, pos, err = json.decode(response)
                    if data and data.response and data.response.jeu then
                        local game = data.response.jeu
                        
                        local imageUrl = nil
                        local screenUrl = nil
                        local region = "Mundo"
                        local description = "Sin descripción."
                        local year = nil
                        
                        if game.synopsis then
                            if type(game.synopsis) == "table" and #game.synopsis > 0 then
                                for _, s in ipairs(game.synopsis) do
                                    if s.langue == "es" then description = s.text break end
                                    if s.langue == "en" and description == "Sin descripción." then description = s.text end
                                end
                            elseif type(game.synopsis) == "string" then
                                description = game.synopsis
                            elseif type(game.synopsis) == "table" and game.synopsis.text then
                                description = game.synopsis.text
                            end
                        end
                        
                        if game.dates then
                            for _, d in ipairs(game.dates) do
                                if d.text then
                                    year = d.text:match("^(%d%d%d%d)")
                                    if year then break end
                                end
                            end
                        end
                        
                        if game.medias and game.medias.media then
                            local medias = game.medias.media
                            if not medias[1] then medias = {medias} end
                            for _, media in ipairs(medias) do
                                if media.type == "box-2d" or media.type == "box-3d" then
                                    imageUrl = media.url
                                    region = media.region or region
                                elseif media.type == "ss" then
                                    screenUrl = media.url
                                end
                            end
                        end

                        if imageUrl then
                            local tempImgPath = "/tmp/scraper_temp.png"
                            os.execute("curl -s -L '" .. imageUrl .. "' -o " .. tempImgPath)
                            
                            local tempScreenPath = nil
                            local screenImg = nil
                            if screenUrl then
                                tempScreenPath = "/tmp/scraper_temp_screen.png"
                                os.execute("curl -s -L '" .. screenUrl .. "' -o " .. tempScreenPath)
                                if love.filesystem.getInfo(tempScreenPath) or io.open(tempScreenPath, "r") then
                                     local sData = love.image.newImageData(tempScreenPath)
                                     screenImg = love.graphics.newImage(sData)
                                end
                            end

                            if love.filesystem.getInfo(tempImgPath) or io.open(tempImgPath, "r") then
                                local imgData = love.image.newImageData(tempImgPath)
                                local img = love.graphics.newImage(imgData)
                                table.insert(results, {
                                    image = img,
                                    screenshot = screenImg,
                                    tempScreenPath = tempScreenPath,
                                    description = description,
                                    year = year,
                                    region = region,
                                    tempPath = tempImgPath,
                                    source = "ScreenScraper"
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. TheGamesDB
    if config.scraperApi == "all" or config.scraperApi == "thegamesdb" then
        local apikey = config.thegamesdb_apikey
        
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
            local response = handle:read("*a")
            handle:close()
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
                                    
                                    local screenImg = nil
                                    local tempScreenPath = nil
                                    if data.include.screenshot and data.include.screenshot.data and data.include.screenshot.data[gameId] then
                                        local scr = data.include.screenshot.data[gameId][1]
                                        if scr then
                                            local screenUrl = "https://cdn.thegamesdb.net/images/original/" .. scr.filename
                                            tempScreenPath = "/tmp/scraper_tgdb_scr_" .. gameId .. ".png"
                                            os.execute("curl -s -L '" .. screenUrl .. "' -o " .. tempScreenPath)
                                            if love.filesystem.getInfo(tempScreenPath) or io.open(tempScreenPath, "r") then
                                                screenImg = love.graphics.newImage(tempScreenPath)
                                            end
                                        end
                                    end

                                    if love.filesystem.getInfo(tempImgPath) or io.open(tempImgPath, "r") then
                                        local imgData = love.image.newImageData(tempImgPath)
                                        local img = love.graphics.newImage(imgData)
                                        table.insert(results, {
                                            image = img,
                                            screenshot = screenImg,
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
             
             local function tryLibretro(nameToTry, label)
                 local nameEnc = utils.urlencode(nameToTry):gsub("%+", "%%20")
                 local url = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Boxarts/" .. nameEnc .. ".png"
                 log("Libretro Request ("..label.."): " .. url)
                 
                 local tempImgPath = "/tmp/scraper_libretro_" .. label:gsub(" ", "_") .. ".png"
                 local handle = io.popen("curl -v -s -L -f '" .. url .. "' -o " .. tempImgPath .. " 2>&1")
                 local output = handle:read("*a")
                 handle:close()
                 log("Libretro Response ("..label.."): " .. (output or "nil"))
                 
                 local f = io.open(tempImgPath, "rb")
                 local data = nil
                 if f then
                     data = f:read("*a")
                     f:close()
                 end

                 if data and #data > 0 then
                     local snapUrl = "http://thumbnails.libretro.com/" .. sysEncoded .. "/Named_Snaps/" .. nameEnc .. ".png"
                     local tempScreenPath = "/tmp/scraper_libretro_snap_" .. label:gsub(" ", "_") .. ".png"
                     local screenImg = nil
                     os.execute("curl -s -L -f '" .. snapUrl .. "' -o " .. tempScreenPath)
                     
                     local fSnap = io.open(tempScreenPath, "rb")
                     if fSnap then
                         local sData = fSnap:read("*a")
                         fSnap:close()
                         if sData and #sData > 0 then
                             screenImg = love.graphics.newImage(love.filesystem.newFileData(sData, "snap.png"))
                         end
                     end

                     local fileData = love.filesystem.newFileData(data, "scraper.png")
                     local img = love.graphics.newImage(fileData)
                     table.insert(results, {
                         image = img,
                         screenshot = screenImg,
                         tempScreenPath = tempScreenPath,
                         description = "Libretro no proporciona descripciones.",
                         region = "Libretro ("..label..")",
                         tempPath = tempImgPath,
                         source = "Libretro"
                     })
                     return true
                 end
                 return false
             end
             
             local found = tryLibretro(cleanName, "Exacto")
             
             if not found then
                 local clean = cleanName:gsub("%b()", ""):gsub("%b[]", ""):gsub("^%s*(.-)%s*$", "%1")
                 if clean ~= cleanName then
                     found = tryLibretro(clean, "Limpio")
                 end
             end
             
             if not found then
                 table.insert(results, {error=true, text="Libretro: No encontrado", source="Libretro"})
             end
        end
    end

    if config.scraperApi == "mock" then
        log("Mock Scraping: " .. item.name)
        local mockSrc = love.filesystem.getSource() .. "/assets/icons/rom.png"
        local mockTemp = "/tmp/scraper_mock.png"
        os.execute("cp '" .. mockSrc .. "' " .. mockTemp)
        
        if io.open(mockTemp, "r") then
            local img = love.graphics.newImage(mockTemp)
            table.insert(results, {
                image = img,
                description = "Esto es una descripción de prueba en modo Mock.",
                region = "Mock Result (Test)",
                tempPath = mockTemp
            })
        end
    end
    return results
end

return M
