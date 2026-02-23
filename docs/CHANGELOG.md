# Changelog

Todos los cambios notables en el proyecto Ubuntu Advanced Installer se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [1.0.1] - 2024-02-22

### 🚫 Eliminado
- **Validaciones de hardware que bloqueaban instalación**
  - Eliminada validación de RAM mínima (4GB)
  - Eliminada validación de espacio en disco (50GB)
  - Eliminada validación de espacio libre en partición (20GB)
  - Eliminados warnings de CPU cores insuficientes
  - Eliminado sistema de confirmación por errores de hardware
  - [Ver detalles](docs/old/INDEX.md)

### 🔧 Modificado
- `install.sh` - Detección de hardware solo informativa (no bloquea)
- `modules/01-prepare-disk.sh` - Espacio libre solo informativo (no valida)

### 📝 Documentación
- README actualizado con requisitos como recomendaciones (no validados)
- Creado `docs/old/` para archivos históricos
- Creado `docs/old/INDEX.md` con índice de cambios importantes

### ℹ️ Notas
- El instalador ahora permite instalación en cualquier hardware
- Usuario responsable de verificar requisitos mínimos
- Recomendaciones permanecen en README como guía

---

## [1.0.0] - 2024-02-21

### ✨ Añadido
- **VRR (Variable Refresh Rate) en Gaming**
  - Habilitado automáticamente en GNOME
  - Compatible con FreeSync/G-Sync
  - Funciona con monitores 120Hz+
  
- **HDR (High Dynamic Range) en Gaming**
  - Características experimentales habilitadas
  - Detección automática de GNOME 47+
  - Soporte para monitores HDR10/HDR400+
  - Compatible con NVIDIA RTX, AMD RX 5000+, Intel Arc
  
- **Animaciones opcionales en Gaming**
  - Pregunta al usuario si desactivar animaciones
  - Default: NO (mantiene animaciones)
  - Genera archivo `~/.config/gaming-display-config.txt`
  
- **Workspaces configurables en GNOME**
  - Pregunta al usuario: 1 fijo o dinámicos
  - Default: SÍ (1 workspace fijo)
  - Simplifica interfaz para usuarios nuevos
  
- **Tiempo de pantalla configurable en GNOME**
  - Pregunta al usuario si desactivar tracking
  - Default: SÍ (desactivado)
  - Elimina GNOME Usage
  - Desactiva remember-app-usage y remember-recent-files
  - Genera archivo `~/.config/gnome-custom-config.txt`

### 📁 Documentación
- Creado `docs/ROADMAP.md` - Plan de desarrollo futuro
  - v1.1.0 (Q2 2026): KDE, TUI, Profiles, Auto-update
  - v1.2.0 (Q3 2026): Arch, Backup, Cloud, Hooks
  - v2.0.0 (Q4 2026): Multi-distro, Containers, Web UI
  
### 🔧 Modificado
- `modules/16-configure-gaming.sh` - Añadido VRR/HDR y animaciones opcionales
- `modules/10-install-gnome-core.sh` - Añadido workspaces y tiempo pantalla configurables
- `README.md` - Actualizado con nuevas características

### 🐛 Corregido
- **Versiones de Ubuntu en documentación**
  - Eliminadas versiones inexistentes (24.10, 25.04)
  - Documentadas solo versiones del código: 20.04, 22.04, 24.04, 25.10, 26.04
  
- **Versión de GNOME en documentación**
  - Eliminada versión específica "GNOME 47"
  - Ahora: "GNOME Desktop" (versión depende de Ubuntu instalado)

### 📦 Archivos Antiguos
- `docs/old/README.md.old` - README antes de corrección de versiones
- `docs/old/16-configure-gaming.sh.old` - Gaming module antes de VRR/HDR

---

## [0.9.0] - 2024-02-20

### ✨ Primera Versión Funcional

#### Core System
- ✅ Instalador modular completo (25 módulos)
- ✅ Soporte para 5 versiones de Ubuntu (20.04, 22.04, 24.04, 25.10, 26.04)
- ✅ Detección automática de hardware
- ✅ Configuración interactiva

#### Desktop Environment
- ✅ GNOME Desktop completo
- ✅ GDM3 display manager
- ✅ Extensiones base (AppIndicator, Dash to Dock)
- ✅ Temas profesionales (Yaru, Elementary)
- ✅ Optimizaciones de memoria

#### Gaming
- ✅ Steam + Proton GE
- ✅ GameMode + MangoHud
- ✅ Launchers (Heroic, Faugus, Lutris)
- ✅ Optimizaciones sysctl (vm.max_map_count, fs.file-max)
- ✅ Drivers GPU (NVIDIA, AMD, Intel)

#### Development
- ✅ VS Code + extensiones
- ✅ Git + GitHub CLI
- ✅ NodeJS 24.x LTS (Krypton)
- ✅ Docker + Docker Compose
- ✅ Build tools completos

#### Laptop Support
- ✅ TLP (gestión energía)
- ✅ auto-cpufreq
- ✅ Trackpad gestures (libinput-gestures)
- ✅ Batería optimizada

#### System
- ✅ PipeWire (audio avanzado)
- ✅ Bluetooth
- ✅ Servicios systemd minimizados (opcional)
- ✅ Hardening de seguridad (opcional)

#### Documentation
- ✅ README completo
- ✅ ARCHITECTURE.md
- ✅ MODULE-DEVELOPMENT.md

---

## Tipos de Cambios

- `✨ Añadido` - Nuevas características
- `🔧 Modificado` - Cambios en funcionalidad existente
- `🐛 Corregido` - Corrección de bugs
- `🚫 Eliminado` - Características eliminadas
- `🔒 Seguridad` - Correcciones de seguridad
- `📝 Documentación` - Cambios solo en documentación
- `⚡ Rendimiento` - Mejoras de rendimiento
- `♻️ Refactorización` - Cambios de código sin afectar funcionalidad
- `🧪 Testing` - Añadidos o cambios en tests

---

## Versionado

Este proyecto usa [Semantic Versioning](https://semver.org/lang/es/):

- **MAJOR** (X.0.0): Cambios incompatibles con versiones anteriores
- **MINOR** (0.X.0): Nueva funcionalidad compatible hacia atrás
- **PATCH** (0.0.X): Correcciones de bugs compatibles hacia atrás

Ejemplo:
- `1.0.0` → `1.0.1` = Bug fix (PATCH)
- `1.0.1` → `1.1.0` = Nueva característica (MINOR)
- `1.9.5` → `2.0.0` = Cambio incompatible (MAJOR)

---

## Enlaces

- [Código fuente](https://github.com/usuario/ubuntu-advanced-install)
- [Issues](https://github.com/usuario/ubuntu-advanced-install/issues)
- [Roadmap](ROADMAP.md)
- [Archivos antiguos](old/INDEX.md)

---

**Formato del CHANGELOG**: [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)  
**Versionado**: [Semantic Versioning](https://semver.org/lang/es/)

---

<div align="center">

**Ubuntu Advanced Installer**

Instalación profesional de Ubuntu con optimizaciones y configuración avanzada

[📖 README](../README.md) · [🗺️ Roadmap](ROADMAP.md) · [🏗️ Arquitectura](ARCHITECTURE.md)

</div>
