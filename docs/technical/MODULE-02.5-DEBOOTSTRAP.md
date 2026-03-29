# MÓDULO 02.5: Investigación de Locales (TEMPORAL)

## 🎯 PROPÓSITO

Este módulo es **TEMPORAL** y existe únicamente para **investigar el estado real del sistema después de debootstrap**.

Una vez entendamos el estado real, diseñaremos la configuración correcta y **eliminaremos este módulo**.

---

## 📋 USO

### Opción 1: Ejecución Manual (Recomendado para investigación)

```bash
# 1. Ejecutar debootstrap
sudo bash modules/02-debootstrap.sh

# 2. Ejecutar investigación
sudo bash modules/02.5-investigate-locale.sh

# 3. Revisar reporte
cat locale-investigation-report.txt

# 4. Analizar resultados
# 5. Diseñar solución apropiada
# 6. Continuar con módulo 03
```

### Opción 2: Integrar en Instalación Interactiva

Editar `install.sh` para añadir después del módulo 02:

```bash
# En full_automatic_install() o full_interactive_install()
run_module "02-debootstrap" || exit 1
run_module "02.5-investigate-locale"  # ← AÑADIR AQUÍ
run_module "03-configure-base" || exit 1
```

---

## 📊 QUÉ INVESTIGA

### 1. Archivos de Configuración
- `/etc/default/locale` - ¿Existe? ¿Qué contiene?
- `/etc/locale.gen` - ¿Qué locales están habilitados?
- `/etc/environment` - ¿Hay variables configuradas?

### 2. Locales Generados
- `/usr/lib/locale/` - ¿Qué locales están compilados?
- `/usr/share/i18n/locales/` - ¿Qué locales disponibles?

### 3. Paquetes Instalados
- `locales` - ¿Instalado? ¿Versión?
- `console-data` - ¿Instalado?
- `console-setup` - ¿Instalado?
- `keyboard-configuration` - ¿Instalado?
- Todos los paquetes relacionados con locale/language

### 4. Estado del Sistema
- Salida de `locale` dentro del chroot
- Variables `LANG` y `LC_ALL`
- Warnings al ejecutar `apt update`
- Warnings al ejecutar `locale-gen`

### 5. Configuración de Teclado
- `/etc/default/keyboard` - ¿Existe?
- `/etc/vconsole.conf` - ¿Existe?

### 6. Otros Directorios
- `/var/lib/locales/supported.d/` - ¿Qué hay aquí?
- `/etc/apt/apt.conf.d/` - ¿Configuración de locale para APT?

---

## 📄 REPORTE GENERADO

El módulo genera: `locale-investigation-report.txt`

### Contenido del Reporte:

```
════════════════════════════════════════════════════════════════
REPORTE DE INVESTIGACIÓN: Estado de Locales Después de Debootstrap
════════════════════════════════════════════════════════════════

═══ 1. ARCHIVOS DE CONFIGURACIÓN DE LOCALE ═══
--- /etc/default/locale ---
[contenido o "NO EXISTE"]

--- /etc/locale.gen ---
[locales habilitados o "todos comentados"]

═══ 2. LOCALES GENERADOS EN EL SISTEMA ═══
[lista de locales en /usr/lib/locale/]

═══ 3. PAQUETES RELACIONADOS CON LOCALE ═══
[estado de locales, console-data, etc.]

═══ 4. SALIDA DEL COMANDO 'locale' EN CHROOT ═══
[variables de locale actuales]

... y más
```

---

## 🎯 PREGUNTAS QUE RESPONDE

### Sobre Configuración Actual:

- ✓ ¿Debootstrap deja algún locale configurado?
- ✓ ¿Cuál es el locale por defecto?
- ✓ ¿Hay locales ya generados?
- ✓ ¿console-data hace algo con locales?

### Sobre Warnings:

- ✓ ¿Los warnings de Perl son normales?
- ✓ ¿Indican problema real o ausencia esperada?
- ✓ ¿apt update genera warnings?
- ✓ ¿locale-gen genera warnings?

### Sobre Próxima Configuración:

- ✓ ¿Necesitamos generar es_ES.UTF-8 desde cero?
- ✓ ¿Hay que cambiar configuración existente?
- ✓ ¿Podemos aprovechar algo ya configurado?

---

