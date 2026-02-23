#!/bin/bash
# Módulo 10: GNOME Core - Instalación esencial (sin personalización)

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE GNOME CORE"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo instala ÚNICAMENTE los componentes esenciales."
echo "Personalización (tema, fuentes, apps) se configura después."
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"

# ============================================================================
# GNOME SHELL Y CORE (componentes esenciales)
# ============================================================================

echo "Instalando GNOME Shell y componentes core..."

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
    bolt \
    gnome-keyring

echo "✓  GNOME Shell instalado"

# ============================================================================
# UTILIDADES ESENCIALES
# ============================================================================

echo "Instalando utilidades esenciales..."

apt install -y \$APT_FLAGS \
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
    nm-connection-editor \
    zenity

echo "✓  Utilidades instaladas"

# ============================================================================
# GESTIÓN DE SOFTWARE
# ============================================================================

echo "Instalando gestión de software..."

apt install -y \$APT_FLAGS \
    software-properties-gtk \
    gdebi \
    update-notifier \
    update-manager \
    curl \
    file

echo "✓  Gestión de software instalada"

# ============================================================================
# EXTENSIONES ESENCIALES
# ============================================================================

echo "Instalando extensiones esenciales..."

apt install -y \$APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-ubuntu-dock

echo "✓  Extensiones instaladas"

# ============================================================================
# SYSTEMD-OOMD (protección contra OOM)
# ============================================================================

echo ""
echo "Instalando systemd-oomd..."

if apt-cache show systemd-oomd &>/dev/null; then
    apt-get install -y systemd-oomd
    
    # Habilitar systemd-oomd manualmente (systemctl no funciona en chroot)
    # Crear symlink para que systemd lo habilite al arrancar
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /lib/systemd/system/systemd-oomd.service \
           /etc/systemd/system/multi-user.target.wants/systemd-oomd.service
    
    echo "✓  systemd-oomd instalado y habilitado"
else
    echo "⚠  systemd-oomd no disponible en esta versión"
fi

# ============================================================================
# TEMA DE ICONOS (parte esencial de GNOME)
# ============================================================================

echo ""
echo "Instalando tema de iconos..."

apt install -y \$APT_FLAGS elementary-icon-theme

echo "✓  Elementary icon theme instalado"

# ============================================================================
# TEMAS GTK EXTRA (para aplicaciones legacy)
# ============================================================================

echo ""
echo "Instalando temas GTK adicionales..."

apt install -y \$APT_FLAGS gnome-themes-extra

echo "✓  Temas GTK instalados (Adwaita, Adwaita-dark, HighContrast)"

# ============================================================================
# HABILITAR GDM
# ============================================================================

echo ""
echo "Habilitando GDM..."

# Crear symlink manualmente (systemctl no funciona en chroot)
# GDM es el display manager, debe arrancar en graphical.target
mkdir -p /etc/systemd/system/display-manager.service.d
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/display-manager.service

echo "✓  GDM habilitado como display manager"

# ============================================================================
# APPMANAGER (kem-a) - Gestor de AppImages estilo macOS
# ============================================================================

echo ""
echo "Instalando AppManager..."

# Instalar dependencias
apt install -y libfuse2 libglib2.0-bin

# Descargar AppManager desde GitHub
APPMANAGER_URL="https://github.com/kem-a/AppManager/releases/latest/download/AppManager-x86_64.AppImage"

mkdir -p /opt/appmanager
wget --timeout=30 --tries=3 -q "$APPMANAGER_URL" -O /opt/appmanager/AppManager.AppImage

if [ -f /opt/appmanager/AppManager.AppImage ]; then
    chmod +x /opt/appmanager/AppManager.AppImage
    
    # Crear desktop entry
    cat > /usr/share/applications/appmanager.desktop << 'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=AppManager
