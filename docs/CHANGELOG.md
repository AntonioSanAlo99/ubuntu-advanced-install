# Changelog — ubuntu-advanced-install

## [Sesión 11] — 2026-02-25 — Workspace y privacidad movidos a dconf de sistema

### Corregido

#### `10-install-gnome-core.sh` — gsettings dentro del chroot sin D-Bus

**Problema:** las configuraciones de workspace único y tiempo de uso de pantalla
se intentaban aplicar dentro del chroot mediante `gsettings` y `dbus-launch`,
sin sesión de sistema activa. Todos los comandos fallaban silenciosamente.
El bloque `GNOMECFG` era completamente código muerto.

**Solución:** eliminado el bloque `GNOMECFG` completo (preguntas interactivas,
`dbus-launch`, archivo de documentación `gnome-custom-config.txt`).

Las tres configuraciones GNOME que no necesitan D-Bus se consolidan en un
único bloque `DCONF_SYSTEM` con el archivo `/etc/dconf/db/local.d/00-gnome-installer`:

```ini
[org/gnome/shell]
app-picker-layout=@aa{sv} []

[org/gnome/mutter]
dynamic-workspaces=false
workspaces-only-on-primary=true

[org/gnome/desktop/wm/preferences]
num-workspaces=1

[org/gnome/desktop/privacy]
remember-app-usage=false
remember-recent-files=false
```

Lock en `/etc/dconf/db/local.d/locks/00-gnome-installer`:
solo `app-picker-layout` está bloqueado. El resto son defaults que
el usuario puede cambiar desde Ajustes si lo desea.

`dconf update` compila la base de datos al final del bloque.

**Antes:** un bloque GNOMECFG + un bloque DCONF_LOCK separado = código duplicado y parcialmente roto.
**Después:** un único bloque DCONF_SYSTEM limpio que funciona sin D-Bus.

### Arquitectura de configuración GNOME — dos capas

| Capa | Dónde | Cuándo | Requiere D-Bus |
|------|-------|--------|----------------|
| dconf sistema | `/etc/dconf/db/local.d/` | Durante instalación (chroot) | No |
| gsettings usuario | `gnome-first-login.sh` | Primer login gráfico | Sí |

Las claves de workspace y privacidad tienen ambas capas como respaldo.
Solo `app-picker-layout` está bloqueado a nivel de sistema.

---

# Changelog — ubuntu-advanced-install

## [Sesión 10] — 2026-02-25 — Appgrid: orden alfabético permanente con dconf lock

### Corregido

#### Appgrid — orden alfabético no persistía tras interacción del usuario

**Problema 1:** GNOME sobrescribe `app-picker-layout` cada vez que el usuario
interactúa con el grid (mueve apps, abre carpetas, cambia de página). El valor
`[]` que forzaba orden alfabético era válido en el primer render pero se
sobreescribía inmediatamente con el orden de uso dinámico.

**Problema 2:** al sacar una app de una carpeta, GNOME la añadía al final del
grid en lugar de reincorporarla en su posición alfabética.

**Solución — dconf lock de sistema** en `10-install-gnome-core.sh`:

Dos archivos escritos dentro del chroot durante la instalación:

`/etc/dconf/db/local.d/00-appgrid` — valor por defecto del sistema:
```
[org/gnome/shell]
app-picker-layout=@aa{sv} []
```

`/etc/dconf/db/local.d/locks/00-appgrid` — lock de solo lectura:
```
/org/gnome/shell/app-picker-layout
```

Seguido de `dconf update` para compilar la base de datos del sistema.

**Efecto:** la clave queda bloqueada para el usuario. Cuando GNOME intenta
escribir el layout actualizado tras cada interacción, la escritura falla
silenciosamente. El valor `[]` se mantiene permanentemente, lo que hace que
GNOME recalcule el orden alfabéticamente en cada renderizado — incluyendo
apps recién liberadas de carpetas.

El lock sobrevive a reinicios, cambios de sesión y actualizaciones del sistema.

El `dconf write app-picker-layout` que existía en `gnome-first-login.sh`
ha sido eliminado — con la clave bloqueada esa escritura habría fallado
silenciosamente de todas formas.

---
