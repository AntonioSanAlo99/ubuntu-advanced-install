#!/bin/bash
# MÓDULO 06: Configurar actualizaciones automáticas (enfoque LTSC)
# REQUIERE: TARGET
# PRODUCE:  unattended-upgrades (solo seguridad) + needrestart (pasivo)
#
# DECISIÓN DE DISEÑO:
# Enfoque tipo Windows LTSC: solo parches de seguridad automáticos.
# Sin actualizaciones de features. Sin reinicios forzados. Sin saltos de versión.
# El usuario actualiza aplicaciones manualmente con topgrade cuando quiera.
#
# - Seguridad (kernel, openssl, glibc, systemd) → automática, diaria
# - Reboot → nunca forzado, indicador discreto en terminal (motd)
# - Aplicaciones → solo con topgrade manual
# - Cambio de release → bloqueado

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

TARGET="${TARGET:-/mnt/ubuntu}"

if ! mountpoint -q "$TARGET" 2>/dev/null; then
    echo "ERROR: TARGET=$TARGET no está montado." >&2
    exit 1
fi
if [ ! -x "$TARGET/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en $TARGET sin apt-get." >&2
    exit 1
fi

echo ""
echo "Configurando actualizaciones automáticas (solo seguridad)..."

arch-chroot "$TARGET" /bin/bash << 'UPDATEEOF'
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# 1. INSTALAR HERRAMIENTAS
# ============================================================================

apt-get install -y unattended-upgrades apt-listchanges needrestart

# ============================================================================
# 2. UNATTENDED-UPGRADES — solo parches de seguridad
# ============================================================================
# Mismo enfoque que Windows LTSC: solo seguridad, nunca features.
# Los orígenes permitidos son exclusivamente -security y ESM.

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UUEOF'
// ubuntu-advanced-install — actualizaciones LTSC (solo seguridad)
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Limpieza automática de kernels y deps no usados
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// NUNCA reiniciar automáticamente
Unattended-Upgrade::Automatic-Reboot "false";

// Aplicar en pasos mínimos (reduce riesgo de interrupciones)
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";

// Logging
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
UUEOF

# ============================================================================
# 3. ACTIVAR ACTUALIZACIONES DIARIAS
# ============================================================================

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AAEOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AAEOF

# ============================================================================
# 4. NEEDRESTART — modo pasivo (solo informar, nunca reiniciar)
# ============================================================================
# needrestart detecta servicios que necesitan reinicio tras parche.
# En modo "list" (l) solo muestra cuáles son, no reinicia nada.
# En modo "interactive" (i) preguntaría al usuario — no queremos eso
# en un sistema desktop donde apt se ejecuta en background.

if [ -f /etc/needrestart/needrestart.conf ]; then
    # Modo automático = lista (no reiniciar, no preguntar)
    sed -i "s/^#\?\$nrconf{restart}.*$/\$nrconf{restart} = 'l';/" /etc/needrestart/needrestart.conf
    # No reiniciar el kernel automáticamente
    sed -i "s/^#\?\$nrconf{kernelhints}.*$/\$nrconf{kernelhints} = 0;/" /etc/needrestart/needrestart.conf
fi

# ============================================================================
# 5. INDICADOR DE REBOOT PENDIENTE (motd + prompt)
# ============================================================================
# Si hay reboot pendiente, el usuario lo ve al abrir una terminal.
# No es un popup ni una notificación intrusiva — es un mensaje en motd.

cat > /etc/update-motd.d/98-reboot-required << 'MOTDEOF'
#!/bin/bash
if [ -f /var/run/reboot-required ]; then
    echo ""
    echo -e "\e[33m⚠  Reinicio pendiente — parches de seguridad aplicados\e[0m"
    echo -e "\e[2m   Reinicia cuando te venga bien: sudo reboot\e[0m"
    echo ""
fi
MOTDEOF
chmod 755 /etc/update-motd.d/98-reboot-required

# ============================================================================
# 6. BLOQUEAR SALTO DE RELEASE
# ============================================================================
# Evitar que do-release-upgrade salte de versión accidentalmente.
# El usuario puede desbloquearlo manualmente si quiere migrar.

cat > /etc/update-manager/release-upgrades << 'RELEASEEOF'
# ubuntu-advanced-install — salto de release bloqueado (enfoque LTSC)
# Para desbloquear: cambiar Prompt=never a Prompt=lts
[DEFAULT]
Prompt=never
RELEASEEOF

# ============================================================================
# 7. OCULTAR UPDATE-MANAGER DEL MENÚ
# ============================================================================
# Las actualizaciones van por unattended-upgrades, no por el GUI de Ubuntu.

if [ -f /usr/share/applications/update-manager.desktop ]; then
    sed -i '/^NoDisplay=/d' /usr/share/applications/update-manager.desktop
    echo "NoDisplay=true" >> /usr/share/applications/update-manager.desktop
fi

# Deshabilitar servicios de publicidad de Ubuntu
systemctl disable apt-news.service 2>/dev/null || true
systemctl disable esm-cache.service 2>/dev/null || true

echo ""
echo "✓  Actualizaciones configuradas (enfoque LTSC)"
UPDATEEOF

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ACTUALIZACIONES CONFIGURADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Seguridad automática: solo -security (diaria, background)"
echo "  Reboot: nunca forzado (indicador en terminal)"
echo "  Aplicaciones: topgrade manual cuando el usuario quiera"
echo "  Salto de release: bloqueado (Prompt=never)"
echo "  needrestart: modo pasivo (lista servicios, no reinicia)"
echo ""
echo "  Logs: /var/log/unattended-upgrades/unattended-upgrades.log"
echo ""

exit 0
