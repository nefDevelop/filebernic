package.path = "./filebernic/?.lua;" .. package.path
local searchers = package.loaders or package.searchers; for i = #searchers, 1, -1 do if tostring(searchers[i]):find("luarocks") then table.remove(searchers, i) end end

_G.love = { filesystem = { getSource = function() return "/app" end, getInfo = function() end } }
_G.json = { encode = function(t) return "{}" end, decode = function(s) return {} end }
local data = require("fs_data")

describe("fs_data save/load favorites", function()
  local original_io_open

  before_each(function()
    original_io_open = io.open
  end)

  after_each(function()
    io.open = original_io_open
  end)

  it("saveFavorites should write JSON", function()
    local written = ""
    io.open = function(p, m)
      if m == "w" then return { write = function(_, d) written = d end, close = function() end } end
      return nil
    end
    data.saveFavorites({ ["/roms/g.zip"] = true }, function(t) return "json_encoded" end)
    assert.are.equal("json_encoded", written)
  end)

  it("loadFavorites should parse JSON", function()
    io.open = function(p, m)
      if m == "r" then return { read = function() return '{"ok":true}' end, close = function() end } end
      return nil
    end
    local r = data.loadFavorites(function(s) return { ok = true } end)
    assert.is_true(r.ok)
  end)

  it("loadFavorites should return {} if no file", function()
    io.open = function() return nil end
    assert.are.same({}, data.loadFavorites(function() end))
  end)
end)

describe("fs_data history", function()
  local original_io_open

  before_each(function()
    original_io_open = io.open
  end)

  after_each(function()
    io.open = original_io_open
  end)

  it("saveHistory writes each ROM on separate line", function()
    local written = ""
    io.open = function(p, m)
      if m == "w" then return { write = function(_, d) written = d end, close = function() end } end
      return nil
    end
    data.saveHistory({ ["/a.zip"] = true, ["/b.zip"] = true })
    assert.is_true(written:find("/a.zip") ~= nil)
    assert.is_true(written:find("/b.zip") ~= nil)
  end)
end)

describe("fs_data saveLastPlayed and savePendingHistory", function()
  local original_io_open

  before_each(function()
    original_io_open = io.open
  end)

  after_each(function()
    io.open = original_io_open
  end)

  it("saveLastPlayed writes path", function()
    local written = ""
    io.open = function(p, m)
      if m == "w" then return { write = function(_, d) written = d end, close = function() end } end
      return nil
    end
    data.saveLastPlayed("/roms/last.zip")
    assert.are.equal("/roms/last.zip", written)
  end)

  it("savePendingHistory writes path", function()
    local written = ""
    io.open = function(p, m)
      if m == "w" then return { write = function(_, d) written = d end, close = function() end } end
      return nil
    end
    data.savePendingHistory("/roms/pending.zip")
    assert.are.equal("/roms/pending.zip", written)
  end)
end)

describe("fs_data checkPendingHistory", function()
  local original_io_open
  local original_os_remove

  before_each(function()
    original_io_open = io.open
    original_os_remove = os.remove
  end)

  after_each(function()
    io.open = original_io_open
    os.remove = original_os_remove
  end)

  it("loads pending and calls saveHistoryFunc", function()
    io.open = function(p, m)
      if m == "r" then return { read = function() return "/roms/pend.zip" end, close = function() end } end
      return nil
    end
    os.remove = function() end
    local saved = {}
    data.checkPendingHistory({}, function(roms) saved = roms end)
    assert.is_true(saved["/roms/pend.zip"])
  end)
end)

describe("fs_data logDeletion", function()
  local original_io_open
  local original_os_date

  before_each(function()
    original_io_open = io.open
    original_os_date = os.date
  end)

  after_each(function()
    io.open = original_io_open
    os.date = original_os_date
  end)

  it("should encode log as JSON", function()
    local written = ""
    io.open = function(p, m)
      if m == "r" then return nil end
      return { write = function(_, d) written = d end, close = function() end }
    end
    os.date = function() return "2024-01-01" end
    data.logDeletion("/deleted.zip", function(obj) return "encoded:" .. #obj end, function() return {} end)
    assert.is_true(written:find("encoded:") ~= nil)
  end)
end)

describe("fs_data view cache", function()
  local original_io_open

  before_each(function()
    original_io_open = io.open
  end)

  after_each(function()
    io.open = original_io_open
  end)

  it("saveViewCache serializes files", function()
    local written = ""
    data.saveViewCache({ { name = "g.zip" } }, "/roms", 1, false, function() return "json" end, function() return "/app" end, function(p, m)
      if m == "w" then return { write = function(_, d) written = d end, close = function() end } end
      return nil
    end)
    assert.are.equal("json", written)
  end)

  it("loadViewCache returns nil if no cache", function()
    io.open = function() return nil end
    assert.is_nil(data.loadViewCache(function() end, function() return "/app" end, function() end))
  end)
end)
