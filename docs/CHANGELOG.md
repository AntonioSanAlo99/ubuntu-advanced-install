# Changelog — ubuntu-advanced-install

## [Sesión 15b] — 2026-03-01 — Actualización CSS tema Adwaita-Transparent

### Cambiado
- **`modules/10-theme.sh`**: CSS del tema reemplazado por versión revisada. Cambios respecto al CSS anterior: paleta unificada a `rgba(36,36,36,X)` en lugar de `rgba(0,0,0,X)`, cobertura extendida (calendario completo, notificaciones apiladas, widgets de fecha), `transition-duration: 100ms` añadido al hover de `.datemenu-today-button` (faltaba), estados `:focus` añadidos a `.events-button`, `.world-clocks-button` y `.weather-button`, `!important` eliminado de `.quick-toggle-menu` (innecesario con el selector actual), comentarios en selectores no estándar (`:second-in-stack`, `:lower-in-stack`) y en la opacidad reducida del dock.

### Añadido
- **`THEME-SUGGESTIONS.txt`** en la raíz: documento con 6 sugerencias de mejora futura para el tema, ordenadas por prioridad, para aplicar tras testear el resultado visual en pantalla.



### Seguridad
- **`03-configure-base.sh`**: Las contraseñas de usuario y root ya no se pasan como variables expandidas en heredocs. Ahora se envían via `printf | chpasswd` desde el host, eliminando su exposición en `ps aux` y `/proc/*/environ` durante la instalación.
- **`install.sh`**: Añadida limpieza automática de `config.env` al finalizar la instalación (`full_interactive_install` pregunta al usuario; `full_automatic_install` lo elimina siempre). El archivo se sobreescribe con datos aleatorios antes de borrarse para dificultar recuperación forense.

### Corregido
- **`00-check-dependencies.sh`**: Añadido `set -e` (faltaba en el único módulo CORE que no lo tenía).
- **`install.sh` — `--dry-run`**: El flag ya no acepta silenciosamente la ejecución. Ahora informa que la funcionalidad no está implementada y sale, evitando que el usuario crea que está en modo simulación cuando en realidad no lo está.
- **`install.sh` — menú**: Las opciones 30, 32, 33 del menú ahora indican explícitamente a qué módulo invocan (`→ módulo 21-optimize-laptop`, etc.) para evitar confusión entre número de menú y número de módulo.

### Estructura
- **`modules/archive/`**: Creado subdirectorio para módulos retirados del flujo principal. Movidos 9 archivos: versiones OLD, módulos huérfanos (`17-install-wine`, `20-optimize-performance`, `21-laptop-advanced`, `03-install-firmware`, `02.5-investigate-locale`). Añadido `README.md` explicando cada uno.



### Corregido

#### `10-theme.sh` — Panel superior: fondo negro detrás del texto del reloj

**Causa:** la sesión anterior añadió reglas sobre `.panel-button` que
interferían con los elementos interiores del panel, creando un fondo
visible detrás del texto. El panel solo debe tener `background-color`
en `#panel` — los hijos heredan transparent del tema base.

**Corrección:** `#panel` solo tiene `background-color: rgba(0,0,0,0.40)`.
`#panel .panel-button` con `transparent` explícito en estado normal y
`rgba(255,255,255,0.10)` solo en hover — sin afectar el texto del reloj.

#### `10-theme.sh` — Quick settings: opacidad igualada al panel (0.40)

Cambiado de `0.55` a `0.40` en `.quick-settings-box` y `.quick-settings`
para coherencia visual con el panel superior.

#### `10-theme.sh` — Quick settings: botones de sistema sin modificación

Eliminadas las reglas de `border-radius` y `background-color` sobre
`.quick-settings-system-item .icon-button` y `.button` — los botones
mantienen su forma y estilo original del tema Yaru.
Solo se mantiene `background-color: transparent` en el contenedor
`.quick-settings-system-item` para eliminar el rectángulo de fondo.

