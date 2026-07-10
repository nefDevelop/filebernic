package.path = "./filebernic/?.lua;" .. package.path

-- Mock love global before requiring theme, as it uses love.filesystem at top level
_G.love = {
  filesystem = { getInfo = function() return nil end },
  graphics = { newFont = function() return {} end }
}

describe("Theme", function()
  local mock_love_fs = {}
  local mock_love_gfx = {}

  local original_love_fs_getInfo = love.filesystem.getInfo
  local original_love_gfx_newFont = love.graphics.newFont

  before_each(function()
    -- Reset mocks
    mock_love_fs.info = nil
    mock_love_gfx.font_calls = {}

    -- Mock dependencies
    love.filesystem.getInfo = function(path) return mock_love_fs.info end
    love.graphics.newFont = function(path_or_size, size)
      table.insert(mock_love_gfx.font_calls, { path = path_or_size, size = size })
      return "mock_font"
    end
  end)

  after_each(function()
    -- Restore
    love.filesystem.getInfo = original_love_fs_getInfo
    love.graphics.newFont = original_love_gfx_newFont
    -- Unload the theme module so it can be re-loaded for the next test
    package.loaded["filebernic.theme"] = nil
  end)

  it("should load custom font when file exists", function()
    mock_love_fs.info = { type = "file" } -- Simulate font file exists
    
    local theme = require("filebernic.theme")

    assert.are.equal(5, #mock_love_gfx.font_calls) -- huge, list, medium, small, title
    for _, call in ipairs(mock_love_gfx.font_calls) do
      assert.are.equal("assets/fonts/JetBrainsMono-Regular.ttf", call.path)
    end
  end)

  it("should fall back to default font when file does not exist", function()
    mock_love_fs.info = nil -- Simulate font file does not exist
    
    local theme = require("filebernic.theme")

    assert.are.equal(5, #mock_love_gfx.font_calls)
    for _, call in ipairs(mock_love_gfx.font_calls) do
      -- The path should be a number (the size), and the size argument should be nil
      assert.are.equal("number", type(call.path))
      assert.is_nil(call.size)
    end
  end)

  it("should contain all required color definitions", function()
    mock_love_fs.info = nil
    local theme = require("filebernic.theme")
    local colors = theme.colors
    assert.is_not_nil(colors.background)
    assert.is_not_nil(colors.text_bright)
    assert.is_not_nil(colors.list_selection)
    assert.is_not_nil(colors.selection_accent)
    assert.is_not_nil(colors.scrollbar_handle)
  end)
end)
