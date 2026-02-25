#!/bin/bash
# apply-improvements.sh
# Script para aplicar mejoras automáticamente a todos los módulos

MODULES_DIR="/home/claude/ubuntu-advanced-install/modules"

echo "════════════════════════════════════════════════════════════════"
echo "  APLICANDO MEJORAS A MÓDULOS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Añadir set -eo pipefail a todos los módulos que no lo tengan
echo "1. Añadiendo set -eo pipefail..."
for module in "$MODULES_DIR"/[0-9]*.sh; do
    if ! grep -q "set -eo pipefail" "$module"; then
        # Insertar después del shebang y comentario del módulo
        sed -i '/^source.*config.env/i set -eo pipefail  # Detectar errores en pipelines\n' "$module"
        echo "  ✓ $(basename $module)"
    fi
done

# 2. Añadir timeout a wget
echo ""
echo "2. Añadiendo timeouts a wget..."
find "$MODULES_DIR" -name "*.sh" -exec sed -i 's/wget -q /wget --timeout=30 --tries=3 -q /g' {} \;
find "$MODULES_DIR" -name "*.sh" -exec sed -i 's/wget -NP /wget --timeout=30 --tries=3 -NP /g' {} \;
echo "  ✓ Timeouts añadidos a wget"

# 3. Añadir timeout a curl
echo ""
echo "3. Añadiendo timeouts a curl..."
find "$MODULES_DIR" -name "*.sh" -exec sed -i 's/curl -s /curl --max-time 30 --retry 3 -s /g' {} \;
find "$MODULES_DIR" -name "*.sh" -exec sed -i 's/curl -fsSL /curl --max-time 30 --retry 3 -fsSL /g' {} \;
echo "  ✓ Timeouts añadidos a curl"

# 4. Reemplazar hardcoded values en gaming
echo ""
echo "4. Reemplazando valores hardcoded..."
if [ -f "$MODULES_DIR/16-configure-gaming.sh" ]; then
    # Añadir constantes al inicio
    if ! grep -q "GAMING_MAX_MAP_COUNT" "$MODULES_DIR/16-configure-gaming.sh"; then
        sed -i '/^source.*config.env/a \
# Constantes\
GAMING_MAX_MAP_COUNT=2147483642\
GAMING_FILE_MAX=524288' "$MODULES_DIR/16-configure-gaming.sh"
    fi
    
    # Reemplazar valores
    sed -i 's/vm.max_map_count=2147483642/vm.max_map_count=${GAMING_MAX_MAP_COUNT}/g' "$MODULES_DIR/16-configure-gaming.sh"
    sed -i 's/fs.file-max=524288/fs.file-max=${GAMING_FILE_MAX}/g' "$MODULES_DIR/16-configure-gaming.sh"
    echo "  ✓ Gaming constants"
fi

# 5. Reemplazar hardcoded values en disk
if [ -f "$MODULES_DIR/01-prepare-disk.sh" ]; then
    if ! grep -q "DEFAULT_UBUNTU_SIZE_GB" "$MODULES_DIR/01-prepare-disk.sh"; then
        sed -i '/^source.*config.env/a \
# Constantes\
DEFAULT_UBUNTU_SIZE_GB=100\
MIN_UBUNTU_SIZE_GB=50\
MAX_UBUNTU_SIZE_GB=500' "$MODULES_DIR/01-prepare-disk.sh"
    fi
    echo "  ✓ Disk constants"
fi

# 6. Reemplazar hardcoded values en laptop
if [ -f "$MODULES_DIR/21-laptop-advanced.sh" ]; then
    if ! grep -q "DEFAULT_UV_CPU" "$MODULES_DIR/21-laptop-advanced.sh"; then
        sed -i '/^source.*config.env/a \
# Constantes de Undervolt\
DEFAULT_UV_CPU=-80\
DEFAULT_UV_GPU=-60\
DEFAULT_UV_CACHE=-80\
DEFAULT_UV_SA=-40\
DEFAULT_UV_IO=-40\
MAX_SAFE_UV=-125' "$MODULES_DIR/21-laptop-advanced.sh"
    fi
    
    sed -i 's/UV_CPU=-80/UV_CPU=${DEFAULT_UV_CPU}/g' "$MODULES_DIR/21-laptop-advanced.sh"
    sed -i 's/UV_GPU=-60/UV_GPU=${DEFAULT_UV_GPU}/g' "$MODULES_DIR/21-laptop-advanced.sh"
    echo "  ✓ Laptop constants"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ MEJORAS APLICADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Cambios aplicados:"
echo "  ✓ set -eo pipefail en todos los módulos"
echo "  ✓ Timeouts (30s) en wget y curl"
echo "  ✓ Constantes en lugar de hardcoded values"
echo ""
echo "NOTA: Revisa los módulos modificados para verificar que todo"
echo "      funciona correctamente antes de ejecutar la instalación."
echo ""
