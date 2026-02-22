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
        sleep 2  # Esperar a que GNOME Shell esté listo
        
        # =====================================================================
        # EXTENSIONES (siempre habilitar extensiones base)
        # =====================================================================
        EXTENSIONS=(
            "appindicatorsupport@rgcjonas.gmail.com"
            "ding@rastersoft.com"
            "ubuntu-dock@ubuntu.com"
        )
        
        # Si existe user-theme, añadirla a la lista
        if gnome-extensions list 2>/dev/null | grep -q "user-theme"; then
            EXTENSIONS+=("user-theme@gnome-shell-extensions.gcampax.github.com")
        fi
        
        for ext in "${EXTENSIONS[@]}"; do
            if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
                gnome-extensions enable "$ext" 2>/dev/null || \
                gdbus call --session --dest org.gnome.Shell \
                    --object-path /org/gnome/Shell \
                    --method org.gnome.Shell.Extensions.EnableExtension "$ext" 2>/dev/null || true
            fi
        done
        
        # =====================================================================
        # TEMA DE ICONOS
        # =====================================================================
        gsettings set org.gnome.desktop.interface icon-theme 'elementary' 2>/dev/null
        
        # =====================================================================
        # TEMA GTK (para aplicaciones legacy)
        # =====================================================================
        # Configurar Adwaita-dark para apps GTK3 que no usan libadwaita
        # Esto hace que apps legacy respeten el modo oscuro de GNOME
        gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null
        
        # Modo de color (preferencia de oscuro)
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
        gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15 2>/dev/null
        
        # =====================================================================
        # APPS ANCLADAS
        # =====================================================================
        gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']" 2>/dev/null
        
        # =====================================================================
        # CARPETAS DEL APP GRID
        # =====================================================================
        # Configurar carpetas organizadas: Utilidades y Sistema
        
        # Carpeta Utilidades
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ name 'Utilidades' 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ translate false 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ categories "['X-GNOME-Utilities']" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps "['org.gnome.baobab.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.Logs.desktop', 'org.gnome.font-viewer.desktop', 'org.gnome.FileRoller.desktop', 'org.gnome.Terminal.desktop']" 2>/dev/null
        
        # Carpeta Sistema
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ name 'Sistema' 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ translate false 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ categories "['Settings', 'System']" 2>/dev/null
        gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/System/ apps "['gnome-control-center.desktop', 'org.gnome.tweaks.desktop', 'gnome-system-monitor.desktop', 'gnome-disks.desktop', 'software-properties-gtk.desktop']" 2>/dev/null
        
        # Activar las carpetas
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
