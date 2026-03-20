---
name: openclaw-backup-nas
version: 2.1.0
description: Auto backup, crash detection, and per-container restore for OpenClaw on Synology NAS. Backs up before edits, monitors health every 5 minutes, and auto-restores only failed containers.
homepage: https://github.com/crazydb911/openclaw-backup-nas
metadata: {"clawdbot":{"emoji":"🦞","requires":{"bins":["bash","curl","python3","tar"]}}}
---

# OpenClaw Backup & Auto-Restore (Synology NAS)
# OpenClaw 自動備份與自救系統（Synology NAS）

Automated backup and self-healing system for OpenClaw running on Synology NAS.
適用於 Synology NAS Docker 環境的 OpenClaw 自動備份與崩潰自動還原系統。

## ⚠️ 重要：容器內 AI 無法直接執行備份腳本

備份腳本位於宿主機 `/volume1/homes/crazydb911/`，容器內無法存取此路徑。
若使用者要求執行備份，請回應：
> 請在 NAS 主機上執行：`sudo bash /volume1/homes/crazydb911/openclaw-backup.sh`

## Scripts / 腳本清單

| Script | Purpose / 用途 |
|--------|---------------|
| `openclaw-backup.sh` | Backup all containers / 備份全部容器 |
| `openclaw-restore.sh` | Restore single container / 還原單一容器 |
| `openclaw-crash-monitor.sh` | Crash detection every 5 min / 每 5 分鐘崩潰偵測 |
| `openclaw-health-watchdog.sh` | Post-edit watchdog / 修改後 watchdog |
| `openclaw-list-backups.sh` | List backups / 列出備份 |
| `openclaw-notify.conf` | Notification credentials (private) / 通知設定（私密） |

> Replace `$USER` with your Synology username. / 將 `$USER` 替換為你的 Synology 使用者名稱。

## File Locations / 檔案位置

- Backup script: `/volume1/homes/$USER/openclaw-backup.sh`
- Restore script: `/volume1/homes/$USER/openclaw-restore.sh`
- Crash monitor: `/volume1/homes/$USER/openclaw-crash-monitor.sh`
- Health watchdog: `/volume1/homes/$USER/openclaw-health-watchdog.sh`
- Notify config: `/volume1/homes/$USER/openclaw-notify.conf` (private, not published)
- Death note log: `/volume1/homes/$USER/openclaw-death-note.log`
- Pending check file: `/volume1/homes/$USER/openclaw-pending-check`
- Restore lock file: `/volume1/homes/$USER/openclaw-restore-lock`
- Backup directory: `/volume1/homes/$USER/openclaw-backups/` (keeps 3 days)

## Cron Schedule / Cron 排程

The backup script automatically repairs the cron entries on each run.
備份腳本每次執行時會自動修復 cron 設定。

```
0 */6 * * *   — backup all containers every 6 hours / 每 6 小時備份
* * * * *     — post-edit watchdog every minute / 每分鐘執行修改後 watchdog
*/5 * * * *   — crash monitor every 5 minutes / 每 5 分鐘崩潰偵測
```

## Rules — Follow Every Time You Edit OpenClaw Config Files
## 規則 — 每次修改 OpenClaw Config 必須遵守

### Before Editing / 修改前

1. Run backup / 執行備份：
```bash
bash /volume1/homes/$USER/openclaw-backup.sh
```

2. Write to death note / 在死亡筆記本記錄：
```
[timestamp] 📝 File: <full path>
[timestamp] Purpose: <why you're changing it>
[timestamp] Change: <what exactly changed>
```

3. Start watchdog timer / 建立 watchdog 計時：
```bash
date +%s > /volume1/homes/$USER/openclaw-pending-check
```

### After Editing / 修改後

1. Restart the affected container if needed. / 重啟對應容器（如有需要）。

2. Run health checks — all must return 200 / 執行健康檢查，確認全部回傳 200：
```bash
curl -s -o /dev/null -w "a: %{http_code}\n" http://localhost:28791/healthz
curl -s -o /dev/null -w "b: %{http_code}\n" http://localhost:28891/healthz
curl -s -o /dev/null -w "c: %{http_code}\n" http://localhost:28991/healthz
```

3. All 200 → cancel watchdog / 全部 200 → 取消 watchdog：
```bash
rm /volume1/homes/$USER/openclaw-pending-check
```

4. If health check fails → check docker logs, write to death note, wait for auto-restore.
   若失敗 → 查 docker logs，記錄死亡筆記本，等待自動還原。

## Auto-Restore Mechanisms / 自動還原機制

### Crash Monitor (NEW in v2.1) / 崩潰監控（v2.1 新增）

- Runs every **5 minutes** regardless of edit activity / 每 **5 分鐘**執行，不需要編輯觸發
- Checks all three containers at all times / 隨時監控三個容器
- If any container is down → restore from latest backup + restart / 任何容器掛掉 → 自動還原最新備份 + 重啟
- 30-minute cooldown after restore / 還原後冷卻 30 分鐘防止無限循環
- Notifies via LINE, Telegram, Gmail / 通知 LINE、Telegram、Gmail

### Post-Edit Watchdog / 修改後 Watchdog

- Activates only after Claude Code edits a config file / 僅在 Claude Code 修改 config 後啟動
- If 10 minutes pass without confirmed health → restore failed containers only / 10 分鐘未確認健康 → 只還原失敗的容器
- 30-minute cooldown / 冷卻 30 分鐘

## Manual Operations / 手動操作

**Restore single container (a/b/c) / 還原單一容器：**
```bash
bash /volume1/homes/$USER/openclaw-restore.sh b
```

**Restore from specific backup / 從指定備份還原：**
```bash
bash /volume1/homes/$USER/openclaw-restore.sh b /volume1/homes/$USER/openclaw-backups/openclaw-backup-YYYYMMDD-HHMMSS.tar.gz
```

**List all backups / 列出所有備份：**
```bash
bash /volume1/homes/$USER/openclaw-list-backups.sh
```

**Cancel scheduled restore / 取消排定的 watchdog：**
```bash
rm /volume1/homes/$USER/openclaw-pending-check
```

**Pause all monitors for 30 minutes / 暫停所有監控 30 分鐘：**
```bash
date +%s > /volume1/homes/$USER/openclaw-restore-lock
```

**View death note / 查看死亡筆記本：**
```bash
cat /volume1/homes/$USER/openclaw-death-note.log
```
