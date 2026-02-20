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

echo "✓ WiFi y Bluetooth instalados"
