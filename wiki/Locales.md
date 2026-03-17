# Configuración de Locales

## 🌍 Locale por Defecto

El sistema se configura con **es_ES.UTF-8** usando el método oficial de Debian.

---

## ✅ Método de Configuración

### dpkg-reconfigure (Oficial Debian/Ubuntu)

El instalador usa `dpkg-reconfigure locales` en modo no-interactivo:

```bash
# Pre-configurar respuestas
debconf-set-selections << EOF
locales locales/locales_to_be_generated multiselect es_ES.UTF-8 UTF-8
locales locales/default_environment_locale select es_ES.UTF-8
EOF

# Reconfigurare (método oficial)
dpkg-reconfigure -f noninteractive locales
```

**Esto configura**:
- `/etc/locale.gen` - Locales a generar
- `/etc/default/locale` - Locale por defecto
- `/etc/environment` - Variables de entorno
- Genera el locale con `locale-gen`
- Configura **todas** las variables LC_*

---

## 📊 Estado Después de Instalación

### Archivos Configurados

```bash
# /etc/default/locale
LANG=es_ES.UTF-8

# /etc/locale.gen
es_ES.UTF-8 UTF-8

# /etc/environment
PATH="/usr/local/sbin:..."
LANG=es_ES.UTF-8
```

### Locales Generados

```bash
ls /usr/lib/locale/
# C.utf8
# es_ES.utf8
```

### Variables de Locale

```bash
locale
# LANG=es_ES.UTF-8
# LC_CTYPE="es_ES.UTF-8"
# LC_NUMERIC="es_ES.UTF-8"
# LC_TIME="es_ES.UTF-8"
# LC_COLLATE="es_ES.UTF-8"
# LC_MONETARY="es_ES.UTF-8"
# LC_MESSAGES="es_ES.UTF-8"
# LC_PAPER="es_ES.UTF-8"
# LC_NAME="es_ES.UTF-8"
# LC_ADDRESS="es_ES.UTF-8"
# LC_TELEPHONE="es_ES.UTF-8"
# LC_MEASUREMENT="es_ES.UTF-8"
# LC_IDENTIFICATION="es_ES.UTF-8"
# LC_ALL=
```

**Sin warnings** - Todas las variables configuradas correctamente.

---

## 🔧 Cambiar Locale

### Método Interactivo

```bash
sudo dpkg-reconfigure locales
```

**Pasos**:
1. Selecciona locales a generar (espacio para marcar)
2. Selecciona locale por defecto
3. Confirma

### Método Manual

```bash
# 1. Editar locales a generar
sudo nano /etc/locale.gen
# Descomentar locales deseados, ejemplo:
# en_US.UTF-8 UTF-8
# es_ES.UTF-8 UTF-8
# fr_FR.UTF-8 UTF-8

# 2. Generar locales
sudo locale-gen

# 3. Configurar default
sudo update-locale LANG=es_ES.UTF-8

# 4. Reiniciar sesión
```

---

## 🌍 Locales Comunes

### Español

```bash
es_ES.UTF-8   # España
es_MX.UTF-8   # México
es_AR.UTF-8   # Argentina
es_CO.UTF-8   # Colombia
```

### Inglés

```bash
en_US.UTF-8   # Estados Unidos
en_GB.UTF-8   # Reino Unido
en_AU.UTF-8   # Australia
```

### Otros

```bash
fr_FR.UTF-8   # Francés
de_DE.UTF-8   # Alemán
it_IT.UTF-8   # Italiano
pt_BR.UTF-8   # Portugués (Brasil)
```

---

## 🎯 Configuración Específica por Variable

### Por Categoría

```bash
# ~/.bashrc o ~/.profile

# Idioma general
export LANG=es_ES.UTF-8

# Mensajes en inglés, resto en español
export LC_MESSAGES=en_US.UTF-8

# Formato de fecha/hora
export LC_TIME=en_GB.UTF-8  # 24h format

# Formato numérico
export LC_NUMERIC=en_US.UTF-8  # Punto decimal
```

### Variables LC_*

