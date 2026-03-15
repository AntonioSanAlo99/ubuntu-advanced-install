#!/bin/bash
# MÓDULO 23: Instalar herramientas de desarrollo

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


echo "Instalando herramientas de desarrollo..."

# ============================================================================
# PREGUNTAS INTERACTIVAS (solo si no está automatizado)
# ============================================================================

if [ -z "$INSTALL_VSCODE" ]; then
    echo ""
    read -p "¿Instalar Visual Studio Code? (s/n) [s]: " INSTALL_VSCODE
    INSTALL_VSCODE=${INSTALL_VSCODE:-s}
fi

if [ -z "$NODEJS_OPTION" ]; then
    echo ""
    echo "NodeJS es recomendado para VS Code y desarrollo web."
    echo "Opciones:"
    echo "  1) No instalar NodeJS"
    echo "  2) NodeJS LTS desde NodeSource (recomendado)"
    read -p "Selecciona opción [2]: " NODEJS_OPTION
    NODEJS_OPTION=${NODEJS_OPTION:-2}
fi

if [ -z "$INSTALL_RUST" ]; then
    echo ""
    read -p "¿Instalar Rust usando rustup? (s/n) [n]: " INSTALL_RUST
    INSTALL_RUST=${INSTALL_RUST:-n}
fi

if [ -z "$INSTALL_TOPGRADE" ]; then
    echo ""
    echo "Topgrade actualiza TODO el sistema con un solo comando:"
    echo "  APT, Snap, Flatpak, Cargo, pip, npm, firmware, etc."
    read -p "¿Instalar topgrade? (s/n) [s]: " INSTALL_TOPGRADE
    INSTALL_TOPGRADE=${INSTALL_TOPGRADE:-s}
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

INSTALL_VSCODE="$INSTALL_VSCODE"
NODEJS_OPTION="${NODEJS_OPTION:-2}"
INSTALL_RUST="$INSTALL_RUST"
INSTALL_TOPGRADE="$INSTALL_TOPGRADE"
USERNAME="$USERNAME"

# ============================================================================
# HERRAMIENTAS BASE
# ============================================================================

echo "Instalando herramientas base..."
apt install -y \
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
apt install -y \
    python3 \
    python3-pip \
    python3-venv

echo "✓  Herramientas base instaladas"

# ============================================================================
# NODEJS
# ============================================================================

if [ "\$NODEJS_OPTION" = "2" ]; then
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
    
    echo "✓  Repositorio NodeSource configurado en formato DEB822"
    
    apt update
    apt install -y nodejs
    
    echo "✓  NodeJS 24 LTS (Krypton) instalado ($(node --version))"
else
    echo "⊘ NodeJS no instalado (puedes instalarlo después con: apt install nodejs npm)"
fi

# ============================================================================
# VISUAL STUDIO CODE
# ============================================================================

if [[ "\$INSTALL_VSCODE" =~ ^[SsYy]$ ]]; then
    echo "Instalando Visual Studio Code desde Microsoft repo..."
    
    # Instalar dependencias
    apt install -y \
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
    
    echo "✓  Repositorio VSCode configurado en formato DEB822"
    
    apt update
    apt install -y code
    
    if command -v code &> /dev/null; then
        echo "  ✓ Visual Studio Code instalado ($(code --version | head -1))"
    else
        echo "  ⚠  Error al instalar VS Code desde repo"
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
    echo "✓  Rust instalado correctamente"
    rustc --version
    cargo --version
else
    echo "⚠  Error al instalar Rust"
    exit 1
fi
RUSTUP_SCRIPT

        chmod +x /tmp/install-rust.sh
        
        # Ejecutar como usuario
        su - "\$USERNAME" -c "/tmp/install-rust.sh"
        
        rm /tmp/install-rust.sh
        
        echo ""
        echo "  ✓ Rust instalado para usuario: \$USERNAME"
        echo "  Ubicación: /home/\$USERNAME/.cargo/bin/"
        echo "  Para usar: source ~/.cargo/env"
        echo ""
        echo "Componentes instalados:"
        echo "  • rustc (compilador)"
        echo "  • cargo (gestor de paquetes)"
        echo "  • rustup (gestor de toolchains)"
    else
        echo "  ⚠  No se puede instalar Rust: usuario \$USERNAME no encontrado"
        echo "  Puedes instalarlo después ejecutando:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
else
    echo "⊘ Rust no instalado"
    echo "  Puedes instalarlo después con: curl https://sh.rustup.rs | sh"
fi

# ============================================================================
# TOPGRADE (actualizador universal)
# ============================================================================
# https://github.com/topgrade-rs/topgrade
# .deb de GitHub releases — binario estático, sin dependencias de Rust.

if [[ "\$INSTALL_TOPGRADE" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Topgrade..."

    TOPGRADE_DEB_URL=\$(curl --max-time 15 -s https://api.github.com/repos/topgrade-rs/topgrade/releases/latest \
        | grep "browser_download_url.*amd64\.deb\"" | cut -d '"' -f 4 | head -1)

    if [ -n "\$TOPGRADE_DEB_URL" ] \
       && wget --timeout=30 --tries=2 -q "\$TOPGRADE_DEB_URL" -O /tmp/topgrade.deb; then
        dpkg -i /tmp/topgrade.deb 2>/dev/null || true
        apt-get install -f -y 2>/dev/null
        rm -f /tmp/topgrade.deb

        if command -v topgrade >/dev/null 2>&1; then
            echo "  ✓ Topgrade instalado"
        else
            echo "  ⚠ Topgrade: instalación falló"
        fi
    else
        echo "  ⚠ Topgrade: descarga falló — https://github.com/topgrade-rs/topgrade/releases"
    fi
else
    echo "⊘ Topgrade no instalado"
fi

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  HERRAMIENTAS DE DESARROLLO INSTALADAS"
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ Git, build-essential, Python"
if [[ "${NODEJS_OPTION:-2}" != "1" ]]; then
    echo "  ✓ NodeJS LTS (NodeSource)"
fi
if [[ "${INSTALL_VSCODE:-s}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Visual Studio Code (Microsoft repo)"
fi
if [[ "${INSTALL_RUST:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Rust (rustup en /home/$USERNAME/.cargo/)"
fi
if [[ "${INSTALL_TOPGRADE:-s}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Topgrade (actualizador universal: topgrade)"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
