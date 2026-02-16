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

echo "✓ Hostname configurado: $HOSTNAME"

# Verificar y actualizar repositorios
arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
echo "Verificando repositorios..."

# Verificar que sources.list tiene todos los componentes
if ! grep -q "universe" /etc/apt/sources.list; then
    echo "⚠ Repositorios incompletos, actualizando..."
    cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
fi

echo "✓ Repositorios verificados"

# Actualizar índice de paquetes
apt update

echo "✓ Índice de paquetes actualizado"
CHROOT_EOF

# Timezone y locale
arch-chroot "$TARGET" /bin/bash << 'LOCALE_EOF'
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime

# Instalar locales si no está
if ! dpkg -l | grep -q "^ii.*locales"; then
    apt install -y locales
fi

locale-gen es_ES.UTF-8
update-locale LANG=es_ES.UTF-8

echo "✓ Timezone y locale configurados"
LOCALE_EOF

# Crear usuario
arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash $USERNAME

echo "Establecer contraseña para $USERNAME:"
passwd $USERNAME

echo "Establecer contraseña para root:"
passwd root

echo "✓ Usuario $USERNAME creado"
USEREOF

echo ""
echo "✓✓✓ Sistema base configurado ✓✓✓"
echo ""
echo "Configuración aplicada:"
echo "  • Hostname: $HOSTNAME"
echo "  • Usuario: $USERNAME"
echo "  • Locale: es_ES.UTF-8"
echo "  • Timezone: Europe/Madrid"
echo "  • Repositorios: main, restricted, universe, multiverse"
