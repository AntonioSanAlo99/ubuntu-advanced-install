#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 16: Configurar gaming
# Steam (PPA Valve) + Heroic (.deb GitHub) + Faugus (PPA oficial) + MangoJuice (fuente) + drivers GPU
# Compatible con bare metal, VM con GPU passthrough y VM sin GPU dedicada
# ══════════════════════════════════════════════════════════════════════════════

# No usar set -e — muchos comandos pueden fallar legitimamente (drivers,
# descargas, detección de hardware en VM). Cada sección maneja sus errores.

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "═══════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN GAMING"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# DETECCIÓN DE HARDWARE
# ============================================================================

echo "Detectando hardware..."
echo ""

# ── Detección de GPUs ────────────────────────────────────────────────────────
# En VMs con passthrough, lspci muestra la GPU real del host.
# En VMs sin passthrough, puede mostrar virtio-gpu, QXL, VGA, etc.
HAS_INTEL=false
HAS_AMD=false
HAS_NVIDIA=false
HAS_VIRTIO=false
GPU_LINES=""

if command -v lspci >/dev/null 2>&1; then
    GPU_LINES=$(lspci 2>/dev/null | grep -iE "vga|3d|display" || true)
fi

if [ -n "$GPU_LINES" ]; then
    echo "$GPU_LINES" | grep -qi "intel"              && HAS_INTEL=true  || true
    echo "$GPU_LINES" | grep -qi "nvidia"             && HAS_NVIDIA=true || true
    echo "$GPU_LINES" | grep -qi "amd\|radeon\|ati"   && HAS_AMD=true   || true
    echo "$GPU_LINES" | grep -qi "virtio\|qxl\|bochs\|vmware\|cirrus" && HAS_VIRTIO=true || true
fi

# Determinar configuración
GPU_CONFIG="unknown"
if $HAS_INTEL && $HAS_NVIDIA; then
    GPU_CONFIG="intel+nvidia"
elif $HAS_INTEL && $HAS_AMD; then
    GPU_CONFIG="intel+amd"
elif $HAS_AMD && $HAS_NVIDIA; then
    GPU_CONFIG="amd+nvidia"
elif $HAS_AMD && ! $HAS_INTEL && ! $HAS_NVIDIA; then
    AMD_COUNT=0
    if [ -n "$GPU_LINES" ]; then
        AMD_COUNT=$(echo "$GPU_LINES" | grep -ciE "amd|radeon|ati" 2>/dev/null) || AMD_COUNT=0
    fi
    [ "$AMD_COUNT" -ge 2 ] 2>/dev/null && GPU_CONFIG="amd+amd" || GPU_CONFIG="amd"
elif $HAS_INTEL && ! $HAS_AMD && ! $HAS_NVIDIA; then
    GPU_CONFIG="intel"
elif $HAS_NVIDIA && ! $HAS_INTEL && ! $HAS_AMD; then
    GPU_CONFIG="nvidia"
elif $HAS_VIRTIO; then
    GPU_CONFIG="virtio"
fi

echo "GPUs detectadas:"
[ -n "$GPU_LINES" ] && echo "$GPU_LINES" | sed 's/^/  /'
[ -z "$GPU_LINES" ] && echo "  (ninguna detectada — posible VM sin lspci)"
echo ""

case "$GPU_CONFIG" in
    intel+nvidia) echo "  Configuración: Intel + NVIDIA (Optimus/PRIME)" ;;
    intel+amd)    echo "  Configuración: Intel + AMD (PRIME)" ;;
    amd+nvidia)   echo "  Configuración: AMD + NVIDIA (PRIME)" ;;
    amd+amd)      echo "  Configuración: AMD iGPU + AMD dGPU" ;;
    intel)        echo "  Configuración: Intel (GPU única)" ;;
    amd)          echo "  Configuración: AMD (GPU única)" ;;
    nvidia)       echo "  Configuración: NVIDIA (GPU única)" ;;
    virtio)       echo "  Configuración: VM (virtio-gpu/QXL)" ;;
    *)            echo "  Configuración: No identificada" ;;
esac
echo ""

# Override manual (si la detección falla — común en passthrough)
if [ -z "$GPU_MANUAL" ]; then
    echo "Si la detección no es correcta, selecciona manualmente:"
    echo "  1) AMD       2) Intel       3) Intel + NVIDIA"
    echo "  4) Intel + AMD  5) AMD + AMD   6) AMD + NVIDIA"
    echo "  7) NVIDIA    8) VM (virtio)   9) Detección automática"
    echo ""
    read -p "Opción [9]: " GPU_MANUAL
fi

case "${GPU_MANUAL:-9}" in
    1) GPU_CONFIG="amd" ;;
    2) GPU_CONFIG="intel" ;;
    3) GPU_CONFIG="intel+nvidia" ;;
    4) GPU_CONFIG="intel+amd" ;;
    5) GPU_CONFIG="amd+amd" ;;
    6) GPU_CONFIG="amd+nvidia" ;;
    7) GPU_CONFIG="nvidia" ;;
    8) GPU_CONFIG="virtio" ;;
    *) ;; # Mantener detección
esac

echo "  → GPU: $GPU_CONFIG"
echo ""

# ============================================================================
# INSTALACIÓN EN CHROOT
# ============================================================================

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
USERNAME="$USERNAME"
GPU_CONFIG="$GPU_CONFIG"

