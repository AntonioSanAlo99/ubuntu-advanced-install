#!/bin/bash
# Módulo 10-theme: Tema transparente GNOME (opcional)

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  TEMA TRANSPARENTE GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Tema Adwaita-Transparent:"
echo "  • Basado en Adwaita vanilla"
echo "  • Transparencias mínimas (Quick Settings + Calendar)"
echo ""

read -p "¿Aplicar tema transparente? (s/n) [n]: " APPLY_THEME
APPLY_THEME=${APPLY_THEME:-n}

if [ "$APPLY_THEME" != "s" ] && [ "$APPLY_THEME" != "S" ]; then
    echo "Tema transparente omitido."
    exit 0
fi

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

echo ""
echo "Instalando extensión User Themes..."

apt install -y gnome-shell-extension-user-theme

echo "✓ User Themes instalado"

echo ""
echo "Creando tema Adwaita-Transparent..."

mkdir -p /etc/skel/.themes/Adwaita-Transparent/gnome-shell

cat > /etc/skel/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css << 'THEME'
/* Adwaita-Transparent: Vanilla Adwaita con transparencias mínimas */
@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

.quick-settings {
    background-color: rgba(0, 0, 0, 0.15) !important;
}

.calendar {
    background-color: rgba(0, 0, 0, 0.15) !important;
}
THEME

echo "✓ Tema creado en /etc/skel/.themes/"

echo ""
echo "Creando script de activación..."

cat > /etc/profile.d/11-gnome-theme-apply.sh << 'THEMEAPPLY'
#!/bin/bash
# Activar tema transparente (se ejecuta en primer login)

if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-theme-configured"
    
    if [ ! -f "$MARKER" ]; then
        sleep 3  # Esperar a GNOME Shell
        
        # Habilitar extensiones necesarias
        EXTENSIONS=(
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "appindicatorsupport@rgcjonas.gmail.com"
            "ding@rastersoft.com"
            "ubuntu-dock@ubuntu.com"
        )
        
        for ext in "${EXTENSIONS[@]}"; do
            if gnome-extensions list 2>/dev/null | grep -q "$ext"; then
                gnome-extensions enable "$ext" 2>/dev/null || \
                gdbus call --session --dest org.gnome.Shell \
                    --object-path /org/gnome/Shell \
                    --method org.gnome.Shell.Extensions.EnableExtension "$ext" 2>/dev/null || true
            fi
        done
        
        # Aplicar tema
        gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent' 2>/dev/null
        
        # Configurar Dock
        gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' 2>/dev/null
        gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15 2>/dev/null
        
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        
        # Reiniciar Shell (solo X11)
        if [ "$XDG_SESSION_TYPE" = "x11" ]; then
            killall -SIGQUIT gnome-shell 2>/dev/null || true
        fi
        
        echo "✓ Tema transparente aplicado"
    fi
fi
THEMEAPPLY

chmod +x /etc/profile.d/11-gnome-theme-apply.sh

echo "✓ Script de activación creado"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ TEMA TRANSPARENTE CONFIGURADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Se aplicará en el primer login del usuario."
echo ""

exit 0
