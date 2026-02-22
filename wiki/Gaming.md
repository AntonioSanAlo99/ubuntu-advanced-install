# Gaming en Ubuntu

## 🎮 Filosofía

**Instalación limpia**: Software instalado, sistema optimizado, **sin configuraciones impuestas**.

El usuario configura según sus necesidades y hardware.

---

## ✅ Qué se Instala

### Herramientas Core

```bash
gamemode       # Optimizaciones rendimiento (daemon)
mangohud       # Overlay métricas (FPS, temp, RAM)
goverlay       # GUI para configurar MangoHud
```

### Launchers

```bash
steam          # Steam oficial (.deb)
lutris         # Múltiples plataformas
heroic         # Epic Games + GOG (.deb desde GitHub)
faugus         # Wine/Proton wrapper (.deb desde GitHub)
```

### Wine & Proton

```bash
wine-stable       # Wine oficial
umu-launcher      # Unified launcher para Proton
proton-cachyos    # Proton optimizado
```

### Drivers

```bash
# NVIDIA
nvidia-driver-xxx  # Auto-detectado con ubuntu-drivers

# AMD
# AMDGPU incluido en kernel (no necesita instalación)
```

---

## 🔧 Optimizaciones de Sistema

### Kernel Parameters

```bash
# /etc/sysctl.d/99-gaming.conf
vm.max_map_count = 2147483642  # NECESARIO para juegos modernos
fs.file-max = 524288           # Previene "too many files"
```

**Por qué**: Sin `vm.max_map_count`, muchos juegos modernos no arrancan.

### Limits

```bash
# /etc/security/limits.conf
* hard nofile 524288
* soft nofile 524288
```

**Por qué**: Previene errores de límite de archivos.

### Udev Rules

```bash
# /etc/udev/rules.d/99-gaming-controllers.rules
# Permisos para controladores (sin sudo)
```

**Soporta**:
- Steam Controller
- PlayStation 4/5 (DualShock 4, DualSense)
- Xbox One/Series
- Nintendo Switch Pro Controller
- 8BitDo
- Logitech

---

## ❌ Qué NO se Configura

### Variables de Entorno

El instalador **NO configura** variables de entorno automáticamente.

**Razones**:
1. Hardware específico (AMD vs NVIDIA)
2. Preferencias personales
3. Configuraciones experimentales
4. Control del usuario

**Usuario configura** según necesidad.

---

## 🎯 Configuración Post-Instalación

### GameMode

#### Uso Automático

GameMode funciona **sin configuración**:

```bash
# Steam
# Detecta gamemode automáticamente - no hacer nada

# Lutris
Settings → System Options → Enable Feral GameMode ✓

# Heroic
Settings → Other → Enable GameMode ✓
```

#### Uso Manual

```bash
# Lanzar juego con gamemode
gamemoderun ./mi-juego

# Verificar que está activo
gamemoded -s
# Output: gamemode is active
```

#### NO Usar LD_PRELOAD

```bash
# ✗ NO HACER ESTO (causa errores ld.so)
export LD_PRELOAD=/usr/$LIB/libgamemode.so.0

# ✓ USAR ESTO
gamemoderun ./juego
```

---

### MangoHud

#### Opción 1: GUI (Recomendado)

```bash
goverlay
```

Interfaz gráfica para configurar:
- Qué métricas mostrar
- Posición en pantalla
- Colores, fuentes
- Configuraciones por juego

#### Opción 2: Archivo de Configuración

```bash
mkdir -p ~/.config/MangoHud
nano ~/.config/MangoHud/MangoHud.conf
```

**Configuración básica**:
```
fps
cpu_temp
gpu_temp
ram
vram
```

**Configuración avanzada**:
```
fps
fps_limit=144
cpu_temp
cpu_power
gpu_temp
gpu_power
ram
vram
frame_timing=1
position=top-left
background_alpha=0.5
```

#### Opción 3: Por Juego (Steam)

```
# Steam → Game Properties → Launch Options
MANGOHUD=1 %command%
```

#### Opción 4: Variable Global

```bash
# ~/.bashrc (activa para todos los juegos)
export MANGOHUD=1
```

#### Desactivar MangoHud

```bash
# Si está en ~/.bashrc, comentar:
# export MANGOHUD=1

# O por juego en Steam:
# (eliminar MANGOHUD=1 de launch options)
```

---

### Variables AMD (Solo Usuarios AMD)

```bash
# ~/.bashrc
export RADV_PERFTEST=aco        # ACO compiler (mejor rendimiento)
export AMD_VULKAN_ICD=RADV      # Usar driver RADV
```

**Aplicar**:
```bash
source ~/.bashrc
```

**Usuarios NVIDIA**: No necesitan estas variables.

---

### Wine/Proton Optimizaciones

#### Esync/Fsync

```bash
# ~/.bashrc
export WINEFSYNC=1    # Fsync (mejor que esync)
export WINEESYNC=1    # Esync (fallback)
```

#### DXVK

```bash
# ~/.bashrc
export DXVK_ASYNC=1                              # Async shader compilation (experimental)
export DXVK_STATE_CACHE_PATH=$HOME/.cache/dxvk   # Cache shaders
```

**Nota**: `DXVK_ASYNC=1` es experimental y puede causar crashes en algunos juegos.

