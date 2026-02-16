#!/bin/bash

##############################################################################
# Sistema avanzado de instalación Ubuntu modular
# Orquestador principal - Ejecuta módulos independientes
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

##############################################################################
# CARGAR CONFIGURACIÓN
##############################################################################

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${YELLOW}⚠ Archivo de configuración no encontrado${NC}"
    echo "Creando configuración por defecto..."
    cat > "$CONFIG_FILE" << 'EOF'
# Configuración de instalación Ubuntu

# === SISTEMA BASE ===
UBUNTU_VERSION="noble"
TARGET_DISK="/dev/vda"
TARGET="/mnt/ubuntu"
HOSTNAME="ubuntu-vm"
USERNAME="user"

# === HARDWARE ===
DISK_TYPE="auto"          # auto, nvme, ssd, hdd
IS_LAPTOP="true"          # true, false
HAS_WIFI="true"           # true, false
HAS_BLUETOOTH="true"      # true, false

# === OPTIMIZACIONES ===
ENABLE_PERFORMANCE="true"
ENABLE_SECURITY="true"
MINIMIZE_SYSTEMD="true"

# === COMPONENTES ===
INSTALL_GNOME="true"
INSTALL_MULTIMEDIA="true"
INSTALL_DEVELOPMENT="false"
INSTALL_GAMING="false"

# === OPCIONES AVANZADAS ===
USE_NO_INSTALL_RECOMMENDS="true"
DUAL_BOOT="false"
UBUNTU_SIZE_GB="50"
EOF
    echo -e "${GREEN}✓${NC} Configuración creada: $CONFIG_FILE"
    echo "Edita el archivo y ejecuta de nuevo el script"
    exit 0
fi

##############################################################################
# FUNCIONES AUXILIARES
##############################################################################

log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

run_module() {
    local module_name="$1"
    local module_path="$MODULES_DIR/$module_name.sh"
    
    if [ ! -f "$module_path" ]; then
        log_error "Módulo no encontrado: $module_name"
        return 1
    fi
    
    log_step "Ejecutando módulo: $module_name"
    bash "$module_path"
    
    if [ $? -eq 0 ]; then
        log_success "Módulo completado: $module_name"
    else
        log_error "Módulo falló: $module_name"
        return 1
    fi
}

##############################################################################
# MENÚ PRINCIPAL
##############################################################################