- `LC_CTYPE`: Clasificación de caracteres
- `LC_NUMERIC`: Formato numérico (1,000.50 vs 1.000,50)
- `LC_TIME`: Formato fecha/hora
- `LC_COLLATE`: Orden alfabético
- `LC_MONETARY`: Formato moneda (€, $, etc.)
- `LC_MESSAGES`: Idioma mensajes del sistema
- `LC_PAPER`: Tamaño papel (A4 vs Letter)
- `LC_NAME`: Formato nombres
- `LC_ADDRESS`: Formato direcciones
- `LC_TELEPHONE`: Formato teléfonos
- `LC_MEASUREMENT`: Sistema medidas (métrico vs imperial)
- `LC_IDENTIFICATION`: Identificación locale

---

## 🐛 Troubleshooting

### Warnings "locale: Cannot set..."

```bash
# Ver warnings exactos
locale

# Causa: Locale no generado
# Solución:
sudo dpkg-reconfigure locales
# O:
sudo locale-gen es_ES.UTF-8
```

### Perl Warnings

```bash
# perl: warning: Setting locale failed.
# perl: warning: Please check that your locale settings...

# Solución:
sudo dpkg-reconfigure locales
```

### Variables sin Configurar

```bash
locale
# LC_ALL=   (vacío - normal)
# LANG=es_ES.UTF-8

# LC_ALL debe estar vacío (usa LANG como default)
# NO configurar LC_ALL a menos que sepas lo que haces
```

### Locale No Disponible en Programa

```bash
# Programa pide locale no instalado
# Error: locale 'en_US.UTF-8' not available

# Solución:
sudo nano /etc/locale.gen
# Descomentar: en_US.UTF-8 UTF-8
sudo locale-gen
```

---

## 📊 Historia del Método

### Por Qué dpkg-reconfigure

#### Métodos Intentados Antes

1. **Manual (v3.5.0)**:
   ```bash
   sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
   locale-gen es_ES.UTF-8
   update-locale LANG=es_ES.UTF-8
   ```
   **Problema**: No configuraba todas las LC_* variables.

2. **Método Complejo**:
   ```bash
   # Filtrar warnings
   # Configurar LC_ALL=C primero
   # Luego cambiar a es_ES
   ```
   **Problema**: Complejidad innecesaria.

#### Método Correcto (v3.6.0+)

```bash
dpkg-reconfigure -f noninteractive locales
```

**Ventajas**:
- ✓ Método oficial Debian/Ubuntu
- ✓ Configura TODO correctamente
- ✓ Todas las variables LC_*
- ✓ Maneja casos edge
- ✓ Robusto a cambios de Ubuntu

---

## 🎯 Verificación

### Check Completo

```bash
# 1. Ver locale actual
locale
# No debe haber warnings

# 2. Ver locales generados
ls /usr/lib/locale/
# Debe incluir es_ES.utf8

# 3. Ver configuración
cat /etc/default/locale
# LANG=es_ES.UTF-8

# 4. Verificar que programas usan locale correcto
date
# Debe mostrar en español

# 5. Probar apt (común origen de warnings)
sudo apt update
# No debe mostrar warnings de locale
```

---

## 💡 Consejos

### Para Desarrolladores

```bash
# Inglés para mensajes de error (mejor para googlear)
export LC_MESSAGES=en_US.UTF-8

# Español para resto
export LANG=es_ES.UTF-8
```

### Para Servidores

```bash
# Usar C.UTF-8 (mínimo, sin traducciones)
sudo update-locale LANG=C.UTF-8

# O inglés
sudo update-locale LANG=en_US.UTF-8
```

### Multi-Usuario

```bash
# Sistema en inglés por defecto
sudo update-locale LANG=en_US.UTF-8

# Usuario individual en español
echo "export LANG=es_ES.UTF-8" >> ~/.bashrc
```

---

## 📋 Resumen

### Configuración Actual

```
Método: dpkg-reconfigure (oficial Debian)
Locale: es_ES.UTF-8
Todas las LC_*: Configuradas automáticamente
Teclado: Español (es)
Timezone: Europe/Madrid
```

### Cambiar

```bash
# Interactivo
sudo dpkg-reconfigure locales

# Manual
sudo locale-gen [locale]
sudo update-locale LANG=[locale]
```

### Verificar

```bash
locale  # Sin warnings
```

---

**dpkg-reconfigure es el método oficial y correcto para configurar locales en Debian/Ubuntu.**