#### `10-theme.sh` — Appgrid: fondo transparente

Todas las opacidades del overview llevadas a `transparent`.
El fondo homogéneo opaco que se veía era `.app-grid` y
`.apps-grid-container` que no estaban correctamente sobreescritos.

#### `10-theme.sh` — Appgrid: workspaces horizontales ocultos

`.page-indicators` y `.page-indicator` con `opacity:0`, `height:0`,
`margin:0` y `padding:0` — elimina los puntos de paginación de workspace
del overview sin afectar la funcionalidad del grid.

#### `10-theme.sh` — Carpetas: color más claro con transparencia homogénea

Cambiado de `rgba(0,0,0,0.55)` a `rgba(255,255,255,0.12)` con borde
`rgba(255,255,255,0.10)` — las carpetas son visualmente más claras que
el fondo transparente del overview y coherentes con el tema.

#### `10-theme.sh` — Notificaciones: border-radius aplicado al cuadro interior

`.message-list .message` con `border-radius: 12px` — cada notificación
individual tiene esquinas redondeadas.

---

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


---

# Changelog — ubuntu-advanced-install

## [Sesión 16] — 2026-03-08 — Bugfix: 5 bugs corregidos

### Corregido

#### `16-configure-gaming.sh` — BUG CRÍTICO: VRR/HDR nunca se activaba

**Causa:** el heredoc interno `<< 'DESKEOF'` tenía comillas simples, lo que
impedía la expansión de `$FEATURES`. El archivo `.desktop` generado contenía
el literal `$FEATURES` en la línea `Exec=`, haciendo que `gsettings` fallara
silenciosamente. VRR (y HDR en GNOME ≥ 48) nunca se habilitaban en el
primer login.

**Corrección:** cambiado a `<< DESKEOF` (sin comillas). Las variables internas
del chroot (`\$USERNAME`) siguen escapadas. Se añadió comentario explicando
la distinción entre variables del host y del chroot en heredocs anidados.

#### `10-install-gnome-core.sh` — Sin `set -e`

**Causa:** el módulo carecía de `set -e`, por lo que un fallo de `apt` durante
la instalación de GNOME (red caída, disco lleno, paquete no encontrado) dejaba
la instalación a medias sin ningún error visible.

**Corrección:** añadido `set -e` tras el shebang.

#### `24-security-hardening.sh` — `dpkg-reconfigure -plow` interactivo y duplicado

**Causa:** el módulo instalaba `unattended-upgrades` y ejecutaba
`dpkg-reconfigure -plow`, que lanza preguntas interactivas de baja prioridad.
Esto podía colgar la instalación desatendida. Además, si el módulo 06 ya había
configurado las actualizaciones automáticas, la instalación era duplicada e
innecesaria.

**Corrección:** instalación condicional (solo si no existe
`/etc/apt/apt.conf.d/20auto-upgrades`), con `DEBIAN_FRONTEND=noninteractive`
y `-pcritical` en `dpkg-reconfigure` para evitar cualquier prompt.

#### `06-configure-auto-updates.sh` — `NOTIFY_RELEASES` hardcodeado a `"S"`

**Causa:** la variable `NOTIFY_RELEASES` se asignaba directamente a `"S"` en
el código, ignorando cualquier valor en `config.env` o entorno. Nunca se podía
desactivar la notificación de nuevas versiones sin editar el módulo.

**Corrección:** la variable ahora se respeta si viene de `config.env`; solo
se pregunta interactivamente si no está definida. Añadida a `config.env.example`
con documentación.

#### `30-verify-system.sh` — `check_fail()` sin tracking de errores

**Causa:** `check_fail()` solo imprimía `"✗ mensaje"` pero no registraba el
error ni modificaba el código de salida del script. Una instalación con kernel
faltante o GRUB roto terminaba con `exit 0`.

**Corrección:** añadido contador `VERIFY_ERRORS`. Al finalizar, si hay errores
el script sale con `exit 1` e imprime un resumen indicando cuántos checks
fallaron.


