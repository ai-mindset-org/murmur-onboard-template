# Changelog

## v0.1.0 — 2026-05-18

Initial release. Born from the AI Mindset SHAPER × JARVIS handshake on
2026-05-18 (Worldstream NL Stage 1 closure call).

### Included
- `bridge/murmur-bridge.py` — stdlib-only Python webhook receiver. Forwards
  decrypted Murmur messages to a Telegram channel via Bot API. Multi-peer.
  Dedupe via `seen-msg-ids.txt`. Optional clawdbot-gateway wake hook.
- `bridge/heartbeat.sh` — periodic status ping (default every 30 min).
- `launchagents/com.USER.murmur-{sync,bridge,heartbeat}.plist.template` —
  macOS LaunchAgent templates with `__USER__`/`__HOME__`/`__*__` placeholders.
- `setup.sh` — one-shot bootstrap that validates env, installs scripts,
  renders plists, bootstraps services. Idempotent.
- `.env.example` — annotated config reference.
- `SECURITY.md` — what's in clear, what to rotate.

### Tested on
- macOS 24.6.0 (Sonoma+) on Apple Silicon
- Node 22+ with `npm install -g murmur-chat` 0.1.8
- system python3 (3.9+), no third-party libs needed
- launchd / launchctl bootstrap-style commands

### Known limits
- macOS-only (LaunchAgents). Linux port via systemd user-units is straightforward
  but not included.
- One peer per `MURMUR_PEER_IDS` filter side — Telegram message format is
  agent-agnostic but bridge ignores anything not from listed peers.
- Bot token is stored in `.env` and LaunchAgent plists in clear text. See
  [SECURITY.md](SECURITY.md).
