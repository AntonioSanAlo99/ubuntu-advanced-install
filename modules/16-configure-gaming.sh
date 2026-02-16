#!/bin/bash
# Módulo 16: Configurar para gaming (Steam, drivers, etc)

source "$(dirname "$0")/../config.env"

echo "Configurando para gaming..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="--no-install-recommends"

# Habilitar i386 para Steam
dpkg --add-architecture i386
apt update

# Drivers Mesa (OpenGL/Vulkan)
apt install -y $APT_FLAGS \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers:i386 \
    libgl1-mesa-dri \
    libgl1-mesa-dri:i386

# Steam (opcional, comentado por defecto)
# apt install -y steam-installer

# Wine (opcional)
# apt install -y wine64 wine32

# Gamemode
apt install -y $APT_FLAGS gamemode

echo "✓ Drivers gaming instalados"
CHROOTEOF

echo "✓ Drivers Vulkan/OpenGL + gamemode instalados"
echo "Para Steam: sudo apt install steam-installer"
