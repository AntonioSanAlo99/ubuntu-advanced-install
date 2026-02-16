#!/bin/bash
# Módulo 04: Instalar kernel y bootloader

source "$(dirname "$0")/../config.env"

echo "Instalando kernel y GRUB..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

apt install -y $APT_FLAGS \
    linux-image-generic \
    linux-headers-generic \
    grub-pc \
    bash-completion \
    zstd \
    xz-utils \
    wget \
    nano

# Instalar GRUB
grub-install $TARGET_DISK
grub-mkconfig -o /boot/grub/grub.cfg
CHROOTEOF

echo "✓ Kernel y GRUB instalados"
