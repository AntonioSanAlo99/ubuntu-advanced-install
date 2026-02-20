# Configuración de Locales (Ubuntu Oficial)

## Documentación Oficial

Basado en:
- [Ubuntu Locales](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/Locales)
- [Language Packs](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/LanguagePacks)
- [Gettext](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/Gettext)

## Sistema de Internacionalización de Ubuntu

Ubuntu separa dos conceptos:

### 1. Locale (formato)
Define formatos de fecha, número, moneda, etc.
- Archivo: `/etc/default/locale`
- Genera: `locale-gen`
- Configura: `update-locale`

### 2. Traducciones (gettext)
Traduce textos de aplicaciones.
- Paquetes: `language-pack-*`
- Ubicación: `/usr/share/locale/[locale]/LC_MESSAGES/`
- Sistema: gettext (.po → .mo)

**Importante:** Puedes tener locale español pero apps en inglés si faltan language packs.

## Método Oficial Ubuntu

### Archivos de Configuración

```
/etc/default/locale     # Configuración principal (Ubuntu oficial)
/etc/locale.gen         # Lista de locales a generar
/etc/vconsole.conf      # Teclado consola (systemd)
```

### Proceso Completo

```bash
# 1. Activar locale en /etc/locale.gen
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen

# 2. Generar locale
locale-gen

# 3. Configurar /etc/default/locale
cat > /etc/default/locale << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
EOF

# 4. Actualizar con update-locale (método seguro)
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

# 5. Instalar language packs (traducciones)
apt install language-pack-es language-pack-es-base
apt install language-pack-gnome-es language-pack-gnome-es-base
```

## Variables de Locale

### LANG
Variable principal que define el locale del sistema.

```bash
LANG=es_ES.UTF-8
```

Todo hereda de `LANG` automáticamente.

### LANGUAGE
Lista de idiomas de fallback separados por `:`.

```bash
LANGUAGE=es_ES:es:en_US:en
```

**Orden:**
1. `es_ES` - Español de España
2. `es` - Español genérico
3. `en_US` - Inglés americano (fallback)
4. `en` - Inglés genérico (fallback final)

### LC_* Variables

Solo configurar si necesitas overrides específicos:

```bash
LC_TIME=en_GB.UTF-8      # Formato fecha británico
LC_MONETARY=en_US.UTF-8  # Formato monetario USD
LC_NUMERIC=en_US.UTF-8   # Números con punto decimal
```

**NO configurar en `/etc/default/locale` a menos que sea necesario.**

### LC_ALL

⚠️ **NUNCA en archivos de configuración**

Según Ubuntu Wiki: Solo para debugging temporal.

```bash
# Correcto: temporal en terminal
LC_ALL=C apt update

# Incorrecto: en /etc/default/locale
LC_ALL=es_ES.UTF-8  # ❌ NO HACER
```

## Language Packs

Ubuntu usa "language packs" para separar traducciones del código base.

### Paquetes Disponibles

```bash
# Base
language-pack-es              # Traducciones principales
language-pack-es-base         # Traducciones base

# GNOME
language-pack-gnome-es        # Traducciones GNOME
language-pack-gnome-es-base   # Traducciones GNOME base

# Otros
hunspell-es                   # Diccionario
hyphen-es                     # Separación silábica
mythes-es                     # Tesauro
```

### Cómo Funcionan

1. Las aplicaciones usan `gettext()` para buscar traducciones
2. Buscan en: `/usr/share/locale/[LANG]/LC_MESSAGES/[domain].mo`
3. Si no existe, usan `LANGUAGE` para fallback
4. Si nada funciona, muestran en inglés

### Verificar Traducciones

```bash
# Ver traducciones instaladas
ls /usr/share/locale/es_ES/LC_MESSAGES/

# Buscar traducción de un paquete específico
ls /usr/share/locale/es_ES/LC_MESSAGES/ | grep nautilus
```

## Consola Virtual (TTY)

Para configurar teclado en consola: `/etc/vconsole.conf`

```bash
KEYMAP=es
FONT=eurlatgr
```

Leído por systemd al arrancar.

## Diferencias con Arch

