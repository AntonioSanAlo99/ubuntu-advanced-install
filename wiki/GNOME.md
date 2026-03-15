# GNOME

Documentación completa de la instalación y configuración de GNOME.

---

## Instalación

### Componentes Instalados

El módulo **10-install-gnome-core** instala:

#### GNOME Shell y Core
- **gnome-shell** - Entorno de escritorio
- **gnome-session** - Gestor de sesión
- **gnome-settings-daemon** - Daemon de configuración
- **gnome-control-center** - Panel de control (Settings)
- **gdm3** - Display manager
- **plymouth** - Pantalla de arranque

#### Aplicaciones Esenciales
- **nautilus** - Explorador de archivos
- **gnome-terminal** - Terminal
- **gnome-calculator** - Calculadora
- **gedit** - Editor de texto
- **evince** - Visor de PDF
- **file-roller** - Compresor de archivos

#### Utilidades del Sistema
- **gnome-disk-utility** - Gestión de discos
- **gnome-tweaks** - Ajustes avanzados
- **gnome-shell-extension-manager** - Gestor de extensiones
- **nm-connection-editor** - Configuración avanzada de red
- **baobab** - Analizador de uso de disco
- **gnome-logs** - Visor de logs
- **gnome-font-viewer** - Visor de fuentes

#### AppImages
- **AppManager** - Gestor de AppImages estilo macOS (kem-a)
- **AppImage thumbnailer** - Miniaturas de AppImages en Nautilus (.deb de kem-a)

#### Gestión de Software
- **software-properties-gtk** - Repositorios y drivers
- **update-manager** - Actualizaciones del sistema
- **gdebi** - Instalador de .deb

---

## Gestión de AppImages

### AppManager

**Descripción:** Gestor moderno de AppImages con interfaz estilo macOS

