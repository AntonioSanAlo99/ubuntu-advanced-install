#!/bin/bash
# Módulo 03: Configurar sistema base - VERSIÓN ULTRA RÁPIDA
# Sin validaciones adicionales al original

source "$(dirname "$0")/../config.env"

# Hostname (exactamente como original)
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

arch-chroot "$TARGET" /bin/bash << 'EOF'
export DEBIAN_FRONTEND=noninteractive

RELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)

# Repositorios
cat > /etc/apt/sources.list << SOURCES
deb http://archive.ubuntu.com/ubuntu/ $RELEASE main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $RELEASE-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $RELEASE-security main restricted universe multiverse
SOURCES

# Update + upgrade + paquetes
apt update
apt upgrade -y
apt install -y locales language-pack-es

# Locale español
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=es_ES.UTF-8

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime

# Teclado español (solo consola)
apt install -y keyboard-configuration
debconf-set-selections << KBD
keyboard-configuration keyboard-configuration/xkb-keymap select es
KBD
dpkg-reconfigure -f noninteractive keyboard-configuration

# Usuario
useradd -m -G sudo -s /bin/bash $USERNAME 2>/dev/null || true
EOF

# Contraseñas (solo si existen)
[ -n "$USER_PASSWORD" ] && echo "$USERNAME:$USER_PASSWORD" | arch-chroot "$TARGET" chpasswd
[ -n "$ROOT_PASSWORD" ] && echo "root:$ROOT_PASSWORD" | arch-chroot "$TARGET" chpasswd

echo "✓ Sistema base configurado"
