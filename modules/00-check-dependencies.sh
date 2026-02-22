#!/bin/bash
# Módulo 00: Verificar e instalar dependencias

# Cargar funciones de debug
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/debug-functions.sh" 2>/dev/null || {
    debug() { debug " $*"; }
    step() { step " $*"; }
    error() { echo "✗ $*"; }
    warn() { warn " $*"; }
}

echo "═══════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DE DEPENDENCIAS"
echo "═══════════════════════════════════════════════════════════"
echo ""

MISSING_DEPS=()

# Verificar dependencias necesarias
echo "Verificando herramientas necesarias..."
echo ""

check_tool() {
    local tool=$1
    local package=$2
    
    if command -v "$tool" &> /dev/null; then
        step " $tool instalado"
        return 0
    else
        echo "✗ $tool NO encontrado"
        MISSING_DEPS+=("$package")
        return 1
    fi
}

# Verificar cada herramienta
check_tool "parted" "parted"
check_tool "debootstrap" "debootstrap"
check_tool "arch-chroot" "arch-install-scripts"
check_tool "genfstab" "arch-install-scripts"

echo ""

# Instalar dependencias faltantes
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Instalando dependencias faltantes..."
    echo ""
    
    # Eliminar duplicados
    UNIQUE_DEPS=($(echo "${MISSING_DEPS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    
    echo "Paquetes a instalar: ${UNIQUE_DEPS[@]}"
    echo ""
    
    apt update
    apt install -y "${UNIQUE_DEPS[@]}"
    
    echo ""
    step " Dependencias instaladas"
else
    step " Todas las dependencias están instaladas"
fi

echo ""
echo "Verificación de dependencias completada"
echo ""

# Verificar ubuntu-keyring (necesario para debootstrap)
if ! dpkg -l | grep -q "^ii.*ubuntu-keyring"; then
    echo "Instalando ubuntu-keyring..."
    apt install -y ubuntu-keyring
    step " ubuntu-keyring instalado"
fi

echo ""
step "✓✓ Sistema listo para instalación ✓✓✓"

exit 0
