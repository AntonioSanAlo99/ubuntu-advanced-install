# Extensiones de GNOME - Configuración

## Extensiones instaladas

El instalador incluye 3 extensiones esenciales de GNOME Shell:

### 1. **App Indicators** (`appindicatorsupport@rgcjonas.gmail.com`)
- **Función**: Muestra iconos de aplicaciones en la bandeja del sistema
- **Ejemplos**: Dropbox, Discord, Steam, Telegram
- **Sin esta extensión**: Apps con icono de bandeja no se mostrarían

### 2. **Desktop Icons NG** (`ding@rastersoft.com`)
- **Función**: Iconos en el escritorio (archivos, carpetas, USB)
- **Características**:
  - Arrastrar archivos al escritorio
  - Crear carpetas/archivos en el escritorio
  - Montar unidades USB automáticamente
- **Sin esta extensión**: Escritorio completamente vacío

### 3. **Ubuntu Dock** (`ubuntu-dock@ubuntu.com`)
- **Función**: Barra de aplicaciones favoritas a la izquierda
- **Características**:
  - Lanzador de aplicaciones
  - Cambiar entre ventanas abiertas
  - Indicadores de aplicaciones activas
- **Sin esta extensión**: No habría lanzador de aplicaciones

## Activación automática

Las extensiones se activan automáticamente en el **primer login** del usuario mediante:

1. **Script de configuración**: `/etc/profile.d/01-gnome-config.sh`
2. **Archivo de marca**: `~/.config/.gnome-configured`
3. **Método de activación**:
   - Primero intenta: `gnome-extensions enable`
   - Si falla: usa D-Bus directamente

## Verificar que las extensiones están activas

```bash
# Ver extensiones instaladas
gnome-extensions list

# Ver estado de cada extensión
gnome-extensions show appindicatorsupport@rgcjonas.gmail.com
gnome-extensions show ding@rastersoft.com
gnome-extensions show ubuntu-dock@ubuntu.com

# Ver todas las extensiones activas
gsettings get org.gnome.shell enabled-extensions
```

## Si las extensiones no se activan

### Método 1: Manual desde terminal
```bash
# Activar todas
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
gnome-extensions enable ding@rastersoft.com
gnome-extensions enable ubuntu-dock@ubuntu.com

# Reiniciar GNOME Shell (solo X11, no Wayland)
killall -SIGQUIT gnome-shell
```

### Método 2: Desde Extension Manager
```
1. Abrir "Gestor de extensiones" desde el menú
2. Buscar las extensiones instaladas
3. Activar con el interruptor
```

### Método 3: Desde GNOME Tweaks
```
1. Abrir "Retoques" (gnome-tweaks)
2. Ir a "Extensiones"
3. Activar las extensiones manualmente
```

## Aplicaciones instaladas

### Utilidades del sistema
- **Calculadora** (`gnome-calculator`) - Calculadora científica
- **Logs** (`gnome-logs`) - Ver logs del sistema (journalctl con GUI)
- **Analizador de disco** (`baobab`) - Ver uso de disco visualmente
- **Gestor de tipografías** (`gnome-font-viewer`) - Ver e instalar fuentes

### Productividad
- **Gedit** - Editor de texto
- **Evince** - Lector de PDF
- **File Roller** - Gestor de archivos comprimidos
- **Nautilus** - Gestor de archivos (con nautilus-admin)

### Sistema
- **GNOME Tweaks** - Configuración avanzada
- **Extension Manager** - Gestor de extensiones
- **Discos** - Gestión de particiones y discos
- **Viewnior** - Visor de imágenes ligero

## Tema de iconos

**Elementary** está configurado como tema predeterminado:
```bash
# Verificar tema actual
gsettings get org.gnome.desktop.interface icon-theme

# Cambiar manualmente si fuera necesario
gsettings set org.gnome.desktop.interface icon-theme 'elementary'
```

## Troubleshooting

### Las extensiones no aparecen después del primer login

**Causa**: El script no se ejecutó o falló

**Solución**:
```bash
# Ejecutar manualmente
bash /etc/profile.d/01-gnome-config.sh

# O activar extensiones una por una
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
gnome-extensions enable ding@rastersoft.com
gnome-extensions enable ubuntu-dock@ubuntu.com
```

### Los iconos del escritorio no se muestran

**Causa**: Desktop Icons NG no está activa

**Solución**:
```bash
# Activar Desktop Icons
gnome-extensions enable ding@rastersoft.com

# Reiniciar GNOME Shell (X11)
killall -SIGQUIT gnome-shell

# En Wayland: cerrar sesión y volver a entrar
```

### No aparecen iconos de aplicaciones en la bandeja

**Causa**: App Indicators no está activa

**Solución**:
```bash
# Activar App Indicators
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com

# Reiniciar la aplicación que debe mostrar icono
```

### El dock no aparece a la izquierda

**Causa**: Ubuntu Dock no está activa

**Solución**:
```bash
# Activar Ubuntu Dock
gnome-extensions enable ubuntu-dock@ubuntu.com

# Reiniciar GNOME Shell
killall -SIGQUIT gnome-shell
```

### El tema de iconos no es elementary

**Causa**: gsettings no se aplicó

**Solución**:
```bash
gsettings set org.gnome.desktop.interface icon-theme 'elementary'
```

## Añadir más extensiones

### Desde Extension Manager (GUI)
```
1. Abrir "Gestor de extensiones"
2. Ir a "Explorar"
3. Buscar extensión deseada
4. Instalar
```

### Desde extensions.gnome.org (web)
```
1. Instalar extensión del navegador
2. Visitar https://extensions.gnome.org
3. Buscar e instalar extensiones
```

### Manualmente
```bash
# Instalar desde repos
sudo apt install gnome-shell-extension-nombre

# Activar
gnome-extensions enable nombre-de-extension
```

## Extensiones recomendadas adicionales

- **Dash to Panel** - Barra de tareas estilo Windows
- **Blur my Shell** - Efectos de desenfoque
- **Clipboard Indicator** - Historial del portapapeles
- **GSConnect** - Integración con Android
- **Caffeine** - Evitar suspensión automática
- **Sound Input & Output Device Chooser** - Cambiar dispositivos de audio

Puedes instalarlas desde el Gestor de extensiones.
