#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 11: Configuración de usuario GNOME (D-Bus)
# REQUIERE: TARGET, USERNAME, GNOME_DOCK
# PRODUCE:  Script primer login + dconf extensions
# DESCRIPCIÓN: Configuración de usuario GNOME — solo lo que necesita D-Bus
# DEPENDENCIAS: 10-install-gnome-core.sh, 13-install-fonts.sh
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# ARQUITECTURA (ver 10-install-gnome-core.sh para contexto completo):
#
#   Este módulo gestiona únicamente la CAPA 3: configuración que requiere
#   D-Bus activo y una sesión GNOME real para funcionar.
#
#   Lo que NO está aquí (ya resuelto en capas anteriores):
#   - Temas, fuentes, cursor, color-scheme  → gschema.override (capa 1)
#   - Dock: posición, tamaño, transparencia → gschema.override (capa 1)
#   - Workspaces, privacidad, botones       → gschema.override (capa 1)
#   - welcome-dialog, xwayland-scaling      → dconf system-db (capa 2)
#
#   Lo que SÍ está aquí (genuinamente requiere D-Bus o es per-usuario):
#   - Activar extensiones (merge con lista existente — requiere leer estado)
#   - user-theme name (schema de extensión — no disponible en gschema.override)
#   - Wallpaper (detección dinámica del archivo instalado por ubuntu-wallpapers)
#   - Carpetas del app grid (schema relocatable — solo funciona con gsettings)
#   - Apps ocultas (~/.local/share/applications/ — archivos de usuario)
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"


# ── Cargar configuración desde config.yaml ────────────────────────────────────
_YAML_FILE="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/../config.yaml"
_yaml_val() {
    # Lee una clave de config.yaml: _yaml_val "section" "key" "default"
    local section="$1" key="$2" default="${3:-}"
    [ ! -f "$_YAML_FILE" ] && { echo "$default"; return; }
    local in_section=false val=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*$ ]]; then
            [ "${BASH_REMATCH[1]}" = "$section" ] && in_section=true || in_section=false
            continue
        fi
        if $in_section && [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]+(.*) ]]; then
            val="${BASH_REMATCH[1]}"
            val="${val%%#*}"; val="${val%"${val##*[![:space:]]}"}";
            val="${val#\"}" ; val="${val%\"}"; val="${val#\'}" ; val="${val%\'}"
            echo "$val"; return
        fi
    done < "$_YAML_FILE"
    echo "$default"
}

[ -z "${GNOME_DOCK:-}" ] && GNOME_DOCK=$(_yaml_val "gnome" "dock" "dash-to-panel")
[ -z "${USERNAME:-}" ] && USERNAME=$(_yaml_val "system" "username" "")


# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

C_OK='\033[0;32m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'


# ── Limpiar extensión snapd-prompting ─────────────────────────────────────────
arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
SNAPD_EXT="/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com"
if [ -d "$SNAPD_EXT" ]; then
    rm -rf "$SNAPD_EXT"
    echo "✓  Extensión snapd-prompting eliminada"
fi
CHROOTEOF

# ============================================================================
# CAPA 3: SCRIPT DE PRIMER LOGIN
# ============================================================================
# Instalado en /usr/local/lib/ y lanzado por /etc/xdg/autostart/ en la
# primera sesión gráfica GNOME. Se autodestruye tras ejecutarse.
# Solo contiene lo que genuinamente requiere D-Bus activo.

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
mkdir -p /usr/local/lib/ubuntu-advanced-install

cat > /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh << 'CONFIGSCRIPT'
#!/bin/bash
# ── Configuración de usuario GNOME — primer login ────────────────────────────
# Invocado por /etc/xdg/autostart/gnome-first-login.desktop
# Se autodestruye tras ejecutarse (mismo patrón que bazzite-user-setup).
#
# Prerequisitos resueltos durante la instalación (sin necesidad de D-Bus):
#   Capa 1 — gschema.override: temas, fuentes, dock, workspaces, privacidad
#   Capa 2 — dconf system-db:  welcome-dialog, xwayland-native-scaling
#
# Este script solo configura lo que genuinamente necesita D-Bus activo.

MARKER="$HOME/.config/.gnome-user-configured"
AUTOSTART_DESKTOP="/etc/xdg/autostart/gnome-first-login.desktop"

