#!/bin/bash
# Módulo 04: Instalar kernel y bootloader (con soporte dual-boot)

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando kernel y GRUB..."
echo "Firmware: $FIRMWARE"
echo "Dual-boot: ${DUAL_BOOT_MODE:-false}"

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

if [ "$FIRMWARE" = "UEFI" ]; then
    GRUB_PKG="grub-efi-amd64"
    GRUB_TGT="x86_64-efi"
    GRUB_DIR="/boot/efi"
else
    GRUB_PKG="grub-pc"
    GRUB_TGT="i386-pc"
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

apt install -y $APT_FLAGS \
    linux-image-generic \
    linux-headers-generic \
    $GRUB_PKG \
    efibootmgr \
    dracut \
    bash-completion \
    zstd \
    xz-utils \
    wget \
    nano

echo "✓ Paquetes base instalados (incluyendo dracut)"

# Dual-boot: instalar os-prober
if [ "$DUAL_BOOT_MODE" = "true" ]; then
    echo "Instalando os-prober para dual-boot..."
    apt install -y os-prober ntfs-3g
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub 2>/dev/null || echo "GRUB_TIMEOUT=10" >> /etc/default/grub
fi

# Instalar GRUB
if [ "$FIRMWARE" = "UEFI" ]; then
    grub-install --target=$GRUB_TGT --efi-directory=$GRUB_DIR --bootloader-id=ubuntu --recheck
else
    grub-install --target=$GRUB_TGT $TARGET_DISK
fi

# Detectar otros OS y generar config
[ "$DUAL_BOOT_MODE" = "true" ] && os-prober || true
update-grub

echo "✓ GRUB instalado"

if [ "$DUAL_BOOT_MODE" = "true" ]; then
    echo ""
    echo "Sistemas detectados:"
    grep menuentry /boot/grub/grub.cfg | grep -v "menuentry_id_option" | sed 's/.*menuentry /  • /' | sed "s/'.*$//" || echo "  • Solo Ubuntu (ejecuta update-grub después si no detectó Windows)"
fi
CHROOTEOF

echo ""
echo "✓✓✓ Bootloader instalado ✓✓✓"
[ "$DUAL_BOOT_MODE" = "true" ] && echo "Dual-boot configurado con timeout de 10s"
