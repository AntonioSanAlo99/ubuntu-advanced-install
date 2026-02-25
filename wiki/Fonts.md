# Configuración de Tipografías

## Tipografías Predeterminadas

El sistema configura automáticamente las siguientes tipografías:

### Interfaz del Sistema
```bash
Ubuntu Regular 11
```
- Menús, botones, diálogos
- Aplicaciones GNOME
- Configuración del sistema

### Documentos
```bash
Ubuntu Regular 11
```
- Gedit, LibreOffice
- Visores de PDF
- Aplicaciones de oficina

### Títulos de Ventanas
```bash
Ubuntu Bold 11
```
- Barra de título de todas las ventanas
- Más prominente que el resto

### Monospace (Terminal/Código)
```bash
JetBrainsMono Nerd Font 10
```
- Terminal (GNOME Terminal)
- Editores de código (VS Code, gedit)
- Consola de desarrollo

## Ventajas de JetBrainsMono Nerd Font

✅ **Ligaduras de código** - `!=` se muestra como `≠`, `=>` como `⇒`
✅ **Iconos integrados** - Glyphs de Nerd Fonts para terminal
✅ **Claridad** - Diseñada específicamente para código
✅ **Distinción** - 0 vs O, 1 vs l vs I claramente diferenciados

## Cambiar Tipografías

### Desde GNOME Tweaks

```bash
# Instalar tweaks si no está
sudo apt install gnome-tweaks

# Abrir
gnome-tweaks
```

**Ir a:** Fuentes → Cambiar cada tipografía

### Desde Terminal

```bash
# Interfaz
gsettings set org.gnome.desktop.interface font-name 'Ubuntu 12'

# Documentos
gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 12'

# Títulos
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 12'

# Monospace
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11'
```

## Tipografías Disponibles

El instalador incluye:

### Sistema
- **Ubuntu** (Regular, Bold, Italic, etc.)
- **Liberation** (alternativa a Arial, Times, Courier)
- **DejaVu** (sans, serif, mono)
- **Noto** (incluye emoji)
- **Font Awesome** (iconos)

### Microsoft

**Core Fonts (ttf-mscorefonts-installer):**
- Arial, Times New Roman, Courier New, Verdana, Georgia, Impact, Trebuchet, Comic Sans, Webdings
- Ubicación: `/usr/share/fonts/truetype/msttcorefonts/`

**ClearType (adicionales):**
- Calibri, Cambria, Candara, Consolas, Constantia, Corbel
- Ubicación: `/usr/local/share/fonts/microsoft-additional/cleartype/`

**Otras (adicionales):**
- Tahoma, Segoe UI
- Ubicación: `/usr/local/share/fonts/microsoft-additional/`

**Nota:** Las fuentes adicionales NO sobrescriben las Core Fonts. Están en directorios separados y se complementan.

### Nerd Fonts (para terminal)
- **JetBrainsMono** (predeterminada)
- **FiraCode** (popular con ligaduras)
- **Hack**
- **Meslo** (Oh My Zsh)
- **UbuntuMono** (parcheada)
- **DejaVuSansMono**

## Verificar Tipografías Instaladas

```bash
# Listar todas
fc-list | sort

# Buscar una específica
fc-list | grep -i ubuntu
fc-list | grep -i jetbrains

# Ver fuentes disponibles en GNOME
gnome-font-viewer
```

## Tamaños Recomendados

| Uso | Tamaño | Razón |
|-----|--------|-------|
| Interfaz | 10-11 | Legible sin ocupar mucho espacio |
| Documentos | 11-12 | Lectura cómoda |
| Títulos | 11 Bold | Destaca pero no exagera |
| Monospace | 9-10 | Terminal suele verse mejor más pequeño |

## Configuración Avanzada

### Hinting y Antialiasing

```bash
# Ver configuración actual
gsettings get org.gnome.desktop.interface font-antialiasing
gsettings get org.gnome.desktop.interface font-hinting

# Opciones de antialiasing: none, grayscale, rgba
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'

# Opciones de hinting: none, slight, medium, full
gsettings set org.gnome.desktop.interface font-hinting 'slight'
```

**Recomendado:**
- Antialiasing: `rgba` (mejor en pantallas modernas)
- Hinting: `slight` (balance entre nitidez y suavidad)

### Escalado de Fuentes

Para pantallas HiDPI o si necesitas fuentes más grandes:

```bash
# Factor de escala (1.0 = normal, 1.25 = 25% más grande, etc.)
gsettings set org.gnome.desktop.interface text-scaling-factor 1.25
```

### Ligaduras en Terminal

Para habilitar ligaduras en GNOME Terminal:

```bash
# Abrir perfil de terminal
# Editar → Preferencias → Perfil → Texto
# Activar: "Ligaduras personalizadas"
```

O desde terminal:
```bash
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$PROFILE/ \
    font 'JetBrainsMono Nerd Font 10'
```

## Tipografías para Aplicaciones Específicas

### VS Code

```json
{
  "editor.fontFamily": "'JetBrainsMono Nerd Font', 'Ubuntu Mono', monospace",
  "editor.fontSize": 13,
  "editor.fontLigatures": true
}
```

### Firefox

Configuración → General → Fuentes → Avanzado:
- Proporcional: Ubuntu
- Serif: Liberation Serif
- Sans-serif: Ubuntu
- Monospace: JetBrainsMono Nerd Font

### LibreOffice

Herramientas → Opciones → Fuentes:
- Predeterminada: Ubuntu
- Fuente para listas: Ubuntu
- Subtítulo: Ubuntu
- Título: Ubuntu Bold

## Instalar Tipografías Adicionales

### Desde Repositorios

```bash
# Buscar fuentes disponibles
apt search fonts- | grep ^fonts-

# Instalar una fuente
sudo apt install fonts-roboto
```

### Manualmente (Usuario)

```bash
# Crear directorio de fuentes del usuario
mkdir -p ~/.local/share/fonts

# Copiar archivos .ttf o .otf
cp MiFuente.ttf ~/.local/share/fonts/

# Actualizar caché
fc-cache -f -v
```

### Manualmente (Sistema)

```bash
# Requiere sudo
sudo mkdir -p /usr/local/share/fonts/misfuentes
sudo cp MiFuente.ttf /usr/local/share/fonts/misfuentes/
sudo fc-cache -f -v
```

## Troubleshooting

### Fuentes borrosas

**Solución:**
```bash
# Cambiar hinting
gsettings set org.gnome.desktop.interface font-hinting 'slight'

# Activar antialiasing
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
```

### JetBrainsMono no aparece

**Verificar instalación:**
```bash
fc-list | grep -i jetbrains

# Si no aparece, reinstalar Nerd Fonts desde módulo 13
```

### Ligaduras no funcionan

**Verificar que la fuente las soporta:**
```bash
# JetBrainsMono y FiraCode tienen ligaduras
# Hay que activarlas en cada aplicación
```

### Fuente muy pequeña en HiDPI

**Solución:**
```bash
# Aumentar factor de escala
gsettings set org.gnome.desktop.interface text-scaling-factor 1.5
```

## Referencias

- [Ubuntu Fonts](https://design.ubuntu.com/font/)
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)
- [Nerd Fonts](https://www.nerdfonts.com/)
- [GNOME Fonts](https://help.gnome.org/users/gnome-help/stable/look-display.html)
