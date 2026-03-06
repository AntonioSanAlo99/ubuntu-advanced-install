#!/bin/bash
# Script para añadir debug functions a todos los módulos

MODULES_DIR="/home/claude/ubuntu-advanced-install/modules"

echo "Aplicando funciones de debug a todos los módulos..."
echo ""

for module in "$MODULES_DIR"/*.sh; do
    module_name=$(basename "$module")
    
    echo "Procesando: $module_name"
    
    # Verificar si ya tiene las funciones de debug
    if grep -q "source.*debug-functions.sh" "$module"; then
        echo "  ✓ Ya tiene debug functions"
        continue
    fi
    
    # Crear backup
    cp "$module" "$module.bak"
    
    # Añadir carga de funciones después del shebang y antes del primer comando significativo
    # Buscar la línea después de set -e o el primer echo
    
    # Leer el archivo
    content=$(<"$module")
    
    # Añadir después de set -e (si existe) o después del shebang
    if echo "$content" | grep -q "^set -e"; then
        # Insertar después de set -e
        sed -i '/^set -e/a\
\
# Cargar funciones de debug\
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\
source "$SCRIPT_DIR/../lib/debug-functions.sh" 2>/dev/null || {\
    debug() { echo "[DEBUG] $*"; }\
    step() { echo "✓ $*"; }\
    error() { echo "✗ $*"; }\
    warn() { echo "⚠ $*"; }\
}' "$module"
    else
        # Insertar después del shebang
        sed -i '2a\
\
# Cargar funciones de debug\
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\
source "$SCRIPT_DIR/../lib/debug-functions.sh" 2>/dev/null || {\
    debug() { echo "[DEBUG] $*"; }\
    step() { echo "✓ $*"; }\
    error() { echo "✗ $*"; }\
    warn() { echo "⚠ $*"; }\
}' "$module"
    fi
    
    # Reemplazar echo "✓ por step "
    sed -i 's/echo "✓/step "/g' "$module"
    sed -i "s/echo '✓/step '/g" "$module"
    
    # Reemplazar echo "❌ por error "
    sed -i 's/echo "❌/error "/g' "$module"
    sed -i "s/echo '❌/error '/g" "$module"
    
    # Reemplazar echo "⚠ por warn "
    sed -i 's/echo "⚠/warn "/g' "$module"
    sed -i "s/echo '⚠/warn '/g" "$module"
    
    # Reemplazar echo "[DEBUG] por debug "
    sed -i 's/echo "\[DEBUG\]/debug "/g' "$module"
    
    echo "  ✓ Debug añadido"
done

echo ""
echo "✓ Proceso completado"
echo ""
echo "Verificando sintaxis de módulos..."

error_count=0
for module in "$MODULES_DIR"/*.sh; do
    if ! bash -n "$module" 2>/dev/null; then
        echo "✗ Error en $(basename "$module")"
        ((error_count++))
        # Restaurar backup si hay error
        cp "$module.bak" "$module"
    else
        # Eliminar backup si está OK
        rm -f "$module.bak"
    fi
done

if [ $error_count -eq 0 ]; then
    echo "✓ Todos los módulos tienen sintaxis correcta"
else
    echo "✗ $error_count módulos con errores (restaurados desde backup)"
fi