# Función auxiliar: instalar paquetes sin fallar si alguno no existe
safe_apt() {
    apt install -y \$APT_FLAGS "\$@" 2>/dev/null || true
}

# ============================================================================
# HABILITAR i386 Y MESA BASE
# ============================================================================

echo ""
echo "Habilitando arquitectura i386..."

dpkg --add-architecture i386
apt update

echo "✓  i386 habilitado"
echo ""

# ── Mesa base (necesario para TODAS las configs, incluida VM) ────────────────
echo "Instalando Mesa base + Vulkan..."
safe_apt \
    mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
    libgl1-mesa-dri libgl1-mesa-dri:i386 \
    mesa-utils vulkan-tools \
    libvulkan1 libvulkan1:i386 \
    libgl1 libgl1:i386

echo "✓  Mesa base instalado"

# ============================================================================
# DRIVERS SEGÚN GPU
# ============================================================================

echo ""
echo "Instalando drivers para: \$GPU_CONFIG"
echo ""

install_intel() {
    echo "  → Drivers Intel..."
    # intel-media-va-driver:     driver VA-API gen8 (Broadwell) e inferior
    # intel-media-va-driver-non-free (iHD): gen9+ (Skylake y posterior) — H.264/HEVC/AV1 HW
    # libva-intel-media-driver:  alias del driver iHD en algunos repos
    safe_apt \
        intel-media-va-driver \
        intel-media-va-driver-non-free \
        intel-gpu-tools \
        libva2 libva-drm2 libva-x11-2 libva-wayland2 \
        vainfo
}

install_amd() {
    echo "  → Drivers AMD..."
    safe_apt \
        libdrm-amdgpu1 libdrm-amdgpu1:i386 \
        mesa-va-drivers mesa-va-drivers:i386 \
        mesa-vdpau-drivers mesa-vdpau-drivers:i386 \
        libvulkan-mesa-layers libvulkan-mesa-layers:i386 \
        libva2 libva-drm2 libva-x11-2 libva-wayland2 \
        vainfo radeontop lm-sensors
    safe_apt firmware-amd-graphics
}

install_nvidia() {
    echo "  → Drivers NVIDIA (método Pop!_OS)..."

    # 1. Asegurar ubuntu-drivers-common (necesario para detectar driver correcto)
    safe_apt ubuntu-drivers-common

    # 2. Intentar PPA System76 (empaqueta drivers NVIDIA probados y actualizados)
    #    Pop!_OS usa system76-driver-nvidia como metapaquete que arrastra el driver
    #    correcto. En Ubuntu funciona añadiendo su PPA estable.
    S76_PPA=false
    if add-apt-repository -y ppa:system76-dev/stable 2>/dev/null; then
        apt update 2>/dev/null || true
        if apt install -y $APT_FLAGS system76-driver-nvidia 2>/dev/null; then
            S76_PPA=true
            echo "  ✓ NVIDIA instalado vía PPA System76 (system76-driver-nvidia)"
        else
            echo "  ⚠ system76-driver-nvidia falló — probando ubuntu-drivers"
            # Quitar PPA si el metapaquete no funcionó (evitar conflictos)
            add-apt-repository -ry ppa:system76-dev/stable 2>/dev/null || true
            apt update 2>/dev/null || true
        fi
    fi

    # 3. Fallback: ubuntu-drivers autoinstall (detecta GPU y elige driver)
    #    No funciona perfecto en chroot pero sí en la mayoría de casos.
    if [ "\$S76_PPA" = "false" ]; then
        if ubuntu-drivers install 2>/dev/null; then
            echo "  ✓ NVIDIA instalado vía ubuntu-drivers"
        else
            # 4. Último recurso: instalar driver genérico por número de versión
            echo "  ⚠ ubuntu-drivers falló — instalando driver manual"
            safe_apt nvidia-driver-560
            if ! dpkg -l 2>/dev/null | grep -q "^ii.*nvidia-driver"; then
                safe_apt nvidia-driver-550
            fi
            if ! dpkg -l 2>/dev/null | grep -q "^ii.*nvidia-driver"; then
                safe_apt nvidia-driver
            fi
        fi
    fi

    # VA-API sobre NVDEC (para aceleración de vídeo en Wayland y X11)
    safe_apt nvidia-vaapi-driver libva2 libva-drm2 libva-x11-2 libva-wayland2 vainfo

    # Verificar resultado
    if dpkg -l 2>/dev/null | grep -q "^ii.*nvidia-driver"; then
        NVIDIA_VER=\$(dpkg -l 2>/dev/null | grep "^ii.*nvidia-driver-[0-9]" | head -1 | awk '{print \$3}')
        echo "  ✓ NVIDIA driver instalado: \${NVIDIA_VER:-versión desconocida}"
    else
        echo "  ⚠ NVIDIA: driver no confirmado en chroot"
        echo "    Ejecutar tras primer boot: sudo ubuntu-drivers install"
    fi
}

install_prime() {
    echo "  → Soporte PRIME / GPU switching..."
    safe_apt switcheroo-control
    if echo "\$GPU_CONFIG" | grep -q "nvidia"; then
        safe_apt nvidia-prime
    fi
    systemctl enable switcheroo-control 2>/dev/null || true
}

