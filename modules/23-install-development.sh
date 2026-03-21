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

if [ -z "$INSTALL_BOXES" ]; then
    echo ""
    read -p "¿Instalar GNOME Boxes (máquinas virtuales)? (s/n) [n]: " INSTALL_BOXES
    INSTALL_BOXES=${INSTALL_BOXES:-n}
fi

if [ -z "$INSTALL_LAZY_TOOLS" ]; then
    echo ""
    read -p "¿Instalar lazy TUI tools (lazygit + lazydocker + LazyVim)? (s/n) [n]: " INSTALL_LAZY_TOOLS
    INSTALL_LAZY_TOOLS=${INSTALL_LAZY_TOOLS:-n}
fi

if [ -z "$INSTALL_BUN" ]; then
    read -p "¿Instalar Bun runtime? (s/n) [n]: " INSTALL_BUN
    INSTALL_BUN=${INSTALL_BUN:-n}
fi

if [ -z "$INSTALL_DENO" ]; then
    read -p "¿Instalar Deno runtime? (s/n) [n]: " INSTALL_DENO
    INSTALL_DENO=${INSTALL_DENO:-n}
fi

if [ -z "$INSTALL_DOCKER_TOOLS" ]; then
    read -p "¿Instalar Docker tools (unregistry + docker-pussh + uncloud)? (s/n) [n]: " INSTALL_DOCKER_TOOLS
    INSTALL_DOCKER_TOOLS=${INSTALL_DOCKER_TOOLS:-n}
fi

if [ -z "$INSTALL_MELD" ]; then
    read -p "¿Instalar Meld (diff/merge visual)? (s/n) [n]: " INSTALL_MELD
    INSTALL_MELD=${INSTALL_MELD:-n}
fi

if [ -z "$INSTALL_POSTMAN" ]; then
    read -p "¿Instalar Postman (API testing)? (s/n) [n]: " INSTALL_POSTMAN
    INSTALL_POSTMAN=${INSTALL_POSTMAN:-n}
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
apt-get install -y \
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
apt-get install -y \
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
    
    apt-get update
    apt-get install -y nodejs
    
    echo "✓  NodeJS 24 LTS (Krypton) instalado ($(node --version))"
else
    echo "⊘ NodeJS no instalado (puedes instalarlo después con: apt-get install nodejs npm)"
fi

# ============================================================================
# VISUAL STUDIO CODE
# ============================================================================

if [[ "\$INSTALL_VSCODE" =~ ^[SsYy]$ ]]; then
    echo "Instalando Visual Studio Code desde Microsoft repo..."
    
    # Instalar dependencias
    apt-get install -y \
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
    
    apt-get update
    apt-get install -y code
    
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
# GHOSTTY (terminal GPU-accelerated)
# ============================================================================
# PPA unofficial de mkasberg — método recomendado para Ubuntu/Debian.
# Ref: https://github.com/mkasberg/ghostty-ubuntu
# Alternativa: snap install ghostty --classic

echo ""
echo "Instalando Ghostty..."
echo "  Ref: https://github.com/mkasberg/ghostty-ubuntu"

GHOSTTY_OK=false

# Script de instalación de mkasberg — compila .deb desde fuente
MKASBERG_SCRIPT=\$(curl --max-time 30 -fsSL \
    https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh 2>/dev/null)

if [ -n "\$MKASBERG_SCRIPT" ]; then
    echo "\$MKASBERG_SCRIPT" | /bin/bash 2>&1 | tail -10
    command -v ghostty >/dev/null 2>&1 && GHOSTTY_OK=true
fi

if [ "\$GHOSTTY_OK" = "true" ]; then
    echo "  ✓ Ghostty instalado"

    # ── Configuración por defecto para todos los usuarios ────────────────
    # Ghostty lee config de ~/.config/ghostty/config (por usuario)
    # y /etc/ghostty/config (system-wide, no oficial pero funciona).
    # Usamos /etc/skel para que se copie a cada usuario nuevo.
    USERNAME="$USERNAME"
    if [ -n "\$USERNAME" ] && id "\$USERNAME" &>/dev/null; then
        GHOSTTY_DIR="/home/\$USERNAME/.config/ghostty"
        mkdir -p "\$GHOSTTY_DIR"
        cat > "\$GHOSTTY_DIR/config" << 'GHOSTTYCFG'
