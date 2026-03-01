# Carpetas del App Grid en GNOME

## Configuración Automática

El instalador configura automáticamente dos carpetas en el app grid:

### 📁 Utilidades
Agrupa herramientas y utilidades del sistema:
- Calculadora
- Terminal
- Baobab (Analizador de uso de disco)
- Visor de fuentes
- Archivador (File Roller)
- Logs del sistema

### ⚙️ Sistema
Agrupa configuración y herramientas de sistema:
- Centro de control (Settings)
- GNOME Tweaks
- Monitor del sistema
- Discos (Disk Utility)
- Propiedades del software

## Cómo Funciona

GNOME usa el estándar de freedesktop.org para categorizar aplicaciones:

```bash
# Cada .desktop file tiene categorías
/usr/share/applications/org.gnome.Calculator.desktop
→ Categories=GNOME;GTK;Core;Utility;Calculator;

# GNOME agrupa por estas categorías
X-GNOME-Utilities → Carpeta "Utilidades"
Settings;System   → Carpeta "Sistema"
```

## Estructura de gsettings

```
org.gnome.desktop.app-folders
├── folder-children: ['Utilities', 'System']
│
├── folder:/org/gnome/desktop/app-folders/folders/Utilities/
│   ├── name: 'Utilidades'
│   ├── translate: false
│   ├── categories: ['X-GNOME-Utilities']
│   └── apps: ['org.gnome.Calculator.desktop', ...]
│
└── folder:/org/gnome/desktop/app-folders/folders/System/
    ├── name: 'Sistema'
    ├── translate: false
    ├── categories: ['Settings', 'System']
    └── apps: ['gnome-control-center.desktop', ...]
```

## Personalización Manual

### Ver carpetas actuales

```bash
gsettings get org.gnome.desktop.app-folders folder-children
# ['Utilities', 'System']
```

### Ver apps en una carpeta

```bash
gsettings get org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps
```

### Crear nueva carpeta personalizada

```bash
# Ejemplo: Carpeta "Desarrollo"
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ name 'Desarrollo'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Development/ apps "['code.desktop', 'org.gnome.Terminal.desktop', 'github-desktop.desktop']"

# Añadir a folder-children
gsettings set org.gnome.desktop.app-folders folder-children "['Utilities', 'System', 'Development']"
```

### Añadir app a carpeta existente

```bash
# Obtener lista actual
APPS=$(gsettings get org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps)

# Editar y volver a establecer
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps "['app1.desktop', 'app2.desktop', 'nueva-app.desktop']"
```

### Renombrar carpeta

```bash
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ name 'Herramientas'
```

### Eliminar carpeta

```bash
# Remover de folder-children
gsettings set org.gnome.desktop.app-folders folder-children "['System']"

# La carpeta Utilities desaparecerá del app grid
```

## Reset a Configuración por Defecto

```bash
gsettings reset org.gnome.desktop.app-folders folder-children
gsettings reset-recursively org.gnome.desktop.app-folders
```

## Categorías Comunes de freedesktop.org

```
AudioVideo     → Multimedia (audio/video)
Development    → Herramientas de desarrollo
Education      → Educación
Game           → Juegos
Graphics       → Gráficos
Network        → Red/Internet
Office         → Ofimática
Science        → Ciencia
Settings       → Configuración
System         → Sistema
Utility        → Utilidades

X-GNOME-*      → Categorías específicas de GNOME
X-KDE-*        → Categorías específicas de KDE
```

## Ver Categorías de una App

```bash
# Método 1: grep en el .desktop
grep Categories /usr/share/applications/org.gnome.Calculator.desktop

# Método 2: desktop-file-validate
desktop-file-validate /usr/share/applications/org.gnome.Calculator.desktop
```

## Ejemplos de Carpetas Personalizadas

### Carpeta Multimedia

```bash
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ name 'Multimedia'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Multimedia/ categories "['AudioVideo', 'Audio', 'Video']"
```

### Carpeta Internet

```bash
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ name 'Internet'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Internet/ categories "['Network', 'WebBrowser']"
```

### Carpeta Gaming

```bash
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Games/ name 'Juegos'
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Games/ translate false
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Games/ categories "['Game']"
```

## GUI para Gestión de Carpetas

Puedes usar **GNOME Tweaks** o **Extension Manager** con la extensión "AppFolders Manager":

```bash
flatpak install flathub com.github.tchx84.Flatseal  # Gestión de permisos
# Incluye gestor de carpetas visual
```

O instalar la extensión:
- [AppFolders Management](https://extensions.gnome.org/extension/1217/appfolders-manager/)

## Troubleshooting

### Las carpetas no aparecen

```bash
# Reiniciar GNOME Shell (solo X11)
killall -SIGQUIT gnome-shell

# En Wayland, cerrar sesión y volver a entrar
```

### Apps no se agrupan correctamente

```bash
# Verificar que la app tiene la categoría
grep Categories /usr/share/applications/app.desktop

# Forzar app específica en carpeta (no usar categorías)
gsettings set org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/Utilities/ apps "['app-especifica.desktop']"
```

### Ver configuración completa

```bash
dconf dump /org/gnome/desktop/app-folders/
```

## Referencias

- [freedesktop.org Menu Specification](https://specifications.freedesktop.org/menu-spec/latest/)
- [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/)
- [GNOME Shell Extensions](https://extensions.gnome.org/)