case "\$GPU_CONFIG" in
    amd)
        install_amd
        ;;
    intel)
        install_intel
        ;;
    nvidia)
        install_nvidia
        ;;
    intel+nvidia)
        install_intel
        install_nvidia
        install_prime
        ;;
    intel+amd)
        install_intel
        install_amd
        install_prime
        ;;
    amd+amd)
        install_amd
        install_prime
        ;;
    amd+nvidia)
        install_amd
        install_nvidia
        install_prime
        ;;
    virtio)
        # VM sin GPU dedicada — solo Mesa base (ya instalado arriba)
        echo "  VM detectada — usando Mesa/llvmpipe (software rendering)"
        echo "  Si tienes GPU passthrough, vuelve a ejecutar con la GPU correcta"
        ;;
    *)
        # Desconocida: intentar todo lo posible
        echo "  GPU no identificada — instalando drivers genéricos"
        install_amd 2>/dev/null || true
        install_intel 2>/dev/null || true
        ;;
esac

echo ""
echo "✓  Drivers instalados"

# ============================================================================
# ACELERACIÓN HARDWARE + WAYLAND NATIVO
# ============================================================================
# Variables de entorno globales en /etc/environment.
# Preparado para GNOME 48/50 en 26.04 donde Wayland es el único backend.
# ============================================================================

echo ""
echo "Configurando aceleración hardware y Wayland nativo..."

arch-chroot "$TARGET" /bin/bash << 'HWACCEL_EOF'

add_env_var() {
    local key="$1" val="$2"
    if grep -q "^${key}=" /etc/environment 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" /etc/environment
    else
        echo "${key}=${val}" >> /etc/environment
    fi
}

# GStreamer: expone todos los drivers VA-API disponibles a GStreamer
add_env_var "GST_VAAPI_ALL_DRIVERS" "1"

# Qt6: Wayland nativo, fallback xcb para apps que no soporten Wayland
# (QT_QPA_PLATFORM, no QT_QPA_PLATFORMTHEME que es diferente)
add_env_var "QT_QPA_PLATFORM" "wayland;xcb"

# SDL2/SDL3: Wayland nativo con fallback a X11 (XWayland) para juegos
# que no tienen backend Wayland. SDL ≥ 2.0.22 soporta lista con coma.
add_env_var "SDL_VIDEODRIVER" "wayland,x11"

# GDK (GTK3/GTK4): GTK4 acepta "wayland,x11", GTK3 solo acepta un valor.
# No se fuerza globalmente — GNOME gestiona esto internamente y forzarlo
# rompe apps GTK3 legacy. Se deja sin variable: GNOME ya prefiere Wayland.

echo "✓  Variables de entorno escritas en /etc/environment"

# ── Chrome/Chromium: flags Wayland + VA-API ───────────────────────────────
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/chrome-flags.conf << 'CHROMEFLAGS'
--ozone-platform=wayland
--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder,CanvasOopRasterization
--use-gl=egl
--enable-gpu-rasterization
--enable-zero-copy
CHROMEFLAGS

cp /etc/skel/.config/chrome-flags.conf /etc/skel/.config/chromium-flags.conf 2>/dev/null || true
echo "✓  Chrome/Chromium: flags Wayland + VA-API configurados en skel"

HWACCEL_EOF

echo "✓  Aceleración hardware y Wayland nativo configurados"

# ============================================================================
# GAMEMODE + MANGOHUD
# ============================================================================

echo ""
echo "Instalando GameMode y MangoHud..."
safe_apt gamemode mangohud
echo "✓  GameMode y MangoHud instalados"

# ============================================================================
# STEAM — .deb oficial de Valve + ejecución headless del cliente
# ============================================================================
# Paso 1: Instalar el .deb de Akamai (bootstrapper + dependencias i386)
# Paso 2: Ejecutar /usr/bin/steam como $USERNAME — el script:
#         a) Extrae bootstraplinux_ubuntu12_32.tar.xz a ~/.local/share/Steam/
#         b) Ejecuta steamdeps para instalar dependencias faltantes del runtime
#         c) Descarga el cliente completo desde client-download.steampowered.com
#         d) Intenta abrir la GUI (falla sin DISPLAY — es esperado)
#
# Resultado: en el primer arranque real, Steam solo necesita login.
# ============================================================================

echo ""
echo "Instalando Steam (paquete oficial Valve)..."

STEAM_DEB="/tmp/steam.deb"
STEAM_URL="https://cdn.akamai.steamstatic.com/client/installer/steam.deb"

