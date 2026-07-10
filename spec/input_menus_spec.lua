package.path = "./filebernic/?.lua;" .. package.path
local searchers = package.loaders or package.searchers; for i = #searchers, 1, -1 do if tostring(searchers[i]):find("luarocks") then table.remove(searchers, i) end end

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
_G.L = { get = function(key, ...)
  local map = {
    move_to = "Mover a ",
    copy_to = "Copiar a ",
    save_games = "save_games",
    add_favorite = "add_favorite",
    remove_favorite = "remove_favorite",
    delete = "delete",
    cancel = "cancel",
    mode = "mode",
    view = "view",
    hide_empty = "hide_empty",
    mark_played = "mark_played",
    hide_favorites = "hide_favorites",
    scraper = "scraper",
    info = "info",
    cleanup = "cleanup",
    api_settings = "api_settings",
    scraper_api = "scraper_api",
    api_key = "api_key",
    ss_user = "ss_user",
    ss_password = "ss_password",
    reindex = "reindex",
    update_now = "update_now",
    select_system = "select_system",
    version = "version",
    config = "config",
    options = "options:",
    delete_sd1 = "delete_sd1",
    delete_sd2 = "delete_sd2",
  }
  return map[key] or key
end, current = "es" }
_G.json = { encode = function() return "{}" end, decode = function() return {} end }

local menus = require("input_menus")
local filesystem = require("filesystem")

local function makeGS(overrides)
  local gs = {
    love = _G.love, math = math,
    state = "OPTIONS_MENU",
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
    validExtensions = { nes = true },
    playedRoms = {},
    favoriteRoms = {},
    saveFiles = {},
    cleanupData = { orphans = {}, duplicates = {}, orphanedImages = {}, scanned = false, scanning = false, confirming = false, progress = 0, cursor = { col = 1, row = 1 } },
    menuAnim = 0,
    menuOptions = {},
    menuSelection = 1,
    menuTitle = "",
    menuMessage = "",
    menuStack = {},
    focusedItem = nil,
    itemToDelete = nil,
    itemToLaunch = nil,
    iconFavorite = {}, iconFolder = {}, iconRom = {},
    iconInfo = {}, iconNetwork = {}, iconSaveStates = {}, iconTrash = {},
    iconHide = {}, iconReload = {}, iconGame = {},
    json = _G.json,
    indexerChannelIn = { push = function() end },
    loader = { invalidate = function() end },
    preview = { load = function() end },
    config = { scraperApi = "all", thegamesdb_apikey = "" },
    L = _G.L,
    log = function() end,
    love = _G.love,
  }
  if overrides then
    for k, v in pairs(overrides) do gs[k] = v end
  end
  return gs
end

