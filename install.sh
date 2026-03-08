#!/bin/bash

##############################################################################
# Sistema avanzado de instalación Ubuntu modular
# Orquestador principal con configuración interactiva
##############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/config.env"

# Modo verbose (mostrar comandos ejecutados)
VERBOSE_MODE="${VERBOSE_MODE:-false}"  # Por defecto desactivado

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Colores (definidos antes de error_handler y log que los usan)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

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

# ============================================================================
# CHROOT: MOUNT Y CLEANUP
# ============================================================================
# Usamos chroot estándar en todos los módulos. Los pseudofilesystems se
# montan una sola vez aquí y se desmontan al salir (trap EXIT).
# --make-rslave es necesario para hosts con systemd (mount propagation).
# Ref: https://wiki.gentoo.org/wiki/Steam#Systemd_and_chroot
# ============================================================================

chroot_mount() {
    local target="$1"
    [ -z "$target" ] && return 1

    # Crear directorios si no existen
    mkdir -p "${target}/proc" "${target}/sys" "${target}/dev" "${target}/run"

    # Montar solo si no está ya montado
    if ! mountpoint -q "${target}/proc" 2>/dev/null; then
        mount -t proc proc "${target}/proc"
    fi
    if ! mountpoint -q "${target}/sys" 2>/dev/null; then
        mount --rbind /sys "${target}/sys"
        mount --make-rslave "${target}/sys" 2>/dev/null || true
    fi
    if ! mountpoint -q "${target}/dev" 2>/dev/null; then
        mount --rbind /dev "${target}/dev"
        mount --make-rslave "${target}/dev" 2>/dev/null || true
    fi
    if ! mountpoint -q "${target}/run" 2>/dev/null; then
        mount --rbind /run "${target}/run"
        mount --make-rslave "${target}/run" 2>/dev/null || true
    fi
    cp -L /etc/resolv.conf "${target}/etc/resolv.conf" 2>/dev/null || true

    # Verificar que /proc se montó correctamente (crítico para dpkg/grub/dracut)
    if ! mountpoint -q "${target}/proc"; then
        echo "ERROR CRÍTICO: No se pudo montar /proc en ${target}/proc"
        echo "Los módulos chroot fallarán sin /proc."
        return 1
    fi

    log "SUCCESS" "Pseudofilesystems montados en $target"
}

chroot_umount() {
    local target="$1"
    [ -z "$target" ] && return 0
    umount -l "${target}/run" 2>/dev/null || true
    umount -l "${target}/dev" 2>/dev/null || true
    umount -l "${target}/sys" 2>/dev/null || true
    umount -l "${target}/proc" 2>/dev/null || true
    log "INFO" "Pseudofilesystems desmontados"
}

