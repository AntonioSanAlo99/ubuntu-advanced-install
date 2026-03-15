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

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE GNOME CORE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# CHROOT: PAQUETES
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

# ── GNOME Shell + core ──────────────────────────────────────────────────────
echo "Instalando GNOME Shell y componentes core..."

apt install -y \
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
    libpam-gnome-keyring \
    at-spi2-core

echo "✓  GNOME Shell instalado"

# ── Utilidades ──────────────────────────────────────────────────────────────
echo "Instalando utilidades..."

apt install -y \
    gnome-calculator bc \
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
apt install -y \
    software-properties-gtk \
    gdebi \
    update-manager \
    curl \
    file

# ── Extension Manager (solo instalación — la activación va en user-config) ──
apt install -y gnome-shell-extension-manager

# ── Extensiones APT (solo instalación — la activación va en user-config) ────
apt install -y \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng

GNOME_DOCK_CHOICE="$GNOME_DOCK"

if [ "\$GNOME_DOCK_CHOICE" = "dash-to-panel" ]; then
    echo "Instalando Dash to Panel..."

    EXT_UUID="dash-to-panel@jderose9.github.com"
    EXT_DIR="/usr/share/gnome-shell/extensions/\$EXT_UUID"
    EXT_ZIP="/tmp/dash-to-panel.zip"

    # Descargar desde GitHub releases (home-sweet-gnome/dash-to-panel)
    # Cada release publica un asset zip con nombre: dash-to-panel@jderose9.github.com_vXX.zip
    # Se usa la API de GitHub para obtener la URL del primer asset .zip del último release.
    DTP_ASSET_URL=\$(curl --max-time 30 --retry 2 -fsSL \
        "https://api.github.com/repos/home-sweet-gnome/dash-to-panel/releases/latest" 2>/dev/null \
        | grep '"browser_download_url"' | grep '\.zip"' | head -1 | cut -d'"' -f4)

    if [ -n "\$DTP_ASSET_URL" ] && wget -q --timeout=30 --tries=2 \
        "\$DTP_ASSET_URL" -O "\$EXT_ZIP" 2>/dev/null && [ -s "\$EXT_ZIP" ]; then

        mkdir -p "\$EXT_DIR"
        unzip -q -o "\$EXT_ZIP" -d "\$EXT_DIR"
        rm -f "\$EXT_ZIP"

        # Compilar schemas si los tiene — requerido para que la extensión arranque
        if [ -d "\$EXT_DIR/schemas" ]; then
            glib-compile-schemas "\$EXT_DIR/schemas" 2>/dev/null || true
        fi

        echo "✓  Dash to Panel instalado (\$EXT_UUID)"
    else
        echo "⚠  Dash to Panel: descarga fallida — se usará Ubuntu Dock"
        GNOME_DOCK_CHOICE="ubuntu-dock"
    fi
fi

if [ "\$GNOME_DOCK_CHOICE" = "ubuntu-dock" ]; then
    apt install -y gnome-shell-extension-ubuntu-dock
    echo "✓  Ubuntu Dock instalado"
fi

echo "✓  Extension Manager + extensiones instaladas"
echo "   (defaults via gschema.override — activación definitiva en primer login)"

# ── systemd-oomd ─────────────────────────────────────────────────────────────
if systemctl list-unit-files systemd-oomd.service &>/dev/null; then
    systemctl enable systemd-oomd 2>/dev/null || true
    echo "✓  systemd-oomd habilitado"
fi

# ── Tema de iconos + GTK ────────────────────────────────────────────────────
apt install -y elementary-icon-theme gnome-themes-extra
echo "✓  Iconos elementary + temas GTK"

# ── Wallpapers ──────────────────────────────────────────────────────────────
CODENAME=\$(. /etc/os-release 2>/dev/null && echo "\${VERSION_CODENAME:-}" || echo "")
[ -z "\$CODENAME" ] && CODENAME="$UBUNTU_VERSION"
apt install -y ubuntu-wallpapers 2>/dev/null || true
apt install -y "ubuntu-wallpapers-\${CODENAME}" 2>/dev/null || true
echo "✓  Wallpapers instalados"

