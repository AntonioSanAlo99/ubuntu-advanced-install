# Ubuntu Advanced Installer

> Sistema modular de instalación de Ubuntu desde cero con soporte avanzado para dual-boot, gaming, laptops y desarrollo.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-All%20Supported%20Versions-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/bash-5.0%2B-brightgreen)

---

## 🌟 Características Principales

### 🎯 **Instalación Base**
- ✅ **Debootstrap puro** - Sistema base mínimo sin bloat
- ✅ **Dual-boot inteligente** - Detección automática de Windows y preservación de EFI
- ✅ **APT 3.0 DEB822** - Formato moderno de repositorios
- ✅ **Múltiples bootloaders** - GRUB o systemd-boot

### 🖥️ **Desktop Environment**
- ✅ **GNOME Desktop** - Entorno de escritorio moderno sin aplicaciones innecesarias
- ✅ **Optimizaciones de memoria** - Configuración para máximo rendimiento
- ✅ **Extensiones esenciales** - AppIndicator, Dash to Dock, etc.
- ✅ **Temas profesionales** - Yaru, Elementary, iconos optimizados

### 🎮 **Gaming**
- ✅ **Steam + Proton GE** - Compatibilidad máxima con juegos Windows
- ✅ **GameMode** - Optimizaciones automáticas durante el juego
- ✅ **MangoHud** - Overlay de estadísticas en tiempo real
- ✅ **Launchers** - Heroic (Epic/GOG), Faugus, Lutris
- ✅ **Optimizaciones sysctl** - vm.max_map_count, fs.file-max
- ✅ **VRR y HDR en GNOME** - Variable Refresh Rate y High Dynamic Range

### 💻 **Desarrollo**
- ✅ **VSCode** - Editor con repositorio DEB822
- ✅ **NodeJS 24 LTS (Krypton)** - Con repositorio oficial
- ✅ **Build tools** - gcc, make, cmake, git
- ✅ **Wine Staging** - Última versión para compatibilidad Windows

### 🔋 **Laptop Avanzado**
- ✅ **Intel Undervolt** - 3 niveles de seguridad con validación activa
- ✅ **Control de ventiladores multi-vendor**:
  - ThinkPad (thinkfan)
  - Dell (i8kutils)
  - HP/ASUS/Generic (lm-sensors)
- ✅ **TLP** - Gestión de energía automática
- ✅ **Thermald** - Control térmico Intel
- ✅ **CPU Power Manager** - Control de TDP, frecuencias y undervolt

### 🎨 **Multimedia**
- ✅ **Codecs completos** - FFmpeg, GStreamer, libavcodec
- ✅ **VLC** - Reproductor universal
- ✅ **Fooyin** - Reproductor de música moderno
- ✅ **Thumbnailers** - Vista previa de AppImage, vídeos, EPUB, HEIF

### 🔤 **Fuentes Profesionales**
- ✅ **JetBrains Mono Nerd Font** - Tipografía para programación
- ✅ **Fuentes Microsoft** - Calibri, Arial, Times New Roman (con ClearType)
- ✅ **Ubuntu fonts** - Familia completa

---

## 📋 Requisitos

### Hardware Mínimo
- **CPU**: 2 cores (recomendado: 4+)
- **RAM**: 4GB (recomendado: 8GB+)
- **Disco**: 50GB libres (recomendado: 100GB+)
- **GPU**: Cualquiera (soporte específico para NVIDIA/AMD/Intel)

### Sistema Actual
- **Ubuntu Live USB** (soportadas: 20.04 LTS, 22.04 LTS, 24.04 LTS, 25.10, 26.04 LTS)
- **Conexión a Internet** (para descargar paquetes)
- **Acceso root** (sudo)

### Opcional para Dual-Boot
- **Windows ya instalado** con partición EFI
- **Espacio sin particionar** o partición a eliminar

---

## 🚀 Inicio Rápido

### 1. Descargar el Instalador

