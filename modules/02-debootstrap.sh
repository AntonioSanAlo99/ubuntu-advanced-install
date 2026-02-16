#!/bin/bash
# Módulo 02: Instalar sistema base con debootstrap

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando Ubuntu $UBUNTU_VERSION con debootstrap..."
echo "Firmware: $FIRMWARE"

# Montar partición root
mkdir -p "$TARGET"
mount "$ROOT_PART" "$TARGET"
echo "✓ Root montado en $TARGET"

# Si es UEFI, montar también EFI
if [ "$FIRMWARE" = "UEFI" ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "$EFI_PART" "$TARGET/boot/efi"
    echo "✓ EFI montado en $TARGET/boot/efi"
fi

# Ejecutar debootstrap
echo "Descargando e instalando sistema base..."
echo "Esto puede tardar varios minutos..."
debootstrap --arch=amd64 "$UBUNTU_VERSION" "$TARGET"

# Generar fstab
echo "Generando fstab..."
genfstab -U "$TARGET" > "$TARGET/etc/fstab"

echo ""
echo "✓✓✓ Sistema base instalado en $TARGET ✓✓✓"
echo ""
echo "Contenido de fstab generado:"
cat "$TARGET/etc/fstab"
