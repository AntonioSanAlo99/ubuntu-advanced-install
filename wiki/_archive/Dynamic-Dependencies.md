# Sistema de Detección Automática de Dependencias

## Problema

Las librerías multimedia de FFmpeg (`libavformat`, `libavcodec`, etc.) cambian de versión frecuentemente entre releases de Ubuntu:

```bash
# Ubuntu 22.04 (Jammy)
libavformat59, libavcodec59, libavutil57

# Ubuntu 24.04 (Noble)
libavformat60, libavcodec60, libavutil58

# Ubuntu 25.04 (Plucky) - futuro
libavformat61, libavcodec61, libavutil59

# Ubuntu 26.04 - ¿quién sabe?
libavformat62?, libavcodec62?, libavutil60?
```

**Problema con código hardcoded:**
```bash
# ❌ Falla en versiones futuras
apt install libavformat60 libavcodec60

# ❌ Requiere mantenimiento constante
apt install libavformat61 || apt install libavformat60 || apt install libavformat59
```

## Solución: Detección 100% Automática

### Función `find_latest_package`

```bash
find_latest_package() {
    local base_name="$1"
    
    # Buscar TODAS las versiones disponibles
    local available=$(apt-cache search "^${base_name}[0-9]" | \
                      awk '{print $1}' | \
                      grep "^${base_name}[0-9]\+$" | \
                      sort -V -r)
    
    if [ -n "$available" ]; then
        # Retornar la MÁS RECIENTE (sort -V -r)
        echo "$available" | head -n1
        return 0
    fi
    
    # Fallback: sin número de versión
    if apt-cache show "${base_name}" &>/dev/null; then
        echo "${base_name}"
        return 0
    fi
    
    return 1
}
```

### Uso

```bash
# Detectar AUTOMÁTICAMENTE (sin listar versiones)
LIBAVFORMAT=$(find_latest_package "libavformat")
LIBAVCODEC=$(find_latest_package "libavcodec")
LIBAVUTIL=$(find_latest_package "libavutil")

# Instalar lo que se encontró
apt-get install -y $LIBAVFORMAT $LIBAVCODEC $LIBAVUTIL
```

## Ventajas

✅ **Cero mantenimiento**
- No hay lista de versiones que actualizar
- Funciona con versiones que AÚN NO EXISTEN
- Sobrevivirá a Ubuntu 26.04, 28.04, 30.04...

✅ **Siempre instala la más reciente**
- `sort -V -r` ordena por versión (descendente)
- `head -n1` toma la primera = más reciente

✅ **Robusto**
- Si no existe versión numerada, intenta sin número
- Maneja paquetes que aún no tienen sufijo numérico

✅ **Transparente**
```
Detectando dependencias FFmpeg disponibles...
Versiones detectadas:
  ✓ libavformat60
  ✓ libavcodec60
  ✓ libavutil58
  ✓ libswscale7
  ✓ libswresample4
✓ Dependencias multimedia instaladas
```

## Cómo Funciona

### 1. Buscar paquetes con patrón
```bash
apt-cache search "^libavformat[0-9]"
```
Encuentra: `libavformat58`, `libavformat59`, `libavformat60`

### 2. Extraer solo nombres de paquete
```bash
awk '{print $1}'
```
Resultado: 
```
libavformat58
libavformat59
libavformat60
```

### 3. Filtrar solo coincidencias exactas
```bash
grep "^libavformat[0-9]\+$"
```
Elimina paquetes como `libavformat-dev`, `libavformat60-doc`

### 4. Ordenar por versión (descendente)
```bash
sort -V -r
```
Ordena numéricamente en reversa:
```
libavformat60
libavformat59
libavformat58
```

### 5. Tomar la primera (más reciente)
```bash
head -n1
```
Resultado: `libavformat60`

## Comparación

### Método Anterior (con lista de versiones)
```bash
find_available_package "libavformat" "61 60 59 58"
```

**Problemas:**
- ❌ Requiere actualizar lista manualmente
- ❌ Si sale versión 62, hay que añadirla
- ❌ Lista puede quedar obsoleta

### Método Actual (100% automático)
```bash
find_latest_package "libavformat"
```

**Ventajas:**
- ✅ No requiere actualización NUNCA
- ✅ Detecta versión 62, 63, 100 automáticamente
- ✅ Lista siempre actualizada (viene de apt-cache)

## Aplicación a Otras Librerías

### Qt con sufijos complejos
```bash
# Detecta automáticamente libqt6core6t64 o libqt6core6
find_latest_package "libqt6core6"
```

### Python
```bash
# Detecta python3.12, python3.11, etc.
PYTHON=$(apt-cache search "^python3\.[0-9]" | \
         awk '{print $1}' | \
         grep "^python3\.[0-9]\+$" | \
         sort -V -r | head -n1)
```

### LLVM
```bash
# Detecta llvm-19, llvm-18, etc.
LLVM=$(find_latest_package "llvm-")
```

## Paquetes FFmpeg Detectados

El script actual detecta automáticamente:

- `libavformat` - Formatos multimedia
- `libavcodec` - Códecs de audio/video
- `libavutil` - Utilidades comunes
- `libswscale` - Escalado de video
- `libswresample` - Remuestreo de audio
- `libavdevice` - Dispositivos de captura
- `libavfilter` - Filtros multimedia

## Testing

```bash
# Ver qué versiones hay disponibles
apt-cache search "^libavformat[0-9]"

# Probar la detección
find_latest_package "libavformat"

# Ver todas las libav disponibles
for lib in libavformat libavcodec libavutil libswscale libswresample; do
    echo "$lib: $(find_latest_package $lib)"
done
```

## Casos Especiales

### Múltiples versiones instaladas

Si ya tienes `libavformat59` y `libavformat60`:
```bash
# Siempre detecta la más reciente (60)
find_latest_package "libavformat"  # → libavformat60
```

### Paquete sin versión numérica

Algunos repos tienen `libavformat` sin número:
```bash
# Fallback automático
find_latest_package "libavformat"  # → libavformat (si no hay con número)
```

### Versión específica requerida

Si necesitas una versión específica (raro):
```bash
# Instalar directamente
apt install libavformat59
```

## Implementación Actual

**Ubicación:** `modules/12-install-multimedia.sh` (línea ~173)

```bash
find_latest_package() {
    local base_name="$1"
    local available=$(apt-cache search "^${base_name}[0-9]" | \
                      awk '{print $1}' | \
                      grep "^${base_name}[0-9]\+$" | \
                      sort -V -r)
    if [ -n "$available" ]; then
        echo "$available" | head -n1
        return 0
    fi
    if apt-cache show "${base_name}" &>/dev/null; then
        echo "${base_name}"
        return 0
    fi
    return 1
}

# Uso
LIBAVFORMAT=$(find_latest_package "libavformat")
LIBAVCODEC=$(find_latest_package "libavcodec")
# ... etc
```

## Resultado en la Práctica

```
Detectando dependencias FFmpeg disponibles...
Versiones detectadas:
  ✓ libavformat60
  ✓ libavcodec60
  ✓ libavutil58
  ✓ libswscale7
  ✓ libswresample4
  ✓ libavdevice60
  ✓ libavfilter9
✓ Dependencias multimedia instaladas
```

## Futuro

Este método funcionará en:
- ✅ Ubuntu 24.04 (actual)
- ✅ Ubuntu 25.04 (próximo)
- ✅ Ubuntu 26.04 (2026)
- ✅ Ubuntu 28.04 (2028)
- ✅ Cualquier versión futura

**Sin necesidad de actualizar el código.**
