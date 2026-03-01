#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-theme.sh
# DESCRIPCIÓN: Tema GNOME con transparencias — Adwaita-Transparent
# DEPENDENCIAS: 10-install-gnome-core.sh (usuario y GNOME instalados)
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# CSS de referencia: gnome-shell.css (Adwaita vanilla + transparencias rgba(36,36,36,X))
# GDM: override en /usr/share/gnome-shell/extensions/gdm-transparency/
# Activación: extensión user-theme + gnome-first-login (módulo 10-user-config)
#
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  TEMA VISUAL GNOME — ADWAITA-TRANSPARENT${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Base: Adwaita vanilla + transparencias sobre fondo oscuro"
echo -e "${C_INFO}ℹ${C_RESET}  Elementos: panel, quick settings, calendario, notificaciones, dock, carpetas"
echo ""

# ── Instalar extensión user-theme ─────────────────────────────────────────────
# Necesaria para que GNOME cargue CSS de ~/.themes/ en lugar del tema del sistema
arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gnome-shell-extension-user-theme 2>/dev/null
echo "✓  gnome-shell-extension-user-theme instalado"
EOF

# ── Crear estructura del tema y CSS ───────────────────────────────────────────
# Heredoc sin comillas simples: necesita $USERNAME del host
arch-chroot "$TARGET" /bin/bash << CHROOTEOF

if [ -z "$USERNAME" ]; then
    echo "⚠  Variable USERNAME no definida — abortando módulo de tema"
    exit 1
fi

USER_HOME="/home/$USERNAME"

if [ ! -d "\$USER_HOME" ]; then
    echo "⚠  Directorio home no existe: \$USER_HOME"
    exit 1
fi

mkdir -p "\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell"

# ── gnome-shell.css ───────────────────────────────────────────────────────────
# Copia fiel del archivo de diseño de referencia.
# Importa el CSS base de GNOME y sobreescribe únicamente los selectores
# necesarios — el resto hereda de Adwaita sin modificación.
# ──────────────────────────────────────────────────────────────────────────────
cat > "\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css" << 'CSSEOF'
/* ══════════════════════════════════════════════════════════════════════════════
   Adwaita-Transparent — Tema de shell para ubuntu-advanced-install
   Base: Adwaita vanilla + transparencias sobre fondo oscuro
   GNOME 46–50 / Ubuntu 24.04+
   ══════════════════════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* Contenedor exterior de popovers del panel */
.popup-menu-content {
    background: rgba(36, 36, 36, 0.88) !important;
    border: none !important;
    box-shadow: none !important;
}


/* ══════════════════════════════════════════════════════════════════════════════
   PANEL SUPERIOR
   ══════════════════════════════════════════════════════════════════════════════ */

#panel {
    background-color: transparent !important;
    border: none !important;
    box-shadow: none !important;
}

#panel .panel-button {
    background-color: transparent;
}

.clock-display {
    background-color: transparent;
    box-shadow: none;
    border: none;
}


/* ══════════════════════════════════════════════════════════════════════════════
   QUICK SETTINGS
   ══════════════════════════════════════════════════════════════════════════════ */

.quick-settings-box,
.quick-settings {
    background-color: rgba(36, 36, 36, 0.88);
    border-radius: 24px;
    border: none;
    box-shadow: none;
}

.quick-settings-system-item {
    background-color: transparent;
    box-shadow: none;
}

.quick-toggle-menu {
    background-color: rgba(36, 36, 36, 0.88) !important;
    box-shadow: none !important;
}


/* ══════════════════════════════════════════════════════════════════════════════
   CALENDARIO Y MENÚ DE FECHA/HORA
   ══════════════════════════════════════════════════════════════════════════════ */

#calendarArea {
    padding: 0;
}

.datemenu-popover {
    padding: 8px;
}

.datemenu-today-button {
    background-color: transparent;
    border-radius: 12px;
}

.datemenu-today-button:hover {
    background-color: rgba(255, 255, 255, 0.06);
    box-shadow: none;
}

/* ── Calendario ─────────────────────────────────────────────────────────────── */

