#!/bin/bash
# Módulo 16: Configurar gaming (todo .deb + umu-launcher + Proton-Cachyos)

set -eo pipefail  # Detectar errores en pipelines

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

GPU_DETECTED="Desconocida"
CONTROLLERS_DETECTED=0

# Detectar GPU
if lspci | grep -i "vga\|3d\|display" | grep -i "nvidia" > /dev/null 2>&1; then
    GPU_DETECTED="NVIDIA"
    echo "🎮 GPU detectada:"
    lspci | grep -i "vga\|3d" | grep -i "nvidia" | sed 's/^/   /'
elif lspci | grep -i "vga\|3d\|display" | grep -i "amd\|radeon" > /dev/null 2>&1; then
    GPU_DETECTED="AMD"
    echo "🎮 GPU detectada:"
    lspci | grep -i "vga\|3d" | grep -i "amd\|radeon" | sed 's/^/   /'
elif lspci | grep -i "vga\|3d\|display" | grep -i "intel" > /dev/null 2>&1; then
    GPU_DETECTED="Intel"
    echo "🎮 GPU detectada:"
    lspci | grep -i "vga\|3d" | grep -i "intel" | sed 's/^/   /'
else
    echo "🎮 GPU: No identificada específicamente"
    lspci | grep -i "vga\|3d\|display" | head -1 | sed 's/^/   /'
fi

echo ""

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

# ============================================================================
# HABILITAR i386 Y DRIVERS BASE
# ============================================================================

echo ""
echo "Habilitando arquitectura i386..."

dpkg --add-architecture i386
apt update

echo "✓ i386 habilitado"

# ============================================================================
# DRIVERS GAMING
# ============================================================================

echo ""
echo "Instalando drivers gaming..."

# Mesa (OpenGL/Vulkan)
apt install -y \$APT_FLAGS \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386 \
    mesa-utils \
    vulkan-tools

# Dependencias Wine/Proton
apt install -y \$APT_FLAGS \
    libvulkan1 \
    libvulkan1:i386 \
    libgl1 \
    libgl1:i386

echo "✓ Drivers instalados"

# ============================================================================
# GAMEMODE + MANGOHUD
# ============================================================================

echo ""
echo "Instalando GameMode y MangoHud..."

apt install -y \$APT_FLAGS \
    gamemode \
    mangohud \
    goverlay

echo "✓ GameMode y MangoHud instalados"

# ============================================================================
# STEAM (.deb oficial)
# ============================================================================

echo ""
echo "Instalando Steam..."

# Descargar .deb oficial de Steam
wget --timeout=30 --tries=3 -q "https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb" \
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
    
    echo "✓ Steam instalado (.deb)"
else
    echo "⚠ No se pudo descargar Steam, instalando desde repos..."
    apt install -y steam-installer
fi

# ============================================================================
# FAUGUS LAUNCHER (.deb desde GitHub)
# ============================================================================

echo ""
echo "Instalando Faugus Launcher..."

# Obtener última versión
FAUGUS_LATEST=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/Faugus/faugus-launcher/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)

if [ -n "\$FAUGUS_LATEST" ]; then
    wget --timeout=30 --tries=3 -q "\$FAUGUS_LATEST" -O /tmp/faugus.deb
    
    if [ -f /tmp/faugus.deb ]; then
        apt install -y /tmp/faugus.deb
        rm /tmp/faugus.deb
        echo "✓ Faugus Launcher instalado (.deb)"
        
        # Ocultar ImageMagick del menú (instalado como dependencia de Faugus)
        if [ -f /usr/share/applications/display-im6.q16.desktop ]; then
            cat > /usr/share/applications/display-im6.q16.desktop << 'IMAGEMAGICK_EOF'
[Desktop Entry]
Type=Application
Name=ImageMagick (display)
Comment=CLI image tool - installed as Faugus dependency
NoDisplay=true
IMAGEMAGICK_EOF
            echo "✓ ImageMagick ocultado del menú (dependencia de Faugus)"
        fi
    else
        echo "⚠ No se pudo descargar Faugus Launcher"
    fi
