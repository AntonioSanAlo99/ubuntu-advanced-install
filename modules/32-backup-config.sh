#!/bin/bash
# Módulo 32: Backup de configuración

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar funciones de debug
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/debug-functions.sh" 2>/dev/null || {
    debug() { debug " $*"; }
    step() { step " $*"; }
    error() { echo "✗ $*"; }
    warn() { warn " $*"; }
}

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

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

step " Backup creado en: /tmp/ubuntu-backup-*.tar.gz"
ls -lh /tmp/ubuntu-backup-*.tar.gz | tail -1

exit 0
