#!/bin/bash
# Módulo 10c: Crear tema personalizado con transparencias basado en Adwaita

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  CREACIÓN DE TEMA ADWAITA-TRANSPARENT"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# ============================================================================
# CREAR TEMA PERSONALIZADO BASADO EN ADWAITA
# ============================================================================

echo "Creando tema Adwaita-Transparent..."

# Directorio del nuevo tema
THEME_DIR="/usr/share/gnome-shell/themes/Adwaita-Transparent"
mkdir -p "$THEME_DIR"

# Crear gnome-shell.css completo con transparencias
cat > "$THEME_DIR/gnome-shell.css" << 'CSS_EOF'
/* ============================================================================
   ADWAITA TRANSPARENT
   Tema basado en Adwaita con transparencias del 15%
   ============================================================================ */

/* ============================================================================
   COLORES BASE (Adwaita palette)
   ============================================================================ */
stage {
    font-family: Cantarell, Sans-Serif;
    font-size: 11pt;
    color: #eeeeec;
}

/* ============================================================================
   PANEL SUPERIOR
   ============================================================================ */
#panel {
    background-color: rgba(0, 0, 0, 0.15);
    font-weight: bold;
    height: 1.86em;
    padding: 0 8px;
}

.panel-corner {
    -panel-corner-radius: 0;
    -panel-corner-background-color: rgba(0, 0, 0, 0.15);
}

.panel-button {
    -natural-hpadding: 12px;
    -minimum-hpadding: 6px;
    font-weight: bold;
    color: #eeeeec;
    transition-duration: 100ms;
}

.panel-button:hover {
    background-color: rgba(238, 238, 236, 0.15);
    color: #eeeeec;
}

.panel-button:active,
.panel-button:overview,
.panel-button:focus,
.panel-button:checked {
    background-color: rgba(238, 238, 236, 0.25);
    color: #eeeeec;
}

.panel-status-menu-box {
    spacing: 6px;
}

/* ============================================================================
   OVERVIEW (Vista general)
   ============================================================================ */
.overview-background {
    background-color: rgba(0, 0, 0, 0.15);
}

/* ============================================================================
   DASH (Barra de aplicaciones)
   ============================================================================ */
#dash {
    background-color: rgba(0, 0, 0, 0.15);
    padding: 4px;
    border-radius: 9px;
}

.dash-background {
    background-color: rgba(0, 0, 0, 0.15);
    border-radius: 9px;
}

.dash-item-container > StButton {
    padding: 4px 8px;
}

/* ============================================================================
   APP GRID
   ============================================================================ */
.app-grid {
    background-color: rgba(0, 0, 0, 0.15);
}

.icon-grid {
    spacing: 30px;
    -shell-grid-horizontal-item-size: 118px;
    -shell-grid-vertical-item-size: 106px;
}

.app-well-app {
    background-color: transparent;
}

.app-well-app:hover {
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 9px;
}

/* ============================================================================
   BÚSQUEDA
   ============================================================================ */
.search-entry {
    width: 320px;
    padding: 9px;
    border-radius: 18px;
    color: rgba(0, 0, 0, 0.9);
    background-color: rgba(255, 255, 255, 0.9);
    border: 2px solid transparent;
}

.search-entry:focus {
    background-color: white;
    border: 2px solid #3584e4;
}

/* ============================================================================
   POPUP MENUS
   ============================================================================ */
.popup-menu {
    min-width: 200px;
    background-color: rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 9px;
    padding: 8px 0;
}

.popup-menu-content {
    padding: 8px 0;
}

.popup-menu-item {
    spacing: 12px;
    padding: 6px;
}

.popup-menu-item:hover,
.popup-menu-item:focus {
    background-color: rgba(255, 255, 255, 0.1);
}

.popup-menu-item:active {
    background-color: rgba(255, 255, 255, 0.15);
}

/* ============================================================================
   CALENDARIO Y NOTIFICACIONES
   ============================================================================ */
.calendar {
    background-color: rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 9px;
    padding: 8px;
}

.calendar-month-label {
    color: #eeeeec;
    font-weight: bold;
    padding: 8px 0;
}

.calendar-day-base {
    font-size: 9pt;
    text-align: center;
    width: 2.4em;
    height: 2.4em;
    padding: 0.1em;
    margin: 2px;
    border-radius: 1.4em;
}

.calendar-day-base:hover,
.calendar-day-base:focus {
    background-color: rgba(255, 255, 255, 0.1);
}

.calendar-day-base:active,
.calendar-day-base:selected {
    background-color: #3584e4;
    color: white;
}

.message-list {
    background-color: rgba(0, 0, 0, 0.15);
    border-radius: 9px;
    padding: 8px;
}

.message-list-section-list {
    spacing: 4px;
}

