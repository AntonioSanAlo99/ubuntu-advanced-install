#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
#  ubuntu-advanced-install — instalador modular
# ─────────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_FILE="$SCRIPT_DIR/config.env"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

VERBOSE_MODE="${VERBOSE_MODE:-false}"

mkdir -p "$LOG_DIR"

# ── Paleta de color ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
# Naranja Ubuntu #E95420 — 256-color, fallback amarillo bold
if [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ] 2>/dev/null; then
    OR='\033[38;5;208m'
else
    OR='\033[1;33m'
fi

# ── Banner ────────────────────────────────────────────────────────────────────
show_banner() {
    echo ""
    echo -e "${OR}${BOLD}"
    echo '  ██╗   ██╗██████╗ ██╗   ██╗███╗  ██╗████████╗██╗   ██╗'
    echo '  ██║   ██║██╔══██╗██║   ██║████╗ ██║╚══██╔══╝██║   ██║'
    echo '  ██║   ██║██████╔╝██║   ██║██╔██╗██║   ██║   ██║   ██║'
    echo '  ██║   ██║██╔══██╗██║   ██║██║╚████║   ██║   ██║   ██║'
    echo '  ╚██████╔╝██████╔╝╚██████╔╝██║ ╚███║   ██║   ╚██████╔╝'
    echo '   ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚══╝   ╚═╝    ╚═════╝ '
    echo -e "${NC}"
    echo -e "  ${OR}▸${NC} ${BOLD}Advanced Install${NC}  ${DIM}·  instalador modular para Ubuntu${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
    echo ""
}

# ── Primitiva de sección ──────────────────────────────────────────────────────
section() { echo -e "\n  ${OR}${BOLD}$*${NC}\n"; }

# ── Log (pantalla + archivo) ──────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local msg="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        OK)   echo -e "  ${GREEN}✓${NC}  $msg" ;;
        ERR)  echo -e "  ${RED}✗${NC}  $msg" ;;
        WARN) echo -e "  ${YELLOW}⚠${NC}  $msg" ;;
        INFO) echo -e "  ${DIM}·${NC}  $msg" ;;
        STEP) echo -e "\n${OR}──${NC} ${BOLD}$msg${NC}" ;;
        *)    echo "  $msg" ;;
    esac
}

exec > >(tee -a "$LOG_FILE") 2>&1
show_banner
log INFO "arrancado — log: $LOG_FILE"

# ── Comprobación de privilegios ───────────────────────────────────────────────
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log ERR "Este script debe ejecutarse como root"
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  BARRA DE PROGRESO APT (idempotente — host + chroot)
# ─────────────────────────────────────────────────────────────────────────────
setup_apt_progress() {
    local conf='Dpkg::Progress-Fancy "1";
APT::Color "1";'
    [ -d /etc/apt/apt.conf.d ] && [ ! -f /etc/apt/apt.conf.d/99-installer-progress ] \
        && echo "$conf" > /etc/apt/apt.conf.d/99-installer-progress
    [ -d "${TARGET:-}/etc/apt/apt.conf.d" ] && [ ! -f "${TARGET}/etc/apt/apt.conf.d/99-installer-progress" ] \
        && echo "$conf" > "${TARGET}/etc/apt/apt.conf.d/99-installer-progress"
}

# ─────────────────────────────────────────────────────────────────────────────
#  EXPORTAR VARIABLES DE CONFIGURACIÓN A LOS MÓDULOS
# ─────────────────────────────────────────────────────────────────────────────
export_config_vars() {
    export UBUNTU_VERSION TARGET_DISK TARGET HOSTNAME USERNAME
    export USER_PASSWORD ROOT_PASSWORD
    export IS_LAPTOP HAS_WIFI HAS_BLUETOOTH
    export INSTALL_GNOME GDM_AUTOLOGIN GNOME_OPTIMIZE_MEMORY GNOME_TRANSPARENT_THEME
    export INSTALL_MULTIMEDIA INSTALL_SPOTIFY
    export INSTALL_DEVELOPMENT INSTALL_VSCODE NODEJS_OPTION INSTALL_RUST INSTALL_TOPGRADE
    export INSTALL_GAMING CACHYOS_CHOICE
    export INSTALL_AM
    export MINIMIZE_SYSTEMD ENABLE_SECURITY AUTO_UPDATE_CHOICE
    export POWER_MANAGER INSTALL_NOTHROTTLE
    export USE_NO_INSTALL_RECOMMENDS DUAL_BOOT UBUNTU_SIZE_GB
    setup_apt_progress
}

