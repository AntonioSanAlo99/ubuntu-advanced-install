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
#   sudo ./install.sh --auto       Automática (requiere config.yaml)
#   sudo ./install.sh --help       Ver todas las opciones
#
# Referentes de diseño: setup-alpine (Alpine), archinstall (Arch), Subiquity
# ══════════════════════════════════════════════════════════════════════════════

# NO usamos set -e en el orquestador: los módulos pueden fallar (EXTRA)
# y run_all_modules() maneja el error por módulo. Cada módulo decide
# su propia política de errores (set -e o control manual).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_YAML="$SCRIPT_DIR/config.yaml"
VERSION="5.3.0"

VERBOSE_MODE="${VERBOSE_MODE:-false}"

# ============================================================================
# PARSER YAML MINIMALISTA
# ============================================================================
# Lee config.yaml de 1 nivel de anidación y exporta SECCION_CLAVE=valor.
# Solo soporta: strings, booleans, integers. No listas ni maps complejos.
parse_yaml() {
    local yaml_file="$1" section=""
    [ ! -f "$yaml_file" ] && return 1
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*$ ]]; then
            section="${BASH_REMATCH[1]}"; continue
        fi
        if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]+(.*) ]]; then
            local key="${BASH_REMATCH[1]}" val="${BASH_REMATCH[2]}"
            val="${val%%#*}"; val="${val%"${val##*[![:space:]]}"}";
            val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
            local varname; varname="$(echo "${section}_${key}" | tr '[:lower:]' '[:upper:]')"
            export "$varname=$val"
        fi
    done < "$yaml_file"
}

# Mapear variables YAML (SECCION_CLAVE) → variables legacy que los módulos esperan
map_yaml_to_legacy() {
    [ -n "${SYSTEM_UBUNTU_VERSION:-}" ]     && UBUNTU_VERSION="$SYSTEM_UBUNTU_VERSION"
    [ -n "${SYSTEM_TARGET_DISK:-}" ]        && TARGET_DISK="$SYSTEM_TARGET_DISK"
    [ -n "${SYSTEM_TARGET_MOUNT:-}" ]       && TARGET="$SYSTEM_TARGET_MOUNT"
    [ -n "${SYSTEM_HOSTNAME:-}" ]           && HOSTNAME="$SYSTEM_HOSTNAME"
    [ -n "${SYSTEM_USERNAME:-}" ]           && USERNAME="$SYSTEM_USERNAME"
    [ -n "${SYSTEM_IS_LAPTOP:-}" ]          && IS_LAPTOP="$SYSTEM_IS_LAPTOP"
    [ -n "${SYSTEM_DUAL_BOOT:-}" ]          && DUAL_BOOT="$SYSTEM_DUAL_BOOT"
    [ -n "${SYSTEM_DUAL_BOOT_SIZE_GB:-}" ]  && UBUNTU_SIZE_GB="$SYSTEM_DUAL_BOOT_SIZE_GB"
    [ -n "${GNOME_ENABLED:-}" ]             && INSTALL_GNOME="$GNOME_ENABLED"
    [ -n "${GNOME_DOCK:-}" ]                && GNOME_DOCK="$GNOME_DOCK"
    [ -n "${GNOME_AUTOLOGIN:-}" ]           && GDM_AUTOLOGIN="$GNOME_AUTOLOGIN"
    [ -n "${GNOME_OPTIMIZE_MEMORY:-}" ]     && GNOME_OPTIMIZE_MEMORY="$GNOME_OPTIMIZE_MEMORY"
    [ -n "${GNOME_TRANSPARENT_THEME:-}" ]   && GNOME_TRANSPARENT_THEME="$GNOME_TRANSPARENT_THEME"
    [ -n "${MULTIMEDIA_ENABLED:-}" ]        && INSTALL_MULTIMEDIA="$MULTIMEDIA_ENABLED"
    [ -n "${MULTIMEDIA_SPOTIFY:-}" ]        && INSTALL_SPOTIFY="$MULTIMEDIA_SPOTIFY"
    [ -n "${DEVELOPMENT_ENABLED:-}" ]       && INSTALL_DEVELOPMENT="$DEVELOPMENT_ENABLED"
    [ -n "${DEVELOPMENT_VSCODE:-}" ]        && INSTALL_VSCODE="$DEVELOPMENT_VSCODE"
    case "${DEVELOPMENT_NODEJS:-}" in lts) NODEJS_OPTION="2" ;; none) NODEJS_OPTION="1" ;; esac
    [ -n "${DEVELOPMENT_TOPGRADE:-}" ]      && INSTALL_TOPGRADE="$DEVELOPMENT_TOPGRADE"
    [ -n "${DEVELOPMENT_GNOME_BOXES:-}" ]   && INSTALL_BOXES="$DEVELOPMENT_GNOME_BOXES"
    [ -n "${DEVELOPMENT_LAZY_TOOLS:-}" ]    && INSTALL_LAZY_TOOLS="$DEVELOPMENT_LAZY_TOOLS"
    [ -n "${DEVELOPMENT_DOCKER_TOOLS:-}" ]  && INSTALL_DOCKER_TOOLS="$DEVELOPMENT_DOCKER_TOOLS"
    [ -n "${DEVELOPMENT_N8N:-}" ]           && INSTALL_N8N="$DEVELOPMENT_N8N"
    [ -n "${DEVELOPMENT_MELD:-}" ]          && INSTALL_MELD="$DEVELOPMENT_MELD"
    [ -n "${DEVELOPMENT_POSTMAN:-}" ]       && INSTALL_POSTMAN="$DEVELOPMENT_POSTMAN"
    [ -n "${DEVELOPMENT_NETTOOLS:-}" ]      && INSTALL_NETTOOLS="$DEVELOPMENT_NETTOOLS"
    [ -n "${GAMING_ENABLED:-}" ]            && INSTALL_GAMING="$GAMING_ENABLED"
    case "${GAMING_GPU:-auto}" in
        auto) GPU_MANUAL="9" ;; amd) GPU_MANUAL="1" ;; intel) GPU_MANUAL="2" ;;
        intel+nvidia) GPU_MANUAL="3" ;; intel+amd) GPU_MANUAL="4" ;; amd+amd) GPU_MANUAL="5" ;;
        amd+nvidia) GPU_MANUAL="6" ;; nvidia) GPU_MANUAL="7" ;; vm) GPU_MANUAL="8" ;; *) GPU_MANUAL="9" ;;
    esac
    [ -n "${GAMING_PROTONPLUS:-}" ]         && INSTALL_PROTONPLUS="$GAMING_PROTONPLUS"
    [ -n "${GAMING_KERNEL_PSYCACHY:-}" ]    && INSTALL_CACHYOS_KERNEL="$GAMING_KERNEL_PSYCACHY"
    [ -n "${GAMING_PSYCACHY_SCHEDULER:-}" ] && PSYCACHY_SCHEDULER="$GAMING_PSYCACHY_SCHEDULER"
    [ -n "${GAMING_DISCORD:-}" ]            && INSTALL_DISCORD="$GAMING_DISCORD"
    [ -n "${GAMING_STEAM_METHOD:-}" ]       && STEAM_METHOD="$GAMING_STEAM_METHOD"
    [ -n "${EXTRAS_ONLYOFFICE:-}" ]         && INSTALL_ONLYOFFICE="$EXTRAS_ONLYOFFICE"
    [ -n "${EXTRAS_QBITTORRENT:-}" ]        && INSTALL_QBITTORRENT="$EXTRAS_QBITTORRENT"
    [ -n "${EXTRAS_MULLVAD_VPN:-}" ]        && INSTALL_MULLVAD="$EXTRAS_MULLVAD_VPN"
    [ -n "${EXTRAS_OBS_STUDIO:-}" ]         && INSTALL_OBS="$EXTRAS_OBS_STUDIO"
    [ -n "${EXTRAS_OBSIDIAN:-}" ]           && INSTALL_OBSIDIAN="$EXTRAS_OBSIDIAN"
    [ -n "${EXTRAS_GRADIA:-}" ]             && INSTALL_GRADIA="$EXTRAS_GRADIA"
    [ -n "${SYSTEM_TUNING_MINIMIZE_SYSTEMD:-}" ] && MINIMIZE_SYSTEMD="$SYSTEM_TUNING_MINIMIZE_SYSTEMD"
    [ -n "${SYSTEM_TUNING_SECURITY_HARDENING:-}" ] && ENABLE_SECURITY="$SYSTEM_TUNING_SECURITY_HARDENING"
    case "${SYSTEM_TUNING_AUTO_UPDATES:-security}" in
        security) AUTO_UPDATE_CHOICE="1" ;; all) AUTO_UPDATE_CHOICE="2" ;; none) AUTO_UPDATE_CHOICE="3" ;;
    esac
    [ -n "${SYSTEM_TUNING_KERNEL_PARAMS:-}" ] && KERNEL_PARAMS_LEVEL="$SYSTEM_TUNING_KERNEL_PARAMS"
    [ -n "${PERFORMANCE_OOMD_AGGRESSIVE:-}" ]  && PERF_OOMD_AGGRESSIVE="$PERFORMANCE_OOMD_AGGRESSIVE"
    [ -n "${PERFORMANCE_TMPFILES_CLEANUP:-}" ] && PERF_TMPFILES_CLEANUP="$PERFORMANCE_TMPFILES_CLEANUP"
    [ -n "${PERFORMANCE_DNS_OVER_TLS:-}" ]     && PERF_DNS_OVER_TLS="$PERFORMANCE_DNS_OVER_TLS"
    [ -n "${LAPTOP_NOTHROTTLE:-}" ]         && INSTALL_NOTHROTTLE="$LAPTOP_NOTHROTTLE"
}

