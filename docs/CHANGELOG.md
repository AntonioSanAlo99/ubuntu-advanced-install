# Changelog — ubuntu-advanced-install

## [Sesión 13] — 2026-02-25 — CSS: transparencia en diálogo de carpetas del appgrid

### Corregido

#### `10-theme.sh` — Carpetas del appgrid sin transparencia

**Problema:** al abrir una carpeta en el appgrid, el diálogo expandido mostraba
fondo sólido oscuro sin transparencia. El selector `.app-folder-popup` que
teníamos solo afecta al estado contraído (el icono de carpeta antes de abrirse).
El diálogo expandido que se ve al hacer clic usa `.app-folder-dialog`.

**Corrección:** añadidos los selectores correctos para GNOME 46:
- `.app-folder-dialog`: contenedor principal del diálogo — `rgba(0,0,0,0.55)`
- `.app-folder-dialog-container`: área interior — `transparent`
- `.app-folder-dialog .app-folder-dialog-title`: título — `transparent`
- `.app-folder .app-well-grid`: grid de iconos interior — `transparent`

Se mantienen los selectores `.app-folder-popup` y `.app-folder-popup-title`
para compatibilidad con versiones anteriores de GNOME Shell.

---

# Changelog — ubuntu-advanced-install

## [Sesión 12] — 2026-02-25 — CSS de tema: quick settings, overview, bloqueo y GDM

### Corregido

#### `10-theme.sh` — Quick settings: rectángulo visible en fila de botones superiores

**Problema:** `.quick-settings-system-item` (la fila con los botones de captura
de pantalla, ajustes, bloqueo y apagar) tenía su propio `background-color`
heredado del tema Yaru que creaba un rectángulo visible con fondo distinto
al resto del panel, rompiendo la coherencia visual.

**Corrección:** `.quick-settings-system-item` ahora tiene `background-color: transparent`
y `box-shadow: none`. Los botones individuales dentro de esa fila tienen su
propio hover sutil `rgba(255,255,255,0.08)`. El contenedor exterior se controla
con `.quick-settings-box` además de `.quick-settings` para cubrir ambas
versiones del selector según la versión de GNOME Shell.

#### `10-theme.sh` — Appgrid: fondo no transparente

**Problema:** `.apps-scroll-view` no es el selector correcto en GNOME 46.
El fondo del overview de aplicaciones lo controla `.app-grid` y `.apps-grid-container`.

**Corrección:** añadidos `.app-grid` y `.apps-grid-container` con `transparent`.
`.overview-controls`, `#overview` y `.overview` también forzados a `transparent`.

#### `10-theme.sh` — Vista previa del workspace: borde y fondo visibles

**Problema:** la miniatura del escritorio activo en el overview tenía fondo y
borde propios visibles. Los selectores `.workspace-thumbnail` y
`.workspace-background` no estaban en el CSS.

**Corrección:** añadidos `.workspace-thumbnails-box`, `.workspace-thumbnail`,
`.workspace-thumbnail-indicator`, `.workspace-overview`, `.window-picker`
y `.workspace-background` todos con `transparent`, `border: none` y
`box-shadow: none`.

#### `10-theme.sh` — Pantalla de bloqueo: blur → transparente

**Corrección:** `#lockDialogGroup` con `background-color: transparent` y
`background-image: none`. `.unlock-dialog` con fondo semidark `rgba(0,0,0,0.45)`
para mantener legibilidad del widget de contraseña.

### Añadido

#### `10-theme.sh` — CSS de GDM (pantalla de login)

El CSS de usuario (`~/.themes/`) no aplica en GDM porque corre en un proceso
separado con su propio usuario. El override se instala en
`/usr/share/gnome-shell/extensions/gdm-transparency/` con `stylesheet.css`
y `metadata.json`. El mecanismo detecta automáticamente la ruta del CSS de
GDM en Ubuntu 24.04 (Yaru).

#### `10-user-config.sh` — Desactivar blur de pantalla de bloqueo

`gsettings set org.gnome.desktop.screensaver picture-opacity 100` — elimina
el efecto de desvanecimiento del fondo en la pantalla de bloqueo.

### Pendiente para prueba en sistema real
Los selectores CSS de GNOME Shell no son documentación oficial — pueden
variar entre versiones menores. Los selectores añadidos están basados en
el tema Yaru de Ubuntu 24.04 (GNOME 46). Si algún selector no tiene efecto
en la próxima prueba, reportar cuál y se ajusta.

---

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
