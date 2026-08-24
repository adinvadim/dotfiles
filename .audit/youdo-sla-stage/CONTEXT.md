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
YouDo account flag `HasLegalEntity` on the contractor profile. Offers inherit that name. There is no separate offer-create company flag.
_Avoid_: B2B offer field, second identity, invented payload key
