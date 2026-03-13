#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-user-config.sh
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

C_OK='\033[0;32m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  CONFIGURACIÓN DE USUARIO GNOME (primer login)${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""

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
_wait_for_shell() {
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if gdbus call --session \
            --dest org.gnome.Shell \
            --object-path /org/gnome/Shell \
            --method org.gnome.Shell.Eval "1" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempts=$(( attempts + 1 ))
    done
    return 1
}
_wait_for_shell || true
sleep 1

# ── Extensiones: merge con lista existente ────────────────────────────────────
# Se lee el valor actual y se añaden las nuestras sin borrar las que GNOME
# o el usuario hayan activado previamente. Requiere D-Bus para leer el estado.
EXTENSIONS=(
    "ubuntu-appindicators@ubuntu.com"
    "DOCK_EXTENSION_PLACEHOLDER"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

CURRENT=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo "@as []")
for ext in "${EXTENSIONS[@]}"; do
    if ! echo "$CURRENT" | grep -q "$ext"; then
        if [ "$CURRENT" = "@as []" ] || [ "$CURRENT" = "[]" ]; then
            CURRENT="['$ext']"
        else
            CURRENT=$(echo "$CURRENT" | sed "s/\]$/, '$ext']/")
        fi
    fi
done
gsettings set org.gnome.shell enabled-extensions "$CURRENT" 2>/dev/null || true

# ── Tema de shell (user-theme) ────────────────────────────────────────────────# org.gnome.shell.extensions.user-theme no existe hasta que la extensión
# user-theme está cargada en la sesión — no puede ir en gschema.override.
if [ -d "$HOME/.themes/Adwaita-Transparent" ]; then
    gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent' 2>/dev/null || true
fi

# ── Wallpaper de Ubuntu ───────────────────────────────────────────────────────
# La ruta exacta varía según la versión instalada — no puede ir en gschema.override.
_set_ubuntu_wallpaper() {
    local bg_dir="/usr/share/backgrounds"
    local wp="" wp_dark=""
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
_set_ubuntu_wallpaper

# ── Workspaces ────────────────────────────────────────────────────────────────
# Ubuntu escribe dynamic-workspaces=true en el user-db durante el primer login
# (desde gnome-initial-setup o su propio script de configuración), lo que toma
# precedencia sobre el system-db. gsettings set sobreescribe ese valor en el
# user-db directamente, que es lo único que funciona en este caso.
gsettings set org.gnome.mutter dynamic-workspaces        false 2>/dev/null || true
gsettings set org.gnome.mutter workspaces-only-on-primary true  2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences num-workspaces  1 2>/dev/null || true

# ── Apps ocultas del App Grid ─────────────────────────────────────────────────
# ~/.local/share/applications/ sobreescribe /usr/share/applications/ por usuario.
# NoDisplay=true oculta la app del grid sin desinstalarla.
HIDDEN_APPS=(
    "org.gnome.Totem.desktop"
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

gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    name 'Utilidades'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ \
    apps "['org.gnome.Calculator.desktop', 'org.gnome.Evince.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.font-viewer.desktop', 'org.gnome.gedit.desktop', 'viewnior.desktop']"

gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    name 'Sistema'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    apps "['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', 'com.mattjakeman.ExtensionManager.desktop', 'org.gnome.DiskUtility.desktop', 'org.gnome.baobab.desktop', 'org.gnome.Logs.desktop', 'org.gnome.Terminal.desktop', 'lxtask.desktop', 'nm-connection-editor.desktop', 'gnome-language-selector.desktop', 'software-properties-gtk.desktop', 'update-manager.desktop', 'gdebi.desktop']"

gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'System']"

# ── Autodestrucción ───────────────────────────────────────────────────────────
mkdir -p "$HOME/.config"
touch "$MARKER"
rm -f "$AUTOSTART_DESKTOP"

echo "✓  Configuración de usuario GNOME aplicada"
CONFIGSCRIPT

chmod +x /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh
echo "✓  Script de primer login instalado en /usr/local/lib/ubuntu-advanced-install/"
CHROOTEOF

# Sustituir el UUID del dock directamente desde el host
if [ "${GNOME_DOCK:-ubuntu-dock}" = "dash-to-panel" ]; then
    DOCK_UUID="dash-to-panel@jderose9.github.com"
else
    DOCK_UUID="ubuntu-dock@ubuntu.com"
fi
sed -i "s/DOCK_EXTENSION_PLACEHOLDER/${DOCK_UUID}/" \
    "$TARGET/usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh"
echo "  Dock en primer login: ${DOCK_UUID}"

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