---

# Changelog — ubuntu-advanced-install

## [Sesión 17] — 2026-03-08 — Proton compartido + fix extension-manager

### Corregido

#### `16-configure-gaming.sh` — Proton no compartido entre Steam, Heroic y Faugus

**Problema:** el módulo usaba symlinks para intentar unificar los runners de
Proton, pero con dos fallos estructurales:

1. El symlink `~/.config/heroic/tools/proton/Steam → compatibilitytools.d`
   creaba una carpeta `Steam` dentro de la ruta de herramientas de Heroic,
   que ni Heroic ni ProtonUp-Qt esperan. ProtonUp-Qt instala runners
   directamente en `~/.config/heroic/tools/proton/NOMBRE_RUNNER/`, no en un
   subdirectorio `Steam`. El symlink rompía esa estructura.

2. Faugus no tenía ningún archivo `config.ini` escrito — solo se creaba el
   directorio. Sin `config.ini`, Faugus no sabe dónde buscar los runners y
   el usuario tiene que configurarlo manualmente tras el primer arranque.

**Corrección:** eliminados los symlinks. Arquitectura declarativa con ruta
canónica única `~/.local/share/Steam/compatibilitytools.d/`:

- **Steam**: la lee de forma nativa, sin configuración adicional.
- **ProtonUp-Qt**: instala en esa ruta (destino "Steam") y detecta Heroic
  automáticamente a través de `~/.config/heroic`.
- **Heroic**: `config.json` escrito antes del primer arranque con
  `customWinePaths` apuntando a `compatibilitytools.d`. Heroic escanea la
  ruta y lista todos los runners disponibles, incluidos los que instale
  ProtonUp-Qt posteriormente.
- **Faugus**: `config.ini` escrito antes del primer arranque con
  `proton-path` apuntando a la misma ruta.

Si Proton-CachyOS se descarga correctamente durante la instalación, su
nombre de directorio exacto se usa como `wineVersion` en Heroic y como
`default-runner` en Faugus. Si la descarga falla, los campos quedan vacíos
y el usuario solo necesita instalar un runner con ProtonUp-Qt — ambas apps
lo detectarán automáticamente sin reconfiguración.

### Documentado

#### `extension-manager` — Error "Permiso denegado" en `~/.local/share/gnome-shell`

El directorio `~/.local/share/gnome-shell` no existe en instalaciones
nuevas. extension-manager intenta crearlo pero falla si el padre tiene
permisos incorrectos (ocurre cuando root creó algún directorio padre
durante la instalación).

**Fix manual:** `mkdir -p ~/.local/share/gnome-shell` (sin sudo).


---

# Changelog — ubuntu-advanced-install

## [Sesión 19b] — 2026-03-08 — Thumbnailers: icoextract + appimage-thumbnailer (kem-a)

### Añadido

#### `12-install-multimedia.sh` — icoextract (thumbnailer .exe/.dll)

`icoextract` está disponible en los repositorios de Ubuntu desde 22.04 y se
instala con `apt`. Incluye `exe-thumbnailer` que registra automáticamente el
descriptor `.thumbnailer` en `/usr/share/thumbnailers/`.

Instalación system-wide obligatoria (no `pip --user`): el proceso de
thumbnailing corre con permisos del gestor de archivos y no tiene acceso a
`~/.local/lib/python*/site-packages/`. Confirmado en issue #8 del repositorio.

#### `12-install-multimedia.sh` — appimage-thumbnailer v4.0.0 (kem-a)

Binario C compilado que extrae el icono embebido en la sección `.DirIcon` del
AppImage sin ejecutarlo (seguro, a diferencia de otros thumbnailers que
ejecutan el AppImage para obtener el icono).

Instalación desde la release fija `v4.0.0` del repositorio `kem-a/appimage-thumbnailer`
con la URL proporcionada. Patrón: `wget` → `dpkg -i` → `apt-get install -f`
para resolver dependencias (GLib/GIO, GdkPixbuf, librsvg, Cairo) que dpkg no
gestiona automáticamente.

