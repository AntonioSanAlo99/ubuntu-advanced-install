# Rust con rustup

## Instalación

El módulo de desarrollo (`15-install-development.sh`) ofrece instalar Rust usando rustup.

### Durante Instalación Interactiva

```bash
sudo ./install.sh
# ...
# ¿Instalar herramientas de desarrollo? (s/n) [n]: s
# ...
# ¿Instalar Rust usando rustup? (s/n) [n]: s
```

### Qué se Instala

```bash
# rustup se instala para el usuario configurado
# Ubicación: /home/$USERNAME/.cargo/

# Componentes:
rustc      # Compilador de Rust
cargo      # Gestor de paquetes
rustup     # Gestor de toolchains
```

## Uso

### Primera vez (en cada sesión nueva)

```bash
source ~/.cargo/env
```

O cierra y abre la terminal de nuevo (ya está en `~/.bashrc`).

### Verificar instalación

```bash
rustc --version
# rustc 1.75.0 (o versión actual)

cargo --version
# cargo 1.75.0
```

### Crear proyecto

```bash
cargo new mi_proyecto
cd mi_proyecto
cargo run
```

## Actualizar Rust

```bash
rustup update
```

## Cambiar toolchain

```bash
# Ver toolchains disponibles
rustup toolchain list

# Instalar nightly
rustup toolchain install nightly

# Usar nightly para un proyecto
rustup default nightly

# Volver a stable
rustup default stable
```

## Añadir componentes

```bash
# rust-analyzer (LSP para VS Code)
rustup component add rust-analyzer

# rustfmt (formateador)
rustup component add rustfmt

# clippy (linter)
rustup component add clippy
```

## Targets adicionales

```bash
# Para cross-compilation
rustup target add x86_64-pc-windows-gnu
rustup target add wasm32-unknown-unknown
```

## Integración con VS Code

Si instalaste VS Code, añade la extensión:

1. Abrir VS Code
2. Extensions (Ctrl+Shift+X)
3. Buscar "rust-analyzer"
4. Instalar

## Por qué rustup y no apt

| rustup | apt install rustc |
|--------|-------------------|
| ✅ Última versión | ❌ Versión antigua |
| ✅ Fácil actualizar | ❌ Depende de repos |
| ✅ Múltiples toolchains | ❌ Solo stable |
| ✅ Targets cross-compilation | ❌ Limitado |
| ✅ Componentes opcionales | ❌ Fijo |

## Instalación Manual (si no se instaló)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Sigue las instrucciones interactivas.

## Desinstalar

```bash
rustup self uninstall
```

## Ubicaciones

```
~/.cargo/               # Directorio principal
~/.cargo/bin/           # Binarios (rustc, cargo, rustup)
~/.cargo/env            # Variables de entorno
~/.rustup/              # Toolchains instalados
```

## Recursos

- [Rust Book](https://doc.rust-lang.org/book/) - Aprender Rust
- [Cargo Book](https://doc.rust-lang.org/cargo/) - Usar cargo
- [rustup](https://rustup.rs/) - Documentación oficial
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/) - Ejemplos
