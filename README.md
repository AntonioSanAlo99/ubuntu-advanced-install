# Ubuntu Advanced Install

Instalador avanzado de Ubuntu con optimizaciones, configuración automática y módulos personalizables.

## 🚀 Inicio Rápido

```bash
# 1. Descargar e instalar
sudo ./install.sh

# 2. Seleccionar opción 1 (Instalación interactiva guiada)
```

## 📚 Documentación

**Toda la documentación está en la [Wiki](wiki/INDEX.md)**

### Accesos Directos

- 📖 [Guía de Testing](wiki/Testing-Guide.md) - Cómo probar el instalador
- 🌍 [Configuración de Locales](wiki/Locales.md) - Sistema en español
- ⌨️ [Configuración de Teclado](wiki/Keyboard.md) - Teclado español
- 🚀 [Optimizaciones Clear Linux](wiki/Clear-Linux-Optimizations.md) - Kernel optimizado
- 💾 [Optimización de Memoria](wiki/GNOME-Memory.md) - Reducir RAM en GNOME
- 🎨 [Extensiones GNOME](wiki/GNOME-Extensions.md) - Extensiones instaladas
- 🪟 [Transparencias](wiki/GNOME-Transparency.md) - Tema transparente

## ✨ Características

### Sistema Base
- ✅ **Debootstrap** - Instalación limpia sin paquetes innecesarios
- ✅ **Español** - Sistema completamente en español (locale, teclado, TTY)
- ✅ **Optimizado** - Parámetros del kernel de Clear Linux
- ✅ **Modular** - Instalación por componentes según necesidades

### GNOME
- ✅ **Sin metapaquetes** - Solo los componentes necesarios
- ✅ **Extensiones** - App Indicators, Desktop Icons, Ubuntu Dock
- ✅ **Transparencias** - Tema Adwaita-Transparent (opcional)
- ✅ **Optimización de memoria** - Tracker, animaciones configurables
- ✅ **systemd-oomd** - Protección contra falta de RAM

### Multimedia
- ✅ **Códecs completos** - ffmpeg, gstreamer
- ✅ **Thumbnailers** - Miniaturas de video, audio, documentos, imágenes
- ✅ **Totem** - Miniaturas de audio (temporal hasta GNOME 2026)
- ✅ **VLC + Fooyin** - Reproductores multimedia

### Personalización
- ✅ **Gaming** - Drivers, gamemode, udev rules, zram (opcional)
- ✅ **Desarrollo** - VS Code, Node.js (opcional)
- ✅ **Fuentes** - Ubuntu Fonts + Nerd Fonts curadas
- ✅ **Laptop** - TLP, optimizaciones de batería (opcional)

## 🗂️ Estructura de Módulos

```
00 → Verificar dependencias
01 → Preparar disco
02 → Debootstrap (sistema base)
03 → Configurar sistema (locale, teclado, usuario)
04 → Bootloader (GRUB + kernel)
05 → Red (NetworkManager)

10 → GNOME (Shell + aplicaciones)
10b → Optimización de memoria (opcional)
10c → Transparencias (opcional)
12 → Multimedia
13 → Fuentes
14 → WiFi/Bluetooth
15 → Desarrollo
16 → Gaming

21 → Laptop (TLP)
23 → Minimizar systemd
24 → Security hardening

30 → Verificar sistema
31 → Generar reporte
```

## 🎯 Casos de Uso

### Desktop Estándar
```bash
./install.sh
# Opción 1: Instalación interactiva
# Tipo: Desktop
# GNOME: Sí
# Multimedia: Sí
# Optimización memoria: Sí (recomendado)
# Transparencias: Sí (opcional)
```

### Laptop
```bash
# Igual que desktop +
# Tipo: Laptop
# → Activa optimizaciones de TLP automáticamente
```

### Gaming
```bash
# Desktop +
# Gaming: Sí
# zram: Sí (recomendado para <16GB RAM)
```

### Desarrollo
```bash
# Desktop +
# Desarrollo: Sí
# → VS Code + Node.js
```

### Servidor/Mínimo
```bash
# GNOME: No
# Multimedia: No
# Solo base + red
```

## 📋 Requisitos

- **Arquitectura**: x86_64 (AMD64)
- **Firmware**: UEFI o BIOS
- **Disco**: Mínimo 20GB (recomendado 40GB+)
- **RAM**: Mínimo 2GB (recomendado 4GB+)
- **Red**: Conexión a internet durante instalación

## 🔧 Configuración

### Archivo config.env

```bash
# Hardware
FIRMWARE="UEFI"  # o "BIOS"
TARGET_DISK="/dev/sda"
IS_LAPTOP="false"  # true para laptop

# Sistema
HOSTNAME="ubuntu"
USERNAME="usuario"
UBUNTU_VERSION="noble"  # 24.04 LTS

# Componentes
INSTALL_GNOME="true"
INSTALL_MULTIMEDIA="true"
INSTALL_DEVELOPMENT="false"
INSTALL_GAMING="false"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
ENABLE_SECURITY="false"
USE_NO_INSTALL_RECOMMENDS="true"
```

## 🛠️ Troubleshooting

### Problema: Sistema en inglés
→ [Solución: Locales](wiki/Locales.md)

### Problema: GNOME consume mucha RAM
→ [Solución: Optimización de Memoria](wiki/GNOME-Memory.md)

### Problema: No hay miniaturas de archivos
→ [Solución: Thumbnailers](wiki/Thumbnailers.md)

### Problema: Extensiones no se activan
→ [Solución: Extensiones GNOME](wiki/GNOME-Extensions.md)

### Problema: Errores de locale en instalación
→ [Solución: Locales Chroot](wiki/Locales-Chroot.md)

## 📖 Más Información

Consulta la [Wiki completa](wiki/INDEX.md) para documentación detallada.

## 📄 Licencia

MIT License - Ver archivo LICENSE para más detalles.
