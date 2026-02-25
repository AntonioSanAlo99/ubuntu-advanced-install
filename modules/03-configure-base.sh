#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO: 03-configure-base.sh
# DESCRIPCIÓN: Configuración del sistema base: locale, timezone, teclado, usuario
# DEPENDENCIAS: 02-debootstrap.sh
# VARIABLES REQUERIDAS: TARGET, HOSTNAME, USERNAME
# ══════════════════════════════════════════════════════════════════════════════
#
# CAMBIOS vs versión anterior:
#   - Locales configurados en bloque PREVIO y SEPARADO antes de cualquier apt
#   - locales y console-data instalados explícitamente (no asumir que existen)
#   - DEBIAN_FRONTEND=noninteractive aplicado como variable de entorno de apt,
#     no solo como export dentro del chroot (evita que scripts postinstall ignoren)
#   - El orden correcto elimina los warnings "Cannot set LC_*" durante instalación
#   - Timezone e idioma siguen siendo es_ES / Europe/Madrid (uso personal)
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/../partition.info" ] && source "${SCRIPT_DIR}/../partition.info"

C_OK='\033[0;32m'; C_WARN='\033[0;33m'; C_INFO='\033[0;34m'
C_HIGH='\033[0;36m'; C_RESET='\033[0m'; C_BOLD='\033[1m'

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}  CONFIGURACIÓN DEL SISTEMA BASE${C_RESET}"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""

# ── Hostname (en el host, sin chroot) ─────────────────────────────────────────
echo "$HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF
echo -e "${C_OK}✓${C_RESET}  Hostname: $HOSTNAME"

# ══════════════════════════════════════════════════════════════════════════════

# ── Configurar barra de progreso apt en el chroot ────────────────────────────
# Se hace aquí porque 03 es el primer módulo que usa apt dentro del chroot.
# debootstrap crea el directorio /etc/apt/apt.conf.d pero puede estar vacío.
mkdir -p "$TARGET/etc/apt/apt.conf.d"
cat > "$TARGET/etc/apt/apt.conf.d/99-installer-progress" << 'APT_CONF'
// Barra de progreso dpkg — activada por ubuntu-advanced-install
Dpkg::Progress-Fancy "1";
APT::Color "1";
APT_CONF
echo -e "${C_OK}✓${C_RESET}  Barra de progreso apt configurada"

# BLOQUE 1 — LOCALE ANTES DE CUALQUIER APT
# Esto es lo que elimina los warnings "Cannot set LC_*"
# Debe ser el primer bloque chroot del módulo, sin ningún apt previo
# Heredoc sin comillas: necesita $TARGET implícitamente vía arch-chroot
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Configurando locale antes de cualquier instalación de paquetes..."

arch-chroot "$TARGET" /bin/bash << 'LOCALE_FIRST'

# Paso 1: establecer locale mínimo válido para silenciar warnings inmediatos
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Paso 2: asegurar que el paquete locales está instalado
# debootstrap no garantiza su presencia — sin él locale-gen no existe
DEBIAN_FRONTEND=noninteractive apt-get install -y locales 2>/dev/null

# Paso 3: configurar qué locales generar
echo "es_ES.UTF-8 UTF-8" > /etc/locale.gen

# Paso 4: generar el locale — a partir de aquí es_ES.UTF-8 existe en el sistema
locale-gen es_ES.UTF-8

# Paso 5: activar como locale del sistema
cat > /etc/default/locale << 'LOCALE_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_ALL=
LOCALE_EOF

# Paso 6: actualizar /etc/environment con el locale correcto
cat > /etc/environment << 'ENV_EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
ENV_EOF

# Paso 7: locale.conf para compatibilidad con systemd y aplicaciones
cat > /etc/locale.conf << 'LCONF_EOF'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_CTYPE=es_ES.UTF-8
LC_NUMERIC=es_ES.UTF-8
LC_TIME=es_ES.UTF-8
LC_COLLATE=es_ES.UTF-8
LC_MONETARY=es_ES.UTF-8
LC_MESSAGES=es_ES.UTF-8
LC_PAPER=es_ES.UTF-8
LC_NAME=es_ES.UTF-8
LC_ADDRESS=es_ES.UTF-8
LC_TELEPHONE=es_ES.UTF-8
LC_MEASUREMENT=es_ES.UTF-8
LC_IDENTIFICATION=es_ES.UTF-8
LCONF_EOF

# Activar el locale en el entorno actual del chroot para el resto de módulos
export LANG=es_ES.UTF-8
export LANGUAGE=es_ES:es
unset LC_ALL

echo "✓  Locale es_ES.UTF-8 generado y activo"
LOCALE_FIRST

