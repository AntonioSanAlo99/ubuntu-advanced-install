#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 10: GNOME Core — instalación esencial (sin personalización)
# Personalización (tema, fuentes, dock) → 10-user-config.sh
# Activación de extensiones → 10-user-config.sh (primer login)
# ══════════════════════════════════════════════════════════════════════════════

set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE GNOME CORE"
echo "════════════════════════════════════════════════════════════════"
echo ""

APT_FLAGS=""
[ "$USE_NO_INSTALL_RECOMMENDS" = "true" ] && APT_FLAGS="--no-install-recommends"

# ============================================================================
# CHROOT: PAQUETES
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS="$APT_FLAGS"

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

# ── Extension Manager (solo instalación — la activación va en user-config) ──
apt install -y \$APT_FLAGS gnome-shell-extension-manager

# ── Extensiones APT (solo instalación — la activación va en user-config) ────
apt install -y \$APT_FLAGS \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-ubuntu-dock

echo "✓  Extension Manager + extensiones instaladas (se activan en primer login)"

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
    echo "✓  GDM: login con contraseña"
fi

# ── GNOME Keyring — contraseña vacía (sin popup) ────────────────────────────
# Con autologin, PAM no puede desbloquear el keyring automáticamente.
# Solución: crear keyring "login" con contraseña vacía → nunca pide contraseña.
# Las contraseñas se almacenan sin cifrar, pero con autologin ya se asume
# que el usuario no necesita esa capa de seguridad.

# PAM: asegurar que gnome-keyring-daemon se integra con gdm-autologin
if [ -f /etc/pam.d/gdm-autologin ]; then
    grep -q "pam_gnome_keyring.so" /etc/pam.d/gdm-autologin || {
        echo "auth       optional     pam_gnome_keyring.so" >> /etc/pam.d/gdm-autologin
        echo "session    optional     pam_gnome_keyring.so auto_start" >> /etc/pam.d/gdm-autologin
    }
fi

# Crear keyring "login" con contraseña vacía en /etc/skel (para todos los usuarios)
SKEL_KEYRING="/etc/skel/.local/share/keyrings"
mkdir -p "\${SKEL_KEYRING}"
# Archivo de control: indica que "login" es el keyring por defecto
echo "login" > "\${SKEL_KEYRING}/default"
# Keyring vacío con contraseña vacía (formato GNOME Keyring plaintext)
cat > "\${SKEL_KEYRING}/login.keyring" << 'KEYRING'
[keyring]
display-name=login
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
KEYRING
chmod 700 "\${SKEL_KEYRING}"
chmod 600 "\${SKEL_KEYRING}/default" "\${SKEL_KEYRING}/login.keyring"

# También crear para el usuario actual si ya existe su home
if [ -d "/home/\${USERNAME}" ]; then
    USER_KEYRING="/home/\${USERNAME}/.local/share/keyrings"
    mkdir -p "\${USER_KEYRING}"
    cp "\${SKEL_KEYRING}/default" "\${USER_KEYRING}/default"
    cp "\${SKEL_KEYRING}/login.keyring" "\${USER_KEYRING}/login.keyring"
    chmod 700 "\${USER_KEYRING}"
    chmod 600 "\${USER_KEYRING}/default" "\${USER_KEYRING}/login.keyring"
    chown -R "\${USERNAME}:\${USERNAME}" "\${USER_KEYRING}"
fi
echo "✓  GNOME Keyring: contraseña vacía (sin popup)"

# ── Directorios de usuario para extension-manager ────────────────────────────
# extension-manager necesita ~/.local/share/gnome-shell/extensions para instalar
# extensiones desde la web. Si el directorio no existe y algún padre fue creado
# por root durante la instalación, extension-manager falla con "Permiso denegado".
# Se crea aquí — con el propietario correcto — para evitar el problema.
if [ -d "/home/\${USERNAME}" ]; then
    mkdir -p "/home/\${USERNAME}/.local/share/gnome-shell/extensions"
    chown -R "\${USERNAME}:\${USERNAME}" "/home/\${USERNAME}/.local/share/gnome-shell"
    echo "✓  ~/.local/share/gnome-shell creado (extension-manager listo)"
fi
# También en /etc/skel para usuarios creados después de la instalación
mkdir -p "/etc/skel/.local/share/gnome-shell/extensions"

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

# ── AppImage: libfuse + MIME ─────────────────────────────────────────────────
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
APPUSER="$USERNAME"
mkdir -p "/home/\${APPUSER}/Applications"
chown -R \$(id -u "\$APPUSER" 2>/dev/null || echo 1000):\$(id -g "\$APPUSER" 2>/dev/null || echo 1000) \
    "/home/\${APPUSER}/Applications"

# ── AppManager GUI (AppImage vía AM) ─────────────────────────────────────────
echo ""
echo "Instalando AppManager GUI..."
if command -v am >/dev/null 2>&1; then
    if am -i appmanager 2>/dev/null; then
        echo "✓  AppManager instalado vía AM (AppImage)"
    else
        echo "⚠  AppManager: am -i falló — instalar tras primer boot: sudo am -i appmanager"
    fi
else
    echo "⚠  AppManager: AM no disponible — instalar tras primer boot: sudo am -i appmanager"
fi

# ── AM Application Manager (siempre) ────────────────────────────────────────
# El script INSTALL oficial necesita SUDO_USER definida — en chroot
# como root no existe. La exportamos con el nombre del usuario del sistema.
echo ""
echo "Instalando AM Application Manager..."

export SUDO_USER="$USERNAME"
cd /tmp
if wget -q https://raw.githubusercontent.com/ivan-hc/AM/main/INSTALL 2>/dev/null; then
    chmod a+x ./INSTALL
    ./INSTALL
    rm -f ./INSTALL
    if command -v am >/dev/null 2>&1; then
        echo "✓  AM instalado correctamente"
    else
        echo "⚠  AM: verificar tras primer boot"
    fi
else
    echo "⚠  AM: descarga del instalador falló"
fi

CHROOTEOF

# ============================================================================
# DCONF: DEFAULTS DE SISTEMA
# ============================================================================
# Solo defaults (sin locks). Extension Manager puede modificar todo libremente.
# Las extensiones se ACTIVAN en user-config.sh (primer login con D-Bus).

arch-chroot "$TARGET" /bin/bash << 'DCONF_SYSTEM'

mkdir -p /etc/dconf/db/local.d

GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' || echo "99.0")

cat > /etc/dconf/db/local.d/00-gnome-installer << DCONF_DEFAULTS
[org/gnome/shell]
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

dconf update

# Evitar gnome-initial-setup
mkdir -p /etc/skel/.config
echo "yes" > /etc/skel/.config/gnome-initial-setup-done

echo "✓  dconf: workspace único, privacidad, arranque directo"
DCONF_SYSTEM

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