if wget --timeout=30 --tries=2 -q "\$STEAM_URL" -O "\$STEAM_DEB" 2>/dev/null \
   && [ -s "\$STEAM_DEB" ]; then

    # Pre-aceptar licencia
    echo "steam steam/question select I AGREE" | debconf-set-selections
    echo "steam steam/license note"            | debconf-set-selections

    # Instalar el .deb y resolver dependencias automáticamente
    dpkg -i "\$STEAM_DEB" 2>/dev/null || true
    apt-get install -f -y 2>/dev/null || true
    rm -f "\$STEAM_DEB"
    echo "✓  Steam .deb instalado"

    # ── Ejecutar steam headless como usuario ──────────────────────────
    # /usr/bin/steam es un script bash que:
    #   1. Detecta si el bootstrap ya está extraído
    #   2. Si no, extrae /usr/lib/steam/bootstraplinux_ubuntu12_32.tar.xz
    #   3. Llama a steamdeps (instala deps i386 que falten)
    #   4. Ejecuta steam.sh que descarga/actualiza el cliente
    #   5. Intenta abrir la GUI → falla sin DISPLAY (esperado)
    #
    # timeout 180s es suficiente para descargar ~200 MB de cliente.
    # El exit code != 0 es esperado (sin display).

    STEAM_HOME="/home/\$USERNAME"
    echo "  Ejecutando Steam headless (bootstrap + descarga del cliente)..."

    timeout 180 sudo -u "\$USERNAME" \
        env HOME="\$STEAM_HOME" \
            STEAM_RUNTIME=1 \
            DISPLAY="" \
            DBUS_SESSION_BUS_ADDRESS="" \
        /usr/bin/steam 2>/dev/null || true

    # Matar procesos residuales de steam
    pkill -u "\$USERNAME" -f steam 2>/dev/null || true
    sleep 2
    pkill -9 -u "\$USERNAME" -f steam 2>/dev/null || true

    # Verificar resultado
    if [ -d "\$STEAM_HOME/.local/share/Steam/ubuntu12_32" ] \
       && [ -f "\$STEAM_HOME/.local/share/Steam/steam.sh" ]; then
        echo "✓  Steam: cliente completo instalado (solo necesita login en primer arranque)"
    else
        echo "⚠  Steam: bootstrap ejecutado pero descarga del cliente incompleta"
        echo "   El cliente se completará automáticamente en el primer arranque"
    fi

    # Asegurar ownership correcto
    chown -R "\$USERNAME:\$USERNAME" "\$STEAM_HOME/.local/share/Steam" 2>/dev/null || true
    chown -R "\$USERNAME:\$USERNAME" "\$STEAM_HOME/.steam" 2>/dev/null || true
else
    echo "⚠  Steam: no se pudo descargar el paquete oficial"
    echo "   Instalar tras primer boot: sudo apt install steam"
fi

# ============================================================================
# HEROIC GAMES LAUNCHER (.deb desde GitHub releases)
# ============================================================================
# Heroic no tiene PPA. Publica .deb en GitHub releases para amd64.
# Se descarga el último release disponible en el momento de la instalación.
# ============================================================================

echo ""
echo "Instalando Heroic Games Launcher..."

HEROIC_DEB=\$(mktemp /tmp/heroic-XXXXXX.deb)
HEROIC_URL=\$(curl -fsSL https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    2>/dev/null | grep "browser_download_url" | grep "\.deb" | grep -v "arm\|aarch" \
    | head -1 | cut -d'"' -f4)

if [ -n "\$HEROIC_URL" ] && curl -fsSL "\$HEROIC_URL" -o "\$HEROIC_DEB" 2>/dev/null; then
    if dpkg -i "\$HEROIC_DEB" 2>/dev/null; then
        apt-get install -f -y 2>/dev/null || true
        echo "✓  Heroic Games Launcher instalado"
    else
        apt-get install -f -y 2>/dev/null || true
        echo "⚠  Heroic: dpkg con errores, dependencias resueltas"
    fi
else
    echo "⚠  Heroic: no se pudo descargar el .deb"
    echo "   Instalar tras primer boot desde https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases"
fi
rm -f "\$HEROIC_DEB"

# ============================================================================
# FAUGUS LAUNCHER (PPA oficial)
# ============================================================================
# PPA: ppa:faugus/faugus-launcher
# Ventajas sobre descargar .deb de GitHub: actualizaciones automáticas,
# gestión de dependencias limpia, sin necesidad de consultar GitHub API.
# ============================================================================

echo ""
echo "Instalando Faugus Launcher (PPA oficial)..."

if add-apt-repository -y ppa:faugus/faugus-launcher 2>/dev/null; then
    apt update 2>/dev/null || true
    if safe_apt faugus-launcher; then
        echo "✓  Faugus Launcher instalado (PPA oficial)"

        # Ocultar ImageMagick del menú (dependencia de Faugus, no útil para el usuario)
        if [ -n "\$USERNAME" ]; then
            for im in display-im7.q16.desktop display-im6.q16.desktop; do
                if [ -f "/usr/share/applications/\$im" ]; then
                    mkdir -p "/home/\$USERNAME/.local/share/applications"
                    cp "/usr/share/applications/\$im" "/home/\$USERNAME/.local/share/applications/\$im"
                    echo "NoDisplay=true" >> "/home/\$USERNAME/.local/share/applications/\$im"
                    chown \$(id -u \$USERNAME):\$(id -g \$USERNAME) \
                        "/home/\$USERNAME/.local/share/applications/\$im" 2>/dev/null || true
                    break
                fi
            done
        fi
    else
        echo "⚠  Faugus: apt falló tras añadir PPA"
        echo "   Instalar tras primer boot: sudo apt install faugus-launcher"
    fi
else
    echo "⚠  Faugus: no se pudo añadir PPA"
    echo "   Instalar tras primer boot: sudo add-apt-repository ppa:faugus/faugus-launcher && sudo apt install faugus-launcher"
fi

# ============================================================================
# ESTRUCTURA COMPARTIDA DE PROTON
# ============================================================================
# Ruta canónica única: ~/.local/share/Steam/compatibilitytools.d/
#
# Arquitectura:
#   - Steam:       lee compatibilitytools.d de forma nativa sin configuración.
#                  Necesita ~/.local/share/Steam/steamapps/libraryfolders.vdf
#                  para que Heroic pueda autodetectar la ruta de Steam.

