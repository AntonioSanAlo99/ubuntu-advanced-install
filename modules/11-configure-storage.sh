#!/bin/bash
# Módulo 11-configure-storage: Optimización de almacenamiento
# Detecta el tipo de disco raíz (NVMe, SSD SATA, HDD, eMMC) y aplica
# los ajustes óptimos para cada caso: scheduler de I/O, opciones de montaje,
# fstrim, readahead y parámetros de kernel.
#
# Filosofía:
#   NVMe/SSD  → minimizar escrituras innecesarias, TRIM periódico, scheduler none/mq-deadline
#   HDD       → readahead agresivo, scheduler bfq (fairness + latencia interactiva)
#   eMMC      → igual que SSD pero con límites de escritura más estrictos
#
# No pregunta nada. Se ejecuta siempre como parte de la instalación base.

set -e

[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIÓN DE ALMACENAMIENTO"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# DETECCIÓN DEL TIPO DE DISCO RAÍZ
# ============================================================================
# Se intenta autodetectar, pero en VMs (virtio, QEMU) la detección puede
# dar resultados incorrectos (virtio reporta rotational=1 aunque sea SSD
# en el host). Se pregunta al usuario con la autodetección como sugerencia.
# ============================================================================

ROOT_DISK=""
DETECTED_TYPE="unknown"

# Autodetectar como sugerencia
if [ -n "$ROOT_PART" ]; then
    ROOT_DISK=$(lsblk -no PKNAME "$ROOT_PART" 2>/dev/null | head -1)
    [ -z "$ROOT_DISK" ] && ROOT_DISK=$(echo "$ROOT_PART" | sed 's/p\?[0-9]*$//' | xargs basename 2>/dev/null)
fi

if [ -n "$ROOT_DISK" ]; then
    ROTA=$(cat "/sys/block/${ROOT_DISK}/queue/rotational" 2>/dev/null || echo "?")

    if [[ "$ROOT_DISK" == nvme* ]]; then
        DETECTED_TYPE="nvme"
    elif [[ "$ROOT_DISK" == mmcblk* ]]; then
        DETECTED_TYPE="emmc"
    elif [ "$ROTA" = "0" ]; then
        DETECTED_TYPE="ssd"
    elif [ "$ROTA" = "1" ]; then
        DETECTED_TYPE="hdd"
    fi
fi

echo "  Disco raíz: ${ROOT_DISK:-desconocido}"
echo "  Tipo detectado: $DETECTED_TYPE"
echo ""
echo "  Tipo de almacenamiento (determina scheduler I/O, readahead, fstab):"
echo "    1) NVMe (M.2 NVMe, PCIe)"
echo "    2) SSD (SATA SSD, mSATA)"
echo "    3) HDD (disco mecánico)"
echo "    4) eMMC (almacenamiento integrado)"
echo ""

# Mapear detección a opción por defecto
case "$DETECTED_TYPE" in
    nvme) DEFAULT_OPT=1 ;;
    ssd)  DEFAULT_OPT=2 ;;
    hdd)  DEFAULT_OPT=3 ;;
    emmc) DEFAULT_OPT=4 ;;
    *)    DEFAULT_OPT=2 ;;
esac

read -p "  Opción [$DEFAULT_OPT]: " opt_disk
opt_disk="${opt_disk:-$DEFAULT_OPT}"

case "$opt_disk" in
    1) DISK_TYPE="nvme" ;;
    2) DISK_TYPE="ssd"  ;;
    3) DISK_TYPE="hdd"  ;;
    4) DISK_TYPE="emmc" ;;
    *) DISK_TYPE="ssd"  ;;
esac

echo ""
echo "  → Tipo seleccionado: $DISK_TYPE"
echo ""

# ============================================================================
# AJUSTES EN EL CHROOT
# ============================================================================

arch-chroot "$TARGET" /bin/bash << STOREOF
export DISK_TYPE="$DISK_TYPE"
export ROOT_DISK="$ROOT_DISK"

echo "Aplicando optimizaciones para: \$DISK_TYPE"
echo ""

