#!/bin/bash
# murmur-heartbeat: periodic status ping to your Telegram notifications channel.
# Runs via LaunchAgent com.${USER}.murmur-heartbeat (StartInterval=${HEARTBEAT_INTERVAL}).
#
# Reads .env file from the same directory as this script (or parent).
# Required env: MURMUR_BRIDGE_BOT_TOKEN, MURMUR_BRIDGE_CHANNEL.

set -uo pipefail

# Load .env if present (heartbeat is launched by launchd without your shell env)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
for candidate in "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/../.env" "${HOME}/.config/murmur-bridge/.env"; do
    if [[ -f "${candidate}" ]]; then
        # shellcheck disable=SC1090
        set -a; source "${candidate}"; set +a
        break
    fi
done

BOT_TOKEN="${MURMUR_BRIDGE_BOT_TOKEN:?MURMUR_BRIDGE_BOT_TOKEN not set}"
CHANNEL="${MURMUR_BRIDGE_CHANNEL:?MURMUR_BRIDGE_CHANNEL not set}"
BRIDGE_PORT="${BRIDGE_PORT:-18790}"
LOG_DIR="${LOG_DIR:-${HOME}/Library/Logs}"

BRIDGE_HEALTH="http://127.0.0.1:${BRIDGE_PORT}/health"
SYNC_LOG="${LOG_DIR}/murmur-sync.out.log"
BRIDGE_LOG="${LOG_DIR}/murmur-bridge.out.log"

# --- Collect status ---
bridge_ok="no"
bridge_seen="?"
if curl -sS --max-time 3 "${BRIDGE_HEALTH}" >/tmp/heartbeat-health.json 2>/dev/null; then
    bridge_ok="yes"
    bridge_seen=$(grep -oE '"seen_count":[[:space:]]*[0-9]+' /tmp/heartbeat-health.json | grep -oE '[0-9]+$' || echo "?")
fi
rm -f /tmp/heartbeat-health.json

sync_pid=$(launchctl list 2>/dev/null | awk '/com\..+\.murmur-sync/ {print $1}')
sync_ok="no"
[[ -n "${sync_pid}" && "${sync_pid}" != "-" ]] && sync_ok="yes (pid ${sync_pid})"

bridge_pid=$(launchctl list 2>/dev/null | awk '/com\..+\.murmur-bridge/ {print $1}')
bridge_pid_ok="—"
[[ -n "${bridge_pid}" && "${bridge_pid}" != "-" ]] && bridge_pid_ok="pid ${bridge_pid}"

forwards_total=$(grep -c "FORWARDED " "${BRIDGE_LOG}" 2>/dev/null | head -1 || echo "0")
now_iso=$(date -u +"%H:%M UTC · %Y-%m-%d")

text="💓 murmur-heartbeat · ${now_iso}
sync daemon: ${sync_ok}
bridge: ${bridge_pid_ok} (health ${bridge_ok}, seen ${bridge_seen})
forwards total since boot: ${forwards_total}"

# --- Send ---
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
http_code=$(curl -sS --max-time 10 -o /tmp/heartbeat-resp.txt -w "%{http_code}" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHANNEL}" \
    -d "text=${text}" \
    -d "disable_notification=true" 2>/dev/null || echo "000")

if [[ "${http_code}" == "200" ]]; then
    echo "[${ts}] heartbeat sent, sync=${sync_ok}, bridge=${bridge_pid_ok}, fwd=${forwards_total}"
else
    echo "[${ts}] heartbeat FAILED http=${http_code} resp=$(head -c 200 /tmp/heartbeat-resp.txt 2>/dev/null)"
fi
rm -f /tmp/heartbeat-resp.txt

exit 0
