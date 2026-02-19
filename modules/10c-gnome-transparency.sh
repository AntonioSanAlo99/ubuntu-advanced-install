#!/bin/bash
# Módulo 10c: Configurar transparencias en GNOME

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE TRANSPARENCIAS EN GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# ============================================================================
# CSS PERSONALIZADO PARA GNOME SHELL
# ============================================================================

echo "Configurando transparencias (opacidad 15%)..."

# Crear directorio para CSS personalizado
mkdir -p /etc/skel/.config/gtk-3.0
mkdir -p /etc/skel/.local/share/gnome-shell

# CSS para GNOME Shell (transparencias globales)
cat > /etc/skel/.local/share/gnome-shell/gnome-shell.css << 'CSS_EOF'
/* ============================================================================
   TRANSPARENCIAS PERSONALIZADAS - Opacidad 15%
   ============================================================================ */

/* App Grid (lanzador de aplicaciones) */
.app-grid {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

#dash,
.dash-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Panel superior */
#panel {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Calendario y notificaciones */
.calendar-popup,
.message-list,
.events-section,
.world-clocks-section,
.weather-section {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Quick Settings (menú de configuración rápida) */
.quick-settings,
.quick-settings-menu,
.quick-toggle,
.quick-settings-header {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Workspaces (selector de espacios de trabajo) */
.workspace-background,
.workspace-box,
.workspace-thumbnails {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Overview background */
.overview-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Dock (Ubuntu Dock) */
#dashtodockContainer .dash-background {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

#dashtodockContainer {
    background-color: rgba(0, 0, 0, 0.15) !important;
}
CSS_EOF

echo "✓ CSS de GNOME Shell configurado"

# ============================================================================
# GDM (PANTALLA DE LOGIN) - Transparencias
# ============================================================================

echo "Configurando transparencias en GDM..."

# Crear directorio para GDM
mkdir -p /etc/gdm3

# CSS para GDM
cat > /etc/gdm3/greeter.dconf-defaults << 'GDM_EOF'
# Configuración personalizada para GDM

[org/gnome/desktop/interface]
gtk-theme='Yaru'

[org/gnome/shell]
# Habilitar extensiones en GDM
enabled-extensions=['']
GDM_EOF

# CSS personalizado para GDM (transparencia en el panel)
mkdir -p /usr/share/gnome-shell/theme
cat > /usr/share/gnome-shell/theme/gdm3-custom.css << 'GDM_CSS_EOF'
/* Transparencias en GDM (pantalla de login) */

/* Panel superior en login */
#panel {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Login box */
.login-dialog,
.login-dialog-user-list,
.login-dialog-prompt-layout {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

/* Dialog */
.modal-dialog {
    background-color: rgba(0, 0, 0, 0.15) !important;
}
GDM_CSS_EOF

echo "✓ Transparencias de GDM configuradas"

# ============================================================================
# SCRIPT DE ACTIVACIÓN (primer login del usuario)
# ============================================================================

cat > /etc/profile.d/03-gnome-transparency.sh << 'TRANSPARENCY_EOF'
#!/bin/bash
# Aplicar transparencias en GNOME Shell

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-transparency-applied"
    
    if [ ! -f "$MARKER" ]; then
        # Copiar CSS personalizado si no existe
        if [ ! -f "$HOME/.local/share/gnome-shell/gnome-shell.css" ]; then
            mkdir -p "$HOME/.local/share/gnome-shell"
            cp /etc/skel/.local/share/gnome-shell/gnome-shell.css \
               "$HOME/.local/share/gnome-shell/gnome-shell.css" 2>/dev/null || true
        fi
        
        # Configuración de Ubuntu Dock (transparencia)
        if gnome-extensions list | grep -q "ubuntu-dock"; then
            # Transparencia en Ubuntu Dock
            gsettings set org.gnome.shell.extensions.dash-to-dock \
                background-opacity 0.15 2>/dev/null || true
            
            # Personalizar Dock
            gsettings set org.gnome.shell.extensions.dash-to-dock \
                transparency-mode 'FIXED' 2>/dev/null || true
            
            echo "✓ Transparencia de Dock configurada"
        fi
        
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        # Reiniciar GNOME Shell para aplicar CSS (solo X11)
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            nohup sh -c 'sleep 2 && killall -SIGQUIT gnome-shell' >/dev/null 2>&1 &
        fi
        
        echo "✓ Transparencias aplicadas (reinicia sesión si es Wayland)"
    fi
fi
TRANSPARENCY_EOF

chmod +x /etc/profile.d/03-gnome-transparency.sh

echo "✓ Script de transparencias creado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ TRANSPARENCIAS CONFIGURADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Elementos con opacidad 15%:"
echo "  • App Grid (lanzador de aplicaciones)"
echo "  • Panel superior"
echo "  • Calendario y notificaciones"
echo "  • Quick Settings (menú de configuración)"
echo "  • Workspaces (espacios de trabajo)"
echo "  • Ubuntu Dock"
echo "  • GDM (pantalla de login)"
echo ""
echo "IMPORTANTE:"
echo "  • En X11: se aplicará automáticamente"
echo "  • En Wayland: requiere reiniciar sesión"
echo "  • CSS ubicado en: ~/.local/share/gnome-shell/gnome-shell.css"
echo ""

exit 0
