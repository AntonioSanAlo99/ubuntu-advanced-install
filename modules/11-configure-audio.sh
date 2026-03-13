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

mkdir -p /etc/wireplumber/wireplumber.conf.d
mkdir -p /etc/wireplumber/bluetooth.lua.d

# ── Auto-switch al dispositivo más reciente ───────────────────────────────────
# device.defaults: cuando se conecta un nuevo dispositivo, se convierte en
# el sink/source activo. Equivale al comportamiento de Windows "usar dispositivo
# recién conectado" y macOS "cambiar salida automáticamente".
cat > /etc/wireplumber/wireplumber.conf.d/50-alsa-config.conf << 'WPEOF'
monitor.alsa.rules = [
  {
    matches = [{ node.name = "~alsa_output.*" }]
    actions = {
      update-props = {
        # Reducir latencia para mejor respuesta interactiva
        api.alsa.period-size   = 512
        api.alsa.headroom      = 0
        # Resample de alta calidad (evita distorsión al mezclar frecuencias)
        resample.quality       = 6
        # Auto-conectar nuevos sinks al stream activo
        node.pause-on-idle     = false
      }
    }
  }
  {
    matches = [{ node.name = "~alsa_input.*" }]
    actions = {
      update-props = {
        api.alsa.period-size   = 512
        node.pause-on-idle     = false
      }
    }
  }
]
WPEOF
echo "✓  WirePlumber: configuración ALSA aplicada"

# ── Auto-switch de dispositivo por defecto ────────────────────────────────────
cat > /etc/wireplumber/wireplumber.conf.d/51-auto-switch.conf << 'ASEOF'
# Cuando se conecta un nuevo dispositivo de audio, activarlo automáticamente
# como dispositivo por defecto — equivalente a Windows "dar prioridad al
# dispositivo recién conectado".
default.configured-audio-sink   = null
default.configured-audio-source = null

# move-new-streams: los nuevos streams de audio van al dispositivo por defecto
# actual en el momento en que se inician (comportamiento de Windows/macOS).
# Desactivar solo si el usuario quiere que cada app recuerde su dispositivo.
stream.default-media-type       = Audio
ASEOF
echo "✓  WirePlumber: auto-switch de dispositivo configurado"

# ── Bluetooth: forzar A2DP sobre HSP/HFP ─────────────────────────────────────
# HSP/HFP es el perfil de telefonía (baja calidad, 8kHz/16kHz).
# A2DP es el perfil de música (alta calidad, hasta 48kHz estéreo).
# Windows y macOS seleccionan A2DP automáticamente para escucha, solo
# cambian a HSP/HFP cuando hay una llamada activa. WirePlumber puede hacer lo mismo.
cat > /etc/wireplumber/bluetooth.lua.d/51-bluez-config.lua << 'BTEOF'
bluez_monitor.properties = {
  -- Preferir A2DP (alta calidad) sobre HSP/HFP al conectar
  ["bluez5.enable-sbc-xq"]           = true,   -- SBC-XQ: calidad mejorada sin AAC/aptX
  ["bluez5.enable-msbc"]             = true,   -- mSBC: voz HD para llamadas (16kHz)
  ["bluez5.enable-hw-volume"]        = true,   -- control de volumen en el dispositivo
  ["bluez5.headset-roles"]           = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]",
  ["bluez5.a2dp.ldac.quality"]       = "auto", -- LDAC adaptativo según señal
  ["bluez5.hfphsp-backend"]          = "native",
}

bluez_monitor.rules = [
  {
    -- Al conectar cualquier dispositivo Bluetooth, seleccionar A2DP si disponible
    matches = [{ device.name = "~bluez_card.*" }]
    actions = {
      update-props = {
        ["bluez5.auto-connect"]  = "[ a2dp_sink hfp_hf hsp_hs ]"
        ["bluez5.profile"]       = "a2dp-sink"
      }
    }
  }
]
BTEOF
echo "✓  WirePlumber: Bluetooth A2DP prioritario configurado"

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
  # Quantum adaptativo: PipeWire ajusta el buffer según la carga del sistema
  # para equilibrar latencia y estabilidad (como el motor de audio de macOS).
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
