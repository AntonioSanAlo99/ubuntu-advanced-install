#!/bin/bash
# Módulo 05: Configurar NetworkManager

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "Configurando NetworkManager..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive


# Instalar NetworkManager
apt install -y $APT_FLAGS network-manager

# CRÍTICO: Crear configuración para que NM gestione todas las interfaces
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << 'EOF'
[keyfile]
unmanaged-devices=none
EOF

# Configurar DNS con systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Habilitar servicios
systemctl enable NetworkManager
systemctl enable systemd-resolved

CHROOTEOF

echo "✓  NetworkManager configurado (fix unmanaged aplicado)"

exit 0
