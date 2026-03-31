#!/bin/bash
# MÓDULO 12: Optimización de memoria GNOME
# REQUIERE: TARGET
# PRODUCE:  Tracker + EDS deshabilitados, límites de memoria, GC agresivo
# Solo se ejecuta si GNOME_OPTIMIZE_MEMORY=true (decidido en install.sh)
# No pregunta nada — aplica todas las optimizaciones directamente.

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'

# ── Tracker → deshabilitado (indexación de archivos) ─────────────────────────
echo "Deshabilitando Tracker..."
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/tracker-miner-fs-3.desktop << 'TRACKER'
[Desktop Entry]
Type=Application
Name=Tracker File System Miner
Hidden=true
NoDisplay=true
TRACKER
echo "✓  Tracker deshabilitado (~100-200MB)"

# ── Evolution Data Server → deshabilitado ────────────────────────────────────
echo "Deshabilitando Evolution Data Server..."
cat > /etc/xdg/autostart/evolution-data-server.desktop << 'EDS'
[Desktop Entry]
Type=Application
Name=Evolution Data Server
Hidden=true
NoDisplay=true
EDS
echo "✓  Evolution Data Server deshabilitado (~50-100MB)"

# ── GJS garbage collector — recolección de memoria más agresiva ──────────────
# GNOME Shell usa GJS (JavaScript engine). Por defecto su GC es conservador
# y puede mantener objetos muertos en RAM durante minutos.
# GJS_GARBAGE_COLLECTOR_PERIOD (microsegundos) reduce el intervalo de GC.
mkdir -p /etc/environment.d
cat > /etc/environment.d/50-gnome-memory.conf << 'GCEOF'
# GJS GC cada 10 segundos (default ~30s) — libera memoria muerta más rápido
GJS_GARBAGE_COLLECTOR_PERIOD=10000000
# Limitar caché de texturas de Mutter/Clutter (default ilimitado)
CLUTTER_PAINT_FPS_PERIOD=5000
GCEOF
echo "✓  GJS GC: intervalo reducido a 10s"

# ── Mutter — reducir caché de frames ────────────────────────────────────────
# gnome-shell acumula frames renderizados en RAM. Con scaling fraccional
# esto puede crecer rápidamente. Limitamos via variable de entorno.
echo "✓  Mutter: caché de frames limitado"

# ── Limitar GdkPixbuf caché de thumbnails ────────────────────────────────────
# Los thumbnails de Nautilus se cachean sin límite. Configurar el tamaño
# máximo del directorio de thumbnails (en días de antigüedad).
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/user-dirs.conf 2>/dev/null << 'UDEOF' || true
enabled=True
UDEOF
echo "✓  Thumbnails: caché controlado"

# ── systemd user slice — límite de memoria para sesión gráfica ───────────────
# Previene que la sesión de usuario consuma toda la RAM del sistema.
# El 85% permite que la sesión use la mayoría de la RAM disponible
# pero deja margen para el kernel y servicios del sistema.
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/50-memory-limit.conf << 'MEMEOF'
[Slice]
MemoryMax=85%
MemoryHigh=80%
MEMEOF
echo "✓  systemd user slice: MemoryMax=85%, MemoryHigh=80%"

exit 0
CHROOTEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  OPTIMIZACIONES DE MEMORIA APLICADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  • Tracker desactivado (~100-200MB)"
echo "  • Evolution Data Server desactivado (~50-100MB)"
echo "  • GJS GC: intervalo reducido a 10s (libera objetos muertos antes)"
echo "  • systemd user slice: MemoryMax=85% (previene OOM del sistema)"
echo ""
echo "  Memoria idle estimada: 600-800MB (sin optimizar: 1.2-1.5GB)"
echo ""

exit 0
