#!/bin/bash
# Statusline Claude Code — usa Python para JSON (sem dependência de jq)
# Campos: modelo, effort, dir, branch, linhas, tokens, 5h rate limit, 7d rate limit

input=$(cat)

# ── Parse JSON via Python (usa arquivo temp para evitar problemas com aspas) ──
_tmpjson=$(mktemp)
printf '%s' "$input" > "$_tmpjson"
trap 'rm -f "$_tmpjson"' EXIT

_py() {
    python - "$_tmpjson" <<EOF
import sys, json
data = {}
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
except:
    pass
$1
EOF
}

# ── Workspace ─────────────────────────────────────────────────────────────────
cwd=$(_py "cw=data.get('workspace',{}).get('current_dir') or data.get('cwd',''); print(cw)")
[ -z "$cwd" ] && cwd=$(pwd)
cwd="${cwd//\\//}"
cwd="${cwd%/}"
dir_basename="${cwd##*/}"
branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)

# ── Modelo e effort ───────────────────────────────────────────────────────────
model_name=$(_py "print(data.get('model',{}).get('display_name',''))")
settings_file="${HOME}/.claude/settings.json"
effort=$(python - "$settings_file" <<'PYEOF'
import sys, json
try:
    print(json.load(open(sys.argv[1])).get('effortLevel',''))
except:
    print('')
PYEOF
)

