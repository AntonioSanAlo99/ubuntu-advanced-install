#!/bin/bash
# Módulo 16: Configurar gaming (Steam .deb + ProtonUp-Qt + game-devices-udev)

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"
# Constantes
GAMING_MAX_MAP_COUNT=2147483642
GAMING_FILE_MAX=524288

echo "═══════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN GAMING"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# DETECCIÓN DE HARDWARE GAMING
# ============================================================================

echo "Detectando hardware gaming..."
echo ""

# ── Detección de GPUs ─────────────────────────────────────────────────────────
# Escanear todas las GPUs del sistema (VGA, 3D controller, Display controller)
HAS_INTEL=false
HAS_AMD=false
HAS_NVIDIA=false

INTEL_GPU=""
AMD_GPU=""
NVIDIA_GPU=""

while IFS= read -r line; do
    if echo "$line" | grep -qi "intel"; then
        HAS_INTEL=true
        INTEL_GPU="$line"
    fi
    if echo "$line" | grep -qi "nvidia"; then
        HAS_NVIDIA=true
        NVIDIA_GPU="$line"
    fi
    if echo "$line" | grep -qi "amd\|radeon\|ati"; then
        HAS_AMD=true
        AMD_GPU="$line"
    fi
done < <(lspci 2>/dev/null | grep -iE "vga|3d|display")

# Determinar configuración
GPU_CONFIG="unknown"
if $HAS_INTEL && $HAS_NVIDIA; then
    GPU_CONFIG="intel+nvidia"
elif $HAS_INTEL && $HAS_AMD; then
    GPU_CONFIG="intel+amd"
elif $HAS_AMD && $HAS_NVIDIA; then
    GPU_CONFIG="amd+nvidia"
elif $HAS_AMD && ! $HAS_INTEL && ! $HAS_NVIDIA; then
    # Podría ser AMD iGPU + AMD dGPU o solo AMD
    AMD_COUNT=$(lspci 2>/dev/null | grep -ciE "(vga|3d|display).*(amd|radeon|ati)")
    if [ "$AMD_COUNT" -ge 2 ]; then
        GPU_CONFIG="amd+amd"
    else
        GPU_CONFIG="amd"
    fi
elif $HAS_INTEL && ! $HAS_AMD && ! $HAS_NVIDIA; then
    GPU_CONFIG="intel"
elif $HAS_NVIDIA && ! $HAS_INTEL && ! $HAS_AMD; then
    GPU_CONFIG="nvidia"
fi

# Mostrar resultado
echo "🎮 GPUs detectadas:"
[ -n "$INTEL_GPU" ]  && echo "   • Intel:  $INTEL_GPU"
[ -n "$AMD_GPU" ]    && echo "   • AMD:    $AMD_GPU"
[ -n "$NVIDIA_GPU" ] && echo "   • NVIDIA: $NVIDIA_GPU"
if [ "$GPU_CONFIG" = "unknown" ]; then
    echo "   • No se identificaron GPUs conocidas"
    lspci 2>/dev/null | grep -iE "vga|3d|display" | head -2 | sed 's/^/   /'
fi
echo ""

# Describir configuración detectada
case "$GPU_CONFIG" in
    intel+nvidia) echo "  Configuración: Intel (iGPU) + NVIDIA (dGPU) — Optimus/PRIME" ;;
    intel+amd)    echo "  Configuración: Intel (iGPU) + AMD (dGPU) — PRIME" ;;
    amd+nvidia)   echo "  Configuración: AMD (iGPU) + NVIDIA (dGPU) — PRIME" ;;
    amd+amd)      echo "  Configuración: AMD (iGPU) + AMD (dGPU) — PRIME" ;;
    intel)        echo "  Configuración: Intel (GPU única)" ;;
    amd)          echo "  Configuración: AMD (GPU única)" ;;
    nvidia)       echo "  Configuración: NVIDIA (GPU única)" ;;
    *)            echo "  Configuración: No identificada" ;;
esac
echo ""

# Ofrecer corrección manual si la detección parece incorrecta
echo "Si la detección no es correcta, puedes seleccionar manualmente:"
echo "  1) AMD (GPU única)"
echo "  2) Intel (GPU única)"
echo "  3) Intel + NVIDIA (Optimus/PRIME)"
echo "  4) Intel + AMD (PRIME)"
echo "  5) AMD + AMD (iGPU + dGPU)"
echo "  6) AMD + NVIDIA (PRIME)"
echo "  7) Usar detección automática [por defecto]"
echo ""
read -p "Selecciona configuración (1-7) [7]: " GPU_MANUAL

case "${GPU_MANUAL:-7}" in
    1) GPU_CONFIG="amd" ;;
    2) GPU_CONFIG="intel" ;;
    3) GPU_CONFIG="intel+nvidia" ;;
    4) GPU_CONFIG="intel+amd" ;;
    5) GPU_CONFIG="amd+amd" ;;
    6) GPU_CONFIG="amd+nvidia" ;;
    *) ;; # Mantener detección automática
