#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 10: GNOME Core — instalación esencial (sin personalización)
# Personalización (tema, fuentes, dock) se configura en 10-user-config.sh
# ══════════════════════════════════════════════════════════════════════════════

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE GNOME CORE"
echo "════════════════════════════════════════════════════════════════"
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

# ── Pregunta: AppManager GUI ─────────────────────────────────────────────────
# AM (ivan-hc/AM) se instala siempre. Solo se pregunta si compilar AppManager.
if [ -z "$APPIMAGE_MANAGER_CHOICE" ]; then
    echo "AM (ivan-hc/AM) se instala siempre como gestor CLI de AppImages."
    echo "  1) Compilar también AppManager GUI (GTK4)"
    echo "  2) Solo AM (CLI)"
    echo ""
    read -rp "Opción [2]: " APPIMAGE_MANAGER_CHOICE
fi
APPIMAGE_MANAGER_CHOICE="${APPIMAGE_MANAGER_CHOICE:-2}"

# ============================================================================
# CHROOT: PAQUETES GNOME + CHROME + APPIMAGE
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"
APPIMAGE_MANAGER_CHOICE="$APPIMAGE_MANAGER_CHOICE"

# ── GNOME Shell + core ──────────────────────────────────────────────────────
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
    gnome-keyring

echo "✓  GNOME Shell instalado"

# ── Utilidades ──────────────────────────────────────────────────────────────
echo "Instalando utilidades..."

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

# ── Gestión de software ─────────────────────────────────────────────────────
apt install -y \$APT_FLAGS \
    software-properties-gtk \
    gdebi \
    update-notifier \
    update-manager \
    curl \
    file

# ── Extensiones APT ─────────────────────────────────────────────────────────
apt install -y \$APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-ubuntu-dock

echo "✓  Extensiones instaladas"

# ── systemd-oomd ─────────────────────────────────────────────────────────────
if apt-cache show systemd-oomd &>/dev/null; then
    apt-get install -y systemd-oomd 2>/dev/null || true
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /lib/systemd/system/systemd-oomd.service \
           /etc/systemd/system/multi-user.target.wants/systemd-oomd.service
    echo "✓  systemd-oomd habilitado"
fi

# ── Tema de iconos + GTK ────────────────────────────────────────────────────
apt install -y \$APT_FLAGS elementary-icon-theme gnome-themes-extra
echo "✓  Iconos elementary + temas GTK"

# ── Wallpapers ──────────────────────────────────────────────────────────────
CODENAME=\$(. /etc/os-release 2>/dev/null && echo "\${VERSION_CODENAME:-}" || echo "")
[ -z "\$CODENAME" ] && CODENAME="$UBUNTU_VERSION"
apt install -y ubuntu-wallpapers 2>/dev/null || true
apt install -y "ubuntu-wallpapers-\${CODENAME}" 2>/dev/null || true
echo "✓  Wallpapers instalados"

# ── GDM ──────────────────────────────────────────────────────────────────────
mkdir -p /etc/systemd/system/display-manager.service.d
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/display-manager.service
echo "✓  GDM habilitado"

# Autologin
GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"
GDM_USER="$USERNAME"
mkdir -p /etc/gdm3

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then
    cat > /etc/gdm3/custom.conf << GDMCONF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=\${GDM_USER}
[security]
[xdmcp]
[chooser]
[debug]
GDMCONF
    echo "✓  Autologin configurado (\${GDM_USER})"
else
    cat > /etc/gdm3/custom.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=False
[security]
[xdmcp]
[chooser]
[debug]
GDMCONF
    echo "✓  GDM configurado (login con contraseña)"
fi

# ── Google Chrome ────────────────────────────────────────────────────────────
echo ""
echo "Instalando Google Chrome..."

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg 2>/dev/null || true

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list

apt update 2>/dev/null || true
apt install -y google-chrome-stable 2>/dev/null && echo "✓  Chrome instalado" \
    || echo "⚠  Chrome: instálalo manualmente tras el primer boot"

# ── AppImage: libfuse + MIME type ────────────────────────────────────────────
apt install -y libfuse2t64 2>/dev/null || apt install -y libfuse2 2>/dev/null || true

cat > /usr/share/mime/packages/appimage.xml << 'MIME_XML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="application/vnd.appimage">
        <comment>AppImage application bundle</comment>
        <glob pattern="*.appimage"/>
        <glob pattern="*.AppImage"/>
    </mime-type>
