#!/bin/bash

##############################################################################
# Sistema avanzado de instalación Ubuntu modular
# Orquestador principal con configuración interactiva
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Trap para capturar errores
error_handler() {
    local line_number=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] Script falló en línea $line_number" >> "$LOG_FILE"
    echo -e "\n${RED}✗ Error en línea $line_number${NC}"
    echo -e "${YELLOW}Ver log completo en: $LOG_FILE${NC}"
    exit 1
}

trap 'error_handler $LINENO' ERR

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # También mostrar en pantalla según nivel
    case "$level" in
        ERROR)
            echo -e "${RED}✗ $message${NC}" ;;
        SUCCESS)
            echo -e "${GREEN}✓ $message${NC}" ;;
        INFO)
            echo -e "${BLUE}ℹ $message${NC}" ;;
        WARN)
            echo -e "${YELLOW}⚠ $message${NC}" ;;
        *)
            echo "$message" ;;
    esac
}

# Redirigir todo stdout y stderr al log (además de pantalla)
exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "INFO" "═══════════════════════════════════════════════════════════"
log "INFO" "Inicio de instalación Ubuntu"
log "INFO" "Log: $LOG_FILE"
log "INFO" "═══════════════════════════════════════════════════════════"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

##############################################################################
# CONFIGURACIÓN INTERACTIVA
##############################################################################