esac

echo ""
echo "  → Configuración GPU: $GPU_CONFIG"
echo ""

# Para compatibilidad con el resumen
GPU_DETECTED="$GPU_CONFIG"

# Detectar controladores gaming
echo "🎮 Controladores detectados:"

if lsusb | grep -i "xbox\|045e:0b13\|045e:02ea" > /dev/null 2>&1; then
    echo "   • Xbox Controller"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if lsusb | grep -i "sony\|054c:05c4\|054c:09cc\|054c:0ce6" > /dev/null 2>&1; then
    echo "   • PlayStation Controller (DualShock/DualSense)"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if lsusb | grep -i "nintendo\|057e:2009" > /dev/null 2>&1; then
    echo "   • Nintendo Switch Pro Controller"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if lsusb | grep -i "valve\|28de" > /dev/null 2>&1; then
    echo "   • Steam Controller"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if lsusb | grep -i "8bitdo\|2dc8" > /dev/null 2>&1; then
    echo "   • 8BitDo Controller"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if lsusb | grep -i "logitech\|046d" | grep -i "gamepad\|wheel" > /dev/null 2>&1; then
    echo "   • Logitech Gaming (Gamepad/Wheel)"
    CONTROLLERS_DETECTED=$((CONTROLLERS_DETECTED + 1))
fi

if [ $CONTROLLERS_DETECTED -eq 0 ]; then
    echo "   • Ninguno detectado actualmente"
fi

echo ""
echo "Resumen hardware:"
echo "  GPU: $GPU_DETECTED"
echo "  Controladores: $CONTROLLERS_DETECTED detectado(s)"
echo ""

# ============================================================================
# INSTALACIÓN
# ============================================================================

echo "Instalando componentes gaming..."
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
USERNAME="$USERNAME"
GPU_CONFIG="$GPU_CONFIG"

# ============================================================================
# HABILITAR i386 Y DRIVERS BASE
# ============================================================================

echo ""
echo "Habilitando arquitectura i386..."

dpkg --add-architecture i386
apt update

echo "✓  i386 habilitado"

# ============================================================================
# DRIVERS GAMING (según configuración GPU)
# ============================================================================

echo ""
echo "Instalando drivers gaming para: \$GPU_CONFIG"
echo ""

# ── Función: drivers Mesa/Vulkan base (necesarios para TODAS las configs) ────
install_mesa_base() {
    echo "  → Mesa base + Vulkan tools..."
    apt install -y \$APT_FLAGS \
        mesa-vulkan-drivers \
        mesa-vulkan-drivers:i386 \
        libgl1-mesa-dri \
        libgl1-mesa-dri:i386 \
        mesa-utils \
        vulkan-tools \
        libvulkan1 \
        libvulkan1:i386 \
        libgl1 \
        libgl1:i386
}

# ── Función: drivers Intel ────────────────────────────────────────────────────
install_intel_drivers() {
    echo "  → Drivers Intel (VA-API, media, Vulkan)..."
    apt install -y \$APT_FLAGS \
        intel-media-va-driver \
        intel-gpu-tools \
        libva2 \
        libva-drm2 \
        vainfo
    # intel-media-va-driver-non-free para HW encoding propietario (si existe)
    apt install -y \$APT_FLAGS intel-media-va-driver-non-free 2>/dev/null || true
}

# ── Función: drivers AMD ──────────────────────────────────────────────────────
install_amd_drivers() {
    echo "  → Drivers AMD (RADV Vulkan, VA-API, firmware)..."
    apt install -y \$APT_FLAGS \
        libdrm-amdgpu1 \
        libdrm-amdgpu1:i386 \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        libva2 \
        libva-drm2 \
        vainfo \
        radeontop
    # Firmware AMD — esencial para GPUs RDNA/RDNA2/RDNA3
    apt install -y \$APT_FLAGS firmware-amd-graphics 2>/dev/null || true
    # OverDrive / power management (si el kernel lo soporta)
    apt install -y \$APT_FLAGS lm-sensors 2>/dev/null || true
}

