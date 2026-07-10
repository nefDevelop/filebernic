# filebernic — Documentación

## Overview

filebernic es un gestor de ROMs para dispositivos muOS (Anbernic RG28XX, RG40XX, etc.). Corre sobre LÖVE (Love2D) 11.x.

## Project structure

```
filebernic/
├── main.lua            # Entry point: love.load(), love.quit()
├── input.lua           # Key dispatch (keypressed, gamepadpressed)
├── input_helpers.lua   # Helpers: jumpToLetter, refreshFiles, filterFiles
├── input_menus.lua     # OPTIONS_MENU, DELETE_MENU, CLEANUP_MENU handlers
├── input_views.lua     # SEARCH, EDIT_TEXT, SCRAPER_*, SAVE_MANAGER handlers
├── input_list.lua      # handleListInput (navigation, launch)
├── drawing.lua         # Main draw() orchestrator
├── draw_helpers.lua    # Shaders, meshes, trimming, scrollbar, battery
├── draw_bars.lua       # Top bar + bottom bar
├── draw_menus.lua      # Menu/info/help panel rendering
├── draw_scraper.lua    # Scraper UI rendering
├── draw_views.lua      # Save manager, cleanup, grid rendering
├── draw_list.lua       # Main list rendering
├── update.lua          # love.update() orchestrator
├── upd_animations.lua  # Animation interpolation
├── upd_scroll.lua      # Scroll repeat + move dispatch
├── upd_messages.lua    # Indexer channel message processing
├── filesystem.lua      # Filesystem operations
├── fs_core.lua         # isSafePath, safeRemove, copyFile, moveFile
├── fs_data.lua         # Favorites, history, cache, collections
├── fs_scanner.lua      # getArtPathForSystem, hasRoms
├── fs_gamelist.lua     # gamelist.xml parsing
├── fs_media.lua        # Art/media management
├── fs_walker.lua       # Recursive directory walker
├── scraper.lua         # Metadata scraping (TGDB, Libretro, ScreenScraper)
├── loader.lua          # Async asset loader (background thread + LRU cache)
├── preview.lua         # Preview loading (boxart, screenshot, text)
├── state.lua           # App state save/load, config management
├── theme.lua           # Color themes and fonts
├── locale.lua          # Translations (es/en)
├── utils.lua           # Utility functions
├── indexer.lua         # Background indexer thread
├── mux_launch.sh       # muOS launch script
└── data/               # Runtime data (gitignored)
```

## State machine

The app uses a single `global_state` table (which is `_G`). The `state` field controls which view is active:

- `LIST` — Main file list
- `SEARCH` — Search keyboard
- `EDIT_TEXT` — Text editing (API keys, collection names)
- `OPTIONS_MENU` — Options/config menu
- `DELETE_MENU` — Delete confirmation
- `INFO_VIEW` — Game info panel
- `SCRAPER_VIEW` — Scraper view
- `SCRAPING_IN_PROGRESS` — Scraping indicator
- `BATCH_SCRAPING` — Batch scrape progress
- `SCRAPER_RESULTS` — Scraper results
- `SCRAPER_OPTIONS` — Scraper API options
- `SAVE_MANAGER` — Save file management
- `CLEANUP_MENU` — Cleanup menu
- `POST_GAME` — Post-launch screen

## Threading

- **Main thread**: UI, input, rendering
- **Loader thread** (`loader.lua`): Async file reading via LÖVE thread
- **Indexer thread** (`indexer.lua`): ROM scanning, OTA checks, scraping

Communication uses `love.thread.getChannel()`.