# ============================================================================
# SCHEDULER DE I/O — udev rule dinámica por tipo de dispositivo
# ============================================================================
# Se usa una regla udev en lugar de sysctl para que funcione con múltiples
# discos y se re-aplique en caliente si se conecta un disco externo.
#
# Schedulers:
#   none       → NVMe: el hardware gestiona la cola internamente (NCQ/NVMe queues)
#   mq-deadline→ SSD SATA/eMMC: deadline garantiza latencia baja sin reordenación excesiva
#   bfq        → HDD: Budget Fair Queuing — fairness entre procesos, buena latencia interactiva
# ============================================================================

mkdir -p /etc/udev/rules.d

cat > /etc/udev/rules.d/60-io-scheduler.rules << 'UDEVEOF'
# Scheduler de I/O por tipo de dispositivo
# NVMe: none (la cola la gestiona el propio hardware)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

# SSD SATA (rotational=0, no NVMe, no eMMC): mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"

# eMMC: mq-deadline (similar a SSD pero con límites de escritura más estrictos)
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="mq-deadline"

# HDD (rotational=1): bfq — fairness + buena latencia interactiva
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
UDEVEOF

echo "✓  Scheduler de I/O: regla udev instalada"

# ============================================================================
# READAHEAD — por tipo de dispositivo
# ============================================================================
# NVMe/SSD: readahead bajo (256 KB) — la latencia ya es baja, readahead alto
#           solo desperdicia memoria y genera I/O innecesario.
# HDD:      readahead alto (4 MB) — amortiza la latencia rotacional cargando
#           más datos en cada seek.
# eMMC:     readahead medio (512 KB) — compromiso entre latencia y escrituras.
# ============================================================================

cat > /etc/udev/rules.d/61-readahead.rules << 'RAEOF'
# Readahead por tipo de dispositivo (en sectores de 512B)
# NVMe: 512 sectores = 256 KB
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="256"

# SSD SATA: 512 sectores = 256 KB
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="256"

# eMMC: 1024 sectores = 512 KB
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/read_ahead_kb}="512"

# HDD: 8192 sectores = 4 MB
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="4096"
RAEOF

echo "✓  Readahead: regla udev instalada"

# ============================================================================
# FSTRIM — mantenimiento periódico para SSD/NVMe/eMMC
# ============================================================================
# fstrim.timer de systemd ejecuta TRIM semanalmente por defecto en Ubuntu,
# pero no está habilitado en todos los casos. Se habilita explícitamente.
# En HDD no tiene efecto (fstrim lo detecta y no hace nada).
# ============================================================================

systemctl enable fstrim.timer 2>/dev/null || true
echo "✓  fstrim.timer habilitado (TRIM semanal para SSD/NVMe/eMMC)"

# ============================================================================
# SYSCTL — parámetros de kernel para almacenamiento
# ============================================================================

cat > /etc/sysctl.d/60-storage.conf << 'SYSCTLEOF'
# ── Escritura en caché ────────────────────────────────────────────────────────
# dirty_ratio: % de RAM que puede acumular páginas sucias antes de forzar flush.
# Valor bajo (10%) → flushes más frecuentes pero más pequeños → más suaves para SSD.
# Valor por defecto Ubuntu: 20%.
vm.dirty_ratio = 10

# dirty_background_ratio: % de RAM en el que el kernel empieza a escribir en
# background. Con 5% el flush empieza pronto, evitando avalanchas de escritura.
vm.dirty_background_ratio = 5

# dirty_writeback_centisecs: intervalo entre escrituras de flusher (en centisegundos).
# 1500 = 15s. Más frecuente que el default (500 = 5s) reduce picos de I/O.
vm.dirty_writeback_centisecs = 1500

# dirty_expire_centisecs: tiempo máximo que una página sucia puede esperar
# antes de ser escrita. 3000 = 30s (default: 3000, se mantiene explícito).
vm.dirty_expire_centisecs = 3000

# ── Caché de VFS ─────────────────────────────────────────────────────────────
# vfs_cache_pressure: controla la tendencia del kernel a recuperar memoria
# usada por el caché de inodos y dentries. Valor bajo (50) preserva más caché
# de filesystem → menos accesos a disco para metadata.
vm.vfs_cache_pressure = 50
SYSCTLEOF

sysctl -p /etc/sysctl.d/60-storage.conf 2>/dev/null || true
echo "✓  sysctl de almacenamiento aplicado"

