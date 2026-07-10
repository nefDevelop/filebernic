std = "lua51+lua52"

ignore = {
    "611", -- línea con solo espacios en blanco
    "612", -- espacios al final de línea
    "121", -- línea muy larga (>120)
    "212", -- línea empieza con espacio
    "431", -- shadowing definition (io.open con 'local f' secuencial es intencional)
    "542", -- setting read-only field of global (love.draw etc. son intencionales)
}

globals = {
    "love", "math", "layout", "config", "L", "playedRoms", "files", "selectedIndex",
    "theme", "viewMode", "launchMode", "romPath", "isVirtualRoot", "markPlayed",
    "hideEmpty", "hideFavorites", "showHelp", "state", "fontList", "fontTitle",
    "fontMedium", "fontSmall", "fontTopBar", "fontClock", "iconReload",
    "buttonIcons", "indexerChannelIn",
}

read_globals = {
    "allFiles", "APP_VERSION",
    "animatedSelectionIndex", "animGridRow", "animGridCol",
    "cleanupCoroutine", "cleanupData", "closingHelp", "closingMenu",
    "currentDescription", "currentImage", "currentImageAlpha",
    "currentScreenshot", "currentScreenshotAlpha", "currentSystemContentIcon",
    "currentSystemIcon", "currentYear", "DEBUG", "DEBUG_SECTIONS", "delay",
    "favoriteRoms", "favAnim", "favAnimIndex", "favAnimTarget", "fastScrollTimer",
    "filesystem", "focusedItem", "fontHuge", "fontSelected",
    "forceReindex", "gridCols", "gridSelectionAnimationSpeed",
    "helpAnim", "helpData", "iconFolder", "iconGame", "iconGrid", "iconHide",
    "iconInfo", "iconFavorite", "iconKey", "iconList", "iconNetwork", "iconRom",
    "iconSaveStates", "iconTrash", "imageInvalid", "imgNoImage", "imgOff", "imgOn",
    "indexerChannelOut", "indexerThread", "indexStateMessage", "initialScrollDelay",
    "input", "inputCooldown", "isIndexing",
    "itemToDelete", "json", "jumpLetter", "jumpPanelAnim", "jumpToNextLetter",
    "jumpToPrevLetter", "keyHeld", "keyboardAnim", "keyboardCol",
    "keyboardGrid", "keyboardRow", "keyboardShift", "keyboardNum", "keyboardGridNum",
    "lastPlayedRom", "launching", "launchTimer",
    "loader", "Loader", "log",
    "markPlayed", "menuAnim", "menuMessage", "menuOptions", "menuSelection",
    "menuStack", "menuTitle", "muosArtPath", "muosPreviewPath", "muosTextPath",
    "pageSize", "pendingLoad", "preview", "previewItem",
    "refreshFiles", "romIndex",
    "saveFiles", "saveManagerSelection",
    "scraperApi", "scraperFocus", "scraperFrontIndex", "scraperProgress",
    "scraperProgressMessage", "scraperResults", "scraperScreenIndex",
    "scraperSelection", "scraperTextIndex", "scraperWarningMessage",
    "scraperWarningTimer", "scrollTimer", "searchQuery",
    "secondaryPath", "selectedFilesCount",
    "selectionAnimationSpeed", "screenshotInvalid",
    "State", "subsequentScrollDelay", "systemName",
    "textEditLabel", "textToEdit", "timer",
    "updateAvailable", "updateFileList", "updateSystemPaths", "updateUrl",
    "utils", "validExtensions",
}

exclude_files = {
    "filebernic/libs/",
    "filebernic/assets/conf.lua",
}
