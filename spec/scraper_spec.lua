package.path = "./filebernic/?.lua;" .. package.path

_G.love = {
  filesystem = {
    getInfo = function() end,
    getSource = function() end
  }
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

  -- Keep original functions to restore them
  local original_utils_urlencode = utils.urlencode
  local original_filesystem_findInGamelist = filesystem.findInGamelist
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
    mock_json.decode = function(s) return {} end
    mock_io.popen_results = {}
    mock_io.open_files = {}
    mock_os.executed_commands = {}
    mock_love_fs.info = {}
    mock_love_fs.source = "/mock/source"

    -- Mock dependencies
    json.decode = mock_json.decode
    io.popen = function(cmd)
      local result = mock_io.popen_results[cmd] or ""
      return {
        read = function(self, fmt) return result end,
        close = function() end
      }
    end
    io.open = function(path, mode)
      if (mode == "r" or mode == "rb") and mock_io.open_files[path] then
        local content = mock_io.open_files[path]
        if content == true then content = "" end
        return {
          read = function(self, fmt) return content end,
          close = function() end
        }
      end
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
          imagePath = "/roms/nes/media/images/game.png",
          year = "1990"
        }
      end
      mock_io.open_files["/roms/nes/media/images/game.png"] = true

      local results = scraper.getScrapeResults(item, {}, log, "nes")

      assert.are.equal(1, #results)
      assert.are.equal("Local Description", results[1].description)
      assert.are.equal("1990", results[1].year)
      assert.are.equal("Local XML", results[1].source)
      assert.are.equal(1, #mock_os.executed_commands)
      assert.are.equal("cp '/roms/nes/media/images/game.png' /tmp/scraper_local.png", mock_os.executed_commands[1])
    end)

    it("should not scrape online if local data is found", function()
      mock_filesystem.findInGamelist = function() return { description = "local" } end
      
      local results = scraper.getScrapeResults(item, { scraperApi = "all" }, log, "nes")
      
      assert.are.equal(1, #results)
      assert.are.equal("Local XML", results[1].source)
      -- No curl commands should have been executed
      assert.are.equal(0, #mock_os.executed_commands)
    end)
  end)

  describe("TheGamesDB scraping", function()
    local config = { scraperApi = "thegamesdb", thegamesdb_apikey = "testkey" }

    it("should fetch and parse data from TheGamesDB", function()
      local url = "https://api.thegamesdb.net/v1/Games/ByGameName?apikey=testkey&name=game&fields=overview,release_date&include=boxart,screenshot"
      mock_io.popen_results[ "curl -s -L --max-time 10 '" .. url .. "'" ] = '{ "data": { "games": [ { "id": 1, "overview": "TGDB Desc", "release_date": "1991-01-01" } ] }, "include": { "boxart": { "data": { "1": [ { "side": "front", "filename": "box.jpg" } ] } } } }'
      
      json.decode = original_json_decode -- Use real json decoder
      -- Simular que el archivo de imagen temporal existe para que el scraper lo añada a los resultados.
      mock_love_fs.info["/tmp/scraper_tgdb_1.png"] = { type = 'file', size = 12345 }

      local results = scraper.getScrapeResults(item, config, log, "nes")
      
      assert.are.equal(1, #results)
      assert.are.equal("TGDB Desc", results[1].description)
      assert.are.equal("1991", results[1].year)
      assert.are.equal("TheGamesDB", results[1].source)
      assert.are.equal("curl -s -L 'https://cdn.thegamesdb.net/images/original/box.jpg' -o /tmp/scraper_tgdb_1.png", mock_os.executed_commands[1])
    end)

    it("should show error if API key is missing", function()
      local results = scraper.getScrapeResults(item, { scraperApi = "thegamesdb", thegamesdb_apikey = "" }, log, "nes")
      assert.are.equal(1, #results)
      assert.is_true(results[1].error)
      assert.are.equal("Error: Falta API Key TGDB", results[1].text)
    end)
  end)

  describe("Libretro scraping", function()
    local config = { scraperApi = "libretro" }

    it("should fetch and parse data from Libretro", function()
      local url = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game.png"
      mock_io.popen_results[ "curl -v -s -L -f '" .. url .. "' -o /tmp/scraper_libretro_Exacto.png 2>&1" ] = "HTTP/2 200"
      mock_io.open_files["/tmp/scraper_libretro_Exacto.png"] = "image data"

      local results = scraper.getScrapeResults(item, config, log, "nes")

      assert.are.equal(1, #results)
      assert.are.equal("Libretro", results[1].source)
      assert.are.equal("/tmp/scraper_libretro_Exacto.png", results[1].imagePath)
    end)

    it("should try fuzzy names if exact match fails", function()
      local item_fuzzy = { name = "game (USA).zip", fullPath = "/roms/nes/game (USA).zip" }
      local url_exact = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game%20(USA).png"
      local url_fuzzy = "http://thumbnails.libretro.com/Nintendo%20-%20Nintendo%20Entertainment%20System/Named_Boxarts/game%20(USA,%20Europe).png"
      
      mock_io.popen_results[ "curl -v -s -L -f '" .. url_exact .. "' -o /tmp/scraper_libretro_Exacto.png 2>&1" ] = "HTTP/2 404"
      mock_io.popen_results[ "curl -v -s -L -f '" .. url_fuzzy .. "' -o /tmp/scraper_libretro_FuzzyUSAEurope.png 2>&1" ] = "HTTP/2 200"
      mock_io.open_files["/tmp/scraper_libretro_FuzzyUSAEurope.png"] = "image data"

      local results = scraper.getScrapeResults(item_fuzzy, config, log, "nes")
      
      assert.are.equal(1, #results)
      assert.are.equal("Libretro", results[1].source)
      assert.is_not_nil(string.find(results[1].region, "Fuzzy"))
    end)
  end)
end)
