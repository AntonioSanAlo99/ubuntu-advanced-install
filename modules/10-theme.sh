#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 10-theme.sh
# DESCRIPCIÓN: Tema GNOME con transparencias y configuración visual completa
# DEPENDENCIAS: 10-install-gnome-core.sh (usuario y GNOME instalados)
# VARIABLES REQUERIDAS: TARGET, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# CAMBIOS vs versión anterior:
#   - Corregido bug de sintaxis CSS: bloques sin cierre de llave
#   - CSS expandido: panel, quicksettings, calendario, notificaciones,
#     appgrid, carpetas — todos con transparencia rgba(0,0,0,X)
#   - Eliminada la pregunta de opt-in: el tema es parte del CORE visual
#   - Extensión user-theme sigue siendo necesaria para aplicar CSS de shell
#   - Permisos corregidos al final del bloque
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

# Colores para output
C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  TEMA VISUAL GNOME — TRANSPARENCIAS Y CONFIGURACIÓN${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Aplicando tema con transparencias sobre fondo oscuro"
echo -e "${C_INFO}ℹ${C_RESET}  Elementos: panel, quicksettings, calendario, appgrid, carpetas"
echo ""

# Instalar extensión user-theme dentro del chroot (necesaria para CSS de shell)
# Heredoc sin comillas: no necesita variables del host aquí
arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gnome-shell-extension-user-theme 2>/dev/null
echo "✓  gnome-shell-extension-user-theme instalado"
EOF

# Crear el tema CSS en el home del usuario
# Heredoc sin comillas: necesita $USERNAME y $TARGET del host — expansión requerida
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

# ── CSS del tema ──────────────────────────────────────────────────────────────
# Importa el tema base de GNOME y sobreescribe solo lo necesario.
# Opacidades elegidas para mantener texto blanco legible:
#   Panel superior:       0.40  (siempre visible, necesita más opacidad)
#   Quick Settings:       0.55  (panel de controles, texto denso)
#   Calendario/notif.:    0.50  (contenido mixto)
#   App Grid fondo:       0.35  (de fondo, iconos dan el contraste)
#   Carpetas App Grid:    0.45  (elemento flotante sobre el grid)
# ──────────────────────────────────────────────────────────────────────────────
cat > "\$USER_HOME/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css" << 'CSSEOF'
/* ══════════════════════════════════════════════════════════════════════════════
   Adwaita-Transparent — Tema de shell para ubuntu-advanced-install
   Base: Adwaita vanilla + transparencias sobre fondo oscuro
   GNOME 46+ / Ubuntu 24.04 Yaru
   Opacidad de referencia: panel = 0.40 — quick settings iguala al panel
   ══════════════════════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* ══════════════════════════════════════════════════════════════════════════════
   PANEL SUPERIOR
   Solo el fondo — sin tocar los elementos interiores (reloj, indicadores)
   para no crear fondos extra detrás del texto.
   ══════════════════════════════════════════════════════════════════════════════ */

#panel {
    background-color: rgba(0, 0, 0, 0.40) !important;
}

/* Asegurar que los botones del panel no añaden fondo propio */
#panel .panel-button {
    background-color: transparent !important;
}

#panel .panel-button:hover {
    background-color: rgba(255, 255, 255, 0.10) !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   QUICK SETTINGS
   Misma opacidad que el panel (0.40) para coherencia visual.
   Los botones de sistema mantienen su forma y estilo original — solo
   se elimina el rectángulo de fondo del contenedor superior.
   ══════════════════════════════════════════════════════════════════════════════ */

.quick-settings-box,
.quick-settings {
    background-color: rgba(0, 0, 0, 0.40) !important;
    border-radius: 12px;
    box-shadow: none !important;
}

/* Fila superior de botones (captura, ajustes, bloqueo, apagar) —
   transparent para que no añada un rectángulo extra sobre el fondo */
