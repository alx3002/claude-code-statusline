# Claude Code — Status Line Personalizada

Uma barra de status customizada para o [Claude Code](https://claude.ai/code) que exibe modelo, nível de esforço, informações do git, uso de tokens e barras de rate limit em tempo real.

## Preview

```
│ Sonnet · high │ n8n-claude · main │ +12 -3 │ in 8.2k out 1.1k cache 4.5k │ 5h ██░░░░░░ 24% ↺1h30m │ 7d ███░░░░░ 41% ↺2d3h
```

**Código de cores:**
- 🟢 Verde — abaixo de 70%
- 🟡 Amarelo — 70–89%
- 🔴 Vermelho — 90%+

## O que é exibido

| Segmento | Descrição |
|---|---|
| `Sonnet · high` | Modelo atual + nível de esforço |
| `n8n-claude · main` | Pasta do projeto + branch do git |
| `+12 -3` | Linhas adicionadas / removidas na sessão |
| `in 8.2k out 1.1k cache 4.5k` | Tokens de input, output e cache |
| `5h ██░░░░░░ 24% ↺1h30m` | Uso do rate limit de 5 horas + tempo até o reset |
| `7d ███░░░░░ 41% ↺2d3h` | Uso do rate limit semanal + tempo até o reset |

> **Observação:** Os campos de `rate_limits` exigem assinatura Claude.ai Pro ou Max e aparecem após a primeira resposta da API em cada sessão.

## Requisitos

- Claude Code v2.1.80+
- `bash`
- `jq`
- `git`

Instale o `jq` se necessário:

```bash
# Debian / Ubuntu / WSL
sudo apt install jq

# macOS
brew install jq

# Windows (Git Bash) — escolha um:
winget install jqlang.jq
# ou: scoop install jq
# ou: choco install jq
```

### Suporte ao Windows

No Windows, o Claude Code executa o script da status line pelo **Git Bash** — o script funciona direto, sem nenhuma adaptação.

| Ambiente | Funciona? | Observação |
|---|---|---|
| WSL (Ubuntu, Debian…) | ✅ | Idêntico ao Linux |
| Git Bash + Windows Terminal | ✅ | Setup recomendado no Windows |
| Git Bash + cmd / terminais antigos | ⚠️ | Caracteres da barra (`█░`) podem não renderizar; centralização pode ficar errada |
| Somente PowerShell | ❌ | Precisaria reescrever em `.ps1` |

> **Recomendado no Windows:** [Windows Terminal](https://aka.ms/terminal) + [Cascadia Code](https://github.com/microsoft/cascadia-code) (ou qualquer Nerd Font) para renderizar corretamente os caracteres da barra de progresso.  
> Certifique-se de ter o [Git para Windows](https://git-scm.com/download/win) instalado — ele já inclui o Git Bash.  
> No Windows, `~/.claude/` corresponde a `C:\Users\SeuNome\.claude\`.

O script trata caminhos Windows automaticamente — barras invertidas em `workspace.current_dir` são normalizadas para que o nome da pasta sempre apareça corretamente.

## Instalação

### Um comando só

```bash
bash install.sh
```

Depois reinicie o Claude Code.

### Manual

1. Copie `statusline.sh` para `~/.claude/statusline-command.sh`
2. Torne executável: `chmod +x ~/.claude/statusline-command.sh`  
   *(no Git Bash/WSL — não é necessário no Windows nativo)*
3. Adicione ao `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Desinstalar

```bash
bash install.sh --uninstall
```

---

## Como funciona

A cada resposta, o Claude Code envia um JSON para o seu script via **stdin**. O script lê esse JSON com `jq`, monta os segmentos coloridos e imprime o resultado. O Claude Code exibe o que o script imprimir na barra inferior do terminal.

### Campos JSON utilizados

```json
{
  "model": { "display_name": "Sonnet" },
  "workspace": { "current_dir": "/caminho/do/projeto" },
  "cost": {
    "total_lines_added": 12,
    "total_lines_removed": 3
  },
  "context_window": {
    "total_input_tokens": 8200,
    "total_output_tokens": 1100,
    "current_usage": { "cache_read_input_tokens": 4500 }
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  }
}
```

O nível de esforço é lido diretamente de `~/.claude/settings.json` (campo `.effortLevel`), pois ele não está incluído no JSON do stdin.

### Lista completa de campos disponíveis

Consulte a [documentação oficial do statusline](https://code.claude.com/docs/en/statusline) para o schema JSON completo. Outros campos úteis que você pode adicionar:

| Campo | Descrição |
|---|---|
| `session_id` | Identificador único da sessão |
| `context_window.used_percentage` | % da janela de contexto usada (pré-calculado) |
| `context_window.context_window_size` | Tamanho máximo da janela de contexto em tokens |
| `cost.total_cost_usd` | Custo estimado da sessão em USD |
| `cost.total_duration_ms` | Tempo total da sessão em milissegundos |
| `vim.mode` | Modo vim (`NORMAL` / `INSERT`) quando o modo vim está ativo |
| `worktree.name` | Nome do worktree git ativo |

---

## Customização

### Mudar as cores

Edite o bloco de paleta de cores no `statusline.sh`:

```bash
MODEL_COLOR=$'\033[38;5;183m'   # lilás   — nome do modelo
EFFORT_COLOR=$'\033[38;5;215m'  # laranja — nível de esforço
DIR=$'\033[38;5;110m'           # azul    — diretório
BRANCH=$'\033[38;5;150m'        # verde   — branch do git
TOKEN=$'\033[38;5;174m'         # salmão  — valores de tokens
CACHE=$'\033[38;5;179m'         # dourado — tokens de cache
ADD=$'\033[38;5;150m'           # verde   — linhas adicionadas
DEL=$'\033[38;5;203m'           # vermelho — linhas removidas
```

Use qualquer [código ANSI 256 cores](https://www.ditig.com/256-colors-cheat-sheet).

### Adicionar custo da sessão

Inclua no bloco de tokens do `statusline.sh`:

```bash
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_fmt=$(LC_ALL=C awk "BEGIN {printf \"$%.4f\", $cost}")
    content+=" ${MUTED}·${RESET} ${TOKEN}${cost_fmt}${RESET}"
fi
```

### Adicionar barra de janela de contexto

```bash
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_pct" ]; then
    ctx_color=$(pct_color "$ctx_pct")
    ctx_int=$(LC_ALL=C awk "BEGIN {print int($ctx_pct+0.5)}")
    content+=" ${MUTED}│ ctx${RESET} $(make_bar "$ctx_pct" "$ctx_color") ${ctx_color}${ctx_int}%${RESET}"
fi
```

### Adicionar indicador de modo vim

```bash
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
[ "$vim_mode" = "NORMAL" ] && content+=" ${MUTED}[N]${RESET}"
[ "$vim_mode" = "INSERT" ] && content+=" ${GREEN}[I]${RESET}"
```

### Atualizar em intervalo fixo

Para manter a contagem regressiva do rate limit atualizada mesmo quando o Claude está ocioso, adicione `refreshInterval` ao `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 30
  }
}
```

---

## Problemas comuns

**A barra sumiu / não aparece nada**

Teste o script manualmente:

```bash
echo '{}' | bash ~/.claude/statusline-command.sh
```

Se der erro, verifique se o `jq` está instalado e se o script tem permissão de execução.

**As barras de rate limit não aparecem**

- Requer assinatura Pro ou Max
- Só aparecem após a primeira resposta da API na sessão (não no início)
- Teste com: `echo '{"rate_limits":{"five_hour":{"used_percentage":50,"resets_at":9999999999}}}' | bash ~/.claude/statusline-command.sh`

**Vírgula no lugar do ponto nos números (ex: `8,2k` em vez de `8.2k`)**

O script usa `LC_ALL=C awk` para forçar o separador decimal como ponto. Se ainda aparecer vírgula, verifique se o seu `awk` respeita o `LC_ALL`.

**Nível de esforço errado**

O esforço é lido de `~/.claude/settings.json`. Altere com `/effort` no Claude Code e ele atualizará na próxima resposta.

---

## Referências

- [Documentação oficial do statusline](https://code.claude.com/docs/en/statusline)
- [Guia do ccusage para statusline](https://ccusage.com/guide/statusline)
- [Gist de referência por jtbr](https://gist.github.com/jtbr/4f99671d1cee06b44106456958caba8b)
