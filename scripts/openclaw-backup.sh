#!/bin/bash
# =============================================
# OpenClaw 備份腳本 v3.0
# =============================================

# ================== 可自訂區 ==================
BACKUP_DIR="/volume1/homes/crazydb911/openclaw-backups"
RETENTION_DAYS=3

BACKUP_PATHS=(
    "/volume1/homes/crazydb911/openclaw-backup.sh"
    "/volume1/docker1/openclaw"
    "/volume1/docker2/openclaw"
    "/volume1/docker3/openclaw"
)
# =============================================

# 讀取通知設定（私密資料放在 openclaw-notify.conf，不發布）
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
FAIL_THRESHOLD=2
[ -f "${CONF_FILE}" ] && source "${CONF_FILE}"

FAIL_COUNT_FILE="${BACKUP_DIR}/.fail_count"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/openclaw-backup-${DATE}.tar.gz"
LOG_FILE="${BACKUP_DIR}/backup.log"

mkdir -p "${BACKUP_DIR}"

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

echo "=== OpenClaw 備份開始 ${DATE} ===" | tee -a "${LOG_FILE}"

tar -czf "${BACKUP_FILE}" --ignore-failed-read "${BACKUP_PATHS[@]}" 2>> "${LOG_FILE}"

if [ $? -eq 0 ]; then
    echo "✅ 成功：${BACKUP_FILE}" | tee -a "${LOG_FILE}"
    echo 0 > "${FAIL_COUNT_FILE}"
else
    echo "❌ 失敗，請查看：${LOG_FILE}" | tee -a "${LOG_FILE}"
    FAIL_COUNT=$(cat "${FAIL_COUNT_FILE}" 2>/dev/null || echo 0)
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo ${FAIL_COUNT} > "${FAIL_COUNT_FILE}"
    if [ ${FAIL_COUNT} -ge ${FAIL_THRESHOLD} ]; then
        MSG="[OpenClaw] ⚠️ 備份連續失敗 ${FAIL_COUNT} 次，請檢查！"
        send_line "${MSG}"
        send_telegram "${MSG}"
        send_mail "[OpenClaw] 備份連續失敗" "${MSG}"
        echo 0 > "${FAIL_COUNT_FILE}"
    fi
fi

# 清理舊備份（只留 RETENTION_DAYS 天）
find "${BACKUP_DIR}" -name "openclaw-backup-*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "=== 備份結束 ===" | tee -a "${LOG_FILE}"