interactive_config() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      CONFIGURACIÓN INTERACTIVA DE INSTALACIÓN             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 1. Versión Ubuntu
    echo -e "${YELLOW}[1/8] Versión de Ubuntu${NC}"
    echo ""
    echo "LTS (Long Term Support - 5 años de soporte):"
    echo "  1) Ubuntu 24.04 LTS (Noble Numbat) - Recomendado ✅"
    echo "  2) Ubuntu 22.04 LTS (Jammy Jellyfish)"
    echo "  3) Ubuntu 20.04 LTS (Focal Fossa)"
    echo ""
    echo "No-LTS (9 meses de soporte):"
    echo "  4) Ubuntu 25.10 (Questing Quokka)"
    echo ""
    echo "Desarrollo:"
    echo "  5) Ubuntu 26.04 LTS (Resolute Raccoon) - En desarrollo"
    echo ""
    read -p "Selecciona versión (1-5) [1]: " ver_choice
    ver_choice=${ver_choice:-1}
    
    case $ver_choice in
        1) UBUNTU_VERSION="noble" ;;
        2) UBUNTU_VERSION="jammy" ;;
        3) UBUNTU_VERSION="focal" ;;
        4) UBUNTU_VERSION="questing" ;;
        5) UBUNTU_VERSION="resolute" ;;
        *) UBUNTU_VERSION="noble" ;;
    esac
    
    echo -e "${GREEN}✓ Versión: Ubuntu $UBUNTU_VERSION${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 2. Hostname
    clear
    echo -e "${YELLOW}[2/8] Nombre del equipo (hostname)${NC}"
    echo ""
    echo "Ejemplos: ubuntu-desktop, mi-laptop, servidor-web"
    echo ""
    read -p "Hostname [ubuntu-vm]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-ubuntu-vm}
    echo -e "${GREEN}✓ Hostname: $HOSTNAME${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 3. Usuario
    clear
    echo -e "${YELLOW}[3/8] Nombre de usuario${NC}"
    echo ""
    read -p "Usuario: " USERNAME
    while [ -z "$USERNAME" ]; do
        echo "El nombre de usuario no puede estar vacío"
        read -p "Usuario: " USERNAME
    done
    echo -e "${GREEN}✓ Usuario: $USERNAME${NC}"
    
    # Contraseña del usuario
    echo ""
    echo "Contraseña para $USERNAME:"
    while true; do
        read -s -p "Contraseña: " USER_PASSWORD
        echo ""
        read -s -p "Confirmar contraseña: " USER_PASSWORD_CONFIRM
        echo ""
        
        if [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
            if [ -n "$USER_PASSWORD" ]; then
                echo -e "${GREEN}✓ Contraseña configurada${NC}"
                break
            else
                echo -e "${RED}La contraseña no puede estar vacía${NC}"
            fi
        else
            echo -e "${RED}Las contraseñas no coinciden, intenta de nuevo${NC}"
            echo ""
        fi
    done
    
    # Contraseña de root
    echo ""
    read -p "¿Usar la misma contraseña para root? (s/n) [s]: " same_pass
    if [[ ${same_pass:-s} =~ ^[SsYy]$ ]]; then
        ROOT_PASSWORD="$USER_PASSWORD"
        echo -e "${GREEN}✓ Root usará la misma contraseña${NC}"
    else
        echo ""
        echo "Contraseña para root:"
        while true; do
            read -s -p "Contraseña root: " ROOT_PASSWORD
            echo ""
            read -s -p "Confirmar contraseña root: " ROOT_PASSWORD_CONFIRM
            echo ""
            
            if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
                if [ -n "$ROOT_PASSWORD" ]; then
                    echo -e "${GREEN}✓ Contraseña de root configurada${NC}"
                    break
                else
                    echo -e "${RED}La contraseña no puede estar vacía${NC}"
                fi
            else
                echo -e "${RED}Las contraseñas no coinciden, intenta de nuevo${NC}"
                echo ""
            fi
        done
    fi
    
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 4. Tipo de hardware
    clear
    echo -e "${YELLOW}[4/8] Tipo de hardware${NC}"
    echo ""
    echo "  1) Desktop/Servidor (predeterminado)"
    echo "  2) Laptop"
    echo ""
    read -p "Selecciona tipo (1-2) [1]: " hw_choice
    hw_choice=${hw_choice:-1}
    
    if [ "$hw_choice" = "2" ]; then
        IS_LAPTOP="true"
        echo -e "${GREEN}✓ Tipo: Laptop${NC}"
    else
        IS_LAPTOP="false"
        echo -e "${GREEN}✓ Tipo: Desktop${NC}"
    fi
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 5. Conectividad
    clear
    echo -e "${YELLOW}[5/8] Conectividad${NC}"
    echo ""
    
    read -p "¿Tiene WiFi? (s/n) [s]: " has_wifi
    [[ ${has_wifi:-s} =~ ^[SsYy]$ ]] && HAS_WIFI="true" || HAS_WIFI="false"
    
    read -p "¿Tiene Bluetooth? (s/n) [s]: " has_bt
    [[ ${has_bt:-s} =~ ^[SsYy]$ ]] && HAS_BLUETOOTH="true" || HAS_BLUETOOTH="false"
    
    echo -e "${GREEN}✓ WiFi: $HAS_WIFI${NC}"
    echo -e "${GREEN}✓ Bluetooth: $HAS_BLUETOOTH${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 6. Componentes a instalar
    clear
    echo -e "${YELLOW}[6/8] Componentes a instalar${NC}"
    echo ""
    
    read -p "¿Instalar GNOME? (s/n) [s]: " inst_gnome
    [[ ${inst_gnome:-s} =~ ^[SsYy]$ ]] && INSTALL_GNOME="true" || INSTALL_GNOME="false"
    
    if [ "$INSTALL_GNOME" = "true" ]; then
        read -p "¿Activar autologin en GDM? (s/n) [n]: " inst_autologin
        [[ ${inst_autologin:-n} =~ ^[SsYy]$ ]] && GDM_AUTOLOGIN="true" || GDM_AUTOLOGIN="false"
        echo -e "${GREEN}✓ GNOME: $INSTALL_GNOME${NC}"
        echo -e "${GREEN}✓ Autologin GDM: $GDM_AUTOLOGIN${NC}"
    else
        GDM_AUTOLOGIN="false"
        echo -e "${GREEN}✓ GNOME: $INSTALL_GNOME${NC}"
    fi
    
    read -p "¿Instalar multimedia (códecs, thumbnailers)? (s/n) [s]: " inst_mm
    [[ ${inst_mm:-s} =~ ^[SsYy]$ ]] && INSTALL_MULTIMEDIA="true" || INSTALL_MULTIMEDIA="false"
    
    read -p "¿Instalar herramientas de desarrollo? (s/n) [n]: " inst_dev
    [[ ${inst_dev:-n} =~ ^[SsYy]$ ]] && INSTALL_DEVELOPMENT="true" || INSTALL_DEVELOPMENT="false"
    
    read -p "¿Configurar para gaming? (s/n) [n]: " inst_gaming
    [[ ${inst_gaming:-n} =~ ^[SsYy]$ ]] && INSTALL_GAMING="true" || INSTALL_GAMING="false"
    
    echo ""
    echo -e "${GREEN}✓ Multimedia: $INSTALL_MULTIMEDIA${NC}"
    echo -e "${GREEN}✓ Desarrollo: $INSTALL_DEVELOPMENT${NC}"
    echo -e "${GREEN}✓ Gaming: $INSTALL_GAMING${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 7. Optimizaciones
    clear
    echo -e "${YELLOW}[7/8] Optimizaciones del sistema${NC}"
    echo ""
    
    read -p "¿Minimizar componentes systemd? (s/n) [s]: " opt_systemd
    [[ ${opt_systemd:-s} =~ ^[SsYy]$ ]] && MINIMIZE_SYSTEMD="true" || MINIMIZE_SYSTEMD="false"
    
    read -p "¿Aplicar hardening de seguridad? (s/n) [n]: " opt_sec
    [[ ${opt_sec:-n} =~ ^[SsYy]$ ]] && ENABLE_SECURITY="true" || ENABLE_SECURITY="false"
    
    echo ""
    echo -e "${GREEN}✓ Minimizar systemd: $MINIMIZE_SYSTEMD${NC}"
    echo -e "${GREEN}✓ Seguridad: $ENABLE_SECURITY${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # 8. Opciones avanzadas
    clear
    echo -e "${YELLOW}[8/8] Opciones avanzadas${NC}"
    echo ""
    
    echo "APT: --no-install-recommends"
    echo "Esto reduce significativamente el tamaño de instalación"
    echo ""
    read -p "¿Usar --no-install-recommends? (s/n) [s]: " apt_opt
    [[ ${apt_opt:-s} =~ ^[SsYy]$ ]] && USE_NO_INSTALL_RECOMMENDS="true" || USE_NO_INSTALL_RECOMMENDS="false"
    
    echo ""
    echo -e "${GREEN}✓ --no-install-recommends: $USE_NO_INSTALL_RECOMMENDS${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
    
    # Resumen final
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              RESUMEN DE CONFIGURACIÓN                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Sistema:${NC}"
    echo "  • Versión: Ubuntu $UBUNTU_VERSION"
    echo "  • Hostname: $HOSTNAME"
    echo "  • Usuario: $USERNAME"
    echo "  • Contraseña usuario: ******* (configurada)"
    echo "  • Contraseña root: $([ "$ROOT_PASSWORD" = "$USER_PASSWORD" ] && echo "******* (misma)" || echo "******* (diferente)")"
    echo "  • Tipo: $([ "$IS_LAPTOP" = "true" ] && echo "Laptop" || echo "Desktop")"
    echo ""
    echo -e "${YELLOW}Hardware:${NC}"
    echo "  • WiFi: $HAS_WIFI"
    echo "  • Bluetooth: $HAS_BLUETOOTH"
    echo ""
    echo -e "${YELLOW}Componentes:${NC}"
    echo "  • GNOME: $INSTALL_GNOME"
    echo "  • Autologin GDM: $GDM_AUTOLOGIN"
    echo "  • Multimedia: $INSTALL_MULTIMEDIA"
    echo "  • Desarrollo: $INSTALL_DEVELOPMENT"
    echo "  • Gaming: $INSTALL_GAMING"
    echo ""
    echo -e "${YELLOW}Optimizaciones:${NC}"
    echo "  • Minimizar systemd: $MINIMIZE_SYSTEMD"
    echo "  • Seguridad: $ENABLE_SECURITY"
    echo "  • --no-install-recommends: $USE_NO_INSTALL_RECOMMENDS"
    echo ""
    
    read -p "¿Guardar esta configuración? (s/n) [s]: " save_conf
    
    if [[ ${save_conf:-s} =~ ^[SsYy]$ ]]; then
        save_config
        echo -e "${GREEN}✓ Configuración guardada en $CONFIG_FILE${NC}"
    fi
    
    echo ""
    read -p "¿Proceder con la instalación? (s/n): " proceed
    
    if [[ ! $proceed =~ ^[SsYy]$ ]]; then
        echo "Instalación cancelada"
        exit 0
    fi
}

