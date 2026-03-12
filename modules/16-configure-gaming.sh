#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 16: Configurar gaming
# Steam (PPA Valve) + Heroic (PPA oficial) + Faugus (PPA oficial) + drivers GPU
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
# STEAM (PPA oficial de Valve)
# ============================================================================
# Método: repositorio oficial deb.valvesoftware.com
# Ventajas sobre AppImage: integración nativa con el sistema, actualizaciones
# via apt, gestión de dependencias correcta, mejor soporte de Steam Runtime.
# ============================================================================

echo ""
echo "Instalando Steam (PPA oficial Valve)..."

# Añadir arquitectura i386 ya fue hecha arriba — solo necesitamos el repo
if wget --timeout=15 --tries=2 -q \
    "https://repo.steampowered.com/steam/archive/precise/steam.gpg" \
    -O /usr/share/keyrings/steam.gpg 2>/dev/null; then

    cat > /etc/apt/sources.list.d/steam.list << 'STEAMEOF'
deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] https://repo.steampowered.com/steam/ stable steam
deb-src [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] https://repo.steampowered.com/steam/ stable steam
STEAMEOF

    apt update 2>/dev/null || true
    # steam-libs-amd64/i386: librerías de Steam Runtime necesarias para juegos
    safe_apt steam-libs-amd64 steam-libs-i386 steam
    echo "✓  Steam instalado (PPA oficial Valve)"
else
    echo "⚠  Steam: no se pudo descargar la clave GPG"
    echo "   Instalar tras primer boot:"
    echo "   wget -O /tmp/steam.deb https://cdn.akamai.steamstatic.com/client/installer/steam.deb"
    echo "   sudo dpkg -i /tmp/steam.deb && sudo apt-get install -f -y"
fi

# ============================================================================
# HEROIC GAMES LAUNCHER (PPA oficial)
# ============================================================================
# PPA: ppa:heroic-games-launcher/ppa
# Proporciona el paquete heroic — actualizable con apt upgrade.
# ============================================================================

echo ""
echo "Instalando Heroic Games Launcher (PPA oficial)..."

if add-apt-repository -y ppa:heroic-games-launcher/ppa 2>/dev/null; then
    apt update 2>/dev/null || true
    if safe_apt heroic; then
        echo "✓  Heroic Games Launcher instalado (PPA oficial)"
    else
        echo "⚠  Heroic: apt falló tras añadir PPA"
        echo "   Instalar tras primer boot: sudo apt install heroic"
    fi
else
    echo "⚠  Heroic: no se pudo añadir PPA"
    echo "   Instalar tras primer boot: sudo add-apt-repository ppa:heroic-games-launcher/ppa && sudo apt install heroic"
fi

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
# Escribir el .desktop en skel — la estructura .config/autostart ya existe
# en skel (preparada en 03-configure-base antes de useradd).
# 10-user-config.sh sincronizará skel → home del usuario al final.
cat > "/etc/skel/.config/autostart/enable-vrr-hdr.desktop" << DESKEOF
[Desktop Entry]
Type=Application
Name=Enable VRR/HDR
Exec=/bin/bash -c 'gsettings set org.gnome.mutter experimental-features "[\"$FEATURES\"]" 2>/dev/null; rm -f ~/.config/autostart/enable-vrr-hdr.desktop'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKEOF
echo "✓  VRR$([ "$GNOME_VER" -ge 48 ] && echo "/HDR") se habilitará en primer login"
VRREOF
    fi
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
echo "  Steam (PPA Valve) + Heroic (PPA oficial) + Faugus (PPA oficial)"
echo "  GameMode + MangoHud + GOverlay"
echo "  sysctl gaming + udev rules controladores"
echo ""

exit 0
