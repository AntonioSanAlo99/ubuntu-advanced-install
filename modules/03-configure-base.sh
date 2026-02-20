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
# LOCALES - Método oficial de Ubuntu (wiki.ubuntu.com)
# Basado en: Ubuntu Development Internationalization Primer
# ============================================================================
echo "Configurando locales (método oficial Ubuntu)..."

# 1. Activar locale en /etc/locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 2. Generar locales
locale-gen

# 3. Configurar /etc/default/locale (método Ubuntu oficial)
# LANG: idioma principal
# LANGUAGE: lista de fallbacks (es_ES:es → español España, luego español genérico)
cat > /etc/default/locale << 'LOCALE_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LOCALE_EOF

# 4. update-locale (actualiza /etc/default/locale de forma segura)
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

# 5. vconsole.conf para systemd (teclado en consola TTY)
cat > /etc/vconsole.conf << 'VCONSOLE_EOF'
KEYMAP=es
FONT=eurlatgr
VCONSOLE_EOF

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

apt update -qq
echo "✓ Índice de paquetes actualizado"

# Instalar paquete locales si debootstrap no lo incluyó
if ! dpkg -l locales 2>/dev/null | grep -q "^ii"; then
    echo "Instalando paquete locales..."
    apt install -y locales
fi

# ============================================================================
# LANGUAGE PACKS (traducciones de aplicaciones)
# 
# Ubuntu separa locale (formato) de traducciones (gettext):
# - locale-gen: genera el locale para formato de fecha/número/etc
# - language-pack-*: provee traducciones de aplicaciones (.mo files)
# 
# Sin language packs, el sistema puede estar en español (locale) pero las
# aplicaciones en inglés (sin traducciones).
# 
# Referencia: https://wiki.ubuntu.com/LanguagePacks
# ============================================================================
echo "Instalando language packs (traducciones)..."

apt install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base \
    hunspell-es \
    hyphen-es \
    mythes-es

echo "✓ Language packs instalados"
echo "  Traducciones disponibles en: /usr/share/locale/es_ES/LC_MESSAGES/"

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
