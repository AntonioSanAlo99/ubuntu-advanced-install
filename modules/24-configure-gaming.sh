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

# ── Decidir i386 según método de Steam ─────────────────────────────────────
USE_I386="true"
if [ "${STEAM_METHOD:-1}" = "2" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║  AVISO: SteamRT3 64-bit es EXPERIMENTAL                       ║"
    echo "║                                                                ║"
    echo "║  Steam arranca sin librerías i386 del host (containerizado).   ║"
    echo "║  Puedes instalar i386 igualmente para juegos nativos 32-bit   ║"
    echo "║  antiguos, o saltarlo para un sistema 100% 64-bit.            ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    read -p "  ¿Habilitar i386 para compatibilidad 32-bit? (s/n) [s]: " opt_i386
    [[ ${opt_i386:-s} =~ ^[Nn]$ ]] && USE_I386="false"
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
USE_I386="$USE_I386"

# Función auxiliar: instalar paquetes sin fallar si alguno no existe
safe_apt() {
    apt-get install -y "\$@" 2>/dev/null || true
}

# ============================================================================
# ARQUITECTURA i386 — ya decidido antes del chroot (variable USE_I386)
# ============================================================================

if [ "$USE_I386" = "true" ]; then
    echo ""
    echo "Habilitando arquitectura i386..."
    dpkg --add-architecture i386
    apt-get update -qq
    echo "✓  i386 habilitado"
else
    echo ""
    echo "Omitiendo i386 — sistema 100% 64-bit"
fi

echo ""

# ── Mesa base (necesario para TODAS las configs, incluida VM) ────────────────
echo "Instalando Mesa base + Vulkan..."
if [ "$USE_I386" = "true" ]; then
    safe_apt \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        libgl1-mesa-dri libgl1-mesa-dri:i386 \
        mesa-utils vulkan-tools \
        libvulkan1 libvulkan1:i386 \
        libgl1 libgl1:i386
else
    safe_apt \
        mesa-vulkan-drivers \
        libgl1-mesa-dri \
        mesa-utils vulkan-tools \
        libvulkan1 \
        libgl1
fi

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
        libva2 libva-drm2 libva-wayland2 \
        vainfo
}

install_amd() {
    echo "  → Drivers AMD..."
    if [ "$USE_I386" = "true" ]; then
        safe_apt \
            libdrm-amdgpu1 libdrm-amdgpu1:i386 \
            mesa-va-drivers mesa-va-drivers:i386 \
            mesa-vdpau-drivers mesa-vdpau-drivers:i386 \
            libvulkan-mesa-layers libvulkan-mesa-layers:i386 \
            libva2 libva-drm2 libva-wayland2 \
            vainfo radeontop lm-sensors
    else
        safe_apt \
            libdrm-amdgpu1 \
            mesa-va-drivers \
            mesa-vdpau-drivers \
            libvulkan-mesa-layers \
            libva2 libva-drm2 libva-wayland2 \
            vainfo radeontop lm-sensors
    fi
    safe_apt firmware-amd-graphics
}

