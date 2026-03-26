# Ubuntu Advanced Installer - Información del Proyecto

<div align="center">

**Instalador profesional de Ubuntu con optimizaciones avanzadas**

[![Version](https://img.shields.io/badge/version-1.0.1-blue.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Ubuntu](https://img.shields.io/badge/ubuntu-24.04%20LTS%20(noble)-orange.svg)](README.md)

[🚀 Inicio Rápido](#inicio-rápido) · [📖 Documentación](#documentación) · [📋 Changelog](CHANGELOG.md) · [🗺️ Roadmap](ROADMAP.md)

</div>

---

## 📋 Índice General

- [Información del Proyecto](#información-del-proyecto)
- [Inicio Rápido](#inicio-rápido)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Documentación](#documentación)
- [Desarrollo](#desarrollo)
- [Versiones](#versiones)
- [Contribuir](#contribuir)

---

## 🎯 Información del Proyecto

### ¿Qué es Ubuntu Advanced Installer?

Un instalador modular y automatizado para Ubuntu que proporciona:

- ✅ **Instalación base optimizada** - Sistema minimalista sin bloat
- ✅ **GNOME Desktop completo** - Con VRR/HDR y configuraciones avanzadas
- ✅ **Gaming ready** - Steam, Proton, GameMode, MangoHud
- ✅ **Development tools** - VS Code, NodeJS, Docker, Git
- ✅ **Laptop optimizations** - TLP, auto-cpufreq, gestures
- ✅ **100% modular** - Elige qué instalar y qué no

### Versión Actual

**v1.0.1** - Febrero 2024

**Última actualización**: Eliminadas validaciones de hardware

Ver [CHANGELOG.md](CHANGELOG.md) para detalles completos.

---

## 🚀 Inicio Rápido

### Instalación en 3 pasos:

```bash
# 1. Descargar y extraer
tar xzf ubuntu-advanced-install-v1.0.1.tar.gz
cd ubuntu-advanced-install

# 2. Configurar (opcional)
nano config.yaml

# 3. Instalar
sudo bash install.sh
```

**Tiempo estimado**: 30-60 minutos (según opciones elegidas)

### Requisitos Recomendados

- **CPU**: 4+ cores (x86_64)
- **RAM**: 8GB+ (mínimo: 2GB)
- **Disco**: 50GB+ libre (mínimo: 20GB)
- **Conexión**: Internet estable

**Nota**: El instalador NO valida estos requisitos. Puedes instalar en cualquier hardware.

---

## 📁 Estructura del Proyecto

```
ubuntu-advanced-install/
├── 📄 README.md                     # Documentación principal
├── 🔧 install.sh                    # Script de instalación
├── ⚙️  config.yaml                    # Configuración
├── .gitignore
│
├── 📂 modules/                      # Módulos de instalación (25 módulos)
│   ├── 01-prepare-disk.sh          # Particionado de disco
│   ├── 02-mount-partitions.sh      # Montaje de particiones
│   ├── 03-debootstrap.sh           # Instalación base
│   ├── 10-install-gnome-core.sh    # GNOME Desktop + workspaces config
│   ├── 16-configure-gaming.sh      # Gaming + VRR/HDR
│   └── ...                          # (21 módulos más)
│
├── 📂 docs/                         # Toda la documentación
│   ├── README.md                    # Índice de documentación
│   ├── PROJECT-INFO.md              # Información general del proyecto
│   ├── CHANGELOG.md                 # Historial de cambios
│   ├── ARCHITECTURE.md              # Arquitectura del proyecto
│   ├── MODULE-DEVELOPMENT.md        # Guía de desarrollo de módulos
│   ├── ROADMAP.md                   # Plan de desarrollo futuro
│   └── old/                         # Archivos históricos
│       ├── INDEX.md                 # Índice de archivos antiguos
│       ├── README.md.old            # README anterior (v1.0.0)
│       └── 16-configure-gaming.sh.old  # Gaming module (pre-VRR/HDR)
│
├── 📂 files/                        # Archivos auxiliares
├── 📂 tools/                        # Scripts de utilidad
└── 📂 wiki/                         # Wiki y guías adicionales
    └── ...
```
```

---

## 📖 Documentación

### Documentos Principales

| Documento | Descripción | Para quién |
|-----------|-------------|------------|
| [../README.md](../README.md) | **Guía completa de uso** | Todos los usuarios |
| [CHANGELOG.md](CHANGELOG.md) | Historial de cambios | Usuarios avanzados |
| [PROJECT-INFO.md](PROJECT-INFO.md) | Navegación del proyecto | Nuevos usuarios |

### Documentación Técnica

| Documento | Descripción | Para quién |
|-----------|-------------|------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Arquitectura y diseño | Desarrolladores |
| [MODULE-DEVELOPMENT.md](MODULE-DEVELOPMENT.md) | Crear módulos | Desarrolladores |
| [ROADMAP.md](ROADMAP.md) | Plan futuro | Todos |
| [old/INDEX.md](old/INDEX.md) | Archivos históricos | Mantenedores |

### Guías Rápidas

**Para usuarios nuevos**:
1. Lee [../README.md](../README.md) - Sección "Instalación"
2. Configura [../config.yaml](../config.yaml)
3. Ejecuta `sudo bash install.sh`

**Para desarrolladores**:
1. Lee [ARCHITECTURE.md](ARCHITECTURE.md)
2. Lee [MODULE-DEVELOPMENT.md](MODULE-DEVELOPMENT.md)
3. Crea tu módulo en `../modules/`

**Para contribuir**:
1. Fork del repositorio
2. Crea rama feature
3. Sigue guía en [MODULE-DEVELOPMENT.md](MODULE-DEVELOPMENT.md)
4. Pull request

---

## 🔧 Desarrollo

### Características Principales

#### Desktop Environment
- **GNOME Desktop** (versión según Ubuntu)
- **Workspaces configurables** (1 fijo o dinámicos)
- **Tiempo de pantalla opcional** (privacidad)
- Optimizaciones de memoria
- Extensiones esenciales

#### Gaming
- **VRR habilitado** (FreeSync/G-Sync)
- **HDR soporte** (GNOME 47+ con hardware compatible)
- **Animaciones opcionales** (rendimiento vs experiencia)
- Steam + Proton GE/Cachyos
- GameMode + MangoHud

#### Development
- VS Code + extensiones
- NodeJS 24.x LTS (Krypton)
- Docker + Docker Compose
- Git + GitHub CLI

#### System
- Drivers automáticos (NVIDIA/AMD/Intel)
- PipeWire audio
- Bluetooth
- Systemd minimizado (opcional)

### Versiones de Ubuntu Soportadas

| Versión | Codename | Estado | LTS |
|---------|----------|--------|-----|
| 20.04 | Focal Fossa | ✅ Soportado | ✅ |
| 22.04 | Jammy Jellyfish | ✅ Soportado | ✅ |
| **24.04** | **Noble Numbat** | ✅ **Recomendado** | ✅ |
| 25.10 | Questing Quokka | ✅ Soportado | ❌ |
| 26.04 | Resolute Raccoon | ⚠️ En desarrollo | ✅ |

---

## 📊 Versiones

### Histórico de Versiones

| Versión | Fecha | Cambios Principales | Estado |
|---------|-------|---------------------|--------|
| **1.0.1** | 22 Feb 2024 | Eliminadas validaciones hardware | ✅ Actual |
| 1.0.0 | 21 Feb 2024 | VRR/HDR + Workspaces config | Anterior |
| 0.9.0 | 20 Feb 2024 | Primera versión funcional | Antigua |

Ver [CHANGELOG.md](CHANGELOG.md) para detalles completos de cada versión.

### Sistema de Versionado

Usamos [Semantic Versioning](https://semver.org/lang/es/):

```
MAJOR.MINOR.PATCH

Ejemplo: 1.0.1
         │ │ └─ PATCH: Bug fixes
         │ └─── MINOR: Nueva funcionalidad
         └───── MAJOR: Cambios incompatibles
```

### Roadmap

**Próximas versiones** (ver [docs/ROADMAP.md](docs/ROADMAP.md)):

- **v1.1.0** (Q2 2026): KDE Plasma, TUI, Profiles
- **v1.2.0** (Q3 2026): Arch Linux, Backup, Cloud
- **v2.0.0** (Q4 2026): Multi-distro, Containers, Web UI

---

## 🤝 Contribuir

### Cómo Contribuir

1. **Fork** el repositorio
2. **Crea** una rama: `git checkout -b feature/AmazingFeature`
3. **Commit** cambios: `git commit -m 'Add AmazingFeature'`
4. **Push** a la rama: `git push origin feature/AmazingFeature`
5. **Abre** un Pull Request

### Áreas de Contribución

- 🐛 **Reportar bugs** - Abre un issue
- ✨ **Proponer features** - Abre un issue con tag `enhancement`
- 📝 **Mejorar documentación** - Pull request directo
- 🔧 **Crear módulos** - Lee [MODULE-DEVELOPMENT.md](docs/MODULE-DEVELOPMENT.md)
- 🧪 **Testing** - Prueba en diferentes hardware/versiones

### Guías de Contribución

Ver:
- [docs/MODULE-DEVELOPMENT.md](docs/MODULE-DEVELOPMENT.md) - Crear módulos
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Entender el código
- [CHANGELOG.md](CHANGELOG.md) - Formato de cambios

---

## 📜 Licencia

Este proyecto está bajo la licencia GPL-3.0-only — ver [LICENSE](LICENSE) para detalles.

---

## 🔗 Enlaces Útiles

### Proyecto
- [GitHub Repository](https://github.com/usuario/ubuntu-advanced-install)
- [Issues](https://github.com/usuario/ubuntu-advanced-install/issues)
- [Discussions](https://github.com/usuario/ubuntu-advanced-install/discussions)

### Documentación
- [README Principal](../README.md) - Guía completa
- [CHANGELOG](CHANGELOG.md) - Historial de cambios
- [ROADMAP](ROADMAP.md) - Plan futuro
- [ARCHITECTURE](ARCHITECTURE.md) - Diseño técnico

### Recursos
- [Keep a Changelog](https://keepachangelog.com/es/1.0.0/)
- [Semantic Versioning](https://semver.org/lang/es/)
- [Ubuntu Documentation](https://help.ubuntu.com/)

---

## 📞 Contacto y Soporte

### Obtener Ayuda

- **Issues**: Problemas técnicos o bugs
- **Discussions**: Preguntas generales o ideas
- **Wiki**: Guías adicionales y tutoriales

### Comunidad

- GitHub Discussions (preguntas y ayuda)
- GitHub Issues (bugs y features)

---

## ⭐ Star History

Si este proyecto te resulta útil, considera darle una ⭐ en GitHub.

---

<div align="center">

**Ubuntu Advanced Installer v1.0.1**

Instalación profesional de Ubuntu con optimizaciones avanzadas

[📖 README](../README.md) · [📋 CHANGELOG](CHANGELOG.md) · [🗺️ Roadmap](ROADMAP.md) · [🏗️ Arquitectura](ARCHITECTURE.md)

---

**Mantenido por**: [Tu Nombre]  
**Última actualización**: 22 Feb 2024  
**Licencia**: GPL-3.0-only

</div>
