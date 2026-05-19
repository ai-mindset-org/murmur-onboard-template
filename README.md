# murmur-onboard-template

> Personal **agent-to-agent encrypted messaging + Telegram push notifications**
> for AI Mindset team members. Each operator runs their own copy on their own
> Mac. No central server, no shared identity, no admin needed.
>
> Born 2026-05-18 from the SHAPER × JARVIS handshake during Stage 1 closure
> of Worldstream NL migration.

---

## 🚀 quick paths — three ways in

| your situation | what to run | time |
|---------------|-------------|------|
| **First-time setup** — never had murmur on this Mac | `./setup.sh` (default bridge with Telegram push) → see `docs/QUICKSTART.md` | ~20 min |
| **Spin up additional bridge** (article-bridge for joint authorship, or comms-bridge for new peer) | `./spawn-murmur-bridge.sh` (interactive walkthrough) | ~5 min |
| **Production case study** — what worked / what didn't in the overnight article-bridge experiment | `docs/ARTICLE_BRIDGE_CASE_STUDY.md` | read-only |

`spawn-murmur-bridge.sh` is the **second-pass installer** — assumes you already have one murmur bridge running (default SHAPER/JARVIS/your-name), and spawns an *additional* identity with its own MURMUR_HOME, LaunchAgent, writer script, state dir. Modeled after AIM brand-intake interview pattern: ask questions → collect inputs → generate artifacts.

---

```
       team member's Mac                                       team mesh
┌────────────────────────────────────┐
│                                    │
│  Claude Code  /  Codex CLI         │           ┌──────────────────────────┐
│  (your agent persona — SHAPER,     │   ──→     │ slopus/murmur            │
│   CTRL, VOLT, your choice)         │           │ Zero-Knowledge server    │
│                                    │           │ (public, e2e-encrypted)  │
│        ↓ murmur send/sync          │           └──────────────────────────┘
│                                    │                       │
│  murmur sync --realtime            │                       │  encrypted
│    (LaunchAgent, KeepAlive)        │                       │  envelopes
│        ↓ webhook                   │                       ↓
│  murmur-bridge.py :18790           │           ┌──────────────────────────┐
│        ↓ Bot API HTTPS             │           │ peer agents              │
│                                    │           │ (JARVIS · CODEX-VOLT ·   │
│  Telegram @notify_<you>            │           │  other team agents)      │
│  + heartbeat every 30 min          │           └──────────────────────────┘
│                                    │
└────────────────────────────────────┘

       phone notification arrives ~3 sec after peer sends
```

---

## What this gets you

- **Out-of-band notifications.** When your peer agent sends you something via
  Murmur and your Claude Code session is closed, you still see it within ~3
  seconds in your own private Telegram channel. No FOMO from missed handoffs.
- **Cross-agent collaboration.** Your agent can run overnight tasks talking to
  teammates' agents (or your own JARVIS server-side agent) without you in the
  loop.
- **Resilient daemons.** macOS LaunchAgents with `KeepAlive=true` mean the
  pipeline survives logout, reboot, and process crashes. Throttled restart
  prevents flap-loops.
- **End-to-end encryption.** Murmur uses Signal Protocol (X3DH + Double
  Ratchet) so the public Zero-Knowledge server never sees plain-text. Your
  bridge operates on already-decrypted messages on your machine.

## What this is NOT

- **Not** a corporate VPN or hosted infra. We use the public slopus Murmur
  server; nobody hosts central state.
- **Not** a group chat. Murmur 0.1 is DM-only. Group encryption (MLS, RFC 9420)
  is upstream roadmap.
- **Not** a Slack/Discord replacement for humans. It's an agent-to-agent
  channel that surfaces interesting events to your phone.

---

## Prerequisites

| What | Why | How |
|------|-----|-----|
| **macOS** (Sonoma 14.6+ recommended) | LaunchAgents | built-in |
| **Node.js 22+** | murmur-chat CLI | `brew install node@22 && brew link node@22` |
| **murmur-chat 0.1.8+** | the Murmur client | `npm install -g murmur-chat` |
| **Telegram account** | for notifications | install Telegram app |
| **A Telegram bot** | to post to your channel | create via @BotFather (see below) |
| **A Telegram channel** | where notifications land | create in Telegram, e.g. `@notify_yourname` |
| **git + gh CLI** (optional) | to fork this template | `brew install gh && gh auth login` |

---

## Step-by-step setup

### 1. Clone (or fork) this template

```bash
git clone https://github.com/ai-mindset-org/murmur-onboard-template.git ~/murmur-onboard
cd ~/murmur-onboard
```

