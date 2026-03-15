#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# ubuntu-advanced-install — Orquestador principal
#
# Instalador modular de Ubuntu con debootstrap. Cada módulo es un script
# independiente ejecutado como subproceso (bash modules/XX-nombre.sh).
# El orquestador solo gestiona: configuración, validación, orden y logging.
#
# Uso:
#   sudo ./install.sh              Instalación interactiva (recomendado)
#   sudo ./install.sh --auto       Automática (requiere config.env)
#   sudo ./install.sh --help       Ver todas las opciones
#
# Referentes de diseño: setup-alpine (Alpine), archinstall (Arch), Subiquity
# ══════════════════════════════════════════════════════════════════════════════

# NO usamos set -e en el orquestador: los módulos pueden fallar (EXTRA)
# y run_all_modules() maneja el error por módulo. Cada módulo decide
# su propia política de errores (set -e o control manual).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/config.env"
VERSION="4.1.0"

VERBOSE_MODE="${VERBOSE_MODE:-false}"

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

# Trap: solo registra en log, no aborta (los módulos manejan sus errores)
error_handler() {
    local line=$1
    echo "[$(date '+%H:%M:%S')] [TRAP] Error detectado en install.sh:$line" >> "$LOG_FILE"
}

trap - ERR  # Se configura después con status_stop integrado

# Funciones de logging
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

# ── Logging: cada función de log escribe a $LOG_FILE directamente ─────────
# NO usamos exec > >(tee) porque crea un subshell para stdout que puede
# sobrevivir al script y causar EOF prematuro en reads interactivos.
# En su lugar, las funciones log_*() escriben a $LOG_FILE Y a terminal.
# Para capturar la salida de módulos completos, run_module() usa tee por módulo.

log_info "Inicio de instalación Ubuntu"
log_info "Log: $LOG_FILE"
echo ""

# ============================================================================
# STATUS BAR — barra de progreso estilo apt en la última línea
# ============================================================================
# Inspirado en el progress bar de APT (apt-pkg/install-progress.cc).
# Reserva la última fila con scroll region. Muestra:
#
#   Progreso: [ 38%] [########.........................] Gaming — Steam, Heroic, Proton
#
# El output de los módulos scrollea normalmente en la zona superior.

_SPINNER_PID=""
_STATUS_ACTIVE=false

_setup_scroll_region() {
    local rows
    rows=$(tput lines 2>/dev/null) || rows=24
    # Bajar una línea para evitar glitch visual al reducir la zona de scroll
    echo -en "\n"
    # Guardar cursor
    printf "\0337"
    # Scroll region: filas 0..(rows-2); la fila (rows-1) queda fuera
    echo -en "\033[0;$(( rows - 1 ))r"
    # Restaurar cursor y asegurar que está dentro de la zona scrollable
    printf "\0338"
    echo -en "\033[1A"
}

_restore_scroll_region() {
    local rows
    rows=$(tput lines 2>/dev/null) || rows=24
    # Guardar cursor
    printf "\0337"
    # Restaurar scroll region completa
    echo -en "\033[0;${rows}r"
    # Ir a la última línea y limpiarla
    tput cup $(( rows - 1 )) 0 2>/dev/null
    echo -en "\033[0K"
    # Restaurar cursor
    printf "\0338"
}