# ============================================================================
# EXPORTAR VARIABLES — las expone al entorno para subprocesos (módulos)
# ============================================================================
# Los módulos se ejecutan con `bash modules/XX.sh` (subproceso), por lo que
# solo ven variables exportadas. Esta función exporta TODAS las variables
# de configuración que cualquier módulo pueda necesitar.
#
# Además, escribe config.yaml en la raíz del proyecto para que los módulos
# puedan leerlo directamente cuando se ejecutan de forma individual
# (--module XX) sin haber pasado por interactive_config().
# ============================================================================

export_config_vars() {
    # ── Sistema ──────────────────────────────────────────────────────────────
    export UBUNTU_VERSION="${UBUNTU_VERSION:-noble}"
    export TARGET_DISK="${TARGET_DISK:-/dev/vda}"
    export TARGET="${TARGET:-/mnt/ubuntu}"
    export HOSTNAME="${HOSTNAME:-ubuntu}"
    export USERNAME="${USERNAME:-}"
    export USER_PASSWORD="${USER_PASSWORD:-}"
    export ROOT_PASSWORD="${ROOT_PASSWORD:-}"
    export IS_LAPTOP="${IS_LAPTOP:-false}"
    export DUAL_BOOT="${DUAL_BOOT:-false}"
    export UBUNTU_SIZE_GB="${UBUNTU_SIZE_GB:-50}"

    # ── GNOME ────────────────────────────────────────────────────────────────
    export INSTALL_GNOME="${INSTALL_GNOME:-true}"
    export GNOME_DOCK="${GNOME_DOCK:-dash-to-panel}"
    export GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-true}"
    export GNOME_OPTIMIZE_MEMORY="${GNOME_OPTIMIZE_MEMORY:-true}"
    export GNOME_TRANSPARENT_THEME="${GNOME_TRANSPARENT_THEME:-true}"

    # ── Multimedia ───────────────────────────────────────────────────────────
    export INSTALL_MULTIMEDIA="${INSTALL_MULTIMEDIA:-true}"
    export INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-true}"

    # ── Desarrollo ───────────────────────────────────────────────────────────
    export INSTALL_DEVELOPMENT="${INSTALL_DEVELOPMENT:-false}"
    export INSTALL_VSCODE="${INSTALL_VSCODE:-false}"
    export NODEJS_OPTION="${NODEJS_OPTION:-2}"
    export INSTALL_TOPGRADE="${INSTALL_TOPGRADE:-false}"
    export INSTALL_BOXES="${INSTALL_BOXES:-false}"
    export INSTALL_LAZY_TOOLS="${INSTALL_LAZY_TOOLS:-false}"
    export INSTALL_DOCKER_TOOLS="${INSTALL_DOCKER_TOOLS:-false}"
    export INSTALL_N8N="${INSTALL_N8N:-false}"
    export INSTALL_MELD="${INSTALL_MELD:-false}"
    export INSTALL_POSTMAN="${INSTALL_POSTMAN:-false}"
    export INSTALL_NETTOOLS="${INSTALL_NETTOOLS:-false}"

    # ── Gaming ───────────────────────────────────────────────────────────────
    export INSTALL_GAMING="${INSTALL_GAMING:-false}"
    export GPU_MANUAL="${GPU_MANUAL:-9}"
    export INSTALL_PROTONPLUS="${INSTALL_PROTONPLUS:-false}"
    export INSTALL_DISCORD="${INSTALL_DISCORD:-false}"
    export STEAM_METHOD="${STEAM_METHOD:-1}"
    export INSTALL_CACHYOS_KERNEL="${INSTALL_CACHYOS_KERNEL:-false}"
    export PSYCACHY_SCHEDULER="${PSYCACHY_SCHEDULER:-bore}"

    # ── Extras ───────────────────────────────────────────────────────────────
    export INSTALL_ONLYOFFICE="${INSTALL_ONLYOFFICE:-false}"
    export INSTALL_QBITTORRENT="${INSTALL_QBITTORRENT:-false}"
    export INSTALL_MULLVAD="${INSTALL_MULLVAD:-false}"
    export INSTALL_OBS="${INSTALL_OBS:-false}"
    export INSTALL_OBSIDIAN="${INSTALL_OBSIDIAN:-false}"
    export INSTALL_GRADIA="${INSTALL_GRADIA:-false}"

    # ── Optimizaciones ───────────────────────────────────────────────────────
    export MINIMIZE_SYSTEMD="${MINIMIZE_SYSTEMD:-true}"
    export ENABLE_SECURITY="${ENABLE_SECURITY:-false}"
    export AUTO_UPDATE_CHOICE="${AUTO_UPDATE_CHOICE:-1}"
    export KERNEL_PARAMS_LEVEL="${KERNEL_PARAMS_LEVEL:-1}"

    # ── Performance ──────────────────────────────────────────────────────────
    export PERF_OOMD_AGGRESSIVE="${PERF_OOMD_AGGRESSIVE:-true}"
    export PERF_TMPFILES_CLEANUP="${PERF_TMPFILES_CLEANUP:-true}"
    export PERF_DNS_OVER_TLS="${PERF_DNS_OVER_TLS:-true}"

    # ── Laptop ───────────────────────────────────────────────────────────────
    export INSTALL_NOTHROTTLE="${INSTALL_NOTHROTTLE:-false}"

    # ── WiFi/Bluetooth (autodetectados, pero pasados a módulos) ──────────────
    export HAS_WIFI="${HAS_WIFI:-true}"
    export HAS_BLUETOOTH="${HAS_BLUETOOTH:-true}"
}

# ============================================================================
# VALIDAR CONFIGURACIÓN — aborta si faltan valores imprescindibles
# ============================================================================

validate_config() {
    local errors=0

    if [ -z "${USERNAME:-}" ]; then
        log_error "USERNAME no definido — imprescindible para la instalación"
        errors=$(( errors + 1 ))
    fi

    if [ -z "${UBUNTU_VERSION:-}" ]; then
        log_error "UBUNTU_VERSION no definido"
        errors=$(( errors + 1 ))
    fi

    if [ -z "${HOSTNAME:-}" ]; then
        log_error "HOSTNAME no definido"
        errors=$(( errors + 1 ))
    fi

    # Validar que GNOME_DOCK tiene valor válido
    case "${GNOME_DOCK:-}" in
        ubuntu-dock|dash-to-panel) ;;
        *) log_warning "GNOME_DOCK='${GNOME_DOCK:-}' no reconocido — usando dash-to-panel"
           GNOME_DOCK="dash-to-panel" ;;
    esac

    # Validar que KERNEL_PARAMS_LEVEL es 1-4
    case "${KERNEL_PARAMS_LEVEL:-1}" in
        1|2|3|4) ;;
        *) log_warning "KERNEL_PARAMS_LEVEL='${KERNEL_PARAMS_LEVEL:-}' inválido — usando 1"
           KERNEL_PARAMS_LEVEL="1" ;;
    esac

    if [ $errors -gt 0 ]; then
        log_error "Configuración inválida ($errors errores). Corrige antes de continuar."
        return 1
    fi

    log_success "Configuración validada"
    return 0
}

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
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Trap: registra en log + muestra warning visible. No aborta porque los módulos
# gestionan sus propios errores y run_all_modules decide si continuar o no.
error_handler() {
    local line=$1
    local msg="[TRAP] Error detectado en install.sh:$line"
    echo "[$(date '+%H:%M:%S')] $msg" >> "$LOG_FILE"
    echo -e "\033[0;33m⚠ $msg\033[0m" >&2
}


