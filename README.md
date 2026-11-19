> **Moved.** This skill now lives in the bundle **[multi-flow-skills](https://github.com/Mariomarquezt/multi-flow-skills)** (`skills/multi-plan`), together with `multi-flow`, `sliced-review` and the shared model list. This repo is archived and will not get updates.

# multi-plan

A [Claude Code](https://claude.com/claude-code) skill that turns an idea into a build plan, then
has **other AI models attack the plan** before you build anything.

1. Claude writes a full plan: goal, stack, architecture, data model, phases, risks, cost.
2. Two to five other models (GPT via Codex, Grok via Cursor, DeepSeek / GLM / MiniMax via
   OpenCode) each review it alone, in parallel, read-only.
3. Claude rules on every finding (accept, partial, reject, or "your call") and writes a new version.
4. Repeat up to 3 rounds, or until no serious objection is left.

You get a final plan, a decision log, and a short list of trade-offs only you should decide.

## Install

```bash
git clone https://github.com/Mariomarquezt/multi-plan.git ~/.claude/skills/multi-plan
chmod +x ~/.claude/skills/multi-plan/scripts/critic.sh
```

Restart Claude Code. Then type `/multi-plan` followed by your idea.

## What you need

You only need the CLIs for the critics you use. Log in to each one once.

| arm | CLI | install |
|---|---|---|
| `sol` | Codex CLI (`codex`) | `npm i -g @openai/codex`, then `codex login` |
| `grok`, `composer` | Cursor Agent (`cursor-agent`) | `curl https://cursor.com/install -fsS \| bash`, then `cursor-agent login` |
| `deepseek`, `glm`, `minimax`, `qwen`, `kimi` | OpenCode (`opencode`) | `brew install sst/tap/opencode`, then `opencode auth login` |

The default OpenCode models use the `opencode-go/` provider. If you use another provider in
OpenCode (or any model id that your CLI accepts), set an env var per arm:

```bash
export MP_MODEL_DEEPSEEK="openrouter/deepseek/deepseek-chat"
export MP_MODEL_SOL="gpt-5"
export MP_MODEL_GROK="grok-4"
```

The env var name is `MP_MODEL_` plus the arm name in upper case. `MP_TIMEOUT` sets the time
limit per critic in seconds (default 900).

## Modes

| command | critics | rounds |
|---|---|---|
| `/multi-plan 2` | Sol, Grok | up to 3 |
| `/multi-plan` or `/multi-plan 3` | Sol, Grok, DeepSeek | up to 3 |
| `/multi-plan 5` | Sol, Grok, DeepSeek, GLM, MiniMax | up to 3 |
| `/multi-plan fast` | Composer, DeepSeek | 1 |
| `… rounds N` | — | N (1 to 3) |
| `… dry` | none — just the first draft | 0 |
| `… report` | — | also makes an HTML report |

If you do not have a CLI that a mode needs, tell Claude which arms to use instead
(for example "use sol, qwen and kimi").

## Test one critic by hand

```bash
echo "Review this plan: a todo app on SQLite. Answer with VERDICT: SHIP or CHANGE." > /tmp/brief.md
~/.claude/skills/multi-plan/scripts/critic.sh deepseek /tmp/brief.md /tmp/out.md && cat /tmp/out.md
```

## Cost

Each critic run uses your own subscription or API credits on that service. A full `5` run with
3 rounds is up to 15 model runs.

## Files

```
SKILL.md                  the instructions Claude follows
scripts/critic.sh         runs one critic model, read-only
templates/plan.md         plan layout
templates/critic-brief.md what each critic is told
templates/decisions.md    decision log layout
```

## License

MIT