#   - Heroic:      config.json → customWinePaths: array de rutas a BINARIOS
#                  de proton/wine (no al directorio padre).
#                  También necesita defaultInstallPath y defaultWinePrefix.
#   - Faugus:      config.ini → proton-path: directorio que contiene runners
#                  (escanea subdirectorios en busca del ejecutable "proton").
#
# NOTA CRÍTICA sobre customWinePaths en Heroic ≥ 2.x:
#   customWinePaths acepta rutas a DIRECTORIOS de runners (no al padre),
#   es decir, la ruta del binario "proton" sin el "/proton" al final.
#   Heroic escanea cada directorio listado y sus hijos directos.
#   Para que detecte TODOS los runners de compatibilitytools.d sin listar
#   cada uno individualmente, se lista el directorio padre (compatibilitytools.d)
#   Y Heroic lo escanea recursivamente un nivel.
#   Confirmado en logs reales: "customWinePaths": ["/path/to/dir"]
#
# NOTA sobre libraryfolders.vdf:
#   Heroic intenta leer ~/.local/share/Steam/steamapps/libraryfolders.vdf
#   para autodetectar la Steam library. Sin él, loguea
#   "Unable to load Steam Libraries, libraryfolders.vdf not found"
#   y no autodetecta runners de Steam. Se crea un VDF mínimo válido.
#
# NO se usan symlinks — cada app recibe su configuración declarativa real.
# ============================================================================

echo ""
echo "Configurando Proton compartido (Steam / Heroic / Faugus)..."

if [ -n "\$USERNAME" ]; then
    PROTON_DIR="/home/\$USERNAME/.local/share/Steam/compatibilitytools.d"
    STEAMAPPS_DIR="/home/\$USERNAME/.local/share/Steam/steamapps"
    mkdir -p "\$PROTON_DIR" "\$STEAMAPPS_DIR"

    # ── libraryfolders.vdf — necesario para que Heroic autodetermine Steam ────
    # Sin este archivo Heroic loguea "Unable to load Steam Libraries"
    # y no puede listar los runners instalados en compatibilitytools.d
    if [ ! -f "\$STEAMAPPS_DIR/libraryfolders.vdf" ]; then
        cat > "\$STEAMAPPS_DIR/libraryfolders.vdf" << VDFEOF
"libraryfolders"
{
    "0"
    {
        "path"      "/home/\$USERNAME/.local/share/Steam"
        "label"     ""
        "contentid" "0"
        "totalsize" "0"
        "update_clean_bytes_tally" "0"
        "time_last_update_corruption" "0"
        "apps"      {}
    }
}
VDFEOF
        echo "  ✓  Steam libraryfolders.vdf creado"
    fi

    # ── Configuración de Heroic Games Launcher ────────────────────────────────
    # Estructura confirmada en logs reales de Heroic ≥ 2.x (issue #1528, #4026):
    #
    #   customWinePaths: array de rutas — Heroic acepta rutas al DIRECTORIO PADRE
    #     (compatibilitytools.d). Heroic escanea un nivel de subdirectorios
    #     buscando ejecutables "proton" o "wine". Listar el padre es suficiente
    #     para que todos los runners instalados después aparezcan sin reconfigurar.
    #
    #   wineVersion: objeto con bin (ruta al ejecutable), name y type.
    #     - type "proton": usa el wrapper proton (para juegos de Windows)
    #     - bin: ruta COMPLETA al ejecutable "proton" dentro del runner
    #     Si no hay runner preinstalado, se deja null (Heroic elegirá el primero
    #     disponible o el usuario lo seleccionará manualmente).
    #
    #   defaultWinePrefix: directorio base para prefijos de juegos (no "winePrefix")
    #   defaultInstallPath: directorio base para instalar juegos de Heroic
    #   useSteamRuntime: false — usar nuestro Proton, no el Steam Runtime
    #   enableEsync/enableFsync: true — mejora rendimiento en juegos compatibles
    mkdir -p "/home/\$USERNAME/.config/heroic"

    cat > "/home/\$USERNAME/.config/heroic/config.json" << HEROIC_EOF
{
  "defaultSettings": {
    "customWinePaths": [
      "\$PROTON_DIR"
    ],
    "wineVersion": null,
    "defaultWinePrefix": "/home/\$USERNAME/Games/Heroic/Prefixes",
    "defaultInstallPath": "/home/\$USERNAME/Games/Heroic",
    "useSteamRuntime": false,
    "enableEsync": true,
    "enableFsync": true
  }
}
HEROIC_EOF
    echo "  ✓  Heroic: config.json escrito"

    # ── Configuración de Faugus Launcher ─────────────────────────────────────
    # proton-path: directorio que contiene los runners (Faugus escanea subdirectorios
    #   buscando el ejecutable "proton" en cada uno). Debe apuntar a
    #   compatibilitytools.d — el mismo directorio padre que usa Steam.
    # default-runner: nombre exacto del subdirectorio dentro de proton-path
    #   (sin ruta — Faugus construye la ruta completa internamente).
    #   Si está vacío, Faugus no preselecciona runner y el usuario elige en primer uso.
    # default-prefix: directorio base donde se crean los prefijos de Wine
    mkdir -p "/home/\$USERNAME/.config/faugus-launcher"

    cat > "/home/\$USERNAME/.config/faugus-launcher/config.ini" << FAUGUS_EOF
