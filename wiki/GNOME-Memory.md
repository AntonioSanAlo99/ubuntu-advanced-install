# Optimización de Memoria en GNOME

## Problema identificado

GNOME puede consumir **1.2-1.5GB de RAM en idle**, lo cual es excesivo para sistemas con poca memoria o para mantener recursos disponibles para aplicaciones.

## Optimizaciones aplicadas (Módulo 10b)

### 1. systemd-oomd (Out Of Memory Daemon)
- **Qué hace**: Gestiona automáticamente situaciones de falta de memoria
- **Beneficio**: Evita que el sistema se cuelgue por falta de RAM
- **Disponible en**: Ubuntu 22.04+

```bash
# Verificar estado
systemctl status systemd-oomd
```

### 2. Tracker deshabilitado
- **Qué es**: Indexador de archivos de GNOME
- **Consumo**: ~100-200MB RAM
- **Beneficio de deshabilitarlo**: 
  - Ahorra RAM significativa
  - Reduce I/O de disco
  - GNOME funciona perfectamente sin él
- **Inconveniente**: Búsqueda de archivos más lenta

**Archivos deshabilitados:**
- `/etc/xdg/autostart/tracker-miner-fs-3.desktop`
- `/etc/xdg/autostart/tracker-extract-3.desktop`

### 3. Evolution Data Server deshabilitado
- **Qué es**: Backend de calendario/contactos
- **Consumo**: ~50-100MB RAM
- **Beneficio**: No lo usamos si no instalamos Evolution

### 4. zram (swap comprimido en RAM)
- **Qué es**: Swap comprimido en memoria RAM
- **Configuración**: 50% de la RAM con algoritmo zstd
- **Beneficio**: 
  - Válvula de escape cuando falta RAM
  - 2-3x compresión (512MB RAM → ~1.5GB disponible)
  - Más rápido que swap en disco

```bash
# Ver estado de zram
zramctl

# Ejemplo de salida:
# NAME       ALGORITHM DISKSIZE  DATA COMPR TOTAL
# /dev/zram0 zstd        2G      156M  45M   48M
```

### 5. gnome-software deshabilitado
- **Qué es**: Tienda de aplicaciones de GNOME
- **Consumo**: ~80-150MB RAM ejecutándose en background
- **Alternativa**: Usamos `gdebi` y `apt` directamente

### 6. Límites de memoria en GNOME Shell
```
MemoryHigh=512M    # Aviso cuando supera 512MB
MemoryMax=768M     # Límite máximo de 768MB
```

### 7. Optimizaciones de usuario
- **Animaciones deshabilitadas**: Ahorra RAM y CPU
- **Thumbnails limitados**: Solo genera miniaturas de archivos <10MB
- **Búsqueda en archivos deshabilitada**: Tracker no indexa

## Resultado esperado

| Estado | RAM consumida | Mejora |
|--------|---------------|--------|
| **Antes** (GNOME sin optimizar) | 1.2-1.5GB | - |
| **Después** (con optimizaciones) | 600-800MB | **~50% menos** |

## Verificar optimizaciones

### systemd-oomd
```bash
systemctl status systemd-oomd
# Debería mostrar: active (running)
```

### Tracker
```bash
# No debería haber procesos tracker
ps aux | grep tracker
# Resultado esperado: solo el grep
```

### zram
```bash
# Ver swap comprimido
swapon --show
# Debería mostrar /dev/zram0

# Estadísticas
zramctl
```

### Memoria total en uso
```bash
free -h
```

Ejemplo esperado en sistema con 4GB RAM:
```
              total        used        free      shared  buff/cache   available
Mem:          3.8Gi       700Mi       2.5Gi        50Mi       600Mi       2.9Gi
Swap:         1.9Gi          0B       1.9Gi
```

## Revertir optimizaciones (si es necesario)

### Habilitar Tracker
```bash
sudo rm /etc/xdg/autostart/tracker-miner-fs-3.desktop
sudo rm /etc/xdg/autostart/tracker-extract-3.desktop

# Iniciar manualmente
tracker3 daemon -s
```

### Habilitar gnome-software
```bash
sudo systemctl unmask gnome-software.service
```

### Habilitar animaciones
```bash
gsettings set org.gnome.desktop.interface enable-animations true
```

### Deshabilitar zram
```bash
sudo systemctl disable zramswap
sudo systemctl stop zramswap
```

## Consumo de memoria por componente

| Componente | RAM típica | Con límites |
|------------|------------|-------------|
| gnome-shell | 300-500MB | max 768MB |
| GDM3 | 100-150MB | - |
| gnome-settings-daemon | 50-100MB | - |
| nautilus | 80-120MB | - |
| Tracker (deshabilitado) | ~~150MB~~ | 0MB |
| Evolution Data (deshabilitado) | ~~80MB~~ | 0MB |
| gnome-software (deshabilitado) | ~~100MB~~ | 0MB |
| **Total** | **~800MB** | vs ~1.5GB |

## Optimizaciones adicionales (opcionales)

### Usar LightDM en lugar de GDM3
```bash
sudo apt install lightdm
sudo dpkg-reconfigure lightdm
# Ahorra ~50-100MB en el login manager
```

### Deshabilitar más servicios de GNOME
```bash
# evolution-source-registry (si existe)
systemctl --user mask evolution-source-registry.service

# gvfs-metadata (indexador de metadatos)
systemctl --user mask gvfs-metadata.service
```

### Aumentar zram si tienes suficiente RAM
```bash
sudo nano /etc/default/zramswap
# Cambiar PERCENT=50 a PERCENT=75
sudo systemctl restart zramswap
```

## Troubleshooting

### systemd-oomd mata procesos importantes

**Síntoma**: Navegador o aplicaciones se cierran inesperadamente

**Solución**: Ajustar configuración de oomd
```bash
sudo nano /etc/systemd/oomd.conf

[OOM]
# Aumentar el umbral (default: 10%)
DefaultMemoryPressureDurationSec=20s
```

### El sistema sigue consumiendo mucha RAM

**Verificar**:
```bash
# Ver procesos que más consumen
ps aux --sort=-%mem | head -20

# Ver memoria usada por servicios
systemd-cgtop
```

### zram no se activa

**Verificar**:
```bash
# Estado del servicio
systemctl status zramswap

# Logs
journalctl -u zramswap

# Reiniciar
sudo systemctl restart zramswap
```

## Notas importantes

⚠️ **Tracker deshabilitado significa:**
- Búsqueda de archivos más lenta en Nautilus
- Sin indexación automática de música/fotos
- Apps que dependen de Tracker pueden fallar

⚠️ **Límites de memoria en GNOME Shell:**
- Si GNOME Shell supera 768MB, puede reiniciarse
- Esto es intencional para evitar fugas de memoria
- Rara vez ocurre en uso normal

✅ **Beneficios generales:**
- Sistema más ágil con poca RAM
- Más memoria disponible para aplicaciones
- Menos swap usado (mejor para SSD)
- Inicio de sesión más rápido