Comment=Gestor de AppImages estilo macOS
Exec=/opt/appmanager/AppManager.AppImage
Icon=application-x-executable
Terminal=false
Categories=System;Utility;
Keywords=appimage;manager;applications;
DESKTOP
    
    echo "✓  AppManager instalado"
else
    echo "⚠  No se pudo descargar AppManager (no crítico)"
fi

# ============================================================================
# APPIMAGE THUMBNAILER (.deb de kem-a)
# ============================================================================

echo ""
echo "Instalando AppImage thumbnailer..."

# Obtener última versión del thumbnailer de kem-a
THUMBNAILER_LATEST=\$(curl --max-time 30 --retry 3 --fail --silent https://api.github.com/repos/kem-a/appimage-thumbnailer/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)

if [ -n "\$THUMBNAILER_LATEST" ]; then
    echo "Descargando desde: \$THUMBNAILER_LATEST"
    
    if wget --timeout=30 --tries=3 --quiet --show-progress "\$THUMBNAILER_LATEST" -O /tmp/appimage-thumbnailer.deb 2>&1; then
        # Verificar que el archivo no está vacío y es un .deb válido
        if [ -f /tmp/appimage-thumbnailer.deb ] && [ -s /tmp/appimage-thumbnailer.deb ]; then
            if file /tmp/appimage-thumbnailer.deb | grep -q "Debian binary package"; then
                apt install -y /tmp/appimage-thumbnailer.deb
                rm /tmp/appimage-thumbnailer.deb
                echo " AppImage thumbnailer instalado (.deb)"
            else
                echo "  ⚠  Archivo descargado no es un .deb válido"
                rm /tmp/appimage-thumbnailer.deb
            fi
        else
            echo "  ⚠  Descarga vacía o corrupta"
            rm -f /tmp/appimage-thumbnailer.deb
        fi
    else
        echo "  ⚠  Fallo en descarga del thumbnailer"
    fi
else
    echo "  ⚠ No se pudo obtener URL del thumbnailer desde GitHub API"
    echo "  Las miniaturas de AppImages no se mostrarán en Nautilus"
fi

# ============================================================================
# APPMANAGER (Gestor de AppImages)
# ============================================================================
# AppManager by kem-a: https://github.com/kem-a/AppManager
# Gestión de AppImages: instalar, actualizar, eliminar, integrar
# ============================================================================

echo ""
echo "Instalando AppManager..."

# Obtener última versión desde GitHub API
APPMANAGER_URL=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/kem-a/AppManager/releases/latest | grep "browser_download_url.*anylinux-x86_64.AppImage" | cut -d '"' -f 4)

if [ -n "\$APPMANAGER_URL" ]; then
    echo "Descargando AppManager desde GitHub..."
    
    # Descargar AppImage
    if wget --timeout=30 --tries=3 -q --show-progress "\$APPMANAGER_URL" -O /tmp/AppManager.AppImage 2>&1; then
        
        # Crear directorio para AppImages del sistema
        mkdir -p /opt/AppImages
        
        # Mover y hacer ejecutable
        mv /tmp/AppManager.AppImage /opt/AppImages/AppManager.AppImage
        chmod +x /opt/AppImages/AppManager.AppImage
        
        # Crear entrada de escritorio
        cat > /usr/share/applications/appmanager.desktop << 'APPMANAGER_DESKTOP'
[Desktop Entry]
Name=AppManager
Comment=Gestor de AppImages
Exec=/opt/AppImages/AppManager.AppImage
Icon=application-x-executable
Terminal=false
Type=Application
Categories=System;PackageManager;
Keywords=appimage;apps;manager;
StartupNotify=true
APPMANAGER_DESKTOP
        
        # Crear symlink en /usr/local/bin para fácil acceso
        ln -sf /opt/AppImages/AppManager.AppImage /usr/local/bin/appmanager
        
        # Configurar MIME type para abrir .appimage con AppManager
        cat > /usr/share/mime/packages/appimage.xml << 'MIME_XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/vnd.appimage">
        <comment>AppImage application bundle</comment>
        <glob pattern="*.appimage"/>
        <glob pattern="*.AppImage"/>
        <icon name="application-x-executable"/>
    </mime-type>
