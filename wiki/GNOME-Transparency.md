# Transparencias en GNOME - Guía Completa

> **⚠️ IMPORTANTE:** El tema transparente (Método 3 abajo) es **totalmente opcional** y está **desactivado por defecto**. 
> 
> **Recomendación:** Usa Adwaita por defecto. Si quieres transparencias, usa **Just Perfection** (Método 2) en su lugar.

---

## Problema: CSS personalizado no funciona

GNOME Shell **no carga CSS personalizado automáticamente** sin una extensión. Los archivos CSS en `~/.local/share/gnome-shell/` son ignorados.

## Solución real: 3 métodos que SÍ funcionan

### ✅ Método 1: Ubuntu Dock (funciona automáticamente)

**Ya configurado por el instalador:**
```bash
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
```

**Resultado:** Dock con 15% de opacidad ✓

---

### ✅ Método 2: Just Perfection (recomendado para todo)

**Instalar extensión:**
1. Abrir "Gestor de extensiones" (Extension Manager)
2. Ir a "Explorar"
3. Buscar "Just Perfection"
4. Instalar

**Configurar transparencias:**
1. Abrir "Gestor de extensiones"
2. Click en "Just Perfection" → Configuración
3. Ir a "Customize" → "Panel"
4. Activar "Panel Transparency"
5. Ajustar "Panel Opacity" a 15%

**O desde terminal:**
```bash
# Instalar extensión manualmente
cd ~/.local/share/gnome-shell/extensions
git clone https://github.com/JustPerfection-dev/just-perfection-gnome-shell-extension.git
mv just-perfection-gnome-shell-extension just-perfection-desktop@just-perfection

# Habilitar
gnome-extensions enable just-perfection-desktop@just-perfection

# Configurar panel transparente
gsettings --schemadir ~/.local/share/gnome-shell/extensions/just-perfection-desktop@just-perfection/schemas/ \
  set org.gnome.shell.extensions.just-perfection panel-opacity 15
```

---

### ✅ Método 3: Blur my Shell (transparencias + desenfoque)

**Instalar:**
```bash
# Desde Extension Manager (GUI)
# Buscar "Blur my Shell"

# O manualmente
cd ~/.local/share/gnome-shell/extensions
git clone https://github.com/aunetx/blur-my-shell
cd blur-my-shell
make install

# Habilitar
gnome-extensions enable blur-my-shell@aunetx
```

**Configurar:**
- Panel: Activar blur, opacidad 15%
- Dash to Dock: Activar blur, opacidad 15%
- Overview: Activar blur
- App Folders: Activar blur

---

## Configuración automática (post-instalación)

Crear script para el usuario:

```bash
cat > ~/configure-transparency.sh << 'SCRIPT'
#!/bin/bash
# Script de configuración de transparencias

echo "Configurando transparencias..."

# Ubuntu Dock (ya debería estar configurado)
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'

# Si Just Perfection está instalado
if gnome-extensions list | grep -q "just-perfection"; then
    gsettings set org.gnome.shell.extensions.just-perfection panel-transparency true
    gsettings set org.gnome.shell.extensions.just-perfection panel-opacity 15
    echo "✓ Just Perfection configurado"
fi

# Si Blur my Shell está instalado
if gnome-extensions list | grep -q "blur-my-shell"; then
    gsettings set org.gnome.shell.extensions.blur-my-shell panel-transparency true
    gsettings set org.gnome.shell.extensions.blur-my-shell panel-opacity 0.15
    echo "✓ Blur my Shell configurado"
fi

echo "✓ Transparencias aplicadas"
SCRIPT

chmod +x ~/configure-transparency.sh
```

---

## Método manual: Editar tema de GNOME Shell

**Solo para usuarios avanzados:**

```bash
# Copiar tema Yaru
sudo cp -r /usr/share/gnome-shell/theme /usr/share/gnome-shell/theme-backup

# Editar CSS principal
sudo nano /usr/share/gnome-shell/theme/Yaru/gnome-shell.css

# Buscar y modificar:
#panel {
    background-color: rgba(0, 0, 0, 0.15); /* Cambiar de 1.0 a 0.15 */
}

# Guardar y reiniciar GNOME Shell
# X11: Alt+F2, escribir 'r', Enter
# Wayland: cerrar sesión
```