install_nvidia() {
    echo "  → Drivers NVIDIA..."

    # ══════════════════════════════════════════════════════════════════════════
    # INSTALACIÓN DEL DRIVER
    # ══════════════════════════════════════════════════════════════════════════
    # Método: ubuntu-drivers autoinstall (recomendado por Canonical)
    # Detecta la GPU y selecciona automáticamente el driver óptimo:
    #   - Versión correcta para la generación de GPU
    #   - Compatible con el kernel instalado
    #   - Desde el repo oficial de Ubuntu (probado, firmado, seguro)
    # Sin PPA de terceros, sin versiones hardcodeadas.
    # Ref: https://documentation.ubuntu.com/server/how-to/graphics/install-nvidia-drivers/

    safe_apt ubuntu-drivers-common

    echo "  Detectando GPU y seleccionando driver óptimo..."
    ubuntu-drivers devices 2>/dev/null | head -10 || true

    if ubuntu-drivers autoinstall 2>&1; then
        echo "  ✓ NVIDIA driver instalado vía ubuntu-drivers autoinstall"
    else
        echo "  ⚠ ubuntu-drivers autoinstall falló — probando metapaquete genérico"
        safe_apt nvidia-driver
    fi

    # Verificar instalación
    if dpkg -l 2>/dev/null | grep -q "^ii.*nvidia-driver"; then
        NVIDIA_VER=\$(dpkg -l 2>/dev/null | grep "^ii.*nvidia-driver-[0-9]" | head -1 | awk '{print \$2}')
        echo "  ✓ NVIDIA driver confirmado: \${NVIDIA_VER:-desconocido}"
    else
        echo "  ⚠ NVIDIA: driver no confirmado en chroot"
        echo "    Ejecutar tras primer boot: sudo ubuntu-drivers autoinstall"
    fi

    # ══════════════════════════════════════════════════════════════════════════
    # WAYLAND — configuración profesional completa
    # ══════════════════════════════════════════════════════════════════════════
    # Ref: ArchWiki NVIDIA, Hyprland Wiki, CachyOS-Settings

    # ── DRM KMS: modeset + fbdev ──────────────────────────────────────────────
    mkdir -p /etc/modprobe.d
    cat > /etc/modprobe.d/nvidia.conf << 'NVIDIAMOD'
# NVIDIA Wayland — ubuntu-advanced-install
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UsePageAttributeTable=1
options nvidia_drm modeset=1 fbdev=1
NVIDIAMOD
    echo "  ✓ modprobe.d: modeset=1, fbdev=1, PreserveVRAM, PAT"

    # ── Early-load en initramfs ───────────────────────────────────────────────
    INITRAMFS_MODULES="/etc/initramfs-tools/modules"
    for mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        grep -qw "\$mod" "\$INITRAMFS_MODULES" 2>/dev/null || echo "\$mod" >> "\$INITRAMFS_MODULES"
    done
    update-initramfs -u 2>/dev/null || true
    echo "  ✓ initramfs: nvidia early-load"

    # ── Suspend/resume/hibernate ──────────────────────────────────────────────
    systemctl enable nvidia-suspend.service 2>/dev/null || true
    systemctl enable nvidia-resume.service 2>/dev/null || true
    systemctl enable nvidia-hibernate.service 2>/dev/null || true
    echo "  ✓ nvidia-suspend/resume/hibernate habilitados"

    # ── EGL Wayland + GBM ─────────────────────────────────────────────────────
    safe_apt libnvidia-egl-wayland1 libnvidia-egl-gbm1
    echo "  ✓ EGL Wayland + GBM libraries"

    # ── Variables de entorno (systemd environment.d) ──────────────────────────
    mkdir -p /etc/environment.d
    cat > /etc/environment.d/50-nvidia-wayland.conf << 'NVENV'
# NVIDIA Wayland — ubuntu-advanced-install
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
NVENV
    echo "  ✓ environment.d: GBM, GLX, VA-API"

    # ── VA-API (aceleración de vídeo por hardware) ────────────────────────────
    safe_apt nvidia-vaapi-driver libva2 libva-drm2 libva-wayland2 vainfo
    echo "  ✓ VA-API: nvidia-vaapi-driver"

    # ── GDM: asegurar sesión Wayland ──────────────────────────────────────────
    if [ -f /usr/lib/udev/rules.d/61-gdm.rules ]; then
        ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules
        echo "  ✓ GDM: 61-gdm.rules anulada (forzar Wayland)"
    fi
    if [ -f /etc/gdm3/custom.conf ]; then
        sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=true/' /etc/gdm3/custom.conf
        echo "  ✓ GDM: WaylandEnable=true"
    fi

    echo "  ✓ NVIDIA Wayland configuración completa"
}

