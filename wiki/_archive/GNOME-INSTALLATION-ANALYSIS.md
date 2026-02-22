# ANÁLISIS COMPLETO: INSTALACIÓN DE GNOME

## Estructura de Módulos

```
┌─────────────────────────────────────────────────────────────┐
│ MÓDULO 10: install-gnome.sh (323 líneas)                   │
│ ├─ Core de GNOME (Shell, Session, Settings)                │
│ ├─ Aplicaciones esenciales                                 │
│ ├─ Extensiones (3 principales)                             │
│ ├─ Eliminar snapd                                          │
│ ├─ systemd-oomd (protección OOM)                           │
│ └─ Configuración GDM                                       │
├─────────────────────────────────────────────────────────────┤
│ MÓDULO 10b: optimize-gnome-memory.sh (219 líneas)          │
│ ├─ Prompt interactivo (s/n)                                │
│ ├─ Deshabilitar Tracker (indexación)                       │
│ ├─ Deshabilitar animaciones                                │
│ ├─ Deshabilitar Evolution Data Server                      │
│ └─ Deshabilitar gnome-software                             │
├─────────────────────────────────────────────────────────────┤
│ MÓDULO 10c: gnome-transparency.sh (187 líneas)             │
│ ├─ Instalar extensión User Themes                          │
│ ├─ Crear tema Adwaita-Transparent en ~/.themes             │
│ ├─ Script de activación (extensiones + tema + fuentes)     │
│ └─ Apps ancladas (Chrome + Nautilus)                       │
└─────────────────────────────────────────────────────────────┘
```

## MÓDULO 10: install-gnome.sh

### Resumen
Instalación modular de GNOME **sin metapaquetes** para control total.

### Paquetes Instalados

#### Core GNOME (11 paquetes)
```bash
gnome-shell                    # Shell de GNOME
gnome-session                  # Gestor de sesión
gnome-settings-daemon          # Daemon de configuración
gnome-control-center           # Configuración del sistema
gnome-terminal                 # Terminal
nautilus                       # Gestor de archivos
nautilus-admin                 # Nautilus con permisos admin
xdg-terminal-exec              # Terminal por defecto
gdm3                          # Display manager
plymouth                       # Splash screen
bolt                          # Thunderbolt manager
```

#### Utilidades GNOME (13 paquetes)
```bash
gnome-keyring                  # Llavero de contraseñas
gnome-calculator               # Calculadora
gnome-logs                     # Visor de logs
gnome-font-viewer              # Visor de fuentes
baobab                        # Analizador de disco
lxtask                        # Gestor de tareas (ligero)
file-roller                   # Compresor de archivos
gedit                         # Editor de texto
evince                        # Visor de PDF
viewnior                      # Visor de imágenes (ligero)
gnome-disk-utility            # Utilidad de discos
gnome-tweaks                  # Personalizaciones avanzadas
gnome-shell-extension-manager # Gestor de extensiones
```

#### Gestión de Software (4 paquetes)
```bash
software-properties-gtk        # Gestión de repositorios
gdebi                         # Instalador .deb
update-notifier               # Notificador de actualizaciones
update-manager                # Gestor de actualizaciones
```

#### Extensiones (3)
```bash
gnome-shell-extension-appindicator        # Iconos de bandeja
gnome-shell-extension-desktop-icons-ng    # Iconos en escritorio (DING)
gnome-shell-extension-ubuntu-dock         # Dock de Ubuntu
```

#### Tema
```bash
elementary-icon-theme          # Tema de iconos Elementary
```

### Configuraciones Aplicadas

1. **Snap eliminado completamente**
   - `apt purge snapd gnome-software-plugin-snap`
   - Bloqueado en `/etc/apt/preferences.d/99-no-snap`

2. **systemd-oomd habilitado**
   - Previene que el sistema se cuelgue por falta de RAM
   - Mata procesos antes de que sea crítico

3. **GDM habilitado**
   - `systemctl enable gdm3`
   - Opción de autologin disponible

4. **Tema de iconos**
   - Elementary como predeterminado

### Scripts NO creados en módulo 10
- ❌ No configura extensiones (se hace en 10c)
- ❌ No configura fuentes (se hace en 10c)
- ❌ No configura tema shell (se hace en 10c)

---

## MÓDULO 10b: optimize-gnome-memory.sh

### Resumen
Módulo **interactivo** de optimización de memoria. Se ejecuta solo si el usuario lo solicita desde módulo 10.

### Prompts Interactivos (3)

#### 1. Deshabilitar Tracker (indexación de archivos)
```
¿Deshabilitar Tracker? (s/n) [s]
```
**Ahorro:** ~100-200MB RAM
**Efecto:** Búsquedas más lentas en Archivos

**Método:**
```bash
# /etc/xdg/autostart/tracker-miner-fs-3.desktop
Hidden=true
```

