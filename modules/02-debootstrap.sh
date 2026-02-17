#!/bin/bash
# Módulo 02: Instalar sistema base con debootstrap

source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando Ubuntu $UBUNTU_VERSION con debootstrap..."
echo "Firmware: $FIRMWARE"
echo ""

# Verificar dependencias
MISSING=()

if ! command -v debootstrap &> /dev/null; then
    echo "⚠ debootstrap no encontrado"
    MISSING+=("debootstrap")
fi

if ! command -v genfstab &> /dev/null; then
    echo "⚠ genfstab (arch-install-scripts) no encontrado"
    MISSING+=("arch-install-scripts")
fi

if ! dpkg -l | grep -q "^ii.*ubuntu-keyring"; then
    echo "⚠ ubuntu-keyring no encontrado"
    MISSING+=("ubuntu-keyring")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Instalando dependencias faltantes: ${MISSING[@]}"
    apt update
    apt install -y "${MISSING[@]}"
    echo "✓ Dependencias instaladas"
    echo ""
fi

# Montar partición root
mkdir -p "$TARGET"
mount "$ROOT_PART" "$TARGET"
echo "✓ Root montado en $TARGET"

# Si es UEFI, montar también EFI
if [ "$FIRMWARE" = "UEFI" ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "$EFI_PART" "$TARGET/boot/efi"
    echo "✓ EFI montado en $TARGET/boot/efi"
fi

# Ejecutar debootstrap CON COMPONENTES
echo "Descargando e instalando sistema base..."
echo "Componentes: main, restricted, universe, multiverse"
echo "Esto puede tardar varios minutos..."

# Usar --components para incluir todos los repositorios desde el inicio
debootstrap --arch=amd64 --components=main,restricted,universe,multiverse \
    "$UBUNTU_VERSION" "$TARGET" http://archive.ubuntu.com/ubuntu/

echo "✓ Sistema base instalado con todos los componentes"

# Configurar sources.list completo
echo "Configurando repositorios completos..."
cat > "$TARGET/etc/apt/sources.list" << EOF
# Ubuntu $UBUNTU_VERSION - Repositorios completos
# Generado automáticamente

# Main - Software libre soportado oficialmente
deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_VERSION main restricted universe multiverse

# Updates - Actualizaciones de seguridad y bugfixes
deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_VERSION-updates main restricted universe multiverse

# Security - Actualizaciones de seguridad críticas
deb http://security.ubuntu.com/ubuntu/ $UBUNTU_VERSION-security main restricted universe multiverse

# Backports - Software más reciente (opcional, comentado por defecto)
# deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_VERSION-backports main restricted universe multiverse

# Proposed - Actualizaciones en testing (comentado, solo para desarrollo)
# deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_VERSION-proposed main restricted universe multiverse
EOF

echo "✓ Repositorios configurados:"
echo "  • main: Software libre oficial"
echo "  • restricted: Drivers propietarios (NVIDIA, etc)"
echo "  • universe: Software mantenido por comunidad"
echo "  • multiverse: Software con restricciones de copyright"

# Generar fstab
echo "Generando fstab..."
genfstab -U "$TARGET" > "$TARGET/etc/fstab"

echo ""
echo "✓✓✓ Sistema base instalado en $TARGET ✓✓✓"
echo ""
echo "Contenido de sources.list:"
cat "$TARGET/etc/apt/sources.list"
echo ""
echo "Contenido de fstab:"
cat "$TARGET/etc/fstab"