# Guardia: ejecutar solo una vez
[ -f "$MARKER" ] && exit 0

# ── Esperar a que GNOME Shell esté completamente listo ────────────────────────
# org.gnome.Shell.Eval está desactivado por defecto en GNOME 45+ (safety lockdown).
# Se usa org.freedesktop.DBus.NameHasOwner que no requiere permisos especiales.
_wait_for_shell() {
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if dbus-send --session --print-reply --dest=org.freedesktop.DBus \
            /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
            string:org.gnome.Shell 2>/dev/null | grep -q "boolean true"; then
            return 0
        fi
        sleep 1
        attempts=$(( attempts + 1 ))
    done
    return 1
}
_wait_for_shell || true
sleep 1

# ── Extensiones: preactivadas via dconf system-db (ver final de módulo 11) ───
# La lista se escribe en /etc/dconf/db/local.d/01-extensions antes de primer
# login, así que las extensiones están activas desde el primer frame de GNOME.
# Este script ya no necesita tocar enabled-extensions.

# ── Tema de shell (user-theme) ────────────────────────────────────────────────
# org.gnome.shell.extensions.user-theme no existe hasta que la extensión
# user-theme está cargada en la sesión — no puede ir en gschema.override.
if [ -d "$HOME/.themes/Adwaita-Transparent" ]; then
    gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent' 2>/dev/null || true
fi

# ── Wallpaper personalizado ───────────────────────────────────────────────────
# Se prioriza el wallpaper custom descargado durante la instalación.
# Fallback: wallpaper de Ubuntu según la release.
_set_wallpaper() {
    local bg_dir="/usr/share/backgrounds"
    local custom_wp="$bg_dir/homer-simpson.jpg"
    local wp="" wp_dark=""

    # Prioridad 1: wallpaper custom (Homer)
    if [ -f "$custom_wp" ]; then
        wp="$custom_wp"
        gsettings set org.gnome.desktop.background picture-uri       "file://$wp"
        gsettings set org.gnome.desktop.screensaver picture-uri      "file://$wp"
        gsettings set org.gnome.desktop.background picture-uri-dark  "file://$wp"
        echo "✓  Wallpaper: $wp"
        return
    fi

    # Prioridad 2: wallpaper de Ubuntu según codename
    local codename=""
    [ -f /etc/os-release ] && codename=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")

    case "$codename" in
        noble)
            wp=$(find "$bg_dir" -maxdepth 2 \( -iname "*noble*" -o -iname "*numbat*" \) \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            ;;
        jammy)
            wp=$(find "$bg_dir" -maxdepth 2 -iname "*jammy*" \
                     \( -name "*-d.*" -o -name "*dark*" \) 2>/dev/null | sort | tail -1)
            [ -z "$wp" ] && wp=$(find "$bg_dir" -maxdepth 2 -iname "*jammy*" \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            wp_dark=$(find "$bg_dir" -maxdepth 2 -iname "*jammy*" \
                     \( -name "*-l.*" -o -name "*light*" \) 2>/dev/null | sort | tail -1)
            ;;
        focal)
            wp=$(find "$bg_dir" -maxdepth 2 \( -iname "*focal*" -o -iname "*fossa*" \) \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            ;;
        *)
            [ -n "$codename" ] && wp=$(find "$bg_dir" -maxdepth 2 -iname "*${codename}*" \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            ;;
    esac

    [ -z "$wp" ] && wp=$(find "$bg_dir" -maxdepth 2 \( -name "*.jpg" -o -name "*.png" \) \
             ! -iname "warty*" 2>/dev/null | sort | tail -1)

    if [ -n "$wp" ] && [ -f "$wp" ]; then
        gsettings set org.gnome.desktop.background picture-uri       "file://$wp"
        gsettings set org.gnome.desktop.screensaver picture-uri      "file://$wp"
        if [ -n "$wp_dark" ] && [ -f "$wp_dark" ]; then
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp_dark"
        else
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp"
        fi
        echo "✓  Wallpaper: $wp"
    else
        echo "ℹ  Sin wallpaper Ubuntu en $bg_dir — dejando el predeterminado"
    fi
}
_set_wallpaper