.quick-settings-system-item {
    background-color: transparent !important;
    box-shadow: none !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   CALENDARIO Y NOTIFICACIONES
   ══════════════════════════════════════════════════════════════════════════════ */

.datemenu-today-button {
    background-color: rgba(0, 0, 0, 0.40) !important;
    border-radius: 10px;
}

.calendar-today {
    background-color: rgba(255, 255, 255, 0.15) !important;
    border-radius: 50%;
}

.message-list {
    background-color: rgba(0, 0, 0, 0.40) !important;
}

/* Cada notificación individual con border-radius */
.message-list .message {
    background-color: rgba(255, 255, 255, 0.06) !important;
    border-radius: 12px;
    margin: 4px 0;
    padding: 2px;
}

.notification-banner {
    background-color: rgba(0, 0, 0, 0.50) !important;
    border-radius: 12px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4) !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   APP GRID — OVERVIEW DE APLICACIONES
   El fondo del overview debe ser completamente transparente.
   Los workspaces horizontales (puntos de paginación) se ocultan con
   height:0 porque no tienen selector de visibilidad directo en GNOME 46.
   ══════════════════════════════════════════════════════════════════════════════ */

.overview-controls,
#overview,
.overview {
    background-color: transparent !important;
}

.app-grid,
.apps-grid-container,
.apps-scroll-view {
    background-color: transparent !important;
}

/* Ocultar indicador de workspaces horizontales (puntos de paginación)
   que aparece bajo el appgrid en el overview */
.page-indicators,
.page-indicator {
    opacity: 0 !important;
    height: 0 !important;
    margin: 0 !important;
    padding: 0 !important;
}

/* Vista previa del escritorio activo — transparente e invisible */
.workspace-thumbnails-box,
.workspace-thumbnail-indicator,
.workspace-thumbnail,
.workspace-overview,
.window-picker,
.workspace-background {
    background-color: transparent !important;
    border: none !important;
    box-shadow: none !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   CARPETAS DEL APP GRID
   Color más claro que el fondo del overview para distinguirlas visualmente
   manteniendo coherencia con el tema transparente.
   ══════════════════════════════════════════════════════════════════════════════ */

/* Diálogo expandido al abrir una carpeta */
.app-folder-dialog {
    background-color: rgba(255, 255, 255, 0.12) !important;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.10) !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.3) !important;
}

.app-folder-dialog-container {
    background-color: transparent !important;
}

.app-folder-dialog .page-indicator,
.app-folder-dialog .app-folder-dialog-title {
    background-color: transparent !important;
    color: rgba(255, 255, 255, 0.95) !important;
}

/* Popup pequeño antes de expandirse */
.app-folder-popup {
    background-color: rgba(255, 255, 255, 0.12) !important;
    border-radius: 16px;
    border: 1px solid rgba(255, 255, 255, 0.10) !important;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3) !important;
}

.app-folder-popup-title,
.app-folder-dialog-title {
    color: rgba(255, 255, 255, 0.90) !important;
}

.app-folder .app-well-grid {
    background-color: transparent !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   PANTALLA DE BLOQUEO
   #lockDialogGroup controla el fondo de la pantalla de bloqueo.
   transparent permite ver el wallpaper sin blur.
   ══════════════════════════════════════════════════════════════════════════════ */

#lockDialogGroup {
    background-color: transparent !important;
    background-image: none !important;
}

.unlock-dialog {
    background-color: rgba(0, 0, 0, 0.45) !important;
    border-radius: 16px;
}

.unlock-dialog-clock {
    color: rgba(255, 255, 255, 0.95) !important;
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
for candidate in     /usr/share/gnome-shell/theme/Yaru/gnome-shell-light.css     /usr/share/gnome-shell/theme/Yaru/gnome-shell.css     /usr/share/gnome-shell/theme/ubuntu/gnome-shell.css     /usr/share/gnome-shell/theme/gnome-shell.css; do
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
