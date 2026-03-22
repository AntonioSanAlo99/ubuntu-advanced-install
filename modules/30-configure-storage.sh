#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 30: zram + tmpfiles.d + ajustes de almacenamiento
# ══════════════════════════════════════════════════════════════════════════════
#
#   1. ZRAM: swap comprimido en RAM (reemplaza swapfile)
#   2. TMPFILES.D: limpieza automática de cachés y temporales
#   3. AJUSTES SEGUROS: fstrim, scheduler I/O, readahead (udev rules)

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

# ============================================================================
# PARTE 1: ZRAM (swap comprimido en RAM)
# ============================================================================
# Más rápido que swapfile (sin I/O disco), mejor para SSD (menos escrituras).
# zstd compresión ~3:1. vm.swappiness=180 optimizado para zram (kernel 5.8+).
# Ref: ArchWiki Zram, Fedora SwapOnZRAM, CachyOS-Settings

echo "Configurando swap..."

if [ "${PERF_ZRAM:-true}" = "true" ]; then
    echo "  → zram (swap comprimido en RAM)"
    arch-chroot "$TARGET" /bin/bash << ZRAMEOF
SWAPPINESS="${PERF_ZRAM_SWAPPINESS:-180}"

apt-get install -y systemd-zram-generator 2>/dev/null \
    || apt-get install -y zram-tools 2>/dev/null || true

if command -v zram-generator >/dev/null 2>&1 || [ -d /usr/lib/systemd/zram-generator.conf.d ]; then
    cat > /etc/systemd/zram-generator.conf << 'ZRAMCONF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAMCONF
    echo "  ✓ zram: systemd-zram-generator (zstd, 50% RAM, max 8G)"
elif [ -f /etc/default/zramswap ] || dpkg -l 2>/dev/null | grep -q zram-tools; then
    cat > /etc/default/zramswap << 'ZRAMTOOLS'
ALGO=zstd
PERCENT=50
PRIORITY=100
ZRAMTOOLS
    systemctl enable zramswap 2>/dev/null || true
    echo "  ✓ zram: zram-tools (zstd, 50% RAM)"
else
    echo "zram" > /etc/modules-load.d/zram.conf
    cat > /etc/udev/rules.d/99-zram.rules << 'ZRAMUDEV'
KERNEL=="zram0", SUBSYSTEM=="block", ACTION=="add", ATTR{disksize}="4G", ATTR{comp_algorithm}="zstd", RUN+="/sbin/mkswap /dev/zram0", RUN+="/sbin/swapon -p 100 /dev/zram0"
ZRAMUDEV
    echo "  ✓ zram: manual (udev, 4G, zstd)"
fi

cat > /etc/sysctl.d/90-zram-swap.conf << ZRAMSYSCTL
# zram swap — ubuntu-advanced-install
vm.swappiness = \$SWAPPINESS
vm.page-cluster = 0
vm.watermark_boost_factor = 0
ZRAMSYSCTL
echo "  ✓ sysctl: swappiness=\$SWAPPINESS, page-cluster=0"

if [ -f /swapfile ]; then
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile
    sed -i '/^\/swapfile/d' /etc/fstab
    echo "  ✓ swapfile anterior eliminado"
fi

ZRAMEOF

    echo "✓  zram configurado"
else
    # Swapfile tradicional (fallback si PERF_ZRAM=false)
    echo "  → swapfile tradicional"
    arch-chroot "$TARGET" /bin/bash << SWAPEOF
SWAP_GIB=${SWAP_GIB:-0}

if [ "\$SWAP_GIB" -gt 0 ] 2>/dev/null; then
    if [ ! -f /swapfile ]; then
        dd if=/dev/zero of=/swapfile bs=1M count=\$(( SWAP_GIB * 1024 )) status=progress
        chmod 600 /swapfile
        mkswap /swapfile
        echo "✓  swapfile creado (\${SWAP_GIB} GiB)"
    fi
    grep -q "^/swapfile" /etc/fstab 2>/dev/null || echo "/swapfile none swap sw 0 0" >> /etc/fstab

    cat > /etc/sysctl.d/90-swap.conf << 'SWAPSYSCTL'
vm.swappiness = 10
SWAPSYSCTL
else
    echo "  SWAP_GIB=0 — sin swap"
fi
SWAPEOF

    echo "✓  swapfile: ${SWAP_GIB:-0} GiB"
fi

# ============================================================================
# PARTE 2: TMPFILES.D + JOURNAL LIMITS (condicional)
# ============================================================================

if [ "${PERF_TMPFILES_CLEANUP:-true}" = "true" ]; then
    echo ""
    echo "Configurando limpieza automática..."

    arch-chroot "$TARGET" /bin/bash << TMPEOF

mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/50-cleanup.conf << 'TMPCONF'
# Limpieza automática — ubuntu-advanced-install
q /tmp 1777 root root 7d
q /var/tmp 1777 root root 30d
e /home/*/.cache/thumbnails - - - 30d
e /home/*/.cache/thumbnails/large - - - 30d
e /home/*/.cache/thumbnails/normal - - - 30d
e /var/cache/apt/archives - - - 14d
TMPCONF

systemctl enable systemd-tmpfiles-clean.timer 2>/dev/null || true

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/50-size-limit.conf << 'JOURNALEOF'
[Journal]
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=1month
JOURNALEOF

echo "✓  tmpfiles.d + journal limits"

TMPEOF

    echo "✓  Limpieza automática configurada"
else
    echo "⊘  tmpfiles.d limpieza desactivada (PERF_TMPFILES_CLEANUP=false)"
fi

# ============================================================================
# PARTE 3: AJUSTES DE ALMACENAMIENTO (siempre)
# ============================================================================

echo ""
echo "Aplicando ajustes de almacenamiento..."

arch-chroot "$TARGET" /bin/bash << STOREOF

mkdir -p /etc/udev/rules.d

cat > /etc/udev/rules.d/60-io-scheduler.rules << 'UDEVEOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEVEOF

cat > /etc/udev/rules.d/61-readahead.rules << 'RAEOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/read_ahead_kb}="512"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="4096"
RAEOF

systemctl enable fstrim.timer 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true

echo "✓  I/O scheduler + readahead + fstrim"

STOREOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ALMACENAMIENTO CONFIGURADO"
echo "════════════════════════════════════════════════════════════════"
if [ "${PERF_ZRAM:-true}" = "true" ]; then
    echo "  zram: swap en RAM (zstd, swappiness=${PERF_ZRAM_SWAPPINESS:-180})"
else
    echo "  swapfile: ${SWAP_GIB:-0} GiB (swappiness=10)"
fi
if [ "${PERF_TMPFILES_CLEANUP:-true}" = "true" ]; then
    echo "  tmpfiles.d: /tmp 7d, /var/tmp 30d, apt 14d, thumbnails 30d"
    echo "  journal: max 500M, retención 1 mes"
fi
echo "  I/O: nvme→none, ssd→mq-deadline, hdd→bfq + readahead + fstrim"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