```bash
# Opción 1: Clonar desde repositorio (recomendado)
git clone https://github.com/usuario/ubuntu-advanced-install.git
cd ubuntu-advanced-install

# Opción 2: Descargar release
wget https://github.com/usuario/ubuntu-advanced-install/archive/refs/tags/v1.0.0.tar.gz
tar xzf v1.0.0.tar.gz
cd ubuntu-advanced-install-1.0.0
```

### 2. Ejecutar Instalación Interactiva

```bash
sudo ./install.sh --interactive
```

El instalador te guiará paso a paso con detección automática de hardware.

### 3. Opciones de Ejecución

```bash
# Instalación interactiva (recomendado)
sudo ./install.sh --interactive

# Configuración previa sin instalar
sudo ./install.sh --config

# Instalación automática (requiere config.env previo)
sudo ./install.sh --auto

# Modo dry-run (simula sin ejecutar)
sudo ./install.sh --dry-run --interactive

# Modo debug (muestra todos los comandos)
sudo ./install.sh --debug --config

# Ejecutar un módulo específico
sudo ./install.sh --module 10-install-gnome-core

# Listar módulos disponibles
sudo ./install.sh --list

# Ver ayuda
sudo ./install.sh --help
```

---

## 📦 Módulos Disponibles

El instalador está dividido en módulos independientes y reutilizables:

### 🔧 Base del Sistema (Obligatorios)

| Módulo | Descripción | Tiempo |
|--------|-------------|--------|
| `00-check-dependencies` | Verifica dependencias del sistema | 10s |
| `01-prepare-disk` | Particionamiento dual-boot inteligente | 2-5min |
| `02-debootstrap` | Sistema base Ubuntu mínimo | 5-10min |
| `03-configure-base` | Configuración (locale, timezone, hostname) | 2min |
| `03-install-firmware` | Drivers y firmware de hardware | 3-5min |
| `04-install-bootloader` | GRUB o systemd-boot | 2min |
| `05-configure-network` | NetworkManager + DNS | 1min |

### 🖥️ Desktop (Opcionales)

| Módulo | Descripción | Tiempo |
|--------|-------------|--------|
| `10-install-gnome-core` | GNOME Desktop + GDM3 | 5-10min |
| `10-optimize` | Optimizaciones de memoria y rendimiento | 1min |
| `10-theme` | Temas Yaru/Elementary + iconos | 2min |
| `10-user-config` | Configuración de usuario (dconf) | 1min |

### 🎯 Aplicaciones (Opcionales)

| Módulo | Descripción | Tiempo |
|--------|-------------|--------|
| `12-install-multimedia` | VLC, Fooyin, codecs, thumbnailers | 3-5min |
| `13-install-fonts` | JetBrains Mono, fuentes Windows | 2-3min |
| `14-configure-wireless` | WiFi + Bluetooth | 1min |
| `15-install-development` | VSCode, NodeJS, build-tools | 3-5min |
| `16-configure-gaming` | Steam, Proton GE, GameMode, launchers | 10-15min |
| `17-install-wine` | Wine Staging + dependencias | 3-5min |

### ⚡ Optimizaciones (Opcionales)

| Módulo | Descripción | Tiempo |
|--------|-------------|--------|
| `20-optimize-performance` | Optimizaciones del sistema | 1min |
| `21-optimize-laptop` | TLP básico para laptops | 1min |
| `21-laptop-advanced` | Undervolt + ventiladores multi-vendor | 3-5min |
| `23-minimize-systemd` | Deshabilita servicios innecesarios | 1min |
| `24-security-hardening` | Hardening de seguridad | 1min |

### 🔍 Utilidades (Opcionales)

| Módulo | Descripción | Tiempo |
|--------|-------------|--------|
| `30-verify-system` | Verificación post-instalación | 1min |
| `31-generate-report` | Genera informe del sistema | 30s |
| `32-backup-config` | Backup de configuraciones | 30s |

**Tiempo total estimado**: 40-70 minutos (dependiendo de módulos seleccionados)

---

## 🎛️ Configuración Avanzada

### Archivo config.env

El instalador genera automáticamente `config.env` con tus selecciones. También puedes editarlo manualmente:

