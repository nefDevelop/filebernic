package.path = "./filebernic/?.lua;" .. package.path

describe("Utils", function()
  describe("checkGitHubUpdate", function()
    local utils
    local original_popen

    before_each(function()
      utils = require("utils")
      original_popen = io.popen
    end)

    after_each(function()
      -- Restaurar la función original después de cada test
      io.popen = original_popen
      package.loaded["utils"] = nil
    end)

    it("should return nil if current version matches latest version", function()
      local mock_json = [[{
        "tag_name": "v1.0.0",
        "assets": [
          { "name": "filebernic.muxapp", "browser_download_url": "http://example.com/filebernic.muxapp" }
        ]
      }
      ]]
      io.popen = function(cmd)
        return {
          read = function(self, mode) return mock_json end,
          close = function(self) end
        }
      end

      local version, url = utils.checkGitHubUpdate("v1.0.0")
      assert.is_nil(version)
      assert.is_nil(url)
    end)

    it("should return new version and url if update is available (.muxapp)", function()
      local mock_json = [[{
        "tag_name": "v1.1.0",
        "assets": [
          { "name": "source.tar.gz", "browser_download_url": "http://example.com/source.tar.gz" },
          { "name": "filebernic.muxapp", "browser_download_url": "http://example.com/filebernic.muxapp" }
        ]
      }
      ]]
      io.popen = function(cmd)
        return {
          read = function(self, mode) return mock_json end,
          close = function(self) end
        }
      end

      local version, url = utils.checkGitHubUpdate("v1.0.0")
      assert.are.equal("v1.1.0", version)
      assert.are.equal("http://example.com/filebernic.muxapp", url)
    end)

    it("should return nil if response is empty or network fails", function()
      io.popen = function(cmd)
        return {
          read = function(self, mode) return "" end,
          close = function(self) end
        }
      end

      local version, url = utils.checkGitHubUpdate("v1.0.0")
      assert.is_nil(version)
      assert.is_nil(url)
    end)

  describe("System Detection and Variants", function()
    local utils
    before_each(function()
      utils = require("utils")
    end)

    it("should return known variants for a system", function()
      local variants = utils.getSystemVariants("NES")
      assert.is_not_nil(variants)
      assert.is_true(utils.isKnownSystem("NES"))
      -- 'nes' should be in the variants table
      local found = false
      for _, v in ipairs(variants) do if v:lower() == "nes" then found = true end end
      assert.is_true(found)
    end)

    it("should get the correct display name", function()
      assert.are.equal("Nintendo - Super Nintendo Entertainment System", utils.getSystemDisplayName("SNES"))
      assert.are.equal("Sony - PlayStation", utils.getSystemDisplayName("PSX"))
      assert.are.equal("UnknownSys", utils.getSystemDisplayName("UnknownSys")) -- Fallback to input
    end)

    it("should correctly detect system from item table", function()
      -- 1. From pre-assigned property
      local item1 = { name = "game.zip", system = "GBA" }
      assert.are.equal("GBA", utils.getSystemNameForItem(item1, nil, true))

      -- 2. From fullPath
      local item2 = { name = "game.zip", fullPath = "/mnt/mmc/ROMS/N64/game.zip" }
      assert.are.equal("N64", utils.getSystemNameForItem(item2, nil, true))

      -- 3. Fallback to global system name (when not in virtual root)
      local item3 = { name = "game.zip", fullPath = "/some/weird/path/game.zip" }
      assert.are.equal("MD", utils.getSystemNameForItem(item3, "MD", false))

      -- 4. Fallback to extension
      local item4 = { name = "game.gba" }
      assert.are.equal("gba", utils.getSystemNameForItem(item4, nil, true))
    end)
  end)

  describe("escapeShellArg", function()
    local utils
    before_each(function()
      utils = require("utils")
    end)

    it("should return empty quotes for nil", function()
      assert.are.equal("''", utils.escapeShellArg(nil))
    end)

    it("should wrap normal strings in single quotes", function()
      assert.are.equal("'Hello World'", utils.escapeShellArg("Hello World"))
    end)

    it("should safely escape single quotes inside the string", function()
      -- 'Zelda's Adventure' -> 'Zelda'\''s Adventure'
      assert.are.equal("'Zelda'\"'\"'s Adventure'", utils.escapeShellArg("Zelda's Adventure"))
    end)

    it("should safely wrap bash variables and backticks as raw strings", function()
      assert.are.equal("'$(rm -rf /)'", utils.escapeShellArg("$(rm -rf /)"))
      assert.are.equal("'`reboot`'", utils.escapeShellArg("`reboot`"))
    end)
  end)
  end)
end)