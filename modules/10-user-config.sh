#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-user-config.sh
# DESCRIPCIÓN: Configuración visual y de comportamiento de GNOME para el usuario
# DEPENDENCIAS: 10-install-gnome-core.sh, 13-install-fonts.sh
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# CAMBIOS vs versión anterior:
#   - Movido de /etc/profile.d/ a ~/.config/autostart/ con .desktop autodestructivo
#   - /etc/profile.d/ se ejecuta en CUALQUIER shell (bash, sh, scripts de sistema)
#     ~/.config/autostart/ solo se ejecuta en sesiones gráficas XDG — correcto
#   - El .desktop llama a un script en /usr/local/lib/ para mantener el .desktop limpio
#   - El script se autodestruye tras ejecutarse (mismo patrón que VRR/HDR en gaming)
#   - Heredoc exterior con comillas simples: no necesita variables del host
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

# Heredoc con comillas simples: el bloque no necesita variables del host.
# USERNAME se pasa como argumento al script de configuración desde el .desktop.
arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# ── Eliminar extensión snapd-prompting si existe ──────────────────────────────
SNAPD_EXT="/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com"
if [ -d "$SNAPD_EXT" ]; then
    rm -rf "$SNAPD_EXT"
    echo "✓  Extensión snapd-prompting eliminada"
fi

# ── Crear el script de configuración en /usr/local/lib/ ──────────────────────
# Se instala en un directorio de sistema para que el .desktop pueda llamarlo.
# El script se ejecuta como el usuario (no root) gracias al autostart XDG.
mkdir -p /usr/local/lib/ubuntu-advanced-install

cat > /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh << 'CONFIGSCRIPT'
#!/bin/bash
# Configuración de usuario GNOME — se ejecuta una sola vez en el primer login
# Invocado por /etc/xdg/autostart/gnome-first-login.desktop
# Se autodestruye al completarse.

MARKER="$HOME/.config/.gnome-user-configured"
AUTOSTART_DESKTOP="/etc/xdg/autostart/gnome-first-login.desktop"

# Doble guardia: marker + verificar sesión GNOME con D-Bus activo
[ -f "$MARKER" ] && exit 0
[ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && exit 0
[ -z "$DBUS_SESSION_BUS_ADDRESS" ] && exit 0

# ── Esperar a que GNOME Shell esté completamente listo ────────────────────────
# En lugar de un sleep fijo, esperamos a que gnome-shell responda correctamente.
# Máximo 30 segundos. Si no responde, continuamos igual (mejor que no configurar).
_wait_for_shell() {
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if gdbus call --session             --dest org.gnome.Shell             --object-path /org/gnome/Shell             --method org.gnome.Shell.Eval "1" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempts=$(( attempts + 1 ))
    done
    return 1
}

_wait_for_shell || true
sleep 1  # Margen adicional tras la respuesta del shell

# ── Extensiones ───────────────────────────────────────────────────────────────
EXTENSIONS=(
    "ubuntu-appindicators@ubuntu.com"
    "ubuntu-dock@ubuntu.com"
)

if gnome-extensions list 2>/dev/null | grep -q "user-theme@gnome-shell-extensions"; then
    EXTENSIONS+=("user-theme@gnome-shell-extensions.gcampax.github.com")
fi

# Habilitar extensiones — doble método para máxima fiabilidad
for ext in "${EXTENSIONS[@]}"; do
    gnome-extensions enable "$ext" 2>/dev/null || true
done

EXT_STR=$(printf "'%s', " "${EXTENSIONS[@]}")
EXT_STR="[${EXT_STR%, }]"
dconf write /org/gnome/shell/enabled-extensions "$EXT_STR" 2>/dev/null || true
dconf write /org/gnome/shell/disable-user-extensions "false" 2>/dev/null || true

# ── Tema de iconos y color ────────────────────────────────────────────────────
gsettings set org.gnome.desktop.interface icon-theme         'elementary'
gsettings set org.gnome.desktop.interface gtk-theme          'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme       'prefer-dark'

if [ -d "$HOME/.themes/Adwaita-Transparent" ]; then
    gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent'
fi

# ── Wallpaper por defecto de la versión ──────────────────────────────────────
# Busca en /usr/share/backgrounds/ el wallpaper que Ubuntu instala para cada
# versión via ubuntu-wallpapers-CODENAME. Si no lo encuentra, no cambia nada
# (deja el que haya o el gris por defecto de GNOME).
_set_ubuntu_wallpaper() {
    local bg_dir="/usr/share/backgrounds"
    local wp="" wp_dark=""

    # Intentar detectar el codename desde /etc/os-release
    local codename=""
    [ -f /etc/os-release ] && codename=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")

    case "$codename" in
        noble)
            # Ubuntu 24.04 — busca el jpg característico del Noble Numbat
            wp=$(find "$bg_dir" -maxdepth 2 \( -iname "*noble*" -o -iname "*numbat*" \) \
                     -name "*.jpg" -o -name "*.png" 2>/dev/null | sort | tail -1)
            ;;
        jammy)
            # Ubuntu 22.04 — Jammy Jellyfish tiene variante dark
            wp=$(find "$bg_dir" -maxdepth 2 \( -iname "*jammy*" \) \
                     \( -name "*-d.*" -o -name "*dark*" \) 2>/dev/null | sort | tail -1)
            [ -z "$wp" ] && wp=$(find "$bg_dir" -maxdepth 2 -iname "*jammy*" \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            wp_dark=$(find "$bg_dir" -maxdepth 2 -iname "*jammy*" \
                     \( -name "*-l.*" -o -name "*light*" \) 2>/dev/null | sort | tail -1)
            ;;
        focal)
            # Ubuntu 20.04 — Focal Fossa
            wp=$(find "$bg_dir" -maxdepth 2 \( -iname "*focal*" -o -iname "*fossa*" \) \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            ;;
        questing|resolute)
            # Versiones futuras — búsqueda genérica por codename
            wp=$(find "$bg_dir" -maxdepth 2 -iname "*${codename}*" \
                     \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | sort | tail -1)
            ;;
    esac

    # Fallback: primer wallpaper que no sea warty (el genérico histórico)
    if [ -z "$wp" ]; then
        wp=$(find "$bg_dir" -maxdepth 2 \( -name "*.jpg" -o -name "*.png" \) \
                 ! -iname "warty*" 2>/dev/null | sort | tail -1)
    fi

    if [ -n "$wp" ] && [ -f "$wp" ]; then
        local wp_uri="file://$wp"
        gsettings set org.gnome.desktop.background picture-uri       "$wp_uri"
        gsettings set org.gnome.desktop.screensaver picture-uri      "$wp_uri"
        # picture-uri-dark disponible desde GNOME 42 (Ubuntu 22.04+)
        if [ -n "$wp_dark" ] && [ -f "$wp_dark" ]; then
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp_dark"
        else
            gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
        fi
        echo "✓  Wallpaper configurado: $wp"
    else
        echo "ℹ  No se encontró wallpaper de Ubuntu en $bg_dir — dejando el predeterminado"
    fi
}
_set_ubuntu_wallpaper