# Funciones de logging
_log() {
    # $1=level $2=icon $3=color $4=message
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$4" >> "$LOG_FILE"
    echo -e "${3}${2}${NC} $4"
}
log_step()    { printf '[%s] [STEP] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; echo ""; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}▶ $1${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
log_success() { _log SUCCESS "✓" "$GREEN" "$1"; }
log_error()   { _log ERROR "✗" "$RED" "$1"; }
log_warning() { _log WARNING "⚠" "$YELLOW" "$1"; }
log_info()    { _log INFO "ℹ" "$BLUE" "$1"; }
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Log silencioso — el banner se muestra en el MAIN, no aquí
printf '[%s] [INFO] Inicio de instalación Ubuntu\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
printf '[%s] [INFO] Log: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOG_FILE" >> "$LOG_FILE"

# ============================================================================
# BARRA DE PROGRESO — fija en la última línea del terminal
# ============================================================================
# Arquitectura: UN SOLO PROCESO escribe al terminal.
#
# 1. _bar_init() activa scroll region (filas 1..N-1), barra en fila N
# 2. Módulo en background: stdout → FIFO vía tee (log), stderr → /dev/tty
# 3. Loop principal lee FIFO, imprime cada línea (scrollea en 1..N-1),
#    repinta barra en fila N
# 4. _bar_cleanup() restaura scroll region completa
#
# Dpkg::Progress-Fancy DESACTIVADO en setup_apt_progress() porque sus \r
# no funcionan a través del pipe (cada \r se convierte en línea nueva).
#
# stdin del módulo ← /dev/tty → reads interactivos funcionan.
# stderr del módulo → /dev/tty → prompts de read -p aparecen sin buffering.

_BAR_ACTIVE=false
_TERM_ROWS=24
_TERM_COLS=80

_update_term_size() {
    _TERM_ROWS=$(tput lines 2>/dev/null) || _TERM_ROWS=24
    _TERM_COLS=$(tput cols 2>/dev/null) || _TERM_COLS=80
}
_update_term_size
trap '_update_term_size' WINCH

_bar_init() {
    _update_term_size
    # Scroll region: filas 1 a N-1
    printf '\033[1;%dr' "$(( _TERM_ROWS - 1 ))"
    printf '\033[%d;1H' "$(( _TERM_ROWS - 1 ))"
}

_bar_paint() {
    # $1=texto  $2=porcentaje
    local text="$1" pct="${2:-0}"
    [ "$pct" -gt 100 ] && pct=100
    [ "$pct" -lt 0 ] && pct=0

    local pct_str
    printf -v pct_str "%3d%%" "$pct"

    local overhead=$(( 12 + ${#text} ))
    local bar_size=$(( _TERM_COLS - overhead ))
    [ "$bar_size" -lt 8 ] && bar_size=8

    local filled=$(( bar_size * pct / 100 ))
    local empty=$(( bar_size - filled ))
    local fill_str empty_str
    printf -v fill_str "%${filled}s" ""; fill_str="${fill_str// /#}"
    printf -v empty_str "%${empty}s" ""; empty_str="${empty_str// /.}"

    # Guardar cursor → fila N → limpiar → pintar → restaurar cursor
    printf '\0337'
    printf '\033[%d;1H' "$_TERM_ROWS"
    printf '\033[2K'
    printf ' \033[32;1m[%s]\033[0m [\033[32;1m%s\033[0;2m%s\033[0m] \033[36m%s\033[0m' \
        "$pct_str" "$fill_str" "$empty_str" "$text"
    printf '\0338'
}

_bar_cleanup() {
    [ "$_BAR_ACTIVE" = true ] || return 0
    _update_term_size
    # Restaurar scroll region completa
    printf '\033[1;%dr' "$_TERM_ROWS"
    # Limpiar fila de la barra
    printf '\0337\033[%d;1H\033[2K\0338' "$_TERM_ROWS"
    _BAR_ACTIVE=false
}

run_module_with_bar() {
    # $1=module_path $2=module_log $3=bar_text $4=start_pct $5=end_pct $6=verbose
    local module_path="$1" module_log="$2" bar_text="$3"
    local start_pct="${4:-0}" end_pct="${5:-100}" verbose="${6:-false}"
    local range=$(( end_pct - start_pct ))
    local fifo exit_file
    fifo=$(mktemp -u /tmp/.mod-fifo.XXXXXX)
    exit_file=$(mktemp /tmp/.mod-exit.XXXXXX)
    mkfifo "$fifo"

    _BAR_ACTIVE=true
    _bar_init
    _bar_paint "$bar_text" "$start_pct"

    # Módulo en background:
    # - stdout → FIFO vía tee (para log + barra de progreso)
    # - stderr → /dev/tty (prompts de read -p aparecen sin buffering)
    # - stdin ← /dev/tty (para read interactivos)
    # En modo verbose: stderr también al pipe (bash -x traces)
    {
        if [ "$verbose" = "true" ]; then
            bash -x "$module_path" 2>&1
        else
            bash "$module_path" 2>/dev/tty
        fi
        echo $? >&3
    } 3>"$exit_file" < /dev/tty | tee -a "$module_log" > "$fifo" &
    local bg_pid=$!

    # Leer FIFO línea a línea — único escritor al terminal
    local n=0
    while IFS= read -r line; do
        printf '%s\n' "$line"
        n=$(( n + 1 ))
        if [ "$range" -gt 0 ]; then
            local p=$(( range * n / (n + 30) ))
            local pct=$(( start_pct + p ))
            [ "$pct" -ge "$end_pct" ] && pct=$(( end_pct - 1 ))
            _bar_paint "$bar_text" "$pct"
        fi
    done < "$fifo"

    wait "$bg_pid" 2>/dev/null
    # Esperar a que fd3 se cierre completamente y el fichero tenga contenido
    sync 2>/dev/null || true
    local exit_code=""
    if [ -f "$exit_file" ] && [ -s "$exit_file" ]; then
        exit_code=$(head -1 "$exit_file" 2>/dev/null | tr -dc '0-9')
    fi
    # Si el fichero está vacío o no es numérico, asumir fallo (no enmascarar)
    if [ -z "$exit_code" ]; then
        exit_code=1
        echo "[WARNING] No se pudo capturar exit code del módulo — asumiendo fallo" >&2
    fi
    rm -f "$fifo" "$exit_file"

    _bar_paint "$bar_text" "$end_pct"
    _bar_cleanup

    return "$exit_code"
}

trap '_bar_cleanup 2>/dev/null; error_handler $LINENO' ERR
trap '_bar_cleanup 2>/dev/null' EXIT

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

##############################################################################
# HELPER: Convertir respuesta s/n de read a true/false
##############################################################################
# Uso: VAR=$(_yn "respuesta" "default")
#   "" + default "false" → "false"
#   "s"/"S"/"y"/"Y" → "true"
#   cualquier otra cosa → "false"
_yn() {
    local answer="${1:-}" default="${2:-false}"
    [ -z "$answer" ] && { echo "$default"; return; }
    [[ "$answer" =~ ^[SsYy]$ ]] && echo "true" || echo "false"
}

##############################################################################
# CONFIGURACIÓN INTERACTIVA
##############################################################################

interactive_config() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           CONFIGURACIÓN DE INSTALACIÓN                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ══════════════════════════════════════════════════════════════════════════
    # PASO 1: SISTEMA BASE (siempre)
    # ══════════════════════════════════════════════════════════════════════════
    echo -e "${YELLOW}[1/6] Sistema base${NC}"
    echo ""
    echo "  Versión de Ubuntu:"
    echo "    1) 24.04 LTS Noble Numbat (recomendado)"
    echo "    2) 22.04 LTS Jammy Jellyfish"
    echo "    3) 20.04 LTS Focal Fossa"
    echo "    4) 25.10 Questing Quokka (no-LTS)"
    echo "    5) 26.04 LTS Resolute Raccoon (en desarrollo)"
    read -p "  Versión [1]: " ver_choice
    case ${ver_choice:-1} in
        1) UBUNTU_VERSION="noble" ;; 2) UBUNTU_VERSION="jammy" ;;
        3) UBUNTU_VERSION="focal" ;; 4) UBUNTU_VERSION="questing" ;;
        5) UBUNTU_VERSION="resolute" ;; *) UBUNTU_VERSION="noble" ;;
    esac
    echo ""

    read -p "  Nombre del equipo [ubuntu]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-ubuntu}
    echo ""

    read -p "  Nombre de usuario: " USERNAME
    while [ -z "$USERNAME" ]; do
        echo "  El nombre de usuario no puede estar vacío"
        read -p "  Nombre de usuario: " USERNAME
    done
    echo ""

    echo "  Contraseña para $USERNAME:"
    while true; do
        read -s -p "  Contraseña: " USER_PASSWORD; echo ""
        read -s -p "  Confirmar:  " USER_PASSWORD_CONFIRM; echo ""
        [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ] && [ -n "$USER_PASSWORD" ] && break
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
            read -s -p "  Contraseña: " ROOT_PASSWORD; echo ""
            read -s -p "  Confirmar:  " ROOT_PASSWORD_CONFIRM; echo ""
            [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ] && [ -n "$ROOT_PASSWORD" ] && break
            [ -z "$ROOT_PASSWORD" ] && echo -e "  ${RED}La contraseña no puede estar vacía${NC}"
            [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ] && echo -e "  ${RED}Las contraseñas no coinciden${NC}"
            echo ""
        done
    fi
    echo ""

    echo "  Tipo: 1) Desktop  2) Laptop"
    read -p "  Opción [1]: " hw_choice
    [ "${hw_choice:-1}" = "2" ] && IS_LAPTOP="true" || IS_LAPTOP="false"
    HAS_WIFI="true"; HAS_BLUETOOTH="true"
    echo ""

    # ══════════════════════════════════════════════════════════════════════════
    # PASO 2: PERFIL
    # ══════════════════════════════════════════════════════════════════════════
    echo -e "${YELLOW}[2/6] Perfil de instalación${NC}"
    echo ""
    echo "  1) Escritorio     — GNOME + multimedia"
    echo "  2) Desarrollo     — Escritorio + todas las herramientas dev"
    echo "  3) Gaming         — Escritorio + Steam/Heroic/Faugus/ProtonPlus"
    echo "  4) Completo       — Todo activado"
    echo "  5) Servidor       — Sin GUI (solo CLI + dev opcional)"
    echo "  6) Personalizado  — Elegir cada componente manualmente"
    echo ""
    read -p "  Perfil [1]: " profile_choice
    profile_choice=${profile_choice:-1}

    # ── Pre-rellenar variables según perfil ───────────────────────────────────
    # Defaults conservadores (todo OFF)
    INSTALL_GNOME="false"; INSTALL_MULTIMEDIA="false"; INSTALL_SPOTIFY="false"
    GNOME_OPTIMIZE_MEMORY="false"; GNOME_TRANSPARENT_THEME="false"
    INSTALL_DEVELOPMENT="false"; INSTALL_VSCODE="false"; NODEJS_OPTION="1"
    INSTALL_TOPGRADE="false"; INSTALL_BOXES="false"; INSTALL_LAZY_TOOLS="false"
    INSTALL_DOCKER_TOOLS="false"; INSTALL_N8N="false"; INSTALL_MELD="false"
    INSTALL_POSTMAN="false"; INSTALL_NETTOOLS="false"
    INSTALL_GAMING="false"; INSTALL_PROTONPLUS="false"; INSTALL_DISCORD="false"
    STEAM_METHOD="2"; INSTALL_CACHYOS_KERNEL="false"; PSYCACHY_SCHEDULER="bore"
    GPU_MANUAL="9"
    INSTALL_ONLYOFFICE="false"; INSTALL_QBITTORRENT="false"; INSTALL_OBS="false"
    INSTALL_OBSIDIAN="false"; INSTALL_GRADIA="false"; INSTALL_MULLVAD="false"
    GDM_AUTOLOGIN="true"; GNOME_DOCK="dash-to-panel"
    INSTALL_NOTHROTTLE="false"

    case $profile_choice in
        1) # ── Escritorio ────────────────────────────────────────────────────
            INSTALL_GNOME="true"; INSTALL_MULTIMEDIA="true"
            GNOME_OPTIMIZE_MEMORY="true"; GNOME_TRANSPARENT_THEME="true"
            echo -e "  ${GREEN}✓ Perfil Escritorio${NC} — GNOME + multimedia"
            ;;
        2) # ── Desarrollo ────────────────────────────────────────────────────
            INSTALL_GNOME="true"; INSTALL_MULTIMEDIA="true"
            GNOME_OPTIMIZE_MEMORY="true"; GNOME_TRANSPARENT_THEME="true"
            INSTALL_DEVELOPMENT="true"; INSTALL_VSCODE="true"; NODEJS_OPTION="2"
            INSTALL_TOPGRADE="true"; INSTALL_BOXES="true"; INSTALL_LAZY_TOOLS="true"
            INSTALL_DOCKER_TOOLS="true"; INSTALL_N8N="true"; INSTALL_MELD="true"
            INSTALL_POSTMAN="true"; INSTALL_NETTOOLS="true"
            echo -e "  ${GREEN}✓ Perfil Desarrollo${NC} — Escritorio + todo dev activado"
            ;;
        3) # ── Gaming ────────────────────────────────────────────────────────
            INSTALL_GNOME="true"; INSTALL_MULTIMEDIA="true"
            GNOME_OPTIMIZE_MEMORY="true"; GNOME_TRANSPARENT_THEME="true"
            INSTALL_GAMING="true"; INSTALL_PROTONPLUS="true"
            echo -e "  ${GREEN}✓ Perfil Gaming${NC} — Escritorio + Steam/Heroic/Faugus"
            ;;
        4) # ── Completo ──────────────────────────────────────────────────────
            INSTALL_GNOME="true"; INSTALL_MULTIMEDIA="true"
            GNOME_OPTIMIZE_MEMORY="true"; GNOME_TRANSPARENT_THEME="true"
            INSTALL_DEVELOPMENT="true"; INSTALL_VSCODE="true"; NODEJS_OPTION="2"
            INSTALL_TOPGRADE="true"; INSTALL_BOXES="true"; INSTALL_LAZY_TOOLS="true"
            INSTALL_DOCKER_TOOLS="true"; INSTALL_N8N="true"; INSTALL_MELD="true"
            INSTALL_POSTMAN="true"; INSTALL_NETTOOLS="true"
            INSTALL_GAMING="true"; INSTALL_PROTONPLUS="true"; INSTALL_DISCORD="true"
            INSTALL_CACHYOS_KERNEL="true"
            echo -e "  ${GREEN}✓ Perfil Completo${NC} — Todo activado"
            ;;
        5) # ── Servidor ──────────────────────────────────────────────────────
            GDM_AUTOLOGIN="false"; GNOME_DOCK="ubuntu-dock"
            echo -e "  ${GREEN}✓ Perfil Servidor${NC} — Sin GUI"
            echo ""
            # Desarrollo es la única opción interactiva en servidor
            read -p "  ¿Desarrollo (git, build-essential, python, etc.)? (s/n) [n]: " inst_dev
            if [[ ${inst_dev:-n} =~ ^[SsYy]$ ]]; then
                INSTALL_DEVELOPMENT="true"; INSTALL_VSCODE="false"; NODEJS_OPTION="1"
                INSTALL_TOPGRADE="true"; INSTALL_LAZY_TOOLS="true"
                INSTALL_DOCKER_TOOLS="true"; INSTALL_N8N="true"
                INSTALL_NETTOOLS="true"
                echo -e "  ${GREEN}✓ Desarrollo CLI activado${NC}"
            fi
            ;;
        6) # ── Personalizado ─────────────────────────────────────────────────
            echo -e "  ${CYAN}✓ Modo personalizado${NC}"
            echo ""
            _interactive_custom
            ;;
    esac
    echo ""

    # ══════════════════════════════════════════════════════════════════════════
    # PASO 3: ADDON GAMING (si el perfil no lo incluye)
    # ══════════════════════════════════════════════════════════════════════════
    if [ "$INSTALL_GNOME" = "true" ] && [ "$INSTALL_GAMING" = "false" ] && [ "$profile_choice" != "6" ]; then
        read -p "  ¿Añadir gaming? (Steam/Heroic/Faugus/ProtonPlus) (s/n) [n]: " addon_gaming
        if [[ ${addon_gaming:-n} =~ ^[SsYy]$ ]]; then
            INSTALL_GAMING="true"; INSTALL_PROTONPLUS="true"
            echo -e "  ${GREEN}✓ Gaming añadido${NC}"
        fi
        echo ""
    fi

    # ── Gaming extras (si gaming activo) ─────────────────────────────────────
    if [ "$INSTALL_GAMING" = "true" ] && [ "$profile_choice" != "6" ]; then
        echo -e "${YELLOW}  Gaming — opciones adicionales${NC}"
        read -p "    ¿Discord? (s/n) [n]: " INSTALL_DISCORD
        INSTALL_DISCORD=$(_yn "$INSTALL_DISCORD" "false")

        echo "    Steam: 1) GLFS tarball  2) .deb Valve (recomendado)  3) SteamRT3 (experimental)"
        read -p "    Opción [2]: " opt_steam
        STEAM_METHOD="${opt_steam:-2}"

        read -p "    ¿Kernel PsyCachy? (s/n) [n]: " inst_cachy
        if [[ ${inst_cachy:-n} =~ ^[SsYy]$ ]]; then
            INSTALL_CACHYOS_KERNEL="true"
            echo "      Scheduler: 1) BORE (gaming)  2) EEVDF (allround)"
            read -p "      Opción [1]: " opt_sched
            [[ "${opt_sched:-1}" = "2" ]] && PSYCACHY_SCHEDULER="eevdf" || PSYCACHY_SCHEDULER="bore"
        fi

        echo "    GPU: 1) AMD  2) Intel  3) Intel+NVIDIA  4) Intel+AMD"
        echo "         5) AMD+AMD  6) AMD+NVIDIA  7) NVIDIA  8) VM  9) Auto"
        read -p "    Opción [9]: " GPU_MANUAL
        GPU_MANUAL="${GPU_MANUAL:-9}"
        echo ""
    fi

    # ══════════════════════════════════════════════════════════════════════════
    # PASO 4: AJUSTES (siempre, fuera del perfil)
    # ══════════════════════════════════════════════════════════════════════════
    if [ "$profile_choice" != "6" ]; then
        echo -e "${YELLOW}[3/6] Ajustes${NC}"
        echo ""

        if [ "$INSTALL_GNOME" = "true" ]; then
            echo "  Panel: 1) Ubuntu Dock (lateral)  2) Dash to Panel (inferior)"
            read -p "  Opción [2]: " opt_dock
            case "${opt_dock:-2}" in
                1) GNOME_DOCK="ubuntu-dock" ;;
                *) GNOME_DOCK="dash-to-panel" ;;
            esac

            read -p "  ¿Autologin GDM? (s/n) [s]: " inst_autologin
            [[ ${inst_autologin:-s} =~ ^[SsYy]$ ]] && GDM_AUTOLOGIN="true" || GDM_AUTOLOGIN="false"
        fi

        MINIMIZE_SYSTEMD="true"


        if [ "$IS_LAPTOP" = "true" ]; then
            read -p "  ¿nothrottle (Intel throttling)? (s/n) [n]: " opt_nothrottle
            [[ ${opt_nothrottle:-n} =~ ^[SsYy]$ ]] && INSTALL_NOTHROTTLE="true" || INSTALL_NOTHROTTLE="false"
        fi

        echo ""
        echo "  Parámetros del kernel:"
        echo "    1) Estándar — Clear Linux defaults (por defecto)"
        echo "    2) Estándar + mitigations=off — máximo rendimiento"
        echo "    3) Mínimo — solo quiet splash"
        read -p "  Opción [1]: " opt_kernel_params
        KERNEL_PARAMS_LEVEL="${opt_kernel_params:-1}"
        echo ""

        # ══════════════════════════════════════════════════════════════════════
        # PASO 5: EXTRAS (checklist, solo si hay GUI)
        # ══════════════════════════════════════════════════════════════════════
        if [ "$INSTALL_GNOME" = "true" ]; then
            echo -e "${YELLOW}[4/6] Extras${NC}"
            echo ""
            read -p "  ¿Spotify? (s/n) [s]: " opt_spotify
            [[ ${opt_spotify:-s} =~ ^[SsYy]$ ]] && INSTALL_SPOTIFY="true" || INSTALL_SPOTIFY="false"
            read -p "  ¿OnlyOffice Desktop? (s/n) [n]: " INSTALL_ONLYOFFICE
            INSTALL_ONLYOFFICE=$(_yn "$INSTALL_ONLYOFFICE" "false")
            read -p "  ¿qBittorrent? (s/n) [n]: " INSTALL_QBITTORRENT
            INSTALL_QBITTORRENT=$(_yn "$INSTALL_QBITTORRENT" "false")
            read -p "  ¿OBS Studio? (s/n) [n]: " INSTALL_OBS
            INSTALL_OBS=$(_yn "$INSTALL_OBS" "false")
            read -p "  ¿Obsidian? (s/n) [n]: " INSTALL_OBSIDIAN
            INSTALL_OBSIDIAN=$(_yn "$INSTALL_OBSIDIAN" "false")
            read -p "  ¿Gradia (screenshot tool)? (s/n) [n]: " INSTALL_GRADIA
            INSTALL_GRADIA=$(_yn "$INSTALL_GRADIA" "false")
            read -p "  ¿Mullvad VPN? (s/n) [n]: " INSTALL_MULLVAD
            INSTALL_MULLVAD=$(_yn "$INSTALL_MULLVAD" "false")
            echo ""
        fi
    fi

    # ══════════════════════════════════════════════════════════════════════════
    # PASO 6: RESUMEN
    # ══════════════════════════════════════════════════════════════════════════
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 RESUMEN DE CONFIGURACIÓN                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Nombre del perfil
    local _profile_name
    case $profile_choice in
        1) _profile_name="Escritorio" ;; 2) _profile_name="Desarrollo" ;;
        3) _profile_name="Gaming" ;; 4) _profile_name="Completo" ;;
        5) _profile_name="Servidor" ;; 6) _profile_name="Personalizado" ;;
        *) _profile_name="Escritorio" ;;
    esac

    echo -e "${YELLOW}Sistema${NC}"
    echo "  Ubuntu $UBUNTU_VERSION · $HOSTNAME · $USERNAME · $_profile_name"
    echo "  $([ "$IS_LAPTOP" = "true" ] && echo "Laptop" || echo "Desktop") · WiFi/BT: autodetectado"
    echo ""
    echo -e "${YELLOW}Componentes${NC}"
    echo "  GNOME: $INSTALL_GNOME$([ "$INSTALL_GNOME" = "true" ] && echo " ($GNOME_DOCK, autologin: $GDM_AUTOLOGIN)")"
    echo "  Multimedia: $INSTALL_MULTIMEDIA$([ "$INSTALL_SPOTIFY" = "true" ] && echo " (+Spotify)")"
    echo "  Desarrollo: $INSTALL_DEVELOPMENT$([ "$INSTALL_DEVELOPMENT" = "true" ] && echo " (VSCode: $INSTALL_VSCODE, Node: $NODEJS_OPTION, topgrade: $INSTALL_TOPGRADE)")"
    echo "  Gaming: $INSTALL_GAMING$([ "$INSTALL_GAMING" = "true" ] && echo " (GPU: $GPU_MANUAL, CachyOS: $INSTALL_CACHYOS_KERNEL, Steam: método $STEAM_METHOD)")"
    echo ""
    echo -e "${YELLOW}Extras${NC}"
    local _extras=""
    [ "$INSTALL_SPOTIFY" = "true" ] && _extras="${_extras}Spotify "
    [ "$INSTALL_ONLYOFFICE" = "true" ] && _extras="${_extras}OnlyOffice "
    [ "$INSTALL_QBITTORRENT" = "true" ] && _extras="${_extras}qBittorrent "
    [ "$INSTALL_OBS" = "true" ] && _extras="${_extras}OBS "
    [ "$INSTALL_OBSIDIAN" = "true" ] && _extras="${_extras}Obsidian "
    [ "$INSTALL_GRADIA" = "true" ] && _extras="${_extras}Gradia "
    [ "$INSTALL_MULLVAD" = "true" ] && _extras="${_extras}Mullvad "
    [ "$INSTALL_DISCORD" = "true" ] && _extras="${_extras}Discord "
    echo "  ${_extras:-ninguno}"
    echo ""
    echo -e "${YELLOW}Optimizaciones${NC}"
    echo "  systemd: minimizado · seguridad: automática (LTSC)"
    echo "  Kernel: $(case "${KERNEL_PARAMS_LEVEL:-1}" in 1) echo "estándar";; 2) echo "estándar + mitigations=off";; 3) echo "mínimo";; *) echo "estándar";; esac)"
    [ "$IS_LAPTOP" = "true" ] && echo "  Laptop: PPD$([ "$INSTALL_NOTHROTTLE" = "true" ] && echo " + nothrottle")"
    echo ""

    read -p "¿Guardar configuración? (s/n) [s]: " save_conf
    if [[ ${save_conf:-s} =~ ^[SsYy]$ ]]; then
        save_config
    fi
    echo ""

    export_config_vars
    validate_config || exit 1
}

