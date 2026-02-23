#!/bin/bash
# Módulo 10-user-config: Configuración de usuario (tema iconos, fuentes, apps)

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

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
    echo "✓  Extensión snapd-prompting eliminada"
else
    echo "✓  Extensión snapd-prompting no encontrada (OK)"
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
        sleep 3  # Esperar a que GNOME Shell esté completamente listo
        
        # =====================================================================
        # EXTENSIONES (habilitar TODAS desde el inicio - MÉTODO ROBUSTO)
        # =====================================================================
        
        # Lista de extensiones a habilitar
        EXTENSIONS=(
            "appindicatorsupport@rgcjonas.gmail.com"
            "ding@rastersoft.com"
            "ubuntu-dock@ubuntu.com"
        )
        
        # Si existe user-theme, añadirla
        if gnome-extensions list 2>/dev/null | grep -q "user-theme"; then
            EXTENSIONS+=("user-theme@gnome-shell-extensions.gcampax.github.com")
        fi
        
        # Método 1: Habilitar con gnome-extensions
        for ext in "${EXTENSIONS[@]}"; do
            if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
                gnome-extensions enable "$ext" 2>/dev/null || true
            fi
        done
        
        # Método 2: Escribir directamente en dconf (más persistente)
        # Construir array para dconf
        EXT_ARRAY=""
        for ext in "${EXTENSIONS[@]}"; do
            if [ -z "$EXT_ARRAY" ]; then
                EXT_ARRAY="'$ext'"
            else
                EXT_ARRAY="$EXT_ARRAY, '$ext'"
            fi
        done
        
        # Escribir lista de extensiones habilitadas en dconf
        dconf write /org/gnome/shell/enabled-extensions "[$EXT_ARRAY]" 2>/dev/null || true
        
        # Forzar que las extensiones estén habilitadas
        dconf write /org/gnome/shell/disable-user-extensions "false" 2>/dev/null || true
        
        # =====================================================================
        # TEMA DE ICONOS
        # =====================================================================
        gsettings set org.gnome.desktop.interface icon-theme 'elementary' 2>/dev/null
        
        # =====================================================================
        # TEMA GTK (para aplicaciones legacy)
        # =====================================================================
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
        
        # =====================================================================
        # TIPOGRAFÍAS
        # =====================================================================
        gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11' 2>/dev/null
        gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 11' 2>/dev/null
        gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 11' 2>/dev/null
        gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10' 2>/dev/null
        
        # =====================================================================
        # TEMA SHELL (solo si existe)
        # =====================================================================
        if [ -d "$HOME/.themes/Adwaita-Transparent" ]; then
            gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent' 2>/dev/null
        fi
        
        # =====================================================================
        # DOCK (configurar transparencia)
        # =====================================================================
        gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' 2>/dev/null
        gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.30 2>/dev/null
        
        # =====================================================================
        # WORKSPACES (espacios de trabajo dinámicos)
        # =====================================================================
        # Habilitar workspaces dinámicos (se crean según necesidad)
        gsettings set org.gnome.mutter dynamic-workspaces true 2>/dev/null
        
        # Workspaces solo en pantalla primaria (mejor para multi-monitor)
        gsettings set org.gnome.mutter workspaces-only-on-primary true 2>/dev/null
        
        # Ocultar workspaces en App Grid (método Just Perfection)
        # Crea archivo CSS personalizado para ocultar workspace background en overview
        mkdir -p "$HOME/.local/share/gnome-shell"
        cat > "$HOME/.local/share/gnome-shell/gnome-shell.css" << 'CSS_EOF'
/* Ocultar workspaces en App Grid */
/* Método usado por Just Perfection extension */
/* https://gitlab.gnome.org/jrahmatzadeh/just-perfection */

.workspace-background {
    background-color: transparent;
    box-shadow: 0 4px 16px 4px transparent;
}
CSS_EOF
        
        echo "  ✓ Workspaces ocultos en App Grid (CSS personalizado)"
        
        # =====================================================================
        # PRIVACIDAD - DESHABILITAR SCREEN TIME
        # =====================================================================
        # Deshabilitar seguimiento de uso de aplicaciones (privacidad)
        gsettings set org.gnome.desktop.privacy remember-app-usage false 2>/dev/null
        
        # Nota: Esto deshabilita el tracking de Screen Time
        # Si el usuario quiere ver estadísticas de uso, puede habilitarlo en:
        # Settings → Privacy → Screen Time → Track application usage
        
        # =====================================================================
        # APPS ANCLADAS (Chrome y Nautilus)
        # =====================================================================
        gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']" 2>/dev/null
        
        # =====================================================================
        # CARPETAS DEL APP GRID - CONFIGURACIÓN PROFESIONAL
        # =====================================================================
        # Eliminar carpetas por defecto que causan duplicados
        gsettings set org.gnome.desktop.app-folders folder-children "[]" 2>/dev/null
        
        # Crear solo 2 carpetas limpias: Utilidades y Sistema
        
        # Carpeta Utilidades (herramientas de uso frecuente)
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ name 'Utilidades' 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ translate false 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ categories "[]" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps "['org.gnome.baobab.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.Logs.desktop', 'org.gnome.font-viewer.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.Characters.desktop', 'simple-scan.desktop', 'org.gnome.Evince.desktop', 'org.gnome.gedit.desktop']" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ excluded-apps "[]" 2>/dev/null
        
        # Carpeta Sistema (configuración y administración)
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ name 'Sistema' 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ translate false 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ categories "[]" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ apps "['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', 'gnome-system-monitor.desktop', 'gnome-disks.desktop', 'software-properties-gtk.desktop', 'gdebi.desktop', 'nm-connection-editor.desktop', 'org.gnome.Terminal.desktop']" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ excluded-apps "[]" 2>/dev/null
        
        # Activar SOLO estas 2 carpetas
        gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'System']" 2>/dev/null
        
        # Crear marker
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        # Reiniciar Shell (solo X11)
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            killall -SIGQUIT gnome-shell 2>/dev/null || true
        fi
        
        echo "  ✓ GNOME configuración de usuario aplicada"
    fi
fi
USERCONF

chmod +x /etc/profile.d/10-gnome-user-config.sh

echo "✓  Script de usuario creado: /etc/profile.d/10-gnome-user-config.sh"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  CONFIGURACIÓN DE USUARIO PREPARADA"
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

exit 0