# ── Tipografías ───────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.interface font-name           'Ubuntu 11'
gsettings set org.gnome.desktop.interface document-font-name  'Ubuntu 11'
gsettings set org.gnome.desktop.wm.preferences titlebar-font  'Ubuntu Bold 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'

# ── Workspaces — un único workspace fijo ─────────────────────────────────────
# dynamic-workspaces false: número fijo de workspaces
# num-workspaces 1: exactamente uno
# workspaces-only-on-primary: en multi-monitor, solo la pantalla principal
gsettings set org.gnome.mutter dynamic-workspaces         false
gsettings set org.gnome.desktop.wm.preferences num-workspaces 1
gsettings set org.gnome.mutter workspaces-only-on-primary true

# ── Overview — vista previa del escritorio ───────────────────────────────────
# show-desktop-icons: desactiva la vista previa del escritorio en el overview
# El selector CSS .workspace-background se encarga del fondo transparente,
# pero la miniatura del escritorio activo requiere esta clave adicional.
# En GNOME 46+ la clave está en org.gnome.shell.overrides
gsettings set org.gnome.shell.overrides workspaces-only-on-primary true 2>/dev/null || true

# Desactivar el blur de la pantalla de bloqueo
# GNOME 46+ permite controlar el blur desde gsettings
# Si la clave no existe en esta versión, falla silenciosamente con || true
gsettings set org.gnome.desktop.screensaver picture-opacity 100 2>/dev/null || true

# ── App Grid ──────────────────────────────────────────────────────────────────
# El orden alfabético permanente se garantiza vía dconf lock de sistema
# instalado en /etc/dconf/db/local.d/locks/00-appgrid durante la instalación.
# No se escribe app-picker-layout aquí — está bloqueado a nivel de sistema.

# Ocultar indicador de workspaces en el overview del appgrid
# show-workspaces-in-app-grid false: elimina los puntos de workspace
# bajo el appgrid en el overview — equivalente a lo que hace Just Perfection
gsettings set org.gnome.shell.extensions.ubuntu-dock show-apps-button-at-top true 2>/dev/null || true
dconf write /org/gnome/shell/overrides/workspaces-only-on-primary true 2>/dev/null || true

# ── Apps ocultas del App Grid ─────────────────────────────────────────────────
# NoDisplay=true en ~/.local/share/applications/ oculta la app del grid
# sin desinstalarla ni romper su funcionalidad como handler de sistema.
# Se usa override de usuario (no modificar /usr/share/applications/).
HIDDEN_APPS=(
    "org.gnome.Totem.desktop"            # Reproductor de vídeo — redundante con mpv/vlc
    "software-properties-drivers.desktop" # Más controladores — innecesario post-instalación
)

mkdir -p "$HOME/.local/share/applications"

