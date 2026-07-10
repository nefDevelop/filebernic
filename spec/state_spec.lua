package.path = "./filebernic/?.lua;" .. package.path
for i = #package.searchers, 1, -1 do if tostring(package.searchers[i]):find("luarocks") then table.remove(package.searchers, i) end end

_G.love = {
  filesystem = {
    getSource = function() end
  }
}

describe("State", function()
  local State = require("filebernic.state")
  local json = require("libs.dkjson")
  local mock_love_fs = { source = "/mock/source" }
  local mock_io = {}
  local mock_os = {}
  local mock_json = {}

  -- Keep original functions
  local original_love_fs_getSource = love.filesystem.getSource
  local original_io_open = io.open
  local original_os_execute = os.execute
  local original_json_encode = json.encode
  local original_json_decode = json.decode

  before_each(function()
    -- Reset mocks
    mock_love_fs.getSource = function() return "/mock/source" end
    -- Mock love.filesystem for saveAppState
    love.filesystem = {
      getSource = mock_love_fs.getSource
    }
    mock_io.written_files = {}
    mock_io.read_files = {}
    mock_os.executed_commands = {}
    mock_json.encoded_data = nil
    mock_json.decoded_data = nil

    -- Mock dependencies
    love.filesystem.getSource = mock_love_fs.getSource
    os.execute = function(cmd) table.insert(mock_os.executed_commands, cmd) end
    json.encode = function(tbl)
      mock_json.encoded_data = tbl
      return "json_string"
    end
    json.decode = function(str) return mock_json.decoded_data end
    
    io.open = function(path, mode)
      if mode == "w" then
        return {
          write = function(self, content) mock_io.written_files[path] = content end,
          close = function() end
        }
      elseif mode == "r" then
        if mock_io.read_files[path] then
          return {
            read = function() return mock_io.read_files[path] end,
            close = function() end
          }
        end
      end
      return nil
    end
  end)

  after_each(function()
    -- Restore
    love.filesystem.getSource = original_love_fs_getSource
    io.open = original_io_open
    os.execute = original_os_execute
    json.encode = original_json_encode
    json.decode = original_json_decode
  end)

  describe("saveAppState", function()
    it("should create data directory", function()
      State.saveAppState("/path", 1, false, true, "list", "auto", false, love.filesystem) -- Pass love.filesystem
      assert.are.equal("mkdir -p '/mock/source/data'", mock_os.executed_commands[1]) -- Expect quotes
    end)

    it("should save the state to app_state.json", function()
      State.saveAppState("/path", 1, false, true, "list", "auto", false, love.filesystem)
      assert.is_not_nil(mock_io.written_files["/mock/source/data/app_state.json.tmp"])
      assert.are.equal("json_string", mock_io.written_files["/mock/source/data/app_state.json.tmp"])
    end)

    it("should normalize /mnt/mmc/ROMS/ paths", function()
      local path = "/mnt/mmc/ROMS/NES"
      State.saveAppState(path, 1, false, true, "list", "auto", false, love.filesystem)
      assert.are.equal("ROMS/NES", mock_json.encoded_data.romPath)
    end)

    it("should normalize /mnt/sdcard/ROMS/ paths", function()
      local path = "/mnt/sdcard/ROMS/SNES"
      State.saveAppState(path, 1, false, true, "list", "auto", false, love.filesystem)
      assert.are.equal("ROMS/SNES", mock_json.encoded_data.romPath)
    end)

    it("should normalize Simulador_SD paths", function()
      local path = "/some/path/Simulador_SD/GBA"
      State.saveAppState(path, 1, false, true, "list", "auto", false, love.filesystem)
      assert.are.equal("ROMS/GBA", mock_json.encoded_data.romPath)
    end)

    it("should save all state fields correctly", function()
      State.saveAppState("/path", 123, true, false, "grid", "manual", true, love.filesystem)
      local data = mock_json.encoded_data
      assert.are.equal("/path", data.romPath)
      assert.are.equal(123, data.selectedIndex)
      assert.is_true(data.hideEmpty)
      assert.is_false(data.markPlayed)
      assert.are.equal("grid", data.viewMode)
      assert.are.equal("manual", data.launchMode)
      assert.is_true(data.hideFavorites)
    end)
  end)

  describe("loadConfig", function()
    local defaultConfig = { theme = "dark", volume = 10 }

    it("should load and merge config from existing file", function()
      mock_io.read_files["/mock/source/data/config.json"] = "json_content"
      mock_json.decoded_data = { theme = "light", show_hidden = true }
      
      local config = State.loadConfig(defaultConfig, love.filesystem)

      assert.are.equal("light", config.theme)
      assert.are.equal(10, config.volume)
      assert.is_true(config.show_hidden)
      assert.are.equal(1, config.configVersion)
    end)

    it("should return defaults if config file does not exist", function()
      local config = State.loadConfig(defaultConfig, love.filesystem) -- Pass love.filesystem
      assert.are.equal(1, config.configVersion) -- Version field added
      assert.are.equal("dark", config.theme)
      assert.are.equal(10, config.volume)
    end)

    it("should create a new config file with defaults if it does not exist", function()
      State.loadConfig(defaultConfig, love.filesystem) -- Pass love.filesystem
      -- Check that it was written
      assert.is_not_nil(mock_io.written_files["/mock/source/data/config.json"])
      -- Check that the data written includes configVersion
      assert.are.equal(1, mock_json.encoded_data.configVersion)
    end)
  end)
end)
