#!/bin/bash
# MÓDULO 32: Optimizar para laptop
# REQUIERE: TARGET, INSTALL_NOTHROTTLE
# PRODUCE:  power-profiles-daemon + nothrottle (opcional)

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# ── Cargar configuración desde config.yaml ────────────────────────────────────
_YAML_FILE="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/../config.yaml"
_yaml_val() {
    local section="$1" key="$2" default="${3:-}"
    [ ! -f "$_YAML_FILE" ] && { echo "$default"; return; }
    local in_section=false val=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*$ ]]; then
            [ "${BASH_REMATCH[1]}" = "$section" ] && in_section=true || in_section=false
            continue
        fi
        if $in_section && [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]+(.*) ]]; then
            val="${BASH_REMATCH[1]}"
            val="${val%%#*}"; val="${val%"${val##*[![:space:]]}"}";
            val="${val#\"}" ; val="${val%\"}"; val="${val#\'}" ; val="${val%\'}"
            echo "$val"; return
        fi
    done < "$_YAML_FILE"
    echo "$default"
}

[ -z "${INSTALL_NOTHROTTLE:-}" ] && INSTALL_NOTHROTTLE=$(_yaml_val "laptop" "nothrottle" "false")

TARGET="${TARGET:-/mnt/ubuntu}"

if ! mountpoint -q "$TARGET" 2>/dev/null; then
    echo "ERROR: TARGET=$TARGET no está montado." >&2
    exit 1
fi
if [ ! -x "$TARGET/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en $TARGET sin apt-get." >&2
    exit 1
fi

# ============================================================================
# PASO 1: power-profiles-daemon (gestor de energía)
# ============================================================================
# PPD es el gestor integrado con GNOME. Tres perfiles: Performance, Balanced,
# Power Saver. Se gestiona desde GNOME Settings → Power → Power Mode.

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

echo ""
echo "Instalando power-profiles-daemon..."

apt-get install -y power-profiles-daemon thermald

systemctl enable power-profiles-daemon.service
systemctl enable thermald.service

echo "✓  power-profiles-daemon configurado"
echo "   Perfiles: Performance / Balanced / Power Saver"
echo "   Acceso: GNOME Settings → Power → Power Mode"
CHROOTEOF

echo ""
echo "✓  power-profiles-daemon instalado"

# ============================================================================
# PASO 2: CPU Power Manager (complementario, solo Intel)
# ============================================================================

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "CPU Power Manager (complementario):"
echo "  Herramienta tipo ThrottleStop para Linux."
echo "  Funciona junto con power-profiles-daemon."
echo ""
echo "  • Undervolt CPU/GPU/Cache (reducir voltaje → menos calor → más batería)"
echo "  • Control TDP (PL1/PL2) y temperatura de throttling (PROCHOT)"
echo "  • Frecuencias P-core/E-core para Intel 12th-14th Gen"
echo "  • Monitor en tiempo real con detección de throttling"
echo "  • Solo Intel (8th-14th Gen)"
echo ""

if [ -z "$INSTALL_NOTHROTTLE" ]; then
    read -p "¿Instalar CPU Power Manager? (s/n) [n]: " INSTALL_CPM
    INSTALL_CPM=$([[ "${INSTALL_CPM:-n}" =~ ^[SsYy]$ ]] && echo "true" || echo "false")
else
    [[ "$INSTALL_NOTHROTTLE" = "true" ]] && INSTALL_CPM="true" || INSTALL_CPM="false"
fi

if [ "$INSTALL_CPM" = "true" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CPM_SOURCE="$SCRIPT_DIR/../files/nothrottle"
    
    if [ -f "$SCRIPT_DIR/../nothrottle.sh" ]; then
        CPM_SOURCE="$SCRIPT_DIR/../nothrottle.sh"
    fi
    
    if [ ! -f "$CPM_SOURCE" ]; then
        echo "❌ Error: nothrottle no encontrado"
        echo "   Buscado en: $CPM_SOURCE"
    else
        echo ""
        echo "Instalando CPU Power Manager..."
        
        cp "$CPM_SOURCE" "$TARGET/tmp/nothrottle.sh"
        chmod 755 "$TARGET/tmp/nothrottle.sh"
        
        arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
export DEBIAN_FRONTEND=noninteractive

# Instalar dependencias opcionales
echo "  Instalando dependencias..."
apt-get install -y msr-tools lm-sensors 2>/dev/null || true

# Ejecutar instalación del binario
/tmp/nothrottle.sh --install

# Limpiar
rm -f /tmp/nothrottle.sh
CHROOTEOF

        echo ""
        echo "✓  CPU Power Manager instalado"
        echo "   Uso: sudo nothrottle"
    fi
else
    echo "  CPU Power Manager omitido"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  OPTIMIZACIONES DE LAPTOP COMPLETADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
