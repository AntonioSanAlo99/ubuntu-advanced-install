#!/bin/bash
# Módulo 15: Instalar herramientas de desarrollo

source "$(dirname "$0")/../config.env"

echo "Instalando herramientas de desarrollo..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

# ============================================================================
# PREGUNTAS INTERACTIVAS (solo si no está automatizado)
# ============================================================================

if [ -z "$INSTALL_VSCODE" ]; then
    echo ""
    read -p "¿Instalar Visual Studio Code? (s/n) [s]: " INSTALL_VSCODE
    INSTALL_VSCODE=${INSTALL_VSCODE:-s}
fi

if [ -z "$INSTALL_NODEJS" ]; then
    echo ""
    echo "NodeJS es recomendado para VS Code y desarrollo web."
    echo "Opciones:"
    echo "  1) No instalar NodeJS"
    echo "  2) NodeJS LTS desde repos Ubuntu (puede ser antiguo)"
    echo "  3) NodeJS LTS desde NodeSource (actualizado)"
    read -p "Selecciona opción [2]: " NODEJS_OPTION
    NODEJS_OPTION=${NODEJS_OPTION:-2}
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
INSTALL_VSCODE="$INSTALL_VSCODE"
NODEJS_OPTION="${NODEJS_OPTION:-2}"

# ============================================================================
# HERRAMIENTAS BASE
# ============================================================================

echo "Instalando herramientas base..."
apt install -y \$APT_FLAGS \
    git \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    autoconf \
    automake \
    pkg-config \
    curl \
    wget

# Python
apt install -y \$APT_FLAGS \
    python3 \
    python3-pip \
    python3-venv

echo "✓ Herramientas base instaladas"

# ============================================================================
# NODEJS
# ============================================================================

if [ "\$NODEJS_OPTION" = "2" ]; then
    echo "Instalando NodeJS desde repos Ubuntu..."
    apt install -y \$APT_FLAGS nodejs npm
    echo "✓ NodeJS instalado ($(node --version 2>/dev/null || echo 'version Ubuntu'))"
    
elif [ "\$NODEJS_OPTION" = "3" ]; then
    echo "Instalando NodeJS LTS desde NodeSource..."
    
    # Limpiar repos anteriores de NodeSource si existen
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /usr/share/keyrings/nodesource.gpg
    
    # Instalar NodeJS 20 LTS (Iron)
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
    
    echo "✓ NodeJS LTS instalado ($(node --version))"
else
    echo "⊘ NodeJS no instalado (puedes instalarlo después con: apt install nodejs npm)"
fi

# ============================================================================
# VISUAL STUDIO CODE
# ============================================================================

if [[ "\$INSTALL_VSCODE" =~ ^[SsYy]$ ]]; then
    echo "Instalando Visual Studio Code desde Microsoft repo..."
    
    # Instalar dependencias
    apt install -y \$APT_FLAGS \
        software-properties-common \
        apt-transport-https
    
    # Añadir repo Microsoft
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
    rm /tmp/microsoft.gpg
    
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
    
    apt update
    apt install -y code
    
    if command -v code &> /dev/null; then
        echo "✓ Visual Studio Code instalado ($(code --version | head -1))"
    else
        echo "⚠ Error al instalar VS Code desde repo"
        echo "  Puedes instalarlo manualmente desde: https://code.visualstudio.com"
    fi
else
    echo "⊘ Visual Studio Code no instalado"
fi

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  HERRAMIENTAS DE DESARROLLO INSTALADAS"
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ Git, build-essential, Python"
if [[ "${NODEJS_OPTION:-2}" != "1" ]]; then
    echo "  ✓ NodeJS $([ "${NODEJS_OPTION}" = "3" ] && echo "(LTS NodeSource)" || echo "(Ubuntu repos)")"
fi
if [[ "${INSTALL_VSCODE:-s}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Visual Studio Code (Microsoft repo)"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""

