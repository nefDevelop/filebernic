package.path = "./filebernic/?.lua;" .. package.path
local searchers = package.loaders or package.searchers; for i = #searchers, 1, -1 do if tostring(searchers[i]):find("luarocks") then table.remove(searchers, i) end end

describe("Update loop", function()
  local update_fn

  local function makeGS(overrides)
    local gs = {
      love = _G.love, math = math,
      inputCooldown = 0, previewItem = nil, files = {},
      menuAnim = 0, helpAnim = 0, keyboardAnim = 0,
      favAnim = 0, favAnimTarget = 0,
      animatedSelectionIndex = 1, jumpPanelAnim = 0, jumpLetter = "",
      scraperWarningTimer = 0, scraperWarningMessage = "",
      showHelp = false, closingHelp = false, closingMenu = false,
      launching = false, launchTimer = 0, state = "LIST",
      currentImage = nil, currentScreenshot = nil,
      currentYear = nil, currentDescription = "",
      currentSystemIcon = nil, currentSystemContentIcon = nil,
      menuStack = {}, cleanupData = {},
      romPath = "@test/", selectedIndex = 1,
      imageInvalid = false, screenshotInvalid = false,
      pendingLoad = false, timer = 0, delay = 0,
      fastScrollTimer = 0, keyHeld = nil,
      layout = { selectionSpeed = 10, gridSelectionSpeed = 20, menuAnimSpeed = 6, helpAnimSpeed = 6, keyboardAnimSpeed = 6, favAnimSpeed = 12, fadeAnimSpeed = 5, jumpPanelSpeed = 6 }, viewMode = "LIST",
      scrollTimer = 0, initialScrollDelay = 0.4, subsequentScrollDelay = 0.1,
      favAnimIndex = -1,
      indexerChannelOut = { push = function() end, pop = function() return nil end, peek = function() end },
      log = function() end,
      updateAvailable = nil, updateUrl = "",
    }
    if overrides then
      for k, v in pairs(overrides) do gs[k] = v end
    end
    return gs
  end

  before_each(function()
    _G.love = {
      math = { lerp = function(a, b, t) return a + (b - a) * t end },
      timer = { getTime = function() return 0 end, sleep = function() end },
      keyboard = { isDown = function() return false end },
      joystick = { getJoystickCount = function() return 0 end, getJoysticks = function() return {} end },
      graphics = { setShader = function() end },
      thread = { getChannel = function() return { push = function() end, pop = function() end, peek = function() end } end },
      filesystem = { getSource = function() return "/mock" end, getInfo = function() end },
      system = { getProcessorCount = function() return 4 end },
    }
    _G.L = { get = function(key) return key end, current = "es" }
    _G.json = { encode = function() return "{}" end, decode = function() return {} end }

    package.loaded["update"] = nil
    package.loaded["input"] = nil
    update_fn = require("update")
  end)

  it("should log lag spikes when dt > 0.05", function()
    local logged = ""
    local gs = makeGS()
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.1, gs, function(msg) logged = msg end, loader, function() end)
    assert.is_true(logged:find("Lag spike") ~= nil)
  end)

  it("should decrease inputCooldown over time", function()
    local gs = makeGS({ inputCooldown = 0.5 })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.1, gs, function() end, loader, function() end)
    assert.are.equal(0.4, gs.inputCooldown)
  end)

  it("should animate favorite star towards target", function()
    local gs = makeGS({ favAnim = 0, favAnimTarget = 1 })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.1, gs, function() end, loader, function() end)
    assert.is_true(gs.favAnim > 0)
    assert.is_true(gs.favAnim <= 1)
  end)

  it("should animate menu closing from 1 to 0", function()
    local gs = makeGS({ menuAnim = 1, closingMenu = true })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.1, gs, function() end, loader, function() end)
    assert.is_true(gs.menuAnim < 1)
    assert.is_true(gs.menuAnim >= 0)
  end)

  it("should clear preview when list is empty", function()
    local gs = makeGS({
      files = {},
      currentImage = "old_image", currentScreenshot = "old_scr",
      currentYear = "1990", currentDescription = "Old desc",
      currentSystemIcon = "old_icon", currentSystemContentIcon = "old_icon2",
    })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.01, gs, function() end, loader, function() end)
    assert.is_nil(gs.currentImage)
    assert.is_nil(gs.currentScreenshot)
    assert.is_nil(gs.currentYear)
    assert.are.equal("", gs.currentDescription)
  end)

  it("should handle scraper warning timer countdown", function()
    local gs = makeGS({ scraperWarningTimer = 0.5, scraperWarningMessage = "Test warning" })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.3, gs, function() end, loader, function() end)
    assert.are.equal(0.2, gs.scraperWarningTimer)
    assert.are.equal("Test warning", gs.scraperWarningMessage)
    update_fn(0.3, gs, function() end, loader, function() end)
    assert.are.equal("", gs.scraperWarningMessage)
  end)

  it("should process indexer channel messages", function()
    local processed = false
    local gs = makeGS({
      indexerChannelOut = {
        push = function() end,
        pop = function()
          if not processed then
            processed = true
            return { command = "index_ready", data = {} }
          end
          return nil
        end,
        peek = function() end,
      },
    })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.01, gs, function() end, loader, function(newIndex) end)
    assert.is_true(processed)
  end)

  it("should handle launching sequence timer", function()
    local gs = makeGS({ launching = true, launchTimer = 0 })
    local loader = { update = function() end, getImage = function() return nil end, getText = function() return nil end }
    update_fn(0.1, gs, function() end, loader, function() end)
    assert.is_true(gs.launchTimer > 0)
  end)
end)