_draw_status_bar() {
    # $1=texto  $2=porcentaje (0-100, opcional)
    # Layout justificado (estilo apt):
    #   ·[NNN%]·[####....]·texto del módulo·
    #   ^1     margen    barra elástica   texto pegado al margen derecho
    local text="$1"
    local percent="${2:-0}"
    local rows cols pct_str

    rows=$(tput lines 2>/dev/null) || rows=24
    cols=$(tput cols 2>/dev/null) || cols=80

    printf -v pct_str "%3d%%" "$percent"

    # Overhead fijo: " [NNN%] [" + "] " + texto + " "
    #                 1+6+2     2   len   1  = 12 + text_len
    local text_len=${#text}
    local overhead=$(( 12 + text_len ))
    local bar_size=$(( cols - overhead ))
    [ "$bar_size" -lt 8 ] && bar_size=8

    local filled=$(( bar_size * percent / 100 ))
    local empty=$(( bar_size - filled ))

    local fill_str empty_str
    printf -v fill_str "%${filled}s" ""; fill_str="${fill_str// /#}"
    printf -v empty_str "%${empty}s" ""; empty_str="${empty_str// /.}"

    # Guardar cursor → última fila → pintar → restaurar
    printf "\0337"
    tput cup $(( rows - 1 )) 0 2>/dev/null
    printf "\033[0K"
    printf " \033[32;1m[%s]\033[0m [\033[32;1m%s\033[0;2m%s\033[0m] \033[36m%s\033[0m " \
        "$pct_str" "$fill_str" "$empty_str" "$text"
    printf "\0338"
}

_status_loop() {
    # $1=texto  $2=porcentaje fijo
    local text="$1"
    local percent="${2:-0}"
    while true; do
        _draw_status_bar "$text" "$percent"
        sleep 0.3
    done
}

status_start() {
    # $1 = texto  $2 = porcentaje (0-100, opcional)
    status_stop 2>/dev/null
    _setup_scroll_region
    _status_loop "$1" "${2:-0}" &
    _SPINNER_PID=$!
    _STATUS_ACTIVE=true
    disown "$_SPINNER_PID" 2>/dev/null
}

status_stop() {
    if [ -n "$_SPINNER_PID" ] && kill -0 "$_SPINNER_PID" 2>/dev/null; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null
    fi
    _SPINNER_PID=""
    if [ "$_STATUS_ACTIVE" = true ]; then
        _restore_scroll_region
        _STATUS_ACTIVE=false
    fi
}

# Limpiar barra al salir del script
trap 'status_stop 2>/dev/null; error_handler $LINENO' ERR
trap 'status_stop 2>/dev/null' EXIT

# ============================================================================
# CHROOT: usamos arch-chroot (paquete arch-install-scripts)
# ============================================================================
# arch-chroot monta automáticamente /proc, /sys, /dev, /dev/pts, /dev/shm,
# /run y /tmp como pseudofilesystems nuevos (no bind mounts), y los desmonta
# al salir. También configura resolv.conf para DNS.
# No necesitamos funciones chroot_mount/chroot_umount manuales.
# ============================================================================

##############################################################################
# CONFIGURACIÓN INTERACTIVA
##############################################################################

interactive_config() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           CONFIGURACIÓN DE INSTALACIÓN                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ── 1. Sistema base ──────────────────────────────────────────────────────
    echo -e "${YELLOW}[1/7] Sistema base${NC}"
    echo ""
    echo "  Versión de Ubuntu:"
    echo "    1) 24.04 LTS Noble Numbat (recomendado)"
    echo "    2) 22.04 LTS Jammy Jellyfish"
    echo "    3) 20.04 LTS Focal Fossa"
    echo "    4) 25.10 Questing Quokka (no-LTS)"
    echo "    5) 26.04 LTS Resolute Raccoon (en desarrollo)"
    read -p "  Versión [1]: " ver_choice
    case ${ver_choice:-1} in
        1) UBUNTU_VERSION="noble" ;;
        2) UBUNTU_VERSION="jammy" ;;
        3) UBUNTU_VERSION="focal" ;;
        4) UBUNTU_VERSION="questing" ;;
        5) UBUNTU_VERSION="resolute" ;;
        *) UBUNTU_VERSION="noble" ;;
    esac
    echo ""

    # ── 2. Hostname ──────────────────────────────────────────────────────────
    echo -e "${YELLOW}[2/7] Hostname${NC}"
    echo ""
    read -p "  Nombre del equipo [ubuntu]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-ubuntu}
    echo ""

    # ── 3. Usuario ───────────────────────────────────────────────────────────
    echo -e "${YELLOW}[3/7] Usuario${NC}"
    echo ""
    read -p "  Nombre de usuario: " USERNAME
    while [ -z "$USERNAME" ]; do
        echo "  El nombre de usuario no puede estar vacío"
        read -p "  Nombre de usuario: " USERNAME
    done
    echo ""

    echo "  Contraseña para $USERNAME:"
    while true; do
        read -s -p "  Contraseña: " USER_PASSWORD
        echo ""
        read -s -p "  Confirmar:  " USER_PASSWORD_CONFIRM
        echo ""
        if [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ] && [ -n "$USER_PASSWORD" ]; then
            break
        fi
        [ -z "$USER_PASSWORD" ] && echo -e "  ${RED}La contraseña no puede estar vacía${NC}"
        [ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ] && echo -e "  ${RED}Las contraseñas no coinciden${NC}"
        echo ""
    done

    read -p "  ¿Misma contraseña para root? (s/n) [s]: " same_pass
    if [[ ${same_pass:-s} =~ ^[SsYy]$ ]]; then
        ROOT_PASSWORD="$USER_PASSWORD"
    else
        echo ""
        echo "  Contraseña para root:"
        while true; do
            read -s -p "  Contraseña: " ROOT_PASSWORD
            echo ""
            read -s -p "  Confirmar:  " ROOT_PASSWORD_CONFIRM
            echo ""
            if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ] && [ -n "$ROOT_PASSWORD" ]; then
                break
            fi
            [ -z "$ROOT_PASSWORD" ] && echo -e "  ${RED}La contraseña no puede estar vacía${NC}"
            [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ] && echo -e "  ${RED}Las contraseñas no coinciden${NC}"
            echo ""
        done
    fi
    echo ""

    # ── 4. Hardware ──────────────────────────────────────────────────────────
    echo -e "${YELLOW}[4/7] Hardware${NC}"
    echo ""
    echo "  Tipo: 1) Desktop  2) Laptop"
    read -p "  Opción [1]: " hw_choice
    [ "${hw_choice:-1}" = "2" ] && IS_LAPTOP="true" || IS_LAPTOP="false"

    read -p "  ¿WiFi? (s/n) [s]: " has_wifi
    [[ ${has_wifi:-s} =~ ^[SsYy]$ ]] && HAS_WIFI="true" || HAS_WIFI="false"

    read -p "  ¿Bluetooth? (s/n) [s]: " has_bt
    [[ ${has_bt:-s} =~ ^[SsYy]$ ]] && HAS_BLUETOOTH="true" || HAS_BLUETOOTH="false"
    echo ""

    # ── 5. Componentes ───────────────────────────────────────────────────────
    echo -e "${YELLOW}[5/7] Componentes${NC}"
    echo ""

    read -p "  ¿GNOME? (s/n) [s]: " inst_gnome
    [[ ${inst_gnome:-s} =~ ^[SsYy]$ ]] && INSTALL_GNOME="true" || INSTALL_GNOME="false"

    if [ "$INSTALL_GNOME" = "false" ]; then
        GDM_AUTOLOGIN="false"
        GNOME_OPTIMIZE_MEMORY="false"
        GNOME_TRANSPARENT_THEME="false"
        GNOME_DOCK="ubuntu-dock"
    fi

    INSTALL_MULTIMEDIA="true"
    read -p "  ¿Spotify? (s/n) [s]: " opt_spotify
    [[ ${opt_spotify:-s} =~ ^[SsYy]$ ]] && INSTALL_SPOTIFY="s" || INSTALL_SPOTIFY="n"

    read -p "  ¿Desarrollo? (s/n) [n]: " inst_dev
    [[ ${inst_dev:-n} =~ ^[SsYy]$ ]] && INSTALL_DEVELOPMENT="true" || INSTALL_DEVELOPMENT="false"

    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        read -p "    ¿Visual Studio Code? (s/n) [s]: " opt_vscode
        INSTALL_VSCODE="${opt_vscode:-s}"
        echo "    NodeJS: 1) No  2) LTS (recomendado)"
        read -p "    Opción [2]: " opt_nodejs
        NODEJS_OPTION="${opt_nodejs:-2}"
        read -p "    ¿Rust (rustup)? (s/n) [n]: " opt_rust
        INSTALL_RUST="${opt_rust:-n}"
        read -p "    ¿topgrade? (s/n) [s]: " opt_topgrade
        INSTALL_TOPGRADE="${opt_topgrade:-s}"
    else
        INSTALL_VSCODE="n"; NODEJS_OPTION="1"; INSTALL_RUST="n"; INSTALL_TOPGRADE="n"
    fi

    read -p "  ¿Gaming? (s/n) [n]: " inst_gaming
    [[ ${inst_gaming:-n} =~ ^[SsYy]$ ]] && INSTALL_GAMING="true" || INSTALL_GAMING="false"

    if [ "$INSTALL_GAMING" = "true" ]; then
        read -p "    ¿ProtonPlus (gestor Proton/Wine-GE)? (s/n) [s]: " inst_pp
        [[ ${inst_pp:-s} =~ ^[SsYy]$ ]] && INSTALL_PROTONPLUS="true" || INSTALL_PROTONPLUS="false"
        echo ""
        echo "    GPU: 1) AMD  2) Intel  3) Intel+NVIDIA  4) Intel+AMD"
        echo "         5) AMD+AMD  6) AMD+NVIDIA  7) NVIDIA  8) VM  9) Auto"
        read -p "    Opción [9]: " GPU_MANUAL
        GPU_MANUAL="${GPU_MANUAL:-9}"
    else
        INSTALL_PROTONPLUS="false"; GPU_MANUAL="9"
    fi
    echo ""

    # ── 6. Personalización de GNOME ──────────────────────────────────────────
    if [ "$INSTALL_GNOME" = "true" ]; then
        echo -e "${YELLOW}[6/7] Personalización de GNOME${NC}"
        echo ""

        GNOME_OPTIMIZE_MEMORY="true"
        GNOME_TRANSPARENT_THEME="true"

        echo "  Panel: 1) Ubuntu Dock (lateral)  2) Dash to Panel (inferior)"
        read -p "  Opción [2]: " opt_dock
        case "${opt_dock:-2}" in
            1) GNOME_DOCK="ubuntu-dock" ;;
            *) GNOME_DOCK="dash-to-panel" ;;
        esac

        read -p "  ¿Autologin GDM? (s/n) [s]: " inst_autologin
        [[ ${inst_autologin:-s} =~ ^[SsYy]$ ]] && GDM_AUTOLOGIN="true" || GDM_AUTOLOGIN="false"
        echo ""
    fi

    # ── 7. Optimizaciones ────────────────────────────────────────────────────
    echo -e "${YELLOW}[7/7] Optimizaciones${NC}"
    echo ""

    MINIMIZE_SYSTEMD="true"

    echo "  Auto-updates: 1) Solo seguridad  2) Todas  3) No configurar"
    read -p "  Opción [1]: " opt_autoupdate
    AUTO_UPDATE_CHOICE="${opt_autoupdate:-1}"

    if [ "$IS_LAPTOP" = "true" ]; then
        echo "  Energía: 1) power-profiles-daemon  2) TLP"
        read -p "  Opción [1]: " opt_power
        POWER_MANAGER="${opt_power:-1}"
        read -p "  ¿nothrottle (Intel throttling)? (s/n) [n]: " opt_nothrottle
        [[ ${opt_nothrottle:-n} =~ ^[SsYy]$ ]] && INSTALL_NOTHROTTLE="true" || INSTALL_NOTHROTTLE="false"
    else
        POWER_MANAGER="1"; INSTALL_NOTHROTTLE="false"
    fi

    read -p "  ¿Optimizar almacenamiento? (scheduler, fstrim, sysctl) (s/n) [n]: " inst_storage
    [[ ${inst_storage:-n} =~ ^[SsYy]$ ]] && INSTALL_STORAGE_OPT="true" || INSTALL_STORAGE_OPT="false"

    if [ "$INSTALL_STORAGE_OPT" = "true" ]; then
        echo "    Disco: 1) NVMe  2) SSD  3) HDD  4) eMMC"
        read -p "    Opción [2]: " opt_disk_type
        case "${opt_disk_type:-2}" in
            1) STORAGE_DISK_TYPE="nvme" ;;
            2) STORAGE_DISK_TYPE="ssd"  ;;
            3) STORAGE_DISK_TYPE="hdd"  ;;
            4) STORAGE_DISK_TYPE="emmc" ;;
            *) STORAGE_DISK_TYPE="ssd"  ;;
        esac
    else
        STORAGE_DISK_TYPE=""
    fi

    # ── Resumen ──────────────────────────────────────────────────────────────
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 RESUMEN DE CONFIGURACIÓN                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Sistema${NC}"
    echo "  Ubuntu $UBUNTU_VERSION · $HOSTNAME · $USERNAME"
    echo "  $([ "$IS_LAPTOP" = "true" ] && echo "Laptop" || echo "Desktop") · WiFi: $HAS_WIFI · BT: $HAS_BLUETOOTH"
    echo ""
    echo -e "${YELLOW}Componentes${NC}"
    echo "  GNOME: $INSTALL_GNOME$([ "$INSTALL_GNOME" = "true" ] && echo " ($GNOME_DOCK, autologin: $GDM_AUTOLOGIN)")"
    echo "  Multimedia: $INSTALL_MULTIMEDIA$([ "$INSTALL_SPOTIFY" = "s" ] && echo " (+Spotify)")"
    echo "  Desarrollo: $INSTALL_DEVELOPMENT$([ "$INSTALL_DEVELOPMENT" = "true" ] && echo " (VSCode: $INSTALL_VSCODE, Node: $NODEJS_OPTION, Rust: $INSTALL_RUST, topgrade: $INSTALL_TOPGRADE)")"
    echo "  Gaming: $INSTALL_GAMING$([ "$INSTALL_GAMING" = "true" ] && echo " (ProtonPlus: $INSTALL_PROTONPLUS, GPU: $GPU_MANUAL)")"
    echo ""
    echo -e "${YELLOW}Optimizaciones${NC}"
    echo "  systemd: minimizado · auto-updates: opción $AUTO_UPDATE_CHOICE"
    [ "$IS_LAPTOP" = "true" ] && echo "  Energía: $([ "$POWER_MANAGER" = "1" ] && echo "power-profiles-daemon" || echo "TLP") · nothrottle: $INSTALL_NOTHROTTLE"
    echo "  Almacenamiento: $INSTALL_STORAGE_OPT$([ "$INSTALL_STORAGE_OPT" = "true" ] && echo " ($STORAGE_DISK_TYPE)")"
    echo ""

    read -p "¿Guardar configuración? (s/n) [s]: " save_conf
    if [[ ${save_conf:-s} =~ ^[SsYy]$ ]]; then
        save_config
        echo -e "${GREEN}✓ Configuración guardada en $CONFIG_FILE${NC}"
    fi
    echo ""

    export_config_vars
}