# ─────────────────────────────────────────────────────────────────────────────
#  EJECUTAR MÓDULO
# ─────────────────────────────────────────────────────────────────────────────
run_module() {
    local name="$1"
    local path="$MODULES_DIR/$name.sh"

    if [ ! -f "$path" ]; then
        log ERR "Módulo no encontrado: $name"
        return 1
    fi

    log STEP "$name"

    # Locale mínimo — evita warnings LC_* en apt dentro del chroot
    export LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=C

    setup_apt_progress

    local exit_code=0
    if [ "$VERBOSE_MODE" = "true" ]; then
        bash -x "$path" || exit_code=$?
    else
        bash "$path" || exit_code=$?
    fi

    echo ""
    if [ "$exit_code" -eq 0 ]; then
        log OK "completado: $name"
        echo "[$name] OK" >> "$LOG_DIR/module-summary.log"
    else
        log ERR "falló: $name (código $exit_code)"
        echo "[$name] FAILED" >> "$LOG_DIR/module-summary.log"
    fi
    return "$exit_code"
}

# ─────────────────────────────────────────────────────────────────────────────
#  GUARDAR CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
save_config() {
    cat > "$CONFIG_FILE" << EOF
# ubuntu-advanced-install — configuración generada: $(date)
# AVISO: contiene contraseñas en texto plano. Eliminar tras la instalación.

# Sistema
UBUNTU_VERSION="$UBUNTU_VERSION"
TARGET_DISK="${TARGET_DISK:-/dev/vda}"
TARGET="${TARGET:-/mnt/ubuntu}"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
USER_PASSWORD="$USER_PASSWORD"
ROOT_PASSWORD="$ROOT_PASSWORD"

# Hardware
IS_LAPTOP="$IS_LAPTOP"
HAS_WIFI="$HAS_WIFI"
HAS_BLUETOOTH="$HAS_BLUETOOTH"

# Entorno gráfico
INSTALL_GNOME="$INSTALL_GNOME"
GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-false}"
GNOME_OPTIMIZE_MEMORY="${GNOME_OPTIMIZE_MEMORY:-false}"
GNOME_TRANSPARENT_THEME="${GNOME_TRANSPARENT_THEME:-false}"

# Componentes
INSTALL_MULTIMEDIA="$INSTALL_MULTIMEDIA"
INSTALL_SPOTIFY="${INSTALL_SPOTIFY:-n}"
INSTALL_DEVELOPMENT="$INSTALL_DEVELOPMENT"
INSTALL_VSCODE="${INSTALL_VSCODE:-n}"
NODEJS_OPTION="${NODEJS_OPTION:-1}"
INSTALL_RUST="${INSTALL_RUST:-n}"
INSTALL_TOPGRADE="${INSTALL_TOPGRADE:-n}"
INSTALL_GAMING="$INSTALL_GAMING"
CACHYOS_CHOICE="${CACHYOS_CHOICE:-3}"
INSTALL_AM="${INSTALL_AM:-false}"

# Optimización
MINIMIZE_SYSTEMD="$MINIMIZE_SYSTEMD"
ENABLE_SECURITY="$ENABLE_SECURITY"
AUTO_UPDATE_CHOICE="${AUTO_UPDATE_CHOICE:-1}"
POWER_MANAGER="${POWER_MANAGER:-1}"
INSTALL_NOTHROTTLE="${INSTALL_NOTHROTTLE:-false}"

# APT
USE_NO_INSTALL_RECOMMENDS="$USE_NO_INSTALL_RECOMMENDS"
DUAL_BOOT="${DUAL_BOOT:-false}"
UBUNTU_SIZE_GB="${UBUNTU_SIZE_GB:-50}"
EOF
    chmod 600 "$CONFIG_FILE"
    log WARN "config.env contiene contraseñas — eliminar tras la instalación: rm $CONFIG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  ELIMINAR CONFIG.ENV DE FORMA SEGURA
# ─────────────────────────────────────────────────────────────────────────────
shred_config() {
    if [ -f "$CONFIG_FILE" ]; then
        shred -u "$CONFIG_FILE" 2>/dev/null \
            || { dd if=/dev/urandom of="$CONFIG_FILE" bs=1k count=1 2>/dev/null; rm -f "$CONFIG_FILE"; }
        log OK "config.env eliminado de forma segura"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  ASISTENTE DE CONFIGURACIÓN INTERACTIVA (5 pasos)
# ─────────────────────────────────────────────────────────────────────────────
# Helpers de resumen
_si()  { [ "$1" = "true" ] || [ "$1" = "s" ] && echo "sí" || echo "no"; }
_ver() { case "$1" in noble) echo "24.04 LTS Noble" ;; jammy) echo "22.04 LTS Jammy" ;;
                      questing) echo "25.10 Questing" ;; resolute) echo "26.04 LTS Resolute" ;;
                      *) echo "$1" ;; esac; }
