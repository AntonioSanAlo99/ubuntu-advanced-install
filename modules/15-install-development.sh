#!/bin/bash
# Módulo 15: Instalar herramientas de desarrollo

set -e  # Exit on error  # Detectar errores en pipelines


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

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

if [ -z "$INSTALL_RUST" ]; then
    echo ""
    read -p "¿Instalar Rust usando rustup? (s/n) [n]: " INSTALL_RUST
    INSTALL_RUST=${INSTALL_RUST:-n}
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

APT_FLAGS="$APT_FLAGS"
INSTALL_VSCODE="$INSTALL_VSCODE"
NODEJS_OPTION="${NODEJS_OPTION:-2}"
INSTALL_RUST="$INSTALL_RUST"
USERNAME="$USERNAME"

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

step " Herramientas base instaladas"

# ============================================================================
# NODEJS
# ============================================================================

if [ "\$NODEJS_OPTION" = "2" ]; then
    echo "Instalando NodeJS desde repos Ubuntu..."
    apt install -y \$APT_FLAGS nodejs npm
    step " NodeJS instalado ($(node --version 2>/dev/null || echo 'version Ubuntu'))"
    
elif [ "\$NODEJS_OPTION" = "3" ]; then
    echo "Instalando NodeJS LTS desde NodeSource..."
    
    # Limpiar repos anteriores de NodeSource si existen
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/sources.list.d/nodesource.sources
    rm -f /usr/share/keyrings/nodesource.gpg
    
    # Crear directorio para keyrings
    mkdir -p /etc/apt/keyrings
    
    # Descargar GPG key de NodeSource
    echo "Descargando clave GPG de NodeSource..."
    curl --max-time 30 --retry 3 -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    # Crear repositorio en formato DEB822
    cat > /etc/apt/sources.list.d/nodesource.sources << NODESOURCE_EOF
# NodeSource Node.js 24.x LTS (Krypton) Repository
# Formato DEB822 (APT 3.0+)

Types: deb
URIs: https://deb.nodesource.com/node_24.x
Suites: nodistro
Components: main
Signed-By: /etc/apt/keyrings/nodesource.gpg
NODESOURCE_EOF
    
    step " Repositorio NodeSource configurado en formato DEB822"
    
    apt update -qq
    apt install -y nodejs
    
    step " NodeJS 24 LTS (Krypton) instalado ($(node --version))"
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
    
    # Crear directorio para keyrings
    mkdir -p /etc/apt/keyrings
    
    # Añadir repo Microsoft
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    install -D -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
    rm /tmp/microsoft.gpg
    
    # Crear repositorio en formato DEB822
    cat > /etc/apt/sources.list.d/vscode.sources << VSCODE_EOF
# Microsoft Visual Studio Code Repository
# Formato DEB822 (APT 3.0+)

Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64 arm64 armhf
Signed-By: /etc/apt/keyrings/microsoft.gpg
VSCODE_EOF
    
    step " Repositorio VSCode configurado en formato DEB822"
    
    apt update -qq
    apt install -y code
    
    if command -v code &> /dev/null; then
        step " Visual Studio Code instalado ($(code --version | head -1))"
    else
        warn " Error al instalar VS Code desde repo"
        echo "  Puedes instalarlo manualmente desde: https://code.visualstudio.com"
    fi
else
    echo "⊘ Visual Studio Code no instalado"
fi

# ============================================================================
# RUST (usando rustup)
# ============================================================================

if [[ "\$INSTALL_RUST" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Rust usando rustup..."
    
    # rustup requiere un usuario para instalar
    # Lo instalamos para el usuario configurado en el sistema
    USERNAME="$USERNAME"
    
    if [ -n "\$USERNAME" ] && id "\$USERNAME" &>/dev/null; then
        # Crear script para instalar rustup como usuario
        cat > /tmp/install-rust.sh << 'RUSTUP_SCRIPT'
#!/bin/bash
# Script para instalar rustup como usuario

# Descargar e instalar rustup (modo no interactivo)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Source del entorno de Rust
source "\$HOME/.cargo/env"

# Verificar instalación
if command -v rustc &>/dev/null; then
    step " Rust instalado correctamente"
    rustc --version
    cargo --version
else
    warn " Error al instalar Rust"
    exit 1
fi
RUSTUP_SCRIPT

        chmod +x /tmp/install-rust.sh
        
        # Ejecutar como usuario
        su - "\$USERNAME" -c "/tmp/install-rust.sh"
        
        rm /tmp/install-rust.sh
        
        echo ""
        step " Rust instalado para usuario: \$USERNAME"
        echo "  Ubicación: /home/\$USERNAME/.cargo/bin/"
        echo "  Para usar: source ~/.cargo/env"
        echo ""
        echo "Componentes instalados:"
        echo "  • rustc (compilador)"
        echo "  • cargo (gestor de paquetes)"
        echo "  • rustup (gestor de toolchains)"
    else
        warn " No se puede instalar Rust: usuario \$USERNAME no encontrado"
        echo "  Puedes instalarlo después ejecutando:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
else
    echo "⊘ Rust no instalado"
    echo "  Puedes instalarlo después con: curl https://sh.rustup.rs | sh"
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
if [[ "${INSTALL_RUST:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Rust (rustup en /home/$USERNAME/.cargo/)"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""


exit 0