# ── GDM ──────────────────────────────────────────────────────────────────────
# Habilitar GDM y establecer graphical.target como default.
# Sin set-default graphical.target el sistema arranca en multi-user.target
# (modo consola) y la pantalla queda en negro.

# systemctl enable gdm3 crea los symlinks correctos en wants/
systemctl enable gdm3

# Establecer graphical.target como target de arranque por defecto
systemctl set-default graphical.target

echo "✓  GDM habilitado, target por defecto: graphical.target"

GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"
GDM_USER="$USERNAME"
mkdir -p /etc/gdm3

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then
    cat > /etc/gdm3/custom.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=GDM_USER_PLACEHOLDER
[security]
[xdmcp]
[chooser]
[debug]
GDMCONF
    sed -i "s/GDM_USER_PLACEHOLDER/$USERNAME/" /etc/gdm3/custom.conf
    echo "✓  Autologin configurado ($USERNAME)"
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

# ── GNOME Keyring — integración PAM ─────────────────────────────────────────
# Flujo de gnome-keyring con PAM (referencia: wiki.gnome.org/Projects/GnomeKeyring/Pam):
#
#   auth     → pam_gnome_keyring.so: recibe la contraseña del login y desbloquea
#              el keyring "login". Si no existe, lo crea con esa contraseña.
#   session  → pam_gnome_keyring.so auto_start: arranca gnome-keyring-daemon
#              si no está corriendo.
#   password → pam_gnome_keyring.so: cuando el usuario cambia contraseña con
#              passwd, sincroniza la contraseña del keyring "login".
#
# Con autologin (gdm-autologin) no se introduce contraseña → PAM no puede
# desbloquear un keyring protegido → apps como Chrome/Chromium piden
# manualmente la contraseña del keyring en cada sesión.
# Solución: pre-crear el keyring "login" sin contraseña (vacío).
# ============================================================================

# 1. pam-auth-update integra gnome-keyring en common-auth/common-session
DEBIAN_FRONTEND=noninteractive pam-auth-update --enable gnome-keyring 2>/dev/null || true

# 2. Verificar/añadir líneas en ficheros PAM de GDM y login
for pam_file in /etc/pam.d/gdm-password /etc/pam.d/gdm-autologin /etc/pam.d/login; do
    [ ! -f "\$pam_file" ] && continue

    # auth: desbloquea el keyring con la contraseña del login
    if ! grep -q "pam_gnome_keyring.so" "\$pam_file"; then
        if grep -q "@include common-auth" "\$pam_file"; then
            sed -i '/^@include common-auth/a auth       optional     pam_gnome_keyring.so' "\$pam_file"
        fi
    fi

    # session: arranca gnome-keyring-daemon
    if ! grep -q "pam_gnome_keyring.so auto_start" "\$pam_file"; then
        if grep -q "@include common-session" "\$pam_file"; then
            sed -i '/^@include common-session/a session    optional     pam_gnome_keyring.so auto_start' "\$pam_file"
        fi
    fi
done

# 3. Hook de cambio de contraseña: sincroniza keyring cuando el usuario usa passwd
if [ -f /etc/pam.d/passwd ]; then
    if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/passwd; then
        echo "password    optional    pam_gnome_keyring.so" >> /etc/pam.d/passwd
    fi
fi

echo "✓  PAM: gnome-keyring integrado (auth + session + password)"

