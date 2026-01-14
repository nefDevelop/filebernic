# Documentación de FileBernic

FileBernic es un gestor de ROMs simple y eficiente diseñado para dispositivos portátiles con muOS.

## Controles y Acciones

### Navegación Principal (Lista de Archivos)

| Botón                       | Acción              | Descripción                                                                                             |
| :-------------------------- | :------------------ | :------------------------------------------------------------------------------------------------------ |
| **D-Pad Arriba/Abajo**      | Navegar             | Moverse por la lista de archivos.                                                                       |
| **D-Pad Izquierda/Derecha** | Paginación          | Saltar una página completa en la lista.                                                                 |
| **A**                       | Aceptar / Entrar    | Abrir carpeta o lanzar el juego seleccionado.                                                           |
| **B**                       | Atrás / Subir       | Volver a la carpeta anterior. Si está en la raíz, sale al selector de unidades.                         |
| **X**                       | Seleccionar         | Marcar/Desmarcar archivo para operaciones en lote (borrar, mover). No disponible en modo "Juego Único". |
| **Y**                       | Opciones de Archivo | Abre el menú contextual para el archivo seleccionado (Scraper, Copiar, Mover, Borrar).                  |
| **Start**                   | Configuración       | Abre el menú de configuración global (Ocultar vacíos, Marcar jugados).                                  |
| **Select**                  | Salir               | Cierra la aplicación inmediatamente.                                                                    |
| **L1**                      | Buscar              | Abre el teclado virtual para filtrar la lista por nombre.                                               |
| **L2**                      | Limpiar Filtro      | Borra el texto de búsqueda y restaura la lista completa.                                                |

### Menú de Opciones (Botón Y)

Este menú aparece en el panel lateral derecho.

- **Info**: Muestra una vista detallada con la carátula, captura y descripción del juego.
- **Scraper**: Abre la herramienta para descargar carátulas y metadatos desde internet.
- **Copiar a SD1/SD2**: Copia el archivo seleccionado a la otra tarjeta SD (si está disponible).
- **Mover a SD1/SD2**: Mueve el archivo a la otra tarjeta SD.
- **Save Games**: Abre el gestor de partidas para ver y copiar saves (.srm) y estados (.state) entre tarjetas.
- **Borrar**: Elimina el archivo (o los archivos seleccionados con X).

### Teclado Virtual (Búsqueda)

- **D-Pad**: Moverse por las teclas.
- **A**: Escribir carácter.
- **B**: Cancelar y salir de la búsqueda.
- **L1**: Salir manteniendo el filtro actual.
- **L2**: Limpiar filtro y salir.
- **SPACE**: Espacio.
- **BACK**: Borrar último carácter.
- **OK**: Confirmar búsqueda y ocultar teclado.

## Paneles y Vistas

### 1. Lista Principal

La vista por defecto. Muestra los archivos y carpetas.

- **Iconos**: Carpeta o ROM.
- **Etiquetas**: `SD1`, `SD2` o `SD½` (archivo presente en ambas tarjetas).
- **Vista Previa**: Si existen imágenes descargadas (Scraper), se muestran a la derecha de la lista.

### 2. Panel Lateral (Menú)

Aparece al pulsar **Y** (Opciones) o **Start** (Configuración). Se superpone a la derecha de la pantalla.

### 3. Vista de Información

Accesible desde el menú de opciones -> Info. Muestra carátula, captura, descripción y año.

### 4. Vista de Scraper

Accesible desde el menú de opciones -> Scraper. Permite buscar metadatos en ScreenScraper, TheGamesDB o Libretro y guardar los resultados.

### 5. Configuración (Start)

Opciones globales:

- **Ocultar vacíos**: Si está ON, las carpetas que no contengan ROMs válidas no se mostrarán.
- **Marcar Jugado**: Si está Si, los juegos lanzado se resaltarán en verde en la lista.
- **Limpieza**: Abre el menú de mantenimiento para buscar Save States huérfanos y ROMs duplicadas.

### 6. Gestor de Partidas (Save Games)

Accesible desde el menú de opciones de un juego. Muestra los archivos de guardado asociados y permite copiarlos a la otra tarjeta SD para backup.

### 7. Menú de Limpieza

Accesible desde Configuración. Escanea el sistema en busca de:

- **States Huérfanos**: Archivos de estado (.state) que no tienen una ROM asociada. Permite borrarlos.
- **Juegos Duplicados**: Lista juegos que existen tanto en SD1 como en SD2.