**⚠️ Advertencia:** Se sobrescribirá con actualizaciones del tema.

---

## Comparación de métodos

| Método | Facilidad | Elementos | Persistente | Recomendado |
|--------|-----------|-----------|-------------|-------------|
| Ubuntu Dock gsettings | ⭐⭐⭐⭐⭐ | Solo Dock | ✅ Sí | Para Dock |
| Just Perfection | ⭐⭐⭐⭐ | Panel, Overview | ✅ Sí | **Mejor opción** |
| Blur my Shell | ⭐⭐⭐ | Todo + blur | ✅ Sí | Más completo |
| Editar tema | ⭐⭐ | Todo | ❌ No | Solo avanzados |

---

## Recomendación del instalador

El instalador configura:
1. ✅ **Ubuntu Dock** → Transparencia automática (gsettings)
2. 📝 **Instrucciones** para instalar Just Perfection o Blur my Shell

**No configura automáticamente:**
- Panel superior (requiere extensión)
- App Grid (requiere extensión)
- Calendario (requiere extensión)
- Quick Settings (requiere extensión)

**Razón:** Las extensiones no están en los repositorios de Ubuntu y no se pueden instalar automáticamente en el chroot.

---

## Pasos post-instalación (usuario)

Después del primer login:

1. **Verificar Dock transparente**
   ```bash
   gsettings get org.gnome.shell.extensions.dash-to-dock background-opacity
   # Debería mostrar: 0.15
   ```

2. **Instalar Just Perfection**
   - Abrir Extension Manager
   - Buscar "Just Perfection"
   - Instalar y configurar panel al 15%

3. **(Opcional) Instalar Blur my Shell**
   - Para efectos de desenfoque adicionales

---

## Verificación

```bash
# Ubuntu Dock
gsettings get org.gnome.shell.extensions.dash-to-dock background-opacity
# Esperado: 0.15

# Just Perfection (si está instalado)
gnome-extensions list | grep just-perfection
gsettings list-recursively org.gnome.shell.extensions.just-perfection | grep panel

# Blur my Shell (si está instalado)
gnome-extensions list | grep blur-my-shell
```

---

## Troubleshooting

**El Dock no es transparente:**
```bash
# Verificar extensión activa
gnome-extensions list | grep ubuntu-dock

# Reconfigurar
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.15
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'

# Reiniciar extensión
gnome-extensions disable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-dock@ubuntu.com
```

**El panel no es transparente:**
- Necesitas instalar Just Perfection o Blur my Shell
- No hay método nativo sin extensiones

**Las extensiones no aparecen:**
```bash
# Instalar extension manager si no está
sudo apt install gnome-shell-extension-manager
```

---

## Método 4: Tema Shell personalizado (NO RECOMENDADO)

> **⚠️ Este método está desactivado por defecto en el instalador**
>
> **Razones:**
> - Requiere User Themes extension
> - Más complejo de mantener
> - Just Perfection es más flexible
> - Adwaita por defecto es excelente

**Si aún así quieres usarlo:**

El instalador puede crear un tema `Adwaita-Transparent`:

```bash
# Durante instalación interactiva
¿Aplicar tema transparente? (s/n) [n]: s

# O en config.env
GNOME_TRANSPARENT_THEME="true"
```

**Qué incluye:**
- Extensión User Themes
- Tema Adwaita-Transparent en `/usr/share/themes/`
- Transparencias en Quick Settings y Calendar
- Aplicado automáticamente

**Desinstalar si lo activaste:**
```bash
# Volver a Adwaita
gsettings set org.gnome.shell.extensions.user-theme name ''

# Desinstalar extensión
sudo apt remove gnome-shell-extension-user-theme

# Eliminar tema
sudo rm -rf /usr/share/themes/Adwaita-Transparent
```

**Recomendación final:** Usa **Just Perfection** en su lugar. Es más moderno, flexible y no requiere temas personalizados.

