#!/bin/bash
# Módulo 10: Instalar GNOME por componentes (sin metapaquetes)

source "$(dirname "$0")/../config.env"

echo "Instalando GNOME Shell por componentes..."

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

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
    gnome-calculator \
    gnome-logs \
    gnome-font-viewer \
    baobab \
    lxtask \
    file-roller \
    gedit \
    evince \
    viewnior \
    gnome-disk-utility \
    gnome-tweaks \
    gnome-shell-extension-manager \
    zenity

echo "✓ Utilidades GNOME instaladas"
echo "  • Calculadora (gnome-calculator)"
echo "  • Logs (gnome-logs)"
echo "  • Gestor de tipografías (gnome-font-viewer)"
echo "  • Analizador de disco (baobab)"

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

echo "✓ Extensiones instaladas"

# ============================================================================
# ELIMINAR SNAPD Y EXTENSIÓN DE SNAP
# ============================================================================

echo "Eliminando snapd y extensiones relacionadas..."

# Desinstalar snapd completamente
apt purge -y snapd gnome-software-plugin-snap 2>/dev/null || true
apt autoremove -y

# Bloquear reinstalación de snap
cat > /etc/apt/preferences.d/99-no-snap << 'NOSNAP_EOF'
Package: snapd
Pin: release *
Pin-Priority: -1

Package: gnome-software-plugin-snap
Pin: release *
Pin-Priority: -1
NOSNAP_EOF

echo "✓ Snapd eliminado y bloqueado"

# ============================================================================
# SYSTEMD-OOMD (gestión automática de memoria baja)
# ============================================================================

echo ""
echo "Instalando systemd-oomd (gestión de memoria)..."

# systemd-oomd evita que el sistema se cuelgue por falta de RAM
if apt-cache show systemd-oomd &>/dev/null; then
    apt-get install -y systemd-oomd
    systemctl enable systemd-oomd
    echo "✓ systemd-oomd instalado (protección contra OOM)"
else
    echo "⚠ systemd-oomd no disponible en esta versión de Ubuntu"
fi

# ============================================================================
# TEMA DE ICONOS
# ============================================================================

echo ""
echo "Instalando tema de iconos elementary..."

apt install -y \$APT_FLAGS elementary-icon-theme

echo "✓ GNOME core instalado"

# ============================================================================
# CONFIGURACIÓN AUTOMÁTICA EN PRIMER LOGIN
# ============================================================================

echo "Configurando activación automática de extensiones y tema..."

# Script que se ejecuta en el primer login del usuario
cat > /etc/profile.d/01-gnome-config.sh << 'GSEOF'
#!/bin/bash
# Script de configuración automática de GNOME (se ejecuta una vez)

