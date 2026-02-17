#!/bin/bash
# Módulo 10: Instalar GNOME por componentes (sin metapaquetes)

source "$(dirname "$0")/../config.env"

echo "Instalando GNOME Shell por componentes..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
# FIX: Perl locale warnings
export LANG=es_ES.UTF-8; export LC_ALL=es_ES.UTF-8; export LANGUAGE=es_ES
APT_FLAGS="$APT_FLAGS"
GDM_AUTOLOGIN="${GDM_AUTOLOGIN:-false}"
USERNAME="$USERNAME"

echo "Instalando core de GNOME..."
apt install -y \$APT_FLAGS \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    nautilus-admin \
    xdg-terminal-exec \
    gdm3 \
    plymouth \
    plymouth-theme-spinner \
    bolt

echo "Instalando utilidades GNOME..."
apt install -y \$APT_FLAGS \
    gnome-keyring \
    lxtask \
    file-roller \
    gedit \
    evince \
    viewnior \
    gnome-disk-utility \
    gnome-tweaks \
    gnome-shell-extension-manager \
    zenity

echo "Instalando gestión de software..."
apt install -y \$APT_FLAGS \
    software-properties-gtk \
    gdebi \
    update-notifier \
    update-manager

echo "Instalando extensiones de GNOME..."
apt install -y \$APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-ubuntu-dock

# Aplicar tema de iconos
apt install -y \$APT_FLAGS elementary-icon-theme

# Script en /etc/profile.d que aplica gsettings en el primer login
cat > /etc/profile.d/01-gnome-config.sh << 'GSEOF'
#!/bin/bash
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    # Aplicar tema de iconos
    CURRENT=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)
    if [ "$CURRENT" != "'elementary'" ]; then
        gsettings set org.gnome.desktop.interface icon-theme 'elementary'
    fi
    
    # Activar extensiones instaladas
    EXTENSIONS=(
        "appindicatorsupport@rgcjonas.gmail.com"
        "ding@rastersoft.com"
        "ubuntu-dock@ubuntu.com"
    )
    
    for ext in "${EXTENSIONS[@]}"; do
        gnome-extensions enable "$ext" 2>/dev/null || true
    done
    
    # Auto-eliminar este script después de ejecutarlo
    rm -f /etc/profile.d/01-gnome-config.sh
fi
GSEOF
chmod +x /etc/profile.d/01-gnome-config.sh

# Habilitar GDM
systemctl enable gdm3

# Configurar autologin si se solicitó
if [ "\$GDM_AUTOLOGIN" = "true" ]; then
    echo "Configurando autologin para \$USERNAME..."
    mkdir -p /etc/gdm3
    cat > /etc/gdm3/custom.conf << GDMEOF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=\$USERNAME

[security]

[xdmcp]

[chooser]

[debug]
GDMEOF
    echo "✓ Autologin activado para \$USERNAME"
else
    # Asegurar que autologin está desactivado (estado por defecto)
    mkdir -p /etc/gdm3
    cat > /etc/gdm3/custom.conf << GDMEOF
[daemon]
AutomaticLoginEnable=False

[security]

[xdmcp]

[chooser]

[debug]
GDMEOF
    echo "✓ Autologin desactivado (se pedirá contraseña)"
fi

echo "✓ GNOME instalado (sin metapaquetes)"

# Instalar Google Chrome
echo ""
echo "Instalando Google Chrome..."

# Descargar Google Chrome .deb oficial
cd /tmp

if wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O google-chrome.deb; then
    echo "✓ Google Chrome descargado"
    
    # Instalar dependencias necesarias
    apt install -y \$APT_FLAGS \
        fonts-liberation \
        libu2f-udev \
        libvulkan1 \
        xdg-utils \
        || true
    
    # Instalar Chrome
    if dpkg -i google-chrome.deb 2>/dev/null; then
        echo "✓ Google Chrome instalado"
    else
        echo "Resolviendo dependencias..."
        apt-get install -f -y
        dpkg -i google-chrome.deb
        echo "✓ Google Chrome instalado"
    fi
    
    rm google-chrome.deb
    
    # Verificar instalación
    if command -v google-chrome &> /dev/null; then
        CHROME_VERSION=\$(google-chrome --version)
        echo "✓ \$CHROME_VERSION instalado correctamente"
    fi
else
    echo "⚠ No se pudo descargar Google Chrome"
    echo "  Puedes instalarlo manualmente desde:"
    echo "  https://www.google.com/chrome/"
fi

cd /

# ============================================================================
# THUMBNAILERS (miniaturas de archivos)
# ============================================================================

echo "Instalando thumbnailers..."

# Thumbnailer para .exe (iconos de Windows)
apt install -y \$APT_FLAGS icoextract-thumbnailer

echo "✓ Thumbnailer .exe instalado"

# Thumbnailer para .appimage (desde kem-a)
cd /tmp
if wget -q https://github.com/kem-a/appimage-thumbnailer/releases/latest/download/appimage-thumbnailer.deb; then
    if dpkg -i appimage-thumbnailer.deb 2>/dev/null; then
        echo "✓ Thumbnailer .appimage instalado"
    else
        apt-get install -f -y
        dpkg -i appimage-thumbnailer.deb
        echo "✓ Thumbnailer .appimage instalado"
    fi
    rm appimage-thumbnailer.deb
else
    echo "⚠ No se pudo descargar thumbnailer de appimage"
    echo "  Puedes instalarlo manualmente desde:"
    echo "  https://github.com/kem-a/appimage-thumbnailer"
fi

cd /

# ============================================================================
# CONFIGURACIÓN DE NAUTILUS (sin fondo de damero)
# ============================================================================

# El fondo de damero se controla con gsettings en la sesión del usuario
# Lo añadimos al script de primer login
cat >> /etc/profile.d/01-gnome-config.sh << 'NAUTILUSEOF'

# Desactivar fondo de damero en Nautilus (transparencia)
gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always'
gsettings set org.gnome.desktop.background picture-options 'zoom'

NAUTILUSEOF

echo "✓ Configuración de Nautilus (sin damero) preparada"

CHROOTEOF

echo ""
echo "✓✓✓ GNOME instalado ✓✓✓"
echo ""
echo "Componentes instalados:"
echo "  • GNOME Shell (sin metapaquetes)"
echo "  • Extensiones básicas"
echo "  • Gestión de software (gdebi, update-manager)"
echo "  • Google Chrome (navegador predeterminado)"
echo "  • Tema de iconos: elementary"
echo "  • Thumbnailers: .exe (icoextract), .appimage"
echo "  • Nautilus sin fondo de damero"
if [ "${GDM_AUTOLOGIN:-false}" = "true" ]; then
    echo "  • GDM autologin: activado (usuario: $USERNAME)"
else
    echo "  • GDM autologin: desactivado (se pedirá contraseña)"
fi