echo -e "${C_OK}✓${C_RESET}  Locale configurado — los warnings de LC_* no aparecerán en módulos siguientes"

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 2 — TIMEZONE, TECLADO Y PAQUETES DE IDIOMA
# A partir de aquí apt ya trabaja con es_ES.UTF-8 activo
# Heredoc sin comillas: mismo razonamiento
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Configurando timezone, teclado y paquetes de idioma..."

arch-chroot "$TARGET" /bin/bash << 'BASE_CONFIG'
export DEBIAN_FRONTEND=noninteractive
export LANG=es_ES.UTF-8
export LANGUAGE=es_ES:es

# ── Timezone ──────────────────────────────────────────────────────────────────
ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
hwclock --systohc 2>/dev/null || true
echo "✓  Timezone: Europe/Madrid"

# ── Repositorios ──────────────────────────────────────────────────────────────
RELEASE=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

mkdir -p /etc/apt/sources.list.d
cat > /etc/apt/sources.list.d/ubuntu.sources << SOURCES_EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: $RELEASE ${RELEASE}-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${RELEASE}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SOURCES_EOF

apt-get update -qq
echo "✓  Repositorios actualizados"

# ── Actualización completa del sistema base ───────────────────────────────────
# Se ejecuta tras configurar repositorios y antes de instalar cualquier paquete.
# Garantiza que el sistema arranque sin actualizaciones pendientes.
# full-upgrade en lugar de upgrade: resuelve cambios de dependencias entre paquetes.
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
echo "✓  Sistema base actualizado a la última versión disponible"

# ── Teclado de consola (TTY) ──────────────────────────────────────────────────
# console-data: mapas de teclado para TTY
# console-setup: configura la fuente y el mapa al arrancar
# keyboard-configuration: gestiona /etc/default/keyboard para setupcon
apt-get install -y console-data console-setup keyboard-configuration

cat > /etc/default/keyboard << 'KBD_EOF'
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD_EOF

# Aplicar configuración de teclado en consola
setupcon -k --force 2>/dev/null || true

# Teclado para X11/Wayland
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11KBD_EOF'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11KBD_EOF

echo "✓  Teclado: Español (es) — TTY y X11/Wayland"

# ── Language packs y gettext en español ──────────────────────────────────────
# language-pack-es: traducciones de aplicaciones del sistema
# language-pack-gnome-es: traducciones específicas de aplicaciones GNOME
# gettext: herramienta base del sistema de traducción (normalmente ya instalada)
# Juntos garantizan que las aplicaciones muestren mensajes en español
apt-get install -y \
    language-pack-es \
    language-pack-es-base \
    language-pack-gnome-es \
    language-pack-gnome-es-base \
    gettext

# Actualizar traducciones instaladas
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

echo "✓  Language packs y gettext instalados"

BASE_CONFIG

echo -e "${C_OK}✓${C_RESET}  Timezone, teclado e idioma configurados"

# ══════════════════════════════════════════════════════════════════════════════
# BLOQUE 3 — USUARIO
# Heredoc SIN comillas simples en el exterior: necesita $USERNAME, $TARGET
# El bloque interior de contraseñas usa su propio contexto
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_INFO}ℹ${C_RESET}  Creando usuario $USERNAME..."

if [ -n "${USER_PASSWORD:-}" ] && [ -n "${ROOT_PASSWORD:-}" ]; then
    # Contraseñas desde config.env — heredoc sin comillas: expande $USERNAME,
    # $USER_PASSWORD y $ROOT_PASSWORD desde el host
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "root:$ROOT_PASSWORD" | chpasswd
USEREOF
    echo -e "${C_OK}✓${C_RESET}  Usuario: $USERNAME (contraseña desde config.env)"
    echo -e "${C_WARN}⚠${C_RESET}  Elimina config.env después de la instalación: rm config.env"
else
    # Sin contraseñas en config.env — las pide interactivamente
    # Heredoc sin comillas: expande $USERNAME desde el host
    arch-chroot "$TARGET" /bin/bash << USEREOF
useradd -m -G sudo,adm,audio,video,plugdev -s /bin/bash "$USERNAME"
echo ""
echo "Contraseña para $USERNAME:"
passwd "$USERNAME"
echo ""
echo "Contraseña para root:"
passwd root
USEREOF
    echo -e "${C_OK}✓${C_RESET}  Usuario: $USERNAME creado"
fi

echo ""
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_OK}✓${C_RESET}  SISTEMA BASE CONFIGURADO"
echo -e "${C_HIGH}${C_BOLD}════════════════════════════════════════════════════════════════${C_RESET}"
echo ""
echo "  Hostname:  $HOSTNAME"
echo "  Usuario:   $USERNAME"
echo "  Locale:    es_ES.UTF-8"
echo "  Timezone:  Europe/Madrid"
echo "  Teclado:   Español pc105 (TTY + X11/Wayland)"
echo ""

exit 0