##############################################################################
# GUARDAR CONFIGURACIÓN
##############################################################################

save_config() {
    cat > "$CONFIG_FILE" << EOF
# ══════════════════════════════════════════════════════════════════════════════
# ubuntu-advanced-install — config.env
# Generada: $(date)
# Documentación: docs/README.md | Editar y ejecutar: sudo ./install.sh --auto
# ══════════════════════════════════════════════════════════════════════════════

# === SISTEMA BASE ===
UBUNTU_VERSION="$UBUNTU_VERSION"
TARGET_DISK="${TARGET_DISK:-/dev/vda}"
TARGET="${TARGET:-/mnt/ubuntu}"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"

# === CREDENCIALES ===
# Las contraseñas no se almacenan en disco.
# Se piden interactivamente durante la instalación si no están en memoria.
EOF

    cat >> "$CONFIG_FILE" << EOF

# === HARDWARE ===
IS_LAPTOP="$IS_LAPTOP"
HAS_WIFI="$HAS_WIFI"
HAS_BLUETOOTH="$HAS_BLUETOOTH"

# === COMPONENTES ===
INSTALL_GNOME="$INSTALL_GNOME"
GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-true}"
GNOME_OPTIMIZE_MEMORY="${GNOME_OPTIMIZE_MEMORY:-true}"
GNOME_TRANSPARENT_THEME="${GNOME_TRANSPARENT_THEME:-true}"
GNOME_DOCK="${GNOME_DOCK:-dash-to-panel}"
INSTALL_MULTIMEDIA="$INSTALL_MULTIMEDIA"
INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-s}"
INSTALL_DEVELOPMENT="$INSTALL_DEVELOPMENT"
INSTALL_VSCODE="${INSTALL_VSCODE:-s}"
NODEJS_OPTION="${NODEJS_OPTION:-2}"
INSTALL_RUST="${INSTALL_RUST:-n}"
INSTALL_TOPGRADE="${INSTALL_TOPGRADE:-s}"
INSTALL_GAMING="$INSTALL_GAMING"
INSTALL_PROTONPLUS="${INSTALL_PROTONPLUS:-false}"
GPU_MANUAL="${GPU_MANUAL:-9}"
INSTALL_STORAGE_OPT="${INSTALL_STORAGE_OPT:-false}"
STORAGE_DISK_TYPE="${STORAGE_DISK_TYPE:-}"

