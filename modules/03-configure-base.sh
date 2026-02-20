#!/bin/bash
# Módulo 03: Configurar sistema base - VERSIÓN CORREGIDA

source "$(dirname "$0")/../config.env"

echo "Configurando sistema base..."

# Hostname
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

echo "✓ Hostname configurado: $HOSTNAME"

# Único chroot con ORDEN CORRECTO de operaciones
arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

echo "Configurando locales..."

# 1. PRIMERO: Configurar repositorios y actualizar
RELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)

cat > /etc/apt/sources.list << SOURCES_EOF
deb http://archive.ubuntu.com/ubuntu/ $RELEASE main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $RELEASE-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $RELEASE-security main restricted universe multiverse
SOURCES_EOF

apt update
echo "✓ Repositorios actualizados"

# 2. SEGUNDO: Instalar locales ANTES de generarlos
apt install -y locales
echo "✓ Paquete locales instalado"

# 3. TERCERO: Generar locale español
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
locale-gen es_ES.UTF-8
echo "✓ Locale es_ES.UTF-8 generado"

# 4. CUARTO: Configurar locale del sistema (ESTO EVITA LOS WARNINGS)
update-locale LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8
export LANG=es_ES.UTF-8
export LC_ALL=es_ES.UTF-8

# 5. QUINTO: Instalar paquetes de idioma (AHORA sin warnings)
apt install -y language-pack-es language-pack-es-base
echo "✓ Paquetes de idioma español instalados"

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "✓ Timezone configurado: Europe/Madrid"

# Teclado
echo "Configurando distribución de teclado..."
apt install -y keyboard-configuration
debconf-set-selections << KEYBOARD_EOF
keyboard-configuration keyboard-configuration/xkb-keymap select es
KEYBOARD_EOF
dpkg-reconfigure -f noninteractive keyboard-configuration
echo "✓ Teclado configurado: Español"

# Crear usuario con contraseña
echo "Creando usuario $USERNAME..."

if [ -n "$USER_PASSWORD" ] && [ -n "$ROOT_PASSWORD" ]; then
    # Contraseñas desde config.env
    echo "Usando contraseñas de config.env..."
    
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME

# Establecer contraseñas automáticamente
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd

echo "✓ Usuario $USERNAME creado con contraseña configurada"
echo "✓ Contraseña de root configurada"
USEREOF

    echo ""
    echo -e "\033[0;33m⚠ SEGURIDAD: Elimina config.env después de la instalación\033[0m"
    echo -e "\033[0;33m  rm $(dirname "$0")/../config.env\033[0m"
    
else
    # Pedir contraseñas interactivamente
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME

echo ""
echo "Establecer contraseña para $USERNAME:"
passwd $USERNAME

echo ""
echo "Establecer contraseña para root:"
passwd root

echo "✓ Usuario $USERNAME creado"
USEREOF
fi

echo ""
echo "✓✓✓ Sistema base configurado ✓✓✓"
echo ""
echo "Configuración aplicada:"
echo "  • Hostname: $HOSTNAME"
echo "  • Usuario: $USERNAME"
echo "  • Locale: es_ES.UTF-8"
echo "  • Timezone: Europe/Madrid"
echo "  • Teclado: Español (es)"
echo "  • Repositorios: main, restricted, universe, multiverse"
echo ""
