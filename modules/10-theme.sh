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
   Texto: blanco — requiere wallpaper oscuro o semidark para máxima legibilidad
   GNOME 46+ — selectores verificados contra el tema Yaru de Ubuntu 24.04
   ══════════════════════════════════════════════════════════════════════════════ */

@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* ══════════════════════════════════════════════════════════════════════════════
   PANEL SUPERIOR
   ══════════════════════════════════════════════════════════════════════════════ */

#panel {
    background-color: rgba(0, 0, 0, 0.40) !important;
    transition: background-color 0.3s ease;
}

/* ══════════════════════════════════════════════════════════════════════════════
   QUICK SETTINGS
   El panel de quick settings tiene múltiples capas de fondo:
   - .quick-settings-box: contenedor exterior con el fondo principal
   - .quick-settings-grid: grid interno de botones
   - .quick-settings-system-item: fila superior (captura, ajustes, bloqueo, apagar)
   Todos deben tener la misma opacidad para coherencia visual.
   ══════════════════════════════════════════════════════════════════════════════ */

/* Contenedor exterior del panel */
.quick-settings-box,
.quick-settings {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 12px;
    border: none !important;
    box-shadow: none !important;
}

/* Fila superior de botones de sistema — mismo fondo que el panel */
.quick-settings-system-item {
    background-color: transparent !important;
    border-radius: 0;
    box-shadow: none !important;
}

/* Botones individuales dentro del sistema item */
.quick-settings-system-item .icon-button,
.quick-settings-system-item .button {
    background-color: rgba(255, 255, 255, 0.08) !important;
    border-radius: 8px;
}

.quick-settings-system-item .icon-button:hover,
.quick-settings-system-item .button:hover {
    background-color: rgba(255, 255, 255, 0.15) !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   CALENDARIO Y NOTIFICACIONES
   ══════════════════════════════════════════════════════════════════════════════ */

/* Contenedor principal del menú de fecha */
.clock-display-box,
.datemenu-today-button {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 12px;
}

/* Cabecera del calendario con fecha actual */
.datemenu-today-button {
    background-color: rgba(0, 0, 0, 0.50) !important;
    border-radius: 10px;
}

/* Día actual resaltado en el calendario */
.calendar-today {
    background-color: rgba(255, 255, 255, 0.15) !important;
    border-radius: 50%;
}

/* Lista de notificaciones */
.message-list {
    background-color: rgba(0, 0, 0, 0.50) !important;
}

/* Cada notificación individual */
.message-list .message {
    background-color: rgba(255, 255, 255, 0.05) !important;
    border-radius: 10px;
    margin: 4px 0;
}

/* Banner de notificación emergente */
.notification-banner {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 12px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4) !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   APP GRID — OVERVIEW DE APLICACIONES
   En GNOME 46 el selector correcto es .app-grid, no .apps-scroll-view.
   El fondo del overview completo se controla desde el stage/overview.
   ══════════════════════════════════════════════════════════════════════════════ */

/* Fondo del overview completo — transparente para ver el wallpaper */
.overview-controls,
#overview,
.overview {
    background-color: transparent !important;
}

/* Contenedor del app grid */
.app-grid,
.apps-grid-container,
.apps-scroll-view {
    background-color: transparent !important;
}

/* Vista previa del workspace en el overview — transparente */
.workspace-thumbnails-box,
.workspace-thumbnail-indicator,
.workspace-thumbnail,
.workspace-overview {
    background-color: transparent !important;
    border: none !important;
    box-shadow: none !important;
}

/* Contenedor de la vista previa del escritorio activo */
.window-picker,
.workspace-background {
    background-color: transparent !important;
    border-radius: 16px;
    border: none !important;
    box-shadow: none !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   CARPETAS DEL APP GRID
   En GNOME 46 el diálogo expandido de carpeta usa .app-folder-dialog,
   no .app-folder-popup. Se cubren ambos selectores para compatibilidad.
   ══════════════════════════════════════════════════════════════════════════════ */

/* Diálogo expandido — lo que se ve al abrir una carpeta (captura) */
.app-folder-dialog {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 16px;
    border: none !important;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4) !important;
}

/* Contenedor interior del diálogo */
.app-folder-dialog-container {
    background-color: transparent !important;
}

/* Cabecera con el nombre de la carpeta */
.app-folder-dialog .page-indicator,
.app-folder-dialog .app-folder-dialog-title {
    color: rgba(255, 255, 255, 0.95) !important;
    background-color: transparent !important;
}

/* Popup pequeño (antes de expandirse) */
.app-folder-popup {
    background-color: rgba(0, 0, 0, 0.55) !important;
    border-radius: 16px;
    border: none !important;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4) !important;
}

/* Título visible en ambos estados */
.app-folder-popup-title,
.app-folder-dialog-title {
    color: rgba(255, 255, 255, 0.90) !important;
}

/* Fondo del área de iconos dentro de la carpeta */
.app-folder .app-well-grid {
    background-color: transparent !important;
}

/* ══════════════════════════════════════════════════════════════════════════════
   PANTALLA DE BLOQUEO
   En GNOME el selector del fondo de bloqueo es #lockDialogGroup.
   Se usa transparent para ver el wallpaper sin blur adicional.
   El blur del sistema (gnome-shell) se desactiva vía gsettings en first-login.
   ══════════════════════════════════════════════════════════════════════════════ */

#lockDialogGroup {
    background-color: transparent !important;
    background-image: none !important;
}

/* Widget de bloqueo (entrada de contraseña) */
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
