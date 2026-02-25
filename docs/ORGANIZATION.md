# Organización del Proyecto

## Estructura de Directorios

```
ubuntu-advanced-install/
├── install.sh              # Script principal de instalación
├── README.md               # Documentación principal
├── config.env.example      # Ejemplo de configuración
├── verify-modules.sh       # Verificación de módulos
│
├── modules/                # Módulos de instalación
│   ├── 00-*.sh            # Verificaciones
│   ├── 01-*.sh            # Preparación de disco
│   ├── 02-*.sh            # Instalación base
│   ├── 03-*.sh            # Configuración base
│   ├── 04-*.sh            # Bootloader
│   ├── 05-*.sh            # Red
│   ├── 06-*.sh            # Actualizaciones
│   ├── 10-*.sh            # GNOME
│   ├── 12-*.sh            # Multimedia
│   ├── 13-*.sh            # Fuentes
│   ├── 14-*.sh            # WiFi
│   ├── 15-*.sh            # Desarrollo
│   ├── 16-*.sh            # Gaming
│   ├── 21-*.sh            # Laptop
│   ├── 23-*.sh            # Systemd
│   ├── 24-*.sh            # Seguridad
│   └── 31-*.sh            # Reportes
│
├── docs/                   # Documentación del proyecto
│   ├── README.md          # Índice de documentación
│   ├── CHANGELOG.md       # Registro de cambios
│   ├── ERROR-HANDLING.md  # Manejo de errores
│   ├── PROJECT-INFO.md    # Información del proyecto
│   ├── ROADMAP.md         # Hoja de ruta
│   ├── STRUCTURE.txt      # Estructura detallada
│   ├── TESTING-MODULES.md # Testing
│   ├── MODULE-*.md        # Documentación de módulos
│   ├── archive/           # Versiones antiguas
│   └── old/               # Archivos históricos
│
├── wiki/                   # Wiki del proyecto
│   ├── README.md          # Índice wiki
│   ├── GNOME.md           # Configuración GNOME
│   ├── Gaming-Launchers.md
│   ├── Fonts.md
│   ├── Laptop.md
│   ├── Locales.md
│   ├── Thumbnailers.md
│   └── 03-Troubleshooting.md
│
├── files/                  # Archivos adicionales
│
└── tools/                  # Herramientas auxiliares
    └── (scripts de desarrollo)
```

## Reglas de Organización

### Módulos (`modules/`)
- **Solo scripts ejecutables (.sh)**
- Sin documentación interna
- Numerados por orden de ejecución
- Documentación en `docs/MODULE-*.md`

### Documentación (`docs/`)
- Documentación técnica del proyecto
- Guías de desarrollo
- Changelog y roadmap
- `archive/` para versiones antiguas
- `old/` para referencia histórica

### Wiki (`wiki/`)
- Documentación de usuario
- Guías de configuración
- Troubleshooting
- Explicaciones de características

### Archivos (`files/`)
- Archivos de configuración
- Assets
- Templates

### Herramientas (`tools/`)
- Scripts de desarrollo
- Utilidades de testing
- Herramientas auxiliares

## Limpieza Realizada (v3.13.4)

- ✓ Movido `modules/02.5-README.md` → `docs/MODULE-02.5-DEBOOTSTRAP.md`
- ✓ Eliminados archivos `.old` y `.bak`
- ✓ Eliminados READMEs obsoletos v1.0.0
- ✓ Limpiado `wiki/_archive`
- ✓ Reorganizado `docs/old`
- ✓ Creada esta guía de organización
