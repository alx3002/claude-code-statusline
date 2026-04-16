#!/usr/bin/env bash
# install.sh — instala o statusline do Claude Code
#
# Uso:
#   bash install.sh
#   bash install.sh --uninstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

fail()    { echo "Erro: $1" >&2; exit 1; }
success() { echo "OK: $1"; }

# ── Uninstall ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$TARGET"
    if command -v jq >/dev/null 2>&1 && [[ -f "$SETTINGS" ]]; then
        jq 'del(.statusLine)' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    fi
    echo "Statusline removido."
    exit 0
fi

# ── Dependências ───────────────────────────────────────────────────────────────
command -v jq  >/dev/null 2>&1 || fail "jq não encontrado. Instale com: sudo apt install jq  ou  brew install jq"
command -v git >/dev/null 2>&1 || fail "git não encontrado."

# ── Instala o script ───────────────────────────────────────────────────────────
mkdir -p "$HOME/.claude"
cp "$SCRIPT_DIR/statusline.sh" "$TARGET"
chmod +x "$TARGET"
success "Script copiado para $TARGET"

# ── Atualiza settings.json ─────────────────────────────────────────────────────
if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
fi

jq --arg cmd "bash $TARGET" \
    '.statusLine = {"type": "command", "command": $cmd}' \
    "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

success "settings.json atualizado"
echo ""
echo "Instalação concluída. Reinicie o Claude Code para ativar."
echo "Para desinstalar: bash install.sh --uninstall"