# ── Linhas ────────────────────────────────────────────────────────────────────
lines_added=$(_py "
cost=data.get('cost',{})
v=cost.get('total_lines_added') or data.get('total_lines_added') or 0
print(int(v or 0))
")
lines_removed=$(_py "
cost=data.get('cost',{})
v=cost.get('total_lines_removed') or data.get('total_lines_removed') or 0
print(int(v or 0))
")

# ── Tokens + contexto ─────────────────────────────────────────────────────────
read -r total_input total_output cache_read ctx_pct < <(_py "
cw=data.get('context_window',{})
ti=int(cw.get('total_input_tokens') or 0)
to_=int(cw.get('total_output_tokens') or 0)
cu=cw.get('current_usage',{})
cr=int(cu.get('cache_read_input_tokens') or cw.get('cache_read_tokens') or 0)
mx=int(cw.get('max_tokens') or cw.get('context_window_tokens') or 0)
pct=round(ti*100/mx,1) if mx>0 else ''
print(ti, to_, cr, pct)
")

# ── Rate limits ───────────────────────────────────────────────────────────────
read -r rl_5h_pct rl_5h_reset rl_7d_pct rl_7d_reset < <(_py "
rl=data.get('rate_limits',{})
fh=rl.get('five_hour',{})
sd=rl.get('seven_day',{})
# Garante que None vire string vazia e remove espaços
def s(v): return str(v).strip() if v is not None else ''
print(s(fh.get('used_percentage')), s(fh.get('resets_at')), s(sd.get('used_percentage')), s(sd.get('resets_at')))
")

# ── Helpers ───────────────────────────────────────────────────────────────────
fmt_k() {
    local n="$1"
    if [ "$n" -ge 1000 ] 2>/dev/null; then
        LC_ALL=C awk "BEGIN {printf \"%.1fk\", $n/1000}"
    else
        echo "$n"
    fi
}

# Calcula tempo restante até epoch Unix; retorna "2h30m", "45m", "3d"
fmt_remaining() {
    local reset_epoch="${1//[$'\r\n ']/}"  # remove \r \n e espaços (Windows)
    [ -z "$reset_epoch" ] && return
    [[ "$reset_epoch" =~ ^[0-9]+$ ]] || return  # garante que é número
    local now_epoch
    now_epoch=$(date +%s)
    local diff=$(( reset_epoch - now_epoch ))
    [ "$diff" -le 0 ] && echo "agora" && return
    if [ "$diff" -ge 86400 ]; then
        local d=$(( diff / 86400 ))
        local h=$(( (diff % 86400) / 3600 ))
        [ "$h" -gt 0 ] && echo "${d}d${h}h" || echo "${d}d"
    elif [ "$diff" -ge 3600 ]; then
        local h=$(( diff / 3600 ))
        local m=$(( (diff % 3600) / 60 ))
        [ "$m" -gt 0 ] && echo "${h}h${m}m" || echo "${h}h"
    else
        local m=$(( diff / 60 ))
        echo "${m}m"
    fi
}

# Constrói barra de progresso: make_bar PCT COLOR_VAR
# Usa 8 chars; retorna string com ANSI
make_bar() {
    local pct="$1"
    local bar_color="$2"
    local pct_int
    pct_int=$(LC_ALL=C awk "BEGIN {pct=int($pct+0.5); if(pct>100) pct=100; print pct}")
    local filled
    filled=$(LC_ALL=C awk "BEGIN {print int($pct_int * 8 / 100)}")
    local empty=$(( 8 - filled ))
    local bar_f bar_e
    bar_f=$(LC_ALL=C awk "BEGIN {for(i=0;i<$filled;i++) printf \"█\"; print \"\"}")
    bar_e=$(LC_ALL=C awk "BEGIN {for(i=0;i<$empty;i++) printf \"░\"; print \"\"}")
    printf "%b" "${bar_color}${bar_f}${MUTED}${bar_e}${RESET}"
}

# Escolhe cor pela porcentagem
pct_color() {
    local pct="$1"
    local pct_int
    pct_int=$(LC_ALL=C awk "BEGIN {print int($pct+0.5)}" 2>/dev/null || echo 0)
    if [ "$pct_int" -ge 90 ] 2>/dev/null; then
        echo "$RED"
    elif [ "$pct_int" -ge 70 ] 2>/dev/null; then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
}

# ── Cores ─────────────────────────────────────────────────────────────────────
RESET=$'\033[0m'
MUTED=$'\033[38;5;245m'
DIR=$'\033[38;5;110m'
BRANCH=$'\033[38;5;150m'
TOKEN=$'\033[38;5;174m'
CACHE=$'\033[38;5;179m'
ADD=$'\033[38;5;150m'
DEL=$'\033[38;5;203m'
GREEN=$'\033[38;5;150m'
YELLOW=$'\033[38;5;221m'
RED=$'\033[38;5;203m'
MODEL_COLOR=$'\033[38;5;183m'   # lilás — modelo
EFFORT_COLOR=$'\033[38;5;215m'  # laranja suave — effort

# ── Build content ─────────────────────────────────────────────────────────────

# Modelo e effort (antes do dir)
content=""
if [ -n "$model_name" ]; then
    content+="${MUTED}│${RESET} ${MODEL_COLOR}${model_name}${RESET}"
    if [ -n "$effort" ]; then
        content+=" ${MUTED}·${RESET} ${EFFORT_COLOR}${effort}${RESET}"
    fi
    content+=" "
fi

content+="${MUTED}│${RESET} 📁 ${DIR}${dir_basename}${RESET}"

if [ -n "$branch" ]; then
    content+=" ${MUTED}·${RESET} ${BRANCH}${branch}${RESET}"
fi

# Linhas adicionadas/removidas
if [ "$lines_added" -gt 0 ] 2>/dev/null || [ "$lines_removed" -gt 0 ] 2>/dev/null; then
    content+=" ${MUTED}│${RESET}"
    [ "$lines_added"   -gt 0 ] 2>/dev/null && content+=" ${ADD}+${lines_added}${RESET}"
    [ "$lines_removed" -gt 0 ] 2>/dev/null && content+=" ${DEL}-${lines_removed}${RESET}"
fi

# Tokens + contexto
in_fmt=$(fmt_k "$total_input")
out_fmt=$(fmt_k "$total_output")
content+=" ${MUTED}│${RESET}"
content+=" ${MUTED}in${RESET} ${TOKEN}${in_fmt}${RESET}"
content+=" ${MUTED}out${RESET} ${TOKEN}${out_fmt}${RESET}"
if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "0" ] && [ "$ctx_pct" != "0.0" ]; then
    ctx_color=$(pct_color "$ctx_pct")
    content+=" ${MUTED}ctx${RESET} ${ctx_color}${ctx_pct}%${RESET}"
fi
if [ "$cache_read" -gt 0 ] 2>/dev/null; then
    cache_fmt=$(fmt_k "$cache_read")
    content+=" ${MUTED}cache${RESET} ${CACHE}${cache_fmt}${RESET}"
fi

# Rate limit 5h
if [ -n "$rl_5h_pct" ] && [ "$rl_5h_pct" != "null" ]; then
    rl5_color=$(pct_color "$rl_5h_pct")
    rl5_pct_int=$(LC_ALL=C awk "BEGIN {print int($rl_5h_pct+0.5)}")
    rl5_time=$(fmt_remaining "$rl_5h_reset")
    content+=" ${MUTED}│ 5h${RESET} $(make_bar "$rl_5h_pct" "$rl5_color") ${rl5_color}${rl5_pct_int}%${RESET}"
    [ -n "$rl5_time" ] && content+=" ${MUTED}${rl5_time}${RESET}"
fi

# Rate limit 7d
if [ -n "$rl_7d_pct" ] && [ "$rl_7d_pct" != "null" ]; then
    rl7_color=$(pct_color "$rl_7d_pct")
    rl7_pct_int=$(LC_ALL=C awk "BEGIN {print int($rl_7d_pct+0.5)}")
    rl7_time=$(fmt_remaining "$rl_7d_reset")
    content+=" ${MUTED}│ 7d${RESET} $(make_bar "$rl_7d_pct" "$rl7_color") ${rl7_color}${rl7_pct_int}%${RESET}"
    [ -n "$rl7_time" ] && content+=" ${MUTED}${rl7_time}${RESET}"
fi

# ── Centering ─────────────────────────────────────────────────────────────────
# Remove ANSI para calcular largura real
plain=$(printf "%b" "$content" | sed 's/\x1b\[[0-9;]*m//g')
plain_len=${#plain}
# tput pode falhar no Git Bash/Windows; usa $COLUMNS como segundo fallback
cols=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
pad=$(( (cols - plain_len) / 2 ))
[ "$pad" -lt 0 ] && pad=0
printf "%${pad}s" ""
printf "%b" "$content"
