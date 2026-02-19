#!/bin/bash
# Módulo 10c: Crear tema personalizado con transparencias + User Themes

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  INSTALACIÓN DE TEMA ADWAITA-TRANSPARENT"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# ============================================================================
# INSTALAR EXTENSIÓN USER THEMES
# ============================================================================

echo "Instalando extensión User Themes..."

# User Themes está disponible en los repositorios de Ubuntu
apt-get install -y gnome-shell-extension-user-theme

echo "✓ User Themes instalado"

# ============================================================================
# CREAR TEMA ADWAITA-TRANSPARENT EN /etc/skel
# ============================================================================

echo "Creando tema Adwaita-Transparent..."

# Crear estructura de directorios para el tema
THEME_DIR="/etc/skel/.themes/Adwaita-Transparent/gnome-shell"
mkdir -p "$THEME_DIR"

# Crear gnome-shell.css con transparencias
cat > "$THEME_DIR/gnome-shell.css" << 'CSS_EOF'
/* ============================================================================
   ADWAITA TRANSPARENT
   Tema basado en Adwaita con transparencias del 15%
   ============================================================================ */

/* Importar tema base de Adwaita */
@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* ============================================================================
   PANEL SUPERIOR
   ============================================================================ */
#panel {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.panel-corner {
    -panel-corner-background-color: rgba(0, 0, 0, 0.15) !important;
}

.panel-button:hover {
    background-color: rgba(238, 238, 236, 0.15) !important;
}

.panel-button:active,
.panel-button:overview,
.panel-button:focus,
.panel-button:checked {
    background-color: rgba(238, 238, 236, 0.25) !important;
}

/* ============================================================================
   OVERVIEW
   ============================================================================ */
.overview-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* ============================================================================
   DASH
   ============================================================================ */
#dash {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.dash-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* ============================================================================
   APP GRID
   ============================================================================ */