export -f chroot_mount chroot_umount

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
    read -p "Hostname [ubuntu]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-ubuntu}
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
        echo ""
        echo -e "${CYAN}Personalización de GNOME:${NC}"
        
        read -p "  ¿Optimizar memoria? (deshabilita Tracker, Evolution, etc.) (s/n) [n]: " opt_mem
        [[ ${opt_mem:-n} =~ ^[SsYy]$ ]] && GNOME_OPTIMIZE_MEMORY="true" || GNOME_OPTIMIZE_MEMORY="false"
        
        read -p "  ¿Aplicar tema transparente? (s/n) [n]: " opt_theme
        [[ ${opt_theme:-n} =~ ^[SsYy]$ ]] && GNOME_TRANSPARENT_THEME="true" || GNOME_TRANSPARENT_THEME="false"
        
        read -p "  ¿Activar autologin en GDM? (s/n) [n]: " inst_autologin
        [[ ${inst_autologin:-n} =~ ^[SsYy]$ ]] && GDM_AUTOLOGIN="true" || GDM_AUTOLOGIN="false"

        echo ""
        echo -e "${CYAN}Gestión de AppImages:${NC}"
        echo "  AM (ivan-hc/AM) se instala siempre como gestor CLI."
        read -p "  ¿Compilar también AppManager GUI? (s/n) [n]: " opt_appmanager
        [[ ${opt_appmanager:-n} =~ ^[SsYy]$ ]] && APPIMAGE_MANAGER_CHOICE="1" || APPIMAGE_MANAGER_CHOICE="2"

        echo ""
        echo -e "${GREEN}✓ GNOME: $INSTALL_GNOME${NC}"
        echo -e "${GREEN}  - Optimizar memoria: $GNOME_OPTIMIZE_MEMORY${NC}"
        echo -e "${GREEN}  - Tema transparente: $GNOME_TRANSPARENT_THEME${NC}"
        echo -e "${GREEN}  - Autologin GDM: $GDM_AUTOLOGIN${NC}"
        echo -e "${GREEN}  - AppManager GUI: $([ "$APPIMAGE_MANAGER_CHOICE" = "1" ] && echo "sí" || echo "no")${NC}"
    else
        GDM_AUTOLOGIN="false"
        GNOME_OPTIMIZE_MEMORY="false"
        GNOME_TRANSPARENT_THEME="false"
        APPIMAGE_MANAGER_CHOICE="2"
        echo -e "${GREEN}✓ GNOME: $INSTALL_GNOME${NC}"
    fi
    
    echo ""
    read -p "¿Instalar multimedia (códecs, thumbnailers)? (s/n) [s]: " inst_mm
    [[ ${inst_mm:-s} =~ ^[SsYy]$ ]] && INSTALL_MULTIMEDIA="true" || INSTALL_MULTIMEDIA="false"
    
    if [ "$INSTALL_MULTIMEDIA" = "true" ]; then
        read -p "  ¿Instalar Spotify? (s/n) [n]: " opt_spotify
        [[ ${opt_spotify:-n} =~ ^[SsYy]$ ]] && INSTALL_SPOTIFY="s" || INSTALL_SPOTIFY="n"
    else
        INSTALL_SPOTIFY="n"
    fi
    
    read -p "¿Instalar herramientas de desarrollo? (s/n) [n]: " inst_dev
    [[ ${inst_dev:-n} =~ ^[SsYy]$ ]] && INSTALL_DEVELOPMENT="true" || INSTALL_DEVELOPMENT="false"
    
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        echo ""
        echo -e "${CYAN}Herramientas de desarrollo:${NC}"
        read -p "  ¿Visual Studio Code? (s/n) [s]: " opt_vscode
        INSTALL_VSCODE="${opt_vscode:-s}"
        
        echo "  NodeJS: 1) No instalar  2) LTS desde NodeSource (recomendado)"
        read -p "  Opción [2]: " opt_nodejs
        NODEJS_OPTION="${opt_nodejs:-2}"
        
        read -p "  ¿Rust (rustup)? (s/n) [n]: " opt_rust
        INSTALL_RUST="${opt_rust:-n}"

        read -p "  ¿topgrade (actualiza todo con un comando)? (s/n) [s]: " opt_topgrade
        INSTALL_TOPGRADE="${opt_topgrade:-s}"
    else
        INSTALL_VSCODE="n"
        NODEJS_OPTION="1"
        INSTALL_RUST="n"
        INSTALL_TOPGRADE="n"
    fi
    
    read -p "¿Configurar para gaming? (s/n) [n]: " inst_gaming
    [[ ${inst_gaming:-n} =~ ^[SsYy]$ ]] && INSTALL_GAMING="true" || INSTALL_GAMING="false"
    
    if [ "$INSTALL_GAMING" = "true" ]; then
        echo ""
        echo -e "${CYAN}Kernel CachyOS (opcional):${NC}"
        echo "  1) BORE — baja latencia (gaming/escritorio)"
        echo "  2) EEVDF — equilibrio rendimiento/estabilidad"
        echo "  3) No instalar kernel CachyOS"
        read -p "  Variante [3]: " opt_cachyos
        CACHYOS_CHOICE="${opt_cachyos:-3}"
    else
        CACHYOS_CHOICE="3"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Multimedia: $INSTALL_MULTIMEDIA$([ "$INSTALL_SPOTIFY" = "s" ] && echo " (+Spotify)")${NC}"
    echo -e "${GREEN}✓ Desarrollo: $INSTALL_DEVELOPMENT${NC}"
    echo -e "${GREEN}✓ Gaming: $INSTALL_GAMING$([ "$CACHYOS_CHOICE" != "3" ] && echo " (+CachyOS)")${NC}"
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
    echo -e "${CYAN}Actualizaciones automáticas:${NC}"
    echo "  1) Solo seguridad (recomendado)"
    echo "  2) Todas las actualizaciones estables"
    echo "  3) No configurar"
    read -p "  Opción [1]: " opt_autoupdate
    AUTO_UPDATE_CHOICE="${opt_autoupdate:-1}"

    if [ "$IS_LAPTOP" = "true" ]; then
        echo ""
        echo -e "${CYAN}Gestión de energía (laptop):${NC}"
        echo "  1) power-profiles-daemon (integrado con GNOME)"
        echo "  2) TLP (configuración avanzada)"
        read -p "  Opción [1]: " opt_power
        POWER_MANAGER="${opt_power:-1}"
        
        read -p "  ¿Instalar nothrottle (control throttling Intel)? (s/n) [n]: " opt_nothrottle
        [[ ${opt_nothrottle:-n} =~ ^[SsYy]$ ]] && INSTALL_NOTHROTTLE="true" || INSTALL_NOTHROTTLE="false"
    else
        POWER_MANAGER="1"
        INSTALL_NOTHROTTLE="false"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Minimizar systemd: $MINIMIZE_SYSTEMD${NC}"
    echo -e "${GREEN}✓ Seguridad: $ENABLE_SECURITY${NC}"
    echo -e "${GREEN}✓ Auto-updates: opción $AUTO_UPDATE_CHOICE${NC}"
    if [ "$IS_LAPTOP" = "true" ]; then
        echo -e "${GREEN}✓ Power manager: $([ "$POWER_MANAGER" = "1" ] && echo "power-profiles-daemon" || echo "TLP")${NC}"
        echo -e "${GREEN}✓ Nothrottle: $INSTALL_NOTHROTTLE${NC}"
    fi
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
    if [ "$INSTALL_GNOME" = "true" ]; then
        echo "    - Optimizar memoria: $GNOME_OPTIMIZE_MEMORY"
        echo "    - Tema transparente: $GNOME_TRANSPARENT_THEME"
        echo "    - Autologin GDM: $GDM_AUTOLOGIN"
        echo "    - AppManager GUI: $([ "${APPIMAGE_MANAGER_CHOICE:-2}" = "1" ] && echo "sí" || echo "no")"
    fi
    echo "  • Multimedia: $INSTALL_MULTIMEDIA$([[ "${INSTALL_SPOTIFY:-n}" =~ ^[SsYy]$ ]] && echo " (+Spotify)")"
    echo "  • Desarrollo: $INSTALL_DEVELOPMENT"
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        echo "    - VSCode: $INSTALL_VSCODE, Node: opción $NODEJS_OPTION, Rust: $INSTALL_RUST, topgrade: $INSTALL_TOPGRADE"
    fi
    echo "  • Gaming: $INSTALL_GAMING$([ "${CACHYOS_CHOICE:-3}" != "3" ] && echo " (+CachyOS)")"
    echo ""
    echo -e "${YELLOW}Optimizaciones:${NC}"
    echo "  • Minimizar systemd: $MINIMIZE_SYSTEMD"
    echo "  • Seguridad: $ENABLE_SECURITY"
    echo "  • Auto-updates: opción ${AUTO_UPDATE_CHOICE:-1}"
    echo "  • --no-install-recommends: $USE_NO_INSTALL_RECOMMENDS"
    if [ "$IS_LAPTOP" = "true" ]; then
        echo "  • Power manager: $([ "${POWER_MANAGER:-1}" = "1" ] && echo "power-profiles-daemon" || echo "TLP")"
        echo "  • Nothrottle: ${INSTALL_NOTHROTTLE:-false}"
    fi
    echo ""
    
    read -p "¿Guardar esta configuración? (s/n) [s]: " save_conf
    
    if [[ ${save_conf:-s} =~ ^[SsYy]$ ]]; then
        save_config
        echo -e "${GREEN}✓ Configuración guardada en $CONFIG_FILE${NC}"
    fi
    
    echo ""
    read -p "¿Proceder con la instalación? (s/n) [s]: " proceed
    proceed=${proceed:-s}
    
    if [[ ! $proceed =~ ^[SsYy]$ ]]; then
        echo "Instalación cancelada"
        exit 0
    fi
    
    # Exportar variables para que los módulos las vean
    export_config_vars
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
IS_LAPTOP="$IS_LAPTOP"
HAS_WIFI="$HAS_WIFI"
HAS_BLUETOOTH="$HAS_BLUETOOTH"