# ── Apps ocultas del App Grid ─────────────────────────────────────────────────
# ~/.local/share/applications/ sobreescribe /usr/share/applications/ por usuario.
# NoDisplay=true oculta la app del grid sin desinstalarla.
HIDDEN_APPS=(
    "org.gnome.Totem.desktop"
    "mpv.desktop"
    "software-properties-drivers.desktop"
    "software-properties-gtk.desktop"
    "software-properties-livepatch.desktop"
)

mkdir -p "$HOME/.local/share/applications"

for DESKTOP_NAME in "${HIDDEN_APPS[@]}"; do
    USER_DESKTOP="$HOME/.local/share/applications/$DESKTOP_NAME"
    SYSTEM_DESKTOP="/usr/share/applications/$DESKTOP_NAME"
    [ ! -f "$SYSTEM_DESKTOP" ] && continue
    [ ! -f "$USER_DESKTOP" ] && cp "$SYSTEM_DESKTOP" "$USER_DESKTOP"
    # NoDisplay=true debe quedar DENTRO de [Desktop Entry], no al final del archivo.
    sed -i '/^NoDisplay=/d' "$USER_DESKTOP"
    sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$USER_DESKTOP"
done

# ── Carpetas del App Grid ─────────────────────────────────────────────────────
# Schema relocatable: no puede especificarse en gschema.override (solo schemas
# con path fijo). Se escribe con gsettings en runtime — mismo patrón que Bazzite.

gsettings set org.gnome.desktop.app-folders folder-children "[]"

# ── Carpeta Utilidades ──────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    name 'Utilidades'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    apps "['org.gnome.Calculator.desktop', 'org.gnome.Evince.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.font-viewer.desktop', 'org.gnome.gedit.desktop', 'viewnior.desktop', 'org.gnome.Geary.desktop', 'com.github.johnfactotum.Foliate.desktop', 'org.gnome.DejaDup.desktop', 'be.alexandervanhee.gradia.desktop']"

# ── Carpeta Sistema ────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    name 'Sistema'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    apps "['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', 'com.mattjakeman.ExtensionManager.desktop', 'org.gnome.DiskUtility.desktop', 'org.gnome.baobab.desktop', 'org.gnome.Logs.desktop', 'org.gnome.Terminal.desktop', 'lxtask.desktop', 'nm-connection-editor.desktop', 'gnome-language-selector.desktop', 'software-properties-gtk.desktop', 'update-manager.desktop', 'gdebi.desktop', 'io.github.thetumultuousunicornofdarkness.cpu-x.desktop', 'kdiskmark.desktop', 'org.gnome.Boxes.desktop', 'org.wireshark.Wireshark.desktop']"

# ── Carpeta Juegos ────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Gaming/ \
    name 'Juegos'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Gaming/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Gaming/ \
    apps "['steam.desktop', 'heroic.desktop', 'faugus-launcher.desktop', 'com.vysp3r.ProtonPlus.desktop', 'io.github.radiolamp.mangojuice.desktop', 'discord.desktop']"

# ── Carpeta Multimedia ────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ \
    name 'Multimedia'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ \
    apps "['vlc.desktop', 'org.fooyin.fooyin.desktop', 'spotify.desktop', 'com.obsproject.Studio.desktop']"

# ── Carpeta Desarrollo ────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ \
    name 'Desarrollo'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ \
    apps "['code.desktop', 'com.mitchellh.ghostty.desktop', 'org.gnome.Meld.desktop', 'nvim.desktop', 'postman.desktop']"

# ── Carpeta Internet ──────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ \
    name 'Internet'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ \
    apps "['org.qbittorrent.qBittorrent.desktop', 'mullvad-vpn.desktop']"

# ── Carpeta Oficina ───────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Office/ \
    name 'Oficina'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Office/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Office/ \
    apps "['onlyoffice-desktopeditors.desktop', 'obsidian.desktop']"

# ── Carpeta Streaming ─────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Streaming/ \
    name 'Streaming'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Streaming/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Streaming/ \
    apps "['webapp-netflix.desktop', 'webapp-hbomax.desktop', 'webapp-primevideo.desktop', 'webapp-disneyplus.desktop', 'webapp-filmin.desktop', 'webapp-dazn.desktop', 'webapp-movistarplus.desktop', 'webapp-youtube.desktop', 'webapp-ytmusic.desktop']"

# ── Carpeta IA ────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/AI/ \
    name 'IA'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/AI/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/AI/ \
    apps "['webapp-chatgpt.desktop', 'webapp-claude.desktop']"

gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'System', 'Gaming', 'Multimedia', 'Development', 'Internet', 'Office', 'Streaming', 'AI']"

# ── V-Shell (vertical-workspaces) — configuración completa ───────────────────
# Keys y valores obtenidos de `dconf dump /org/gnome/shell/extensions/vertical-workspaces/`
# en una instalación real con la configuración deseada.
#
# Las extensiones de terceros no leen del system-db de forma fiable:
# se aplica todo via dconf write en el primer login con D-Bus activo.
#
# Módulos desactivados (dash-module, layout-module, panel-module…):
#   V-Shell los autodesactiva al detectar Dash to Panel / ubuntu-dock.
# ─────────────────────────────────────────────────────────────────────────────

# ── V-Shell: un solo dconf load con toda la configuración ─────────────────────
# 97 keys cargadas en una sola operación (antes: 97 fork+exec individuales).
dconf load /org/gnome/shell/extensions/vertical-workspaces/ << 'VSHELL_INI'
[/]
startup-state=1
ws-thumbnails-position=9
ws-thumbnail-scale=10
ws-thumbnail-scale-appgrid=10
ws-thumbnails-full=false
wst-position-adjust=0
ws-preview-scale=100
ws-max-spacing=20
overview-mode=2
workspace-animation=1
dash-position=2
dash-position-adjust=0
show-app-icon-position=1
center-dash-to-ws=false
win-preview-icon-size=1
win-title-position=4
win-preview-show-close-button=true
win-preview-height-compensation=80
win-preview-sec-mouse-btn-action=0
win-preview-mid-mouse-btn-action=0
show-ws-preview-bg=true
ws-preview-bg-radius=30
show-ws-switcher-bg=true
show-overview-background=2
overview-bg-brightness=100
app-grid-bg-brightness=100
search-bg-brightness=50
overview-bg-blur-sigma=0
app-grid-bg-blur-sigma=0
panel-overview-style=0
app-grid-order=4
app-grid-icon-size=112
app-grid-columns=0
app-grid-rows=3
app-grid-page-width-scale=100
app-grid-page-height-scale=100
app-grid-spacing=18
app-grid-incomplete-pages=false
app-grid-content=0
app-grid-names=1
app-grid-animation=4
app-grid-active-preview=false
app-grid-orientation=0
app-grid-performance=true
app-grid-remember-page=false
app-grid-show-page-arrows=true
app-grid-show-page-indicators=false
app-grid-show-package-type=1
center-app-grid=true
app-folder-order=1
app-grid-folder-icon-size=112
app-grid-folder-columns=4
app-grid-folder-rows=3
app-grid-folder-icon-grid=2
app-grid-folder-spacing=5
app-grid-folder-center=true
app-folder-close-button=true
app-folder-remove-button=1
search-icon-size=0
search-max-results-rows=5
search-app-grid-mode=1
search-results-bg-style=0
search-view-animation=0
search-width-scale=100
search-fuzzy=false
search-include-settings=true
show-search-entry=false
center-search=true
hot-corner-action=1
hot-corner-position=6
hot-corner-fullscreen=true
hot-corner-ripples=true
overview-esc-behavior=0
overview-sort-windows=1
overview-select-window=2
click-empty-close=false
dash-icon-scroll=2
dash-isolate-workspaces=false
notification-position=1
osd-position=6
favorites-notify=1
animation-speed-factor=100
delay-startup=true
highlighting-style=1
window-attention-mode=0
window-icon-click-action=1
ws-switcher-mode=0
ws-switcher-wraparound=false
ws-switcher-ignore-last=false
ws-sw-popup-h-position=50
ws-sw-popup-v-position=95
ws-sw-popup-mode=1
app-menu-force-quit=true
app-menu-close-wins-ws=true
app-menu-move-app=true
app-menu-window-tmb=true
always-activate-selected-window=false
VSHELL_INI

echo "✓  V-Shell configurado (97 keys via dconf load)"

