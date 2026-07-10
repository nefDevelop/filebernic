package.path = "./filebernic/?.lua;" .. package.path
for i = #package.searchers, 1, -1 do if tostring(package.searchers[i]):find("luarocks") then table.remove(package.searchers, i) end end

_G.love = {
  keyboard = { setTextInput = function() end, isDown = function() return false end },
  joystick = { getJoystickCount = function() return 0 end, getJoysticks = function() return {} end },
  filesystem = { getSource = function() return "/mock" end, getInfo = function() end },
  graphics = { newImage = function() end },
  thread = { getChannel = function() return { push = function() end, pop = function() end } end },
  timer = { sleep = function() end, getTime = function() return 0 end },
  event = { quit = function() end },
  system = { getProcessorCount = function() return 4 end },
}
_G.L = { get = function(key, ...) return key end, current = "es" }
_G.json = { encode = function() return "{}" end, decode = function() return {} end }

local list = require("input_list")
local filesystem = require("filesystem")

local function makeGS(overrides)
  local gs = {
    love = _G.love, L = _G.L, math = math,
    state = "LIST",
    files = {},
    allFiles = {},
    selectedIndex = 1,
    selectedFilesCount = 0,
    romPath = "/mnt/mmc/ROMS/nes/",
    secondaryPath = nil,
    isVirtualRoot = false,
    launchMode = "Folder",
    viewMode = "LIST",
    hideEmpty = false,
    hideFavorites = false,
    markPlayed = true,
    gridCols = 4,
    pageSize = 7,
    inputCooldown = 0,
    pendingLoad = false,
    timer = 0,
    searchQuery = "",
    keyboardRow = 1,
    keyboardCol = 1,
    launching = false,
    launchTimer = 0,
    lastPlayedRom = "",
    romIndex = nil,
    validExtensions = { nes = true, snes = true, zip = true },
    playedRoms = {},
    favoriteRoms = {},
    saveFiles = {},
    menuAnim = 0,
    menuOptions = {},
    menuSelection = 1,
    menuTitle = "",
    menuMessage = "",
    menuStack = {},
    itemToLaunch = nil,
    iconFavorite = {}, iconFolder = {}, iconRom = {},
    iconInfo = {}, iconNetwork = {}, iconSaveStates = {}, iconTrash = {},
    json = _G.json,
    loader = { invalidate = function() end },
    preview = { load = function() end },
    config = {},
    log = function() end,
    indexerChannelIn = { push = function() end },
  }
  if overrides then
    for k, v in pairs(overrides) do gs[k] = v end
  end
  return gs
end

