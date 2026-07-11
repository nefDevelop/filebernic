# Roadmap — filebernic v0.2

> Hoja de ruta hacia la versión 0.2 con mejoras de rendimiento, nuevas funcionalidades y calidad de vida.
> ✅ = Completado

---

## Fase 1: Rendimiento ✅

### ✓ 1.1 Walker Lua recursivo
Reemplazar `io.popen('find ...')` con walker Lua usando `love.filesystem`.

**Impacto:** ~35 forks de shell eliminados. Indexado ~5x más rápido.

### ✓ 1.2 Precarga de previews adyacentes
Precargar ±2 items al seleccionar uno.

**Impacto:** transiciones de preview instantáneas.

### ✓ 1.3 Scraper paralelo
Descargas curl concurrentes.

**Impacto:** scraping ~2-3x más rápido.

### ✓ 1.4 Lazy-load en grid view
Solo cargar imágenes del foco ±2 celdas.

**Impacto:** grid fluido sin stutters.

---

## Fase 2: Features ✅

### ✓ 2.1 Lista de recientes (`@Recent/`)
Últimos 20 juegos lanzados. Virtual folder en raíz.

### ✓ 2.2 Selector aleatorio
"Juego Aleatorio" en menú Config.

### ✓ 2.3 Cambio rápido de sistema
Opción "Cambiar Sistema" en Config → lista de sistemas → salto directo.

### ✓ 2.4 Cancelar batch scrape
Botón "Cancelar" + B key durante scraping por lote.

### ✓ 2.5 Colecciones / playlists
`data/collections.json`, virtual folder `@Collections/`, agregar/quitar/crear desde menú contextual.

---

## Fase 3: Calidad de vida ✅

### ✓ 3.1 Page Up/Down con hombros
L1/R1 como page up/down en scroll handler.

### ✓ 3.2 Escalado por resolución
Layout proporcional a la pantalla (`love.graphics.getDimensions()` → `scaleX = sw / 640`, `scaleY = sh / 480`).

### ✓ 3.3 Modo baja memoria
Ajustar cachés según RAM disponible (`/proc/meminfo` → `maxCacheSize`/`gridLazyRadius`).

### ✓ 3.4 Search history
Últimas 10 búsquedas guardadas (`search_history.json`).

---

## Fase 4: Robustez y plataforma

### ✓ 4.1 Error recovery
Guardado periódico (`_autoSaveTimer` cada 30s), escritura atómica (`utils.atomicWrite()`).

### ✓ 4.2 OTA update system
Checksum, rollback, reintentos, semver (`utils.semverCompare()`).

### [-] 4.3 Input remapeable (pospuesto)
### ✓ 4.4 CI y build
Workflow consolidado (luacheck + 14 tests con busted + muxapp + release).

### ✓ 4.5 Internacionalización (i18n)
Traducciones externas, `en` completo, fallback chain.

### [-] 4.6 Temas personalizables (pospuesto)
### ✓ 4.7 Documentación
DOCUMENTATION.md, ARCHITECTURE.md.

### ✓ 4.8 GitHub project structure
Issue/PR templates, CONTRIBUTING.md.

### [-] 4.9 Accesibilidad (pospuesto)
### ✓ 4.10 Centralizar paths de dispositivo
`utils.isDevice()`, `SD1_ROOT`, `SD2_ROOT`, `SIM_PREFIX`, `getBaseMuosPath()` usados en todos lados.

### ✓ 4.11 Dependencias
Fuentes no usadas eliminadas (Outfit, Onest, SNPro-Bold/Medium). Solo 4 fuentes esenciales.

---

## Fase 5: Experiencia de usuario (UX)

### ✓ 5.1 Feedback al lanzar un ROM
Overlay "Launching..." antes de salir.

### ✓ 5.2 Highlight de selección
Azul `selection_accent` 25% + barra lateral 3px.

### ✓ 5.3 Confirmación con undo al borrar
Toast "Deleted. [Undo]" por 3s (`undoData.timer`).

### [-] 5.4 Onboarding en primer inicio (pospuesto)

### ✓ 5.5 Botón B consistente
Campo `parentState`.

### ✓ 5.6 Ayuda contextual para API keys
Botón `?` con instrucciones.

### ✓ 5.7 Bottom bar adaptativa
4 hints principales, menos clutter.

### ✓ 5.8 Barra de progreso de indexación
Barra + texto siempre visible durante indexing.

### ✓ 5.9 Errores de API visibles en scraper
Fondo rojo + círculo con icono `!` + texto del warning.

### ✓ 5.10 Feedback búsqueda sin resultados
"No results for 'query'. Press F2 to clear."

### ✓ 5.11 Teclado virtual QWERTY estándar
Layout con stagger real, Shift, "123".

### ✓ 5.12 Top bar contextual
Título dinámico según vista.

### ✓ 5.13 Panel de salto por letra
Threshold 0.75s configurable.

### ✓ 5.14 Scrollbar animado
Usa `animatedSelectionIndex`.

### ✓ 5.15 Overlay de menú con alpha fijo
0.6 independiente de profundidad.

### ✓ 5.16 Fade de imágenes con ease cubic
`easeInOut` en vez de lineal.

### ✓ 5.17 Swap Start/Select
Select → Config, Start → Salir.

### ✓ 5.18 Protección visual en borrado
Fondo rojo + hold 0.5s con barra de progreso. Se cancela si se suelta la tecla.

---

## Resumen

| Fase | Completado | Pendiente | Total |
|------|-----------|-----------|-------|
| 1 — Rendimiento | **4** | 0 | 4 |
| 2 — Features | **5** | 0 | 5 |
| 3 — Calidad de vida | **4** | 0 | 4 |
| 4 — Robustez y plataforma | **8** | 0 | 11¹ |
| 5 — UX | **17** | 0 | 18² |
| **Total** | **38** | **0** | **42** |

¹ 3 items pospuestos (4.3, 4.6, 4.9)
² 1 item pospuesto (5.4)
