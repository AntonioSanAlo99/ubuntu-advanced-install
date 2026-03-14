#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 02: Instalar sistema base con debootstrap y montar filesystems
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE SISTEMA BASE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Ubuntu   : $UBUNTU_VERSION"
echo "  Firmware : $FIRMWARE"
echo "  Target   : $TARGET"
echo ""

# ============================================================================
# MONTAJE DE FILESYSTEMS
# ============================================================================

echo "Montando filesystems..."

# Root
mkdir -p "$TARGET"
mount -o noatime,errors=remount-ro "$ROOT_PART" "$TARGET"
echo "  ✓  Root  : $ROOT_PART → $TARGET"

# EFI (UEFI)
if [ "$FIRMWARE" = "UEFI" ] && [ -n "$EFI_PART" ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "$EFI_PART" "$TARGET/boot/efi"
    echo "  ✓  EFI   : $EFI_PART → $TARGET/boot/efi"
fi


echo ""

# ============================================================================
# DEBOOTSTRAP
# ============================================================================

echo "Instalando sistema base (debootstrap)..."
echo "  Componentes: main, restricted, universe, multiverse"
echo "  Esto puede tardar varios minutos..."
echo ""

debootstrap \
    --arch=amd64 \
    --components=main,restricted,universe,multiverse \
    "$UBUNTU_VERSION" \
    "$TARGET" \
    http://archive.ubuntu.com/ubuntu/

echo ""
echo "  ✓  Sistema base instalado"

# ============================================================================
# REPOSITORIOS APT (formato DEB822)
# ============================================================================

echo ""
echo "Configurando repositorios APT..."

mkdir -p "$TARGET/etc/apt/sources.list.d"

# sources.list legacy vacío (APT 3.0 usa DEB822)
cat > "$TARGET/etc/apt/sources.list" << EOF
# Este archivo ya no se usa (formato legacy)
# Los repositorios están en /etc/apt/sources.list.d/ubuntu.sources
# Formato DEB822 (APT 3.0+) — Ubuntu $UBUNTU_VERSION
EOF

cat > "$TARGET/etc/apt/sources.list.d/ubuntu.sources" << EOF
# Ubuntu $UBUNTU_VERSION — Repositorios oficiales
# Formato DEB822 (APT 3.0+)

Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: $UBUNTU_VERSION ${UBUNTU_VERSION}-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${UBUNTU_VERSION}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

echo "  ✓  Repositorios configurados"

# ============================================================================
# APT: NO INSTALAR RECOMMENDS POR DEFECTO
# ============================================================================
# Configuración global de apt para todo el sistema instalado.
# Equivale a pasar --no-install-recommends en cada apt install.
# Todos los módulos del instalador dependen de esta configuración.
# Si un módulo necesita recommends para un paquete concreto, debe usar
# explícitamente --install-recommends en esa línea.
# ============================================================================

mkdir -p "$TARGET/etc/apt/apt.conf.d"
cat > "$TARGET/etc/apt/apt.conf.d/90norecommends" << 'APTEOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APTEOF

echo "  ✓  apt: Install-Recommends=false (global)"

# ============================================================================
# FSTAB
# ============================================================================
# Se genera con UUIDs (no nombres de dispositivo) para que sea inmune a
# reordenamientos de discos — comportamiento idéntico a Calamares y al
# instalador de Ubuntu/Debian.
# Opciones por partición:
#   root  → noatime (reduce escrituras, mejora rendimiento SSD/NVMe)
#   EFI   → umask=0077 (solo root puede leer — seguridad estándar)
#   swap  → sw (opción estándar de swap)
# ============================================================================

echo ""
echo "Generando /etc/fstab con UUIDs..."

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=""

[ "$FIRMWARE" = "UEFI" ] && [ -n "$EFI_PART" ] && EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
# Swap: se usará swapfile creado en 11-configure-storage.sh

cat > "$TARGET/etc/fstab" << EOF
# /etc/fstab — generado por ubuntu-advanced-install
# <filesystem>                         <mount>     <type>  <options>                    <dump> <pass>

# Root filesystem
UUID=$ROOT_UUID    /           ext4    noatime,errors=remount-ro    0      1
EOF

if [ -n "$EFI_UUID" ]; then
    cat >> "$TARGET/etc/fstab" << EOF

# EFI System Partition
UUID=$EFI_UUID    /boot/efi   vfat    umask=0077                   0      2
EOF
fi


echo ""
echo "  Contenido de /etc/fstab:"
cat "$TARGET/etc/fstab" | sed 's/^/    /'

# ============================================================================
# VALIDACIÓN
# ============================================================================

echo ""
echo "Verificando instalación base..."

[ -f "$TARGET/bin/bash" ]       && echo "  ✓  /bin/bash" \
                                 || { echo "  ✗  /bin/bash ausente"; exit 1; }
[ -f "$TARGET/etc/fstab" ]      && echo "  ✓  /etc/fstab" \
                                 || { echo "  ✗  /etc/fstab ausente"; exit 1; }
[ -n "$ROOT_UUID" ]             && echo "  ✓  UUID root: $ROOT_UUID" \
                                 || { echo "  ✗  No se pudo obtener UUID de root"; exit 1; }

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  SISTEMA BASE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
