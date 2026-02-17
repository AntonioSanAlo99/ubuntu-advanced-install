# Guía de Testing de Optimizaciones

Este instalador incluye un sistema modular de optimizaciones que te permite activar/desactivar categorías específicas para medir su impacto real en tu hardware.

---

## Filosofía del sistema

Todas las optimizaciones están **comentadas por defecto**. Esto te permite:

1. Instalar el sistema con configuración base (equivalente a Ubuntu stock mejorado)
2. Hacer benchmark baseline sin optimizaciones
3. Activar una categoría específica
4. Hacer benchmark con esa categoría
5. Comparar resultados objetivos
6. Decidir qué optimizaciones mantener según TU hardware y TU uso

---

## Categorías disponibles

### MEMORIA
- `vm.swappiness = 1` — Todo en RAM, swap solo emergencias
- `vm.page-cluster = 0` — Lectura exacta de swap en NVMe

**Cuándo activar:** Si tienes ≥8GB RAM y quieres máxima agilidad

### FS_CACHE
- `vm.vfs_cache_pressure = 50` — Retiene estructuras de filesystem en caché

**Cuándo activar:** Desktop con apertura frecuente de aplicaciones

### SCHEDULER
- `kernel.sched_migration_cost_ns = 5000000` — Tareas permanecen 5ms en su core
- `kernel.sched_nr_migrate = 256` — Balanceo más agresivo (8x Ubuntu)

**Cuándo activar:** CPUs con ≥6 cores, compilación, gaming

### RED
- `net.ipv4.tcp_congestion_control = bbr` — Algoritmo Google BBR
- `net.ipv4.tcp_fastopen = 3` — TCP Fast Open
- `net.ipv4.tcp_slow_start_after_idle = 0` — Sin slow start

**Cuándo activar:** Siempre (mejora latencia y throughput sin coste)

---

## Uso del script de testing

```bash
# Copiar la herramienta al sistema instalado
sudo cp tools/benchmark-optimizer.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/benchmark-optimizer.sh

# Ver estado actual
sudo benchmark-optimizer.sh status

# Activar una categoría
sudo benchmark-optimizer.sh enable MEMORIA

# Desactivar una categoría
sudo benchmark-optimizer.sh disable MEMORIA

# Activar todas
sudo benchmark-optimizer.sh enable ALL

# Volver a defaults Ubuntu
sudo benchmark-optimizer.sh disable ALL
```

---

## Workflow recomendado de testing

### 1. Baseline (sin optimizaciones)

```bash
# Asegurar que todo está desactivado
sudo benchmark-optimizer.sh disable ALL

# Hacer benchmarks
systemd-analyze                          # Boot time
time make -j$(nproc)                     # Compilación
sysbench memory run                      # Memoria
curl -o /dev/null http://speedtest.com  # Red
```

### 2. Testing por categoría

```bash
# Probar MEMORIA
sudo benchmark-optimizer.sh enable MEMORIA
<repetir benchmarks>
<anotar resultados>
sudo benchmark-optimizer.sh disable MEMORIA

# Probar SCHEDULER
sudo benchmark-optimizer.sh enable SCHEDULER
<repetir benchmarks>
<anotar resultados>
sudo benchmark-optimizer.sh disable SCHEDULER

# etc...
```

### 3. Testing combinado

```bash
# Una vez identificadas las categorías que dan beneficio
sudo benchmark-optimizer.sh enable MEMORIA
sudo benchmark-optimizer.sh enable RED
<benchmark final>
```

### 4. Hacer permanente la configuración ganadora

```bash
# Editar archivo y descomentar líneas deseadas
sudo nano /etc/sysctl.d/99-performance-modular.conf

# Las optimizaciones se aplicarán en cada boot
```

---

## Parámetros de boot opcionales

Estos están documentados en `/etc/default/grub` después de la instalación:

### mitigations=off
- **Efecto:** +10-20% rendimiento CPU
- **Coste:** Vulnerable a Spectre/Meltdown
- **Cuándo usar:** Desktop personal sin código no confiable

### split_lock_detect=off
- **Efecto:** Sin verificaciones de errores de software
- **Coste:** No detecta bugs de apps mal compiladas
- **Cuándo usar:** 10ª gen Intel+ con software de confianza

**Para activar:**
```bash
sudo nano /etc/default/grub
# Añadir a GRUB_CMDLINE_LINUX_DEFAULT
sudo update-grub
sudo reboot
```

---

## Benchmarks sugeridos por uso

### Desktop general
- Boot time: `systemd-analyze`
- Responsividad: Abrir/cerrar apps y medir tiempo
- Memoria: `free -h` en idle

### Desarrollo
- Compilación: `time make -j$(nproc)` en proyecto real
- Git operations: `time git clone <large-repo>`

### Gaming
- Latencia: `ping -c 100 8.8.8.8` (buscar jitter bajo)
- FPS: Benchmark in-game

### Multimedia
- Encoding: `time ffmpeg -i input.mp4 output.mp4`
- Decode: Reproducir 4K y medir CPU usage

---

## Resultados esperables

Estos son **valores aproximados** según testing en hardware Skylake/Zen:

| Categoría | Compilación | Boot | RAM idle | Latencia red |
|-----------|:-----------:|:----:|:--------:|:------------:|
| Baseline  | 100% | 100% | 450MB | 0.15ms |
| +MEMORIA  | 100% | 100% | 450MB | 0.15ms |
| +SCHEDULER| 85% | 100% | 450MB | 0.15ms |
| +RED      | 100% | 100% | 450MB | 0.10ms |
| +ALL      | 85% | 95% | 450MB | 0.10ms |

**Nota:** Los resultados varían según hardware. Por eso el testing controlado es esencial.

---

## Troubleshooting

**P: Activé MEMORIA y el sistema usa más swap**
R: Paradójicamente correcto. Con swappiness=1 el sistema retiene más en RAM antes de swappear, pero cuando swappea lo hace porque realmente no hay RAM. Si esto ocurre, desactiva MEMORIA.

**P: SCHEDULER no mejora mi compilación**
R: Depende del número de cores y del proyecto. En CPUs con 4 cores o menos el beneficio es mínimo.

**P: RED no cambia mi velocidad de descarga**
R: BBR mejora latencia y throughput en conexiones congestionadas. Si tu conexión ya funciona al 100% del ancho de banda contratado, no hay margen de mejora.

**P: ¿Puedo dejar todo activado permanentemente?**
R: Sí, si los benchmarks confirman que tu hardware se beneficia de cada categoría. Si alguna no da beneficio, desactívala para mantener el sistema limpio.

---

## Hacer permanente tu configuración

Una vez decidido qué optimizaciones quieres:

```bash
# Opción 1: Usar el script para activar (temporal, cada boot)
sudo benchmark-optimizer.sh enable MEMORIA
sudo benchmark-optimizer.sh enable RED

# Opción 2: Editar el archivo y descomentar (permanente)
sudo nano /etc/sysctl.d/99-performance-modular.conf
# Descomentar las líneas deseadas
# Guardar y cerrar

# Los cambios se aplicarán automáticamente en cada boot
```

---

**Recuerda:** El objetivo no es activar todas las optimizaciones porque sí, sino activar solo las que **demuestren beneficio real en TU hardware con TU carga de trabajo**.

