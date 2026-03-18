# 🦞 openclaw-backup-nas

Auto backup, health check, and self-restore for [OpenClaw](https://openclaw.ai) running on **Synology NAS** with Docker ContainerManager.

## What it does

- **Before AI edits config files** → automatically backs up all OpenClaw containers
- **After AI edits** → confirms all containers are healthy (HTTP 200)
- **If healthy** → cancels the restore schedule, logs success
- **If no confirmation within 10 minutes** → watchdog checks each container and **restores only the failed ones**
- **Notifies** via LINE Messaging API, Telegram, and Gmail
- **Anti-loop protection** → 30-minute cooldown after restore
- **Keeps 3 days of backups** to save disk space

## Install

```bash
npx clawhub install openclaw-backup-nas
```

## Setup (one-time)

### 1. Download scripts

```bash
BASE="https://raw.githubusercontent.com/crazydb911/openclaw-backup-nas/main/scripts"
for SCRIPT in openclaw-backup.sh openclaw-restore.sh openclaw-list-backups.sh openclaw-health-watchdog.sh openclaw-pre-edit-hook.sh openclaw-post-edit-hook.sh; do
    curl -o ~/$SCRIPT $BASE/$SCRIPT
    chmod +x ~/$SCRIPT
done
```

### 2. Fix file permissions (one-time, required for non-root backup)

```bash
sudo find /volume1/docker1/openclaw -exec chmod a+rw {} \;
sudo find /volume1/docker2/openclaw -exec chmod a+rw {} \;
sudo find /volume1/docker3/openclaw -exec chmod a+rw {} \;
sudo find /volume1/docker1/openclaw -type d -exec chmod a+rwx {} \;
sudo find /volume1/docker2/openclaw -type d -exec chmod a+rwx {} \;
sudo find /volume1/docker3/openclaw -type d -exec chmod a+rwx {} \;
sudo chmod a+rx /volume1/docker3
```

### 3. Set up notifications (optional)

Create `~/openclaw-notify.conf` with your credentials:

```bash
# LINE Messaging API
LINE_CHANNEL_ACCESS_TOKEN=""
LINE_USER_ID=""

# Gmail SMTP
MAIL_TO="you@gmail.com"
MAIL_FROM="you@gmail.com"
GMAIL_APP_PASSWORD=""   # from https://myaccount.google.com/apppasswords

# Telegram
TELEGRAM_CHAT_ID=""     # from @userinfobot
TELEGRAM_TOKEN_A=""     # docker1 bot token
TELEGRAM_TOKEN_B=""     # docker2 bot token
TELEGRAM_TOKEN_C=""     # docker3 bot token

# Alert threshold
FAIL_THRESHOLD=2
```

```bash
chmod 600 ~/openclaw-notify.conf
```

### 4. Set up Synology Task Scheduler

Create two tasks in **Control Panel → Task Scheduler**:

| Task | User | Schedule | Command |
|------|------|----------|---------|
| OpenClaw 備份 | root | Every 6h (0,6,12,18) | `bash ~/openclaw-backup.sh` |
| OpenClaw Watchdog | your-user | Every minute | `bash ~/openclaw-health-watchdog.sh` |

### 5. Set up Claude Code hooks

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash ~/openclaw-pre-edit-hook.sh", "timeout": 60, "statusMessage": "Backing up OpenClaw..." }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash ~/openclaw-post-edit-hook.sh", "timeout": 10 }]
      }
    ]
  }
}
```

## Files

| File | Description |
|------|-------------|
| `scripts/openclaw-backup.sh` | Backup all containers (tar, 3-day retention) |
| `scripts/openclaw-restore.sh` | Restore latest or specific backup |
| `scripts/openclaw-list-backups.sh` | List all available backups |
| `scripts/openclaw-health-watchdog.sh` | Health check + per-container auto-restore |
| `scripts/openclaw-pre-edit-hook.sh` | Claude Code pre-edit hook |
| `scripts/openclaw-post-edit-hook.sh` | Claude Code post-edit hook |

## Logs

- Backup/restore log: `~/openclaw-backups/backup.log`
- Incident log (death note): `~/openclaw-death-note.log`

## License

MIT-0 — Free to use, modify, and redistribute. No attribution required.