# === OPTIMIZACIONES ===
MINIMIZE_SYSTEMD="$MINIMIZE_SYSTEMD"
ENABLE_SECURITY="${ENABLE_SECURITY:-false}"
AUTO_UPDATE_CHOICE="${AUTO_UPDATE_CHOICE:-1}"
POWER_MANAGER="${POWER_MANAGER:-1}"
INSTALL_NOTHROTTLE="${INSTALL_NOTHROTTLE:-false}"

# === OPCIONES AVANZADAS ===
DUAL_BOOT="${DUAL_BOOT:-false}"
UBUNTU_SIZE_GB="${UBUNTU_SIZE_GB:-50}"
EOF

    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}✓ Configuración guardada en $CONFIG_FILE${NC}"
    echo -e "${GREEN}✓ Las contraseñas no se escriben a disco${NC}"
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
        log_info "APT progress configurado en chroot: ${TARGET}"
    fi
}

export_config_vars() {
    # Exportar todas las variables de configuración para que los módulos las vean
    export UBUNTU_VERSION
    export TARGET_DISK
    export TARGET
    export HOSTNAME
    export USERNAME

    # Credenciales: solo en memoria, nunca en disco
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
    export GNOME_DOCK
    export INSTALL_MULTIMEDIA
    export INSTALL_SPOTIFY
    export INSTALL_DEVELOPMENT
    export INSTALL_VSCODE
    export NODEJS_OPTION
    export INSTALL_RUST
    export INSTALL_TOPGRADE
    export INSTALL_GAMING
    export INSTALL_PROTONPLUS
    export GPU_MANUAL
    export INSTALL_STORAGE_OPT
    export STORAGE_DISK_TYPE
    export AUTO_UPDATE_CHOICE
    export POWER_MANAGER
    export INSTALL_NOTHROTTLE
    export DUAL_BOOT
    export UBUNTU_SIZE_GB

    # Configurar barra de progreso apt en live y en chroot
    setup_apt_progress
}

##############################################################################
# VALIDACIÓN DE CONFIGURACIÓN
##############################################################################
# Inspirado en: Alpine (setup-alpine valida cada campo), Subiquity (schema),
# archinstall (type validation). Garantiza que config.env es coherente ANTES
# de tocar disco.
##############################################################################