else
    echo "⚠ No se pudo obtener última versión de Faugus Launcher"
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
        echo "✓ Heroic Games Launcher instalado (.deb)"
    else
        echo "⚠ No se pudo descargar Heroic"
    fi
else
    echo "⚠ No se pudo obtener última versión de Heroic"
fi

# ============================================================================
# PROTONUP-QT (gestor gráfico de Proton)
# ============================================================================

echo ""
echo "Instalando ProtonUp-Qt..."

# Obtener última versión de ProtonUp-Qt
PROTONUP_LATEST=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/DavidoTek/ProtonUp-Qt/releases/latest | grep "browser_download_url.*_amd64.deb" | cut -d '"' -f 4)

if [ -n "\$PROTONUP_LATEST" ]; then
    wget --timeout=30 --tries=3 -q "\$PROTONUP_LATEST" -O /tmp/protonup-qt.deb
    
    if [ -f /tmp/protonup-qt.deb ]; then
        apt install -y /tmp/protonup-qt.deb
        rm /tmp/protonup-qt.deb
        echo "✓ ProtonUp-Qt instalado (.deb)"
    else
        echo "⚠ No se pudo descargar ProtonUp-Qt"
    fi
else
    echo "⚠ No se pudo obtener última versión de ProtonUp-Qt"
fi

# ============================================================================
# UMU-LAUNCHER (unificador de Proton)
# ============================================================================

echo ""
echo "Instalando umu-launcher..."

# Instalar dependencias
apt install -y \$APT_FLAGS \
    python3 \
    python3-pip \
    python3-venv

# Instalar umu-launcher desde pip
pip3 install --break-system-packages umu-launcher || pip3 install umu-launcher

# Crear directorio de configuración
mkdir -p /etc/skel/.config/umu
mkdir -p /etc/skel/.local/share/umu

echo "✓ umu-launcher instalado"

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

# umu-launcher configuración
cat > /home/\$USERNAME/.config/umu/umu.conf << 'UMUCONF'
[umu]
proton_dir = ~/.local/share/Steam/compatibilitytools.d
cache_dir = ~/.cache/umu
UMUCONF

chown -R \$USERNAME:\$USERNAME /home/\$USERNAME/.config/umu
chown -R \$USERNAME:\$USERNAME /home/\$USERNAME/.local/share/faugus-launcher

echo "✓ Estructura compartida configurada"
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
        
        echo "✓ Proton-Cachyos instalado"
        echo "  Gestionar con ProtonUp-Qt para actualizar"
    else
        echo "⚠ No se pudo descargar Proton-Cachyos"
    fi
else
    echo "⚠ No se pudo obtener última versión de Proton-Cachyos"
    echo "  Usar ProtonUp-Qt después de instalación"
fi

# ============================================================================
# CONFIGURACIÓN DE VARIABLES DE ENTORNO
# ============================================================================

echo ""
echo "Configurando variables de entorno gaming..."

cat > /etc/profile.d/99-gaming-env.sh << 'GAMINGENV'
#!/bin/bash
# Variables de entorno para gaming

# GameMode
export LD_PRELOAD=/usr/\$LIB/libgamemode.so.0:\$LD_PRELOAD

# MangoHud
export MANGOHUD=1
export MANGOHUD_CONFIG=fps,cpu_temp,gpu_temp,ram,vram

# AMD GPU (si aplica)
export RADV_PERFTEST=aco
export AMD_VULKAN_ICD=RADV

# DXVK/VKD3D optimizaciones
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH=\$HOME/.cache/dxvk
export VKD3D_SHADER_CACHE_PATH=\$HOME/.cache/vkd3d

# Wine/Proton
export WINEFSYNC=1
export WINEESYNC=1

# umu-launcher
export UMU_PROTON_DIR=\$HOME/.local/share/Steam/compatibilitytools.d
GAMINGENV

chmod +x /etc/profile.d/99-gaming-env.sh

echo "✓ Variables de entorno configuradas"

# ============================================================================
# UDEV RULES PARA CONTROLADORES
# ============================================================================

echo ""
echo "Configurando udev rules para controladores..."