#### VKD3D

```bash
# ~/.bashrc
export VKD3D_SHADER_CACHE_PATH=$HOME/.cache/vkd3d
```

---

## 🎮 Uso de Launchers

### Steam

```bash
# Instalar juegos
# Steam → Library → Install

# GameMode
# Detectado automáticamente - no hacer nada

# MangoHud
# Game Properties → Launch Options:
MANGOHUD=1 %command%

# Proton (juegos Windows)
# Game Properties → Compatibility → Enable Steam Play
# Seleccionar versión Proton
```

### Lutris

```bash
# Añadir juego
Lutris → + → Search for game / Add locally

# GameMode
Game → Configure → System Options → Enable Feral GameMode ✓

# MangoHud
Game → Configure → System Options → Enable MangoHud ✓

# Variables de entorno
Game → Configure → System Options → Environment variables
DXVK_ASYNC=1
```

### Heroic

```bash
# Epic Games / GOG login
Settings → Log in

# GameMode
Settings → Other → Enable GameMode ✓

# Wine version
Game → Settings → Wine Version → (select)
```

### Faugus Launcher

```bash
faugus-launcher

# Interfaz simple para ejecutar .exe con Wine/Proton
# Detecta Proton de Steam automáticamente
```

---

## 🔧 Troubleshooting

### GameMode No Funciona

```bash
# Verificar servicio
systemctl status gamemoded
# Debe estar: active (running)

# Si no está activo
systemctl enable --now gamemoded

# Verificar manualmente
gamemoderun glxgears &
gamemoded -s
# Debe decir: gamemode is active
```

### MangoHud No Aparece

```bash
# Verificar instalación
which mangohud
# Debe mostrar: /usr/bin/mangohud

# Probar manualmente
mangohud glxgears

# Si no funciona, reinstalar
sudo apt install --reinstall mangohud
```

### Errores ld.so con GameMode

```bash
# Si ves:
# ERROR: ld.so: object '/usr/$LIB/libgamemode.so.0'...

# Causa: Versión antigua configuró LD_PRELOAD
# Buscar configuración incorrecta:
grep -r "LD_PRELOAD.*gamemode" /etc/profile.d/ ~/.bashrc ~/.profile

# Eliminar líneas encontradas
sudo nano /etc/profile.d/99-gaming-env.sh
# (eliminar línea LD_PRELOAD)

# Reiniciar sesión
```

### Juego No Detecta Gamepad

```bash
# Verificar udev rules
ls /etc/udev/rules.d/99-gaming-controllers.rules

# Recargar udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Verificar detección
jstest /dev/input/js0
```

### Proton No Funciona

```bash
# Verificar umu-launcher
which umu-run

# Verificar Proton instalado
ls ~/.local/share/Steam/compatibilitytools.d/

# Si no hay Proton, instalar desde Steam
Steam → Settings → Compatibility → Enable Steam Play for all titles
```

---

## 📊 Comparación: Antes vs Ahora

### Versiones Antiguas (≤v3.7.x)

```bash
# Configuraciones automáticas impuestas:
export MANGOHUD=1                    # Forzado para todos
export MANGOHUD_CONFIG=fps,cpu...    # Configuración fija
export RADV_PERFTEST=aco             # Solo AMD (inútil en NVIDIA)
export DXVK_ASYNC=1                  # Experimental
export LD_PRELOAD=.../libgamemode... # Causaba errores ld.so
```

**Problemas**:
- Usuario NVIDIA tenía variables AMD
- MangoHud forzado siempre
- Errores ld.so persistentes
- Sin control del usuario

### Versión Actual (v3.8.0+)

```bash
# Sin variables de entorno automáticas
# Usuario configura según necesidad
```

**Ventajas**:
- ✓ Control total del usuario
- ✓ Sin configuraciones innecesarias
- ✓ Sin errores ld.so
- ✓ Configuración por juego
- ✓ Fácil de debuggear

---

## 📋 Checklist Post-Instalación

### Verificaciones

- [ ] GameMode servicio activo: `systemctl status gamemoded`
- [ ] Controlador detectado: `jstest /dev/input/js0`
- [ ] MangoHud instalado: `which mangohud`
- [ ] Steam lanza: `steam`

### Configuraciones (Opcionales)

- [ ] MangoHud: `goverlay` o crear `~/.config/MangoHud/MangoHud.conf`
- [ ] Variables AMD (solo AMD): Añadir a `~/.bashrc`
- [ ] Wine/Proton vars: Añadir a `~/.bashrc` si usas Wine

### Recomendaciones

- [ ] Steam → Settings → Enable Steam Play for all titles
- [ ] Lutris → Configure runners
- [ ] Probar gamemode: `gamemoderun glxgears`

---

## 🎯 Recursos

### Documentación Oficial

- [GameMode](https://github.com/FeralInteractive/gamemode)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [Lutris](https://lutris.net/)
- [Proton](https://github.com/ValveSoftware/Proton)

### Comunidad

- [ProtonDB](https://www.protondb.com/) - Compatibilidad juegos
- [r/linux_gaming](https://www.reddit.com/r/linux_gaming/)

---

**Gaming en Linux**: Herramientas instaladas, configuración en manos del usuario.