# ── Autologin: keyring "login" sin contraseña ────────────────────────────────
# Con autologin, PAM no recibe credenciales → si el keyring "login" tiene
# contraseña, Chrome y cualquier app que use Secret Service API pedirán
# desbloqueo manual.
#
# Solución: crear ~/.local/share/keyrings/ con el fichero "default" apuntando
# a "login" y SIN fichero login.keyring → gnome-keyring-daemon lo creará en
# el primer arranque con contraseña vacía (porque PAM no le pasó ninguna).
#
# Si el usuario desactiva autologin después, PAM le pasará la contraseña
# y el keyring se re-creará protegido automáticamente.
if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ] && [ -n "\$GDM_USER" ]; then
    KEYRING_DIR="/home/\$GDM_USER/.local/share/keyrings"
    mkdir -p "\$KEYRING_DIR"
    # Eliminar cualquier keyring pre-existente que pudiera tener contraseña
    rm -f "\$KEYRING_DIR"/*.keyring 2>/dev/null
    # Indicar que el keyring por defecto es "login"
    echo "login" > "\$KEYRING_DIR/default"
    chown -R "\$GDM_USER:\$GDM_USER" "/home/\$GDM_USER/.local/share/keyrings"
    # Copiar a /etc/skel para nuevos usuarios
    mkdir -p /etc/skel/.local/share/keyrings
    echo "login" > /etc/skel/.local/share/keyrings/default
    echo "✓  GNOME Keyring: configurado para autologin (sin contraseña)"
else
    echo "✓  GNOME Keyring: se desbloqueará con la contraseña del login"
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
    # Generar override con la sección de dock correcta según la elección del usuario.
    # El archivo fuente siempre contiene la sección ubuntu-dock; si el usuario eligió
    # Dash to Panel, se elimina esa sección (DtP gestiona sus propios defaults).
    if [ "${GNOME_DOCK:-ubuntu-dock}" = "dash-to-panel" ]; then
        # Eliminar bloque [org.gnome.shell.extensions.ubuntu-dock] completo
        python3 - "$OVERRIDE_SRC" "$OVERRIDE_DST" << 'PYEOF'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
content = open(src).read()
# Eliminar el bloque ubuntu-dock (desde el comentario hasta la línea en blanco siguiente)
content = re.sub(
    r'# ── Dock \(ubuntu-dock.*?\n\n',
    '# Dock: Dash to Panel (configuración gestionada por la extensión)\n\n',
    content, flags=re.DOTALL
)
# Añadir override de Dash to Panel para desactivar overview al login
content += """
# ── Dash to Panel — no overview al iniciar sesión ────────────────────────────
[org.gnome.shell.extensions.dash-to-panel]
disable-overview-on-startup=true
"""
open(dst, 'w').write(content)
PYEOF
        echo "  gschema.override: sección ubuntu-dock omitida (usando Dash to Panel)"
    else
        cp "$OVERRIDE_SRC" "$OVERRIDE_DST"
    fi
    arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "✓  gschema.override instalado y compilado"
    echo "   (temas, fuentes, dock, workspaces, privacidad — activos sin primer login)"

    # ── Override condicional: screen-time-limits (solo GNOME >= 48) ───────────
    # Este schema no existe en GNOME < 48. Si se incluye en el override estático,
    # glib-compile-schemas falla y NINGÚN override se aplica.
    GNOME_MAJOR=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "0")
    if [ "${GNOME_MAJOR:-0}" -ge 48 ]; then
        cat > "$TARGET/usr/share/glib-2.0/schemas/99-screen-time-limits.gschema.override" << 'STLEOF'
[org.gnome.desktop.screen-time-limits]
history-enabled=false
STLEOF
        arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
        echo "✓  screen-time-limits override instalado (GNOME $GNOME_MAJOR >= 48)"
    else
        echo "ℹ  screen-time-limits omitido (GNOME ${GNOME_MAJOR:-?} < 48 — schema no existe)"
    fi
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
experimental-features=['xwayland-native-scaling']

[org/gnome/desktop/wm/preferences]
num-workspaces=1

# ── Privacidad — historial de aplicaciones y archivos ────────────────────────
[org/gnome/desktop/privacy]
remember-app-usage=false
remember-recent-files=false

# ── Donaciones GNOME — desactivar aviso ───────────────────────────────────────
[org/gnome/settings-daemon/plugins/housekeeping]
donation-reminder-enabled=false

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