# ── Función: drivers NVIDIA propietarios ──────────────────────────────────────
install_nvidia_drivers() {
    echo "  → Drivers NVIDIA propietarios..."
    # ubuntu-drivers detecta e instala la mejor versión disponible
    if command -v ubuntu-drivers &>/dev/null; then
        echo "    Detectando mejor driver NVIDIA con ubuntu-drivers..."
        NVIDIA_DRIVER=\$(ubuntu-drivers devices 2>/dev/null | grep "recommended" | awk '{print \$3}' | head -1)
        if [ -n "\$NVIDIA_DRIVER" ]; then
            echo "    Instalando \$NVIDIA_DRIVER (recomendado)..."
            apt install -y \$APT_FLAGS "\$NVIDIA_DRIVER"
        else
            echo "    Instalando nvidia-driver genérico..."
            apt install -y \$APT_FLAGS nvidia-driver 2>/dev/null || \
            apt install -y \$APT_FLAGS nvidia-driver-560 2>/dev/null || \
            apt install -y \$APT_FLAGS nvidia-driver-550 2>/dev/null || true
        fi
    else
        apt install -y \$APT_FLAGS ubuntu-drivers-common
        ubuntu-drivers install 2>/dev/null || {
            echo "    Fallback: instalando nvidia-driver..."
            apt install -y \$APT_FLAGS nvidia-driver 2>/dev/null || true
        }
    fi

    # Vulkan NVIDIA (ICD loader) + 32-bit para Steam/Proton
    apt install -y \$APT_FLAGS \
        libvulkan1 \
        libvulkan1:i386 2>/dev/null || true

    # nvidia-vaapi-driver para VA-API sobre NVDEC
    apt install -y \$APT_FLAGS nvidia-vaapi-driver 2>/dev/null || true

    # Herramientas de monitoreo
    apt install -y \$APT_FLAGS nvidia-smi 2>/dev/null || true
}

# ── Función: PRIME / switcheroo (configs multi-GPU) ───────────────────────────
install_prime_support() {
    echo "  → Soporte PRIME / GPU switching..."
    apt install -y \$APT_FLAGS switcheroo-control 2>/dev/null || true
    # prime-select para NVIDIA Optimus
    if echo "\$GPU_CONFIG" | grep -q "nvidia"; then
        apt install -y \$APT_FLAGS nvidia-prime 2>/dev/null || true
    fi
    # Habilitar switcheroo-control para GNOME
    systemctl enable switcheroo-control 2>/dev/null || true
}

# ── Instalar según configuración ─────────────────────────────────────────────
install_mesa_base

case "\$GPU_CONFIG" in
    amd)
        install_amd_drivers
        echo "✓  AMD: RADV (Vulkan) + Mesa (OpenGL) + VA-API"
        ;;
    intel)
        install_intel_drivers
        echo "✓  Intel: ANV (Vulkan) + Mesa (OpenGL) + VA-API"
        ;;
    nvidia)
        install_nvidia_drivers
        echo "✓  NVIDIA: driver propietario + Vulkan"
        ;;
    intel+nvidia)
        install_intel_drivers
        install_nvidia_drivers
        install_prime_support
        echo "✓  Intel + NVIDIA: Optimus/PRIME configurado"
        echo "  Usar 'prime-select nvidia|intel|on-demand' para cambiar GPU"
        echo "  O lanzar juegos con: __NV_PRIME_RENDER_OFFLOAD=1 <app>"
        ;;
    intel+amd)
        install_intel_drivers
        install_amd_drivers
        install_prime_support
        echo "✓  Intel + AMD: PRIME configurado"
        echo "  Usar switcheroo o DRI_PRIME=1 para GPU dedicada"
        ;;
    amd+amd)
        install_amd_drivers
        install_prime_support
        echo "✓  AMD + AMD: iGPU + dGPU con PRIME"
        echo "  Usar DRI_PRIME=1 para GPU dedicada"
        ;;
    amd+nvidia)
        install_amd_drivers
        install_nvidia_drivers
        install_prime_support
        echo "✓  AMD + NVIDIA: PRIME configurado"
        echo "  Usar __NV_PRIME_RENDER_OFFLOAD=1 para GPU NVIDIA"
        ;;
    *)
        # Desconocida: instalar lo esencial
        echo "  ⚠ Config GPU no identificada — instalando drivers genéricos"
        install_amd_drivers 2>/dev/null || true
        install_intel_drivers 2>/dev/null || true
        echo "✓  Drivers genéricos instalados"
        ;;
esac

echo ""

# ============================================================================
# GAMEMODE + MANGOHUD
# ============================================================================

echo ""
echo "Instalando GameMode y MangoHud..."

apt install -y \$APT_FLAGS \
    gamemode \
    mangohud \
    goverlay

echo "✓  GameMode y MangoHud instalados"

# ============================================================================
# STEAM (.deb oficial)
# ============================================================================

echo ""
echo "Instalando Steam..."

# Descargar .deb oficial de Steam
wget --timeout=30 --tries=3 -q "https://cdn.akamai.steamstatic.com/client/installer/steam.deb" \
    -O /tmp/steam.deb

if [ -f /tmp/steam.deb ]; then
    # Instalar dependencias primero
    apt install -y \$APT_FLAGS \
        libgl1-mesa-dri:i386 \
        libgl1:i386 \
        libc6:i386
    
    # Instalar Steam
    apt install -y /tmp/steam.deb
    rm /tmp/steam.deb
    
    echo "✓  Steam instalado (.deb)"
else
    echo "⚠  No se pudo descargar Steam, instalando desde repos..."
    apt install -y steam-installer
fi

# ============================================================================
# FAUGUS LAUNCHER (.deb desde GitHub)
# ============================================================================

echo ""
echo "Instalando Faugus Launcher..."

