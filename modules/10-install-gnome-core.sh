#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 10: GNOME Core — instalación y configuración de sistema
# REQUIERE: TARGET, USERNAME, GNOME_DOCK, GDM_AUTOLOGIN, IS_LAPTOP, PERF_OOMD_AGGRESSIVE, INSTALL_GRADIA, UBUNTU_VERSION
# PRODUCE:  GNOME Shell + extensiones + dconf + GDM
#
# ARQUITECTURA DE CONFIGURACIÓN (3 capas, mismo patrón que Zorin OS / Bazzite):
#
#   1. gschema.override  (/usr/share/glib-2.0/schemas/)
#      Defaults del sistema: temas, fuentes, dock, workspaces, privacidad...
#      Aplica sin D-Bus, sin primer login, para todos los usuarios.
#      El usuario puede sobreescribirlos libremente desde Ajustes.
#
#   2. dconf system-db   (/etc/dconf/db/local.d/ + dconf update)
#      Keys que NO tienen schema instalado antes del paquete correspondiente
#      o que necesitan valores dinámicos (ej. versión de GNOME en runtime).
#      También aplica sin D-Bus, para todos los usuarios.
#
#   3. Script primer login  (10-user-config.sh → /etc/xdg/autostart/)
#      Solo lo que genuinamente necesita D-Bus activo:
#      - Activar extensiones (merge con lista existente)
#      - Carpetas del app grid (schema relocatable)
#      - Wallpaper (detección dinámica de archivo)
#      - Archivos de usuario (~/.config/gnome-shell/gnome-shell.css)
#      - Apps ocultas (~/.local/share/applications/)
# ══════════════════════════════════════════════════════════════════════════════

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

[ -z "${GNOME_DOCK:-}" ] && GNOME_DOCK=$(_yaml_val "gnome" "dock" "dash-to-panel")
[ -z "${GDM_AUTOLOGIN:-}" ] && GDM_AUTOLOGIN=$(_yaml_val "gnome" "autologin" "true")
[ -z "${USERNAME:-}" ] && USERNAME=$(_yaml_val "system" "username" "")
[ -z "${UBUNTU_VERSION:-}" ] && UBUNTU_VERSION=$(_yaml_val "system" "ubuntu_version" "noble")
[ -z "${IS_LAPTOP:-}" ] && IS_LAPTOP=$(_yaml_val "system" "is_laptop" "false")
[ -z "${PERF_OOMD_AGGRESSIVE:-}" ] && PERF_OOMD_AGGRESSIVE=$(_yaml_val "performance" "oomd_aggressive" "true")
[ -z "${INSTALL_GRADIA:-}" ] && INSTALL_GRADIA=$(_yaml_val "extras" "gradia" "false")


# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


# ============================================================================
# CHROOT: PAQUETES
# ============================================================================

arch-chroot "$TARGET" /bin/bash << CHROOTEOF
export DEBIAN_FRONTEND=noninteractive

# ── GNOME Shell + core ──────────────────────────────────────────────────────
echo "Instalando GNOME Shell y componentes core..."

apt-get install -y \
    gnome-shell \
    gnome-session \
    gnome-settings-daemon \
    gnome-control-center \
    gnome-terminal \
    nautilus \
    nautilus-admin \
    xdg-terminal-exec \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    gdm3 \
    plymouth \
    plymouth-theme-spinner \
    bolt \
    gnome-keyring \
    libpam-gnome-keyring \
    at-spi2-core

echo "✓  GNOME Shell instalado"

# ── Utilidades ──────────────────────────────────────────────────────────────
echo "Instalando utilidades..."

apt-get install -y \
    gnome-calculator bc \
    gnome-logs \
    gnome-font-viewer \
    baobab \
    lxtask \
    file-roller \
    gedit \
    evince \
    viewnior \
    gnome-disk-utility \
    gnome-tweaks \
    nm-connection-editor \
    geary \
    foliate \
    zenity \
    default-jre

# KDiskMark — benchmark de disco (kdiskmark en repos desde 22.04)
apt-get install -y kdiskmark \
    && echo "✓  KDiskMark instalado" \
    || echo "⚠  KDiskMark no disponible en este Ubuntu — omitido"

echo "✓  Utilidades instaladas"

# ── Gestión de software ─────────────────────────────────────────────────────
apt-get install -y \
    software-properties-gtk \
    gdebi \
    update-manager \
    curl \
    file

# ── Extension Manager (solo instalación — la activación va en user-config) ──
apt-get install -y gnome-shell-extension-manager

# ── Extensiones APT (solo instalación — la activación va en user-config) ────
apt-get install -y \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-desktop-icons-ng

GNOME_DOCK_CHOICE="$GNOME_DOCK"

