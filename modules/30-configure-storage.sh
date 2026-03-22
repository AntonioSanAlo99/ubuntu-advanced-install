#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 30: tmpfiles.d + ajustes de almacenamiento
# ══════════════════════════════════════════════════════════════════════════════
#
#   1. TMPFILES.D: limpieza automática de cachés y temporales
#   2. AJUSTES SEGUROS: fstrim, scheduler I/O, readahead (udev rules)

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

# ============================================================================
# PARTE 1: TMPFILES.D + JOURNAL LIMITS (condicional)
# ============================================================================

if [ "${PERF_TMPFILES_CLEANUP:-true}" = "true" ]; then
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
    echo "⊘  tmpfiles.d limpieza desactivada"
fi

# ============================================================================
# PARTE 2: AJUSTES DE ALMACENAMIENTO (siempre)
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
if [ "${PERF_TMPFILES_CLEANUP:-true}" = "true" ]; then
    echo "  tmpfiles.d: /tmp 7d, /var/tmp 30d, apt 14d, thumbnails 30d"
    echo "  journal: max 500M, retención 1 mes"
fi
echo "  I/O: nvme→none, ssd→mq-deadline, hdd→bfq + readahead + fstrim"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
