#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-user-config.sh
# DESCRIPCIÓN: Configuración completa de GNOME para el usuario.
#              Todo se aplica en chroot — sin script de primer arranque.
# DEPENDENCIAS: 03-configure-base.sh (usuario creado), 10-install-gnome-core.sh
# VARIABLES REQUERIDAS: TARGET, USERNAME
#
# MÉTODO:
#   1. Apps ocultas → .desktop con NoDisplay=true en /etc/skel/.local/share/applications/
#      Se sincroniza al home del usuario con cp -a + chown -R.
#   2. CSS de overview → /etc/skel/.config/gnome-shell/gnome-shell.css
#   3. Todo lo demás (tema, fuentes, dock, extensiones, wallpaper, carpetas…) →
#      dconf load ejecutado como el usuario dentro del chroot.
#      dconf escribe ~/.config/dconf/user directamente sin necesitar D-Bus.
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

C_OK='\033[0;32m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  CONFIGURACIÓN DE USUARIO GNOME${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""

# ============================================================================
# BLOQUE 1 — ARCHIVOS DE SKEL (no requieren D-Bus)
# ============================================================================

arch-chroot "$TARGET" /bin/bash << SKELEOF

# ── Eliminar extensión snapd-prompting ───────────────────────────────────────
SNAPD_EXT="/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com"
[ -d "\$SNAPD_EXT" ] && rm -rf "\$SNAPD_EXT" && echo "✓  snapd-prompting eliminado"

# ── CSS de overview transparente ─────────────────────────────────────────────
# gnome-shell carga ~/.config/gnome-shell/gnome-shell.css automáticamente
# desde GNOME 44+. .workspace-background controla el fondo del overview/app grid.
install -d -m 0755 /etc/skel/.config/gnome-shell
cat > /etc/skel/.config/gnome-shell/gnome-shell.css << 'CSS_EOF'
/* ubuntu-advanced-install: overview y app grid transparentes */
.workspace-background {
    background: transparent !important;
    border-radius: 0 !important;
    box-shadow: none !important;
}
CSS_EOF

# ── Apps ocultas del App Grid ─────────────────────────────────────────────────
# NoDisplay=true en ~/.local/share/applications/ oculta la app del grid sin
# desinstalarla. NoDisplay debe estar DENTRO de [Desktop Entry] — sed lo inserta
# en la primera línea tras el bloque principal, incluso con secciones adicionales.
HIDDEN_APPS=(
    "org.gnome.Totem.desktop"               # Totem — solo para thumbnailers
    "software-properties-drivers.desktop"   # Controladores adicionales
    "software-properties-gtk.desktop"       # Software y actualizaciones
    "software-properties-livepatch.desktop" # Livepatch
    "display-im7.q16.desktop"               # ImageMagick — dependencia arrastrada
    "display-im6.q16.desktop"               # ImageMagick (versión alternativa)
)

for DESKTOP_NAME in "\${HIDDEN_APPS[@]}"; do
    SKEL_DESKTOP="/etc/skel/.local/share/applications/\$DESKTOP_NAME"
    SYSTEM_DESKTOP="/usr/share/applications/\$DESKTOP_NAME"
    [ ! -f "\$SYSTEM_DESKTOP" ] && echo "  ⚠  \$DESKTOP_NAME no encontrado — omitido" && continue
    cp "\$SYSTEM_DESKTOP" "\$SKEL_DESKTOP"
    sed -i '/^NoDisplay=/d' "\$SKEL_DESKTOP"
    sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "\$SKEL_DESKTOP"
    echo "  ✓  Oculto: \$DESKTOP_NAME"
done

# ── Sincronizar skel → home del usuario ──────────────────────────────────────
if id "$USERNAME" >/dev/null 2>&1; then
    cp -a --no-clobber /etc/skel/. "/home/$USERNAME/"
    chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME"
    echo "✓  skel → /home/$USERNAME sincronizado"
fi

SKELEOF

# ============================================================================
# BLOQUE 2 — DCONF DE USUARIO
# ============================================================================
# dconf load ejecutado como el usuario en chroot escribe ~/.config/dconf/user
# (base de datos binaria GVDB) sin necesitar D-Bus ni sesión gráfica.
# Configura de forma definitiva, desde la instalación, sin script diferido.
# ============================================================================

arch-chroot "$TARGET" /bin/bash << DCONFEOF

USERNAME="$USERNAME"

if ! id "\$USERNAME" >/dev/null 2>&1; then
    echo "⚠  Usuario \$USERNAME no encontrado — saltando configuración dconf"
    exit 0
fi

# Detectar versión de GNOME
GNOME_VER=\$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "46")

