#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AGENTS_MD="$SCRIPT_DIR/AGENTS.md"

TODO_OPEN_COUNT=$(grep -cE '^\s*-\s*\[\s\]\s+' "$SCRIPT_DIR/TODO.md" 2>/dev/null)
TODO_DONE_COUNT=$(grep -cE '^\s*-\s*\[[xX]\]\s+' "$SCRIPT_DIR/TODO.md" 2>/dev/null)
UNREAD_MESSAGE_COUNT=$(sed -n '/## Непрочитанные/,/^## /p' "$SCRIPT_DIR/INBOX.md" 2>/dev/null | grep -c '^### ')

TODO_OPEN_COUNT=${TODO_OPEN_COUNT:-0}
TODO_DONE_COUNT=${TODO_DONE_COUNT:-0}
UNREAD_MESSAGE_COUNT=${UNREAD_MESSAGE_COUNT:-0}

REPLAN_REQUESTED=0
if [[ "${AUTO_AGENT_REPLAN:-0}" == "1" || "${AUTO_AGENT_FORCE_NEXT_CYCLE:-0}" == "1" || "${FORCE_NEXT_CYCLE:-0}" == "1" ]]; then
  REPLAN_REQUESTED=1
fi

if [[ "$TODO_OPEN_COUNT" -gt 0 ]]; then
  TODO_CYCLE_STATUS="active"
elif [[ "$TODO_DONE_COUNT" -gt 0 ]]; then
  TODO_CYCLE_STATUS="completed"
else
  TODO_CYCLE_STATUS="empty"
fi

# Собираем контекст пробуждения — всё, что нужно агенту, чтобы вспомнить себя
PROMPT="# Main Goal
$(cat "$SCRIPT_DIR/MAIN_GOAL.md")

---

# Моя память (MEMORY.md)
$(cat "$SCRIPT_DIR/MEMORY.md" 2>/dev/null || echo '_Файл не найден — это первый запуск._')

---

# Мои цели (GOALS.md)
$(cat "$SCRIPT_DIR/GOALS.md" 2>/dev/null || echo '_Файл не найден._')

---

# Мой план (TODO.md)
$(cat "$SCRIPT_DIR/TODO.md" 2>/dev/null || echo '_Файл не найден._')

---

# Архив памяти
$(if [ -f "$SCRIPT_DIR/MEMORY_ARCHIVE.md" ]; then echo '⚠️ Старые записи перенесены в MEMORY_ARCHIVE.md. Если нужен полный контекст ранних запусков, прочитай этот файл.'; fi)

---

# Мой журнал (последние записи из JOURNAL.md)
$(tail -80 "$SCRIPT_DIR/JOURNAL.md" 2>/dev/null || echo '_Файл не найден._')

---

# Входящие сообщения (INBOX.md)
$(cat "$SCRIPT_DIR/INBOX.md" 2>/dev/null || echo '_Нет входящих._')

---

# Runtime State
- todo_cycle_status: $TODO_CYCLE_STATUS
- todo_open_tasks: $TODO_OPEN_COUNT
- todo_done_tasks: $TODO_DONE_COUNT
- unread_messages: $UNREAD_MESSAGE_COUNT
- replan_requested: $REPLAN_REQUESTED

---

Протокол:
- Сначала прочитай контекст выше и оцени текущее состояние.
- Если есть непрочитанные сообщения в INBOX.md — ответь на них ПЕРВЫМ ДЕЛОМ (запиши ответ в раздел «Мои ответы», перенеси сообщение в архив).
- Если в TODO.md есть незакрытые шаги, выполни ровно один следующий осмысленный шаг.
- Если незакрытых шагов нет и replan_requested=1, проведи короткий replanning pass: реши, нужен ли новый TODO-цикл для продвижения MAIN_GOAL.md.
- Создавай новый TODO-цикл только если он действительно двигает главную цель вперёд; не создавай искусственные задачи ради движения.
- Если main goal уже достигнута или дальше осталось только busywork, честно зафиксируй это в MEMORY.md, JOURNAL.md, TODO.md и GOALS.md и остановись."

claude \
  --print \
  --system-prompt "$(cat "$AGENTS_MD")" \
  "$PROMPT"
