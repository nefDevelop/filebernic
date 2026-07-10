package.path = "./filebernic/?.lua;" .. package.path
local searchers = package.loaders or package.searchers; for i = #searchers, 1, -1 do if tostring(searchers[i]):find("luarocks") then table.remove(searchers, i) end end

describe("Input helpers", function()
  local helpers

  before_each(function()
    _G.love = {
      filesystem = { getSource = function() return "/mock/source/filebernic" end, getInfo = function() end },
      graphics = { newImage = function() end },
      thread = { getChannel = function() return { push = function() end, pop = function() end } end },
      keyboard = { setTextInput = function() end },
      timer = { sleep = function() end },
      joystick = { getJoystickCount = function() return 0 end, getJoysticks = function() return {} end },
      event = { quit = function() end },
      system = { getProcessorCount = function() return 4 end },
    }
    _G.L = { get = function(key) return key end, current = "es" }
    _G.json = { encode = function(t) return "{}" end, decode = function(s) return {} end }

    helpers = require("input_helpers")
  end)

  after_each(function()
    package.loaded["input_helpers"] = nil
  end)

  describe("jumpToNextLetter", function()
    it("should jump to next letter when there is one", function()
      local gs = {
        files = { { name = "Castlevania.zip" }, { name = "Donkey Kong.zip" }, { name = "Mario.zip" } },
        selectedIndex = 2, jumpLetter = "",
      }
      helpers.jumpToNextLetter(gs)
      assert.are.equal(3, gs.selectedIndex)
      assert.are.equal("M", gs.jumpLetter)
    end)

    it("should stay on last item if already at last letter", function()
      local gs = {
        files = { { name = "Castlevania.zip" }, { name = "Donkey Kong.zip" }, { name = "Mario.zip" } },
        selectedIndex = 3, jumpLetter = "",
      }
      helpers.jumpToNextLetter(gs)
      assert.are.equal(3, gs.selectedIndex)
    end)

    it("should handle single-element list", function()
      local gs = { files = { { name = "Solo.zip" } }, selectedIndex = 1, jumpLetter = "" }
      helpers.jumpToNextLetter(gs)
      assert.are.equal(1, gs.selectedIndex)
    end)

    it("should handle empty list", function()
      local gs = { files = {}, selectedIndex = 1, jumpLetter = "" }
      helpers.jumpToNextLetter(gs)
      assert.are.equal(1, gs.selectedIndex)
    end)
  end)

  describe("jumpToPrevLetter", function()
    it("should jump to previous letter", function()
      local gs = {
        files = { { name = "Castlevania.zip" }, { name = "Donkey Kong.zip" }, { name = "Mario.zip" } },
        selectedIndex = 3, jumpLetter = "",
      }
      helpers.jumpToPrevLetter(gs)
      assert.are.equal(2, gs.selectedIndex)
      assert.are.equal("D", gs.jumpLetter)
    end)

    it("should stay on first item", function()
      local gs = {
        files = { { name = "Castlevania.zip" }, { name = "Donkey Kong.zip" }, { name = "Mario.zip" } },
        selectedIndex = 1, jumpLetter = "",
      }
      helpers.jumpToPrevLetter(gs)
      assert.are.equal(1, gs.selectedIndex)
    end)

    it("should handle empty list", function()
      local gs = { files = {}, selectedIndex = 1, jumpLetter = "" }
      helpers.jumpToPrevLetter(gs)
      assert.are.equal(1, gs.selectedIndex)
    end)
  end)

  describe("filterFiles", function()
    it("should filter files by search query", function()
      local gs = {
        allFiles = { { name = "Super Mario.zip" }, { name = "Zelda.zip" }, { name = "Metroid.zip" } },
        files = {}, searchQuery = "mario", selectedIndex = 5,
      }
      helpers.filterFiles(gs)
      assert.are.equal(1, #gs.files)
      assert.are.equal("Super Mario.zip", gs.files[1].name)
      assert.are.equal(1, gs.selectedIndex)
    end)

    it("should return empty when no matches", function()
      local gs = { allFiles = { { name = "Super Mario.zip" } }, files = {}, searchQuery = "nonexistent", selectedIndex = 5 }
      helpers.filterFiles(gs)
      assert.are.equal(0, #gs.files)
      assert.are.equal(1, gs.selectedIndex)
    end)

    it("should be case insensitive", function()
      local gs = { allFiles = { { name = "SUPER MARIO.zip" } }, files = {}, searchQuery = "mario", selectedIndex = 1 }
      helpers.filterFiles(gs)
      assert.are.equal(1, #gs.files)
      assert.are.equal("SUPER MARIO.zip", gs.files[1].name)
    end)
  end)

  describe("saveLastPlayed", function()
    it("should call filesystem.saveLastPlayed", function()
      local called = false
      local fs = require("filesystem")
      local orig = fs.saveLastPlayed
      fs.saveLastPlayed = function(path) called = path end
      helpers.saveLastPlayed("/roms/test.zip")
      assert.are.equal("/roms/test.zip", called)
      fs.saveLastPlayed = orig
    end)
  end)

  describe("deleteGameMedia", function()
    it("should call filesystem.deleteGameMedia", function()
      local called = false
      local fs = require("filesystem")
      local orig = fs.deleteGameMedia
      fs.deleteGameMedia = function(path) called = path end
      helpers.deleteGameMedia("/roms/test.zip")
      assert.are.equal("/roms/test.zip", called)
      fs.deleteGameMedia = orig
    end)
  end)
end)
