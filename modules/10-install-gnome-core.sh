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
# CURSOR ELEMENTARY (desde GitHub — no hay paquete apt)
# ============================================================================

echo ""
echo "Instalando cursor elementary..."

# Descargar y extraer cursores elementary desde GitHub
CURSOR_TMP="/tmp/elementary-cursors"
rm -rf "\$CURSOR_TMP"
if git clone --depth 1 https://github.com/kaesetoast/elementary-cursors.git "\$CURSOR_TMP" 2>/dev/null; then
    # Copiar la carpeta del tema a /usr/share/icons
    if [ -d "\$CURSOR_TMP/elementary" ]; then
        cp -r "\$CURSOR_TMP/elementary" /usr/share/icons/elementary-cursors
        chmod -R 755 /usr/share/icons/elementary-cursors
        echo "✓  Cursor elementary instalado"
    else
        echo "⚠  Estructura de cursores elementary no reconocida — omitido"
    fi
    rm -rf "\$CURSOR_TMP"
else
    echo "⚠  No se pudo descargar cursor elementary — omitido"
fi

# ============================================================================
# TEMAS GTK EXTRA (para aplicaciones legacy)
# ============================================================================

echo ""
echo "Instalando temas GTK adicionales..."

apt install -y \$APT_FLAGS gnome-themes-extra

echo "✓  Temas GTK instalados (Adwaita, Adwaita-dark, HighContrast)"

# ============================================================================
# WALLPAPERS DE LA VERSIÓN
# ============================================================================

echo ""
echo "Instalando wallpapers de Ubuntu..."

# El codename viene de /etc/os-release dentro del chroot (ya configurado
# por 03-configure-base). Como fallback usamos UBUNTU_VERSION del host.
CODENAME=\$(. /etc/os-release 2>/dev/null && echo "\${VERSION_CODENAME:-}" || echo "")
[ -z "\$CODENAME" ] && CODENAME="$UBUNTU_VERSION"

# ubuntu-wallpapers instala el fondo genérico de todos los tiempos (warty, etc.)
# ubuntu-wallpapers-CODENAME instala los específicos de esta versión
apt install -y ubuntu-wallpapers 2>/dev/null || true
apt install -y "ubuntu-wallpapers-\${CODENAME}" 2>/dev/null || \
    echo "  ⚠  Paquete ubuntu-wallpapers-\${CODENAME} no disponible — usando wallpapers genéricos"

echo "✓  Wallpapers instalados para \${CODENAME}"

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

# ── Configuración de autologin ────────────────────────────────────────────────
# /etc/gdm3/custom.conf es el fichero oficial de configuración de GDM3.
# La sección [daemon] acepta AutomaticLoginEnable y AutomaticLogin.
# Si el fichero ya existe (creado por el paquete gdm3) se reemplaza
# completamente para evitar conflictos con valores duplicados.
GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"
GDM_USER="$USERNAME"

mkdir -p /etc/gdm3

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then
    cat > /etc/gdm3/custom.conf << GDMCONF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=\${GDM_USER}
# TimedLoginEnable y TimedLogin permiten login retardado (no usado aquí)

[security]

[xdmcp]

[chooser]

[debug]
GDMCONF
    echo "✓  GDM autologin configurado para el usuario '\${GDM_USER}'"
else
    cat > /etc/gdm3/custom.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=False

[security]

[xdmcp]

[chooser]

[debug]
GDMCONF
    echo "✓  GDM configurado (sin autologin — pedirá contraseña)"
fi

# ============================================================================
# APPIMAGE THUMBNAILER v4.0.0 (.deb — kem-a)
# https://github.com/kem-a/appimage-thumbnailer
# ============================================================================

echo ""
echo "Instalando AppImage thumbnailer..."

THUMBNAILER_URL="https://github.com/kem-a/appimage-thumbnailer/releases/download/v4.0.0/appimage-thumbnailer_v4.0.0_amd64.deb"

if wget --timeout=30 --tries=3 --quiet --show-progress "\$THUMBNAILER_URL" -O /tmp/appimage-thumbnailer.deb 2>&1; then
    if [ -s /tmp/appimage-thumbnailer.deb ] && file /tmp/appimage-thumbnailer.deb | grep -q "Debian binary package"; then
        apt install -y /tmp/appimage-thumbnailer.deb
        rm /tmp/appimage-thumbnailer.deb
        echo "✓  AppImage thumbnailer v4.0.0 instalado"
    else
        echo "  ⚠ Archivo descargado no es un .deb válido"
        rm -f /tmp/appimage-thumbnailer.deb
    fi
else
    echo "  ⚠ Fallo en descarga del thumbnailer"
    echo "  Instalar manualmente: \$THUMBNAILER_URL"
fi

# ============================================================================
# APPMANAGER v3.4.2+ (Gestor de AppImages)
# https://github.com/kem-a/AppManager
# ============================================================================
# GTK4/Libadwaita, drag-and-drop al estilo macOS, auto-updates,
# soporta SquashFS y DwarFS, no requiere FUSE (uruntime)
# Se deja como AppImage en ~/Applications — al ejecutarlo por primera vez
# AppManager se auto-integra con el escritorio (menú, MIME, iconos)
# ============================================================================

