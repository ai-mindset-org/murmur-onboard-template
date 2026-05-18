#!/usr/bin/env python3
"""
murmur-bridge: webhook receiver that forwards new Murmur incoming messages
to a Telegram channel via Bot API, optionally pings clawdbot-gateway to wake
any active Claude Code session.

Architecture:
    murmur sync --realtime --webhook http://127.0.0.1:${BRIDGE_PORT}/murmur
        ↓
    this script (POST /murmur)
        ↓
    murmur messages --with <PEER_ID> --limit 8   (re-fetch decrypted bodies)
        ↓
    Telegram Bot API → ${MURMUR_BRIDGE_CHANNEL}

Environment variables (read at startup):
    MURMUR_BRIDGE_BOT_TOKEN   — required, Telegram bot API token
    MURMUR_BRIDGE_CHANNEL     — required, channel handle (@xxx) or numeric chat_id
    MURMUR_PEER_IDS           — required, comma-separated 44-char base64 peer IDs
    BRIDGE_PORT               — default 18790
    MURMUR_BIN                — default /opt/homebrew/bin/murmur
    CLAWDBOT_WAKE_URL         — optional, GET this URL on every event
    STATE_DIR                 — default ~/.config/murmur-bridge

State files:
    ${STATE_DIR}/seen-msg-ids.txt — dedupe across restarts

Endpoints:
    POST /murmur   — Murmur sync POSTs here on each incoming
    GET  /health   — liveness probe (returns seen count, config summary)

Setup is `./setup.sh` — copy .env.example → .env, run setup.sh, it bootstraps
LaunchAgents from launchagents/*.plist.template.
"""

import http.server
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

# --- Config from environment ---
PORT = int(os.environ.get("BRIDGE_PORT", "18790"))
BOT_TOKEN = os.environ.get("MURMUR_BRIDGE_BOT_TOKEN", "")
CHANNEL = os.environ.get("MURMUR_BRIDGE_CHANNEL", "")
PEER_IDS = [p.strip() for p in os.environ.get("MURMUR_PEER_IDS", "").split(",") if p.strip()]
MURMUR_BIN = os.environ.get("MURMUR_BIN", "/opt/homebrew/bin/murmur")
CLAWDBOT_WAKE = os.environ.get("CLAWDBOT_WAKE_URL", "").strip() or None
STATE_DIR = os.path.expanduser(os.environ.get("STATE_DIR", "~/.config/murmur-bridge"))
SEEN_FILE = os.path.join(STATE_DIR, "seen-msg-ids.txt")

os.makedirs(STATE_DIR, exist_ok=True)
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def log(msg: str) -> None:
    ts = datetime.now(timezone.utc).isoformat(timespec="seconds")
    print(f"[{ts}] {msg}", flush=True)


def validate_config() -> bool:
    missing = []
    if not BOT_TOKEN or BOT_TOKEN.startswith("000000"):
        missing.append("MURMUR_BRIDGE_BOT_TOKEN")
    if not CHANNEL:
        missing.append("MURMUR_BRIDGE_CHANNEL")
    if not PEER_IDS:
        missing.append("MURMUR_PEER_IDS")
    if missing:
        log(f"FATAL: missing required env vars: {', '.join(missing)}")
        log("see .env.example for required configuration")
        return False
    return True


def load_seen() -> set:
    try:
        with open(SEEN_FILE) as f:
            return {line.strip() for line in f if line.strip()}
    except FileNotFoundError:
        return set()


def mark_seen(msg_id: str) -> None:
    with open(SEEN_FILE, "a") as f:
        f.write(msg_id + "\n")


