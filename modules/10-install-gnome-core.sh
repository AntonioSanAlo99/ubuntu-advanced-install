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

# ── dconf defaults y locks de sistema — sin D-Bus, sin gsettings ─────────────
# Todas las configuraciones GNOME que no necesitan sesión gráfica se aplican
# aquí como defaults del sistema via dconf. Esto funciona dentro del chroot
# durante la instalación porque escribe archivos planos en /etc/dconf/.
#
# Las claves con lock son de solo lectura para el usuario — GNOME no puede
# sobrescribirlas. Las claves sin lock son defaults que el usuario puede cambiar.
#
# dconf update compila los archivos en una base de datos binaria que GNOME
# lee al arrancar. Sin este paso los cambios no tienen efecto.
arch-chroot "$TARGET" /bin/bash << 'DCONF_SYSTEM'

mkdir -p /etc/dconf/db/local.d
mkdir -p /etc/dconf/db/local.d/locks

# ── Defaults de sistema ───────────────────────────────────────────────────────
cat > /etc/dconf/db/local.d/00-gnome-installer << 'DCONF_DEFAULTS'
[org/gnome/shell]
# Layout vacío = orden alfabético. Bloqueado abajo para que no cambie con el uso.
app-picker-layout=@aa{sv} []

[org/gnome/mutter]
# Workspace único fijo — sin workspaces dinámicos
dynamic-workspaces=false
workspaces-only-on-primary=true

[org/gnome/desktop/wm/preferences]
# Exactamente un workspace
num-workspaces=1

[org/gnome/desktop/privacy]
# No registrar tiempo de uso de aplicaciones ni archivos recientes
remember-app-usage=false
remember-recent-files=false
DCONF_DEFAULTS

# ── Locks de sistema ──────────────────────────────────────────────────────────
# app-picker-layout bloqueado: GNOME no puede sobrescribir el orden alfabético
# El resto no está bloqueado: el usuario puede cambiarlos desde Ajustes
cat > /etc/dconf/db/local.d/locks/00-gnome-installer << 'DCONF_LOCKS'
/org/gnome/shell/app-picker-layout
DCONF_LOCKS

# Compilar la base de datos — imprescindible para que los cambios tengan efecto
dconf update

echo "✓  dconf: workspaces fijos, privacidad y appgrid configurados"
DCONF_SYSTEM

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GNOME APLICADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ Workspace único fijo (dconf default de sistema)"
echo "  ✅ Tiempo de uso de pantalla desactivado (dconf default de sistema)"
echo "  ✅ Appgrid alfabético permanente (dconf lock de sistema)"
echo ""

# ============================================================================

exit 0

