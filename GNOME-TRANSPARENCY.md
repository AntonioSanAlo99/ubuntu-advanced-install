# Transparencias en GNOME Shell

## Configuración aplicada

Opacidad del **15%** (85% transparente) en todos los elementos principales de GNOME Shell.

### Elementos con transparencia

| Elemento | Descripción | Archivo CSS |
|----------|-------------|-------------|
| **App Grid** | Lanzador de aplicaciones | `.app-grid` |
| **Panel superior** | Barra superior con reloj e iconos | `#panel` |
| **Calendario** | Panel de calendario y notificaciones | `.calendar-popup` |
| **Quick Settings** | Menú de configuración rápida (WiFi, Bluetooth, etc) | `.quick-settings` |
| **Workspaces** | Selector de espacios de trabajo | `.workspace-background` |
| **Ubuntu Dock** | Barra de aplicaciones lateral | `#dashtodockContainer` |
| **GDM** | Pantalla de login | `#panel`, `.login-dialog` |

## Ubicación de archivos

### CSS del usuario
```
~/.local/share/gnome-shell/gnome-shell.css
```
Este archivo contiene las reglas CSS personalizadas que se aplican a GNOME Shell.

### CSS de GDM (login)
```
/usr/share/gnome-shell/theme/gdm3-custom.css
```
Afecta la pantalla de login (GDM3).

### Script de activación
```
/etc/profile.d/03-gnome-transparency.sh
```
Se ejecuta en el primer login para aplicar transparencias.

## Verificar que las transparencias están activas

### Método 1: Verificar archivo CSS
```bash
cat ~/.local/share/gnome-shell/gnome-shell.css | grep "opacity"
# Debería mostrar: rgba(0, 0, 0, 0.15)
```

### Método 2: Verificar gsettings (Dock)
```bash
gsettings get org.gnome.shell.extensions.dash-to-dock background-opacity
# Debería mostrar: 0.15
```

### Método 3: Visual
- Abrir App Grid (tecla Super) → fondo semi-transparente
- Ver panel superior → semi-transparente
- Abrir calendario (clic en fecha) → semi-transparente

## Cambiar nivel de opacidad

### Para todos los elementos (editar CSS)
```bash
nano ~/.local/share/gnome-shell/gnome-shell.css

# Buscar: rgba(0, 0, 0, 0.15)
# Cambiar a:
#   0.0 = completamente transparente
#   0.5 = 50% opacidad
#   1.0 = opaco (sin transparencia)

# Guardar y reiniciar GNOME Shell:
# X11: Alt+F2, escribir 'r', Enter
# Wayland: cerrar sesión y volver a entrar
```

### Solo para el Dock
```bash
# Cambiar opacidad del Dock (0.0 a 1.0)
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.3

# Modo de transparencia
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
# Opciones: DEFAULT, FIXED, DYNAMIC
```

## Desactivar transparencias

### Opción 1: Eliminar CSS personalizado
```bash
rm ~/.local/share/gnome-shell/gnome-shell.css

# Reiniciar GNOME Shell (X11)
killall -SIGQUIT gnome-shell

# O cerrar sesión (Wayland)
```

### Opción 2: Restaurar opacidad completa (editar CSS)
```bash
nano ~/.local/share/gnome-shell/gnome-shell.css

# Cambiar todos los rgba(0, 0, 0, 0.15) por rgba(0, 0, 0, 0.85)
# O simplemente eliminar las líneas de background-color

# Guardar y reiniciar GNOME Shell
```

### Opción 3: Solo Dock
```bash
gsettings reset org.gnome.shell.extensions.dash-to-dock background-opacity
gsettings reset org.gnome.shell.extensions.dash-to-dock transparency-mode
```

## Personalizar por elemento

Puedes ajustar la transparencia de cada elemento individualmente editando el CSS:

```css
/* Más transparente (5%) */
#panel {
    background-color: rgba(0, 0, 0, 0.05) !important;
}

/* Menos transparente (50%) */
.app-grid {
    background-color: rgba(0, 0, 0, 0.50) !important;
}

/* Opaco completo (100%) */
.quick-settings {
    background-color: rgba(0, 0, 0, 1.0) !important;
}

/* Color diferente (azul oscuro al 15%) */
.calendar-popup {
    background-color: rgba(0, 50, 100, 0.15) !important;
}
```

## Troubleshooting

### Las transparencias no se aplican

**Causa 1**: CSS no se cargó

**Solución**:
```bash
# Verificar que el archivo existe
ls -la ~/.local/share/gnome-shell/gnome-shell.css

# Si no existe, copiar desde plantilla
cp /etc/skel/.local/share/gnome-shell/gnome-shell.css \
   ~/.local/share/gnome-shell/

# Reiniciar GNOME Shell
```

**Causa 2**: GNOME Shell no se reinició

**Solución**:
```bash
# En X11
killall -SIGQUIT gnome-shell

# En Wayland
gnome-session-quit --logout
```

### El Dock no es transparente

**Solución**:
```bash
# Verificar que Ubuntu Dock está activo
gnome-extensions list | grep ubuntu-dock

# Activar si es necesario
gnome-extensions enable ubuntu-dock@ubuntu.com

# Configurar transparencia
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
```

### GDM (login) no es transparente

**Causa**: CSS de GDM no se aplicó

**Solución**:
```bash
# Verificar CSS de GDM
sudo cat /usr/share/gnome-shell/theme/gdm3-custom.css

# Si no existe, recrear
sudo mkdir -p /usr/share/gnome-shell/theme
sudo nano /usr/share/gnome-shell/theme/gdm3-custom.css

# Pegar el CSS (ver módulo 10c)
# Reiniciar GDM
sudo systemctl restart gdm3
```

### Las transparencias se ven mal (texto ilegible)

**Solución**: Aumentar la opacidad
```bash
nano ~/.local/share/gnome-shell/gnome-shell.css

# Cambiar 0.15 por 0.30 o 0.50
# Experimentar hasta encontrar el balance adecuado
```

### Quiero transparencias dinámicas (según el contexto)

Ubuntu Dock soporta transparencias dinámicas:
```bash
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'DYNAMIC'
```

Para otros elementos necesitas extensiones como:
- **Blur my Shell** - Añade desenfoque a elementos
- **Transparent Shell** - Transparencias más avanzadas

## Valores de opacidad recomendados

| Nivel | Valor | Descripción |
|-------|-------|-------------|
| Muy transparente | 0.05-0.10 | Casi invisible, texto puede ser difícil de leer |
| **Transparente** | **0.15-0.25** | **Balance ideal (recomendado)** |
| Medio | 0.30-0.50 | Visible pero con transparencia notable |
| Poco transparente | 0.60-0.80 | Ligera transparencia |
| Opaco | 0.90-1.0 | Sin transparencia (GNOME estándar) |

## Compatibilidad

- ✅ **X11**: Transparencias funcionan perfectamente
- ✅ **Wayland**: Requiere reiniciar sesión para aplicar cambios
- ✅ **GNOME 42+**: Compatible
- ✅ **Ubuntu 22.04+**: Compatible

## Extensiones complementarias

Para mejorar la experiencia visual con transparencias:

- **Blur my Shell** - Añade desenfoque de fondo
- **Compiz windows effect** - Efectos en ventanas
- **Transparent Window Moving** - Transparencia al mover ventanas

```bash
# Instalar desde Extension Manager (GUI)
# O desde terminal
gnome-extensions install blur-my-shell@aunetx
```