echo ""
echo "Descargando AppManager..."

# Obtener la última release (incluyendo las que no estén marcadas como "latest")
# La API /releases devuelve ordenadas por fecha, la primera es la más reciente
APPMANAGER_URL=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/kem-a/AppManager/releases \
    | grep "browser_download_url.*x86_64.*AppImage\"" \
    | grep -v "\.zsync" \
    | head -1 \
    | cut -d '"' -f 4)

APPMANAGER_USER="$USERNAME"

if [ -n "\$APPMANAGER_URL" ]; then
    echo "Descargando AppManager desde GitHub..."
    echo "  URL: \$APPMANAGER_URL"
    
    # Crear ~/Applications para el usuario
    mkdir -p "/home/\${APPMANAGER_USER}/Applications"
    
    # Descargar AppImage directamente a ~/Applications
    if wget --timeout=30 --tries=3 -q --show-progress "\$APPMANAGER_URL" \
        -O "/home/\${APPMANAGER_USER}/Applications/AppManager.AppImage" 2>&1; then
        
        if [ -s "/home/\${APPMANAGER_USER}/Applications/AppManager.AppImage" ]; then
            chmod +x "/home/\${APPMANAGER_USER}/Applications/AppManager.AppImage"
            chown -R "\$(id -u "\$APPMANAGER_USER" 2>/dev/null || echo 1000):\$(id -g "\$APPMANAGER_USER" 2>/dev/null || echo 1000)" \
                "/home/\${APPMANAGER_USER}/Applications"
            
            # Registrar MIME type para .appimage / .AppImage
            cat > /usr/share/mime/packages/appimage.xml << 'MIME_XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/vnd.appimage">
        <comment>AppImage application bundle</comment>
        <glob pattern="*.appimage"/>
        <glob pattern="*.AppImage"/>
        <icon name="application-vnd.appimage"/>
    </mime-type>
</mime-info>
MIME_XML
            update-mime-database /usr/share/mime 2>/dev/null
            
            # Instalar libfuse2 para AppImages legacy que lo necesiten
            apt install -y libfuse2t64 2>/dev/null || apt install -y libfuse2 2>/dev/null || true
            
            echo "✓  AppManager descargado en ~/Applications/AppManager.AppImage"
            echo "  Al ejecutarlo, se auto-integra con el escritorio"
        else
            echo "  ⚠ Descarga vacía o corrupta"
            rm -f "/home/\${APPMANAGER_USER}/Applications/AppManager.AppImage"
        fi
    else
        echo "  ⚠ Error en descarga de AppManager"
    fi
else
    echo "  ⚠ No se pudo obtener URL de AppManager desde GitHub API"
    echo "  Descargar manualmente desde: https://github.com/kem-a/AppManager/releases"
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
apt update
apt install -y google-chrome-stable

echo "✓  Google Chrome instalado"

# Fix: tema del sistema (GTK4 / Wayland nativo / tema oscuro)
# Sin esto Chrome ignora el tema oscuro de GNOME y se ve en modo claro
CHROME_DESKTOP="/usr/share/applications/google-chrome.desktop"
if [ -f "\$CHROME_DESKTOP" ]; then
    sed -i 's|^Exec=/usr/bin/google-chrome-stable|Exec=/usr/bin/google-chrome-stable --gtk-version=4|' "\$CHROME_DESKTOP"
    echo "✓  Chrome: fix tema del sistema aplicado (--gtk-version=4)"
fi

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

# Detectar versión real de GNOME Shell instalada
GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' || echo "99.0")

# ── Defaults de sistema ───────────────────────────────────────────────────────
# welcome-dialog-last-shown-version se genera dinámicamente con la versión real
cat > /etc/dconf/db/local.d/00-gnome-installer << DCONF_DEFAULTS
[org/gnome/shell]
# Layout vacío = orden alfabético. Bloqueado abajo para que no cambie con el uso.
app-picker-layout=@aa{sv} []
# Marcar el diálogo de bienvenida como ya mostrado → GNOME inicia en el escritorio
welcome-dialog-last-shown-version='${GNOME_VER}'

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

# Deshabilitar gnome-initial-setup (si se arrastró como dependencia)
# Esto evita el asistente de bienvenida que abre el overview al primer login
mkdir -p /etc/skel/.config
echo "yes" > /etc/skel/.config/gnome-initial-setup-done

echo "✓  dconf: workspaces fijos, privacidad, appgrid y arranque directo al escritorio"
DCONF_SYSTEM

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN GNOME APLICADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ Arranque directo al escritorio (sin overview)"
echo "  ✅ Workspace único fijo (dconf default de sistema)"
echo "  ✅ Tiempo de uso de pantalla desactivado (dconf default de sistema)"
echo "  ✅ Appgrid alfabético permanente (dconf lock de sistema)"
echo ""

# ============================================================================

exit 0

