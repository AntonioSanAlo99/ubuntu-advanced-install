#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 24: Configurar gaming
# Steam (PPA Valve) + Heroic (.deb GitHub) + Faugus (PPA oficial) + drivers GPU
# Compatible con bare metal, VM con GPU passthrough y VM sin GPU dedicada
# ══════════════════════════════════════════════════════════════════════════════

# No usar set -e — muchos comandos pueden fallar legitimamente (drivers,
# descargas, detección de hardware en VM). Cada sección maneja sus errores.

[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


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

# ── Preguntas opcionales ────────────────────────────────────────────────────
if [ -z "$INSTALL_DISCORD" ]; then
    read -p "¿Instalar Discord? (s/n) [n]: " INSTALL_DISCORD
    INSTALL_DISCORD=${INSTALL_DISCORD:-n}
fi

if [ -z "$INSTALL_UNIGINE" ]; then
    read -p "¿Instalar Unigine Heaven benchmark? (s/n) [n]: " INSTALL_UNIGINE
    INSTALL_UNIGINE=${INSTALL_UNIGINE:-n}
fi

# ============================================================================
# BLOQUE CHROOT PRINCIPAL
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

USERNAME="$USERNAME"
GPU_CONFIG="$GPU_CONFIG"
INSTALL_DISCORD="$INSTALL_DISCORD"
INSTALL_UNIGINE="$INSTALL_UNIGINE"

# Función auxiliar: instalar paquetes sin fallar si alguno no existe
safe_apt() {
    apt-get install -y "\$@" 2>/dev/null || true
}

# ============================================================================
# HABILITAR i386 Y MESA BASE
# ============================================================================

echo ""
echo "Habilitando arquitectura i386..."

dpkg --add-architecture i386
apt-get update -qq

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

    safe_apt ubuntu-drivers-common

    S76_PPA=false
    if add-apt-repository -y ppa:system76-dev/stable 2>/dev/null; then
        apt-get update -qq || true
        if apt-get install -y system76-driver-nvidia; then
            S76_PPA=true
            echo "  ✓ NVIDIA instalado vía PPA System76 (system76-driver-nvidia)"
        else
            echo "  ⚠ system76-driver-nvidia falló — probando ubuntu-drivers"
            add-apt-repository -ry ppa:system76-dev/stable 2>/dev/null || true
            apt-get update -qq || true
        fi
    fi

    if [ "\$S76_PPA" = "false" ]; then
        if ubuntu-drivers install 2>/dev/null; then
            echo "  ✓ NVIDIA instalado vía ubuntu-drivers"
        else
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

    safe_apt nvidia-vaapi-driver libva2 libva-drm2 libva-x11-2 libva-wayland2 vainfo

    if dpkg -l 2>/dev/null | grep -q "^ii.*nvidia-driver"; then
        NVIDIA_VER=\$(dpkg -l 2>/dev/null | grep "^ii.*nvidia-driver-[0-9]" | head -1 | awk '{print \$3}')
        echo "  ✓ NVIDIA driver instalado: \${NVIDIA_VER:-versión desconocida}"
    else
        echo "  ⚠ NVIDIA: driver no confirmado en chroot"
        echo "    Ejecutar tras primer boot: sudo ubuntu-drivers install"
    fi

    # ── Fix GSK renderer para NVIDIA ─────────────────────────────────────────
    # GTK4 usa Vulkan por defecto en Wayland (desde GTK 4.16). En NVIDIA,
    # el renderer Vulkan de GSK causa glitches, labels vacíos y crashes.
    # Workaround oficial: forzar el renderer OpenGL NGL.
    # Ref: LP#2061079, LP#2081291, ArchWiki GTK#GSK_RENDERER
    if ! grep -q "GSK_RENDERER" /etc/environment 2>/dev/null; then
        echo "GSK_RENDERER=ngl" >> /etc/environment
        echo "  ✓ Fix GSK: GSK_RENDERER=ngl añadido a /etc/environment"
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
        echo "  VM detectada — usando Mesa/llvmpipe (software rendering)"
        echo "  Si tienes GPU passthrough, vuelve a ejecutar con la GPU correcta"
        ;;
    *)
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

echo ""
echo "Configurando aceleración hardware y Wayland nativo..."

add_env_var() {
    local key="\$1" val="\$2"
    if grep -q "^\${key}=" /etc/environment 2>/dev/null; then
        sed -i "s|^\${key}=.*|\${key}=\${val}|" /etc/environment
    else
        echo "\${key}=\${val}" >> /etc/environment
    fi
}

# GStreamer: expone todos los drivers VA-API disponibles a GStreamer
add_env_var "GST_VAAPI_ALL_DRIVERS" "1"

# Qt6: Wayland nativo, fallback xcb para apps que no soporten Wayland
add_env_var "QT_QPA_PLATFORM" "wayland;xcb"

