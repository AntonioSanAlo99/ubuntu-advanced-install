#!/bin/bash
# Módulo 10c: Tema transparente simple + User Themes + Apps ancladas

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE TEMA Y EXTENSIONES"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# ============================================================================
# SCRIPT DE ACTIVACIÓN EN PRIMER LOGIN
# ============================================================================

cat > /etc/profile.d/03-gnome-config.sh << 'GNOME_CONFIG_EOF'
#!/bin/bash
# Configuración de GNOME: tema, extensiones, apps ancladas

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-configured"
    
    if [ ! -f "$MARKER" ]; then
        sleep 2
        
        # =====================================================================
        # TEMA DE ICONOS
        # =====================================================================
        gsettings set org.gnome.desktop.interface icon-theme 'elementary' 2>/dev/null
        
        # =====================================================================
        # TIPOGRAFÍAS DEL SISTEMA
        # =====================================================================
        
        # Interfaz: Ubuntu Regular 11
        gsettings set org.gnome.desktop.interface font-name 'Ubuntu Regular' 2>/dev/null
        
        # Documentos: Ubuntu Regular 11
        gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu Regular' 2>/dev/null
        
        # Títulos de ventanas: Ubuntu Bold 11
        gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold' 2>/dev/null
        
        # Monospace: JetBrainsMono Nerd Font Regular 10
        gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font Regular' 2>/dev/null
        
        echo "✓ Tipografías configuradas: Ubuntu + JetBrainsMono Nerd Font"
        
        # =====================================================================
        # EXTENSIONES
        # =====================================================================
        
        # User Themes
        if gnome-extensions list 2>/dev/null | grep -q "user-theme"; then
            gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null
            echo "✓ User Themes habilitado"
        fi
        
        # App Indicators
        if gnome-extensions list 2>/dev/null | grep -q "appindicator"; then
            gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com 2>/dev/null
            echo "✓ App Indicators habilitado"
        fi
        
        # Desktop Icons
        if gnome-extensions list 2>/dev/null | grep -q "ding"; then
            gnome-extensions enable ding@rastersoft.com 2>/dev/null
            echo "✓ Desktop Icons habilitado"
        fi
        
        # Ubuntu Dock
        if gnome-extensions list 2>/dev/null | grep -q "ubuntu-dock"; then
            gnome-extensions enable ubuntu-dock@ubuntu.com 2>/dev/null
            
            # Configurar transparencia del Dock
            gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15 2>/dev/null
            gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' 2>/dev/null
            
            echo "✓ Ubuntu Dock habilitado con transparencia"
        fi
        
        # =====================================================================
        # APPS ANCLADAS: SOLO CHROME Y NAUTILUS
        # =====================================================================
        
        gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']" 2>/dev/null
        echo "✓ Apps ancladas: Chrome, Nautilus"
        
        # =====================================================================
        # MARCAR COMO CONFIGURADO
        # =====================================================================
        
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        # Reiniciar GNOME Shell (solo X11)
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            nohup sh -c 'sleep 2 && killall -SIGQUIT gnome-shell' >/dev/null 2>&1 &
        fi
    fi
fi
GNOME_CONFIG_EOF

chmod +x /etc/profile.d/03-gnome-config.sh

echo "✓ Script de configuración creado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ CONFIGURACIÓN COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Tipografías:"
echo "  • Interfaz: Ubuntu Regular"
echo "  • Documentos: Ubuntu Regular"
echo "  • Títulos: Ubuntu Bold"
echo "  • Monospace: JetBrainsMono Nerd Font"
echo ""
echo "Extensiones activadas:"
echo "  • User Themes (para tema personalizado)"
echo "  • App Indicators (iconos de bandeja)"
echo "  • Desktop Icons (iconos en escritorio)"
echo "  • Ubuntu Dock (barra lateral con transparencia)"
echo ""
echo "Apps ancladas:"
echo "  1. Google Chrome"
echo "  2. Nautilus"
echo ""

exit 0
