# Reordenación de Módulos - NetworkManager a Base

## Cambio realizado

**NetworkManager movido de componentes opcionales a módulos base**

```
ANTES:
00-04: Base
05: enable-backports (opcional)
10: GNOME
11: configure-network ← Opcional
12-16: Otros componentes

DESPUÉS:
00-04: Base
05: configure-network ← AHORA BASE
06: enable-backports
10-16: Componentes opcionales
```

## Justificación

La configuración de red es **fundamental** para cualquier sistema, no opcional:

1. **Servidor sin GUI** → Necesita red funcional
2. **Desktop mínimo** → Necesita red funcional
3. **Workstation completa** → Necesita red funcional

NetworkManager proporciona:
- Gestión automática de interfaces
- DHCP client integrado
- Soporte WiFi (con wpa_supplicant)
- DNS resolution (systemd-resolved)
- Sin red configurada, el sistema queda aislado

## Archivos modificados

- `modules/11-configure-network.sh` → `modules/05-configure-network.sh`
- `modules/05-enable-backports.sh` → `modules/06-enable-backports.sh`
- `install.sh` (línea 558 → 555: red ahora en secuencia base)
- `README.md` (estructura de módulos actualizada)

## Orden de ejecución actualizado

```bash
# MÓDULOS BASE (siempre se ejecutan)
00-check-dependencies
01-prepare-disk
02-debootstrap
03-configure-base
04-install-bootloader
05-configure-network ← NUEVO
06-enable-backports

# COMPONENTES OPCIONALES
10-install-gnome (si INSTALL_GNOME=true)
12-install-multimedia (si INSTALL_MULTIMEDIA=true)
13-install-fonts (siempre)
14-configure-wireless (si HAS_WIFI=true)
15-install-development (si INSTALL_DEVELOPMENT=true)
16-configure-gaming (si INSTALL_GAMING=true)

# OPTIMIZACIONES
20-optimize-performance (modular, comentado)
21-optimize-laptop (si IS_LAPTOP=true)
23-minimize-systemd (si MINIMIZE_SYSTEMD=true)
24-security-hardening (si ENABLE_SECURITY=true)
```

## Impacto

**Instalaciones mínimas** (servidor CLI, sistema base):
- ✅ Ahora tienen NetworkManager por defecto
- ✅ Red funcional inmediatamente después del primer boot
- ✅ No requieren configuración manual de `/etc/network/interfaces`

**Instalaciones completas** (desktop, workstation):
- Sin cambios en el comportamiento
- NetworkManager se instala más temprano en la secuencia
