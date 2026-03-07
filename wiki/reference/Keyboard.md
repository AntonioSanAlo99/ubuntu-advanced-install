# Configuración de Teclado Español

## Configuración aplicada

El instalador configura **Español de España (es)** como único layout de teclado en:

### 1. Consola TTY (texto)
- Archivo: `/etc/default/keyboard`
- Layout: `es` (Español)
- Modelo: `pc105` (teclado estándar 105 teclas)

### 2. X11/Wayland (gráfico)
- Archivo: `/etc/X11/xorg.conf.d/00-keyboard.conf`
- Layout: `es`
- Modelo: `pc105`

### 3. systemd (localectl)
- Keymap consola: `es`
- Keymap X11: `es pc105`

## Verificar configuración

```bash
# Ver configuración actual
localectl status

# Ver archivo de teclado
cat /etc/default/keyboard

# Ver configuración X11
cat /etc/X11/xorg.conf.d/00-keyboard.conf
```

## Cambiar a otro layout manualmente

Si necesitas cambiar el layout después de la instalación:

### Opción 1: Con GNOME Settings
```
Configuración → Teclado → Fuentes de entrada → Añadir/Eliminar
```

### Opción 2: Con localectl (consola)
```bash
# Cambiar a layout latinoamericano
sudo localectl set-keymap latam
sudo localectl set-x11-keymap latam pc105

# Volver a español de España
sudo localectl set-keymap es
sudo localectl set-x11-keymap es pc105
```

### Opción 3: Editar /etc/default/keyboard
```bash
sudo nano /etc/default/keyboard

# Cambiar XKBLAYOUT="es" por:
# XKBLAYOUT="latam"   # Latinoamericano
# XKBLAYOUT="us"      # Inglés estadounidense

sudo setupcon -k
```

## Layouts disponibles

| Código | Layout |
|--------|--------|
| `es` | Español de España |
| `latam` | Latinoamericano |
| `us` | Inglés (EE.UU.) |
| `gb` | Inglés (Reino Unido) |
| `fr` | Francés |
| `de` | Alemán |

## Añadir múltiples layouts (solo si se necesita)

Para añadir español + inglés como alternativa:

```bash
sudo localectl set-x11-keymap "es,us" pc105 "" "grp:alt_shift_toggle"

# Cambiar entre layouts con Alt+Shift
```

## Troubleshooting

**El teclado sigue en inglés después de instalar:**
```bash
# Verificar que los paquetes están instalados
dpkg -l | grep keyboard-configuration

# Reinstalar configuración
sudo apt-get install --reinstall keyboard-configuration console-setup

# Reconfigurar interactivamente
sudo dpkg-reconfigure keyboard-configuration

# Aplicar cambios
sudo setupcon -k
```

**En GNOME el teclado está en inglés:**
```bash
# GNOME ignora /etc/default/keyboard y usa gsettings
# Configurar español en GNOME:
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'es')]"

# Ver configuración actual
gsettings get org.gnome.desktop.input-sources sources
```

**Caracteres especiales no funcionan (ñ, á, etc):**
```bash
# Verificar que el locale es correcto
echo $LANG
# Debería mostrar: es_ES.UTF-8

# Si no, configurarlo
export LANG=es_ES.UTF-8
export LC_ALL=es_ES.UTF-8
```

## Layout español vs latinoamericano

### Español de España (`es`)
- Ñ en tecla a la derecha de L
- Ç en tecla a la derecha de P
- < > en tecla a la izquierda de Z
- Símbolos: @ en AltGr+2, # en AltGr+3

### Latinoamericano (`latam`)
- Ñ en tecla a la derecha de L
- Sin tecla Ç dedicada
- Distribución diferente de símbolos

El instalador usa **español de España** por defecto, que es el layout más común en España.