describe("DELETE_MENU", function()
  it("confirming deletes a single item and refreshes", function()
    local deleted_path = ""
    local orig_safeRemove = filesystem.safeRemove
    filesystem.safeRemove = function(path) deleted_path = path; return true end
    filesystem.logDeletion = function() end

    local gs = makeGS({ menuOptions = { "delete", "cancel" }, menuSelection = 1, itemToDelete = { fullPath = "/mnt/mmc/ROMS/nes/game.nes", name = "game.nes" } })
    menus.DELETE_MENU("return", gs)
    assert.are.equal("/mnt/mmc/ROMS/nes/game.nes", deleted_path)
    assert.are.equal("LIST", gs.state)

    filesystem.safeRemove = orig_safeRemove
  end)

  it("canceling clears item and triggers closing", function()
    local gs = makeGS({ menuOptions = { "delete", "cancel" }, menuSelection = 2, itemToDelete = { name = "game.nes" } })
    menus.DELETE_MENU("backspace", gs)
    assert.is_nil(gs.itemToDelete)
    assert.is_true(gs.closingMenu)
  end)

  it("deletes multiple selected files", function()
    local deleted = {}
    local orig_safeRemove = filesystem.safeRemove
    filesystem.safeRemove = function(path) table.insert(deleted, path); return true end
    filesystem.logDeletion = function() end

    local gs = makeGS({
      menuOptions = { "delete", "cancel" }, menuSelection = 1,
      selectedFilesCount = 2,
      files = {
        { name = "a.nes", fullPath = "/roms/a.nes", selected = true },
        { name = "b.nes", fullPath = "/roms/b.nes", selected = true },
      },
    })
    menus.DELETE_MENU("return", gs)
    assert.are.equal(2, #deleted)
    assert.are.equal("/roms/a.nes", deleted[1])
    assert.are.equal("/roms/b.nes", deleted[2])
    assert.are.equal("LIST", gs.state)

    filesystem.safeRemove = orig_safeRemove
  end)
end)

describe("OPTIONS_MENU", function()
  it("opens edit text for thegamesdb api key", function()
    local gs = makeGS({ menuOptions = { "api_key: Empty" }, menuSelection = 1, menuTitle = "api_settings" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("EDIT_TEXT", gs.state)
    assert.are.equal("api_key", gs.textEditLabel)
    assert.are.equal("thegamesdb_apikey", gs.textEditKey)
  end)

  it("toggles hide_empty setting", function()
    local gs = makeGS({ menuOptions = { "hide_empty: off" }, menuSelection = 1, menuTitle = "config", hideEmpty = false })
    menus.OPTIONS_MENU("return", gs)
    assert.is_true(gs.hideEmpty)
  end)

  it("toggles mark_played setting", function()
    local gs = makeGS({ menuOptions = { "mark_played: yes" }, menuSelection = 1, menuTitle = "config", markPlayed = true })
    menus.OPTIONS_MENU("return", gs)
    assert.is_false(gs.markPlayed)
  end)

  it("toggles view mode", function()
    local gs = makeGS({ menuOptions = { "view: LIST" }, menuSelection = 1, menuTitle = "config", viewMode = "LIST" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("GRID", gs.viewMode)
  end)

  it("switches launch mode", function()
    local gs = makeGS({ menuOptions = { "mode: Folder" }, menuSelection = 1, menuTitle = "config", launchMode = "Folder" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("Juego Unico", gs.launchMode)
  end)

  it("opens cleanup menu", function()
    local gs = makeGS({ menuOptions = { "cleanup" }, menuSelection = 1, menuTitle = "config" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("CLEANUP_MENU", gs.state)
  end)

  it("opens scraper view", function()
    local gs = makeGS({ menuOptions = { "scraper" }, menuSelection = 1, menuTitle = "options:", files = { { name = "game.nes" } } })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("SCRAPER_VIEW", gs.state)
  end)

  it("discards scraper if multiple files selected", function()
    local orig_fs = filesystem.saveFavorites
    filesystem.saveFavorites = function() end
    local gs = makeGS({ menuOptions = { "scraper" }, menuSelection = 1, selectedFilesCount = 2, files = { { name = "a.nes", selected = true }, { name = "b.nes", selected = true } }, menuTitle = "config" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("BATCH_SCRAPING", gs.state)
    filesystem.saveFavorites = orig_fs
  end)

  it("opens info view", function()
    local gs = makeGS({ menuOptions = { "info" }, menuSelection = 1, menuTitle = "config" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("INFO_VIEW", gs.state)
  end)

  it("opens delete confirmation for single item", function()
    local gs = makeGS({ menuOptions = { "delete" }, menuSelection = 1, menuTitle = "config", files = { { name = "game.nes" } } })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("DELETE_MENU", gs.state)
  end)

  it("opens save manager", function()
    local gs = makeGS({ menuOptions = { "save_games (3)" }, menuSelection = 1, menuTitle = "config" })
    menus.OPTIONS_MENU("return", gs)
    assert.are.equal("SAVE_MANAGER", gs.state)
  end)

  it("closes menu on backspace", function()
    local gs = makeGS({ menuTitle = "config" })
    menus.OPTIONS_MENU("backspace", gs)
    assert.is_true(gs.closingMenu)
  end)

  it("pops submenu on backspace when menuStack has items", function()
    local gs = makeGS({ menuStack = { { title = "parent" } }, menuTitle = "child" })
    menus.OPTIONS_MENU("backspace", gs)
    assert.is_true(gs.closingMenu)
  end)
end)

describe("POST_GAME", function()
  it("confirming clears last played and returns to list", function()
    local orig_safeRemove = filesystem.safeRemove
    filesystem.safeRemove = function() end
    local gs = makeGS({ lastPlayedRom = "/tmp/launch_rom" })
    menus.POST_GAME("return", gs)
    assert.are.equal("LIST", gs.state)
    filesystem.safeRemove = orig_safeRemove
  end)

  it("canceling returns to list", function()
    local gs = makeGS()
    menus.POST_GAME("backspace", gs)
    assert.are.equal("LIST", gs.state)
  end)
end)

describe("CLEANUP_MENU", function()
  it("starts scan on enter", function()
    local gs = makeGS({ cleanupData = { scanned = false, scanning = false, orphans = {}, duplicates = {}, orphanedImages = {}, cursor = { col = 1, row = 1 } } })
    menus.CLEANUP_MENU("return", gs)
    assert.is_true(gs.cleanupData.scanning)
  end)

  it("backspace returns to list", function()
    local gs = makeGS({ cleanupData = { scanned = true, orphans = {}, duplicates = {}, orphanedImages = {}, cursor = { col = 1, row = 1 } } })
    menus.CLEANUP_MENU("backspace", gs)
    assert.are.equal("LIST", gs.state)
  end)
end)