# SDL2/SDL3: Wayland nativo — SDL solo acepta un valor, no lista
add_env_var "SDL_VIDEODRIVER" "wayland"

echo "✓  Variables de entorno escritas en /etc/environment"

# ── Chrome/Chromium: flags Wayland + VA-API ──────────────────────────────────
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

# ============================================================================
# GAMEMODE + MANGOHUD
# ============================================================================
# ⚠ falcond y Feral GameMode conflictan entre sí (documentado por PikaOS).
# Si falcond está activado, se omite gamemode — falcond cubre su funcionalidad.

echo ""
if [ "${INSTALL_FALCOND:-false}" = "true" ]; then
    echo "Omitiendo GameMode (Feral) — falcond activado (conflicto documentado)"
    safe_apt mangohud
    echo "✓  MangoHud instalado (GameMode omitido por falcond)"
else
    echo "Instalando GameMode y MangoHud..."
    safe_apt gamemode mangohud
    echo "✓  GameMode y MangoHud instalados"
fi

# ============================================================================
# STEAM — método GLFS 13.0 (glfs-book.github.io/glfs/steam/steam.html)
# ============================================================================
# Instalación GLFS: tarball + ln -sf /usr/bin/true steamdeps + make install
# steamdeps se anula para que Steam no ejecute su script APT de dependencias.
#
# Las dependencias del host se instalan previamente para que Steam arranque
# directo sin necesitar steamdeps ni chequeos en primer boot.
#
# Fuentes para la lista de dependencias:
#   - GLFS required:    alsa-plugins, curl, dbus, libglvnd, ca-certificates
#   - GLFS recommended: vulkan, pulseaudio, xdg-user-dirs, zenity, lsof, libgpg-error
#   - Arch PKGBUILD:    depends + depends_x86_64 (referencia canónica de deps mínimas)

echo ""
echo "Instalando dependencias de Steam..."
safe_apt \
    libasound2-plugins:amd64 libasound2-plugins:i386 \
    curl dbus ca-certificates \
    libglvnd0:amd64 libglvnd0:i386 \
    libgl1:amd64 libgl1:i386 \
    libegl1:amd64 libegl1:i386 \
    libgl1-mesa-dri:amd64 libgl1-mesa-dri:i386 \
    libgbm1:amd64 libgbm1:i386 \
    libx11-6:amd64 libx11-6:i386 \
    libxss1:amd64 libxss1:i386 \
    libnss3:amd64 libnss3:i386 \
    libgpg-error0:amd64 libgpg-error0:i386 \
    libgcc-s1:amd64 libgcc-s1:i386 \
    libc6:amd64 libc6:i386 \
    libvulkan1:amd64 libvulkan1:i386 \
    mesa-vulkan-drivers:amd64 mesa-vulkan-drivers:i386 \
    libfreetype6 libgdk-pixbuf2.0-0 fonts-liberation \
    zenity lsof xdg-user-dirs \
    desktop-file-utils hicolor-icon-theme python3 diffutils \
    make
echo "✓  Dependencias de Steam instaladas"

echo ""
echo "Instalando Steam (GLFS 13.0)..."

STEAM_VER="1.0.0.85"
STEAM_TAR="/tmp/steam_\${STEAM_VER}.tar.gz"
STEAM_URL="https://repo.steampowered.com/steam/archive/precise/steam_\${STEAM_VER}.tar.gz"

wget --timeout=30 --tries=2 -q "\$STEAM_URL" -O "\$STEAM_TAR"
mkdir -p /tmp/steam-build
tar xf "\$STEAM_TAR" -C /tmp/steam-build
cd /tmp/steam-build/steam-launcher

ln -sf /usr/bin/true steamdeps
make install
mv -v /usr/share/doc/steam{,-\${STEAM_VER}}

cd /
rm -rf /tmp/steam-build "\$STEAM_TAR"
echo "✓  Steam \${STEAM_VER} instalado"

# ── Bloquear paquete steam de repos APT para prevenir duplicación ────────
# Steam se instaló via GLFS tarball (make install). Si el usuario añade el PPA
# de Valve o si algún paquete tira de steam-launcher como dependencia, apt
# intentaría sobreescribir la instalación GLFS. Este pin lo impide.
cat > /etc/apt/preferences.d/no-steam-apt << 'PINEOF'
# Bloquear instalación de Steam via APT — ya instalado via GLFS tarball
Package: steam steam-launcher steam-installer steam-libs-amd64 steam-libs-i386
Pin: release *
Pin-Priority: -1
PINEOF
echo "  ✓  apt pin: steam bloqueado para prevenir duplicación"