# Ghostty — configuración ubuntu-advanced-install
background-opacity = 0.8
theme = Adwaita Dark
GHOSTTYCFG
        chown -R "\$USERNAME":"\$USERNAME" "/home/\$USERNAME/.config/ghostty"
        echo "  ✓ Config Ghostty: background-opacity=0.8, theme=Adwaita Dark"
    fi

    # También en skel para futuros usuarios
    mkdir -p /etc/skel/.config/ghostty
    cat > /etc/skel/.config/ghostty/config << 'GHOSTTYCFG'
# Ghostty — configuración ubuntu-advanced-install
background-opacity = 0.8
theme = Adwaita Dark
GHOSTTYCFG
else
    echo "  ⚠ Ghostty: instalación falló — https://github.com/mkasberg/ghostty-ubuntu"
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

        chmod 755 /tmp/install-rust.sh
        
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
        dpkg -i /tmp/topgrade.deb || true
        apt-get install -f -y
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

# ============================================================================
# GNOME BOXES (máquinas virtuales)
# ============================================================================
# Gestor de VMs integrado en GNOME. Usa libvirt/QEMU por debajo.
# Permite crear, ejecutar y gestionar máquinas virtuales con interfaz simple.
# Soporta: ISOs locales, imágenes de disco, descargas automáticas de distros.

