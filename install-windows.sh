#!/usr/bin/env bash
# install-windows.sh — instala o statusline (versão Windows, sem jq)
#
# Requisitos: Python 3 e Git (via Git Bash)
#
# Uso:
#   bash install-windows.sh
#   bash install-windows.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

fail()    { echo "Erro: $1" >&2; exit 1; }
success() { echo "OK: $1"; }

# ── Uninstall ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$TARGET"
    if command -v python >/dev/null 2>&1 && [[ -f "$SETTINGS" ]]; then
        python - "$SETTINGS" <<'EOF'
import sys, json
f = sys.argv[1]
data = json.load(open(f))
data.pop('statusLine', None)
json.dump(data, open(f, 'w'), indent=2)
EOF
    fi
    echo "Statusline removido."
    exit 0
fi

# ── Dependências ───────────────────────────────────────────────────────────────
command -v python >/dev/null 2>&1 || \
command -v python3 >/dev/null 2>&1 || \
    fail "Python não encontrado. Instale em https://python.org"

command -v git >/dev/null 2>&1 || fail "git não encontrado. Instale em https://git-scm.com"

# ── Instala o script ───────────────────────────────────────────────────────────
mkdir -p "$HOME/.claude"
cp "$SCRIPT_DIR/statusline-windows.sh" "$TARGET"
chmod +x "$TARGET"
success "Script copiado para $TARGET"

# ── Atualiza settings.json via Python ─────────────────────────────────────────
[[ ! -f "$SETTINGS" ]] && echo '{}' > "$SETTINGS"

python - "$SETTINGS" "$TARGET" <<'EOF'
import sys, json
settings_path, target = sys.argv[1], sys.argv[2]
data = json.load(open(settings_path))
data['statusLine'] = {"type": "command", "command": f"bash {target}", "refreshInterval": 30}
json.dump(data, open(settings_path, 'w'), indent=2)
EOF

success "settings.json atualizado"
echo ""
echo "Instalação concluída. Reinicie o Claude Code para ativar."
echo "Para desinstalar: bash install-windows.sh --uninstall"
