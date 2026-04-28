#!/bin/bash
# HELP: filebernic
# ICON: filebernic
# GRID: filebernic

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

# Define global variables
SCREEN_WIDTH=$(GET_VAR device mux/width)
SCREEN_HEIGHT=$(GET_VAR device mux/height)
SCREEN_RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# Usaremos filebernic para seguir la convención de los ejemplos
APP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/filebernic"
GPTOKEYB="$APP_DIR/bin/gptokeyb2"

CONFDIR="$APP_DIR/data"
LOGDIR="$CONFDIR/log"

mkdir -p "$LOGDIR" "$CONFDIR"

# Export environment variables
SETUP_SDL_ENVIRONMENT
export XDG_DATA_HOME="$CONFDIR"

# Redirigir la salida a un archivo de log para depuración (quitado por problemas de reinicio)
# exec > >(tee "$APP_DIR/log.txt") 2>&1

# Launcher
cd "$APP_DIR" || exit
SET_VAR "system" "foreground_process" "love"

export LD_LIBRARY_PATH="$APP_DIR/libs:$LD_LIBRARY_PATH"
LOGFILE="${LOGDIR}/filebernic.log"
echo "[DEBUG] Running as user: $(whoami)" >>"$LOGFILE"
echo "[DEBUG] LANG: $LANG" >>"$LOGFILE"
echo "[DEBUG] Environment variables:" >>"$LOGFILE"
env >>"$LOGFILE"

# Generar configuración de controles específica para evitar conflictos
cat > "$APP_DIR/filebernic.gptk" << EOF
back = "escape"
select = "escape"
start = "f1"
a = "kp_enter"
b = "backspace"
x = ""
y = "tab"
l1 = ""
l2 = ""
r1 = ""
r2 = ""
up = "up"
down = "down"
left = "left"
right = "right"
left_analog_up = "up"
left_analog_down = "down"
left_analog_left = "left"
left_analog_right = "right"
EOF

