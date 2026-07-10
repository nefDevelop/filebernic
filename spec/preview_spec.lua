package.path = "./filebernic/?.lua;" .. package.path
for i = #package.searchers, 1, -1 do if tostring(package.searchers[i]):find("luarocks") then table.remove(package.searchers, i) end end

_G.love = {
  math = { random = function(a, b) return a end },
  filesystem = { getSource = function() return "/mock" end, getInfo = function() end },
  graphics = { newImage = function() end },
  timer = { sleep = function() end },
}

local preview = require("preview")

describe("preview.load", function()
  before_each(function()
    require("filesystem").getArtPathForSystem = function(s) return "/mock/catalogue/" .. s .. "/box/" end
    require("filesystem").updateSystemForFile = function(item, ...) return "nes", "/art/", "/text/", "/preview/" end
    require("utils").getSystemNameForItem = function() return "nes" end
  end)

  it("should set previewItem to nil for directories", function()
    local gs = { files = {}, focusedItem = { isDir = true, name = "nes" }, imageInvalid = false, screenshotInvalid = false, currentYear = "1990", currentDescription = "desc", previewItem = "old" }
    preview.load(gs)
    assert.is_nil(gs.previewItem)
    assert.is_true(gs.imageInvalid)
    assert.is_true(gs.screenshotInvalid)
    assert.is_nil(gs.currentYear)
    assert.are.equal("", gs.currentDescription)
  end)

  it("should set previewItem to nil if list is empty", function()
    local gs = { files = {}, focusedItem = nil, imageInvalid = false, screenshotInvalid = false, previewItem = "old" }
    preview.load(gs)
    assert.is_nil(gs.previewItem)
  end)

  it("should set previewItem to selected file", function()
    local gs = { files = { { name = "game.nes" }, { name = "other.sfc" } }, focusedItem = nil, selectedIndex = 1, launchMode = "Folder", imageInvalid = false, screenshotInvalid = false, currentYear = "1990", currentDescription = "desc", previewItem = nil, systemName = "nes", muosArtPath = "", muosTextPath = "", muosPreviewPath = "", romPath = "/roms/nes/", isVirtualRoot = false, love = _G.love }
    preview.load(gs, nil, { request = function() end })
    assert.are.equal("game.nes", gs.previewItem.name)
  end)

  it("should pick random version in Juego Unico mode", function()
    local gs = { files = { { name = "Game", versions = { { name = "game (USA).nes" }, { name = "game (EUR).nes" } } } }, focusedItem = nil, selectedIndex = 1, launchMode = "Juego Unico", imageInvalid = false, screenshotInvalid = false, currentYear = "1990", currentDescription = "desc", previewItem = nil, systemName = "nes", muosArtPath = "", muosTextPath = "", muosPreviewPath = "", romPath = "/roms/nes/", isVirtualRoot = true, love = _G.love }
    preview.load(gs, nil, { request = function() end })
    assert.are.equal("game (USA).nes", gs.previewItem.name)
  end)

  it("should request boxart, screenshot, description and year files", function()
    local requested = {}
    local gs = { files = { { name = "game.nes" } }, focusedItem = nil, selectedIndex = 1, launchMode = "Folder", imageInvalid = false, screenshotInvalid = false, currentYear = "1990", currentDescription = "desc", previewItem = nil, systemName = "nes", muosArtPath = "", muosTextPath = "", muosPreviewPath = "", romPath = "/roms/nes/", isVirtualRoot = false, love = _G.love }
    local loader = { request = function(_, path) table.insert(requested, path) end }
    preview.load(gs, nil, loader)
    assert.are.equal(4, #requested)
  end)

  it("should use focusedItem over selectedIndex", function()
    local gs = { files = { { name = "unselected.nes" } }, focusedItem = { name = "focused.sfc", isDir = false }, selectedIndex = 1, launchMode = "Folder", imageInvalid = false, screenshotInvalid = false, currentYear = "1990", currentDescription = "desc", previewItem = nil, systemName = "sfc", muosArtPath = "", muosTextPath = "", muosPreviewPath = "", romPath = "/roms/sfc/", isVirtualRoot = false, love = _G.love }
    preview.load(gs, nil, { request = function() end })
    assert.are.equal("focused.sfc", gs.previewItem.name)
  end)
end)
