#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# MÓDULO 10: GNOME Core — instalación y configuración de sistema
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
fi

echo "✓  Extension Manager + extensiones instaladas"
echo "   (defaults via gschema.override — activación definitiva en primer login)"

# ── Blur my Shell (GitHub releases → system-wide) ────────────────────────────
# Efecto cristal/glass en overview y app grid. sigma bajo + brightness alta
# = transparencia tipo vidrio esmerilado. Configuración vía dconf system-db.
echo ""
echo "Instalando Blur my Shell..."

BMS_UUID="blur-my-shell@aunetx"
BMS_DIR="/usr/share/gnome-shell/extensions/\$BMS_UUID"
BMS_ZIP="/tmp/blur-my-shell.zip"

BMS_ASSET_URL=\$(curl --max-time 30 --retry 2 -fsSL \
    "https://api.github.com/repos/aunetx/blur-my-shell/releases/latest" 2>/dev/null \
    | grep '"browser_download_url"' | grep '\.zip"' | head -1 | cut -d'"' -f4)

if [ -n "\$BMS_ASSET_URL" ] && wget -q --timeout=30 --tries=2 \
    "\$BMS_ASSET_URL" -O "\$BMS_ZIP" 2>/dev/null && [ -s "\$BMS_ZIP" ]; then

    mkdir -p "\$BMS_DIR"
    unzip -q -o "\$BMS_ZIP" -d "\$BMS_DIR"
    rm -f "\$BMS_ZIP"

    # Compilar schemas locales de la extensión
    if [ -d "\$BMS_DIR/schemas" ]; then
        glib-compile-schemas "\$BMS_DIR/schemas" 2>/dev/null || true
    fi

    # Copiar schema a schemas globales para poder usar gschema.override
    for f in "\$BMS_DIR/schemas/"*.gschema.xml; do
        [ -f "\$f" ] && cp "\$f" /usr/share/glib-2.0/schemas/
    done

    chmod -R 755 "\$BMS_DIR"
    echo "✓  Blur my Shell instalado (\$BMS_UUID)"
else
    echo "⚠  Blur my Shell: descarga fallida — se omite"
fi

# ── Alphabetical App Grid (GitHub releases → system-wide) ───────────────────
# Fuerza orden alfabético permanente en el app grid y dentro de carpetas.
# Sin esta extensión, GNOME usa orden "adaptativo" que se desordena solo.
echo ""
echo "Instalando Alphabetical App Grid..."

AAG_UUID="AlphabeticalAppGrid@stuarthayhurst"
AAG_DIR="/usr/share/gnome-shell/extensions/\$AAG_UUID"
AAG_ZIP="/tmp/alphabetical-grid.zip"

AAG_ASSET_URL=\$(curl --max-time 30 --retry 2 -fsSL \
    "https://api.github.com/repos/stuarthayhurst/alphabetical-grid-extension/releases/latest" 2>/dev/null \
    | grep '"browser_download_url"' | grep '\.zip"' | head -1 | cut -d'"' -f4)

if [ -n "\$AAG_ASSET_URL" ] && wget -q --timeout=30 --tries=2 \
    "\$AAG_ASSET_URL" -O "\$AAG_ZIP" 2>/dev/null && [ -s "\$AAG_ZIP" ]; then

    mkdir -p "\$AAG_DIR"
    unzip -q -o "\$AAG_ZIP" -d "\$AAG_DIR"
    rm -f "\$AAG_ZIP"

    if [ -d "\$AAG_DIR/schemas" ]; then
        glib-compile-schemas "\$AAG_DIR/schemas" 2>/dev/null || true
    fi

    chmod -R 755 "\$AAG_DIR"
    echo "✓  Alphabetical App Grid instalado (\$AAG_UUID)"
else
    echo "⚠  Alphabetical App Grid: descarga fallida — se omite"
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

