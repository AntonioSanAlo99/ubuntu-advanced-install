#!/bin/bash
# Módulo 01: Preparar disco (detección automática + dual-boot)

source "$(dirname "$0")/../config.env"

echo "═══════════════════════════════════════════════════════════"
echo "  PREPARACIÓN DE DISCO - DETECCIÓN AUTOMÁTICA"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Verificar parted
if ! command -v parted &> /dev/null; then
    echo "⚠ parted no encontrado, instalando..."
    apt update && apt install -y parted
    echo "✓ parted instalado"
    echo ""
fi

# Detect firmware
if [ -d /sys/firmware/efi ]; then
    FIRMWARE="UEFI"
else
    FIRMWARE="BIOS"
fi

echo "✓ Firmware: $FIRMWARE"
echo ""

# Detect disks
echo "Detectando discos y sistemas operativos..."
DISKS=($(lsblk -d -n -p -o NAME,TYPE | grep disk | awk '{print $1}'))

if [ ${#DISKS[@]} -eq 0 ]; then
    echo "❌ No se detectaron discos"
    exit 1
fi

# Detect Windows and other OS
declare -A DISK_HAS_WINDOWS
declare -A DISK_HAS_EFI

for disk in "${DISKS[@]}"; do
    DISK_HAS_WINDOWS[$disk]="no"
    DISK_HAS_EFI[$disk]="no"
    
    # Check for Windows partitions
    while read part; do
        fstype=$(lsblk -n -o FSTYPE "$part" 2>/dev/null)
        label=$(lsblk -n -o LABEL "$part" 2>/dev/null)
        
        # Detect Windows by filesystem and common labels
        if [[ "$fstype" == "ntfs" ]]; then
            # Check if it's a Windows system partition
            if [[ "$label" =~ ^(Windows|System|OS|WINRE).*$ ]] || \
               [ -n "$(blkid "$part" | grep -i windows)" ]; then
                DISK_HAS_WINDOWS[$disk]="yes"
            fi
            # Check common Windows directories if we can mount
            if mkdir -p /tmp/check_win 2>/dev/null; then
                if mount -r "$part" /tmp/check_win 2>/dev/null; then
                    if [ -d /tmp/check_win/Windows ] || [ -d /tmp/check_win/windows ]; then
                        DISK_HAS_WINDOWS[$disk]="yes"
                    fi
                    umount /tmp/check_win 2>/dev/null
                fi
                rmdir /tmp/check_win 2>/dev/null
            fi
        fi
        
        # Detect EFI partition
        if [[ "$fstype" == "vfat" ]] && [[ "$label" =~ ^(EFI|SYSTEM).*$ ]]; then
            DISK_HAS_EFI[$disk]="yes"
        fi
        
        # Check partition type for EFI (GPT)
        parttype=$(blkid -s PART_ENTRY_TYPE -o value "$part" 2>/dev/null)
        if [[ "$parttype" == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]]; then
            DISK_HAS_EFI[$disk]="yes"
        fi
    done < <(lsblk -n -p -o NAME "$disk" | grep -v "^$disk$")
done

# Show disks with OS detection
echo ""
for i in "${!DISKS[@]}"; do
    disk="${DISKS[$i]}"
    size=$(lsblk -b -d -n -o SIZE "$disk")
    size_gb=$((size / 1024 / 1024 / 1024))
    
    # Detect type
    if [[ $disk == *"nvme"* ]]; then
        dtype="NVMe"
    else
        dname=$(basename "$disk")
        if [ -f "/sys/block/$dname/queue/rotational" ]; then
            rot=$(cat "/sys/block/$dname/queue/rotational")
            [ "$rot" -eq 0 ] && dtype="SSD" || dtype="HDD"
        else
            dtype="Unknown"
        fi
    fi
    
    echo "  $((i+1))) $disk - ${size_gb}GB [$dtype]"
    
    # Show OS detection
    if [ "${DISK_HAS_WINDOWS[$disk]}" = "yes" ]; then
        echo "      ⚠️  Windows detectado en este disco"
    fi
    
    # Show partitions
    while read line; do
        part_name=$(echo "$line" | awk '{print $1}')
        part_size=$(echo "$line" | awk '{print $2}')
        part_fstype=$(echo "$line" | awk '{print $3}')
        part_label=$(echo "$line" | awk '{print $4}')
        
        if [ -n "$part_fstype" ]; then
            echo -n "      $part_name  $part_size  $part_fstype"
            [ -n "$part_label" ] && echo "  \"$part_label\"" || echo ""
        fi
    done < <(lsblk -n -p -o NAME,SIZE,FSTYPE,LABEL "$disk" | grep -v "^$disk ")
    echo ""
done

# Select disk
if [ ${#DISKS[@]} -eq 1 ]; then
    read -p "Usar ${DISKS[0]}? (s/n) [s]: " ans
    [[ ! ${ans:-s} =~ ^[SsYy]$ ]] && exit 1
    TARGET_DISK="${DISKS[0]}"
else
    read -p "Selecciona disco (1-${#DISKS[@]}): " choice
    TARGET_DISK="${DISKS[$((choice-1))]}"
fi

# Detect disk type
if [[ $TARGET_DISK == *"nvme"* ]]; then
    DISK_TYPE="nvme"
else
    dname=$(basename "$TARGET_DISK")
    rot=$(cat "/sys/block/$dname/queue/rotational" 2>/dev/null || echo "0")
    [ "$rot" -eq 0 ] && DISK_TYPE="ssd" || DISK_TYPE="hdd"
fi

echo ""
echo "✓ Disco seleccionado: $TARGET_DISK [$DISK_TYPE]"

# Check if Windows exists on selected disk
HAS_WINDOWS="${DISK_HAS_WINDOWS[$TARGET_DISK]}"
HAS_EFI="${DISK_HAS_EFI[$TARGET_DISK]}"

if [ "$HAS_WINDOWS" = "yes" ]; then
    echo ""
    echo "⚠️⚠️⚠️  WINDOWS DETECTADO  ⚠️⚠️⚠️"
    echo ""
    echo "Se ha detectado una instalación de Windows en este disco."
    echo ""
fi

echo ""
echo "Opciones de instalación:"
echo ""

if [ "$HAS_WINDOWS" = "yes" ]; then
    echo "  1) Dual-boot (mantener Windows + instalar Ubuntu)"
    echo "  2) Formatear completo (⚠️ BORRA WINDOWS)"
    echo "  3) Manual (cfdisk/fdisk)"
    echo ""
    read -p "Opción (1-3) [1]: " mode
    mode=${mode:-1}
else
    echo "  1) Formatear completo (automático)"
    echo "  2) Manual (cfdisk/fdisk)"
    echo ""
    read -p "Opción (1-2) [1]: " mode
    mode=${mode:-1}
    # Ajustar números si no hay Windows
    [ "$mode" = "2" ] && mode=3
fi

# ============================================================================
# MODO 1: DUAL-BOOT
# ============================================================================

if [ "$mode" = "1" ] && [ "$HAS_WINDOWS" = "yes" ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  CONFIGURACIÓN DUAL-BOOT"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Show current partitions
    echo "Particiones actuales:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$TARGET_DISK"
    echo ""
    
    # Calculate free space
    TOTAL_SIZE=$(lsblk -b -d -n -o SIZE "$TARGET_DISK")
    USED_SIZE=0
    
    while read part; do
        part_size=$(lsblk -b -n -o SIZE "$part" 2>/dev/null)
        USED_SIZE=$((USED_SIZE + part_size))
    done < <(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^$TARGET_DISK$")
    
    FREE_SIZE=$((TOTAL_SIZE - USED_SIZE))
    FREE_GB=$((FREE_SIZE / 1024 / 1024 / 1024))
    
    echo "Espacio libre disponible: ~${FREE_GB}GB"
    echo ""
    
    if [ $FREE_GB -lt 20 ]; then
        echo "⚠️  Advertencia: Espacio libre insuficiente (mínimo 20GB recomendado)"
        read -p "¿Continuar de todos modos? (s/n): " continue
        [[ ! $continue =~ ^[SsYy]$ ]] && exit 1
    fi
    
    read -p "¿Cuánto espacio asignar a Ubuntu? (GB) [50]: " ubuntu_size
    ubuntu_size=${ubuntu_size:-50}
    
    if [ $ubuntu_size -gt $FREE_GB ]; then
        echo "⚠️  No hay suficiente espacio libre. Usando ${FREE_GB}GB"
        ubuntu_size=$FREE_GB
    fi
    
    echo ""
    echo "Se creará:"
    echo "  • Partición Ubuntu: ${ubuntu_size}GB ext4"
    
    if [ "$HAS_EFI" = "yes" ]; then
        echo "  • Partición EFI: Usar existente (compartida con Windows)"
    else
        echo "  • Partición EFI: Crear nueva 512MB"
    fi
    
    echo ""
    read -p "¿Continuar con dual-boot? (s/n): " confirm
    [[ ! $confirm =~ ^[SsYy]$ ]] && exit 1
    
    # Get last partition number and end sector
    LAST_PART=$(parted -s "$TARGET_DISK" print | grep "^ " | tail -1 | awk '{print $1}')
    
    # Create new partition for Ubuntu
    echo ""
    echo "Creando partición Ubuntu..."
    
    # Use parted to create partition in free space
    parted -s "$TARGET_DISK" mkpart primary ext4 "-${ubuntu_size}GB" "100%"
    
    sleep 2
    partprobe "$TARGET_DISK" 2>/dev/null || true
    sleep 1
    
    # Get the new partition
    NEW_PARTS=($(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^$TARGET_DISK$"))
    ROOT_PART="${NEW_PARTS[-1]}"  # Last partition
    
    echo "Formateando $ROOT_PART como ext4..."
    mkfs.ext4 -F "$ROOT_PART"
    
    # Find or use existing EFI partition
    if [ "$FIRMWARE" = "UEFI" ]; then
        if [ "$HAS_EFI" = "yes" ]; then
            # Find existing EFI partition
            EFI_PART=$(lsblk -n -p -o NAME,FSTYPE "$TARGET_DISK" | grep vfat | head -1 | awk '{print $1}')
            echo "✓ Usando partición EFI existente: $EFI_PART"
        else
            echo "⚠️  No se encontró partición EFI existente"
            echo "Esto puede causar problemas en dual-boot UEFI"
            read -p "¿Crear nueva partición EFI? (s/n) [n]: " create_efi
            if [[ $create_efi =~ ^[SsYy]$ ]]; then
                parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 513MiB
                parted -s "$TARGET_DISK" set 1 esp on
                sleep 1
                [[ $TARGET_DISK == *"nvme"* ]] && EFI_PART="${TARGET_DISK}p1" || EFI_PART="${TARGET_DISK}1"
                mkfs.fat -F32 "$EFI_PART"
                echo "✓ Partición EFI creada: $EFI_PART"
            fi
        fi
    fi
    
    DUAL_BOOT_MODE="true"
    
    echo ""
    echo "✓✓✓ Dual-boot configurado ✓✓✓"
    echo ""
    echo "Particiones:"
    echo "  • Windows: Preservado"
    echo "  • Ubuntu Root: $ROOT_PART (${ubuntu_size}GB)"
    [ -n "$EFI_PART" ] && echo "  • EFI: $EFI_PART (compartida)"

# ============================================================================
# MODO 2: FORMATEO COMPLETO
# ============================================================================

elif [ "$mode" = "2" ] && [ "$HAS_WINDOWS" = "yes" ]; then
    echo ""
    echo "⚠️⚠️⚠️  ADVERTENCIA: BORRAR WINDOWS  ⚠️⚠️⚠️"
    echo ""
    echo "Esto BORRARÁ completamente Windows y TODOS los datos en $TARGET_DISK"
    echo ""
    read -p "¿BORRAR TODO incluyendo Windows? (escribe 'BORRAR WINDOWS'): " conf
    
    if [ "$conf" != "BORRAR WINDOWS" ]; then
        echo "Operación cancelada"
        exit 1
    fi
    
    # Continue with automatic partitioning
    mode=1  # Treat as automatic format
    HAS_WINDOWS="no"  # Prevent re-checking
fi

# ============================================================================
# MODO AUTOMÁTICO (sin Windows)
# ============================================================================

if [ "$mode" = "1" ] && [ "$HAS_WINDOWS" = "no" ]; then
    echo ""
    read -p "¿BORRAR TODO en $TARGET_DISK? (escribe 'SI'): " conf
    [ "$conf" != "SI" ] && exit 1
    
    # Auto partition
    if [ "$FIRMWARE" = "UEFI" ]; then
        parted -s "$TARGET_DISK" mklabel gpt
        parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 513MiB
        parted -s "$TARGET_DISK" set 1 esp on
        parted -s "$TARGET_DISK" mkpart primary ext4 513MiB 100%
        
        [[ $TARGET_DISK == *"nvme"* ]] && EFI_PART="${TARGET_DISK}p1" || EFI_PART="${TARGET_DISK}1"
        [[ $TARGET_DISK == *"nvme"* ]] && ROOT_PART="${TARGET_DISK}p2" || ROOT_PART="${TARGET_DISK}2"
        
        sleep 2
        partprobe "$TARGET_DISK" 2>/dev/null || true
        sleep 1
        
        mkfs.fat -F32 "$EFI_PART"
        mkfs.ext4 -F "$ROOT_PART"
    else
        parted -s "$TARGET_DISK" mklabel msdos
        parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
        parted -s "$TARGET_DISK" set 1 boot on
        
        [[ $TARGET_DISK == *"nvme"* ]] && ROOT_PART="${TARGET_DISK}p1" || ROOT_PART="${TARGET_DISK}1"
        
        sleep 2
        partprobe "$TARGET_DISK" 2>/dev/null || true
        sleep 1
        
        mkfs.ext4 -F "$ROOT_PART"
    fi
    
    DUAL_BOOT_MODE="false"

# ============================================================================
# MODO MANUAL
# ============================================================================

elif [ "$mode" = "3" ]; then
    echo ""
    read -p "Usar cfdisk? (s=cfdisk, n=fdisk) [s]: " tool
    
    if [ "$HAS_WINDOWS" = "yes" ]; then
        echo ""
        echo "⚠️  CUIDADO: Windows está instalado en este disco"
        echo "No borres las particiones de Windows si quieres dual-boot"
        echo ""
        read -p "Presiona Enter para continuar..."
    fi
    
    [[ ${tool:-s} =~ ^[SsYy]$ ]] && cfdisk "$TARGET_DISK" || fdisk "$TARGET_DISK"
    
    echo ""
    lsblk "$TARGET_DISK"
    echo ""
    
    PARTS=($(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^$TARGET_DISK$"))
    
    if [ "$FIRMWARE" = "UEFI" ]; then
        echo "Particiones disponibles:"
        for i in "${!PARTS[@]}"; do
            echo "  $((i+1))) ${PARTS[$i]}"
        done
        read -p "¿Cuál es EFI? (número, 0=ninguna): " efi_n
        if [ "$efi_n" != "0" ]; then
            EFI_PART="${PARTS[$((efi_n-1))]}"
            read -p "¿Formatear $EFI_PART como FAT32? (s/n) [n]: " fmt
            [[ $fmt =~ ^[SsYy]$ ]] && mkfs.fat -F32 "$EFI_PART"
        fi
    fi
    
    echo "Particiones disponibles:"
    for i in "${!PARTS[@]}"; do
        echo "  $((i+1))) ${PARTS[$i]}"
    done
    read -p "¿Cuál es ROOT para Ubuntu? (número): " root_n
    ROOT_PART="${PARTS[$((root_n-1))]}"
    read -p "¿Formatear $ROOT_PART como ext4? (s/n) [s]: " fmt
    [[ ${fmt:-s} =~ ^[SsYy]$ ]] && mkfs.ext4 -F "$ROOT_PART"
    
    DUAL_BOOT_MODE="${HAS_WINDOWS}"
fi

# Save info
cat > "$(dirname "$0")/../partition.info" << EOF
export FIRMWARE="$FIRMWARE"
export DISK_TYPE="$DISK_TYPE"
export TARGET_DISK="$TARGET_DISK"
export ROOT_PART="$ROOT_PART"
export DUAL_BOOT_MODE="$DUAL_BOOT_MODE"
EOF

[ -n "$EFI_PART" ] && echo "export EFI_PART=\"$EFI_PART\"" >> "$(dirname "$0")/../partition.info"

echo ""
echo "✓✓✓ Particionamiento completado ✓✓✓"
echo ""
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$TARGET_DISK"

exit 0