#### 2. Deshabilitar animaciones
```
¿Deshabilitar animaciones? (s/n) [n]
```
**Ahorro:** ~30-50MB RAM + CPU
**Efecto:** Interfaz menos fluida

**Método:**
```bash
gsettings set org.gnome.desktop.interface enable-animations false
```

#### 3. Deshabilitar Evolution Data Server
```
¿Deshabilitar Evolution Data Server? (s/n) [s]
```
**Ahorro:** ~50-100MB RAM
**Efecto:** Sin sincronización de calendario/contactos

**Método:**
```bash
# /etc/xdg/autostart/evolution-data-server.desktop
Hidden=true
```

### Siempre Deshabilitado (sin prompt)

```bash
gnome-software              # Centro de software (reemplazado por update-manager)
```
**Ahorro:** ~80-150MB RAM
**Método:** `systemctl mask gnome-software`

### Ahorro Total Estimado
```
Mínimo (solo gnome-software): ~80-150MB
Máximo (todo):               ~260-500MB

RAM idle:
- Sin optimizar: 1.2-1.5GB
- Optimizado:    600-800MB (~50% reducción)
```

---

## MÓDULO 10c: gnome-transparency.sh

### Resumen
Configuración unificada de: tema transparente, extensiones, fuentes, y apps ancladas.

### Estructura

```bash
┌─────────────────────────────────────────────────────────────┐
│ /etc/profile.d/03-gnome-config.sh                           │
│ (se ejecuta en el PRIMER LOGIN del usuario)                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Tema de iconos: elementary                               │
│ 2. Tipografías del sistema                                  │
│ 3. Extensiones (habilitar 4)                                │
│ 4. Tema shell: Adwaita-Transparent                          │
│ 5. Apps ancladas: Chrome + Nautilus                         │
└─────────────────────────────────────────────────────────────┘
```

### 1. Extensión User Themes

**Paquete:** `gnome-shell-extension-user-theme`
**Necesaria para:** Aplicar tema personalizado de `~/.themes`

### 2. Tema Adwaita-Transparent

**Ubicación:** `~/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css`

**Contenido:**
```css
/* Importa Adwaita base */
@import url("resource:///org/gnome/shell/theme/gnome-shell.css");

/* Solo 2 transparencias */
.quick-settings { background-color: rgba(0, 0, 0, 0.15) !important; }
.calendar { background-color: rgba(0, 0, 0, 0.15) !important; }
```

**Filosofía:** Vanilla Adwaita con transparencias mínimas en:
- Quick Settings (WiFi, Bluetooth, etc.)
- Calendar/Notificaciones

### 3. Tipografías Configuradas

```bash
# Interfaz
gsettings set org.gnome.desktop.interface font-name 'Ubuntu 11'

# Documentos
gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 11'

# Títulos
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 11'

# Monospace
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 10'
```

### 4. Extensiones Habilitadas (4)

```bash
1. user-theme@gnome-shell-extensions        # Para tema personalizado
2. appindicatorsupport@rgcjonas.gmail.com   # Iconos de bandeja
3. ding@rastersoft.com                      # Iconos en escritorio
4. ubuntu-dock@ubuntu.com                   # Dock lateral (transparencia 15%)
```

**Método de activación:**
- Dual: `gnome-extensions enable` + D-Bus fallback
- Robusto: Verifica que extensión existe antes de activar

### 5. Apps Ancladas

```bash
gsettings set org.gnome.shell favorite-apps "['google-chrome.desktop', 'org.gnome.Nautilus.desktop']"
```

**Solo 2 apps:**
1. Google Chrome
2. Nautilus

### 6. Script de Primer Login

**Archivo:** `/etc/profile.d/03-gnome-config.sh`

**Marker:** `~/.config/.gnome-configured`

**Comportamiento:**
- Se ejecuta UNA VEZ en el primer login
- Espera 2 segundos (GNOME Shell listo)
- Configura todo
- Crea marker para no repetir
- Reinicia Shell (solo X11)

---

## FLUJO DE INSTALACIÓN COMPLETO

