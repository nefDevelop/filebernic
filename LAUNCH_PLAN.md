# Plan de Lanzamiento: FileBernic

Este documento detalla los pasos necesarios para preparar **FileBernic** para su lanzamiento público (v1.0).

## 1. Estado Actual de la App

La aplicación es funcional e implementa las características principales documentadas:
- Navegación de sistemas y archivos.
- Scraper de meta-datos (imágenes, descripciones).
- Gestión de archivos (copiar/mover entre SDs, borrar).
- Favoritos e Historial.
- Soporte para LÖVE 11.4 (muOS).

Sin embargo, existen configuraciones de desarrollo activas y faltan elementos de identidad visual para un producto final.

## 2. Lo que Falta en la App (Critical Missing Items)

### A. Configuración de Producción
- **DEBUG Mode**: En `main.lua` (línea 13), `DEBUG = 2` debe cambiarse a `0` o `1` (solo errores) para mejorar el rendimiento y evitar escrituras innecesarias en disco.
- **API Keys**: En `main.lua`, `config.thegamesdb_apikey` está vacío.
    - *Solución*: Implementar un teclado virtual para que el usuario introduzca su propia API Key, o incluir una "default" con límites claros.
    - *Alternativa*: Usar ScreenScraper como default si no requiere key personal obligatoria (o usar una demo key).

### B. Identidad y Branding
- **Icono de Ventana**: En `assets/conf.lua`, `t.window.icon` es `nil`. Aunque en muOS el lanzador usa su propio icono, es buena práctica definirlo para pruebas en PC.
- **Icono del Paquete (.muxapp)**: El script `create_muxapp.sh` genera el archivo, pero muOS suele usar un icono asociado en el menú principal. Asegurarse de que el archivo `.muxapp` tenga un icono visible en el menú de muOS (normalmente un `.png` con el mismo nombre en la carpeta `glyph` o similar, aunque el script comenta `DIR2="glyph"` como comentado).

### C. Licencias y Legal
- **Licencia**: No existe un archivo `LICENSE` en la raíz.
    - Si es Open Source, añadir MIT/GPL.
- **Fuentes**: La app usa `SNPro` y `JetBrainsMono`. Verificar que sus licencias permiten redistribución (ambas suelen ser permisivas, pero debe confirmarse).

## 3. Recursos Externos Necesarios

Para un "buen lanzamiento", se necesitan materiales de marketing y soporte:

- **Repositorio Público (GitHub/GitLab)**:
    - `README.md`: Crear una portada atractiva con screenshots, lista de features e instrucciones de instalación.
    - `Releases`: Subir el `.muxapp` compilado.
- **Assets Gráficos para Tiendas/Discord**:
    - **Banner**: 1280x720px o similar para posts en redes/Discord.
    - **Screenshots**: Capturas limpias de la interfaz (Lista, Grid, Detalles).
    - **Logo**: Versión vectorial o alta resolución del logo de FileBernic.
- **Comunidad**:
    - Hilo oficial en el Discord de muOS.
    - Hilo en Reddit (r/SBCGaming, etc.).

## 4. Mejoras Técnicas Sugeridas (Quick Wins)

1.  **Script de Build Mejorado**:
    - Descomentar/Implementar la inclusión de la carpeta `glyph` en `create_muxapp.sh` si es necesaria para los iconos del menú de muOS.
2.  **Validación de Actualizaciones**:
    - ¿Cómo actualizarán los usuarios? Si no hay OTA (Over-The-Air), dejar claro en la App que deben bajar la nueva versión manualmente.

## 5. Plan de Acción (Checklist)

### Fase 1: Limpieza de Código
- [ ] Cambiar `DEBUG = 0` en `main.lua`.
- [ ] Verificar que `thegamesdb_apikey` se maneje con gracia si está vacía (mostrar mensaje al usuario).
- [ ] Crear archivo `LICENSE`.

### Fase 2: Paquetizado
- [x] Crear carpeta `glyph` con el icono de la app (png 256x256 recomendando).
- [x] Actualizar `create_muxapp.sh` para incluir `glyph`.
- [x] Generar la Build v1.0 (`FileBernic_v1.0.muxapp`).

### Fase 3: Documentación y Marketing
- [ ] Crear `README.md` en raíz con secciones: "Instalación", "Uso", "Créditos".
- [ ] Tomar 3-4 screenshots finales.
- [ ] Redactar post de anuncio para Discord/Comunidad.

### Fase 4: Lanzamiento
- [ ] Publicar release en GitHub.
- [ ] Anunciar en canales de muOS.
