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
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# LOCALES - Configuración según Arch Wiki y Gentoo Handbook (systemd)
# ============================================================================
echo "Configurando locales..."

# 1. Editar /etc/locale.gen (activar es_ES.UTF-8)
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 2. Generar locales
locale-gen

# 3. Crear /etc/locale.conf (método systemd estándar)
cat > /etc/locale.conf << 'LOCALE_CONF'
LANG=es_ES.UTF-8
LOCALE_CONF

# 4. Aplicar con localectl (systemd)
localectl set-locale LANG=es_ES.UTF-8

echo "✓ Locale configurado: es_ES.UTF-8"

# ============================================================================
# AHORA SÍ: apt update y repositorios
# ============================================================================
echo "Verificando repositorios..."

# Verificar que sources.list tiene todos los componentes
if ! grep -q "universe" /etc/apt/sources.list; then
    echo "⚠ Repositorios incompletos, actualizando..."
    RELEASE=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)
    cat > /etc/apt/sources.list << SOURCES_EOF
deb http://archive.ubuntu.com/ubuntu/ $RELEASE main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $RELEASE-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $RELEASE-security main restricted universe multiverse
SOURCES_EOF
fi

apt update && apt upgrade -y
echo "✓ Sistema actualizado"

# Instalar paquete locales si debootstrap no lo incluyó
if ! dpkg -l locales 2>/dev/null | grep -q "^ii"; then
    echo "Instalando paquete locales..."
    apt install -y locales
fi

# ============================================================================
# PAQUETES DE IDIOMA ESPAÑOL
# locale-gen solo genera el locale para Perl/libc.
# Sin los language-pack el sistema arranca en inglés porque GNOME,
# GTK, Qt y las apps buscan las traducciones en estos paquetes.
# ============================================================================
echo "Instalando paquetes de idioma español..."

apt install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base \
    hunspell-es \
    hyphen-es \
    mythes-es

# Páginas de manual en español (opcional, descomenta si las necesitas)
# Las páginas man ocupan ~50MB y no todos los comandos tienen traducción
# apt install -y manpages-es manpages-es-extra

echo "✓ Paquetes de idioma español instalados"
# echo "✓ Páginas de manual en español instaladas"

# ============================================================================
# CONFIGURAR GETTY (TTY) PARA MOSTRAR MENSAJES EN ESPAÑOL
# ============================================================================

# Crear drop-in para todas las getty
mkdir -p /etc/systemd/system/getty@.service.d/

echo "✓ Paquetes de idioma español instalados"

CHROOT_EOF

# Timezone y locale
arch-chroot "$TARGET" /bin/bash << 'LOCALE_EOF'
export DEBIAN_FRONTEND=noninteractive
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "✓ Timezone configurado: Europe/Madrid"
LOCALE_EOF

# ============================================================================
# CONFIGURACIÓN DE TECLADO - Español de España
# ============================================================================

echo "Configurando distribución de teclado..."

arch-chroot "$TARGET" /bin/bash << 'KEYBOARD_EOF'
export DEBIAN_FRONTEND=noninteractive

# Instalar paquete keyboard-configuration si no está
apt-get install -y keyboard-configuration console-setup

# Configurar teclado español para consola (TTY)
cat > /etc/default/keyboard << 'KBD_EOF'
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
KBD_EOF

# Aplicar configuración de teclado
setupcon -k --force || true

# Crear /etc/vconsole.conf (método Arch/systemd para consola virtual)
cat > /etc/vconsole.conf << 'VCONSOLE_EOF'
KEYMAP=es
FONT=eurlatgr
VCONSOLE_EOF

# Configurar también para X11/Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11_EOF

# Asegurar que localectl también lo refleja (systemd)
localectl set-keymap es || true
localectl set-x11-keymap es pc105 || true

echo "✓ Teclado configurado: Español (consola + X11 + Wayland)"

KEYBOARD_EOF

echo "✓ Distribución de teclado: es (España)"

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