# ── Flujo personalizado (opción 6 — preguntas una a una) ─────────────────────
_interactive_custom() {
    read -p "  ¿Escritorio GNOME? (s/n) [s]: " inst_gnome
    [[ ${inst_gnome:-s} =~ ^[SsYy]$ ]] && INSTALL_GNOME="true" || INSTALL_GNOME="false"

    if [ "$INSTALL_GNOME" = "true" ]; then
        GNOME_OPTIMIZE_MEMORY="true"; GNOME_TRANSPARENT_THEME="true"
        INSTALL_MULTIMEDIA="true"

        read -p "  ¿Spotify? (s/n) [s]: " opt_spotify
        [[ ${opt_spotify:-s} =~ ^[SsYy]$ ]] && INSTALL_SPOTIFY="true" || INSTALL_SPOTIFY="false"
    fi

    read -p "  ¿Desarrollo? (s/n) [n]: " inst_dev
    if [[ ${inst_dev:-n} =~ ^[SsYy]$ ]]; then
        INSTALL_DEVELOPMENT="true"
        if [ "$INSTALL_GNOME" = "true" ]; then
            read -p "    ¿Visual Studio Code? (s/n) [s]: " opt_vscode
            INSTALL_VSCODE=$(_yn "$opt_vscode" "true")
        else
            INSTALL_VSCODE="false"
        fi
        echo "    NodeJS: 1) No  2) LTS"
        read -p "    Opción [$([ "$INSTALL_GNOME" = "true" ] && echo "2" || echo "1")]: " opt_nodejs
        NODEJS_OPTION="${opt_nodejs:-$([ "$INSTALL_GNOME" = "true" ] && echo "2" || echo "1")}"
        read -p "    ¿topgrade? (s/n) [n]: " opt_topgrade
        INSTALL_TOPGRADE=$(_yn "$opt_topgrade" "false")
        [ "$INSTALL_GNOME" = "true" ] && { read -p "    ¿GNOME Boxes? (s/n) [n]: " opt_boxes; INSTALL_BOXES=$(_yn "$opt_boxes" "false"); }
        read -p "    ¿Lazy TUI tools? (s/n) [n]: " opt_lazy
        INSTALL_LAZY_TOOLS=$(_yn "$opt_lazy" "false")
        read -p "    ¿Docker tools? (s/n) [n]: " opt_docker_tools
        INSTALL_DOCKER_TOOLS=$(_yn "$opt_docker_tools" "false")
        read -p "    ¿n8n? (s/n) [n]: " opt_n8n
        INSTALL_N8N=$(_yn "$opt_n8n" "false")
        [ "$INSTALL_GNOME" = "true" ] && { read -p "    ¿Meld? (s/n) [n]: " opt_meld; INSTALL_MELD=$(_yn "$opt_meld" "false"); }
        [ "$INSTALL_GNOME" = "true" ] && { read -p "    ¿Postman? (s/n) [n]: " opt_postman; INSTALL_POSTMAN=$(_yn "$opt_postman" "false"); }
        read -p "    ¿Red y cloud (Wireshark, nmap, AWS CLI)? (s/n) [n]: " opt_nettools
        INSTALL_NETTOOLS=$(_yn "$opt_nettools" "false")
    fi

    if [ "$INSTALL_GNOME" = "true" ]; then
        read -p "  ¿Gaming? (s/n) [n]: " inst_gaming
        if [[ ${inst_gaming:-n} =~ ^[SsYy]$ ]]; then
            INSTALL_GAMING="true"; INSTALL_PROTONPLUS="true"
        fi

        read -p "  ¿OnlyOffice? (s/n) [n]: " INSTALL_ONLYOFFICE
        INSTALL_ONLYOFFICE=$(_yn "$INSTALL_ONLYOFFICE" "false")
        read -p "  ¿qBittorrent? (s/n) [n]: " INSTALL_QBITTORRENT
        INSTALL_QBITTORRENT=$(_yn "$INSTALL_QBITTORRENT" "false")
        read -p "  ¿OBS Studio? (s/n) [n]: " INSTALL_OBS
        INSTALL_OBS=$(_yn "$INSTALL_OBS" "false")
        read -p "  ¿Obsidian? (s/n) [n]: " INSTALL_OBSIDIAN
        INSTALL_OBSIDIAN=$(_yn "$INSTALL_OBSIDIAN" "false")
        read -p "  ¿Gradia? (s/n) [n]: " INSTALL_GRADIA
        INSTALL_GRADIA=$(_yn "$INSTALL_GRADIA" "false")
    fi

    read -p "  ¿Mullvad VPN? (s/n) [n]: " INSTALL_MULLVAD
    INSTALL_MULLVAD=$(_yn "$INSTALL_MULLVAD" "false")
}