INSTALL_BOXES_VAR="$INSTALL_BOXES"
if [[ "\$INSTALL_BOXES_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando GNOME Boxes..."
    apt-get install -y gnome-boxes
    echo "✓  GNOME Boxes instalado"
else
    echo "⊘ GNOME Boxes no instalado"
fi

# ============================================================================
# PYTHON PIP + VENV
# ============================================================================
echo ""
echo "Instalando pip + venv..."
apt-get install -y python3-pip python3-venv 2>/dev/null || true
echo "✓  pip + venv instalados"

# ============================================================================
# CLI MODERNAS (eza, fzf, zoxide, yazi)
# ============================================================================
# Se instalan siempre con desarrollo — son mejoras de productividad fundamentales.

echo ""
echo "Instalando CLI modernas..."

# ── fzf — fuzzy finder (ya puede estar de LazyVim, pero lo aseguramos) ────
apt-get install -y fzf 2>/dev/null || true
echo "  ✓ fzf"

# ── eza — ls moderno con colores, iconos, Git ─────────────────────────────
# Repo APT oficial de eza-community
mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    > /etc/apt/sources.list.d/gierens.list
chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list 2>/dev/null || true
apt-get update 2>/dev/null || true
apt-get install -y eza 2>/dev/null && echo "  ✓ eza" || echo "  ⚠ eza: instalación falló"

# ── zoxide — cd inteligente (aprende tus directorios frecuentes) ──────────
ZOXIDE_VER=\$(curl -s "https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest" \
    | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
if [ -n "\$ZOXIDE_VER" ]; then
    curl -Lo /tmp/zoxide.deb \
        "https://github.com/ajeetdsouza/zoxide/releases/download/v\${ZOXIDE_VER}/zoxide_\${ZOXIDE_VER}-1_amd64.deb" 2>/dev/null
    dpkg -i /tmp/zoxide.deb 2>/dev/null && echo "  ✓ zoxide \$ZOXIDE_VER" \
        || echo "  ⚠ zoxide: instalación falló"
    rm -f /tmp/zoxide.deb
fi

# ── yazi — file manager terminal (Rust, async I/O, previews) ──────────────
YAZI_VER=\$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" \
    | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
if [ -n "\$YAZI_VER" ]; then
    curl -Lo /tmp/yazi.zip \
        "https://github.com/sxyazi/yazi/releases/download/v\${YAZI_VER}/yazi-x86_64-unknown-linux-gnu.zip" 2>/dev/null
    if [ -s /tmp/yazi.zip ]; then
        apt-get install -y unzip 2>/dev/null || true
        unzip -o /tmp/yazi.zip -d /tmp/yazi-extract 2>/dev/null
        install /tmp/yazi-extract/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/yazi 2>/dev/null
        install /tmp/yazi-extract/yazi-x86_64-unknown-linux-gnu/ya /usr/local/bin/ya 2>/dev/null
        rm -rf /tmp/yazi.zip /tmp/yazi-extract
        echo "  ✓ yazi \$YAZI_VER"
    fi
fi

# Aliases eza + zoxide en skel .bashrc
if command -v eza >/dev/null 2>&1; then
    if ! grep -q "alias ls=" /etc/skel/.bashrc 2>/dev/null; then
        cat >> /etc/skel/.bashrc << 'EZA_ALIASES'

# eza (ls moderno)
alias ls='eza'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias tree='eza --tree --icons'
EZA_ALIASES
    fi
fi
if command -v zoxide >/dev/null 2>&1; then
    if ! grep -q "zoxide init" /etc/skel/.bashrc 2>/dev/null; then
        echo 'eval "$(zoxide init bash)"' >> /etc/skel/.bashrc
    fi
fi

echo "✓  CLI modernas instaladas"

# ============================================================================
# JS RUNTIMES (Bun, Deno)
# ============================================================================
INSTALL_BUN_VAR="$INSTALL_BUN"
INSTALL_DENO_VAR="$INSTALL_DENO"

if [[ "\$INSTALL_BUN_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Bun..."
    BUN_VER=\$(curl -s "https://api.github.com/repos/oven-sh/bun/releases/latest" \
        | grep -Po '"tag_name": "bun-v\K[0-9.]+' 2>/dev/null || echo "")
    if [ -n "\$BUN_VER" ]; then
        curl -Lo /tmp/bun.zip \
            "https://github.com/oven-sh/bun/releases/download/bun-v\${BUN_VER}/bun-linux-x64.zip" 2>/dev/null
        unzip -o /tmp/bun.zip -d /tmp/bun-extract 2>/dev/null
        install /tmp/bun-extract/bun-linux-x64/bun /usr/local/bin/bun 2>/dev/null
        rm -rf /tmp/bun.zip /tmp/bun-extract
        echo "✓  Bun \$BUN_VER instalado"
    else
        echo "⚠  Bun: no se pudo obtener versión"
    fi
else
    echo "⊘ Bun no instalado"
fi

if [[ "\$INSTALL_DENO_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Deno..."
    DENO_VER=\$(curl -s "https://api.github.com/repos/denoland/deno/releases/latest" \
        | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
    if [ -n "\$DENO_VER" ]; then
        curl -Lo /tmp/deno.zip \
            "https://github.com/denoland/deno/releases/download/v\${DENO_VER}/deno-x86_64-unknown-linux-gnu.zip" 2>/dev/null
        unzip -o /tmp/deno.zip -d /tmp 2>/dev/null
        install /tmp/deno /usr/local/bin/deno 2>/dev/null
        rm -f /tmp/deno.zip /tmp/deno
        echo "✓  Deno \$DENO_VER instalado"
    else
        echo "⚠  Deno: no se pudo obtener versión"
    fi
else
    echo "⊘ Deno no instalado"
fi

# ============================================================================
# DOCKER TOOLS (unregistry, docker-pussh, uncloud)
# ============================================================================
INSTALL_DOCKER_TOOLS_VAR="$INSTALL_DOCKER_TOOLS"

if [[ "\$INSTALL_DOCKER_TOOLS_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Docker tools (unregistry + docker-pussh + uncloud)..."

    for tool in unregistry docker-pussh uncloud; do
        case \$tool in
            unregistry) REPO="psviderski/unregistry"; BIN="unregistry" ;;
            docker-pussh) REPO="psviderski/unregistry"; BIN="docker-pussh" ;;
            uncloud) REPO="psviderski/uncloud"; BIN="uc" ;;
        esac

        TOOL_VER=\$(curl -s "https://api.github.com/repos/\$REPO/releases/latest" \
            | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
        if [ -n "\$TOOL_VER" ]; then
            curl -Lo "/tmp/\${tool}.tar.gz" \
                "https://github.com/\${REPO}/releases/download/v\${TOOL_VER}/\${BIN}_linux_amd64.tar.gz" 2>/dev/null
            if [ -s "/tmp/\${tool}.tar.gz" ]; then
                tar xf "/tmp/\${tool}.tar.gz" -C /tmp "\$BIN" 2>/dev/null
                install "/tmp/\$BIN" "/usr/local/bin/\$BIN" 2>/dev/null
                rm -f "/tmp/\${tool}.tar.gz" "/tmp/\$BIN"
                echo "  ✓ \$tool \$TOOL_VER"
            fi
        else
            echo "  ⚠ \$tool: no se pudo obtener versión"
        fi
    done

    # docker-pussh se instala como plugin de Docker CLI
    mkdir -p /usr/local/lib/docker/cli-plugins
    if [ -f /usr/local/bin/docker-pussh ]; then
        ln -sf /usr/local/bin/docker-pussh /usr/local/lib/docker/cli-plugins/docker-pussh
        echo "  ✓ docker-pussh registrado como plugin Docker CLI"
    fi

    echo "✓  Docker tools instalados"
else
    echo "⊘ Docker tools (unregistry/pussh/uncloud) no instalados"
fi

# ============================================================================
# MELD (diff visual)
# ============================================================================
INSTALL_MELD_VAR="$INSTALL_MELD"

if [[ "\$INSTALL_MELD_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Meld..."
    apt-get install -y meld
    echo "✓  Meld instalado"
    # Configurar como diff tool por defecto de Git
    git config --system diff.tool meld 2>/dev/null || true
    git config --system merge.tool meld 2>/dev/null || true
    echo "  ✓ Meld configurado como diff/merge tool de Git"
else
    echo "⊘ Meld no instalado"
fi

# ============================================================================
# POSTMAN (API testing)
# ============================================================================
INSTALL_POSTMAN_VAR="$INSTALL_POSTMAN"

if [[ "\$INSTALL_POSTMAN_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Postman..."
    curl -Lo /tmp/postman.tar.gz "https://dl.pstmn.io/download/latest/linux_64" 2>/dev/null
    if [ -s /tmp/postman.tar.gz ]; then
        tar xf /tmp/postman.tar.gz -C /opt/ 2>/dev/null
        ln -sf /opt/Postman/Postman /usr/local/bin/postman
        # Desktop entry
        cat > /usr/share/applications/postman.desktop << 'POSTMAN_DESKTOP'
[Desktop Entry]
Name=Postman
GenericName=API Client
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
POSTMAN_DESKTOP
        rm -f /tmp/postman.tar.gz
        echo "✓  Postman instalado"
    else
        echo "⚠  Postman: descarga falló"
    fi
else
    echo "⊘ Postman no instalado"
fi

# ============================================================================
# LAZY TUI TOOLS (lazygit, lazydocker, LazyVim)
# ============================================================================
# Binarios precompilados de GitHub releases + neovim con config LazyVim.
# Se instalan solo si el usuario lo pidió.

INSTALL_LAZY_VAR="$INSTALL_LAZY_TOOLS"

if [[ "\$INSTALL_LAZY_VAR" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando lazy TUI tools..."

    # ── lazygit — TUI para Git ────────────────────────────────────────────────
    LAZYGIT_VER=\$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
    if [ -n "\$LAZYGIT_VER" ]; then
        curl -Lo /tmp/lazygit.tar.gz \
            "https://github.com/jesseduffield/lazygit/releases/download/v\${LAZYGIT_VER}/lazygit_\${LAZYGIT_VER}_Linux_x86_64.tar.gz" 2>/dev/null
        if [ -s /tmp/lazygit.tar.gz ]; then
            tar xf /tmp/lazygit.tar.gz -C /tmp lazygit 2>/dev/null
            install /tmp/lazygit /usr/local/bin/lazygit
            rm -f /tmp/lazygit /tmp/lazygit.tar.gz
            echo "  ✓ lazygit \$LAZYGIT_VER instalado"
        fi
    else
        echo "  ⚠ lazygit: no se pudo obtener versión"
    fi

    # ── lazydocker — TUI para Docker ──────────────────────────────────────────
    LAZYDOCKER_VER=\$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" \
        | grep -Po '"tag_name": "v\K[0-9.]+' 2>/dev/null || echo "")
    if [ -n "\$LAZYDOCKER_VER" ]; then
        curl -Lo /tmp/lazydocker.tar.gz \
            "https://github.com/jesseduffield/lazydocker/releases/download/v\${LAZYDOCKER_VER}/lazydocker_\${LAZYDOCKER_VER}_Linux_x86_64.tar.gz" 2>/dev/null
        if [ -s /tmp/lazydocker.tar.gz ]; then
            tar xf /tmp/lazydocker.tar.gz -C /tmp lazydocker 2>/dev/null
            install /tmp/lazydocker /usr/local/bin/lazydocker
            rm -f /tmp/lazydocker /tmp/lazydocker.tar.gz
            echo "  ✓ lazydocker \$LAZYDOCKER_VER instalado"
        fi
    else
        echo "  ⚠ lazydocker: no se pudo obtener versión"
    fi

    # ── LazyVim — Neovim con config IDE preconfigurada ────────────────────────
    # Requisitos: neovim ≥0.9, git, ripgrep, fd-find, fzf, lazygit
    apt-get install -y neovim ripgrep fd-find fzf 2>/dev/null || true

    # Clonar starter template de LazyVim en skel (todos los usuarios)
    if command -v nvim >/dev/null 2>&1; then
        NVIM_VER=\$(nvim --version 2>/dev/null | head -1 || echo "")
        echo "  Neovim: \$NVIM_VER"

        # skel — futuros usuarios
        mkdir -p /etc/skel/.config
        git clone --depth 1 https://github.com/LazyVim/starter.git \
            /etc/skel/.config/nvim 2>/dev/null || true
        rm -rf /etc/skel/.config/nvim/.git

        # Usuario principal
        USERNAME_VAR="$USERNAME"
        if [ -n "\$USERNAME_VAR" ] && [ -d "/home/\$USERNAME_VAR" ]; then
            mkdir -p "/home/\$USERNAME_VAR/.config"
            if [ ! -d "/home/\$USERNAME_VAR/.config/nvim" ]; then
                cp -r /etc/skel/.config/nvim "/home/\$USERNAME_VAR/.config/nvim"
                chown -R "\$USERNAME_VAR:\$USERNAME_VAR" "/home/\$USERNAME_VAR/.config/nvim"
            fi
        fi
        echo "  ✓ LazyVim starter clonado (plugins se instalan en primer arranque)"
    else
        echo "  ⚠ LazyVim: neovim no disponible"
    fi

    echo "✓  Lazy TUI tools instalados"
else
    echo "⊘ Lazy TUI tools no instalados"
fi

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  HERRAMIENTAS DE DESARROLLO INSTALADAS"
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ Git, build-essential, Python"
echo "  ✓ Ghostty (terminal GPU-accelerated)"
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
if [[ "${INSTALL_BOXES:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ GNOME Boxes (máquinas virtuales)"
fi
if [[ "${INSTALL_LAZY_TOOLS:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ lazygit + lazydocker + LazyVim (TUI tools)"
fi
echo "  ✓ pip + venv (Python)"
echo "  ✓ eza + fzf + zoxide + yazi (CLI modernas)"
if [[ "${INSTALL_BUN:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Bun runtime"
fi
if [[ "${INSTALL_DENO:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Deno runtime"
fi
if [[ "${INSTALL_DOCKER_TOOLS:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ unregistry + docker-pussh + uncloud"
fi
if [[ "${INSTALL_MELD:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Meld (diff/merge visual + Git)"
fi
if [[ "${INSTALL_POSTMAN:-n}" =~ ^[SsYy]$ ]]; then
    echo "  ✓ Postman (API testing)"
fi
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