.app-grid {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.app-well-app:hover {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

/* ============================================================================
   POPUP MENUS
   ============================================================================ */
.popup-menu {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.popup-menu-item:hover,
.popup-menu-item:focus {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

/* ============================================================================
   CALENDARIO Y NOTIFICACIONES
   ============================================================================ */
.calendar {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.message-list {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.message {
    background-color: rgba(255, 255, 255, 0.05) !important;
}

.message:hover {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

/* ============================================================================
   QUICK SETTINGS
   ============================================================================ */
.quick-settings {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.quick-toggle {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

.quick-toggle:hover {
    background-color: rgba(255, 255, 255, 0.15) !important;
}

.quick-toggle:checked {
    background-color: #3584e4 !important;
}

/* ============================================================================
   WORKSPACES
   ============================================================================ */
.workspace-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.workspace-thumbnails {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* ============================================================================
   MODAL DIALOGS
   ============================================================================ */
.modal-dialog {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* ============================================================================
   BOTONES
   ============================================================================ */
.button {
    background-color: rgba(255, 255, 255, 0.1) !important;
}

.button:hover {
    background-color: rgba(255, 255, 255, 0.15) !important;
}

.button:active {
    background-color: rgba(255, 255, 255, 0.2) !important;
}

/* ============================================================================
   SYSTEM MENU
   ============================================================================ */
.system-menu-action {
    background-color: rgba(255, 255, 255, 0.05) !important;
}

.system-menu-action:hover,
.system-menu-action:focus {
    background-color: rgba(255, 255, 255, 0.1) !important;
}
CSS_EOF

echo "✓ Tema Adwaita-Transparent creado en /etc/skel/.themes/"

# ============================================================================
# SCRIPT DE ACTIVACIÓN EN PRIMER LOGIN
# ============================================================================

cat > /etc/profile.d/03-gnome-transparency.sh << 'TRANSPARENCY_EOF'
#!/bin/bash
# Activar tema Adwaita-Transparent y configurar transparencias

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-transparency-applied"
    
    if [ ! -f "$MARKER" ]; then
        # Esperar a que GNOME Shell esté listo
        sleep 2
        
        # =====================================================================
        # ACTIVAR EXTENSIÓN USER THEMES
        # =====================================================================
        if gnome-extensions list 2>/dev/null | grep -q "user-theme"; then
            gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null || \
            gnome-extensions enable user-theme 2>/dev/null
            echo "✓ User Themes habilitado"
        fi
        
        # =====================================================================
        # APLICAR TEMA ADWAITA-TRANSPARENT
        # =====================================================================
        
        # Verificar que el tema existe
        if [ -d "$HOME/.themes/Adwaita-Transparent/gnome-shell" ]; then
            # Aplicar el tema
            gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent' 2>/dev/null
            echo "✓ Tema Adwaita-Transparent aplicado"
        else
            echo "⚠ Tema Adwaita-Transparent no encontrado en ~/.themes/"
        fi
        
        # =====================================================================
        # CONFIGURAR UBUNTU DOCK CON TRANSPARENCIA
        # =====================================================================
        if gnome-extensions list 2>/dev/null | grep -q "ubuntu-dock"; then
            gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock customize-alphas true 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock min-alpha 0.15 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock max-alpha 0.15 2>/dev/null
            echo "✓ Ubuntu Dock transparencia configurada (15%)"
        fi
        
        # Marcar como configurado
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        # Reiniciar GNOME Shell para aplicar tema (solo X11)
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            echo "Reiniciando GNOME Shell..."
            nohup sh -c 'sleep 2 && killall -SIGQUIT gnome-shell' >/dev/null 2>&1 &
        else
            echo "Wayland detectado: cierra sesión para aplicar el tema"
        fi
    fi
fi
TRANSPARENCY_EOF

chmod +x /etc/profile.d/03-gnome-transparency.sh

echo "✓ Script de activación creado"

# ============================================================================
# CREAR README PARA EL USUARIO
# ============================================================================

cat > /etc/skel/README-TEMA-TRANSPARENTE.txt << 'README_EOF'
TEMA ADWAITA-TRANSPARENT
========================

Este sistema incluye un tema personalizado con transparencias del 15%.

UBICACIÓN:
~/.themes/Adwaita-Transparent/

EXTENSIÓN REQUERIDA:
User Themes (ya instalada)

ACTIVACIÓN:
El tema se activa automáticamente en el primer login.

VERIFICAR:
gsettings get org.gnome.shell.extensions.user-theme name
# Debería mostrar: 'Adwaita-Transparent'

CAMBIAR TEMA MANUALMENTE:
1. Abrir "Retoques" (gnome-tweaks)
2. Ir a "Apariencia"
3. En "Tema de Shell" seleccionar "Adwaita-Transparent"

O desde terminal:
gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent'

DESACTIVAR TRANSPARENCIAS:
gsettings set org.gnome.shell.extensions.user-theme name ''

PERSONALIZAR:
Editar el archivo:
~/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css

Buscar "rgba(0, 0, 0, 0.15)" y cambiar el último valor:
- 0.05 = más transparente
- 0.30 = menos transparente
- 1.00 = opaco

Después de editar, reiniciar GNOME Shell:
- X11: Alt+F2, escribir 'r', Enter
- Wayland: Cerrar sesión
README_EOF

echo "✓ README creado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ TEMA ADWAITA-TRANSPARENT INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Componentes instalados:"
echo "  • Extensión: gnome-shell-extension-user-theme"
echo "  • Tema: ~/.themes/Adwaita-Transparent/"
echo "  • Script: /etc/profile.d/03-gnome-transparency.sh"
echo ""
echo "El tema se activará automáticamente en el primer login."
echo ""
echo "Transparencias aplicadas (15%):"
echo "  • Panel superior"
echo "  • App Grid"
echo "  • Calendario y notificaciones"
echo "  • Quick Settings"
echo "  • Workspaces"
echo "  • Ubuntu Dock"
echo "  • Todos los menús"
echo ""
echo "Ver: ~/README-TEMA-TRANSPARENTE.txt para más detalles"
echo ""

exit 0