# Obtener última versión (buscar _all.deb ya que es architecture-independent)
FAUGUS_LATEST=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/Faugus/faugus-launcher/releases/latest | grep "browser_download_url.*_all.deb" | cut -d '"' -f 4)

if [ -n "\$FAUGUS_LATEST" ]; then
    echo "Descargando Faugus Launcher desde GitHub..."
    wget --timeout=30 --tries=3 -q --show-progress "\$FAUGUS_LATEST" -O /tmp/faugus.deb
    
    if [ -f /tmp/faugus.deb ]; then
        apt install -y /tmp/faugus.deb
        rm /tmp/faugus.deb
        echo "  ✓ Faugus Launcher instalado (.deb)"
        
        # Ocultar ImageMagick del menú (instalado como dependencia de Faugus)
        if [ -f /usr/share/applications/display-im6.q16.desktop ]; then
            cat > /usr/share/applications/display-im6.q16.desktop << 'IMAGEMAGICK_EOF'
[Desktop Entry]
Type=Application
Name=ImageMagick (display)
Comment=CLI image tool - installed as Faugus dependency
NoDisplay=true
IMAGEMAGICK_EOF
            echo "  ✓ ImageMagick ocultado del menú (dependencia de Faugus)"
        fi
    else
        echo "  ⚠ No se pudo descargar Faugus Launcher"
    fi
else
    echo "  ⚠ No se pudo obtener última versión de Faugus Launcher"
fi

# ============================================================================
# HEROIC GAMES LAUNCHER (.deb desde GitHub)
# ============================================================================

echo ""
echo "Instalando Heroic Games Launcher..."

# Obtener última versión
HEROIC_LATEST=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)

if [ -n "\$HEROIC_LATEST" ]; then
    wget --timeout=30 --tries=3 -q "\$HEROIC_LATEST" -O /tmp/heroic.deb
    
    if [ -f /tmp/heroic.deb ]; then
        apt install -y /tmp/heroic.deb
        rm /tmp/heroic.deb
        echo "  ✓ Heroic Games Launcher instalado (.deb)"
    else
        echo "  ⚠  No se pudo descargar Heroic"
    fi
else
    echo "⚠  No se pudo obtener última versión de Heroic"
fi

# ============================================================================
# PROTONUP-QT (gestor gráfico de versiones de Proton — AppImage)
# ============================================================================
# ProtonUp-Qt gestiona GE-Proton, Wine-GE, Luxtorpeda, etc. para Steam,
# Lutris y Heroic. Se descarga como AppImage en ~/Applications.
# https://github.com/DavidoTek/ProtonUp-Qt
# ============================================================================

echo ""
echo "Instalando ProtonUp-Qt..."

PROTONUPQT_URL=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/DavidoTek/ProtonUp-Qt/releases/latest \
    | grep "browser_download_url.*\.AppImage\"" | cut -d '"' -f 4 | head -1)

if [ -n "\$PROTONUPQT_URL" ]; then
    APPS_DIR="/home/\$USERNAME/Applications"
    mkdir -p "\$APPS_DIR"

    echo "  Descargando ProtonUp-Qt AppImage..."
    if wget --timeout=30 --tries=3 -q "\$PROTONUPQT_URL" -O "\$APPS_DIR/ProtonUp-Qt.AppImage"; then
        chmod +x "\$APPS_DIR/ProtonUp-Qt.AppImage"
        chown \$(id -u \$USERNAME):\$(id -g \$USERNAME) "\$APPS_DIR/ProtonUp-Qt.AppImage"
        echo "  ✓ ProtonUp-Qt instalado en ~/Applications/"
    else
        echo "  ⚠ Error descargando ProtonUp-Qt — omitido"
    fi
else
    echo "  ⚠ No se pudo obtener URL de ProtonUp-Qt — omitido"
fi

# ============================================================================
# ESTRUCTURA COMPARTIDA DE PROTON
# ============================================================================

echo ""
echo "Configurando estructura compartida de Proton..."

# Directorio unificado para Proton
PROTON_SHARED="/home/\$USERNAME/.local/share/Steam/compatibilitytools.d"

mkdir -p "\$PROTON_SHARED"
chown -R \$USERNAME:\$USERNAME "\$PROTON_SHARED"

# Faugus Launcher
mkdir -p /home/\$USERNAME/.local/share/faugus-launcher
ln -sf "\$PROTON_SHARED" /home/\$USERNAME/.local/share/faugus-launcher/compatibilitytools.d

# Heroic
mkdir -p /home/\$USERNAME/.config/heroic/tools/proton
ln -sf "\$PROTON_SHARED" /home/\$USERNAME/.config/heroic/tools/proton/Steam

chown -R \$USERNAME:\$USERNAME /home/\$USERNAME/.local/share/faugus-launcher

echo "✓  Estructura compartida configurada"
echo "  Ubicación: \$PROTON_SHARED"

# ============================================================================
# PROTON-CACHYOS (última versión)
# ============================================================================

