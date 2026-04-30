---@diagnostic disable: undefined-global
-- loader.lua
-- Handles asynchronous loading of assets in a background thread to avoid
-- blocking the main thread, which is crucial for low-powered devices.

local Loader = {}

-- The thread code that runs in the background.
-- It waits for file paths from the main thread, reads them,
-- and sends the data back.
local threadCode = [[ -- This is a string, not a function
  local channelIn, channelOut = ...

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
        channelOut:push({ path = path, data = data }) -- Send raw data (string)
    else
        channelOut:push({ path = path, error = "File not found or unreadable" })
    end
  end
]] -- End of string

function Loader:new(logger, love_modules)
  local obj = {
    -- In-memory cache for loaded assets.
    -- cache[path] = 'loading' | 'error' | love.FileData | love.Image | string
    cache = {},
    accessOrder = {}, -- Fila LRU para evitar llenar la RAM
    maxCacheSize = 60, -- Máximo de assets simultáneos en memoria
    -- Communication channel with the background thread.
    channelIn = love_modules.thread.newChannel(),
    channelOut = love_modules.thread.newChannel(),
    -- The background thread instance.
    thread = love_modules.thread.newThread(threadCode),
    logger = logger,
    love_modules = love_modules
  }
  obj.thread:start(obj.channelIn, obj.channelOut) -- No third argument needed
  setmetatable(obj, self)
  self.__index = self
  return obj
end

function Loader:log(msg)
    if self.logger then self.logger("[LOADER] " .. msg) end
end

function Loader:markUsed(path)
  if self.accessOrder[1] == path then return end
  for i, p in ipairs(self.accessOrder) do
    if p == path then
      table.remove(self.accessOrder, i)
      break
    end
  end
  table.insert(self.accessOrder, 1, path)
  
  while #self.accessOrder > self.maxCacheSize do
     local oldest = table.remove(self.accessOrder)
     if self.cache[oldest] ~= 'loading' then
        self.cache[oldest] = nil
     else
        table.insert(self.accessOrder, oldest)
        break
     end
  end
end

-- Called in love.update() to process results from the background thread.
function Loader:update()
  while true do
    local msg = self.channelOut:pop()
    if not msg then break end

    if msg.data then
      self:log("File content received: " .. msg.path)
      -- File content received. Create FileData object in the main thread.
      -- The love.filesystem.newFileData call must happen on the main thread.
      self.cache[msg.path] = self.love_modules.filesystem.newFileData(msg.data, msg.path)
      self:markUsed(msg.path)
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
    if type(self.cache[path]) == "userdata" and self.cache[path].release then
        pcall(self.cache[path].release, self.cache[path])
    end
    for i, p in ipairs(self.accessOrder) do
        if p == path then
            table.remove(self.accessOrder, i)
            break
        end
    end
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

  if (type(data) == 'userdata' or type(data) == 'table') and data.typeOf and data:typeOf('Image') then
    self:markUsed(path)
    return data -- Already a decoded, cached image.
  elseif (type(data) == 'userdata' or type(data) == 'table') and data.typeOf and data:typeOf('FileData') then
    -- The FileData is ready. Try to decode it as an Image.
    local success, imageData = pcall(self.love_modules.image.newImageData, data)
    if success then
      local imgSuccess, image = pcall(self.love_modules.graphics.newImage, imageData)
      if imgSuccess then
        self.cache[path] = image -- Cache the final drawable image.
        self:markUsed(path)
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

  if data == 'error' then
    return nil
  end

  if type(data) == 'string' then
    self:markUsed(path)
    return data -- Already a decoded, cached string.
  elseif (type(data) == 'userdata' or type(data) == 'table') and data.typeOf and data:typeOf('FileData') then
    -- The FileData is ready. Decode it as a string.
    local content = data:getString()
    self.cache[path] = content -- Cache the final string.
    self:markUsed(path)
    return content
  end
  -- Return nil if it's still loading or not convertible.
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