##############################################################################
# GUARDAR CONFIGURACIÓN
##############################################################################

save_config() {
    cat > "$CONFIG_FILE" << EOF
# Configuración de instalación Ubuntu
# Generada: $(date)

# === SISTEMA BASE ===
UBUNTU_VERSION="$UBUNTU_VERSION"
TARGET_DISK="${TARGET_DISK:-/dev/vda}"
TARGET="${TARGET:-/mnt/ubuntu}"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"

# === CONTRASEÑAS (almacenadas temporalmente) ===
# IMPORTANTE: Este archivo contiene contraseñas en texto plano
# Elimínalo después de la instalación: rm config.env
USER_PASSWORD="$USER_PASSWORD"
ROOT_PASSWORD="$ROOT_PASSWORD"

# === HARDWARE ===
DISK_TYPE="${DISK_TYPE:-auto}"
IS_LAPTOP="$IS_LAPTOP"
HAS_WIFI="$HAS_WIFI"
HAS_BLUETOOTH="$HAS_BLUETOOTH"

# === OPTIMIZACIONES ===
ENABLE_SECURITY="$ENABLE_SECURITY"
MINIMIZE_SYSTEMD="$MINIMIZE_SYSTEMD"

# === COMPONENTES ===
INSTALL_GNOME="$INSTALL_GNOME"
GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-false}"
INSTALL_MULTIMEDIA="$INSTALL_MULTIMEDIA"
INSTALL_DEVELOPMENT="$INSTALL_DEVELOPMENT"
INSTALL_GAMING="$INSTALL_GAMING"

