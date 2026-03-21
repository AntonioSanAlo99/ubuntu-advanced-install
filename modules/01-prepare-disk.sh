#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 01: Preparación de disco
# Particionado interactivo con soporte completo para instalación limpia y
# dual boot. Diseñado con el mismo nivel de robustez que Calamares y los
# instaladores oficiales de Ubuntu/Debian.
# ══════════════════════════════════════════════════════════════════════════════
# EXPORTA: TARGET_DISK, ROOT_PART, EFI_PART, SWAP_PART, FIRMWARE,
#          DUAL_BOOT_MODE, TARGET → partition.info
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TARGET:-/mnt/ubuntu}"


# ============================================================================
# DETECCIÓN DE FIRMWARE
# ============================================================================

if [ -d /sys/firmware/efi ]; then
    FIRMWARE="UEFI"
    EFI_BITNESS=$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null || echo 64)
else
    FIRMWARE="BIOS"
    EFI_BITNESS=""
fi

echo "  Firmware  : $FIRMWARE${EFI_BITNESS:+ (${EFI_BITNESS}-bit)}"
echo "  Kernel    : $(uname -r)"
echo ""

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Nombre de partición según tipo de dispositivo (nvme/mmcblk usan 'p' como separador)
part_name() {
    local disk="$1" num="$2"
    if [[ "$disk" == *nvme* ]] || [[ "$disk" == *mmcblk* ]]; then
        echo "${disk}p${num}"
    else
        echo "${disk}${num}"
    fi
}

# Tamaño de bloque en bytes
disk_bytes() {
    lsblk -b -d -n -o SIZE "$1" 2>/dev/null || echo 0
}

bytes_to_gib() {
    echo $(( $1 / 1024 / 1024 / 1024 ))
}

# Espacio libre real al final del disco (mayor región contigua no particionada)
free_space_end_gib() {
    local disk="$1"
    local total_bytes
    total_bytes=$(disk_bytes "$disk")
    local used_bytes=0
    while IFS= read -r part; do
        [ -z "$part" ] && continue
        local s
        s=$(lsblk -b -n -o SIZE "$part" 2>/dev/null || echo 0)
        used_bytes=$(( used_bytes + s ))
    done < <(lsblk -n -p -o NAME "$disk" | grep -v "^${disk}$")
    local free=$(( total_bytes - used_bytes ))
    [ $free -lt 0 ] && free=0
    bytes_to_gib $free
}

# Tabla de particiones actual del disco
partition_table_type() {
    lsblk -n -d -o PTTYPE "$1" 2>/dev/null || parted -s "$1" print 2>/dev/null | grep "Partition Table:" | awk '{print $3}'
}

# Verificar que una partición fue creada y tiene el tamaño esperado
verify_partition() {
    local part="$1"
    local label="$2"
    if [ ! -b "$part" ]; then
        echo "  ✗  ERROR CRÍTICO: $label ($part) no existe como dispositivo de bloque"
        exit 1
    fi
    local size_mb=$(( $(lsblk -b -n -o SIZE "$part" 2>/dev/null || echo 0) / 1024 / 1024 ))
    echo "  ✓  $label: $part (${size_mb} MiB)"
}

# Esperar a que udev procese los nuevos nodos de dispositivo
settle_partitions() {
    local disk="$1"
    sync
    partprobe "$disk" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
    sleep 1
    partprobe "$disk" 2>/dev/null || true
    udevadm settle 2>/dev/null || true
    sleep 1
}

# ============================================================================
# SELECCIÓN DE DISCO
# ============================================================================

echo "Discos disponibles:"
echo ""

mapfile -t DISKS < <(lsblk -d -n -p -o NAME,TYPE | awk '$2=="disk"{print $1}')

