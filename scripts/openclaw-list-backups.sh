#!/bin/bash
# =============================================
# OpenClaw 備份清單
# =============================================

BACKUP_DIR="/volume1/homes/crazydb911/openclaw-backups"

echo "======================================"
echo " OpenClaw 備份清單"
echo " 目錄：${BACKUP_DIR}"
echo "======================================"

FILES=$(ls -1t "${BACKUP_DIR}"/openclaw-backup-*.tar.gz 2>/dev/null)

if [ -z "${FILES}" ]; then
    echo "（目前沒有備份）"
    exit 0
fi

COUNT=0
while IFS= read -r FILE; do
    COUNT=$((COUNT + 1))
    SIZE=$(du -sh "${FILE}" 2>/dev/null | cut -f1)
    MTIME=$(stat -c "%y" "${FILE}" | cut -c1-19)
    NAME=$(basename "${FILE}")
    printf " %2d. [%s] %6s  %s\n" "${COUNT}" "${MTIME}" "${SIZE}" "${NAME}"
done <<< "${FILES}"

echo "======================================"
echo " 共 ${COUNT} 個備份"
echo ""
echo "還原用法："
echo "  最新：bash /volume1/homes/crazydb911/openclaw-restore.sh"
echo "  指定：bash /volume1/homes/crazydb911/openclaw-restore.sh ${BACKUP_DIR}/<檔名>"
echo "======================================"
