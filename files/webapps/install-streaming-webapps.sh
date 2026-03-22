#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# install-streaming-webapps.sh — Genera webapps de streaming para Google Chrome
#
# Crea .desktop files que abren cada servicio como ventana aislada de Chrome
# con soporte DRM (Widevine incluido en Chrome). Descarga iconos oficiales
# de cada servicio en 128x128 para el menú de aplicaciones.
#
# Servicios: Netflix, HBO Max, Prime Video, Disney+, Filmin, DAZN, Movistar+
#
# Uso: Se ejecuta dentro del chroot durante la instalación.
#      Requiere google-chrome-stable instalado.
# ══════════════════════════════════════════════════════════════════════════════

ICONS_DIR="/usr/share/icons/hicolor/128x128/apps"
DESKTOP_DIR="/usr/share/applications"
CHROME_BIN="/usr/bin/google-chrome-stable"

mkdir -p "$ICONS_DIR" "$DESKTOP_DIR"

# ── Verificar Chrome ─────────────────────────────────────────────────────────
if [ ! -x "$CHROME_BIN" ]; then
    echo "⚠  Google Chrome no encontrado — webapps de streaming omitidas"
    exit 0
fi

echo "Generando webapps de streaming (Chrome + Widevine DRM)..."

# ── Definición de servicios ──────────────────────────────────────────────────
# Formato: ID|Nombre|URL|URL_Icono_fallback
# Los iconos se descargan de Google S2 favicon service (128px) o del CDN del
# servicio. Si falla, se usa un SVG genérico de video.
SERVICES="
netflix|Netflix|https://www.netflix.com|https://assets.nflxext.com/us/ffe/siteui/common/icons/nficon2016.png
hbomax|HBO Max|https://play.max.com|https://play.max.com/favicon.ico
primevideo|Prime Video|https://www.primevideo.com|https://m.media-amazon.com/images/G/01/digital/video/web/Logo-min.png
disneyplus|Disney+|https://www.disneyplus.com|https://static-assets.bamgrid.com/product/disneyplus/favicons/favicon-96x96.png
filmin|Filmin|https://www.filmin.es|https://www.filmin.es/favicon.ico
dazn|DAZN|https://www.dazn.com|https://www.dazn.com/favicon.ico
movistarplus|Movistar+|https://ver.movistarplus.es|https://ver.movistarplus.es/favicon.ico
"

# ── Generar SVG genérico de video como fallback ─────────────────────────────
FALLBACK_SVG="$ICONS_DIR/webapp-streaming.svg"
if [ ! -f "$FALLBACK_SVG" ]; then
    cat > "$FALLBACK_SVG" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="20" fill="#1a1a2e"/>
  <polygon points="48,32 48,96 96,64" fill="#e94560"/>
</svg>
SVGEOF
fi

# ── Función: descargar icono ─────────────────────────────────────────────────
download_icon() {
    local id="$1" url="$2" fallback_url="$3"
    local dest="$ICONS_DIR/webapp-${id}.png"

    # Ya existe
    [ -f "$dest" ] && [ -s "$dest" ] && return 0

    # Método 1: Google S2 favicon service (128px, alta calidad)
    wget -q --timeout=10 -O "$dest" \
        "https://www.google.com/s2/favicons?domain=${url#https://}&sz=128" 2>/dev/null
    [ -f "$dest" ] && [ -s "$dest" ] && [ "$(stat -c%s "$dest" 2>/dev/null)" -gt 500 ] && return 0

    # Método 2: URL directa del servicio
    if [ -n "$fallback_url" ]; then
        wget -q --timeout=10 -O "$dest" "$fallback_url" 2>/dev/null
        [ -f "$dest" ] && [ -s "$dest" ] && return 0
    fi

    # Método 3: favicon estándar del dominio
    local domain="${url#https://}"
    domain="${domain%%/*}"
    wget -q --timeout=10 -O "$dest" "https://${domain}/favicon.ico" 2>/dev/null
    [ -f "$dest" ] && [ -s "$dest" ] && return 0

    # Fallback: copiar SVG genérico
    rm -f "$dest"
    cp "$FALLBACK_SVG" "$ICONS_DIR/webapp-${id}.svg" 2>/dev/null
    return 1
}

