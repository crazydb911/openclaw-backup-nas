#!/bin/bash
# Claude Code Pre-Edit Hook - 編輯 openclaw 相關檔案前自動備份

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)

if echo "$FILE_PATH" | grep -qE "docker[123]/openclaw|openclaw.*config|openclaw.*compose"; then
    DEATH_NOTE="/volume1/homes/crazydb911/openclaw-death-note.log"

    TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)
    OLD_STR=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',d); s=ti.get('old_string',''); print(s[:200] if s else '(新建檔案)')" 2>/dev/null)
    NEW_STR=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); ti=d.get('tool_input',d); s=ti.get('new_string',ti.get('content','')); print(s[:200])" 2>/dev/null)

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$DEATH_NOTE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 AI 即將修改：$FILE_PATH" >> "$DEATH_NOTE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 工具：$TOOL_NAME" >> "$DEATH_NOTE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 修改前：$OLD_STR" >> "$DEATH_NOTE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 修改後：$NEW_STR" >> "$DEATH_NOTE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🗂  開始備份..." >> "$DEATH_NOTE"

    BACKUP_OUTPUT=$(bash /volume1/homes/crazydb911/openclaw-backup.sh 2>&1)
    BACKUP_EXIT=$?
    echo "$BACKUP_OUTPUT" >> "$DEATH_NOTE"

    if [ $BACKUP_EXIT -eq 0 ]; then
        BACKUP_FILE=$(echo "$BACKUP_OUTPUT" | grep "✅ 成功" | awk '{print $2}')
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🗂  備份完成：$BACKUP_FILE" >> "$DEATH_NOTE"
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"✅ 備份完成（$BACKUP_FILE）。請在修改完成後立即確認容器健康狀態，並將本次修改目的記錄到死亡筆記本。\"}}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ 備份失敗！" >> "$DEATH_NOTE"
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContent\":\"❌ 備份失敗，請先排除備份問題再繼續修改。\"}}"
    fi
fi
