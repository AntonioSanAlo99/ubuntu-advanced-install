#!/bin/bash
# MÓDULO 25: Instalar aplicaciones extras opcionales
# PRODUCE:  Apps extras seleccionadas
# OnlyOffice, qBittorrent, Mullvad VPN — cada una con pregunta interactiva.

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"


# ── Cargar configuración desde config.yaml ────────────────────────────────────
_YAML_FILE="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/../config.yaml"
_yaml_val() {
    # Lee una clave de config.yaml: _yaml_val "section" "key" "default"
    local section="$1" key="$2" default="${3:-}"
    [ ! -f "$_YAML_FILE" ] && { echo "$default"; return; }
    local in_section=false val=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
        if [[ "$line" =~ ^([a-z_]+):[[:space:]]*$ ]]; then
            [ "${BASH_REMATCH[1]}" = "$section" ] && in_section=true || in_section=false
            continue
        fi
        if $in_section && [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]+(.*) ]]; then
            val="${BASH_REMATCH[1]}"
            val="${val%%#*}"; val="${val%"${val##*[![:space:]]}"}";
            val="${val#\"}" ; val="${val%\"}"; val="${val#\'}" ; val="${val%\'}"
            echo "$val"; return
        fi
    done < "$_YAML_FILE"
    echo "$default"
}

[ -z "${INSTALL_ONLYOFFICE:-}" ] && INSTALL_ONLYOFFICE=$(_yaml_val "extras" "onlyoffice" "false")
[ -z "${INSTALL_QBITTORRENT:-}" ] && INSTALL_QBITTORRENT=$(_yaml_val "extras" "qbittorrent" "false")
[ -z "${INSTALL_MULLVAD:-}" ] && INSTALL_MULLVAD=$(_yaml_val "extras" "mullvad_vpn" "false")
[ -z "${INSTALL_OBS:-}" ] && INSTALL_OBS=$(_yaml_val "extras" "obs_studio" "false")
[ -z "${INSTALL_OBSIDIAN:-}" ] && INSTALL_OBSIDIAN=$(_yaml_val "extras" "obsidian" "false")
[ -z "${INSTALL_GRADIA:-}" ] && INSTALL_GRADIA=$(_yaml_val "extras" "gradia" "false")
[ -z "${USERNAME:-}" ] && USERNAME=$(_yaml_val "system" "username" "")


# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


echo "Aplicaciones extras opcionales..."

# ============================================================================
# VARIABLES — todas vienen de install.sh (exportadas)
# ============================================================================

INSTALL_ONLYOFFICE="${INSTALL_ONLYOFFICE:-false}"
INSTALL_QBITTORRENT="${INSTALL_QBITTORRENT:-false}"
INSTALL_MULLVAD="${INSTALL_MULLVAD:-false}"
INSTALL_OBS="${INSTALL_OBS:-false}"
INSTALL_OBSIDIAN="${INSTALL_OBSIDIAN:-false}"
INSTALL_GRADIA="${INSTALL_GRADIA:-false}"

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

INSTALL_ONLYOFFICE="$INSTALL_ONLYOFFICE"
INSTALL_QBITTORRENT="$INSTALL_QBITTORRENT"
INSTALL_MULLVAD="$INSTALL_MULLVAD"
INSTALL_OBS="$INSTALL_OBS"
INSTALL_OBSIDIAN="$INSTALL_OBSIDIAN"
USERNAME="$USERNAME"

# ============================================================================
# ONLYOFFICE DESKTOP EDITORS (repo oficial)
# ============================================================================
# Ref: https://helpcenter.onlyoffice.com/installation/desktop-install-ubuntu.aspx

if [ "\$INSTALL_ONLYOFFICE" = "true" ]; then
    echo ""
    echo "Instalando OnlyOffice Desktop Editors..."

    mkdir -p /etc/apt/keyrings
    curl --max-time 30 --retry 2 -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE \
        | gpg --dearmor -o /etc/apt/keyrings/onlyoffice.gpg 2>/dev/null

    cat > /etc/apt/sources.list.d/onlyoffice.sources << OOEOF
Types: deb
URIs: https://download.onlyoffice.com/repo/debian
Suites: squeeze
Components: main
Signed-By: /etc/apt/keyrings/onlyoffice.gpg
OOEOF

    # Update e install en un paso (repo recién añadido)
    apt-get update -qq || true
    apt-get install -y onlyoffice-desktopeditors

    if command -v onlyoffice-desktopeditors >/dev/null 2>&1; then
        echo "  ✓ OnlyOffice Desktop Editors instalado"
    else
        echo "  ⚠ OnlyOffice: instalación falló"
    fi