# ── Arc Menu — configuración (solo si está instalado con ubuntu-dock) ─────────
# menu-layout 'Elementary': grid de iconos estilo elementary OS, sin categorías.
# position-in-panel: 0=Left, 1=Center, 2=Right — se coloca al inicio del panel.
# show-activities-button: false — el botón de Arc Menu reemplaza al de Show Apps
# del dock; Activities se abre desde el hot corner o Super.
#
# ubuntu-dock: show-apps-button-at-top=false oculta el botón nativo Show Apps
# del dock para que no quede duplicado junto a Arc Menu.
if [ -d "/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com" ]; then
    AM="/org/gnome/shell/extensions/arcmenu"

    dconf write $AM/menu-layout "'Elementary'"
    dconf write $AM/position-in-panel 'int32 0'
    dconf write $AM/show-activities-button 'false'
    dconf write $AM/arc-menu-placement 'int32 0'

    # ubuntu-dock: ocultar botón Show Apps (reemplazado por Arc Menu)
    gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-button-at-top false \
        2>/dev/null || true
    gsettings set org.gnome.shell.extensions.ubuntu-dock show-apps-button-at-top false \
        2>/dev/null || true

    echo "✓  Arc Menu configurado (Elementary, posición izquierda)"
    unset AM
fi

# ── Autodestrucción ───────────────────────────────────────────────────────────
mkdir -p "$HOME/.config"
touch "$MARKER"
rm -f "$AUTOSTART_DESKTOP"

echo "✓  Configuración de usuario GNOME aplicada"
CONFIGSCRIPT

chmod 755 /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh
echo "✓  Script de primer login instalado en /usr/local/lib/ubuntu-advanced-install/"
CHROOTEOF

# Sustituir el UUID del dock directamente desde el host
if [ "${GNOME_DOCK:-ubuntu-dock}" = "dash-to-panel" ]; then
    DOCK_UUID="dash-to-panel@jderose9.github.com"
else
    DOCK_UUID="ubuntu-dock@ubuntu.com"
fi
echo "  Dock: ${DOCK_UUID}"

# ── Preactivar extensiones via dconf system-db ───────────────────────────────
# Se escribe en un segundo archivo dconf para no duplicar la sección
# [org/gnome/shell] del archivo 00-ubuntu-advanced-install.
# Así GNOME arranca con todas las extensiones activas desde el primer frame.
EXT_LIST="'ubuntu-appindicators@ubuntu.com', '${DOCK_UUID}', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'vertical-workspaces@G-dH.github.com', 'caffeine@patapon.info'"

# Arc Menu: solo con ubuntu-dock (reemplaza el botón Show Apps por lanzador de workspace)
if [ "${GNOME_DOCK:-ubuntu-dock}" = "ubuntu-dock" ] && \
   [ -d "$TARGET/usr/share/gnome-shell/extensions/arcmenu@arcmenu.com" ]; then
    EXT_LIST="${EXT_LIST}, 'arcmenu@arcmenu.com'"
    echo "  Arc Menu: activado (ubuntu-dock)"
fi

if [ "${ENABLE_DESKTOP_ICONS:-false}" = "true" ]; then
    EXT_LIST="${EXT_LIST}, 'ding@rastersoft.com'"
    echo "  Desktop Icons NG: activado"
else
    echo "  Desktop Icons NG: no activado"
fi

cat > "$TARGET/etc/dconf/db/local.d/01-extensions" << EXTEOF
[org/gnome/shell]
enabled-extensions=[${EXT_LIST}]
EXTEOF

arch-chroot "$TARGET" dconf update 2>/dev/null || true
echo "✓  Extensiones preactivadas via dconf system-db"

# ── Autostart .desktop ────────────────────────────────────────────────────────
arch-chroot "$TARGET" /bin/bash << 'AUTOSTARTEOF'
mkdir -p /etc/xdg/autostart

cat > /etc/xdg/autostart/gnome-first-login.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Type=Application
Name=GNOME First Login Configuration
Comment=Configura el entorno GNOME en el primer inicio de sesión
Exec=/usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh
Terminal=false
NoDisplay=true
OnlyShowIn=GNOME;
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
DESKTOP_EOF

echo "✓  Autostart: /etc/xdg/autostart/gnome-first-login.desktop"
AUTOSTARTEOF

echo ""
echo -e "${C_OK}✓${C_RESET}  Configuración GNOME lista"
echo ""
echo "  Capa 1 — gschema.override:  temas, fuentes, dock, workspaces (desde 1er boot)"
echo "  Capa 2 — dconf system-db:   welcome-dialog, xwayland-scaling  (desde 1er boot)"
echo "  Capa 3 — primer login:      extensiones, wallpaper, carpetas, CSS de usuario"
echo ""

exit 0