# ── Estructura de directorios de Steam para el usuario ────────────────────
# Steam espera ~/.steam/steam → ~/.local/share/Steam (symlink canónico).
# compatibilitytools.d/ es donde se colocan builds de Proton custom (GE, TKG).
if [ -n "\$USERNAME" ]; then
    STEAM_HOME="/home/\$USERNAME"

    install -d -o "\$USERNAME" -g "\$USERNAME" \
        "\$STEAM_HOME/.local/share/Steam/compatibilitytools.d" \
        "\$STEAM_HOME/.steam"

    ln -sfn "\$STEAM_HOME/.local/share/Steam" "\$STEAM_HOME/.steam/steam"
    ln -sfn "\$STEAM_HOME/.local/share/Steam" "\$STEAM_HOME/.steam/root"
    chown -h "\$USERNAME:\$USERNAME" "\$STEAM_HOME/.steam/steam" "\$STEAM_HOME/.steam/root"
fi

# ============================================================================
# HEROIC GAMES LAUNCHER (.deb desde GitHub releases)
# ============================================================================

echo ""
echo "Instalando Heroic Games Launcher..."

HEROIC_DEB=\$(mktemp /tmp/heroic-XXXXXX.deb)
HEROIC_URL=\$(curl -fsSL https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest \
    2>/dev/null | grep "browser_download_url" | grep "\.deb" | grep -v "arm\|aarch" \
    | head -1 | cut -d'"' -f4)

if [ -n "\$HEROIC_URL" ] && curl -fsSL "\$HEROIC_URL" -o "\$HEROIC_DEB" 2>/dev/null; then
    dpkg -i "\$HEROIC_DEB" || true
    apt-get install -f -y 2>/dev/null || true
    echo "✓  Heroic Games Launcher instalado"
else
    echo "⚠  Heroic: no se pudo descargar el .deb"
fi
rm -f "\$HEROIC_DEB"

# ============================================================================
# FAUGUS LAUNCHER (PPA oficial)
# ============================================================================

echo ""
echo "Instalando Faugus Launcher (PPA oficial)..."

if add-apt-repository -y ppa:faugus/faugus-launcher 2>/dev/null; then
    apt-get update -qq || true
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
    fi
else
    echo "⚠  Faugus: no se pudo añadir PPA"
fi

# ============================================================================
# ESTRUCTURA COMPARTIDA DE PROTON
# ============================================================================
# Ruta canónica única: ~/.local/share/Steam/compatibilitytools.d/
# Steam, Heroic y Faugus comparten esta ruta vía configuración declarativa.
# ============================================================================

echo ""
echo "Configurando Proton compartido (Steam / Heroic / Faugus)..."

if [ -n "\$USERNAME" ]; then
    PROTON_DIR="/home/\$USERNAME/.local/share/Steam/compatibilitytools.d"
    STEAMAPPS_DIR="/home/\$USERNAME/.local/share/Steam/steamapps"
    mkdir -p "\$PROTON_DIR" "\$STEAMAPPS_DIR"

    # ── libraryfolders.vdf — necesario para que Heroic autodetermine Steam ────
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
    mkdir -p "/home/\$USERNAME/.config/faugus-launcher"
    cat > "/home/\$USERNAME/.config/faugus-launcher/config.ini" << FAUGUS_EOF
[Settings]
proton-path=\$PROTON_DIR
default-runner=
default-prefix=/home/\$USERNAME/Games/Faugus
FAUGUS_EOF
    echo "  ✓  Faugus: config.ini escrito"

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

    echo "  Ruta canónica de Proton: \$PROTON_DIR"
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
# CPU-X (info de hardware tipo CPU-Z)
# ============================================================================

echo ""
echo "Instalando CPU-X..."
safe_apt cpu-x
echo "✓  CPU-X instalado"

# ============================================================================
# DISCORD (opcional — .deb desde sitio oficial)
# ============================================================================

