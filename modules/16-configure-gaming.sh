#!/bin/bash
# Módulo 16: Configurar gaming (drivers + udev rules completas)

source "$(dirname "$0")/../config.env"

echo "═══════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN GAMING"
echo "═══════════════════════════════════════════════════════════"
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"

# ============================================================================
# DRIVERS GAMING
# ============================================================================

echo "Instalando drivers gaming..."

# Habilitar i386 para Steam/Wine
dpkg --add-architecture i386
apt update

# Mesa (OpenGL/Vulkan)
apt install -y \$APT_FLAGS \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386

# Gamemode
apt install -y \$APT_FLAGS gamemode

# GPU switching para híbridas (iGPU + dGPU)
apt install -y \$APT_FLAGS switcheroo-control

# ProtonUp-Qt para gestión de Proton-GE
# Instalamos desde pip (método más estable que AppImage)
apt install -y \$APT_FLAGS python3-pip python3-pyqt5 || true
pip3 install --break-system-packages protonup-qt 2>/dev/null || pip3 install protonup-qt

# Crear estructura compartida para Proton
mkdir -p /etc/skel/.local/share/Steam/compatibilitytools.d
mkdir -p /etc/skel/.config/heroic/tools/proton
mkdir -p /etc/skel/.local/share/faugus-launcher

# Script para configurar Proton compartido en primer login
cat > /etc/profile.d/99-setup-proton-shared.sh << 'PROTONEOF'
#!/bin/bash
# Configurar Proton compartido entre launchers (ejecuta una vez)
if [ ! -f "\$HOME/.config/.proton-shared-setup-done" ]; then
    STEAM_COMPAT="\$HOME/.local/share/Steam/compatibilitytools.d"
    HEROIC_PROTON="\$HOME/.config/heroic/tools/proton"
    FAUGUS_DIR="\$HOME/.local/share/faugus-launcher"
    
    # Crear directorios si no existen
    mkdir -p "\$STEAM_COMPAT"
    mkdir -p "\$HEROIC_PROTON"
    mkdir -p "\$FAUGUS_DIR"
    
    # Heroic usa symlink a Steam para compartir Proton
    if [ ! -L "\$HEROIC_PROTON/Steam" ]; then
        ln -sf "\$STEAM_COMPAT" "\$HEROIC_PROTON/Steam" 2>/dev/null
    fi
    
    # Faugus Launcher también apunta a Steam
    if [ ! -L "\$FAUGUS_DIR/compatibilitytools.d" ]; then
        ln -sf "\$STEAM_COMPAT" "\$FAUGUS_DIR/compatibilitytools.d" 2>/dev/null
    fi
    
    touch "\$HOME/.config/.proton-shared-setup-done"
fi
PROTONEOF
chmod +x /etc/profile.d/99-setup-proton-shared.sh

# Información de uso
cat > /etc/skel/.local/share/proton-usage.txt << 'INFOEOF'
GESTIÓN DE PROTON COMPARTIDO
=============================

Este sistema comparte las versiones de Proton entre Steam, Heroic y Faugus Launcher
para evitar duplicación (~1.5GB por versión).

UBICACIÓN PRINCIPAL:
  ~/.local/share/Steam/compatibilitytools.d/

INSTALACIÓN DE PROTON-GE:
  1. Usando ProtonUp-Qt (GUI):
     $ protonup-qt
     
  2. Manual:
     $ cd ~/.local/share/Steam/compatibilitytools.d/
     $ wget <URL-de-Proton-GE.tar.gz>
     $ tar xzf Proton-GE-*.tar.gz
     $ rm Proton-GE-*.tar.gz

PROTON CACHYOS (optimizado x86-64-v3):
  $ cd ~/.local/share/Steam/compatibilitytools.d/
  $ wget https://github.com/CachyOS/proton-cachyos/releases/latest/download/proton-cachyos.tar.xz
  $ tar xJf proton-cachyos.tar.xz
  $ rm proton-cachyos.tar.xz

Los tres launchers detectarán automáticamente cualquier Proton instalado en esa carpeta.
INFOEOF

echo "✓ Drivers gaming + ProtonUp-Qt + switcheroo-control instalados"
echo "✓ Estructura de Proton compartido configurada"

# ============================================================================
# UDEV RULES - I/O SCHEDULERS (Clear Linux style)
# ============================================================================

echo "Configurando I/O schedulers via udev..."

cat > /etc/udev/rules.d/60-ioschedulers.rules << 'UDEV_EOF'
# ============================================================================
# I/O SCHEDULERS - CLEAR LINUX STYLE
# Máximo rendimiento según tipo de disco
# ============================================================================

# NVMe - none (sin overhead, NVMe tiene scheduler propio)
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="1024"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="512"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/max_sectors_kb}="1024"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/add_random}="0"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rq_affinity}="2"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nomerges}="2"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/iostats}="0"

# SSD SATA - mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="512"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/add_random}="0"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/rq_affinity}="2"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/iostats}="0"

# HDD - bfq (Budget Fair Queueing)
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/nr_requests}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="1024"
UDEV_EOF

echo "✓ I/O schedulers configurados"

# ============================================================================
# UDEV RULES - PERIFÉRICOS GAMING
# Permisos correctos y sin autosuspend para 17+ marcas
# ============================================================================

echo "Configurando periféricos gaming via udev..."

cat > /etc/udev/rules.d/70-gaming-peripherals.rules << 'UDEV_EOF'
# ============================================================================
# PERIFÉRICOS GAMING - UDEV RULES
# Permisos de usuario + autosuspend desactivado
# ============================================================================

# --- LOGITECH (046d) ---
# Ratones, teclados, mandos, volantes
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTR{power/autosuspend_delay_ms}="-1"
# Logitech HID++ protocolo
KERNEL=="hidraw*", ATTRS{idVendor}=="046d", MODE="0664", GROUP="input"

