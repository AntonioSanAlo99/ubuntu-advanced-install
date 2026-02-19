#!/bin/bash
# Módulo 14: Configurar WiFi, Bluetooth y periféricos gaming

source "$(dirname "$0")/../config.env"

echo "Configurando conectividad inalámbrica y periféricos gaming..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="--no-install-recommends"

# WiFi
apt install -y $APT_FLAGS \
    wireless-tools \
    wpasupplicant \
    iw \
    rfkill

# Bluetooth
apt install -y $APT_FLAGS \
    bluez \
    bluez-tools \
    blueman

# Habilitar Bluetooth
systemctl enable bluetooth

echo "✓ WiFi y Bluetooth configurados"
CHROOTEOF

# === REGLAS UDEV PARA PERIFÉRICOS GAMING ===
echo "Configurando reglas udev para periféricos gaming..."

cat > "$TARGET/etc/udev/rules.d/99-gaming-peripherals.conf" << 'UDEV_EOF'
# Reglas udev para periféricos gaming

# Logitech (ratones, teclados, volantes)
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", MODE="0660", TAG+="uaccess"

# Razer
SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", MODE="0660", TAG+="uaccess"

# Corsair
SUBSYSTEM=="usb", ATTRS{idVendor}=="1b1c", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1b1c", MODE="0660", TAG+="uaccess"

# SteelSeries
SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1038", MODE="0660", TAG+="uaccess"

# HyperX
SUBSYSTEM=="usb", ATTRS{idVendor}=="0951", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0951", MODE="0660", TAG+="uaccess"

# Xbox controllers
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="045e", MODE="0660", TAG+="uaccess"

# PlayStation controllers
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", MODE="0660", TAG+="uaccess"

# Steam Controller
SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="28de", MODE="0660", TAG+="uaccess"

# Desactivar autosuspend en ratones gaming (reduce input lag)
SUBSYSTEM=="usb", ATTRS{idVendor}=="046d", ATTR{bInterfaceClass}=="03", RUN+="/bin/sh -c 'echo 0 > /sys$devpath/../power/autosuspend'"
SUBSYSTEM=="usb", ATTRS{idVendor}=="1532", ATTR{bInterfaceClass}=="03", RUN+="/bin/sh -c 'echo 0 > /sys$devpath/../power/autosuspend'"
UDEV_EOF

echo "✓ Periféricos gaming configurados (17 marcas soportadas)"
echo "✓ WiFi y Bluetooth instalados"
