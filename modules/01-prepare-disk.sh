#!/bin/bash
# Módulo 01: Preparar disco - SIMPLE Y DIRECTO

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  PREPARACIÓN DE DISCO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Detectar firmware
if [ -d /sys/firmware/efi ]; then
    FIRMWARE="UEFI"
else
    FIRMWARE="BIOS"
fi
echo "Firmware: $FIRMWARE"
echo ""

# Listar discos
echo "Discos disponibles:"
echo ""
DISKS=($(lsblk -d -n -p -o NAME,TYPE | grep disk | awk '{print $1}'))

if [ ${#DISKS[@]} -eq 0 ]; then
    echo "✗ No se encontraron discos"
    exit 1
fi

# Mostrar discos
for i in "${!DISKS[@]}"; do
    disk="${DISKS[$i]}"
    size=$(lsblk -d -n -o SIZE "$disk")
    
    # Detectar qué hay
    has_ntfs=$(lsblk -n -o FSTYPE "$disk" | grep -q ntfs && echo "NTFS" || echo "")
    has_ext4=$(lsblk -n -o FSTYPE "$disk" | grep -q ext4 && echo "ext4" || echo "")
    has_vfat=$(lsblk -n -o FSTYPE "$disk" | grep -q vfat && echo "EFI" || echo "")
    
    info=""
    [ -n "$has_ntfs" ] && info="$info Windows?"
    [ -n "$has_ext4" ] && info="$info Linux?"
    [ -n "$has_vfat" ] && [ -z "$has_ntfs" ] && [ -z "$has_ext4" ] && info="$info EFI"
    
    echo "  $((i+1))) $disk - $size $info"
done

echo ""
read -p "Selecciona disco [1]: " choice
choice=${choice:-1}

TARGET_DISK="${DISKS[$((choice-1))]}"
echo ""
echo "Disco seleccionado: $TARGET_DISK"
echo ""

# Mostrar particiones actuales
echo "Particiones actuales:"
lsblk "$TARGET_DISK"
echo ""

# Detectar qué hay instalado
HAS_WINDOWS=$(lsblk -n -o FSTYPE "$TARGET_DISK" | grep -q ntfs && echo "yes" || echo "no")
HAS_LINUX=$(lsblk -n -o FSTYPE "$TARGET_DISK" | grep -q ext4 && echo "yes" || echo "no")

# Opciones según qué hay
echo "¿Qué quieres hacer?"
echo ""

if [ "$HAS_WINDOWS" = "yes" ] || [ "$HAS_LINUX" = "yes" ]; then
    # Hay sistema operativo
    echo "  1) Instalación limpia (BORRA TODO en $TARGET_DISK)"
    echo "  2) Dual-boot (mantener sistema actual, añadir Ubuntu)"
    echo "  3) Cancelar"
    echo ""
    read -p "Opción [2]: " install_mode
    install_mode=${install_mode:-2}
else
    # Disco vacío
    echo "  1) Instalación limpia (usar todo el disco)"
    echo "  2) Cancelar"
    echo ""
    read -p "Opción [1]: " install_mode
    install_mode=${install_mode:-1}
fi

case $install_mode in
    1)
        # Instalación limpia - BORRA TODO
        echo ""
        echo "⚠️  ADVERTENCIA: Esto BORRARÁ TODO en $TARGET_DISK"
        read -p "Escribir 'BORRAR' para confirmar: " confirm
        
        if [ "$confirm" != "BORRAR" ]; then
            echo "Cancelado"
            exit 1
        fi
        
        echo ""
        echo "Creando particiones nuevas..."
        
        # Limpiar disco
        wipefs -a "$TARGET_DISK"
        
        # Crear tabla de particiones
        if [ "$FIRMWARE" = "UEFI" ]; then
            # GPT para UEFI
            parted -s "$TARGET_DISK" mklabel gpt
            parted -s "$TARGET_DISK" mkpart primary fat32 1MiB 513MiB
            parted -s "$TARGET_DISK" set 1 esp on
            parted -s "$TARGET_DISK" mkpart primary ext4 513MiB 100%
            
            # Detectar particiones
            sleep 1
            partprobe "$TARGET_DISK"
            sleep 1
            
            if [[ "$TARGET_DISK" == *nvme* ]] || [[ "$TARGET_DISK" == *mmcblk* ]]; then
                EFI_PART="${TARGET_DISK}p1"
                ROOT_PART="${TARGET_DISK}p2"
            else
                EFI_PART="${TARGET_DISK}1"
                ROOT_PART="${TARGET_DISK}2"
            fi
            
            # Formatear
            mkfs.fat -F 32 "$EFI_PART"
            mkfs.ext4 -F "$ROOT_PART"
            
        else
            # MBR para BIOS
            parted -s "$TARGET_DISK" mklabel msdos
            parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
            parted -s "$TARGET_DISK" set 1 boot on
            
            sleep 1
            partprobe "$TARGET_DISK"
            sleep 1
            
            if [[ "$TARGET_DISK" == *nvme* ]] || [[ "$TARGET_DISK" == *mmcblk* ]]; then
                ROOT_PART="${TARGET_DISK}p1"
            else
                ROOT_PART="${TARGET_DISK}1"
            fi
            
            mkfs.ext4 -F "$ROOT_PART"
            EFI_PART=""
        fi
        
        DUAL_BOOT_MODE="false"
        echo "✓ Particiones creadas"
        ;;
        
    2)
        # Dual-boot - usar espacio inteligentemente (80% para Ubuntu, 20% libre para sistema existente)
        echo ""
        echo "Configurando dual-boot..."
        echo ""
        
        # Analizar disco
        TOTAL_SIZE=$(lsblk -b -d -n -o SIZE "$TARGET_DISK")
        TOTAL_GB=$((TOTAL_SIZE / 1024 / 1024 / 1024))
        
        # Calcular espacio usado por particiones existentes
        USED_SIZE=0
        while IFS= read -r part; do
            [ -z "$part" ] && continue
            part_size=$(lsblk -b -n -o SIZE "$part" 2>/dev/null || echo 0)
            USED_SIZE=$((USED_SIZE + part_size))
        done < <(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^$TARGET_DISK$")
        
        USED_GB=$((USED_SIZE / 1024 / 1024 / 1024))
        FREE_GB=$((TOTAL_GB - USED_GB))
        
        echo "Análisis del disco:"
        echo "  Total: ${TOTAL_GB}GB"
        echo "  Usado por sistema existente: ${USED_GB}GB"
        echo "  Libre disponible: ${FREE_GB}GB"
        echo ""
        
        # Verificar espacio mínimo
        if [ $FREE_GB -lt 30 ]; then
            echo "✗ No hay suficiente espacio libre (mínimo 30GB)"
            echo "  Libera espacio en tu sistema actual primero"
            exit 1
        fi
        
        # Calcular 80/20: Ubuntu usa 80% del espacio libre, deja 20% libre
        UBUNTU_SIZE=$(( (FREE_GB * 80) / 100 ))
        REMAINING=$(( FREE_GB - UBUNTU_SIZE ))
        
        # Asegurar mínimos razonables
        [ $UBUNTU_SIZE -lt 30 ] && UBUNTU_SIZE=30
        [ $REMAINING -lt 10 ] && UBUNTU_SIZE=$((FREE_GB - 10))
        
        echo "Distribución óptima (80% para Ubuntu, 20% libre):"
        echo "  Ubuntu: ${UBUNTU_SIZE}GB"
        echo "  Libre para sistema existente: ${REMAINING}GB"
        echo ""
        read -p "¿Cuántos GB para Ubuntu? [$UBUNTU_SIZE]: " ubuntu_size
        ubuntu_size=${ubuntu_size:-$UBUNTU_SIZE}
        
        # Validar
        if [ $ubuntu_size -lt 25 ]; then
            echo "✗ Mínimo 25GB para Ubuntu"
            exit 1
        fi
        
        if [ $ubuntu_size -gt $((FREE_GB - 5)) ]; then
            echo "✗ Debes dejar al menos 5GB libres para el sistema existente"
            exit 1
        fi
        
        FINAL_FREE=$((FREE_GB - ubuntu_size))
        echo ""
        echo "Configuración final:"
        echo "  Ubuntu: ${ubuntu_size}GB ($(( (ubuntu_size * 100) / FREE_GB ))% del espacio libre)"
        echo "  Libre para sistema existente: ${FINAL_FREE}GB ($(( (FINAL_FREE * 100) / FREE_GB ))% del espacio libre)"
        echo ""
        read -p "¿Continuar? [s/n]: " confirm
        [ "$confirm" != "s" ] && exit 1
        
        # Encontrar partición EFI si existe (para UEFI)
        if [ "$FIRMWARE" = "UEFI" ]; then
            EFI_PART=$(lsblk -n -p -o NAME,FSTYPE "$TARGET_DISK" | grep vfat | head -1 | awk '{print $1}')
            
            if [ -z "$EFI_PART" ]; then
                echo "✗ No se encontró partición EFI"
                exit 1
            fi
            echo "Usando EFI existente: $EFI_PART"
        else
            EFI_PART=""
        fi
        
        # Crear nueva partición para Ubuntu AL FINAL del disco
        echo ""
        echo "Creando partición de ${ubuntu_size}GB para Ubuntu..."
        parted -s "$TARGET_DISK" mkpart primary ext4 -- "-${ubuntu_size}GB" "100%"
        
        sleep 1
        partprobe "$TARGET_DISK"
        sleep 1
        
        # Encontrar la nueva partición (la última)
        ROOT_PART=$(lsblk -n -p -o NAME "$TARGET_DISK" | grep -v "^$TARGET_DISK$" | tail -1)
        
        # Formatear
        mkfs.ext4 -F "$ROOT_PART"
        
        DUAL_BOOT_MODE="true"
        echo "✓ Partición de Ubuntu creada: $ROOT_PART (${ubuntu_size}GB)"
        ;;
        
    *)
        echo "Cancelado"
        exit 1
        ;;
esac

echo ""
echo "Particionado completado:"
lsblk "$TARGET_DISK"
echo ""

# Exportar variables para otros módulos
export TARGET_DISK
export ROOT_PART
export EFI_PART
export FIRMWARE
export DUAL_BOOT_MODE
export TARGET

# Guardar en archivo para que otros módulos puedan leerlo
cat > "$(dirname "$0")/../partition.info" << EOF
TARGET_DISK="$TARGET_DISK"
ROOT_PART="$ROOT_PART"
EFI_PART="$EFI_PART"
FIRMWARE="$FIRMWARE"
DUAL_BOOT_MODE="$DUAL_BOOT_MODE"
TARGET="${TARGET:-/mnt/ubuntu}"
EOF

echo "✓ Disco preparado para instalación"