**Autor:** [kem-a](https://github.com/kem-a/AppManager)

**Características:**
- Interfaz limpia inspirada en macOS
- Gestión centralizada de AppImages
- Integración con el sistema de aplicaciones
- Thumbnails/miniaturas en Nautilus
- Organización y categorización

**Abrir:**
```bash
/opt/appmanager/AppManager.AppImage
```

O desde el menú de aplicaciones: "AppManager"

**Uso:**

1. **Añadir AppImage:**
   - Abrir AppManager
   - Importar AppImages desde carpetas
   - Gestionar ubicación centralizada

2. **Miniaturas en Nautilus:**
   - Los AppImages muestran su icono automáticamente
   - Gracias al thumbnailer instalado
   - Funciona en vista de iconos/miniaturas

3. **Integración:**
   - AppImages gestionados aparecen en menú
   - Se pueden anclar al dock
   - Actualizaciones centralizadas

### Thumbnailer de AppImages

**Instalado:** .deb de kem-a

**Repositorio:** https://github.com/kem-a/appimage-thumbnailer

**Función:** Muestra miniaturas de archivos .AppImage en Nautilus

**Qué hace:**
- Extrae el icono del AppImage automáticamente
- Lo muestra como miniatura en Nautilus
- Funciona automáticamente al abrir carpetas con AppImages

**Troubleshooting:**

Si las miniaturas no aparecen:

```bash
# Limpiar cache de thumbnails
rm -rf ~/.cache/thumbnails
nautilus -q

# Reabrir Nautilus
nautilus &
```

**Verificar instalación:**
```bash
# Ver si el paquete está instalado
dpkg -l | grep appimage-thumbnailer
```

---

## Configuración Automática

### Extensiones Habilitadas

El script de primer login habilita automáticamente:

1. **AppIndicator Support** - Iconos de bandeja del sistema
2. **Desktop Icons NG (DING)** - Iconos en escritorio
3. **Ubuntu Dock** - Dock lateral
4. **User Themes** - Soporte para temas personalizados (si instalado)

### Configuraciones Aplicadas

**Tema de iconos:**
- Elementary Icon Theme

**Tema GTK:**
- Adwaita-dark (aplicaciones legacy)
- Color scheme: prefer-dark

**Tipografías:**
- Interfaz: Ubuntu 11
- Documentos: Ubuntu 11
- Títulos: Ubuntu Bold 11
- Monospace: JetBrainsMono Nerd Font 10

**Organización App Grid:**
- Carpeta "Utilidades" → Calculadora, Terminal, etc.
- Carpeta "Sistema" → Settings, Tweaks, Monitor, etc.

Ver [GNOME-App-Folders.md](GNOME-App-Folders.md)

**Apps ancladas:**
- Google Chrome (si instalado)
- Nautilus (Archivos)

---

## Modo Oscuro

### Temas Instalados

El sistema incluye **gnome-themes-extra** que proporciona:

- **Adwaita** - Tema claro predeterminado de GNOME
- **Adwaita-dark** - Tema oscuro de GNOME
- **HighContrast** - Alto contraste claro
- **HighContrastInverse** - Alto contraste oscuro

### Aplicaciones Modernas vs Legacy

**Aplicaciones modernas (libadwaita):**
- Respetan automáticamente el modo oscuro del sistema
- Ejemplos: GNOME Settings, Nautilus (Files), GNOME Terminal
- No necesitan configuración de tema GTK

**Aplicaciones legacy (GTK3):**
- NO respetan automáticamente el modo oscuro
- Necesitan tema GTK explícito: `Adwaita-dark`
- Ejemplos: algunas apps de terceros, apps antiguas

### Configuración Automática

El instalador configura automáticamente:

```bash
# Tema GTK para apps legacy
gtk-theme = 'Adwaita-dark'

# Preferencia de color del sistema
color-scheme = 'prefer-dark'
```

**Resultado:**
- Apps modernas: Modo oscuro ✓
- Apps legacy: Modo oscuro ✓
- Consistencia visual completa

### Cambiar a Modo Claro

Si prefieres modo claro:

```bash
# Tema claro
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'

# Preferencia de color claro
gsettings set org.gnome.desktop.interface color-scheme 'default'
```

### Modo Automático (día/noche)

GNOME 42+ soporta cambio automático:

```bash
# Instalar extensión Night Theme Switcher
# O usar GNOME Tweaks → Appearance

# Programar cambio automático según hora del día
```

### Verificar Tema Actual

```bash
# Ver tema GTK configurado
gsettings get org.gnome.desktop.interface gtk-theme

# Ver esquema de color
gsettings get org.gnome.desktop.interface color-scheme
```

---

## Configuración de Red Avanzada

### nm-connection-editor

Herramienta gráfica para configuración avanzada de NetworkManager.

**Abrir:**
```bash
nm-connection-editor
```

O desde GNOME Settings → Network → ⚙️ (icono engranaje)

**Funcionalidades:**

#### WiFi Avanzado
- Configurar IP estática
- DNS personalizados
- Rutas estáticas
- 802.1x (autenticación empresarial)
- IPv6 avanzado

#### Ethernet
- Bonding (agregación de enlaces)
- Bridge (puente de red)
- VLAN (redes virtuales)
- Clonación de MAC

#### VPN
- OpenVPN
- WireGuard
- PPTP
- L2TP/IPSec

#### Configuración Avanzada

**IP Estática:**
```
Editar conexión → IPv4 Settings
Método: Manual
Addresses:
  Address: 192.168.1.100
  Netmask: 24
  Gateway: 192.168.1.1
DNS servers: 8.8.8.8, 1.1.1.1
```

**DNS Personalizado:**
```
IPv4 Settings → DNS servers
Ejemplo: 1.1.1.1, 1.0.0.1
```

**MTU Personalizado:**
```
Ethernet → General → MTU
Ejemplo: 1492 (para PPPoE)
```

---

## Optimizaciones Opcionales

### Optimización de Memoria

**Módulo:** `10-optimize.sh`

**Qué hace:**
- Deshabilita Tracker (indexación de archivos)
- Deshabilita Evolution Data Server (calendario/contactos)
- Libera ~200-400MB de RAM

**Servicios deshabilitados:**
- tracker-miner-fs
- tracker-extract
- evolution-source-registry
- evolution-addressbook-factory
- evolution-calendar-factory

Ver [GNOME-Memory.md](GNOME-Memory.md)

### Tema Transparente (OPCIONAL)

**Módulo:** `10-theme.sh`

**Estado:** Totalmente opcional - OFF por defecto

**Recomendación:** NO activar - Adwaita por defecto es excelente

**Si decides activarlo:**
- Instala extensión User Themes
- Crea tema Adwaita-Transparent
- Aplica transparencias sutiles

**Transparencias solo en:**
- Quick Settings (panel superior derecho)
- Calendar (al hacer clic en fecha/hora)
- El resto del sistema permanece igual

**Activar:**
```bash
# En modo interactivo
¿Aplicar tema transparente? (s/n) [n]: s

# En config.env
GNOME_TRANSPARENT_THEME="true"
```

Ver [GNOME-Transparency.md](GNOME-Transparency.md)

---

## Extensiones

### Extensiones Incluidas

**Por defecto en Ubuntu:**
1. **ubuntu-dock@ubuntu.com**
   - Dock lateral estilo macOS
   - Configurable con Tweaks

2. **ding@rastersoft.com**
   - Iconos en el escritorio
   - Carpetas Home, Papelera

3. **appindicatorsupport@rgcjonas.gmail.com**
   - Iconos de bandeja del sistema
   - Necesario para apps como Steam, Discord

**Opcional (si instala tema):**
4. **user-theme@gnome-shell-extensions.gcampax.github.com**
   - Permite temas personalizados de Shell

### Gestor de Extensiones

```bash
# Desde aplicaciones
Extension Manager

# O desde terminal
gnome-extensions list
gnome-extensions enable nombre-extension
gnome-extensions disable nombre-extension
```

Ver [GNOME-Extensions.md](GNOME-Extensions.md)

---

## Configuración Manual

### GNOME Tweaks

Herramienta para ajustes que no están en Settings.

**Abrir:**
```bash
gnome-tweaks
```

**Opciones importantes:**

**Apariencia:**
- Tema de aplicaciones
- Tema de cursor
- Tema de iconos
- Fuentes

**Barra superior:**
- Mostrar fecha
- Mostrar segundos
- Mostrar número de semana
- Mostrar batería en porcentaje

**Extensiones:**
- Habilitar/deshabilitar extensiones
- Configurar extensiones

**Ventanas:**
- Comportamiento de maximizar
- Botones de titlebar
- Focus mode

**Teclado y ratón:**
- Velocidad de repetición
- Aceleración del ratón
- Touchpad

### gsettings (línea de comandos)

**Ver configuración:**
```bash
gsettings list-recursively org.gnome.desktop.interface
```

**Cambiar configuración:**
```bash
# Tema de iconos
gsettings set org.gnome.desktop.interface icon-theme 'elementary'

# Fuente del sistema
gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11'

# Apps favoritas (dock)
gsettings set org.gnome.shell favorite-apps "['nautilus.desktop', 'org.gnome.Terminal.desktop']"

# Transparencia del dock
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15
```

### dconf-editor

Editor gráfico completo de configuración.

**Instalar:**
```bash
sudo apt install dconf-editor
```

**Usar:**
```bash
dconf-editor
```

⚠️ **Cuidado:** Cambios incorrectos pueden romper GNOME

---

## Atajos de Teclado

### Predeterminados

**Sistema:**
- `Super` - Abrir Activities/Búsqueda
- `Super + A` - Mostrar aplicaciones
- `Super + L` - Bloquear pantalla
- `Alt + F2` - Ejecutar comando
- `Ctrl + Alt + T` - Abrir terminal

**Ventanas:**
- `Super + ↑` - Maximizar ventana
- `Super + ↓` - Restaurar ventana
- `Super + ←/→` - Anclar ventana izquierda/derecha
- `Alt + Tab` - Cambiar entre ventanas
- `Alt + F4` - Cerrar ventana
- `Super + H` - Ocultar ventana

**Workspaces:**
- `Super + PgUp/PgDn` - Cambiar workspace
- `Shift + Super + PgUp/PgDn` - Mover ventana a workspace

### Personalizar

Settings → Keyboard → View and Customize Shortcuts

---

## Troubleshooting

### Extensiones no funcionan

```bash
# Ver errores
journalctl -f

# Reiniciar GNOME Shell (solo X11)
killall -SIGQUIT gnome-shell

# En Wayland: cerrar sesión
```

### Tema no se aplica

```bash
# Verificar extensión user-theme
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

# Verificar que tema existe
ls ~/.themes/Adwaita-Transparent/

# Aplicar manualmente
gsettings set org.gnome.shell.extensions.user-theme name 'Adwaita-Transparent'
```

### Panel superior congelado

```bash
# Reiniciar GNOME Shell (X11)
killall -SIGQUIT gnome-shell

# Wayland: cerrar sesión
```

### Alto uso de CPU

```bash
# Ver procesos GNOME
ps aux | grep gnome

# Problemas comunes:
# - tracker-miner-fs → Ver optimizaciones
# - gvfs-udisks2-volume-monitor → Normal
```

### NetworkManager no guarda configuración

```bash
# Permisos
sudo chown -R root:root /etc/NetworkManager/
sudo chmod 755 /etc/NetworkManager/

# Reiniciar servicio
sudo systemctl restart NetworkManager
```

Ver [03-Troubleshooting.md](03-Troubleshooting.md) para más problemas.

---

## Recursos

### Documentación Oficial
- [GNOME Help](https://help.gnome.org/)
- [GNOME Shell Extensions](https://extensions.gnome.org/)
- [NetworkManager Documentation](https://networkmanager.dev/)

### Guías Relacionadas
- [App Folders](GNOME-App-Folders.md) - Organización del app grid
- [Extensions](GNOME-Extensions.md) - Gestión de extensiones
- [Memory](GNOME-Memory.md) - Optimización de RAM
- [Transparency](GNOME-Transparency.md) - Tema transparente

---

**Siguiente:** [Configuración](02-Configuration.md) | [Troubleshooting](03-Troubleshooting.md)
