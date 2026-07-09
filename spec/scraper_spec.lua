package.path = "./filebernic/?.lua;" .. package.path

_G.love = {
  filesystem = {
    getInfo = function() end,
    getSource = function() end
  },
  timer = {
    sleep = function() end
  }
}

_G.L = {
  get = function(key, ...)
    local translations = {
      error_no_response_tgdb = "Error: No se pudo obtener respuesta de TheGamesDB",
      error_invalid_response_tgdb = "Error: Respuesta inválida de TheGamesDB"
    }
    return translations[key] or key
  end
}

describe("Scraper", function()
  local scraper = require("filebernic.scraper")
  local json = require("libs.dkjson")
  local filesystem = require("filesystem") -- Require the actual module to mock its methods
  local utils = require("utils")
  local mock_utils = { urlencode = function(s) return s end }
  local mock_filesystem = { findInGamelist = function() return nil end }
  local mock_json = { decode = function(s) return {} end }
  local mock_io = {}
  local mock_os = {}
  local mock_love_fs = {}
  local copied_files = {}

  -- Keep original functions to restore them
  local original_utils_urlencode = utils.urlencode
  local original_filesystem_findInGamelist = filesystem.findInGamelist
  local original_filesystem_copyFile = filesystem.copyFile
  local original_json_decode = json.decode
  local original_io_popen = io.popen
  local original_io_open = io.open
  local original_os_execute = os.execute
  local original_love_fs_getInfo = love.filesystem.getInfo
  local original_love_fs_getSource = love.filesystem.getSource

  before_each(function()
    -- Reset mocks before each test
    utils.urlencode = function(s) return s:gsub(" ", "%%20") end
    mock_filesystem.findInGamelist = function() return nil end
    filesystem.findInGamelist = function(...) return mock_filesystem.findInGamelist(...) end
    copied_files = {}
    filesystem.copyFile = function(src, dest)
      table.insert(copied_files, {src = src, dest = dest})
      return true
    end
    mock_json.decode = function(s) return {} end
    mock_io.popen_calls = {}
    mock_io.written_files = {} -- Initialize written_files
    mock_io.popen_results = {}
    mock_io.open_files = {}
    mock_os.executed_commands = {}
    mock_love_fs.info = {}
    mock_love_fs.source = "/mock/source"

    -- Mock dependencies
    json.decode = mock_json.decode
    io.popen = function(cmd)
      table.insert(mock_io.popen_calls, cmd)
      local result = mock_io.popen_results[cmd] or ""
      -- print("Mock io.popen called: " .. cmd) -- Debugging
      return {
        read = function(self, fmt) return result end,
        close = function() end
      }
    end
    io.open = function(path, mode)
      -- print("Mock io.open called for path: " .. path .. ", mode: " .. mode) -- Debugging
      if (mode == "r" or mode == "rb") then
        if mock_io.open_files[path] then
          local content = mock_io.open_files[path]
          if content == true then content = "" end -- If just marked as existing, return empty string
          -- print("  -> Returning mock handle for read") -- Debugging
          return {
            read = function(self, fmt) 
              if self.read_done then return nil end
              self.read_done = true
              return content 
            end,
            seek = function(self, whence)
              if whence == "end" then
                return type(content) == "string" and #content or 100
              end
              return 0
            end,
            close = function() end
          }
        end
      elseif (mode == "w" or mode == "wb") then
        -- print("  -> Returning mock handle for write") -- Debugging
        return {
          write = function(self, content) mock_io.written_files[path] = content end,
          close = function() end
        }
      end
      -- print("  -> Returning nil") -- Debugging
      return nil
    end
    os.execute = function(cmd) table.insert(mock_os.executed_commands, cmd) end
    love.filesystem.getInfo = function(path) return mock_love_fs.info[path] end
    love.filesystem.getSource = function() return mock_love_fs.source end
  end)

  after_each(function()
    -- Restore original functions
    utils.urlencode = original_utils_urlencode
    filesystem.findInGamelist = original_filesystem_findInGamelist
    filesystem.copyFile = original_filesystem_copyFile
    json.decode = original_json_decode
    io.popen = original_io_popen
    io.open = original_io_open
    os.execute = original_os_execute
    love.filesystem.getInfo = original_love_fs_getInfo
    love.filesystem.getSource = original_love_fs_getSource
  end)

  local item = { name = "game.zip", fullPath = "/roms/nes/game.zip" }
  local log = function(msg) print("[Scraper Test] " .. tostring(msg)) end

  describe("Local Gamelist scraping", function()
    it("should return data from gamelist.xml if found", function()
      mock_filesystem.findInGamelist = function(path, name)
        return {
          description = "Local Description",
          -- Ensure imagePath is valid and exists for fs_getInfo and io.open
          imagePath = "/roms/nes/media/images/game.png",
          year = "1990"
        }
      end
      mock_love_fs.info["/roms/nes/media/images/game.png"] = { type = 'file', size = 12345 } -- Simulate file exists for fs_getInfo
      mock_io.open_files["/roms/nes/media/images/game.png"] = true

      local results = scraper.getScrapeResults(item, {}, log, "nes", love.filesystem.getInfo)
      assert.are.equal(1, #results)
      assert.are.equal("Local Description", results[1].description)
      assert.are.equal("1990", results[1].year)
      assert.are.equal("Local XML", results[1].source)
      assert.are.equal(1, #copied_files)
      assert.are.equal("/roms/nes/media/images/game.png", copied_files[1].src)
      assert.are.equal("tmp/scraper_local.png", copied_files[1].dest)
    end)

    it("should not scrape online if local data is found", function()
      mock_filesystem.findInGamelist = function() return { description = "local" } end
      
      local results = scraper.getScrapeResults(item, { scraperApi = "all" }, log, "nes", love.filesystem.getInfo) -- Pass love.filesystem.getInfo
      
      assert.are.equal(1, #results)
      assert.are.equal("Local XML", results[1].source)
      -- No curl commands should have been executed
      assert.are.equal(0, #mock_os.executed_commands)
      assert.are.equal(0, #copied_files)
    end)
  end)

  describe("TheGamesDB scraping", function()
    local config = { scraperApi = "thegamesdb", thegamesdb_apikey = "testkey" }

    it("should fetch and parse data from TheGamesDB", function()
      local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=testkey&name=game&platform=Nintendo%20-%20Nintendo%20Entertainment%20System&fields=overview,release_date&include=boxart,screenshot"
      mock_io.popen_results[ "curl -s -L -k --max-time 10 -A 'Mozilla/5.0' " .. utils.escapeShellArg(url) .. " 2>/dev/null"] = '{ "data": { "games": [ { "id": 1, "overview": "TGDB Desc", "release_date": "1991-01-01", "game_title": "Game Title" } ] }, "include": { "boxart": { "data": { "1": [ { "side": "front", "filename": "box.jpg" } ] } } } }'
      
      json.decode = original_json_decode -- Use real json decoder
      -- Simular que el archivo de imagen temporal existe para que el scraper lo añada a los resultados.
      mock_io.open_files["tmp/scraper_tgdb_1_front_0.jpg"] = "mock image data"
      mock_io.popen_results["curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg("tmp/scraper_tgdb_1_front_0.jpg") .. " --write-out '%{http_code}' " .. utils.escapeShellArg("https://cdn.thegamesdb.net/images/original/box.jpg") .. " 2>/dev/null"] = "200"
      
      local results = scraper.getScrapeResults(item, config, log, "nes")
      
      assert.are.equal(1, #results)
      assert.are.equal("TGDB Desc", results[1].description)
      assert.are.equal("1991", results[1].year)
      assert.are.equal("TheGamesDB", results[1].source)
      assert.are.equal("curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg("tmp/scraper_tgdb_1_front_0.jpg") .. " --write-out '%{http_code}' " .. utils.escapeShellArg("https://cdn.thegamesdb.net/images/original/box.jpg") .. " 2>/dev/null", mock_io.popen_calls[2])
    end)

    it("should show error if API key is missing", function()
      local results = scraper.getScrapeResults(item, { scraperApi = "thegamesdb", thegamesdb_apikey = "" }, log, "nes", love.filesystem.getInfo) -- Pass love.filesystem.getInfo
      assert.are.equal(1, #results)
      assert.is_true(results[1].error)
      assert.are.equal("Error: Falta API Key TGDB", results[1].text)
    end)
    
    it("should handle network errors gracefully for TheGamesDB", function()
      local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=testkey&name=game&platform=Nintendo%20-%20Nintendo%20Entertainment%20System&fields=overview,release_date&include=boxart,screenshot"
      -- Simulate empty response (network error/timeout)
      mock_io.popen_results[ "curl -s -L -k --max-time 10 -A 'Mozilla/5.0' " .. utils.escapeShellArg(url) .. " 2>/dev/null"] = ""

      local results = scraper.getScrapeResults(item, config, log, "nes", love.filesystem.getInfo)
      assert.are.equal(1, #results)
      assert.is_true(results[1].error)
      assert.are.equal("Error: No se pudo obtener respuesta de TheGamesDB", results[1].text)
    end)

    it("should handle invalid JSON response for TheGamesDB", function()
      local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=testkey&name=game&platform=Nintendo%20-%20Nintendo%20Entertainment%20System&fields=overview,release_date&include=boxart,screenshot"
      -- Simulate invalid JSON
      mock_io.popen_results[ "curl -s -L -k --max-time 10 -A 'Mozilla/5.0' " .. utils.escapeShellArg(url) .. " 2>/dev/null"] = "NOT JSON DATA" 
      
      local results = scraper.getScrapeResults(item, config, log, "nes", love.filesystem.getInfo)
      assert.are.equal(1, #results)
      assert.is_true(results[1].error)
      assert.are.equal("Error: Respuesta inválida de TheGamesDB", results[1].text)
    end)
  end)

  describe("Libretro scraping", function()
    local config = { scraperApi = "libretro" }

    it("should fetch and parse data from Libretro", function()
      local url = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game.png"
      mock_io.popen_results["curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg("tmp/scraper_libretro_Exacto.png") .. " --write-out '%{http_code}' " .. utils.escapeShellArg(url) .. " 2>/dev/null"] = "200"
      mock_io.open_files["tmp/scraper_libretro_Exacto.png"] = "image data"

      local results = scraper.getScrapeResults(item, config, log, "nes", love.filesystem.getInfo) -- Pass love.filesystem.getInfo

      assert.are.equal(1, #results)
      assert.are.equal("Libretro", results[1].source)
      assert.are.equal("tmp/scraper_libretro_Exacto.png", results[1].imagePath)
    end)

    it("should try fuzzy names if exact match fails", function()
      local item_fuzzy = { name = "game (USA).zip", fullPath = "/roms/nes/game (USA).zip" }
      local url_exact = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game%20(USA).png"
      local url_fuzzy = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game%20(USA,%20Europe).png"
      
      mock_io.popen_results["curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg("tmp/scraper_libretro_Exacto.png") .. " --write-out '%{http_code}' " .. utils.escapeShellArg(url_exact) .. " 2>/dev/null"] = "404"
      mock_io.popen_results["curl -s -L -f -k --max-time 15 -A 'Mozilla/5.0' --output " .. utils.escapeShellArg("tmp/scraper_libretro_FuzzyUSAEurope.png") .. " --write-out '%{http_code}' " .. utils.escapeShellArg(url_fuzzy) .. " 2>/dev/null"] = "200"
      mock_io.open_files["tmp/scraper_libretro_FuzzyUSAEurope.png"] = "image data"

      local results = scraper.getScrapeResults(item_fuzzy, config, log, "nes", love.filesystem.getInfo) -- Pass love.filesystem.getInfo
      
      assert.are.equal(1, #results)
      assert.are.equal("Libretro", results[1].source)
      assert.is_not_nil(string.find(results[1].region, "Fuzzy"))
    end)
  end)
end)
