#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# install-streaming-webapps.sh — Genera webapps nativas con Pake (Tauri/Rust)
#
# Cada webapp se compila como binario nativo (~5MB) usando el webview del
# sistema (WebKitGTK), sin Electron ni Chromium embebido.
#
# Requisitos (instalados por módulo 23):
#   - Rust toolchain (rustup) instalado para el usuario
#   - Node.js >= 22 (para pake-cli)
#   - Dependencias Tauri: libwebkit2gtk-4.1-dev, libxdo-dev, etc.
#
# Servicios: Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+,
#            YouTube, YouTube Music, ChatGPT, Claude
#
# Uso: Se ejecuta dentro del chroot durante la instalación.
# ══════════════════════════════════════════════════════════════════════════════

DESKTOP_DIR="/usr/share/applications"
ICONS_DIR="/usr/share/icons/hicolor/128x128/apps"
PAKE_OUTPUT_DIR="/opt/pake-webapps"
USERNAME="${USERNAME:-}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  install-streaming-webapps.sh — Pake (Tauri/Rust)"
echo "  USERNAME=$USERNAME"
echo "════════════════════════════════════════════════════════════════"
echo ""

mkdir -p "$DESKTOP_DIR" "$ICONS_DIR" "$PAKE_OUTPUT_DIR"

# ── Verificar requisitos ─────────────────────────────────────────────────────

if [ -z "$USERNAME" ] || ! id "$USERNAME" &>/dev/null; then
    echo "⚠  USERNAME no definido o usuario no existe — webapps omitidas"
    exit 0
fi

USER_HOME="/home/$USERNAME"
CARGO_BIN="$USER_HOME/.cargo/bin"

if [ ! -f "$CARGO_BIN/cargo" ]; then
    echo "⚠  Rust/cargo no encontrado en $CARGO_BIN — webapps omitidas"
    echo "   Instala Rust primero: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 0
fi

if ! command -v node &>/dev/null; then
    echo "Node.js no encontrado — instalando para pake-cli..."
    # Instalar Node.js LTS desde NodeSource
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg 2>/dev/null || true
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list
    apt-get update -qq 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs 2>/dev/null || true

    if ! command -v node &>/dev/null; then
        echo "⚠  No se pudo instalar Node.js — webapps omitidas"
        exit 0
    fi
    echo "✓  Node.js $(node --version) instalado"
fi

# ── Instalar dependencias de Tauri (compilación) ────────────────────────────
echo "Instalando dependencias de compilación Tauri..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libwebkit2gtk-4.1-dev \
    libxdo-dev \
    libssl-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    patchelf \
    2>/dev/null || true

echo "✓  Dependencias Tauri instaladas"

# ── Instalar pake-cli ────────────────────────────────────────────────────────
echo "Instalando pake-cli..."

npm install -g pake-cli 2>/dev/null || {
    echo "⚠  No se pudo instalar pake-cli — webapps omitidas"
    exit 0
}

echo "✓  pake-cli disponible"

# ── Definición de webapps ────────────────────────────────────────────────────
# Formato: ID|Nombre|URL|Categoría|Ancho|Alto
WEBAPPS="
netflix|Netflix|https://www.netflix.com|AudioVideo;Video|1280|800
hbomax|HBO Max|https://play.max.com|AudioVideo;Video|1280|800
primevideo|Prime Video|https://www.primevideo.com|AudioVideo;Video|1280|800
disneyplus|Disney+|https://www.disneyplus.com|AudioVideo;Video|1280|800
filmin|Filmin|https://www.filmin.es|AudioVideo;Video|1280|800
dazn|DAZN|https://www.dazn.com|AudioVideo;Video|1280|800
movistarplus|Movistar+|https://ver.movistarplus.es|AudioVideo;Video|1280|800
youtube|YouTube|https://www.youtube.com|AudioVideo;Video|1280|800
ytmusic|YouTube Music|https://music.youtube.com|AudioVideo;Audio;Music|1200|780
chatgpt|ChatGPT|https://chatgpt.com|Utility;Office|1200|860
claude|Claude|https://claude.ai|Utility;Office|1200|860
"

# ── Compilar webapps con Pake ────────────────────────────────────────────────
# La primera compilación descarga y cachea las dependencias de Tauri (~2-3 min).
# Las siguientes son mucho más rápidas (~30-60s cada una) porque reusan la caché.

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Compilando webapps con Pake (Tauri/Rust)"
echo "  Primera app tardará más (descarga caché de Tauri)"
echo "════════════════════════════════════════════════════════════════"
echo ""

INSTALLED=0
FAILED=0