# Detectar wallpaper del codename instalado
CODENAME=\$(. /etc/os-release 2>/dev/null && echo "\${VERSION_CODENAME:-noble}")
BG_DIR="/usr/share/backgrounds"
WALLPAPER=\$(find "\$BG_DIR" -maxdepth 2 \( -iname "*\${CODENAME}*" \) \
    \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
[ -z "\$WALLPAPER" ] && WALLPAPER=\$(find "\$BG_DIR" -maxdepth 2 \
    \( -name "*.jpg" -o -name "*.png" \) ! -iname "warty*" 2>/dev/null | sort | tail -1)
[ -z "\$WALLPAPER" ] && WALLPAPER="/usr/share/backgrounds/warty-final-ubuntu.png"
WALLPAPER_URI="file://\$WALLPAPER"

cat > /tmp/user-dconf.ini << DCONF_INI
[org/gnome/shell]
enabled-extensions=['ubuntu-appindicators@ubuntu.com', 'ubuntu-dock@ubuntu.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'ding@rastersoft.com']
welcome-dialog-last-shown-version='\$GNOME_VER'
favorite-apps=['google-chrome.desktop', 'org.gnome.Nautilus.desktop']

[org/gnome/shell/extensions/user-theme]
name='Adwaita-Transparent'

[org/gnome/desktop/interface]
gtk-theme='Adwaita-dark'
icon-theme='elementary'
cursor-theme='elementary'
color-scheme='prefer-dark'
font-name='Ubuntu 11'
document-font-name='Ubuntu 11'
monospace-font-name='JetBrainsMono Nerd Font 10'

[org/gnome/desktop/wm/preferences]
titlebar-font='Ubuntu Bold 11'
button-layout=':minimize,maximize,close'
num-workspaces=1

[org/gnome/mutter]
dynamic-workspaces=false
workspaces-only-on-primary=true
experimental-features=['xwayland-native-scaling']

[org/gnome/desktop/background]
picture-uri='\$WALLPAPER_URI'
picture-uri-dark='\$WALLPAPER_URI'
picture-options='zoom'
color-shading-type='solid'
primary-color='#000000'

[org/gnome/desktop/screensaver]
picture-uri='\$WALLPAPER_URI'
picture-options='zoom'
picture-opacity=100

[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
dash-max-icon-size=48
autohide=true
intellihide=true
intellihide-mode='FOCUS_APPLICATION_WINDOWS'
animation-time=0.20000000000000001
hide-delay=0.20000000000000001
show-delay=0.0
click-action='minimize-or-previews'
show-running=true
show-windows-preview=true
transparency-mode='FIXED'
background-opacity=0.34999999999999998
isolate-workspaces=false
show-apps-button-at-top=true

[org/gnome/desktop/app-folders]
folder-children=['Utilities', 'System']

[org/gnome/desktop/app-folders/folders/Utilities]
name='Utilidades'
translate=false
apps=['org.gnome.Calculator.desktop', 'org.gnome.Evince.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.font-viewer.desktop', 'org.gnome.gedit.desktop', 'viewnior.desktop']

[org/gnome/desktop/app-folders/folders/System]
name='Sistema'
translate=false
apps=['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', 'com.mattjakeman.ExtensionManager.desktop', 'org.gnome.DiskUtility.desktop', 'org.gnome.baobab.desktop', 'org.gnome.Logs.desktop', 'org.gnome.Terminal.desktop', 'lxtask.desktop', 'nm-connection-editor.desktop', 'gnome-language-selector.desktop', 'software-properties-gtk.desktop', 'update-manager.desktop', 'gdebi.desktop']

[org/gnome/desktop/privacy]
remember-app-usage=false
remember-recent-files=false
send-software-usage-stats=false

[org/gnome/desktop/screen-time-limits]
history-enabled=false
grayscale=false
daily-limit-enabled=false
DCONF_INI

# Crear directorio dconf con permisos correctos y cargar la configuración
install -d -m 0700 -o "\$USERNAME" -g "\$USERNAME" "/home/\$USERNAME/.config/dconf"
su -s /bin/bash "\$USERNAME" -c "dconf load / < /tmp/user-dconf.ini"
rm -f /tmp/user-dconf.ini

echo "✓  dconf de usuario escrito en /home/\$USERNAME/.config/dconf/user"
echo "   extensiones, tema, fuentes, dock, carpetas, wallpaper: configurados"

DCONFEOF

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_OK}✓${C_RESET}  CONFIGURACIÓN DE USUARIO GNOME APLICADA"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo "  Sin script de primer arranque."
echo "  Configuración completa desde la instalación vía dconf load."
echo ""

exit 0
