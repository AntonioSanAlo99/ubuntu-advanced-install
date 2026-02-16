#!/bin/bash
# Módulo 12: Instalar multimedia (códecs y thumbnailers)

source "$(dirname "$0")/../config.env"

echo "Instalando multimedia..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="--no-install-recommends"

# Códecs multimedia
apt install -y $APT_FLAGS \
    ffmpeg \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav

# Thumbnailers
apt install -y $APT_FLAGS \
    ffmpegthumbnailer \
    gnome-epub-thumbnailer \
    libgdk-pixbuf2.0-bin \
    ghostscript \
    poppler-utils

echo "✓ Multimedia instalado"
CHROOTEOF

echo "✓ Códecs y thumbnailers instalados"