_pm()  { [ "$1" = "1" ] && echo "power-profiles-daemon" || echo "TLP"; }
_au()  { case "$1" in 1) echo "solo actualizaciones de seguridad" ;; 2) echo "todas" ;; *) echo "desactivadas" ;; esac; }

interactive_config() {
    # --no-install-recommends siempre activo — decisión del instalador, no del usuario
    USE_NO_INSTALL_RECOMMENDS="true"

    clear; show_banner
    echo -e "  ${OR}${BOLD}CONFIGURACIÓN${NC}  ${DIM}(5 pasos)${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
    echo ""

    # ── 1. Sistema ────────────────────────────────────────────────────────────
    clear; show_banner
    section "[1/5] Sistema"

    echo "  Versión de Ubuntu:"
    echo "    1  24.04 LTS  Noble Numbat     ← recomendado"
    echo "    2  22.04 LTS  Jammy Jellyfish"
    echo "    3  25.10       Questing Quokka"
    echo "    4  26.04 LTS  Resolute Raccoon  (en desarrollo)"
    echo ""
    read -rp "  → [1]: " v; v=${v:-1}
    case $v in
        2) UBUNTU_VERSION="jammy"    ;;
        3) UBUNTU_VERSION="questing" ;;
        4) UBUNTU_VERSION="resolute" ;;
        *) UBUNTU_VERSION="noble"    ;;
    esac

    echo ""
    echo "  Nombre del equipo (aparece en la red y en el terminal):"
    read -rp "  → [ubuntu]: " HOSTNAME; HOSTNAME=${HOSTNAME:-ubuntu}

    echo ""
    echo "  Tipo de equipo:"
    echo "    1  Escritorio"
    echo "    2  Portátil"
    echo ""
    read -rp "  → [1]: " hw; hw=${hw:-1}
    [ "$hw" = "2" ] && IS_LAPTOP="true" || IS_LAPTOP="false"

    echo ""
    echo "  Conectividad:"
    read -rp "  ¿Tiene tarjeta WiFi? [s]: " w; w=${w:-s}
    [[ $w =~ ^[SsYy]$ ]] && HAS_WIFI="true" || HAS_WIFI="false"
    read -rp "  ¿Tiene Bluetooth? [s]: " b; b=${b:-s}
    [[ $b =~ ^[SsYy]$ ]] && HAS_BLUETOOTH="true" || HAS_BLUETOOTH="false"

    # ── 2. Cuenta de usuario ──────────────────────────────────────────────────
    clear; show_banner
    section "[2/5] Cuenta de usuario"

    read -rp "  Nombre de usuario: " USERNAME
    while [ -z "$USERNAME" ]; do
        log ERR "El nombre de usuario no puede estar vacío"
        read -rp "  Nombre de usuario: " USERNAME
    done

    echo ""
    while true; do
        read -rsp "  Contraseña: " USER_PASSWORD; echo ""
        read -rsp "  Repite la contraseña: " UP2; echo ""
        [ "$USER_PASSWORD" = "$UP2" ] && [ -n "$USER_PASSWORD" ] && break
        log ERR "Las contraseñas no coinciden o están vacías"
    done

    echo ""
    read -rp "  ¿Usar la misma contraseña para el administrador (root)? [s]: " sp; sp=${sp:-s}
    if [[ $sp =~ ^[SsYy]$ ]]; then
        ROOT_PASSWORD="$USER_PASSWORD"
    else
        echo ""
        while true; do
            read -rsp "  Contraseña de administrador: " ROOT_PASSWORD; echo ""
            read -rsp "  Repite la contraseña: " RP2; echo ""
            [ "$ROOT_PASSWORD" = "$RP2" ] && [ -n "$ROOT_PASSWORD" ] && break
            log ERR "Las contraseñas no coinciden o están vacías"
        done
    fi

    # ── 3. Escritorio ─────────────────────────────────────────────────────────
    clear; show_banner
    section "[3/5] Escritorio"

    echo "  ¿Instalar entorno de escritorio GNOME?"
    echo "  ${DIM}Si respondes no, el sistema arrancará en modo texto (sin interfaz gráfica).${NC}"
    echo ""
    read -rp "  → [s]: " ig
    [[ ${ig:-s} =~ ^[SsYy]$ ]] && INSTALL_GNOME="true" || INSTALL_GNOME="false"

    if [ "$INSTALL_GNOME" = "true" ]; then
        echo ""
        echo "  Opciones de GNOME:"
        read -rp "  ¿Arrancar sesión automáticamente sin pedir contraseña? [n]: " al
        [[ ${al:-n} =~ ^[SsYy]$ ]] && GDM_AUTOLOGIN="true" || GDM_AUTOLOGIN="false"

        read -rp "  ¿Aplicar tema con transparencias? [n]: " ot
        [[ ${ot:-n} =~ ^[SsYy]$ ]] && GNOME_TRANSPARENT_THEME="true" || GNOME_TRANSPARENT_THEME="false"

        read -rp "  ¿Desactivar servicios de GNOME en segundo plano (Tracker, Evolution)? [n]: " om
        [[ ${om:-n} =~ ^[SsYy]$ ]] && GNOME_OPTIMIZE_MEMORY="true" || GNOME_OPTIMIZE_MEMORY="false"
    else
        GDM_AUTOLOGIN="false"; GNOME_TRANSPARENT_THEME="false"; GNOME_OPTIMIZE_MEMORY="false"
    fi

    # ── 4. Programas ──────────────────────────────────────────────────────────
    clear; show_banner
    section "[4/5] Programas"

    echo "  Reproducción de audio y vídeo"
    echo "  ${DIM}Incluye códecs, VLC, reproductor de música y miniaturas de archivos multimedia.${NC}"
    read -rp "  ¿Instalar? [s]: " im
    [[ ${im:-s} =~ ^[SsYy]$ ]] && INSTALL_MULTIMEDIA="true" || INSTALL_MULTIMEDIA="false"
    if [ "$INSTALL_MULTIMEDIA" = "true" ]; then
        read -rp "  ¿Incluir Spotify? [n]: " isp
        [[ ${isp:-n} =~ ^[SsYy]$ ]] && INSTALL_SPOTIFY="s" || INSTALL_SPOTIFY="n"
    else
        INSTALL_SPOTIFY="n"
    fi

    echo ""
    echo "  Soporte para AppImages"
    echo "  ${DIM}Permite instalar y gestionar aplicaciones en formato AppImage desde el escritorio.${NC}"
    read -rp "  ¿Instalar? [n]: " iam
    [[ ${iam:-n} =~ ^[SsYy]$ ]] && INSTALL_AM="true" || INSTALL_AM="false"

    echo ""
    echo "  Herramientas de desarrollo"
    echo "  ${DIM}Visual Studio Code, Node.js, Rust y topgrade.${NC}"
    read -rp "  ¿Instalar? [n]: " id
    [[ ${id:-n} =~ ^[SsYy]$ ]] && INSTALL_DEVELOPMENT="true" || INSTALL_DEVELOPMENT="false"
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        read -rp "    ¿Visual Studio Code? [s]: " vc; INSTALL_VSCODE="${vc:-s}"
        echo "    Node.js:  1) no instalar  2) versión LTS"
        read -rp "    → [2]: " nj; NODEJS_OPTION="${nj:-2}"
        read -rp "    ¿Rust? [n]: " ir; INSTALL_RUST="${ir:-n}"
        read -rp "    ¿topgrade (actualizador universal)? [s]: " it; INSTALL_TOPGRADE="${it:-s}"
    else
        INSTALL_VSCODE="n"; NODEJS_OPTION="1"; INSTALL_RUST="n"; INSTALL_TOPGRADE="n"
    fi

    echo ""
    echo "  Gaming"
    echo "  ${DIM}Steam, Heroic Games Launcher, gestión de versiones de Proton y drivers de GPU.${NC}"
    read -rp "  ¿Instalar? [n]: " igm
    [[ ${igm:-n} =~ ^[SsYy]$ ]] && INSTALL_GAMING="true" || INSTALL_GAMING="false"
    if [ "$INSTALL_GAMING" = "true" ]; then
        echo ""
        echo "    Kernel de alto rendimiento CachyOS (opcional):"
        echo "    1) BORE  — baja latencia, ideal para gaming"
        echo "    2) EEVDF — equilibrio entre rendimiento y estabilidad"
        echo "    3) No instalar  ← recomendado si no sabes qué elegir"
        read -rp "    → [3]: " cc; CACHYOS_CHOICE="${cc:-3}"
    else
        CACHYOS_CHOICE="3"
    fi

    # ── 5. Sistema y actualizaciones ──────────────────────────────────────────
    clear; show_banner
    section "[5/5] Sistema y actualizaciones"

    echo "  Actualizaciones automáticas:"
    echo "    1  Solo parches de seguridad  ← recomendado"
    echo "    2  Todas las actualizaciones disponibles"
    echo "    3  Desactivadas"
    echo ""
    read -rp "  → [1]: " au; AUTO_UPDATE_CHOICE="${au:-1}"

    echo ""
    echo "  ¿Desactivar servicios del sistema que no se usan?"
    echo "  ${DIM}Reduce el consumo de memoria y el tiempo de arranque.${NC}"
    read -rp "  → [s]: " ms
    [[ ${ms:-s} =~ ^[SsYy]$ ]] && MINIMIZE_SYSTEMD="true" || MINIMIZE_SYSTEMD="false"

    echo ""
    echo "  ¿Activar medidas de seguridad adicionales?"
    echo "  ${DIM}Endurece la configuración del sistema: restringe acceso root, ajusta permisos y límites.${NC}"
    read -rp "  → [n]: " hs
    [[ ${hs:-n} =~ ^[SsYy]$ ]] && ENABLE_SECURITY="true" || ENABLE_SECURITY="false"

    if [ "$IS_LAPTOP" = "true" ]; then
        echo ""
        echo "  Gestión de batería:"
        echo "    1  Automática integrada con GNOME  ← recomendado"
        echo "    2  TLP (configuración avanzada)"
        echo ""
        read -rp "  → [1]: " pm; POWER_MANAGER="${pm:-1}"

        echo ""
        echo "  ¿Activar corrección de throttling térmico en procesadores Intel?"
        echo "  ${DIM}Útil si el portátil reduce el rendimiento por temperatura. No necesario en AMD.${NC}"
        read -rp "  → [n]: " nt
        [[ ${nt:-n} =~ ^[SsYy]$ ]] && INSTALL_NOTHROTTLE="true" || INSTALL_NOTHROTTLE="false"
    else
        POWER_MANAGER="1"; INSTALL_NOTHROTTLE="false"
    fi

    # ── Resumen ───────────────────────────────────────────────────────────────
    clear; show_banner
    echo -e "  ${OR}${BOLD}RESUMEN DE LA INSTALACIÓN${NC}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${DIM}Sistema${NC}"
    printf "    %-32s %s\n" "Ubuntu"           "$(_ver "$UBUNTU_VERSION")"
    printf "    %-32s %s\n" "Nombre del equipo" "$HOSTNAME"
    printf "    %-32s %s\n" "Usuario"           "$USERNAME"
    printf "    %-32s %s\n" "Tipo de equipo"    "$([ "$IS_LAPTOP" = "true" ] && echo "Portátil" || echo "Escritorio")"
    printf "    %-32s %s\n" "WiFi"              "$(_si "$HAS_WIFI")"
    printf "    %-32s %s\n" "Bluetooth"         "$(_si "$HAS_BLUETOOTH")"
    echo ""
    echo -e "  ${DIM}Escritorio${NC}"
    if [ "$INSTALL_GNOME" = "true" ]; then
        printf "    %-32s %s\n" "Entorno de escritorio" "GNOME"
        [ "$GDM_AUTOLOGIN"          = "true" ] && printf "    %-32s %s\n" "Inicio de sesión automático" "sí"
        [ "$GNOME_TRANSPARENT_THEME" = "true" ] && printf "    %-32s %s\n" "Tema con transparencias"     "sí"
        [ "$GNOME_OPTIMIZE_MEMORY"  = "true" ] && printf "    %-32s %s\n" "Servicios en segundo plano"  "desactivados"
    else
        printf "    %-32s %s\n" "Entorno de escritorio" "ninguno (modo texto)"
    fi
    echo ""
    echo -e "  ${DIM}Programas${NC}"
    local multimedia_label="$(_si "$INSTALL_MULTIMEDIA")"
    [ "$INSTALL_SPOTIFY" = "s" ] && multimedia_label="sí, con Spotify"
    printf "    %-32s %s\n" "Audio y vídeo"   "$multimedia_label"
    printf "    %-32s %s\n" "AppImages"        "$(_si "$INSTALL_AM")"
    if [ "$INSTALL_DEVELOPMENT" = "true" ]; then
        local dev_detail=""
        [[ "${INSTALL_VSCODE:-n}" =~ ^[SsYy]$ ]] && dev_detail="VSCode"
        [ "$NODEJS_OPTION" = "2" ]  && dev_detail="${dev_detail:+$dev_detail, }Node.js"
        [[ "${INSTALL_RUST:-n}" =~ ^[SsYy]$ ]]    && dev_detail="${dev_detail:+$dev_detail, }Rust"
        [[ "${INSTALL_TOPGRADE:-n}" =~ ^[SsYy]$ ]] && dev_detail="${dev_detail:+$dev_detail, }topgrade"
        printf "    %-32s %s\n" "Desarrollo"  "sí${dev_detail:+ ($dev_detail)}"
    else
        printf "    %-32s %s\n" "Desarrollo"  "no"
    fi
    if [ "$INSTALL_GAMING" = "true" ]; then
        local gaming_detail="Steam, Heroic, Proton"
        [ "$CACHYOS_CHOICE" = "1" ] && gaming_detail="$gaming_detail, kernel BORE"
        [ "$CACHYOS_CHOICE" = "2" ] && gaming_detail="$gaming_detail, kernel EEVDF"
        printf "    %-32s %s\n" "Gaming"  "sí ($gaming_detail)"
    else
        printf "    %-32s %s\n" "Gaming"  "no"
    fi
    echo ""
    echo -e "  ${DIM}Sistema${NC}"
    printf "    %-32s %s\n" "Actualizaciones automáticas" "$(_au "$AUTO_UPDATE_CHOICE")"
    printf "    %-32s %s\n" "Servicios innecesarios"      "$([ "$MINIMIZE_SYSTEMD" = "true" ] && echo "desactivados" || echo "sin cambios")"
    printf "    %-32s %s\n" "Seguridad reforzada"         "$(_si "$ENABLE_SECURITY")"
    if [ "$IS_LAPTOP" = "true" ]; then
        printf "    %-32s %s\n" "Gestión de batería" "$(_pm "$POWER_MANAGER")"
        [ "$INSTALL_NOTHROTTLE" = "true" ] && \
            printf "    %-32s %s\n" "Corrección de throttling" "sí"
    fi
    echo ""
    echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
    echo ""

    read -rp "  ¿Todo correcto? Guardar y continuar [s]: " pr; pr=${pr:-s}
    if [[ ! $pr =~ ^[SsYy]$ ]]; then
        echo ""
        log WARN "Configuración descartada. Vuelve a ejecutar el instalador para empezar de nuevo."
        exit 0
    fi

    save_config
    log OK "Configuración guardada"
    export_config_vars
}