echo ""
echo "Instalando Proton-Cachyos..."

# Obtener última versión de Proton-Cachyos
CACHYOS_API=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest)
CACHYOS_LATEST=\$(echo "\$CACHYOS_API" | grep "browser_download_url.*tar.gz" | grep -v "sha256sum" | head -1 | cut -d '"' -f 4)

if [ -n "\$CACHYOS_LATEST" ]; then
    # Descargar y extraer
    wget --timeout=30 --tries=3 -q "\$CACHYOS_LATEST" -O /tmp/proton-cachyos.tar.gz
    
    if [ -f /tmp/proton-cachyos.tar.gz ]; then
        cd "\$PROTON_SHARED"
        tar xzf /tmp/proton-cachyos.tar.gz
        
        rm /tmp/proton-cachyos.tar.gz
        
        chown -R \$USERNAME:\$USERNAME "\$PROTON_SHARED"
        
        echo "  ✓ Proton-Cachyos instalado"
        echo "  Gestionar con ProtonUp-Qt para actualizar"
    else
        echo "  ⚠  No se pudo descargar Proton-Cachyos"
    fi
else
    echo "⚠  No se pudo obtener última versión de Proton-Cachyos"
    echo "  Usar ProtonUp-Qt después de instalación"
fi

# ============================================================================
# UDEV RULES PARA CONTROLADORES
# ============================================================================

echo ""
echo "Configurando udev rules para controladores..."

# Descargar y aplicar reglas oficiales de game-devices-udev (fabiscafe/Codeberg)
# Cubre: Valve, Sony, Microsoft, Nintendo, 8BitDo, Logitech, Razer, HORI,
#        Nacon, PDP, Mad Catz, ASTRO, NVIDIA Shield, Google Stadia y más.
UDEV_ZIP_URL="https://codeberg.org/fabiscafe/game-devices-udev/archive/main.zip"
UDEV_TMP="/tmp/game-devices-udev"

echo "  Descargando game-devices-udev desde Codeberg..."
mkdir -p "\$UDEV_TMP"

if wget --timeout=30 --tries=3 -q "\$UDEV_ZIP_URL" -O "\$UDEV_TMP/main.zip"; then
    cd "\$UDEV_TMP"
    unzip -q main.zip
    # Copiar todos los archivos .rules al directorio de udev
    find . -name "71-*.rules" -exec cp {} /etc/udev/rules.d/ \;
    # Habilitar módulo uinput al arranque (requerido por las reglas de uinput)
    echo "uinput" > /etc/modules-load.d/uinput.conf
    cd /
    rm -rf "\$UDEV_TMP"
    echo "✓  udev rules instaladas desde game-devices-udev (Codeberg)"
else
    echo "  ⚠ No se pudo descargar game-devices-udev — omitido"
    rm -rf "\$UDEV_TMP"
fi

udevadm control --reload-rules 2>/dev/null || true

echo "✓  udev rules configuradas"

# ============================================================================
# LÍMITES DEL SISTEMA
# ============================================================================

echo ""
echo "Configurando límites del sistema..."

cat >> /etc/security/limits.conf << 'LIMITSEOF'

# Gaming optimizations
*    soft    nofile    524288
*    hard    nofile    524288
*    soft    memlock   unlimited
*    hard    memlock   unlimited
LIMITSEOF

echo "✓  Límites configurados"

# ============================================================================
# SYSCTL OPTIMIZACIONES
# ============================================================================

echo ""
echo "Aplicando optimizaciones sysctl..."

cat > /etc/sysctl.d/99-gaming.conf << 'SYSCTLEOF'
# Gaming optimizations

# Memory management
vm.max_map_count = 2147483642
vm.swappiness = 10

# Network gaming
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTLEOF

sysctl -p /etc/sysctl.d/99-gaming.conf 2>/dev/null || true

echo "✓  Optimizaciones sysctl aplicadas"

CHROOTEOF

# ============================================================================
# CONFIRMACIÓN FINAL
# ============================================================================
# CONFIGURACIÓN GNOME PARA GAMING: VRR Y HDR
# ============================================================================
# VRR disponible desde GNOME 46+
# HDR disponible desde GNOME 48+
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN GNOME - VRR Y HDR"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Verificar si GNOME está instalado
if arch-chroot "$TARGET" command -v gnome-shell &> /dev/null; then
    echo "GNOME detectado, verificando versión para VRR/HDR..."
    
    # Detectar versión de GNOME
    GNOME_VERSION=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    
    if [ -n "$GNOME_VERSION" ]; then
        echo "GNOME $GNOME_VERSION detectado"
        echo ""
        
        # Configurar VRR si GNOME >= 46
        if [ "$GNOME_VERSION" -ge 46 ]; then
            echo "✓ GNOME $GNOME_VERSION soporta VRR (Variable Refresh Rate)"
            
            # Crear script de configuración para primer login
            arch-chroot "$TARGET" /bin/bash << 'VRR_SCRIPT'
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)

