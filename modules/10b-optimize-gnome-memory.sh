#!/bin/bash
# Módulo 10b: Optimizar consumo de RAM en GNOME (interactivo)

set -e

source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIÓN DE MEMORIA PARA GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# PREGUNTAS INTERACTIVAS
# ============================================================================

echo "Responde a las siguientes preguntas para personalizar las optimizaciones:"
echo ""

# Tracker
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TRACKER (indexador de archivos)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Consume: ~100-200MB RAM"
echo "Función: Indexa archivos para búsquedas rápidas"
echo "Sin él: Búsquedas más lentas en Nautilus"
echo ""
read -p "¿Deshabilitar Tracker? (s/n) [s]: " DISABLE_TRACKER
DISABLE_TRACKER=${DISABLE_TRACKER:-s}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ANIMACIONES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Consume: ~30-50MB RAM y CPU"
echo "Función: Efectos visuales al abrir/cerrar ventanas"
echo "Sin ellas: Sistema más ágil, aspecto menos moderno"
echo ""
read -p "¿Deshabilitar animaciones? (s/n) [n]: " DISABLE_ANIMATIONS
DISABLE_ANIMATIONS=${DISABLE_ANIMATIONS:-n}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "EVOLUTION DATA SERVER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Consume: ~50-100MB RAM"
echo "Función: Backend de calendario/contactos (para Evolution)"
echo "Sin él: GNOME Calendar no funcionará"
echo ""
read -p "¿Deshabilitar Evolution Data Server? (s/n) [s]: " DISABLE_EDS
DISABLE_EDS=${DISABLE_EDS:-s}

echo ""
echo "Aplicando configuración..."
echo ""

# ============================================================================
# APLICAR OPTIMIZACIONES
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
set -e
export DEBIAN_FRONTEND=noninteractive

DISABLE_TRACKER="$DISABLE_TRACKER"
DISABLE_ANIMATIONS="$DISABLE_ANIMATIONS"
DISABLE_EDS="$DISABLE_EDS"

# ============================================================================
# DESHABILITAR TRACKER
# ============================================================================

if [[ \$DISABLE_TRACKER =~ ^[SsYy]$ ]]; then
    echo "Deshabilitando Tracker..."
    
    mkdir -p /etc/xdg/autostart
    
    cat > /etc/xdg/autostart/tracker-miner-fs-3.desktop << 'TRACKER_EOF'
[Desktop Entry]
Type=Application
Name=Tracker File System Miner
Hidden=true
X-GNOME-Autostart-enabled=false
TRACKER_EOF
    
    cat > /etc/xdg/autostart/tracker-extract-3.desktop << 'TRACKER_EOF'
[Desktop Entry]
Type=Application
Name=Tracker Metadata Extractor
Hidden=true
X-GNOME-Autostart-enabled=false
TRACKER_EOF
    
    echo "✓ Tracker deshabilitado (ahorra ~100-200MB RAM)"
else
    echo "○ Tracker habilitado (indexación activa)"
fi

# ============================================================================
# DESHABILITAR EVOLUTION DATA SERVER
# ============================================================================

if [[ \$DISABLE_EDS =~ ^[SsYy]$ ]]; then
    echo "Deshabilitando Evolution Data Server..."
    
    if dpkg -l | grep -q evolution-data-server; then
        cat > /etc/xdg/autostart/evolution-data-server.desktop << 'EDS_EOF'
[Desktop Entry]
Type=Application
Name=Evolution Data Server
Hidden=true
X-GNOME-Autostart-enabled=false
EDS_EOF
        
        echo "✓ Evolution Data Server deshabilitado (ahorra ~50-100MB RAM)"
    else
        echo "○ Evolution Data Server no instalado"
    fi
else
    echo "○ Evolution Data Server habilitado"
fi

# ============================================================================
# DESHABILITAR GNOME SOFTWARE
# ============================================================================

echo "Deshabilitando gnome-software (siempre)..."
systemctl mask gnome-software.service 2>/dev/null || true
echo "✓ gnome-software deshabilitado (ahorra ~80-150MB RAM)"

# ============================================================================
# CONFIGURACIÓN DE USUARIO (primer login)
# ============================================================================

cat > /etc/profile.d/02-gnome-memory-opt.sh << 'OPTEOF'
#!/bin/bash
# Optimizaciones de memoria para GNOME

if [ -n "\$DBUS_SESSION_BUS_ADDRESS" ] && [ "\$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="\$HOME/.config/.gnome-memory-optimized"
    
    if [ ! -f "\$MARKER" ]; then
        DISABLE_ANIMATIONS="$DISABLE_ANIMATIONS"
        DISABLE_TRACKER="$DISABLE_TRACKER"
        
        # Animaciones
        if [[ \$DISABLE_ANIMATIONS =~ ^[SsYy]$ ]]; then
            gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
            echo "✓ Animaciones deshabilitadas"
        fi
        
        # Búsqueda (Tracker)
        if [[ \$DISABLE_TRACKER =~ ^[SsYy]$ ]]; then
            gsettings set org.gnome.desktop.search-providers disabled \
                "['org.gnome.Nautilus.desktop']" 2>/dev/null
        fi
        
        # Limitar thumbnails
        gsettings set org.gnome.nautilus.preferences thumbnail-limit 10485760 2>/dev/null
        
        mkdir -p "\$HOME/.config"
        touch "\$MARKER"
    fi
fi
OPTEOF

chmod +x /etc/profile.d/02-gnome-memory-opt.sh

CHROOTEOF

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ OPTIMIZACIÓN DE MEMORIA COMPLETADA"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Configuración aplicada:"

RAM_SAVED=0

if [[ ${DISABLE_TRACKER:-n} =~ ^[SsYy]$ ]]; then
    echo "  ✓ Tracker deshabilitado"
    RAM_SAVED=$((RAM_SAVED + 150))
else
    echo "  ○ Tracker habilitado"
fi

if [[ ${DISABLE_ANIMATIONS:-n} =~ ^[SsYy]$ ]]; then
    echo "  ✓ Animaciones deshabilitadas"
    RAM_SAVED=$((RAM_SAVED + 40))
else
    echo "  ○ Animaciones habilitadas"
fi

if [[ ${DISABLE_EDS:-n} =~ ^[SsYy]$ ]]; then
    echo "  ✓ Evolution Data Server deshabilitado"
    RAM_SAVED=$((RAM_SAVED + 75))
else
    echo "  ○ Evolution Data Server habilitado"
fi

echo "  ✓ gnome-software deshabilitado (siempre)"
RAM_SAVED=$((RAM_SAVED + 100))

echo ""
echo "RAM ahorrada estimada: ~${RAM_SAVED}MB"
echo "Consumo esperado en idle: ~$((1200 - RAM_SAVED))MB (vs ~1200MB antes)"
echo ""

exit 0