```bash
# Editar configuración
nano config.env

# Ejemplo de configuración
UBUNTU_VERSION="noble"            # noble (24.04 LTS), jammy (22.04 LTS), focal (20.04 LTS), questing (25.10), resolute (26.04 LTS dev)
HOSTNAME="mi-ubuntu"
USERNAME="usuario"
TARGET="/mnt"
INSTALL_GNOME="true"
INSTALL_GAMING="true"
INSTALL_DEVELOPMENT="true"
IS_LAPTOP="true"
HAS_NVIDIA="false"
USE_SYSTEMD_BOOT="false"          # false = GRUB
MINIMIZE_SYSTEMD="true"
ENABLE_SECURITY="true"
```

### Dual-Boot con Windows

El módulo `01-prepare-disk` detecta automáticamente:
- ✅ Particiones Windows existentes
- ✅ Partición EFI de Windows
- ✅ Espacio libre disponible
- ✅ Calcula tamaño óptimo para Ubuntu

**No es necesario particionar manualmente.**

```
Ejemplo de detección automática:
┌──────────────────────────────────────────────────┐
│ Windows detectado en /dev/nvme0n1p3             │
│ Partición EFI en /dev/nvme0n1p1                 │
│ Espacio libre: 250GB                            │
│                                                  │
│ ¿Tamaño para Ubuntu? [100GB]:                   │
└──────────────────────────────────────────────────┘
```

---

## 🔋 Gestión Avanzada de Laptop

### Intel Undervolt con Validación

El módulo `21-laptop-advanced` ofrece **3 niveles de seguridad**:

#### Nivel 1: CONSERVADOR (Recomendado para principiantes)
```
CPU:   -50mV  ← Estabilidad >99%
GPU:   -40mV  ← Reducción térmica: 3-7°C
Cache: -50mV  ← Sin riesgo de crashes
```

#### Nivel 2: MODERADO (Usuarios intermedios)
```
CPU:   -70mV  ← Estabilidad ~95%
GPU:   -55mV  ← Reducción térmica: 7-12°C
Cache: -70mV  ← Requiere testing
```

#### Nivel 3: AVANZADO (Personalizado con validación)
```
CPU:   ? mV  ← Usuario define (validado -150mV máximo)
GPU:   ? mV  ← Validación activa rechaza valores peligrosos
Cache: ? mV  ← Rangos educativos explicados
```

**Características de seguridad**:
- ✅ Validación en tiempo real
- ❌ Rechaza valores > -150mV (peligrosos)
- ❌ Rechaza valores positivos
- ✅ Guía post-instalación incluida

### Control de Ventiladores Multi-Vendor

Soporte automático para:

| Vendor | Método | Configuración |
|--------|--------|---------------|
| **ThinkPad** | thinkfan | `/etc/thinkfan.conf` |
| **Dell** | i8kutils | `/etc/i8kmon.conf` |
| **HP** | lm-sensors | Manual: `pwmconfig` |
| **ASUS** | lm-sensors | Manual: `pwmconfig` |
| **Genérico** | lm-sensors | Manual: `pwmconfig` |

**Detección automática** de vendor y aplicación de configuración específica.

---

## 🎮 Configuración de Gaming

### Incluido en el módulo 16-configure-gaming:

#### Steam + Proton
- ✅ Steam (flatpak o .deb)
- ✅ Proton GE (última versión)
- ✅ ProtonUp-Qt (gestor de versiones)

#### Optimizaciones
```bash
# Kernel parameters aplicados automáticamente
vm.max_map_count=2147483642
fs.file-max=524288

# GameMode habilitado
# MangoHud configurado
```

#### GNOME: VRR y HDR
```bash
# Variable Refresh Rate (FreeSync/G-Sync)
✓ VRR habilitado automáticamente
✓ Compatible con monitores 120Hz+

# HDR (High Dynamic Range)
✓ Características experimentales habilitadas
✓ Funcional en GNOME 47+ con hardware compatible
✓ Detección automática de monitores HDR

# Optimizaciones adicionales
✓ Compositor optimizado para gaming
⚙️ Animaciones deshabilitadas (OPCIONAL - se pregunta durante instalación)
```

**Requisitos HDR**:
- GNOME 47 o superior
- Monitor compatible HDR
- GPU: NVIDIA RTX series / AMD RX 5000+ / Intel Arc

