# Gaming en Ubuntu

Documentación completa de la configuración de gaming con gestión unificada de Proton.

---

## Qué se Instala

### Launchers (.deb)

**Todos instalados desde paquetes .deb:**

1. **Steam** - Oficial de Valve
   - Descarga: https://store.steampowered.com
   - Formato: .deb oficial
   - Integración nativa con Ubuntu

2. **Faugus Launcher** - Launcher universal simple
   - Repositorio: https://github.com/Faugus/faugus-launcher
   - Formato: .deb desde GitHub
   - Soporta: Epic, GOG, Amazon Prime, itch.io, juegos standalone

3. **Heroic Games Launcher** - Epic + GOG
   - Descarga: GitHub releases
   - Formato: .deb desde GitHub
   - Soporta: Epic Games Store, GOG, Amazon Prime Gaming

### Herramientas

4. **ProtonUp-Qt** - Gestor gráfico de Proton
   - Repositorio: https://github.com/DavidoTek/ProtonUp-Qt
   - Formato: .deb desde GitHub
   - Función: Instalar/actualizar versiones de Proton fácilmente
   - **Soporta Proton-Cachyos**

5. **umu-launcher** - Unificador de Proton
   - Instalación: pip
   - Función: Gestiona Proton de forma unificada
   - Integración: Todos los launchers

6. **Proton-Cachyos** - Proton optimizado
   - Repositorio: https://github.com/CachyOS/proton-cachyos
   - Optimizaciones: Cachyos patches
   - Rendimiento: Mejoras sobre Proton-GE
   - **Actualizable con ProtonUp-Qt**

7. **GameMode** - Optimizaciones en tiempo real
8. **MangoHud** - Overlay de FPS y estadísticas
9. **Goverlay** - Configurador gráfico de MangoHud

---

## ProtonUp-Qt

### Qué es

**Gestor gráfico** para instalar y actualizar versiones de Proton/Wine.

**Ventajas:**
- ✅ Interfaz gráfica simple
- ✅ Detecta automáticamente Steam/Heroic/Faugus
- ✅ Descarga automática de nuevas versiones
- ✅ **Soporta Proton-Cachyos oficialmente**
- ✅ También GE-Proton, Wine-GE, Luxtorpeda

### Uso

**Abrir:**
```bash
protonup-qt
```

O desde el menú de aplicaciones: "ProtonUp-Qt"

### Instalar/Actualizar Proton-Cachyos

1. **Abrir ProtonUp-Qt**
2. **Seleccionar launcher:** Steam (o Heroic/Faugus)
3. **Add version:**
   - Compatibility tool: **Proton-Cachyos**
   - Version: Latest
4. **Install**

**Resultado:** Proton-Cachyos actualizado y disponible en todos los launchers

### Instalar GE-Proton

Mismo proceso:
1. Compatibility tool: **GE-Proton**
2. Version: Latest
3. Install

### Configuración

**Settings en ProtonUp-Qt:**
- Install directory: Detectado automáticamente
  - Steam: `~/.local/share/Steam/compatibilitytools.d`
  - Heroic: `~/.config/heroic/tools/proton`
  - Faugus: `~/.local/share/faugus-launcher`

---

## Estructura Compartida de Proton

### Ubicación Unificada

**Directorio principal (estándar de Steam):**
```
~/.local/share/Steam/compatibilitytools.d/
├── Proton-Cachyos-8.25/     # Instalado con ProtonUp-Qt
├── GE-Proton8-32/           # Si instalas GE-Proton
└── Wine-GE-Proton8-26/      # Wine-GE
```

### Cómo Funciona

Todos los launchers apuntan a la ubicación de Steam:

```
Steam
  ~/.local/share/Steam/compatibilitytools.d/
  (ubicación nativa)

Faugus Launcher
  ~/.local/share/faugus-launcher/compatibilitytools.d → Steam/compatibilitytools.d/

Heroic
  ~/.config/heroic/tools/proton/Steam → Steam/compatibilitytools.d/

umu-launcher
  Configurado: ~/.local/share/Steam/compatibilitytools.d/
```

**Ventaja:** 
- ProtonUp-Qt instala en Steam
- Automáticamente disponible en Faugus y Heroic
- Una sola ubicación para gestionar

### umu-launcher

**Qué es:** Herramienta que unifica la gestión de Proton

**Configuración:**
```bash
# ~/.config/umu/umu.conf
[umu]
proton_dir = ~/.local/share/Steam/compatibilitytools.d
cache_dir = ~/.cache/umu
```

**Uso:**
```bash
# Ejecutar juego con umu
umu-run game.exe

# Especificar versión de Proton
UMU_PROTON=Proton-Cachyos-8.25 umu-run game.exe
```

