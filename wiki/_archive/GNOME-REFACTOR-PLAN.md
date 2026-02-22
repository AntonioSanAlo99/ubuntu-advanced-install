# PLAN DE REFACTORIZACIÓN GNOME

## PROBLEMA ACTUAL

```
Módulo 10:  Mezcla esencial + opciones
Módulo 10b: Opciones de memoria (interactivo)
Módulo 10c: Opciones de personalización (interactivo)
```

**Problemas:**
- Módulo 10 llama a 10b y 10c (acoplamiento)
- No está claro qué es esencial vs opcional
- Scripts de primer login mezclados con instalación

## PROPUESTA: SEPARACIÓN CLARA

### ESENCIAL (no negociable para GNOME funcional)

```
Módulo 10: install-gnome-core.sh
├─ GNOME Shell + Session + Settings
├─ GDM3
├─ Terminal + Nautilus
├─ Utilidades básicas (calculator, logs, font-viewer, baobab)
├─ Extensiones necesarias (appindicator, ding, ubuntu-dock)
├─ Eliminar snapd (decisión de diseño del instalador)
└─ systemd-oomd (prevención OOM)
```

### PERSONALIZACIÓN (decisiones del usuario)

```
Módulo 10-user-config.sh (nuevo)
├─ Tema de iconos (elementary)
├─ Fuentes (Ubuntu + JetBrainsMono)
├─ Apps ancladas (Chrome + Nautilus)
└─ Se ejecuta en primer login
```

### OPTIMIZACIÓN (decisiones del usuario)

```
Módulo 10-optimize.sh (refactor de 10b)
├─ Prompt: ¿Optimizar memoria? [s/n]
├─ Si sí:
│   ├─ Tracker [s/n]
│   ├─ Animaciones [s/n]
│   ├─ Evolution DS [s/n]
│   └─ gnome-software (siempre)
└─ Se ejecuta durante instalación
```

### TEMA (decisiones del usuario)

```
Módulo 10-theme.sh (refactor de 10c)
├─ Prompt: ¿Aplicar tema transparente? [s/n]
├─ Si sí:
│   ├─ Instalar user-theme
│   ├─ Crear Adwaita-Transparent
│   └─ Activar en primer login
└─ Se ejecuta durante instalación
```

## NUEVA ESTRUCTURA

```
modules/
├── 10-install-gnome-core.sh       # ESENCIAL
├── 10-user-config.sh              # PERSONALIZACIÓN (primer login)
├── 10-optimize.sh                 # OPTIMIZACIÓN (interactivo)
└── 10-theme.sh                    # TEMA (interactivo)
```

## FLUJO DE EJECUCIÓN

```
install.sh
    ↓
[Usuario selecciona GNOME]
    ↓
10-install-gnome-core.sh           # Siempre se ejecuta
    ↓
[Prompt: ¿Optimizar memoria?]
    ↓ (si)
10-optimize.sh                     # Opcional
    ↓
[Prompt: ¿Tema transparente?]
    ↓ (si)
10-theme.sh                        # Opcional
    ↓
10-user-config.sh                  # Siempre (crea script primer login)
    ↓
[Resto de instalación]
    ↓
[Primer boot + login]
    ↓
/etc/profile.d/gnome-user-config.sh ejecuta
```

## BENEFICIOS

✅ **Claridad**: Cada módulo tiene un propósito único
✅ **Mantenibilidad**: Cambios en tema no afectan core
✅ **Testeable**: Probar core sin tema
✅ **Flexible**: Fácil añadir más opciones
✅ **Sin acoplamiento**: Módulos independientes

## SCRIPTS DE PRIMER LOGIN

Actualmente: 1 script hace todo
Propuesta: Separar por responsabilidad

```
/etc/profile.d/
├── 10-gnome-user-config.sh        # Tema iconos + fuentes + apps (siempre)
└── 11-gnome-theme-apply.sh        # Tema shell + extensiones (si usuario eligió)
```

Cada script:
- Tiene su propio marker
- Puede ejecutarse independientemente
- Se puede reconfigurar sin afectar otros