**Verificación**: Settings → Displays → HDR (después del reinicio)

#### Launchers Adicionales
- ✅ **Heroic Games Launcher** - Epic Games Store + GOG
- ✅ **Faugus Launcher** - Gestor de juegos universal
- ✅ **Lutris** - Plataforma de gaming

#### GPU Drivers
- ✅ NVIDIA: Drivers propietarios (si detectado)
- ✅ AMD: Mesa + RADV (open source)
- ✅ Intel: Mesa (incluido por defecto)

---

## 💻 Desarrollo

### VSCode + NodeJS

```bash
# Instalado automáticamente en módulo 15-install-development
- VSCode (repositorio oficial DEB822)
- NodeJS 24 LTS Krypton (repositorio oficial)
- npm, npx
- build-essential (gcc, make, cmake)
- git
```

### Wine Staging

```bash
# Módulo 17-install-wine
- Wine Staging (última versión)
- Winetricks
- Dependencias 32-bit
- Repositorio DEB822 oficial
```

---

## 🛠️ Troubleshooting

### Problema: Instalación falla en un módulo

```bash
# El instalador ofrece 5 opciones:
1) Continuar con siguiente módulo
2) Reintentar este módulo
3) Saltar al siguiente
4) Abrir shell de depuración  ← RECOMENDADO
5) Abortar instalación

# Opción 4 abre bash interactivo con variables disponibles:
TARGET=/mnt
CONFIG_FILE=/ruta/config.env

# Depurar manualmente y luego 'exit' para reintentar
```

### Problema: Dual-boot no detecta Windows

```bash
# Verificar particiones manualmente
sudo fdisk -l
sudo blkid

# Ejecutar solo particionamiento
sudo ./install.sh --module 01-prepare-disk
```

### Problema: GRUB no arranca

```bash
# Desde Ubuntu Live:
sudo mount /dev/sdXY /mnt
sudo mount /dev/sdX1 /mnt/boot/efi  # Partición EFI
sudo arch-chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi
update-grub
```

### Problema: Undervolt causa crashes

```bash
# Reducir valores en 10-20mV
sudo nano /etc/intel-undervolt.conf

# Cambiar:
undervolt 0 'CPU' -80  →  undervolt 0 'CPU' -60

# Aplicar
sudo intel-undervolt apply
```

### Logs

```bash
# Logs de instalación
ls -lah logs/

# Ver último log
tail -f logs/install-*.log

# Ver errores específicos
grep ERROR logs/install-*.log
```

---

## 📚 Documentación Adicional

### Wiki del Proyecto
```
wiki/
├── 01-installation-guide.md     - Guía detallada de instalación
├── 02-dual-boot-windows.md      - Dual-boot paso a paso
├── 03-gaming-setup.md           - Configuración de gaming completa
├── 04-laptop-optimization.md    - Optimizaciones de laptop
├── 05-development-setup.md      - Entorno de desarrollo
└── 99-faq.md                    - Preguntas frecuentes
```

### Documentación Técnica
```
docs/
├── ARCHITECTURE.md              - Arquitectura del sistema
├── MODULE-DEVELOPMENT.md        - Crear módulos nuevos
└── CONTRIBUTING.md              - Guía de contribución
```

---

## 🏗️ Arquitectura del Proyecto

```
ubuntu-advanced-install/
├── install.sh                   # Orquestador principal
├── apply-improvements.sh        # Script de mejoras automáticas
├── config.env                   # Configuración (generado)
│
├── modules/                     # Módulos de instalación (25)
│   ├── 00-check-dependencies.sh
│   ├── 01-prepare-disk.sh
│   ├── 02-debootstrap.sh
│   ├── 03-configure-base.sh
│   ├── ...
│   └── 32-backup-config.sh
│
├── files/                       # Archivos auxiliares
│   ├── cpu-power-manager        # Utilidad de control de CPU
│   └── [configs]
│
├── docs/                        # Documentación técnica
│   ├── ARCHITECTURE.md
│   └── MODULE-DEVELOPMENT.md
│
├── wiki/                        # Documentación de usuario
│   ├── 01-installation-guide.md
│   └── ...
│
└── tools/                       # Herramientas auxiliares
    └── [scripts de utilidad]
```