---

## Faugus Launcher

### Qué es

Launcher minimalista y rápido para juegos de múltiples tiendas.

**Soporta:**
- Epic Games Store
- GOG
- Amazon Prime Gaming
- itch.io
- Juegos standalone (exe/AppImage)

**Características:**
- Interfaz simple
- Bajo uso de recursos
- Configuración mínima
- Integración con Steam Proton

### Uso

1. **Abrir Faugus Launcher**
2. **Añadir juego:**
   - Epic/GOG: Conectar cuenta
   - Standalone: Add game → Seleccionar .exe

3. **Configurar Proton:**
   - Game settings → Runner
   - Seleccionar: Proton-Cachyos o GE-Proton

### Ventajas vs Lutris

| Característica | Faugus | Lutris |
|----------------|--------|--------|
| Simplicidad | ✅✅✅ | ❌ |
| Recursos | Ligero | Pesado |
| Proton compartido | ✅ | ✅ |
| Epic/GOG | ✅ | ✅ |
| Emuladores | ❌ | ✅ |
| Configuración | Simple | Compleja |

**Faugus:** Ideal para jugar rápido sin complicaciones
**Lutris:** Mejor para usuarios avanzados y emuladores

---

## Proton-Cachyos

### Actualizar con ProtonUp-Qt

**Método recomendado:**

1. Abrir ProtonUp-Qt
2. Steam → Add version
3. Proton-Cachyos → Latest
4. Install
5. ✓ Disponible en todos los launchers

### Usar en Steam

1. Biblioteca → Click derecho en juego → Properties
2. Compatibility → Force use of specific tool
3. Seleccionar: **Proton-Cachyos-8.XX**

### Usar en Faugus

1. Game → Settings
2. Runner → Wine/Proton
3. Seleccionar: **Proton-Cachyos**

### Usar en Heroic

1. Juego → Settings
2. Wine/Proton Version
3. Seleccionar: **Steam/Proton-Cachyos-8.XX**

---

## Añadir Más Versiones de Proton

### Con ProtonUp-Qt (Recomendado)

**Para cualquier versión:**
1. Abrir ProtonUp-Qt
2. Add version
3. Seleccionar tipo:
   - Proton-Cachyos
   - GE-Proton
   - Wine-GE
   - Luxtorpeda (para juegos nativos)
4. Latest → Install

**Automático** - No requiere terminal

### Manual (Avanzado)

```bash
cd ~/.local/share/Steam/compatibilitytools.d

# Descargar Proton manualmente
wget <URL-del-release.tar.gz>
tar xzf archivo.tar.gz
rm archivo.tar.gz
```

---

## GameMode

### Qué es

Optimiza el sistema automáticamente al ejecutar juegos:
- Prioridad de CPU al juego
- Deshabilita compositor (reduce latencia)
- Ajusta gobernador de CPU
- Optimiza I/O scheduler

### Uso Automático

**Steam:**
- Activado automáticamente por variable de entorno
- No requiere configuración

**Lutris:**
- System options → Enable Feral GameMode

**Heroic:**
- Settings → Use GameMode

**Manual:**
```bash
gamemoderun ./juego
```

### Verificar

```bash
# Ver si está activo
gamemoded -s

# Ver configuración
cat /etc/gamemode.ini
```

---

## MangoHud

### Qué es

Overlay que muestra:
- FPS
- Temperatura CPU/GPU
- Uso de RAM/VRAM
- Frametime

### Uso

**Steam:**
- Propiedades del juego → Launch Options:
```
mangohud %command%
```

**Faugus Launcher:**
- Settings → Game → Runner

**Heroic:**
- Settings → Environment Variables
- Add: `MANGOHUD=1`

**Manual:**
```bash
mangohud ./juego
```

### Configuración

**Goverlay (GUI):**
```bash
goverlay
```

**Manual:**
```bash
# ~/.config/MangoHud/MangoHud.conf
fps
cpu_temp
gpu_temp
ram
vram
frametime=0
position=top-right
```

### Atajos de Teclado

- `Shift + F12` - Toggle MangoHud
- `Shift + F11` - Toggle logging

---

## Optimizaciones Aplicadas

### Variables de Entorno

**Archivo:** `/etc/profile.d/99-gaming-env.sh`

