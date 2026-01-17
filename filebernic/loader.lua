-- loader.lua
-- Handles asynchronous loading of assets in a background thread to avoid
-- blocking the main thread, which is crucial for low-powered devices.

local Loader = {}

-- The thread code that runs in the background.
-- It waits for file paths from the main thread, reads them,
-- and sends the data back.
local threadCode = [[
  local channel = ...
  local lovefs = require('love.filesystem')

  while true do
    local path = channel:pop()
    if not path then
      -- Channel was closed, exit the thread.
      break
    end

    -- Try to read the file content.
    local data, err = lovefs.read(path)
    if data then
      -- Send back the path and the raw FileData object.
      channel:push({ path = path, data = lovefs.newFileData(data, path) })
    else
      -- If there's an error (e.g., file not found), send an error message.
      channel:push({ path = path, error = err or "Could not read file" })
    end
  end
]]

function Loader:new()
  log("Loader:new called")
  local obj = {
    -- In-memory cache for loaded assets.
    -- cache[path] = 'loading' | 'error' | love.FileData | love.Image | string
    cache = {},
    -- Communication channel with the background thread.
    channel = love.thread.newChannel(),
    -- The background thread instance.
    thread = love.thread.newThread(threadCode)
  }
  obj.thread:start(obj.channel)
  setmetatable(obj, self)
  self.__index = self
  return obj
end

-- Called in love.update() to process results from the background thread.
function Loader:update()
  log("Loader:update called")
  while true do
    local msg = self.channel:pop()
    if not msg then break end

    if msg.data then
      -- File was loaded successfully. Store the raw FileData.
      -- Decoding happens in the specific getter (getImage, getText).
      self.cache[msg.path] = msg.data
    elseif msg.error then
      -- An error occurred while loading.
      self.cache[msg.path] = 'error'
    end
  end
end

-- Requests a file to be loaded.
function Loader:request(path)
  log("Loader:request called with path: " .. tostring(path))
  if not path or path == "" or self.cache[path] then
    -- Don't request if it's nil, already cached, or already being loaded.
    return
  end
  -- Mark as 'loading' to prevent duplicate requests.
  self.cache[path] = 'loading'
  -- Push the path to the background thread's queue.
  self.channel:push(path)
end

-- Returns a love.Image object if it's ready.
function Loader:getImage(path)
  log("Loader:getImage called with path: " .. tostring(path))
  if not path or path == "" then return nil end
  local data = self.cache[path]

  if not data then
    self:request(path)
    return nil
  end

  if type(data) == 'userdata' and data:typeOf('Image') then
    return data -- Already a decoded, cached image.
  elseif type(data) == 'userdata' and data:typeOf('FileData') then
    -- The FileData is ready. Try to decode it as an Image.
    local success, imageData = pcall(love.image.newImageData, data)
    if success then
      local imgSuccess, image = pcall(love.graphics.newImage, imageData)
      if imgSuccess then
        self.cache[path] = image -- Cache the final drawable image.
        return image
      end
    end
    -- If any part of the decoding fails, mark as an error.
    self.cache[path] = 'error'
    return nil
  end
  -- Return nil if it's still loading ('loading'), an error, or not convertible.
  return nil
end

-- Returns a string object if it's ready.
function Loader:getText(path)
  log("Loader:getText called with path: " .. tostring(path))
  if not path or path == "" then return nil end
  local data = self.cache[path]

  if not data then
    self:request(path)
    return nil
  end

  if type(data) == 'string' then
    return data -- Already a decoded, cached string.
  elseif type(data) == 'userdata' and data:typeOf('FileData') then
    -- The FileData is ready. Decode it as a string.
    local content = data:getString()
    self.cache[path] = content -- Cache the final string.
    return content
  end
  -- Return nil if it's still loading, an error, or not convertible.
  return nil
end


-- Clears the asset cache.
function Loader:clearCache()
  log("Loader:clearCache called")
  self.cache = {}
end

-- Safely shuts down the thread.
function Loader:quit()
  log("Loader:quit called")
  -- Push nil to the channel to signal the thread to exit its loop.
  self.channel:push(nil)
end

return Loader