# Reglas para múltiples controladores
cat > /etc/udev/rules.d/99-gaming-controllers.rules << 'UDEVEOF'
# Steam Controller
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"

# PS4 DualShock 4
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"

# PS5 DualSense
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"

# Xbox One/Series
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="02ea", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="0b13", MODE="0666"

# Nintendo Switch Pro
SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0666"

# 8BitDo
SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", MODE="0666"

# Logitech
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", MODE="0666"
UDEVEOF

udevadm control --reload-rules 2>/dev/null || true

echo "✓ udev rules configuradas"

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

echo "✓ Límites configurados"

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

echo "✓ Optimizaciones sysctl aplicadas"

CHROOTEOF

# ============================================================================
# CONFIRMACIÓN FINAL
# ============================================================================
# CONFIGURACIÓN GNOME PARA GAMING: VRR Y HDR
# ============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN GNOME - VRR Y HDR"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verificar si GNOME está instalado
if command -v gnome-shell &> /dev/null; then
    echo "GNOME detectado, configurando VRR y HDR..."
    echo ""
    
    # Configurar para el usuario
    arch-chroot "$TARGET" /bin/bash << 'GNOMEVRR'
# Configurar como el usuario real (no root)
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)

if [ -n "$USERNAME" ]; then
    # VRR (Variable Refresh Rate)
    echo "Habilitando VRR (Variable Refresh Rate)..."
    
    sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter experimental-features \
        "['variable-refresh-rate', 'scale-monitor-framebuffer']"
    
    echo "✓ VRR habilitado en GNOME Mutter"
    
    # HDR (High Dynamic Range)
    echo ""
    echo "Configurando soporte HDR..."
    
    # Habilitar características experimentales para HDR
    sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter experimental-features \
        "['variable-refresh-rate', 'scale-monitor-framebuffer', 'rt-scheduler']"
    
    echo "✓ Características experimentales habilitadas (incluye base para HDR)"
    
    # Nota: HDR completo requiere GNOME 47+ y hardware compatible
    GNOME_VERSION=$(gnome-shell --version 2>/dev/null | grep -oP '\d+\.\d+' | cut -d. -f1)
    
    if [ -n "$GNOME_VERSION" ] && [ "$GNOME_VERSION" -ge 47 ]; then
        echo "✓ GNOME $GNOME_VERSION detectado - Soporte HDR disponible"
        echo "  HDR se habilitará automáticamente con monitores compatibles"
    else
        echo "⚠ GNOME $GNOME_VERSION - HDR completo requiere GNOME 47+"
        echo "  VRR funcionará, HDR limitado o no disponible"
    fi
    
    # Configuraciones adicionales para gaming (OPCIONAL)
    echo ""
    echo "Aplicando optimizaciones adicionales de GNOME..."
    
    # Configurar compositor para menor latencia
    sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter attach-modal-dialogs false
    echo "✓ Compositor optimizado"
    
    echo ""
    
GNOMEVRR

    # Preguntar sobre desactivar animaciones (fuera de chroot para interacción)
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    read -p "¿Deshabilitar animaciones de GNOME para menor latencia? (s/n) [n]: " DISABLE_ANIMATIONS
    DISABLE_ANIMATIONS=${DISABLE_ANIMATIONS:-n}
    echo ""
    
    if [ "$DISABLE_ANIMATIONS" = "s" ] || [ "$DISABLE_ANIMATIONS" = "S" ]; then
        arch-chroot "$TARGET" /bin/bash << 'ANIMEOF'
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)
if [ -n "$USERNAME" ]; then
    sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.interface enable-animations false
    echo "✓ Animaciones deshabilitadas (menor latencia en gaming)"
    
    # Añadir al archivo de configuración
    cat >> /home/$USERNAME/.config/gaming-display-config.txt << 'EOF'

## Animaciones
Estado: Deshabilitadas
Comando aplicado: gsettings set org.gnome.desktop.interface enable-animations false
Beneficio: Menor latencia de input, mejor rendimiento en gaming

