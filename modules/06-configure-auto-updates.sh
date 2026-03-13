#!/bin/bash
# Módulo 06: Configurar actualizaciones automáticas

set -e

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ACTUALIZACIONES AUTOMÁTICAS"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Las actualizaciones automáticas mantienen el sistema seguro"
echo "instalando automáticamente actualizaciones de seguridad."
echo ""
echo "Opciones:"
echo "  1) Solo actualizaciones de seguridad (recomendado)"
echo "  2) Todas las actualizaciones estables"
echo "  3) No configurar actualizaciones automáticas"
echo ""

if [ -z "$AUTO_UPDATE_CHOICE" ]; then
    read -p "Selecciona opción (1-3): " AUTO_UPDATE_CHOICE
fi

case $AUTO_UPDATE_CHOICE in
    1|2)
        echo ""
        echo "Configurando actualizaciones automáticas..."
        
        arch-chroot "$TARGET" /bin/bash << 'AUTO_UPDATE_EOF'
export DEBIAN_FRONTEND=noninteractive

# Instalar unattended-upgrades
apt-get install -y unattended-upgrades apt-listchanges

# ============================================================================
# CONFIGURACIÓN DE ACTUALIZACIONES AUTOMÁTICAS
# ============================================================================

# Archivo principal de configuración
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UNATTENDED_EOF'
// Actualizaciones automáticas configuradas por instalador Ubuntu Advanced
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
    "Google LLC:stable";
    "Microsoft Corporation:packages.microsoft.com";
REPLACE_UPDATES_LINE};

// Eliminar paquetes no usados automáticamente
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reinicio automático desactivado — en un sistema desktop/gaming el usuario
// puede estar en medio de una sesión. Se notificará que hay reboot pendiente.
Unattended-Upgrade::Automatic-Reboot "false";

// Notificaciones por email (deshabilitado - requiere configurar email)
// Unattended-Upgrade::Mail "";

// Limpiar cache automáticamente
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";

// Logging
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
UNATTENDED_EOF

# Habilitar actualizaciones según elección del usuario
AUTO_UPDATE_EOF

        if [ "$AUTO_UPDATE_CHOICE" = "2" ]; then
            # Opción 2: Todas las actualizaciones estables
            arch-chroot "$TARGET" /bin/bash << 'STABLE_UPDATES_EOF'
# Añadir actualizaciones estables (updates)
sed -i 's/REPLACE_UPDATES_LINE/    "${distro_id}:${distro_codename}-updates";/' /etc/apt/apt.conf.d/50unattended-upgrades
STABLE_UPDATES_EOF
            echo "  ✓ Configurado: Actualizaciones de seguridad + actualizaciones estables"
        else
            # Opción 1: Solo seguridad
            arch-chroot "$TARGET" /bin/bash << 'SECURITY_ONLY_EOF'
# Solo seguridad (eliminar línea REPLACE)
sed -i '/REPLACE_UPDATES_LINE/d' /etc/apt/apt.conf.d/50unattended-upgrades
SECURITY_ONLY_EOF
            echo "  ✓ Configurado: Solo actualizaciones de seguridad"
        fi

        # Activar actualizaciones automáticas
        arch-chroot "$TARGET" /bin/bash << 'ENABLE_AUTO_EOF'
# Archivo de activación
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTO_ENABLE_EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTO_ENABLE_EOF

# update-notifier no se instala (deprecado — usa libayatana-indicator obsoleto)
# update-manager se oculta del menú — las actualizaciones van por unattended-upgrades
if [ -f /usr/share/applications/update-manager.desktop ]; then
    sed -i '/^NoDisplay=/d' /usr/share/applications/update-manager.desktop
    echo "NoDisplay=true" >> /usr/share/applications/update-manager.desktop
fi
systemctl disable apt-news.service 2>/dev/null || true
systemctl disable esm-cache.service 2>/dev/null || true

echo "  ✓ Actualizaciones automáticas activadas"
echo "  ✓ update-manager ocultado del menú"
ENABLE_AUTO_EOF
        ;;
    3)
        echo ""
        echo "Actualizaciones automáticas NO configuradas"
        echo "Puedes configurarlas manualmente después con:"
        echo "  sudo dpkg-reconfigure unattended-upgrades"
        ;;
    *)
        echo ""
        echo "Opción no válida, omitiendo actualizaciones automáticas"
        ;;
esac

# ============================================================================
# RESUMEN
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  ACTUALIZACIONES CONFIGURADAS"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$AUTO_UPDATE_CHOICE" = "1" ]; then
    echo "Actualizaciones automáticas:"
    echo "  ✓ Solo actualizaciones de seguridad"
    echo "  ✓ Instaladas automáticamente cada día"
    echo "  ✓ Sin reinicio automático (se notifica al usuario)"
    echo "  ✓ Limpieza automática de paquetes no usados"
elif [ "$AUTO_UPDATE_CHOICE" = "2" ]; then
    echo "Actualizaciones automáticas:"
    echo "  ✓ Actualizaciones de seguridad + actualizaciones estables"
    echo "  ✓ Instaladas automáticamente cada día"
    echo "  ✓ Sin reinicio automático (se notifica al usuario)"
    echo "  ✓ Limpieza automática de paquetes no usados"
else
    echo "Actualizaciones automáticas:"
    echo "  ✗ No configuradas"
fi

echo ""

echo ""
echo "Ver logs de actualizaciones:"
echo "  sudo cat /var/log/unattended-upgrades/unattended-upgrades.log"
echo ""

exit 0