### Principios de Diseño

1. **Modularidad**: Cada módulo es independiente y reutilizable
2. **Autonomía**: Sin dependencias entre módulos
3. **Simplicidad**: Código directo, sin abstracciones innecesarias
4. **Minimalismo**: Solo lo esencial
5. **Unix Philosophy**: "Do one thing and do it well"

---

## 🔒 Seguridad

### Hardening Incluido (módulo 24-security-hardening)

```bash
# Configuraciones aplicadas:
- Límites de recursos (ulimit)
- Protección kernel (sysctl)
- Auditoría básica
- Fail2ban (opcional)
```

### Consideraciones

- ⚠️ El instalador requiere **acceso root** (sudo)
- ✅ Todo el código es **open source** y auditable
- ✅ No se envían datos externos
- ✅ Sin telemetría
- ✅ Sin conexiones a servicios de terceros (excepto repos oficiales)

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas!

### Formas de Contribuir

1. 🐛 **Reportar bugs** - Abre un issue con detalles
2. 💡 **Sugerir features** - Propón mejoras
3. 📝 **Mejorar documentación** - Wiki, README, comentarios
4. 🔧 **Crear módulos** - Añade nuevas funcionalidades
5. 🧪 **Testing** - Prueba en diferentes hardware

### Desarrollo de Módulos

```bash
# Estructura básica de un módulo
#!/bin/bash
# Módulo XX: Descripción

set -eo pipefail

source "$(dirname "$0")/../config.env"

echo "Ejecutando módulo..."

# Tu código aquí

exit 0
```

Ver `docs/MODULE-DEVELOPMENT.md` para guía completa.

---

## 📜 Licencia

Este proyecto está bajo la licencia **MIT**.

```
MIT License

Copyright (c) 2026 Ubuntu Advanced Installer Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Agradecimientos

- **Ubuntu Team** - Por el sistema operativo base
- **Arch Linux** - Inspiración de arch-chroot y filosofía minimalista
- **Comunidad Linux** - Por compartir conocimiento y herramientas

### Proyectos Usados

- [debootstrap](https://wiki.debian.org/Debootstrap)
- [GNOME](https://www.gnome.org/)
- [Steam](https://store.steampowered.com/)
- [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom)
- [GameMode](https://github.com/FeralInteractive/gamemode)
- [TLP](https://linrunner.de/tlp/)
- [intel-undervolt](https://github.com/kitsunyan/intel-undervolt)
- [thinkfan](https://github.com/vmatare/thinkfan)
- Y muchos más...

---

## 📞 Soporte y Contacto

### Comunidad

- 💬 **Discord**: [Enlace al servidor]
- 💡 **GitHub Discussions**: [github.com/usuario/ubuntu-advanced-install/discussions]
- 🐛 **Issues**: [github.com/usuario/ubuntu-advanced-install/issues]

### Recursos

- 📖 **Wiki Completa**: [wiki/]
- 🎥 **Video Tutorial**: [Enlace a YouTube]
- 📝 **Blog**: [Enlace a blog con guías]

---

---

## ⭐ Star History

Si este proyecto te resulta útil, considera darle una ⭐ en GitHub.

Para ver las características planificadas en futuras versiones, consulta el [**Roadmap del proyecto**](docs/ROADMAP.md).

---

## 📊 Estado del Proyecto

![Status](https://img.shields.io/badge/status-production--ready-brightgreen)
![Maintained](https://img.shields.io/badge/maintained-yes-green)
![Tests](https://img.shields.io/badge/tests-passing-brightgreen)

**Última actualización**: Febrero 2026  
**Versión estable**: 1.0.0  
**Compatibilidad**: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS, 25.10, 26.04 LTS (dev)

---

<div align="center">

**Hecho con ❤️ por la comunidad Linux**

[Documentación](wiki/) · [Reportar Bug](issues) · [Solicitar Feature](issues) · [Contribuir](CONTRIBUTING.md)

</div>