# --- RAZER (1532) ---
# Periféricos Razer (Blackwidow, DeathAdder, etc)
SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1532", MODE="0664", GROUP="input"

# --- CORSAIR (1b1c) ---
# iCUE devices (K70, K95, Scimitar, etc)
SUBSYSTEM=="usb", ATTRS{idVendor}=="1b1c", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1b1c", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1b1c", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1b1c", MODE="0664", GROUP="input"

# --- STEELSERIES (1038) ---
# Arctis, Apex, Rival, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1038", MODE="0664", GROUP="input"

# --- HYPERX / KINGSTON (0951) ---
# Alloy, Pulsefire, Cloud, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="0951", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0951", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0951", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="0951", MODE="0664", GROUP="input"

# --- ROCCAT (1e7d) ---
# Kone, Kova, Vulcan, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="1e7d", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1e7d", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1e7d", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1e7d", MODE="0664", GROUP="input"

# --- ASUS ROG / TUF (0b05) ---
# Claymore, Strix, Chakram, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="0b05", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="0b05", MODE="0664", GROUP="input"

# --- MSI (1462) ---
# Clutch, Vigor, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="1462", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1462", ATTR{power/autosuspend}="-1"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1462", ATTR{power/autosuspend_delay_ms}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1462", MODE="0664", GROUP="input"

# --- ZOWIE / BENQ (1d57) ---
# EC, S, ZA series
SUBSYSTEM=="usb", ATTRS{idVendor}=="1d57", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1d57", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="1d57", MODE="0664", GROUP="input"

# --- GLORIOUS (258a) ---
# Model O, D, etc
SUBSYSTEM=="usb", ATTRS{idVendor}=="258a", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="258a", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="258a", MODE="0664", GROUP="input"

# --- XBOX CONTROLLERS (045e) ---
# Xbox 360, One, Series X/S
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="045e", MODE="0664", GROUP="input"

# --- PLAYSTATION CONTROLLERS (054c) ---
# DualShock 3/4, DualSense PS5
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="054c", MODE="0664", GROUP="input"
# DualShock 4 (Bluetooth)
KERNEL=="hidraw*", KERNELS=="*054C:09CC*", MODE="0664", GROUP="input"
# DualSense (Bluetooth)
KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0664", GROUP="input"

# --- 8BITDO (2dc8) ---
# Retro controllers
SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2dc8", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="2dc8", MODE="0664", GROUP="input"

# --- STEAM CONTROLLER / VALVE (28de) ---
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0664", GROUP="input"

# --- THRUSTMASTER (044f) ---
# Volantes y joysticks
SUBSYSTEM=="usb", ATTRS{idVendor}=="044f", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="044f", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="044f", MODE="0664", GROUP="input"

# --- FANATEC (eb03) ---
# Volantes y pedales Fanatec
SUBSYSTEM=="usb", ATTRS{idVendor}=="eb03", MODE="0664", GROUP="input"
SUBSYSTEM=="usb", ATTRS{idVendor}=="eb03", ATTR{power/autosuspend}="-1"
KERNEL=="hidraw*", ATTRS{idVendor}=="eb03", MODE="0664", GROUP="input"

# --- JOYSTICKS/GAMEPADS GENÉRICOS ---
# Permisos para dispositivos de juego
SUBSYSTEM=="input", GROUP="input", MODE="0664"
KERNEL=="js[0-9]*", MODE="0664", GROUP="input"
KERNEL=="event[0-9]*", ATTRS{name}=="*Controller*", MODE="0664", GROUP="input"
KERNEL=="event[0-9]*", ATTRS{name}=="*Gamepad*", MODE="0664", GROUP="input"
KERNEL=="event[0-9]*", ATTRS{name}=="*Joystick*", MODE="0664", GROUP="input"
UDEV_EOF

echo "✓ Reglas udev de periféricos gaming configuradas"

# Recargar reglas udev
udevadm control --reload-rules 2>/dev/null || true

# ============================================================================
# AÑADIR USUARIO AL GRUPO input
# ============================================================================

# Añadir todos los usuarios normales al grupo input
for user in \$(awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}' /etc/passwd); do
    usermod -aG input "\$user" 2>/dev/null || true
    echo "✓ Usuario \$user añadido al grupo input"
done

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "✓✓✓ Configuración gaming completada ✓✓✓"
echo ""
echo "Instalado:"
echo "  • Mesa Vulkan drivers (32 y 64 bit)"
echo "  • Gamemode (optimizador de rendimiento)"
echo ""
echo "Reglas udev configuradas:"
echo "  • I/O schedulers: NVMe/SSD/HDD optimizados"
echo "  • Periféricos soportados:"
echo "    - Logitech (046d)"
echo "    - Razer (1532)"
echo "    - Corsair (1b1c)"
echo "    - SteelSeries (1038)"
echo "    - HyperX (0951)"
echo "    - Roccat (1e7d)"
echo "    - ASUS ROG (0b05)"
echo "    - MSI (1462)"
echo "    - Zowie (1d57)"
echo "    - Glorious (258a)"
echo "    - Xbox (045e)"
echo "    - PlayStation (054c)"
echo "    - 8BitDo (2dc8)"
echo "    - Steam Controller (28de)"
echo "    - Thrustmaster (044f)"
echo "    - Fanatec (eb03)"
echo "    - Joysticks genéricos"
echo ""
echo "Para Steam: sudo apt install steam-installer"
echo "Para Wine: sudo apt install wine64 wine32"

CHROOTEOF

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  GAMING CONFIGURADO"
echo "═══════════════════════════════════════════════════════════"
