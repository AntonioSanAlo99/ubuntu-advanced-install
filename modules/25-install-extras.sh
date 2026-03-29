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

exit 0
CHROOTEOF

# ============================================================================
# GRADIA v1.12 — screenshot tool GTK4/libadwaita (compilado desde fuente)
# ============================================================================
# Basado en el PKGBUILD del AUR (gradia 1.12.1) y el patch gradia_ocr.patch
# que permite compilación nativa (fuera de Flatpak) configurando las rutas
# de tesseract via opciones de meson en vez de hardcodear /app/bin/tesseract.
#
# Flags meson clave (del PKGBUILD):
#   -Docr_tesseract_cmd=/usr/bin/tesseract
#   -Docr_original_tessdata_dir=/usr/share/tessdata
#
# El patch modifica meson.build + meson.options + ocr.py para soportar
# estas opciones. Sin él, OCR busca en /app/bin/ (ruta Flatpak) y falla.
#
# Deps del PKGBUILD: dconf, graphene, libsoup3, gtk4>=4.12, libadwaita>=1.5,
#   libportal>=0.9.1, gtksourceview5>=5.16, python-gobject>=3.48,
#   python-pillow, python-cairo, python-pytesseract
#
# Ref: https://aur.archlinux.org/packages/gradia (PKGBUILD + gradia_ocr.patch)
# Ref: https://github.com/AlexanderVanhee/Gradia/releases/tag/v1.12.0

if [ "${INSTALL_GRADIA:-false}" = "true" ]; then
    echo ""
    echo "Compilando Gradia (screenshot tool GTK4)..."

    arch-chroot "$TARGET" /bin/bash << 'GRADIAEOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# ── Dependencias de compilación ──────────────────────────────────────────────
echo "  Instalando dependencias de compilación..."
apt-get install -y \
    git meson ninja-build gettext desktop-file-utils appstream \
    blueprint-compiler \
    libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
    libportal-dev libportal-gtk4-dev \
    libsoup-3.0-dev libgraphene-1.0-dev

# ── Dependencias runtime (del PKGBUILD del AUR) ─────────────────────────────
echo "  Instalando dependencias runtime..."
apt-get install -y \
    dconf-cli \
    python3 python3-gi python3-gi-cairo python3-gobject python3-cairo \
    gobject-introspection \
    gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 \
    xdg-desktop-portal xdg-desktop-portal-gnome

# Pillow (requirements.txt: con soporte webp + avif)
apt-get install -y python3-pil

# Portal GTK4 typelib (screenshot/screencast via portal)
apt-get install -y gir1.2-xdpgtk4-1.0 2>/dev/null || true

# GStreamer para screencast via portal
apt-get install -y \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-base 2>/dev/null || true

# OCR: tesseract + pytesseract (usado por gradia.backend.ocr)
apt-get install -y tesseract-ocr python3-pytesseract 2>/dev/null \
    && echo "  ✓ OCR (tesseract) disponible" \
    || echo "  ⊘ OCR no disponible (opcional)"

echo "  ✓ Dependencias instaladas"
echo "  blueprint-compiler: $(blueprint-compiler --version 2>/dev/null || echo 'no encontrado')"

# ── Clonar Gradia ────────────────────────────────────────────────────────────
GRADIA_BUILD=$(mktemp -d /tmp/gradia-build.XXXXXX)
cd "$GRADIA_BUILD"

echo "  Clonando Gradia..."
git clone --depth 1 --branch v1.12.0 \
    https://github.com/AlexanderVanhee/Gradia.git gradia 2>/dev/null \
    || git clone --depth 1 https://github.com/AlexanderVanhee/Gradia.git gradia
cd gradia

# ── Patch OCR para compilación nativa (fuera de Flatpak) ─────────────────────
# El meson.build original hardcodea /app/bin/tesseract y /app/share/tessdata
# (rutas Flatpak). Este patch añade opciones de meson para configurarlas.
# Basado en gradia_ocr.patch del AUR (PKGBUILD gradia 1.12.1).

# 1. meson.options: añadir opciones ocr_tesseract_cmd y ocr_original_tessdata_dir
if ! grep -q 'ocr_tesseract_cmd' meson.options 2>/dev/null; then
    echo "option('ocr_tesseract_cmd', type: 'string', value: '/usr/bin/tesseract', description: 'OCR cmd path')" >> meson.options
    echo "option('ocr_original_tessdata_dir', type: 'string', value: '/usr/share/tessdata', description: 'OCR data path')" >> meson.options
fi

# 2. meson.build: usar get_option() en vez de rutas hardcodeadas
if grep -q "OCR_TESSERACT_CMD = '/app/bin/tesseract'" meson.build 2>/dev/null; then
    sed -i "s|OCR_TESSERACT_CMD = '/app/bin/tesseract'|ocr_tesseract_cmd = get_option('ocr_tesseract_cmd')|" meson.build
    sed -i "s|OCR_ORIGINAL_TESSDATA_DIR = '/app/share/tessdata'|ocr_original_tessdata_dir = get_option('ocr_original_tessdata_dir')|" meson.build
    sed -i "s|conf.set('OCR_TESSERACT_CMD', OCR_TESSERACT_CMD)|conf.set('OCR_TESSERACT_CMD', ocr_tesseract_cmd)|" meson.build
    sed -i "s|conf.set('OCR_ORIGINAL_TESSDATA_DIR', OCR_ORIGINAL_TESSDATA_DIR)|conf.set('OCR_ORIGINAL_TESSDATA_DIR', ocr_original_tessdata_dir)|" meson.build
fi

# 3. ocr.py: tessdata de usuario en ~/.local/var/app/ (no ~/.var/app/ de Flatpak)
if grep -q '~/.var/app/' gradia/backend/ocr.py 2>/dev/null; then
    sed -i 's|~/.var/app/|~/.local/var/app/|' gradia/backend/ocr.py
fi

echo "  ✓ Patch OCR aplicado (rutas nativas)"

# ── Compilar (con fallback de blueprint-compiler) ────────────────────────────
MESON_FLAGS="--prefix=/usr --buildtype=release"
MESON_FLAGS="$MESON_FLAGS -Docr_tesseract_cmd=/usr/bin/tesseract"
MESON_FLAGS="$MESON_FLAGS -Docr_original_tessdata_dir=/usr/share/tessdata"

echo "  meson setup (intento 1: blueprint-compiler del sistema)..."
if meson setup builddir $MESON_FLAGS 2>/dev/null; then
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
    meson setup builddir $MESON_FLAGS
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
    python3 -c "from PIL import Image; print('  ✓ Pillow OK')" 2>/dev/null || echo "  ⚠ Pillow: import falló"
    python3 -c "import gi; gi.require_version('GtkSource','5'); print('  ✓ GtkSource 5 OK')" 2>/dev/null || echo "  ⚠ GtkSource 5: import falló"
    [ -x /usr/bin/tesseract ] && echo "  ✓ tesseract OK: $(tesseract --version 2>&1 | head -1)" || echo "  ⊘ tesseract no instalado (OCR deshabilitado)"
else
    echo "⚠  Gradia: binario no encontrado tras instalación"
    exit 1
fi
exit 0
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