.message {
    background-color: rgba(255, 255, 255, 0.05);
    border-radius: 9px;
    padding: 8px;
}

.message:hover {
    background-color: rgba(255, 255, 255, 0.1);
}

/* ============================================================================
   QUICK SETTINGS
   ============================================================================ */
.quick-settings {
    background-color: rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 18px;
    padding: 12px;
    spacing: 12px;
}

.quick-settings-grid {
    spacing: 6px;
}

.quick-toggle {
    border-radius: 12px;
    padding: 6px 12px;
    background-color: rgba(255, 255, 255, 0.1);
}

.quick-toggle:hover {
    background-color: rgba(255, 255, 255, 0.15);
}

.quick-toggle:checked {
    background-color: #3584e4;
    color: white;
}

.quick-menu-toggle {
    border-radius: 12px;
    padding: 0;
}

.quick-menu-toggle:hover {
    background-color: rgba(255, 255, 255, 0.15);
}

/* ============================================================================
   WORKSPACES
   ============================================================================ */
.workspace-background {
    background-color: rgba(0, 0, 0, 0.15);
    border-radius: 18px;
}

.workspace-thumbnails {
    visible-width: 48px;
    spacing: 12px;
    padding: 12px;
    border-radius: 12px;
    background-color: rgba(0, 0, 0, 0.15);
}

.workspace-thumbnail {
    border: 2px solid transparent;
    border-radius: 3px;
}

.workspace-thumbnail:hover {
    border: 2px solid rgba(255, 255, 255, 0.3);
}

/* ============================================================================
   MODAL DIALOGS
   ============================================================================ */
.modal-dialog {
    background-color: rgba(0, 0, 0, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 18px;
    padding: 24px;
}

.modal-dialog-content-box {
    spacing: 24px;
}

/* ============================================================================
   BOTONES
   ============================================================================ */
.button {
    border-radius: 6px;
    padding: 6px 24px;
    font-weight: bold;
    border: none;
    background-color: rgba(255, 255, 255, 0.1);
    color: #eeeeec;
}

.button:hover {
    background-color: rgba(255, 255, 255, 0.15);
}

.button:active {
    background-color: rgba(255, 255, 255, 0.2);
}

.button:focus {
    border: 2px solid #3584e4;
}

/* ============================================================================
   SYSTEM MENU
   ============================================================================ */
.aggregate-menu {
    width: 360px;
}

.system-menu-action {
    padding: 12px;
    border-radius: 32px;
    background-color: rgba(255, 255, 255, 0.05);
}

.system-menu-action:hover,
.system-menu-action:focus {
    background-color: rgba(255, 255, 255, 0.1);
}

.system-menu-action:active {
    background-color: rgba(255, 255, 255, 0.15);
}
CSS_EOF

echo "✓ Tema Adwaita-Transparent creado"

# Crear archivo de metadata del tema
cat > "$THEME_DIR/gnome-shell-theme.gresource.xml" << 'XML_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<gresources>
  <gresource prefix="/org/gnome/shell/theme">
    <file>gnome-shell.css</file>
  </gresource>
</gresources>
XML_EOF

# ============================================================================
# HACER EL TEMA PREDETERMINADO
# ============================================================================

# Crear symlink para que sea el tema predeterminado
ln -sf "$THEME_DIR/gnome-shell.css" /usr/share/gnome-shell/theme/gnome-shell.css

echo "✓ Tema configurado como predeterminado"

# ============================================================================
# CONFIGURAR UBUNTU DOCK
# ============================================================================

cat > /etc/profile.d/03-gnome-transparency.sh << 'TRANSPARENCY_EOF'
#!/bin/bash
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-transparency-applied"
    
    if [ ! -f "$MARKER" ]; then
        if gnome-extensions list 2>/dev/null | grep -q "ubuntu-dock"; then
            gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock customize-alphas true 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock min-alpha 0.15 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock max-alpha 0.15 2>/dev/null
        fi
        
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            nohup sh -c 'sleep 3 && killall -SIGQUIT gnome-shell' >/dev/null 2>&1 &
        fi
    fi
fi
TRANSPARENCY_EOF

chmod +x /etc/profile.d/03-gnome-transparency.sh

echo "✓ Configuración de transparencias creada"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ TEMA ADWAITA-TRANSPARENT CREADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Tema: Adwaita-Transparent (basado en Adwaita)"
echo "Ubicación: /usr/share/gnome-shell/themes/Adwaita-Transparent/"
echo ""
echo "Transparencias aplicadas (15%):"
echo "  • Panel superior"
echo "  • App Grid"
echo "  • Calendario y notificaciones"
echo "  • Quick Settings"
echo "  • Workspaces"
echo "  • Ubuntu Dock"
echo "  • Todos los menús y popups"
echo ""
echo "Se aplicará automáticamente al iniciar sesión."
echo ""

exit 0