</mime-info>
MIME_XML
        
        # Actualizar base de datos MIME
        update-mime-database /usr/share/mime
        
        # Configurar AppManager como aplicación por defecto para AppImages
        cat >> /usr/share/applications/appmanager.desktop << 'MIME_ASSOC'
MimeType=application/vnd.appimage;application/x-executable;
MIME_ASSOC
        
        # Actualizar base de datos de aplicaciones
        update-desktop-database /usr/share/applications
        
        echo "✓  AppManager instalado"
        echo "  Ejecutar: appmanager (o desde menú de aplicaciones)"
        echo "  MIME: archivos .appimage se abren con AppManager"
        
    else
        echo "  ⚠ Error en descarga de AppManager"
    fi
else
    echo "  ⚠ No se pudo obtener URL de AppManager desde GitHub API"
    echo "  Instalar manualmente desde: https://github.com/kem-a/AppManager/releases"
fi

# ============================================================================
# GOOGLE CHROME (Navegador)
# ============================================================================

echo ""
echo "Instalando Google Chrome..."

# Añadir clave GPG de Google
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg

# Añadir repositorio
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

# Actualizar e instalar
apt update -qq
apt install -y google-chrome-stable

echo "✓  Google Chrome instalado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Componentes instalados:"
echo "  • GNOME Shell + Session"
echo "  • GDM3 (display manager)"
echo "  • Nautilus + Terminal"
echo "  • Utilidades esenciales (13 paquetes)"
echo "  • Extensiones base (3)"
echo "  • systemd-oomd (protección OOM)"
echo "  • Google Chrome (navegador)"
echo "  • AppManager (gestor de AppImages)"
echo "  • AppImage thumbnailer"
echo ""
echo "NO incluido (se configura en otros módulos):"
echo "  ✗ Personalización (tema, fuentes, apps ancladas)"
echo "  ✗ Optimizaciones de memoria"
echo "  ✗ Tema transparente"
echo ""

# ============================================================================
# CONFIGURACIÓN DE GNOME - WORKSPACES Y TIEMPO DE PANTALLA
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN ADICIONAL DE GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Preguntar sobre áreas de trabajo (fuera del chroot para interacción)
echo "Configuración de áreas de trabajo (workspaces):"
echo "  • Por defecto: Dinámicas (se crean/eliminan automáticamente)"
echo "  • Alternativa: Fijo en 1 workspace (simplifica la interfaz)"
echo ""
read -p "¿Establecer número fijo de workspaces en 1? (s/n) [s]: " FIX_WORKSPACES
FIX_WORKSPACES=${FIX_WORKSPACES:-s}

echo ""
echo "Configuración de tiempo de pantalla:"
echo "  • GNOME Usage rastrea tiempo de uso de aplicaciones"
echo "  • Puede consumir recursos en segundo plano"
echo ""
read -p "¿Desactivar tiempo de pantalla (GNOME Usage)? (s/n) [s]: " DISABLE_USAGE
DISABLE_USAGE=${DISABLE_USAGE:-s}

# Aplicar configuraciones
arch-chroot "$TARGET" /bin/bash << 'GNOMECFG'
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)

