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

  end)
end)