install_prime() {
    # ══════════════════════════════════════════════════════════════════════════
    # PRIME HYBRID GPU — switcheroo-control + render offload dinámico
    # ══════════════════════════════════════════════════════════════════════════
    # Configuración estilo Debian/CachyOS:
    #   - GPU integrada (Intel/AMD) renderiza el escritorio y apps ligeras
    #   - GPU dedicada (NVIDIA/AMD) se activa bajo demanda para apps pesadas
    #   - switcheroo-control: D-Bus service que GNOME usa para el menú
    #     "Ejecutar con tarjeta gráfica dedicada" (clic derecho)
    #   - PRIME render offload: el kernel redirige el rendering a la GPU
    #     dedicada sin necesidad de reiniciar sesión
    #   - Dynamic Power Management: la GPU dedicada se apaga automáticamente
    #     cuando no hay apps usándola (ahorro de batería)
    #
    # En GNOME + Wayland, switcheroo-control es el método recomendado:
    #   - CachyOS: "please avoid optimus-manager, use switcheroo-control"
    #   - Debian: "PRIME Render Offload should work out-of-the-box"
    #   - ArchWiki: "GNOME will respect PrefersNonDefaultGPU in .desktop"
    # ══════════════════════════════════════════════════════════════════════════

    echo ""
    echo "  → Configurando GPU híbrida (PRIME render offload dinámico)..."

    # switcheroo-control: daemon D-Bus que detecta GPUs y permite a GNOME
    # ofrecer "Ejecutar con tarjeta gráfica dedicada" en el menú contextual
    safe_apt switcheroo-control
    systemctl enable switcheroo-control.service 2>/dev/null || true
    echo "  ✓ switcheroo-control habilitado"

    # nvidia-prime: wrapper que setea __NV_PRIME_RENDER_OFFLOAD=1 etc.
    # Solo necesario para NVIDIA (AMD usa DRI_PRIME=1 automáticamente)
    if echo "\$GPU_CONFIG" | grep -q "nvidia"; then
        safe_apt nvidia-prime

        # Configurar PRIME render offload por defecto para apps que lo pidan
        # Los .desktop con PrefersNonDefaultGPU=true se ejecutarán en la GPU dedicada
        # automáticamente (Steam, juegos, etc.)
        echo "  ✓ nvidia-prime instalado (PRIME render offload)"

        # Asegurar que el driver NVIDIA no bloquee la GPU integrada
        # y que Wayland use la integrada como primary display
        mkdir -p /etc/modprobe.d
        if ! grep -q "NVreg_DynamicPowerManagement" /etc/modprobe.d/nvidia.conf 2>/dev/null; then
            echo "options nvidia NVreg_DynamicPowerManagement=0x02" >> /etc/modprobe.d/nvidia.conf
        fi
        echo "  ✓ NVIDIA Dynamic Power Management: Fine-Grained (0x02)"
        echo "    GPU dedicada se apaga automáticamente cuando no se usa"
    fi

    # Para AMD+AMD: DRI_PRIME=1 funciona out-of-the-box con Mesa
    # switcheroo-control ya detecta ambas GPUs vía D-Bus
    if echo "\$GPU_CONFIG" | grep -q "amd+amd\|intel+amd"; then
        echo "  ✓ PRIME offload: DRI_PRIME=1 (automático con Mesa)"
    fi

    # Marcar apps de gaming para que prefieran GPU dedicada automáticamente
    # PrefersNonDefaultGPU=true en .desktop → GNOME las lanza en la GPU dedicada
    for desktop_file in \
        /usr/share/applications/steam.desktop \
        /usr/share/applications/com.heroicgameslauncher.hgl.desktop \
        /usr/share/applications/faugus-launcher.desktop; do
        if [ -f "\$desktop_file" ]; then
            if ! grep -q "PrefersNonDefaultGPU" "\$desktop_file"; then
                sed -i '/^\[Desktop Entry\]/a PrefersNonDefaultGPU=true' "\$desktop_file"
            fi
        fi
    done
    echo "  ✓ Apps gaming marcadas con PrefersNonDefaultGPU=true"

    echo ""
    echo "  ═══════════════════════════════════════════════════════"
    echo "  ✓ GPU híbrida configurada (PRIME render offload)"
    echo "    Escritorio → GPU integrada (bajo consumo)"
    echo "    Gaming/3D  → GPU dedicada (bajo demanda, clic derecho)"
    echo "    Batería    → GPU dedicada se apaga cuando no se usa"
    echo "  ═══════════════════════════════════════════════════════"
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

# Variables de entorno de sesión via systemd environment.d
# Método moderno: /etc/environment.d/*.conf (man environment.d(5))
# NO usamos /etc/environment (legacy, no soporta comentarios ni drops)
#
# Eliminadas variables obsoletas en Ubuntu 26.04 / GNOME 50 / Wayland 100%:
#   QT_QPA_PLATFORM=wayland;xcb — Qt6 detecta Wayland automáticamente desde Qt 6.5
#   GDK_BACKEND — GTK4 prioriza Wayland por defecto
#   MOZ_ENABLE_WAYLAND — default en Firefox 121+
#   ELECTRON_OZONE_PLATFORM_HINT — default en Electron 28+

mkdir -p "\$CHROOT/etc/environment.d" 2>/dev/null || mkdir -p /etc/environment.d

cat > /etc/environment.d/50-wayland-session.conf << 'WAYENV'
# Wayland session — ubuntu-advanced-install
# GStreamer: exponer todos los drivers VA-API disponibles
GST_VAAPI_ALL_DRIVERS=1
# SDL2/SDL3: Wayland nativo
SDL_VIDEODRIVER=wayland
WAYENV

echo "✓  /etc/environment.d/50-wayland-session.conf"

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

# ── Realtime privileges para audio gaming ─────────────────────────────────────
# Reduce latencia de audio bajo carga (importante en gaming para evitar glitches).
# Crea grupo realtime, añade el usuario, y configura limits.
# Ref: CachyOS gaming setup, PipeWire realtime scheduling
if [ -n "\$USERNAME" ]; then
    groupadd -f realtime 2>/dev/null || true
    usermod -aG realtime "\$USERNAME" 2>/dev/null || true

    mkdir -p /etc/security/limits.d
    cat > /etc/security/limits.d/99-realtime-audio.conf << 'RTLIMITS'
# Realtime privileges para audio y gaming — ubuntu-advanced-install
@realtime   -   rtprio      98
@realtime   -   memlock     unlimited
@realtime   -   nice        -20
RTLIMITS
    echo "✓  Realtime privileges: usuario \$USERNAME en grupo realtime"
fi

# ============================================================================
# STEAM — dos métodos de instalación
# ============================================================================
#   1) GLFS 13.0 — tarball + make install (estable, probado, necesita i386)
#   2) SteamRT3 Beta — .deb oficial + contenedor 64-bit (experimental)
#
# El método se elige con STEAM_METHOD (1 o 2) desde install.sh.
# ============================================================================

if [ "${STEAM_METHOD:-1}" = "2" ]; then
    # ── Método 2: SteamRT3 Beta (64-bit, containerizado) ─────────────────────
    # Instala el .deb oficial de Valve. Steam arranca en modo legacy por defecto;
    # el usuario activa SteamRT3 desde Settings → Interface →
    # "Use experimental SteamRT3 Steam Client".
    #
    # Ventajas: 64-bit nativo, no necesita librerías i386 del host para Steam
    # Desventaja: beta experimental, puede tener bugs
    echo ""
    echo "Instalando Steam (método SteamRT3 Beta — 64-bit containerizado)..."

    # Dependencias mínimas para el .deb de Valve (sin i386 si no se activó)
    if [ "$USE_I386" = "true" ]; then
        safe_apt \
            curl ca-certificates wget zenity xdg-user-dirs desktop-file-utils \
            libgl1 libgl1:i386 libglvnd0 libglvnd0:i386 \
            libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
            libnss3 libgpg-error0
    else
        safe_apt \
            curl ca-certificates wget zenity xdg-user-dirs desktop-file-utils \
            libgl1 libglvnd0 \
            libvulkan1 mesa-vulkan-drivers \
            libnss3 libgpg-error0
    fi

    # Descargar e instalar .deb oficial de Valve
    STEAM_DEB="/tmp/steam_latest.deb"
    wget --timeout=30 --tries=2 -q \
        "https://cdn.akamai.steamstatic.com/client/installer/steam.deb" \
        -O "\$STEAM_DEB" 2>/dev/null

    if [ -f "\$STEAM_DEB" ] && [ -s "\$STEAM_DEB" ]; then
        dpkg -i "\$STEAM_DEB" || true
        apt-get install -f -y 2>/dev/null || true
        rm -f "\$STEAM_DEB"
        echo "✓  Steam instalado (.deb oficial Valve)"
        echo "   Para activar SteamRT3 64-bit:"
        echo "   Settings → Interface → Use experimental SteamRT3 Steam Client"
    else
        echo "⚠  Steam: descarga del .deb fallida"
    fi

else
    # ── Método 1: GLFS 13.0 (estable, tarball + make install) ────────────────
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
    echo "✓  Steam \${STEAM_VER} instalado (GLFS)"

    # ── Bloquear paquete steam de repos APT para prevenir duplicación ────────
    cat > /etc/apt/preferences.d/no-steam-apt << 'PINEOF'
# Bloquear instalación de Steam via APT — ya instalado via GLFS tarball
Package: steam steam-launcher steam-installer steam-libs-amd64 steam-libs-i386
Pin: release *
Pin-Priority: -1
PINEOF
    echo "  ✓  apt pin: steam bloqueado para prevenir duplicación"
fi

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
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTLEOF

# Solo forzar swappiness bajo si NO hay zram activo
# (si hay zram, 90-zram-swap.conf ya configura el valor correcto)
if [ ! -f /etc/sysctl.d/90-zram-swap.conf ]; then
    echo "vm.swappiness = 10" >> /etc/sysctl.d/99-gaming.conf
fi

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
# KERNEL PSYCACHY — debs precompilados de CachyOS para Ubuntu/Debian
# ============================================================================
# Descarga .deb precompilados de github.com/psygreg/linux-psycachy.
# PsyCachy: kernel CachyOS adaptado para Debian/Ubuntu con BORE scheduler,
# compilado con gcc, compatible con DKMS de Ubuntu. Sin compilación local.
# Ref: https://github.com/psygreg/linux-psycachy
# ============================================================================

if [ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ]; then
    echo ""
    echo "Instalando kernel PsyCachy (CachyOS para Ubuntu/Debian)..."
    echo "  Ref: https://github.com/psygreg/linux-psycachy"

    arch-chroot "$TARGET" /bin/bash << CACHYEOF
set -e
export DEBIAN_FRONTEND=noninteractive

# ── PsyCachy: kernel CachyOS precompilado para Ubuntu/Debian ─────────────────
# Descarga .deb precompilados de GitHub releases (psygreg/linux-psycachy).
# Incluye BORE scheduler, parches CachyOS, compilado con gcc, compatible con
# DKMS de Ubuntu. Sin necesidad de compilar desde fuente.
# .deb nombrados: linux-image-psycachy_VERSION_amd64.deb
#                 linux-headers-psycachy_VERSION_amd64.deb
#                 linux-libc-dev_VERSION_amd64.deb

echo "  Buscando última release de PsyCachy..."

# Obtener URLs de la última release
RELEASE_JSON=\$(curl -s "https://api.github.com/repos/psygreg/linux-psycachy/releases/latest" 2>/dev/null)

if [ -z "\$RELEASE_JSON" ]; then
    echo "  ⚠ No se pudo contactar GitHub API — omitiendo kernel PsyCachy"
else
    PSYCACHY_VER=\$(echo "\$RELEASE_JSON" | grep -Po '"tag_name":\s*"\K[^"]+' | head -1)
    echo "  Release: \$PSYCACHY_VER"

    # Descargar los 3 debs: image, headers, libc-dev
    DEB_DIR=\$(mktemp -d /tmp/psycachy.XXXXXX)
    cd "\$DEB_DIR"
    DOWNLOADED=0

    for pattern in "linux-image-psycachy.*amd64.deb" "linux-headers-psycachy.*amd64.deb" "linux-libc-dev.*amd64.deb"; do
        URL=\$(echo "\$RELEASE_JSON" | grep -Po '"browser_download_url":\s*"\K[^"]+' | grep -E "\$pattern" | head -1)
        if [ -n "\$URL" ]; then
            FNAME=\$(basename "\$URL")
            echo "  Descargando \$FNAME..."
            curl -Lo "\$FNAME" "\$URL" 2>/dev/null
            [ -s "\$FNAME" ] && DOWNLOADED=\$((DOWNLOADED + 1))
        fi
    done

    if [ "\$DOWNLOADED" -ge 2 ]; then
        echo "  Instalando kernel PsyCachy..."
        dpkg -i linux-image-psycachy*.deb linux-headers-psycachy*.deb linux-libc-dev*.deb 2>/dev/null || true
        apt-get install -f -y 2>/dev/null || true

        INSTALLED=\$(dpkg -l 2>/dev/null | grep "linux-image-psycachy" | head -1 | awk '{print \$2}')
        if [ -n "\$INSTALLED" ]; then
            update-grub 2>/dev/null || true
            echo "  ✓ Kernel PsyCachy instalado: \$INSTALLED"
            echo "    Selecciona psycachy en GRUB tras reiniciar"
        else
            echo "  ⚠ PsyCachy: instalación no confirmada — revisa debs en \$DEB_DIR"
        fi
    else
        echo "  ⚠ PsyCachy: no se encontraron suficientes .deb en la release"
    fi

    cd /
    rm -rf "\$DEB_DIR"
fi

CACHYEOF

fi

# ── Scheduler: BORE vs EEVDF (sysctl) ────────────────────────────────────────
# PsyCachy viene con CONFIG_SCHED_BORE=y. BORE se activa/desactiva en runtime
# con sysctl kernel.sched_bore. Si el usuario eligió EEVDF, lo desactivamos.
SCHED_CHOICE="$PSYCACHY_SCHEDULER"
if [ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ]; then
    arch-chroot "$TARGET" /bin/bash -c "
        mkdir -p /etc/sysctl.d
        if [ '\$SCHED_CHOICE' = 'eevdf' ]; then
            echo 'kernel.sched_bore = 0' > /etc/sysctl.d/90-scheduler.conf
            echo '  ✓ Scheduler: EEVDF (BORE desactivado via sysctl)'
        else
            echo 'kernel.sched_bore = 1' > /etc/sysctl.d/90-scheduler.conf
            echo '  ✓ Scheduler: BORE (default PsyCachy)'
        fi
    "
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

# ── Instalar zig (método lindevs.com: última release via GitHub API) ─────────
# Ref: https://lindevs.com/install-zig-on-ubuntu
ZIG_OK=false

# Método 1: última release estable via GitHub API
ZIG_VER=\$(curl -s "https://api.github.com/repos/ziglang/zig/releases/latest" \
    | grep -Po '"tag_name": "\K[0-9.]+' 2>/dev/null || echo "")

if [ -n "\$ZIG_VER" ]; then
    echo "  Descargando zig \$ZIG_VER (última release)..."
    ZIG_URL="https://ziglang.org/download/\${ZIG_VER}/zig-x86_64-linux-\${ZIG_VER}.tar.xz"
    wget -q "\$ZIG_URL" -O /tmp/zig.tar.xz 2>/dev/null
    if [ -s /tmp/zig.tar.xz ]; then
        rm -rf /opt/zig
        mkdir -p /opt/zig
        tar xf /tmp/zig.tar.xz -C /opt/zig --strip-components=1
        export PATH="/opt/zig:\$PATH"
        rm -f /tmp/zig.tar.xz
        ZIG_OK=true
        echo "  ✓ zig \$ZIG_VER instalado en /opt/zig"
    fi
fi

# Método 2: fallback a versiones fijas conocidas (formato URL antiguo)
if [ "\$ZIG_OK" = "false" ]; then
    for ZIG_VER in "0.14.1" "0.14.0" "0.13.0"; do
        echo "  Fallback: probando zig \$ZIG_VER..."
        # Intentar ambos formatos de nombre (cambió entre versiones)
        for ZIG_NAME in "zig-x86_64-linux-\${ZIG_VER}" "zig-linux-x86_64-\${ZIG_VER}"; do
            ZIG_URL="https://ziglang.org/download/\${ZIG_VER}/\${ZIG_NAME}.tar.xz"
            wget -q "\$ZIG_URL" -O /tmp/zig.tar.xz 2>/dev/null
            if [ -s /tmp/zig.tar.xz ]; then
                rm -rf /opt/zig
                mkdir -p /opt/zig
                tar xf /tmp/zig.tar.xz -C /opt/zig --strip-components=1
                export PATH="/opt/zig:\$PATH"
                rm -f /tmp/zig.tar.xz
                ZIG_OK=true
                echo "  ✓ zig \$ZIG_VER instalado"
                break 2
            fi
            rm -f /tmp/zig.tar.xz
        done
    done
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
echo "  Steam ($([ "${STEAM_METHOD:-1}" = "2" ] && echo "SteamRT3 Beta 64-bit" || echo "GLFS estable")) + Heroic + Faugus"
[ "${INSTALL_PROTONPLUS:-false}" = "true" ] && echo "  ProtonPlus (compilado desde fuente)"
if [ "${INSTALL_FALCOND:-false}" = "true" ]; then
    echo "  MangoHud + MangoJuice + CPU-X (GameMode omitido por falcond)"
else
    echo "  GameMode + MangoHud + MangoJuice + CPU-X"
fi
[[ "${INSTALL_DISCORD:-n}" =~ ^[SsYy]$ ]] && echo "  Discord"
[[ "${INSTALL_UNIGINE:-n}" =~ ^[SsYy]$ ]] && echo "  Unigine Heaven benchmark"
[ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ] && echo "  Kernel PsyCachy (CachyOS para Ubuntu)"
[ "${INSTALL_FALCOND:-false}" = "true" ] && echo "  Falcond (auto-optimización gaming + GUI)"
[ "${INSTALL_OPTISCALER:-false}" = "true" ] && echo "  OptiScaler (FSR4/DLSS/XeSS)"
echo "  VA-API HW + Wayland nativo (GDK/Qt/SDL/EGL)"
echo "  sysctl gaming + udev rules controladores"
echo ""

exit 0