if [ -n "$USERNAME" ]; then
    # Crear script que se ejecutará en primer login
    cat > /home/$USERNAME/.config/autostart/enable-vrr.desktop << 'VREOF'
[Desktop Entry]
Type=Application
Name=Enable VRR
Exec=/bin/bash -c 'gsettings set org.gnome.mutter experimental-features "[\\"variable-refresh-rate\\"]" && rm ~/.config/autostart/enable-vrr.desktop'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
VREOF
    
    chown $USERNAME:$USERNAME /home/$USERNAME/.config/autostart/enable-vrr.desktop
    echo "  → VRR se habilitará en primer login"
fi
VRR_SCRIPT
            
        else
            echo "⚠ GNOME $GNOME_VERSION no soporta VRR (requiere GNOME 46+)"
        fi
        
        # Configurar HDR si GNOME >= 48
        if [ "$GNOME_VERSION" -ge 48 ]; then
            echo "✓ GNOME $GNOME_VERSION soporta HDR (High Dynamic Range)"
            
            # Crear script de configuración para primer login
            arch-chroot "$TARGET" /bin/bash << 'HDR_SCRIPT'
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)

if [ -n "$USERNAME" ]; then
    # Crear script que se ejecutará en primer login
    cat > /home/$USERNAME/.config/autostart/enable-hdr.desktop << 'HDREOF'
[Desktop Entry]
Type=Application
Name=Enable HDR
Exec=/bin/bash -c 'gsettings set org.gnome.mutter experimental-features "[\\"variable-refresh-rate\\", \\"hdr\\"]" && rm ~/.config/autostart/enable-hdr.desktop'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
HDREOF
    
    chown $USERNAME:$USERNAME /home/$USERNAME/.config/autostart/enable-hdr.desktop
    echo "  → HDR se habilitará en primer login (requiere monitor HDR compatible)"
fi
HDR_SCRIPT
            
        elif [ "$GNOME_VERSION" -ge 46 ]; then
            echo "⚠ GNOME $GNOME_VERSION no soporta HDR (requiere GNOME 48+)"
        fi
        
        echo ""
        
        # Resumen
        if [ "$GNOME_VERSION" -ge 48 ]; then
            echo "Características gaming habilitadas:"
            echo "  ✅ VRR (Variable Refresh Rate) - GNOME $GNOME_VERSION"
            echo "  ✅ HDR (High Dynamic Range) - GNOME $GNOME_VERSION"
            echo ""
            echo "Notas:"
            echo "  • VRR funciona con monitores FreeSync/G-Sync"
            echo "  • HDR requiere monitor HDR compatible"
            echo "  • Verifica en Configuración → Pantallas después del primer login"
        elif [ "$GNOME_VERSION" -ge 46 ]; then
            echo "Características gaming habilitadas:"
            echo "  ✅ VRR (Variable Refresh Rate) - GNOME $GNOME_VERSION"
            echo "  ⚠ HDR no disponible (requiere GNOME 48+)"
            echo ""
            echo "Notas:"
            echo "  • VRR funciona con monitores FreeSync/G-Sync"
            echo "  • Actualiza a GNOME 48+ para soporte HDR"
        else
            echo "Características gaming:"
            echo "  ⚠ VRR no disponible (requiere GNOME 46+)"
            echo "  ⚠ HDR no disponible (requiere GNOME 48+)"
            echo ""
            echo "Nota: Actualiza a GNOME 46+ para VRR y GNOME 48+ para HDR"
        fi
        
    else
        echo "⚠ No se pudo detectar versión de GNOME"
        echo "VRR/HDR no configurados automáticamente"
    fi
    
else
    echo "GNOME no detectado, omitiendo configuración VRR/HDR"
fi

echo ""

# ============================================================================
# ANIMACIONES DE GNOME PARA GAMING
# ============================================================================

read -p "¿Deshabilitar animaciones de GNOME para menor latencia? (s/n) [n]: " DISABLE_ANIMATIONS
DISABLE_ANIMATIONS=${DISABLE_ANIMATIONS:-n}
echo ""

if [ "$DISABLE_ANIMATIONS" = "s" ] || [ "$DISABLE_ANIMATIONS" = "S" ]; then
    # Usar dconf defaults de sistema (funciona en chroot sin D-Bus)
    arch-chroot "$TARGET" /bin/bash << 'ANIMEOF'
mkdir -p /etc/dconf/db/local.d
cat >> /etc/dconf/db/local.d/00-gnome-installer << 'DCONF_ANIM'

[org/gnome/desktop/interface]
enable-animations=false
DCONF_ANIM
dconf update
echo "✓  Animaciones deshabilitadas via dconf (menor latencia en gaming)"
ANIMEOF
else
    echo "  ✓ Animaciones mantenidas (experiencia visual completa)"
fi

