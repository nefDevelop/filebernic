package.path = "./filebernic/?.lua;" .. package.path
for i = #package.searchers, 1, -1 do if tostring(package.searchers[i]):find("luarocks") then table.remove(package.searchers, i) end end

describe("Loader", function()
  local Loader = require("filebernic.loader")
  local loader

  -- Mock Love2D modules and functions
  local love_mocks = {
    thread = {
      newChannel = function()
        return {
          push = function(self, val) self.value = val end,
          pop = function(self) local v = self.value; self.value = nil; return v end,
          demand = function(self) return self.value end,
          clear = function(self) self.value = nil end
        }
      end,
      newThread = function()
        return {
          start = function() end
        }
      end
    },
    filesystem = {
      newFileData = function(data, name)
        return {
          typeOf = function(self, t) return t == "FileData" end,
          getString = function() return data end,
          __data = data,
          __name = name
        }
      end
    },
    image = {
      newImageData = function(fileData)
        if fileData.__name == "error.png" then
          error("mock image error")
        end
        return {
          typeOf = function(self, t) return t == "ImageData" end,
          __data = fileData.__data
        }
      end
    },
    graphics = {
      newImage = function(imageData)
         if imageData.__data == "error_data" then
          error("mock graphics error")
        end
        return {
          typeOf = function(self, t) return t == "Image" end,
           __data = imageData.__data
        }
      end
    }
  }

  -- Global mocks for Love2D
  _G.love = love_mocks

  before_each(function()
    -- Create a new loader instance before each test
    loader = Loader:new(function() end, love_mocks) -- Mock logger
  end)

  it("should be created with an empty cache", function()
    assert.are.same({}, loader.cache)
  end)

  it("should request a file and set cache to 'loading'", function()
    loader:request("test.txt")
    assert.are.equal("loading", loader.cache["test.txt"])
  end)

  it("should not request a file that is already cached", function()
    loader.cache["test.txt"] = "some data"
    loader:request("test.txt")
    -- The channel should be empty
    assert.is_nil(loader.channelIn:pop())
  end)

  it("should update cache with loaded data", function()
    loader:request("test.txt")
    -- The thread sends raw string data, not FileData objects
    loader.channelOut:push({path = "test.txt", data = "file content"})
    loader:update()
    assert.are.equal("file content", loader.cache["test.txt"].__data) -- Check the content of the FileData object
  end)

  it("should handle loading errors", function()
    loader:request("error.txt")
    loader.channelOut:push({path = "error.txt", error = "File not found"})
    loader:update()
    assert.are.equal("error", loader.cache["error.txt"])
  end)

  it("should invalidate a cached path", function()
    loader.cache["test.txt"] = "some data"
    loader:invalidate("test.txt")
    assert.is_nil(loader.cache["test.txt"])
  end)

  it("should get text from a loaded file", function()
    local fileData = love_mocks.filesystem.newFileData("file content", "test.txt")
    loader.cache["test.txt"] = fileData
    local text = loader:getText("test.txt")
    assert.are.equal("file content", text)
    -- Check that the cache is updated with the decoded string
    assert.are.equal("file content", loader.cache["test.txt"])
  end)

  it("should return nil for text that is not loaded", function()
    local text = loader:getText("nonexistent.txt")
    assert.is_nil(text)
    -- And it should have requested the file
    assert.are.equal("loading", loader.cache["nonexistent.txt"])
  end)

  it("should get an image from a loaded file", function()
    local fileData = love_mocks.filesystem.newFileData("image data", "test.png")
    loader.cache["test.png"] = fileData
    local image = loader:getImage("test.png")
    assert.is_not_nil(image)
    assert.is_true(image:typeOf("Image"))
    -- Check that the cache is updated with the decoded image
    assert.is_true(loader.cache["test.png"]:typeOf("Image"))
  end)

  it("should handle image decoding errors", function()
    local fileData = love_mocks.filesystem.newFileData("bad image data", "error.png")
    loader.cache["error.png"] = fileData
    local image = loader:getImage("error.png")
    assert.is_nil(image)
    assert.are.equal("error", loader.cache["error.png"])
  end)
  
  it("should handle image creation errors from graphics", function()
    local fileData = love_mocks.filesystem.newFileData("error_data", "graphics_error.png")
    loader.cache["graphics_error.png"] = fileData
    local image = loader:getImage("graphics_error.png")
    assert.is_nil(image)
    assert.are.equal('error', loader.cache["graphics_error.png"])
  end)

  it("should send 'quit' message to the thread", function()
    loader:quit()
    assert.are.equal("quit", loader.channelIn:demand())
  end)
end)