validate_config() {
    local errors=0

    _vfail() { echo -e "  ${RED}✗${NC} $1"; errors=$(( errors + 1 )); }
    _vok()   { echo -e "  ${GREEN}✓${NC} $1"; }

    echo ""
    echo -e "${CYAN}Validando configuración...${NC}"
    echo ""

    # ── Campos obligatorios ──────────────────────────────────────────────────
    [ -n "${UBUNTU_VERSION:-}" ]  && _vok "UBUNTU_VERSION=$UBUNTU_VERSION"  || _vfail "UBUNTU_VERSION no definido"
    [ -n "${HOSTNAME:-}" ]        && _vok "HOSTNAME=$HOSTNAME"              || _vfail "HOSTNAME no definido"
    [ -n "${USERNAME:-}" ]        && _vok "USERNAME=$USERNAME"              || _vfail "USERNAME no definido"
    [ -n "${TARGET:-}" ]          && _vok "TARGET=$TARGET"                  || _vfail "TARGET no definido"

    # ── UBUNTU_VERSION debe ser un codename conocido ─────────────────────────
    local known_versions="focal jammy noble oracular questing resolute"
    if [ -n "${UBUNTU_VERSION:-}" ]; then
        if ! echo "$known_versions" | grep -qw "$UBUNTU_VERSION"; then
            _vfail "UBUNTU_VERSION='$UBUNTU_VERSION' no reconocido (válidos: $known_versions)"
        fi
    fi

    # ── USERNAME: sin espacios, sin caracteres especiales, lowercase ─────────
    if [ -n "${USERNAME:-}" ]; then
        if ! echo "$USERNAME" | grep -qP '^[a-z_][a-z0-9_-]*$'; then
            _vfail "USERNAME='$USERNAME' inválido (debe ser lowercase, sin espacios, empezar con letra)"
        fi
    fi

    # ── Booleanos: deben ser "true" o "false" ────────────────────────────────
    local bool_vars="IS_LAPTOP HAS_WIFI HAS_BLUETOOTH INSTALL_GNOME INSTALL_MULTIMEDIA
                     INSTALL_DEVELOPMENT INSTALL_GAMING INSTALL_PROTONPLUS
                     GDM_AUTOLOGIN GNOME_OPTIMIZE_MEMORY GNOME_TRANSPARENT_THEME
                     MINIMIZE_SYSTEMD ENABLE_SECURITY INSTALL_STORAGE_OPT
                     INSTALL_NOTHROTTLE DUAL_BOOT"
    for var in $bool_vars; do
        local val="${!var:-}"
        if [ -n "$val" ] && [ "$val" != "true" ] && [ "$val" != "false" ]; then
            _vfail "$var='$val' debe ser 'true' o 'false'"
        fi
    done

    # ── Contraseñas: no se almacenan en config.env ─────────────────────────
    # Se piden interactivamente si no están en memoria. No es error que falten.

    # ── TARGET_DISK: si está definido, debe existir como block device ────────
    if [ -n "${TARGET_DISK:-}" ] && [ ! -b "$TARGET_DISK" ]; then
        # Solo avisar, no fallar — puede ser correcto en modo config-only
        echo -e "  ${YELLOW}⚠${NC} TARGET_DISK=$TARGET_DISK no existe como dispositivo de bloque"
    fi

    # ── GNOME_DOCK: valores válidos ──────────────────────────────────────────
    if [ "${INSTALL_GNOME:-}" = "true" ] && [ -n "${GNOME_DOCK:-}" ]; then
        case "$GNOME_DOCK" in
            ubuntu-dock|dash-to-panel) ;;
            *) _vfail "GNOME_DOCK='$GNOME_DOCK' inválido (ubuntu-dock|dash-to-panel)" ;;
        esac
    fi

    # ── GPU_MANUAL: 1-9 ──────────────────────────────────────────────────────
    if [ "${INSTALL_GAMING:-}" = "true" ] && [ -n "${GPU_MANUAL:-}" ]; then
        case "$GPU_MANUAL" in
            [1-9]) ;;
            *) _vfail "GPU_MANUAL='$GPU_MANUAL' fuera de rango (1-9)" ;;
        esac
    fi

    # ── Resultado ────────────────────────────────────────────────────────────
    echo ""
    if [ "$errors" -gt 0 ]; then
        echo -e "${RED}✗ Configuración inválida: $errors errores${NC}"
        echo -e "${YELLOW}  Corrige config.env o ejecuta: $0 --config${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Configuración válida${NC}"
        return 0
    fi
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
            INSTALL_PROTONPLUS="false"
            
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

    # Validar siempre después de cargar
    validate_config || exit 1
}

##############################################################################
# FUNCIONES AUXILIARES
##############################################################################

run_module() {
    local module_name="$1"
    local module_label="${2:-$module_name}"
    local module_num="${3:-}"
    local module_total="${4:-}"
    local module_path="$MODULES_DIR/$module_name.sh"

    if [ ! -f "$module_path" ]; then
        log_error "Módulo no encontrado: $module_name"
        return 1
    fi

    local module_log="$LOG_DIR/${module_name}.log"
    local start_ts=$SECONDS

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  MÓDULO: $module_name${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Exportar contexto para módulos
    export LOG_FILE
    export DEBUG_MODULE="$module_name"

    # Locale limpio para arch-chroot
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export LANGUAGE=C

    # Barra de progreso apt (idempotente)
    setup_apt_progress

    # Status bar: barra estilo apt con porcentaje y texto del módulo
    local status_text="$module_label"
    local percent=0
    if [ -n "$module_num" ] && [ -n "$module_total" ]; then
        status_text="[$module_num/$module_total] $module_label"
        percent=$(( (module_num - 1) * 100 / module_total ))
    fi
    status_start "$status_text" "$percent"

    # ── Ejecutar módulo capturando output a log individual ────────────────────
    # El output va a terminal Y al fichero de log del módulo.
    # Usamos tee en un pipe, no exec > >(tee), para evitar subshells huérfanos.
    local exit_code=0

    if [ "$VERBOSE_MODE" = "true" ]; then
        bash -x "$module_path" 2>&1 | tee -a "$module_log" || exit_code=${PIPESTATUS[0]}
    else
        bash "$module_path" 2>&1 | tee -a "$module_log" || exit_code=${PIPESTATUS[0]}
    fi

    status_stop

    # Append al log principal también
    cat "$module_log" >> "$LOG_FILE" 2>/dev/null || true

    local elapsed=$(( SECONDS - start_ts ))

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

    if [ $exit_code -eq 0 ]; then
        log_success "Módulo completado: $module_name (${elapsed}s)"
        echo "$(date '+%H:%M:%S') [$module_name] OK (${elapsed}s)" >> "$LOG_DIR/module-summary.log"
        echo ""
        return 0
    else
        log_error "Módulo falló: $module_name (exit code: $exit_code, ${elapsed}s)"
        echo "$(date '+%H:%M:%S') [$module_name] FAILED (code: $exit_code, ${elapsed}s)" >> "$LOG_DIR/module-summary.log"
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
    echo -e "${CYAN}║  MENÚ AVANZADO — Módulos individuales y utilidades        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        export_config_vars
        echo -e "  ${DIM}Config: Ubuntu $UBUNTU_VERSION · $HOSTNAME · $USERNAME${NC}"
        echo ""
    fi

    echo -e "${YELLOW}INSTALACIÓN:${NC}"
    echo "  i) Interactiva    a) Automática    c) Solo configurar"
    echo ""

    # Listar módulos disponibles agrupados por prefijo
    echo -e "${YELLOW}BASE (0x):${NC}"
    echo "  00) check-dependencies     04) install-bootloader"
    echo "  01) prepare-disk           05) configure-network"
    echo "  02) debootstrap            06) configure-auto-updates"
    echo "  03) configure-base"
    echo ""
    echo -e "${YELLOW}GNOME (1x):${NC}"
    echo "  10) install-gnome-core     12) optimize-gnome"
    echo "  11) configure-gnome-user   13) configure-gnome-theme"
    echo ""
    echo -e "${YELLOW}SOFTWARE (2x):${NC}"
    echo "  20) install-multimedia     23) install-development"
    echo "  21) install-fonts          24) configure-gaming"
    echo "  22) configure-wireless"
    echo ""
    echo -e "${YELLOW}OPTIMIZACIÓN (3x):${NC}"
    echo "  30) configure-storage      33) minimize-systemd"
    echo "  31) configure-audio        34) security-hardening"
    echo "  32) optimize-laptop"
    echo ""
    echo -e "${YELLOW}POST-INSTALACIÓN (9x):${NC}"
    echo "  90) verify-system          92) backup-config"
    echo "  91) generate-report"
    echo ""
    echo "   q) Salir"
    echo ""
    read -p "Módulo [número]: " choice
    echo ""

    # Resolver: el usuario escribe el número de prefijo del módulo
    local mod_file
    mod_file=$(ls "$MODULES_DIR"/${choice}-*.sh 2>/dev/null | head -1)

    case $choice in
        i) full_interactive_install ;;
        a) full_automatic_install ;;
        c) interactive_config ;;
        q|0) exit 0 ;;
        *)
            if [ -n "$mod_file" ]; then
                run_module "$(basename "$mod_file" .sh)"
            else
                log_error "Módulo $choice no encontrado"
                sleep 1
            fi
            ;;
    esac

    echo ""
    read -p "Presiona Enter para continuar..."
}

