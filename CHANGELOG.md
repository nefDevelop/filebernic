# Changelog

## [Unreleased]

### Refactor
- **`drawing.lua`** dividido en 6 módulos especializados:
  - `draw_helpers.lua` — shaders, meshes, utilidades de dibujo (283 líneas)
  - `draw_bars.lua` — barra superior e inferior (80 líneas)
  - `draw_menus.lua` — menús laterales, info, ayuda (572 líneas)
  - `draw_scraper.lua` — vista del scraper (312 líneas)
  - `draw_views.lua` — gestor de partidas, limpieza, vista cuadrícula (527 líneas)
  - `draw_list.lua` — lista principal de juegos (348 líneas)
  - `drawing.lua` reducido de 2503 → 244 líneas (orquestador)

- **`input.lua`** dividido en 4 módulos especializados:
  - `input_helpers.lua` — funciones auxiliares (171 líneas)
  - `input_menus.lua` — menú de opciones, borrado, limpieza (616 líneas)
  - `input_views.lua` — búsqueda, scraper, info, editor texto (279 líneas)
  - `input_list.lua` — navegación y lanzamiento de juegos (327 líneas)
  - `input.lua` reducido de 1581 → 160 líneas (despachador)

### Corrección de bugs
- **`main.lua:538`** — `io.popen` sin nil-check podía crashear al detectar SD
- **`filesystem.lua:1063`** — resource leak: handle `io.popen` abierto pero nunca cerrado
- **`filesystem.lua:1395`** — `logEntry` era una variable indefinida (crash al loguear ROMs borradas)
- **`scraper.lua:260-272`** — `tempScreenPath` declarado dentro de bloque incorrecto (scope bug)
- **`input.lua:136`** — `performBatchScrape` no recibía `global_state` como parámetro

### Estilo y consistencia
- Migradas todas las referencias a bare globals en `input.lua` (`preview.load`, `selectedFilesCount`, `files`, `selectedIndex`) a `global_state.xxx`
- Migrada referencia `showHelp` en `update.lua` a `global_state.showHelp`
- Eliminados archivos duplicados `input.lua` y `update.lua` de la raíz del proyecto

### Manejo de errores
- Agregado nil-check en `io.popen` de `main.lua:538`
- Agregado `2>/dev/null` a todos los comandos curl (scraper + utils)
- Agregado logging en fallos de `mkdir -p` en `filesystem.lua`, `input.lua`, `main.lua`

### Linter
- Agregado `.luacheckrc` con configuración para Lua 5.1/5.2 y LÖVE
- Agregado paso `luacheck` en CI (`.github/workflows/release.yml`)
- Corregidos 56+ warnings reales (variables sin usar, shadowing, bugs)
- 0 warnings en los 7 archivos nuevos de dibujo y 5 archivos nuevos de input

### Tests
- **`spec/fs_core_spec.lua`** — 14 tests: isSafePath (11 casos), safeRemove, copyFile, moveFile
- **`spec/fs_data_spec.lua`** — 10 tests: favoritos, historial, pending, logDeletion, view cache
- **`spec/input_helpers_spec.lua`** — 12 tests: jumpToNextLetter, jumpToPrevLetter, filterFiles, etc.
- **`spec/update_spec.lua`** — 8 tests: lag spike, cooldown, animaciones, indexer messages, scraper timer
- **Total: 120 tests** (76 legacy + 44 nuevos)

### Archivos eliminados
- `input.lua` (raíz) — copia antigua duplicada
- `update.lua` (raíz) — copia antigua duplicada
