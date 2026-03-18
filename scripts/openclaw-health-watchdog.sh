#!/bin/bash
# =============================================
# OpenClaw 健康 Watchdog（每分鐘由任務排程器呼叫）
# 修改後 10 分鐘內未確認健康 → 自動還原
# =============================================

PENDING_FILE="/volume1/homes/crazydb911/openclaw-pending-check"
LOCK_FILE="/volume1/homes/crazydb911/openclaw-restore-lock"
LOG_FILE="/volume1/homes/crazydb911/openclaw-backups/backup.log"
RESTORE_SCRIPT="/volume1/homes/crazydb911/openclaw-restore.sh"

# ================== 可自訂區 ==================
TIMEOUT_MIN=10        # 幾分鐘內未確認 → 觸發還原
COOLDOWN_MIN=30       # 還原後冷卻幾分鐘（防無限循環）
# =============================================

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

NOW=$(date +%s)

# 檢查冷卻中
if [ -f "${LOCK_FILE}" ]; then
    LOCK_TIME=$(cat "${LOCK_FILE}")
    ELAPSED=$(( (NOW - LOCK_TIME) / 60 ))
    if [ ${ELAPSED} -lt ${COOLDOWN_MIN} ]; then
        exit 0  # 冷卻中，靜默退出
    fi
fi

# 沒有 pending 就不用做事
[ ! -f "${PENDING_FILE}" ] && exit 0

# 計算距離上次修改幾分鐘
PENDING_TIME=$(cat "${PENDING_FILE}" 2>/dev/null)
ELAPSED=$(( (NOW - PENDING_TIME) / 60 ))

[ ${ELAPSED} -lt ${TIMEOUT_MIN} ] && exit 0

# 超過 10 分鐘，執行健康檢查
A=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:28791/healthz)
B=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:28891/healthz)
C=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:28991/healthz)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog 健康檢查：a=${A} b=${B} c=${C}" >> "${LOG_FILE}"

if [ "${A}" = "200" ] && [ "${B}" = "200" ] && [ "${C}" = "200" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog：健康通過，自動清除 pending" >> "${LOG_FILE}"
    rm "${PENDING_FILE}"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watchdog：健康異常，觸發自動還原" >> "${LOG_FILE}"
    MSG="[OpenClaw] 🚨 健康檢查失敗（a=${A} b=${B} c=${C}），Watchdog 自動還原中..."
    send_line "${MSG}"
    send_telegram "${MSG}"
    send_mail "[OpenClaw] 健康檢查失敗" "${MSG}"
    bash "${RESTORE_SCRIPT}" >> "${LOG_FILE}" 2>&1
    send_line "[OpenClaw] 🔄 自動還原完成，請確認容器狀態"
    send_telegram "[OpenClaw] 🔄 自動還原完成，請確認容器狀態"
    send_mail "[OpenClaw] 自動還原完成" "Watchdog 已自動還原，請確認容器狀態"
    echo ${NOW} > "${LOCK_FILE}"
    rm -f "${PENDING_FILE}"
fi