.calendar {
    background-color: rgba(36, 36, 36, 0.88) !important;
    border-radius: 14px !important;
    border-color: transparent !important;
    box-shadow: none !important;
    padding: 3px !important;
    margin: 0 !important;
}

.calendar-month-header {
    padding: 2px;
}

.calendar-month-header .calendar-month-label {
    background-color: transparent;
    color: white;
}

.calendar-day.calendar-day-heading,
.calendar .calendar-day-heading {
    background-color: transparent;
    color: white;
    border-radius: 8px;
}

.calendar-day,
.calendar-month-header .pager-button {
    background-color: transparent;
    color: white;
    border-radius: 9px;
    transition-duration: 100ms;
}

.calendar-day:hover,
.calendar .calendar-day-heading:hover,
.calendar .calendar-month-header .pager-button:hover {
    background-color: rgba(255, 255, 255, 0.08);
    box-shadow: none;
}

.calendar-today,
.calendar-today:selected {
    background-color: rgba(255, 255, 255, 0.20);
    color: white;
    font-weight: bold;
    box-shadow: none;
}

.calendar-today:hover,
.calendar-today:selected:hover {
    background-color: rgba(255, 255, 255, 0.28);
}

.calendar .calendar-nonwork-day,
.calendar-weekend {
    color: rgba(255, 255, 255, 0.60);
}

.calendar .calendar-other-month-day,
.calendar-other-month {
    color: rgba(255, 255, 255, 0.28);
}

.calendar .calendar-week-number {
    background-color: rgba(255, 255, 255, 0.06);
    color: rgba(255, 255, 255, 0.45);
    box-shadow: none;
    border-radius: 7px;
}

/* ── Widgets bajo el calendario ─────────────────────────────────────────────── */

.events-button,
.world-clocks-button,
.weather-button {
    background-color: rgba(36, 36, 36, 0.88) !important;
    color: white !important;
    border-radius: 14px !important;
    border-color: transparent !important;
    box-shadow: none !important;
}

.events-button:hover,
.world-clocks-button:hover,
.weather-button:hover {
    background-color: rgba(255, 255, 255, 0.06);
}

.weather-button .weather-header,
.events-button .events-title,
.world-clocks-button .world-clocks-header {
    color: rgba(255, 255, 255, 0.55);
}


/* ══════════════════════════════════════════════════════════════════════════════
   NOTIFICACIONES
   ══════════════════════════════════════════════════════════════════════════════ */

.message-list {
    border-color: transparent;
    padding: 0;
}

.message-list-placeholder {
    color: rgba(255, 255, 255, 0.38);
    font-weight: 700;
}

.message-list .message,
.message-view .message {
    background-color: rgba(36, 36, 36, 0.88) !important;
    box-shadow: none !important;
    border-radius: 13px !important;
    transition-duration: 100ms;
}

.message-list .message:hover {
    background-color: rgba(255, 255, 255, 0.06);
}

.message .message-body,
.message-title {
    color: white;
}

.message .message-secondary-bin > .event-time,
.message .message-header .message-source-icon,
.message .message-header .message-header-content .message-source-title,
.message .message-header .message-header-content .event-time {
    color: rgba(255, 255, 255, 0.55);
}

.message-close-button,
.message-expand-button,
.message-collapse-button {
    color: white;
    background-color: rgba(255, 255, 255, 0.08);
    box-shadow: none;
    border-radius: 99px;
}

.message-close-button:hover,
.message-expand-button:hover,
.message-collapse-button:hover {
    background-color: rgba(255, 255, 255, 0.14);
}

.notification-banner {
    background-color: rgba(36, 36, 36, 0.88) !important;
    color: white !important;
    border: none !important;
    box-shadow: 0 2px 8px rgba(36, 36, 36, 0.63) !important;
    border-radius: 16px !important;
}

.message:second-in-stack {
    background-color: rgba(36, 36, 36, 0.78);
}

.message:lower-in-stack {
    background-color: rgba(36, 36, 36, 0.68);
}


/* ══════════════════════════════════════════════════════════════════════════════
   DASH-TO-DOCK
   ══════════════════════════════════════════════════════════════════════════════ */

