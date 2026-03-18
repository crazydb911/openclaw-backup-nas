---
name: openclaw-backup-nas
version: 2.0.0
description: Auto backup, health check, and per-container restore for OpenClaw on Synology NAS. Backs up before edits, confirms health after, and auto-restores only failed containers if health check fails within 10 minutes.
homepage: https://github.com/crazydb911/openclaw-backup-nas
metadata: {"clawdbot":{"emoji":"🦞","requires":{"bins":["bash","curl","python3","tar"]}}}
---

# OpenClaw Backup & Auto-Restore (Synology NAS)

Automated backup and self-healing system for OpenClaw running on Synology NAS.

## Environment

- Backup script: `/volume1/homes/$USER/openclaw-backup.sh`
- Restore script: `/volume1/homes/$USER/openclaw-restore.sh`
- List backups: `/volume1/homes/$USER/openclaw-list-backups.sh`
- Health watchdog: `/volume1/homes/$USER/openclaw-health-watchdog.sh`
- Notify config: `/volume1/homes/$USER/openclaw-notify.conf` (private, not published)
- Death note log: `/volume1/homes/$USER/openclaw-death-note.log`
- Pending check file: `/volume1/homes/$USER/openclaw-pending-check`
- Restore lock file: `/volume1/homes/$USER/openclaw-restore-lock`
- Backup directory: `/volume1/homes/$USER/openclaw-backups/` (keeps 3 days)

> Replace `$USER` with your Synology username.

## Rules — Follow Every Time You Edit OpenClaw Config Files

### Before Editing

1. Run backup:
```bash
bash /volume1/homes/$USER/openclaw-backup.sh
```

2. Write to death note:
```
[timestamp] 📝 File: <full path>
[timestamp] Purpose: <why you're changing it>
[timestamp] Change: <what exactly changed>
```

3. Start watchdog timer:
```bash
date +%s > /volume1/homes/$USER/openclaw-pending-check
```

### After Editing

1. Restart the affected container if needed.

2. Run health checks — all must return 200:
```bash
curl -s -o /dev/null -w "a: %{http_code}\n" http://localhost:28791/healthz
curl -s -o /dev/null -w "b: %{http_code}\n" http://localhost:28891/healthz
curl -s -o /dev/null -w "c: %{http_code}\n" http://localhost:28991/healthz
```

3. All 200 → cancel watchdog and log result:
```bash
rm /volume1/homes/$USER/openclaw-pending-check
```

4. If health check fails → check docker logs, write to death note, wait for watchdog to auto-restore.

## Auto-Restore Mechanism

- Watchdog runs every minute via Synology Task Scheduler
- If 10 minutes pass without confirmed health → watchdog checks each container
- **Only failed containers are restored** (not all three)
- Notifies via LINE, Telegram, and Gmail
- 30-minute cooldown after restore to prevent infinite loops

## Manual Operations

**List all backups:**
```bash
bash /volume1/homes/$USER/openclaw-list-backups.sh
```

**Restore latest backup:**
```bash
bash /volume1/homes/$USER/openclaw-restore.sh
```

**Restore specific backup:**
```bash
bash /volume1/homes/$USER/openclaw-restore.sh /volume1/homes/$USER/openclaw-backups/openclaw-backup-YYYYMMDD-HHMMSS.tar.gz
```

**Cancel scheduled restore:**
```bash
rm /volume1/homes/$USER/openclaw-pending-check
```

**Pause watchdog for 30 minutes:**
```bash
date +%s > /volume1/homes/$USER/openclaw-restore-lock
```

**View death note:**
```bash
cat /volume1/homes/$USER/openclaw-death-note.log
```