[Settings]
proton-path=\$PROTON_DIR
default-runner=
default-prefix=/home/\$USERNAME/Games/Faugus
FAUGUS_EOF
    echo "  ✓  Faugus: config.ini escrito (runner: \${FAUGUS_RUNNER:-detectar automáticamente})"

    # ── Directorios de prefijos de juegos ────────────────────────────────────
    mkdir -p \
        "/home/\$USERNAME/Games/Heroic/Prefixes" \
        "/home/\$USERNAME/Games/Faugus" \
        "/home/\$USERNAME/Games/Steam"

    # ── Permisos ──────────────────────────────────────────────────────────────
    chown -R \$(id -u \$USERNAME):\$(id -g \$USERNAME) \
        "/home/\$USERNAME/.local/share/Steam" \
        "/home/\$USERNAME/.config/heroic" \
        "/home/\$USERNAME/.config/faugus-launcher" \
        "/home/\$USERNAME/Games" 2>/dev/null || true

    echo ""
    echo "  Ruta canónica de Proton: \$PROTON_DIR"

    echo "  y serán detectadas automáticamente por Steam, Heroic y Faugus"
    echo "✓  Configuración de Proton compartido completada"
fi

# ============================================================================
# UDEV RULES — game-devices-udev (controladores)
# ============================================================================

echo ""
echo "Instalando udev rules para controladores..."

UDEV_TMP="/tmp/game-devices-udev"
mkdir -p "\$UDEV_TMP"

if wget --timeout=15 --tries=2 -q \
    "https://codeberg.org/fabiscafe/game-devices-udev/archive/main.zip" \
    -O "\$UDEV_TMP/main.zip" 2>/dev/null; then
    cd "\$UDEV_TMP"
    unzip -qo main.zip 2>/dev/null || true
    find . -name "71-*.rules" -exec cp {} /etc/udev/rules.d/ \; 2>/dev/null || true
    echo "uinput" > /etc/modules-load.d/uinput.conf
    echo "✓  udev rules instaladas"
else
    echo "⚠  udev rules: descarga falló (controladores funcionarán con reglas por defecto)"
fi
rm -rf "\$UDEV_TMP"
udevadm control --reload-rules 2>/dev/null || true

# ============================================================================
# SYSCTL + LÍMITES DEL SISTEMA
# ============================================================================

echo ""
echo "Aplicando optimizaciones del sistema..."

# Sysctl gaming
cat > /etc/sysctl.d/99-gaming.conf << 'SYSCTLEOF'
# Gaming optimizations
vm.max_map_count = 2147483642
vm.swappiness = 10
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-gaming.conf 2>/dev/null || true

# Límites del sistema
if ! grep -q "# Gaming optimizations" /etc/security/limits.conf 2>/dev/null; then
    cat >> /etc/security/limits.conf << 'LIMITSEOF'

# Gaming optimizations
*    soft    nofile    524288
*    hard    nofile    524288
*    soft    memlock   unlimited
*    hard    memlock   unlimited
LIMITSEOF
fi

echo "✓  sysctl + límites configurados"

CHROOTEOF

# ============================================================================
# VRR + HDR + EXPLICIT SYNC (GNOME — fuera del heredoc principal)
# ============================================================================
# GNOME 46-47: VRR y xwayland-native-scaling son experimental-features
# GNOME 48+:   xwayland-native-scaling permanece experimental;
#              VRR y HDR se activan desde Ajustes → Pantallas (settings estables)
# ============================================================================

if arch-chroot "$TARGET" command -v gnome-shell >/dev/null 2>&1; then
    GNOME_VER=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)

    if [ -n "$GNOME_VER" ] && [ "$GNOME_VER" -ge 46 ]; then
        echo ""
        echo "Configurando VRR/experimental-features para GNOME $GNOME_VER..."

        arch-chroot "$TARGET" /bin/bash << VRREOF
GNOME_VER=$GNOME_VER

# xwayland-native-scaling: escalado correcto para apps X11 en HiDPI — experimental en todas las versiones
# kms-modifiers: mejora compatibilidad DRM explicit sync (GNOME 47+)
FEATURES='["xwayland-native-scaling"]' 
[ "\$GNOME_VER" -ge 47 ] && FEATURES='["xwayland-native-scaling","kms-modifiers"]'

# Para GNOME < 48, VRR también va en experimental-features
if [ "\$GNOME_VER" -lt 48 ]; then
    [ "\$GNOME_VER" -ge 47 ] \
        && FEATURES='["xwayland-native-scaling","kms-modifiers","variable-refresh-rate"]' \
        || FEATURES='["xwayland-native-scaling","variable-refresh-rate"]'
fi

# Autostart autodestructivo: merge correcto con valores existentes
mkdir -p /etc/skel/.config/autostart
cat > "/etc/skel/.config/autostart/enable-experimental-features.desktop" << DESKEOF
[Desktop Entry]
Type=Application
Name=Enable GNOME experimental features
Exec=/bin/bash -c 'gsettings set org.gnome.mutter experimental-features "\$FEATURES" 2>/dev/null; rm -f ~/.config/autostart/enable-experimental-features.desktop'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKEOF
echo "✓  experimental-features se aplicarán en primer login (GNOME \$GNOME_VER)"
VRREOF
    fi
