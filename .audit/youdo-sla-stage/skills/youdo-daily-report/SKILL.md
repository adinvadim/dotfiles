---
name: youdo-daily-report
description: "Каждое утро отчитайся по отправленным и заблокированным тарифом откликам YouDo."
---

# Ежедневная сводка YouDo

Штатный утренний cron запускает `scripts/run-youdo-daily-report.zsh` без модели. Скрипт сам читает live YouDo account `personal`, повторяет временно неудавшееся чтение, пишет отчёт только после валидного ответа и возвращает ненулевой exit code при ошибке. Поэтому OpenClaw не может принять объяснение агента за успешный отчёт.

Этот skill нужен сотруднику `freelancer` для ручного запуска и восстановления classification backlog. Источник тарифов всегда live YouDo account `personal`, прочитанный тобой в текущем turn. Monitor state, чужой пересказ и вчерашний отчёт не подтверждают действующий тариф.

## 1. Собрать точные данные

Дата отчёта по умолчанию равна вчерашнему календарному дню в `Asia/Makassar`. Если оператор передал `REPORT_DATE=YYYY-MM-DD`, используй её. Получи канонический срез:

```bash
scripts/build-youdo-daily-report-input.zsh [YYYY-MM-DD]
```

Затем сам прочитай купленные тарифы и сохрани ровно этот JSON во временный файл внутри `state/`:

```bash
scripts/youdo-exec.zsh cli --timeout 90s --account personal --json offer package list
```

Каждый `exec` запускай последовательно с `timeoutSeconds: 120`; не передавай custom `env` или `PATH`. Дождись exit code перед следующим вызовом.

Действующим купленным тарифом считай только запись с `Status=1`, `PaidPrice>0`, положительным `TimeRemain` и доступным остатком. Для unlimited `OfferCountLimit=null`; для лимитного пакета `OfferCountRemain` должен быть больше нуля.

Если `missing_classification_task_ids` не пуст, для каждого ID последовательно выполни точный `offer package check`. Проверь exact task ID и положительный category или subcategory ID. Исходное время блокировки возьми только из первого канонического доказательства: `first_payment_blocked_at`, а для legacy-записи — самый ранний `checked_at` в `state/youdo-monitor-history.jsonl`, где этот task уже был `payment_blocked`. Не используй текущий `updated_at` и не угадывай время. Затем сохрани имена, ID и исходное время:

```bash
scripts/record-youdo-outcome.zsh classify_payment_blocked <task-id> \
  <category-id-or-null> <subcategory-id-or-null> "<category-name-or-null>" "<subcategory-name-or-null>" \
  <first-payment-blocked-at-UTC>
```

После backfill снова запусти `build-youdo-daily-report-input.zsh`. Продолжай только при пустом `missing_classification_task_ids`. Package-check и classification не отправляют отклик и не покупают тариф.

## 2. Записать и вернуть сводку

Передай дату и сохранённый live package JSON детерминированному writer:

```bash
scripts/write-youdo-daily-report.zsh <YYYY-MM-DD> <live-package-json-file>
```

Верни stdout writer без изменений. Он пишет коротко и по-человечески, сохраняет canonical input, live package snapshot, полный Markdown и machine-readable receipt. Не предлагай покупать конкретный тариф и не называй цену каталога: владелец решает это после сводки. Не включай тексты задач, заказчиков, cookies, карту, proxy или browser diagnostics.

Удалить временный live package JSON можно только после успешного writer. Итоговый ответ turn должен состоять ровно из stdout writer, без служебного вступления.

## 3. Критерий завершения

Готово, когда live package list прочитан в этом turn, classification backlog пуст, writer атомарно записал `reports/daily/<date>.md`, `.input.json`, `.packages.json` и `state/youdo-daily-report.json`, а финальный текст равен stdout writer. Любая ошибка чтения или записи завершает cron ошибкой, чтобы failure alert дошёл владельцу.