# ── Función: crear .desktop ──────────────────────────────────────────────────
create_desktop() {
    local id="$1" name="$2" url="$3"
    local icon_name="webapp-${id}"
    local desktop_file="$DESKTOP_DIR/${icon_name}.desktop"

    # Determinar icono (png si existe, svg como fallback)
    local icon_path="$ICONS_DIR/${icon_name}.png"
    [ ! -f "$icon_path" ] && icon_path="$ICONS_DIR/${icon_name}.svg"
    [ ! -f "$icon_path" ] && icon_path="webapp-streaming"

    cat > "$desktop_file" << DESKEOF
[Desktop Entry]
Name=${name}
Comment=Streaming — ${name} (Chrome)
Exec=${CHROME_BIN} --app=${url} --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --enable-widevine
Icon=${icon_name}
Terminal=false
Type=Application
Categories=AudioVideo;Video;Network;
StartupWMClass=chrome-${url#https://}-Default
DESKEOF

    chmod 644 "$desktop_file"
}

# ── Procesar cada servicio ───────────────────────────────────────────────────
INSTALLED=0
echo "$SERVICES" | while IFS='|' read -r id name url icon_url; do
    [ -z "$id" ] && continue

    if download_icon "$id" "$url" "$icon_url"; then
        echo "  ✓ ${name} (icono descargado)"
    else
        echo "  ⚠ ${name} (icono fallback)"
    fi

    create_desktop "$id" "$name" "$url"
    INSTALLED=$((INSTALLED + 1))
done

# Actualizar caché de iconos
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

echo "✓  Webapps de streaming instaladas (7 servicios)"
echo "   Chrome con Widevine DRM — ventanas aisladas --app="

# ============================================================================
# YOUTUBE + YOUTUBE MUSIC — webapps con extensiones de privacidad
# ============================================================================
# Estas webapps usan un perfil Chrome dedicado (/opt/youtube-profile) con
# extensiones de privacidad preinstaladas vía Chrome managed policy:
#
#   - uBlock Origin Lite (MV3) — bloqueo de anuncios
#   - SponsorBlock           — skip de sponsors dentro del vídeo
#   - Return YouTube Dislike — restaura el contador de dislikes
#   - DeArrow                — títulos y thumbnails sin clickbait
#
# Esto replica las funciones clave de FreeTube sin sacrificar la integración
# con la cuenta de Google ni la compatibilidad con YouTube.
# ============================================================================

echo ""
echo "Configurando webapps YouTube con extensiones de privacidad..."

YT_PROFILE="/opt/youtube-chrome-profile"
POLICY_DIR="/etc/opt/chrome/policies/managed"

mkdir -p "$YT_PROFILE" "$POLICY_DIR"

# ── Chrome policy: extensiones de privacidad (autoinstaladas + autoactualizadas)
# Se aplica a todas las instancias de Chrome. Las 4 extensiones son beneficiosas
# en cualquier contexto (adblock, antisponsor, dislikes, antclickbait).
# Chrome las descarga del Web Store en el primer arranque y las actualiza solo.
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

echo "  ✓ Extensiones de privacidad configuradas (policy global Chrome)"
echo "    uBlock Origin Lite, SponsorBlock, Return YT Dislike, DeArrow"
echo "    Se autoinstalan y autoactualizan desde el Web Store"

# ── Iconos de YouTube ────────────────────────────────────────────────────────
download_icon "youtube" "https://www.youtube.com" \
    "https://www.youtube.com/s/desktop/f1e2c4a1/img/favicon_144x144.png"
download_icon "ytmusic" "https://music.youtube.com" \
    "https://music.youtube.com/img/on_platform_logo_dark.svg"

# ── .desktop YouTube ─────────────────────────────────────────────────────────
# Perfil dedicado (--user-data-dir) para separar historial/cookies de YouTube
# del Chrome principal. Las extensiones se aplican a ambos perfiles via policy.
cat > "$DESKTOP_DIR/webapp-youtube.desktop" << YTEOF
[Desktop Entry]
Name=YouTube
Comment=YouTube — privacidad mejorada (SponsorBlock, uBlock, DeArrow)
Exec=${CHROME_BIN} --app=https://www.youtube.com --user-data-dir=${YT_PROFILE} --enable-features=VaapiVideoDecoder,VaapiVideoEncoder
Icon=webapp-youtube
Terminal=false
Type=Application
Categories=AudioVideo;Video;Network;
StartupWMClass=chrome-www.youtube.com-Default
YTEOF
chmod 644 "$DESKTOP_DIR/webapp-youtube.desktop"
echo "  ✓ YouTube webapp"

# ── .desktop YouTube Music ───────────────────────────────────────────────────
cat > "$DESKTOP_DIR/webapp-ytmusic.desktop" << YMEOF
[Desktop Entry]
Name=YouTube Music
Comment=YouTube Music — privacidad mejorada (SponsorBlock, uBlock, DeArrow)
Exec=${CHROME_BIN} --app=https://music.youtube.com --user-data-dir=${YT_PROFILE} --enable-features=VaapiVideoDecoder,VaapiVideoEncoder
Icon=webapp-ytmusic
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Network;
StartupWMClass=chrome-music.youtube.com-Default
YMEOF
chmod 644 "$DESKTOP_DIR/webapp-ytmusic.desktop"
echo "  ✓ YouTube Music webapp"

# Actualizar caché de iconos (de nuevo, por los nuevos iconos)
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

echo ""
echo "✓  YouTube + YouTube Music configurados con extensiones de privacidad"
echo "   Las extensiones se instalarán automáticamente en el primer arranque"

# ============================================================================
# CHATGPT + CLAUDE.AI — webapps de IA como apps standalone
# ============================================================================
# Chrome --app= en versiones modernas soporta:
#   - Drag & drop de archivos nativamente (input type=file + drop zones)
#   - Popups de SSO/OAuth (Google, Microsoft, Apple) en ventana auxiliar
#   - Clipboard, notificaciones, service workers
#
# No se necesitan flags especiales — Chrome gestiona los popups de login
# externo abriéndolos en una ventana nueva del mismo perfil.
# ============================================================================

echo ""
echo "Configurando webapps de IA (ChatGPT, Claude)..."

# ── Iconos ───────────────────────────────────────────────────────────────────
download_icon "chatgpt" "https://chatgpt.com" \
    "https://cdn.oaistatic.com/assets/apple-touch-icon-mz9nytnj.png"
download_icon "claude" "https://claude.ai" \
    "https://claude.ai/images/claude_app_icon.png"

# ── .desktop ChatGPT ─────────────────────────────────────────────────────────
cat > "$DESKTOP_DIR/webapp-chatgpt.desktop" << CGEOF
[Desktop Entry]
Name=ChatGPT
Comment=ChatGPT — OpenAI
Exec=${CHROME_BIN} --app=https://chatgpt.com
Icon=webapp-chatgpt
Terminal=false
Type=Application
Categories=Utility;Office;Network;
StartupWMClass=chrome-chatgpt.com__-Default
MimeType=text/plain;
CGEOF
chmod 644 "$DESKTOP_DIR/webapp-chatgpt.desktop"
echo "  ✓ ChatGPT webapp"

# ── .desktop Claude ──────────────────────────────────────────────────────────
cat > "$DESKTOP_DIR/webapp-claude.desktop" << CLEOF
[Desktop Entry]
Name=Claude
Comment=Claude — Anthropic
Exec=${CHROME_BIN} --app=https://claude.ai
Icon=webapp-claude
Terminal=false
Type=Application
Categories=Utility;Office;Network;
StartupWMClass=chrome-claude.ai__-Default
MimeType=text/plain;
CLEOF
chmod 644 "$DESKTOP_DIR/webapp-claude.desktop"
echo "  ✓ Claude webapp"

# Actualizar caché de iconos
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

echo ""
echo "✓  Webapps de IA instaladas (ChatGPT, Claude)"
echo "   Soporte drag & drop de archivos y login SSO (Google/Microsoft/Apple)"
