#!/bin/bash
# MÓDULO 07: Instalar Rust (base del sistema)
# REQUIERE: TARGET, USERNAME
# PRODUCE:  Rust toolchain (rustc, cargo, rustup) en /home/$USERNAME/.cargo/

# Rust es dependencia base del sistema: necesario para compilar webapps con
# Pake (Tauri) y como toolchain de desarrollo general. Se instala como usuario
# (no root) via rustup — el método oficial recomendado por rust-lang.org.
#
# Se ejecuta SIEMPRE como módulo CORE, independiente de INSTALL_DEVELOPMENT.

# ── Parser YAML inline ──────────────────────────────────────────────────────
_yaml_val() {
    local section="$1" key="$2" default="$3"
    local env_var; env_var="$(echo "${section}_${key}" | tr '[:lower:]' '[:upper:]')"
    [ -n "${!env_var:-}" ] && { echo "${!env_var}"; return; }
    local cfg="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/config.yaml"
    if [ -f "$cfg" ]; then
        local val; val=$(awk -v s="$section" -v k="$key" '
            /^[a-z]/ { sec=$1; gsub(/:$/,"",sec) }
            sec==s && $1==k":" { $1=""; gsub(/^[ \t]+/,"",$0); gsub(/#.*/,"",$0); gsub(/[ \t]+$/,"",$0); print; exit }
        ' "$cfg")
        [ -n "$val" ] && { echo "$val"; return; }
    fi
    echo "$default"
}

TARGET="${TARGET:-/mnt/ubuntu}"
USERNAME="${USERNAME:-$(_yaml_val "system" "username" "")}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Instalando Rust (rustup) — base del sistema"
echo "════════════════════════════════════════════════════════════════"
echo ""

arch-chroot "$TARGET" /bin/bash << RUSTEOF
set -e
export DEBIAN_FRONTEND=noninteractive

USERNAME="$USERNAME"

if [ -z "\$USERNAME" ] || ! id "\$USERNAME" &>/dev/null; then
    echo "⚠  Usuario \$USERNAME no encontrado — Rust no instalado"
    echo "   Instalar manualmente: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 0
fi

# Verificar si ya está instalado
if [ -f "/home/\$USERNAME/.cargo/bin/rustc" ]; then
    echo "✓  Rust ya instalado: \$(su - \$USERNAME -c 'rustc --version' 2>/dev/null)"
    exit 0
fi

echo "Instalando Rust para \$USERNAME..."

cat > /tmp/install-rust.sh << 'RUSTUP_SCRIPT'
#!/bin/bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "\$HOME/.cargo/env"
if command -v rustc &>/dev/null; then
    echo "✓  Rust instalado: \$(rustc --version), \$(cargo --version)"
else
    echo "⚠  Error al instalar Rust"
    exit 1
fi
RUSTUP_SCRIPT

chmod 755 /tmp/install-rust.sh
su - "\$USERNAME" -c "/tmp/install-rust.sh"
rm -f /tmp/install-rust.sh

echo ""
echo "  ✓ Rust instalado para \$USERNAME"
echo "  Ubicación: /home/\$USERNAME/.cargo/bin/"

RUSTEOF

echo ""
echo "✓  Módulo 07 completado — Rust"
