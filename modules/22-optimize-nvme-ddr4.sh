#!/bin/bash
# Módulo 22: Optimizar para NVMe + DDR4

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

if [ "$DISK_TYPE" != "nvme" ]; then
    echo "⚠ Este módulo es para discos NVMe"
    echo "Tipo detectado: $DISK_TYPE"
    read -p "¿Aplicar optimizaciones de todos modos? (s/n): " cont
    [[ ! $cont =~ ^[SsYy]$ ]] && exit 0
fi

echo "Aplicando optimizaciones NVMe + DDR4..."

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES

# Sysctl para NVMe + DDR4
cat > /etc/sysctl.d/99-nvme-ddr4.conf << 'SYSCTL_EOF'
# Optimizaciones NVMe + DDR4

# Memoria agresiva (DDR4 es rápida)
vm.swappiness = 10
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 134217728

# Writeback más frecuente (NVMe aguanta)
vm.dirty_expire_centisecs = 1500
vm.dirty_writeback_centisecs = 500

# Shared memory (DDR4)
kernel.shmmax = 17179869184
kernel.shmall = 4194304
SYSCTL_EOF

echo "✓ Optimizaciones NVMe + DDR4 aplicadas"
CHROOTEOF

echo "✓ Sistema optimizado para NVMe + DDR4"
