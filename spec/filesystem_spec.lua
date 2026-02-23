package.path = "./filebernic/?.lua;" .. package.path

_G.love = {
  filesystem = {
    getSource = function() return "." end,
    getDirectoryItems = function() return {} end,
    isFile = function() return false end
  }
}

describe("filesystem.escapeXML", function()
  local filesystem = require("filebernic.filesystem")

  it("should escape XML special characters", function()
    assert.are.equal("text &amp; more &lt;tag&gt; &quot;quotes&quot; &apos;single&apos;", filesystem.escapeXML("text & more <tag> \"quotes\" 'single'"))
  end)

  it("should handle an empty string", function()
    assert.are.equal("", filesystem.escapeXML(""))
  end)

  it("should handle a string with no special characters", function()
    assert.are.equal("hello world", filesystem.escapeXML("hello world"))
  end)

  it("should handle nil input", function()
    assert.are.equal("", filesystem.escapeXML(nil))
  end)
end)

describe("filesystem.getArtPathForSystem", function()
  local filesystem = require("filebernic.filesystem")
  local original_io_open
  local original_love_filesystem_getSource
  local original_log

  before_each(function()
    original_io_open = io.open
    original_love_filesystem_getSource = love.filesystem.getSource
    original_log = log
    _G.log = function() end -- Mock log function
  end)

  after_each(function()
    io.open = original_io_open
    love.filesystem.getSource = original_love_filesystem_getSource
    _G.log = original_log
  end)

  it("should return nil for nil systemName", function()
    assert.is.falsy(filesystem.getArtPathForSystem(nil))
  end)

  it("should return nil for empty systemName", function()
    assert.is.falsy(filesystem.getArtPathForSystem(""))
  end)

  it("should return MUOS path if /mnt/mmc exists", function()
    io.open = function(path, mode)
      if path == "/mnt/mmc" then return { close = function() end } end -- Simulate /mnt/mmc exists
      return original_io_open(path, mode)
    end
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/box/", filesystem.getArtPathForSystem("NES"))
  end)

  it("should return simulator path if /mnt/mmc does not exist", function()
    io.open = function(path, mode)
      if path == "/mnt/mmc" then return nil end
      return original_io_open(path, mode)
    end
    love.filesystem.getSource = function() return "/path/to/project/filebernic" end -- Mock love.filesystem.getSource
    assert.are.equal("/path/to/project/filebernic/../Simulador_SD/MUOS/info/catalogue/SNES/box/", filesystem.getArtPathForSystem("SNES"))
  end)
end)

describe("filesystem.hasRoms", function()
  local filesystem = require("filebernic.filesystem")
  local original_love_filesystem_getDirectoryItems
  local original_love_filesystem_isFile
  local original_log
  local original_io_popen
  local original_os_execute
  local original_io_open

  before_each(function()
    original_love_filesystem_getDirectoryItems = love.filesystem.getDirectoryItems
    original_love_filesystem_isFile = love.filesystem.isFile
    original_log = log
    original_io_popen = io.popen
    original_os_execute = os.execute
    original_io_open = io.open
    _G.log = function() end -- Mock log function
    io.popen = function() return nil end -- Mock popen to fail so it falls back to love.filesystem
    os.execute = function() end -- Mock os.execute to do nothing
    io.open = function(path, mode) if path == "/tmp/filebernic_hasroms.txt" then return nil end return original_io_open(path, mode) end -- Force fallback
  end)

  after_each(function()
    love.filesystem.getDirectoryItems = original_love_filesystem_getDirectoryItems
    love.filesystem.isFile = original_love_filesystem_isFile
    _G.log = original_log
    io.popen = original_io_popen
    os.execute = original_os_execute
    io.open = original_io_open
  end)

  it("should return true if a rom is found", function()
    love.filesystem.getDirectoryItems = function(path)
      if path == "/roms/NES/" then return {"game.nes", "image.png"} end
      return {}
    end
    love.filesystem.isFile = function(path)
      return path == "/roms/NES/game.nes"
    end
    local validExtensions = {nes = true, zip = true}
    assert.is_true(filesystem.hasRoms("/roms/NES/", validExtensions))
  end)

  it("should return false if no rom is found", function()
    love.filesystem.getDirectoryItems = function(path)
      if path == "/roms/NES" then return {"image.png", "doc.txt"} end
      return {}
    end
    love.filesystem.isFile = function(path)
      return path == "/roms/NES/image.png" or path == "/roms/NES/doc.txt"
    end
    local validExtensions = {nes = true, zip = true}
    assert.is_falsy(filesystem.hasRoms("/roms/NES", validExtensions))
  end)

  it("should return false if directory is empty", function()
    love.filesystem.getDirectoryItems = function(path)
      return {}
    end
    love.filesystem.isFile = function(path)
      return false
    end
    local validExtensions = {nes = true, zip = true}
    assert.is_falsy(filesystem.hasRoms("/roms/NES", validExtensions))
  end)

  it("should handle subdirectories correctly (not count them as roms)", function()
    love.filesystem.getDirectoryItems = function(path)
      if path == "/roms/SNES/" then return {"subdir/", "game.snes"} end
      return {}
    end
    love.filesystem.isFile = function(path)
      return path == "/roms/SNES/game.snes"
    end
    local validExtensions = {snes = true}
    assert.is_true(filesystem.hasRoms("/roms/SNES/", validExtensions))
  end)
end)

describe("filesystem.findInGamelist", function()
  local filesystem = require("filebernic.filesystem")
  local mock_io = {}
  local original_io_open = io.open

  before_each(function()
    mock_io.open_files = {}
    io.open = function(path, mode)
      if (mode == "r" or mode == "rb") and mock_io.open_files[path] then
        return { read = function() return mock_io.open_files[path] end, close = function() end }
      end
      return nil
    end
  end)

  after_each(function()
    io.open = original_io_open
  end)

  it("should return nil if gamelist.xml does not exist", function()
    assert.is_nil(filesystem.findInGamelist("/roms/nes/game.zip", "game.zip"))
  end)

  it("should return nil if gamelist.xml is empty", function()
    mock_io.open_files["/roms/nes/gamelist.xml"] = ""
    assert.is_nil(filesystem.findInGamelist("/roms/nes/game.zip", "game.zip"))
  end)

  it("should return nil if gamelist.xml is malformed (missing game block)", function()
    mock_io.open_files["/roms/nes/gamelist.xml"] = "<gameList><game><path>./game.zip</path></gameList>"
    assert.is_nil(filesystem.findInGamelist("/roms/nes/game.zip", "game.zip"))
  end)

  it("should return nil if gamelist.xml exists but does not contain the rom", function()
    mock_io.open_files["/roms/nes/gamelist.xml"] = "<gameList><game><path>./other_game.zip</path><name>Other Game</name></game></gameList>"
    assert.is_nil(filesystem.findInGamelist("/roms/nes/game.zip", "game.zip"))
  end)

  it("should return data if gamelist.xml contains the rom", function()
    mock_io.open_files["/roms/nes/gamelist.xml"] = "<gameList><game><path>./game.zip</path><name>Test Game</name><desc>A test description.</desc><releasedate>19900101T000000</releasedate><image>./media/images/game.png</image></game></gameList>"
    local result = filesystem.findInGamelist("/roms/nes/game.zip", "game.zip")
    assert.is_not_nil(result)
    assert.are.equal("A test description.", result.description)
    assert.are.equal("1990", result.year)
    assert.are.equal("/roms/nes/media/images/game.png", result.imagePath)
    assert.are.equal("Gamelist.xml", result.source)
  end)
end)