fi

# ============================================================================
# PROTONPLUS — compilación desde código fuente
# ============================================================================
# ProtonPlus es un gestor gráfico de herramientas de compatibilidad (Proton,
# Wine-GE, etc.) para Steam, Heroic, Lutris y Bottles. Escrito en Vala con
# GTK4 + Libadwaita. No está en los repos de Ubuntu — se compila con Meson.
#
# Dependencias de compilación: vala, meson, ninja-build, libgee, libadwaita,
# libsoup3, json-glib, libarchive, gettext, desktop-file-utils.
# Dependencias de runtime: todas son libs del sistema (GTK4, Adwaita, libsoup3).
# ============================================================================

# ============================================================================
# PROTONPLUS — compilación desde código fuente
# ============================================================================
# ProtonPlus es un gestor gráfico de herramientas de compatibilidad (GE-Proton,
# Wine-GE, etc.) para Steam, Heroic, Lutris y Bottles. Escrito en Vala con
# GTK4 + Libadwaita. No está en los repos de Ubuntu — se compila con Meson.
#
# REQUISITO: libadwaita >= 1.6
#   Ubuntu 24.04 (noble) tiene libadwaita 1.5.0 en repositorios.
#   Si la versión del sistema es < 1.6, se usa meson --force-fallback-for=libadwaita
#   para compilar libadwaita 1.6 como subproyecto (wrap file del propio ProtonPlus).
#   El resultado final se instala en /usr/local y el .so queda en /usr/local/lib.
#
# TEST DE APPSTREAM: siempre se salta — bug conocido upstream donde la imagen
#   Preview-1.png excede 900px de alto y falla la validación de metainfo.xml.
#   No afecta al binario ni a la funcionalidad.
# ============================================================================

if [ "${INSTALL_PROTONPLUS:-false}" = "true" ]; then
    echo ""
    echo "Compilando ProtonPlus desde código fuente..."

    arch-chroot "$TARGET" /bin/bash << 'PPEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# ── Dependencias de compilación ───────────────────────────────────────────────
# Dependencias declaradas en el README oficial de ProtonPlus.
# sassc: requerido por libadwaita cuando se compila como subproyecto (genera CSS).
# gobject-introspection: requerido para compilar libadwaita como subproyecto.
apt-get install -y --no-install-recommends \
    git \
    meson \
    ninja-build \
    valac \
    gettext \
    desktop-file-utils \
    appstream \
    libappstream-dev \
    sassc \
    gobject-introspection \
    libglib2.0-dev \
    libgee-0.8-dev \
    libgtk-4-dev \
    libjson-glib-dev \
    libadwaita-1-dev \
    libarchive-dev \
    libsoup-3.0-dev \
    libgirepository1.0-dev

echo "  ✓ Dependencias instaladas"

# ── Clonar ProtonPlus (último tag estable) ────────────────────────────────────
BUILD_DIR="$(mktemp -d /tmp/protonplus-build.XXXXXX)"
cd "$BUILD_DIR"

git clone --filter=blob:none https://github.com/Vysp3r/ProtonPlus.git
cd ProtonPlus

# Seleccionar último tag semántico estable (vX.Y.Z)
LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -n "$LATEST_TAG" ]; then
    git checkout "$LATEST_TAG" --quiet
    echo "  Versión: $LATEST_TAG"
else
    echo "  Versión: main (no se encontró tag semántico)"
fi

# ── Detectar si libadwaita del sistema cumple >= 1.6 ─────────────────────────
ADW_VERSION=$(pkg-config --modversion libadwaita-1 2>/dev/null || echo "0")
ADW_MAJOR=$(echo "$ADW_VERSION" | cut -d. -f1)
ADW_MINOR=$(echo "$ADW_VERSION" | cut -d. -f2)

echo "  libadwaita del sistema: $ADW_VERSION"

MESON_EXTRA_OPTS=""
if [ "$ADW_MAJOR" -lt 1 ] || { [ "$ADW_MAJOR" -eq 1 ] && [ "$ADW_MINOR" -lt 6 ]; }; then
    echo "  libadwaita < 1.6 — se compilará como subproyecto meson (wrap)"
    # ProtonPlus incluye subprojects/libadwaita.wrap — meson lo usa automáticamente
    # con --force-fallback-for. Requiere sassc + gobject-introspection (ya instalados).
    MESON_EXTRA_OPTS="--force-fallback-for=libadwaita"
fi

# ── Compilar ──────────────────────────────────────────────────────────────────
echo "  Configurando meson..."
meson setup build \
    --prefix=/usr/local \
    --buildtype=plain \
    $MESON_EXTRA_OPTS

echo "  Compilando..."
meson compile -C build

# ── Instalar (saltando tests) ─────────────────────────────────────────────────
# El test "Validate appstream file" siempre falla en ProtonPlus por un bug
# upstream (screenshot de 1072px > máximo 900px en metainfo.xml). Es cosmético
# y no afecta al binario. Se instala directamente sin ejecutar tests.
echo "  Instalando..."
meson install -C build

# ── Actualizar caché de librerías si se compiló libadwaita como subproyecto ──
if [ -n "$MESON_EXTRA_OPTS" ]; then
    echo "/usr/local/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/protonplus-local.conf
    ldconfig
    echo "  ✓ ldconfig actualizado para libadwaita local"
