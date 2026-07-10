# Architecture

## Dependency graph

```
main.lua
├── utils.lua (shared utilities)
├── theme.lua (colors, fonts)
├── locale.lua (translations)
├── state.lua (config, app state)
├── fs_core.lua (security, file I/O)
├── fs_data.lua (persistence: favorites, history, collections, cache)
├── fs_scanner.lua (ROM scanning)
├── fs_gamelist.lua (gamelist.xml)
├── fs_media.lua (art/media management)
├── fs_walker.lua (recursive directory walker)
├── filesystem.lua (coordinates fs_* modules)
├── loader.lua (async asset loading)
├── preview.lua (preview loading)
├── scraper.lua (metadata scraping)
├── indexer.lua (background thread)
├── input_helpers.lua
├── input_list.lua
├── input_views.lua
├── input_menus.lua
├── input.lua (key dispatch)
├── upd_animations.lua
├── upd_scroll.lua
├── upd_messages.lua
├── update.lua (love.update orchestrator)
├── draw_helpers.lua
├── draw_bars.lua
├── draw_menus.lua
├── draw_scraper.lua
├── draw_views.lua
├── draw_list.lua
└── drawing.lua (love.draw orchestrator)
```

## Data flow

```
Input (key/gamepad) → input.lua → state handlers → global_state mutations
                                    ↓
Update loop (update.lua) → animations, I/O, messages, preview
                                    ↓
Draw loop (drawing.lua) → render global_state to screen
```

## Thread model

```
┌──────────────┐    channelIn     ┌──────────────┐
│  Main thread  │ ←───────────── │ Indexer thread│
│  (update.lua) │   scrape_cancel │ (indexer.lua) │
│               │ ──────────────→ │              │
│               │   channelOut    │              │
│               │ ←───────────── │              │
│               │   index_ready,  │              │
│               │   scrape_result,│              │
│               │   batch_done,   │              │
│               │   update_avail  │              │
└──────────────┘                 └──────────────┘

┌──────────────┐    channelIn     ┌──────────────┐
│  Main thread  │ ←───────────── │ Loader thread │
│  (draw/love)  │   file paths    │ (loader.lua)  │
│               │ ──────────────→ │              │
│               │   channelOut    │              │
│               │ ←───────────── │              │
│               │   file data     │              │
└──────────────┘                 └──────────────┘
```

## Virtual folders

Paths starting with `@` are virtual (not real filesystem paths):

| Path | Content |
|------|---------|
| `@Favorites/` | Favorite ROMs (from `favoriteRoms` table) |
| `@Recent/` | Last 20 played ROMs (from `recent.json`) |
| `@Collections/` | User-defined collections (from `collections.json`) |
| `@Collections/<name>/` | Games in a specific collection |
