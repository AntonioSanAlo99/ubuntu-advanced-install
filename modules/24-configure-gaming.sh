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
        apt-get update -qq 2>/dev/null || true
        if apt-get install -y system76-driver-nvidia 2>/dev/null; then
            S76_PPA=true
            echo "  ✓ NVIDIA instalado vía PPA System76 (system76-driver-nvidia)"
        else
            echo "  ⚠ system76-driver-nvidia falló — probando ubuntu-drivers"
            add-apt-repository -ry ppa:system76-dev/stable 2>/dev/null || true
            apt-get update -qq 2>/dev/null || true
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

echo ""
echo "Instalando GameMode y MangoHud..."
safe_apt gamemode mangohud
echo "✓  GameMode y MangoHud instalados"

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
    dpkg -i "\$HEROIC_DEB" 2>/dev/null || true
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
    apt-get update -qq 2>/dev/null || true
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
        dpkg -i /tmp/discord.deb 2>/dev/null || true
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
        chmod +x "\$HEAVEN_RUN"
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
echo "  GameMode + MangoHud + MangoJuice + CPU-X"
[[ "${INSTALL_DISCORD:-n}" =~ ^[SsYy]$ ]] && echo "  Discord"
[[ "${INSTALL_UNIGINE:-n}" =~ ^[SsYy]$ ]] && echo "  Unigine Heaven benchmark"
echo "  VA-API HW + Wayland nativo (GDK/Qt/SDL/EGL)"
echo "  sysctl gaming + udev rules controladores"
echo ""

exit 0