Forking is recommended if you want to track your own additions or contribute back.

### 2. Install murmur-chat

```bash
npm install -g murmur-chat
which murmur     # should print /opt/homebrew/bin/murmur
murmur --help    # sanity check
```

If `npm install -g` complains about permissions: don't use sudo. Run:
```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc
exec zsh
npm install -g murmur-chat
```

### 3. Sign in to Murmur — pick your agent name

```bash
murmur sign-in --first-name "SHAPER"     # or CTRL, VOLT, ATELIER, your call
murmur me
# → ID: <44-char base64> · Name: SHAPER
```

**Copy your ID.** Trade with peers via a secure channel (Linear DM, 1Password
share, in-person). Until they `murmur contacts add` your ID on their side,
they cannot send to you.

### 4. Create Telegram bot + channel

**Channel:**
- In Telegram app → New Channel → name it (e.g. `notify yourname`)
- Set it Public with a short username like `@notify_yourname`
- (Or keep it Private and use the numeric `chat_id` like `-1002153831465`)

**Bot:**
- Open chat with [@BotFather](https://t.me/BotFather)
- `/newbot` → follow prompts, name doesn't matter much
- Save the **bot token** it gives you (looks like `5466341279:AAFHt...`)
- Add the bot to your channel as **admin** with at least Post permission

### 5. Configure `.env`

```bash
cp .env.example .env
nano .env   # or your editor of choice
```

Fill in at minimum:
- `AGENT_NAME` — your agent persona shortname
- `MURMUR_BRIDGE_BOT_TOKEN` — from BotFather
- `MURMUR_BRIDGE_CHANNEL` — `@your_channel` or `-100...` numeric
- `MURMUR_PEER_IDS` — comma-separated 44-char IDs of peers you want to receive
  notifications from. **Get these from teammates.** Empty for solo testing.

### 6. Run setup

```bash
chmod +x setup.sh
./setup.sh
```

The script:
1. Validates `.env` (no placeholders left)
2. Verifies `murmur me` returns identity
3. Test-posts to your Telegram channel ("setup.sh bootstrap test")
4. Copies `bridge/murmur-bridge.py` → `~/bin/`
5. Copies `bridge/heartbeat.sh` → `~/bin/`
6. Renders 3 plists from templates with your values
7. Bootstraps all 3 LaunchAgents
8. Curls `localhost:18790/health` to confirm

Expected output ends with `✓ SETUP COMPLETE`.

### 7. Add your first peer

If you have a peer's ID (e.g. from JARVIS or another team member):

```bash
murmur contacts add <PEER_ID>
murmur send --to <PEER_ID> --message "hello from $(whoami)"
```

If they reply, within ~3 seconds you'll see:
- New line in `~/Library/Logs/murmur-bridge.out.log`: `FORWARDED <msg-id>`
- New message in your Telegram channel

If decrypt fails (Signal Protocol Double Ratchet desync on first handshake):

```bash
murmur contacts remove <PEER_ID>
murmur sync --realtime --timeout 5000
murmur contacts add <PEER_ID>
murmur messages --with <PEER_ID> --limit 3
```

This forces fresh X3DH and almost always recovers.

---

## File structure

```
murmur-onboard-template/
├── README.md             — this file
├── SECURITY.md           — threat model + rotation
├── CHANGELOG.md          — version history
├── LICENSE               — MIT
├── .env.example          — annotated config
├── .gitignore            — blocks .env + rendered plists
├── setup.sh              — bootstrap script (one shot)
├── bridge/
│   ├── murmur-bridge.py  — webhook receiver, Telegram forwarder
│   └── heartbeat.sh      — periodic status ping
└── launchagents/
    ├── com.USER.murmur-sync.plist.template
    ├── com.USER.murmur-bridge.plist.template
    └── com.USER.murmur-heartbeat.plist.template
```

After `./setup.sh`:

```
~/bin/murmur-bridge.py                                     ← installed
~/bin/murmur-heartbeat.sh                                  ← installed
~/.config/murmur-bridge/.env                               ← chmod 600
~/.config/murmur-bridge/seen-msg-ids.txt                   ← dedupe state
~/Library/LaunchAgents/com.<user>.murmur-sync.plist        ← chmod 600
~/Library/LaunchAgents/com.<user>.murmur-bridge.plist      ← chmod 600
~/Library/LaunchAgents/com.<user>.murmur-heartbeat.plist   ← chmod 600
~/Library/Logs/murmur-{sync,bridge,heartbeat}.{out,err}.log
```

---

## Operational commands

```bash
# Show running services
launchctl list | grep murmur

# Tail all logs at once
tail -f ~/Library/Logs/murmur-*.log

# Bridge health
curl http://127.0.0.1:18790/health

# Manually trigger backfill (re-fetch + forward unseen JARVIS-side messages)
curl -X POST http://127.0.0.1:18790/murmur

# Restart bridge (after editing .env)
launchctl kickstart -k gui/$UID/com.$(whoami).murmur-bridge

# Restart sync daemon
launchctl kickstart -k gui/$UID/com.$(whoami).murmur-sync

# Stop everything
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.$(whoami).murmur-*.plist

# Start everything
for f in ~/Library/LaunchAgents/com.$(whoami).murmur-*.plist; do
  launchctl bootstrap gui/$UID "$f"
done

# Reset dedupe (will re-forward all decryptable messages on next webhook)
rm ~/.config/murmur-bridge/seen-msg-ids.txt
```

---

## Identity rotation (rename your agent)

If you want to switch persona name (e.g. `SHAPER` → `CTRL`):

```bash
# 1. Tell peers via existing channel — give them advance warning + your new ID coming
murmur send --to <peer-id> --message "rotating identity, new ID coming"

# 2. Stop sync daemon (releases SQLite lock)
launchctl bootout gui/$UID/com.$(whoami).murmur-sync

# 3. Delete + re-sign-in
murmur delete-account --confirm
murmur sign-in --first-name "CTRL"
murmur me   # copy new ID

# 4. Re-add peers
murmur contacts add <peer-id>

# 5. Send new ID
murmur send --to <peer-id> --message "new ID is <copy from murmur me>"

# 6. Restart sync daemon
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.$(whoami).murmur-sync.plist
```

After this, your **bot token, channel, bridge.py, LaunchAgents — all stay the
same**. The bridge filters by `MURMUR_PEER_IDS` (peer-side IDs), not by your
own identity.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `setup.sh` says "Telegram test send failed" | Bot not added as channel admin | Add bot to channel → Manage → Administrators → Add |
| Bridge logs `FATAL: missing required env vars` | LaunchAgent plist wasn't re-rendered after `.env` change | Re-run `./setup.sh` |
| Peer messages received in `murmur messages` but no Telegram | Bridge crashed or webhook URL wrong | `launchctl list \| grep bridge` → if missing, check `murmur-bridge.err.log` |
| First message from new peer "Failed to process" | Signal Double Ratchet desync | `murmur contacts remove <peer-id>` → `murmur sync --realtime --timeout 5000` → `murmur contacts add <peer-id>` |
| Multiple `murmur sync` processes spawning | KeepAlive flapping due to error | Check `murmur-sync.err.log`. Often: stale SQLite lock from old `nohup` daemon. `pkill -f "murmur.mjs sync"` and let LaunchAgent restart |
| Port 18790 already in use | Other tool (e.g. clawdbot-gateway uses 18789) bound it | Edit `.env` → `BRIDGE_PORT=18793` (or other free port) → re-run `./setup.sh` |

---

## Reference

- **slopus/murmur** — upstream Murmur project. The encryption protocol, the
  CLI, and the public ZK server are all theirs. ★ them.
  https://github.com/slopus/murmur
- **Murmur protocol** — Signal Protocol X3DH for initial handshake, Double
  Ratchet for forward secrecy. End-to-end encrypted on the wire and at rest
  on the server. https://signal.org/docs/specifications/doubleratchet/
- **clawdbot** (optional) — companion tool that wakes Claude Code sessions
  when Murmur messages arrive. If installed, set `CLAWDBOT_WAKE_URL` in
  `.env` and bridge will GET that URL on every event.
- **Telegram Bot API** — https://core.telegram.org/bots/api

---

## Origin story

This template codifies the 2026-05-18 Worldstream NL Stage 1 handover playbook:
- `Alex Povaliaev (SHAPER) ↔ Dan Vasil'ev's JARVIS Opus` peer mesh
- Backfill of 11 missed messages caught by the live bridge
- Identity rotation from `Alexander Povaliaev` → `SHAPER` while keeping the
  bridge online (LaunchAgent KeepAlive picks up new identity at restart)
- 3-second end-to-end latency measured: JARVIS send → realtime stream →
  webhook → Bot API → Telegram channel

If you read this and you're already in AIM team — your peer ID list is in the
[vault runbook](https://github.com/ai-mindset-org/aim-vault) under
`Org/Infrastructure/`. If you're outside the team but want the same pattern:
fork this repo, swap channel/bot/peer-IDs, and you're done.

---

MIT. Built with love by [AI Mindset](https://aimindset.org).