| Aspecto | Ubuntu Oficial | Arch/systemd |
|---------|----------------|--------------|
| Archivo config | `/etc/default/locale` | `/etc/locale.conf` |
| Comando | `update-locale` | `localectl` |
| Traducciones | Language packs | Paquetes individuales |
| Variables | `LANG` + `LANGUAGE` | Solo `LANG` |

**Nota:** Ubuntu con systemd puede usar ambos métodos, pero el método Ubuntu es el oficial y recomendado.

## Implementación en el Instalador

```bash
# 1. Generar locale
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
locale-gen

# 2. Configurar (método Ubuntu oficial)
cat > /etc/default/locale << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
EOF

update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es

# 3. Instalar traducciones
apt install language-pack-es language-pack-es-base
apt install language-pack-gnome-es language-pack-gnome-es-base

# 4. Consola
cat > /etc/vconsole.conf << EOF
KEYMAP=es
FONT=eurlatgr
EOF
```

## Verificación

```bash
# Locale configurado
cat /etc/default/locale

# Locales generados
locale -a | grep es_ES

# Locale actual
locale

# Traducciones instaladas
dpkg -l | grep language-pack

# Traducciones disponibles
ls /usr/share/locale/es_ES/LC_MESSAGES/ | wc -l
```

## Troubleshooting

### Sistema en español pero apps en inglés

**Causa:** Faltan language packs

**Solución:**
```bash
sudo apt install language-pack-es language-pack-gnome-es
```

### Variable LANGUAGE no funciona

**Causa:** No está en `/etc/default/locale`

**Solución:**
```bash
echo 'LANGUAGE=es_ES:es' | sudo tee -a /etc/default/locale
# O usar update-locale
sudo update-locale LANGUAGE=es_ES:es
```

### Warnings de perl sobre locale

**Causa:** Locale no generado

**Solución:**
```bash
sudo locale-gen es_ES.UTF-8
```

### LC_ALL configurado incorrectamente

**Síntoma:** Apps ignoran LANGUAGE

**Solución:**
```bash
# Eliminar LC_ALL de archivos
sudo grep -r "LC_ALL" /etc/

# Desconfigurar
unset LC_ALL

# Solo usar LANG y LANGUAGE
sudo update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es
```

## Referencias Oficiales

- [Ubuntu Locales](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/Locales)
- [Language Packs](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/LanguagePacks)
- [Gettext System](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/Gettext)
- [Translation Domains](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation/InternationalizationPrimer/Domains)

### Archivos de Configuración

```
/etc/locale.gen          # Lista de locales a generar
/etc/locale.conf         # Configuración del locale del sistema (systemd)
```

### Proceso Completo

```bash
# 1. Editar /etc/locale.gen (descomentar locales)
es_ES.UTF-8 UTF-8

# 2. Generar locales
locale-gen

# 3. Crear /etc/locale.conf
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf

# 4. Aplicar con localectl (systemd)
localectl set-locale LANG=es_ES.UTF-8
```

## ❌ Archivos que NO se usan (Debian legacy)

Estos archivos son específicos de Debian/Ubuntu y NO son estándar systemd:

- ❌ `/etc/default/locale` - Solo Debian/Ubuntu sin systemd
- ❌ `/etc/environment` - Para variables de entorno, NO locales
- ❌ Variables `LC_ALL` en archivos - Solo para sesiones temporales

## ✅ Método Correcto

### /etc/locale.gen

Lista de locales disponibles:

```
# /etc/locale.gen
en_US.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
```

Descomentar los locales necesarios.

### /etc/locale.conf

Configuración del sistema (leída por systemd):

```
# /etc/locale.conf
LANG=es_ES.UTF-8
```

**Solo `LANG` es necesario.** Otras variables se heredan automáticamente.

### localectl

Comando systemd para gestionar locales:

```bash
# Ver locale actual
localectl status

# Configurar locale
localectl set-locale LANG=es_ES.UTF-8

# Listar locales disponibles
localectl list-locales
```

## Variables de Locale

### LANG

Variable principal que define el locale del sistema:

```bash
LANG=es_ES.UTF-8
```

Todas las demás variables (`LC_*`) heredan de `LANG` automáticamente.

