#!/bin/bash
# =============================================
# OpenClaw 還原腳本 v3.0
# 用法：bash openclaw-restore.sh [備份檔案]
# 不指定檔案 = 自動還原最新備份
# =============================================

BACKUP_DIR="/volume1/homes/crazydb911/openclaw-backups"
LOG_FILE="${BACKUP_DIR}/backup.log"

# 讀取通知設定
CONF_FILE="$(dirname "$0")/openclaw-notify.conf"
LINE_CHANNEL_ACCESS_TOKEN=""
LINE_USER_ID=""
MAIL_TO=""
MAIL_FROM=""
GMAIL_APP_PASSWORD=""
TELEGRAM_CHAT_ID=""
TELEGRAM_TOKEN_A=""
TELEGRAM_TOKEN_B=""
TELEGRAM_TOKEN_C=""
[ -f "${CONF_FILE}" ] && source "${CONF_FILE}"

send_line() {
    [ -z "${LINE_CHANNEL_ACCESS_TOKEN}" ] || [ -z "${LINE_USER_ID}" ] && return
    curl -s -X POST https://api.line.me/v2/bot/message/push \
        -H "Authorization: Bearer ${LINE_CHANNEL_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"to\":\"${LINE_USER_ID}\",\"messages\":[{\"type\":\"text\",\"text\":\"$1\"}]}" > /dev/null
}

send_telegram() {
    [ -z "${TELEGRAM_CHAT_ID}" ] && return
    for TOKEN in "${TELEGRAM_TOKEN_A}" "${TELEGRAM_TOKEN_B}" "${TELEGRAM_TOKEN_C}"; do
        [ -z "${TOKEN}" ] && continue
        curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"$1\"}" > /dev/null
    done
}

send_mail() {
    [ -z "${MAIL_TO}" ] || [ -z "${GMAIL_APP_PASSWORD}" ] && return
    python3 - << PYEOF
import smtplib, ssl
from email.mime.text import MIMEText
msg = MIMEText("""$2""", "plain", "utf-8")
msg["Subject"] = "$1"
msg["From"] = "OpenClaw NAS <${MAIL_FROM}>"
msg["To"] = "${MAIL_TO}"
ctx = ssl.create_default_context()
with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=ctx) as s:
    s.login("${MAIL_FROM}", "${GMAIL_APP_PASSWORD}")
    s.send_message(msg)
PYEOF
}

# 選擇備份檔
if [ -n "$1" ]; then
    BACKUP_FILE="$1"
else
    BACKUP_FILE=$(ls -1t "${BACKUP_DIR}"/openclaw-backup-*.tar.gz 2>/dev/null | head -1)
fi

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
    echo "❌ 找不到備份檔：${BACKUP_FILE}"
    exit 1
fi

echo "=== OpenClaw 還原開始 $(date '+%Y-%m-%d %H:%M:%S') ===" | tee -a "${LOG_FILE}"
echo "📦 還原來源：${BACKUP_FILE}" | tee -a "${LOG_FILE}"

tar -xzf "${BACKUP_FILE}" -C / --no-same-permissions --no-same-owner 2>&1 \
    | grep -v "Cannot utime" | grep -v "Cannot change mode" \
    | tee -a "${LOG_FILE}"

if [ -f "/volume1/docker1/openclaw/docker-compose.yml" ]; then
    echo "✅ 還原完成" | tee -a "${LOG_FILE}"
    send_line "[OpenClaw] ✅ 還原完成：$(basename ${BACKUP_FILE})"
    send_telegram "[OpenClaw] ✅ 還原完成：$(basename ${BACKUP_FILE})"
    send_mail "[OpenClaw] 還原完成" "已還原：${BACKUP_FILE}"
else
    MSG="[OpenClaw] ❌ 還原失敗，請手動檢查"
    echo "${MSG}" | tee -a "${LOG_FILE}"
    send_line "${MSG}"
    send_telegram "${MSG}"
    send_mail "[OpenClaw] 還原失敗" "${MSG}"
    exit 1
fi

echo "=== 還原結束 ===" | tee -a "${LOG_FILE}"

# 健康檢查
echo ""
echo "健康檢查："
sleep 2
curl -s -o /dev/null -w "a: %{http_code}\n" http://localhost:28791/healthz
curl -s -o /dev/null -w "b: %{http_code}\n" http://localhost:28891/healthz
curl -s -o /dev/null -w "c: %{http_code}\n" http://localhost:28991/healthz
