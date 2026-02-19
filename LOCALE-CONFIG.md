# Configuración de Idioma Español

## Configuración aplicada

El sistema está completamente configurado en **español de España (es_ES.UTF-8)** en todos los niveles:

### 1. Locale del sistema
- **Archivo**: `/etc/default/locale`
- **Variables**:
  - `LANG=es_ES.UTF-8`
  - `LANGUAGE=es_ES:es`
  - `LC_ALL=es_ES.UTF-8`
  - `LC_MESSAGES=es_ES.UTF-8`

### 2. systemd
- **Archivo**: `/etc/locale.conf`
- **Configuración**: `LANG=es_ES.UTF-8`, `LC_MESSAGES=es_ES.UTF-8`
- **Efecto**: Mensajes de systemd en español

### 3. Variables de entorno
- **Archivo**: `/etc/environment`
- **Efecto**: Todos los servicios y aplicaciones usan español

### 4. TTY/Getty (consolas virtuales)
- **Archivo**: `/etc/systemd/system/getty@.service.d/locale.conf`
- **Efecto**: Mensajes de login y sistema en español en Ctrl+Alt+F1-F6

### 5. Paquetes instalados
```
language-pack-es              # Traducciones generales
language-pack-es-base         # Traducciones base
language-pack-gnome-es        # Traducciones GNOME
language-pack-gnome-es-base   # Base GNOME
manpages-es                   # Páginas de manual
manpages-es-extra             # Manuales adicionales
hunspell-es                   # Corrector ortográfico
hyphen-es                     # Separación silábica
mythes-es                     # Diccionario de sinónimos
```

## Verificar configuración

```bash
# Ver locale actual
locale

# Ver configuración de systemd
localectl status

# Ver mensajes del sistema en español
journalctl -b | head -20

# Ver archivos de configuración
cat /etc/default/locale
cat /etc/locale.conf
cat /etc/environment
```

## Resultado esperado

### En TTY (Ctrl+Alt+F2)
```
Ubuntu 24.04 LTS hostname tty2

hostname login: _
```
Mensajes de inicio y systemd en español.

### En terminal GNOME
```bash
usuario@hostname:~$ man ls
# Página de manual en español
```

### Mensajes del sistema
```bash
sudo systemctl status NetworkManager
# Estado y mensajes en español
```

## Qué está en español

✅ **Mensajes de systemd** (inicio, servicios)
✅ **Login prompts** (TTY1-6)
✅ **Páginas de manual** (`man comando`)
✅ **Mensajes de error del sistema**
✅ **GNOME completo** (menús, diálogos, configuración)
✅ **Aplicaciones GTK/Qt** con traducciones disponibles
✅ **Corrector ortográfico** en aplicaciones

## Qué NO está traducido (limitaciones)

❌ **Mensajes del kernel** (siempre en inglés, del propio kernel)
❌ **Bootloader GRUB** (generalmente en inglés)
❌ **Algunos comandos de sistema** sin traducción disponible
❌ **Aplicaciones de terceros** sin soporte de español

## Cambiar a otro idioma

Si necesitas cambiar el idioma del sistema:

### Cambiar a inglés
```bash
sudo localectl set-locale LANG=en_US.UTF-8
sudo systemctl restart systemd-logind
```

### Cambiar a catalán
```bash
sudo apt install language-pack-ca language-pack-gnome-ca
sudo localectl set-locale LANG=ca_ES.UTF-8
```

### Aplicar cambios
```bash
# Reiniciar servicios
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1

# O reiniciar el sistema
sudo reboot
```

## Troubleshooting

### Los mensajes siguen en inglés después de instalar

**Problema**: Algunas aplicaciones no respetan el locale

**Solución**:
```bash
# Verificar que las variables están configuradas
echo $LANG
echo $LC_MESSAGES

# Si están vacías, cargarlas
source /etc/default/locale
export LANG=es_ES.UTF-8
export LC_MESSAGES=es_ES.UTF-8
```

### systemd muestra mensajes mezclados (español/inglés)

**Problema**: Algunas traducciones no están completas

**Solución**: Normal, algunas partes de systemd no tienen traducción completa. Los mensajes principales sí estarán en español.

### Páginas de manual en inglés

**Problema**: El comando no tiene traducción

**Solución**:
```bash
# Ver si existe traducción
man -L es comando

# Instalar más manuales en español
sudo apt install manpages-es-extra
```

### TTY1 (login) sigue en inglés

**Problema**: Getty no recargó la configuración

**Solución**:
```bash
# Recargar systemd
sudo systemctl daemon-reload

# Reiniciar getty
sudo systemctl restart getty@tty1

# O reiniciar el sistema
sudo reboot
```

### GNOME en inglés después de login

**Problema**: El usuario tiene configuración propia

**Solución**:
```bash
# GNOME usa su propia configuración por usuario
# Cambiar en: Configuración → Región e idioma
# O con gsettings:
gsettings set org.gnome.system.locale region 'es_ES.UTF-8'
```

## Variables de locale

| Variable | Uso | Valor en este sistema |
|----------|-----|----------------------|
| `LANG` | Locale predeterminado | `es_ES.UTF-8` |
| `LANGUAGE` | Lista de idiomas preferidos | `es_ES:es` |
| `LC_ALL` | Sobrescribe todas las LC_* | `es_ES.UTF-8` |
| `LC_MESSAGES` | Mensajes del sistema | `es_ES.UTF-8` |
| `LC_TIME` | Formato de fecha/hora | (hereda de LANG) |
| `LC_NUMERIC` | Formato de números | (hereda de LANG) |

## Archivos de configuración relevantes

```
/etc/default/locale                           # Locale de aplicaciones
/etc/locale.conf                              # Locale de systemd
/etc/environment                              # Variables globales
/etc/systemd/system/getty@.service.d/locale.conf  # TTY en español
/etc/locale.gen                               # Locales disponibles
```

## Regenerar locales

Si los locales se corrompen:

```bash
# Regenerar todos
sudo locale-gen

# Regenerar solo español
sudo locale-gen es_ES.UTF-8

# Actualizar configuración
sudo update-locale LANG=es_ES.UTF-8
```