### LC_* Variables

Solo configurar si necesitas overrides específicos:

```bash
LC_TIME=en_GB.UTF-8      # Formato de fecha británico
LC_MONETARY=en_US.UTF-8  # Formato monetario USD
LC_NUMERIC=en_US.UTF-8   # Números con punto decimal
```

**NO configurar en `/etc/locale.conf` a menos que sea necesario.**

### LC_ALL

⚠️ **NUNCA en archivos de configuración**

Solo para sesiones temporales:

```bash
# Correcto: en la terminal temporalmente
LC_ALL=C apt update

# Incorrecto: en /etc/locale.conf
LC_ALL=es_ES.UTF-8  # ❌ NO HACER ESTO
```

`LC_ALL` sobrescribe todas las otras variables y puede causar problemas.

## Verificación

```bash
# Ver configuración actual
locale

# Ver locale del sistema
localectl status

# Ver locales generados
locale -a
```

Salida esperada:
```
LANG=es_ES.UTF-8
LC_CTYPE="es_ES.UTF-8"
LC_NUMERIC="es_ES.UTF-8"
LC_TIME="es_ES.UTF-8"
LC_COLLATE="es_ES.UTF-8"
LC_MONETARY="es_ES.UTF-8"
LC_MESSAGES="es_ES.UTF-8"
LC_PAPER="es_ES.UTF-8"
LC_NAME="es_ES.UTF-8"
LC_ADDRESS="es_ES.UTF-8"
LC_TELEPHONE="es_ES.UTF-8"
LC_MEASUREMENT="es_ES.UTF-8"
LC_IDENTIFICATION="es_ES.UTF-8"
LC_ALL=
```

## Consola Virtual (TTY)

Para configurar teclado en consola virtual: `/etc/vconsole.conf`

```bash
# /etc/vconsole.conf
KEYMAP=es
FONT=eurlatgr
```

Leído por systemd al arrancar.

## Diferencias con Debian/Ubuntu

| Aspecto | Systemd Estándar | Debian/Ubuntu |
|---------|------------------|---------------|
| Archivo config | `/etc/locale.conf` | `/etc/default/locale` |
| Comando | `localectl` | `update-locale` |
| Variables | Solo `LANG` | `LANG` + muchas `LC_*` |
| Consola TTY | `/etc/vconsole.conf` | `/etc/default/keyboard` |

Ubuntu con systemd puede usar ambos métodos, pero **el método systemd es preferible** para consistencia.

## Implementación en el Instalador

```bash
# 1. Generar locale
sed -i 's/^# *es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen
locale-gen

# 2. Configurar con archivo (systemd)
echo 'LANG=es_ES.UTF-8' > /etc/locale.conf

# 3. Aplicar con localectl
localectl set-locale LANG=es_ES.UTF-8
```

Limpio, estándar, sin redundancias.

## Troubleshooting

### Locale no aplicado después de boot

**Verificar:**
```bash
cat /etc/locale.conf
# Debe contener: LANG=es_ES.UTF-8

localectl status
# Debe mostrar: System Locale: LANG=es_ES.UTF-8
```

**Solución:**
```bash
localectl set-locale LANG=es_ES.UTF-8
```

### Warnings de perl sobre locale

**Causa:** Locale no generado

**Solución:**
```bash
# Verificar que está en locale.gen
grep es_ES.UTF-8 /etc/locale.gen

# Generar
locale-gen

# Verificar
locale -a | grep es_ES
```

### LC_ALL configurado incorrectamente

**Síntoma:** Algunas aplicaciones usan locale incorrecto

**Solución:**
```bash
# Eliminar LC_ALL de archivos de config
grep -r "LC_ALL" /etc/

# Desconfigurar
unset LC_ALL

# Reconfigurar solo LANG
localectl set-locale LANG=es_ES.UTF-8
```

## Referencias

- [Arch Wiki - Locale](https://wiki.archlinux.org/title/Locale)
- [Gentoo Handbook - Locales (systemd)](https://wiki.gentoo.org/wiki/Localization/Guide#Locales_for_systemd)
- [systemd - locale.conf(5)](https://man.archlinux.org/man/locale.conf.5)
