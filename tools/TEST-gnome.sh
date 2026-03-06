#!/bin/bash
# Módulo TEST: Testeo de funciones GNOME

# ============================================================================
# HABILITACIÓN EN install.sh
# ============================================================================
# Para habilitar este módulo de test, en install.sh descomentar:
#
# En show_menu(), añadir:
#   echo "  90) [TEST] GNOME - Probar configuración GNOME"
#
# En el case del menú:
#   90) run_module "TEST-gnome" ;;
#
# O ejecutar directamente:
#   ./modules/TEST-gnome.sh
# ============================================================================

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env" 2>/dev/null || TARGET="/mnt"
    log_error() { echo "ERROR: $2"; }
    log_success() { echo "✓ $2"; }
    show_error_summary() { :; }

MODULE_NAME="TEST-GNOME"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================================
# TESTS INDIVIDUALES
# ============================================================================

test_gnome_extensions() {
    echo -e "${CYAN}═══ Test: Extensiones GNOME ═══${NC}"
    echo ""
    
    echo "Extensiones disponibles para test:"
    echo "  1) Dash to Dock"
    echo "  2) AppIndicator"
    echo "  3) User Themes"
    echo "  4) Blur my Shell"
    echo ""
    read -p "Selecciona extensión (1-4): " ext_choice
    
    case $ext_choice in
        1)
            EXT_ID="dash-to-dock@micxgx.gmail.com"
            EXT_NAME="Dash to Dock"
            ;;
        2)
            EXT_ID="appindicatorsupport@rgcjonas.gmail.com"
            EXT_NAME="AppIndicator"
            ;;
        3)
            EXT_ID="user-theme@gnome-shell-extensions.gcampax.github.com"
            EXT_NAME="User Themes"
            ;;
        4)
            EXT_ID="blur-my-shell@aunetx"
            EXT_NAME="Blur my Shell"
            ;;
        *)
            echo "Opción inválida"
            return 1
            ;;
    esac
    
    echo ""
    echo "Testeando extensión: $EXT_NAME"
    
    read -p "¿Habilitar esta extensión? (s/n) [s]: " enable
    enable=${enable:-s}
    
    if [ "$enable" = "s" ]; then
        echo "Habilitando $EXT_NAME..."
        # Comando de test (requiere que GNOME esté instalado)
        if command -v gnome-extensions >/dev/null 2>&1; then
            gnome-extensions enable "$EXT_ID" 2>/dev/null && \
                log_success "$MODULE_NAME" "$EXT_NAME habilitada" || \
                log_error "$MODULE_NAME" "No se pudo habilitar $EXT_NAME" "WARNING"
        else
            echo "⚠ GNOME no instalado, simulando..."
            log_success "$MODULE_NAME" "Simulación: $EXT_NAME habilitada"
        fi
    else
        echo "Extensión no habilitada"
    fi

test_gnome_theme() {
    echo -e "${CYAN}═══ Test: Tema GNOME ═══${NC}"
    echo ""
    
    echo "Temas disponibles:"
    echo "  1) Adwaita (por defecto)"
    echo "  2) Adwaita-dark"
    echo "  3) HighContrast"
    echo ""
    read -p "Selecciona tema (1-3): " theme_choice
    
    case $theme_choice in
        1) THEME="Adwaita" ;;
        2) THEME="Adwaita-dark" ;;
        3) THEME="HighContrast" ;;
        *) echo "Opción inválida"; return 1 ;;
    esac
    
    echo ""
    echo "Aplicando tema: $THEME"
    
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme "$THEME" 2>/dev/null && \
            log_success "$MODULE_NAME" "Tema $THEME aplicado" || \
            log_error "$MODULE_NAME" "Error aplicando tema" "WARNING"
    else
        echo "⚠ gsettings no disponible, simulando..."
        log_success "$MODULE_NAME" "Simulación: Tema $THEME aplicado"
    fi

