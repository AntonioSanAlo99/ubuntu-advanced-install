#!/bin/bash
# Módulo 23: Minimizar systemd

set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "════════════════════════════════════════════════════════════════"
echo "  MINIMIZACIÓN DE SYSTEMD"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Verificar si un servicio existe
service_exists() {
    systemctl list-unit-files "$1" >/dev/null 2>&1

# Verificar si un servicio está habilitado
service_enabled() {
    systemctl is-enabled "$1" >/dev/null 2>&1

# Deshabilitar servicio con verificación
disable_service() {
    local service="$1"
    local reason="$2"
    
    if service_exists "$service"; then
        if service_enabled "$service"; then
            systemctl disable "$service" 2>/dev/null || true
            echo "  ✓ Deshabilitado: $service"
            [ -n "$reason" ] && echo "    Razón: $reason"
            return 0
        else
            echo "  ⊘ Ya deshabilitado: $service"
            return 0
        fi
    else
        echo "  − No existe: $service (omitiendo)"
        return 0
    fi

# Enmascarar servicio (evitar arranque incluso manual)
mask_service() {
    local service="$1"
    
    if service_exists "$service"; then
        systemctl mask "$service" 2>/dev/null || true
        echo "  ✓ Enmascarado: $service"
    fi

# ============================================================================
# SERVICIOS A DESHABILITAR
# ============================================================================

echo "Analizando servicios systemd..."
echo ""

# systemd-networkd (usamos NetworkManager)
echo "NetworkManager vs systemd-networkd:"
if service_exists "NetworkManager.service"; then
    if service_enabled "NetworkManager.service"; then
        echo "  ✓ NetworkManager activo → deshabilitando systemd-networkd"
        disable_service "systemd-networkd.service" "Conflicto con NetworkManager"
        disable_service "systemd-networkd.socket" "Conflicto con NetworkManager"
        mask_service "systemd-networkd.service"
    else
        echo "  ⚠ NetworkManager existe pero no está habilitado"
        echo "    No se modificará systemd-networkd"
    fi
else
    echo "  − NetworkManager no instalado → manteniendo systemd-networkd"
fi

echo ""
echo "Servicios wait-online (ralentizan boot):"
disable_service "systemd-networkd-wait-online.service" "Ralentiza boot innecesariamente"
disable_service "NetworkManager-wait-online.service" "Ralentiza boot innecesariamente"

echo ""
echo "Servicios D-Bus innecesarios en desktop:"
disable_service "systemd-hostnamed.service" "Redundante en desktop estático"
disable_service "systemd-localed.service" "Redundante en desktop con locale fijo"
disable_service "systemd-timedated.service" "Redundante si timezone no cambia"

echo ""
echo "Servicios de hardware opcional:"
disable_service "ModemManager.service" "Solo si no tienes módem 3G/4G"

echo ""

# ============================================================================
# BLOQUEAR INSTALACIÓN DE PAQUETES OPCIONALES
# ============================================================================

echo "Configurando preferencias de APT..."

cat > /etc/apt/preferences.d/99-no-systemd-extras << 'PREFS_EOF'
# Bloquear paquetes systemd opcionales que no se usan en desktop

Package: systemd-homed
Pin: release *
Pin-Priority: -1

Package: systemd-container
Pin: release *
Pin-Priority: -1

Package: systemd-journal-remote
Pin: release *
Pin-Priority: -1

Package: systemd-coredump
Pin: release *
Pin-Priority: -1

Package: systemd-oomd
Pin: release *
Pin-Priority: -1
PREFS_EOF

echo "✓  Preferencias APT configuradas (5 paquetes bloqueados)"

# ============================================================================
# OPTIMIZAR JOURNALD
# ============================================================================

echo ""
echo "Optimizando systemd-journald..."

mkdir -p /etc/systemd/journald.conf.d/

cat > /etc/systemd/journald.conf.d/99-minimal.conf << 'JOURNAL_EOF'
[Journal]
# Limitar uso de disco del journal
SystemMaxUse=100M
SystemMaxFileSize=10M
RuntimeMaxUse=50M

# Retención limitada
MaxRetentionSec=1week
MaxFileSec=1day

# Solo en RAM (volatile) para SSD/NVMe
# Cambiar a 'persistent' si necesitas logs post-mortem
Storage=volatile

# Comprimir logs
Compress=yes

# Solo warnings y errores (no info/debug)
MaxLevelStore=warning
MaxLevelSyslog=warning
JOURNAL_EOF

echo "✓  journald optimizado (100MB máx, 1 semana retención, volátil)"

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  RESUMEN"
echo "════════════════════════════════════════════════════════════════"

# Contar servicios deshabilitados
DISABLED_COUNT=0
for service in \
    systemd-networkd.service \
    systemd-networkd-wait-online.service \
    NetworkManager-wait-online.service \
    systemd-hostnamed.service \
    systemd-localed.service \
    systemd-timedated.service \
    ModemManager.service
do
    if service_exists "$service" && ! service_enabled "$service"; then
        DISABLED_COUNT=$((DISABLED_COUNT + 1))
    fi
done

echo "Servicios deshabilitados: $DISABLED_COUNT"
echo "Paquetes bloqueados: 5"
echo "Journal limitado: 100MB"
echo ""

CHROOTEOF

echo "════════════════════════════════════════════════════════════════"
echo "✓  SYSTEMD MINIMIZADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "IMPORTANTE:"
echo "  • Si instalas un módem 3G/4G, habilita ModemManager"
echo "  • Si necesitas logs persistentes, cambia Storage=volatile"
echo "  • Los servicios se verificaron antes de deshabilitarlos"
echo ""

exit 0
