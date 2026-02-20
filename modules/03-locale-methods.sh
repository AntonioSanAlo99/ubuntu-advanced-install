#!/bin/bash
# Métodos de configuración de locales - Testing y comparación

# Este archivo NO se ejecuta automáticamente
# Es para testing y entender qué método funciona mejor

set -e

TARGET="${1:-/mnt}"
LOCALE="es_ES.UTF-8"

# ============================================================================
# MÉTODO 1: ARCH STYLE (systemd puro)
# ============================================================================
method_arch() {
    echo "════════════════════════════════════════════════════════════════"
    echo "MÉTODO 1: ARCH STYLE (systemd estándar)"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# 1. Editar /etc/locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 2. Generar locales
locale-gen

# 3. /etc/locale.conf (systemd)
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf

# 4. localectl (systemd)
localectl set-locale LANG=es_ES.UTF-8

# 5. vconsole.conf (teclado consola)
cat > /etc/vconsole.conf << 'VCONSOLE'
KEYMAP=es
FONT=eurlatgr
VCONSOLE

echo "✓ Método Arch completado"
echo ""
echo "Archivos creados:"
ls -la /etc/locale.conf /etc/vconsole.conf 2>/dev/null || true
echo ""
echo "Verificación:"
localectl status
CHROOT_EOF
}

# ============================================================================
# MÉTODO 2: DEBIAN STYLE (reconfigure)
# ============================================================================
method_debian() {
    echo "════════════════════════════════════════════════════════════════"
    echo "MÉTODO 2: DEBIAN STYLE (dpkg-reconfigure)"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# 1. Verificar que locales esté instalado
if ! dpkg -l locales 2>/dev/null | grep -q "^ii"; then
    echo "Instalando paquete locales..."
    apt-get update -qq
    apt-get install -y locales
fi

# 2. Configurar locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 3. Generar locales
locale-gen

# 4. /etc/default/locale (Debian way)
cat > /etc/default/locale << 'LOCALE'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LOCALE

# 5. update-locale (Debian)
update-locale LANG=es_ES.UTF-8

# 6. Reconfigure locales (Debian)
dpkg-reconfigure -f noninteractive locales

echo "✓ Método Debian completado"
echo ""
echo "Archivos creados:"
ls -la /etc/default/locale 2>/dev/null || true
echo ""
echo "Contenido:"
cat /etc/default/locale
CHROOT_EOF
}

# ============================================================================
# MÉTODO 3: HYBRID (Arch + Debian compatibility)
# ============================================================================
method_hybrid() {
    echo "════════════════════════════════════════════════════════════════"
    echo "MÉTODO 3: HYBRID (Arch systemd + Debian compatibility)"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# 1. Locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 2. Generar
locale-gen

# 3. /etc/locale.conf (systemd - prioritario)
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf

# 4. /etc/default/locale (Debian compatibility - fallback)
echo 'LANG=es_ES.UTF-8' > /etc/default/locale

# 5. localectl
localectl set-locale LANG=es_ES.UTF-8

# 6. vconsole.conf
cat > /etc/vconsole.conf << 'VCONSOLE'
KEYMAP=es
FONT=eurlatgr
VCONSOLE

echo "✓ Método Hybrid completado"
echo ""
echo "Archivos creados:"
ls -la /etc/locale.conf /etc/default/locale /etc/vconsole.conf 2>/dev/null || true
CHROOT_EOF
}

# ============================================================================
# MÉTODO 4: EXPORT STYLE (variables de entorno)
# ============================================================================
method_export() {
    echo "════════════════════════════════════════════════════════════════"
    echo "MÉTODO 4: EXPORT STYLE (variables de entorno)"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# 1. Locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
grep -q "^es_ES.UTF-8" /etc/locale.gen || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen

# 2. Generar
locale-gen

# 3. /etc/environment (variables globales)
cat > /etc/environment << 'ENV'
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
LC_ALL=es_ES.UTF-8
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV

# 4. /etc/profile.d/locale.sh (para shells)
cat > /etc/profile.d/locale.sh << 'PROFILE'
export LANG=es_ES.UTF-8
export LANGUAGE=es_ES:es
export LC_ALL=es_ES.UTF-8
PROFILE

chmod +x /etc/profile.d/locale.sh

echo "✓ Método Export completado"
echo ""
echo "Archivos creados:"
ls -la /etc/environment /etc/profile.d/locale.sh 2>/dev/null || true
echo ""
echo "Contenido /etc/environment:"
cat /etc/environment
CHROOT_EOF
}

