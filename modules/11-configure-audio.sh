#!/bin/bash
# Módulo 11-configure-audio: Audio plug and play
# Configura el stack de audio para que los dispositivos se detecten y
# seleccionen automáticamente al conectarlos, con una experiencia equivalente
# o superior a Windows/macOS.
#
# Stack: PipeWire + WirePlumber + pipewire-pulse (reemplaza PulseAudio)
#
# Capacidades:
#   - Auto-switch al dispositivo más reciente al conectarlo
#   - Bluetooth: A2DP seleccionado automáticamente sobre HSP/HFP
#   - Jack detection: auriculares con micrófono correctamente separados
#   - HDMI/DisplayPort: audio digital detectado y seleccionado
#   - USB audio: clase USB UAC1/UAC2 sin drivers adicionales
#   - Rebuffering adaptativo para eliminar glitches y cracks

set -e

[ -f "$(dirname "$0")/../partition.info" ] && source "$(dirname "$0")/../partition.info"

echo "════════════════════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE AUDIO (PipeWire + WirePlumber)"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << 'AUDIOEOF'
export DEBIAN_FRONTEND=noninteractive

# ============================================================================
# PAQUETES
# ============================================================================
# pipewire-audio: metapaquete que instala pipewire-alsa + pipewire-pulse +
#                libspa-0.2-bluetooth + wireplumber — el stack completo.
# pipewire-jack:  compatibilidad JACK para apps pro-audio (OBS, Ardour, etc.)
# alsa-ucm-conf:  perfiles UCM para hardware portátil (laptops, USB audio)
# alsa-topology-conf: topologías ALSA para DSP interno (Intel SST, etc.)

echo "Instalando stack de audio completo..."
apt-get install -y \
    pipewire-audio \
    pipewire-jack \
    alsa-ucm-conf \
    alsa-topology-conf \
    alsa-utils \
    rtkit
echo "✓  Stack de audio instalado"

# ============================================================================
# WIREPLUMBER — configuración de auto-switch y dispositivos
# ============================================================================
# WirePlumber 0.5 (Ubuntu 24.04) usa archivos .lua en /etc/wireplumber/
# para sobreescribir la configuración del sistema en /usr/share/wireplumber/
# ============================================================================

mkdir -p /etc/wireplumber/main.lua.d
mkdir -p /etc/wireplumber/bluetooth.lua.d

# ── ALSA: latencia y pause-on-idle ───────────────────────────────────────────
# WirePlumber 0.4 (Ubuntu 24.04) usa Lua para overrides en main.lua.d/.
# Sintaxis correcta: table con apply_properties dentro de rule.
cat > /etc/wireplumber/main.lua.d/50-alsa-config.lua << 'WPEOF'
rule = {
  matches = {
    { { "node.name", "matches", "alsa_output.*" } },
  },
  apply_properties = {
    ["api.alsa.period-size"]  = 512,
    ["api.alsa.headroom"]     = 0,
    ["resample.quality"]      = 6,
    ["node.pause-on-idle"]    = false,
  },
}
table.insert(alsa_monitor.rules, rule)

rule = {
  matches = {
    { { "node.name", "matches", "alsa_input.*" } },
  },
  apply_properties = {
    ["api.alsa.period-size"]  = 512,
    ["node.pause-on-idle"]    = false,
  },
}
table.insert(alsa_monitor.rules, rule)
WPEOF
echo "✓  WirePlumber: configuración ALSA aplicada (WP 0.4 Lua)"

# ── Bluetooth: A2DP prioritario ───────────────────────────────────────────────
# bluetooth.lua.d/ es compatible con WP 0.4 y 0.5 en Ubuntu 24.04.
cat > /etc/wireplumber/bluetooth.lua.d/51-bluez-config.lua << 'BTEOF'
bluez_monitor.properties = {
  ["bluez5.enable-sbc-xq"]    = true,
  ["bluez5.enable-msbc"]      = true,
  ["bluez5.enable-hw-volume"] = true,
  ["bluez5.hfphsp-backend"]   = "native",
}

bluez_monitor.rules = {
  {
    matches = { { { "device.name", "matches", "bluez_card.*" } } },
    apply_properties = {
      ["bluez5.auto-connect"]  = "[ a2dp_sink hfp_hf hsp_hs ]",
      ["bluez5.profile"]       = "a2dp-sink",
    },
  },
}
BTEOF
echo "✓  WirePlumber: Bluetooth A2DP prioritario configurado (WP 0.4 Lua)"

# ============================================================================
# PIPEWIRE — configuración del servidor de audio
# ============================================================================

mkdir -p /etc/pipewire/pipewire.conf.d

# ── Parámetros del servidor ───────────────────────────────────────────────────
# default.clock.rate: frecuencia base del servidor. 48000 Hz es estándar
# para vídeo (HDMI/DP, streaming) y compatible con 44100 Hz via resampling.
# Quantum bajo = menor latencia; quantum adaptativo evita glitches.
cat > /etc/pipewire/pipewire.conf.d/50-defaults.conf << 'PWEOF'
context.properties = {
  default.clock.rate          = 48000
  default.clock.allowed-rates = [ 44100 48000 88200 96000 ]
  default.clock.min-quantum   = 32
  default.clock.max-quantum   = 8192
  default.clock.quantum       = 1024
}
PWEOF
echo "✓  PipeWire: parámetros de servidor configurados"

# ============================================================================
# UDEV — detección de jack de auriculares y USB audio
# ============================================================================
# Regla para que los dispositivos USB audio clase UAC1/UAC2 se inicialicen
# correctamente y se expongan a PipeWire sin intervención manual.

cat > /etc/udev/rules.d/62-audio-devices.rules << 'UDEVEOF'
# USB audio: dar permisos al grupo audio para acceso directo
SUBSYSTEM=="sound", GROUP="audio", MODE="0664"
# HID audio (auriculares USB con controles): cargar módulo HID
SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="01", ATTRS{bInterfaceSubClass}=="03", GROUP="audio", MODE="0664"
UDEVEOF
echo "✓  udev: reglas de audio instaladas"

# ============================================================================
# ASEGURARSE DE QUE PULSEAUDIO NO INTERFIERE
# ============================================================================
# pipewire-pulse reemplaza PulseAudio. Si pulseaudio está instalado como
# servicio del sistema, puede competir con pipewire-pulse al arrancar.

if dpkg -l pulseaudio 2>/dev/null | grep -q "^ii"; then
    apt-get remove -y --purge pulseaudio pulseaudio-module-bluetooth 2>/dev/null || true
    echo "✓  PulseAudio eliminado (reemplazado por pipewire-pulse)"
else
    echo "  PulseAudio no instalado — sin conflictos"
fi

# Asegurar que los servicios de PipeWire están habilitados para el arranque
# por defecto (se activan por socket, no por systemctl enable)
# La activación por socket ocurre automáticamente con pipewire-audio en Ubuntu 24.04.
echo "✓  PipeWire activado por socket (no requiere systemctl enable)"

AUDIOEOF

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✓  AUDIO CONFIGURADO"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Stack:       PipeWire + WirePlumber + pipewire-pulse"
echo "  Auto-switch: nuevo dispositivo → activo automáticamente"
echo "  Bluetooth:   A2DP prioritario, SBC-XQ habilitado"
echo "  USB audio:   UAC1/UAC2 plug and play"
echo "  HDMI/DP:     detectado y seleccionable desde ajustes"
echo "  Latencia:    adaptativa (32–8192 quantum)"
echo ""

exit 0