# === OPCIONES AVANZADAS ===
USE_NO_INSTALL_RECOMMENDS="$USE_NO_INSTALL_RECOMMENDS"
DUAL_BOOT="${DUAL_BOOT:-false}"
UBUNTU_SIZE_GB="${UBUNTU_SIZE_GB:-50}"
EOF

    # Hacer el archivo legible solo por root
    chmod 600 "$CONFIG_FILE"
    echo -e "${YELLOW}⚠ Archivo contiene contraseñas en texto plano${NC}"
    echo -e "${YELLOW}⚠ Elimínalo después: rm $CONFIG_FILE${NC}"
}

##############################################################################
# CARGAR O CREAR CONFIGURACIÓN
##############################################################################

load_or_create_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ Configuración encontrada: $CONFIG_FILE${NC}"
        echo ""
        read -p "¿Usar configuración existente? (s/n/e=editar) [s]: " use_existing
        
        case $use_existing in
            [Ee])
                ${EDITOR:-nano} "$CONFIG_FILE"
                source "$CONFIG_FILE"
                ;;
            [Nn])
                interactive_config
                ;;
            *)
                source "$CONFIG_FILE"
                echo -e "${GREEN}✓ Configuración cargada${NC}"
                ;;
        esac
    else
        echo -e "${YELLOW}No se encontró archivo de configuración${NC}"
        echo ""
        echo "Opciones:"
        echo "  1) Configuración interactiva (recomendado)"
        echo "  2) Crear config.env por defecto"
        echo ""
        read -p "Selecciona opción (1-2) [1]: " config_choice
        
        if [ "${config_choice:-1}" = "2" ]; then
            # Valores por defecto
            UBUNTU_VERSION="noble"
            HOSTNAME="ubuntu-vm"
            USERNAME="user"
            IS_LAPTOP="true"
            HAS_WIFI="true"
            HAS_BLUETOOTH="true"
            ENABLE_SECURITY="true"
            MINIMIZE_SYSTEMD="true"
            INSTALL_GNOME="true"
            INSTALL_MULTIMEDIA="true"
            INSTALL_DEVELOPMENT="false"
            INSTALL_GAMING="false"
            USE_NO_INSTALL_RECOMMENDS="true"
            
            save_config
            echo -e "${GREEN}✓ Configuración por defecto creada${NC}"
            echo "Edita $CONFIG_FILE y ejecuta de nuevo"
            exit 0
        else
            interactive_config
        fi
    fi
}

##############################################################################
# FUNCIONES AUXILIARES
##############################################################################

log_step() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [STEP] $1" >> "$LOG_FILE"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}▶ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() { 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [SUCCESS] $1" >> "$LOG_FILE"
    echo -e "${GREEN}✓${NC} $1"
}

log_error() { 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $1" >> "$LOG_FILE"
    echo -e "${RED}✗${NC} $1"
}