##############################################################################
# GUARDAR CONFIGURACIÓN
##############################################################################

save_config() {
    local _gpu_str
    case "${GPU_MANUAL:-9}" in
        1) _gpu_str="amd" ;; 2) _gpu_str="intel" ;; 3) _gpu_str="intel+nvidia" ;;
        4) _gpu_str="intel+amd" ;; 5) _gpu_str="amd+amd" ;; 6) _gpu_str="amd+nvidia" ;;
        7) _gpu_str="nvidia" ;; 8) _gpu_str="vm" ;; *) _gpu_str="auto" ;;
    esac
    local _nodejs_str
    case "${NODEJS_OPTION:-2}" in 2) _nodejs_str="lts" ;; *) _nodejs_str="none" ;; esac
    local _updates_str
    case "${AUTO_UPDATE_CHOICE:-1}" in 2) _updates_str="all" ;; 3) _updates_str="none" ;; *) _updates_str="security" ;; esac

    cat > "$CONFIG_YAML" << EOF
# ══════════════════════════════════════════════════════════════════════════════
# ubuntu-advanced-install — config.yaml
# Generada: $(date)
# Para instalación desatendida: sudo ./install.sh --auto
# ══════════════════════════════════════════════════════════════════════════════

system:
  ubuntu_version: "$UBUNTU_VERSION"
  target_disk:    "${TARGET_DISK:-/dev/vda}"
  target_mount:   "${TARGET:-/mnt/ubuntu}"
  hostname:       "$HOSTNAME"
  username:       "$USERNAME"
  # Contraseñas opcionales — si se omiten, se piden al arrancar --auto
  # user_password: "CAMBIA_ESTO"
  # root_password: "CAMBIA_ESTO"
  is_laptop:         $IS_LAPTOP
  dual_boot:         ${DUAL_BOOT:-false}
  dual_boot_size_gb: ${UBUNTU_SIZE_GB:-50}

