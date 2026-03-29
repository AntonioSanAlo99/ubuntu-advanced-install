# Arquitectura de configuración GNOME

## El problema: gsettings necesita D-Bus

`gsettings` es la herramienta estándar para configurar GNOME. Internamente
escribe en la base de datos dconf del usuario (`~/.config/dconf/user`), pero
para hacerlo necesita un bus D-Bus de sesión activo.

Durante la instalación, los módulos se ejecutan dentro del chroot con
`arch-chroot`. En ese contexto:

- No hay sesión de usuario activa
- No hay D-Bus de sesión
- `gsettings set` falla silenciosamente sin modificar nada
- `dbus-launch gsettings set` falla porque no hay servidor de display

Cualquier `gsettings` ejecutado dentro del chroot es **código muerto**.

---

## La solución: dos capas según el contexto

La configuración GNOME del proyecto usa dos mecanismos distintos según
cuándo y dónde se necesita aplicar cada valor.

### Capa 1 — dconf de sistema (durante la instalación)

**Cuándo:** dentro del chroot, sin sesión gráfica, sin D-Bus  
**Dónde:** `10-install-gnome-core.sh`  
**Mecanismo:** archivos de texto en `/etc/dconf/db/local.d/`

dconf tiene una base de datos de sistema separada de la del usuario.
Se escribe con archivos `.ini` en `/etc/dconf/db/local.d/` y se compila
con `dconf update`. GNOME la lee al arrancar, antes de que el usuario
abra sesión. No necesita D-Bus.

Archivo de defaults del proyecto: `/etc/dconf/db/local.d/00-gnome-installer`

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

#### dconf locks

Un lock hace que una clave sea de **solo lectura para el usuario**. GNOME
puede intentar escribir sobre ella (por ejemplo, al mover apps en el
appgrid), pero la escritura falla silenciosamente y el valor configurado
se mantiene.

Archivo de locks: `/etc/dconf/db/local.d/locks/00-gnome-installer`

```
/org/gnome/shell/app-picker-layout
```

Solo `app-picker-layout` está bloqueado — el resto son defaults que
el usuario puede cambiar desde Ajustes si lo desea.

**Importante:** `dconf update` debe ejecutarse tras escribir los archivos
para compilar la base de datos binaria. Sin este paso los cambios no
tienen efecto.

---

### Capa 2 — gsettings de usuario (primer login)

**Cuándo:** primera sesión gráfica del usuario  
**Dónde:** `/usr/local/lib/ubuntu-advanced-install/gnome-first-login.sh`  
**Mecanismo:** script de autostart XDG con `gsettings` y `dconf write`

El script se registra en `/etc/xdg/autostart/gnome-first-login.desktop`
con `OnlyShowIn=GNOME;`. El gestor de sesión lo lanza automáticamente
en el primer login gráfico, cuando D-Bus está disponible.

El script espera activamente a que GNOME Shell esté listo:

```bash
_wait_for_shell() {
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if gdbus call --session \
            --dest org.gnome.Shell \
            --object-path /org/gnome/Shell \
            --method org.gnome.Shell.Eval "1" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempts=$(( attempts + 1 ))
    done
}
```

Tras confirmar que el shell responde, aplica extensiones, tema, tipografías,
dock y carpetas del appgrid — cosas que requieren sesión gráfica activa.

El script se autodestruye al completarse: elimina su propio `.desktop`
de autostart y escribe un marker en `~/.config/.gnome-user-configured`
para no ejecutarse de nuevo.

---

## Tabla de configuraciones por capa

| Configuración | Capa 1 (dconf sistema) | Capa 2 (gsettings usuario) | Lock |
|---|---|---|---|
| Workspace único fijo | ✅ | ✅ (respaldo) | No |
| Tiempo de uso desactivado | ✅ | ✅ (respaldo) | No |
| Appgrid orden alfabético | ✅ | — | **Sí** |
| Extensiones habilitadas | — | ✅ | No |
| Tema oscuro / iconos | — | ✅ | No |
| Tipografías | — | ✅ | No |
| Dock (comportamiento) | — | ✅ | No |
| Carpetas del appgrid | — | ✅ | No |
| Apps ancladas en dock | — | ✅ | No |
| Totem oculto del appgrid | — | ✅ (override .desktop) | No |

---

## Regla general para añadir nueva configuración

**¿La clave tiene valor por defecto que el sistema debe imponer siempre?**
→ Capa 1 (dconf sistema). Añadir a `00-gnome-installer` y ejecutar `dconf update`.

**¿El valor debe ser inamovible por el usuario?**
→ Añadir también a `locks/00-gnome-installer`.

**¿La configuración requiere que GNOME Shell esté corriendo?**  
(extensiones, tema de shell, `gnome-extensions enable`)  
→ Capa 2 únicamente (script de primer login).

**¿La configuración depende de preferencias del usuario?**  
→ Capa 2, sin lock en Capa 1.

---

## Errores comunes a evitar

### gsettings dentro del chroot

```bash
# MAL — falla silenciosamente, no hace nada
arch-chroot "$TARGET" /bin/bash << EOF
gsettings set org.gnome.mutter dynamic-workspaces false
EOF

# MAL — dbus-launch no funciona sin servidor de display
arch-chroot "$TARGET" /bin/bash << EOF
sudo -u $USERNAME dbus-launch gsettings set org.gnome.mutter dynamic-workspaces false
EOF

# BIEN — dconf de sistema, no necesita D-Bus
arch-chroot "$TARGET" /bin/bash << 'EOF'
cat > /etc/dconf/db/local.d/00-config << 'DCONF'
[org/gnome/mutter]
dynamic-workspaces=false
DCONF
dconf update
EOF
```

### sleep fijo para esperar GNOME Shell

```bash
# MAL — tiempo arbitrario, falla en hardware lento
sleep 3
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com

# BIEN — espera activa hasta que el shell responde
_wait_for_shell && gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
```

### (( var++ )) con set -e

```bash
# MAL — (( 0 )) evalúa a falso, set -e mata el script
(( counter++ ))

# BIEN — $(( )) nunca dispara set -e
counter=$(( counter + 1 ))
```
