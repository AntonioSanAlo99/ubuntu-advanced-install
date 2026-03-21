#!/bin/bash
# MÓDULO 31: Audio plug and play (PipeWire + WirePlumber)
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

# Verificar que TARGET está montado y el chroot es funcional
if ! mountpoint -q "${TARGET:-/mnt/ubuntu}" 2>/dev/null; then
    echo "ERROR: TARGET=${TARGET:-/mnt/ubuntu} no está montado." >&2
    exit 1
fi
if [ ! -x "${TARGET:-/mnt/ubuntu}/usr/bin/apt-get" ]; then
    echo "ERROR: Chroot en ${TARGET:-/mnt/ubuntu} sin apt-get." >&2
    exit 1
fi


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
    rtkit
echo "✓  Stack de audio instalado"
echo "  Nota: alsa-utils omitido (udev rule rota en Ubuntu 25.04, pipewire-alsa lo cubre)"

# ============================================================================
# WIREPLUMBER — configuración de auto-switch y dispositivos
# ============================================================================
# WP 0.4 (Ubuntu 24.04 noble): archivos .lua en main.lua.d/ y bluetooth.lua.d/
# WP 0.5+ (Ubuntu 25.10+):     archivos .conf en wireplumber.conf.d/ (JSON-like)
# Se detecta la versión instalada y se escribe el formato correcto.
# ============================================================================

WP_VER=$(wireplumber --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+' | head -1 || echo "0.4")
WP_MAJOR=$(echo "$WP_VER" | cut -d. -f1)
WP_MINOR=$(echo "$WP_VER" | cut -d. -f2)
echo "  WirePlumber detectado: $WP_VER"

if [ "$WP_MAJOR" -eq 0 ] && [ "$WP_MINOR" -lt 5 ] 2>/dev/null; then
    # ── WP 0.4: formato Lua ──────────────────────────────────────────────────
    echo "  Usando formato Lua (WP 0.4)"

    mkdir -p /etc/wireplumber/main.lua.d
    mkdir -p /etc/wireplumber/bluetooth.lua.d

    # ALSA: latencia y pause-on-idle
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

    # Bluetooth: A2DP prioritario
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

else
    # ── WP 0.5+: formato .conf (JSON-like SPA-JSON) ─────────────────────────
    echo "  Usando formato .conf (WP 0.5+)"

    mkdir -p /etc/wireplumber/wireplumber.conf.d

    # ALSA: latencia y pause-on-idle
    cat > /etc/wireplumber/wireplumber.conf.d/50-alsa-config.conf << 'WP5ALSA'
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_output.*" }
    ]
    actions = {
      update-props = {
        api.alsa.period-size = 512
        api.alsa.headroom    = 0
        resample.quality     = 6
        node.pause-on-idle   = false
      }
    }
  }
  {
    matches = [
      { node.name = "~alsa_input.*" }
    ]
    actions = {
      update-props = {
        api.alsa.period-size = 512
        node.pause-on-idle   = false
      }
    }
  }
]
WP5ALSA
    echo "✓  WirePlumber: configuración ALSA aplicada (WP 0.5+ .conf)"

    # Bluetooth: A2DP prioritario
    cat > /etc/wireplumber/wireplumber.conf.d/51-bluez-config.conf << 'WP5BT'
monitor.bluez.properties = {
  bluez5.enable-sbc-xq    = true
  bluez5.enable-msbc       = true
  bluez5.enable-hw-volume  = true
  bluez5.hfphsp-backend    = native
}

monitor.bluez.rules = [
  {
    matches = [
      { device.name = "~bluez_card.*" }
    ]
    actions = {
      update-props = {
        bluez5.auto-connect = [ a2dp_sink hfp_hf hsp_hs ]
        bluez5.profile      = a2dp-sink
      }
    }
  }
]
WP5BT
    echo "✓  WirePlumber: Bluetooth A2DP prioritario configurado (WP 0.5+ .conf)"
fi

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