gnome:
  enabled:           $INSTALL_GNOME
  dock:              "${GNOME_DOCK:-dash-to-panel}"
  autologin:         ${GDM_AUTOLOGIN:-true}
  optimize_memory:   ${GNOME_OPTIMIZE_MEMORY:-true}
  transparent_theme: ${GNOME_TRANSPARENT_THEME:-true}

multimedia:
  enabled: $INSTALL_MULTIMEDIA
  spotify: ${INSTALL_SPOTIFY:-false}

development:
  enabled:      $INSTALL_DEVELOPMENT
  vscode:       ${INSTALL_VSCODE:-false}
  nodejs:       $_nodejs_str
  topgrade:     ${INSTALL_TOPGRADE:-false}
  gnome_boxes:  ${INSTALL_BOXES:-false}
  lazy_tools:   ${INSTALL_LAZY_TOOLS:-false}
  docker_tools: ${INSTALL_DOCKER_TOOLS:-false}
  n8n:          ${INSTALL_N8N:-false}
  meld:         ${INSTALL_MELD:-false}
  postman:      ${INSTALL_POSTMAN:-false}
  nettools:     ${INSTALL_NETTOOLS:-false}

gaming:
  enabled:            $INSTALL_GAMING
  gpu:                $_gpu_str
  steam_method:       ${STEAM_METHOD:-1}
  protonplus:         ${INSTALL_PROTONPLUS:-false}
  kernel_psycachy:    ${INSTALL_CACHYOS_KERNEL:-false}
  psycachy_scheduler: "${PSYCACHY_SCHEDULER:-bore}"
  discord:            ${INSTALL_DISCORD:-false}

extras:
  onlyoffice:        ${INSTALL_ONLYOFFICE:-false}
  qbittorrent:       ${INSTALL_QBITTORRENT:-false}
  mullvad_vpn:       ${INSTALL_MULLVAD:-false}
  obs_studio:        ${INSTALL_OBS:-false}
  obsidian:          ${INSTALL_OBSIDIAN:-false}
  gradia:            ${INSTALL_GRADIA:-false}

system_tuning:
  minimize_systemd:   ${MINIMIZE_SYSTEMD:-true}
  security_hardening: ${ENABLE_SECURITY:-false}
  auto_updates:       $_updates_str
  kernel_params:      ${KERNEL_PARAMS_LEVEL:-1}

performance:
  oomd_aggressive:  ${PERF_OOMD_AGGRESSIVE:-true}
  tmpfiles_cleanup: ${PERF_TMPFILES_CLEANUP:-true}
  dns_over_tls:     ${PERF_DNS_OVER_TLS:-true}

laptop:
  nothrottle:    ${INSTALL_NOTHROTTLE:-false}
EOF

    chmod 600 "$CONFIG_YAML"
    echo -e "${GREEN}✓ Configuración guardada en $CONFIG_YAML${NC}"
}
##############################################################################
# CARGAR CONFIGURACIÓN — MODO DESATENDIDO
##############################################################################

