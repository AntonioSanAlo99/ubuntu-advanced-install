# Ubuntu Advanced Installer

> **Instalador modular de Ubuntu optimizado**  
> Sistema base minimalista + Gaming + Desarrollo + Optimizaciones para laptop

![Version](https://img.shields.io/badge/version-1.0.1-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 🎯 ¿Qué es esto?

Un instalador basado en **debootstrap** que crea un sistema Ubuntu limpio sin aplicaciones preinstaladas innecesarias. 

**En lugar de** instalar Ubuntu estándar con +1800 paquetes, este instalador construye el sistema desde cero con solo lo necesario.

### Diferencias Medibles con Ubuntu Estándar

| Aspecto | Ubuntu 24.04 Estándar | Este Instalador | Diferencia |
|---------|----------------------|-----------------|------------|
| **Paquetes base** | ~1800 paquetes | ~900 paquetes | -50% paquetes |
| **Espacio en disco** | ~8-9 GB | ~4-5 GB | -50% espacio |
| **Servicios systemd** | ~120-130 servicios | ~50-60 servicios | -50% servicios |
| **RAM en idle** | ~1.5-2 GB | ~700MB-1GB | ~50% menos RAM |

*Mediciones en instalación base con GNOME. Los números varían según la configuración.*

---

## ⚡ Ventajas Principales

### 1. Sistema Base Limpio

**Debootstrap puro** - Instalación mínima sin:
```
✗ Aplicaciones de oficina preinstaladas
✗ Juegos incluidos por defecto
✗ Software de telemetría
✗ Snaps preinstalados (opcional)
✗ Ubuntu Pro nagware
```

**Solo** lo esencial del sistema + lo que tú elijas instalar.

### 2. Gaming Configurado

Si eliges instalar el módulo de gaming, incluye:
```
✓ Steam (repositorio oficial .deb)
✓ Proton GE + Proton Cachyos
✓ GameMode + MangoHud
✓ Heroic (Epic/GOG), Lutris
✓ VRR en GNOME (si hardware compatible)
✓ HDR en GNOME 47+ (si hardware compatible)
✓ Optimizaciones sysctl (vm.max_map_count, etc)
```

**Nota sobre rendimiento gaming**: Las mejoras dependen del hardware y juego específico. GameMode y las optimizaciones sysctl pueden ayudar en algunos juegos, especialmente con muchos assets.

### 3. Desarrollo Listo

Si eliges el módulo de desarrollo:
```
✓ VS Code (repositorio oficial)
✓ NodeJS 24.x LTS
✓ Docker + Docker Compose
✓ Git + GitHub CLI
✓ Build essentials
```

### 4. Laptop Optimizado

Si eliges el módulo de laptop:
```
✓ TLP - Gestión de energía
✓ auto-cpufreq - Scaling de CPU
✓ Intel Undervolt (opcional, 3 niveles seguridad)
✓ Control de ventiladores (ThinkPad/Dell/HP)
✓ Thermald para Intel
```

**Nota**: Las mejoras de batería dependen mucho del hardware específico y uso.

---

## 🛠️ Características Técnicas

### Sistema Base

- **Debootstrap** - Instalación desde cero
- **APT con formato DEB822** - Repositorios modernos
- **Dual-boot inteligente** - Detecta Windows y preserva EFI
- **GRUB o systemd-boot** - Tú eliges

### GNOME Desktop

- **GNOME limpio** - Sin aplicaciones innecesarias
- **Workspaces configurables** - 1 fijo o dinámicos (pregunta durante instalación)
- **Tiempo de pantalla opcional** - Desactivable para privacidad
- **Extensiones base** - AppIndicator, Dash to Dock
- **Optimizaciones de memoria** - Configuración más eficiente

### Gaming (Módulo Opcional)

- **VRR (Variable Refresh Rate)** - Habilitado en GNOME si hardware soporta
- **HDR** - Habilitado en GNOME 47+ con hardware compatible
- **Animaciones opcionales** - Puedes desactivarlas para menor latencia
- **Proton configurado** - Gestores de versiones incluidos
- **GameMode** - Optimizaciones automáticas al jugar

### Laptop (Módulo Opcional)

- **TLP** - Gestión de energía bien configurada
- **auto-cpufreq** - Alternativa/complemento a TLP
- **Intel Undervolt** - 3 niveles de seguridad con validación
- **Ventiladores** - Soporte para múltiples marcas
- **Thermal management** - Intel thermald

---

## 📊 ¿Por Qué Menos Paquetes es Mejor?

### Arranque Más Rápido

Menos servicios = arranque más rápido. La diferencia exacta depende del hardware, pero es notable en SSDs.

### Menos Uso de RAM

Menos servicios en background = más RAM disponible para tus aplicaciones.

### Actualizaciones Más Rápidas

Menos paquetes = menos tiempo actualizando el sistema.

### Más Espacio en Disco

Especialmente importante en SSDs pequeños o laptops con poco espacio.

---

## 📋 Requisitos

### Hardware

| Componente | Mínimo | Recomendado |
|------------|--------|-------------|
| **CPU** | 2 cores x86_64 | 4+ cores |
| **RAM** | 2GB | 8GB+ |
| **Disco** | 20GB libres | 50GB+ |
| **GPU** | Cualquiera | Dedicada para gaming |

**El instalador NO valida requisitos mínimos.** Puedes instalar en hardware con menos recursos, pero el rendimiento variará.

### Sistema

- **Ubuntu Live USB** (20.04, 22.04, 24.04, 25.10, 26.04)
- **Conexión a Internet** (para descargar paquetes)
- **Permisos root** (sudo)

---

## 🚀 Uso

### Instalación Rápida

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/ubuntu-advanced-install.git
cd ubuntu-advanced-install

# 2. Ejecutar (menú interactivo)
sudo bash install.sh

# 3. Seguir las preguntas
```

### Modos de Instalación

```bash
# Menú interactivo (recomendado para primera vez)
sudo bash install.sh

# Instalación automática (usa config.env)
sudo bash install.sh --auto

# Interactivo guiado (pregunta en cada paso)
sudo bash install.sh --interactive

# Configurar antes de instalar
sudo bash install.sh --config

# Ver ayuda completa
sudo bash install.sh --help
```

### Configuración

Edita `config.env` antes de instalar:

```bash
# Versión Ubuntu
UBUNTU_VERSION="noble"  # 20.04, 22.04, 24.04, 25.10, 26.04

# Sistema
HOSTNAME="mi-ubuntu"
USERNAME="usuario"

# Módulos opcionales
INSTALL_GNOME="true"
INSTALL_GAMING="false"
INSTALL_DEVELOPMENT="false"
IS_LAPTOP="false"

# Optimizaciones
MINIMIZE_SYSTEMD="true"
ENABLE_SECURITY="true"
```

---

## 📁 Módulos Principales

El instalador es **modular**. Cada funcionalidad está en un módulo separado.

### Sistema Base (Obligatorio)
```
01-prepare-disk      - Particionado
02-debootstrap       - Sistema base mínimo
03-configure-base    - Configuración esencial
04-install-bootloader - GRUB/Systemd-boot
05-configure-network - Red
```

### GNOME (Opcional)
```
10-install-gnome-core - Desktop + VRR/HDR config
10-optimize          - Optimizaciones
10-theme             - Temas
10-user-config       - Configuración usuario
```

### Opcionales
```
15-install-development - VSCode, NodeJS, Docker
16-configure-gaming    - Steam, Proton, VRR/HDR
21-optimize-laptop     - TLP, auto-cpufreq
23-minimize-systemd    - Deshabilita servicios innecesarios
24-security-hardening  - Hardening del sistema
```

Ver todos los módulos: `ls modules/`

---

## 🔧 Estructura del Proyecto

```
ubuntu-advanced-install/
├── install.sh          # Script principal (orquestador)
├── config.env          # Configuración
├── modules/            # 24 módulos funcionales
│   ├── 01-prepare-disk.sh
│   ├── 10-install-gnome-core.sh
│   ├── 16-configure-gaming.sh
│   └── ...
├── docs/               # Documentación técnica
│   ├── ARCHITECTURE.md
│   ├── MODULE-DEVELOPMENT.md
│   ├── ROADMAP.md
│   └── CHANGELOG.md
└── tools/              # Scripts de utilidad
```

Para información técnica detallada, ver [`docs/`](docs/).

---

## 🎯 Casos de Uso

### Gaming PC

Sistema limpio enfocado en juegos:
```bash
INSTALL_GNOME="true"
INSTALL_GAMING="true"
MINIMIZE_SYSTEMD="true"
```

### Laptop Desarrollo

VSCode, NodeJS, Docker con batería optimizada:
```bash
INSTALL_GNOME="true"
INSTALL_DEVELOPMENT="true"
IS_LAPTOP="true"
```

### Servidor/Headless

Sin GNOME, solo sistema base:
```bash
INSTALL_GNOME="false"
INSTALL_GAMING="false"
MINIMIZE_SYSTEMD="true"
```

---

## ⚠️ Limitaciones y Advertencias

### Lo Que Este Instalador NO Hace

- ❌ **No instala automáticamente drivers propietarios NVIDIA** - Los detecta pero pregunta
- ❌ **No garantiza mejor rendimiento en todos los juegos** - Depende del juego y hardware
- ❌ **No hace milagros con hardware antiguo** - Un sistema limpio ayuda, pero no sustituye hardware
- ❌ **No instala software crackado o pirata** - Todo desde repositorios oficiales
- ❌ **No es una distribución distinta** - Es Ubuntu estándar, solo instalado diferente

### Sobre las "Optimizaciones"

- **Systemd minimizado**: Solo deshabilita servicios claramente innecesarios. No toca lo crítico.
- **Gaming optimizations**: Los sysctl ayudan en algunos juegos, no en todos. No esperes milagros.
- **VRR/HDR**: Solo funciona si tu monitor, GPU y GNOME lo soportan. No se puede forzar.
- **Batería laptop**: TLP y auto-cpufreq ayudan, pero la batería depende principalmente del hardware y uso.

---

## 🤝 Créditos

### Autor

**[Tu Nombre]** - Creador y mantenedor del proyecto

### Asistencia en Desarrollo

Este proyecto fue desarrollado con la asistencia de **Claude 3.5 Sonnet (Anthropic)** para:
- Diseño de arquitectura modular
- Scripts de automatización
- Documentación técnica
- Testing y validación de código

### Tecnologías

- **Bash** - Scripting
- **Debootstrap** - Instalación base
- **APT** - Gestión de paquetes
- **Systemd** - Gestión de servicios
- **GNOME** - Desktop environment

### Licencia

MIT License - Ver [LICENSE](LICENSE)

---

## 📖 Documentación

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Diseño técnico del sistema
- **[docs/MODULE-DEVELOPMENT.md](docs/MODULE-DEVELOPMENT.md)** - Cómo crear módulos
- **[docs/ROADMAP.md](docs/ROADMAP.md)** - Plan de desarrollo futuro
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** - Historial de cambios
- **[docs/PROJECT-INFO.md](docs/PROJECT-INFO.md)** - Información general del proyecto

---

## 🐛 Problemas y Soporte

### Reportar Problemas

Si encuentras un bug:

1. Revisa los [Issues existentes](https://github.com/tu-usuario/ubuntu-advanced-install/issues)
2. Si es nuevo, abre un issue con:
   - Versión de Ubuntu que instalaste
   - Hardware (CPU, RAM, GPU)
   - Log completo (`logs/install-*.log`)
   - Pasos para reproducir

### Obtener Ayuda

- **Documentación**: Lee [`docs/`](docs/) primero
- **Issues**: [GitHub Issues](https://github.com/tu-usuario/ubuntu-advanced-install/issues)
- **Discussions**: [GitHub Discussions](https://github.com/tu-usuario/ubuntu-advanced-install/discussions)

---

## 🔄 Desarrollo

### Roadmap

Ver [docs/ROADMAP.md](docs/ROADMAP.md) para el plan completo.

**Próximas características (v1.1.0)**:
- TUI (interfaz de texto mejorada)
- ISO personalizada con instalador incluido
- Drivers gráficos opcionales en gaming
- Emuladores y EmulationStation

**En desarrollo (v1.2.0)**:
- Gestor de AppImages (AM)
- Topgrade para actualizaciones
- Mejoras de apariencia GNOME

**Planificado (v1.3.0)**:
- Aplicaciones extras (OnlyOffice, Obsidian, Teams, etc.)
- QEMU/KVM + Virtual Machine Manager

### Contribuir

Las contribuciones son bienvenidas. Ver [docs/MODULE-DEVELOPMENT.md](docs/MODULE-DEVELOPMENT.md) para guías.

---

## ⭐ Apoya el Proyecto

Si te resulta útil:
- ⭐ Estrella en GitHub
- 🐛 Reporta bugs
- 📝 Mejora la documentación
- 🤝 Contribuye código

---

## 📞 Contacto

- **GitHub**: [tu-usuario/ubuntu-advanced-install](https://github.com/tu-usuario/ubuntu-advanced-install)
- **Issues**: [Reportar problema](https://github.com/tu-usuario/ubuntu-advanced-install/issues)

---

<div align="center">

**Ubuntu Advanced Installer v1.0.1**

Instalación limpia de Ubuntu desde debootstrap

Desarrollado por **[Tu Nombre]** con asistencia de Claude 3.5 Sonnet

[Documentación](docs/) · [Changelog](docs/CHANGELOG.md) · [Roadmap](docs/ROADMAP.md)

</div>
