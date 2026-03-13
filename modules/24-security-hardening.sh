#!/bin/bash
# Módulo 24: Hardening de seguridad

set -e  # Exit on error  # Detectar errores en pipelines

# Cargar variables de particionado
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# Variables se pasan desde install.sh via environment
# source "$(dirname "$0")/../config.env"

echo "Aplicando hardening de seguridad..."

arch-chroot "$TARGET" /bin/bash << 'CHROOTEOF'


# === HARDENING DEL KERNEL ===
cat > /etc/sysctl.d/99-security-hardening.conf << 'SYSCTL_EOF'
# Hardening de seguridad del kernel

# Protección contra IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# No aceptar ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Protección SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Log paquetes sospechosos
net.ipv4.conf.all.log_martians = 1

# Ignorar ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# ASLR
kernel.randomize_va_space = 2

# Restringir acceso a información del kernel
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
SYSCTL_EOF

# Habilitar actualizaciones automáticas de seguridad si no están ya configuradas
# (el módulo 06-configure-auto-updates.sh puede haberlas configurado ya)
# Se usa DEBIAN_FRONTEND=noninteractive para evitar prompts interactivos
if ! [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    apt install -y unattended-upgrades
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -pcritical unattended-upgrades
fi

# ============================================================================
# USBGUARD — control de autorización de dispositivos USB
# ============================================================================
# USBGuard intercepta la conexión de nuevos dispositivos USB y los bloquea
# hasta que el usuario los autorice explícitamente, previniendo ataques
# BadUSB y acceso no autorizado por hardware externo.
#
# Política inicial: se generan reglas que permiten todos los dispositivos
# USB actualmente conectados en el momento de la instalación (teclado, ratón,
# etc.) — sin esta política initial el sistema podría quedarse sin input.
# Los dispositivos nuevos que se conecten después requerirán autorización
# manual via `usbguard allow-device <id>` o la GUI usbguard-applet.
#
# Integración con GNOME: usbguard-applet-qt no existe como paquete Ubuntu;
# la gestión se hace desde terminal o desde GNOME Settings con polkit.
# ============================================================================

export DEBIAN_FRONTEND=noninteractive
apt-get install -y usbguard

# Generar política inicial permitiendo los dispositivos ya conectados.
# usbguard generate-policy lee los dispositivos del kernel en /sys/bus/usb
# y emite reglas "allow" para cada uno — garantiza que el teclado y ratón
# actuales no queden bloqueados tras activar el servicio.
#
# Se ejecuta antes de habilitar el servicio para que rules.conf exista.
# Si no hay dispositivos USB (VM, contenedor), el archivo queda vacío — válido.
mkdir -p /etc/usbguard
usbguard generate-policy > /etc/usbguard/rules.conf 2>/dev/null || \
    echo "# Política vacía — no hay dispositivos USB detectados en la instalación" \
    > /etc/usbguard/rules.conf

# Permisos: solo root puede leer/escribir las reglas
chmod 600 /etc/usbguard/rules.conf
chmod 700 /etc/usbguard

# Configuración del daemon
# IPCAllowedUsers: el grupo del usuario normal puede consultar el estado
# pero no modificar reglas (solo root via sudo)
cat > /etc/usbguard/usbguard-daemon.conf << 'USBCONF'
RuleFile=/etc/usbguard/rules.conf
ImplicitPolicyTarget=block
PresentDevicePolicy=apply-policy
PresentControllerPolicy=keep
InsertedDevicePolicy=apply-policy
RestoreControllerDeviceState=false
DeviceManagerBackend=uevent
IPCAllowedUsers=root
IPCAllowedGroups=sudo
DeviceRulesWithPort=false
AuditBackend=FileAudit
AuditFilePath=/var/log/usbguard/usbguard-audit.log
USBCONF

mkdir -p /var/log/usbguard

# Habilitar servicio — arranca con el sistema
systemctl enable usbguard 2>/dev/null || true

echo "✓  USBGuard instalado y configurado"
echo "   Política: dispositivos actuales permitidos, nuevos bloqueados"
echo "   Gestión:  usbguard list-devices / usbguard allow-device <id>"

echo "✓  Hardening de seguridad aplicado"
CHROOTEOF

echo "✓  Sistema endurecido (protecciones de red, kernel y USB)"

exit 0