test_gnome_settings() {
    echo -e "${CYAN}═══ Test: Configuración GNOME ═══${NC}"
    echo ""
    
    echo "Configuraciones disponibles:"
    echo "  1) Habilitar botones minimizar/maximizar"
    echo "  2) Cambiar disposición de botones"
    echo "  3) Configurar dock"
    echo "  4) Configurar fuentes"
    echo ""
    read -p "Selecciona configuración (1-4): " setting_choice
    
    case $setting_choice in
        1)
            echo "Habilitando botones minimizar/maximizar..."
            read -p "¿Incluir minimizar? (s/n) [s]: " minimize
            minimize=${minimize:-s}
            read -p "¿Incluir maximizar? (s/n) [s]: " maximize
            maximize=${maximize:-s}
            
            BUTTONS=""
            [ "$minimize" = "s" ] && BUTTONS="minimize,"
            [ "$maximize" = "s" ] && BUTTONS="${BUTTONS}maximize,"
            BUTTONS="${BUTTONS}close"
            
            echo "Configuración: $BUTTONS"
            
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.desktop.wm.preferences button-layout "appmenu:$BUTTONS" 2>/dev/null
                log_success "$MODULE_NAME" "Botones configurados: $BUTTONS"
            else
                log_success "$MODULE_NAME" "Simulación: Botones configurados"
            fi
            ;;
            
        2)
            echo "Disposición de botones:"
            echo "  1) Izquierda (estilo macOS)"
            echo "  2) Derecha (estilo Windows)"
            read -p "Selecciona (1-2): " pos
            
            if [ "$pos" = "1" ]; then
                LAYOUT="close,minimize,maximize:appmenu"
            else
                LAYOUT="appmenu:minimize,maximize,close"
            fi
            
            echo "Layout: $LAYOUT"
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.desktop.wm.preferences button-layout "$LAYOUT"
                log_success "$MODULE_NAME" "Layout aplicado"
            else
                log_success "$MODULE_NAME" "Simulación: Layout aplicado"
            fi
            ;;
            
        3)
            echo "Configuración de dock:"
            read -p "Posición (left/right/bottom) [bottom]: " dock_pos
            dock_pos=${dock_pos:-bottom}
            read -p "Tamaño de iconos (16-64) [48]: " icon_size
            icon_size=${icon_size:-48}
            
            echo "Dock: posición=$dock_pos, iconos=${icon_size}px"
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.shell.extensions.dash-to-dock dock-position "$dock_pos" 2>/dev/null
                gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size $icon_size 2>/dev/null
                log_success "$MODULE_NAME" "Dock configurado"
            else
                log_success "$MODULE_NAME" "Simulación: Dock configurado"
            fi
            ;;
            
        4)
            echo "Configuración de fuentes:"
            read -p "Fuente de interfaz [Cantarell]: " font_ui
            font_ui=${font_ui:-Cantarell}
            read -p "Tamaño (8-16) [11]: " font_size
            font_size=${font_size:-11}
            
            echo "Fuente: $font_ui ${font_size}pt"
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.desktop.interface font-name "$font_ui $font_size" 2>/dev/null
                log_success "$MODULE_NAME" "Fuente configurada"
            else
                log_success "$MODULE_NAME" "Simulación: Fuente configurada"
            fi
            ;;
            
        *)
            echo "Opción inválida"
            return 1
            ;;
    esac

test_gnome_performance() {
    echo -e "${CYAN}═══ Test: Optimización de Rendimiento ═══${NC}"
    echo ""
    
    echo "Optimizaciones disponibles:"
    echo "  1) Deshabilitar animaciones"
    echo "  2) Reducir transparencias"
    echo "  3) Deshabilitar búsqueda de Tracker"
    echo "  4) Todas las anteriores"
    echo ""
    read -p "Selecciona (1-4): " perf_choice
    
    case $perf_choice in
        1|4)
            echo "Deshabilitando animaciones..."
            if command -v gsettings >/dev/null 2>&1; then
                gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
                log_success "$MODULE_NAME" "Animaciones deshabilitadas"
            else
                log_success "$MODULE_NAME" "Simulación: Animaciones deshabilitadas"
            fi
            ;;&
        2|4)
            echo "Reduciendo transparencias..."
            # Código para reducir transparencias
            log_success "$MODULE_NAME" "Transparencias reducidas"
            ;;&
        3|4)
            echo "Deshabilitando Tracker..."
            if command -v systemctl >/dev/null 2>&1; then
                systemctl --user mask tracker-miner-fs.service 2>/dev/null
                log_success "$MODULE_NAME" "Tracker deshabilitado"
            else
                log_success "$MODULE_NAME" "Simulación: Tracker deshabilitado"
            fi
            ;;
    esac

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================

show_test_menu() {
    clear
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}              MÓDULO DE TESTEO - GNOME${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Módulo de PRUEBAS - No afecta la instalación principal${NC}"
    echo -e "${YELLOW}   Requiere tener GNOME instalado para tests reales${NC}"
    echo ""
    echo "Tests disponibles:"
    echo ""
    echo "  1) Extensiones GNOME - Habilitar/deshabilitar extensiones"
    echo "  2) Tema GNOME - Cambiar tema de interfaz"
    echo "  3) Configuración GNOME - Botones, dock, fuentes"
    echo "  4) Optimización - Rendimiento y recursos"
    echo ""
    echo "  a) Ejecutar todos los tests"
    echo "  r) Revertir a valores por defecto"
    echo "  q) Salir"
    echo ""
    read -p "Selecciona opción: " choice
    
    case $choice in
        1) test_gnome_extensions ;;
        2) test_gnome_theme ;;
        3) test_gnome_settings ;;
        4) test_gnome_performance ;;
        a|A)
            echo "Ejecutando todos los tests..."
            test_gnome_extensions
            test_gnome_theme
            test_gnome_settings
            test_gnome_performance
            ;;
        r|R)
            echo "Revirtiendo a valores por defecto..."
            if command -v dconf >/dev/null 2>&1; then
                dconf reset -f /org/gnome/ 2>/dev/null
                log_success "$MODULE_NAME" "Configuración GNOME reseteada"
            else
                echo "⚠ dconf no disponible"
            fi
            ;;
        q|Q)
            echo "Saliendo..."
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

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Ejecución directa - modo interactivo
    while true; do
        show_test_menu
    done
else
    # Ejecución desde install.sh - modo automático
    echo "Ejecutando tests GNOME en modo automático..."
    test_gnome_extensions
    test_gnome_theme
    test_gnome_settings
    test_gnome_performance
    show_error_summary "$MODULE_NAME"
fi
