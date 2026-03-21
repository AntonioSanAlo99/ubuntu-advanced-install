#!/bin/bash
# MÓDULO 92: Backup de configuración

set -e

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

BACKUP_DIR="/tmp/ubuntu-install-backup-$(date +%Y%m%d-%H%M%S)"

echo "Creando backup de configuración..."
mkdir -p "$BACKUP_DIR"

# Copiar archivos de configuración
cp "$(dirname "$0")/../config.env" "$BACKUP_DIR/" 2>/dev/null
cp "$(dirname "$0")/../partition.info" "$BACKUP_DIR/" 2>/dev/null

# Backup de archivos importantes del sistema instalado
if [ -d "$TARGET" ]; then
    mkdir -p "$BACKUP_DIR/system"
    cp "$TARGET/etc/fstab" "$BACKUP_DIR/system/" 2>/dev/null
    cp "$TARGET/etc/hostname" "$BACKUP_DIR/system/" 2>/dev/null
    cp -r "$TARGET/etc/NetworkManager/conf.d/" "$BACKUP_DIR/system/" 2>/dev/null
    cp -r "$TARGET/etc/sysctl.d/" "$BACKUP_DIR/system/" 2>/dev/null
fi

# Crear tarball
cd /tmp
tar czf "ubuntu-backup-$(date +%Y%m%d-%H%M%S).tar.gz" "$(basename "$BACKUP_DIR")"

echo "✓  Backup creado en: /tmp/ubuntu-backup-*.tar.gz"
ls -lh /tmp/ubuntu-backup-*.tar.gz | tail -1

exit 0
