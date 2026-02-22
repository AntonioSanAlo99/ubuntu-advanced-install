#!/bin/bash
# Módulo TEST: Template de testeo de funciones

# ============================================================================
# INSTRUCCIONES DE USO
# ============================================================================
# Este es un módulo de TESTEO que no se ejecuta por defecto.
# Para habilitarlo:
#
# 1. En install.sh, descomenta la línea correspondiente en el menú
# 2. O ejecuta directamente: ./modules/TEST-nombre.sh
# 3. Los módulos TEST permiten probar funcionalidades sin hacer la instalación completa
#
# Características:
# - Selección individual de cada parámetro
# - Reversible (puede deshacerse)
# - No modifica la instalación principal
# - Muestra resultados detallados
# ============================================================================

source "$(dirname "$0")/../config.env" 2>/dev/null || {
    echo "⚠ config.env no encontrado, usando valores por defecto"
    TARGET="/mnt"

    log_error() { echo "ERROR: $2"; }
    log_success() { echo "✓ $2"; }
    show_error_summary() { :; }

MODULE_NAME="TEST-Template"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================================
# FUNCIONES DE TESTEO
# ============================================================================

test_function_1() {
    echo -e "${CYAN}═══ Test: Función 1 ═══${NC}"
    echo ""
    
    # Selección de parámetros
    read -p "Parámetro 1 (valor por defecto): " param1
    param1=${param1:-valor_defecto}
    
    read -p "Parámetro 2 (s/n) [n]: " param2
    param2=${param2:-n}
    
    echo ""
    echo "Ejecutando test con:"
    echo "  Parámetro 1: $param1"
    echo "  Parámetro 2: $param2"
    echo ""
    
    # Código de test aquí
    echo "Simulando operación..."
    sleep 1
    
    # Resultado
    log_success "$MODULE_NAME" "Test 1 completado"

test_function_2() {
    echo -e "${CYAN}═══ Test: Función 2 ═══${NC}"
    echo ""
    
    # Más parámetros
    read -p "Opción (1-3): " option
    
    case $option in
        1) echo "Ejecutando opción 1..." ;;
        2) echo "Ejecutando opción 2..." ;;
        3) echo "Ejecutando opción 3..." ;;
        *) echo "Opción inválida" ; return 1 ;;
    esac
    
    log_success "$MODULE_NAME" "Test 2 completado"

test_function_3() {
    echo -e "${CYAN}═══ Test: Función 3 ═══${NC}"
    echo ""
    
    # Test con confirmación
    echo "Esta función hará cambios en el sistema"
    read -p "¿Continuar? (s/n): " confirm
    
    if [ "$confirm" != "s" ]; then
        echo "Test cancelado"
        return 0
    fi
    
    # Operación
    echo "Ejecutando..."
    
    log_success "$MODULE_NAME" "Test 3 completado"

# ============================================================================
# MENÚ PRINCIPAL DE TESTS
# ============================================================================

show_test_menu() {
    clear
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}             MÓDULO DE TESTEO - ${MODULE_NAME}${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Este es un módulo de PRUEBAS. No afecta la instalación principal.${NC}"
    echo ""
    echo "Tests disponibles:"
    echo ""
    echo "  1) Test Función 1 - Descripción breve"
    echo "  2) Test Función 2 - Descripción breve"
    echo "  3) Test Función 3 - Descripción breve"
    echo ""
    echo "  a) Ejecutar todos los tests"
    echo "  r) Revertir cambios (si aplica)"
    echo "  q) Salir"
    echo ""
    read -p "Selecciona opción: " choice
    
    case $choice in
        1) test_function_1 ;;
        2) test_function_2 ;;
        3) test_function_3 ;;
        a|A)
            echo "Ejecutando todos los tests..."
            test_function_1
            test_function_2
            test_function_3
            ;;
        r|R)
            echo "Revirtiendo cambios..."
            # Código de reversión aquí
            ;;
        q|Q)
            echo "Saliendo del módulo de test"
            exit 0
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    echo ""
    read -p "Presiona Enter para continuar..."

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Si se ejecuta directamente (no desde install.sh)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    while true; do
        show_test_menu
    done
else
    # Si se ejecuta desde install.sh, ejecutar todos los tests automáticamente
    echo "Ejecutando módulo de test en modo automático..."
    test_function_1
    test_function_2
    test_function_3
    show_error_summary "$MODULE_NAME"
fi
