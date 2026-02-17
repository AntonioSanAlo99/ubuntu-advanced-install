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
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES
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

echo "✓ Drivers gaming instalados"

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
