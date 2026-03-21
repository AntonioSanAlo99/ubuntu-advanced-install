#!/bin/bash
# MÓDULO 25: Instalar aplicaciones extras opcionales
# OnlyOffice, aMule, Mullvad VPN — cada una con pregunta interactiva.

set -e
[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

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
# PREGUNTAS INTERACTIVAS (solo si no está automatizado)
# ============================================================================

if [ -z "$INSTALL_ONLYOFFICE" ]; then
    echo ""
    read -p "¿Instalar OnlyOffice Desktop Editors? (s/n) [n]: " INSTALL_ONLYOFFICE
    INSTALL_ONLYOFFICE=${INSTALL_ONLYOFFICE:-n}
fi

if [ -z "$INSTALL_AMULE" ]; then
    echo ""
    read -p "¿Instalar aMule (cliente eDonkey/Kademlia)? (s/n) [n]: " INSTALL_AMULE
    INSTALL_AMULE=${INSTALL_AMULE:-n}
fi

if [ -z "$INSTALL_MULLVAD" ]; then
    echo ""
    read -p "¿Instalar Mullvad VPN? (s/n) [n]: " INSTALL_MULLVAD
    INSTALL_MULLVAD=${INSTALL_MULLVAD:-n}
fi

if [ -z "$INSTALL_OBS" ]; then
    echo ""
    read -p "¿Instalar OBS Studio (streaming/grabación)? (s/n) [n]: " INSTALL_OBS
    INSTALL_OBS=${INSTALL_OBS:-n}
fi

if [ -z "$INSTALL_OBSIDIAN" ]; then
    echo ""
    read -p "¿Instalar Obsidian (notas/knowledge base)? (s/n) [n]: " INSTALL_OBSIDIAN
    INSTALL_OBSIDIAN=${INSTALL_OBSIDIAN:-n}
fi

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

INSTALL_ONLYOFFICE="$INSTALL_ONLYOFFICE"
INSTALL_AMULE="$INSTALL_AMULE"
INSTALL_MULLVAD="$INSTALL_MULLVAD"
INSTALL_OBS="$INSTALL_OBS"
INSTALL_OBSIDIAN="$INSTALL_OBSIDIAN"
USERNAME="$USERNAME"

# ============================================================================
# ONLYOFFICE DESKTOP EDITORS (repo oficial)
# ============================================================================
# Ref: https://helpcenter.onlyoffice.com/installation/desktop-install-ubuntu.aspx

if [[ "\$INSTALL_ONLYOFFICE" =~ ^[SsYy]$ ]]; then
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
# AMULE (cliente eDonkey/Kademlia — repos Ubuntu)
# ============================================================================

if [[ "\$INSTALL_AMULE" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando aMule..."

    apt-get install -y amule

    if command -v amule >/dev/null 2>&1; then
        echo "  ✓ aMule instalado"
    else
        echo "  ⚠ aMule: instalación falló"
    fi
else
    echo "⊘ aMule no instalado"
fi

# ============================================================================
# MULLVAD VPN (repo oficial)
# ============================================================================
# Ref: https://mullvad.net/en/help/install-mullvad-app-linux

if [[ "\$INSTALL_MULLVAD" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando Mullvad VPN..."

    # Signing key
    curl --max-time 30 --retry 2 -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
        https://repository.mullvad.net/deb/mullvad-keyring.asc 2>/dev/null

    # Repo — usar "stable stable" (no codename) como indica la documentación oficial
    ARCH=\$(dpkg --print-architecture)
    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=\$ARCH] https://repository.mullvad.net/deb/stable stable main" \
        > /etc/apt/sources.list.d/mullvad.list

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

if [[ "\$INSTALL_OBS" =~ ^[SsYy]$ ]]; then
    echo ""
    echo "Instalando OBS Studio..."

    if add-apt-repository -y ppa:obsproject/obs-studio > /dev/null 2>&1; then
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

if [[ "\$INSTALL_OBSIDIAN" =~ ^[SsYy]$ ]]; then
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
# WEBAPPS STREAMING (fuera del chroot — copia y ejecuta el script)
# ============================================================================

if [ "${INSTALL_STREAMING_WEBAPPS:-false}" = "true" ]; then
    echo ""
    SCRIPT_DIR_WA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WEBAPP_SCRIPT="$SCRIPT_DIR_WA/files/webapps/install-streaming-webapps.sh"

    if [ -f "$WEBAPP_SCRIPT" ]; then
        # Asegurar dependencias del script de webapps en el chroot
        arch-chroot "$TARGET" apt-get install -y wget 2>/dev/null || true
        cp "$WEBAPP_SCRIPT" "${TARGET}/tmp/install-streaming-webapps.sh"
        chmod 755 "${TARGET}/tmp/install-streaming-webapps.sh"
        arch-chroot "$TARGET" /bin/bash /tmp/install-streaming-webapps.sh
        rm -f "${TARGET}/tmp/install-streaming-webapps.sh"
    else
        echo "⚠  Script de webapps no encontrado en $WEBAPP_SCRIPT"
    fi
fi

# ============================================================================
# GESTORES CLI: kernel-manager + firmware-manager (fuera del chroot)
# ============================================================================

if [ "${INSTALL_SYS_MANAGERS:-false}" = "true" ]; then
    echo ""
    echo "Instalando gestores CLI de kernels y firmware..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    BIN_SRC="$SCRIPT_DIR/files/bin"

    for tool in kernel-manager firmware-manager; do
        if [ -f "$BIN_SRC/$tool" ]; then
            cp "$BIN_SRC/$tool" "${TARGET}/usr/local/bin/$tool"
            chmod 755 "${TARGET}/usr/local/bin/$tool"
            echo "  ✓ $tool → /usr/local/bin/$tool"
        else
            echo "  ⚠ $tool: fichero fuente no encontrado en $BIN_SRC/"
        fi
    done

    # fwupd como dependencia de firmware-manager
    arch-chroot "$TARGET" apt-get install -y fwupd 2>/dev/null || true
    echo "  ✓ fwupd instalado"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  APLICACIONES EXTRAS"
echo "════════════════════════════════════════════════════════════════"
[[ "${INSTALL_ONLYOFFICE:-n}" =~ ^[SsYy]$ ]] && echo "  ✓ OnlyOffice Desktop Editors"
[[ "${INSTALL_AMULE:-n}" =~ ^[SsYy]$ ]] && echo "  ✓ aMule"
[[ "${INSTALL_MULLVAD:-n}" =~ ^[SsYy]$ ]] && echo "  ✓ Mullvad VPN"
[[ "${INSTALL_OBS:-n}" =~ ^[SsYy]$ ]] && echo "  ✓ OBS Studio"
[[ "${INSTALL_OBSIDIAN:-n}" =~ ^[SsYy]$ ]] && echo "  ✓ Obsidian"
[ "${INSTALL_SYS_MANAGERS:-false}" = "true" ] && echo "  ✓ kernel-manager + firmware-manager (CLI)"
[ "${INSTALL_STREAMING_WEBAPPS:-false}" = "true" ] && echo "  ✓ Webapps: streaming, YouTube, ChatGPT, Claude (Chrome standalone)"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
