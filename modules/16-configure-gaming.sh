#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 16: Configurar gaming
# Steam (AppImage vía AM) + Heroic (AppImage vía AM) + Faugus + ProtonUp-Qt + Proton-Cachyos + drivers GPU
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
    safe_apt intel-media-va-driver intel-gpu-tools libva2 libva-drm2 vainfo
    safe_apt intel-media-va-driver-non-free
}

install_amd() {
    echo "  → Drivers AMD..."
    safe_apt \
        libdrm-amdgpu1 libdrm-amdgpu1:i386 \
        mesa-va-drivers mesa-vdpau-drivers \
        libva2 libva-drm2 vainfo radeontop lm-sensors
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
        if apt install -y system76-driver-nvidia 2>/dev/null; then
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

    # VA-API sobre NVDEC (para aceleración de vídeo)
    safe_apt nvidia-vaapi-driver

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
# GAMEMODE + MANGOHUD
# ============================================================================

echo ""
echo "Instalando GameMode y MangoHud..."
safe_apt gamemode mangohud goverlay
echo "✓  GameMode y MangoHud instalados"

# ============================================================================
# STEAM (AppImage vía AM)
# ============================================================================

echo ""
echo "Instalando Steam..."

if command -v am >/dev/null 2>&1; then
    if am -i steam 2>/dev/null; then
        echo "✓  Steam instalado vía AM (AppImage)"
    else
        echo "⚠  Steam: am -i falló — instalar tras primer boot: sudo am -i steam"
    fi
else
    echo "⚠  Steam: AM no disponible — instalar tras primer boot: sudo am -i steam"
fi

# ============================================================================
# FAUGUS LAUNCHER (.deb desde GitHub)
# ============================================================================

echo ""
echo "Instalando Faugus Launcher..."

FAUGUS_URL=\$(curl --max-time 15 --retry 2 -sL \
    https://api.github.com/repos/Faugus/faugus-launcher/releases/latest \
    | grep "browser_download_url.*_all.deb" | cut -d '"' -f 4 | head -1)

if [ -n "\$FAUGUS_URL" ]; then
    wget --timeout=30 --tries=2 -q "\$FAUGUS_URL" -O /tmp/faugus.deb 2>/dev/null || true
    if [ -f /tmp/faugus.deb ]; then
        dpkg -i /tmp/faugus.deb 2>/dev/null || true
        apt-get install -f -y 2>/dev/null || true
        rm -f /tmp/faugus.deb
        echo "✓  Faugus Launcher instalado"

        # Ocultar ImageMagick del menú (dependencia de Faugus)
        if [ -n "\$USERNAME" ]; then
            for im in display-im7.q16.desktop display-im6.q16.desktop; do
                if [ -f "/usr/share/applications/\$im" ]; then
                    mkdir -p "/home/\$USERNAME/.local/share/applications"
                    cp "/usr/share/applications/\$im" "/home/\$USERNAME/.local/share/applications/\$im"
                    echo "NoDisplay=true" >> "/home/\$USERNAME/.local/share/applications/\$im"
                    chown \$(id -u \$USERNAME):\$(id -g \$USERNAME) "/home/\$USERNAME/.local/share/applications/\$im"
                    break
                fi
            done
        fi
    else
        echo "⚠  Faugus: descarga falló"
    fi
else
    echo "⚠  Faugus: no se pudo consultar GitHub API"
fi

# ============================================================================
# HEROIC GAMES LAUNCHER (AppImage vía AM)
# ============================================================================

echo ""
echo "Instalando Heroic Games Launcher..."

if command -v am >/dev/null 2>&1; then
    if am -i heroic-games-launcher 2>/dev/null; then
        echo "✓  Heroic Games Launcher instalado vía AM (AppImage)"
    else
        echo "⚠  Heroic: am -i falló — instalar tras primer boot: sudo am -i heroic-games-launcher"
    fi
else
    echo "⚠  Heroic: AM no disponible — instalar tras primer boot: sudo am -i heroic-games-launcher"
fi

# ============================================================================
# PROTONUP-QT (vía AM)
# ============================================================================

echo ""
echo "Instalando ProtonUp-Qt..."

PROTONUPQT_OK=false

# AM puede no funcionar bien en chroot — intentar, si falla dar instrucciones
if command -v am >/dev/null 2>&1; then
    if am -i protonup-qt 2>/dev/null; then
        PROTONUPQT_OK=true
        echo "✓  ProtonUp-Qt instalado vía AM"
    fi
fi

if [ "\$PROTONUPQT_OK" = "false" ]; then
    echo "⚠  ProtonUp-Qt: instalar tras el primer boot con 'sudo am -i protonup-qt'"
fi

# ============================================================================
# ESTRUCTURA COMPARTIDA DE PROTON + PROTON-CACHYOS
# ============================================================================
# Ruta canónica única: ~/.local/share/Steam/compatibilitytools.d/
#
# Arquitectura:
#   - Steam:       lee compatibilitytools.d de forma nativa
#   - ProtonUp-Qt: instala en compatibilitytools.d (destino "Steam")
#                  y detecta Heroic automáticamente vía ~/.config/heroic
#   - Heroic:      config.json → customWinePaths apunta a compatibilitytools.d
#                  Heroic escanea la ruta y muestra todos los runners disponibles
#   - Faugus:      config.ini → proton-path apunta a compatibilitytools.d
#
# NO se usan symlinks — cada app recibe su configuración declarativa real.
# ============================================================================

echo ""
echo "Configurando Proton compartido (Steam / Heroic / Faugus)..."

if [ -n "\$USERNAME" ]; then
    PROTON_DIR="/home/\$USERNAME/.local/share/Steam/compatibilitytools.d"
    mkdir -p "\$PROTON_DIR"

    # ── Descargar Proton-CachyOS ──────────────────────────────────────────────
    echo "  Descargando Proton-CachyOS..."
    PCACHYOS_URL=\$(curl --max-time 15 --retry 2 -sL \
        https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest \
        | grep "browser_download_url.*tar.gz" | grep -v "sha256" | head -1 | cut -d '"' -f 4)

    PROTON_CACHYOS_NAME=""
    if [ -n "\$PCACHYOS_URL" ]; then
        wget --timeout=60 --tries=2 -q "\$PCACHYOS_URL" -O /tmp/proton-cachyos.tar.gz 2>/dev/null || true
        if [ -f /tmp/proton-cachyos.tar.gz ] && [ -s /tmp/proton-cachyos.tar.gz ]; then
            tar xzf /tmp/proton-cachyos.tar.gz -C "\$PROTON_DIR" 2>/dev/null || true
            rm -f /tmp/proton-cachyos.tar.gz
            # Obtener el nombre exacto del directorio extraído para usarlo en configs
            PROTON_CACHYOS_NAME=\$(ls "\$PROTON_DIR" | grep -i "cachyos\|cachy" | head -1)
            echo "  ✓  Proton-CachyOS instalado: \$PROTON_CACHYOS_NAME"
        else
            rm -f /tmp/proton-cachyos.tar.gz
            echo "  ⚠  Proton-CachyOS: descarga falló — usar ProtonUp-Qt tras primer boot"
        fi
    else
        echo "  ⚠  Proton-CachyOS: GitHub API no respondió — usar ProtonUp-Qt tras primer boot"
    fi

    # ── Configuración de Heroic Games Launcher ────────────────────────────────
    # config.json: customWinePaths incluye compatibilitytools.d para que Heroic
    # escanee y detecte automáticamente todos los runners (incluidos los que
    # instale ProtonUp-Qt después).
    # Si Proton-CachyOS se descargó, se establece como runner por defecto.
    mkdir -p "/home/\$USERNAME/.config/heroic"

    HEROIC_WINE_DEFAULT="null"
    if [ -n "\$PROTON_CACHYOS_NAME" ]; then
        HEROIC_WINE_DEFAULT="{
      \"bin\": \"\$PROTON_DIR/\$PROTON_CACHYOS_NAME/proton\",
      \"name\": \"\$PROTON_CACHYOS_NAME\",
      \"type\": \"proton\"
    }"
    fi

    cat > "/home/\$USERNAME/.config/heroic/config.json" << HEROIC_EOF
{
  "defaultSettings": {
    "customWinePaths": [
      "\$PROTON_DIR"
    ],
    "wineVersion": \$HEROIC_WINE_DEFAULT,
    "winePrefix": "/home/\$USERNAME/Games/Heroic/Prefixes/default",
    "useSteamRuntime": false
  }
}
HEROIC_EOF
    echo "  ✓  Heroic: config.json escrito (runner: \${PROTON_CACHYOS_NAME:-detectar automáticamente})"

    # ── Configuración de Faugus Launcher ─────────────────────────────────────
    # config.ini: proton-path apunta a compatibilitytools.d.
    # default-runner usa el nombre exacto del directorio de Proton-CachyOS
    # (sin ruta, solo el nombre — Faugus lo busca dentro de proton-path).
    mkdir -p "/home/\$USERNAME/.config/faugus-launcher"

    FAUGUS_RUNNER="\${PROTON_CACHYOS_NAME:-}"

    cat > "/home/\$USERNAME/.config/faugus-launcher/config.ini" << FAUGUS_EOF
