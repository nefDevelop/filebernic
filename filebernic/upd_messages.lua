---@diagnostic disable: undefined-global
local M = {}

function M.processMessages(gs, log_func, updateFileList_func)
    if not gs.indexerChannelOut then return end

    while true do
        local msg = gs.indexerChannelOut:pop()
        if not msg then break end

        if msg.type == "progress" then
            gs.indexStateMessage = msg.message
        elseif msg.type == "done" then
            log_func("Indexing finished successfully.")
            updateFileList_func(msg.index)
            gs.isIndexing = false
            gs.indexStateMessage = ""
        elseif msg.type == "log" then
            log_func(msg.message)
        elseif msg.type == "scrape_result" then
            M.loadScrapeResults(gs, msg, log_func)
        elseif msg.type == "batch_progress" then
            gs.scraperProgress.current = msg.current
            gs.scraperProgress.total = msg.total
            gs.scraperProgress.currentName = msg.currentName
            gs.scraperProgress.successes = msg.successes
            gs.scraperProgress.failures = msg.failures
        elseif msg.type == "scraper_warning" then
            gs.scraperWarningMessage = msg.message
            gs.scraperWarningTimer = 3
            log_func("Scraper Warning: " .. msg.message)
        elseif msg.type == "scraper_progress" then
            gs.scraperProgressMessage = msg.message
            log_func("Scraper Progress: " .. msg.message)
        elseif msg.type == "batch_done" then
            local summary = msg.cancelled and "Batch scraping cancelled." or ("Batch scraping finished. OK: " .. msg.successes .. " / Fail: " .. msg.failures)
            log_func(summary)
            gs.scraperCancel = false
            gs.state = "LIST"
            gs.refreshFiles()
        elseif msg.type == "update_available" then
            gs.updateAvailable = { version = msg.version, url = msg.url }
            log_func("OTA Update found in background: " .. msg.version)
            if gs.state == "LIST" then
                gs.updateUrl = msg.url
                gs.state = "OPTIONS_MENU"
                gs.menuTitle = gs.L.get("update_available")
                gs.menuMessage = gs.L.get("update_msg", msg.version)
                gs.menuOptions = {gs.L.get("update_now"), gs.L.get("cancel")}
                gs.menuSelection = 1
                gs.menuAnim = 0
                gs.menuStack = {}
            end
        end
    end
end

function M.loadScrapeResults(gs, msg, log_func)
    gs.scraperResults = msg.results
    for _, res in ipairs(gs.scraperResults) do
        if res.imagePath then
            local f = io.open(res.imagePath, "rb")
            if f then
                local data = f:read("*a")
                f:close()
                if data then
                    local success, img = pcall(gs.love.graphics.newImage,
                                               gs.love.filesystem.newFileData(data, res.imagePath))
                    if success then res.image = img
                    else log_func("Error creating LÖVE image from " .. res.imagePath .. ": " .. tostring(img)) end
                end
            end
        end
        if res.screenshotPath then
            local f = io.open(res.screenshotPath, "rb")
            if f then
                local data = f:read("*a")
                f:close()
                if data then
                    local success, img = pcall(gs.love.graphics.newImage,
                                               gs.love.filesystem.newFileData(data, res.screenshotPath))
                    if success then res.screenshot = img
                    else log_func("Error creating LÖVE screenshot from " .. res.screenshotPath .. ": " .. tostring(img)) end
                end
            end
        end
    end
    gs.scraperSelection = 1
    gs.scraperFrontIndex = 1
    gs.scraperScreenIndex = 1
    gs.scraperTextIndex = 1
    gs.scraperFocus = "FRONT"
    gs.state = "SCRAPER_RESULTS"
end

return M
