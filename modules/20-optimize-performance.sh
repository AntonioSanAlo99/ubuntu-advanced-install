#!/bin/bash
# Módulo 20: Optimizar rendimiento general

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Aplicando optimizaciones de rendimiento..."
echo "Tipo de disco: $DISK_TYPE"

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# === OPTIMIZACIONES SYSCTL ===
cat > /etc/sysctl.d/99-performance.conf << 'SYSCTL_EOF'
# Optimizaciones de rendimiento

# === MEMORIA Y SWAP ===
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10

# === RED ===
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000

# === FILESYSTEM ===
vm.dirty_expire_centisecs = 1500
vm.dirty_writeback_centisecs = 500

# === SCHEDULER ===
kernel.sched_autogroup_enabled = 1
kernel.sched_migration_cost_ns = 5000000
SYSCTL_EOF

echo "✓ Optimizaciones sysctl aplicadas"
CHROOTEOF

# === I/O SCHEDULER SEGÚN TIPO DE DISCO ===
case "$DISK_TYPE" in
    nvme)
        echo "Configurando I/O scheduler para NVMe..."
        cat > "$TARGET/etc/udev/rules.d/60-ioschedulers.conf" << 'EOF'
# NVMe - scheduler none (sin overhead)
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nr_requests}="1024"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/add_random}="0"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/nomerges}="2"
EOF
        ;;
    ssd)
        echo "Configurando I/O scheduler para SSD..."
        cat > "$TARGET/etc/udev/rules.d/60-ioschedulers.conf" << 'EOF'
# SSD - scheduler mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="128"
EOF
        ;;
    hdd)
        echo "Configurando I/O scheduler para HDD..."
        cat > "$TARGET/etc/udev/rules.d/60-ioschedulers.conf" << 'EOF'
# HDD - scheduler bfq
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/nr_requests}="128"
EOF
        ;;
esac

# === TRIM PARA SSD/NVMe ===
if [ "$DISK_TYPE" = "ssd" ] || [ "$DISK_TYPE" = "nvme" ]; then
    echo "Habilitando TRIM semanal..."
    arch-chroot "$TARGET" systemctl enable fstrim.timer
fi

echo "✓ Optimizaciones de rendimiento aplicadas"
