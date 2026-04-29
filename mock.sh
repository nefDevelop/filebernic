#!/bin/bash

# Ruta base del simulador (relativa a donde ejecutes el script)
BASE_DIR="Simulador_SD"
ROMS_DIR="$BASE_DIR/ROMS"
MUOS_DIR="$BASE_DIR/MUOS/info/catalogue"

echo "========================================="
echo " Generando entorno de pruebas FileBernic "
echo "========================================="

# Limpiar simulador anterior para empezar de cero
rm -rf "$BASE_DIR"

# Crear directorios base
mkdir -p "$ROMS_DIR"
mkdir -p "$MUOS_DIR"

# 1. Array de juegos reales. Formato: "Sistema|Archivo|Pre-Scraped(0/1)"
GAMES=(
    # --- Juegos Multi-Sistema (Para probar el apilamiento en Juego Único) ---
    "SNES|Street Fighter II.smc|0"
    "MD|Street Fighter II.gen|0"
    "ARCADE|Street Fighter II.zip|0"
    
    "SNES|Mortal Kombat.sfc|0"
    "MD|Mortal Kombat.md|0"
    
    "NES|Tetris.nes|0"
    "GB|Tetris.gb|1" # Este lo pre-scrapeamos para ver la diferencia
    
    "SNES|Aladdin.sfc|0"
    "MD|Aladdin.md|0"
    "GB|Aladdin.gb|0"
    
    "SNES|Doom.smc|0"
    "PS|Doom.chd|0"
    "DOS|Doom.dosz|0"
    
    # --- Juegos únicos (Para probar el scraper puro) ---
    "GBA|Pokemon Emerald.gba|0"
    "GBA|Metroid Fusion.zip|0"
    "SNES|Chrono Trigger.zip|0"
    "MD|Sonic the Hedgehog.md|0"
    "NES|Super Mario Bros..nes|0"
    "PS|Castlevania - Symphony of the Night.chd|0"
    "ARCADE|Metal Slug.zip|0"
    "NEOGEO|Fatal Fury.zip|0"
    "N64|Super Mario 64.z64|0"
)

# Generar ROMs y Media mock
echo "-> Creando ROMs de prueba..."
for game_info in "${GAMES[@]}"; do
    IFS='|' read -r SYS FILENAME PRESCRAPED <<< "$game_info"
    
    SYS_DIR="$ROMS_DIR/$SYS"
    mkdir -p "$SYS_DIR"
    touch "$SYS_DIR/$FILENAME"
    
    if [ "$PRESCRAPED" == "1" ]; then
        GAME_NAME="${FILENAME%.*}"
        mkdir -p "$MUOS_DIR/$SYS/box"
        mkdir -p "$MUOS_DIR/$SYS/text"
        mkdir -p "$MUOS_DIR/$SYS/preview"
        
        touch "$MUOS_DIR/$SYS/box/$GAME_NAME.png"
        touch "$MUOS_DIR/$SYS/preview/$GAME_NAME.png"
        echo "El clásico juego de puzzle que todo el mundo conoce." > "$MUOS_DIR/$SYS/text/$GAME_NAME.txt"
        echo "1989" > "$MUOS_DIR/$SYS/text/$GAME_NAME.year"
    fi
done

# 2. Crear un juego Multi-Disco para probar el "Juego Único" (aplanado de versiones)
echo "-> Creando juego Multi-Disco (Final Fantasy VII) en PS..."
mkdir -p "$ROMS_DIR/PS"
touch "$ROMS_DIR/PS/Final Fantasy VII (Disc 1).chd"
touch "$ROMS_DIR/PS/Final Fantasy VII (Disc 2).chd"
touch "$ROMS_DIR/PS/Final Fantasy VII (Disc 3).chd"

# 3. Crear carpetas específicas para probar filtros
echo "-> Creando carpetas vacías y excluidas..."
# Añadir archivos "basura" en algunas carpetas para probar el escáner
mkdir -p "$ROMS_DIR/GBA"
touch "$ROMS_DIR/GBA/leeme.txt"
touch "$ROMS_DIR/GBA/.archivo_oculto.gba"
touch "$ROMS_DIR/GBA/portada_colada.jpg"

# Carpeta totalmente vacía (Ocultar Vacíos = ON debería ocultarla)
mkdir -p "$ROMS_DIR/SISTEMA_VACIO"

# Carpeta con basura pero sin ROMs (Ocultar Vacíos = ON debería ocultarla)
mkdir -p "$ROMS_DIR/SISTEMA_BASURA"
touch "$ROMS_DIR/SISTEMA_BASURA/instrucciones.pdf"

# Carpetas hardcoded que NUNCA deben salir en la lista
mkdir -p "$ROMS_DIR/BIOS"
mkdir -p "$ROMS_DIR/Saves"
mkdir -p "$ROMS_DIR/MUOS"

echo "========================================="
echo " ¡Listo! Puedes abrir la app ahora.      "
echo "========================================="
