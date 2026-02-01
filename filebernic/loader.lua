---@diagnostic disable: undefined-global
---@diagnostic disable: undefined-field

-- loader.lua
-- Handles asynchronous loading of assets in a background thread to avoid
-- blocking the main thread, which is crucial for low-powered devices.

local Loader = {}

-- The thread code that runs in the background.
-- It waits for file paths from the main thread, reads them,
-- and sends the data back.
local threadCode = [[
  local channelIn, channelOut = ...
  local lovefs = require('love.filesystem')
  require('love.image') -- Asegurar que el módulo de imagen está cargado
  require('love.data')  -- Asegurar que el módulo de datos está cargado

  while true do
    local path = channelIn:demand()
    if path == "quit" then
      -- Received quit signal, exit the thread.
      break
    end

    -- Try to read the file content using io.open (bypasses love.filesystem sandbox)
    local f = io.open(path, "rb")
    if f then
        local data = f:read("*a")
        f:close()
        -- Send back the path and the raw FileData object.
        channelOut:push({ path = path, data = lovefs.newFileData(data, path) })
    else
        channelOut:push({ path = path, error = "File not found or unreadable" })
    end
  end
]]

function Loader:new(logger)
  local obj = {
    -- In-memory cache for loaded assets.
    -- cache[path] = 'loading' | 'error' | love.FileData | love.Image | string
    cache = {},
    -- Communication channel with the background thread.
    channelIn = love.thread.newChannel(),
    channelOut = love.thread.newChannel(),
    -- The background thread instance.
    thread = love.thread.newThread(threadCode),
    logger = logger
  }
  obj.thread:start(obj.channelIn, obj.channelOut)
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Loader:log(msg)
    if self.logger then self.logger("[LOADER] " .. msg) end
end

-- Called in love.update() to process results from the background thread.
function Loader:update()
  while true do
    local msg = self.channelOut:pop()
    if not msg then break end

    if msg.data then
      self:log("Loaded successfully: " .. msg.path)
      -- File was loaded successfully. Store the raw FileData.
      -- Decoding happens in the specific getter (getImage, getText).
      self.cache[msg.path] = msg.data
    elseif msg.error then
      self:log("Error loading " .. msg.path .. ": " .. tostring(msg.error))
      -- An error occurred while loading.
      self.cache[msg.path] = 'error'
    end
  end
end

-- Requests a file to be loaded.
function Loader:request(path)
  if not path or path == "" or self.cache[path] then
    -- if self.cache[path] then self:log("Request ignored (cached/loading): " .. path) end
    -- Don't request if it's nil, already cached, or already being loaded.
    return
  end
  -- Mark as 'loading' to prevent duplicate requests.
  self:log("Requesting: " .. path)
  self.cache[path] = 'loading'
  -- Push the path to the background thread's queue.
  self.channelIn:push(path)
end

-- Invalidates a specific path in the cache.
function Loader:invalidate(path)
  if path and self.cache[path] then
    self:log("Invalidating cache for: " .. path)
    self.cache[path] = nil
  else
    self:log("Invalidate skipped (not in cache): " .. tostring(path))
  end
end

-- Returns a love.Image object if it's ready.
function Loader:getImage(path)
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
      self:log("Error creating image from data: " .. path)
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
  self.cache = {}
end

-- Safely shuts down the thread.
function Loader:quit()
  -- Push "quit" to the channel to signal the thread to exit its loop.
  self.channelIn:push("quit")
end

return Loader
