#!/bin/bash
# Header común para módulos standalone
# Este script detecta si se ejecuta durante instalación o en sistema real

# ============================================================================
# DETECCIÓN AUTOMÁTICA DE MODO
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.env"

if [ -f "$CONFIG_FILE" ]; then
    # ============================================================================
    # MODO INSTALACIÓN - Durante debootstrap
    # ============================================================================
    source "$CONFIG_FILE"
    STANDALONE_MODE=false
    CHROOT_CMD="arch-chroot"
    
    # Verificar que TARGET está definido
    if [ -z "$TARGET" ]; then
        echo "❌ Error: TARGET no definido en config.env"
        exit 1
    fi
    
else
    # ============================================================================
    # MODO STANDALONE - Sistema real ya instalado
    # ============================================================================
    STANDALONE_MODE=true
    CHROOT_CMD=""
    TARGET="/"
    
    # Detectar usuario que invocó sudo
    if [ -n "$SUDO_USER" ]; then
        USERNAME="$SUDO_USER"
    else
        USERNAME="$(whoami)"
    fi
    
    # Variables con defaults para standalone
    USE_NO_INSTALL_RECOMMENDS="${USE_NO_INSTALL_RECOMMENDS:-false}"
    UBUNTU_VERSION="${UBUNTU_VERSION:-noble}"
    
    echo "════════════════════════════════════════════════════════════════"
    echo "  MODO STANDALONE - Ejecutando en sistema instalado"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Usuario detectado: $USERNAME"
    echo ""
fi

# ============================================================================
# FUNCIONES COMUNES
# ============================================================================

# Función para ejecutar comandos (en chroot durante instalación, directo en standalone)
run_cmd() {
    if [ "$STANDALONE_MODE" = true ]; then
        # Modo standalone: ejecutar directamente
        eval "$@"
    else
        # Modo instalación: ejecutar en chroot
        arch-chroot "$TARGET" /bin/bash -c "$@"
    fi

# Configurar APT_FLAGS
APT_FLAGS=""
if [ "$USE_NO_INSTALL_RECOMMENDS" = "true" ]; then
    APT_FLAGS="--no-install-recommends"
fi

export DEBIAN_FRONTEND=noninteractive