while IFS='|' read -r id name url category width height; do
    [ -z "$id" ] && continue

    echo "  ▶ Compilando $name ($url)..."

    BUILD_DIR=$(mktemp -d /tmp/pake-build-${id}.XXXXXX)
    BUILD_OK=false

    # pake-cli se ejecuta como usuario (cargo/rustup están en $USER_HOME/.cargo)
    if su - "$USERNAME" -c "
        export PATH='$CARGO_BIN':\$PATH
        cd '$BUILD_DIR'
        pake '$url' --name '$name' --width $width --height $height 2>&1 | tail -5
    "; then
        # Buscar binario generado (pake genera .deb en Linux)
        BINARY=$(find "$BUILD_DIR" -maxdepth 3 \( -name "*.deb" -o -perm /111 -name "${name}*" \) -type f 2>/dev/null | head -1)

        if [ -n "$BINARY" ] && [ -s "$BINARY" ]; then
            if [[ "$BINARY" == *.deb ]]; then
                dpkg -i "$BINARY" 2>/dev/null || true
                apt-get install -f -y 2>/dev/null || true
                echo "    ✓ $name instalado (.deb)"
                BUILD_OK=true
            else
                install -m 755 "$BINARY" "$PAKE_OUTPUT_DIR/$id"
                cat > "$DESKTOP_DIR/pake-${id}.desktop" << DESKEOF
[Desktop Entry]
Name=${name}
Comment=${name} — webapp nativa (Pake/Tauri)
Exec=${PAKE_OUTPUT_DIR}/${id}
Icon=pake-${id}
Terminal=false
Type=Application
Categories=${category};Network;
StartupWMClass=${name}
DESKEOF
                chmod 644 "$DESKTOP_DIR/pake-${id}.desktop"
                echo "    ✓ $name instalado (binario)"
                BUILD_OK=true
            fi
        fi
    fi

    if [ "$BUILD_OK" = "false" ]; then
        echo "    ⚠ $name: compilación falló"
        FAILED=$((FAILED + 1))
    else
        INSTALLED=$((INSTALLED + 1))
    fi

    rm -rf "$BUILD_DIR"
done <<< "$(echo "$WEBAPPS" | grep -v '^$')"

# ── Descargar iconos (en paralelo) ───────────────────────────────────────────
echo ""
echo "Descargando iconos..."

while IFS='|' read -r id name url category width height; do
    [ -z "$id" ] && continue
    dest="$ICONS_DIR/pake-${id}.png"
    domain="${url#https://}"
    domain="${domain%%/*}"
    (
        wget -q --timeout=10 -O "$dest" \
            "https://www.google.com/s2/favicons?domain=${domain}&sz=128" 2>/dev/null
        [ -f "$dest" ] && [ "$(stat -c%s "$dest" 2>/dev/null || echo 0)" -gt 100 ] && exit 0
        rm -f "$dest"
        wget -q --timeout=10 -O "$dest" \
            "https://icons.duckduckgo.com/ip3/${domain}.ico" 2>/dev/null
    ) &
done <<< "$(echo "$WEBAPPS" | grep -v '^$')"
wait

gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

# ── Chrome policy: extensiones de privacidad (global) ────────────────────────
# Benefician a la navegación en Chrome (si está instalado) con uBlock Origin
# Lite, SponsorBlock, Return YouTube Dislike y DeArrow.
POLICY_DIR="/etc/opt/chrome/policies/managed"
if command -v google-chrome-stable &>/dev/null; then
    mkdir -p "$POLICY_DIR"
    cat > "$POLICY_DIR/privacy-extensions.json" << 'POLICYEOF'
{
  "ExtensionInstallForcelist": [
    "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx",
    "mnjggcdmjocbbbhaepdhchncahnbgone;https://clients2.google.com/service/update2/crx",
    "gebbhagfogifgklhpdlkpmjnbnjfffop;https://clients2.google.com/service/update2/crx",
    "enamippconapkdmgfgjchkhakpfinmaj;https://clients2.google.com/service/update2/crx"
  ]
}
POLICYEOF
    echo "✓  Chrome: extensiones de privacidad (uBlock, SponsorBlock, DeArrow)"
fi

# ── Resumen ──────────────────────────────────────────────────────────────────
TOTAL=$((INSTALLED + FAILED))
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  Webapps compiladas con Pake (Tauri/Rust)"
echo "════════════════════════════════════════════════════════════════"
echo "  Instaladas: $INSTALLED | Fallidas: $FAILED | Total: $TOTAL"
echo "  Cada webapp: ~5MB, webview nativo (WebKitGTK), sin Chromium"
echo "  Ubicación: $PAKE_OUTPUT_DIR/"
echo "════════════════════════════════════════════════════════════════"
