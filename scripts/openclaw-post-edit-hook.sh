#!/bin/bash
# Claude Code Post-Edit Hook - 編輯後排程健康檢查，並提醒 AI 主動確認

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)

if echo "$FILE_PATH" | grep -qE "docker[123]/openclaw|openclaw.*config|openclaw.*compose"; then
    DEATH_NOTE="/volume1/homes/crazydb911/openclaw-death-note.log"
    echo "$(date +%s)" > /volume1/homes/crazydb911/openclaw-pending-check
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⏳ 已排程：10 分鐘後健康檢查 (修改：$FILE_PATH)" >> "$DEATH_NOTE"

    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"你剛修改了 openclaw 設定檔（$FILE_PATH）。請依序執行：\n1. 重啟對應容器（如有需要）\n2. 健康檢查：curl -s -o /dev/null -w \\\"%{http_code}\\\" http://localhost:28791/healthz 和 28891/healthz\n3. 若全部 200：rm /volume1/homes/crazydb911/openclaw-pending-check，並在死亡筆記本寫下修改目的與結果\n4. 若失敗：查看 docker logs 找出採坑原因，記錄到死亡筆記本，然後判斷是修復還是等 watchdog 還原\"}}"
fi
