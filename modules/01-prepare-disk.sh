#!/bin/bash
# Módulo 01: Preparar disco (particionar y formatear)

source "$(dirname "$0")/../config.env"

echo "Preparando disco: $TARGET_DISK"
echo "Tipo de disco: $DISK_TYPE"
echo ""

# Detectar tipo de disco si es auto
if [ "$DISK_TYPE" = "auto" ]; then
    if [[ $TARGET_DISK == *"nvme"* ]]; then
        DISK_TYPE="nvme"
    else
        disk_name=$(basename $TARGET_DISK)
        if [ -f /sys/block/$disk_name/queue/rotational ]; then
            rotational=$(cat /sys/block/$disk_name/queue/rotational)
            [ "$rotational" -eq 0 ] && DISK_TYPE="ssd" || DISK_TYPE="hdd"
        fi
    fi
    echo "Tipo detectado: $DISK_TYPE"
fi

if [ "$DUAL_BOOT" = "true" ]; then
    echo "Modo dual-boot no implementado en este módulo"
    echo "Usar particionamiento manual"
    exit 1
fi

echo "⚠ ADVERTENCIA: Se borrará todo en $TARGET_DISK"
read -p "¿Continuar? (escribe 'BORRAR'): " confirm
[ "$confirm" != "BORRAR" ] && exit 1

# Particionar (BIOS legacy - tabla DOS)
echo "Creando tabla de particiones DOS..."
parted -s "$TARGET_DISK" mklabel msdos
parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
parted -s "$TARGET_DISK" set 1 boot on

# Determinar nombre de partición
if [[ $TARGET_DISK == *"nvme"* ]]; then
    PART="${TARGET_DISK}p1"
else
    PART="${TARGET_DISK}1"
fi

# Formatear
echo "Formateando $PART..."
mkfs.ext4 -F "$PART"

# Guardar información de partición para otros módulos
echo "export ROOT_PART=\"$PART\"" > "$(dirname "$0")/../partition.info"
echo "export DISK_TYPE=\"$DISK_TYPE\"" >> "$(dirname "$0")/../partition.info"

echo "✓ Disco preparado: $PART"
