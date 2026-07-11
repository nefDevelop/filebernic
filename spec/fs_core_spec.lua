package.path = "./filebernic/?.lua;" .. package.path
local searchers = package.loaders or package.searchers; for i = #searchers, 1, -1 do if tostring(searchers[i]):find("luarocks") then table.remove(searchers, i) end end

_G.love = { filesystem = { getSource = function() return "/app/filebernic" end, getInfo = function() end } }
local core = require("fs_core")

describe("isSafePath", function()
  it("rejects nil", function()
    assert.is_false(core.isSafePath(nil))
  end)

  it("rejects non-string", function()
    assert.is_false(core.isSafePath(123))
  end)

  it("allows ROM paths on SD1", function()
    assert.is_true(core.isSafePath("/mnt/mmc/ROMS/nes/game.zip"))
  end)

  it("allows ROM paths on SD2", function()
    assert.is_true(core.isSafePath("/mnt/sdcard/ROMS/snes/game.sfc"))
  end)

  it("allows save paths", function()
    assert.is_true(core.isSafePath("/mnt/mmc/MUOS/save/nes/game.srm"))
  end)

  it("allows catalogue paths", function()
    assert.is_true(core.isSafePath("/mnt/mmc/MUOS/info/catalogue/nes/box/game.png"))
  end)

  it("allows temporary paths", function()
    assert.is_true(core.isSafePath("/tmp/filebernic_temp.png"))
    assert.is_true(core.isSafePath("tmp/scraper_image.png"))
  end)

  it("allows app data paths", function()
    assert.is_true(core.isSafePath("/app/filebernic/data/config.json"))
    assert.is_true(core.isSafePath("/app/filebernic/tmp/cache.txt"))
  end)

  it("allows simulator paths", function()
    assert.is_true(core.isSafePath("Simulador_SD/ROMS/nes/game.zip"))
  end)

  it("rejects path traversal with ..", function()
    assert.is_false(core.isSafePath("/mnt/mmc/ROMS/../../etc/passwd"))
  end)

  it("rejects arbitrary system paths", function()
    assert.is_false(core.isSafePath("/etc/passwd"))
    assert.is_false(core.isSafePath("/bin/sh"))
  end)

  it("rejects relative traversal", function()
    assert.is_false(core.isSafePath("../../../etc/passwd"))
  end)
end)

describe("safeRemove", function()
  before_each(function()
    os.remove = function(path) return true end
  end)

  it("removes allowed files", function()
    assert.is_true(core.safeRemove("/mnt/mmc/ROMS/nes/game.zip"))
  end)

  it("blocks removal of disallowed files", function()
    local logged = ""
    assert.is_false(core.safeRemove("/etc/passwd", function(msg) logged = msg end))
    assert.is_true(logged:find("SECURITY BLOCK") ~= nil)
  end)
end)

describe("copyFile", function()
  local original_io

  before_each(function() original_io = io.open end)
  after_each(function() io.open = original_io end)

  it("copies file contents", function()
    local written = {}
    local eof = false
    io.open = function(path, mode)
      if mode == "rb" then return { read = function() if eof then return nil end; eof = true; return "test data" end, close = function() end } end
      if mode == "wb" then return { write = function(_, d) written[path] = d end, close = function() end } end
    end
    assert.is_true(core.copyFile("/mnt/mmc/ROMS/src.zip", "/mnt/sdcard/ROMS/dst.zip"))
    assert.are.equal("test data", written["/mnt/sdcard/ROMS/dst.zip"])
  end)

  it("fails if source missing", function()
    io.open = function() return nil end
    assert.is_false(core.copyFile("/nonexistent.zip", "/dest.zip"))
  end)
end)

describe("moveFile", function()
  local original_io
  local deleted = {}

  before_each(function()
    original_io = io.open
    deleted = {}
    os.remove = function(path) table.insert(deleted, path); return true end
  end)

  after_each(function() io.open = original_io end)

  it("copies then removes source", function()
    local eof = false
    io.open = function(path, mode)
      if mode == "rb" then return { read = function() if eof then return nil end; eof = true; return "data" end, close = function() end } end
      if mode == "wb" then return { write = function() end, close = function() end } end
    end
    assert.is_true(core.moveFile("/mnt/mmc/ROMS/game.zip", "/mnt/sdcard/ROMS/game.zip"))
    assert.are.equal("/mnt/mmc/ROMS/game.zip", deleted[1])
  end)
end)