# ── No overview at start-up (extensions.gnome.org → system-wide) ─────────────
# Evita que GNOME muestre el overview al iniciar sesión.
# NOTA: disable-overview-on-startup de ubuntu-dock/dash-to-panel se ha
# eliminado para evitar conflictos — esta extensión es el único mecanismo.
#
# Se descarga desde extensions.gnome.org (zip oficial) en lugar de git clone,
# que puede incluir ficheros extra y versiones incompatibles con la shell.
echo ""
echo "Instalando No overview at start-up..."

NOV_UUID="no-overview@fthx"
NOV_DIR="/usr/share/gnome-shell/extensions/\$NOV_UUID"
GNOME_MAJOR=\$(gnome-shell --version 2>/dev/null | grep -oP '[0-9]+' | head -1 || echo "")

NOV_INSTALLED=false

if [ -n "\$GNOME_MAJOR" ]; then
    # Método 1: API de extensions.gnome.org — obtiene el zip correcto para esta shell
    NOV_INFO=\$(curl --max-time 10 -s \
        "https://extensions.gnome.org/extension-info/?uuid=\${NOV_UUID}&shell_version=\${GNOME_MAJOR}" 2>/dev/null || echo "")

    NOV_DL=\$(echo "\$NOV_INFO" | grep -oP '"download_url"\s*:\s*"\K[^"]+' | head -1)

    if [ -n "\$NOV_DL" ]; then
        wget --timeout=15 -q "https://extensions.gnome.org\${NOV_DL}" -O /tmp/no-overview.zip 2>/dev/null
        if [ -f /tmp/no-overview.zip ]; then
            mkdir -p "\$NOV_DIR"
            unzip -qo /tmp/no-overview.zip -d "\$NOV_DIR"
            rm -f /tmp/no-overview.zip
            NOV_INSTALLED=true
            echo "  ✓ Descargado desde extensions.gnome.org (GNOME \$GNOME_MAJOR)"
        fi
    fi
fi

