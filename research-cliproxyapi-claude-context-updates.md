# Claude Code + CLIProxyAPI: контекст и безопасное обновление

Проверено 2026-08-05 по локальной установке, официальным release notes и GitHub issues проекта. Конфигурация и программы не менялись; OAuth-файлы и содержимое credential store не читались.

## Короткий вывод

Claude Code стоит обновить с `2.1.214` до `2.1.222`: между ними исправлены auto-compact, отображение `/context`, повторные запросы после context overflow и работа keep-alive через custom gateway ([2.1.216](https://github.com/anthropics/claude-code/releases/tag/v2.1.216), [2.1.217](https://github.com/anthropics/claude-code/releases/tag/v2.1.217), [2.1.218](https://github.com/anthropics/claude-code/releases/tag/v2.1.218), [2.1.222](https://github.com/anthropics/claude-code/releases/tag/v2.1.222)). Существенный видимый compatibility change — в `2.1.222` удалён `ultraplan`; в текущем локальном settings он не используется.

CLIProxyAPI не следует обновлять до GitHub latest вслепую. Локально установлен `7.2.105`, Homebrew stable — `7.2.115`, GitHub latest — [`7.2.119`](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.119). Консервативная цель сейчас — **`7.2.115`**, а не `7.2.119`: релиз `7.2.116` внёс Claude-регрессию, из-за которой `thinking: disabled` вместе с автоматически добавленным `context_management` получает upstream 400; она присутствует в `7.2.116–7.2.119`, а исправляющий [PR #4785](https://github.com/router-for-me/CLIProxyAPI/pull/4785) на момент проверки открыт и не смержен ([issue #4784](https://github.com/router-for-me/CLIProxyAPI/issues/4784)). При текущем `effortLevel: high` этот путь менее вероятен, но ручное отключение thinking его активирует.

Гарантировать «ничего не сломается» нельзя: `7.2.115` всё ещё имеет открытый кейс, где очень длинный Codex stream заканчивается без `response.completed` после тяжёлого subagent-turn ([#4760](https://github.com/router-for-me/CLIProxyAPI/issues/4760)). Практический workaround — не укладывать планирование, десятки tool calls и реализацию в один гигантский turn; разделять их на отдельные пользовательские ходы/сессии.

## Что установлено и настроено локально

- Claude Code: `2.1.214`, Homebrew cask `claude-code@latest`; upstream latest `2.1.222`.
- CLIProxyAPI: `7.2.105`; Homebrew stable `7.2.115`; upstream latest `7.2.119`.
- `claude/settings.json` направляет Claude Code на `http://127.0.0.1:8317`, включает gateway model discovery и выбирает `claude-fable-5`.
- Явных `CLAUDE_CODE_CONTEXT_WINDOW_OVERRIDES`, `CLAUDE_CODE_MAX_CONTEXT_TOKENS` и `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` нет. То есть локальный settings сам по себе не объявляет ложное 1M-окно.
- Локальный catalog сообщает `claude-fable-5` окно 1M, а GPT-5.6 Sol/Terra — 372k. Текущий [официальный Codex catalog](https://github.com/openai/codex/blob/main/codex-rs/models-manager/models.json) сообщает GPT-5.6 окно 272k; это реальное расхождение, а не ошибка status line.
- CLIProxyAPI config подключён symlink-ом `/opt/homebrew/etc/cliproxyapi.conf -> /Users/comp/sandbox/dotfiles/cliproxyapi/config.yaml`. В нём OAuth-фильтр оставляет из Codex прежде всего GPT-5.6 Sol/Terra и исключает GPT-5.5/Luna; файл сейчас имеет несохранённые пользовательские изменения.

Локальный smoke test подтвердил: `/count_tokens` для `claude-fable-5` на `"hi"` вернул 3 токена без старой прибавки ~2k, а GPT-5.6 Sol через Anthropic-compatible `/v1/messages` ответил HTTP 200. Генерация через Claude OAuth в момент проверки вернула HTTP 429 `All credentials ... are cooling down`; это текущая квота/cooldown credential pool, а не доказательство несовместимости версий, и обновление не обязано её снять ([связанный open issue #4761](https://github.com/router-for-me/CLIProxyAPI/issues/4761)).

Обновление Homebrew обычно заменяет бинарник в Cellar, а не этот tracked config, но перед и после обновления всё равно следует проверить symlink, `git diff` и фактические версии. Текущие настройки/credentials лучше не мигрировать и не перегенерировать.

## Что на самом деле происходит с контекстом

Здесь смешиваются четыре независимых механизма.

1. **Счётчик UI.** В Anthropic streaming `input_tokens` доступен в начале, а Codex сообщает авторитетный usage в конце. Поэтому CLIProxyAPI может дать `message_start.input_tokens: 0`, и live status показывает ноль; maintainer первоначально закрыл это как не влияющее на расчёты ([#1700](https://github.com/router-for-me/CLIProxyAPI/issues/1700)). Поздний [PR #4293](https://github.com/router-for-me/CLIProxyAPI/pull/4293) предлагал стартовую локальную оценку, но закрыт без merge. Нулевой live-индикатор не доказывает, что само окно равно нулю.

2. **`count_tokens` и `/context`.** Claude OAuth path действительно завышал каждый элемент `/context` примерно на 2k из-за повторно внедрённого system prompt ([#4103](https://github.com/router-for-me/CLIProxyAPI/issues/4103)). В [`7.2.102`](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.102) появился local token counting; локальная `7.2.105` уже новее этого исправления. Claude Code `2.1.218` отдельно исправляет stale pre-compact usage в `/context`.

3. **Заявленное окно против реального upstream limit.** Заголовок Claude `context-1m` или клиентский override не расширяет Codex OAuth backend. Для GPT-5.5 maintainer прямо подтвердил реальный Codex limit 272k и закрыл отчёты о падении около 270k как expected ([#3744](https://github.com/router-for-me/CLIProxyAPI/issues/3744), [#4126](https://github.com/router-for-me/CLIProxyAPI/issues/4126)). Для GPT-5.6 история метаданных менялась: запрос поставить 1.05M отклонили, потому что официальный Codex catalog тогда сообщал 372k ([#4195](https://github.com/router-for-me/CLIProxyAPI/issues/4195)); позже OpenAI catalog сменился на 272k, но maintainer оставил 372k, сославшись на фактически доступное сервером большее окно ([#4476](https://github.com/router-for-me/CLIProxyAPI/issues/4476)). Поэтому число catalog — ориентир для compaction, а не гарантия upstream.

4. **Compaction/replay.** Есть отчёты, где после compaction локальная оценка падала до ~26k, но incremental chain продолжала нести ~325k cached input и доходила до `context_too_large` ([#4227](https://github.com/router-for-me/CLIProxyAPI/issues/4227)); похожий Claude Code/Codex issue закрыт, хотя пользователи подтвердили, что предложенный commit не решил его ([#4176](https://github.com/router-for-me/CLIProxyAPI/issues/4176)). Старый отчёт о не срабатывающем auto-compact закрыт без решения, ручной `/compact` работал ([#363](https://github.com/router-for-me/CLIProxyAPI/issues/363)). Это не лечится простым увеличением отображаемого окна.

CLIProxyAPI `7.2.115` добавил `max-context-length` для **явно configured provider models** ([release](https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.115), [implementation](https://github.com/router-for-me/CLIProxyAPI/commit/a303fd869b03df43d8b70cd4eb5cff44ad526715)). Он меняет metadata, которую видит Codex-клиент, но не добавляет токены upstream и не является общим override для OAuth catalog. Ставить туда 1M без проверенного 1M upstream опасно: клиент начнёт compact слишком поздно.

Отдельный open issue просит proxy-side fallback, когда provider не поддерживает remote `/responses/compact`; общего fallback пока нет ([#4427](https://github.com/router-for-me/CLIProxyAPI/issues/4427)). Это прежде всего Codex Responses mechanism. Claude Code `/compact` — клиентская суммаризация, и его исправления приходят с самим Claude Code.

## Рекомендуемый порядок

1. Сохранить текущий `git diff`/сделать обычную резервную копию пользовательских settings и убедиться, что config symlink указывает на dotfiles.
2. Обновить Claude Code до `2.1.222`. После запуска проверить `/status`, `/model`, `/context`, короткий tool call и ручной `/compact`.
3. Обновить CLIProxyAPI только до Homebrew stable `7.2.115`, перезапустить сервис и повторить те же smoke tests на Claude и GPT-5.6 Sol/Terra. Не менять одновременно model/context overrides.
4. Не ставить `7.2.116–7.2.119`. Дождаться merge [#4785](https://github.com/router-for-me/CLIProxyAPI/pull/4785), следующего релиза и подтверждения, что regression test вошёл в tag; затем обновлять выше `7.2.115`.
5. Если длинная сессия приближается к реальному окну, запускать `/compact` заранее или переносить работу в свежую сессию с кратким handoff. Не поднимать window до 1M ради индикатора. При повторе ошибки собрать sanitized request id, model, фактический terminal usage/последний SSE event и проверить, что после compact не переиспользуется старая incremental chain.

Для отдельного Claude-Code-профиля, который всегда маршрутизирует GPT-5.6 через Codex OAuth, консервативный workaround — считать окно равным официальным 272k и compact примерно на 90%:

```json
{
  "env": {
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "270000",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "90"
  }
}
```

Это запускает compact примерно на 243k и оставляет запас до upstream limit. Настройки описаны в [официальном справочнике Claude Code](https://code.claude.com/docs/en/env-vars). Их нельзя добавлять в общий текущий профиль `claude-fable-5`: там они искусственно урежут доступное 1M-окно.

Итого: **Claude обновить сейчас; CLIProxyAPI — до `7.2.115`, не до latest `7.2.119`**. Это наименее рискованный вариант при текущем наборе issues и локальной конфигурации.
