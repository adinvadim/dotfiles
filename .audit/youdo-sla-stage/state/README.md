# Состояние поиска

`freelance-search.json` — единственный машинно-читаемый указатель текущего поиска. Обновляй `updated_at` в UTC ISO 8601, сохраняй только ID заданий и относительные пути к черновикам. Не сохраняй тексты переписки или секреты.

`youdo-operations.json` — канонический автоматизационный state по task ID. Конечные состояния: `confirmed`, `rejected`, `deferred`, `ambiguous`, `missed`. Его меняет только `scripts/record-youdo-outcome.zsh` под lock; trigger не хранит собственный список seen.

`youdo-monitor.json` — последний безмодельный health/SLA snapshot. `youdo-monitor-history.jsonl` хранит до семи суток пятиминутных snapshot для проверки тренда без вызова LLM. Gate выполнен только при `sla.gate_30_of_30=true`, а цель — при `sla.goal_ready=true`; `technical.healthy` отдельно показывает auth, возраст и refresh verified-state, proxy, cron, reconciliation, согласованность проекции и свежесть скана.

`auto-offer-ledger.json` остаётся совместимым журналом прошлых отправок. Новые записи в него проецирует outcome recorder; scanner и SLA используют `youdo-operations.json` как источник текущего workflow state. Монитор проверяет проекцию, а `scripts/reconcile-youdo-ambiguous.zsh` без модели восстанавливает точные публикации после неоднозначного ответа. Неоднозначность старше 10 минут делает health красным.