---



### Añadido

#### `modules/17-install-am.sh` — nuevo módulo para AM / AppMan

AM (Application Manager) extraído de `10-install-gnome-core.sh` a su propio
módulo independiente. Cambios respecto al código anterior:

- **Dependencias explícitas:** `curl`, `wget`, `git`, `zsync`, `binutils`,
  `xdg-utils` — instalados al inicio del módulo, no asumidos del entorno.
- **Descarga con timeout y nombre de archivo temporal explícito** (`/tmp/am-install.sh`)
  en lugar de `cd /tmp && wget ... INSTALL` — evita colisiones con otros scripts.
- **`AM_INSTALLED` como flag** — el resumen final distingue entre instalación
  correcta y fallida, con instrucciones de instalación manual en el caso de fallo.
- **MIME type idempotente** — solo escribe `appimage.xml` si no existe ya
  (puede haberlo escrito `10-install-gnome-core.sh`); `update-mime-database`
  es idempotente de todas formas.
- **Resumen con uso básico** — comandos `am -l`, `-i`, `-u`, `-R`, `-q` y
  cómo crear el alias `appman` para gestión por usuario.

#### `modules/10-install-gnome-core.sh` — eliminado bloque de AM

Eliminado el bloque de instalación de AM y AppManager GUI. Se mantiene
la infraestructura de AppImages (libfuse2, MIME type, `~/Applications/`)
con un comentario que referencia el módulo `17-install-am.sh`.

#### `install.sh` — menú opción 27, flujo automático `INSTALL_AM`

Añadida opción `27) AM / AppMan` al menú interactivo y `run_module "17-install-am"`
en el flujo automático condicionado a `INSTALL_AM=true`.

#### `config.env.example` — nueva variable `INSTALL_AM`

---



### Corregido

#### `12-install-multimedia.sh` — Spotify: restaurado `--ozone-platform=x11`

Spotify en Wayland nativo muestra una barra CSD azul (CEF) que no integra
con el tema de GNOME y no es eliminable desde fuera. Con `--ozone-platform=x11`
Spotify corre en XWayland y Mutter aplica Server-Side Decorations estándar
— la titlebar del sistema, coherente con el resto de aplicaciones.

El `sed` se corrige para preservar flags existentes (`--uri=%u`, etc.):
primero elimina cualquier `--ozone-platform=` previo, luego inserta el flag
justo tras `spotify` en la línea `Exec=`.

#### `10-user-config.sh` — Añadido `xwayland-native-scaling` a experimental-features

Sin esta feature, las apps que corren en XWayland (como Spotify con
`--ozone-platform=x11`) muestran texto borroso en monitores con escalado
fraccional (125%, 150%, etc.) porque XWayland usa el método de escaldo
legacy. Con `xwayland-native-scaling` activado el renderizado es nítido.

La feature se añade sin pisar valores existentes en `experimental-features`
(VRR/HDR pueden estar ya configurados por `16-configure-gaming.sh`). Se lee
el array actual con `gsettings get` y se inserta solo si no está presente.

---



### Corregido

#### `12-install-multimedia.sh` — Spotify mostraba doble titlebar

**Causa:** el flag `--ozone-platform=x11` forzaba Spotify a correr bajo
XWayland. En XWayland, Mutter aplica Server-Side Decorations (SSD) — la
barra de título del sistema de ventanas — mientras Spotify simultáneamente
dibuja su propia barra Client-Side (CSD). El resultado era una doble titlebar:
la barra gris del sistema encima de la barra propia de Spotify.

**Corrección:** eliminado el flag `--ozone-platform=x11`. Spotify corre ahora
en Wayland nativo. En Wayland nativo, Mutter no aplica SSD — el protocolo
Wayland no tiene server-side decorations obligatorias. Solo existe la barra
CSD de Spotify, sin duplicado.

