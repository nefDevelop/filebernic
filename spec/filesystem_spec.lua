package.path = "./filebernic/?.lua;" .. package.path
for i = #package.searchers, 1, -1 do if tostring(package.searchers[i]):find("luarocks") then table.remove(package.searchers, i) end end

_G.love = {
  filesystem = {
    getSource = function() return "." end,
    getDirectoryItems = function() return {} end,
    isFile = function() return false end,
    getInfo = function() return nil end,
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
    love.filesystem.getInfo = function(path)
      if path == "/mnt/mmc" then return { type = "directory" } end
      return nil
    end
    love.filesystem.getSource = function() return "/path/to/project/filebernic" end
    local result = filesystem.getArtPathForSystem("NES")
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/box/", result)
  end)

  it("should return simulator path if /mnt/mmc does not exist", function()
    love.filesystem.getInfo = function() return nil end
    love.filesystem.getSource = function() return "/path/to/project/filebernic" end
    love.filesystem.getDirectoryItems = function(path)
      return {"SNES"}
    end
    local result = filesystem.getArtPathForSystem("SNES")
    assert.are.equal("/path/to/project/filebernic/../Simulador_SD/MUOS/info/catalogue/SNES/box/", result)
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
    _G.log = function() end
    io.popen = function() return nil end
    os.execute = function() end
    love.filesystem.getInfo = function(path) return { type = "file" } end
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
    love.filesystem.getInfo = function(path)
      if path:find("%.nes$") then return { type = "file" } end
      if path:find("image") then return { type = "file" } end
      return nil
    end
    local validExtensions = {nes = true, zip = true}
    assert.is_true(filesystem.hasRoms("/roms/NES/", validExtensions))
  end)

  it("should return false if no rom is found", function()
    love.filesystem.getDirectoryItems = function(path)
      if path == "/roms/NES" then return {"image.png", "doc.txt"} end
      return {}
    end
    love.filesystem.getInfo = function(path) return { type = "file" } end
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

describe("filesystem.isSafePath and safeRemove", function()
  local filesystem = require("filebernic.filesystem")
  local original_os_remove
  local original_love_filesystem_getSource
  local removed_file
  local logged_msg

  before_each(function()
    original_os_remove = os.remove
    original_love_filesystem_getSource = love.filesystem.getSource
    love.filesystem.getSource = function() return "/home/user/project/filebernic" end
    removed_file = nil
    logged_msg = nil
    os.remove = function(path)
      removed_file = path
      return true
    end
  end)

  after_each(function()
    os.remove = original_os_remove
    love.filesystem.getSource = original_love_filesystem_getSource
  end)

  it("should return false for path traversal attempts", function()
    assert.is_false(filesystem.isSafePath("/mnt/mmc/ROMS/../../bin/bash"))
    assert.is_false(filesystem.isSafePath("Simulador_SD/ROMS/../secret.txt"))
  end)

  it("should return false for directories outside of bounds", function()
    assert.is_false(filesystem.isSafePath("/etc/passwd"))
    assert.is_false(filesystem.isSafePath("/mnt/mmc/MUOS/system/config.ini"))
    assert.is_false(filesystem.isSafePath("/mnt/sdcard/Images/photo.jpg"))
    assert.is_false(filesystem.isSafePath("/mnt/mmc/data/test.zip"))
  end)

  it("should return true for valid ROM and media paths", function()
    assert.is_true(filesystem.isSafePath("/mnt/mmc/ROMS/NES/game.zip"))
    assert.is_true(filesystem.isSafePath("/mnt/sdcard/ROMS/SNES/game.sfc"))
    assert.is_true(filesystem.isSafePath("/mnt/mmc/MUOS/info/catalogue/NES/box/game.png"))
    assert.is_true(filesystem.isSafePath("/mnt/mmc/MUOS/save/state/game.state"))
    assert.is_true(filesystem.isSafePath("/home/user/project/Simulador_SD/ROMS/GBA/game.gba"))
  end)

  it("safeRemove should block and log invalid paths", function()
    local mock_log = function(msg) logged_msg = msg end
    local success, err = filesystem.safeRemove("/etc/passwd", mock_log)
    
    assert.is_false(success)
    assert.are.equal("Ruta no autorizada por seguridad", err)
    assert.is_nil(removed_file)
    assert.is_truthy(logged_msg:find("SECURITY BLOCK"))
  end)

  it("safeRemove should allow valid paths", function()
    local mock_log = function(msg) logged_msg = msg end
    local success = filesystem.safeRemove("/mnt/mmc/ROMS/NES/game.zip", mock_log)
    
    assert.is_true(success)
    assert.are.equal("/mnt/mmc/ROMS/NES/game.zip", removed_file)
    assert.is_nil(logged_msg)
  end)
end)

describe("filesystem.deleteGameMedia", function()
  local filesystem = require("filebernic.filesystem")
  local original_os_remove
  local original_io_open
  local original_love_filesystem_getSource
  local mock_removed_files = {}
  local original_filesystem_safeRemove

  before_each(function()
    original_os_remove = os.remove
    original_io_open = io.open
    original_love_filesystem_getSource = love.filesystem.getSource
    original_filesystem_safeRemove = filesystem.safeRemove
    mock_removed_files = {}
    local fs_core = package.loaded["fs_core"]
    if fs_core then
      fs_core.safeRemove = function(path)
        table.insert(mock_removed_files, path)
        return true
      end
    end
  end)

  after_each(function()
    os.remove = original_os_remove
    io.open = original_io_open
    love.filesystem.getSource = original_love_filesystem_getSource
    filesystem.safeRemove = original_filesystem_safeRemove
  end)

  it("should remove media files using /mnt/mmc path if it exists", function()
    io.open = function(path, mode)
      if path == "/mnt/mmc" then return { close = function() end } end
      return nil
    end

    filesystem.deleteGameMedia("/mnt/mmc/ROMS/NES/SuperMario.zip")

    assert.are.equal(4, #mock_removed_files)
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/box/SuperMario.png", mock_removed_files[1])
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/text/SuperMario.txt", mock_removed_files[2])
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/text/SuperMario.year", mock_removed_files[3])
    assert.are.equal("/mnt/mmc/MUOS/info/catalogue/NES/preview/SuperMario.png", mock_removed_files[4])
  end)

  it("should remove media files using Simulator path if /mnt/mmc does not exist", function()
    io.open = function(path, mode) return nil end
    love.filesystem.getSource = function() return "/my/project/dir" end

    filesystem.deleteGameMedia("/mnt/sdcard/ROMS/SNES/Zelda.sfc")

    assert.are.equal(4, #mock_removed_files)
    assert.are.equal("/my/project/dir/../Simulador_SD/MUOS/info/catalogue/SNES/box/Zelda.png", mock_removed_files[1])
    assert.are.equal("/my/project/dir/../Simulador_SD/MUOS/info/catalogue/SNES/text/Zelda.txt", mock_removed_files[2])
    assert.are.equal("/my/project/dir/../Simulador_SD/MUOS/info/catalogue/SNES/text/Zelda.year", mock_removed_files[3])
    assert.are.equal("/my/project/dir/../Simulador_SD/MUOS/info/catalogue/SNES/preview/Zelda.png", mock_removed_files[4])
  end)

  it("should safely ignore paths without a valid system folder", function()
    filesystem.deleteGameMedia("/invalid/path/game.zip")
    assert.are.equal(0, #mock_removed_files)
  end)
end)

describe("filesystem.removeFromIndex", function()
  local filesystem = require("filebernic.filesystem")
  local mock_io_open
  local mock_written_data

  before_each(function()
    mock_written_data = nil
    mock_io_open = function(path, mode)
      if mode == "w" then
        return {
          write = function(self, data) mock_written_data = data end,
          close = function() end
        }
      end
      return nil
    end
  end)

  it("should remove a version from an item and keep the item if other versions exist", function()
    local romIndex = {
      {
        name = "Game",
        versions = {
          { fullPath = "/roms/nes/game (USA).nes" },
          { fullPath = "/roms/nes/game (EUR).nes" }
        }
      }
    }

    local result = filesystem.removeFromIndex("/roms/nes/game (USA).nes", romIndex, function(d) return "encoded_json" end, function() return "/tmp" end, mock_io_open)

    assert.are.equal(1, #result)
    assert.are.equal(1, #result[1].versions)
    assert.are.equal("/roms/nes/game (EUR).nes", result[1].versions[1].fullPath)
    assert.are.equal("encoded_json", mock_written_data)
  end)

  it("should remove the item entirely if its last version is removed", function()
    local romIndex = {
      { name = "Game 1", versions = { { fullPath = "/roms/nes/game1.nes" } } },
      { name = "Game 2", versions = { { fullPath = "/roms/nes/game2.nes" } } }
    }

    local result = filesystem.removeFromIndex("/roms/nes/game1.nes", romIndex, function(d) return "encoded_json" end, function() return "/tmp" end, mock_io_open)

    assert.are.equal(1, #result)
    assert.are.equal("Game 2", result[1].name)
    assert.are.equal("encoded_json", mock_written_data)
  end)

  it("should promote the fullPath and sourceLabel to the root item if only 1 version remains", function()
    local romIndex = {
      {
        name = "Game",
        fullPath = "multi",
        sourceLabel = "Multi",
        versions = {
          { fullPath = "/roms/nes/game (USA).nes", sourceLabel = "SD1" },
          { fullPath = "/roms/nes/game (EUR).nes", sourceLabel = "SD2" }
        }
      }
    }

    local result = filesystem.removeFromIndex("/roms/nes/game (USA).nes", romIndex, function() return "" end, function() return "/tmp" end, mock_io_open)

    assert.are.equal(1, #result)
    assert.are.equal(1, #result[1].versions)
    assert.are.equal("/roms/nes/game (EUR).nes", result[1].fullPath)
    assert.are.equal("SD2", result[1].sourceLabel)
  end)
end)

describe("filesystem.logDeletion", function()
  local filesystem = require("filebernic.filesystem")
  local original_os_date = os.date
  local original_io_open = io.open

  after_each(function()
    os.date = original_os_date
    io.open = original_io_open
  end)

  it("should append a deletion log and handle missing previous log", function()
    local written_json = "" -- Initialize to empty string
    io.open = function(p, m) if m == "r" then return nil end return { write = function(s, d) written_json = d end, close = function() end } end
    local mock_encode = function(obj) return "length:" .. #obj end
    
    filesystem.logDeletion("/game.zip", mock_encode, function() return {} end)
    assert.are.equal("length:1", written_json)
  end)
end)

describe("filesystem copyFile and moveFile", function()
  local filesystem = require("filebernic.filesystem")
  local original_io_open = io.open
  local original_os_remove = os.remove
  local mock_io = {}
  local deleted_paths = {}

  before_each(function()
    _G.love = { filesystem = { getSource = function() return "/src" end, getInfo = function() end } }
    deleted_paths = {}
    os.remove = function(path) table.insert(deleted_paths, path); return true end
    local fs_core = package.loaded["fs_core"]
    if fs_core then fs_core.safeRemove = function(path) table.insert(deleted_paths, path); return true end end
    mock_io = { writes = {} }
    io.open = function(path, mode)
      if mode == "rb" then
        return {
          read = function(self, bytes)
            if not self.read_once then self.read_once = true return "DUMMY_DATA" end
            return nil -- Simulate end of file
          end,
          close = function() end
        }
      elseif mode == "wb" then
        return {
          write = function(self, data) mock_io.writes[path] = data end,
          close = function() end
        }
      end
      return nil
    end
  end)

  after_each(function()
    io.open = original_io_open
    os.remove = original_os_remove
  end)

  it("should successfully copy data from source to destination", function()
    local success, err = filesystem.copyFile("/mnt/mmc/ROMS/game.zip", "/mnt/sdcard/ROMS/game.zip")
    assert.is_true(success)
    assert.are.equal("DUMMY_DATA", mock_io.writes["/mnt/sdcard/ROMS/game.zip"])
  end)

  it("should successfully move data and delete original file", function()
    local success, err = filesystem.moveFile("/mnt/mmc/ROMS/game.zip", "/mnt/sdcard/ROMS/game.zip")
    assert.is_true(success)
    assert.are.equal("DUMMY_DATA", mock_io.writes["/mnt/sdcard/ROMS/game.zip"])
    assert.are.equal("/mnt/mmc/ROMS/game.zip", deleted_paths[1])
  end)
end)
