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
read -p "Selecciona opción (1-3): " AUTO_UPDATE_CHOICE

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
REPLACE_UPDATES_LINE};

// Eliminar paquetes no usados automáticamente
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reiniciar automáticamente si necesario (a las 3am)
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

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

echo "  ✓ Actualizaciones automáticas activadas"
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
# NOTIFICACIÓN DE NUEVAS VERSIONES DE UBUNTU
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  NOTIFICACIÓN DE NUEVAS VERSIONES"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Cuando salga una nueva versión de Ubuntu, se creará un archivo"
echo "en el escritorio recordándote actualizar."
echo ""
read -p "¿Habilitar notificación de nuevas versiones? (S/n): " NOTIFY_RELEASES

if [ "$NOTIFY_RELEASES" != "n" ] && [ "$NOTIFY_RELEASES" != "N" ]; then
    echo ""
    echo "Configurando notificación de nuevas versiones..."
    
    arch-chroot "$TARGET" /bin/bash << 'RELEASE_NOTIFY_EOF'
# ============================================================================
# SCRIPT DE NOTIFICACIÓN DE NUEVAS VERSIONES
# ============================================================================

# Crear script que verifica nuevas versiones
cat > /usr/local/bin/check-ubuntu-release << 'CHECK_SCRIPT'
#!/bin/bash
# Script para notificar nuevas versiones de Ubuntu

# Solo ejecutar en sesión gráfica
[ -z "$DISPLAY" ] && exit 0

# Archivo de control
NOTIFIED_FILE="$HOME/.config/ubuntu-release-notified"
DESKTOP_FILE="$HOME/Desktop/Nueva-Version-Ubuntu.txt"

# Verificar si ya se notificó de esta versión
if [ -f "$NOTIFIED_FILE" ]; then
    NOTIFIED_VERSION=$(cat "$NOTIFIED_FILE")
else
    NOTIFIED_VERSION=""
fi

# Obtener versión actual
CURRENT_VERSION=$(lsb_release -rs)

# Verificar si hay nueva versión disponible
# update-manager-core proporciona esta funcionalidad
if command -v do-release-upgrade &> /dev/null; then
    # Verificar nueva versión (no interactivo)
    NEW_VERSION=$(do-release-upgrade -c 2>/dev/null | grep "New release" | grep -oP '\d+\.\d+' | head -1)
    
    if [ -n "$NEW_VERSION" ] && [ "$NEW_VERSION" != "$CURRENT_VERSION" ] && [ "$NEW_VERSION" != "$NOTIFIED_VERSION" ]; then
        # Nueva versión disponible y no notificada
        
        # Crear archivo en escritorio
        cat > "$DESKTOP_FILE" << DESKTOP_EOF
═══════════════════════════════════════════════════════════════
  NUEVA VERSIÓN DE UBUNTU DISPONIBLE
═══════════════════════════════════════════════════════════════

¡Hay una nueva versión de Ubuntu disponible!

Versión actual:    Ubuntu $CURRENT_VERSION
Nueva versión:     Ubuntu $NEW_VERSION

════════════════════════════════════════════════════════════════
CÓMO ACTUALIZAR
════════════════════════════════════════════════════════════════

Opción 1 - Interfaz Gráfica (Recomendado):
  1. Abrir "Configuración"
  2. Ir a "Acerca de"
  3. Click en "Buscar actualizaciones"
  4. Si aparece nueva versión, click en "Actualizar"

Opción 2 - Terminal:
  sudo do-release-upgrade

════════════════════════════════════════════════════════════════
IMPORTANTE
════════════════════════════════════════════════════════════════

Antes de actualizar:
  ✓ Haz copia de seguridad de tus datos importantes
  ✓ Cierra todas las aplicaciones abiertas
  ✓ Conecta el portátil a la corriente (si aplica)
  ✓ Asegúrate de tener buena conexión a internet
  ✓ Lee las notas de la versión: 
    https://ubuntu.com/desktop

La actualización puede tardar 30-60 minutos.

════════════════════════════════════════════════════════════════

Fecha de notificación: $(date '+%Y-%m-%d %H:%M:%S')

Este archivo se creó automáticamente.
Puedes eliminarlo después de actualizar o si decides no hacerlo.

════════════════════════════════════════════════════════════════
DESKTOP_EOF
        
        # Hacer el archivo visible en escritorio
        chmod 644 "$DESKTOP_FILE"
        
        # Marcar como notificado
        echo "$NEW_VERSION" > "$NOTIFIED_FILE"
        
        # Notificación del sistema (si está disponible)
        if command -v notify-send &> /dev/null; then
            notify-send -u normal -i system-software-update \
                "Nueva versión de Ubuntu" \
                "Ubuntu $NEW_VERSION está disponible. Ver archivo en escritorio."
        fi
    fi
fi
CHECK_SCRIPT

chmod +x /usr/local/bin/check-ubuntu-release

# ============================================================================
# AUTOSTART PARA VERIFICAR EN CADA INICIO
# ============================================================================

# Crear entrada de autostart para todos los usuarios
mkdir -p /etc/skel/.config/autostart

cat > /etc/skel/.config/autostart/check-ubuntu-release.desktop << 'AUTOSTART_DESKTOP'
[Desktop Entry]
Type=Application
Name=Check Ubuntu Release
Comment=Check for new Ubuntu releases
Exec=/usr/local/bin/check-ubuntu-release
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=30
AUTOSTART_DESKTOP

# Copiar también al usuario actual
USERNAME=$(grep "1000" /etc/passwd | cut -d: -f1)
if [ -n "$USERNAME" ]; then
    mkdir -p /home/$USERNAME/.config/autostart
    cp /etc/skel/.config/autostart/check-ubuntu-release.desktop \
       /home/$USERNAME/.config/autostart/
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
fi

echo "  ✓ Notificación de nuevas versiones configurada"
echo "  Archivo aparecerá en escritorio cuando haya nueva versión"

RELEASE_NOTIFY_EOF

else
    echo ""
    echo "Notificación de nuevas versiones NO configurada"
fi

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
    echo "  ✓ Reinicio automático a las 3:00 AM si necesario"
    echo "  ✓ Limpieza automática de paquetes no usados"
elif [ "$AUTO_UPDATE_CHOICE" = "2" ]; then
    echo "Actualizaciones automáticas:"
    echo "  ✓ Actualizaciones de seguridad + actualizaciones estables"
    echo "  ✓ Instaladas automáticamente cada día"
    echo "  ✓ Reinicio automático a las 3:00 AM si necesario"
    echo "  ✓ Limpieza automática de paquetes no usados"
else
    echo "Actualizaciones automáticas:"
    echo "  ✗ No configuradas"
fi

echo ""

if [ "$NOTIFY_RELEASES" != "n" ] && [ "$NOTIFY_RELEASES" != "N" ]; then
    echo "Notificación de nuevas versiones:"
    echo "  ✓ Archivo .txt se creará en escritorio"
    echo "  ✓ Verificación en cada inicio de sesión"
    echo "  ✓ Notificación del sistema"
else
    echo "Notificación de nuevas versiones:"
    echo "  ✗ No configurada"
fi

echo ""
echo "Ver logs de actualizaciones:"
echo "  sudo cat /var/log/unattended-upgrades/unattended-upgrades.log"
echo ""

exit 0
