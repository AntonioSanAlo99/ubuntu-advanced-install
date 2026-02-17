#!/bin/bash
# Módulo 15: Instalar herramientas de desarrollo

source "$(dirname "$0")/../config.env"

echo "Instalando herramientas de desarrollo..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="--no-install-recommends"

# Herramientas base
apt install -y $APT_FLAGS \
    git \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    pkg-config

# Python
apt install -y $APT_FLAGS \
    python3 \
    python3-pip \
    python3-venv

# Node.js (opcional)
# apt install -y nodejs npm

echo "✓ Herramientas de desarrollo instaladas"
CHROOTEOF

echo "✓ Git, build-essential, Python instalados"
