# FileBernic: Tu Gestor de ROMs Definitivo para muOS

![FileBernic Banner](https://via.placeholder.com/1280x720?text=FileBernic+Banner+Image)

## 🚀 Visión General

**FileBernic** es un gestor de ROMs diseñado específicamente para dispositivos portátiles con **muOS**. Ofrece una interfaz intuitiva y potentes herramientas para organizar, explorar y lanzar tu colección de juegos. Olvídate de la tediosa gestión manual y sumérgete directamente en la diversión.

## ✨ Características Principales

- **Navegación Intuitiva**: Explora tus sistemas y ROMs con facilidad, tanto en vista de lista como de cuadrícula.
- **Scraper Integrado**: Descarga carátulas, capturas de pantalla y metadatos (descripciones, años) automáticamente para enriquecer tu biblioteca.
- **Gestión de Archivos Avanzada**:
  - Copia y mueve ROMs entre tarjetas SD.
  - Elimina juegos y sus metadatos asociados.
  - Herramienta de limpieza para encontrar y eliminar saves huérfanos e imágenes no utilizadas.
- **Favoritos e Historial**: Marca tus juegos preferidos y retoma rápidamente donde lo dejaste con el historial de juegos recientes.
- **Soporte Multi-Versión**: Agrupa automáticamente diferentes versiones de un mismo juego (región, idioma) para una selección más limpia.
- **Modos de Visualización**: Alterna entre vista de lista y cuadrícula para adaptarse a tus preferencias.
- **Filtros Rápidos**: Busca juegos por nombre y oculta directorios vacíos para mantener tu lista ordenada.
- **Optimizado para muOS**: Diseñado para un rendimiento fluido en el entorno muOS.

## 🎮 Controles

La navegación en FileBernic es sencilla e intuitiva, adaptada a los controles de tu dispositivo muOS.

### Navegación Principal (Lista de Archivos)

| Botón                       | Acción              | Descripción                                                                                             |
| :-------------------------- | :------------------ | :------------------------------------------------------------------------------------------------------ |
| **D-Pad Arriba/Abajo**      | Navegar             | Moverse por la lista de archivos.                                                                       |
| **D-Pad Izquierda/Derecha** | Paginación          | Saltar una página completa en la lista.                                                                 |
| **A**                       | Aceptar / Entrar    | Abrir carpeta o lanzar el juego seleccionado.                                                           |
| **B**                       | Atrás / Subir       | Volver a la carpeta anterior. Si está en la raíz, sale al selector de unidades.                         |
| **X**                       | Seleccionar         | Marcar/Desmarcar archivo para operaciones en lote (borrar, mover). No disponible en modo "Juego Único". |
| **Y**                       | Opciones de Archivo | Abre el menú contextual para el archivo seleccionado (Scraper, Copiar, Mover, Borrar).                  |
| **Start**                   | Configuración       | Abre el menú de configuración global (Ocultar vacíos, Marcar jugados, Limpieza).                        |
| **Select**                  | Salir               | Cierra la aplicación inmediatamente.                                                                    |
| **L1**                      | Buscar              | Abre el teclado virtual para filtrar la lista por nombre.                                               |
| **L2**                      | Limpiar Filtro      | Borra el texto de búsqueda y restaura la lista completa.                                                |
| **R1**                      | Ayuda               | Muestra una guía rápida de controles.                                                                   |

## 🛠️ Instalación

Para instalar FileBernic en tu dispositivo muOS:

1.  Descarga el archivo `FileBernic_vX.Y.muxapp` desde la sección de Releases de GitHub.
2.  Copia el archivo `.muxapp` a la carpeta `MUOS/application/` en la tarjeta SD de tu dispositivo.
3.  Reinicia tu dispositivo muOS o actualiza la lista de aplicaciones.
4.  FileBernic aparecerá en el menú de aplicaciones.

## ⚙️ Uso

Al iniciar FileBernic, serás recibido por la lista de tus sistemas o la última carpeta visitada.

- **Navegar**: Usa el D-Pad para moverte por la lista.
- **Entrar en Carpetas/Lanzar Juegos**: Pulsa **A**.
- **Volver**: Pulsa **B** para ir a la carpeta padre.
- **Opciones de Juego**: Selecciona un juego y pulsa **Y** para acceder a opciones como scraping, mover/copiar, gestión de saves o borrar.
- **Configuración Global**: Pulsa **Start** para acceder a opciones de visualización y herramientas de mantenimiento.

### Scraper

Para usar el scraper, selecciona un juego, pulsa **Y** y elige "Scraper". Podrás buscar metadatos y carátulas en línea. Asegúrate de tener una conexión a internet activa.

### Limpieza

Desde el menú de configuración (botón Start), selecciona "Limpieza" para escanear tu tarjeta SD en busca de archivos de guardado huérfanos o ROMs duplicadas.

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Si encuentras un error o tienes una sugerencia de mejora, por favor, abre un _issue_ o envía un _pull request_ en el repositorio de GitHub.

## 📜 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE.md` para más detalles.

## 💖 Créditos

- **Desarrollador Principal**: [Nefdevelop]
- **Agradecimientos Especiales**:
  - La comunidad de muOS por su soporte y plataforma.
  - LÖVE2D por el framework de desarrollo.
  - Fuentes:
    - **JetBrains Mono**: Licencia Apache 2.0.
    - **SNPro**: Designed by [Tobias Whetton](https://github.com/supernotes/sn-pro):
  - `dkjson` (para manejo de JSON)
  - `love-loader` (para carga de assets)

---

**¡Disfruta de tu colección de juegos con FileBernic!**

---
