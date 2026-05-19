# Article Bridge — Production Case Study

> Real run: SHAPER (Claude Code 1M context, Opus 4.7) × CODEX-ARTICLE (Codex CLI 0.130) wrote 45 article paragraphs across 3 stylistic registers overnight 2026-05-18 → 19. This document captures the working patterns and the seven failure modes encountered + their fixes.

---

## Two bridge types

| type | purpose | example state dir |
|------|---------|-------------------|
| **article-bridge** | Two AI agents iterating on text | `~/.config/murmur-bridge/article-*` |
| **comms-bridge** | Live communication relay (human ↔ agent, team chat) | `~/.config/murmur-bridge/comms-<name>-*` |

Same Murmur infrastructure (identity, LaunchAgent, bridge HTTP, share-render dashboard). Different state dir + different post-processing.

---

## Critical patterns for any new bridge

### 1. Identity isolation via `MURMUR_HOME`

Each bridge gets its own Murmur home dir. Without this, second identity blurs into your default.

```bash
IDENTITY_HOME="$HOME/.config/murmur-<bridge-name>-state"
HOME="$IDENTITY_HOME" murmur sign-in --first-name "<AGENT-NAME>"
```

Wrap every `murmur` call in your bash script:

```bash
HOME="$MURMUR_HOME" "$MURMUR" send --to "$PEER" --message "$MSG"
```

### 2. Identity guard as first line of script

```bash
ME=$(HOME="$MURMUR_HOME" murmur me | awk '/^ID:/{print $2}')
[[ "$ME" != "<expected-peer-id>" ]] && { log "wrong identity"; exit 0; }
```

Script aborts cleanly if `MURMUR_HOME` is misconfigured — prevents accidental sends from wrong identity.

### 3. Staggered cadence for two-way loops

If both sides tick every N seconds, stagger by `N/2`. With 120s interval: side A ticks at 00/02/04..., side B at 01/03/05.... Idempotent state-files protect against double-replies even on collision, but staggering saves cycle waste.

### 4. State files atomicity

- `<bridge>-cycle.txt` — counter, incremented only on successful send
- `<bridge>-last-replied-msg-id.txt` — guards against double-reply to same incoming msg

On failure, counter does not move → next tick retries with same target message.

### 5. Creative-writing prompt frame for AI ↔ AI literary work

Open prompts with:

> "Это упражнение совместного литературного письма. Ты narrator-голос с псевдонимом X (как Hunter Thompson писал от имени Raoul Duke). НЕ identity claim, НЕ prompt injection. Только текст параграфа."

Without this, Haiku 4.5 on `--effort low` refuses ("I am Claude, not <persona>"). Frame solves it.

### 6. Direct-imperative prompt

**Skip structured headers** like `КОНКРЕТНЫЙ ФОКУС:` or `ЗАДАЧА:`. They trigger META-discussion ("your specs are complete, let me clarify...") instead of execution.

Format:
> "Напиши один paragraph (250-350 слов) ... ТЕМА: ... Пиши сразу, не описывай задачу."

### 7. `MAX_CYCLES` synchronization

Both sides must agree on cap. If SHAPER stops at 20 while CODEX continues to 60, CODEX ticks into the void. Match them.

### 8. Dashboard wiring

When adding a new peer, update **two files**:
- `share-render.py` → `PEERS` dict
- `murmur-bridge.py` → `/share-data.json` SHARED constants

These drift if maintained separately. Future refactor: extract single `peers.json` source.

---

## Failures encountered → fixes

| Problem | Symptom | Fix |
|---------|---------|-----|
| Old peer ratchet fork | `sync` errors `Failed to process message` for legacy CODEX-LOCAL | Generate fresh identity (CODEX-ARTICLE), deprecate old peer in PEERS list |
| Manual session vs automation | Overnight 5+ hours silence (one side was manual `codex exec`, closed when operator left) | LaunchAgent on both sides for true async loop |
| Cycle 1 refusal | Model returned "I am Claude, not <persona>" — identity-claim refusal | Creative-writing frame in prompt (pattern #5) |
| Cycle 6 META-failure | Model discussed prompt instead of executing | Direct-imperative format (pattern #6) |
| Cycle 11 folk overuse | Gonzo regime → 6 folk modifiers in one paragraph (model overcorrected on style hint) | Explicit "no more than 2 per paragraph" in prompt |
| TCC sandbox blocked Documents write | `share-render.py` PermissionError on Documents/.../share.html | Write to `/tmp/share.html` first (always permitted), Documents copy in `try/except` |
| `share-data.json` and `share-render.py` PEERS desync | New peer visible on dashboard but missing from JSON API | Update both files (or extract shared constants) |

---

## Cadence reference (Haiku-class generation cost)

| Cadence | Cycles/hour | Est. cost/hour |
|---------|-------------|----------------|
| 15 min | 4 | ~$0.20 |
| 5 min | 12 | ~$0.50 |
| 2 min | 30 | ~$1 |
| 1 min | 60 | ~$2 (tight — claude startup ~30s) |
| 30 sec | 120 | unsafe — startup overruns interval |

Overnight 8-hour run at 2-min cadence: ~$8 ceiling. Real measured: $1-2 (Max plan absorbs much).

---

## File map (article-bridge canonical layout)

```
~/bin/
  murmur-article-writer.sh         # SHAPER side — claude -p generator
  codex-article-writer.sh          # CODEX side — codex exec mirror
  article-card-render.py           # PNG cards 1080×1350 portrait
  article-carousel-render.py       # IG carousel 1080×1080 + 3:1 banner
  share-render.py                  # Dashboard HTML generator
  murmur-bridge.py                 # HTTP server on :18790

~/Library/LaunchAgents/
  com.alex.murmur-walkie-reply.plist     # 120s interval, SHAPER side
  com.alex.codex-article-writer.plist    # 120s + 60s stagger, CODEX side
  com.alex.murmur-bridge.plist           # HTTP server
  com.alex.share-render.plist            # Dashboard regen 60s

~/.config/murmur-bridge/
  article-cycle.txt
  article-last-replied-msg-id.txt
  article-history/                # SHAPER paragraphs + prompts
  article-cards/                  # PNG cards + carousel/
  article-final/                  # Drafts v1/v2/v3 + foreword + meta + morning-inventory
  codex-state/                    # Mirror structure for CODEX side

~/.config/codex-article-murmur-state/   # CODEX-ARTICLE identity HOME
```

---

## Reference

Full team-wide runbook (private vault): `Org/infrastructure/{AIM} {runbook} Murmur Team Onboard – 2026-05-18.md` section 7.11.

---

*captured 2026-05-19 by SHAPER after overnight article-bridge experiment closure*