log_warning() { 
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $1" >> "$LOG_FILE"
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $1" >> "$LOG_FILE"
    echo -e "${BLUE}ℹ${NC} $1"
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
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "${GREEN}Configuración actual:${NC}"
        echo "  • Ubuntu: $UBUNTU_VERSION"
        echo "  • Hostname: $HOSTNAME"
        echo "  • Usuario: $USERNAME"
        echo "  • Laptop: $IS_LAPTOP"
        echo ""
    fi
    
    echo -e "${YELLOW}INSTALACIÓN COMPLETA:${NC}"
    echo "  1) Instalación interactiva guiada (recomendado)"
    echo "  2) Instalación automática (requiere config.env)"
    echo ""
    echo -e "${YELLOW}CONFIGURACIÓN:${NC}"
    echo "  3) Configuración interactiva guiada"
    echo "  4) Editar config.env manualmente"
    echo ""
    echo -e "${YELLOW}MÓDULOS INDIVIDUALES - BASE:${NC}"
    echo "  9) Verificar dependencias"
    echo "  10) Preparar disco"
    echo "  11) Instalar sistema base"
    echo "  12) Configurar sistema"
    echo "  13) Instalar bootloader"
    echo "  14) Configurar red"
    echo ""
    echo -e "${YELLOW}MÓDULOS - COMPONENTES:${NC}"
    echo "  20) Instalar GNOME"
    echo "  22) Multimedia"
    echo "  23) Fuentes"
    echo "  24) WiFi/Bluetooth"
    echo "  25) Desarrollo"
    echo "  26) Gaming"
    echo ""
    echo -e "${YELLOW}MÓDULOS - OPTIMIZACIÓN:${NC}"
    echo "  30) Laptop (TLP)"
    echo "  32) Systemd"
    echo "  33) Seguridad"
    echo ""
    echo -e "${YELLOW}UTILIDADES:${NC}"
    echo "  40) Verificar sistema"
    echo "  41) Generar informe"
    echo "  42) Backup config"
    echo ""
    echo "  0) Salir"
    echo ""
    read -p "Selecciona opción: " choice
    echo ""
    
    case $choice in
        1) full_interactive_install ;;
        2) full_automatic_install ;;
        3) interactive_config ;;
        4) ${EDITOR:-nano} "$CONFIG_FILE" && source "$CONFIG_FILE" ;;
        
        9) run_module "00-check-dependencies" ;;
        10) run_module "01-prepare-disk" ;;
        11) run_module "02-debootstrap" ;;
        12) run_module "03-configure-base" ;;
        13) run_module "04-install-bootloader" ;;
        14) run_module "05-configure-network" ;;
        
        20) run_module "10-install-gnome" ;;
        22) run_module "12-install-multimedia" ;;
        23) run_module "13-install-fonts" ;;
        24) run_module "14-configure-wireless" ;;
        25) run_module "15-install-development" ;;
        26) run_module "16-configure-gaming" ;;
        
        30) run_module "21-optimize-laptop" ;;
        32) run_module "23-minimize-systemd" ;;
        33) run_module "24-security-hardening" ;;
        
        40) run_module "30-verify-system" ;;
        41) run_module "31-generate-report" ;;
        42) run_module "32-backup-config" ;;
        
        0) exit 0 ;;
        *) log_error "Opción inválida"; sleep 2 ;;
    esac
    
    read -p "Presiona Enter para continuar..."
}

##############################################################################
# INSTALACIÓN AUTOMÁTICA
##############################################################################

