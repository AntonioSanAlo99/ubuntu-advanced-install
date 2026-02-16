#!/bin/bash
# Módulo 02: Instalar sistema base con debootstrap

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando Ubuntu $UBUNTU_VERSION con debootstrap..."

# Montar partición
mkdir -p "$TARGET"
mount "$ROOT_PART" "$TARGET"

# Ejecutar debootstrap
echo "Descargando e instalando sistema base..."
debootstrap --arch=amd64 "$UBUNTU_VERSION" "$TARGET"

# Generar fstab
echo "Generando fstab..."
genfstab -U "$TARGET" > "$TARGET/etc/fstab"

echo "✓ Sistema base instalado en $TARGET"
