#!/bin/bash
# Script para verificar el orden de módulos en la instalación

echo "════════════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN DE MÓDULOS DE INSTALACIÓN"
echo "════════════════════════════════════════════════════════════════"
echo ""

MODULES_DIR="./modules"

echo "Módulos base (ejecutados siempre en este orden):"
echo ""

modules=(
    "00-check-dependencies"
    "01-prepare-disk"
    "02-debootstrap"
    "03-configure-base"
    "04-install-bootloader"
    "05-configure-network"
    "06-configure-auto-updates"
)

for i in "${!modules[@]}"; do
    module="${modules[$i]}"
    num=$((i + 1))
    module_path="$MODULES_DIR/$module.sh"
    
    if [ -f "$module_path" ]; then
        size=$(stat -f%z "$module_path" 2>/dev/null || stat -c%s "$module_path" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "  $num. ✓ $module (${size_kb}KB)"
    else
        echo "  $num. ✗ $module - NO ENCONTRADO"
    fi
done

echo ""
echo "Módulos opcionales (GNOME):"
echo ""

optional_gnome=(
    "10-install-gnome-core"
    "10-optimize"
    "10-theme"
    "10-user-config"
)

for module in "${optional_gnome[@]}"; do
    module_path="$MODULES_DIR/$module.sh"
    
    if [ -f "$module_path" ]; then
        size=$(stat -f%z "$module_path" 2>/dev/null || stat -c%s "$module_path" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "  ✓ $module (${size_kb}KB)"
    else
        echo "  ✗ $module - NO ENCONTRADO"
    fi
done

echo ""
echo "Módulos opcionales (otros):"
echo ""

optional_others=(
    "12-install-multimedia"
    "13-install-fonts"
    "14-configure-wireless"
    "15-install-development"
    "16-configure-gaming"
    "21-optimize-laptop"
    "23-minimize-systemd"
    "24-security-hardening"
    "31-generate-report"
)

for module in "${optional_others[@]}"; do
    module_path="$MODULES_DIR/$module.sh"
    
    if [ -f "$module_path" ]; then
        size=$(stat -f%z "$module_path" 2>/dev/null || stat -c%s "$module_path" 2>/dev/null)
        size_kb=$((size / 1024))
        echo "  ✓ $module (${size_kb}KB)"
    else
        echo "  ✗ $module - NO ENCONTRADO"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Verificar que 06-configure-auto-updates está en install.sh
echo "Verificando llamada en install.sh:"
if grep -q "06-configure-auto-updates" install.sh; then
    line=$(grep -n "06-configure-auto-updates" install.sh | cut -d: -f1)
    echo "  ✓ Módulo 06-configure-auto-updates llamado (línea $line)"
else
    echo "  ✗ Módulo 06-configure-auto-updates NO llamado en install.sh"
fi

echo ""