Revertir:
gsettings set org.gnome.desktop.interface enable-animations true
EOF
    chown $USERNAME:$USERNAME /home/$USERNAME/.config/gaming-display-config.txt
fi
ANIMEOF
    else
        arch-chroot "$TARGET" /bin/bash << 'ANIMEKEEP'
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)
if [ -n "$USERNAME" ]; then
    # Añadir al archivo de configuración
    cat >> /home/$USERNAME/.config/gaming-display-config.txt << 'EOF'

## Animaciones
Estado: Habilitadas (no modificadas)
Nota: Las animaciones están activas (experiencia visual completa)

Para deshabilitar manualmente:
gsettings set org.gnome.desktop.interface enable-animations false
EOF
    chown $USERNAME:$USERNAME /home/$USERNAME/.config/gaming-display-config.txt
fi
ANIMEKEEP
        echo "✓ Animaciones mantenidas (experiencia visual completa)"
    fi
    
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✓ CONFIGURACIÓN GNOME APLICADA"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    echo "Características habilitadas:"
    echo "  ✅ VRR (Variable Refresh Rate)"
    echo "  ✅ Características experimentales para HDR"
    if [ "$DISABLE_ANIMATIONS" = "s" ] || [ "$DISABLE_ANIMATIONS" = "S" ]; then
        echo "  ✅ Animaciones deshabilitadas (menor latencia)"
    else
        echo "  ℹ️  Animaciones habilitadas (experiencia visual completa)"
    fi
    echo "  ✅ Compositor optimizado"
    echo ""
    
    echo "Notas importantes:"
    echo "  • VRR funcionará con monitores FreeSync/G-Sync compatibles"
    echo "  • HDR requiere GNOME 47+, monitor HDR y GPU compatible"
    echo "  • Verifica en Settings → Displays después del reinicio"
    echo "  • Archivo de referencia: ~/.config/gaming-display-config.txt"
    echo ""
    
else
    echo "GNOME no detectado, omitiendo configuración VRR/HDR"
    echo "(Esta configuración es específica para GNOME Desktop)"
    echo ""
fi

# ============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✓ CONFIGURACIÓN GAMING COMPLETADA"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Hardware detectado:"
echo "  🎮 GPU: $GPU_DETECTED"
echo "  🎮 Controladores: $CONTROLLERS_DETECTED"
echo ""

echo "Software instalado:"
echo "  ✅ Steam (oficial .deb)"
echo "  ✅ Faugus Launcher (.deb)"
echo "  ✅ Heroic Games Launcher (.deb)"
echo "  ✅ ProtonUp-Qt (gestor gráfico de Proton)"
echo "  ✅ umu-launcher (unificador Proton)"
echo "  ✅ Proton-Cachyos (optimizado)"
echo "  ✅ GameMode + MangoHud"
echo ""

echo "Configuración compartida:"
echo "  ~/.local/share/Steam/compatibilitytools.d/"
echo "    ├─ Proton-Cachyos-X.X"
echo "    └─ (otras versiones Proton)"
echo ""

echo "Optimizaciones aplicadas:"
echo "  ✅ Drivers Mesa + Vulkan"
echo "  ✅ Parámetros sysctl gaming"
echo "  ✅ Límites del sistema aumentados"
echo "  ✅ Reglas udev para controladores"
if command -v gnome-shell &> /dev/null; then
    echo "  ✅ GNOME: VRR + HDR habilitados"
    if [ "$DISABLE_ANIMATIONS" = "s" ] || [ "$DISABLE_ANIMATIONS" = "S" ]; then
        echo "  ✅ GNOME: Animaciones deshabilitadas"
    fi
fi
echo ""

echo "Próximos pasos:"
echo "  1. Reiniciar para aplicar todas las optimizaciones"
echo "  2. Verificar VRR/HDR en Settings → Displays (si GNOME)"
echo "  3. Ejecutar Steam para completar instalación"
echo "  4. Usar ProtonUp-Qt para actualizar Proton-Cachyos:"
echo "     - Abrir ProtonUp-Qt"
echo "     - Seleccionar 'Steam'"
echo "     - Install: Proton-Cachyos (Latest)"
echo ""

exit 0