load_config_for_auto() {
    # Requiere config.yaml existente. Sin preguntas de configuración.
    if [ ! -f "$CONFIG_YAML" ]; then
        log_error "No se encontró $CONFIG_YAML"
        echo ""
        echo -e "  ${YELLOW}El modo --auto requiere un config.yaml previo.${NC}"
        echo -e "  Genera uno con:  sudo ./install.sh --config"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}✓ Cargando $CONFIG_YAML${NC}"
    parse_yaml "$CONFIG_YAML"
    map_yaml_to_legacy

    # Contraseñas opcionales en yaml (system.user_password / system.root_password)
    [ -n "${SYSTEM_USER_PASSWORD:-}" ] && USER_PASSWORD="$SYSTEM_USER_PASSWORD"
    [ -n "${SYSTEM_ROOT_PASSWORD:-}" ] && ROOT_PASSWORD="$SYSTEM_ROOT_PASSWORD"

    # Si no están en yaml, pedirlas (única interacción permitida en --auto)
    if [ -z "${USER_PASSWORD:-}" ]; then
        echo ""
        echo -e "${YELLOW}Contraseñas no encontradas en config.yaml:${NC}"
        echo ""
        while true; do
            read -s -p "  Contraseña para $USERNAME: " USER_PASSWORD; echo ""
            read -s -p "  Confirmar:                 " _confirm;       echo ""
            [ "$USER_PASSWORD" = "$_confirm" ] && [ -n "$USER_PASSWORD" ] && break
            echo -e "  ${RED}No coinciden o están vacías — repite${NC}"
        done
        read -p "  ¿Misma contraseña para root? (s/n) [s]: " _same
        if [[ ${_same:-s} =~ ^[SsYy]$ ]]; then
            ROOT_PASSWORD="$USER_PASSWORD"
        else
            while true; do
                read -s -p "  Contraseña para root: " ROOT_PASSWORD; echo ""
                read -s -p "  Confirmar:            " _confirm;       echo ""
                [ "$ROOT_PASSWORD" = "$_confirm" ] && [ -n "$ROOT_PASSWORD" ] && break
                echo -e "  ${RED}No coinciden o están vacías — repite${NC}"
            done
        fi
    fi

    export_config_vars
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

    # ── Cabecera de log estructurada ──────────────────────────────────────────
    {
        echo "╔══════════════════════════════════════════════════════════════"
        echo "║ MÓDULO: $module_name"
        echo "║ LABEL:  $module_label"
        [ -n "$module_num" ] && echo "║ PASO:   $module_num / $module_total"
        echo "║ INICIO: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "║ HOST:   $(hostname 2>/dev/null || echo 'chroot')"
        echo "╚══════════════════════════════════════════════════════════════"
        echo ""
    } > "$module_log"

    # Exportar contexto para módulos
    export LOG_FILE
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8

    # Calcular progreso
    local bar_text="$module_label"
    local start_pct=0 end_pct=100
    if [ -n "$module_num" ] && [ -n "$module_total" ]; then
        bar_text="[$module_num/$module_total] $module_label"
        start_pct=$(( (module_num - 1) * 100 / module_total ))
        end_pct=$(( module_num * 100 / module_total ))
    fi

    # ── Ejecutar módulo ────────────────────────────────────────────────────────
    local exit_code=0

    case "$module_name" in
        01-prepare-disk|9[0-9]-*)
            if [ "$VERBOSE_MODE" = "true" ]; then
                bash -x "$module_path" 2>&1 | tee -a "$module_log" || exit_code=${PIPESTATUS[0]}
            else
                bash "$module_path" 2>&1 | tee -a "$module_log" || exit_code=${PIPESTATUS[0]}
            fi
            ;;
        *)
            run_module_with_bar "$module_path" "$module_log" "$bar_text" "$start_pct" "$end_pct" "$VERBOSE_MODE" \
                || exit_code=$?
            ;;
    esac

    # ── Pie de log estructurado ───────────────────────────────────────────────
    local elapsed=$(( SECONDS - start_ts ))
    local status_icon="✓" status_text="OK"
    [ $exit_code -ne 0 ] && status_icon="✗" && status_text="FAILED (exit $exit_code)"

    {
        echo ""
        echo "┌──────────────────────────────────────────────────────────────"
        echo "│ FIN: $module_name — $status_text (${elapsed}s)"
        echo "│ $(date '+%Y-%m-%d %H:%M:%S')"

        # Resumen de errores/warnings del log del módulo
        # Filtrar falsos positivos de chroot (D-Bus, NM reload, gschema warnings)
        local err_count warn_count
        err_count=$(grep -iE 'error|fail|unable|cannot|not found|E:' "$module_log" 2>/dev/null \
            | grep -viE 'dbus.*Failed\|dbus.*socket\|initscript\|NMClient\|Running in chroot\|invoke-rc\.d\|postinst.*file not found\|system-connections.*No such\|NetworkManager could not\|message bus\|No such key.*gschema\|ignoring override\|2>/dev/null\|Install-Recommends\|PIPESTATUS\|install -f\|--no-install\|if.*fail\|echo.*fail' \
            | wc -l || echo 0)
        warn_count=$(grep -ciE 'warning|⚠|deprecated|skipp' "$module_log" 2>/dev/null || echo 0)
        echo "│ Errores detectados: $err_count | Warnings: $warn_count"

        if [ "$err_count" -gt 0 ]; then
            echo "│"
            echo "│ ── Errores relevantes ──"
            grep -iE 'error|fail|unable|cannot|not found' "$module_log" 2>/dev/null \
                | grep -viE 'install -f\|--no-install\|if.*fail\|echo.*fail\|2>/dev/null\|Install-Recommends\|PIPESTATUS' \
                | grep -viE 'dbus.*Failed to open\|dbus.*socket\|initscript.*force-reload\|NMClient.*Could not' \
                | grep -viE 'Running in chroot\|invoke-rc\.d\|postinst.*file not found\|system-connections.*No such' \
                | grep -viE 'NetworkManager could not reload\|Failed to connect to.*message bus' \
                | grep -viE 'No such key.*gschema\|ignoring override' \
                | tail -10 | sed 's/^/│   /'
        fi

        echo "└──────────────────────────────────────────────────────────────"
    } >> "$module_log"

    # Append al log principal
    cat "$module_log" >> "$LOG_FILE" 2>/dev/null || true

    # Resumen de una línea para module-summary.log
    printf '%s  %-30s  %s  %3ds  errors:%d  warnings:%d\n' \
        "$(date '+%H:%M:%S')" "$module_name" "$status_icon $status_text" \
        "$elapsed" "$err_count" "$warn_count" \
        >> "$LOG_DIR/module-summary.log"

    if [ $exit_code -eq 0 ]; then
        log_success "Módulo completado: $module_name (${elapsed}s)"
        return 0
    else
        log_error "Módulo falló: $module_name (exit code: $exit_code, ${elapsed}s)"
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

    if [ -f "$CONFIG_YAML" ]; then
        parse_yaml "$CONFIG_YAML"
        map_yaml_to_legacy
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
    MODULES_TO_RUN+=("07-install-rust");           MODULES_LABELS+=("Rust (base del sistema)");    MODULES_REQUIRED+=("1")
    MODULES_TO_RUN+=("30-configure-storage");      MODULES_LABELS+=("Almacenamiento");       MODULES_REQUIRED+=("1")
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
    # Módulo 25 se ejecuta si hay cualquier extra activado
    _needs_extras=false
    [ "${INSTALL_ONLYOFFICE:-false}" = "true" ] && _needs_extras=true
    [ "${INSTALL_QBITTORRENT:-false}" = "true" ] && _needs_extras=true
    [ "${INSTALL_MULLVAD:-false}" = "true" ] && _needs_extras=true
    [ "${INSTALL_OBS:-false}" = "true" ] && _needs_extras=true
    [ "${INSTALL_OBSIDIAN:-false}" = "true" ] && _needs_extras=true
    [ "${INSTALL_GRADIA:-false}" = "true" ] && _needs_extras=true
    [ "$_needs_extras" = "true" ] && {
        MODULES_TO_RUN+=("25-install-extras"); MODULES_LABELS+=("Apps extras"); MODULES_REQUIRED+=("0")
    }
    [ "${IS_LAPTOP:-false}" = "true" ] && {
        MODULES_TO_RUN+=("32-optimize-laptop"); MODULES_LABELS+=("Optimización laptop"); MODULES_REQUIRED+=("0")
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
    echo -e "${BOLD}${CYAN}  INSTALACIÓN COMPLETADA — ubuntu-advanced-install $VERSION${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Estado de módulos
    echo -e "  ${BOLD}Módulos${NC}"
    echo -e "  ${GREEN}✓${NC} $modules_ok completados"
    [ $modules_failed -gt 0 ] && echo -e "  ${RED}✗${NC} $modules_failed con errores"
    [ $modules_skipped -gt 0 ] && echo -e "  ${DIM}· $modules_skipped omitidos${NC}"
    echo ""

    # Sistema base
    echo -e "  ${BOLD}Sistema base${NC}"
    echo "    Ubuntu ${UBUNTU_VERSION:-24.04} · ${HOSTNAME:-ubuntu}"
    echo "    Usuario: ${USERNAME:-user} · Disco: ${TARGET_DISK:-/dev/vda}"
    local kparams_label="base"
    case "${KERNEL_PARAMS_LEVEL:-1}" in
        2) kparams_label="base + gaming" ;;
        3) kparams_label="base + gaming + mitigations=off" ;;
        4) kparams_label="mínimo" ;;
    esac
    echo "    Parámetros kernel: $kparams_label"
    echo ""

    # GNOME
    if [ "${INSTALL_GNOME:-false}" = "true" ]; then
        echo -e "  ${BOLD}GNOME${NC}"
        echo "    Dock: ${GNOME_DOCK:-ubuntu-dock} · Autologin: ${GDM_AUTOLOGIN:-false}"
        echo "    Extensiones: blur-my-shell, alphabetical-app-grid, caffeine,"
        echo "                 no-overview, no-screenshot-box"
        echo ""
    fi

    # Software
    local sw_items=""
    [ "${INSTALL_MULTIMEDIA:-false}" = "true" ] && sw_items="${sw_items}Multimedia "
    [ "${INSTALL_DEVELOPMENT:-false}" = "true" ] && sw_items="${sw_items}Desarrollo "
    [ "${INSTALL_GAMING:-false}" = "true" ] && sw_items="${sw_items}Gaming "
    if [ -n "$sw_items" ]; then
        echo -e "  ${BOLD}Software${NC}"
        echo "    $sw_items"
        [ "${INSTALL_GAMING:-false}" = "true" ] && {
            echo "    Gaming: Steam, Heroic, Faugus, MangoHud, MangoJuice"
            [ "${INSTALL_CACHYOS_KERNEL:-false}" = "true" ] && echo "    Kernel PsyCachy (CachyOS para Ubuntu)"
        }
        echo ""
    fi

    # Extras
    local extras=""
    [ "${INSTALL_ONLYOFFICE:-false}" = "true" ] && extras="${extras}OnlyOffice "
    [ "${INSTALL_QBITTORRENT:-false}" = "true" ] && extras="${extras}qBittorrent "
    [ "${INSTALL_MULLVAD:-false}" = "true" ] && extras="${extras}Mullvad "
    if [ -n "$extras" ]; then
        echo -e "  ${BOLD}Extras${NC}"
        echo "    $extras"
        echo ""
    fi

    # Warnings
    if [ $modules_failed -gt 0 ]; then
        echo -e "  ${YELLOW}⚠  Algunos módulos fallaron. Revisa el log para detalles.${NC}"
        echo ""
    fi

    # ── Diagnóstico rápido del log ────────────────────────────────────────────
    # Buscar problemas comunes en module-summary.log
    local summary_file="$LOG_DIR/module-summary.log"
    if [ -f "$summary_file" ]; then
        local total_errors total_warnings
        total_errors=$(awk -F'errors:' '{s+=$2} END{print s+0}' "$summary_file" 2>/dev/null)
        total_warnings=$(awk -F'warnings:' '{s+=$2} END{print s+0}' "$summary_file" 2>/dev/null)

        if [ "$total_errors" -gt 0 ] || [ "$total_warnings" -gt 5 ]; then
            echo -e "  ${BOLD}Diagnóstico${NC}"
            echo "    Errores totales: $total_errors · Warnings totales: $total_warnings"

            # Módulos con más errores
            if [ "$total_errors" -gt 0 ]; then
                echo ""
                echo -e "    ${RED}Módulos con errores:${NC}"
                grep -v 'errors:0' "$summary_file" 2>/dev/null | grep 'errors:' | while read line; do
                    echo "      $line"
                done
            fi
            echo ""
            echo "    Para investigar un módulo específico:"
            echo "      cat $LOG_DIR/<nombre-módulo>.log | grep -i error"
            echo ""
        fi
    fi

    # Pie
    printf "  Tiempo total: %dm %02ds\n" "$elapsed_min" "$elapsed_sec"
    echo -e "  Log: ${DIM}$LOG_FILE${NC}"
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Reinicia para completar la configuración.${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""

    log_success "Instalación completada"
}

##############################################################################
# LIMPIEZA POST-INSTALACIÓN
##############################################################################

cleanup_config() {
    [ ! -f "$CONFIG_YAML" ] && return

    if [ "${1:-}" = "auto" ]; then
        rm -f "$CONFIG_YAML"
        echo -e "${GREEN}✓  config.yaml eliminado${NC}"
    else
        echo ""
        read -p "  ¿Eliminar config.yaml? (s/n) [s]: " del_conf
        if [[ ${del_conf:-s} =~ ^[SsYy]$ ]]; then
            rm -f "$CONFIG_YAML"
            echo -e "${GREEN}✓  config.yaml eliminado${NC}"
        else
            echo "  config.yaml conservado en: $CONFIG_YAML"
        fi
    fi
}

##############################################################################
# INSTALACIÓN AUTOMÁTICA (sin preguntas durante ejecución)
##############################################################################

