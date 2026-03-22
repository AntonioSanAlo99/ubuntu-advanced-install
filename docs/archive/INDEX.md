# Archivos Antiguos - Histórico de Cambios Importantes

Este directorio contiene versiones antiguas de archivos que fueron modificados significativamente durante el desarrollo.

---

## 📋 Índice de Archivos

### `README-v1.0.0.md`
**Fecha**: 22 Feb 2024  
**Razón del cambio**: Reescritura enfocada en rendimiento y comparativas  
**Cambios principales**:
- README anterior más técnico y estructural
- Nuevo README enfocado en benchmarks y rendimiento
- Añadidas comparativas de FPS y batería
- Créditos actualizados (autor + Claude Sonnet 4.5)

**Ver cambios**: Comparar con `../README.md` actual

---

### `README.md.old`
**Fecha**: 21 Feb 2024  
**Razón del cambio**: Actualización de versiones de Ubuntu y reestructuración  
**Cambios principales**:
- Versiones de Ubuntu corregidas (eliminadas versiones inexistentes)
- GNOME sin versión específica
- Roadmap movido a `docs/ROADMAP.md`

**Ver cambios**: Comparar con versiones intermedias

---

### `README.old.md`
**Fecha**: 18 Feb 2024  
**Razón del cambio**: Primera versión del README  
**Cambios principales**:
- Estructura inicial del README
- Primera documentación del proyecto

**Ver cambios**: Versión muy antigua, comparar con versiones intermedias

---

### `16-configure-gaming.sh.old`
**Fecha**: 20 Feb 2024  
**Razón del cambio**: Añadido soporte VRR/HDR y animaciones opcionales  
**Cambios principales**:
- Añadido soporte VRR (Variable Refresh Rate)
- Añadido soporte HDR (High Dynamic Range)
- Animaciones GNOME ahora opcionales (antes automáticas)
- Generación de archivo de configuración `gaming-display-config.txt`

**Ver cambios**: Comparar con `../modules/16-configure-gaming.sh` actual

---

## 🔍 Cómo Usar Este Directorio

### Ver diferencias entre versiones:
```bash
# Comparar README antiguo con actual
diff docs/old/README.md.old README.md

# Comparar módulo gaming antiguo con actual
diff docs/old/16-configure-gaming.sh.old modules/16-configure-gaming.sh
```

### Restaurar versión antigua (si necesario):
```bash
# CUIDADO: Esto sobrescribe el archivo actual
cp docs/old/README.md.old README.md
```

---

## 📝 Política de Archivos Antiguos

### Cuándo mover archivo a `docs/old/`:

1. **Cambios estructurales grandes** (>50% del archivo modificado)
2. **Funcionalidad completamente reescrita**
3. **Cambios que rompan compatibilidad hacia atrás**
4. **Antes de refactorización mayor**

### Nombrado de archivos:
```
<nombre-original>.<fecha-opcional>.<extension>.old

Ejemplos:
- README.md.old
- 16-configure-gaming.sh.old
- install.2024-02-20.sh.old
```

### Qué NO incluir:
- Archivos de backup automático (`.bak`, `~`)
- Archivos temporales
- Cambios menores (typos, formato)

---

## 📊 Histórico de Versiones Importantes

| Versión | Fecha | Archivo | Cambio Principal |
|---------|-------|---------|------------------|
| v1.0.1 | Feb 22 2024 | install.sh | Eliminadas validaciones hardware |
| v1.0.0 | Feb 21 2024 | 16-configure-gaming.sh | VRR/HDR + animaciones opcionales |
| v1.0.0 | Feb 21 2024 | 10-install-gnome-core.sh | Workspaces + tiempo pantalla configurables |
| v1.0.0 | Feb 21 2024 | README.md | Versiones corregidas + roadmap separado |
| v0.9.x | Feb 20 2024 | 16-configure-gaming.sh | Primera versión gaming module |

---

## 🗂️ Estructura Recomendada

```
docs/old/
├── INDEX.md                          ← Este archivo
├── README.md.old                     ← Versión anterior README
├── README.old.md                     ← Versión muy antigua README
├── 16-configure-gaming.sh.old        ← Gaming module sin VRR/HDR
└── [futuros archivos antiguos]
```

---

## 💡 Consejos

### Antes de cambio importante:
```bash
# 1. Hacer copia del archivo actual
cp modules/mi-modulo.sh docs/old/mi-modulo.$(date +%Y%m%d).sh.old

# 2. Documentar cambio en CHANGELOG.md

# 3. Hacer el cambio

# 4. Actualizar este INDEX.md
```

### Recuperar funcionalidad antigua:
```bash
# Ver qué cambió
diff docs/old/archivo.old modules/archivo.sh

# Extraer solo la función que necesitas
# (editar manualmente)
```

---

## 🔄 Limpieza Periódica

**Cada 6 meses** revisar archivos en `docs/old/`:
- Eliminar versiones muy antiguas (>1 año)
- Mantener solo versiones pre-cambio importante
- Archivar en Git history si es necesario

---

**Última actualización**: 22 Feb 2024  
**Archivos actuales**: 3  
**Espacio usado**: ~40KB

---

<div align="center">

[⬆ Volver a docs](../) · [📖 README Principal](../../README.md) · [📋 CHANGELOG](../../CHANGELOG.md)

</div>

## Archivos adicionales archivados

- **STRUCTURE-historical.txt** — Árbol de directorios de una versión anterior del proyecto. Reemplazado por `docs/ORGANIZATION.md`.
- **THEME-SUGGESTIONS.txt** — Sugerencias de mejora del CSS del tema Adwaita-Transparent generadas en sesión 15b. Pendiente de evaluar y aplicar antes de eliminar.
