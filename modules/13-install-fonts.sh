#!/bin/bash
# Módulo 13: Instalar fuentes

source "$(dirname "$0")/../config.env"

echo "Instalando fuentes..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="--no-install-recommends"

# Fuentes del sistema
apt install -y $APT_FLAGS \
    fonts-liberation \
    fonts-dejavu \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-font-awesome \
    fonts-hack \
    fonts-inconsolata \
    console-setup

# MS Core Fonts (requiere aceptar EULA)
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y $APT_FLAGS ttf-mscorefonts-installer

echo "✓ Fuentes instaladas"
CHROOTEOF

echo "✓ Fuentes del sistema instaladas"