##############################################################################
# CONSTRUCCIÓN DE LA LISTA DE MÓDULOS (compartida por ambos modos)
##############################################################################

build_module_list() {
    MODULES_TO_RUN=()
    MODULES_LABELS=()
    MODULES_REQUIRED=()

    # ── CORE ──────────────────────────────────────────────────────────────────
    MODULES_TO_RUN+=("01-prepare-disk");      MODULES_LABELS+=("Preparar disco");         MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("02-debootstrap");       MODULES_LABELS+=("Sistema base Ubuntu");    MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("03-configure-base");    MODULES_LABELS+=("Configuración base");     MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("04-install-bootloader"); MODULES_LABELS+=("Bootloader GRUB");       MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("05-configure-network"); MODULES_LABELS+=("Red y NetworkManager");   MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("06-configure-auto-updates"); MODULES_LABELS+=("Actualizaciones automáticas"); MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("30-configure-storage");      MODULES_LABELS+=("Almacenamiento y swapfile");       MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("31-configure-audio");        MODULES_LABELS+=("Audio plug and play");             MODULES_REQUIRED+=("1")

    # ── GNOME ─────────────────────────────────────────────────────────────────
    if [ "${INSTALL_GNOME:-false}" = "true" ]; then
        MODULES_TO_RUN+=("10-install-gnome-core"); MODULES_LABELS+=("GNOME — entorno gráfico");     MODULES_REQUIRED+=("1")
        MODULES_TO_RUN+=("11-configure-gnome-user");        MODULES_LABELS+=("GNOME — configuración visual"); MODULES_REQUIRED+=("1")
        [ "${GNOME_OPTIMIZE_MEMORY:-false}" = "true" ] && {
            MODULES_TO_RUN+=("12-optimize-gnome"); MODULES_LABELS+=("GNOME — optimización de memoria"); MODULES_REQUIRED+=("0")
        }
        [ "${GNOME_TRANSPARENT_THEME:-false}" = "true" ] && {
            MODULES_TO_RUN+=("13-configure-gnome-theme"); MODULES_LABELS+=("GNOME — tema transparente"); MODULES_REQUIRED+=("0")
        }
    fi

    # ── EXTRA ─────────────────────────────────────────────────────────────────
    MODULES_TO_RUN+=("21-install-fonts"); MODULES_LABELS+=("Fuentes tipográficas"); MODULES_REQUIRED+=("1")

    [ "${INSTALL_MULTIMEDIA:-false}" = "true" ] && {
        MODULES_TO_RUN+=("20-install-multimedia"); MODULES_LABELS+=("Multimedia — códecs y reproductores"); MODULES_REQUIRED+=("0")
    }
    [ "${HAS_WIFI:-false}" = "true" ] || [ "${HAS_BLUETOOTH:-false}" = "true" ] && {
        MODULES_TO_RUN+=("22-configure-wireless"); MODULES_LABELS+=("WiFi y Bluetooth"); MODULES_REQUIRED+=("0")
    }
    [ "${INSTALL_DEVELOPMENT:-false}" = "true" ] && {
        MODULES_TO_RUN+=("23-install-development"); MODULES_LABELS+=("Herramientas de desarrollo"); MODULES_REQUIRED+=("0")
    }
    [ "${INSTALL_GAMING:-false}" = "true" ] && {
        MODULES_TO_RUN+=("24-configure-gaming"); MODULES_LABELS+=("Gaming — Steam, Heroic, Proton"); MODULES_REQUIRED+=("0")
    }
    [ "${IS_LAPTOP:-false}" = "true" ] && {
        MODULES_TO_RUN+=("32-optimize-laptop"); MODULES_LABELS+=("Optimización laptop (TLP)"); MODULES_REQUIRED+=("0")
    }
    [ "${MINIMIZE_SYSTEMD:-false}" = "true" ] && {
        MODULES_TO_RUN+=("33-minimize-systemd"); MODULES_LABELS+=("Minimizar systemd"); MODULES_REQUIRED+=("0")
    }
    [ "${ENABLE_SECURITY:-false}" = "true" ] && {
        MODULES_TO_RUN+=("34-security-hardening"); MODULES_LABELS+=("Hardening de seguridad"); MODULES_REQUIRED+=("0")
    }
}

##############################################################################
# EJECUTAR MÓDULOS (compartido por ambos modos)
##############################################################################

