# Limitaciones de chroot

## Problema

Cuando instalamos con `debootstrap` + `arch-chroot`, algunos comandos fallan porque necesitan servicios corriendo (systemd, D-Bus, etc.) que no están disponibles en el entorno chroot.

## Comandos que NO Funcionan en chroot

### ❌ localectl

```bash
localectl set-locale LANG=es_ES.UTF-8
# ERROR: Failed to connect to bus: No such file or directory
```

**Causa:** Necesita systemd-localed corriendo

**Solución:** No usar. En su lugar, editar archivos directamente:
```bash
# Funciona en chroot
echo 'LANG=es_ES.UTF-8' > /etc/default/locale
update-locale LANG=es_ES.UTF-8
```

### ❌ systemctl enable

```bash
systemctl enable gdm3
# ERROR: System has not been booted with systemd
```

**Causa:** Necesita systemd como PID 1

**Solución:** Crear symlinks manualmente:
```bash
# En lugar de systemctl enable gdm3
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/display-manager.service
```

### ❌ gsettings

```bash
gsettings set org.gnome.desktop.interface icon-theme 'elementary'
# ERROR: No D-Bus daemon running
```

**Causa:** Necesita D-Bus + sesión de usuario

**Solución:** Ejecutar en primer login del usuario, no en chroot:
```bash
# Script en /etc/profile.d/
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
    gsettings set org.gnome.desktop.interface icon-theme 'elementary'
fi
```

### ⚠️ locale-gen (warnings de Perl)

```bash
locale-gen
perl: warning: Setting locale failed.
perl: warning: Please check that your locale settings:
```

**Causa:** Perl intenta usar el locale que estamos generando

**Es normal:** Son warnings, no errores. El locale se genera correctamente.

**No hacer nada:** Los warnings desaparecen después del primer boot.

## Comandos que SÍ Funcionan en chroot

### ✅ Gestión de archivos

```bash
cat > /etc/default/locale << EOF
LANG=es_ES.UTF-8
EOF
```

### ✅ locale-gen

```bash
locale-gen  # Warnings OK
```

### ✅ update-locale

```bash
update-locale LANG=es_ES.UTF-8
```

### ✅ dpkg-reconfigure

```bash
dpkg-reconfigure -f noninteractive locales
dpkg-reconfigure -f noninteractive keyboard-configuration
```

### ✅ setupcon

```bash
setupcon -k --force
```

### ✅ apt

```bash
apt-get install package
```

### ✅ useradd / passwd

```bash
useradd -m usuario
echo "usuario:password" | chpasswd
```

## Soluciones Implementadas

### Módulo 03: Locales y Teclado

**Antes (incorrecto):**
```bash
localectl set-locale LANG=es_ES.UTF-8  # ❌ Falla en chroot
```

**Después (correcto):**
```bash
# Generar locale
locale-gen

# Configurar archivo directamente
cat > /etc/default/locale << EOF
LANG=es_ES.UTF-8
LANGUAGE=es_ES:es
EOF

# Usar comando Ubuntu oficial
update-locale LANG=es_ES.UTF-8 LANGUAGE=es_ES:es
```

### Módulo 10: Habilitar servicios

**Antes (incorrecto):**
```bash
systemctl enable gdm3  # ❌ Falla en chroot
```

**Después (correcto):**
```bash
# Crear symlink manualmente
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/display-manager.service
```

**Equivalencia:**
```bash
# Estos dos comandos hacen lo mismo:
systemctl enable gdm3

# Es equivalente a:
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/multi-user.target.wants/gdm3.service
```

### Módulo 10-user-config: Configuración GNOME

**Solución:** Script en `/etc/profile.d/` que se ejecuta en primer login:

```bash
# NO en chroot
if [ -n "$DBUS_SESSION_BUS_ADDRESS" ] && [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
    gsettings set org.gnome.desktop.interface icon-theme 'elementary'
fi
```

## Estructura de Symlinks systemd

### Qué hace systemctl enable

```bash
systemctl enable servicio.service
```

Crea un symlink de:
```
/lib/systemd/system/servicio.service
```

A:
```
/etc/systemd/system/TARGET.wants/servicio.service
```

Donde `TARGET` es el target donde se activa el servicio (multi-user, graphical, etc.)

### Targets comunes

```bash
# multi-user.target (modo texto)
/etc/systemd/system/multi-user.target.wants/

# graphical.target (modo gráfico)
/etc/systemd/system/graphical.target.wants/

# default.target (por defecto)
/etc/systemd/system/default.target.wants/
```

### Display Manager

```bash
# Caso especial: display manager
ln -sf /lib/systemd/system/gdm3.service \
       /etc/systemd/system/display-manager.service
```

Systemd busca `display-manager.service` para iniciar el entorno gráfico.

## Verificar después del Primer Boot

```bash
# Verificar que servicios están habilitados
systemctl list-unit-files --state=enabled

# Verificar locale
locale

# Verificar teclado
localectl status
```

## Referencias

- [systemd.unit - symlinks](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)
- [arch-chroot](https://wiki.archlinux.org/title/Chroot)
- [Ubuntu Locales](https://wiki.ubuntu.com/UbuntuDevelopment/Internationalisation)