while true; do
    # Limpiar solicitud de lanzamiento previa
    rm -f /tmp/launch_rom

    # Start gptokeyb
    $GPTOKEYB "love" -c "$APP_DIR/filebernic.gptk" &
    GPTOKEYB_PID=$!

    # Launch app and capture output
    ./love . "${SCREEN_RESOLUTION}" >>"$LOGFILE" 2>&1

    # Kill gptokeyb
    if kill -0 "$GPTOKEYB_PID" >/dev/null 2>&1; then
        kill -9 "$GPTOKEYB_PID"
    fi

    # --- SISTEMA DE ACTUALIZACIÓN OTA ---
    if [ -f /tmp/filebernic_update ]; then
        DOWNLOAD_URL=$(cat /tmp/filebernic_update)
        echo "[OTA] Descargando actualización desde: $DOWNLOAD_URL" >>"$LOGFILE"
        
        # Descargar el nuevo empaquetado (.zip o .muxapp)
        curl -L -k -o /tmp/filebernic_new.zip "$DOWNLOAD_URL" >>"$LOGFILE" 2>&1
        
        if [ -f /tmp/filebernic_new.zip ]; then
            echo "[OTA] Descomprimiendo actualización..." >>"$LOGFILE"
            # Extraer sobrescribiendo los archivos antiguos en la carpeta actual
            unzip -o /tmp/filebernic_new.zip -d "$APP_DIR" >>"$LOGFILE" 2>&1
            rm /tmp/filebernic_new.zip
        fi
        rm -f /tmp/filebernic_update
        # El bucle continue, por lo que LÖVE se volverá a abrir inmediatamente con la nueva versión
        continue
    fi

    # Verificar si hay una ROM para lanzar
    if [ -f /tmp/launch_rom ]; then
        LAST_ROM=$(cat /tmp/launch_rom)
        echo "[DEBUG] Launching ROM: $LAST_ROM" >>"$LOGFILE"
        
        # --- Lanzamiento de Juego ---
        # 1. Detectar el núcleo (core) a usar basado en la extensión y carpeta
        CORE="mgba_libretro.so" # Default GBA
        
        # Extraer extensión y carpeta para mejor detección
        FILENAME=$(basename "$LAST_ROM")
        EXT="${FILENAME##*.}"
        EXT="${EXT,,}" # Convertir a minúsculas
        
        # Intentar detectar el sistema desde la ruta base (ej: .../ROMS/GBA/Sub/Juego.zip -> GBA)
        SYSTEM_FOLDER=$(echo "$LAST_ROM" | sed -n 's|.*/ROMS/\([^/]*\)/.*|\1|p')
        # Fallback si no encuentra /ROMS/ (ej: simulador o rutas absolutas directas)
        if [ -z "$SYSTEM_FOLDER" ]; then SYSTEM_FOLDER=$(basename "$(dirname "$LAST_ROM")"); fi
        
        case "$EXT" in
            # Nintendo
            gb|gbc|dmg) CORE="gambatte_libretro.so" ;;
            gba) CORE="mgba_libretro.so" ;;
            nes|fds|unf|unif) CORE="fceumm_libretro.so" ;;
            snes|smc|sfc|fig|swc|bs) CORE="snes9x_libretro.so" ;;
            n64|z64|v64|ndd) CORE="mupen64plus_next_libretro.so" ;;
            nds|ids|dsi) CORE="melonds_libretro.so" ;;
            vb|vboy) CORE="mednafen_vb_libretro.so" ;;
            min) CORE="pokemini_libretro.so" ;;
            # Sega
            md|gen|smd) CORE="picodrive_libretro.so" ;;
            sms|gg|sg) CORE="genesis_plus_gx_libretro.so" ;;
            32x|68k|sgd|pco) CORE="picodrive_libretro.so" ;;
            cdi|gdi) CORE="flycast_libretro.so" ;;
            # Sony
            pbp|cbn|mdf|psf) CORE="pcsx_rearmed_libretro.so" ;;
            psp|cso|prx) CORE="ppsspp_libretro.so" ;;
            # Atari
            a26) CORE="stella_libretro.so" ;;
            a78|cdf) CORE="prosystem_libretro.so" ;;
            a52|xfd|atr|atx) CORE="atari800_libretro.so" ;;
            lnx|lyx) CORE="handy_libretro.so" ;;
            jag|j64) CORE="virtualjaguar_libretro.so" ;;
            st|msa|dim|stx) CORE="hatari_libretro.so" ;;
            # Arcade
            neo) CORE="fbneo_libretro.so" ;;
            # Otros
            pce|sgx) CORE="mednafen_pce_fast_libretro.so" ;;
            ngp|ngc|ngpc|npc) CORE="mednafen_ngp_libretro.so" ;;
            ws|wsc|pc2) CORE="mednafen_wswan_libretro.so" ;;
            col|cv) CORE="gearcoleco_libretro.so" ;;
            int) CORE="freeintv_libretro.so" ;;
            d64|t64|prg|crt) CORE="vice_x64_libretro.so" ;;
            adf|ipf|lha) CORE="puae_libretro.so" ;;
            dosz|exe|com|bat) CORE="dosbox_pure_libretro.so" ;;
            scummvm) CORE="scummvm_libretro.so" ;;
            p8) CORE="fake08_libretro.so" ;;
            tic) CORE="tic80_libretro.so" ;;
            # Archivos ambiguos (zip, 7z, bin, iso, cue, chd, m3u, img, rom) - Intentar adivinar por carpeta
            zip|7z|rar|bin|iso|cue|chd|m3u|img|rom|dsk|cas|tap|wav|cmd)
                case "$SYSTEM_FOLDER" in
                    *SNES*|*SFC*) CORE="snes9x_libretro.so" ;;
                    *NES*|*FC*) CORE="fceumm_libretro.so" ;;
                    *PS*|*Sony*) CORE="pcsx_rearmed_libretro.so" ;;
                    *PCE*|*Turbo*) CORE="mednafen_pce_fast_libretro.so" ;;
                    *Saturn*) CORE="yabasanshiro_libretro.so" ;;
                    *Dreamcast*|*DC*|*Naomi*|*Atomiswave*) CORE="flycast_libretro.so" ;;
                    *Mega*|*Genesis*|*SegaCD*|*MegaCD*) CORE="genesis_plus_gx_libretro.so" ;;
                    *NeoGeoCD*|*NGCD*) CORE="neocd_libretro.so" ;;
                    *NeoGeo*|*NEOGEO*) CORE="fbneo_libretro.so" ;;
                    *3DO*) CORE="opera_libretro.so" ;;
                    *Amiga*) CORE="puae_libretro.so" ;;
                    *Arcade*|*ARCADE*|*CPS*|*MAME*|*FBNeo*) CORE="fbneo_libretro.so" ;;
                    *GBA*) CORE="mgba_libretro.so" ;;
                    *GBC*|*GB*) CORE="gambatte_libretro.so" ;;
                    *N64*) CORE="mupen64plus_next_libretro.so" ;;
                    *NDS*) CORE="melonds_libretro.so" ;;
                    *MSX*) CORE="bluemsx_libretro.so" ;;
                    *DOS*) CORE="dosbox_pure_libretro.so" ;;
                    *C64*|*Commodore*) CORE="vice_x64_libretro.so" ;;
                    *Amstrad*) CORE="cap32_libretro.so" ;;
                    *X68000*) CORE="px68k_libretro.so" ;;
                    *) 
                        if [[ "$EXT" == "zip" || "$EXT" == "7z" ]]; then CORE="fbneo_libretro.so"; 
                        else CORE="pcsx_rearmed_libretro.so"; fi 
                        ;; 
                esac
                ;;
        esac

        # Override: Si la App especificó un núcleo (porque preguntó al usuario), usarlo.
        if [ -f /tmp/launch_core ]; then
            CORE=$(cat /tmp/launch_core)
            rm -f /tmp/launch_core
            echo "[DEBUG] Overriding core with: $CORE" >>"$LOGFILE"
        fi

        # 2. Usar el script de lanzamiento encontrado en la lista: lr-general.sh
        MUOS_LAUNCHER="/opt/muos/script/launch/lr-general.sh"

        if [ -f "$MUOS_LAUNCHER" ]; then
            # Extraer nombre del sistema (carpeta padre) para el primer argumento (NAME)
            SYSTEM_NAME=$(basename "$(dirname "$LAST_ROM")")
            echo "[DEBUG] Usando lanzador oficial: $MUOS_LAUNCHER $SYSTEM_NAME $CORE $LAST_ROM" >> "$LOGFILE"
            "$MUOS_LAUNCHER" "$SYSTEM_NAME" "$CORE" "$LAST_ROM" >> "$LOGFILE" 2>&1
        else
            echo "[WARNING] No se encontró lr-general.sh. Usando Plan B (Directo)..." >> "$LOGFILE"
            # Plan B: Ejecución directa (que sabemos que funciona)
            RA_CFG="/mnt/mmc/MUOS/emulator/retroarch/retroarch.cfg"
            RA_CORES="/mnt/mmc/MUOS/emulator/retroarch/cores"
            retroarch -v -L "$RA_CORES/$CORE" -c "$RA_CFG" "$LAST_ROM" >> "$LOGFILE" 2>&1
        fi
        
        echo "[DEBUG] Juego terminado. Reiniciando bucle..." >>"$LOGFILE"
    else
        # Si no hay archivo launch_rom, salimos del bucle (volver a muOS)
        echo "[DEBUG] Saliendo del bucle y cerrando aplicación." >>"$LOGFILE"
        break
    fi
done
exit 0