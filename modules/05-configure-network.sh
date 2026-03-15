#!/bin/bash
# MÓDULO 05: Configurar NetworkManager

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


echo "Configurando NetworkManager..."

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

apt install -y network-manager

# CRÍTICO: Crear configuración para que NM gestione todas las interfaces
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf << 'EOF'
[keyfile]
unmanaged-devices=none
EOF

# Configurar DNS con systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl enable NetworkManager
systemctl enable systemd-resolved

CHROOTEOF

echo "✓  NetworkManager configurado (fix unmanaged aplicado)"

exit 0