# ─────────────────────────────────────────────────────────────────────────────
#  CARGAR O CREAR CONFIGURACIÓN
# ─────────────────────────────────────────────────────────────────────────────
load_or_create_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        export_config_vars
        log OK "Configuración cargada"
    else
        interactive_config
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  MENÚ PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
show_menu() {
    clear; show_banner

    echo -e "  ${DIM}[1]${NC}  Instalar Ubuntu          ${DIM}← empezar aquí${NC}"
    echo -e "  ${DIM}[2]${NC}  Reanudar instalación     ${DIM}← continuar con config.env guardado${NC}"
    echo -e "  ${DIM}[3]${NC}  Salir"
    echo ""
    echo -e "  ${DIM}──────────────────────────────────────────────────────────${NC}"
    echo ""
    read -rp "  → " choice; choice=${choice:-1}
    echo ""

    case $choice in
        1)  full_interactive_install ;;
        2)  if [ ! -f "$CONFIG_FILE" ]; then
                log ERR "No se encontró config.env"
                log INFO "Usa la opción 1 para iniciar una instalación nueva"
                sleep 2
            else
                source "$CONFIG_FILE"
                export_config_vars
                full_interactive_install
            fi ;;
        3)  exit 0 ;;
        *)  log ERR "Opción no válida"; sleep 1 ;;
    esac
}


