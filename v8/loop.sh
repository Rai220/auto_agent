#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TODO_FILE="$SCRIPT_DIR/TODO.md"
INBOX_FILE="$SCRIPT_DIR/INBOX.md"
MAX_IDLE_REPLANS=2  # Сколько replanning-проходов без новых задач допускается перед остановкой

todo_has_open_tasks() {
  [[ -f "$TODO_FILE" ]] || return 1
  grep -qE '^\s*-\s*\[\s\]\s+' "$TODO_FILE"
}

todo_has_done_tasks() {
  [[ -f "$TODO_FILE" ]] || return 1
  grep -qE '^\s*-\s*\[[xX]\]\s+' "$TODO_FILE"
}

todo_cycle_completed() {
  [[ -f "$TODO_FILE" ]] || return 1
  todo_has_open_tasks && return 1
  todo_has_done_tasks
}

has_unread_messages() {
  [[ -f "$INBOX_FILE" ]] || return 1
  # Проверяем, есть ли непрочитанные сообщения (что-то между "Непрочитанные" и следующим разделом)
  local section
  section=$(sed -n '/## Непрочитанные/,/^## /p' "$INBOX_FILE" 2>/dev/null | grep -c '^### ')
  [[ "$section" -gt 0 ]]
}

run_loop() {
  local idle_replans=0

  while true; do
    if ! has_unread_messages && ! todo_has_open_tasks && [[ "$idle_replans" -ge "$MAX_IDLE_REPLANS" ]]; then
      echo "=== Остановка: $idle_replans replanning-проходов без новых задач ($(date)) ==="
      echo "=== Агент решил, что без новых входящих или смены цели осмысленного продолжения нет ==="
      break
    fi

    local replan_requested=0

    if has_unread_messages; then
      echo "=== Есть непрочитанные сообщения — запускаю обработку ($(date)) ==="
    elif todo_has_open_tasks; then
      echo "=== Есть незакрытые шаги TODO — продолжаю цикл ($(date)) ==="
    else
      replan_requested=1
      if todo_cycle_completed; then
        echo "=== TODO-цикл завершён: запускаю автономное перепланирование ($(date)) ==="
      else
        echo "=== В TODO нет открытых шагов: запускаю планирование нового цикла ($(date)) ==="
      fi
    fi

    echo "=== Запуск агента: $(date) ==="
    if [[ "$replan_requested" -eq 1 ]]; then
      AUTO_AGENT_REPLAN=1 bash "$SCRIPT_DIR/run.sh"
    else
      bash "$SCRIPT_DIR/run.sh"
    fi
    echo "=== Агент завершил работу: $(date) ==="

    if [[ "$replan_requested" -eq 1 ]]; then
      if ! has_unread_messages && ! todo_has_open_tasks; then
        idle_replans=$((idle_replans + 1))
      else
        idle_replans=0
      fi
    else
      idle_replans=0
    fi

    echo ""
  done
}

run_loop
