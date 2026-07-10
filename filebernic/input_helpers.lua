---@diagnostic disable: undefined-global
local M = {}
local filesystem = require "filesystem"

function M.jumpToNextLetter(global_state)
    if #global_state.files == 0 then return end
    local current = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
    for i = global_state.selectedIndex + 1, #global_state.files do
        local c = global_state.files[i].name:sub(1,1):upper()
        if c ~= current then
            global_state.selectedIndex = i
            global_state.jumpLetter = c
            return
        end
    end
    global_state.selectedIndex = #global_state.files
    global_state.jumpLetter = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
end

function M.jumpToPrevLetter(global_state)
    if #global_state.files == 0 then return end
    local current = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
    local prevLetterIdx = nil
    for i = global_state.selectedIndex - 1, 1, -1 do
        local c = global_state.files[i].name:sub(1,1):upper()
        if c ~= current then
            prevLetterIdx = i
            break
        end
    end

    if prevLetterIdx then
        local targetChar = global_state.files[prevLetterIdx].name:sub(1,1):upper()
        for i = prevLetterIdx - 1, 1, -1 do
            local c = global_state.files[i].name:sub(1,1):upper()
            if c ~= targetChar then
                global_state.selectedIndex = i + 1
                global_state.jumpLetter = targetChar
                return
            end
        end
        global_state.selectedIndex = 1
    else
        global_state.selectedIndex = 1
    end
    global_state.jumpLetter = global_state.files[global_state.selectedIndex].name:sub(1,1):upper()
end

function M.updateSystemPaths(global_state)
    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath, global_state.currentSystemIcon, global_state.currentSystemContentIcon =
        filesystem.updateSystemPaths(global_state.systemName, global_state.romPath, global_state.log, global_state.love.filesystem.getInfo, global_state.love.graphics.newImage)
end

function M.refreshFiles(global_state)
    if global_state.romPath and global_state.romPath ~= "" and global_state.romPath:sub(-1) ~= "/" then global_state.romPath = global_state.romPath .. "/" end
    global_state.romPath = filesystem.fixPathCase(global_state.romPath)
    global_state.log("Refreshing files... Path: " .. global_state.romPath)

    local function updatePathsWrapper()
         M.updateSystemPaths(global_state)
    end

    global_state.files, global_state.selectedFilesCount, global_state.selectedIndex, global_state.allFiles = filesystem.refreshFiles(updatePathsWrapper, global_state.files, global_state.selectedFilesCount, global_state.launchMode, global_state.hideEmpty, global_state.validExtensions, global_state.romPath, global_state.secondaryPath, global_state.selectedIndex, global_state.allFiles, global_state.log, global_state.favoriteRoms, global_state.hideFavorites)
    global_state.preview.load(global_state, global_state.log, global_state.loader)
end

function M.saveHistory(global_state)
    filesystem.saveHistory(global_state.playedRoms)
end

function M.saveLastPlayed(path)
    filesystem.saveLastPlayed(path)
end

function M.addToHistory(path, global_state)
    global_state.playedRoms = filesystem.addToHistory(path, global_state.playedRoms)
end

function M.deleteGameMedia(path)
    filesystem.deleteGameMedia(path)
end

function M.removeFromIndex(path, global_state)
    if global_state.romIndex then
        global_state.romIndex = filesystem.removeFromIndex(path, global_state.romIndex, global_state.json.encode, global_state.love.filesystem.getSource, io.open)
    end
end

function M.findSaveFiles(item, global_state)
    global_state.saveFiles, global_state.saveManagerSelection = filesystem.findSaveFiles(item)
end

function M.performCleanupScan(global_state)
    global_state.cleanupData.orphanedImages = {}
    global_state.cleanupData, global_state.cleanupCoroutine = filesystem.performCleanupScan(
        global_state.cleanupData,
        global_state.validExtensions,
        global_state.love.filesystem.getSource,
        io.open,
        coroutine.create,
        coroutine.yield,
        table.insert,
        table.sort
    )
    if global_state.cleanupData and not global_state.cleanupData.orphanedImages then global_state.cleanupData.orphanedImages = {} end
end

function M.filterFiles(global_state)
    global_state.files = {}
    for _, item in ipairs(global_state.allFiles) do
        if item.name:lower():find(global_state.searchQuery:lower(), 1, true) then
            table.insert(global_state.files, item)
        end
    end
    global_state.selectedIndex = 1
end

function M.startScraping(global_state)
    local item = global_state.files[global_state.selectedIndex]
    if not item then return end

    if global_state.lastScrapedRom ~= item.fullPath then
        os.execute("rm -f tmp/scraper_*.png")
        global_state.lastScrapedRom = item.fullPath
    end

    global_state.log("Starting interactive scrape for: " .. item.name)
    global_state.state = "SCRAPING_IN_PROGRESS"
    global_state.scraperResults = {}
    global_state.indexerChannelIn:push({ command = "scrape_single", item = item, config = global_state.config, systemName = global_state.systemName })
end

function M.performBatchScrape(global_state, items)
    global_state.log("Starting batch scrape for " .. #items .. " items")
    global_state.state = "BATCH_SCRAPING"
    global_state.scraperProgress = { current = 0, total = #items, currentName = "", successes = 0, failures = 0 }
    global_state.scraperCancel = false
    os.execute("rm -f tmp/scraper_*.png")
    global_state.indexerChannelIn:push({ command = "scrape_batch", items = items, config = global_state.config, systemName = global_state.systemName, romPath = global_state.romPath, muosArtPath = global_state.muosArtPath, muosTextPath = global_state.muosTextPath, muosPreviewPath = global_state.muosPreviewPath })
end

function M.saveCompositeArt(global_state)
    global_state.log("Saving composite art...")
    local frontRes = global_state.scraperResults[global_state.scraperFrontIndex]
    local screenRes = global_state.scraperResults[global_state.scraperScreenIndex]
    local textRes = global_state.scraperResults[global_state.scraperTextIndex]

    local compositeResult = {
        imagePath = frontRes and frontRes.imagePath,
        tempPath = frontRes and frontRes.tempPath,
        screenshotPath = screenRes and screenRes.screenshotPath,
        tempScreenPath = screenRes and screenRes.tempScreenPath,
        description = textRes and textRes.description,
        year = textRes and textRes.year
    }

    local item = global_state.files[global_state.selectedIndex]
    global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath = filesystem.updateSystemForFile(item, global_state.romPath, global_state.systemName, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath)
    filesystem.saveScrapeResult(item, compositeResult, global_state.muosArtPath, global_state.muosTextPath, global_state.muosPreviewPath, global_state.log)

    local baseName = item.name:gsub("%..-$", "")
    if global_state.muosArtPath and global_state.muosArtPath ~= "" then
        global_state.loader:invalidate(global_state.muosArtPath .. baseName .. ".png")
        global_state.loader:invalidate(global_state.muosTextPath .. baseName .. ".txt")
        global_state.loader:invalidate(global_state.muosTextPath .. baseName .. ".year")
        global_state.loader:invalidate(global_state.muosPreviewPath .. baseName .. ".png")
    end
    global_state.state = "LIST"
    global_state.preview.load(global_state, global_state.log, global_state.loader)
end

return M