full_automatic_install() {
    load_config_for_auto
    
    log_step "INSTALACIÓN AUTOMÁTICA COMPLETA"
    
    echo -e "${GREEN}Verificando dependencias del sistema...${NC}"
    local dep_log="$LOG_DIR/00-check-dependencies.log"
    if bash "$MODULES_DIR/00-check-dependencies.sh" > "$dep_log" 2>&1; then
        echo -e "♦  Dependencias instaladas"
    else
        log_error "Error al verificar dependencias (ver $dep_log)"
        exit 1
    fi
    cat "$dep_log" >> "$LOG_FILE" 2>/dev/null || true

    build_module_list
    run_all_modules "automatic" || exit 1

    run_module "90-verify-system" "Verificación post-instalación"
    run_module "91-generate-report" "Generando informe"
    cleanup_config "auto"
    post_install_menu
}

##############################################################################
# INSTALACIÓN INTERACTIVA
##############################################################################

full_interactive_install() {
    interactive_config
    
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
    local dep_log="$LOG_DIR/00-check-dependencies.log"
    if bash "$MODULES_DIR/00-check-dependencies.sh" > "$dep_log" 2>&1; then
        echo -e "♦  Dependencias instaladas"
    else
        log_error "Error al verificar dependencias (ver $dep_log)"
        exit 1
    fi
    cat "$dep_log" >> "$LOG_FILE" 2>/dev/null || true
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

    run_module "90-verify-system" "Verificación post-instalación"
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

# ── Argumentos CLI: despacho directo sin pantalla principal ──────────────────
# Si hay argumentos, se procesan directamente sin mostrar el banner.
if [ -n "${1:-}" ]; then
    check_root
    case "$1" in
        --auto|-a)      full_automatic_install ;;
        --interactive|-i) full_interactive_install ;;
        --config|-c)    interactive_config ;;
        --module|-m)
            [ -z "${2:-}" ] && { log_error "Especifica módulo: $0 --module NOMBRE"; exit 1; }
            [ -f "$CONFIG_YAML" ] && { parse_yaml "$CONFIG_YAML"; map_yaml_to_legacy; }
            export_config_vars
            run_module "$2"
            ;;
        --list|-l)
            echo "ubuntu-advanced-install v${VERSION} — Módulos disponibles:"
            echo ""
            prev_group=""
            for f in "$MODULES_DIR"/[0-9]*.sh; do
                name=$(basename "$f" .sh)
                prefix=${name%%-*}
                case $prefix in
                    0[0-9]) group="BASE" ;; 1[0-9]) group="GNOME" ;;
                    2[0-9]) group="SOFTWARE" ;; 3[0-9]) group="OPTIMIZACIÓN" ;;
                    9[0-9]) group="POST-INSTALACIÓN" ;; *) group="OTRO" ;;
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
        --verbose|-v)   VERBOSE_MODE=true; export VERBOSE_MODE; full_interactive_install ;;
        --debug)        VERBOSE_MODE=true; export VERBOSE_MODE; set -x; full_interactive_install ;;
        --dry-run|-n)
            # Muestra el plan de instalación completo sin ejecutar nada.
            # Requiere config.yaml o interacción para definir la configuración.
            if [ -f "$CONFIG_YAML" ]; then
                parse_yaml "$CONFIG_YAML"
                map_yaml_to_legacy
            else
                interactive_config
            fi
            export_config_vars
            validate_config || exit 1
            build_module_list

            clear
            echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
            echo -e "${BOLD}${CYAN}  DRY RUN — ubuntu-advanced-install v${VERSION}${NC}"
            echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
            echo ""

            # Sistema
            echo -e "  ${BOLD}Sistema${NC}"
            echo "    Ubuntu ${UBUNTU_VERSION} · ${HOSTNAME} · ${USERNAME}"
            echo "    $([ "$IS_LAPTOP" = "true" ] && echo "Laptop" || echo "Desktop") · Disco: ${TARGET_DISK:-/dev/vda}"
            echo ""

            # Módulos
            local total=${#MODULES_TO_RUN[@]}
            local core_count=0 extra_count=0
            for req in "${MODULES_REQUIRED[@]}"; do
                [ "$req" = "1" ] && core_count=$(( core_count + 1 )) || extra_count=$(( extra_count + 1 ))
            done

            echo -e "  ${BOLD}Módulos a ejecutar ($total)${NC}"
            local prev_section=""
            for i in "${!MODULES_TO_RUN[@]}"; do
                local mod="${MODULES_TO_RUN[$i]}"
                local label="${MODULES_LABELS[$i]}"
                local req="${MODULES_REQUIRED[$i]}"
                if [ "$req" = "1" ] && [ "$prev_section" != "core" ]; then
                    echo -e "    ${GREEN}CORE${NC}"
                    prev_section="core"
                elif [ "$req" = "0" ] && [ "$prev_section" != "extra" ]; then
                    echo -e "    ${CYAN}EXTRA${NC}"
                    prev_section="extra"
                fi
                local badge; [ "$req" = "1" ] && badge="${GREEN}●${NC}" || badge="${CYAN}○${NC}"
                printf "    %b %2d. %s\n" "$badge" "$(( i + 1 ))" "$label"
            done
            echo ""
            echo -e "  ${GREEN}$core_count CORE${NC} + ${CYAN}$extra_count EXTRA${NC} = ${BOLD}$total total${NC}"
            echo ""

            # Variables exportadas (las relevantes)
            echo -e "  ${BOLD}Configuración${NC}"
            echo "    GNOME: ${INSTALL_GNOME} (dock: ${GNOME_DOCK}, autologin: ${GDM_AUTOLOGIN})"
            echo "    Multimedia: ${INSTALL_MULTIMEDIA} (Spotify: ${INSTALL_SPOTIFY})"
            echo "    Desarrollo: ${INSTALL_DEVELOPMENT} (VSCode: ${INSTALL_VSCODE}, Node: ${NODEJS_OPTION})"
            echo "    Gaming: ${INSTALL_GAMING} (GPU: ${GPU_MANUAL}, Steam: método ${STEAM_METHOD})"
            echo "    Kernel params: nivel ${KERNEL_PARAMS_LEVEL}"
            echo ""

            echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
            echo -e "  ${DIM}Dry run completado — no se ejecutó nada${NC}"
            echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
            ;;
        --help|-h)
            cat << HELPEOF
ubuntu-advanced-install v${VERSION}
Instalador modular de Ubuntu con debootstrap

Uso: sudo ./install.sh [opción]

MODOS DE INSTALACIÓN:
  (sin args)          Pantalla principal (recomendado)
  --auto,    -a       Instalación automática (requiere config.yaml)
  --dry-run, -n       Mostrar plan sin ejecutar nada
  --verbose, -v       Interactiva con verbose
  --debug             Interactiva con bash -x

CONFIGURACIÓN:
  --config,  -c       Generar config.yaml interactivamente
  --validate          Validar config.yaml sin instalar

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

Config de ejemplo: config.yaml.example
Documentación:      docs/README.md
HELPEOF
            ;;
        --version)      echo "ubuntu-advanced-install v${VERSION}" ;;
        --validate)
            [ -f "$CONFIG_YAML" ] || { log_error "No se encontró config.yaml"; exit 1; }
            parse_yaml "$CONFIG_YAML"; map_yaml_to_legacy; export_config_vars; validate_config
            ;;
        --menu)         check_root; while true; do show_menu; done ;;
        *)              log_error "Opción desconocida: $1 (usa --help)"; exit 1 ;;
    esac
    exit 0
fi

# ── Sin argumentos: pantalla principal ───────────────────────────────────────
check_root
clear
echo -e "${YELLOW}"
cat << 'BANNER'
   __  ____                __           ___       __                                __   ____           __        ____
  / / / / /_  __  ______  / /___  __   /   | ____/ /   ______ _____  ________  ____/ /  /  _/___  _____/ /_____ _/ / /
 / / / / __ \/ / / / __ \/ __/ / / /  / /| |/ __  / | / / __ `/ __ \/ ___/ _ \/ __  /   / // __ \/ ___/ __/ __ `/ / / 
/ /_/ / /_/ / /_/ / / / / /_/ /_/ /  / ___ / /_/ /| |/ / /_/ / / / / /__/  __/ /_/ /  _/ // / / (__  ) /_/ /_/ / / /  
\____/_.___/\__,_/_/ /_/\__/\__,_/  /_/  |_\__,_/ |___/\__,_/_/ /_/\___/\___/\__,_/  /___/_/ /_/____/\__/\__,_/_/_/   
BANNER
echo -e "${NC}"
echo -e "${DIM}  v${VERSION}${NC}"
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  INSTALADOR DE UBUNTU                     ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  ${NC}${BOLD}1)${NC}${CYAN}  Instalación interactiva guiada                      ║${NC}"
echo -e "${CYAN}║      ${DIM}Configura paso a paso y ejecuta${NC}${CYAN}                     ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║  ${NC}${BOLD}2)${NC}${CYAN}  Instalación automática                              ║${NC}"
echo -e "${CYAN}║      ${DIM}Usa config.yaml existente${NC}${CYAN}                            ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -f "$CONFIG_YAML" ]; then
    echo -e "  ${DIM}config.yaml detectado — opción 2 disponible${NC}"
    echo ""
fi

read -p "  Selecciona opción [1]: " main_choice
echo ""

case "${main_choice:-1}" in
    1)  full_interactive_install ;;
    2)
        if [ ! -f "$CONFIG_YAML" ]; then
            log_error "No se encontró config.yaml"
            echo ""
            echo -e "  ${YELLOW}Genera uno primero con:${NC}  sudo ./install.sh --config"
            echo -e "  ${YELLOW}O copia el ejemplo:${NC}     cp config.yaml.example config.yaml"
            echo ""
            exit 1
        fi
        full_automatic_install
        ;;
    *)
        echo "Opción no válida"
        exit 1
        ;;
esac