else
    echo "⊘ OnlyOffice no instalado"
fi

# ============================================================================
# QBITTORRENT (cliente torrent — repos Ubuntu)
# ============================================================================

if [ "\$INSTALL_QBITTORRENT" = "true" ]; then
    echo ""
    echo "Instalando qBittorrent..."
    apt-get install -y qbittorrent
    echo "✓  qBittorrent instalado"
else
    echo "⊘ qBittorrent no instalado"
fi

# ============================================================================
# MULLVAD VPN (repo oficial)
# ============================================================================
# Ref: https://mullvad.net/en/help/install-mullvad-app-linux

if [ "\$INSTALL_MULLVAD" = "true" ]; then
    echo ""
    echo "Instalando Mullvad VPN..."

    # Signing key
    curl --max-time 30 --retry 2 -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
        https://repository.mullvad.net/deb/mullvad-keyring.asc 2>/dev/null

    # Repo — usar "stable stable" (no codename) como indica la documentación oficial
    ARCH=\$(dpkg --print-architecture)
    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=\$ARCH] https://repository.mullvad.net/deb/stable stable main" \
        > /etc/apt/sources.list.d/mullvad.list

    # Update e install en un paso (repo recién añadido)
    apt-get update -qq || true
    apt-get install -y mullvad-vpn

    if command -v mullvad >/dev/null 2>&1; then
        echo "  ✓ Mullvad VPN instalado"
    else
        echo "  ⚠ Mullvad VPN: instalación falló"
    fi
else
    echo "⊘ Mullvad VPN no instalado"
fi

# ============================================================================
# OBS STUDIO (PPA oficial obsproject)
# ============================================================================
# Streaming y grabación de pantalla. PPA oficial para versión más reciente.
# Ref: https://obsproject.com/download#linux

if [ "\$INSTALL_OBS" = "true" ]; then
    echo ""
    echo "Instalando OBS Studio..."

    if add-apt-repository -y ppa:obsproject/obs-studio > /dev/null 2>&1; then
        # Update e install en un paso (repo recién añadido)
        apt-get update -qq || true
        apt-get install -y obs-studio
        if command -v obs >/dev/null 2>&1; then
            echo "  ✓ OBS Studio instalado (PPA obsproject)"
        else
            echo "  ⚠ OBS Studio: instalación no confirmada"
        fi
    else
        # Fallback: repo de Ubuntu (versión más antigua pero funcional)
        apt-get install -y obs-studio 2>/dev/null || true
        if command -v obs >/dev/null 2>&1; then
            echo "  ✓ OBS Studio instalado (repo Ubuntu)"
        else
            echo "  ⚠ OBS Studio: instalación falló"
        fi
    fi
else
    echo "⊘ OBS Studio no instalado"
fi

# ============================================================================
# OBSIDIAN (.deb desde GitHub releases)
# ============================================================================
# Knowledge base y notas en Markdown.
# Ref: https://obsidian.md

if [ "\$INSTALL_OBSIDIAN" = "true" ]; then
    echo ""
    echo "Instalando Obsidian..."

    OBSIDIAN_DEB_URL=\$(curl --max-time 15 -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
        | grep "browser_download_url" | grep "_amd64\\.deb\"" \
        | head -1 | cut -d'"' -f4)

    if [ -n "\$OBSIDIAN_DEB_URL" ]; then
        wget --timeout=30 --tries=2 -q "\$OBSIDIAN_DEB_URL" -O /tmp/obsidian.deb 2>/dev/null

        if [ -s /tmp/obsidian.deb ]; then
            dpkg -i /tmp/obsidian.deb || true
            apt-get install -f -y 2>/dev/null || true
            rm -f /tmp/obsidian.deb

            if dpkg -l 2>/dev/null | grep -q "^ii.*obsidian"; then
                echo "  ✓ Obsidian instalado (.deb)"
            else
                echo "  ⚠ Obsidian: instalación no confirmada"
            fi
        else
            echo "  ⚠ Obsidian: descarga falló"
        fi
    else
        echo "  ⚠ Obsidian: no se pudo obtener URL de GitHub releases"
    fi
else
    echo "⊘ Obsidian no instalado"
fi

CHROOTEOF