```
┌─────────────────────────────────────────────────────────────┐
│ 1. DEBOOTSTRAP (sistema base)                               │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. MÓDULO 03 (locales, teclado, usuario)                    │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. MÓDULO 10 (GNOME core + apps + extensiones)              │
│    ├─ Instala 31 paquetes core                              │
│    ├─ Elimina snapd                                         │
│    ├─ Instala systemd-oomd                                  │
│    └─ Habilita GDM                                          │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
                  [Prompt Usuario]
                       ↓
        ┌──────────────┴──────────────┐
        │ ¿Optimizar memoria?         │
        └──────────┬─────────┬────────┘
                   │         │
              [No] │         │ [Sí]
                   │         ↓
                   │  ┌─────────────────────────────────────┐
                   │  │ 4a. MÓDULO 10b (memoria)            │
                   │  │     ├─ Tracker? [s]                 │
                   │  │     ├─ Animaciones? [n]             │
                   │  │     ├─ Evolution DS? [s]            │
                   │  │     └─ gnome-software (siempre off) │
                   │  └──────────────┬──────────────────────┘
                   │                 │
                   └─────────────────┘
                           ↓
                  [Prompt Usuario]
                           ↓
        ┌──────────────────┴──────────────────┐
        │ ¿Aplicar transparencias?            │
        └──────────┬─────────┬────────────────┘
                   │         │
              [No] │         │ [Sí]
                   │         ↓
                   │  ┌─────────────────────────────────────┐
                   │  │ 4b. MÓDULO 10c (tema + config)      │
                   │  │     ├─ Instala User Themes          │
                   │  │     ├─ Crea tema ~/.themes          │
                   │  │     └─ Script primer login          │
                   │  └──────────────┬──────────────────────┘
                   │                 │
                   └─────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Resto de módulos (multimedia, fuentes, etc.)             │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. PRIMER BOOT + LOGIN                                      │
│    ↓                                                         │
│    /etc/profile.d/03-gnome-config.sh se ejecuta             │
│    ├─ Aplica tema iconos                                    │
│    ├─ Configura fuentes                                     │
│    ├─ Habilita extensiones                                  │
│    ├─ Aplica tema shell                                     │
│    ├─ Ancla apps                                            │
│    └─ Crea marker                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## CONFIGURACIONES QUE SE APLICAN

### En Instalación (chroot)
1. ✅ Instalar paquetes
2. ✅ Eliminar snapd
3. ✅ Habilitar systemd-oomd
4. ✅ Habilitar GDM
5. ✅ Crear tema en `/etc/skel/.themes/`
6. ✅ Crear script en `/etc/profile.d/`
7. ✅ Deshabilitar servicios (10b)

### En Primer Login (usuario)
1. ✅ Tema de iconos
2. ✅ Fuentes del sistema
3. ✅ Habilitar extensiones
4. ✅ Aplicar tema shell
5. ✅ Configurar Dock transparente
6. ✅ Anclar apps
7. ✅ Crear marker

---

## RESUMEN EJECUTIVO

### Paquetes Totales
- **Core:** 11
- **Utilidades:** 13
- **Software:** 4
- **Extensiones:** 3 + 1 (User Themes en 10c)
- **Tema:** 1
- **Total:** ~33 paquetes

### Memoria
- **Sin optimizar:** 1.2-1.5GB idle
- **Optimizado:** 600-800MB idle
- **Ahorro:** ~50%

### Archivos Creados
```
/etc/apt/preferences.d/99-no-snap
/etc/skel/.themes/Adwaita-Transparent/gnome-shell/gnome-shell.css
/etc/profile.d/03-gnome-config.sh
/etc/xdg/autostart/tracker-miner-fs-3.desktop (si 10b)
/etc/xdg/autostart/evolution-data-server.desktop (si 10b)
```

### Scripts que se Ejecutan
1. **Instalación:** Módulos 10, 10b (opt), 10c (opt)
2. **Primer login:** `/etc/profile.d/03-gnome-config.sh`

### Interacciones con Usuario
1. ¿Optimizar memoria? (módulo 10 llama a 10b)
2. ¿Aplicar transparencias? (módulo 10 llama a 10c)
3. Dentro de 10b: 3 prompts (Tracker, animaciones, Evolution DS)

---

## VENTAJAS DEL DISEÑO

✅ **Modular:** Cada módulo hace una cosa
✅ **Sin metapaquetes:** Control total de lo instalado
✅ **Interactivo:** Usuario decide optimizaciones
✅ **Limpio:** Sin configuraciones superpuestas
✅ **Primer login:** Configuración se aplica al usuario real
✅ **Marker:** No se repite la configuración
✅ **Robusto:** Verifica que extensiones existan
✅ **Vanilla:** Tema basado en Adwaita, mínimas modificaciones

---

## POSIBLES MEJORAS

⚠️ **Script único vs múltiple:**
- Actualmente: `/etc/profile.d/03-gnome-config.sh` hace todo
- Alternativa: Separar en `01-theme.sh`, `02-extensions.sh`, `03-fonts.sh`

⚠️ **Marker global vs por función:**
- Actualmente: Un marker para todo
- Alternativa: Markers separados permiten reconfigurar partes

⚠️ **Orden de ejecución:**
- Extensiones antes que tema (tema necesita User Themes)
- Fuentes se configuran aunque el módulo 13 aún no se haya ejecutado

⚠️ **Fallback si extensión no existe:**
- Actualmente: Verifica y salta si no existe
- Alternativa: Podría intentar instalarla desde extensions.gnome.org
