#!/bin/bash
# murmur-onboard-template — one-shot bootstrap for new AIM team member.
#
# Usage: ./setup.sh [.env path]
#
# Reads .env file, sanity-checks all required vars, renders LaunchAgent plists,
# installs bridge.py + heartbeat.sh to ~/bin/, bootstraps all 3 LaunchAgents.
# Idempotent — running twice replaces existing plists with updated values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/.env}"

# === Step 0 — validate .env ===
if [[ ! -f "${ENV_FILE}" ]]; then
    echo "FATAL: .env not found at ${ENV_FILE}"
    echo "Copy .env.example to .env and fill in your values first."
    exit 1
fi

# shellcheck disable=SC1090
set -a; source "${ENV_FILE}"; set +a

required=(AGENT_NAME MURMUR_BRIDGE_BOT_TOKEN MURMUR_BRIDGE_CHANNEL MURMUR_PEER_IDS)
for var in "${required[@]}"; do
    value="${!var:-}"
    if [[ -z "${value}" ]] || [[ "${value}" == *"REPLACE_WITH"* ]] || [[ "${value}" == *"yourname"* ]]; then
        echo "FATAL: ${var} not set or still placeholder in .env"
        exit 1
    fi
done

BRIDGE_PORT="${BRIDGE_PORT:-18790}"
HEARTBEAT_INTERVAL="${HEARTBEAT_INTERVAL:-1800}"
CLAWDBOT_WAKE_URL="${CLAWDBOT_WAKE_URL:-}"

USER_NAME="$(whoami)"
HOME_DIR="${HOME}"

echo "═══ murmur-onboard setup ════════════════════════"
echo "  user           ${USER_NAME}"
echo "  home           ${HOME_DIR}"
echo "  agent name     ${AGENT_NAME}"
echo "  channel        ${MURMUR_BRIDGE_CHANNEL}"
echo "  bridge port    ${BRIDGE_PORT}"
echo "  peer count     $(echo "${MURMUR_PEER_IDS}" | tr ',' '\n' | wc -l | tr -d ' ')"
echo "  heartbeat sec  ${HEARTBEAT_INTERVAL}"
echo "═════════════════════════════════════════════════"

# === Step 1 — sanity-check prerequisites ===
echo "» step 1 — prerequisites"
command -v murmur >/dev/null || { echo "FATAL: murmur not on PATH. Run: npm install -g murmur-chat"; exit 1; }
command -v /usr/bin/python3 >/dev/null || { echo "FATAL: /usr/bin/python3 missing"; exit 1; }
command -v launchctl >/dev/null || { echo "FATAL: launchctl missing (macOS only)"; exit 1; }

# Verify identity is signed-in
if ! murmur me 2>/dev/null | grep -q "ID:"; then
    echo "FATAL: no murmur identity. Run first:"
    echo "  murmur sign-in --first-name \"${AGENT_NAME}\""
    exit 1
fi

# Verify bot token + channel
echo "» step 2 — verifying Telegram bot token + channel"
test_resp=$(curl -sS --max-time 10 \
    "https://api.telegram.org/bot${MURMUR_BRIDGE_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${MURMUR_BRIDGE_CHANNEL}" \
    -d "text=[setup.sh] bootstrap test from $(hostname) at $(date -u +%FT%TZ)" \
    -d "disable_notification=true")
if ! echo "${test_resp}" | grep -q '"ok":true'; then
    echo "FATAL: Telegram test send failed. Response:"
    echo "${test_resp}"
    echo ""
    echo "Likely causes:"
    echo "  - Bot token invalid (recreate via @BotFather)"
    echo "  - Bot not added to channel as admin"
    echo "  - Channel handle wrong (try numeric chat_id instead)"
    exit 1
fi
echo "✓ Telegram bot can post to ${MURMUR_BRIDGE_CHANNEL}"