[Settings]
proton-path=\$PROTON_DIR
default-runner=\$FAUGUS_RUNNER
default-prefix=/home/\$USERNAME/Games/Faugus
FAUGUS_EOF
    echo "  ✓  Faugus: config.ini escrito (runner: \${FAUGUS_RUNNER:-detectar automáticamente})"

    # ── Permisos ──────────────────────────────────────────────────────────────
    chown -R \$(id -u \$USERNAME):\$(id -g \$USERNAME) \
        "/home/\$USERNAME/.local/share/Steam" \
        "/home/\$USERNAME/.config/heroic" \
        "/home/\$USERNAME/.config/faugus-launcher" 2>/dev/null || true

    echo ""
    echo "  Ruta canónica de Proton: \$PROTON_DIR"
    echo "  ProtonUp-Qt instalará nuevas versiones en esa misma ruta"
    echo "  y serán visibles en Steam, Heroic y Faugus sin configuración adicional"
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
# VRR + HDR (GNOME — fuera del heredoc principal)
# ============================================================================

if arch-chroot "$TARGET" command -v gnome-shell >/dev/null 2>&1; then
    GNOME_VER=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)

    if [ -n "$GNOME_VER" ] && [ "$GNOME_VER" -ge 46 ]; then
        echo ""
        echo "Configurando VRR/HDR para GNOME $GNOME_VER..."

        # Construir lista de experimental-features según versión
        FEATURES="variable-refresh-rate"
        [ "$GNOME_VER" -ge 48 ] && FEATURES="variable-refresh-rate, hdr"

        # Un solo autostart que habilita todo y se autodestruye
        # NOTA: heredoc sin comillas (VRREOF y DESKEOF) para que $FEATURES,
        # $USERNAME y $GNOME_VER se expandan correctamente desde el host.
        # Las variables internas del chroot se escapan con \$.
        arch-chroot "$TARGET" /bin/bash << VRREOF
