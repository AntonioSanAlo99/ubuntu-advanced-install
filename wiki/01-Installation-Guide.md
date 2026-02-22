# Guía de Instalación

## 📋 Tabla de Contenidos

1. [Requisitos](#requisitos)
2. [Instalación Rápida](#instalación-rápida)
3. [Módulos Disponibles](#módulos-disponibles)
4. [Post-Instalación](#post-instalación)

---

## Requisitos

### Hardware Mínimo

- **CPU**: x86_64 (AMD64/Intel 64-bit)
- **RAM**: 4GB mínimo, 8GB recomendado
- **Disco**: 25GB mínimo, 50GB recomendado
- **Boot**: UEFI (recomendado) o BIOS legacy

### Software Requerido

Verificación automática de:
- `debootstrap`
- `arch-install-scripts`
- `parted` o `fdisk`
- `wget` o `curl`

---

## Instalación Rápida

```bash
# 1. Descargar
wget https://github.com/.../ubuntu-advanced-install.tar.gz
tar xzf ubuntu-advanced-install.tar.gz
cd ubuntu-advanced-install

# 2. Configurar (opcional)
cp config.env.example config.env
nano config.env

# 3. Ejecutar
sudo bash install.sh

# 4. Reiniciar
reboot
```

---

## Módulos Disponibles

### Base (Esenciales)

#### 00-check-dependencies
Verifica dependencias del instalador.

#### 01-prepare-disk
Particiona disco (UEFI: EFI + Root, BIOS: Root).

#### 02-debootstrap
Instala Ubuntu 25.10 base (main, restricted, universe, multiverse).

#### 03-configure-base
- Locale: **es_ES.UTF-8** (dpkg-reconfigure)
- Timezone: Europe/Madrid
- Teclado: Español
- Usuario + sudo

#### 04-install-bootloader
GRUB (UEFI o BIOS).

#### 05-configure-network
NetworkManager.

---

### Desktop

#### 10-install-gnome-core
GNOME Shell + GDM3 + Nautilus + Terminal + Utilidades + Google Chrome.

#### 10-user-config
Configuración usuario GNOME (dock, extensiones).

---

### Multimedia

#### 12-install-multimedia
- FFmpeg + GStreamer (detección automática versiones)
- VLC, Fooyin
- Thumbnailers (ffmpeg, epub, pdf, webp, heif)
- Auto-detección: `libtag1v5[-vanilla]`, `libebur128-1`

#### 13-install-fonts
- Liberation, DejaVu, Noto, Font Awesome, Hack, Ubuntu
- Microsoft Core Fonts
- Auto-detección: `fonts-noto[-core]`, `fonts-dejavu[-core]`

---

### Gaming

#### 16-configure-gaming

**Instalado**:
- gamemode, mangohud, goverlay
- Steam, Lutris, Heroic, Faugus
- wine, umu-launcher, Proton-Cachyos

**Optimizaciones**:
- vm.max_map_count = 2147483642
- fs.file-max = 524288
- Udev rules (PS4/5, Xbox, Switch Pro, etc.)

**NO configurado** (usuario configura):
- Variables de entorno
- MangoHud automático
- GameMode LD_PRELOAD

---

### Desarrollo

#### 15-install-development
- build-essential, git
- Python 3, Node.js, Rust
- Visual Studio Code

---

## Post-Instalación

### Gaming

#### MangoHud
```bash
goverlay  # GUI configuración
```

O crear `~/.config/MangoHud/MangoHud.conf`:
```
fps
cpu_temp
gpu_temp
```

#### GameMode
Funciona automáticamente:
- Steam: detecta solo
- Terminal: `gamemoderun ./juego`

#### Variables AMD (solo AMD)
```bash
# ~/.bashrc
export RADV_PERFTEST=aco
export AMD_VULKAN_ICD=RADV
```

---

### Locales

Sistema configurado con **es_ES.UTF-8**.

Cambiar:
```bash
sudo dpkg-reconfigure locales
```

Verificar:
```bash
locale  # Sin warnings
```

---

## Troubleshooting

Ver [Troubleshooting](03-Troubleshooting.md).

### Problemas Comunes

**Locale warnings**:
```bash
sudo dpkg-reconfigure locales
```

**GameMode ld.so errors** (versiones antiguas):
```bash
grep -r "LD_PRELOAD.*gamemode" /etc/profile.d/ ~/.bashrc
# Eliminar líneas LD_PRELOAD
```

---

## Logs

```bash
/var/log/ubuntu-install/*.log
```

---

Ver [Configuration](02-Configuration.md) para más opciones.
