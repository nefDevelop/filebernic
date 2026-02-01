package.path = "./filebernic/?.lua;" .. package.path

describe("Indexer", function()
  -- We can't test the thread directly, but we can test the functions it uses.
  -- The indexer.lua file is not a module, so we load it and expose its functions.
  local indexer_env = {}
  local function load_indexer_functions()
    local f = assert(loadfile("filebernic/indexer.lua", "t", indexer_env))
    -- Mock channels before running the script
    indexer_env.love = { thread = { getChannel = function()
      return { push = function() end, demand = function() return { command = "quit" } end }
    end } }
    -- Mock other globals the script expects
    indexer_env.require = require
    indexer_env.io = { popen = function() end, open = function() end }
    indexer_env.os = { execute = function() end }
    indexer_env.json = require("libs.dkjson")
    indexer_env.scraper = { getScrapeResults = function() end }
    indexer_env.filesystem = { checkIndex = function() end, saveScrapeResult = function() end, updateSystemForFile = function() end }
    
    -- By running the loaded chunk, the functions like scanRoot will be defined in indexer_env
    f()
  end

  load_indexer_functions()
  local scanRoot = indexer_env.scanRoot

  describe("scanRoot", function()
    local validExtensions
    local newIndex
    local fileMap
    local romDirs
    local mock_channel_out

    before_each(function()
      validExtensions = { zip = true, nes = true }
      newIndex = {}
      fileMap = {}
      romDirs = {}
      
      -- Mock the output channel to capture progress messages
      mock_channel_out = { 
        pushes = {},
        push = function(self, msg) table.insert(self.pushes, msg) end
      }
      indexer_env.channel_out = mock_channel_out

      -- Mock io.open to simulate directory existence
      indexer_env.io.open = function(path, mode)
        if path == "/test/roms/" and mode == "r" then return true end
        return nil
      end
    end)

    it("should scan a directory and find roms", function()
      local find_output = {
        "/test/roms/game1.nes",
        "/test/roms/game2.zip",
        "/test/roms/image.png" -- should be ignored
      }
      indexer_env.io.popen = function(cmd)
        assert.are.equal('find "/test/roms/" -type f', cmd)
        local i = 0
        return {
          lines = function()
            i = i + 1
            if i <= #find_output then return function() return find_output[i] end end
            return nil
          end,
          close = function() end
        }
      end

      scanRoot("/test/roms/", validExtensions, newIndex, fileMap, romDirs)

      assert.are.equal(1, #romDirs)
      assert.are.equal("/test/roms/", romDirs[1])
      assert.are.equal(2, #newIndex)
      assert.are.equal("game1", newIndex[1].name)
      assert.are.equal("game2", newIndex[2].name)
    end)

    it("should group roms with same base name", function()
      local find_output = {
        "/test/roms/ROMS/NES/game (USA).zip",
        "/test/roms/ROMS/NES/game (Europe).zip"
      }
       indexer_env.io.popen = function(cmd)
        local i = 0
        return {
          lines = function()
            i = i + 1
            if i <= #find_output then return function() return find_output[i] end end
            return nil
          end,
          close = function() end
        }
      end

      scanRoot("/test/roms/", validExtensions, newIndex, fileMap, romDirs)
      
      assert.are.equal(1, #newIndex)
      assert.are.equal("game", newIndex[1].name)
      assert.are.equal(2, #newIndex[1].versions)
      assert.are.equal("game (USA).zip", newIndex[1].versions[1].name)
      assert.are.equal("game (Europe).zip", newIndex[1].versions[2].name)
      assert.are.equal("Multi", newIndex[1].sourceLabel)
    end)

    it("should extract system name from path", function() {
      local find_output = { "/test/roms/ROMS/SNES/snes_game.zip" }
      indexer_env.io.popen = function(cmd)
        local i = 0
        return {
          lines = function()
            i = i + 1
            if i <= #find_output then return function() return find_output[i] end end
            return nil
          end,
          close = function() end
        }
      end

      scanRoot("/test/roms/", validExtensions, newIndex, fileMap, romDirs)

      assert.are.equal(1, #newIndex)
      assert.are.equal("SNES", newIndex[1].sourceLabel)
      assert.are.equal("SNES", newIndex[1].versions[1].system)
    })
  end)
end)
