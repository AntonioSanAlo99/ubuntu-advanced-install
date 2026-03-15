# Gestión de Energía en Laptop

Documentación de las opciones de gestión de energía para laptops.

---

## Opciones Disponibles

El módulo de laptop ofrece dos opciones:

### 1. power-profiles-daemon (Predeterminado)

**Descripción:** Daemon de perfiles de energía de GNOME

**Ventajas:**
- ✅ Integración nativa con GNOME Settings
- ✅ Interfaz gráfica simple
- ✅ Cambio rápido de perfiles
- ✅ Automático y sin configuración
- ✅ Sincronización con apps (notificaciones reducidas en power saver)

**Desventajas:**
- ❌ Menos opciones de configuración
- ❌ Control menos fino
- ❌ Ahorro energético menor que TLP

**Ideal para:**
- Usuarios que prefieren simplicidad
- Integración con GNOME
- Perfiles rápidos (Performance/Balanced/Power Saver)
- Uso general de laptop

### 2. TLP

**Descripción:** Herramienta avanzada de gestión de energía

**Ventajas:**
- ✅ Configuración detallada AC vs Batería
- ✅ Optimización agresiva de batería
- ✅ Control fino de CPU, disco, USB, WiFi, PCI
- ✅ Ahorro energético máximo
- ✅ Altamente personalizable

**Desventajas:**
- ❌ Más complejo de configurar
- ❌ No integración visual con GNOME Settings
- ❌ Requiere terminal para cambios

**Ideal para:**
- Usuarios avanzados
- Máxima duración de batería necesaria
- Control total del hardware
- Configuración diferenciada AC/Batería

---

## power-profiles-daemon

### Instalación

El módulo 21 instala automáticamente si seleccionas opción 1 (predeterminado).

### Perfiles Disponibles

#### Performance (Rendimiento)
- CPU: Máxima frecuencia
- GPU: Máximo rendimiento
- WiFi: Full power
- **Uso:** Gaming, rendering, compilación
- **Batería:** Consumo alto

#### Balanced (Equilibrado)
- CPU: Balanceado
- GPU: Balanceado
- WiFi: Balanceado
- **Uso:** Uso general, navegación
- **Batería:** Consumo medio
- **Predeterminado**

#### Power Saver (Ahorro de energía)
- CPU: Frecuencia reducida
- GPU: Ahorro energético
- WiFi: Power save
- Brillo: Reducido
- Notificaciones: Reducidas
- **Uso:** Batería baja, lectura
- **Batería:** Máxima duración

### Cambiar Perfil

**Desde GNOME Settings:**
```
Settings → Power → Power Mode
```

Selector con 3 opciones (slider)

**Desde terminal:**
```bash
# Ver perfil actual
powerprofilesctl get

# Listar perfiles disponibles
powerprofilesctl list

# Cambiar a performance
powerprofilesctl set performance

# Cambiar a power-saver
powerprofilesctl set power-saver

# Cambiar a balanced
powerprofilesctl set balanced
```

### Integración con Apps

Algunas aplicaciones detectan el perfil activo:

- **GNOME Shell:** Reduce animaciones en power-saver
- **Videos:** Reduce calidad de reproducción
- **GNOME Software:** Pausa descargas en power-saver
- **Evolution:** Reduce sincronización en power-saver

### Estado del Servicio

```bash
# Ver estado
systemctl status power-profiles-daemon

# Ver perfil activo
powerprofilesctl get
```

### Automático según Batería

power-profiles-daemon NO cambia automáticamente según nivel de batería.

Para esto, usar extensión GNOME:
- **Power Profile Switcher** (extensions.gnome.org)

---

## TLP

### Instalación

El módulo 21 instala automáticamente si seleccionas opción 2.

### Configuración

**Archivo:** `/etc/tlp.d/99-laptop-custom.conf`

**Configuración predeterminada:**

```bash
# CPU
CPU_BOOST_ON_AC=1                           # Boost activado en AC
CPU_BOOST_ON_BAT=1                          # Boost activado en batería
CPU_SCALING_GOVERNOR_ON_AC=schedutil        # Governor en AC
CPU_SCALING_GOVERNOR_ON_BAT=schedutil       # Governor en batería
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# Disco
AHCI_RUNTIME_PM_ON_AC=on                    # SATA power management
AHCI_RUNTIME_PM_ON_BAT=auto

# Red
WIFI_PWR_ON_AC=off                          # WiFi full power en AC
WIFI_PWR_ON_BAT=on                          # WiFi power save en batería

# USB
USB_AUTOSUSPEND=1                           # Suspender USB inactivos
```

### Comandos

```bash
# Ver estado completo
sudo tlp-stat

# Ver estado de batería
sudo tlp-stat -b

# Aplicar configuración
sudo tlp start

# Ver diferencias AC vs BAT
sudo tlp-stat -c
```