if [ -n "$USERNAME" ]; then
    echo ""
    echo "Aplicando configuraciones de GNOME para $USERNAME..."
    
    # Workspaces
    if [ "$FIX_WORKSPACES" = "s" ] || [ "$FIX_WORKSPACES" = "S" ]; then
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter dynamic-workspaces false
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.wm.preferences num-workspaces 1
        echo " Workspaces fijos: 1 área de trabajo"
    else
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter dynamic-workspaces true
        echo " Workspaces dinámicos (comportamiento predeterminado de GNOME)"
    fi
    
    # Tiempo de pantalla
    if [ "$DISABLE_USAGE" = "s" ] || [ "$DISABLE_USAGE" = "S" ]; then
        # Deshabilitar GNOME Usage si está instalado
        if dpkg -l | grep -q gnome-usage; then
            apt remove -y gnome-usage 2>/dev/null || true
        fi
        
        # Deshabilitar tracking de uso
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.privacy remember-app-usage false
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.privacy remember-recent-files false
        
        echo " Tiempo de pantalla desactivado"
        echo "  → remember-app-usage: false"
        echo "  → remember-recent-files: false"
    else
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.privacy remember-app-usage true
        sudo -u $USERNAME dbus-launch gsettings set org.gnome.desktop.privacy remember-recent-files true
        echo " Tiempo de pantalla habilitado (comportamiento predeterminado)"
    fi
    
    # Crear archivo de documentación
    cat > /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'
# Configuración Personalizada de GNOME

## Áreas de Trabajo (Workspaces)
EOF

    if [ "$FIX_WORKSPACES" = "s" ] || [ "$FIX_WORKSPACES" = "S" ]; then
        cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'
Estado: Fijo en 1 workspace
Comandos aplicados:
  gsettings set org.gnome.mutter dynamic-workspaces false
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 1

Beneficio: Interfaz simplificada, sin cambios accidentales de workspace

Revertir a dinámico:
  gsettings set org.gnome.mutter dynamic-workspaces true

EOF
    else
        cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'
Estado: Dinámicos (predeterminado GNOME)
Comportamiento: Workspaces se crean/eliminan automáticamente

Cambiar a fijo (1 workspace):
  gsettings set org.gnome.mutter dynamic-workspaces false
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 1

EOF
    fi

    cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'

## Tiempo de Pantalla y Privacidad
EOF

    if [ "$DISABLE_USAGE" = "s" ] || [ "$DISABLE_USAGE" = "S" ]; then
        cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'
Estado: Desactivado
Comandos aplicados:
  gsettings set org.gnome.desktop.privacy remember-app-usage false
  gsettings set org.gnome.desktop.privacy remember-recent-files false

Beneficio: Menor uso de recursos, mayor privacidad

Reactivar:
  gsettings set org.gnome.desktop.privacy remember-app-usage true
  gsettings set org.gnome.desktop.privacy remember-recent-files true

EOF
    else
        cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'
Estado: Habilitado (predeterminado GNOME)
Funcionalidad: Rastrea uso de aplicaciones y archivos recientes

Desactivar:
  gsettings set org.gnome.desktop.privacy remember-app-usage false
  gsettings set org.gnome.desktop.privacy remember-recent-files false

EOF
    fi

    cat >> /home/$USERNAME/.config/gnome-custom-config.txt << 'EOF'

## Verificar Configuración Actual
gsettings get org.gnome.mutter dynamic-workspaces
gsettings get org.gnome.desktop.wm.preferences num-workspaces
gsettings get org.gnome.desktop.privacy remember-app-usage
gsettings get org.gnome.desktop.privacy remember-recent-files
EOF

    chown $USERNAME:$USERNAME /home/$USERNAME/.config/gnome-custom-config.txt
    echo ""
    echo "✓  Configuración guardada en ~/.config/gnome-custom-config.txt"
    
else
    echo "⚠  Usuario no encontrado, configuraciones de GNOME omitidas"
fi

GNOMECFG

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GNOME APLICADA"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$FIX_WORKSPACES" = "s" ] || [ "$FIX_WORKSPACES" = "S" ]; then
    echo "  ✅ Workspaces: Fijo en 1"
else
    echo "  ℹ️  Workspaces: Dinámicos"
fi

if [ "$DISABLE_USAGE" = "s" ] || [ "$DISABLE_USAGE" = "S" ]; then
    echo "  ✅ Tiempo de pantalla: Desactivado"
else
    echo "  ℹ️  Tiempo de pantalla: Habilitado"
fi

echo ""

# ============================================================================

exit 0