# Solo ejecutar si estamos en sesión GNOME con D-Bus activo
if [ -n "\$DBUS_SESSION_BUS_ADDRESS" ] && [ "\$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    
    # Archivo de marca para evitar ejecutar múltiples veces
    MARKER="\$HOME/.config/.gnome-configured"
    
    if [ ! -f "\$MARKER" ]; then
        echo "Configurando GNOME por primera vez..."
        
        # Esperar a que GNOME Shell esté completamente iniciado
        sleep 2
        
        # =====================================================================
        # TEMA DE ICONOS
        # =====================================================================
        
        echo "Aplicando tema de iconos elementary..."
        gsettings set org.gnome.desktop.interface icon-theme 'elementary' 2>/dev/null
        echo "✓ Tema de iconos: elementary"
        
        # =====================================================================
        # ACTIVAR EXTENSIONES
        # =====================================================================
        
        echo "Activando extensiones de GNOME Shell..."
        
        # Lista de extensiones a activar
        EXTENSIONS=(
            "appindicatorsupport@rgcjonas.gmail.com"
            "ding@rastersoft.com"
            "ubuntu-dock@ubuntu.com"
        )
        
        # Activar cada extensión
        for ext in "\${EXTENSIONS[@]}"; do
            # Verificar si la extensión existe
            EXT_DIR="/usr/share/gnome-shell/extensions/\$ext"
            if [ -d "\$EXT_DIR" ]; then
                # Intentar activarla
                if gnome-extensions enable "\$ext" 2>/dev/null; then
                    echo "  ✓ \$ext activada"
                else
                    # Si falla, intentar con dbus directamente
                    gdbus call --session \
                        --dest org.gnome.Shell \
                        --object-path /org/gnome/Shell \
                        --method org.gnome.Shell.Extensions.EnableExtension "\$ext" 2>/dev/null
                    echo "  ✓ \$ext activada (dbus)"
                fi
            else
                echo "  ⚠ \$ext no encontrada en \$EXT_DIR"
            fi
        done
        
        # =====================================================================
        # CONFIGURACIÓN DE NAUTILUS
        # =====================================================================
        
        # Deshabilitar fondo de cuadros en miniaturas
        gsettings set org.gnome.nautilus.preferences show-image-thumbnails 'always' 2>/dev/null
        gsettings set org.gtk.Settings.FileChooser show-hidden false 2>/dev/null
        
        # =====================================================================
        # MARCAR COMO CONFIGURADO
        # =====================================================================
        
        mkdir -p "\$HOME/.config"
        touch "\$MARKER"
        echo "✓ Configuración de GNOME completada"
        
        # Reiniciar GNOME Shell para aplicar cambios (solo en X11)
        if [ "\$XDG_SESSION_TYPE" = "x11" ]; then
            echo "Reiniciando GNOME Shell..."
            killall -SIGQUIT gnome-shell 2>/dev/null || true
        else
            echo "Sesión Wayland detectada, los cambios se aplicarán al cerrar sesión"
        fi
    fi
fi
GSEOF

chmod +x /etc/profile.d/01-gnome-config.sh

echo "✓ Script de configuración automática creado"

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
apt install -y \$APT_FLAGS python3-pip python3-pil || true
pip3 install --break-system-packages icoextract 2>/dev/null || pip3 install icoextract

# Crear thumbnailer para .exe
mkdir -p /usr/share/thumbnailers
cat > /usr/share/thumbnailers/exe-thumbnailer.thumbnailer << 'EXETHUMB'
[Thumbnailer Entry]
TryExec=icoextract
Exec=sh -c 'icoextract "%i" "%o" -n 1 2>/dev/null || convert -size 256x256 xc:transparent "%o"'
MimeType=application/x-ms-dos-executable;application/x-msdos-program;application/x-executable;
EXETHUMB

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

CHROOTEOF

echo ""
echo "✓✓✓ GNOME instalado ✓✓✓"
echo ""
echo "Componentes instalados:"
echo "  • GNOME Shell (sin metapaquetes)"
echo "  • systemd-oomd (protección contra falta de RAM)"
echo "  • Extensiones: App Indicators, Desktop Icons, Ubuntu Dock"
echo "  • Aplicaciones GNOME:"
echo "    - Calculadora (gnome-calculator)"
echo "    - Logs del sistema (gnome-logs)"
echo "    - Gestor de tipografías (gnome-font-viewer)"
echo "    - Analizador de disco Baobab"
echo "    - Gedit, Evince, File Roller"
echo "  • Gestión de software (gdebi, update-manager)"
echo "  • Google Chrome (navegador predeterminado)"
echo "  • Tema de iconos: elementary"
echo "  • Thumbnailers: .exe (icoextract), .appimage"
echo "  • Nautilus sin fondo de damero"
echo ""
echo "Removido del sistema:"
echo "  • Snapd eliminado y bloqueado"
echo ""
if [ "${GDM_AUTOLOGIN:-false}" = "true" ]; then
    echo "  • GDM autologin: activado (usuario: $USERNAME)"
else
    echo "  • GDM autologin: desactivado (se pedirá contraseña)"
fi
echo ""
echo "IMPORTANTE:"
echo "  Las extensiones y el tema de iconos se activarán"
echo "  automáticamente en el primer login del usuario."
echo ""

# ============================================================================
# PREGUNTA: ¿OPTIMIZAR MEMORIA?
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIÓN DE MEMORIA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "GNOME puede consumir ~1.2-1.5GB de RAM en idle."
echo ""
echo "Optimizaciones disponibles (módulo 10b):"
echo "  • Deshabilitar Tracker (indexador) → ahorra ~100-200MB"
echo "  • Deshabilitar animaciones → ahorra ~30-50MB"
echo "  • Deshabilitar Evolution Data Server → ahorra ~50-100MB"
echo "  • Deshabilitar gnome-software → ahorra ~80-150MB"
echo ""
echo "Consumo esperado después: ~600-800MB (50% menos)"
echo ""

read -p "¿Aplicar optimizaciones de memoria? (s/n) [n]: " OPTIMIZE_MEMORY
if [[ ${OPTIMIZE_MEMORY:-n} =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Ejecutando módulo de optimización de memoria..."
    bash "$(dirname "$0")/10b-optimize-gnome-memory.sh"
else
    echo "✓ Optimizaciones omitidas (GNOME estándar)"
fi

echo ""