# ─────────────────────────────────────────────────────────────────────────────
#  INSTALACIÓN INTERACTIVA
# ─────────────────────────────────────────────────────────────────────────────
full_interactive_install() {
    check_root
    load_or_create_config

    # Detección de hardware
    section "Detección de hardware"
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    GPU_INFO=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" || true)
    log INFO "CPU: $CPU_MODEL ($(nproc) cores)"
    log INFO "RAM: ${RAM_GB} GB"
    [ -n "$GPU_INFO" ] && log INFO "GPU: $(echo "$GPU_INFO" | head -1 | sed 's/.*: //')"
    [ -d /sys/firmware/efi ] && log INFO "Firmware: UEFI" || log INFO "Firmware: BIOS/Legacy"

    run_module "00-check-dependencies" || { log ERR "Dependencias insatisfechas"; exit 1; }

    # Construir plan de módulos
    MODULES_TO_RUN=(); MODULES_LABELS=(); MODULES_REQUIRED=()
    _add() { MODULES_TO_RUN+=("$1"); MODULES_LABELS+=("$2"); MODULES_REQUIRED+=("$3"); }

    _add "01-prepare-disk"           "Preparar disco"               1
    _add "02-debootstrap"            "Sistema base Ubuntu"          1
    _add "03-configure-base"         "Configuración base"           1
    _add "04-install-bootloader"     "Bootloader GRUB"              1
    _add "05-configure-network"      "Red y NetworkManager"         1
    _add "06-configure-auto-updates" "Actualizaciones automáticas"  1

    if [ "${INSTALL_GNOME:-false}" = "true" ]; then
        _add "10-install-gnome-core" "GNOME — entorno gráfico"       1
        _add "10-user-config"        "GNOME — configuración visual"  1
        [ "${GNOME_OPTIMIZE_MEMORY:-false}" = "true" ]   && _add "10-optimize" "GNOME — optimización memoria" 0
        [ "${GNOME_TRANSPARENT_THEME:-false}" = "true" ]  && _add "10-theme"   "GNOME — tema transparente"    0
    fi

    _add "13-install-fonts" "Fuentes tipográficas" 1
    [ "${INSTALL_MULTIMEDIA:-false}" = "true" ]  && _add "12-install-multimedia" "Multimedia"         0
    { [ "${HAS_WIFI:-false}" = "true" ] || [ "${HAS_BLUETOOTH:-false}" = "true" ]; } \
        && _add "14-configure-wireless" "WiFi y Bluetooth" 0
    [ "${INSTALL_DEVELOPMENT:-false}" = "true" ] && _add "15-install-development" "Desarrollo"        0
    [ "${INSTALL_GAMING:-false}" = "true" ]      && _add "16-configure-gaming"    "Gaming"            0
    [ "${INSTALL_AM:-false}" = "true" ]          && _add "17-install-am"          "AM / AppMan"       0
    [ "${IS_LAPTOP:-false}" = "true" ]           && _add "21-optimize-laptop"     "Laptop"            0
    [ "${MINIMIZE_SYSTEMD:-false}" = "true" ]    && _add "23-minimize-systemd"    "Minimizar systemd" 0
    [ "${ENABLE_SECURITY:-false}" = "true" ]     && _add "24-security-hardening"  "Seguridad"         0

    # Plan
    local total=${#MODULES_TO_RUN[@]}
    local core_n=0 extra_n=0
    for r in "${MODULES_REQUIRED[@]}"; do
        [ "$r" = "1" ] && core_n=$(( core_n + 1 )) || extra_n=$(( extra_n + 1 ))
    done

    section "Plan de instalación — $total módulos"
    echo -e "  ${DIM}Ubuntu ${UBUNTU_VERSION} · ${HOSTNAME} · ${USERNAME}${NC}"
    echo ""

    local prev=""
    for i in "${!MODULES_TO_RUN[@]}"; do
        local req="${MODULES_REQUIRED[$i]}"
        local label="${MODULES_LABELS[$i]}"
        if [ "$req" = "1" ] && [ "$prev" != "core" ]; then
            echo -e "  ${BOLD}Core${NC}  ${DIM}— siempre se ejecutan${NC}"
            prev="core"
        elif [ "$req" = "0" ] && [ "$prev" != "extra" ]; then
            echo ""
            echo -e "  ${BOLD}Extra${NC}  ${DIM}— según tu configuración${NC}"
            prev="extra"
        fi
        printf "    %2d.  %-40s" "$(( i + 1 ))" "$label"
        [ "$req" = "1" ] && echo -e "${GREEN}core${NC}" || echo -e "${DIM}extra${NC}"
    done

    echo ""
    echo -e "  ${GREEN}$core_n core${NC}  +  ${DIM}$extra_n extra${NC}  =  ${BOLD}$total módulos${NC}"
    echo ""
    read -rp "  ¿Continuar? [s]: " pr; pr=${pr:-s}
    [[ ! $pr =~ ^[SsYy]$ ]] && { echo "  Cancelado."; return; }

    # Ejecución
    local start=$SECONDS ok=0 failed=0 skipped=0

    for i in "${!MODULES_TO_RUN[@]}"; do
        local mod="${MODULES_TO_RUN[$i]}"
        local label="${MODULES_LABELS[$i]}"
        local req="${MODULES_REQUIRED[$i]}"
        local num=$(( i + 1 ))

        echo ""
        echo -e "  ${OR}─${NC} ${BOLD}$num/$total  $label${NC}  ${DIM}$([ "$req" = "1" ] && echo core || echo extra)${NC}"
        echo ""

        if [ "$req" = "0" ]; then
            read -rp "  ¿Ejecutar? (s/n/q) [s]: " ans; ans=${ans:-s}
            case $ans in
                [Qq]*) echo "  Cancelado."; return 0 ;;
                [Nn]*) log WARN "omitido: $label"; skipped=$(( skipped + 1 )); continue ;;
            esac
        fi

        local exit_code=0
        run_module "$mod" || exit_code=$?

        if [ "$exit_code" -eq 0 ]; then
            ok=$(( ok + 1 ))
        else
            failed=$(( failed + 1 ))
            if [ "$req" = "1" ]; then
                log ERR "Módulo core fallido: $label"
                read -rp "  ¿Continuar de todas formas? [n]: " ct; ct=${ct:-n}
                [[ ! $ct =~ ^[SsYy]$ ]] && { echo "  Interrumpido."; return 1; }
            else
                log WARN "módulo extra fallido, continuando: $label"
            fi
        fi
    done

    # Resultado final
    local elapsed=$(( SECONDS - start ))
    section "Instalación completada"
    [ $ok      -gt 0 ] && log OK   "$ok módulos completados"
    [ $failed  -gt 0 ] && log ERR  "$failed módulos con errores"
    [ $skipped -gt 0 ] && log WARN "$skipped módulos omitidos"
    printf "\n  Tiempo: %dm %02ds\n" "$(( elapsed / 60 ))" "$(( elapsed % 60 ))"
    log INFO "Log: $LOG_FILE"
    echo ""

    shred_config
    post_install_menu
}

