# Configuración de Locales (Arch Wiki + Gentoo Handbook)

## Método Estándar Systemd

Basado en **Arch Wiki** y **Gentoo Handbook** para sistemas con systemd.

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
