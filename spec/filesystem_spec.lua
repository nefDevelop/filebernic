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
