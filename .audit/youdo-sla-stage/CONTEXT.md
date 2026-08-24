# YouDo freelancer deals

Local YouDo automation and the human deal funnel share one workspace. They are different machines.

## Language

**Deal**:
A confirmed YouDo offer the human can move through the freelancer funnel.
_Avoid_: lead, ticket, opportunity, CRM record

**Funnel state**:
One of `offered`, `message_received`, `in_progress`, `done_paid`. Russian labels are Отклик, Получено сообщение, Взято в работу, Выполнено и оплачено.
_Avoid_: status, stage, phase, pipeline step

**Operations state**:
Automation outcome on a task ID: `confirmed`, `rejected`, `deferred`, `ambiguous`, `missed`, plus bookkeeping states such as `retryable` and `baseline_seen`.
_Avoid_: funnel state, CRM status

**Safe Deal**:
YouDo безопасная оплата / SBR. Every published offer must set `IsSbr=true`.
_Avoid_: escrow, safe-pay as a second product name

**Legal entity**:
One-offer actor `personal` or `legal-entity`. YouDo task `isB2B` / `isManagedB2B` selects legal-entity. Personal tasks stay personal. This is not the account `HasLegalEntity` profile toggle.
_Avoid_: global profile switch, company name on every create

**Offer timing**:
A detected task in `state/youdo-task-timings.json`. Fields are `task_id`, `first_seen`, and a map of offer stages: detect, hydrate, tariff, create, verify, publish_confirm, chat_crm_sync. `detect_to_publish_s` is first_seen to publication confirm.
_Avoid_: funnel state, poll interval