# ============================================================================
# GRADIA — screenshot tool GTK4/libadwaita (compilado desde fuente)
# ============================================================================
# App Python + Blueprint + GTK4/libadwaita. Usa portal XDG nativo para capturas.
# blueprint-compiler es la dependencia de compilación clave.
#
# Estrategia: intentar primero con el blueprint-compiler del repo de Ubuntu.
# Si meson setup falla (versión insuficiente), compilar blueprint-compiler
# desde GNOME GitLab (última release) y reintentar.
#
# Ref: https://github.com/AlexanderVanhee/Gradia
# Ref: https://gitlab.gnome.org/jwestman/blueprint-compiler

if [ "${INSTALL_GRADIA:-false}" = "true" ]; then
    echo ""
    echo "Compilando Gradia (screenshot tool GTK4)..."

    arch-chroot "$TARGET" /bin/bash << 'GRADIAEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# ── Dependencias de compilación y runtime ────────────────────────────────────
echo "  Instalando dependencias..."
apt-get install -y \
    git meson ninja-build gettext desktop-file-utils appstream \
    blueprint-compiler \
    python3 python3-gi python3-gi-cairo python3-pil python3-gobject \
    gobject-introspection gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 \
    libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
    libportal-dev libportal-gtk4-dev

# Opcional — no disponible en todas las versiones de Ubuntu
apt-get install -y gir1.2-xdpgtk4-1.0 2>/dev/null || true

echo "  ✓ Dependencias instaladas"
echo "  blueprint-compiler: $(blueprint-compiler --version 2>/dev/null || echo 'no encontrado')"

# ── Clonar Gradia ────────────────────────────────────────────────────────────
GRADIA_BUILD=$(mktemp -d /tmp/gradia-build.XXXXXX)
cd "$GRADIA_BUILD"

echo "  Clonando repositorio Gradia..."
git clone --depth 1 https://github.com/AlexanderVanhee/Gradia.git gradia
cd gradia

# ── Intentar compilar con blueprint-compiler del sistema ─────────────────────
echo "  meson setup (intento 1: blueprint-compiler del sistema)..."
if meson setup builddir --prefix=/usr --buildtype=release 2>/dev/null; then
    echo "  ✓ meson setup OK con blueprint-compiler del sistema"
else
    echo "  ⚠ blueprint-compiler del sistema insuficiente — compilando desde fuente..."

    BC_BUILD=$(mktemp -d /tmp/bc-build.XXXXXX)
    git clone --depth 1 https://gitlab.gnome.org/jwestman/blueprint-compiler.git "$BC_BUILD/bc" 2>/dev/null
    cd "$BC_BUILD/bc"
    meson setup _build --prefix=/usr --buildtype=release
    ninja -C _build
    ninja -C _build install
    cd "$GRADIA_BUILD/gradia"
    rm -rf "$BC_BUILD"

    echo "  blueprint-compiler actualizado: $(blueprint-compiler --version 2>/dev/null || echo '?')"

    rm -rf builddir
    echo "  meson setup (intento 2: blueprint-compiler compilado)..."
    meson setup builddir --prefix=/usr --buildtype=release
fi

echo "  ninja build..."
ninja -C builddir

echo "  ninja install..."
ninja -C builddir install

# ── Post-install ─────────────────────────────────────────────────────────────
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
update-desktop-database /usr/share/applications/ 2>/dev/null || true
gtk-update-icon-cache -f -t /usr/share/icons/hicolor/ 2>/dev/null || true

cd /
rm -rf "$GRADIA_BUILD"

# ── Verificar ────────────────────────────────────────────────────────────────
if [ -f /usr/bin/gradia ] || command -v gradia &>/dev/null; then
    echo "✓  Gradia compilado e instalado correctamente"
else
    echo "⚠  Gradia: binario no encontrado tras instalación"
    exit 1
fi
GRADIAEOF

    if [ $? -ne 0 ]; then
        echo "⚠  Gradia: compilación falló — se omite"
        echo "   Revisar logs del chroot para detalles"
    fi
else
    echo "⊘ Gradia no instalado"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  APLICACIONES EXTRAS"
echo "════════════════════════════════════════════════════════════════"
[ "${INSTALL_ONLYOFFICE:-false}" = "true" ] && echo "  ✓ OnlyOffice Desktop Editors"
[ "${INSTALL_QBITTORRENT:-false}" = "true" ] && echo "  ✓ qBittorrent"
[ "${INSTALL_MULLVAD:-false}" = "true" ] && echo "  ✓ Mullvad VPN"
[ "${INSTALL_OBS:-false}" = "true" ] && echo "  ✓ OBS Studio"
[ "${INSTALL_OBSIDIAN:-false}" = "true" ] && echo "  ✓ Obsidian"
[ "${INSTALL_GRADIA:-false}" = "true" ] && echo "  ✓ Gradia (screenshot tool)"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