if [ "\$GNOME_DOCK_CHOICE" = "dash-to-panel" ]; then
    echo "Instalando Dash to Panel..."

    EXT_UUID="dash-to-panel@jderose9.github.com"
    EXT_DIR="/usr/share/gnome-shell/extensions/\$EXT_UUID"
    EXT_ZIP="/tmp/dash-to-panel.zip"

    # Descargar desde GitHub releases (home-sweet-gnome/dash-to-panel)
    # Cada release publica un asset zip con nombre: dash-to-panel@jderose9.github.com_vXX.zip
    # Se usa la API de GitHub para obtener la URL del primer asset .zip del último release.
    DTP_ASSET_URL=\$(curl --max-time 30 --retry 2 -fsSL \
        "https://api.github.com/repos/home-sweet-gnome/dash-to-panel/releases/latest" 2>/dev/null \
        | grep '"browser_download_url"' | grep '\.zip"' | head -1 | cut -d'"' -f4)

    if [ -n "\$DTP_ASSET_URL" ] && wget -q --timeout=30 --tries=2 \
        "\$DTP_ASSET_URL" -O "\$EXT_ZIP" 2>/dev/null && [ -s "\$EXT_ZIP" ]; then

        mkdir -p "\$EXT_DIR"
        unzip -q -o "\$EXT_ZIP" -d "\$EXT_DIR"
        rm -f "\$EXT_ZIP"

        # Compilar schemas si los tiene — requerido para que la extensión arranque
        if [ -d "\$EXT_DIR/schemas" ]; then
            glib-compile-schemas "\$EXT_DIR/schemas" 2>/dev/null || true
        fi

        echo "✓  Dash to Panel instalado (\$EXT_UUID)"
    else
        echo "⚠  Dash to Panel: descarga fallida — se usará Ubuntu Dock"
        GNOME_DOCK_CHOICE="ubuntu-dock"
    fi
fi

if [ "\$GNOME_DOCK_CHOICE" = "ubuntu-dock" ]; then
    apt-get install -y gnome-shell-extension-ubuntu-dock
    echo "✓  Ubuntu Dock instalado"

    # ── Arc Menu (extensions.gnome.org → system-wide) ─────────────────────────
    # Reemplaza el botón Show Apps del dock con un lanzador de vista de workspace.
    # Requiere: libgnome-menu-3-0 gir1.2-gmenu-3.0
    echo ""
    echo "Instalando Arc Menu..."
    apt-get install -y libgnome-menu-3-0 gir1.2-gmenu-3.0

    AM_UUID="arcmenu@arcmenu.com"
    AM_DIR="/usr/share/gnome-shell/extensions/\$AM_UUID"
    GNOME_MAJOR=\$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+' | head -1 || echo "")
    AM_INSTALLED=false

    if [ -n "\$GNOME_MAJOR" ]; then
        AM_INFO=\$(curl --max-time 15 -s \
            "https://extensions.gnome.org/extension-info/?uuid=\${AM_UUID}&shell_version=\${GNOME_MAJOR}" \
            2>/dev/null || echo "")
        AM_DL=\$(echo "\$AM_INFO" | grep -oP '"download_url"\s*:\s*"\K[^"]+' | head -1)

        if [ -n "\$AM_DL" ]; then
            wget --timeout=30 -q "https://extensions.gnome.org\${AM_DL}" -O /tmp/arcmenu.zip 2>/dev/null
            if [ -s /tmp/arcmenu.zip ]; then
                mkdir -p "\$AM_DIR"
                unzip -qo /tmp/arcmenu.zip -d "\$AM_DIR"
                rm -f /tmp/arcmenu.zip
                AM_INSTALLED=true
                echo "  ✓ Descargado desde extensions.gnome.org (GNOME \$GNOME_MAJOR)"
            fi
        fi
    fi

    if [ "\$AM_INSTALLED" = "false" ]; then
        echo "⚠  Arc Menu: descarga fallida — se omite"
    else
        if [ -d "\$AM_DIR/schemas" ]; then
            glib-compile-schemas "\$AM_DIR/schemas" 2>/dev/null || true
            for f in "\$AM_DIR/schemas/"*.gschema.xml; do
                [ -f "\$f" ] && cp "\$f" /usr/share/glib-2.0/schemas/
            done
        fi
        chmod -R 755 "\$AM_DIR"
        echo "✓  Arc Menu instalado (\$AM_UUID)"
    fi
fi

echo "✓  Extension Manager + extensiones instaladas"
echo "   (defaults via gschema.override — activación definitiva en primer login)"

