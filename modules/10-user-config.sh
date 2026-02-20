#!/bin/bash
# Módulo 10-user-config: Configuración de usuario (tema iconos, fuentes, apps)

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE USUARIO GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# ============================================================================
# ELIMINAR EXTENSIÓN snapd-prompting (si existe)
# ============================================================================

echo "Verificando extensión snapd-prompting..."

SNAPD_EXT="/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com"
if [ -d "$SNAPD_EXT" ]; then
    echo "Eliminando extensión snapd-prompting..."
    rm -rf "$SNAPD_EXT"
    echo "✓ Extensión snapd-prompting eliminada"
else
    echo "✓ Extensión snapd-prompting no encontrada (OK)"
fi

# ============================================================================
# SCRIPT DE PRIMER LOGIN - PERSONALIZACIÓN
# ============================================================================

echo ""
echo "Creando script de configuración de usuario..."

cat > /etc/profile.d/10-gnome-user-config.sh << 'USERCONF'
#!/bin/bash
# Configuración de usuario GNOME (se ejecuta en primer login)

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-user-configured"
    
    if [ ! -f "$MARKER" ]; then
        sleep 2  # Esperar a que GNOME Shell esté listo
        
        # =====================================================================
        # TEMA DE ICONOS
        # =====================================================================
        gsettings set org.gnome.desktop.interface icon-theme 'elementary' 2>/dev/null
        
        # =====================================================================
        # TIPOGRAFÍAS
        # =====================================================================
        # Interfaz y documentos: Ubuntu Regular 11
        gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11' 2>/dev/null
        gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 11' 2>/dev/null
        
        # Títulos: Ubuntu Bold 11
        gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 11' 2>/dev/null
        
        # Monospace: JetBrainsMono Nerd Font 10
        gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10' 2>/dev/null
        
        # =====================================================================
        # APPS ANCLADAS
        # =====================================================================
        gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']" 2>/dev/null
        
        # Crear marker
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        echo "✓ GNOME configuración de usuario aplicada"
    fi
fi
USERCONF

chmod +x /etc/profile.d/10-gnome-user-config.sh

echo "✓ Script de usuario creado: /etc/profile.d/10-gnome-user-config.sh"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ CONFIGURACIÓN DE USUARIO PREPARADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Realizado durante instalación:"
echo "  • Eliminar extensión snapd-prompting (si existe)"
echo ""
echo "Se aplicará en el primer login:"
echo "  • Tema de iconos: elementary"
echo "  • Fuentes: Ubuntu + JetBrainsMono Nerd Font"
echo "  • Apps ancladas: Chrome + Nautilus"
echo ""

# ============================================================================
# VALIDACIÓN POST-EJECUCIÓN
# ============================================================================

source "$(dirname "$0")/../lib/validate-module.sh" 2>/dev/null || {
    echo "⚠ Sistema de validación no disponible"
    exit 0
}

validate_start "10-user-config"

# Script de configuración de usuario
validate_file "$TARGET/etc/profile.d/10-gnome-user-config.sh" "Script configuración usuario"
validate_permissions "$TARGET/etc/profile.d/10-gnome-user-config.sh" "755" "Permisos script usuario"

# Verificar que extensión snapd-prompting fue eliminada
SNAPD_EXT="$TARGET/usr/share/gnome-shell/extensions/snapd-prompting@canonical.com"
if [ -d "$SNAPD_EXT" ]; then
    validate_error "Extensión snapd-prompting no eliminada"
else
    validate_ok "Extensión snapd-prompting eliminada correctamente"
fi

validate_report

exit 0