# === OPTIMIZACIONES ===
ENABLE_SECURITY="$ENABLE_SECURITY"
MINIMIZE_SYSTEMD="$MINIMIZE_SYSTEMD"

# === COMPONENTES ===
INSTALL_GNOME="$INSTALL_GNOME"
GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-false}"
GNOME_OPTIMIZE_MEMORY="${GNOME_OPTIMIZE_MEMORY:-false}"
GNOME_TRANSPARENT_THEME="${GNOME_TRANSPARENT_THEME:-false}"
APPIMAGE_MANAGER_CHOICE="${APPIMAGE_MANAGER_CHOICE:-2}"
INSTALL_MULTIMEDIA="$INSTALL_MULTIMEDIA"
INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-n}"
INSTALL_DEVELOPMENT="$INSTALL_DEVELOPMENT"
INSTALL_VSCODE="${INSTALL_VSCODE:-s}"
NODEJS_OPTION="${NODEJS_OPTION:-2}"
INSTALL_RUST="${INSTALL_RUST:-n}"
INSTALL_TOPGRADE="${INSTALL_TOPGRADE:-s}"
INSTALL_GAMING="$INSTALL_GAMING"
CACHYOS_CHOICE="${CACHYOS_CHOICE:-3}"
AUTO_UPDATE_CHOICE="${AUTO_UPDATE_CHOICE:-1}"
POWER_MANAGER="${POWER_MANAGER:-1}"
INSTALL_NOTHROTTLE="${INSTALL_NOTHROTTLE:-false}"

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


setup_apt_progress() {
    # ── Barra de progreso dpkg ────────────────────────────────────────────────
    # Dpkg::Progress-Fancy muestra una barra de progreso en terminal durante
    # la instalación/desconfiguración de paquetes. Requiere terminal con color.
    # APT::Color habilita colores en el output de apt.
    #
    # Se llama dos veces durante la instalación:
    #   1) Al cargar config (antes de debootstrap) → configura solo el host
    #   2) Después de debootstrap (run_module wrapper) → configura el chroot
    # La función es idempotente: si el archivo ya existe no lo reescribe.

    local APT_PROGRESS_CONF='// Barra de progreso dpkg — activada por ubuntu-advanced-install
Dpkg::Progress-Fancy "1";
APT::Color "1";'

    # Sistema live (host)
    if [ -d /etc/apt/apt.conf.d ] && [ ! -f /etc/apt/apt.conf.d/99-installer-progress ]; then
        echo "$APT_PROGRESS_CONF" > /etc/apt/apt.conf.d/99-installer-progress
    fi

    # Chroot ($TARGET) — solo si el directorio ya existe (post-debootstrap)
    if [ -d "${TARGET:-}/etc/apt/apt.conf.d" ] && [ ! -f "${TARGET}/etc/apt/apt.conf.d/99-installer-progress" ]; then
        echo "$APT_PROGRESS_CONF" > "${TARGET}/etc/apt/apt.conf.d/99-installer-progress"
        log "APT progress configurado en chroot: ${TARGET}"
    fi
}

export_config_vars() {
    # Exportar todas las variables de configuración para que los módulos las vean
    export UBUNTU_VERSION
    export TARGET_DISK
    export TARGET
    export HOSTNAME
    export USERNAME
    export USER_PASSWORD
    export ROOT_PASSWORD
    export IS_LAPTOP
    export HAS_WIFI
    export HAS_BLUETOOTH
    export ENABLE_SECURITY
    export MINIMIZE_SYSTEMD
    export INSTALL_GNOME
    export GDM_AUTOLOGIN
    export GNOME_OPTIMIZE_MEMORY
    export GNOME_TRANSPARENT_THEME
    export APPIMAGE_MANAGER_CHOICE
    export INSTALL_MULTIMEDIA
    export INSTALL_SPOTIFY
    export INSTALL_DEVELOPMENT
    export INSTALL_VSCODE
    export NODEJS_OPTION
    export INSTALL_RUST
    export INSTALL_TOPGRADE
    export INSTALL_GAMING
    export CACHYOS_CHOICE
    export AUTO_UPDATE_CHOICE
    export POWER_MANAGER
    export INSTALL_NOTHROTTLE
    export USE_NO_INSTALL_RECOMMENDS
    export DUAL_BOOT
    export UBUNTU_SIZE_GB

    # Configurar barra de progreso apt en live y en chroot
    setup_apt_progress
}