show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  SISTEMA DE INSTALACIÓN UBUNTU AVANZADO Y MODULAR         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Configuración actual:${NC}"
    echo "  • Ubuntu: $UBUNTU_VERSION"
    echo "  • Disco: $TARGET_DISK"
    echo "  • Hostname: $HOSTNAME"
    echo "  • Usuario: $USERNAME"
    echo "  • Laptop: $IS_LAPTOP"
    echo "  • Tipo disco: $DISK_TYPE"
    echo ""
    echo -e "${YELLOW}INSTALACIÓN COMPLETA:${NC}"
    echo "  1) Instalación automática completa"
    echo "  2) Instalación interactiva (paso a paso)"
    echo ""
    echo -e "${YELLOW}MÓDULOS INDIVIDUALES - BASE:${NC}"
    echo "  10) Preparar disco (particionar + formatear)"
    echo "  11) Instalar sistema base (debootstrap)"
    echo "  12) Configurar sistema base"
    echo "  13) Instalar kernel + GRUB"
    echo ""
    echo -e "${YELLOW}MÓDULOS INDIVIDUALES - COMPONENTES:${NC}"
    echo "  20) Instalar GNOME (por componentes)"
    echo "  21) Configurar NetworkManager"
    echo "  22) Instalar multimedia (códecs, thumbnailers)"
    echo "  23) Instalar fuentes"
    echo "  24) Configurar WiFi y Bluetooth"
    echo "  25) Instalar herramientas de desarrollo"
    echo "  26) Configurar periféricos gaming"
    echo ""
    echo -e "${YELLOW}MÓDULOS INDIVIDUALES - OPTIMIZACIÓN:${NC}"
    echo "  30) Optimizar rendimiento (CPU, I/O, memoria)"
    echo "  31) Optimizar para laptop (TLP, thermald)"
    echo "  32) Optimizar para NVMe + DDR4"
    echo "  33) Minimizar systemd"
    echo "  34) Hardening de seguridad"
    echo ""
    echo -e "${YELLOW}UTILIDADES:${NC}"
    echo "  40) Editar configuración"
    echo "  41) Verificar sistema instalado"
    echo "  42) Generar informe del sistema"
    echo "  43) Backup de configuración"
    echo ""
    echo "  0) Salir"
    echo ""
    read -p "Selecciona opción: " choice
    echo ""
    
    case $choice in
        1) full_automatic_install ;;
        2) full_interactive_install ;;
        
        10) run_module "01-prepare-disk" ;;
        11) run_module "02-debootstrap" ;;
        12) run_module "03-configure-base" ;;
        13) run_module "04-install-bootloader" ;;
        
        20) run_module "10-install-gnome" ;;
        21) run_module "11-configure-network" ;;
        22) run_module "12-install-multimedia" ;;
        23) run_module "13-install-fonts" ;;
        24) run_module "14-configure-wireless" ;;
        25) run_module "15-install-development" ;;
        26) run_module "16-configure-gaming" ;;
        
        30) run_module "20-optimize-performance" ;;
        31) run_module "21-optimize-laptop" ;;
        32) run_module "22-optimize-nvme-ddr4" ;;
        33) run_module "23-minimize-systemd" ;;
        34) run_module "24-security-hardening" ;;
        
        40) ${EDITOR:-nano} "$CONFIG_FILE" ;;
        41) run_module "30-verify-system" ;;
        42) run_module "31-generate-report" ;;
        43) run_module "32-backup-config" ;;
        
        0) exit 0 ;;
        *) 
            log_error "Opción inválida"
            sleep 2
            ;;
    esac
    
    read -p "Presiona Enter para continuar..."
}

##############################################################################
# INSTALACIÓN AUTOMÁTICA COMPLETA
##############################################################################

full_automatic_install() {
    check_root
    
    log_step "INSTALACIÓN AUTOMÁTICA COMPLETA"
    
    echo "Esta instalación ejecutará todos los módulos en orden."
    echo "Configuración:"
    echo "  • Sistema base: Ubuntu $UBUNTU_VERSION"
    echo "  • GNOME: $([ "$INSTALL_GNOME" = "true" ] && echo "SÍ" || echo "NO")"
    echo "  • Multimedia: $([ "$INSTALL_MULTIMEDIA" = "true" ] && echo "SÍ" || echo "NO")"
    echo "  • Desarrollo: $([ "$INSTALL_DEVELOPMENT" = "true" ] && echo "SÍ" || echo "NO")"
    echo "  • Gaming: $([ "$INSTALL_GAMING" = "true" ] && echo "SÍ" || echo "NO")"
    echo "  • Optimizaciones: $([ "$ENABLE_PERFORMANCE" = "true" ] && echo "SÍ" || echo "NO")"
    echo ""
    read -p "¿Continuar? (s/n): " confirm
    
    if [[ ! $confirm =~ ^[SsYy]$ ]]; then
        return
    fi
    
    # Fase 1: Sistema base
    run_module "01-prepare-disk" || exit 1
    run_module "02-debootstrap" || exit 1
    run_module "03-configure-base" || exit 1
    run_module "04-install-bootloader" || exit 1
    
    # Fase 2: Componentes
    [ "$INSTALL_GNOME" = "true" ] && run_module "10-install-gnome"
    run_module "11-configure-network" || exit 1
    [ "$INSTALL_MULTIMEDIA" = "true" ] && run_module "12-install-multimedia"
    run_module "13-install-fonts"
    [ "$HAS_WIFI" = "true" ] && run_module "14-configure-wireless"
    [ "$INSTALL_DEVELOPMENT" = "true" ] && run_module "15-install-development"
    [ "$INSTALL_GAMING" = "true" ] && run_module "16-configure-gaming"
    
    # Fase 3: Optimizaciones
    if [ "$ENABLE_PERFORMANCE" = "true" ]; then
        run_module "20-optimize-performance"
        [ "$IS_LAPTOP" = "true" ] && run_module "21-optimize-laptop"
        [ "$DISK_TYPE" = "nvme" ] && run_module "22-optimize-nvme-ddr4"
    fi
    
    [ "$MINIMIZE_SYSTEMD" = "true" ] && run_module "23-minimize-systemd"
    [ "$ENABLE_SECURITY" = "true" ] && run_module "24-security-hardening"
    
    log_success "¡Instalación completada!"
    run_module "31-generate-report"
}