## 🔍 ANÁLISIS DEL REPORTE

### Escenario A: Sistema Limpio

```
/etc/default/locale: NO EXISTE
/etc/locale.gen: todos comentados
/usr/lib/locale/: vacío o solo C/POSIX
locale command: todas variables = POSIX
```

**Conclusión**: Sistema sin locale configurado (esperado)

**Acción**: Configurar es_ES.UTF-8 desde cero sin preocupaciones

### Escenario B: C.UTF-8 Configurado

```
/etc/default/locale: LANG=C.UTF-8
/etc/locale.gen: C.UTF-8 habilitado
/usr/lib/locale/: C.UTF-8 generado
locale command: LANG=C.UTF-8
```

**Conclusión**: Debootstrap configura C.UTF-8 minimal

**Acción**: Cambiar de C.UTF-8 a es_ES.UTF-8

### Escenario C: Configuración Parcial

```
/etc/default/locale: EXISTE pero vacío
/etc/locale.gen: en_US.UTF-8 habilitado
/usr/lib/locale/: en_US.UTF-8 generado
locale command: variables mezcladas
```

**Conclusión**: Configuración inconsistente

**Acción**: Limpiar y reconfigurar apropiadamente

---

## 🚀 DESPUÉS DE LA INVESTIGACIÓN

### Paso 1: Analizar Reporte

```bash
cat locale-investigation-report.txt

# Buscar secciones clave:
# - ¿Existe /etc/default/locale?
# - ¿Qué dice locale command?
# - ¿Hay warnings?
```

### Paso 2: Diseñar Solución

Basado en resultados reales, modificar `modules/03-configure-base.sh`:

```bash
# Ejemplo: Si sistema está limpio
# → Configurar desde cero

# Ejemplo: Si hay C.UTF-8
# → Cambiar a es_ES.UTF-8

# Ejemplo: Si hay config parcial
# → Limpiar y reconfigurar
```

### Paso 3: Documentar Decisión

Crear documento explicando:
- Estado encontrado
- Por qué elegimos esta solución
- Qué hace exactamente el código

### Paso 4: Eliminar Este Módulo

```bash
rm modules/02.5-investigate-locale.sh
```

Una vez tengamos la solución correcta, no necesitamos investigar más.

---

## 💡 FILOSOFÍA

### Por Qué Este Enfoque:

**MAL:**
```
1. Asumir estado del sistema
2. Escribir código basado en suposiciones
3. Probar y ver qué falla
4. Aplicar "fixes" sin entender
```

**BIEN:**
```
1. Investigar estado real del sistema ← ESTE MÓDULO
2. Entender qué hace debootstrap
3. Diseñar solución basada en datos
4. Implementar con confianza
```

### Trabajo en Equipo:

```
TU PARTE:
1. Ejecutar este módulo
2. Compartir reporte
3. Describir qué ves

MI PARTE:
1. Analizar datos reales
2. Diseñar solución apropiada
3. Documentar el "por qué"
4. Implementar correctamente
```

---

## 📋 CHECKLIST

Después de ejecutar el módulo:

- [ ] Reporte generado en `locale-investigation-report.txt`
- [ ] Revisar sección 1: Archivos de configuración
- [ ] Revisar sección 4: Salida de `locale`
- [ ] Revisar sección 8: Warnings de apt update
- [ ] Revisar sección 9: Warnings de locale-gen
- [ ] Anotar observaciones y compartir
- [ ] Diseñar solución basada en datos
- [ ] Implementar en módulo 03
- [ ] **Eliminar este módulo 02.5**

---

## 🎯 OBJETIVOS

### Corto Plazo:
- ✓ Entender estado real después de debootstrap
- ✓ Identificar qué está/no está configurado
- ✓ Ver warnings reales en contexto

### Medio Plazo:
- ✓ Diseñar configuración apropiada
- ✓ Documentar decisiones
- ✓ Implementar solución robusta

### Largo Plazo:
- ✓ Eliminar este módulo temporal
- ✓ Tener configuración que funciona
- ✓ Entender el "por qué" de cada línea

---

<div align="center">

**Módulo 02.5 - Investigación Temporal**

Entender antes de configurar

"Data-driven solutions > Guesswork"

**Este módulo se eliminará después de tener los datos necesarios**

</div>