# ── V-Shell / vertical-workspaces (GitHub releases → system-wide) ─────────────
# V-Shell reemplaza tres extensiones anteriores en uno:
#   - blur-my-shell@aunetx       → blur integrado en overview y app grid
#   - AlphabeticalAppGrid        → app grid ordenado alfabéticamente
#   - no-overview@fthx           → startup-state configurable (sin overview)
#
# Compatible con Dash to Panel (auto-desactiva sus módulos Dash/Panel/Layout
# al detectar DtP). UUID: vertical-workspaces@G-dH.github.com
# Repo: https://github.com/G-dH/vertical-workspaces  GNOME 45-49.
echo ""
echo "Instalando V-Shell (vertical-workspaces)..."

VS_UUID="vertical-workspaces@G-dH.github.com"
VS_DIR="/usr/share/gnome-shell/extensions/\$VS_UUID"
VS_ZIP="/tmp/vertical-workspaces.zip"

VS_ASSET_URL=\$(curl --max-time 30 --retry 2 -fsSL \
    "https://api.github.com/repos/G-dH/vertical-workspaces/releases/latest" 2>/dev/null \
    | grep '"browser_download_url"' | grep '\.zip"' | head -1 | cut -d'"' -f4)

if [ -n "\$VS_ASSET_URL" ] && wget -q --timeout=30 --tries=2 \
    "\$VS_ASSET_URL" -O "\$VS_ZIP" 2>/dev/null && [ -s "\$VS_ZIP" ]; then

    mkdir -p "\$VS_DIR"
    unzip -q -o "\$VS_ZIP" -d "\$VS_DIR"
    rm -f "\$VS_ZIP"

    # Compilar schemas locales de la extensión
    if [ -d "\$VS_DIR/schemas" ]; then
        glib-compile-schemas "\$VS_DIR/schemas" 2>/dev/null || true
    fi

    # Copiar schema a schemas globales para poder usar gschema.override
    for f in "\$VS_DIR/schemas/"*.gschema.xml; do
        [ -f "\$f" ] && cp "\$f" /usr/share/glib-2.0/schemas/
    done

    chmod -R 755 "\$VS_DIR"
    echo "✓  V-Shell instalado (\$VS_UUID)"
else
    echo "⚠  V-Shell: descarga fallida — se omite"
fi

# ── Caffeine (git clone → system-wide) ──────────────────────────────────────
# Desactiva screensaver y auto-suspensión con un toggle en el panel.
echo ""
echo "Instalando Caffeine..."

CAFF_UUID="caffeine@patapon.info"
CAFF_DIR="/usr/share/gnome-shell/extensions/\$CAFF_UUID"