.dash-background {
    background-color: rgba(37, 37, 37, 0.4);
    border-radius: 18px;
}


/* ══════════════════════════════════════════════════════════════════════════════
   APP FOLDERS
   ══════════════════════════════════════════════════════════════════════════════ */

.app-folder-popup {
    background-color: rgba(36, 36, 36, 0.88);
    border-radius: 14px;
    border: none;
    box-shadow: none;
}
CSSEOF

# Permisos correctos
chown -R "$USERNAME":"$USERNAME" "\$USER_HOME/.themes"
chmod -R u=rwX,go=rX "\$USER_HOME/.themes"

echo "✓  Tema CSS creado en \$USER_HOME/.themes/Adwaita-Transparent/"
CHROOTEOF

echo ""
echo -e "${C_OK}✓${C_RESET}  Tema CSS creado: /home/${USERNAME}/.themes/Adwaita-Transparent/"

# ── CSS para GDM (pantalla de login) ─────────────────────────────────────────
# GDM usa su propio proceso gnome-shell con tema en /usr/share/gnome-shell/theme/
# El CSS de usuario (~/.themes/) no aplica en GDM.
# La forma correcta es crear un tema alternativo en /usr/share/gnome-shell/theme/
# o sobreescribir el CSS de gdm3 con un archivo de override.
# Usamos el mecanismo oficial: /etc/alternatives/gdm3.css
# Si no existe el symlink, escribimos directamente en el CSS de GDM de Ubuntu.
arch-chroot "$TARGET" /bin/bash << 'GDM_EOF'

# Localizar el CSS de GDM en Ubuntu 24.04
# Ubuntu usa Yaru como tema de GDM — el CSS está en gnome-shell-common
GDM_CSS=""
for candidate in \
    /usr/share/gnome-shell/theme/Yaru/gnome-shell-light.css \
    /usr/share/gnome-shell/theme/Yaru/gnome-shell.css \
    /usr/share/gnome-shell/theme/ubuntu/gnome-shell.css \
    /usr/share/gnome-shell/theme/gnome-shell.css; do
    if [ -f "$candidate" ]; then
        GDM_CSS="$candidate"
        break
    fi
done

if [ -z "$GDM_CSS" ]; then
    echo "⚠  No se encontró el CSS de GDM — pantalla de login sin transparencia"
else
    # Crear un override en lugar de modificar el CSS original
    # gdm3 permite cargar CSS adicional desde /usr/share/gdm/greeter.dconf-defaults
    # pero el método más fiable es el directorio de extensiones de gdm
    GDM_OVERRIDE_DIR="/usr/share/gnome-shell/extensions/gdm-transparency"
    mkdir -p "$GDM_OVERRIDE_DIR"

    # Crear un CSS de override para GDM
    # #lockDialogGroup es el selector del fondo en GDM y en la pantalla de bloqueo
    cat > "$GDM_OVERRIDE_DIR/stylesheet.css" << 'GDM_CSS_EOF'
/* GDM — override de transparencia para ubuntu-advanced-install */

#lockDialogGroup {
    background-color: rgba(0, 0, 0, 0.55) !important;
    background-image: none !important;
}

.login-dialog {
    background-color: rgba(0, 0, 0, 0.40) !important;
    border-radius: 16px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.5) !important;
}

.login-dialog-prompt-layout {
    background-color: transparent !important;
}
GDM_CSS_EOF

    # Registrar la extensión de GDM
    cat > "$GDM_OVERRIDE_DIR/metadata.json" << 'GDM_META_EOF'
{
    "description": "Transparencia en pantalla de login GDM",
    "name": "GDM Transparency",
    "shell-version": ["46", "47", "48"],
    "uuid": "gdm-transparency",
    "version": 1
}
GDM_META_EOF

    echo "✓  CSS de GDM creado en $GDM_OVERRIDE_DIR"
    echo "  El fondo de login tendrá transparencia semidark"
fi
GDM_EOF

echo -e "${C_INFO}ℹ${C_RESET}  Se aplicará en el primer login del usuario"
echo -e "${C_INFO}ℹ${C_RESET}  Requiere wallpaper oscuro para máxima legibilidad del texto"
echo ""

exit 0
