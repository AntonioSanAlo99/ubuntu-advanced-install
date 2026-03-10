#!/bin/bash
# Módulo 10-optimize: Optimización de memoria GNOME
# Este módulo solo se ejecuta si GNOME_OPTIMIZE_MEMORY=true (decidido en install.sh)
# No pregunta nada — aplica todas las optimizaciones directamente.

set -e

[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "════════════════════════════════════════════════════════════════"
echo "  OPTIMIZACIÓN DE MEMORIA GNOME"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# ── gnome-software → deshabilitado (reemplazado por update-manager) ──────────
echo "Deshabilitando gnome-software..."
systemctl mask gnome-software 2>/dev/null || true
echo "✓  gnome-software deshabilitado (~80-150MB)"

# ── Tracker → deshabilitado (indexación de archivos) ─────────────────────────
echo "Deshabilitando Tracker..."
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/tracker-miner-fs-3.desktop << 'TRACKER'
[Desktop Entry]
Hidden=true
TRACKER
echo "✓  Tracker deshabilitado (~100-200MB)"

# ── Evolution Data Server → deshabilitado ────────────────────────────────────
echo "Deshabilitando Evolution Data Server..."
cat > /etc/xdg/autostart/evolution-data-server.desktop << 'EDS'
[Desktop Entry]
Hidden=true
EDS
echo "✓  Evolution Data Server deshabilitado (~50-100MB)"

CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  OPTIMIZACIONES APLICADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Memoria estimada idle:"
echo "  Sin optimizar: 1.2-1.5GB"
echo "  Optimizado:    600-800MB"
echo ""

exit 0