def fetch_messages_from_peer(peer_id: str, limit: int = 8) -> list:
    """Run `murmur messages --with <peer> --limit N`, parse blocks."""
    try:
        proc = subprocess.run(
            [MURMUR_BIN, "messages", "--with", peer_id, "--limit", str(limit)],
            capture_output=True,
            text=True,
            timeout=20,
        )
    except subprocess.TimeoutExpired:
        log(f"ERROR fetch_messages_from_peer({peer_id[:12]}…): timeout")
        return []
    if proc.returncode != 0:
        log(f"ERROR fetch_messages_from_peer rc={proc.returncode}: {proc.stderr.strip()[:200]}")
        return []

    text = ANSI_RE.sub("", proc.stdout)
    blocks, current, in_body = [], None, False
    for line in text.split("\n"):
        if line.strip() == "----":
            if current and current.get("id"):
                blocks.append(current)
            current, in_body = {"body_lines": []}, False
            continue
        if current is None:
            continue
        if line.startswith("Message ID:"):
            current["id"] = line.split(":", 1)[1].strip()
        elif line.startswith("Sender ID:"):
            current["sender_id"] = line.split(":", 1)[1].strip()
        elif line.startswith("Sender Name:"):
            current["sender_name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Date:"):
            current["date"] = line.split(":", 1)[1].strip()
            in_body = True
        elif in_body:
            current["body_lines"].append(line)
    if current and current.get("id"):
        blocks.append(current)
    for b in blocks:
        b["body"] = "\n".join(b.get("body_lines", [])).strip()
        b.pop("body_lines", None)
    return blocks


def telegram_send(text: str) -> dict:
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = urllib.parse.urlencode(
        {
            "chat_id": CHANNEL,
            "text": text[:4000],
            "parse_mode": "HTML",
            "disable_web_page_preview": "true",
        }
    ).encode()
    req = urllib.request.Request(url, data=payload, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except Exception as e:
        log(f"ERROR telegram_send: {type(e).__name__}: {e}")
        return {"ok": False, "error": str(e)}


def html_escape(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def format_message(m: dict) -> str:
    sender = html_escape(m.get("sender_name", "unknown"))
    body = m.get("body", "") or "(empty body)"
    msg_id = m.get("id", "")
    date_iso = m.get("date", "")
    if len(body) > 1800:
        body = body[:1800] + "\n…(truncated, full body in murmur)"
    body = html_escape(body)
    timestr = date_iso
    try:
        dt = datetime.fromisoformat(date_iso.replace("Z", "+00:00"))
        timestr = dt.astimezone(timezone.utc).strftime("%H:%M:%S UTC · %Y-%m-%d")
    except Exception:
        pass
    return (
        f"📨 <b>{sender}</b> → murmur\n"
        f"<code>{html_escape(msg_id)}</code>\n"
        f"<i>{timestr}</i>\n\n"
        f"{body}"
    )


def wake_clawdbot() -> None:
    if not CLAWDBOT_WAKE:
        return
    try:
        urllib.request.urlopen(CLAWDBOT_WAKE, timeout=5)
    except Exception as e:
        log(f"WARN wake_clawdbot failed: {e}")


class BridgeHandler(http.server.BaseHTTPRequestHandler):
    server_version = "MurmurBridge/0.1"

    def log_message(self, fmt, *args):
        return  # silenced; use module-level log() instead

    def _send_json(self, code: int, obj: dict) -> None:
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/health"):
            self._send_json(
                200,
                {
                    "ok": True,
                    "service": "murmur-bridge",
                    "port": PORT,
                    "channel": CHANNEL,
                    "peer_count": len(PEER_IDS),
                    "seen_count": len(load_seen()),
                },
            )
            return
        self._send_json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length > 0:
            try:
                self.rfile.read(min(length, 65536))
            except Exception:
                pass

        seen = load_seen()
        forwarded, skipped = [], 0

        for peer_id in PEER_IDS:
            messages = fetch_messages_from_peer(peer_id)
            for m in messages:
                mid = m.get("id")
                if not mid or mid in seen:
                    skipped += 1
                    continue
                if m.get("sender_id") != peer_id:
                    continue  # ignore our own echoes
                result = telegram_send(format_message(m))
                if result.get("ok"):
                    mark_seen(mid)
                    forwarded.append(mid)
                    log(f"FORWARDED {mid} from {peer_id[:12]}… → {CHANNEL}")
                else:
                    log(f"FAILED to forward {mid}: {result.get('error') or result}")

        wake_clawdbot()
        self._send_json(200, {"ok": True, "forwarded": forwarded, "skipped": skipped})


def main():
    if not validate_config():
        sys.exit(1)
    log(f"murmur-bridge starting on 127.0.0.1:{PORT}")
    log(f"channel={CHANNEL}, peers={len(PEER_IDS)}, seen={len(load_seen())}")
    server = http.server.HTTPServer(("127.0.0.1", PORT), BridgeHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("interrupt; shutting down")
        server.server_close()


if __name__ == "__main__":
    main()