load_or_create_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓ Configuración encontrada: $CONFIG_FILE${NC}"
        echo ""
        read -p "¿Usar configuración existente? (s/n/e=editar) [s]: " use_existing
        
        case $use_existing in
            [Ee])
                ${EDITOR:-nano} "$CONFIG_FILE"
                source "$CONFIG_FILE"
                export_config_vars
                ;;
            [Nn])
                interactive_config
                export_config_vars
                ;;
            *)
                source "$CONFIG_FILE"
                export_config_vars
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
            HOSTNAME="ubuntu"
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
            export_config_vars
            echo -e "${GREEN}✓ Configuración por defecto creada${NC}"
            echo "Edita $CONFIG_FILE y ejecuta de nuevo"
            exit 0
        else
            interactive_config
            export_config_vars
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
    
    # Exportar variables
    export DEBUG_MODULE="$module_name"
    export DEBUG_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  MÓDULO: $module_name${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Garantizar locale mínimo válido en el entorno del host.
    # Los módulos invocan chroot que hereda estas variables.
    # Sin esto, apt dentro del chroot recibe un entorno sin locale y
    # genera warnings "Cannot set LC_*" en cada instalación de paquetes.
    # C.UTF-8 siempre existe — no requiere instalar ni generar nada.
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export LANGUAGE=C

    # Montar pseudofilesystems si TARGET existe y no están montados
    if [ -n "$TARGET" ] && [ -d "$TARGET" ] && ! mountpoint -q "${TARGET}/proc" 2>/dev/null; then
        chroot_mount "$TARGET"
    fi

    # Asegurar que la barra de progreso de apt está configurada en el chroot
    # (idempotente — solo crea el archivo la primera vez que el chroot existe)
    setup_apt_progress

    # Ejecutar con o sin verbose según configuración
    local exit_code=0
    
    if [ "$VERBOSE_MODE" = "true" ]; then
        # Modo verbose: usar bash -x directamente
        bash -x "$module_path" || exit_code=$?
    else
        # Modo normal: ejecución estándar
        bash "$module_path" || exit_code=$?
    fi
    
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    
    if [ $exit_code -eq 0 ]; then
        log_success "Módulo completado: $module_name"
        echo "[$module_name] OK" >> "$LOG_DIR/module-summary.log"
        echo ""
        return 0
    else
        log_error "Módulo falló: $module_name (exit code: $exit_code)"
        echo "[$module_name] FAILED (code: $exit_code)" >> "$LOG_DIR/module-summary.log"
        echo ""
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
    echo "  3) Instalación DEBUG asistida (verbose, para diagnosticar)"
    echo ""
    echo -e "${YELLOW}CONFIGURACIÓN:${NC}"
    echo "  4) Configuración interactiva guiada"
    echo "  5) Editar config.env manualmente"
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
    echo "  20) GNOME (completo con config)"
    echo "  22) Multimedia"
    echo "  23) Fuentes"
    echo "  24) WiFi/Bluetooth"
    echo "  25) Desarrollo"
    echo "  26) Gaming"
    echo ""
    echo -e "${YELLOW}MÓDULOS - OPTIMIZACIÓN:${NC}"
    echo "  30) Laptop (TLP)         → módulo 21-optimize-laptop"
    echo "  32) Systemd              → módulo 23-minimize-systemd"
    echo "  33) Seguridad            → módulo 24-security-hardening"
    echo ""
    echo -e "${YELLOW}UTILIDADES:${NC}"
    echo "  40) Verificar sistema"
    echo "  41) Generar informe"
    echo "  42) Backup config"
    echo ""
    # ============================================================================
    # MÓDULOS DE TESTEO (COMENTADOS POR DEFECTO)
    # ============================================================================
    # Para habilitar los módulos de testeo, descomenta las siguientes líneas:
    #
    # echo -e "${CYAN}MÓDULOS DE TESTEO (AVANZADO):${NC}"
    # echo "  90) [TEST] GNOME - Probar configuración GNOME"
    # echo "  91) [TEST] Gaming - Probar configuración gaming"
    # echo "  92) [TEST] Power - Probar gestión de energía"
    # echo "  93) [TEST] Network - Probar conectividad"
    # echo ""
    #
    # Y en el case añade:
    #   90) run_module "TEST-gnome" ;;
    #   91) run_module "TEST-gaming" ;;
    #   92) run_module "TEST-power" ;;
    #   93) run_module "TEST-network" ;;
    # ============================================================================
    echo "  0) Salir"
    echo ""
    read -p "Selecciona opción [1]: " choice
    choice=${choice:-1}  # Default opción 1
    echo ""
    
    case $choice in
        1) full_interactive_install ;;
        2) full_automatic_install ;;
        3) 
            # Activar modo verbose para esta sesión
            VERBOSE_MODE=true
            export VERBOSE_MODE
            echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
            echo -e "${CYAN}  MODO DEBUG ASISTIDO ACTIVADO${NC}"
            echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${YELLOW}Este modo mostrará cada comando ejecutado en tiempo real.${NC}"
            echo -e "${YELLOW}Útil para diagnosticar problemas o entender qué hace el instalador.${NC}"
            echo ""
            read -p "Presiona Enter para continuar..."
            full_interactive_install
            ;;
        4) interactive_config ;;
        5) ${EDITOR:-nano} "$CONFIG_FILE" && source "$CONFIG_FILE" ;;
        
        9) run_module "00-check-dependencies" ;;
        10) run_module "01-prepare-disk" ;;
        11) run_module "02-debootstrap" ;;
        12) run_module "03-configure-base" ;;
        13) run_module "04-install-bootloader" ;;
        14) run_module "05-configure-network" ;;
        
        20) 
            run_module "10-install-gnome-core"
            run_module "10-user-config"
            ;;
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
    
    # ── CORE: siempre se ejecutan, fallo = abort ─────────────────────────────
    run_module "00-check-dependencies" || exit 1
    run_module "01-prepare-disk"       || exit 1
    run_module "02-debootstrap"        || exit 1

    # Montar pseudofilesystems para chroot estándar
    chroot_mount "$TARGET"
    trap 'chroot_umount "$TARGET"' EXIT

    run_module "03-configure-base"     || exit 1
    run_module "04-install-bootloader" || exit 1
    run_module "05-configure-network"  || exit 1
    run_module "06-configure-auto-updates" || exit 1

    # ── GNOME ─────────────────────────────────────────────────────────────────
    if [ "${INSTALL_GNOME:-false}" = "true" ]; then
        run_module "10-install-gnome-core" || exit 1
        run_module "10-user-config"        || exit 1
        [ "${GNOME_OPTIMIZE_MEMORY:-false}" = "true" ] && run_module "10-optimize"
        [ "${GNOME_TRANSPARENT_THEME:-false}" = "true" ] && run_module "10-theme"
    fi

    # ── EXTRA: fallo = advertencia, continuar ────────────────────────────────
    run_module "13-install-fonts"
    [ "${INSTALL_MULTIMEDIA:-false}"  = "true" ] && run_module "12-install-multimedia"
    [ "${HAS_WIFI:-false}"  = "true" ] || [ "${HAS_BLUETOOTH:-false}" = "true" ] &&         run_module "14-configure-wireless"
    [ "${INSTALL_DEVELOPMENT:-false}" = "true" ] && run_module "15-install-development"
    [ "${INSTALL_GAMING:-false}"      = "true" ] && run_module "16-configure-gaming"
    [ "${IS_LAPTOP:-false}"           = "true" ] && run_module "21-optimize-laptop"
    [ "${MINIMIZE_SYSTEMD:-false}"    = "true" ] && run_module "23-minimize-systemd"
    [ "${ENABLE_SECURITY:-false}"     = "true" ] && run_module "24-security-hardening"

    log_success "Instalación automática completada"

    # ── Limpieza de seguridad: eliminar config.env con contraseñas ────────────
    if [ -f "$CONFIG_FILE" ]; then
        dd if=/dev/urandom bs=1 count="$(stat -c%s "$CONFIG_FILE")" 2>/dev/null | \
            tr -dc 'a-zA-Z0-9' | head -c "$(stat -c%s "$CONFIG_FILE")" > "$CONFIG_FILE" 2>/dev/null || true
        rm -f "$CONFIG_FILE"
        echo -e "${GREEN}✓  config.env eliminado de forma segura${NC}"
    fi

    run_module "31-generate-report"
}

