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

# ── Pregunta interactiva: gestión de AppImages ───────────────────────────────
# Se hace ANTES del arch-chroot porque read no funciona dentro de heredocs
# (el stdin del heredoc es su propio texto, no la terminal).
# La variable se expande dentro del heredoc sin comillas.
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           GESTIÓN DE APPIMAGES — Elige un método            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                             ║"
echo "║  1) Compilar AppManager (kem-a/AppManager)                  ║"
echo "║     • Interfaz gráfica GTK4 con drag-and-drop               ║"
echo "║     • CLI: app-manager install /ruta/a/app.AppImage          ║"
echo "║     • Auto-updates en segundo plano                          ║"
echo "║                                                             ║"
echo "║  2) Instalar AM Application Manager (ivan-hc/AM)            ║"
echo "║     • Gestor CLI tipo APT para AppImages                     ║"
echo "║     • Base de datos con +2000 apps disponibles               ║"
echo "║     • Se te preguntará si instalar 'am' (sistema) o          ║"
echo "║       'appman' (local sin root)                              ║"
echo "║     • Más info: https://github.com/ivan-hc/AM               ║"
echo "║                                                             ║"
echo "║  3) Ambos (compilar AppManager + instalar AM)                ║"
echo "║                                                             ║"
echo "║  0) Ninguno — saltar                                         ║"
echo "║                                                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
read -rp "Elige opción [1/2/3/0]: " APPIMAGE_MANAGER_CHOICE
APPIMAGE_MANAGER_CHOICE="${APPIMAGE_MANAGER_CHOICE:-1}"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"
APPIMAGE_MANAGER_CHOICE="$APPIMAGE_MANAGER_CHOICE"

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
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    gdm3 \
    plymouth \
    plymouth-theme-spinner \
    bolt \
    gnome-keyring \
    apparmor

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

echo "✓  Elementary icon theme instalado (incluye iconos y cursores)"

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
# GESTIÓN DE APPIMAGES — Método elegido antes del chroot
# ============================================================================
# Opción 1: Compilar AppManager desde fuente (kem-a/AppManager)
#   - Gestor GUI GTK4/Libadwaita con drag-and-drop al estilo macOS
#   - CLI: app-manager install /path/to.AppImage
#   - Auto-updates con zsync, soporta SquashFS y DwarFS
#   - Se compila como binario nativo en /usr (sin FUSE en chroot)
#
# Opción 2: Instalar AM Application Manager (ivan-hc/AM)
#   - Gestor CLI tipo APT para AppImages y apps portables
#   - Base de datos de +2000 apps (incluyendo appmanager y protonup-qt)
#   - Dos modos: "am" (sistema, con sudo) o "appman" (local, sin root)
#   - El script AM-INSTALLER preguntará qué modo prefieres
#   - Más info: https://github.com/ivan-hc/AM
# ============================================================================

echo "Método AppImage elegido: \$APPIMAGE_MANAGER_CHOICE"

# Instalar libfuse2 para AppImages que lo necesiten
apt install -y libfuse2t64 2>/dev/null || apt install -y libfuse2 2>/dev/null || true

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

# Crear ~/Applications para el usuario
APPMANAGER_USER="$USERNAME"
mkdir -p "/home/\${APPMANAGER_USER}/Applications"
chown -R "\$(id -u "\$APPMANAGER_USER" 2>/dev/null || echo 1000):\$(id -g "\$APPMANAGER_USER" 2>/dev/null || echo 1000)" \
    "/home/\${APPMANAGER_USER}/Applications"

APPMANAGER_OK=false
AM_OK=false

# --- Opción 1 o 3: Compilar AppManager desde fuente ---
if [ "\$APPIMAGE_MANAGER_CHOICE" = "1" ] || [ "\$APPIMAGE_MANAGER_CHOICE" = "3" ]; then
    echo ""
    echo "Compilando AppManager desde fuente..."

    APPMANAGER_BUILD_DEPS="valac meson ninja-build pkg-config libadwaita-1-dev libgtk-4-dev \
        libglib2.0-dev libjson-glib-dev libgee-0.8-dev libgirepository1.0-dev libsoup-3.0-dev \
        cmake desktop-file-utils jq"

    apt install -y \$APPMANAGER_BUILD_DEPS 2>/dev/null

    APPMANAGER_TAG=\$(curl --max-time 30 --retry 3 -s https://api.github.com/repos/kem-a/AppManager/releases \
        | grep '"tag_name"' | head -1 | cut -d '"' -f 4)

    if [ -n "\$APPMANAGER_TAG" ]; then
        echo "  Versión: \$APPMANAGER_TAG"

        cd /tmp
        rm -rf AppManager
        git clone --depth 1 --branch "\$APPMANAGER_TAG" https://github.com/kem-a/AppManager.git 2>/dev/null \
            || git clone --depth 1 https://github.com/kem-a/AppManager.git 2>/dev/null

        if [ -d "AppManager" ]; then
            cd AppManager

            if meson setup build --prefix=/usr --buildtype=release 2>&1 && \
               meson compile -C build 2>&1 && \
               meson install -C build 2>&1; then

                APPMANAGER_OK=true
                echo "  ✓ AppManager compilado e instalado"
            else
                echo "  ⚠ Error compilando AppManager"
            fi

            cd /tmp
            rm -rf AppManager
        else
            echo "  ⚠ Error clonando repositorio de AppManager"
        fi
    else
        echo "  ⚠ No se pudo obtener versión de AppManager"
    fi

    # Eliminar dependencias solo de compilación
    apt purge -y valac meson ninja-build 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
fi

# --- Opción 2 o 3: Instalar AM Application Manager ---
if [ "\$APPIMAGE_MANAGER_CHOICE" = "2" ] || [ "\$APPIMAGE_MANAGER_CHOICE" = "3" ]; then
    echo ""
    echo "Instalando AM Application Manager..."
    echo ""
    echo "El script AM-INSTALLER te preguntará:"
    echo "  1) 'AM'     → instalación a nivel de sistema (requiere sudo)"
    echo "  2) 'AppMan' → instalación local (sin root, apps en ~/Applications)"
    echo ""

    cd /tmp
    if wget -q https://raw.githubusercontent.com/ivan-hc/AM/main/AM-INSTALLER && \
       chmod a+x ./AM-INSTALLER; then
        # AM-INSTALLER es interactivo (pregunta am vs appman).
        # Redirigir stdin desde /dev/tty porque estamos dentro de un heredoc
        # y el stdin normal es el texto del heredoc, no la terminal.
        ./AM-INSTALLER < /dev/tty
        rm -f ./AM-INSTALLER

        # Verificar si se instaló correctamente
        if command -v am >/dev/null 2>&1 || command -v appman >/dev/null 2>&1; then
            AM_OK=true
            echo "  ✓ AM/AppMan instalado correctamente"
        else
            echo "  ⚠ AM/AppMan no se detectó tras instalación"
        fi
    else
        echo "  ⚠ Error descargando AM-INSTALLER"
    fi
fi

if [ "\$APPIMAGE_MANAGER_CHOICE" = "0" ]; then
    echo "  Saltando gestión de AppImages"
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
echo "  • Gestor de AppImages (AppManager y/o AM según elección)"
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