# $1 = "interactive" o "automatic"
run_all_modules() {
    local mode="${1:-interactive}"
    local total=${#MODULES_TO_RUN[@]}
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

        # En modo interactivo, preguntar por módulos EXTRA
        if [ "$mode" = "interactive" ] && [ "$req" = "0" ]; then
            read -p "  ¿Ejecutar? (s/n/q=salir) [s]: " ans
            ans=${ans:-s}
            case $ans in
                [Qq]*) echo "Instalación cancelada por el usuario"; return 0 ;;
                [Nn]*) log_warning "Omitido: $label"; modules_skipped=$(( modules_skipped + 1 )); continue ;;
            esac
        fi

        local exit_code=0
        run_module "$mod" "$label" "$num" "$total" || exit_code=$?

        if [ "$exit_code" -eq 0 ]; then
            modules_ok=$(( modules_ok + 1 ))
        else
            modules_failed=$(( modules_failed + 1 ))
            if [ "$req" = "1" ]; then
                echo ""
                echo -e "${RED}✗  Módulo CORE fallido: $label${NC}"
                if [ "$mode" = "interactive" ]; then
                    read -p "  ¿Continuar de todas formas? (s/n) [n]: " cont
                    if [[ ! ${cont:-n} =~ ^[SsYy]$ ]]; then
                        echo "Instalación interrumpida en módulo $num/$total"
                        return 1
                    fi
                else
                    echo "Instalación automática abortada: módulo CORE falló"
                    return 1
                fi
            else
                echo -e "${YELLOW}⚠  Módulo EXTRA fallido, continuando: $label${NC}"
            fi
        fi
    done

    # ── Sumario ───────────────────────────────────────────────────────────────
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
    printf "  Tiempo total: %dm %02ds\n" "$elapsed_min" "$elapsed_sec"
    echo -e "  ${DIM}Log completo: $LOG_FILE${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    log_success "Instalación completada"
}

##############################################################################
# LIMPIEZA DE CONFIG.ENV CON CONTRASEÑAS
##############################################################################

cleanup_config() {
    [ ! -f "$CONFIG_FILE" ] && return

    if [ "${1:-}" = "auto" ]; then
        # Modo automático: eliminar sin preguntar
        dd if=/dev/urandom bs=1 count="$(stat -c%s "$CONFIG_FILE")" 2>/dev/null | \
            tr -dc 'a-zA-Z0-9' | head -c "$(stat -c%s "$CONFIG_FILE")" > "$CONFIG_FILE" 2>/dev/null || true
        rm -f "$CONFIG_FILE"
        echo -e "${GREEN}✓  config.env eliminado de forma segura${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠  config.env contiene contraseñas en texto plano.${NC}"
        read -p "  ¿Eliminar config.env ahora? (recomendado) (s/n) [s]: " del_conf
        if [[ ${del_conf:-s} =~ ^[SsYy]$ ]]; then
            dd if=/dev/urandom bs=1 count="$(stat -c%s "$CONFIG_FILE")" 2>/dev/null | \
                tr -dc 'a-zA-Z0-9' | head -c "$(stat -c%s "$CONFIG_FILE")" > "$CONFIG_FILE" 2>/dev/null || true
            rm -f "$CONFIG_FILE"
            echo -e "${GREEN}✓  config.env eliminado de forma segura${NC}"
        else
            echo -e "${YELLOW}⚠  Recuerda eliminarlo manualmente: rm \"$CONFIG_FILE\"${NC}"
        fi
    fi
}

##############################################################################
# INSTALACIÓN AUTOMÁTICA (sin preguntas durante ejecución)
##############################################################################

full_automatic_install() {
    check_root
    load_or_create_config
    
    log_step "INSTALACIÓN AUTOMÁTICA COMPLETA"
    
    echo -e "${GREEN}Verificando dependencias del sistema...${NC}"
    run_module "00-check-dependencies" "Verificando dependencias" || { log_error "Error al verificar dependencias"; exit 1; }

    build_module_list
    run_all_modules "automatic" || exit 1

    run_module "91-generate-report" "Generando informe"
    cleanup_config "auto"
    post_install_menu
}

##############################################################################
# INSTALACIÓN INTERACTIVA
##############################################################################

