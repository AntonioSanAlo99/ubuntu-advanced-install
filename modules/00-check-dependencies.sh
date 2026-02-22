#!/bin/bash
# Módulo 00: Verificar e instalar dependencias

echo "═══════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DE DEPENDENCIAS"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "Verificando herramientas necesarias..."
echo ""

# Lista de paquetes a instalar
# Nota: No verificamos paquetes base como util-linux (lsblk), coreutils, mount, etc.
#       ya que están presentes en cualquier LiveCD/sistema Linux
REQUIRED_PACKAGES=()

# Verificar parted (herramienta de particionado)
if ! command -v parted &> /dev/null; then
    echo "⚠  parted no encontrado"
    REQUIRED_PACKAGES+=("parted")
else
    echo "✓  parted instalado"
fi

# Verificar debootstrap (instalador de sistema base Debian/Ubuntu)
if ! command -v debootstrap &> /dev/null; then
    echo "⚠  debootstrap no encontrado"
    REQUIRED_PACKAGES+=("debootstrap")
else
    echo "✓  debootstrap instalado"
fi

# Verificar arch-install-scripts (arch-chroot y genfstab)
if ! command -v arch-chroot &> /dev/null || ! command -v genfstab &> /dev/null; then
    echo "⚠  arch-install-scripts no encontrado"
    REQUIRED_PACKAGES+=("arch-install-scripts")
else
    echo "✓  arch-install-scripts instalado"
fi

# Verificar ubuntu-keyring (claves GPG para repositorios Ubuntu)
if ! dpkg -l | grep -q "^ii.*ubuntu-keyring"; then
    echo "⚠  ubuntu-keyring no encontrado"
    REQUIRED_PACKAGES+=("ubuntu-keyring")
else
    echo "✓  ubuntu-keyring instalado"
fi

echo ""

# Instalar paquetes faltantes
if [ ${#REQUIRED_PACKAGES[@]} -gt 0 ]; then
    echo "Instalando dependencias faltantes: ${REQUIRED_PACKAGES[@]}"
    echo ""
    apt update
    apt install -y "${REQUIRED_PACKAGES[@]}"
    echo ""
    echo "✓  Dependencias instaladas"
else
    echo "✓  Todas las dependencias están instaladas"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✓  Sistema listo para instalación"
echo "═══════════════════════════════════════════════════════════"