fi

# ── Registrar schemas de GSettings instalados en /usr/local ──────────────────
# meson install los pone en /usr/local/share/glib-2.0/schemas/
# glib-compile-schemas del sistema solo lee /usr/share — hay que compilar también
# el directorio local para que ProtonPlus encuentre sus schemas en runtime.
if [ -d /usr/local/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/local/share/glib-2.0/schemas/
    echo "  ✓ GSettings schemas compilados en /usr/local"
fi

# ── Limpieza: eliminar dependencias de compilación ───────────────────────────
cd /
rm -rf "$BUILD_DIR"

apt-get autoremove --purge -y \
    valac \
    meson \
    ninja-build \
    sassc \
    gobject-introspection \
    libglib2.0-dev \
    libgee-0.8-dev \
    libgtk-4-dev \
    libjson-glib-dev \
    libadwaita-1-dev \
    libarchive-dev \
    libsoup-3.0-dev \
    libgirepository1.0-dev \
    libappstream-dev \
    2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

echo "✓  ProtonPlus instalado correctamente"
echo "   Binario: /usr/local/bin/protonplus"

PPEOF

fi

# ============================================================================
# MANGOJUICE — compilación desde código fuente
# ============================================================================
# MangoJuice es una GUI GTK4/Libadwaita para configurar MangoHud, alternativa
# a GOverlay. Escrita en Vala. No está en los repos de Ubuntu — se compila
# con Meson desde https://github.com/radiolamp/mangojuice
#
# Dependencias de compilación: vala, meson, ninja-build, cmake, gcc,
#   libgtk-4-dev, libadwaita-1-dev, libglib2.0-dev, libgee-0.8-dev,
#   libfontconfig-dev.
# Dependencias de runtime: GTK4, Libadwaita, libgee, fontconfig, mangohud
#   (ya instalado como paquete en este módulo).
# Dependencias opcionales: mesa-utils, vulkan-tools (para test buttons).
# ============================================================================

echo ""
echo "Compilando MangoJuice desde código fuente..."

arch-chroot "$TARGET" /bin/bash << 'MJEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# ── Dependencias de compilación ───────────────────────────────────────────────
apt-get install -y --no-install-recommends \
    git \
    meson \
    ninja-build \
    cmake \
    gcc \
    valac \
    gettext \
    desktop-file-utils \
    libglib2.0-dev \
    libgee-0.8-dev \
    libgtk-4-dev \
    libadwaita-1-dev \
    libfontconfig-dev

echo "  ✓ Dependencias de MangoJuice instaladas"

# ── Clonar MangoJuice (último tag estable) ────────────────────────────────────
BUILD_DIR="$(mktemp -d /tmp/mangojuice-build.XXXXXX)"
cd "$BUILD_DIR"

git clone --filter=blob:none https://github.com/radiolamp/mangojuice.git
cd mangojuice

# Seleccionar último tag semántico estable
LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -n "$LATEST_TAG" ]; then
    git checkout "$LATEST_TAG" --quiet
    echo "  Versión: $LATEST_TAG"
else
    echo "  Versión: main (no se encontró tag semántico)"
fi

# ── Compilar ──────────────────────────────────────────────────────────────────
echo "  Configurando meson..."
meson setup build \
    --prefix=/usr/local \
    --buildtype=plain

echo "  Compilando..."
meson compile -C build

echo "  Instalando..."
meson install -C build

# ── Registrar schemas de GSettings si existen ─────────────────────────────────
if [ -d /usr/local/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/local/share/glib-2.0/schemas/
    echo "  ✓ GSettings schemas compilados en /usr/local"
fi

# ── Limpieza: eliminar dependencias de compilación ───────────────────────────
cd /
rm -rf "$BUILD_DIR"

apt-get autoremove --purge -y \
    valac \
    meson \
    ninja-build \
    cmake \
    libglib2.0-dev \
    libgee-0.8-dev \
    libgtk-4-dev \
    libadwaita-1-dev \
    libfontconfig-dev \
    2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

echo "✓  MangoJuice instalado correctamente"
echo "   Binario: /usr/local/bin/mangojuice"

MJEOF

# ── Sync skel → home del usuario ─────────────────────────────────────────────
# Los módulos de gaming escriben en /etc/skel/ (chrome-flags, autostart VRR)
# después de que useradd -m ya creó el home. Se copian aquí explícitamente.
arch-chroot "$TARGET" /bin/bash << SKELEOF
if [ -n "$USERNAME" ] && id "$USERNAME" >/dev/null 2>&1; then
    cp -a --no-clobber /etc/skel/. "/home/$USERNAME/"
    chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME"
    echo "✓  skel sincronizado → /home/$USERNAME"
fi
SKELEOF

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GAMING COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  GPU: $GPU_CONFIG"
echo "  Steam (PPA Valve) + Heroic (PPA oficial) + Faugus (PPA oficial)"
[ "${INSTALL_PROTONPLUS:-false}" = "true" ] && echo "  ProtonPlus (compilado desde fuente)"
echo "  GameMode + MangoHud + MangoJuice"
echo "  VA-API HW + Wayland nativo (GDK/Qt/SDL/EGL)"
echo "  sysctl gaming + udev rules controladores"
echo ""

exit 0