##############################################################################
# INSTALACIÓN INTERACTIVA
##############################################################################

full_interactive_install() {
    check_root
    
    log_step "INSTALACIÓN INTERACTIVA"
    echo "Instalación paso a paso con confirmación"
    echo ""
    
    # Lista de módulos con descripciones
    declare -A modules
    modules=(
        ["01-prepare-disk"]="Preparar disco (particionar y formatear)"
        ["02-debootstrap"]="Instalar sistema base Ubuntu"
        ["03-configure-base"]="Configurar hostname, locale, usuarios"
        ["04-install-bootloader"]="Instalar kernel y GRUB"
        ["10-install-gnome"]="Instalar entorno GNOME"
        ["11-configure-network"]="Configurar NetworkManager"
        ["12-install-multimedia"]="Instalar códecs y multimedia"
        ["13-install-fonts"]="Instalar fuentes"
        ["14-configure-wireless"]="Configurar WiFi y Bluetooth"
        ["20-optimize-performance"]="Optimizar rendimiento general"
        ["21-optimize-laptop"]="Optimizar para laptop"
        ["23-minimize-systemd"]="Minimizar systemd"
        ["24-security-hardening"]="Hardening de seguridad"
    )
    
    for module in "01-prepare-disk" "02-debootstrap" "03-configure-base" \
                  "04-install-bootloader" "10-install-gnome" "11-configure-network" \
                  "12-install-multimedia" "13-install-fonts" "14-configure-wireless" \
                  "20-optimize-performance" "21-optimize-laptop" "23-minimize-systemd" \
                  "24-security-hardening"; do
        
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Siguiente módulo:${NC} ${modules[$module]}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "¿Ejecutar este módulo? (s/n/q=quit): " answer
        
        case $answer in
            [Qq]*)
                echo "Instalación cancelada por el usuario"
                return
                ;;
            [Ss]*)
                run_module "$module" || {
                    read -p "Módulo falló. ¿Continuar de todos modos? (s/n): " continue
                    [[ ! $continue =~ ^[SsYy]$ ]] && return
                }
                ;;
            *)
                log_warning "Módulo omitido: $module"
                ;;
        esac
    done
    
    log_success "¡Instalación interactiva completada!"
}

##############################################################################
# MAIN LOOP
##############################################################################

check_root

# Si se pasa un módulo como argumento, ejecutarlo directamente
if [ $# -gt 0 ]; then
    case "$1" in
        --auto)
            full_automatic_install
            ;;
        --interactive)
            full_interactive_install
            ;;
        --module)
            if [ -z "$2" ]; then
                log_error "Especifica el nombre del módulo"
                exit 1
            fi
            run_module "$2"
            ;;
        --list)
            echo "Módulos disponibles:"
            ls -1 "$MODULES_DIR" | sed 's/.sh$//'
            ;;
        --help)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --auto           Instalación automática completa"
            echo "  --interactive    Instalación interactiva paso a paso"
            echo "  --module NOMBRE  Ejecutar módulo específico"
            echo "  --list           Listar módulos disponibles"
            echo "  --help           Mostrar esta ayuda"
            echo ""
            echo "Sin opciones: Mostrar menú interactivo"
            ;;
        *)
            log_error "Opción desconocida: $1"
            exit 1
            ;;
    esac
else
    # Menú interactivo
    while true; do
        show_menu
    done
fi