</mime-info>
MIME_XML
update-mime-database /usr/share/mime 2>/dev/null || true

# ~/Applications para el usuario
APPMANAGER_USER="$USERNAME"
mkdir -p "/home/\${APPMANAGER_USER}/Applications"
chown -R \$(id -u "\$APPMANAGER_USER" 2>/dev/null || echo 1000):\$(id -g "\$APPMANAGER_USER" 2>/dev/null || echo 1000) \
    "/home/\${APPMANAGER_USER}/Applications"

# ── AppManager (compilar si opción 1) ────────────────────────────────────────
if [ "\$APPIMAGE_MANAGER_CHOICE" = "1" ]; then
    echo ""
    echo "Compilando AppManager..."

    apt install -y valac meson ninja-build pkg-config libadwaita-1-dev libgtk-4-dev \
        libglib2.0-dev libjson-glib-dev libgee-0.8-dev libgirepository1.0-dev libsoup-3.0-dev \
        cmake desktop-file-utils jq 2>/dev/null || true

    APPMANAGER_TAG=\$(curl --max-time 15 --retry 2 -s https://api.github.com/repos/kem-a/AppManager/releases \
        | grep '"tag_name"' | head -1 | cut -d '"' -f 4)

    if [ -n "\$APPMANAGER_TAG" ]; then
        cd /tmp && rm -rf AppManager
        git clone --depth 1 --branch "\$APPMANAGER_TAG" https://github.com/kem-a/AppManager.git 2>/dev/null \
            || git clone --depth 1 https://github.com/kem-a/AppManager.git 2>/dev/null

        if [ -d "AppManager" ]; then
            cd AppManager
            if meson setup build --prefix=/usr --buildtype=release 2>&1 && \
               meson compile -C build 2>&1 && \
               meson install -C build 2>&1; then
                echo "✓  AppManager compilado e instalado"
            else
                echo "⚠  Error compilando AppManager"
            fi
            cd /tmp && rm -rf AppManager
        fi
    else
        echo "⚠  AppManager: no se pudo obtener versión"
    fi

    apt purge -y valac meson ninja-build 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
fi

# ── AM Application Manager (siempre) ────────────────────────────────────────
echo ""
echo "Instalando AM Application Manager..."

cd /tmp
if wget -q https://raw.githubusercontent.com/ivan-hc/AM/main/INSTALL && \
   chmod a+x ./INSTALL; then
    ./INSTALL 2>/dev/null || true
    rm -f ./INSTALL
    command -v am >/dev/null 2>&1 && echo "✓  AM instalado" \
        || echo "⚠  AM: verificar tras el primer boot"
else
    echo "⚠  AM: descarga falló"
fi

CHROOTEOF

# ============================================================================
# DCONF: DEFAULTS Y LOCKS DE SISTEMA
# ============================================================================
# Configuraciones que aplican antes del primer login. Las que necesitan
# sesión D-Bus (tema, dock, extensiones) van en 10-user-config.sh.

arch-chroot "$TARGET" /bin/bash << 'DCONF_SYSTEM'

mkdir -p /etc/dconf/db/local.d
mkdir -p /etc/dconf/db/local.d/locks

GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' || echo "99.0")

cat > /etc/dconf/db/local.d/00-gnome-installer << DCONF_DEFAULTS
[org/gnome/shell]
app-picker-layout=@aa{sv} []
welcome-dialog-last-shown-version='${GNOME_VER}'

[org/gnome/mutter]
dynamic-workspaces=false
workspaces-only-on-primary=true

[org/gnome/desktop/wm/preferences]
num-workspaces=1

[org/gnome/desktop/privacy]
remember-app-usage=false
remember-recent-files=false
DCONF_DEFAULTS

# Lock: appgrid alfabético permanente (usuario no puede cambiar)
cat > /etc/dconf/db/local.d/locks/00-gnome-installer << 'DCONF_LOCKS'
/org/gnome/shell/app-picker-layout
DCONF_LOCKS

dconf update

# Evitar gnome-initial-setup (asistente de bienvenida)
mkdir -p /etc/skel/.config
echo "yes" > /etc/skel/.config/gnome-initial-setup-done

echo "✓  dconf: workspaces, privacidad, appgrid, arranque directo"
DCONF_SYSTEM

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
