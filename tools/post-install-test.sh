#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# ubuntu-advanced-install — Tests post-instalación
# Ejecutar DENTRO del sistema instalado (primer boot o chroot)
#
# Uso:
#   sudo bash tools/post-install-test.sh                  # test completo
#   sudo bash tools/post-install-test.sh --quick           # solo críticos
#   sudo bash tools/post-install-test.sh --section gnome   # solo sección
# ══════════════════════════════════════════════════════════════════════════════

set -u

ERRORS=0
WARNINGS=0
PASSED=0
SECTION_FILTER="${1:-all}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

_pass() { PASSED=$((PASSED+1)); echo -e "  ${GREEN}✓${NC} $1"; }
_fail() { ERRORS=$((ERRORS+1)); echo -e "  ${RED}✗${NC} $1"; }
_warn() { WARNINGS=$((WARNINGS+1)); echo -e "  ${YELLOW}⚠${NC} $1"; }
_skip() { echo -e "  ${DIM}· $1 (omitido)${NC}"; }
_check() { "$@" 2>/dev/null && _pass "$*" || _fail "$*"; }

_section() {
    if [ "$SECTION_FILTER" != "all" ] && [ "$SECTION_FILTER" != "--quick" ] && [ "$SECTION_FILTER" != "--section" ] && [ "$SECTION_FILTER" != "$1" ]; then
        return 1
    fi
    echo ""
    echo -e "${BOLD}${CYAN}[$1]${NC}"
    return 0
}

echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  POST-INSTALL TEST — ubuntu-advanced-install${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${DIM}$(date) · $(hostname) · $(uname -r)${NC}"

# ════════════════════════════════════════════════════════════════════════════
# SISTEMA BASE
# ════════════════════════════════════════════════════════════════════════════

if _section "sistema"; then
    [ -f /etc/fstab ] && _pass "fstab existe" || _fail "fstab no encontrado"
    [ -f /etc/hostname ] && _pass "hostname configurado: $(cat /etc/hostname)" || _fail "hostname no configurado"
    [ -f /etc/default/locale ] && _pass "locale configurado" || _fail "locale no configurado"

    # Locale es_ES.UTF-8
    if locale 2>/dev/null | grep -q "es_ES.UTF-8"; then
        _pass "locale es_ES.UTF-8 activo"
    else
        _warn "locale es_ES.UTF-8 no activo ($(locale 2>/dev/null | head -1))"
    fi

    # Timezone
    if timedatectl 2>/dev/null | grep -q "Europe/Madrid"; then
        _pass "timezone Europe/Madrid"
    else
        _warn "timezone no es Europe/Madrid"
    fi

    # Teclado
    if [ -f /etc/default/keyboard ] && grep -q 'XKBLAYOUT="es"' /etc/default/keyboard; then
        _pass "teclado español configurado"
    else
        _warn "teclado no configurado como español"
    fi

    # Usuario
    MAIN_USER=$(getent passwd 1000 2>/dev/null | cut -d: -f1)
    if [ -n "$MAIN_USER" ]; then
        _pass "usuario principal: $MAIN_USER (UID 1000)"
        id "$MAIN_USER" | grep -q sudo && _pass "$MAIN_USER en grupo sudo" || _fail "$MAIN_USER no está en grupo sudo"
    else
        _fail "no se encontró usuario con UID 1000"
    fi

    # chrony (NTP)
    if systemctl is-enabled chrony &>/dev/null; then
        _pass "chrony (NTP) habilitado"
    else
        _warn "chrony no habilitado"
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# BOOTLOADER
# ════════════════════════════════════════════════════════════════════════════

if _section "boot"; then
    ls /boot/vmlinuz-* &>/dev/null && _pass "kernel presente: $(ls /boot/vmlinuz-* | tail -1 | sed 's|.*/vmlinuz-||')" || _fail "kernel no encontrado"
    ls /boot/initrd.img-* &>/dev/null && _pass "initramfs presente" || _warn "initramfs no encontrado"
    [ -f /boot/grub/grub.cfg ] && _pass "grub.cfg presente ($(wc -l < /boot/grub/grub.cfg) líneas)" || _fail "grub.cfg no encontrado"

    if [ -d /sys/firmware/efi ]; then
        [ -f /boot/efi/EFI/ubuntu/shimx64.efi ] || [ -f /boot/efi/EFI/ubuntu/grubx64.efi ] \
            && _pass "EFI binaries presentes" || _fail "EFI binaries ausentes"
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# RED
# ════════════════════════════════════════════════════════════════════════════

if _section "red"; then
    systemctl is-enabled NetworkManager &>/dev/null && _pass "NetworkManager habilitado" || _fail "NetworkManager no habilitado"
    systemctl is-enabled systemd-resolved &>/dev/null && _pass "systemd-resolved habilitado" || _warn "systemd-resolved no habilitado"

    # DNS funcional
    if host google.com &>/dev/null || ping -c1 -W2 8.8.8.8 &>/dev/null; then
        _pass "conectividad de red OK"
    else
        _warn "sin conectividad de red (normal en chroot)"
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# GNOME
# ════════════════════════════════════════════════════════════════════════════

if _section "gnome"; then
    if command -v gnome-shell &>/dev/null; then
        GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' || echo "?")
        _pass "GNOME Shell $GNOME_VER"

        systemctl is-enabled gdm3 &>/dev/null && _pass "GDM habilitado" || _fail "GDM no habilitado"

        # Target gráfico
        CURRENT_TARGET=$(systemctl get-default 2>/dev/null)
        [ "$CURRENT_TARGET" = "graphical.target" ] && _pass "target: graphical.target" || _fail "target: $CURRENT_TARGET (esperado: graphical.target)"

        # gschema.override
        [ -f /usr/share/glib-2.0/schemas/99-ubuntu-advanced-install.gschema.override ] \
            && _pass "gschema.override instalado" || _warn "gschema.override no encontrado"

        # gschemas.compiled
        [ -f /usr/share/glib-2.0/schemas/gschemas.compiled ] \
            && _pass "schemas compilados" || _fail "gschemas.compiled no encontrado"

        # dconf system-db
        [ -f /etc/dconf/db/local.d/00-ubuntu-advanced-install ] \
            && _pass "dconf system-db configurado" || _warn "dconf system-db no encontrado"
        [ -f /etc/dconf/profile/user ] \
            && _pass "dconf profile presente" || _warn "dconf profile ausente"

        # Extensiones instaladas
        EXT_DIR="/usr/share/gnome-shell/extensions"
        for ext in "vertical-workspaces@G-dH.github.com" "caffeine@patapon.info"; do
            [ -d "$EXT_DIR/$ext" ] && _pass "extensión: $ext" || _warn "extensión ausente: $ext"
        done

        # Primer login script
        [ -f /usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh ] \
            && _pass "script primer login instalado" || _warn "script primer login ausente"

        # Keyring
        [ -d /etc/skel/.local/share/keyrings ] \
            && _pass "keyring directorio en skel" || _warn "keyring directorio ausente en skel"

        # PAM gnome-keyring configurado
        if grep -q 'pam_gnome_keyring' /etc/pam.d/gdm-password 2>/dev/null || \
           grep -q 'pam_gnome_keyring' /etc/pam.d/gdm-autologin 2>/dev/null; then
            _pass "PAM gnome-keyring configurado"
        else
            _warn "PAM gnome-keyring no encontrado en gdm-password/gdm-autologin"
        fi
    else
        _skip "GNOME no instalado"
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# SOFTWARE
# ════════════════════════════════════════════════════════════════════════════

if _section "software"; then
    # Navegador
    command -v google-chrome-stable &>/dev/null && _pass "Google Chrome" || _warn "Chrome no instalado"

    # Multimedia
    command -v ffmpeg &>/dev/null && _pass "ffmpeg" || _warn "ffmpeg no instalado"
    command -v vlc &>/dev/null && _pass "VLC" || _skip "VLC"

    # Fuentes
    if fc-list 2>/dev/null | grep -qi "ubuntu"; then
        _pass "fuente Ubuntu presente"
    else
        _warn "fuente Ubuntu no encontrada"
    fi
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono.*Nerd"; then
        _pass "JetBrainsMono Nerd Font presente"
    else
        _warn "JetBrainsMono Nerd Font no encontrada"
    fi
    if fc-list 2>/dev/null | grep -qi "calibri"; then
        _pass "MS ClearType fonts presentes"
    else
        _warn "MS ClearType fonts no encontradas"
    fi

    # Desarrollo
    command -v git &>/dev/null && _pass "git" || _skip "git"
    command -v node &>/dev/null && _pass "node $(node --version 2>/dev/null)" || _skip "node"
    command -v code &>/dev/null && _pass "VS Code" || _skip "VS Code"
    command -v ghostty &>/dev/null && _pass "Ghostty" || _skip "Ghostty"

    # Gaming
    command -v steam &>/dev/null && _pass "Steam" || _skip "Steam"
    [ -f /usr/share/applications/heroic.desktop ] || command -v heroic &>/dev/null \
        && _pass "Heroic" || _skip "Heroic"
    command -v mangohud &>/dev/null && _pass "MangoHud" || _skip "MangoHud"
fi

# ════════════════════════════════════════════════════════════════════════════
# OPTIMIZACIONES
# ════════════════════════════════════════════════════════════════════════════

if _section "optimizaciones"; then
    # systemd-oomd
    systemctl is-enabled systemd-oomd &>/dev/null && _pass "systemd-oomd habilitado" || _warn "systemd-oomd no habilitado"

    # Unattended upgrades
    [ -f /etc/apt/apt.conf.d/50unattended-upgrades ] && _pass "unattended-upgrades configurado" || _warn "unattended-upgrades no configurado"

    # APT no-recommends
    if [ -f /etc/apt/apt.conf.d/90norecommends ] && grep -q 'Install-Recommends.*false' /etc/apt/apt.conf.d/90norecommends; then
        _pass "APT Install-Recommends=false"
    else
        _warn "APT Install-Recommends no configurado"
    fi

    # sysctl gaming (si gaming instalado)
    if [ -f /etc/sysctl.d/99-gaming.conf ]; then
        _pass "sysctl gaming configurado (max_map_count, swappiness, bbr)"
    fi

    # fstrim
    systemctl is-enabled fstrim.timer &>/dev/null && _pass "fstrim.timer habilitado" || _warn "fstrim.timer no habilitado"
fi

# ════════════════════════════════════════════════════════════════════════════
# AUDIO
# ════════════════════════════════════════════════════════════════════════════

if _section "audio"; then
    if command -v pipewire &>/dev/null; then
        _pass "PipeWire instalado"
        command -v wireplumber &>/dev/null && _pass "WirePlumber instalado" || _warn "WirePlumber no encontrado"
    else
        _warn "PipeWire no instalado"
    fi
fi

# ════════════════════════════════════════════════════════════════════════════
# RESUMEN
# ════════════════════════════════════════════════════════════════════════════

TOTAL=$((PASSED + ERRORS + WARNINGS))
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✓ $PASSED passed${NC}  ${RED}✗ $ERRORS failed${NC}  ${YELLOW}⚠ $WARNINGS warnings${NC}  ${DIM}($TOTAL total)${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "  ${RED}Hay $ERRORS errores que deben revisarse.${NC}"
    exit 1
elif [ $WARNINGS -gt 3 ]; then
    echo -e "  ${YELLOW}Varios warnings — verificar manualmente.${NC}"
    exit 0
else
    echo -e "  ${GREEN}Sistema instalado correctamente.${NC}"
    exit 0
fi