# ============================================================================
# KERNEL CACHYOS (OPCIONAL — kernel gaming con schedulers BORE/EEVDF)
# ============================================================================
# CachyOS kernel: patches de rendimiento, schedulers optimizados, sched-ext,
# BBRv3, baja latencia, AMD P-State, Steam Deck drivers, PCIe ACS override.
# No existe repositorio apt oficial para Ubuntu — se usa linux-psycachy
# (fork activo del archivado CachyOS/linux-cachyos-deb) que compila .deb
# con las opciones de CachyOS adaptadas para Debian/Ubuntu.
#
# El builder se instala en /opt/linux-psycachy y se puede re-ejecutar
# para actualizar el kernel cuando haya nuevas versiones.
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  KERNEL CACHYOS (opcional)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Kernel CachyOS con patches de rendimiento gaming."
echo ""
echo "Variantes disponibles:"
echo "  1) BORE   — Burst-Oriented Response Enhancer (baja latencia)"
echo "              Mejor para gaming y escritorio interactivo"
echo "  2) EEVDF  — Earliest Eligible Virtual Deadline First (stock tuneado)"
echo "              Mejor equilibrio rendimiento/estabilidad"
echo "  3) No instalar"
echo ""
read -p "Selecciona variante (1/2/3) [3]: " CACHYOS_CHOICE

case "${CACHYOS_CHOICE:-3}" in
    1) CACHYOS_SCHED="bore" ;;
    2) CACHYOS_SCHED="eevdf" ;;
    *) CACHYOS_SCHED="" ;;
esac

if [ -n "$CACHYOS_SCHED" ]; then
    echo ""
    echo "Preparando kernel CachyOS ($CACHYOS_SCHED)..."
    echo "Esto requiere compilar el kernel — puede tardar 15-45 minutos."
    echo ""

    arch-chroot "$TARGET" /bin/bash << CACHYOS_EOF
export DEBIAN_FRONTEND=noninteractive
SCHED="$CACHYOS_SCHED"

# Dependencias de compilación
apt install -y build-essential bc kmod cpio flex libncurses-dev \
    libelf-dev libssl-dev dwarves bison lsb-release \
    wget git fakeroot whiptail debhelper rsync

# Clonar linux-psycachy (fork activo de CachyOS/linux-cachyos-deb)
PSYCACHY_DIR="/opt/linux-psycachy"
rm -rf "\$PSYCACHY_DIR"
if git clone --depth 1 https://github.com/psygreg/linux-psycachy.git "\$PSYCACHY_DIR" 2>/dev/null; then
    cd "\$PSYCACHY_DIR"
    chmod +x cachyos-deb.sh

    # Compilar con defaults estables (-s) que usa scheduler BORE por defecto
    # Para EEVDF necesitamos el modo interactivo o editar la config
    if [ "\$SCHED" = "bore" ]; then
        # Modo estable con BORE (defaults de psycachy)
        echo "Compilando kernel CachyOS con BORE scheduler..."
        ./cachyos-deb.sh -g 2>&1 | tail -5
    else
        # EEVDF: compilar con modo genérico y parchar la config
        echo "Compilando kernel CachyOS con EEVDF scheduler..."
        # Establecer EEVDF como scheduler antes de compilar
        export CACHY_SCHED="eevdf"
        ./cachyos-deb.sh -g 2>&1 | tail -5
    fi

    # Buscar e instalar los .deb generados
    DEB_DIR="\$(find /tmp -maxdepth 2 -name 'linux-image-psycachy*.deb' -printf '%h\n' 2>/dev/null | head -1)"
    if [ -z "\$DEB_DIR" ]; then
        DEB_DIR="\$(find "\$PSYCACHY_DIR" -maxdepth 2 -name 'linux-image-psycachy*.deb' -printf '%h\n' 2>/dev/null | head -1)"
    fi

    if [ -n "\$DEB_DIR" ] && ls "\$DEB_DIR"/linux-image-psycachy*.deb &>/dev/null; then
        echo "Instalando kernel CachyOS..."
        dpkg -i "\$DEB_DIR"/linux-image-psycachy*.deb "\$DEB_DIR"/linux-headers-psycachy*.deb 2>/dev/null
        
        # Actualizar GRUB
        update-initramfs -u -k all 2>/dev/null || true
        update-grub 2>/dev/null || true

        echo ""
        echo "✓  Kernel CachyOS (\$SCHED) instalado"
        echo "  El kernel de Ubuntu se mantiene como fallback en GRUB"
    else
        echo ""
        echo "  ⚠ No se encontraron .deb compilados"
        echo "  El builder queda en \$PSYCACHY_DIR para compilar manualmente:"
        echo "  cd \$PSYCACHY_DIR && sudo ./cachyos-deb.sh"
    fi

    # Limpiar archivos temporales de compilación (no el repo)
    rm -rf /tmp/linux-cachyos-* 2>/dev/null || true
else
    echo "  ⚠ No se pudo clonar linux-psycachy"
    echo "  Instalar manualmente: https://github.com/psygreg/linux-psycachy"
fi

