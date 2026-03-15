#!/bin/bash
# MÓDULO 30: Swapfile + optimización de almacenamiento
#
# Dos partes:
#   1. SWAPFILE (siempre): crea /swapfile según SWAP_GIB de partition.info
#   2. OPTIMIZACIÓN (solo si INSTALL_STORAGE_OPT=true): scheduler I/O,
#      readahead, fstrim, sysctl, opciones de montaje en fstab.
#      Usa STORAGE_DISK_TYPE (nvme/ssd/hdd/emmc) — preguntado en install.sh.
#
# No tiene inputs interactivos — todo viene de variables de install.sh.

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

echo "════════════════════════════════════════════════════════════════"
echo "  ALMACENAMIENTO Y SWAPFILE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# PARTE 1: SWAPFILE (siempre se ejecuta)
# ============================================================================

arch-chroot "$TARGET" /bin/bash << SWAPEOF
SWAP_GIB=${SWAP_GIB:-0}

if [ "\$SWAP_GIB" -gt 0 ] 2>/dev/null; then
    SWAPFILE="/swapfile"

    if [ -f "\$SWAPFILE" ]; then
        echo "  swapfile ya existe (\$SWAPFILE) — omitiendo creación"
    else
        echo "Creando swapfile de \${SWAP_GIB} GiB..."

        # IMPORTANTE: NO usar fallocate — en ext4 crea extents preallocados que
        # el kernel puede rechazar con "swapon: Invalid argument" (man swapon,
        # sección "Files with holes"). dd /dev/zero es el método correcto.
        dd if=/dev/zero of="\$SWAPFILE" bs=1M count=\$(( SWAP_GIB * 1024 )) status=progress
        echo "  ✓  dd: \$SWAPFILE (\${SWAP_GIB} GiB)"

        chmod 600 "\$SWAPFILE"
        mkswap "\$SWAPFILE"
        echo "✓  swapfile creado y formateado"
    fi

    # Añadir al fstab si no está ya
    if ! grep -q "^/swapfile" /etc/fstab 2>/dev/null; then
        echo "/swapfile    none    swap    sw    0    0" >> /etc/fstab
        echo "✓  swapfile añadido a /etc/fstab"
    fi
else
    echo "  SWAP_GIB=0 — sin swapfile (elegido en la configuración del disco)"
fi
SWAPEOF

echo ""
echo "  swapfile: ${SWAP_GIB:-0} GiB ($([ "${SWAP_GIB:-0}" = "0" ] && echo "desactivado" || echo "/swapfile"))"

# ============================================================================
# PARTE 2: OPTIMIZACIÓN DE ALMACENAMIENTO (opcional)
# ============================================================================

if [ "${INSTALL_STORAGE_OPT:-false}" != "true" ]; then
    echo ""
    echo "  Optimización de almacenamiento: omitida"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "✓  SWAPFILE CONFIGURADO"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    exit 0
fi

DISK_TYPE="${STORAGE_DISK_TYPE:-ssd}"
echo ""
echo "  Optimizando para: $DISK_TYPE"
echo ""

arch-chroot "$TARGET" /bin/bash << STOREOF
export DISK_TYPE="$DISK_TYPE"

echo "Aplicando optimizaciones para: \$DISK_TYPE"
echo ""

# ── Scheduler de I/O — udev rule dinámica ────────────────────────────────────
mkdir -p /etc/udev/rules.d

cat > /etc/udev/rules.d/60-io-scheduler.rules << 'UDEVEOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEVEOF
echo "✓  Scheduler de I/O: regla udev instalada"

# ── Readahead — udev rule ────────────────────────────────────────────────────
cat > /etc/udev/rules.d/61-readahead.rules << 'RAEOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/read_ahead_kb}="512"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="4096"
RAEOF
echo "✓  Readahead: regla udev instalada"

# ── fstrim.timer ─────────────────────────────────────────────────────────────
systemctl enable fstrim.timer 2>/dev/null || true
echo "✓  fstrim.timer habilitado (TRIM semanal)"

# ── sysctl — parámetros de kernel ────────────────────────────────────────────
cat > /etc/sysctl.d/60-storage.conf << 'SYSCTLEOF'
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
vm.vfs_cache_pressure = 50
SYSCTLEOF
sysctl -p /etc/sysctl.d/60-storage.conf 2>/dev/null || true
echo "✓  sysctl de almacenamiento aplicado"

# ── fstab — opciones de montaje adicionales ──────────────────────────────────
if [ -f /etc/fstab ]; then
    ROOT_FS=\$(awk '\$2=="/" {print \$3}' /etc/fstab 2>/dev/null | head -1)

    if [ "\$ROOT_FS" = "ext4" ]; then
        case "\$DISK_TYPE" in
            nvme|ssd|emmc)
                if ! grep -q "commit=" /etc/fstab; then
                    sed -i '/^UUID=.*\s\/\s\+ext4\s/ s|errors=remount-ro|errors=remount-ro,commit=60,discard=async|' /etc/fstab
                fi
                echo "✓  fstab: commit=60 + discard=async (SSD/NVMe/eMMC)"
                ;;
            hdd)
                if ! grep -q "commit=" /etc/fstab; then
                    sed -i '/^UUID=.*\s\/\s\+ext4\s/ s|errors=remount-ro|errors=remount-ro,commit=60|' /etc/fstab
                fi
                echo "✓  fstab: commit=60 (HDD)"
                ;;
        esac
    fi
fi

udevadm control --reload-rules 2>/dev/null || true

STOREOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ALMACENAMIENTO OPTIMIZADO ($DISK_TYPE)"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
