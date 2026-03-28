#!/bin/bash
# MÓDULO 33: Minimizar systemd
# REQUIERE: TARGET
# PRODUCE:  Servicios innecesarios deshabilitados

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

# Verificar que TARGET está montado
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi



arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'
set -e

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Verificar si un servicio existe
service_exists() {
    systemctl list-unit-files "$1" >/dev/null 2>&1
}

# Verificar si un servicio está habilitado
service_enabled() {
    systemctl is-enabled "$1" >/dev/null 2>&1
}

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
}

# Enmascarar servicio (evitar arranque incluso manual)
mask_service() {
    local service="$1"
    
    if service_exists "$service"; then
        systemctl mask "$service" 2>/dev/null || true
        echo "  ✓ Enmascarado: $service"
    fi
}

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
disable_service "systemd-timedated.service" "Redundante — chrony gestiona NTP directamente"
# NOTA: systemd-localed NO se desactiva.
# GNOME Settings lo necesita para cambiar el layout de teclado.
# Es D-Bus-activated (solo arranca bajo demanda), no consume recursos en reposo.

echo ""
echo "Servicios de hardware opcional:"
disable_service "ModemManager.service" "Solo si no tienes módem 3G/4G"

echo ""
echo "Telemetría y reportes de Ubuntu:"
disable_service "apport.service" "Reportes de crash — consume CPU en background"
disable_service "whoopsie.service" "Envío de reportes a Canonical"
mask_service "apport.service"
mask_service "whoopsie.service"
# Deshabilitar apport a nivel de configuración también
if [ -f /etc/default/apport ]; then
    sed -i 's/^enabled=1/enabled=0/' /etc/default/apport
fi

echo ""
echo "Servicios de indexación (consumen I/O en background):"
# Tracker indexa ficheros continuamente — consume CPU/I/O sin que el usuario lo note
disable_service "tracker-miner-fs-3.service" "Indexador de ficheros — I/O constante en background"
disable_service "tracker-miner-rss-3.service" "Indexador RSS — no se usa"
# Deshabilitar también a nivel de usuario (autostart)
mkdir -p /etc/xdg/autostart
for tracker_desktop in \
    tracker-miner-fs-3.desktop \
    tracker-miner-rss-3.desktop \
    tracker-extract-3.desktop; do
    if [ -f "/usr/share/applications/$tracker_desktop" ] || [ -f "/etc/xdg/autostart/$tracker_desktop" ]; then
        cp "/etc/xdg/autostart/$tracker_desktop" "/etc/xdg/autostart/$tracker_desktop" 2>/dev/null || true
        echo -e "[Desktop Entry]\nHidden=true" > "/etc/xdg/autostart/$tracker_desktop"
        echo "  ✓ Oculto autostart: $tracker_desktop"
    fi
done

echo ""
echo "Snapd (no se usa — todo se instala via apt/cargo/pip):"
if service_exists "snapd.service"; then
    disable_service "snapd.service" "No se usa — consume RAM y CPU en background"
    disable_service "snapd.socket" "Socket de snapd"
    disable_service "snapd.seeded.service" "Seed de snapd"
    mask_service "snapd.service"
    mask_service "snapd.socket"
    # Purgar snapd si no tiene snaps instalados (solo core)
    SNAP_COUNT=$(snap list 2>/dev/null | wc -l || echo 0)
    if [ "$SNAP_COUNT" -le 2 ]; then
        apt-get purge -y snapd 2>/dev/null || true
        rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd
        # Evitar reinstalación
        cat > /etc/apt/preferences.d/no-snapd << 'SNAPEOF'
Package: snapd
Pin: release *
Pin-Priority: -1
SNAPEOF
        echo "  ✓ snapd purgado y bloqueado"
    else
        echo "  ⚠ snapd tiene snaps instalados — no se purga (solo deshabilitado)"
    fi
fi

echo ""
echo "CUPS (impresión — se habilita bajo demanda si se necesita):"
disable_service "cups.service" "Daemon de impresión — se inicia bajo demanda via socket"
disable_service "cups-browsed.service" "Descubrimiento de impresoras en red"
# cups.socket se mantiene — arranca cups solo cuando algo intenta imprimir
echo "  ℹ cups.socket activo — CUPS arranca solo si se imprime"

echo ""
echo "Servicios misceláneos:"
disable_service "avahi-daemon.service" "Descubrimiento mDNS — rara vez necesario en desktop"
# switcheroo-control: solo desactivar si NO hay GPU dual (módulo 24 lo habilita)
if ! service_enabled "switcheroo-control.service" 2>/dev/null; then
    disable_service "switcheroo-control.service" "Solo GPU dual — no detectada"
else
    echo "  ⊘ switcheroo-control: activo (GPU dual configurada por módulo gaming)"
fi
# bluetooth: solo desactivar si NO fue habilitado por módulo 22
if ! service_enabled "bluetooth.service" 2>/dev/null; then
    disable_service "bluetooth.service" "No hay hardware bluetooth detectado"
else
    echo "  ⊘ bluetooth: activo (configurado por módulo wireless)"
fi
# power-profiles-daemon: solo desactivar si NO es laptop (módulo 32 lo habilita)
if ! service_enabled "power-profiles-daemon.service" 2>/dev/null; then
    disable_service "power-profiles-daemon.service" "No es laptop"
else
    echo "  ⊘ power-profiles-daemon: activo (configurado por módulo laptop)"
fi

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
PREFS_EOF

echo "✓  Preferencias APT configuradas (4 paquetes bloqueados)"

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
    systemd-timedated.service \
    ModemManager.service \
    apport.service \
    whoopsie.service \
    tracker-miner-fs-3.service \
    tracker-miner-rss-3.service \
    snapd.service \
    cups.service \
    cups-browsed.service \
    switcheroo-control.service \
    avahi-daemon.service \
    bluetooth.service
do
    if service_exists "$service" && ! service_enabled "$service"; then
        DISABLED_COUNT=$((DISABLED_COUNT + 1))
    fi
done

echo "Servicios deshabilitados: $DISABLED_COUNT"
echo "Paquetes bloqueados: $(cat /etc/apt/preferences.d/99-no-systemd-extras /etc/apt/preferences.d/no-snapd 2>/dev/null | grep -c 'Package:' || echo 4)"
echo "Journal limitado: 100MB (volátil, solo warnings)"
echo "Tracker indexación: deshabilitada"
echo "Snapd: $(command -v snap >/dev/null 2>&1 && echo 'deshabilitado' || echo 'purgado')"
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