echo ""
echo "Para actualizar el kernel en el futuro:"
echo "  cd /opt/linux-psycachy && git pull && sudo ./cachyos-deb.sh -g"
CACHYOS_EOF

    CACHYOS_INSTALLED=true
else
    echo ""
    echo "Kernel CachyOS no instalado (se omitió)"
    CACHYOS_INSTALLED=false
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GAMING COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "Hardware detectado:"
echo "  🎮 GPU: $GPU_CONFIG"
echo "  🎮 Controladores: $CONTROLLERS_DETECTED"
echo ""

echo "Drivers GPU instalados:"
case "$GPU_CONFIG" in
    amd)          echo "  ✅ AMD: RADV (Vulkan) + Mesa (OpenGL) + VA-API" ;;
    intel)        echo "  ✅ Intel: ANV (Vulkan) + Mesa (OpenGL) + VA-API" ;;
    nvidia)       echo "  ✅ NVIDIA: driver propietario + Vulkan" ;;
    intel+nvidia) echo "  ✅ Intel: ANV + VA-API"
                  echo "  ✅ NVIDIA: driver propietario + Vulkan"
                  echo "  ✅ PRIME/Optimus: nvidia-prime + switcheroo" ;;
    intel+amd)    echo "  ✅ Intel: ANV + VA-API"
                  echo "  ✅ AMD: RADV + Mesa + VA-API"
                  echo "  ✅ PRIME: switcheroo (DRI_PRIME=1)" ;;
    amd+amd)      echo "  ✅ AMD: RADV + Mesa + VA-API (iGPU + dGPU)"
                  echo "  ✅ PRIME: switcheroo (DRI_PRIME=1)" ;;
    amd+nvidia)   echo "  ✅ AMD: RADV + VA-API"
                  echo "  ✅ NVIDIA: driver propietario + Vulkan"
                  echo "  ✅ PRIME: nvidia-prime + switcheroo" ;;
    *)            echo "  ✅ Drivers genéricos (Mesa + Vulkan)" ;;
esac
echo ""

echo "Software instalado:"
echo "  ✅ Steam (oficial .deb)"
echo "  ✅ Heroic Games Launcher (.deb)"
echo "  ✅ Faugus Launcher (.deb)"
echo "  ✅ ProtonUp-Qt (AppImage — gestor de Proton/Wine-GE)"
echo "  ✅ Proton-Cachyos (optimizado)"
echo "  ✅ GameMode + MangoHud + GOverlay"
echo ""

echo "Configuración compartida:"
echo "  ~/.local/share/Steam/compatibilitytools.d/"
echo "    ├─ Proton-Cachyos-X.X"
echo "    └─ (otras versiones Proton)"
echo ""

echo "Optimizaciones aplicadas:"
echo "  ✅ Drivers GPU según configuración ($GPU_CONFIG)"
echo "  ✅ Parámetros sysctl gaming (vm.max_map_count)"
echo "  ✅ Límites del sistema aumentados"
echo "  ✅ Reglas udev para controladores (PS4/5, Xbox, Switch Pro)"
if [ "${CACHYOS_INSTALLED:-false}" = "true" ]; then
    echo "  ✅ Kernel CachyOS (${CACHYOS_SCHED}, baja latencia)"
fi

# Mostrar estado VRR/HDR según versión GNOME
if arch-chroot "$TARGET" command -v gnome-shell &> /dev/null; then
    GNOME_VER=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    if [ -n "$GNOME_VER" ]; then
        if [ "$GNOME_VER" -ge 48 ]; then
            echo "  ✅ GNOME $GNOME_VER: VRR + HDR habilitados"
        elif [ "$GNOME_VER" -ge 46 ]; then
            echo "  ✅ GNOME $GNOME_VER: VRR habilitado (HDR requiere 48+)"
        fi
    fi
fi
echo ""

echo "Próximos pasos:"
echo "  1. Reiniciar para aplicar todas las optimizaciones"
echo "  2. Configurar MangoHud: goverlay"
echo "  3. Ejecutar Steam para completar instalación"
echo "  4. GameMode funciona automáticamente con Steam"
case "$GPU_CONFIG" in
    intel+nvidia)
        echo "  5. Cambiar GPU: prime-select nvidia|intel|on-demand"
        echo "     O lanzar con: __NV_PRIME_RENDER_OFFLOAD=1 <juego>" ;;
    amd+nvidia)
        echo "  5. Lanzar en NVIDIA: __NV_PRIME_RENDER_OFFLOAD=1 <juego>" ;;
    intel+amd|amd+amd)
        echo "  5. Lanzar en dGPU: DRI_PRIME=1 <juego>" ;;
esac
if arch-chroot "$TARGET" command -v gnome-shell &> /dev/null; then
    GNOME_VER=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1)
    if [ -n "$GNOME_VER" ] && [ "$GNOME_VER" -ge 46 ]; then
        echo "  5. Verificar VRR/HDR en Configuración → Pantallas"
    fi
fi
echo ""

exit 0