```bash
# GameMode
LD_PRELOAD=/usr/$LIB/libgamemode.so.0

# MangoHud
MANGOHUD=1
MANGOHUD_CONFIG=fps,cpu_temp,gpu_temp,ram,vram

# AMD GPU
RADV_PERFTEST=aco
AMD_VULKAN_ICD=RADV

# DXVK/VKD3D
DXVK_ASYNC=1
DXVK_STATE_CACHE_PATH=$HOME/.cache/dxvk
VKD3D_SHADER_CACHE_PATH=$HOME/.cache/vkd3d

# Wine/Proton
WINEFSYNC=1
WINEESYNC=1

# umu-launcher
UMU_PROTON_DIR=$HOME/.local/share/proton-shared
```

### sysctl

**Archivo:** `/etc/sysctl.d/99-gaming.conf`

```bash
# Memory
vm.max_map_count = 2147483642  # Para juegos que usan mucha memoria
vm.swappiness = 10              # Reducir uso de swap

# Network
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
```

### Límites del Sistema

**Archivo:** `/etc/security/limits.conf`

```bash
*    soft    nofile    524288     # Archivos abiertos
*    hard    nofile    524288
*    soft    memlock   unlimited  # Memoria bloqueada
*    hard    memlock   unlimited
```

### udev Rules

Soporte automático para controladores:
- Steam Controller
- PlayStation 4/5 (DualShock/DualSense)
- Xbox One/Series
- Nintendo Switch Pro
- 8BitDo
- Logitech

---

## Solución de Problemas

### Steam no inicia

```bash
# Reinstalar Steam
sudo apt remove --purge steam steam-launcher
sudo apt autoremove
sudo apt install steam

# O descargar .deb oficial
wget https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb
sudo apt install ./steam.deb
```

### Juego no detecta controlador

```bash
# Recargar reglas udev
sudo udevadm control --reload-rules
sudo udevadm trigger

# Verificar que se detecta
lsusb
evtest
```

### Bajo rendimiento

```bash
# Verificar GameMode activo
gamemoded -s

# Verificar drivers Vulkan
vulkaninfo | grep deviceName

# Ver estadísticas con MangoHud
mangohud glxgears
```

### Proton no aparece en launcher

```bash
# Verificar symlinks
ls -la ~/.local/share/Steam/compatibilitytools.d/
ls -la ~/.local/share/proton-shared/

# Recrear symlinks si faltan
ln -sf ~/.local/share/proton-shared ~/.local/share/Steam/compatibilitytools.d/shared
```

### Error de memoria (game crash)

```bash
# Verificar vm.max_map_count
sysctl vm.max_map_count

# Debe ser: 2147483642
# Si no:
sudo sysctl -w vm.max_map_count=2147483642
```

---

## Benchmarks y Testing

### Verificar Vulkan

```bash
# Info de Vulkan
vulkaninfo

# Test básico
vkcube
```

### Test OpenGL

```bash
# FPS test
glxgears

# Con MangoHud
mangohud glxgears
```

### Probar GameMode

```bash
# Ejecutar test con GameMode
gamemoderun glxgears

# Verificar que está activo
gamemoded -s
```

---

## Comparativa de Launchers

| Característica | Steam | Faugus | Heroic |
|----------------|-------|--------|--------|
| Juegos Steam | ✅ Nativo | ❌ | ❌ |
| Epic Games | ❌ | ✅ | ✅ Nativo |
| GOG | ❌ | ✅ | ✅ Nativo |
| Amazon Prime | ❌ | ✅ | ✅ |
| itch.io | ❌ | ✅ | ❌ |
| Standalone | ❌ | ✅ | ❌ |
| Emuladores | ❌ | ❌ | ❌ |
| Interfaz | Completa | Simple | Completa |
| Recursos | Alto | Bajo | Medio |
| Juegos Windows | ✅ Proton | ✅ Proton | ✅ Proton |
| Formato | .deb | .deb | .deb |
| Proton compartido | ✅ | ✅ | ✅ |

**Faugus:** Ligero y simple para Epic/GOG/standalone
**Heroic:** Interfaz completa para Epic/GOG
**Steam:** Plataforma principal de Valve

---

## Recursos

### Documentación Oficial
- [Steam](https://store.steampowered.com)
- [Faugus Launcher](https://github.com/Faugus/faugus-launcher)
- [Heroic](https://heroicgameslauncher.com)
- [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt)
- [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher)
- [Proton-Cachyos](https://github.com/CachyOS/proton-cachyos)
- [GameMode](https://github.com/FeralInteractive/gamemode)
- [MangoHud](https://github.com/flightlessmango/MangoHud)

### Comunidades
- [ProtonDB](https://www.protondb.com/) - Compatibilidad de juegos
- [r/linux_gaming](https://www.reddit.com/r/linux_gaming/)
- [GamingOnLinux](https://www.gamingonlinux.com/)

---

**Siguiente:** [Configuración](02-Configuration.md) | [Troubleshooting](03-Troubleshooting.md)