if [[ "\$INSTALL_DISCORD" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Discord..."

    if wget --timeout=30 --tries=2 -q "https://discord.com/api/download?platform=linux&format=deb" \
         -O /tmp/discord.deb 2>/dev/null && [ -s /tmp/discord.deb ]; then
        dpkg -i /tmp/discord.deb || true
        apt-get install -f -y 2>/dev/null || true
        rm -f /tmp/discord.deb

        if command -v discord >/dev/null 2>&1; then
            echo "  ✓ Discord instalado"
        else
            echo "  ⚠ Discord: instalación falló"
        fi
    else
        echo "  ⚠ Discord: descarga falló — https://discord.com/download"
    fi
else
    echo "⊘ Discord no instalado"
fi

# ============================================================================
# UNIGINE HEAVEN BENCHMARK (opcional — .run desde assets.unigine.com)
# ============================================================================
# Se descarga el .run de Heaven 4.0 y se extrae a /opt/unigine-heaven/.
# Requiere OpenGL y libs de 64 bits (ya instaladas por Mesa+drivers).

if [[ "\$INSTALL_UNIGINE" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Unigine Heaven benchmark..."

    HEAVEN_RUN="/tmp/Unigine_Heaven-4.0.run"
    HEAVEN_URL="https://assets.unigine.com/d/Unigine_Heaven-4.0.run"

    if wget --timeout=60 --tries=2 -q "\$HEAVEN_URL" -O "\$HEAVEN_RUN" 2>/dev/null \
       && [ -s "\$HEAVEN_RUN" ]; then
        chmod 755 "\$HEAVEN_RUN"
        # Extraer sin ejecutar: --nox11 --noexec --target
        "\$HEAVEN_RUN" --nox11 --noexec --target /opt/unigine-heaven 2>/dev/null || true

        if [ -d /opt/unigine-heaven ]; then
            # Crear .desktop para que aparezca en el menú
            cat > /usr/share/applications/unigine-heaven.desktop << 'HEAVENDESKTOP'
[Desktop Entry]
Type=Application
Name=Unigine Heaven
Comment=GPU Benchmark (OpenGL 4.0)
Exec=/opt/unigine-heaven/heaven
Icon=/opt/unigine-heaven/data/launcher/icon.png
Categories=Game;
Terminal=false
HEAVENDESKTOP
            # Permisos para el usuario
            if [ -n "\$USERNAME" ]; then
                chown -R "\$USERNAME:\$USERNAME" /opt/unigine-heaven 2>/dev/null || true
            fi
            echo "  ✓ Unigine Heaven instalado en /opt/unigine-heaven/"
        else
            echo "  ⚠ Unigine Heaven: extracción falló"
        fi
        rm -f "\$HEAVEN_RUN"
    else
        echo "  ⚠ Unigine Heaven: descarga falló — https://benchmark.unigine.com/heaven"
    fi
else
    echo "⊘ Unigine Heaven no instalado"
fi

# ============================================================================
# SYSCTL + LÍMITES DEL SISTEMA
# ============================================================================

echo ""
echo "Aplicando optimizaciones del sistema..."

cat > /etc/sysctl.d/99-gaming.conf << 'SYSCTLEOF'
# Gaming optimizations
vm.max_map_count = 2147483642
vm.swappiness = 10
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-gaming.conf 2>/dev/null || true

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
# VRR + HDR + EXPLICIT SYNC (heredoc independiente — fuera de CHROOTEOF)
# ============================================================================
# GNOME 46-47: VRR y xwayland-native-scaling son experimental-features
# GNOME 48+:   VRR y HDR se activan desde Ajustes → Pantallas
# ============================================================================

if arch-chroot "$TARGET" command -v gnome-shell >/dev/null 2>&1; then
    GNOME_VER=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)

    if [ -n "$GNOME_VER" ] && [ "$GNOME_VER" -ge 46 ]; then
        echo ""
        echo "Configurando VRR/experimental-features para GNOME $GNOME_VER..."

        arch-chroot "$TARGET" /bin/bash << VRREOF
GNOME_VER=$GNOME_VER

FEATURES='["xwayland-native-scaling"]'
[ "\$GNOME_VER" -ge 47 ] && FEATURES='["xwayland-native-scaling","kms-modifiers"]'

if [ "\$GNOME_VER" -lt 48 ]; then
    [ "\$GNOME_VER" -ge 47 ] \
        && FEATURES='["xwayland-native-scaling","kms-modifiers","variable-refresh-rate"]' \
        || FEATURES='["xwayland-native-scaling","variable-refresh-rate"]'
fi

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
# PROTONPLUS — compilación desde código fuente (heredoc independiente)
# ============================================================================

if [ "${INSTALL_PROTONPLUS:-false}" = "true" ]; then
    echo ""
    echo "Compilando ProtonPlus desde código fuente..."

    arch-chroot "$TARGET" /bin/bash << 'PPEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get install -y \
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

BUILD_DIR="$(mktemp -d /tmp/protonplus-build.XXXXXX)"
cd "$BUILD_DIR"

git clone --filter=blob:none https://github.com/Vysp3r/ProtonPlus.git
cd ProtonPlus

LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -n "$LATEST_TAG" ]; then
    git checkout "$LATEST_TAG" --quiet
    echo "  Versión: $LATEST_TAG"
else
    echo "  Versión: main (no se encontró tag semántico)"
fi

ADW_VERSION=$(pkg-config --modversion libadwaita-1 2>/dev/null || echo "0")
ADW_MAJOR=$(echo "$ADW_VERSION" | cut -d. -f1)
ADW_MINOR=$(echo "$ADW_VERSION" | cut -d. -f2)

echo "  libadwaita del sistema: $ADW_VERSION"

MESON_EXTRA_OPTS=""
if [ "$ADW_MAJOR" -lt 1 ] || { [ "$ADW_MAJOR" -eq 1 ] && [ "$ADW_MINOR" -lt 6 ]; }; then
    echo "  libadwaita < 1.6 — se compilará como subproyecto meson (wrap)"
    MESON_EXTRA_OPTS="--force-fallback-for=libadwaita"
fi

echo "  Configurando meson..."
meson setup build --prefix=/usr --buildtype=plain $MESON_EXTRA_OPTS

echo "  Compilando..."
meson compile -C build

echo "  Instalando..."
meson install -C build

if [ -n "$MESON_EXTRA_OPTS" ]; then
    echo "/usr/lib/x86_64-linux-gnu" >> /etc/ld.so.conf.d/protonplus-local.conf
    ldconfig
    echo "  ✓ ldconfig actualizado para libadwaita local"
fi

if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "  ✓ GSettings schemas compilados"
fi

cd /
rm -rf "$BUILD_DIR"

apt-get remove --purge -y \
    valac meson ninja-build sassc gobject-introspection \
    libglib2.0-dev libgee-0.8-dev libgtk-4-dev libjson-glib-dev \
    libadwaita-1-dev libarchive-dev libsoup-3.0-dev \
    libgirepository1.0-dev libappstream-dev \
    2>/dev/null || true

echo "✓  ProtonPlus instalado correctamente"
PPEOF

fi

# ============================================================================
# MANGOJUICE — compilación desde código fuente (heredoc independiente)
# ============================================================================

echo ""
echo "Compilando MangoJuice desde código fuente..."

arch-chroot "$TARGET" /bin/bash << 'MJEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get install -y \
    git meson ninja-build cmake gcc valac gettext desktop-file-utils \
    libglib2.0-dev libgee-0.8-dev libgtk-4-dev libadwaita-1-dev libfontconfig-dev

echo "  ✓ Dependencias de MangoJuice instaladas"

BUILD_DIR="$(mktemp -d /tmp/mangojuice-build.XXXXXX)"
cd "$BUILD_DIR"

git clone --filter=blob:none https://github.com/radiolamp/mangojuice.git
cd mangojuice

LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -n "$LATEST_TAG" ]; then
    git checkout "$LATEST_TAG" --quiet
    echo "  Versión: $LATEST_TAG"
else
    echo "  Versión: main (no se encontró tag semántico)"
fi

echo "  Configurando meson..."
meson setup build --prefix=/usr --buildtype=plain

echo "  Compilando..."
meson compile -C build

echo "  Instalando..."
meson install -C build

if [ -d /usr/share/icons/hicolor ]; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    echo "  ✓ Caché de iconos actualizado"
fi

if [ -d /usr/share/glib-2.0/schemas ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "  ✓ GSettings schemas compilados en /usr/local"
fi

cd /
rm -rf "$BUILD_DIR"

apt-get remove --purge -y \
    valac meson ninja-build cmake \
    libglib2.0-dev libgee-0.8-dev libgtk-4-dev libadwaita-1-dev libfontconfig-dev \
    2>/dev/null || true

echo "✓  MangoJuice instalado correctamente"
MJEOF

# ============================================================================
# KERNEL CACHYOS — compilación desde fuente (heredoc independiente)
# ============================================================================
# El kernel CachyOS aplica los parches del proyecto CachyOS sobre el último
# mainline, con scheduler BORE o EEVDF, BBR3, CONFIG_CACHY y optimizaciones
# de latencia. Se compila como .deb con make deb-pkg.
# ============================================================================

if [ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ]; then
    echo ""
    echo "Compilando kernel CachyOS desde fuente..."
    echo "  Scheduler: $([ "${CACHYOS_SCHEDULER:-1}" = "1" ] && echo "BORE" || echo "EEVDF")"

    arch-chroot "$TARGET" /bin/bash << CACHYEOF
set -e
export DEBIAN_FRONTEND=noninteractive

# Dependencias de compilación
apt-get install -y \
    git build-essential bc kmod cpio flex libncurses-dev \
    libelf-dev libssl-dev dwarves bison lz4 zstd \
    debhelper rsync python3 2>/dev/null

echo "  ✓ Dependencias de compilación instaladas"

BUILD_DIR="\$(mktemp -d /tmp/cachyos-kernel.XXXXXX)"
cd "\$BUILD_DIR"

# Clonar fuentes del kernel CachyOS (PKGBUILD + parches)
git clone --depth 1 https://github.com/CachyOS/linux-cachyos.git
cd linux-cachyos

# Elegir variante según scheduler
SCHED="${CACHYOS_SCHEDULER:-1}"
if [ "\$SCHED" = "2" ]; then
    # EEVDF — usar linux-cachyos (variante default, EEVDF tuneado)
    cd linux-cachyos
    SCHED_NAME="eevdf"
else
    # BORE — usar linux-cachyos-bore
    if [ -d ../linux-cachyos-bore ]; then
        cd ../linux-cachyos-bore
    fi
    SCHED_NAME="bore"
fi

echo "  Variante: linux-cachyos-\$SCHED_NAME"

# Obtener versión del kernel desde PKGBUILD
KVER=\$(grep -oP '^pkgver=\K.*' PKGBUILD 2>/dev/null || echo "")
KSRC=\$(grep -oP '^_srcname=\K.*' PKGBUILD 2>/dev/null || echo "")

if [ -z "\$KVER" ]; then
    echo "  ⚠ No se pudo extraer versión del PKGBUILD — abortando"
    cd /; rm -rf "\$BUILD_DIR"
    exit 0
fi

echo "  Versión kernel: \$KVER"

# Descargar tarball del kernel
KMAJOR=\$(echo "\$KVER" | cut -d. -f1)
TARBALL="linux-\$KVER.tar.xz"
echo "  Descargando kernel \$KVER..."
wget -q "https://cdn.kernel.org/pub/linux/kernel/v\${KMAJOR}.x/\$TARBALL" -O "\$TARBALL" 2>/dev/null \
    || wget -q "https://mirrors.edge.kernel.org/pub/linux/kernel/v\${KMAJOR}.x/\$TARBALL" -O "\$TARBALL" 2>/dev/null

if [ ! -f "\$TARBALL" ]; then
    echo "  ⚠ Descarga del kernel fallida — abortando"
    cd /; rm -rf "\$BUILD_DIR"
    exit 0
fi

tar xf "\$TARBALL"
cd "linux-\$KVER"

# Aplicar parches CachyOS
echo "  Aplicando parches CachyOS..."
for p in ../\$KSRC/*.patch ../*.patch; do
    [ -f "\$p" ] && patch -Np1 -i "\$p" 2>/dev/null && echo "    ✓ \$(basename \$p)" || true
done

# Aplicar config CachyOS
if [ -f ../config ]; then
    cp ../config .config
    echo "  ✓ Config CachyOS aplicada"
else
    # Fallback: config actual + opciones CachyOS clave
    make olddefconfig
fi

# Ajustes clave
scripts/config --enable CONFIG_CACHY 2>/dev/null || true
scripts/config --set-val CONFIG_HZ 1000 2>/dev/null || true
scripts/config --enable CONFIG_HZ_1000 2>/dev/null || true
scripts/config --disable CONFIG_HZ_250 2>/dev/null || true
scripts/config --enable CONFIG_PREEMPT 2>/dev/null || true
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY 2>/dev/null || true
scripts/config --enable CONFIG_TCP_CONG_BBR 2>/dev/null || true
scripts/config --set-str CONFIG_DEFAULT_TCP_CONG "bbr" 2>/dev/null || true
scripts/config --enable CONFIG_THP_ALWAYS 2>/dev/null || true

# Scheduler específico
if [ "\$SCHED_NAME" = "bore" ]; then
    scripts/config --enable CONFIG_SCHED_BORE 2>/dev/null || true
    echo "  ✓ Scheduler BORE activado"
else
    echo "  ✓ Scheduler EEVDF (default tuneado)"
fi

# sched-ext support
scripts/config --enable CONFIG_SCHED_CLASS_EXT 2>/dev/null || true
scripts/config --enable CONFIG_BPF_SYSCALL 2>/dev/null || true

make olddefconfig

# Compilar como .deb
NPROC=\$(nproc)
echo "  Compilando con \$NPROC hilos (esto tarda 20-60 min)..."
make -j"\$NPROC" deb-pkg LOCALVERSION=-cachyos-\$SCHED_NAME 2>&1 | tail -5

# Instalar los .deb generados
echo "  Instalando kernel..."
cd ..
dpkg -i linux-headers-*.deb linux-image-*.deb linux-libc-dev*.deb || true

# Verificar
INSTALLED=\$(dpkg -l 2>/dev/null | grep "linux-image.*cachyos" | head -1 | awk '{print \$2}')
if [ -n "\$INSTALLED" ]; then
    echo "✓  Kernel CachyOS instalado: \$INSTALLED"
else
    echo "⚠  Kernel CachyOS: instalación no confirmada"
fi

cd /
rm -rf "\$BUILD_DIR"
CACHYEOF

fi

# ============================================================================
# FALCOND — daemon auto-optimización gaming de PikaOS (heredoc independiente)
# ============================================================================
# Compilado desde fuente con zig. Requiere power-profiles-daemon.
# Perfiles de juegos descargados de PikaOS-Linux/falcond-profiles.
# La GUI (falcond-gui) se compila desde git.pika-os.com si está disponible.
#
# Ref: https://github.com/PikaOS-Linux/falcond
# Ref: https://git.pika-os.com/general-packages/falcond
# ============================================================================

if [ "${INSTALL_FALCOND:-false}" = "true" ]; then
    echo ""
    echo "Compilando Falcond desde fuente..."

    arch-chroot "$TARGET" /bin/bash << FALCONDEOF
export DEBIAN_FRONTEND=noninteractive
USERNAME="$USERNAME"

# ── Instalar zig (binario estático desde ziglang.org) ────────────────────────
# falcond v1.1.x requiere zig 0.14.x+
ZIG_OK=false
ZIG_VER="0.14.0"
ZIG_URL="https://ziglang.org/download/\${ZIG_VER}/zig-linux-x86_64-\${ZIG_VER}.tar.xz"

echo "  Descargando zig \$ZIG_VER..."
wget -q "\$ZIG_URL" -O /tmp/zig.tar.xz 2>/dev/null
if [ -f /tmp/zig.tar.xz ] && [ -s /tmp/zig.tar.xz ]; then
    mkdir -p /opt/zig
    tar xf /tmp/zig.tar.xz -C /opt/zig --strip-components=1
    export PATH="/opt/zig:\$PATH"
    rm -f /tmp/zig.tar.xz
    ZIG_OK=true
    echo "  ✓ zig \$ZIG_VER instalado en /opt/zig"
fi

if [ "\$ZIG_OK" = "false" ]; then
    echo "⚠  No se pudo instalar zig — falcond omitido"
    exit 0
fi

# ── Dependencias ─────────────────────────────────────────────────────────────
apt-get install -y git power-profiles-daemon 2>/dev/null || true

# ── Compilar falcond daemon ──────────────────────────────────────────────────
BUILD_DIR="\$(mktemp -d /tmp/falcond-build.XXXXXX)"
cd "\$BUILD_DIR"

# El repo tiene estructura: falcond/ (repo root) → falcond/ (código zig)
git clone --depth 1 https://github.com/PikaOS-Linux/falcond.git repo
if [ -d repo/falcond ]; then
    cd repo/falcond

    echo "  Compilando falcond daemon..."
    /opt/zig/zig build -Doptimize=ReleaseFast 2>&1 | tail -3

    if [ -f zig-out/bin/falcond ]; then
        cp zig-out/bin/falcond /usr/bin/falcond
        chmod 755 /usr/bin/falcond
        echo "  ✓ falcond daemon compilado"

        # Service file
        if [ -f debian/falcond.service ]; then
            cp debian/falcond.service /etc/systemd/system/falcond.service
        else
            cat > /etc/systemd/system/falcond.service << 'SVCEOF'
[Unit]
Description=Falcond Gaming Optimization Daemon
After=power-profiles-daemon.service

[Service]
Type=simple
ExecStart=/usr/bin/falcond
Restart=on-failure

[Install]
WantedBy=multi-user.target
SVCEOF
        fi

        # Config por defecto
        mkdir -p /etc/falcond
        cat > /etc/falcond/config.conf << 'CFGEOF'
enable_performance_mode = true
scx_sched = none
scx_sched_props = default
vcache_mode = none
profile_mode = none
CFGEOF

        # Perfiles de juegos
        git clone --depth 1 https://github.com/PikaOS-Linux/falcond-profiles.git /tmp/falcond-profiles 2>/dev/null
        if [ -d /tmp/falcond-profiles/profiles ]; then
            mkdir -p /usr/share/falcond
            cp -r /tmp/falcond-profiles/profiles /usr/share/falcond/
            [ -f /tmp/falcond-profiles/system.conf ] && cp /tmp/falcond-profiles/system.conf /usr/share/falcond/
            echo "  ✓ Perfiles de juegos instalados"
        fi
        rm -rf /tmp/falcond-profiles

        # Grupo falcond + usuario
        groupadd -f falcond 2>/dev/null || true
        usermod -aG falcond "\$USERNAME" 2>/dev/null || true

        systemctl enable falcond 2>/dev/null || true
        echo "  ✓ falcond daemon habilitado"
    else
        echo "  ⚠ falcond daemon: compilación fallida"
    fi
else
    echo "  ⚠ falcond: estructura del repo inesperada"
fi

# ── Compilar falcond-gui (GTK4, si el repo está disponible) ──────────────────
# La GUI es un paquete separado en custom-gui-packages de PikaOS.
# Está escrito en Rust+GTK4 y permite configurar falcond gráficamente.
echo ""
echo "  Intentando compilar falcond-gui..."

apt-get install -y cargo rustc libgtk-4-dev libadwaita-1-dev \
    libdbus-1-dev pkg-config 2>/dev/null || true

GUI_OK=false

# Intentar desde git.pika-os.com (repo original)
if git clone --depth 1 https://git.pika-os.com/custom-gui-packages/falcond-gui.git \
        /tmp/falcond-gui 2>/dev/null; then
    cd /tmp/falcond-gui
    GUI_OK=true
fi

# Fallback: buscar si hay GUI dentro del repo principal de falcond
if [ "\$GUI_OK" = "false" ] && [ -d "\$BUILD_DIR/repo/falcond-gui" ]; then
    cd "\$BUILD_DIR/repo/falcond-gui"
    GUI_OK=true
fi

if [ "\$GUI_OK" = "true" ]; then
    if [ -f Cargo.toml ]; then
        echo "    Compilando con cargo (Rust)..."
        cargo build --release 2>&1 | tail -3
        GUI_BIN=\$(find target/release -maxdepth 1 -name "falcond*" -type f -executable 2>/dev/null | head -1)
        if [ -n "\$GUI_BIN" ]; then
            cp "\$GUI_BIN" /usr/bin/falcond-gui
            chmod 755 /usr/bin/falcond-gui

            # Instalar .desktop y recursos solo si los trae el repo
            find . -name "*.desktop" -exec cp {} /usr/share/applications/ \; 2>/dev/null || true
            find . -path "*/icons/*" -name "*.png" -exec cp {} /usr/share/icons/hicolor/48x48/apps/ \; 2>/dev/null || true
            find . -path "*/icons/*" -name "*.svg" -exec cp {} /usr/share/icons/hicolor/scalable/apps/ \; 2>/dev/null || true

            echo "  ✓ falcond-gui instalado"
        else
            echo "  ⚠ falcond-gui: compilación Rust fallida"
        fi
    elif [ -f build.zig ]; then
        echo "    Compilando con zig..."
        /opt/zig/zig build -Doptimize=ReleaseFast 2>&1 | tail -3
        GUI_BIN=\$(find zig-out/bin -name "falcond-gui" -type f 2>/dev/null | head -1)
        if [ -n "\$GUI_BIN" ]; then
            cp "\$GUI_BIN" /usr/bin/falcond-gui
            chmod 755 /usr/bin/falcond-gui
            echo "  ✓ falcond-gui instalado (zig)"
        else
            echo "  ⚠ falcond-gui: compilación zig fallida"
        fi
    else
        echo "  ⚠ falcond-gui: no se encontró Cargo.toml ni build.zig"
    fi
else
    echo "  ⚠ falcond-gui: repo no disponible — solo daemon instalado"
    echo "    (Configurar manualmente: /etc/falcond/config.conf)"
fi

# Limpiar
cd /
rm -rf "\$BUILD_DIR" /tmp/falcond-gui

# Limpiar zig
rm -rf /opt/zig
FALCONDEOF

fi

# ============================================================================
# OPTISCALER — instalador 0ptiscaler4linux (heredoc independiente)
# ============================================================================
# Clona el script instalador de 0ptiscaler4linux en /opt/optiscaler.
# El usuario lo ejecuta manualmente por juego. No es un servicio del sistema.
# ============================================================================

if [ "${INSTALL_OPTISCALER:-false}" = "true" ]; then
    echo ""
    echo "Instalando OptiScaler for Linux..."

    arch-chroot "$TARGET" /bin/bash << OPTIEOF
export DEBIAN_FRONTEND=noninteractive
USERNAME="$USERNAME"

apt-get install -y git wget curl 2>/dev/null || true

# Clonar 0ptiscaler4linux
if git clone --depth 1 https://github.com/ind4skylivey/0ptiscaler4linux.git \
        /opt/optiscaler 2>/dev/null; then

    chmod 755 /opt/optiscaler/scripts/*.sh 2>/dev/null || true

    # Crear wrapper en PATH
    cat > /usr/local/bin/optiscaler << 'WRAPEOF'
#!/bin/bash
# OptiScaler for Linux — wrapper
cd /opt/optiscaler
exec bash scripts/install.sh "\$@"
WRAPEOF
    chmod 755 /usr/local/bin/optiscaler

    # Permisos para el usuario
    chown -R "\$USERNAME":"\$USERNAME" /opt/optiscaler 2>/dev/null || true

    echo "✓  OptiScaler instalado en /opt/optiscaler"
    echo "   Uso: optiscaler --scan-only  (escanear juegos)"
    echo "   Uso: optiscaler              (configurar juegos)"
else
    echo "⚠  OptiScaler: descarga fallida — se omite"
fi
OPTIEOF

fi

# ── Sync skel → home del usuario ─────────────────────────────────────────────
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
if [ "${INSTALL_FALCOND:-false}" = "true" ]; then
    echo "  MangoHud + MangoJuice + CPU-X (GameMode omitido por falcond)"
else
    echo "  GameMode + MangoHud + MangoJuice + CPU-X"
fi
[[ "${INSTALL_DISCORD:-n}" =~ ^[SsYy]$ ]] && echo "  Discord"
[[ "${INSTALL_UNIGINE:-n}" =~ ^[SsYy]$ ]] && echo "  Unigine Heaven benchmark"
[ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ] && echo "  Kernel CachyOS ($([ "${CACHYOS_SCHEDULER:-1}" = "1" ] && echo "BORE" || echo "EEVDF"))"
[ "${INSTALL_FALCOND:-false}" = "true" ] && echo "  Falcond (auto-optimización gaming + GUI)"
[ "${INSTALL_OPTISCALER:-false}" = "true" ] && echo "  OptiScaler (FSR4/DLSS/XeSS)"
echo "  VA-API HW + Wayland nativo (GDK/Qt/SDL/EGL)"
echo "  sysctl gaming + udev rules controladores"
echo ""

exit 0
