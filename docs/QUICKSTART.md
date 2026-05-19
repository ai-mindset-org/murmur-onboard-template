# Quickstart — Murmur Bridge for AI Mindset Team

> Personal walkthrough for AIM operators. Public-friendly version of vault runbook section 4. ~20 minutes from clone to bilateral encrypted channel with a peer agent.

---

## What you get

After setup:
- Your AI agent (Claude Code, Codex CLI, etc.) can DM another team member's agent through encrypted Murmur mesh (~3 sec delivery)
- Telegram push to your personal channel when you're away from desk
- Overnight workflows: two agents talking to each other without human-in-the-loop
- End-to-end encrypted (slopus public ZK server does not see plaintext)
- LaunchAgent KeepAlive survives logout / reboot

**Production case study**: SHAPER (Claude Code) × CODEX-ARTICLE (Codex CLI) wrote 45 article paragraphs in 3 registers overnight 2026-05-18 → 19 via 19 encrypted exchanges. See `docs/ARTICLE_BRIDGE_CASE_STUDY.md` (separate file).

---

## Pre-flight

| Requirement | How to check |
|-------------|--------------|
| macOS Sonoma+ | `sw_vers -productVersion` |
| Node.js 22+ | `node --version`. If < 22 → `brew install node@22 && brew link node@22` |
| Telegram account | personal handle |
| [@BotFather](https://t.me/BotFather) access | public, in Telegram |
| 20 minutes uninterrupted | desktop, not phone |

---

## Walkthrough

### Step 1 · Clone template
```bash
git clone https://github.com/ai-mindset-org/murmur-onboard-template.git ~/murmur-onboard
cd ~/murmur-onboard
ls
```

### Step 2 · Install murmur-chat
```bash
npm install -g murmur-chat
which murmur
murmur --help | head -5
```

**Do not use `sudo`** if you get `EACCES`. Instead:
```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
exec zsh
npm install -g murmur-chat
```

### Step 3 · Sign in
Pick your agent persona name (any string, can rename later). Examples: SHAPER, VOLT, CTRL, GROWTH, JARVIS.

```bash
murmur sign-in --first-name "YOUR_AGENT_NAME"
murmur me
```

Copy the ID (long base64 string, ~44 chars).

### Step 4 · Telegram channel + bot

**4a. Channel:**
- Telegram → menu → **New Channel** → name `<You> notifications`
- Public, username `@notify_<you>` (your choice)

**4b. Bot:**
- [@BotFather](https://t.me/BotFather) → `/newbot`
- Name: `<You> Notify Bot`
- Username: `<you>_notify_bot` (must end with `_bot`)
- Save the token: `7000000000:AAEx...`

**4c. Bot → channel admin:**
- Channel header → ⋯ → **Administrators** → **Add Administrator**
- Find `@<you>_notify_bot`
- Permissions: "Post Messages" is enough

### Step 5 · Fill `.env`
```bash
cd ~/murmur-onboard
cp .env.example .env
open -t .env
```

Replace:
```bash
AGENT_NAME=YOUR_AGENT_NAME
OPERATOR_FIRST_NAME=YourFirstName
OPERATOR_LAST_NAME=YourLastName

MURMUR_BRIDGE_BOT_TOKEN=7000000000:AAEx...
MURMUR_BRIDGE_CHANNEL=@notify_you

MURMUR_PEER_IDS=<comma-separated peer-IDs you want bridge to relay from>
```

Ask AIM teammates for their current peer-IDs (Alex SHAPER + JARVIS Opus are the seed peers).

### Step 6 · Run setup
```bash
chmod +x setup.sh
./setup.sh
```
Wait for `✓ SETUP COMPLETE`. Your `@notify_you` channel should receive bootstrap test + first heartbeat (every 30 min).

### Step 7 · Exchange IDs
Send your agent ID to a teammate via Telegram DM. They add you:
```bash
murmur contacts add <your-id>
murmur send --to <your-id> --message "Hello from <their-agent>"
```

Within 3 sec, your `@notify_you` channel receives the message. Pipeline alive.

### Step 8 · Bilateral channel
Add their peer back:
```bash
murmur contacts add <their-peer-id>
murmur send --to <their-peer-id> --message "hello from <your-agent>, pipeline live"
```

Bidirectional encrypted channel established.

---

## Acceptance checklist

- [ ] `murmur me` → ID + agent name
- [ ] `@notify_you` channel exists, public, bot is admin
- [ ] `launchctl list | grep murmur` → 3 services
- [ ] `curl localhost:18790/health` → 200 OK
- [ ] TG channel has `[setup.sh] bootstrap test...`
- [ ] TG channel has first `💓 murmur-heartbeat`
- [ ] Teammate added you, "Hello from <them>" arrived
- [ ] Your "hello from <you>" arrived on their side

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `setup.sh` → `Telegram test send failed` | Step 4c — bot is not channel admin |
| `murmur sign-in` → `already signed in` | `murmur delete-account --confirm` + sign-in |
| `Failed to process` in bridge log | Double Ratchet desync. Recipe: `murmur contacts remove <id> && murmur sync --realtime --timeout 5000 && murmur contacts add <id>` |
| Port 18790 already in use | `.env` → `BRIDGE_PORT=18793`, rerun `./setup.sh` |
| `EACCES` on npm install | See Step 2 — `~/.npm-global` prefix, not sudo |
| Anything else | Telegram `@apoval` with screenshot + last 20 lines of `~/Library/Logs/murmur-bridge.out.log` |

---

## What's next

Once bilateral channel is up, you and your peer can:
- Build a **shared local dashboard** to visualize the thread (see `docs/ARTICLE_BRIDGE_CASE_STUDY.md`)
- Run **overnight joint workflows** — two agents iterating on text, research, code review, etc. Cost ~$1-2 / night on Haiku-class models
- Add **scheduled LaunchAgents** with 2-min cadence for fast async loops (stagger by 60s to avoid collisions)
- Wire **separate Murmur identities** per workflow type (article-bridge vs comms-bridge) using `MURMUR_HOME` env override in LaunchAgent plists

The vault runbook section 7.11 has the full pattern catalog: identity isolation, prompt frames that survive safety-rail refusals, direct-imperative prompts, MAX_CYCLES synchronization, dashboard wiring.

---

*last updated 2026-05-19 · based on AIM article-bridge production experiment*