# ============================================================================
# MÉTODO 5: MINIMAL (solo lo esencial)
# ============================================================================
method_minimal() {
    echo "════════════════════════════════════════════════════════════════"
    echo "MÉTODO 5: MINIMAL (mínimo absoluto)"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# 1. Locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen

# 2. Generar
locale-gen

# 3. Solo locale.conf
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf

echo "✓ Método Minimal completado"
echo ""
echo "Archivos creados:"
ls -la /etc/locale.conf 2>/dev/null || true
CHROOT_EOF
}

# ============================================================================
# CONFIGURACIÓN DE TECLADO
# ============================================================================

# MÉTODO A: Keyboard - Debian style
keyboard_debian() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "TECLADO: DEBIAN STYLE"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
export DEBIAN_FRONTEND=noninteractive

# Verificar paquetes
apt-get install -y keyboard-configuration console-setup

# Configurar /etc/default/keyboard
cat > /etc/default/keyboard << 'KBD'
XKBMODEL="pc105"
XKBLAYOUT="es"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD

# Aplicar
setupcon -k --force || true

# Reconfigure
dpkg-reconfigure -f noninteractive keyboard-configuration

echo "✓ Teclado Debian configurado"
CHROOT_EOF
}

# MÉTODO B: Keyboard - Systemd style
keyboard_systemd() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "TECLADO: SYSTEMD STYLE"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# vconsole.conf (ya debería estar si usaste método Arch)
cat > /etc/vconsole.conf << 'VCONSOLE'
KEYMAP=es
FONT=eurlatgr
VCONSOLE

# localectl
localectl set-keymap es
localectl set-x11-keymap es pc105

# X11 config
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'X11'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbModel" "pc105"
EndSection
X11

echo "✓ Teclado systemd configurado"
CHROOT_EOF
}

# ============================================================================
# CONFIGURACIÓN GNOME
# ============================================================================

gnome_config() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "GNOME: Configuración de locale y teclado"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'CHROOT_EOF'
# Script que se ejecuta en el primer login
cat > /etc/profile.d/99-gnome-locale.sh << 'GNOME'
#!/bin/bash
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    MARKER="$HOME/.config/.gnome-locale-configured"
    
    if [ ! -f "$MARKER" ]; then
        # Configurar idioma de GNOME
        gsettings set org.gnome.system.locale region 'es_ES.UTF-8' 2>/dev/null
        
        # Configurar distribución de teclado
        gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'es')]" 2>/dev/null
        
        mkdir -p "$HOME/.config"
        touch "$MARKER"
        echo "✓ GNOME locale y teclado configurados"
    fi
fi
GNOME

chmod +x /etc/profile.d/99-gnome-locale.sh

echo "✓ Script GNOME creado"
CHROOT_EOF
}

# ============================================================================
# FUNCIÓN DE TESTING - Ejecuta un método y verifica
# ============================================================================
test_method() {
    local method=$1
    local kbd_method=$2
    local with_gnome=$3
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  TESTING: $method + $kbd_method"
    [ "$with_gnome" = "yes" ] && echo "║  + GNOME config"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Ejecutar método de locale
    case "$method" in
        arch) method_arch ;;
        debian) method_debian ;;
        hybrid) method_hybrid ;;
        export) method_export ;;
        minimal) method_minimal ;;
        *) echo "Método desconocido: $method"; return 1 ;;
    esac
    
    # Ejecutar método de teclado
    case "$kbd_method" in
        debian) keyboard_debian ;;
        systemd) keyboard_systemd ;;
        skip) echo "Teclado: SKIP" ;;
        *) echo "Método de teclado desconocido: $kbd_method"; return 1 ;;
    esac
    
    # GNOME si se solicita
    if [ "$with_gnome" = "yes" ]; then
        gnome_config
    fi
    
    # Verificación
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "VERIFICACIÓN"
    echo "════════════════════════════════════════════════════════════════"
    
    arch-chroot "$TARGET" /bin/bash << 'VERIFY_EOF'