full_automatic_install() {
    check_root
    load_or_create_config
    
    log_step "INSTALACIÓN AUTOMÁTICA COMPLETA"
    
    # Verificar dependencias primero
    run_module "00-check-dependencies" || exit 1
    
    # Módulos base (esenciales)
    run_module "01-prepare-disk" || exit 1
    run_module "02-debootstrap" || exit 1
    run_module "03-configure-base" || exit 1
    run_module "04-install-bootloader" || exit 1
    run_module "05-configure-network" || exit 1
    
    # Componentes opcionales
    [ "$INSTALL_GNOME" = "true" ] && run_module "10-install-gnome"
    [ "$INSTALL_MULTIMEDIA" = "true" ] && run_module "12-install-multimedia"
    run_module "13-install-fonts"
    [ "$HAS_WIFI" = "true" ] && run_module "14-configure-wireless"
    [ "$INSTALL_DEVELOPMENT" = "true" ] && run_module "15-install-development"
    [ "$INSTALL_GAMING" = "true" ] && run_module "16-configure-gaming"
    
    # Optimizaciones
    [ "$IS_LAPTOP" = "true" ] && run_module "21-optimize-laptop"
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
    load_or_create_config
    
    log_step "INSTALACIÓN INTERACTIVA"
    
    # Ejecutar verificación de dependencias automáticamente
    echo ""
    echo -e "${GREEN}Verificando dependencias del sistema...${NC}"
    run_module "00-check-dependencies" || {
        log_error "Error al verificar dependencias"
        exit 1
    }
    echo ""
    
    declare -A modules=(
        ["01-prepare-disk"]="Preparar disco"
        ["02-debootstrap"]="Sistema base"
        ["03-configure-base"]="Configuración"
        ["04-install-bootloader"]="Bootloader"
        ["05-configure-network"]="Red"
        ["10-install-gnome"]="GNOME"
        ["12-install-multimedia"]="Multimedia"
        ["13-install-fonts"]="Fuentes"
        ["14-configure-wireless"]="WiFi/Bluetooth"
        ["21-optimize-laptop"]="Laptop"
        ["23-minimize-systemd"]="Systemd"
        ["24-security-hardening"]="Seguridad"
    )
    
    # Lista de módulos a ejecutar (base es obligatorio)
    MODULES_TO_RUN=(
        "01-prepare-disk"
        "02-debootstrap"
        "03-configure-base"
        "04-install-bootloader"
        "05-configure-network"
    )
    
    # Agregar módulos opcionales según configuración
    [ "$INSTALL_GNOME" = "true" ] && MODULES_TO_RUN+=("10-install-gnome")
    
    [ "$INSTALL_MULTIMEDIA" = "true" ] && MODULES_TO_RUN+=("12-install-multimedia")
    
    # Fuentes siempre (son ligeras)
    MODULES_TO_RUN+=("13-install-fonts")
    
    [ "$HAS_WIFI" = "true" ] || [ "$HAS_BLUETOOTH" = "true" ] && MODULES_TO_RUN+=("14-configure-wireless")
    
    [ "$IS_LAPTOP" = "true" ] && MODULES_TO_RUN+=("21-optimize-laptop")
    [ "$MINIMIZE_SYSTEMD" = "true" ] && MODULES_TO_RUN+=("23-minimize-systemd")
    [ "$ENABLE_SECURITY" = "true" ] && MODULES_TO_RUN+=("24-security-hardening")
    
    echo -e "${CYAN}Módulos a instalar según tu configuración:${NC}"
    for mod in "${MODULES_TO_RUN[@]}"; do
        echo "  • ${modules[$mod]}"
    done
    echo ""
    
    read -p "¿Continuar con instalación interactiva? (s/n): " proceed
    if [[ ! $proceed =~ ^[SsYy]$ ]]; then
        echo "Instalación cancelada"
        return
    fi
    
    for mod in "${MODULES_TO_RUN[@]}"; do
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Siguiente:${NC} ${modules[$mod]}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        read -p "¿Ejecutar? (s/n/q=salir) [s]: " ans
        ans=${ans:-s}
        
        case $ans in
            [Qq]*) 
                echo "Instalación cancelada"
                return
                ;;
            [Nn]*) 
                log_warning "Omitido: $mod"
                ;;
            *) 
                run_module "$mod" || {
                    read -p "Falló. ¿Continuar? (s/n): " cont
                    [[ ! $cont =~ ^[SsYy]$ ]] && return
                }
                ;;
        esac
    done
    
    log_success "¡Instalación completada!"
}

##############################################################################
# MAIN
##############################################################################

check_root

if [ $# -gt 0 ]; then
    case "$1" in
        --auto)
            load_or_create_config
            full_automatic_install
            ;;
        --interactive|-i)
            load_or_create_config
            full_interactive_install
            ;;
        --config|-c)
            interactive_config
            ;;
        --module|-m)
            [ -z "$2" ] && { log_error "Especifica módulo"; exit 1; }
            source "$CONFIG_FILE" 2>/dev/null || true
            run_module "$2"
            ;;
        --list|-l)
            echo "Módulos disponibles:"
            ls -1 "$MODULES_DIR" | sed 's/.sh$//'
            ;;
        --help|-h)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --auto, -a           Instalación automática"
            echo "  --interactive, -i    Instalación interactiva"
            echo "  --config, -c         Configuración guiada"
            echo "  --module NOMBRE, -m  Ejecutar módulo"
            echo "  --list, -l           Listar módulos"
            echo "  --help, -h           Ayuda"
            echo ""
            echo "Sin opciones: Menú interactivo"
            ;;
        *)
            log_error "Opción desconocida: $1"
            exit 1
            ;;
    esac
else
    while true; do
        show_menu
    done
fi

# ============================================================================
# RESUMEN FINAL DEL LOG
# ============================================================================
log_step "Instalación finalizada"
log_info "Log completo guardado en: $LOG_FILE"
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║               INSTALACIÓN COMPLETADA                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Log guardado en:${NC}"
echo -e "  $LOG_FILE"
echo ""

