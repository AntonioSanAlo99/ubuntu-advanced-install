#!/bin/bash
# Módulo 00: Verificar e instalar dependencias

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
    local package=${2:-$1}  # Si no se proporciona paquete, usar el nombre del tool
    
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool instalado"
        return 0
    else
        echo "✗ $tool NO encontrado"
        MISSING_DEPS+=("$package")
        return 1
    fi
}

# Verificar cada herramienta
check_tool "parted"                              # paquete = parted (automático)
check_tool "debootstrap"                         # paquete = debootstrap (automático)
check_tool "arch-chroot" "arch-install-scripts"  # paquete diferente (especificado)
check_tool "genfstab" "arch-install-scripts"     # paquete diferente (especificado)

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
    echo "✓  Dependencias instaladas"
else
    echo "✓  Todas las dependencias están instaladas"
fi

echo ""
echo "Verificación de dependencias completada"
echo ""

# Verificar ubuntu-keyring (necesario para debootstrap)
if ! dpkg -l | grep -q "^ii.*ubuntu-keyring"; then
    echo "Instalando ubuntu-keyring..."
    apt install -y ubuntu-keyring
    echo "✓  ubuntu-keyring instalado"
fi

echo ""
echo "✓ ✓✓ Sistema listo para instalación ✓✓✓"

exit 0