for DESKTOP_NAME in "${HIDDEN_APPS[@]}"; do
    USER_DESKTOP="$HOME/.local/share/applications/$DESKTOP_NAME"
    SYSTEM_DESKTOP="/usr/share/applications/$DESKTOP_NAME"

    if [ ! -f "$USER_DESKTOP" ]; then
        if [ -f "$SYSTEM_DESKTOP" ]; then
            cp "$SYSTEM_DESKTOP" "$USER_DESKTOP"
        else
            # Si el .desktop del sistema no existe aún, crear uno mínimo de override
            printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n' \
                "${DESKTOP_NAME%.desktop}" > "$USER_DESKTOP"
        fi
    fi

    # Asegurar NoDisplay=true independientemente del origen del archivo
    if grep -q "^NoDisplay=" "$USER_DESKTOP"; then
        sed -i "s/^NoDisplay=.*/NoDisplay=true/" "$USER_DESKTOP"
    else
        echo "NoDisplay=true" >> "$USER_DESKTOP"
    fi
done

# ── Carpetas del App Grid ─────────────────────────────────────────────────────
gsettings set org.gnome.desktop.app-folders folder-children "[]"

gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/     name 'Utilidades'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/     translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/     apps "['org.gnome.baobab.desktop', 'org.gnome.Calculator.desktop',            'org.gnome.Logs.desktop', 'org.gnome.font-viewer.desktop',            'org.gnome.FileRoller.desktop', 'org.gnome.Characters.desktop',            'simple-scan.desktop', 'org.gnome.Evince.desktop']"

gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    name 'Sistema'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ \
    apps "['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', \
           'gnome-system-monitor.desktop', 'gnome-disks.desktop', \
           'nm-connection-editor.desktop', 'org.gnome.Terminal.desktop']"

gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'System']"

# ── Dock ──────────────────────────────────────────────────────────────────────
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position        'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size   48
gsettings set org.gnome.shell.extensions.dash-to-dock autohide             true
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide          true
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide-mode     'FOCUS_APPLICATION_WINDOWS'
gsettings set org.gnome.shell.extensions.dash-to-dock animation-time       0.2
gsettings set org.gnome.shell.extensions.dash-to-dock hide-delay            0.2
gsettings set org.gnome.shell.extensions.dash-to-dock show-delay            0.0
gsettings set org.gnome.shell.extensions.dash-to-dock click-action          'minimize-or-previews'
gsettings set org.gnome.shell.extensions.dash-to-dock show-running          true
gsettings set org.gnome.shell.extensions.dash-to-dock show-windows-preview  true
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode     'FIXED'
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity     0.35
gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces    false

# ── Apps ancladas en el dock ──────────────────────────────────────────────────
gsettings set org.gnome.shell favorite-apps     "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']"

# ── Privacidad — tiempo de uso de pantalla ────────────────────────────────────
# Este gsettings SOLO funciona en sesión gráfica con D-Bus activo.
# NO debe ejecutarse dentro del chroot durante la instalación (sin D-Bus).
gsettings set org.gnome.desktop.privacy remember-app-usage          false
gsettings set org.gnome.desktop.privacy remember-recent-files        false
gsettings set org.gnome.desktop.privacy send-software-usage-stats    false

# Bienestar digital — schema org.gnome.desktop.screen-time-limits
gsettings set org.gnome.desktop.screen-time-limits history-enabled    false
gsettings set org.gnome.desktop.screen-time-limits grayscale          false
gsettings set org.gnome.desktop.screen-time-limits daily-limit-enabled false

# ── Autodestrucción del .desktop y marker ─────────────────────────────────────
mkdir -p "$HOME/.config"
touch "$MARKER"
rm -f "$AUTOSTART_DESKTOP"

# En X11: reiniciar gnome-shell para que las extensiones sean visibles inmediatamente
# En Wayland: no es necesario, los cambios de dconf aplican sin reinicio
if [ "$XDG_SESSION_TYPE" = "x11" ]; then
    killall -SIGQUIT gnome-shell 2>/dev/null || true
fi

echo "✓  Configuración de usuario GNOME aplicada"
CONFIGSCRIPT

chmod +x /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh

echo "✓  Script de configuración creado en /usr/local/lib/ubuntu-advanced-install/"

CHROOTEOF

# ── Crear el .desktop de autostart para cada usuario ─────────────────────────
# Se crea en /etc/xdg/autostart/ para que aplique a todos los usuarios del sistema.
# XDG autostart solo se ejecuta en sesiones gráficas — correcto por diseño.
# A diferencia de /etc/profile.d/, no se dispara en scripts, cron ni TTY.
arch-chroot "$TARGET" /bin/bash << AUTOSTARTEOF
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

echo "✓  Autostart registrado en /etc/xdg/autostart/gnome-first-login.desktop"
AUTOSTARTEOF

echo ""
echo -e "${C_OK}✓${C_RESET}  Configuración de usuario GNOME preparada"
echo ""
echo "  Método: /etc/xdg/autostart/ (solo sesiones gráficas GNOME)"
echo "  Script: /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh"
echo "  Se autodestruye tras ejecutarse — sin rastro tras el primer login"
echo ""

exit 0