# ─────────────────────────────────────────────────────────────────────────────
#  MENÚ POST-INSTALACIÓN
# ─────────────────────────────────────────────────────────────────────────────
post_install_menu() {
    while true; do
        section "¿Qué deseas hacer ahora?"
        echo "    1  Generar informe del sistema"
        echo "    2  Backup de configuración"
        echo "    3  Reiniciar  ← recomendado"
        echo "    4  Salir sin reiniciar"
        echo ""
        read -rp "  → [3]: " choice; choice=${choice:-3}
        echo ""
        case $choice in
            1) run_module "31-generate-report" ;;
            2) run_module "32-backup-config" ;;
            3) _do_reboot; return 0 ;;
            4) log WARN "Sistema instalado pero no reiniciado"
               log INFO "Desmontar: umount -R \"${TARGET:-/mnt/ubuntu}\" && reboot"
               return 0 ;;
            *) log ERR "Opción no válida" ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
#  REINICIO LIMPIO — desmonta el chroot y reinicia
# ─────────────────────────────────────────────────────────────────────────────
_do_reboot() {
    local target="${TARGET:-/mnt/ubuntu}"

    section "Preparando el reinicio"
    echo -n "  Cerrando procesos en $target... "
    fuser -km "$target" 2>/dev/null || true
    sleep 1; echo -e "${GREEN}✓${NC}"

    echo "  Desmontando sistemas de ficheros..."
    local mounts=(
        "$target/tmp" "$target/run"
        "$target/dev/shm" "$target/dev/pts" "$target/dev"
        "$target/sys/firmware/efi/efivars" "$target/sys"
        "$target/proc" "$target/boot/efi" "$target"
    )
    for mnt in "${mounts[@]}"; do
        mountpoint -q "$mnt" 2>/dev/null \
            && { umount -l "$mnt" 2>/dev/null \
                && echo -e "    ${GREEN}✓${NC}  $mnt" \
                || log WARN "no se pudo desmontar: $mnt"; }
    done

    echo -n "  Sincronizando disco... "; sync; echo -e "${GREEN}✓${NC}"
    log OK "Sistema desmontado"
    log INFO "Reiniciando — retira el medio de instalación"
    sleep 3
    reboot
}


# ─────────────────────────────────────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────────────────────────────────────
check_root

# Flags opcionales para desarrollo/diagnóstico
case "${1:-}" in
    --debug)  VERBOSE_MODE=true; export VERBOSE_MODE; set -x ;;
    --module) [ -z "${2:-}" ] && { log ERR "Especifica el nombre del módulo"; exit 1; }
              source "$CONFIG_FILE" 2>/dev/null || true
              run_module "$2"; exit $? ;;
esac

while true; do
    show_menu
done