describe("input_list handleListInput", function()
  local orig_filesystem

  before_each(function()
    orig_filesystem = {}
    orig_filesystem.resolveSecondary = filesystem.resolveSecondary
    orig_filesystem.createMergedVirtualRoot = filesystem.createMergedVirtualRoot
    orig_filesystem.getTargetSDPath = filesystem.getTargetSDPath
    orig_filesystem.savePendingHistory = filesystem.savePendingHistory
    filesystem.resolveSecondary = function() return nil end
    filesystem.createMergedVirtualRoot = function(...) return {}, false, "", nil, 1, {} end
    filesystem.getTargetSDPath = function() return nil end
    filesystem.savePendingHistory = function() end
  end)

  after_each(function()
    filesystem.resolveSecondary = orig_filesystem.resolveSecondary
    filesystem.createMergedVirtualRoot = orig_filesystem.createMergedVirtualRoot
    filesystem.getTargetSDPath = orig_filesystem.getTargetSDPath
    filesystem.savePendingHistory = orig_filesystem.savePendingHistory
  end)

  describe("navigation", function()
    it("pageup in list view moves up by pageSize", function()
      local gs = makeGS({ files = { { name = "1.zip" }, { name = "2.zip" }, { name = "3.zip" }, { name = "4.zip" }, { name = "5.zip" }, { name = "6.zip" }, { name = "7.zip" }, { name = "8.zip" } }, selectedIndex = 8 })
      list.handleListInput("pageup", gs)
      assert.are.equal(1, gs.selectedIndex)
    end)

    it("pagedown in list view moves down by pageSize", function()
      local gs = makeGS({ files = { { name = "1.zip" }, { name = "2.zip" }, { name = "3.zip" }, { name = "4.zip" }, { name = "5.zip" }, { name = "6.zip" }, { name = "7.zip" }, { name = "8.zip" } }, selectedIndex = 1 })
      list.handleListInput("pagedown", gs)
      assert.are.equal(8, gs.selectedIndex)
    end)

    it("pageup in grid view moves by gridCols*3", function()
      local gs = makeGS({ viewMode = "GRID", gridCols = 4, files = { { name = "1.zip" }, { name = "2.zip" }, { name = "3.zip" }, { name = "4.zip" }, { name = "5.zip" }, { name = "6.zip" }, { name = "7.zip" }, { name = "8.zip" }, { name = "9.zip" }, { name = "10.zip" }, { name = "11.zip" }, { name = "12.zip" }, { name = "13.zip" } }, selectedIndex = 13 })
      list.handleListInput("pageup", gs)
      assert.are.equal(1, gs.selectedIndex)
    end)
  end)

  describe("search", function()
    it("f key opens search mode", function()
      local gs = makeGS({ files = { { name = "mario.zip" } }, allFiles = { { name = "mario.zip" }, { name = "zelda.zip" } } })
      list.handleListInput("f", gs)
      assert.are.equal("SEARCH", gs.state)
      assert.are.equal("", gs.searchQuery)
    end)
  end)

  describe("launch ROM", function()
    it("launches a simple ROM in folder mode", function()
      local gs = makeGS({ files = { { name = "game.nes" } }, selectedIndex = 1, romPath = "/mnt/mmc/ROMS/nes/" })
      list.handleListInput("kpenter", gs)
      assert.is_true(gs.launching)
      assert.are.equal("/mnt/mmc/ROMS/nes/game.nes", gs.lastPlayedRom)
    end)

    it("opens version menu for multi-version juego unico", function()
      local gs = makeGS({
        launchMode = "Juego Unico", isVirtualRoot = true,
        files = { { name = "Game", versions = { { name = "game (USA).nes", fullPath = "/roms/nes/game (USA).nes", system = "nes" }, { name = "game (EUR).nes", fullPath = "/roms/nes/game (EUR).nes", system = "nes" } } } },
        selectedIndex = 1,
      })
      list.handleListInput("kpenter", gs)
      assert.are.equal("OPTIONS_MENU", gs.state)
      assert.are.equal("version", gs.menuTitle)
    end)

    it("handles ambiguous zip/7z with system selector", function()
      local gs = makeGS({
        files = { { name = "unknown.zip" } }, selectedIndex = 1,
        romPath = "/mnt/mmc/ROMS/unknown_folder/",
      })
      list.handleListInput("kpenter", gs)
      assert.are.equal("OPTIONS_MENU", gs.state)
      assert.are.equal("select_system", gs.menuTitle)
    end)
  end)

  describe("options menu", function()
    it("tab key opens options menu for files", function()
      local gs = makeGS({ files = { { name = "game.nes" } }, selectedIndex = 1, L = { get = function(k) return k end } })
      list.handleListInput("tab", gs)
      assert.are.equal("OPTIONS_MENU", gs.state)
    end)

    it("tab key does nothing for directories", function()
      local gs = makeGS({ files = { { name = "nes", isDir = true } }, selectedIndex = 1 })
      list.handleListInput("tab", gs)
      assert.are.equal("LIST", gs.state)
    end)
  end)

  describe("select/mark", function()
    it("x key toggles item selection", function()
      local gs = makeGS({ files = { { name = "game.nes", selected = false } }, selectedIndex = 1, selectedFilesCount = 0 })
      list.handleListInput("x", gs)
      assert.is_true(gs.files[1].selected)
      assert.are.equal(1, gs.selectedFilesCount)
    end)

    it("x key deselects item", function()
      local gs = makeGS({ files = { { name = "game.nes", selected = true } }, selectedIndex = 1, selectedFilesCount = 1 })
      list.handleListInput("x", gs)
      assert.is_false(gs.files[1].selected)
      assert.are.equal(0, gs.selectedFilesCount)
    end)
  end)

  describe("back navigation", function()
    it("backspace in virtual root does nothing", function()
      local gs = makeGS({ isVirtualRoot = true, romPath = "" })
      list.handleListInput("backspace", gs)
      assert.are.equal("LIST", gs.state)
    end)

    it("backspace in subdirectory navigates up", function()
      local called = false
      local orig_refresh = require("input_helpers").refreshFiles
      require("input_helpers").refreshFiles = function() called = true end
      local gs = makeGS({
        isVirtualRoot = false, romPath = "/mnt/mmc/ROMS/nes/games/",
        files = { { name = "..", isDir = true }, { name = "game.nes" } },
      })
      list.handleListInput("backspace", gs)
      assert.is_true(called)
      assert.are.equal("/mnt/mmc/ROMS/nes/", gs.romPath)
      require("input_helpers").refreshFiles = orig_refresh
    end)
  end)

  describe("pendingDelete ghost items", function()
    it("moving past a ghost removes it", function()
      local gs = makeGS({
        files = { { name = "a.zip" }, { name = "b.zip", pendingDelete = true }, { name = "c.zip" } },
        selectedIndex = 2,
      })
      list.handleListInput("down", gs)
      assert.are.equal(2, #gs.files)
      assert.are.equal("c.zip", gs.files[2].name)
    end)
  end)

  describe("empty directory", function()
    it("backspace in empty dir calls refreshFiles to navigate up", function()
      local called = false
      local orig_refresh = require("input_helpers").refreshFiles
      require("input_helpers").refreshFiles = function() called = true end
      local gs = makeGS({ files = { { name = "..", isDir = true, empty = true } }, romPath = "/mnt/mmc/ROMS/nes/subdir/", selectedIndex = 1 })
      list.handleListInput("backspace", gs)
      assert.is_true(called)
      require("input_helpers").refreshFiles = orig_refresh
    end)
  end)
end)