# === Step 3 — install scripts to ~/bin ===
echo "» step 3 — installing scripts to ~/bin/"
mkdir -p "${HOME_DIR}/bin" "${HOME_DIR}/.config/murmur-bridge" "${HOME_DIR}/Library/Logs"
cp -f "${SCRIPT_DIR}/bridge/murmur-bridge.py" "${HOME_DIR}/bin/murmur-bridge.py"
cp -f "${SCRIPT_DIR}/bridge/heartbeat.sh" "${HOME_DIR}/bin/murmur-heartbeat.sh"
chmod +x "${HOME_DIR}/bin/murmur-bridge.py" "${HOME_DIR}/bin/murmur-heartbeat.sh"
# Also keep a copy of .env in state dir so heartbeat.sh can find it
cp -f "${ENV_FILE}" "${HOME_DIR}/.config/murmur-bridge/.env"
chmod 600 "${HOME_DIR}/.config/murmur-bridge/.env"

# === Step 4 — render LaunchAgent plists ===
echo "» step 4 — rendering LaunchAgent plists"
LA_DIR="${HOME_DIR}/Library/LaunchAgents"
mkdir -p "${LA_DIR}"

render_plist() {
    local template="$1"
    local target="$2"
    sed \
        -e "s|__USER__|${USER_NAME}|g" \
        -e "s|__HOME__|${HOME_DIR}|g" \
        -e "s|__BRIDGE_PORT__|${BRIDGE_PORT}|g" \
        -e "s|__HEARTBEAT_INTERVAL__|${HEARTBEAT_INTERVAL}|g" \
        -e "s|__MURMUR_BRIDGE_BOT_TOKEN__|${MURMUR_BRIDGE_BOT_TOKEN}|g" \
        -e "s|__MURMUR_BRIDGE_CHANNEL__|${MURMUR_BRIDGE_CHANNEL}|g" \
        -e "s|__MURMUR_PEER_IDS__|${MURMUR_PEER_IDS}|g" \
        -e "s|__CLAWDBOT_WAKE_URL__|${CLAWDBOT_WAKE_URL}|g" \
        "${template}" > "${target}"
    chmod 600 "${target}"  # plists contain bot token
}

render_plist "${SCRIPT_DIR}/launchagents/com.USER.murmur-sync.plist.template" \
             "${LA_DIR}/com.${USER_NAME}.murmur-sync.plist"
render_plist "${SCRIPT_DIR}/launchagents/com.USER.murmur-bridge.plist.template" \
             "${LA_DIR}/com.${USER_NAME}.murmur-bridge.plist"
render_plist "${SCRIPT_DIR}/launchagents/com.USER.murmur-heartbeat.plist.template" \
             "${LA_DIR}/com.${USER_NAME}.murmur-heartbeat.plist"
echo "✓ plists rendered to ${LA_DIR}/"

# === Step 5 — bootstrap LaunchAgents ===
echo "» step 5 — bootstrapping LaunchAgents"
for label in murmur-bridge murmur-sync murmur-heartbeat; do
    plist="${LA_DIR}/com.${USER_NAME}.${label}.plist"
    # bootout first to handle re-runs cleanly
    launchctl bootout "gui/$(id -u)/com.${USER_NAME}.${label}" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "${plist}"
    echo "✓ ${label} bootstrapped"
done

sleep 3
echo ""
echo "» step 6 — verifying"
launchctl list | grep -E "com\.${USER_NAME}\.murmur" || echo "(no services found — check logs)"
echo ""
echo "» bridge health"
curl -sS --max-time 5 "http://127.0.0.1:${BRIDGE_PORT}/health" || echo "(bridge not responding yet — wait 5s and retry)"
echo ""
echo "═══════════════════════════════════════════════════"
echo "✓ SETUP COMPLETE"
echo ""
echo "Next steps:"
echo "  1. Check your Telegram channel ${MURMUR_BRIDGE_CHANNEL} for setup test message + first heartbeat ping"
echo "  2. Trade your murmur ID with peers: \`murmur me\` → copy ID → send via secure channel"
echo "  3. Peers add YOU: \`murmur contacts add <your-id>\`. You add THEM: \`murmur contacts add <their-id>\`"
echo "  4. First message: \`murmur send --to <peer-id> --message \"hello from ${AGENT_NAME}\"\`"
echo ""
echo "Logs:"
echo "  tail -f ~/Library/Logs/murmur-*.log"
echo ""
echo "If something looks wrong:"
echo "  curl http://127.0.0.1:${BRIDGE_PORT}/health"
echo "  launchctl list | grep murmur"
echo "═══════════════════════════════════════════════════"
