#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 10: GNOME Core — instalación y configuración de sistema
#
# ARQUITECTURA DE CONFIGURACIÓN (3 capas, mismo patrón que Zorin OS / Bazzite):
#
#   1. gschema.override  (/usr/share/glib-2.0/schemas/)
#      Defaults del sistema: temas, fuentes, dock, workspaces, privacidad...
#      Aplica sin D-Bus, sin primer login, para todos los usuarios.
#      El usuario puede sobreescribirlos libremente desde Ajustes.
#
#   2. dconf system-db   (/etc/dconf/db/local.d/ + dconf update)
#      Keys que NO tienen schema instalado antes del paquete correspondiente
#      o que necesitan valores dinámicos (ej. versión de GNOME en runtime).
#      También aplica sin D-Bus, para todos los usuarios.
#
#   3. Script primer login  (10-user-config.sh → /etc/xdg/autostart/)
#      Solo lo que genuinamente necesita D-Bus activo:
#      - Activar extensiones (merge con lista existente)
#      - Carpetas del app grid (schema relocatable)
#      - Wallpaper (detección dinámica de archivo)
#      - Archivos de usuario (~/.config/gnome-shell/gnome-shell.css)
#      - Apps ocultas (~/.local/share/applications/)
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

echo "✓  Extension Manager + extensiones instaladas"
echo "   (defaults via gschema.override — activación definitiva en primer login)"

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

# ── GNOME Keyring — keyring "login" con contraseña vacía ──────────────────
# Se escribe directamente en /etc/skel: useradd -m ya lo copió al home
# del usuario con permisos correctos. Solo necesitamos asegurar los archivos.
# El directorio .local/share/keyrings ya existe en skel (creado en 03).
install -d -m 0700 /etc/skel/.local/share/keyrings
echo "login" > /etc/skel/.local/share/keyrings/default
cat > /etc/skel/.local/share/keyrings/login.keyring << 'KEYRING'
[keyring]
display-name=login
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
KEYRING
chmod 600 /etc/skel/.local/share/keyrings/default \
          /etc/skel/.local/share/keyrings/login.keyring
echo "✓  GNOME Keyring: contraseña vacía configurada en skel"

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

# ── AppImage: libfuse ────────────────────────────────────────────────────────
# libfuse2 — necesario para ejecutar AppImages (FUSE v2)
apt install -y libfuse2t64 2>/dev/null || apt install -y libfuse2 2>/dev/null || true


CHROOTEOF

# ============================================================================
# CAPA 1: GSCHEMA OVERRIDE — defaults de sistema
# ============================================================================
# Mismo patrón que Zorin OS y Ubuntu: copiar el .gschema.override al directorio
# de schemas de GNOME y compilar. Los valores son defaults (no locks): el usuario
# puede sobreescribirlos desde Ajustes o Extension Manager sin restricciones.
#
# Se instala DESPUÉS de los paquetes para que los schemas de las extensiones
# (ubuntu-dock, etc.) ya estén disponibles cuando se ejecuta glib-compile-schemas.
# glib-compile-schemas --strict falla si referencia un schema no instalado.

OVERRIDE_SRC="$(dirname "$0")/../files/99-ubuntu-advanced-install.gschema.override"
OVERRIDE_DST="$TARGET/usr/share/glib-2.0/schemas/99-ubuntu-advanced-install.gschema.override"

if [ -f "$OVERRIDE_SRC" ]; then
    cp "$OVERRIDE_SRC" "$OVERRIDE_DST"
    arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "✓  gschema.override instalado y compilado"
    echo "   (temas, fuentes, dock, workspaces, privacidad — activos sin primer login)"
else
    echo "⚠  No se encontró files/99-ubuntu-advanced-install.gschema.override"
fi

# ============================================================================
# CAPA 2: DCONF SYSTEM-DB — valores dinámicos y keys sin schema previo
# ============================================================================
# /etc/dconf/db/local.d/ es el equivalente al "system-db" de Bazzite/Fedora.
# Aplica a todos los usuarios, sin D-Bus, sin primer login.
# El perfil /etc/dconf/profile/user define el orden de búsqueda:
#   user-db:user  → ~/.config/dconf/user  (mayor prioridad, escritura)
#   system-db:local → /etc/dconf/db/local (menor prioridad, solo lectura)

arch-chroot "$TARGET" /bin/bash << 'DCONF_SYSTEM'

# ── Perfil dconf: user → local ────────────────────────────────────────────────
# Sin este archivo, dconf no sabe que existe un system-db y lo ignora.
# Mismo patrón que Ubuntu, Zorin OS y Bazzite.
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

mkdir -p /etc/dconf/db/local.d

# ── Valores dinámicos que requieren runtime en chroot ─────────────────────────
# (no pueden ir en gschema.override porque dependen de la versión instalada)
GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' | head -1 || echo "99.0")

cat > /etc/dconf/db/local.d/00-ubuntu-advanced-install << DCONF_EOF
# ── Sistema ───────────────────────────────────────────────────────────────────
# Suprimir el diálogo de bienvenida de GNOME ("What's New")
[org/gnome/shell]
welcome-dialog-last-shown-version='${GNOME_VER}'

# ── Workspaces — workspace único fijo ────────────────────────────────────────
# El perfil /etc/dconf/profile/user (creado arriba) hace que dconf consulte
# este system-db como fuente de defaults. Para un usuario nuevo sin nada en
# su user-db, estos valores se aplican directamente sin ningún paso extra.
[org/gnome/mutter]
dynamic-workspaces=false
workspaces-only-on-primary=true

[org/gnome/desktop/wm/preferences]
num-workspaces=1

# ── Privacidad — historial de aplicaciones y archivos ────────────────────────
[org/gnome/desktop/privacy]
remember-app-usage=false
remember-recent-files=false

# ── xwayland-native-scaling — escalado correcto para apps X11 en Wayland ─────
[org/gnome/mutter]
experimental-features=['xwayland-native-scaling']

DCONF_EOF

dconf update

echo "✓  dconf system-db configurado (workspaces, welcome-dialog, privacidad)"
DCONF_SYSTEM

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