##############################################################################
# INSTALACIÓN INTERACTIVA
##############################################################################

full_interactive_install() {
    check_root
    load_or_create_config
    
    log_step "INSTALACIÓN INTERACTIVA"
    
    # ============================================================================
    # VERIFICACIÓN DE HARDWARE
    # ============================================================================
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  VERIFICACIÓN DE HARDWARE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    HW_WARNINGS=0
    HW_ERRORS=0
    
    # CPU
    echo -e "${CYAN}Verificando CPU...${NC}"
    if grep -q "Intel" /proc/cpuinfo; then
        CPU_VENDOR="Intel"
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo "  ✓ CPU Intel: $CPU_MODEL"
    elif grep -q "AMD" /proc/cpuinfo; then
        CPU_VENDOR="AMD"
        CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo "  ✓ CPU AMD: $CPU_MODEL"
    else
        echo "  ℹ️  CPU detectada"
    fi
    
    CPU_CORES=$(nproc)
    echo "  ✓ Cores detectados: $CPU_CORES"
    
    
    # RAM
    echo ""
    echo -e "${CYAN}Verificando RAM...${NC}"
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    echo "  ✓ RAM detectada: ${RAM_GB}GB (${RAM_MB}MB)"
    
    
    # GPU
    echo ""
    echo -e "${CYAN}Verificando GPU...${NC}"
    GPU_INFO=$(lspci | grep -i "vga\|3d\|display")
    
    if echo "$GPU_INFO" | grep -qi "nvidia"; then
        echo "  ✓ GPU NVIDIA detectada"
        echo "    → Drivers propietarios disponibles"
        HAS_NVIDIA=true
    fi
    
    if echo "$GPU_INFO" | grep -qi "amd\|radeon"; then
        echo "  ✓ GPU AMD detectada"
    fi
    
    if echo "$GPU_INFO" | grep -qi "intel"; then
        echo "  ✓ GPU Intel detectada"
    fi
    
    # Disco
    echo ""
    echo -e "${CYAN}Verificando espacio en disco...${NC}"
    DISK_FREE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "  ✓ Espacio libre detectado: ${DISK_FREE}GB"
    
    
    # Laptop detection
    echo ""
    echo -e "${CYAN}Detectando tipo de sistema...${NC}"
    if [ -d /sys/class/power_supply/BAT* ] || [ -d /sys/class/power_supply/battery ]; then
        IS_LAPTOP=true
        echo "  ✓ LAPTOP detectado"
        
        # Guardar en config
        if ! grep -q "IS_LAPTOP=" "$CONFIG_FILE" 2>/dev/null; then
            echo "IS_LAPTOP=true" >> "$CONFIG_FILE"
        fi
    else
        echo "  ✓ DESKTOP detectado"
        IS_LAPTOP=false
    fi
    
    # UEFI/BIOS
    echo ""
    if [ -d /sys/firmware/efi ]; then
        echo "  ✓ Modo: UEFI"
        BOOT_MODE="UEFI"
    else
        echo "  ✓ Modo: BIOS/Legacy"
        BOOT_MODE="BIOS"
    fi
    
    # Resumen
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✓ Detección de hardware completada${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    
    # ============================================================================
    # VERIFICACIÓN DE DEPENDENCIAS
    # ============================================================================
    echo ""
    echo -e "${GREEN}Verificando dependencias del sistema...${NC}"
    run_module "00-check-dependencies" || {
        log_error "Error al verificar dependencias"
        exit 1
    }
    echo ""
    
    # ── Construir la lista de módulos en orden de ejecución ──────────────────
    # Los módulos CORE se ejecutan siempre. Los EXTRA dependen de la config.
    # El orden de inserción en el array define el orden de ejecución.

    MODULES_TO_RUN=()       # nombres técnicos en orden
    MODULES_LABELS=()       # etiquetas legibles en el mismo orden
    MODULES_REQUIRED=()     # "1" si es obligatorio, "0" si es opcional

    # ── CORE: siempre se ejecutan ─────────────────────────────────────────────
    MODULES_TO_RUN+=("01-prepare-disk");      MODULES_LABELS+=("Preparar disco");         MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("02-debootstrap");       MODULES_LABELS+=("Sistema base Ubuntu");    MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("03-configure-base");    MODULES_LABELS+=("Configuración base");     MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("04-install-bootloader"); MODULES_LABELS+=("Bootloader GRUB");       MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("05-configure-network"); MODULES_LABELS+=("Red y NetworkManager");   MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("06-configure-auto-updates"); MODULES_LABELS+=("Actualizaciones automáticas"); MODULES_REQUIRED+=("1")

    # ── GNOME ─────────────────────────────────────────────────────────────────
    if [ "${INSTALL_GNOME:-false}" = "true" ]; then
        MODULES_TO_RUN+=("10-install-gnome-core"); MODULES_LABELS+=("GNOME — entorno gráfico");     MODULES_REQUIRED+=("1")
        MODULES_TO_RUN+=("10-user-config");        MODULES_LABELS+=("GNOME — configuración visual"); MODULES_REQUIRED+=("1")
        [ "${GNOME_OPTIMIZE_MEMORY:-false}" = "true" ] && {
            MODULES_TO_RUN+=("10-optimize"); MODULES_LABELS+=("GNOME — optimización de memoria"); MODULES_REQUIRED+=("0")
        }
        [ "${GNOME_TRANSPARENT_THEME:-false}" = "true" ] && {
            MODULES_TO_RUN+=("10-theme"); MODULES_LABELS+=("GNOME — tema transparente"); MODULES_REQUIRED+=("0")
        }
    fi

    # ── EXTRA: según configuración ────────────────────────────────────────────
    MODULES_TO_RUN+=("13-install-fonts"); MODULES_LABELS+=("Fuentes tipográficas"); MODULES_REQUIRED+=("1")

    [ "${INSTALL_MULTIMEDIA:-false}" = "true" ] && {
        MODULES_TO_RUN+=("12-install-multimedia"); MODULES_LABELS+=("Multimedia — códecs y reproductores"); MODULES_REQUIRED+=("0")
    }
    [ "${HAS_WIFI:-false}" = "true" ] || [ "${HAS_BLUETOOTH:-false}" = "true" ] && {
        MODULES_TO_RUN+=("14-configure-wireless"); MODULES_LABELS+=("WiFi y Bluetooth"); MODULES_REQUIRED+=("0")
    }
    [ "${INSTALL_DEVELOPMENT:-false}" = "true" ] && {
        MODULES_TO_RUN+=("15-install-development"); MODULES_LABELS+=("Herramientas de desarrollo"); MODULES_REQUIRED+=("0")
    }
    [ "${INSTALL_GAMING:-false}" = "true" ] && {
        MODULES_TO_RUN+=("16-configure-gaming"); MODULES_LABELS+=("Gaming — Steam, Heroic, Proton"); MODULES_REQUIRED+=("0")
    }
    [ "${IS_LAPTOP:-false}" = "true" ] && {
        MODULES_TO_RUN+=("21-optimize-laptop"); MODULES_LABELS+=("Optimización laptop (TLP)"); MODULES_REQUIRED+=("0")
    }
    [ "${MINIMIZE_SYSTEMD:-false}" = "true" ] && {
        MODULES_TO_RUN+=("23-minimize-systemd"); MODULES_LABELS+=("Minimizar systemd"); MODULES_REQUIRED+=("0")
    }
    [ "${ENABLE_SECURITY:-false}" = "true" ] && {
        MODULES_TO_RUN+=("24-security-hardening"); MODULES_LABELS+=("Hardening de seguridad"); MODULES_REQUIRED+=("0")
    }

    # ── Sumario visual de módulos seleccionados ───────────────────────────────
    local total=${#MODULES_TO_RUN[@]}
    local core_count=0
    local extra_count=0
    for req in "${MODULES_REQUIRED[@]}"; do
        # Aritmética segura: (( N++ )) falla con set -e cuando N=0
        if [ "$req" = "1" ]; then
            core_count=$(( core_count + 1 ))
        else
            extra_count=$(( extra_count + 1 ))
        fi
    done

    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  PLAN DE INSTALACIÓN — $total módulos${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${DIM}Ubuntu ${UBUNTU_VERSION} · ${HOSTNAME} · ${USERNAME}${NC}"
    echo ""

    local prev_section=""
    for i in "${!MODULES_TO_RUN[@]}"; do
        local mod="${MODULES_TO_RUN[$i]}"
        local label="${MODULES_LABELS[$i]}"
        local req="${MODULES_REQUIRED[$i]}"
        local num=$(( i + 1 ))

        # Separador de sección al cambiar entre CORE y EXTRA
        if [ "$req" = "1" ] && [ "$prev_section" != "core" ]; then
            echo -e "  ${BOLD}CORE${NC} ${DIM}— siempre se ejecutan${NC}"
            prev_section="core"
        elif [ "$req" = "0" ] && [ "$prev_section" != "extra" ]; then
            echo ""
            echo -e "  ${BOLD}EXTRA${NC} ${DIM}— según tu configuración${NC}"
            prev_section="extra"
        fi

        printf "  %2d. %-42s" "$num" "$label"
        if [ "$req" = "1" ]; then
            echo -e "${GREEN}[CORE]${NC}"
        else
            echo -e "${CYAN}[EXTRA]${NC}"
        fi
    done

    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}$core_count módulos CORE${NC}  +  ${CYAN}$extra_count módulos EXTRA${NC}  =  ${BOLD}$total en total${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    read -p "¿Continuar con la instalación? (s/n) [s]: " proceed
    proceed=${proceed:-s}
    if [[ ! $proceed =~ ^[SsYy]$ ]]; then
        echo "Instalación cancelada"
        return
    fi

    # ── Ejecución de módulos ──────────────────────────────────────────────────
    local start_time=$SECONDS
    local modules_ok=0
    local modules_failed=0
    local modules_skipped=0

    for i in "${!MODULES_TO_RUN[@]}"; do
        local mod="${MODULES_TO_RUN[$i]}"
        local label="${MODULES_LABELS[$i]}"
        local req="${MODULES_REQUIRED[$i]}"
        local num=$(( i + 1 ))
        local badge
        [ "$req" = "1" ] && badge="${GREEN}[CORE]${NC}" || badge="${CYAN}[EXTRA]${NC}"

        echo ""
        echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────────────${NC}"
        printf "${BOLD}  %2d/%d  %s${NC}  " "$num" "$total" "$label"
        echo -e "$badge"
        echo -e "${BOLD}${CYAN}────────────────────────────────────────────────────────────────${NC}"
        echo ""

        # Preguntar por módulos EXTRA (los CORE se ejecutan siempre)
        if [ "$req" = "0" ]; then
            read -p "  ¿Ejecutar? (s/n/q=salir) [s]: " ans
            ans=${ans:-s}
            case $ans in
                [Qq]*)
                    echo "Instalación cancelada por el usuario"
                    return 0
                    ;;
                [Nn]*)
                    log_warning "Omitido: $label"
                    modules_skipped=$(( modules_skipped + 1 ))
                    continue
                    ;;
            esac
        fi

        # Ejecutar el módulo — || true evita que set -e mate el script
        local exit_code=0
        run_module "$mod" || exit_code=$?

        if [ "$exit_code" -eq 0 ]; then
            modules_ok=$(( modules_ok + 1 ))
        else
            modules_failed=$(( modules_failed + 1 ))
            if [ "$req" = "1" ]; then
                # CORE fallido: preguntar si abortar
                echo ""
                echo -e "${RED}✗  Módulo CORE fallido: $label${NC}"
                read -p "  ¿Continuar de todas formas? (s/n) [n]: " cont
                cont=${cont:-n}
                if [[ ! $cont =~ ^[SsYy]$ ]]; then
                    echo "Instalación interrumpida en módulo $num/$total"
                    return 1
                fi
            else
                # EXTRA fallido: advertencia y continuar automáticamente
                echo -e "${YELLOW}⚠  Módulo EXTRA fallido, continuando: $label${NC}"
            fi
        fi
    done

    # ── Sumario final de la ejecución ─────────────────────────────────────────
    local elapsed=$(( SECONDS - start_time ))
    local elapsed_min=$(( elapsed / 60 ))
    local elapsed_sec=$(( elapsed % 60 ))

    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  INSTALACIÓN COMPLETADA${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}✓  $modules_ok módulos completados${NC}"
    [ $modules_failed -gt 0 ] && echo -e "  ${RED}✗  $modules_failed módulos con errores${NC}"
    [ $modules_skipped -gt 0 ] && echo -e "  ${YELLOW}⊘  $modules_skipped módulos omitidos${NC}"
    echo ""
    printf "  Tiempo total: %dm %02ds
" "$elapsed_min" "$elapsed_sec"
    echo ""
    echo -e "  ${DIM}Log completo: $LOG_FILE${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    log_success "Instalación completada"

    # ── Limpieza de seguridad: eliminar config.env con contraseñas ────────────
    if [ -f "$CONFIG_FILE" ]; then
        echo ""
        echo -e "${YELLOW}⚠  config.env contiene contraseñas en texto plano.${NC}"
        read -p "  ¿Eliminar config.env ahora? (recomendado) (s/n) [s]: " del_conf
        del_conf=${del_conf:-s}
        if [[ ${del_conf:-s} =~ ^[SsYy]$ ]]; then
            # Sobreescribir antes de borrar para evitar recuperación forense
            dd if=/dev/urandom bs=1 count="$(stat -c%s "$CONFIG_FILE")" 2>/dev/null | \
                tr -dc 'a-zA-Z0-9' | head -c "$(stat -c%s "$CONFIG_FILE")" > "$CONFIG_FILE" 2>/dev/null || true
            rm -f "$CONFIG_FILE"
            echo -e "${GREEN}✓  config.env eliminado de forma segura${NC}"
        else
            echo -e "${YELLOW}⚠  Recuerda eliminarlo manualmente: rm \"$CONFIG_FILE\"${NC}"
        fi
    fi

    # ── Menú post-instalación ─────────────────────────────────────────────────
    post_install_menu
}

# ─────────────────────────────────────────────────────────────────────────────
# post_install_menu — opciones finales tras completar la instalación
# ─────────────────────────────────────────────────────────────────────────────
post_install_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}  ¿QUÉ DESEAS HACER AHORA?${NC}"
        echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "  1) Generar informe del sistema instalado"
        echo "  2) Hacer backup de la configuración"
        echo "  3) Reiniciar y arrancar Ubuntu"
        echo "  4) Salir sin reiniciar"
        echo ""
        read -p "Selecciona opción [3]: " post_choice
        post_choice=${post_choice:-3}
        echo ""

        case $post_choice in
            1)
                run_module "31-generate-report"
                ;;
            2)
                run_module "32-backup-config"
                ;;
            3)
                _do_reboot
                return 0
                ;;
            4)
                echo -e "${YELLOW}⚠  Sistema instalado pero NO reiniciado.${NC}"
                echo -e "${YELLOW}   Recuerda desmontar manualmente antes de apagar:${NC}"
                echo -e "${DIM}   umount -R \"${TARGET:-/mnt/ubuntu}\" && reboot${NC}"
                echo ""
                return 0
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# _do_reboot — desmonta el chroot limpiamente y reinicia
# ─────────────────────────────────────────────────────────────────────────────
_do_reboot() {
    local target="${TARGET:-/mnt/ubuntu}"

    echo -e "${CYAN}Preparando el sistema para reiniciar...${NC}"
    echo ""

    # 1. Terminar procesos que aún usen el chroot
    echo -n "  Cerrando procesos en $target... "
    fuser -km "$target" 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✓${NC}"

    # 2. Desmontar en orden inverso (los más anidados primero)
    local mounts=(
        "$target/dev/pts"
        "$target/dev"
        "$target/run"
        "$target/proc"
        "$target/sys/firmware/efi/efivars"
        "$target/sys"
        "$target/boot/efi"
        "$target"
    )

    echo "  Desmontando sistemas de ficheros..."
    for mnt in "${mounts[@]}"; do
        if mountpoint -q "$mnt" 2>/dev/null; then
            umount -l "$mnt" 2>/dev/null && \
                echo -e "    ${GREEN}✓${NC}  $mnt" || \
                echo -e "    ${YELLOW}⚠${NC}  $mnt (no se pudo desmontar, continuando)"
        fi
    done

    # 3. Sincronizar buffers
    echo -n "  Sincronizando disco... "
    sync
    echo -e "${GREEN}✓${NC}"

    echo ""
    echo -e "${GREEN}✓  Sistema desmontado correctamente${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  REINICIANDO — retira el medio de instalación${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    sleep 3
    reboot
}