# Método 2: fallback a git clone si la API falla
if [ "\$NOV_INSTALLED" = "false" ]; then
    echo "  → Fallback: git clone desde GitHub..."
    if git clone --depth 1 -q https://github.com/fthx/no-overview.git \
            /tmp/no-overview-src 2>/dev/null; then
        mkdir -p "\$NOV_DIR"
        cp -r /tmp/no-overview-src/* "\$NOV_DIR/"
        rm -rf "\$NOV_DIR/.git" "\$NOV_DIR/.github" "\$NOV_DIR/README"* "\$NOV_DIR/LICENSE"*
        rm -rf /tmp/no-overview-src
        NOV_INSTALLED=true
    fi
fi

if [ "\$NOV_INSTALLED" = "true" ]; then
    # Inyectar la versión de GNOME en shell-version si no está ya
    if [ -n "\$GNOME_MAJOR" ] && [ -f "\$NOV_DIR/metadata.json" ]; then
        if ! grep -q "\"\$GNOME_MAJOR\"" "\$NOV_DIR/metadata.json"; then
            sed -i "s/\"shell-version\": \\[/\"shell-version\": [\"\$GNOME_MAJOR\", /" "\$NOV_DIR/metadata.json"
            echo "  → shell-version parcheado: añadido GNOME \$GNOME_MAJOR"
        fi
    fi

    # Desactivar validación de versión de extensiones
    gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true

    chmod -R 755 "\$NOV_DIR"
    echo "✓  No overview at start-up instalado (\$NOV_UUID)"
else
    echo "⚠  No overview at start-up: descarga fallida — se omite"
fi

# ── No Screenshot Box (git clone → system-wide) ─────────────────────────────
# Elimina el rectángulo de selección previa en la UI de captura de GNOME.
echo ""
echo "Instalando No Screenshot Box..."

NSB_UUID="no-screenshot-box@screenshot"
NSB_DIR="/usr/share/gnome-shell/extensions/\$NSB_UUID"

if git clone --depth 1 -q https://github.com/abdallah-alkanani/no-screenshot-box.git \
    /tmp/no-screenshot-box-src 2>/dev/null; then

    mkdir -p "\$NSB_DIR"
    cp -r /tmp/no-screenshot-box-src/* "\$NSB_DIR/"
    rm -rf "\$NSB_DIR/.git" "\$NSB_DIR/.github" "\$NSB_DIR/README"* "\$NSB_DIR/LICENSE"*
    rm -rf /tmp/no-screenshot-box-src

    if [ -d "\$NSB_DIR/schemas" ]; then
        glib-compile-schemas "\$NSB_DIR/schemas" 2>/dev/null || true
    fi

    chmod -R 755 "\$NSB_DIR"
    echo "✓  No Screenshot Box instalado (\$NSB_UUID)"
else
    echo "⚠  No Screenshot Box: descarga fallida — se omite"
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
# Flujo de gnome-keyring con PAM (referencia: wiki.gnome.org/Projects/GnomeKeyring/Pam):
#
#   auth     → pam_gnome_keyring.so: recibe la contraseña del login y desbloquea
#              el keyring "login". Si no existe, lo crea con esa contraseña.
#   session  → pam_gnome_keyring.so auto_start: arranca gnome-keyring-daemon
#              si no está corriendo.
#   password → pam_gnome_keyring.so: cuando el usuario cambia contraseña con
#              passwd, sincroniza la contraseña del keyring "login".
#
# Con autologin (gdm-autologin) no se introduce contraseña → PAM no puede
# desbloquear un keyring protegido → apps como Chrome/Chromium piden
# manualmente la contraseña del keyring en cada sesión.
# Solución: pre-crear el keyring "login" sin contraseña (vacío).
# ============================================================================

# 1. pam-auth-update integra gnome-keyring en common-auth/common-session
DEBIAN_FRONTEND=noninteractive pam-auth-update --enable gnome-keyring 2>/dev/null || true

# 2. Verificar/añadir líneas en ficheros PAM de GDM y login
for pam_file in /etc/pam.d/gdm-password /etc/pam.d/gdm-autologin /etc/pam.d/login; do
    [ ! -f "\$pam_file" ] && continue

    # auth: desbloquea el keyring con la contraseña del login
    if ! grep -q "pam_gnome_keyring.so" "\$pam_file"; then
        if grep -q "@include common-auth" "\$pam_file"; then
            sed -i '/^@include common-auth/a auth       optional     pam_gnome_keyring.so' "\$pam_file"
        fi
    fi

    # session: arranca gnome-keyring-daemon
    if ! grep -q "pam_gnome_keyring.so auto_start" "\$pam_file"; then
        if grep -q "@include common-session" "\$pam_file"; then
            sed -i '/^@include common-session/a session    optional     pam_gnome_keyring.so auto_start' "\$pam_file"
        fi
    fi
done

# 3. Hook de cambio de contraseña: sincroniza keyring cuando el usuario usa passwd
if [ -f /etc/pam.d/passwd ]; then
    if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/passwd; then
        echo "password    optional    pam_gnome_keyring.so" >> /etc/pam.d/passwd
    fi
fi

echo "✓  PAM: gnome-keyring integrado (auth + session + password)"

# ── Keyring "login" — preparar para desbloqueo automático ────────────────────
# Flujo según autologin:
#   - Con autologin: PAM no pasa contraseña → necesitamos pre-crear
#     login.keyring con contraseña VACÍA para que se desbloquee solo.
#   - Sin autologin: PAM pasa la contraseña del login al daemon, que crea
#     el keyring "login" con esa misma contraseña al primer inicio.
#     Si pre-creamos con contraseña vacía, PAM intenta desbloquear con
#     la contraseña real → no coincide → Chrome pide contraseña. MAL.
#     Solución: NO pre-crear login.keyring, solo el directorio y "default".
#
# Ref: ArchWiki GNOME/Keyring — "Using the keyring outside GNOME"
# Ref: gnome-keyring source — pkcs11/gkm/gkm-secret-binary.c

_prepare_keyring_dir() {
    local dest_dir="\$1"
    mkdir -p "\$dest_dir"
    rm -f "\$dest_dir"/*.keyring 2>/dev/null
    echo "login" > "\$dest_dir/default"
}

_create_empty_keyring() {
    local dest_dir="\$1"
    _prepare_keyring_dir "\$dest_dir"

    # Generar login.keyring en formato egg binario con contraseña vacía
    python3 -c "
import struct, hashlib, os, subprocess, sys
dest = sys.argv[1]
HEADER = b'GnomeKeyring\n\r\0\n'
name, salt, iters = b'login', os.urandom(8), 1000
buf = bytearray(HEADER)
buf.extend(struct.pack('BBBB', 0, 0, 0, 0))
buf.extend(struct.pack('>I', len(name))); buf.extend(name)
buf.extend(struct.pack('>III', 0, 0, 0))
buf.extend(struct.pack('>I', iters)); buf.extend(salt)
buf.extend(struct.pack('>IIII', 0, 0, 0, 0))
buf.extend(struct.pack('>I', 0))
pw, dig, n = b'', b'', 0
while len(dig) < 32:
    h = hashlib.sha256()
    if n > 0: h.update(dig[-32:] if len(dig) >= 32 else dig)
    h.update(pw); h.update(salt)
    st = h.digest()
    for _ in range(1, iters): st = hashlib.sha256(st).digest()
    dig += st; n += 1
key, iv = dig[:16], dig[16:32]
plain = struct.pack('>I', 0) + hashlib.md5(b'').digest()
pad = 16 - (len(plain) % 16)
if pad < 16: plain += bytes([pad] * pad)
ct = subprocess.run(['openssl', 'enc', '-aes-128-cbc', '-nosalt', '-nopad',
    '-K', key.hex(), '-iv', iv.hex()], input=plain, capture_output=True).stdout
buf.extend(struct.pack('>I', len(ct))); buf.extend(ct)
with open(dest, 'wb') as f: f.write(bytes(buf))
" "\$dest_dir/login.keyring" 2>/dev/null
}

GDM_AUTOLOGIN_ENABLED="$GDM_AUTOLOGIN"

# Siempre pre-crear login.keyring con contraseña vacía.
# Razón: en el primer login, gnome-keyring-daemon necesita que el fichero
# exista para poder desbloquearlo. Si solo existe "default" sin login.keyring,
# el daemon intenta abrir un keyring inexistente → "failed to allocate" → crash.
#
# Con contraseña vacía:
#   - Autologin: funciona directo (PAM no pasa contraseña, keyring vacío se desbloquea).
#   - Login con contraseña: PAM desbloquea el keyring vacío, y al primer
#     cambio de contraseña (o via seahorse), se re-encripta.
#
# Es el mismo comportamiento que Ubuntu Desktop installer usa.
if [ -n "\$USERNAME" ]; then
    KEYRING_DIR="/home/\$USERNAME/.local/share/keyrings"
    _create_empty_keyring "\$KEYRING_DIR"
    chown -R "\$USERNAME:\$USERNAME" "/home/\$USERNAME/.local/share/keyrings"
fi
_create_empty_keyring "/etc/skel/.local/share/keyrings"

if [ "\$GDM_AUTOLOGIN_ENABLED" = "true" ]; then
    echo "✓  GNOME Keyring: login.keyring vacío (autologin activo)"
else
    echo "✓  GNOME Keyring: login.keyring vacío (PAM lo re-encriptará al primer login)"
fi

# ── Gradia — screenshot tool nativo GTK4/libadwaita ──────────────────────────
# Compilado desde fuente (meson). Usa org.freedesktop.portal.Screenshot
# directamente — no necesita gnome-screenshot como dependencia.
# Ref: https://github.com/AlexanderVanhee/Gradia
echo ""
echo "Compilando Gradia (screenshot tool)..."

# Dependencias de compilación y runtime
# gir1.2-xdpgtk4-1.0 puede no existir en todas las versiones — se intenta sin forzar
apt-get install -y \
    git meson ninja-build blueprint-compiler gettext desktop-file-utils \
    python3 python3-gi python3-gi-cairo python3-pil gir1.2-gtk-4.0 \
    gir1.2-adw-1 gir1.2-gtksource-5 \
    libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
    libportal-dev libportal-gtk4-dev libsoup-3.0-dev 2>/dev/null || true
# Intentar xdpgtk4 por separado (no existe en Ubuntu 24.04 base)
apt-get install -y gir1.2-xdpgtk4-1.0 2>/dev/null || true

GRADIA_OK=false
GRADIA_BUILD="\$(mktemp -d /tmp/gradia-build.XXXXXX)"

if git clone --depth 1 https://github.com/AlexanderVanhee/Gradia.git "\$GRADIA_BUILD/gradia" 2>/dev/null; then
    cd "\$GRADIA_BUILD/gradia"

    # meson setup — capturar exit code real (sin pipe)
    if meson setup builddir --prefix=/usr > /tmp/gradia-meson.log 2>&1; then
        echo "  ✓ meson setup OK"
        if ninja -C builddir > /tmp/gradia-ninja.log 2>&1; then
            echo "  ✓ ninja build OK"
            if DESTDIR="" ninja -C builddir install > /dev/null 2>&1; then
                GRADIA_OK=true
            else
                # Fallback: ninja install sin DESTDIR
                ninja -C builddir install 2>/dev/null && GRADIA_OK=true
            fi
        else
            echo "  ⚠ ninja build falló — ver /tmp/gradia-ninja.log"
            tail -5 /tmp/gradia-ninja.log 2>/dev/null
        fi
    else
        echo "  ⚠ meson setup falló — ver /tmp/gradia-meson.log"
        tail -5 /tmp/gradia-meson.log 2>/dev/null
    fi
    cd /
fi
rm -rf "\$GRADIA_BUILD"

if [ "\$GRADIA_OK" = "true" ]; then
    # Compilar gschemas de Gradia si existen
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    # Actualizar desktop database
    update-desktop-database /usr/share/applications/ 2>/dev/null || true
    # Actualizar icon cache
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
    echo "✓  Gradia compilado e instalado"
    echo "  ✓ Gradia usa portal nativo (sin gnome-screenshot)"
else
    echo "⚠  Gradia: compilación falló — se omite"
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
# Eliminar el bloque ubuntu-dock (desde el comentario hasta la línea en blanco siguiente)
content = re.sub(
    r'# ── Dock \(ubuntu-dock.*?\n\n',
    '# Dock: Dash to Panel (configuración gestionada por la extensión)\n\n',
    content, flags=re.DOTALL
)
# Dash to Panel no necesita disable-overview-on-startup: la extensión
# no-overview@fthx se encarga de evitar el overview al iniciar sesión.
open(dst, 'w').write(content)
PYEOF
        echo "  gschema.override: sección ubuntu-dock omitida (usando Dash to Panel)"
    else
        cp "$OVERRIDE_SRC" "$OVERRIDE_DST"
    fi
    arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
    echo "✓  gschema.override instalado y compilado"
    echo "   (temas, fuentes, dock, workspaces, privacidad — activos sin primer login)"

    # ── Override condicional: screen-time-limits (solo GNOME >= 48) ───────────
    # Este schema no existe en GNOME < 48. Si se incluye en el override estático,
    # glib-compile-schemas falla y NINGÚN override se aplica.
    GNOME_MAJOR=$(arch-chroot "$TARGET" gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "0")
    if [ "${GNOME_MAJOR:-0}" -ge 48 ]; then
        cat > "$TARGET/usr/share/glib-2.0/schemas/99-screen-time-limits.gschema.override" << 'STLEOF'
[org.gnome.desktop.screen-time-limits]
history-enabled=false
STLEOF
        arch-chroot "$TARGET" glib-compile-schemas /usr/share/glib-2.0/schemas/
        echo "✓  screen-time-limits override instalado (GNOME $GNOME_MAJOR >= 48)"
    else
        echo "ℹ  screen-time-limits omitido (GNOME ${GNOME_MAJOR:-?} < 48 — schema no existe)"
    fi
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
#   - Configuración de extensiones de terceros (blur-my-shell)
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

# ── Blur my Shell — transparencia elegante, blur mínimo ──────────────────────
# Filosofía: transparencia > blur. Solo emborronar donde afecte legibilidad.
# sigma=0 (transparencia pura sin blur). brightness=1.0 (sin oscurecer).
# Overview: sin blur (fondo transparente limpio, se ve el wallpaper nítido).
# App folders: sin blur (transparencia pura para consistencia visual).
# Todo lo demás: desactivado.
[org/gnome/shell/extensions/blur-my-shell]
sigma=0
brightness=1.0
color=(0.0, 0.0, 0.0, 0.0)
noise-amount=0.0
noise-lightness=0.0
hacks-level=1

[org/gnome/shell/extensions/blur-my-shell/overview]
customize=true
sigma=0
brightness=1.0
blur=false
style-dialogs=1

[org/gnome/shell/extensions/blur-my-shell/appfolder]
blur=false

[org/gnome/shell/extensions/blur-my-shell/panel]
blur=false

[org/gnome/shell/extensions/blur-my-shell/dash-to-dock]
blur=false

[org/gnome/shell/extensions/blur-my-shell/applications]
blur=false

[org/gnome/shell/extensions/blur-my-shell/screenshot]
blur=false

[org/gnome/shell/extensions/blur-my-shell/lockscreen]
blur=false

[org/gnome/shell/extensions/blur-my-shell/window-list]
blur=false

# ── Gradia como herramienta de screenshot por defecto ─────────────────────────
# Keybindings estilo Windows 10 Recortes (Snipping Tool):
#   Print Screen      → Gradia (captura/edición)
#   Super+Shift+S     → Gradia (equivalente a Win+Shift+S)
#   Alt+Print Screen   → Gradia (captura ventana activa)
# Desactivar todos los atajos nativos de GNOME Shell para screenshots
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

# ── Dash to Panel — configuración estilo Zorin OS (solo si se eligió) ─────────
# Panel inferior con Activities button visible (workspace indicator) a la izquierda.
# Elementos: Show Apps (izq), Activities (izq), Taskbar (izq), Center (der),
#            Right box (der), Date menu (der), System menu (der), Desktop (der).
# panel-element-positions es un JSON stringificado indexado por monitor.
[org/gnome/shell/extensions/dash-to-panel]
panel-positions='{"0":"BOTTOM"}'
panel-sizes='{"0":48}'
panel-lengths='{"0":100}'
panel-anchors='{"0":"MIDDLE"}'
panel-element-positions='{"0":[{"element":"showAppsButton","visible":true,"position":"stackedTL"},{"element":"activitiesButton","visible":true,"position":"stackedTL"},{"element":"leftBox","visible":true,"position":"stackedTL"},{"element":"taskbar","visible":true,"position":"stackedTL"},{"element":"centerBox","visible":true,"position":"stackedBR"},{"element":"rightBox","visible":true,"position":"stackedBR"},{"element":"dateMenu","visible":true,"position":"stackedBR"},{"element":"systemMenu","visible":true,"position":"stackedBR"},{"element":"desktopButton","visible":true,"position":"stackedBR"}]}'
panel-element-positions-monitors-sync=true
show-activities-button=true
animate-appicon-hover=true
animate-appicon-hover-animation-type='SIMPLE'
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

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  GNOME CORE INSTALADO"
echo "════════════════════════════════════════════════════════════════"
echo ""

exit 0