USERNAME="$USERNAME"
if [ -n "\$USERNAME" ]; then
    mkdir -p "/home/\$USERNAME/.config/autostart"
    cat > "/home/\$USERNAME/.config/autostart/enable-vrr-hdr.desktop" << DESKEOF
[Desktop Entry]
Type=Application
Name=Enable VRR/HDR
Exec=/bin/bash -c 'gsettings set org.gnome.mutter experimental-features "[\"$FEATURES\"]" 2>/dev/null; rm -f ~/.config/autostart/enable-vrr-hdr.desktop'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKEOF
    chown \$(id -u \$USERNAME):\$(id -g \$USERNAME) "/home/\$USERNAME/.config/autostart/enable-vrr-hdr.desktop"
    echo "✓  VRR$([ "$GNOME_VER" -ge 48 ] && echo "/HDR") se habilitará en primer login"
fi
VRREOF
    fi
fi

# ============================================================================
# KERNEL CACHYOS (OPCIONAL)
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  KERNEL CACHYOS (opcional)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Variantes: 1) BORE (baja latencia)  2) EEVDF (equilibrio)  3) No instalar"
echo ""
if [ -z "$CACHYOS_CHOICE" ]; then
    read -p "Variante [3]: " CACHYOS_CHOICE
fi

case "${CACHYOS_CHOICE:-3}" in
    1) CACHYOS_SCHED="bore" ;;
    2) CACHYOS_SCHED="eevdf" ;;
    *) CACHYOS_SCHED="" ;;