full_interactive_install() {
    check_root
    load_or_create_config
    
    log_step "INSTALACIÓN INTERACTIVA"
    
    # ============================================================================
    # INFORMACIÓN DE HARDWARE (solo informativa — no sobreescribe config)
    # ============================================================================
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  HARDWARE DETECTADO"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # CPU
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs) || true
    echo "  CPU:  ${CPU_MODEL:-desconocida} ($(nproc) cores)"
    
    # RAM
    RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    echo "  RAM:  ${RAM_MB}MB"
    
    # GPU
    GPU_INFO=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | head -2 | sed 's/^/  GPU:  /') || true
    [ -n "$GPU_INFO" ] && echo "$GPU_INFO" || echo "  GPU:  no detectada (VM sin lspci?)"
    
    # Firmware
    [ -d /sys/firmware/efi ] && echo "  Boot: UEFI" || echo "  Boot: BIOS/Legacy"
    
    echo ""
    echo "  Config: $([ "$IS_LAPTOP" = "true" ] && echo "Laptop" || echo "Desktop") · WiFi: $HAS_WIFI · BT: $HAS_BLUETOOTH"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # ── Dependencias ────────────────────────────────────────────────────────
    echo -e "${GREEN}Verificando dependencias del sistema...${NC}"
    run_module "00-check-dependencies" "Verificando dependencias" || { log_error "Error al verificar dependencias"; exit 1; }
    echo ""

    # ── Construir y mostrar plan de instalación ──────────────────────────────
    build_module_list

    local total=${#MODULES_TO_RUN[@]}
    local core_count=0
    local extra_count=0
    for req in "${MODULES_REQUIRED[@]}"; do
        [ "$req" = "1" ] && core_count=$(( core_count + 1 )) || extra_count=$(( extra_count + 1 ))
    done

    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  PLAN DE INSTALACIÓN — $total módulos${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local prev_section=""
    for i in "${!MODULES_TO_RUN[@]}"; do
        local mod="${MODULES_TO_RUN[$i]}"
        local label="${MODULES_LABELS[$i]}"
        local req="${MODULES_REQUIRED[$i]}"

        if [ "$req" = "1" ] && [ "$prev_section" != "core" ]; then
            echo -e "  ${BOLD}CORE${NC} ${DIM}— siempre se ejecutan${NC}"
            prev_section="core"
        elif [ "$req" = "0" ] && [ "$prev_section" != "extra" ]; then
            echo ""
            echo -e "  ${BOLD}EXTRA${NC} ${DIM}— según tu configuración${NC}"
            prev_section="extra"
        fi

        printf "  %2d. %-42s" "$(( i + 1 ))" "$label"
        [ "$req" = "1" ] && echo -e "${GREEN}[CORE]${NC}" || echo -e "${CYAN}[EXTRA]${NC}"
    done

    echo ""
    echo -e "  ${GREEN}$core_count CORE${NC}  +  ${CYAN}$extra_count EXTRA${NC}  =  ${BOLD}$total total${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    read -p "¿Continuar con la instalación? (s/n) [s]: " proceed
    if [[ ! ${proceed:-s} =~ ^[SsYy]$ ]]; then
        echo "Instalación cancelada"
        return
    fi

    # ── Ejecutar ─────────────────────────────────────────────────────────────
    run_all_modules "interactive" || return 1

    run_module "91-generate-report" "Generando informe"
    cleanup_config
    post_install_menu
}

# ─────────────────────────────────────────────────────────────────────────────
# post_install_menu — opciones finales tras completar la instalación
# ─────────────────────────────────────────────────────────────────────────────
post_install_menu() {
    # Asegurar que read usa el terminal real, no un pipe agotado
    # Si stdin no es un terminal (ej. pipe, heredoc agotado), read devuelve
    # EOF instantáneamente → el default "3" dispara reboot en bucle infinito.
    if [ ! -t 0 ]; then
        echo ""
        echo -e "${YELLOW}stdin no es un terminal — reiniciando automáticamente en 10s${NC}"
        echo -e "${YELLOW}(Ctrl+C para cancelar)${NC}"
        sleep 10
        _do_reboot
        return 0
    fi

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
        # read devuelve !=0 en EOF → salir del bucle
        read -p "Selecciona opción [3]: " post_choice || { post_choice=3; break; }
        post_choice=${post_choice:-3}
        echo ""

        case $post_choice in
            1)
                run_module "91-generate-report" "Generando informe"
                ;;
            2)
                run_module "92-backup-config" "Respaldo de configuración"
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

    # Si llegamos aquí por EOF + break con opción 3
    if [ "$post_choice" = "3" ]; then
        _do_reboot
    fi
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
    #    arch-chroot normalmente limpia tras sí, pero si algún mount persiste
    #    (ej. el usuario ejecutó módulos individualmente), limpiamos todo.
    local mounts=(
        "$target/tmp"
        "$target/run"
        "$target/dev/shm"
        "$target/dev/pts"
        "$target/dev"
        "$target/sys/firmware/efi/efivars"
        "$target/sys"
        "$target/proc"
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
    reboot || true
    # Si reboot no terminó el proceso inmediatamente (ej. VM), forzar salida
    sleep 5
    reboot -f 2>/dev/null || true
    exit 0
}

##############################################################################
# MAIN
##############################################################################

check_root

# Parsear argumentos
case "${1:-}" in
    --auto|-a)
        full_automatic_install
        ;;
    --interactive|-i)
        full_interactive_install
        ;;
    --config|-c)
        interactive_config
        ;;
    --module|-m)
        [ -z "${2:-}" ] && { log_error "Especifica módulo: $0 --module NOMBRE"; exit 1; }
        source "$CONFIG_FILE" 2>/dev/null || true
        export_config_vars
        run_module "$2"
        ;;
    --list|-l)
        echo "ubuntu-advanced-install v${VERSION} — Módulos disponibles:"
        echo ""
        local prev_group=""
        for f in "$MODULES_DIR"/[0-9]*.sh; do
            local name=$(basename "$f" .sh)
            local prefix=${name%%-*}
            local group
            case $prefix in
                0[0-9]) group="BASE" ;;
                1[0-9]) group="GNOME" ;;
                2[0-9]) group="SOFTWARE" ;;
                3[0-9]) group="OPTIMIZACIÓN" ;;
                9[0-9]) group="POST-INSTALACIÓN" ;;
                *)      group="OTRO" ;;
            esac
            if [ "$group" != "$prev_group" ]; then
                [ -n "$prev_group" ] && echo ""
                echo "  $group:"
                prev_group="$group"
            fi
            printf "    %-40s %s\n" "$name" "$(head -2 "$f" | grep '^# ' | head -1 | sed 's/^# //')"
        done
        echo ""
        ;;
    --verbose|-v)
        VERBOSE_MODE=true
        export VERBOSE_MODE
        full_interactive_install
        ;;
    --debug)
        VERBOSE_MODE=true
        export VERBOSE_MODE
        set -x
        full_interactive_install
        ;;
    --help|-h)
        cat << HELPEOF
ubuntu-advanced-install v${VERSION}
Instalador modular de Ubuntu con debootstrap

Uso: sudo ./install.sh [opción]

MODOS DE INSTALACIÓN:
  (sin args)          Instalación interactiva guiada (recomendado)
  --auto,    -a       Instalación automática (requiere config.env)
  --verbose, -v       Interactiva con verbose
  --debug             Interactiva con bash -x

CONFIGURACIÓN:
  --config,  -c       Generar config.env interactivamente
  --validate          Validar config.env sin instalar

MÓDULOS:
  --module,  -m NAME  Ejecutar un módulo individual
  --list,    -l       Listar módulos disponibles
  --menu              Menú interactivo de módulos

AYUDA:
  --help,    -h       Esta ayuda
  --version           Mostrar versión

Estructura de módulos:
  0x = Base (disco, debootstrap, red)
  1x = GNOME (escritorio, tema, optimización)
  2x = Software (multimedia, dev, gaming)
  3x = Optimización (storage, audio, laptop, systemd)
  9x = Post-instalación (verify, report, backup)

Config de ejemplo: config.env.example
Documentación:      docs/README.md
HELPEOF
        ;;
    --version)
        echo "ubuntu-advanced-install v${VERSION}"
        ;;
    --validate)
        source "$CONFIG_FILE" 2>/dev/null || { log_error "No se encontró config.env"; exit 1; }
        export_config_vars
        validate_config
        ;;
    --menu)
        while true; do show_menu; done
        ;;
    "")
        # Sin argumentos: instalación interactiva (flujo principal)
        full_interactive_install
        ;;
    *)
        log_error "Opción desconocida: $1 (usa --help)"
        exit 1
        ;;
esac