if git clone --depth 1 -q https://github.com/eonpatapon/gnome-shell-extension-caffeine.git \
    /tmp/caffeine-src 2>/dev/null; then

    mkdir -p "\$CAFF_DIR"
    cp -r /tmp/caffeine-src/caffeine@patapon.info/* "\$CAFF_DIR/" 2>/dev/null || \
        cp -r /tmp/caffeine-src/* "\$CAFF_DIR/"
    rm -rf /tmp/caffeine-src

    if [ -d "\$CAFF_DIR/schemas" ]; then
        glib-compile-schemas "\$CAFF_DIR/schemas" 2>/dev/null || true
    fi

    chmod -R 755 "\$CAFF_DIR"
    echo "✓  Caffeine instalado (\$CAFF_UUID)"
else
    echo "⚠  Caffeine: descarga fallida — se omite"
fi

# ── systemd-oomd ─────────────────────────────────────────────────────────────
if systemctl list-unit-files systemd-oomd.service &>/dev/null; then
    systemctl enable systemd-oomd 2>/dev/null || true

    # Configuración agresiva solo si PERF_OOMD_AGGRESSIVE=true
    OOMD_AGG="$PERF_OOMD_AGGRESSIVE"
    if [ "\$OOMD_AGG" = "true" ]; then
        mkdir -p /etc/systemd/oomd.conf.d
        cat > /etc/systemd/oomd.conf.d/50-aggressive.conf << 'OOMDEOF'
[OOM]
SwapUsedLimit=90%
DefaultMemoryPressureLimit=60%
DefaultMemoryPressureDurationUSec=20s
OOMDEOF

        mkdir -p /etc/systemd/system/user-.slice.d
        cat > /etc/systemd/system/user-.slice.d/50-oomd.conf << 'SLICEEOF'
[Slice]
ManagedOOMSwap=kill
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=80%
SLICEEOF
        echo "✓  systemd-oomd: configuración agresiva (swap 90%, presión 60%/20s)"
    else
        echo "✓  systemd-oomd habilitado (defaults de systemd)"
    fi
fi

# ── Tema de iconos + GTK ────────────────────────────────────────────────────
apt-get install -y elementary-icon-theme gnome-themes-extra
echo "✓  Iconos elementary + temas GTK"

# ── Wallpapers ──────────────────────────────────────────────────────────────
CODENAME=\$(. /etc/os-release 2>/dev/null && echo "\${VERSION_CODENAME:-}" || echo "")
[ -z "\$CODENAME" ] && CODENAME="$UBUNTU_VERSION"
apt-get install -y ubuntu-wallpapers 2>/dev/null || true
apt-get install -y "ubuntu-wallpapers-\${CODENAME}" 2>/dev/null || true

# ── Wallpaper custom (Homer Simpson) ────────────────────────────────────────
HOMER_URL="https://preview.redd.it/homer-simpson-v0-llud0j7a7ch21.jpg?width=1080&crop=smart&auto=webp&s=68770264c88bb9d083e194f66db50c8de7fc8a7b"
HOMER_DEST="/usr/share/backgrounds/homer-simpson.jpg"
if curl --max-time 15 --retry 2 -fsSL -o "\$HOMER_DEST" "\$HOMER_URL" 2>/dev/null \
   && [ -s "\$HOMER_DEST" ]; then
    chmod 644 "\$HOMER_DEST"
    echo "✓  Wallpaper Homer descargado"
else
    rm -f "\$HOMER_DEST"
    echo "⚠  Wallpaper Homer: descarga falló — se usará el de Ubuntu"
fi

echo "✓  Wallpapers instalados"

# ── GDM ──────────────────────────────────────────────────────────────────────
# Habilitar GDM y establecer graphical.target como default.
# Sin set-default graphical.target el sistema arranca en multi-user.target
# (modo consola) y la pantalla queda en negro.

# systemctl enable gdm3 crea los symlinks correctos en wants/
systemctl enable gdm3

# Establecer graphical.target como target de arranque por defecto
systemctl set-default graphical.target

echo "✓  GDM habilitado, target por defecto: graphical.target"

GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"
GDM_USER="$USERNAME"
mkdir -p /etc/gdm3

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then
    cat > /etc/gdm3/custom.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=GDM_USER_PLACEHOLDER
[security]
[xdmcp]
[chooser]
[debug]
GDMCONF
    sed -i "s/GDM_USER_PLACEHOLDER/$USERNAME/" /etc/gdm3/custom.conf
    echo "✓  Autologin configurado ($USERNAME)"
else
    cat > /etc/gdm3/custom.conf << 'GDMCONF'
[daemon]
AutomaticLoginEnable=False
[security]
[xdmcp]
[chooser]
[debug]
GDMCONF
    echo "✓  GDM: login con contraseña"
fi

# ── GNOME Keyring — integración PAM ─────────────────────────────────────────
# gnome-keyring y libpam-gnome-keyring ya se instalaron en el bloque de
# paquetes. pam-auth-update es el método oficial de Ubuntu/Debian para
# integrar módulos PAM — añade las líneas correctas en common-auth,
# common-session y common-password automáticamente.
#
# NO tocar ficheros PAM manualmente (sed en /etc/pam.d/*). Ubuntu los
# gestiona via pam-auth-update y cualquier edición manual puede romperse
# en actualizaciones o causar duplicación de líneas.
# ============================================================================

DEBIAN_FRONTEND=noninteractive pam-auth-update --enable gnome-keyring 2>/dev/null || true
echo "✓  PAM: gnome-keyring integrado via pam-auth-update"

# ── Keyring "login" — preparar directorio ────────────────────────────────────
# Solo crear el directorio. NO pre-crear el fichero "default" — gnome-keyring-daemon
# lo crea él mismo al inicializar. Un fichero "default" apuntando a "login" sin
# un login.keyring correspondiente causa: "gkr-pam: couldn't unlock the login keyring"

if [ -n "\$USERNAME" ]; then
    KEYRING_DIR="/home/\$USERNAME/.local/share/keyrings"
    mkdir -p "\$KEYRING_DIR"
    chown -R "\$USERNAME:\$USERNAME" "/home/\$USERNAME/.local"
fi
mkdir -p /etc/skel/.local/share/keyrings

# ── Autologin: desbloqueo automático del keyring ─────────────────────────────
# Con autologin, GDM no pasa contraseña a PAM → gkr-pam no puede desbloquear
# el keyring → error "gkr-pam: couldn't unlock the login keyring".
#
# Solución (ArchWiki + distros gaming): crear un keyring con contraseña vacía
# ANTES del primer boot. Así gkr-pam encuentra el keyring y lo desbloquea
# sin necesitar contraseña.
#
# Método: python3 + secretstorage para crear el keyring con contraseña vacía.
# Si python3-secretstorage no está disponible, fallback a borrar el keyring
# (gnome-keyring-daemon lo recreará con contraseña vacía al arrancar).
GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then

    # Método 1: Borrar cualquier keyring existente y crear directorio limpio.
    # gnome-keyring-daemon, al no encontrar login.keyring y tener autologin
    # (sin contraseña PAM), creará uno nuevo con contraseña vacía en el
    # primer arranque. El fichero "default" apunta a "login".
    if [ -n "\$USERNAME" ] && [ -d "/home/\$USERNAME" ]; then
        KEYRING_DIR="/home/\$USERNAME/.local/share/keyrings"
        rm -f "\$KEYRING_DIR/login.keyring" 2>/dev/null
        # NO crear fichero default aquí — gnome-keyring-daemon lo gestiona
    fi
    rm -f /etc/skel/.local/share/keyrings/login.keyring 2>/dev/null

    # Método 2: Autostart que desbloquea el keyring con contraseña vacía.
    # Esto es un safety net: si gkr-pam falla (bug GNOME 48+), el autostart
    # desbloquea el keyring cuando se inicia la sesión gráfica.
    mkdir -p /etc/skel/.config/autostart
    cat > /etc/skel/.config/autostart/unlock-keyring.desktop << 'UNLOCKEOF'
[Desktop Entry]
Type=Application
Name=Unlock Keyring
Exec=/bin/sh -c 'echo -n "" | gnome-keyring-daemon --unlock 2>/dev/null; exit 0'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=PreDisplayServer
UNLOCKEOF

    # Copiar al usuario principal
    if [ -n "\$USERNAME" ] && [ -d "/home/\$USERNAME" ]; then
        mkdir -p "/home/\$USERNAME/.config/autostart"
        cp /etc/skel/.config/autostart/unlock-keyring.desktop \
           "/home/\$USERNAME/.config/autostart/"
        chown -R "\$USERNAME:\$USERNAME" "/home/\$USERNAME/.config"
    fi

    # Método 3: Configurar GDM para pasar contraseña vacía a PAM en autologin.
    # En /etc/gdm3/custom.conf, AutomaticLogin ya está configurado más arriba.
    # Añadir configuración PAM específica para gdm-autologin que incluya
    # gnome-keyring con auto_start.
    if [ -f /etc/pam.d/gdm-autologin ]; then
        if ! grep -q 'pam_gnome_keyring' /etc/pam.d/gdm-autologin; then
            echo "auth       optional     pam_gnome_keyring.so" >> /etc/pam.d/gdm-autologin
            echo "session    optional     pam_gnome_keyring.so auto_start" >> /etc/pam.d/gdm-autologin
            echo "  ✓  PAM gdm-autologin: gnome-keyring añadido"
        fi
    fi

    echo "✓  GNOME Keyring: configurado para autologin (contraseña vacía)"
else
    echo "✓  GNOME Keyring: PAM desbloqueará con contraseña del login"
fi

# ── Google Chrome ────────────────────────────────────────────────────────────
echo ""
echo "Instalando Google Chrome..."

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg 2>/dev/null || true

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list

apt-get update 2>/dev/null || true
apt-get install -y google-chrome-stable && echo "✓  Chrome instalado" \
    || echo "⚠  Chrome: instálalo manualmente tras el primer boot"

# ── AppImage: libfuse ────────────────────────────────────────────────────────
# libfuse2 — necesario para ejecutar AppImages (FUSE v2)
apt-get install -y libfuse2t64 2>/dev/null || apt-get install -y libfuse2 2>/dev/null || true

# ── Eliminar gnome-initial-setup ─────────────────────────────────────────────
# Este paquete muestra un asistente de bienvenida al primer login (idioma,
# cuentas online, etc.) que da aspecto de "sistema sin configurar".
# Con Install-Recommends=false normalmente no se instala, pero si algún
# paquete lo arrastra como dependencia, lo eliminamos explícitamente.
# El fichero gnome-initial-setup-done en /etc/skel ya existe (módulo 03).
apt-get purge -y gnome-initial-setup 2>/dev/null || true

# ── Déjà Dup — backups integrados en GNOME ──────────────────────────────────
echo ""
echo "Instalando Déjà Dup (backups)..."
apt-get install -y deja-dup
echo "✓  Déjà Dup instalado"

# ── Thumbnails de vídeo en Nautilus ──────────────────────────────────────────
# ffmpegthumbnailer genera previews de vídeos (.mp4, .mkv, .avi, etc.)
# Nautilus lo detecta automáticamente via /usr/share/thumbnailers/
apt-get install -y ffmpegthumbnailer 2>/dev/null || true
echo "✓  ffmpegthumbnailer instalado (thumbnails de vídeo en Nautilus)"

# ── GNOME Sushi — previsualización rápida con barra espaciadora ──────────────
# Seleccionar archivo en Nautilus → pulsar Espacio → preview instantáneo.
# Soporta: imágenes, PDFs, vídeos, audio, texto (con syntax highlighting), SVG.
# Flechas ←→ para navegar entre archivos sin cerrar el preview.
# Equivalente a Quick Look de macOS. Parte de GNOME core desde 3.2.
apt-get install -y gnome-sushi 2>/dev/null || true
echo "✓  GNOME Sushi instalado (Espacio = preview rápido en Nautilus)"

# ── Archivos comprimidos: ABRIR por defecto (no extraer) ─────────────────────
# file-roller ya está instalado. Configuramos como handler por defecto de
# todos los formatos de archivo comprimido para que al hacer doble clic
# se ABRA (explorar contenido) en vez de extraer automáticamente.
# Esto se aplica en /etc/skel y para el usuario principal.
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/mimeapps.list << 'MIMEAPPS'
[Default Applications]
application/zip=org.gnome.FileRoller.desktop
application/x-tar=org.gnome.FileRoller.desktop
application/x-compressed-tar=org.gnome.FileRoller.desktop
application/x-bzip2-compressed-tar=org.gnome.FileRoller.desktop
application/x-xz-compressed-tar=org.gnome.FileRoller.desktop
application/x-zstd-compressed-tar=org.gnome.FileRoller.desktop
application/gzip=org.gnome.FileRoller.desktop
application/x-7z-compressed=org.gnome.FileRoller.desktop
application/x-rar=org.gnome.FileRoller.desktop
application/x-rar-compressed=org.gnome.FileRoller.desktop
application/vnd.rar=org.gnome.FileRoller.desktop
application/x-lzma-compressed-tar=org.gnome.FileRoller.desktop
application/x-lz4-compressed-tar=org.gnome.FileRoller.desktop
application/x-iso9660-image=org.gnome.FileRoller.desktop
application/x-deb=org.gnome.FileRoller.desktop
application/x-rpm=org.gnome.FileRoller.desktop
application/x-cpio=org.gnome.FileRoller.desktop
application/x-ar=org.gnome.FileRoller.desktop
MIMEAPPS

# También como default global del sistema (para GDM y usuarios sin .config)
mkdir -p /usr/share/applications
if [ -f /usr/share/applications/mimeapps.list ]; then
    # Añadir sin sobreescribir las entradas existentes
    cat /etc/skel/.config/mimeapps.list >> /usr/share/applications/mimeapps.list
else
    cp /etc/skel/.config/mimeapps.list /usr/share/applications/mimeapps.list
fi

# Copiar al usuario principal si ya existe
USERNAME_VAR="$USERNAME"
if [ -n "\$USERNAME_VAR" ] && [ -d "/home/\$USERNAME_VAR" ]; then
    mkdir -p "/home/\$USERNAME_VAR/.config"
    cp /etc/skel/.config/mimeapps.list "/home/\$USERNAME_VAR/.config/mimeapps.list"
    chown "\$USERNAME_VAR:\$USERNAME_VAR" "/home/\$USERNAME_VAR/.config/mimeapps.list"
fi

echo "✓  Archivos comprimidos: abrir con File Roller por defecto (explorar, no extraer)"

# ── Detalles de batería para portátiles ──────────────────────────────────────
# upower ya viene con gnome-shell (dependencia de gir1.2-upowerglib-1.0).
# GNOME Settings (Configuración → Energía) muestra porcentaje, estado, tiempo
# restante y perfil de energía sin necesidad de gnome-power-manager (deprecated).
# power-profiles-daemon se instala en módulo 32 si es laptop.
IS_LAPTOP_VAR="$IS_LAPTOP"
if [ "\$IS_LAPTOP_VAR" = "true" ]; then
    echo ""
    echo "✓  Monitor de batería: GNOME Settings → Energía (upower integrado)"
fi

CHROOTEOF

# ============================================================================
# CAPA 1: GSCHEMA OVERRIDE — defaults de sistema
# ============================================================================
# Mismo patrón que Zorin OS y Ubuntu: copiar el .gschema.override al directorio
# de schemas de GNOME y compilar. Los valores son defaults (no locks): el usuario
# puede sobreescribirlos desde Ajustes o Extension Manager sin restricciones.
#
# Se instala DESPUÉS de los paquetes para que los schemas de las extensiones
# (ubuntu-dock, etc.) ya estén disponibles cuando se ejecuta glib-compile-schemas.
# glib-compile-schemas --strict falla si referencia un schema no instalado.

OVERRIDE_SRC="$(dirname "$0")/../files/99-ubuntu-advanced-install.gschema.override"
OVERRIDE_DST="$TARGET/usr/share/glib-2.0/schemas/99-ubuntu-advanced-install.gschema.override"

if [ -f "$OVERRIDE_SRC" ]; then
    # Generar override con la sección de dock correcta según la elección del usuario.
    # El archivo fuente siempre contiene la sección ubuntu-dock; si el usuario eligió
    # Dash to Panel, se elimina esa sección (DtP gestiona sus propios defaults).
    if [ "${GNOME_DOCK:-ubuntu-dock}" = "dash-to-panel" ]; then
        # Eliminar bloque [org.gnome.shell.extensions.ubuntu-dock] completo
        python3 - "$OVERRIDE_SRC" "$OVERRIDE_DST" << 'PYEOF'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
content = open(src).read()
# Eliminar desde el comentario de Dock hasta la siguiente sección [xxx]
# que NO sea ubuntu-dock. Esto captura la cabecera + [ubuntu-dock] + todas
# las keys (click-action, scroll-action, transparency, etc.)
content = re.sub(
    r'# ── Dock \(ubuntu-dock[^\[]*\[org\.gnome\.shell\.extensions\.ubuntu-dock\][^[]*(?=\n\[)',
    '# Dock: Dash to Panel (configuración gestionada por la extensión)\n',
    content, flags=re.DOTALL
)
open(dst, 'w').write(content)
PYEOF
        echo "  gschema.override: sección ubuntu-dock omitida (usando Dash to Panel)"
    else
        cp "$OVERRIDE_SRC" "$OVERRIDE_DST"
    fi
    # No compilar aún — se hace una sola vez al final (después de screen-time-limits)

    # ── Override condicional: screen-time-limits (solo GNOME >= 48) ───────────
    # Este schema no existe en GNOME < 48. Si se incluye en el override estático,
    # glib-compile-schemas falla y NINGÚN override se aplica.
    GNOME_MAJOR=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "0")
    if [ "${GNOME_MAJOR:-0}" -ge 48 ]; then
        cat > "$TARGET/usr/share/glib-2.0/schemas/99-screen-time-limits.gschema.override" << 'STLEOF'
[org.gnome.desktop.screen-time-limits]
history-enabled=false
STLEOF
        echo "✓  screen-time-limits override añadido (GNOME $GNOME_MAJOR >= 48)"

        # GNOME 48+: sort-directories-first fue eliminado de Nautilus (es default).
        # Eliminar la key del override principal si existe para evitar warnings.
        if [ -f "$OVERRIDE_DST" ]; then
            sed -i '/sort-directories-first/d' "$OVERRIDE_DST"
            echo "✓  sort-directories-first eliminado del override (GNOME $GNOME_MAJOR — ya es default)"
        fi
    else
        echo "ℹ  screen-time-limits omitido (GNOME ${GNOME_MAJOR:-?} < 48 — schema no existe)"
        # GNOME < 48: sort-directories-first existe y se usa — no tocar el override
    fi

    # ── Compilar todos los schemas de una sola vez ────────────────────────────
    # gschema.override + screen-time-limits + schemas de extensiones copiados al
    # directorio global durante la instalación de cada extensión
    arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "✓  glib-compile-schemas: todos los schemas compilados en una pasada"
else
    echo "⚠  No se encontró files/99-ubuntu-advanced-install.gschema.override"
fi

# ============================================================================
# CAPA 2: DCONF SYSTEM-DB — valores dinámicos y keys sin schema previo
# ============================================================================
# /etc/dconf/db/local.d/ es el equivalente al "system-db" de Bazzite/Fedora.
# Aplica a todos los usuarios, sin D-Bus, sin primer login.
# El perfil /etc/dconf/profile/user define el orden de búsqueda:
#   user-db:user  → ~/.config/dconf/user  (mayor prioridad, escritura)
#   system-db:local → /etc/dconf/db/local (menor prioridad, solo lectura)

arch-chroot "$TARGET" /bin/bash << 'DCONF_SYSTEM'

# ── Perfil dconf: user → local ────────────────────────────────────────────────
# Sin este archivo, dconf no sabe que existe un system-db y lo ignora.
# Mismo patrón que Ubuntu, Zorin OS y Bazzite.
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user << 'PROFILE'
user-db:user
system-db:local
PROFILE

mkdir -p /etc/dconf/db/local.d

# ── Valores dinámicos que requieren runtime en chroot ─────────────────────────
# (no pueden ir en gschema.override porque dependen de la versión instalada)
GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+\.[0-9.]+' | head -1 || echo "99.0")

cat > /etc/dconf/db/local.d/00-ubuntu-advanced-install << DCONF_EOF
# ═══════════════════════════════════════════════════════════════════════════════
# dconf system-db — solo keys que NO pueden ir en gschema.override
#
# gschema.override ya cubre: temas, fuentes, dock, workspaces, privacidad,
# power, peripherals, favorite-apps. NO duplicar aquí.
#
# Este archivo solo contiene:
#   - Keys con valores dinámicos (GNOME_VER)
#   - Keys que no tienen schema override (experimental-features, donation)
#   - Configuración de extensiones de terceros (vertical-workspaces / V-Shell)
#   - App grid layout reset
# ═══════════════════════════════════════════════════════════════════════════════

# ── Sistema ───────────────────────────────────────────────────────────────────
[org/gnome/shell]
welcome-dialog-last-shown-version='${GNOME_VER}'
app-picker-layout=@aa{sv} []

# ── Mutter — experimental-features + workspaces (locked) ─────────────────────
# Los workspaces están duplicados aquí a propósito: los locks de dconf fijan
# los valores del system-db, así que DEBEN estar presentes aquí para que
# los locks funcionen. El gschema.override define el default; el system-db
# + lock lo hace inmutable (Ubuntu no puede pisarlo en el user-db).
[org/gnome/mutter]
experimental-features=['xwayland-native-scaling']
dynamic-workspaces=false
workspaces-only-on-primary=true

[org/gnome/desktop/wm/preferences]
num-workspaces=1

# ── Donaciones GNOME — no tiene schema override disponible ────────────────────
[org/gnome/settings-daemon/plugins/housekeeping]
donation-reminder-enabled=false

# ── V-Shell (vertical-workspaces) — configuración base ───────────────────────
# La configuración efectiva se aplica via dconf write en el primer login
# (módulo 11) porque las extensiones de terceros no leen system-db fielmente.
# Aquí se dejan los defaults mínimos para que dconf update los vea disponibles.
[org/gnome/shell/extensions/vertical-workspaces]
startup-state=1
ws-thumbnails-position=9

# ── Dash to Panel — configuración estilo Zorin OS (solo si se eligió) ─────────
# Panel inferior. Activities a la izquierda del calendario (zona derecha).
# Orden izquierda: Show Apps, Taskbar, Left box.
# Orden derecha:   Center, Right box, Activities, Date, System, Desktop.
# panel-element-positions es un JSON stringificado indexado por monitor.
[org/gnome/shell/extensions/dash-to-panel]
panel-positions='{"0":"BOTTOM"}'
panel-sizes='{"0":48}'
panel-lengths='{"0":100}'
panel-anchors='{"0":"MIDDLE"}'
panel-element-positions='{"0":[{"element":"showAppsButton","visible":true,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"stackedTL"},{"element":"centerBox","visible":true,"position":"stackedBR"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"activitiesButton","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'
panel-element-positions-monitors-sync=true
show-activities-button=true
animate-appicon-hover=false
dot-style-focused='SEGMENTED'
dot-style-unfocused='DOTS'
trans-use-custom-opacity=true
trans-panel-opacity=0.35
intellihide=false
show-window-previews=true
group-apps=true
click-action='CYCLE-MIN'

DCONF_EOF

# ── dconf locks — evitar que Ubuntu sobreescriba workspaces en el user-db ────
# Ubuntu (via gnome-initial-setup o ubuntu-session) escribe dynamic-workspaces=true
# en el user-db durante el primer login, pisando gschema.override y system-db.
# Los locks hacen que estas keys sean de solo lectura desde el system-db.
mkdir -p /etc/dconf/db/local.d/locks
cat > /etc/dconf/db/local.d/locks/00-workspaces << 'LOCKS'
/org/gnome/mutter/dynamic-workspaces
/org/gnome/mutter/workspaces-only-on-primary
/org/gnome/desktop/wm/preferences/num-workspaces
LOCKS

dconf update

echo "✓  dconf system-db configurado (workspaces, welcome-dialog, privacidad)"
DCONF_SYSTEM

# ── Gradia: keybindings de screenshot (solo si se instala Gradia) ─────────────
# Se añade FUERA del heredoc DCONF_SYSTEM para poder condicionar con la variable
# del host. Si INSTALL_GRADIA=false, se mantienen los atajos nativos de GNOME.
if [ "${INSTALL_GRADIA:-false}" = "true" ]; then
    arch-chroot "$TARGET" /bin/bash << 'GRADIA_DCONF'
cat >> /etc/dconf/db/local.d/00-ubuntu-advanced-install << 'GRADIA_EOF'

# ── Gradia como herramienta de screenshot por defecto ─────────────────────────
[org/gnome/shell/keybindings]
show-screenshot-ui=@as []
screenshot=@as []
screenshot-window=@as []
show-screen-recording-ui=@as []

[org/gnome/settings-daemon/plugins/media-keys]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-print/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-super/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-alt/']
screenshot=@as []
screenshot-clip=@as []
window-screenshot=@as []
window-screenshot-clip=@as []

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-print]
name='Gradia (Print Screen)'
command='gradia'
binding='Print'

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-super]
name='Gradia (Super+Shift+S)'
command='gradia'
binding='<Super><Shift>s'

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/gradia-alt]
name='Gradia (Alt+Print Screen)'
command='gradia'
binding='<Alt>Print'
GRADIA_EOF

dconf update
echo "✓  Keybindings de Gradia configurados"
GRADIA_DCONF
else
    echo "ℹ  Gradia no seleccionado — atajos nativos de screenshot de GNOME intactos"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
