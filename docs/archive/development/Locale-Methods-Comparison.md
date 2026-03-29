# Comparación de Métodos de Configuración de Locales

## Script de Testing

**Ubicación:** `modules/03-locale-methods.sh`

Este script NO se ejecuta automáticamente. Es para testing y entender qué método causa errores.

```bash
# Uso
sudo ./modules/03-locale-methods.sh /mnt

# Menú interactivo para probar diferentes combinaciones
```

## Métodos Disponibles

### 1. Arch Style (systemd puro)

**Archivos:**
- `/etc/locale.gen` - Lista de locales
- `/etc/locale.conf` - Configuración systemd
- `/etc/vconsole.conf` - Teclado consola

**Comandos:**
```bash
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf
localectl set-locale LANG=es_ES.UTF-8
```

**Pros:**
- ✅ Estándar systemd
- ✅ Simple y limpio
- ✅ Arch Wiki compatible

**Contras:**
- ⚠️ Algunas apps Debian pueden no leerlo

---

### 2. Debian Style (dpkg-reconfigure)

**Archivos:**
- `/etc/locale.gen` - Lista de locales
- `/etc/default/locale` - Configuración Debian

**Comandos:**
```bash
locale-gen
echo 'LANG=es_ES.UTF-8' > /etc/default/locale
update-locale LANG=es_ES.UTF-8
dpkg-reconfigure -f noninteractive locales
```

**Pros:**
- ✅ Compatible con Debian/Ubuntu legacy
- ✅ Apps antiguas lo leen

**Contras:**
- ⚠️ No sigue estándar systemd
- ⚠️ Más verbose

---

### 3. Hybrid (Arch + Debian)

**Archivos:**
- `/etc/locale.gen`
- `/etc/locale.conf` (prioritario)
- `/etc/default/locale` (fallback)
- `/etc/vconsole.conf`

**Comandos:**
```bash
locale-gen
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf
echo 'LANG=es_ES.UTF-8' > /etc/default/locale
localectl set-locale LANG=es_ES.UTF-8
```

**Pros:**
- ✅ Máxima compatibilidad
- ✅ Funciona con todo

**Contras:**
- ⚠️ Redundante
- ⚠️ Dos archivos hacen lo mismo

---

### 4. Export Style (variables)

**Archivos:**
- `/etc/locale.gen`
- `/etc/environment` - Variables globales
- `/etc/profile.d/locale.sh` - Para shells

**Comandos:**
```bash
locale-gen
cat > /etc/environment << EOF
LANG=es_ES.UTF-8
LC_ALL=es_ES.UTF-8