### Personalización Avanzada

**Editar configuración:**
```bash
sudo nano /etc/tlp.d/99-laptop-custom.conf
```

**Opciones comunes:**

```bash
# Más agresivo en batería
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Máximo rendimiento en AC
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_AC=performance

# Deshabilitar Bluetooth en batería
DEVICES_TO_DISABLE_ON_BAT="bluetooth"

# Control de ventilador (ThinkPad)
FAN_SPEED_ON_AC="255 255"
FAN_SPEED_ON_BAT="128 128"
```

**Aplicar cambios:**
```bash
sudo tlp start
```

### Conflictos

TLP desactiva automáticamente:
- power-profiles-daemon
- laptop-mode-tools

**No usar junto con:** otros gestores de energía

---

## Comparativa

| Característica | TLP | power-profiles-daemon |
|----------------|-----|----------------------|
| Integración GNOME | ❌ | ✅ |
| Configuración visual | ❌ | ✅ |
| Control fino | ✅ | ❌ |
| Ahorro de batería | ✅✅✅ | ✅✅ |
| Personalización | ✅✅✅ | ✅ |
| Simplicidad | ❌ | ✅✅✅ |
| AC vs BAT diferenciado | ✅ | ❌ |
| Control USB | ✅ | ❌ |
| Control WiFi | ✅ | ❌ |
| Perfiles rápidos | ❌ | ✅ |

---

## Cambiar Entre TLP y power-profiles-daemon

### De TLP a power-profiles-daemon

```bash
# Deshabilitar TLP
sudo systemctl stop tlp
sudo systemctl disable tlp
sudo systemctl mask tlp

# Instalar y habilitar PPD
sudo apt install power-profiles-daemon
sudo systemctl unmask power-profiles-daemon
sudo systemctl enable power-profiles-daemon
sudo systemctl start power-profiles-daemon
```

### De power-profiles-daemon a TLP

```bash
# Deshabilitar PPD
sudo systemctl stop power-profiles-daemon
sudo systemctl disable power-profiles-daemon
sudo systemctl mask power-profiles-daemon

# Instalar y habilitar TLP
sudo apt install tlp tlp-rdw
sudo systemctl unmask tlp
sudo systemctl enable tlp
sudo tlp start
```

---

## Otras Optimizaciones de Laptop

### thermald

**Instalado con ambas opciones**

**Función:** Control térmico del CPU

**Configuración:** Automática, no requiere cambios

### CPU Governor

**Opciones:**
- `performance` - Máxima frecuencia siempre
- `powersave` - Mínima frecuencia siempre
- `schedutil` - Dinámico según carga (recomendado)
- `ondemand` - Similar a schedutil (legacy)

**Ver actual:**
```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Cambiar (temporal):**
```bash
echo "schedutil" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

### Brillo de Pantalla

```bash
# Instalar utilidad
sudo apt install brightnessctl

# Ver nivel actual
brightnessctl

# Reducir
brightnessctl set 50%

# Incrementar
brightnessctl set +10%
```

---

## Monitorización

### Consumo de Batería

```bash
# Ver estadísticas
upower -i /org/freedesktop/UPower/devices/battery_BAT0

# Monitorizar en tiempo real
watch -n 2 upower -i /org/freedesktop/UPower/devices/battery_BAT0
```

### Consumo de Energía

```bash
# Instalar powertop
sudo apt install powertop

# Ejecutar análisis
sudo powertop

# Generar reporte HTML
sudo powertop --html=power-report.html
```

### Procesos que Consumen

```bash
# Con powertop (Tab: Overview)
sudo powertop

# Con htop
htop

# Wakeups por segundo
cat /proc/interrupts
```

---

## Recomendaciones

### Para Máxima Duración de Batería

1. Usar **TLP**
2. Configuración agresiva en batería
3. Reducir brillo al mínimo cómodo
4. Cerrar apps innecesarias
5. Usar modo avión si no necesitas red
6. Deshabilitar Bluetooth

### Para Equilibrio

1. Usar **power-profiles-daemon**
2. Perfil Balanced normal
3. Power Saver cuando batería < 20%
4. Brillo automático
5. WiFi power save

### Para Rendimiento

1. Usar **power-profiles-daemon** en Performance
2. O TLP con configuración performance
3. Conectar a AC cuando sea posible

---

## Recursos

- [TLP Documentation](https://linrunner.de/tlp/)
- [power-profiles-daemon](https://gitlab.freedesktop.org/hadess/power-profiles-daemon)
- [ArchWiki - Power Management](https://wiki.archlinux.org/title/Power_management)
- [Ubuntu Wiki - Laptop](https://help.ubuntu.com/community/Laptop)

---

**Siguiente:** [Configuración](02-Configuration.md) | [GNOME](GNOME.md)
