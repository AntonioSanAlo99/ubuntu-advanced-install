#!/bin/bash
# Módulo 10-optimize: Optimización de memoria GNOME (interactivo)

set -eo pipefail  # Detectar errores en pipelines

# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIÓN DE MEMORIA GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Este módulo permite reducir el consumo de memoria de GNOME."
echo "Ahorro estimado: 260-500MB RAM"
echo ""
echo "NOTA: Estas opciones son OPCIONALES y tienen trade-offs."
echo ""

# Prompt principal
read -p "¿Aplicar optimizaciones de memoria? (s/n) [n]: " OPTIMIZE
OPTIMIZE=${OPTIMIZE:-n}

if [ "$OPTIMIZE" != "s" ] && [ "$OPTIMIZE" != "S" ]; then
    echo "Optimización de memoria omitida."
    exit 0
fi

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURANDO OPTIMIZACIONES"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# gnome-software (siempre deshabilitar, sin prompt)
# ============================================================================

echo "Deshabilitando gnome-software (reemplazado por update-manager)..."

systemctl mask gnome-software 2>/dev/null || true

echo "✓ gnome-software deshabilitado (~80-150MB)"
echo ""

CHROOTEOF

# ============================================================================
# PROMPTS INTERACTIVOS
# ============================================================================

echo "────────────────────────────────────────────────────────────────"
echo "1/3: TRACKER (indexación de archivos)"
echo "────────────────────────────────────────────────────────────────"
echo "Ahorro: ~100-200MB RAM"
echo "Efecto: Búsquedas más lentas en Nautilus"
echo ""
read -p "¿Deshabilitar Tracker? (s/n) [s]: " DISABLE_TRACKER
DISABLE_TRACKER=${DISABLE_TRACKER:-s}

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "2/3: ANIMACIONES"
echo "────────────────────────────────────────────────────────────────"
echo "Ahorro: ~30-50MB RAM + CPU"
echo "Efecto: Interfaz menos fluida (sin animaciones)"
echo ""
read -p "¿Deshabilitar animaciones? (s/n) [n]: " DISABLE_ANIMATIONS
DISABLE_ANIMATIONS=${DISABLE_ANIMATIONS:-n}

echo ""
echo "────────────────────────────────────────────────────────────────"
echo "3/3: EVOLUTION DATA SERVER"
echo "────────────────────────────────────────────────────────────────"
echo "Ahorro: ~50-100MB RAM"
echo "Efecto: Sin sincronización de calendario/contactos"
echo ""
read -p "¿Deshabilitar Evolution Data Server? (s/n) [s]: " DISABLE_EDS
DISABLE_EDS=${DISABLE_EDS:-s}

# Aplicar configuraciones
arch-chroot "$TARGET" /bin/bash << APPLYEOF

# ============================================================================
# TRACKER
# ============================================================================

if [ "$DISABLE_TRACKER" = "s" ] || [ "$DISABLE_TRACKER" = "S" ]; then
    echo ""
    echo "Deshabilitando Tracker..."
    
    mkdir -p /etc/xdg/autostart
    cat > /etc/xdg/autostart/tracker-miner-fs-3.desktop << 'TRACKER'
[Desktop Entry]
Hidden=true
TRACKER
    
    echo "✓ Tracker deshabilitado (~100-200MB)"
fi

# ============================================================================
# ANIMACIONES
# ============================================================================

if [ "$DISABLE_ANIMATIONS" = "s" ] || [ "$DISABLE_ANIMATIONS" = "S" ]; then
    echo ""
    echo "Deshabilitando animaciones..."
    
    # Script para deshabilitar en primer login
    cat >> /etc/profile.d/10-gnome-user-config.sh << 'ANIM'

# Deshabilitar animaciones
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null
ANIM
    
    echo "✓ Animaciones se deshabilitarán en primer login (~30-50MB)"
fi

# ============================================================================
# EVOLUTION DATA SERVER
# ============================================================================

if [ "$DISABLE_EDS" = "s" ] || [ "$DISABLE_EDS" = "S" ]; then
    echo ""
    echo "Deshabilitando Evolution Data Server..."
    
    cat > /etc/xdg/autostart/evolution-data-server.desktop << 'EDS'
[Desktop Entry]
Hidden=true
EDS
    
    echo "✓ Evolution Data Server deshabilitado (~50-100MB)"
fi

APPLYEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓ OPTIMIZACIONES APLICADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Memoria estimada idle:"
echo "  Sin optimizar: 1.2-1.5GB"
echo "  Optimizado:    600-800MB"
echo ""

exit 0