La barra CSD de Spotify en Wayland (azul o gris según versión) no es
integrable con el tema de GNOME — es una limitación de CEF (Chromium
Embedded Framework) que usa Spotify, no de GNOME. No existe flag ni regla
externa que la elimine o la adapte al tema del sistema. Es una sola barra,
simplemente con estilo propio.

**Alternativa documentada en comentario:** si hay problemas de texto borroso
con escalado fraccional, añadir manualmente `--ozone-platform=x11` al
`.desktop` y activar `xwayland-native-scaling` en GNOME experimental features.

---



### Corregido

#### `10-user-config.sh` — `dynamic-workspaces=false` no tenía efecto

**Causa:** la configuración de workspaces solo existía en la capa dconf de
sistema (`/etc/dconf/db/local.d/00-gnome-installer`). dconf de sistema
establece *defaults* — valores que GNOME usa únicamente si el perfil del
usuario (`~/.config/dconf/user`) no tiene un valor propio para esa clave.

En una instalación nueva sin intervención del usuario funciona. Pero si el
usuario alguna vez ha abierto Ajustes → Multitarea (incluso sin cambiar nada,
solo abrir y cerrar la ventana), GNOME escribe el valor actual en el perfil
de usuario. A partir de ese momento ese valor tiene precedencia sobre el
default de sistema y `dynamic-workspaces` vuelve a `true`.

El changelog de Sesión 11 indicaba que las claves tendrían "ambas capas como
respaldo", pero la capa de gsettings nunca se escribió en `10-user-config.sh`
— se eliminó junto con el bloque `GNOMECFG` sin restituirse.

**Corrección:** añadidos tres `gsettings set` en `10-user-config.sh`
(primer login con D-Bus activo) que sobreescriben el perfil de usuario:

```bash
gsettings set org.gnome.mutter dynamic-workspaces false
gsettings set org.gnome.mutter workspaces-only-on-primary true
gsettings set org.gnome.desktop.wm.preferences num-workspaces 1
```

Con esto la configuración tiene dos capas independientes:
- **dconf sistema**: default para cualquier usuario nuevo creado después
- **gsettings primer login**: sobreescribe el perfil del usuario principal,
  garantizando el valor aunque el perfil dconf ya tenga un valor previo

---



### Corregido

#### `10-user-config.sh` y `12-install-multimedia.sh` — `NoDisplay=true` ignorado por GNOME

**Causa:** el método anterior añadía `NoDisplay=true` con `echo >>` al final
del archivo `.desktop`. Los `.desktop` de Totem y `software-properties-drivers`
tienen secciones adicionales tras `[Desktop Entry]` (por ejemplo
`[Desktop Action NewWindow]`, `[Desktop Action Play]`). La especificación
freedesktop.org exige que las claves de cada sección pertenezcan al grupo
en el que aparecen — una clave escrita después del último grupo queda fuera
de todos ellos y los parsers de GNOME la ignoran silenciosamente.
El resultado: `NoDisplay=true` no tenía efecto y las apps seguían visibles.

**Corrección:** reemplazado `echo "NoDisplay=true" >>` por:
```bash
sed -i '/^NoDisplay=/d' archivo.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' archivo.desktop
```
`sed /a` inserta la línea inmediatamente después de `[Desktop Entry]`,
garantizando que pertenece al grupo correcto independientemente de cuántas
secciones adicionales tenga el archivo.

El mismo fix se aplica al override mínimo creado cuando el `.desktop` no
existe: el `printf` ahora escribe `NoDisplay=true` como segunda línea
(tras `[Desktop Entry]`), no como última.

#### `10-user-config.sh` — Gestor de idioma ausente de la carpeta Sistema

**Causa:** `gnome-language-selector.desktop` (paquete `language-selector-gnome`,
instalado por defecto en Ubuntu) no estaba en la lista de apps de la carpeta
Sistema ni en la lista de ocultos. Aparecía suelto en el appgrid.

