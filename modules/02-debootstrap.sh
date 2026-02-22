#!/bin/bash
# Módulo 02: Instalar sistema base con debootstrap

set -e  # Exit on error  # Detectar errores en pipelines


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "Instalando Ubuntu $UBUNTU_VERSION con debootstrap..."
echo "Firmware: $FIRMWARE"
echo ""

# Verificar dependencias
MISSING=()

if ! command -v debootstrap &> /dev/null; then
    warn " debootstrap no encontrado"
    MISSING+=("debootstrap")
fi

if ! command -v genfstab &> /dev/null; then
    warn " genfstab (arch-install-scripts) no encontrado"
    MISSING+=("arch-install-scripts")
fi

if ! dpkg -l | grep -q "^ii.*ubuntu-keyring"; then
    warn " ubuntu-keyring no encontrado"
    MISSING+=("ubuntu-keyring")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "Instalando dependencias faltantes: ${MISSING[@]}"
    apt update
    apt install -y "${MISSING[@]}"
    step " Dependencias instaladas"
    echo ""
fi

# Montar partición root
mkdir -p "$TARGET"
mount "$ROOT_PART" "$TARGET"
step " Root montado en $TARGET"

# Si es UEFI, montar también EFI
if [ "$FIRMWARE" = "UEFI" ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "$EFI_PART" "$TARGET/boot/efi"
    step " EFI montado en $TARGET/boot/efi"
fi

# Ejecutar debootstrap CON COMPONENTES
echo "Descargando e instalando sistema base..."
echo "Componentes: main, restricted, universe, multiverse"
echo "Esto puede tardar varios minutos..."

# Usar --components para incluir todos los repositorios desde el inicio
debootstrap --arch=amd64 --components=main,restricted,universe,multiverse \
    "$UBUNTU_VERSION" "$TARGET" http://archive.ubuntu.com/ubuntu/

step " Sistema base instalado con todos los componentes"

# Configurar repositorios completos
echo "Configurando repositorios en formato DEB822 (APT 3.0)..."

# Crear directorio para sources si no existe
mkdir -p "$TARGET/etc/apt/sources.list.d"

# Vaciar sources.list legacy (mantener para compatibilidad)
cat > "$TARGET/etc/apt/sources.list" << EOF
# Este archivo ya no se usa (legacy format)
# Los repositorios están configurados en /etc/apt/sources.list.d/*.sources
# Formato DEB822 (APT 3.0+) - Ubuntu $UBUNTU_VERSION
EOF

# Crear repositorios Ubuntu en formato DEB822
cat > "$TARGET/etc/apt/sources.list.d/ubuntu.sources" << EOF
# Ubuntu $UBUNTU_VERSION - Repositorios oficiales
# Formato DEB822 (APT 3.0+)
# Generado automáticamente

## Main repository (archive + updates)
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: $UBUNTU_VERSION ${UBUNTU_VERSION}-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

## Security repository
Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${UBUNTU_VERSION}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

## Backports (descomentado - software más reciente)
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: ${UBUNTU_VERSION}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
Enabled: yes

## Proposed (comentado - solo para testing/desarrollo)
# Types: deb
# URIs: http://archive.ubuntu.com/ubuntu/
# Suites: ${UBUNTU_VERSION}-proposed
# Components: main restricted universe multiverse
# Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
# Enabled: no
EOF

step " Repositorios configurados en formato DEB822:"
echo "  • main: Software libre oficial"
echo "  • restricted: Drivers propietarios (NVIDIA, etc)"
echo "  • universe: Software mantenido por comunidad"
echo "  • multiverse: Software con restricciones de copyright"
echo "  • Archivo: /etc/apt/sources.list.d/ubuntu.sources"

# Los locales se configurarán correctamente en el módulo 03 con es_ES.UTF-8
# No configuramos C.UTF-8 temporal

# Generar fstab
echo "Generando fstab..."
genfstab -U "$TARGET" > "$TARGET/etc/fstab"

echo ""
step "✓✓ Sistema base instalado en $TARGET ✓✓✓"
echo ""
echo "Contenido de ubuntu.sources:"
cat "$TARGET/etc/apt/sources.list.d/ubuntu.sources"
echo ""
echo "Contenido de fstab:"
cat "$TARGET/etc/fstab"

exit 0