if [ ${#DISKS[@]} -eq 0 ]; then
    echo "  ✗  No se encontraron discos disponibles"
    exit 1
fi

for i in "${!DISKS[@]}"; do
    disk="${DISKS[$i]}"
    size_bytes=$(disk_bytes "$disk")
    size_gib=$(bytes_to_gib $size_bytes)
    size_display=$(lsblk -d -n -o SIZE "$disk" 2>/dev/null || echo "?")
    model=$(lsblk -d -n -o MODEL "$disk" 2>/dev/null | xargs || echo "")
    rota=$(lsblk -d -n -o ROTA "$disk" 2>/dev/null || echo "?")
    pttype=$(partition_table_type "$disk")

    # Sistemas detectados en el disco
    sys_info=""
    if lsblk -n -o FSTYPE "$disk" 2>/dev/null | grep -qi "ntfs"; then
        sys_info="${sys_info} [Windows]"
    fi
    if lsblk -n -o FSTYPE "$disk" 2>/dev/null | grep -qiE "ext4|btrfs|xfs"; then
        sys_info="${sys_info} [Linux]"
    fi
    if lsblk -n -o FSTYPE "$disk" 2>/dev/null | grep -qi "vfat"; then
        sys_info="${sys_info} [EFI]"
    fi

    disk_type=""
    [ "$rota" = "0" ] && disk_type="SSD/NVMe" || disk_type="HDD"

    printf "  %d) %-12s  %6s  %-10s  %s%s\n" \
        "$((i+1))" "$disk" "$size_display" "$disk_type" "${model:+$model}" "$sys_info"
done

echo ""
read -p "  Selecciona disco [1]: " choice
choice=${choice:-1}
idx=$(( choice - 1 ))

if [ $idx -lt 0 ] || [ $idx -ge ${#DISKS[@]} ]; then
    echo "  ✗  Selección inválida"
    exit 1
fi

TARGET_DISK="${DISKS[$idx]}"
DISK_SIZE_BYTES=$(disk_bytes "$TARGET_DISK")
DISK_SIZE_GIB=$(bytes_to_gib $DISK_SIZE_BYTES)

echo ""
echo "  Disco seleccionado: $TARGET_DISK ($DISK_SIZE_GIB GiB)"
echo ""
echo "  Tabla de particiones actual:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,PARTLABEL "$TARGET_DISK" 2>/dev/null | sed 's/^/    /'
echo ""

# ============================================================================
# MODO DE INSTALACIÓN
# ============================================================================

HAS_WINDOWS=false
HAS_LINUX=false
HAS_EFI_PART=false
EXISTING_EFI=""

lsblk -n -o FSTYPE "$TARGET_DISK" 2>/dev/null | grep -qi "ntfs"  && HAS_WINDOWS=true || true
lsblk -n -o FSTYPE "$TARGET_DISK" 2>/dev/null | grep -qiE "ext4|btrfs|xfs" && HAS_LINUX=true || true

if [ "$FIRMWARE" = "UEFI" ]; then
    # Buscar partición EFI: tipo ESP o vfat en los primeros 512 MiB
    while IFS= read -r part; do
        [ -z "$part" ] && continue
        fstype=$(lsblk -n -o FSTYPE "$part" 2>/dev/null | head -1)
        parttype=$(lsblk -n -o PARTTYPE "$part" 2>/dev/null | head -1 | tr '[:upper:]' '[:lower:]')
        esp_flag=$(lsblk -n -o PARTFLAGS "$part" 2>/dev/null | head -1)
        # ESP: tipo c12a7328 (GUID) o boot+esp flags o vfat en posición inicial
        if [[ "$parttype" == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]] || \
           echo "$esp_flag" | grep -qi "esp\|boot"; then
            EXISTING_EFI="$part"
            HAS_EFI_PART=true
            break
        fi
        # Fallback: primera partición vfat en los primeros 512 MiB
        if [ "$fstype" = "vfat" ] && [ -z "$EXISTING_EFI" ]; then
            part_start=$(parted -s "$TARGET_DISK" unit MiB print 2>/dev/null | \
                grep "$(basename $part)" | awk '{print $2}' | tr -d 'MiB')
            if [ -n "$part_start" ] && [ "${part_start%%.*}" -lt 513 ] 2>/dev/null; then
                EXISTING_EFI="$part"
                HAS_EFI_PART=true
            fi
        fi
    done < <(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^${TARGET_DISK}$")
fi

if $HAS_WINDOWS || $HAS_LINUX; then
    echo "  Se detectaron sistemas existentes en el disco."
    echo ""
    echo "  ¿Qué quieres hacer?"
    echo ""
    echo "    1) Instalación limpia  — BORRA TODO en $TARGET_DISK"
    echo "    2) Dual boot           — Conserva el sistema actual, instala Ubuntu en espacio libre"
    echo "    3) Cancelar"
    echo ""
    read -p "  Opción [2]: " install_mode
    install_mode=${install_mode:-2}
else
    echo "  Disco sin sistemas operativos detectados."
    echo ""
    echo "  ¿Qué quieres hacer?"
    echo ""
    echo "    1) Instalación limpia  — Usar todo el disco"
    echo "    2) Cancelar"
    echo ""
    read -p "  Opción [1]: " install_mode
    install_mode=${install_mode:-1}
fi

# ============================================================================
# PARÁMETRO: SWAP
# ============================================================================
# Calamares y el instalador de Ubuntu crean swap según la RAM disponible.
# Regla usada por Ubuntu / Debian:
#   RAM < 2 GiB  → swap = RAM * 2
#   2–8 GiB      → swap = RAM
#   8–16 GiB     → swap = 8 GiB (fijo)
#   > 16 GiB     → swap = 0 (opcional, el usuario decide)
#
# Se usa swapfile (no partición swap) porque:
#   - Más flexible: redimensionable sin reparticionar
#   - Mismo rendimiento desde kernel 5.0 en ext4
#   - El swapfile se crea en 11-configure-storage.sh
#   - Compatible con hibernación via swapfile (uswsusp/systemd-sleep)
# El tamaño aquí solo se guarda en partition.info para que
# 11-configure-storage.sh lo use al crear el swapfile.

RAM_BYTES=$(grep MemTotal /proc/meminfo | awk '{print $2 * 1024}')
RAM_GIB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))

if   [ $RAM_GIB -lt 2 ];  then SWAP_GIB=$(( RAM_GIB * 2 ))
elif [ $RAM_GIB -le 8 ];  then SWAP_GIB=$RAM_GIB
elif [ $RAM_GIB -le 16 ]; then SWAP_GIB=8
else                            SWAP_GIB=0
fi

echo ""
echo "  RAM detectada: ${RAM_GIB} GiB  →  Swap recomendado: ${SWAP_GIB} GiB"
echo "  (0 = sin swapfile; se puede crear manualmente después)"
echo ""
read -p "  Tamaño de swapfile en GiB [${SWAP_GIB}]: " user_swap
SWAP_GIB=${user_swap:-$SWAP_GIB}

if ! [[ "$SWAP_GIB" =~ ^[0-9]+$ ]]; then
    echo "  ✗  Valor de swap inválido"
    exit 1
fi

# ============================================================================
# MODO 1: INSTALACIÓN LIMPIA
# ============================================================================

if [ "$install_mode" = "1" ]; then

    echo ""
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  ⚠  ADVERTENCIA: SE BORRARÁ TODO en $TARGET_DISK"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "  Esta operación es IRREVERSIBLE. Todos los datos se perderán."
    echo ""
    read -p "  Escribe BORRAR para confirmar: " confirm
    [ "$confirm" != "BORRAR" ] && echo "  Cancelado." && exit 1

    echo ""
    echo "  Preparando disco..."

    # Desmontar todo lo que pueda estar montado del disco objetivo
    for part in $(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^${TARGET_DISK}$"); do
        umount -f "$part" 2>/dev/null || true
    done
    swapoff -a 2>/dev/null || true

    # Invalidar firmas y tabla de particiones anterior
    wipefs -a "$TARGET_DISK"
    dd if=/dev/zero of="$TARGET_DISK" bs=1M count=4 conv=fsync 2>/dev/null || true
    # Limpiar también el final del disco (tabla GPT de respaldo)
    dd if=/dev/zero of="$TARGET_DISK" bs=512 count=34 seek=$(( $(blockdev --getsz "$TARGET_DISK") - 34 )) conv=fsync 2>/dev/null || true

    settle_partitions "$TARGET_DISK"

    # ── Esquema de particionado ──────────────────────────────────────────────
    NEXT_PART=1
    EFI_PART=""
    SWAP_PART=""

    if [ "$FIRMWARE" = "UEFI" ]; then
        # ── UEFI / GPT ───────────────────────────────────────────────────────
        # Diseño idéntico a Ubuntu 24.04 y Debian 12:
        #   1 MiB   alineación inicial (GPT + BIOS boot gap)
        #   512 MiB EFI System Partition (FAT32, tipo ESP)
        #   [N GiB] Swap (tipo Linux swap)
        #   resto   Root (ext4, tipo Linux filesystem)

        parted -s "$TARGET_DISK" mklabel gpt

        # EFI: 1 MiB → 513 MiB
        parted -s "$TARGET_DISK" mkpart "EFI" fat32 1MiB 513MiB
        parted -s "$TARGET_DISK" set $NEXT_PART esp on
        EFI_PART=$(part_name "$TARGET_DISK" $NEXT_PART)
        NEXT_PART=$(( NEXT_PART + 1 ))

        START_MIB=513

        parted -s "$TARGET_DISK" mkpart "root" ext4 "${START_MIB}MiB" "100%"
        SWAP_PART=""
        ROOT_PART=$(part_name "$TARGET_DISK" $NEXT_PART)

    else
        # ── BIOS / MBR ───────────────────────────────────────────────────────
        # Diseño para BIOS legacy:
        #   1 MiB   alineación inicial (BIOS boot)
        #   [N GiB] Swap (tipo 82)
        #   resto   Root ext4 primaria, flag boot

        parted -s "$TARGET_DISK" mklabel msdos

        START_MIB=1

        parted -s "$TARGET_DISK" mkpart primary ext4 "${START_MIB}MiB" "100%"
        SWAP_PART=""
        parted -s "$TARGET_DISK" set $NEXT_PART boot on
        ROOT_PART=$(part_name "$TARGET_DISK" $NEXT_PART)
        EFI_PART=""
    fi

    settle_partitions "$TARGET_DISK"

    # ── Formateo ─────────────────────────────────────────────────────────────
    echo ""
    echo "  Formateando particiones..."

    if [ "$FIRMWARE" = "UEFI" ]; then
        # EFI: FAT32 con etiqueta EFI (compatible con todos los firmware)
        mkfs.fat -F 32 -n "EFI" "$EFI_PART"
        echo "  ✓  EFI: $EFI_PART → FAT32"
    fi

    # Root: ext4 con opciones recomendadas por Ubuntu installer
    mkfs.ext4 -F \
        -L "ubuntu-root" \
        -O "has_journal,extent,huge_file,flex_bg,metadata_csum,64bit,dir_nlink,extra_isize" \
        "$ROOT_PART"
    echo "  ✓  Root: $ROOT_PART → ext4"

    DUAL_BOOT_MODE="false"

# ============================================================================
# MODO 2: DUAL BOOT
# ============================================================================

elif [ "$install_mode" = "2" ]; then

    echo ""
    echo "  Analizando espacio disponible..."
    echo ""

    FREE_GIB=$(free_space_end_gib "$TARGET_DISK")
    TOTAL_NEEDED=$(( 25 + 1 ))   # mínimo root + margen (swap como swapfile en root)

    echo "  Espacio libre al final del disco : ${FREE_GIB} GiB"
    echo "  Mínimo necesario para Ubuntu     : ${TOTAL_NEEDED} GiB  (25 sistema + 1 margen; swap como swapfile)"
    echo ""

    if [ $FREE_GIB -lt $TOTAL_NEEDED ]; then
        echo "  ✗  Espacio insuficiente."
        echo "     Libera al menos ${TOTAL_NEEDED} GiB en el disco antes de continuar."
        echo "     En Windows: Administrador de discos → Reducir volumen."
        exit 1
    fi

    # Sugerir tamaño: espacio libre menos swap menos 2 GiB de margen
    SUGGESTED=$(( FREE_GIB - 2 ))
    [ $SUGGESTED -lt 25 ] && SUGGESTED=25

    echo "  Tamaño sugerido para Ubuntu: ${SUGGESTED} GiB"
    echo "  (mínimo recomendado: 30 GiB; óptimo: 50 GiB o más)"
    echo ""
    read -p "  ¿Cuántos GiB para Ubuntu? [${SUGGESTED}]: " ubuntu_gib
    ubuntu_gib=${ubuntu_gib:-$SUGGESTED}

    if ! [[ "$ubuntu_gib" =~ ^[0-9]+$ ]]; then
        echo "  ✗  Valor inválido"
        exit 1
    fi
    if [ $ubuntu_gib -lt 25 ]; then
        echo "  ✗  Mínimo absoluto: 25 GiB"
        exit 1
    fi
    TOTAL_NEEDED_FINAL=$(( ubuntu_gib + 1 ))
    if [ $TOTAL_NEEDED_FINAL -gt $FREE_GIB ]; then
        echo "  ✗  No hay suficiente espacio libre (necesitas ${TOTAL_NEEDED_FINAL} GiB, disponibles ${FREE_GIB} GiB)"
        exit 1
    fi

    # ── Validar partición EFI existente (UEFI) ───────────────────────────────
    if [ "$FIRMWARE" = "UEFI" ]; then
        if [ -z "$EXISTING_EFI" ]; then
            echo ""
            echo "  ✗  No se encontró partición EFI en $TARGET_DISK."
            echo "     En un sistema UEFI con dual boot debe existir una EFI System Partition."
            echo "     Si Windows está instalado, debería haber una. Verifica con: lsblk -o NAME,FSTYPE,PARTTYPE $TARGET_DISK"
            exit 1
        fi

        EFI_SIZE_MIB=$(( $(lsblk -b -n -o SIZE "$EXISTING_EFI" 2>/dev/null || echo 0) / 1024 / 1024 ))
        echo ""
        echo "  Partición EFI existente: $EXISTING_EFI (${EFI_SIZE_MIB} MiB)"

        # Advertir si la EFI es demasiado pequeña (mínimo recomendado: 100 MiB, ideal: 260 MiB)
        if [ $EFI_SIZE_MIB -lt 100 ]; then
            echo "  ⚠  La partición EFI es muy pequeña (${EFI_SIZE_MIB} MiB). Pueden surgir problemas."
            echo "     Se recomienda una EFI de al menos 260 MiB para dual boot."
        fi

        EFI_PART="$EXISTING_EFI"
    else
        EFI_PART=""
    fi

    # ── Verificar tabla de particiones ───────────────────────────────────────
    PTTYPE=$(partition_table_type "$TARGET_DISK")
    echo "  Tabla de particiones: $PTTYPE"

    if [ "$FIRMWARE" = "UEFI" ] && [ "$PTTYPE" != "gpt" ]; then
        echo "  ✗  El firmware es UEFI pero la tabla de particiones es '$PTTYPE' (se requiere GPT)."
        exit 1
    fi
    if [ "$FIRMWARE" = "BIOS" ] && [ "$PTTYPE" = "gpt" ]; then
        echo "  ⚠  Tabla GPT en sistema BIOS. El bootloader necesitará una partición BIOS boot."
        echo "     Si no existe, la instalación de GRUB puede fallar."
    fi

    # ── Contar particiones existentes para numerar las nuevas ────────────────
    EXISTING_PARTS=$(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^${TARGET_DISK}$" | wc -l)
    NEXT_NUM=$(( EXISTING_PARTS + 1 ))

    # ── Resumen y confirmación ───────────────────────────────────────────────
    echo ""
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║  Configuración de dual boot"
    echo "  ╠══════════════════════════════════════════════════════════╣"
    [ "$FIRMWARE" = "UEFI" ] && echo "  ║  EFI  : $EFI_PART  (existente, no se modifica)"
    ROOT_NUM=$NEXT_NUM
    echo "  ║  Root : $(part_name $TARGET_DISK $ROOT_NUM)  (nueva, ${ubuntu_gib} GiB, ext4)"
    echo "  ║"
    echo "  ║  ⚠  Las particiones del sistema existente NO se modifican."
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo ""
    read -p "  ¿Continuar? [s/N]: " confirm
    [[ ! "$confirm" =~ ^[Ss]$ ]] && echo "  Cancelado." && exit 1

    # ── Crear nuevas particiones ─────────────────────────────────────────────
    echo ""
    echo "  Creando particiones..."

    SWAP_PART=""

    if [ "$PTTYPE" = "gpt" ]; then
        parted -s "$TARGET_DISK" mkpart "ubuntu-root" ext4 -- "-${ubuntu_gib}GiB" "100%"
    else
        parted -s "$TARGET_DISK" mkpart primary ext4 -- "-${ubuntu_gib}GiB" "100%"
    fi
    ROOT_PART=$(part_name "$TARGET_DISK" $NEXT_NUM)

    settle_partitions "$TARGET_DISK"

    # ── Formateo ─────────────────────────────────────────────────────────────
    echo ""
    echo "  Formateando particiones nuevas..."

    mkfs.ext4 -F \
        -L "ubuntu-root" \
        -O "has_journal,extent,huge_file,flex_bg,metadata_csum,64bit,dir_nlink,extra_isize" \
        "$ROOT_PART"
    echo "  ✓  Root: $ROOT_PART → ext4 (${ubuntu_gib} GiB)"

    DUAL_BOOT_MODE="true"

else
    echo ""
    echo "  Cancelado."
    exit 1
fi

# ============================================================================
# VERIFICACIÓN POST-PARTICIONADO
# ============================================================================

echo ""
echo "  Verificando particiones..."

[ "$FIRMWARE" = "UEFI" ] && [ -n "$EFI_PART" ]  && verify_partition "$EFI_PART"  "EFI"
[ -n "$SWAP_PART" ]                               && verify_partition "$SWAP_PART" "Swap"
verify_partition "$ROOT_PART" "Root"

# ============================================================================
# RESUMEN FINAL
# ============================================================================

echo ""
echo "  Estado del disco tras el particionado:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINT "$TARGET_DISK" 2>/dev/null | sed 's/^/    /'
echo ""

# ============================================================================
# EXPORTAR VARIABLES
# ============================================================================

export TARGET_DISK
export ROOT_PART
export EFI_PART
export SWAP_PART
export FIRMWARE
export DUAL_BOOT_MODE
export TARGET

cat > "${SCRIPT_DIR}/../partition.info" << EOF
TARGET_DISK="$TARGET_DISK"
ROOT_PART="$ROOT_PART"
EFI_PART="$EFI_PART"
SWAP_PART="$SWAP_PART"
SWAP_GIB="$SWAP_GIB"
FIRMWARE="$FIRMWARE"
DUAL_BOOT_MODE="$DUAL_BOOT_MODE"
TARGET="${TARGET:-/mnt/ubuntu}"
EOF

echo "════════════════════════════════════════════════════════════════"
echo "✓  DISCO PREPARADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Disco  : $TARGET_DISK"
echo "  Modo   : $([ "$DUAL_BOOT_MODE" = "true" ] && echo "Dual boot" || echo "Instalación limpia")"
[ "$FIRMWARE" = "UEFI" ] && echo "  EFI    : $EFI_PART"
[ -n "$SWAP_PART" ]       && echo "  Swap   : $SWAP_PART (${SWAP_GIB} GiB)"
[ -z "$SWAP_PART" ] && [ "$SWAP_GIB" -gt 0 ] && echo "  Swap   : swapfile de ${SWAP_GIB} GiB (se creará en /swapfile)"
[ "$SWAP_GIB" = "0" ]     && echo "  Swap   : sin swap"
echo "  Root   : $ROOT_PART"
echo ""

exit 0