**Corrección:** añadido `gnome-language-selector.desktop` a la carpeta Sistema,
entre `nm-connection-editor.desktop` y `software-properties-gtk.desktop`.

---



### Corregido

#### `16-configure-gaming.sh` — ProtonUp-Qt instalado desde PPA inexistente

**Causa:** el módulo usaba `ppa:tlvince/protonup-qt` que no existe. ProtonUp-Qt
no tiene PPA oficial ni paquete .deb en ningún repositorio. Las únicas
distribuciones oficiales son Flatpak (Flathub) y AppImage (GitHub releases).
El PPA anterior producía un error silencioso y ProtonUp-Qt nunca se instalaba.

**Corrección:** instalación como AppImage descargado desde GitHub releases API:
- AppImage en `/opt/protonup-qt/ProtonUp-Qt.AppImage`
- Wrapper ejecutable en `/usr/local/bin/protonup-qt`
- `.desktop` en `/usr/share/applications/protonup-qt.desktop`

Se usa AppImage nativo (no Flatpak) porque Steam está instalado como paquete
nativo y ProtonUp-Qt necesita acceder al mismo filesystem para autodetectar
`~/.local/share/Steam/compatibilitytools.d` sin configuración adicional.
ProtonUp-Qt Flatpak usa sandbox y puede no detectar Steam nativo correctamente.

#### `16-configure-gaming.sh` — Heroic no encontraba runners de Steam

**Causa:** Heroic busca `~/.local/share/Steam/steamapps/libraryfolders.vdf`
para autodetectar la Steam library. Sin ese archivo, loguea
`Unable to load Steam Libraries, libraryfolders.vdf not found` y no lista
los runners instalados en `compatibilitytools.d`, aunque `customWinePaths`
apunte al directorio correcto.

**Corrección:** se crea `~/.local/share/Steam/steamapps/libraryfolders.vdf`
con estructura VDF mínima válida durante la instalación. Heroic lo lee al
arrancar y detecta los runners automáticamente sin intervención del usuario.

#### `16-configure-gaming.sh` — `defaultInstallPath` faltaba en config.json de Heroic

**Causa:** el config.json de Heroic no incluía `defaultInstallPath`, por lo que
Heroic usaba su ruta interna por defecto (`~/Games/Heroic` en versiones antiguas
era `~/legendary`). Esto causaba confusión al buscar juegos instalados.

**Corrección:** añadido `"defaultInstallPath": "/home/USER/Games/Heroic"` en
`defaultSettings`, coherente con `defaultWinePrefix`.

#### `16-configure-gaming.sh` — `wineVersion.name` en Heroic sin prefijo "Proton -"

**Causa:** el campo `name` en `wineVersion` se rellenaba con el nombre del
directorio del runner (`proton-cachyos-9.0-1`) sin el prefijo que Heroic
usa para mostrar runners de tipo Proton. Heroic muestra el nombre tal cual,
lo que era inconsistente con cómo aparecen otros runners en la UI.

**Corrección:** el campo `name` ahora incluye el prefijo `"Proton - "`:
`"name": "Proton - proton-cachyos-9.0-1"`. Confirmado en logs reales de
Heroic (issue #1345): `"name": "Proton - GE-Proton7-18"`.

---



### Corregido

#### `10-install-gnome-core.sh` — extension-manager falla al instalar extensiones

**Causa:** `~/.local/share/gnome-shell/extensions` no existía tras la
instalación. extension-manager intenta crearlo en el primer uso, pero si
algún directorio padre (`~/.local` o `~/.local/share`) fue creado por root
durante la instalación, el intento falla con "Permiso denegado" aunque el
usuario tenga su sesión activa.

**Corrección:** el directorio se crea durante la instalación, en el mismo
bloque donde ya se crean otros directorios de usuario (keyring). Se aplica
`chown -R` con el propietario correcto. También se crea en `/etc/skel/` para
que cualquier usuario creado después de la instalación lo tenga desde el
primer login.
