#!/usr/bin/env bash
# critic.sh <arm> <prompt-file> <out-file>
# Run ONE critic model, read-only, on a plan brief. Writes the critic's final answer to <out-file>
# and the raw transcript to <out-file>.transcript. Prints "<arm> <provider> <model> exit=<n> secs=<s>".
#
# Arms and the CLI each one needs (log in to each CLI once before use):
#   sol       Codex CLI      (codex)         default model: gpt-6.1-sol
#   grok      Cursor Agent   (cursor-agent)  default model: cursor-grok-4.6-high
#   composer  Cursor Agent   (cursor-agent)  default model: composer-2.5
#   deepseek  OpenCode       (opencode)      default model: opencode-go/deepseek-v4.1-flash
#   glm       OpenCode       (opencode)      default model: opencode-go/glm-5.3-flash
#   minimax   OpenCode       (opencode)      default model: opencode-go/minimax-m3.1-flash
#   qwen      OpenCode       (opencode)      default model: opencode-go/qwen3.8-flash
#   kimi      OpenCode       (opencode)      default model: opencode-go/kimi-k2.7-code
#
# Override any model with an env var: MP_MODEL_<ARM> (upper case), e.g.
#   MP_MODEL_DEEPSEEK=openrouter/deepseek/deepseek-chat critic.sh deepseek brief.md out.md
# Override a per-run timeout (seconds, default 900) with MP_TIMEOUT.
set -uo pipefail

[ $# -eq 3 ] || { echo "usage: critic.sh <arm> <prompt-file> <out-file>" >&2; exit 2; }
arm="$1"; prompt_file="$2"; out="$3"
[ -s "$prompt_file" ] || { echo "critic: prompt file '$prompt_file' is missing or empty" >&2; exit 2; }
prompt="$(cat "$prompt_file")"
TIMEOUT="${MP_TIMEOUT:-900}"
start=$(date +%s)

# Use GNU timeout / gtimeout when present; run without a limit otherwise.
TO=""
command -v timeout  >/dev/null 2>&1 && TO="timeout $TIMEOUT"
[ -z "$TO" ] && command -v gtimeout >/dev/null 2>&1 && TO="gtimeout $TIMEOUT"

need() { command -v "$1" >/dev/null 2>&1 || { echo "critic: '$1' not found — install it or pick another arm" >&2; exit 2; }; }
model_for() { # $1 = arm, $2 = default
  local var="MP_MODEL_$(echo "$1" | tr '[:lower:]' '[:upper:]')"
  echo "${!var:-$2}"
}

provider=""; model=""; rc=1
case "$arm" in
  sol)
    need codex; provider=codex; model="$(model_for sol gpt-6.1-sol)"
    T="$(mktemp)"
    $TO codex exec --skip-git-repo-check -m "$model" -c model_reasoning_effort="high" \
      -s read-only -o "$T" "$prompt" < /dev/null > "$out.transcript" 2>&1
    rc=$?; cat "$T" > "$out"; rm -f "$T" ;;
  grok|composer)
    need cursor-agent; provider=cursor
    if [ "$arm" = grok ]; then model="$(model_for grok cursor-grok-4.6-high)"
    else model="$(model_for composer composer-2.5)"; fi
    # --mode ask = read-only Q&A, no edits.
    $TO cursor-agent -p --mode ask --model "$model" --output-format text "$prompt" \
      < /dev/null > "$out" 2> "$out.transcript"
    rc=$? ;;
  deepseek|glm|minimax|qwen|kimi)
    need opencode; provider=opencode
    case "$arm" in
      deepseek) model="$(model_for deepseek opencode-go/deepseek-v4.1-flash)" ;;
      glm)      model="$(model_for glm      opencode-go/glm-5.3-flash)" ;;
      minimax)  model="$(model_for minimax  opencode-go/minimax-m3.1-flash)" ;;
      qwen)     model="$(model_for qwen     opencode-go/qwen3.8-flash)" ;;
      kimi)     model="$(model_for kimi     opencode-go/kimi-k2.7-code)" ;;
    esac
    # The built-in "plan" agent is read-only.
    $TO opencode run --agent plan -m "$model" "$prompt" \
      < /dev/null > "$out" 2> "$out.transcript"
    rc=$? ;;
  *) echo "unknown arm '$arm' (sol|grok|composer|deepseek|glm|minimax|qwen|kimi)" >&2; exit 2 ;;
esac

[ -s "$out" ] || { [ "$rc" -eq 0 ] && rc=1; }
echo "$arm $provider $model exit=$rc secs=$(( $(date +%s) - start )) bytes=$(wc -c < "$out" 2>/dev/null | tr -d ' ')"
exit "$rc"
