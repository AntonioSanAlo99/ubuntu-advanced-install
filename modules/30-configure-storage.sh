#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 30: Swapfile + ajustes de almacenamiento seguros
# ══════════════════════════════════════════════════════════════════════════════
#
# Dos partes:
#   1. SWAPFILE: crea /swapfile según SWAP_GIB de partition.info
#   2. AJUSTES SEGUROS (siempre): fstrim, scheduler I/O, readahead
#      — Solo reglas udev y timers de systemd
#      — NO modifica fstab (riesgo de romper arranque)
#      — NO modifica sysctl (valores por defecto del kernel son buenos)
#
# No tiene inputs interactivos — todo viene de variables de install.sh.

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi


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
# PARTE 2: AJUSTES DE ALMACENAMIENTO SEGUROS (siempre se ejecuta)
# ============================================================================
# Solo ajustes que:
#   - Mejoran la vida útil del disco (TRIM, scheduler apropiado)
#   - Mejoran la respuesta (readahead según tipo de disco)
#   - NO modifican fstab (riesgo de romper arranque)
#   - NO modifican sysctl (valores por defecto del kernel son buenos)
#   - Son reglas udev + timers de systemd (revertibles, sin riesgo)
# ============================================================================

echo ""
echo "Aplicando ajustes de almacenamiento seguros..."

arch-chroot "$TARGET" /bin/bash << STOREOF

# ── Scheduler de I/O — udev rule dinámica ────────────────────────────────────
# Asigna el scheduler óptimo según tipo de dispositivo:
#   NVMe  → none (el firmware del controlador ya gestiona la cola)
#   SSD   → mq-deadline (baja latencia, respeta TRIM)
#   eMMC  → mq-deadline (similar a SSD)
#   HDD   → bfq (priorización justa, mejor para rotacionales)
# El kernel 6.x ya selecciona bien en la mayoría de casos, pero esta regla
# asegura consistencia en hardware variado.
mkdir -p /etc/udev/rules.d

cat > /etc/udev/rules.d/60-io-scheduler.rules << 'UDEVEOF'
# Scheduler de I/O — ubuntu-advanced-install
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEVEOF
echo "  ✓ Scheduler I/O: regla udev instalada"

# ── Readahead — udev rule ────────────────────────────────────────────────────
# Valores conservadores que mejoran lectura secuencial sin desperdiciar RAM:
#   NVMe/SSD → 256 KB (lecturas rápidas, no necesita prefetch grande)
#   eMMC     → 512 KB (latencia mayor que NVMe, algo más de buffer)
#   HDD      → 4096 KB (lectura secuencial lenta, prefetch grande ayuda)
cat > /etc/udev/rules.d/61-readahead.rules << 'RAEOF'
# Readahead — ubuntu-advanced-install
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/read_ahead_kb}="512"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="4096"
RAEOF
echo "  ✓ Readahead: regla udev instalada"

# ── fstrim.timer ─────────────────────────────────────────────────────────────
# TRIM semanal para SSD/NVMe. Mejora vida útil y rendimiento a largo plazo.
# Ubuntu lo incluye pero no siempre lo habilita por defecto.
# En HDD no tiene efecto (el kernel lo ignora).
systemctl enable fstrim.timer 2>/dev/null || true
echo "  ✓ fstrim.timer habilitado (TRIM semanal)"

udevadm control --reload-rules 2>/dev/null || true

STOREOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ALMACENAMIENTO CONFIGURADO"
echo "════════════════════════════════════════════════════════════════"
echo "  swapfile: ${SWAP_GIB:-0} GiB"
echo "  Scheduler I/O: udev rule (nvme→none, ssd→mq-deadline, hdd→bfq)"
echo "  Readahead: udev rule (nvme/ssd→256K, emmc→512K, hdd→4096K)"
echo "  fstrim: semanal (systemd timer)"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
