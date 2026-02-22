# Ubuntu Advanced Installer

Instalador modular y simplificado de Ubuntu con detección automática.

## 🚀 Inicio Rápido

```bash
# Descargar y extraer
tar xzf ubuntu-advanced-install-v3.2.0.tar.gz
cd ubuntu-advanced-install

# Ejecutar (modo interactivo)
sudo bash install.sh
```

## 📋 Modos de Instalación

### 1. Instalación Interactiva (Recomendado)
```bash
sudo bash install.sh
# Seleccionar opción 1
```

**Flujo**:
1. Muestra discos disponibles
2. Preguntas qué hacer (limpiar o dual-boot)
3. Dual-boot: usa regla 80/20 automática
4. Listo

### 2. Instalación Automática
```bash
sudo bash install.sh --auto
```
Requiere `config.env` configurado

### 3. Instalación Debug
```bash
sudo bash install.sh
# Seleccionar opción 3
```
Muestra cada comando ejecutado (útil para diagnosticar)

## 🔧 Variables Importantes

### Detectadas Automáticamente (Módulo 01)

El módulo `01-prepare-disk.sh` detecta y configura:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `TARGET_DISK` | Dispositivo físico | `/dev/sda` |
| `ROOT_PART` | Partición raíz Ubuntu | `/dev/sda2` |
| `EFI_PART` | Partición EFI | `/dev/sda1` |
| `FIRMWARE` | Tipo de firmware | `UEFI` o `BIOS` |
| `DUAL_BOOT_MODE` | Si es dual-boot | `true` o `false` |

Estas se guardan en `partition.info` para otros módulos.

### Configuración Manual (config.env)

Solo necesario para instalación automática:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TARGET` | `/mnt/ubuntu` | Punto de montaje |
| `UBUNTU_VERSION` | `noble` | Versión Ubuntu |
| `HOSTNAME` | `ubuntu` | Nombre equipo |
| `USERNAME` | `user` | Usuario crear |

## 🎯 Dual-Boot Inteligente: Regla 80/20

### Filosofía

Si instalas dual-boot = vas a **USAR** Ubuntu → Dale espacio

### Cálculo Automático

```
Espacio Libre → Ubuntu 80%, Sistema existente 20%
```

### Ejemplo Real

Laptop 500GB con Windows 250GB:

```
Análisis:
  Total: 500GB
  Usado por Windows: 250GB
  Libre: 250GB

Distribución 80/20:
  Ubuntu: 200GB  ← 80% del libre
  Libre para Windows: 50GB  ← 20% del libre

¿Cuántos GB para Ubuntu? [200]: █
```

**Resultado**:
- Ubuntu: 200GB para trabajar
- Windows: 250GB + 50GB libres

## 📁 Estructura

```
ubuntu-advanced-install/
├── install.sh              # Script principal
├── config.env.example      # Ejemplo configuración
├── partition.info          # Generado por módulo 01
├── modules/
│   ├── 00-check-dependencies.sh
│   ├── 01-prepare-disk.sh          # ← Detecta TARGET_DISK
│   ├── 02-debootstrap.sh
│   └── ...
└── logs/
```

## 🔍 Verificación de Dependencias

Solo verifica lo NO base:

✓ **Verificados** (pueden faltar):
- parted, debootstrap, arch-install-scripts, ubuntu-keyring

✗ **No verificados** (siempre presentes):
- lsblk, mount, blkid, bash, apt

## 💡 TARGET vs TARGET_DISK

**Confusión común**, son diferentes:

| Variable | Tipo | Ejemplo | Uso |
|----------|------|---------|-----|
| `TARGET` | Directorio | `/mnt/ubuntu` | Montar sistema |
| `TARGET_DISK` | Dispositivo | `/dev/sda` | Instalar GRUB |

```bash
# Correcto
mount "$ROOT_PART" "$TARGET"
grub-install "$TARGET_DISK"

# Incorrecto
mount "$TARGET" "$ROOT_PART"  # ← Al revés
grub-install "$TARGET"         # ← GRUB va al disco
```

## 🚀 Ejemplos de Uso

### Laptop con Windows

```bash
$ sudo bash install.sh

Discos disponibles:
  1) /dev/nvme0n1 - 500GB Windows?

Selecciona disco [1]: 1

Particiones actuales:
...

¿Qué hacer?
  1) Borrar todo
  2) Dual-boot
Opción [2]: 2

Distribución 80/20:
  Ubuntu: 200GB
  Libre: 50GB

¿GB para Ubuntu? [200]: [Enter]

✓ Partición creada: /dev/nvme0n1p5
```

### Servidor Disco Vacío

```bash
$ sudo bash install.sh

Discos disponibles:
  1) /dev/sda - 1TB

Selecciona disco [1]: 1

¿Qué hacer?
  1) Usar todo el disco
Opción [1]: 1

✓ Disco particionado
```

## 🐛 Debugging

```bash
# Opción 1: Modo debug integrado
sudo bash install.sh
# → Opción 3: Debug asistida

# Opción 2: Ver logs
tail -f logs/install-*.log

# Opción 3: Ejecutar módulo individual
sudo bash modules/01-prepare-disk.sh
```

## 📖 Documentación Adicional

- `VERSION-v3.2.0-80-20-RULE.md` - Explicación regla 80/20
- `BASE-PACKAGES-EXPLAINED.md` - Qué se verifica
- `TARGET-VARIABLES-EXPLAINED.md` - TARGET vs TARGET_DISK

## 🎯 Filosofía

1. **Simplicidad**: Menos código = mejor código
2. **Sensato**: Asumir lo razonable (lsblk existe)
3. **80/20**: Dale espacio al sistema que usarás
4. **KISS**: Keep It Simple, Stupid
5. **DRY**: Don't Repeat Yourself

---

**Versión**: 3.2.0  
**Estado**: Estable - Producción
