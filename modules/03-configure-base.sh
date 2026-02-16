#!/bin/bash
# Módulo 03: Configurar sistema base

source "$(dirname "$0")/../config.env"

echo "Configurando sistema base..."

# Hostname
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

# Timezone y locale
arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
apt update
apt install -y locales
locale-gen es_ES.UTF-8
update-locale LANG=es_ES.UTF-8
CHROOT_EOF

# Crear usuario
arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME
echo "Establecer contraseña para $USERNAME:"
passwd $USERNAME
echo "Establecer contraseña para root:"
passwd root
USEREOF

echo "✓ Sistema base configurado"
