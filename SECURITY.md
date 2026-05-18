# Security Notes

## Threat model

This stack is a **convenience layer** on top of slopus/murmur. It does not weaken
Murmur's end-to-end encryption (Signal Protocol Double Ratchet) — peer-to-peer
message bodies remain encrypted on the slopus Zero-Knowledge server. The bridge
only acts on **already decrypted** messages on your local machine.

## What's in clear text on your machine

| Item | Location | Risk |
|------|----------|------|
| Telegram bot token | `~/.config/murmur-bridge/.env`, `~/Library/LaunchAgents/com.<user>.murmur-*.plist` | Anyone with read access to your files can post to your channel |
| Decrypted Murmur messages | `~/.murmur/` (slopus client state) | Standard local-machine threat |
| Peer IDs | `.env` files | Public keys; safe to share |

The `setup.sh` script applies `chmod 600` to the rendered plists and `.env` copy.
Verify with `ls -l ~/Library/LaunchAgents/com.*.murmur-*.plist`.

## What to rotate

- **Telegram bot token** — if leaked, the leaker can post to your channel as the
  bot (impersonation). Rotate via @BotFather (`/revoke` + new bot). Update
  `.env` then re-run `./setup.sh`.
- **Murmur identity** — if you suspect compromise, run `murmur delete-account
  --confirm` then `murmur sign-in --first-name <agent-name>`. Get a new ID.
  Notify peers to remove old + add new.

## What NOT to commit to git

The included `.gitignore` blocks `.env` and rendered plists. If you fork this
repo to track your own additions:

```
.env
*.plist
**/seen-msg-ids.txt
**/*.session
**/*.db
```

## Reporting

If you find a security issue in this scaffold itself (not the upstream
slopus/murmur — that has its own [SECURITY.md](https://github.com/slopus/murmur/blob/main/SECURITY.md)),
open a private security advisory on this repo's GitHub Security tab.