esac

CACHYOS_INSTALLED=false
if [ -n "$CACHYOS_SCHED" ]; then
    echo ""
    echo "Preparando kernel CachyOS ($CACHYOS_SCHED) — puede tardar 15-45 min..."

    arch-chroot "$TARGET" /bin/bash << CACHYOS_EOF
export DEBIAN_FRONTEND=noninteractive
SCHED="$CACHYOS_SCHED"

apt install -y build-essential bc kmod cpio flex libncurses-dev \
    libelf-dev libssl-dev dwarves bison lsb-release \
    wget git fakeroot whiptail debhelper rsync 2>/dev/null || true

PSYCACHY_DIR="/opt/linux-psycachy"
rm -rf "\$PSYCACHY_DIR"

if git clone --depth 1 https://github.com/psygreg/linux-psycachy.git "\$PSYCACHY_DIR" 2>/dev/null; then
    cd "\$PSYCACHY_DIR"
    chmod +x cachyos-deb.sh

    [ "\$SCHED" = "eevdf" ] && export CACHY_SCHED="eevdf"
    ./cachyos-deb.sh -g 2>&1 | tail -5

    DEB_DIR="\$(find /tmp "\$PSYCACHY_DIR" -maxdepth 2 -name 'linux-image-psycachy*.deb' -printf '%h\n' 2>/dev/null | head -1)"

    if [ -n "\$DEB_DIR" ] && ls "\$DEB_DIR"/linux-image-psycachy*.deb &>/dev/null; then
        dpkg -i "\$DEB_DIR"/linux-image-psycachy*.deb "\$DEB_DIR"/linux-headers-psycachy*.deb 2>/dev/null || true
        update-initramfs -u -k all 2>/dev/null || true
        update-grub 2>/dev/null || true
        echo "✓  Kernel CachyOS (\$SCHED) instalado"
    else
        echo "⚠  Kernel CachyOS: compilación falló"
        echo "  Builder en \$PSYCACHY_DIR — compilar manualmente: sudo ./cachyos-deb.sh"
    fi

    rm -rf /tmp/linux-cachyos-* 2>/dev/null || true
else
    echo "⚠  No se pudo clonar linux-psycachy"
fi
CACHYOS_EOF

    CACHYOS_INSTALLED=true
else
    echo "Kernel CachyOS omitido"
fi

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GAMING COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  GPU: $GPU_CONFIG"
echo "  Steam, Heroic, Faugus, ProtonUp-Qt (AppImage vía AM) + Proton-Cachyos"
echo "  GameMode + MangoHud + GOverlay"
echo "  sysctl gaming + udev rules controladores"
[ "${CACHYOS_INSTALLED}" = "true" ] && echo "  Kernel CachyOS (${CACHYOS_SCHED})"
echo ""

exit 0