echo ""
echo "1. Locales generados:"
locale -a | grep es_ES
echo ""
echo "2. Configuración actual:"
locale
echo ""
echo "3. Archivos de configuración:"
echo "--- /etc/locale.conf ---"
cat /etc/locale.conf 2>/dev/null || echo "No existe"
echo ""
echo "--- /etc/default/locale ---"
cat /etc/default/locale 2>/dev/null || echo "No existe"
echo ""
echo "--- /etc/vconsole.conf ---"
cat /etc/vconsole.conf 2>/dev/null || echo "No existe"
echo ""
echo "4. localectl status:"
localectl status 2>/dev/null || echo "localectl no disponible"
VERIFY_EOF
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "FIN DEL TEST"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================
show_menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          LOCALE CONFIGURATION METHODS - TESTING              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "MÉTODOS DE LOCALE:"
    echo "  1) Arch Style       - /etc/locale.conf + localectl"
    echo "  2) Debian Style     - /etc/default/locale + dpkg-reconfigure"
    echo "  3) Hybrid           - Arch + Debian compatibility"
    echo "  4) Export Style     - /etc/environment + profile.d"
    echo "  5) Minimal          - Solo /etc/locale.conf"
    echo ""
    echo "MÉTODOS DE TECLADO:"
    echo "  a) Debian           - keyboard-configuration + setupcon"
    echo "  b) Systemd          - localectl + vconsole.conf"
    echo "  c) Skip             - No configurar teclado"
    echo ""
    echo "ENTORNO:"
    echo "  g) Con GNOME        - Añadir configuración GNOME"
    echo "  n) Sin GNOME        - Solo sistema base"
    echo ""
    echo "TESTS RÁPIDOS:"
    echo "  s1) Server (minimal + systemd teclado)"
    echo "  s2) Desktop sin GNOME (arch + systemd teclado)"
    echo "  s3) Desktop con GNOME (arch + systemd teclado + GNOME)"
    echo "  s4) Debian puro (debian + debian teclado + GNOME)"
    echo ""
    echo "  0) Salir"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    if [ ! -d "$TARGET" ]; then
        echo "Error: $TARGET no existe"
        echo "Uso: $0 [/mnt]"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Selecciona método locale (1-5): " locale_method
        read -p "Selecciona método teclado (a/b/c): " kbd_method
        read -p "¿Con GNOME? (y/n): " gnome_opt
        
        case "$locale_method" in
            1) method="arch" ;;
            2) method="debian" ;;
            3) method="hybrid" ;;
            4) method="export" ;;
            5) method="minimal" ;;
            s1) method="minimal"; kbd_method="b"; gnome_opt="n" ;;
            s2) method="arch"; kbd_method="b"; gnome_opt="n" ;;
            s3) method="arch"; kbd_method="b"; gnome_opt="y" ;;
            s4) method="debian"; kbd_method="a"; gnome_opt="y" ;;
            0) exit 0 ;;
            *) echo "Opción inválida"; continue ;;
        esac
        
        case "$kbd_method" in
            a) kbd="debian" ;;
            b) kbd="systemd" ;;
            c) kbd="skip" ;;
            *) kbd="systemd" ;;
        esac
        
        case "$gnome_opt" in
            y|Y) gnome="yes" ;;
            *) gnome="no" ;;
        esac
        
        test_method "$method" "$kbd" "$gnome"
        
        echo ""
        read -p "Presiona Enter para continuar o Ctrl+C para salir..."
    done
}

# Si se ejecuta directamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