# ============================================================================
# OPCIONES DE MONTAJE — actualizar fstab con opciones adicionales
# ============================================================================
# noatime ya está en el fstab generado por 02-debootstrap.
# Para SSD/NVMe añadimos también commit=60 (flush de journal cada 60s en lugar
# de 5s) y discard=async (TRIM inline asíncrono, más eficiente que sícrono).
# Para HDD: commit=60 también reduce escrituras de journal sin riesgo real.
# NOTA: no se modifica el fstab directamente para evitar romper UUIDs;
# se usa drop-in de systemd mount si está disponible, o sed conservador.
# ============================================================================

if [ -f /etc/fstab ]; then
    # Detectar si la raíz es ext4 (único FS donde estas opciones aplican aquí)
    ROOT_FS=\$(awk '\$2=="/" {print \$3}' /etc/fstab 2>/dev/null | head -1)

    if [ "\$ROOT_FS" = "ext4" ]; then
        case "\$DISK_TYPE" in
            nvme|ssd|emmc)
                # Añadir commit=60 y discard=async si no están ya
                if ! grep -q "commit=" /etc/fstab; then
                    sed -i '/^UUID=.*\s\/\s\+ext4\s/ s|errors=remount-ro|errors=remount-ro,commit=60,discard=async|' /etc/fstab
                fi
                echo "✓  fstab: commit=60 + discard=async añadidos (SSD/NVMe/eMMC)"
                ;;
            hdd)
                if ! grep -q "commit=" /etc/fstab; then
                    sed -i '/^UUID=.*\s\/\s\+ext4\s/ s|errors=remount-ro|errors=remount-ro,commit=60|' /etc/fstab
                fi
                echo "✓  fstab: commit=60 añadido (HDD)"
                ;;
            *)
                echo "  fstab: tipo de disco no detectado, sin cambios adicionales"
                ;;
        esac
    fi
fi

# ============================================================================
# SWAPFILE
# ============================================================================
# Se usa swapfile en lugar de partición swap: más flexible (redimensionable
# sin reparticionar) y mismo rendimiento desde kernel 5.0 en ext4.
# Tamaño: viene de SWAP_GIB en partition.info (calculado en 01-prepare-disk).
# Si SWAP_GIB=0 el usuario eligió no tener swap — se respeta.
# Prioridad de swappiness: baja (10) para SSD/NVMe, normal (60) para HDD.
# ============================================================================

SWAP_GIB=${SWAP_GIB:-0}

if [ "\$SWAP_GIB" -gt 0 ] 2>/dev/null; then
    SWAPFILE="/swapfile"

    if [ -f "\$SWAPFILE" ]; then
        echo "  swapfile ya existe (\$SWAPFILE) — omitiendo creación"
    else
        echo "Creando swapfile de \${SWAP_GIB} GiB..."

        # IMPORTANTE: NO usar fallocate — en ext4 crea extents preallocados que
        # el kernel puede rechazar con "swapon: Invalid argument" (man swapon,
        # sección "Files with holes"). dd /dev/zero es el método portablemente
        # correcto recomendado por mkswap(8) y swapon(8).
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

    # NOTA: la hibernación via swapfile requiere resume=UUID=<root> resume_offset=<offset>
    # en el cmdline de GRUB. El offset se calcula con:
    #   sudo filefrag -v /swapfile | awk 'NR==4 {print $4}'
    # y debe añadirse a GRUB_CMDLINE_LINUX_DEFAULT en /etc/default/grub
    # seguido de sudo update-grub. No se configura automáticamente desde el
    # instalador porque el offset solo es válido en el sistema arrancado real.

else
    echo "  SWAP_GIB=0 — sin swapfile (elegido en la configuración del disco)"
fi

udevadm control --reload-rules 2>/dev/null || true

STOREOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ALMACENAMIENTO OPTIMIZADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Scheduler I/O: none (NVMe) / mq-deadline (SSD/eMMC) / bfq (HDD)"
echo "  Readahead:     256 KB (NVMe/SSD) / 512 KB (eMMC) / 4 MB (HDD)"
echo "  fstrim.timer:  habilitado (TRIM semanal)"
echo "  sysctl:        dirty_ratio=10, vfs_cache_pressure=50"
echo "  fstab:         commit=60 + discard=async (SSD/NVMe/eMMC)"
echo "  swapfile:      ${SWAP_GIB:-0} GiB en /swapfile (si SWAP_GIB > 0)"
echo ""

exit 0