##############################################################################
# MAIN
##############################################################################

# Variables globales
DRY_RUN=false
DEBUG_MODE=false

check_root

# Parsear argumentos
if [ $# -gt 0 ]; then
    case "$1" in
        --dry-run)
            echo ""
            echo -e "${YELLOW}⚠  --dry-run no está implementado aún.${NC}"
            echo "   El instalador realizaría cambios reales si continúas."
            echo "   Usa --list para ver los módulos disponibles o --help para más opciones."
            echo ""
            exit 0
            ;;
        --debug)
            DEBUG_MODE=true
            VERBOSE_MODE=true
            set -x  # Mostrar todos los comandos ejecutados
            echo "Modo DEBUG activado (verbose habilitado)"
            shift
            [ $# -eq 0 ] && interactive_config && exit 0
            ;;
        --verbose|-v)
            VERBOSE_MODE=true
            echo "Modo VERBOSE activado (mostrará comandos ejecutados)"
            shift
            [ $# -eq 0 ] && interactive_config && exit 0
            ;;
        --quiet|-q)
            VERBOSE_MODE=false
            echo "Modo QUIET activado (sin comandos de debug)"
            shift
            [ $# -eq 0 ] && interactive_config && exit 0
            ;;
    esac
    
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
            echo "Opciones principales:"
            echo "  --auto, -a           Instalación automática"
            echo "  --interactive, -i    Instalación interactiva"
            echo "  --config, -c         Configuración guiada"
            echo ""
            echo "Opciones de debug:"
            echo "  --verbose, -v        Modo verbose (muestra comandos ejecutados)"
            echo "  --quiet, -q          Modo silencioso (sin debug)"
            echo "  --debug              Modo debug completo (bash -x)"
            echo ""
            echo "Opciones de módulos:"
            echo "  --module NOMBRE, -m  Ejecutar módulo específico"
            echo "  --list, -l           Listar módulos disponibles"
            echo ""
            echo "Otras opciones:"
            echo "  --dry-run            (no implementado aún — avisa si se usa)"
            echo "  --help, -h           Mostrar esta ayuda"
            echo ""
            echo "Nota: Modo verbose está DESACTIVADO por defecto"
            echo "      Para diagnóstico, usa opción 3 en el menú o --verbose"
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

# ============================================================================
# RESUMEN DE MÓDULOS EJECUTADOS
# ============================================================================

if [ -f "$LOG_DIR/module-summary.log" ]; then
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}           RESUMEN DE MÓDULOS EJECUTADOS${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Contar módulos
    TOTAL_MODULES=$(wc -l < "$LOG_DIR/module-summary.log")
    OK_MODULES=$(grep -c "OK$" "$LOG_DIR/module-summary.log" || echo "0")
    FAILED_MODULES=$(grep -c "FAILED" "$LOG_DIR/module-summary.log" || echo "0")
    
    echo -e "Total de módulos ejecutados: ${BOLD}$TOTAL_MODULES${NC}"
    echo -e "Completados exitosamente:    ${GREEN}$OK_MODULES${NC}"
    echo -e "Con errores:                 ${RED}$FAILED_MODULES${NC}"
    echo ""
    
    # Mostrar detalles
    echo "Detalles por módulo:"
    while IFS= read -r line; do
        if echo "$line" | grep -q "OK$"; then
            echo -e "  ${GREEN}✓${NC} $line"
        else
            echo -e "  ${RED}✗${NC} $line"
        fi
    done < "$LOG_DIR/module-summary.log"
    
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Advertencia si hay errores
    if [ $FAILED_MODULES -gt 0 ]; then
        echo -e "${YELLOW}⚠️  ATENCIÓN: Algunos módulos tuvieron errores${NC}"
        echo -e "${YELLOW}   Revisa los logs para más detalles${NC}"
        echo ""
        echo "Logs de errores:"
        echo "  Error general: $ERROR_LOG"
        echo "  Advertencias: $WARNING_LOG"
        echo "  Log completo: $LOG_FILE"
        echo ""
    fi
fi

