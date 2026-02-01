describe("filebernic.utils", function()
  local utils = require("filebernic.utils")

  describe("split", function()
    it("should split a string by a delimiter", function()
      local result = utils.split("a,b,c", ",")
      assert.are.same({"a", "b", "c"}, result)
    end)

    it("should handle an empty string", function()
      local result = utils.split("", ",")
      assert.are.same({""}, result)
    end)

    it("should handle a string with no delimiters", function()
      local result = utils.split("abc", ",")
      assert.are.same({"abc"}, result)
    end)

    it("should handle a string with a trailing delimiter", function()
      local result = utils.split("a,b,c,", ",")
      assert.are.same({"a", "b", "c", ""}, result)
    end)
  end)

  describe("getSystemDisplayName", function()
    it("should return the display name for a known variant", function()
      assert.are.equal("Nintendo - Game Boy Advance", utils.getSystemDisplayName("GBA"))
      assert.are.equal("Nintendo - Game Boy Advance", utils.getSystemDisplayName("gba"))
    end)

    it("should return the original name if no variant is found", function()
      assert.are.equal("UnknownSystem", utils.getSystemDisplayName("UnknownSystem"))
    end)

    it("should handle nil input", function()
      assert.is.falsy(utils.getSystemDisplayName(nil))
    end)
  end)

  describe("getSystemVariants", function()
    it("should return the variants for a known system", function()
      local variants = utils.getSystemVariants("GBA")
      assert.are.same({"GBA", "gba", "Nintendo - Game Boy Advance", "Game Boy Advance"}, variants)
    end)

    it("should return a table with the original name if no variant is found", function()
      local variants = utils.getSystemVariants("UnknownSystem")
      assert.are.same({"UnknownSystem"}, variants)
    end)

    it("should handle nil input", function()
      assert.are.same({}, utils.getSystemVariants(nil))
    end)
  end)

  describe("urlencode", function()
    it("should encode special characters", function()
      assert.are.equal("hello%20world", utils.urlencode("hello world"))
      assert.are.equal("a%2Bb%26c", utils.urlencode("a+b&c"))
    end)

    it("should not encode alphanumeric characters", function()
      assert.are.equal("abc123", utils.urlencode("abc123"))
    end)

    it("should handle an empty string", function()
      assert.are.equal("", utils.urlencode(""))
    end)
  end)

  describe("getSystemNameForItem", function()
    local originalIsVirtualRoot
    local originalSystemName
    local originalLog

    beforeEach(function()
      originalIsVirtualRoot = _G.isVirtualRoot
      originalSystemName = _G.systemName
      originalLog = _G.log
      _G.log = function() end -- Mock log function to prevent output during tests
    end)

    afterEach(function()
      _G.isVirtualRoot = originalIsVirtualRoot
      _G.systemName = originalSystemName
      _G.log = originalLog
    end)

    it("should return system from item.system if present", function()
      local item = { system = "NES" }
      assert.are.equal("NES", utils.getSystemNameForItem(item))
    end)

    it("should extract system from fullPath (roms)", function()
      local item = { fullPath = "/roms/SNES/game.zip" }
      assert.are.equal("snes", utils.getSystemNameForItem(item))
    end)

    it("should extract system from fullPath (simulador_sd)", function()
      local item = { fullPath = "/simulador_sd/GBA/game.zip" }
      assert.are.equal("gba", utils.getSystemNameForItem(item))
    end)

    it("should use global systemName as a fallback when not in virtual root", function()
      _G.isVirtualRoot = false
      _G.systemName = "GBC"
      local item = {}
      assert.are.equal("GBC", utils.getSystemNameForItem(item))
    end)

    it("should not use global systemName if isVirtualRoot is true", function()
      _G.isVirtualRoot = true
      _G.systemName = "GBC"
      local item = {}
      assert.is.falsy(utils.getSystemNameForItem(item))
    end)

    it("should extract system from file extension as a last resort", function()
      local item = { name = "mygame.gb" }
      assert.are.equal("gb", utils.getSystemNameForItem(item))
    end)

    it("should return nil if no system can be determined", function()
      local item = {}
      assert.is.falsy(utils.getSystemNameForItem(item))
    end)

    it("should handle nil item", function()
      assert.is.falsy(utils.getSystemNameForItem(nil))
    end)
  end)
end)