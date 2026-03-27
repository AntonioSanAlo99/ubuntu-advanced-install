#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# install-streaming-webapps.sh — Genera webapps con Chrome --app=URL
#
# Cada webapp se crea como un .desktop que lanza Chrome en modo app
# (ventana independiente, sin barra de navegación). Resultado idéntico
# a "Crear acceso directo" de Chrome pero automatizado.
#
# Ventajas vs Pake/Tauri:
#   - 0 compilación, 0 dependencias extra (solo Chrome)
#   - ~4KB por webapp vs ~5MB binario
#   - Actualizaciones de seguridad via Chrome (no binarios estáticos)
#
# Servicios: Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN,
#            Movistar+, YouTube, YouTube Music, ChatGPT, Claude
# ══════════════════════════════════════════════════════════════════════════════

set -e

DESKTOP_DIR="/usr/share/applications"
ICONS_DIR="/usr/share/icons/hicolor/128x128/apps"

mkdir -p "$DESKTOP_DIR" "$ICONS_DIR"

# ── Verificar Chrome ─────────────────────────────────────────────────────────
CHROME_BIN=""
for bin in google-chrome-stable google-chrome chromium-browser chromium; do
    if command -v "$bin" &>/dev/null; then
        CHROME_BIN="$bin"
        break
    fi
done

if [ -z "$CHROME_BIN" ]; then
    echo "⚠  Chrome/Chromium no encontrado — webapps omitidas"
    exit 0
fi

echo "Usando navegador: $CHROME_BIN"

# ── Definición de webapps ────────────────────────────────────────────────────
# Formato: ID|Nombre|URL|Categoría
WEBAPPS="
netflix|Netflix|https://www.netflix.com|AudioVideo;Video
hbomax|HBO Max|https://play.max.com|AudioVideo;Video
primevideo|Prime Video|https://www.primevideo.com|AudioVideo;Video
disneyplus|Disney+|https://www.disneyplus.com|AudioVideo;Video
filmin|Filmin|https://www.filmin.es|AudioVideo;Video
dazn|DAZN|https://www.dazn.com|AudioVideo;Video
movistarplus|Movistar+|https://ver.movistarplus.es|AudioVideo;Video
youtube|YouTube|https://www.youtube.com|AudioVideo;Video
ytmusic|YouTube Music|https://music.youtube.com|AudioVideo;Audio;Music
chatgpt|ChatGPT|https://chatgpt.com|Utility;Office
claude|Claude|https://claude.ai|Utility;Office
"

# ── Crear .desktop + descargar iconos ────────────────────────────────────────
INSTALLED=0

while IFS='|' read -r id name url category; do
    [ -z "$id" ] && continue

    DESKTOP_FILE="$DESKTOP_DIR/webapp-${id}.desktop"
    ICON_NAME="webapp-${id}"
    ICON_FILE="$ICONS_DIR/${ICON_NAME}.png"

    # .desktop
    cat > "$DESKTOP_FILE" << DESKEOF
[Desktop Entry]
Name=${name}
Comment=${name} — webapp (Chrome)
Exec=${CHROME_BIN} --app=${url} --class=webapp-${id}
Icon=${ICON_NAME}
Terminal=false
Type=Application
Categories=${category};Network;
StartupWMClass=webapp-${id}
StartupNotify=true
DESKEOF
    chmod 644 "$DESKTOP_FILE"

    # Icono (intentar Google favicons, fallback DuckDuckGo)
    domain="${url#https://}"
    domain="${domain%%/*}"
    (
        wget -q --timeout=10 -O "$ICON_FILE" \
            "https://www.google.com/s2/favicons?domain=${domain}&sz=128" 2>/dev/null
        if [ ! -s "$ICON_FILE" ] || [ "$(stat -c%s "$ICON_FILE" 2>/dev/null || echo 0)" -lt 100 ]; then
            rm -f "$ICON_FILE"
            wget -q --timeout=10 -O "$ICON_FILE" \
                "https://icons.duckduckgo.com/ip3/${domain}.ico" 2>/dev/null
        fi
    ) &

    INSTALLED=$((INSTALLED + 1))
    echo "  ✓ $name → webapp-${id}.desktop"
done <<< "$(echo "$WEBAPPS" | grep -v '^$')"

wait

# Actualizar caché de iconos
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

# ── Chrome policy: extensiones de privacidad ─────────────────────────────────
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
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  Webapps instaladas (Chrome --app)"
echo "════════════════════════════════════════════════════════════════"
echo "  Total: $INSTALLED webapps"
echo "  Método: Chrome --app (ventana nativa, sin barra de navegación)"
echo "  Naming: webapp-*.desktop (consistente con App Grid)"
echo "════════════════════════════════════════════════════════════════"
