# Claude Code + CLIProxyAPI: Claude для оркестрации, GPT/Grok для исполнения

Дата исследования: 2026-07-17. Проверены локальные Claude Code 2.1.207 и CLIProxyAPI 7.2.80; исходники CLIProxyAPI зафиксированы на commit [`9f4f53c`](https://github.com/router-for-me/CLIProxyAPI/tree/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66). Секреты и содержимое OAuth-файлов не читались.

## Итог

Целевая схема поддерживается:

- интерфейс, Workflow, subagents, hooks, MCP, permissions и TUI остаются Claude Code;
- Claude Opus можно оставить основной моделью и автором Workflow;
- исполнителей Workflow можно направлять на `gpt-5.6-sol(high)` или `grok-4.5(high)`;
- CLIProxyAPI принимает Anthropic Messages, выбирает backend по реестру модели и переводит запрос/stream-ответ в формат Codex/xAI;
- для Auto mode нужен настоящий доступный Claude-маршрут: ошибка `claude-opus-4-8 is temporarily unavailable` соответствует отсутствию зарегистрированной Claude credential/model, а не поломке GPT/Grok-переводчика.

Рекомендуемая архитектура: один CLIProxyAPI с тремя OAuth-каналами `claude`, `codex`, `xai`; обычный `claude` без прокси; один `ccx` с маленьким settings-overlay, указывающим только proxy URL. Модель выбирается штатно через `/model`, а Workflow stages при необходимости получают явные model IDs. Не маскировать GPT/Grok под Sonnet/Opus: нативные имена дают предсказуемую маршрутизацию и не перехватывают внутренние Claude-вызовы.

## Что уже наследует `ccx`

Основной `claude/settings.json` содержит Workflow, hooks, permissions с Auto mode, UI-настройки и модель Claude. Дополнительный `claude/settings-gpt.json` задаёт только proxy-переменные. Это правильное разделение: JSON из `--settings <file>` не заменяет user/project settings целиком, а сливается с ними; указанные ключи перекрываются, отсутствующие остаются из нижних слоёв. Это прямо описано в [Claude Code settings: precedence](https://code.claude.com/docs/en/settings#settings-precedence).

Следовательно, копировать основной settings-файл в GPT-профиль не нужно. `ccx` продолжает получать:

- `enableWorkflows`, предупреждения Workflow и `permissions.defaultMode`;
- hooks из user/project settings;
- MCP из `~/.claude.json`, `.mcp.json` и явно переданного `--mcp-config`;
- agents, skills, plugins и CLAUDE.md по обычным scope-правилам.

Проверка после запуска: `/status` → `Setting sources`; документация рекомендует этот экран для подтверждения загруженных слоёв ([settings verification](https://code.claude.com/docs/en/settings#verify-active-settings)).

## Реальный путь запроса

1. Claude Code отправляет Anthropic-compatible `POST /v1/messages`; token count идёт в `/v1/messages/count_tokens`. Оба маршрута реализованы сервером CLIProxyAPI ([server.go, строки 520–539](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/api/server.go#L520-L539)).
2. Handler читает `model`, декодирует discovery-ID и передаёт запрос общему auth manager ([code_handlers.go, строки 70–93](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/api/handlers/claude/code_handlers.go#L70-L93), [handlers.go, строки 719–753](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/api/handlers/handlers.go#L719-L753)).
3. Backend определяется только по активному глобальному model registry. Если модель не зарегистрирована, provider не угадывается по имени ([provider.go, строки 29–74](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/util/provider.go#L29-L74)).
4. Для Codex Claude Messages переводятся в Responses/Codex: system → developer, messages, images, `tool_use`/`tool_result`, tool declarations и thinking/reasoning ([codex_claude_request.go, строки 23–41](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/translator/codex/claude/codex_claude_request.go#L23-L41)). Обратный stream-перевод зарегистрирован той же translator-парой.
5. xAI использует тот же translator framework, затем применяет thinking и формирует Responses-запрос ([xai_executor.go, строки 882–908](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/runtime/executor/xai_executor.go#L882-L908)). Claude backend переводится/нормализуется в Anthropic Messages и получает модель без suffix ([claude_executor.go, строки 198–225](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/runtime/executor/claude_executor.go#L198-L225)).

Таким образом, Claude Code tools, MCP tools и Workflow доступны GPT/Grok как обычные tool declarations. Hooks и MCP lifecycle исполняются клиентом Claude Code, а не моделью. Ограничение практическое: сторонняя модель может хуже соблюдать tool protocol; Anthropic официально предупреждает, что non-Claude routing не поддерживается ими и gateway должен следить за изменениями протокола ([LLM gateway overview](https://code.claude.com/docs/en/llm-gateway)).

## Model registry, discovery, exclusions и aliases

Регистрация каждой credential строится так:

- берётся каталог провайдера/тарифа;
- применяется `oauth-excluded-models`;
- затем применяется `oauth-model-alias`;
- результат регистрируется за credential.

Порядок виден для Claude/Codex/xAI в [service.go, строки 1941–2045](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/cliproxy/service.go#L1941-L2045), а alias вызывается позже в [строках 2146–2157](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/cliproxy/service.go#L2146-L2157).

Ключевое следствие: `oauth-excluded-models` — не просто фильтр `/models`. Он удаляет модель до регистрации ([service.go, строки 2367–2410](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/cliproxy/service.go#L2367-L2410)); прямой вызов исключённого ID не найдёт provider. Нельзя одновременно исключить исходную модель и затем alias-нуть её.

Чтобы скрыть upstream-ID, но сохранить маршрут, нужен alias с `fork: false` (default): оригинал не добавляется, alias добавляется как clone ([service.go, строки 2760–2849](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/cliproxy/service.go#L2760-L2849)). При исполнении alias разворачивается обратно, suffix сохраняется ([oauth_model_alias.go, строки 95–133](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/cliproxy/auth/oauth_model_alias.go#L95-L133)). Но для этой задачи aliases не нужны: `gpt-5.6-sol` и `grok-4.5` уже уникальны. Пересекающиеся alias между providers официально отмечены как неоднозначные ([config.example.yaml, строки 405–417](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/config.example.yaml#L405-L417)).

Claude Code discovery принимает Claude-подобные IDs. CLIProxyAPI поэтому выдаёт для non-Claude моделей обратимо закодированный `claude-fable-5-dd-<reversed-id>`, но оставляет реальный display name; при запросе ID декодируется обратно ([claude_model.go, строки 12–47](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/util/claude_model.go#L12-L47), [code_handlers.go, строки 137–164](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/sdk/api/handlers/claude/code_handlers.go#L137-L164)). Это transport workaround, не подмена исполняемой модели. Прямой `--model gpt-5.6-sol` тоже работает, если ID зарегистрирован.

Текущий каталог подтверждает нужные возможности:

- `claude-opus-4-8`: 1M context, 128K output, effort до `max` ([models.json, строки 100–120](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/registry/models/models.json#L100-L120));
- `gpt-5.6-sol`: 372K context, 128K output, tools, `low..max` ([строки 1581–1602](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/registry/models/models.json#L1581-L1602));
- `grok-4.5`: 500K context, 65,536 output, `low..high`, thinking нельзя выключить ([строки 2422–2439](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/registry/models/models.json#L2422-L2439)).

Текущая denylist-конфигурация оставляет только GPT 5.6 Sol и Grok 4.5 среди Codex/xAI. После добавления Claude OAuth классические Claude-модели появятся отдельным каналом. Denylist потребует обслуживания при появлении новых upstream-моделей; это не строгий allowlist.

## Workflow и выбор модели исполнителей

Workflow — клиентский JavaScript-оркестратор Claude Code. Скрипт создаёт subagents и может назначить модель каждому stage. По официальным правилам каждый агент наследует session model, кроме stage с явной моделью; `CLAUDE_CODE_SUBAGENT_MODEL` перекрывает и session model, и stage model ([Workflow docs: model usage](https://code.claude.com/docs/en/workflows#understand-costs)). Та же переменная действует на **все** subagents, agent teams и Workflow agents, принимает полный model ID; `inherit` возвращает нормальное разрешение ([model configuration](https://code.claude.com/docs/en/model-config#environment-variables)).

Отсюда три режима:

- все исполнители GPT: session env `CLAUDE_CODE_SUBAGENT_MODEL=gpt-5.6-sol(high)`;
- все исполнители Grok: session env `CLAUDE_CODE_SUBAGENT_MODEL=grok-4.5(high)`;
- GPT и Grok в одном Workflow: переменную не задавать (или `inherit`), а в проверенном Workflow script явно назначить полный ID каждой стадии.

Для смешанного режима не следует постоянно хранить `CLAUDE_CODE_SUBAGENT_MODEL` в общем `settings-gpt.json`: она отменит stage routing. Надёжнее отдельные launch-профили для «все GPT»/«все Grok» и базовый `ccx` без этой переменной для mixed Workflow.

Основную session model лучше поставить `claude-opus-4-8`: она пишет/чинит Workflow script и остаётся оркестратором. Ошибка на первом скриншоте `Expecting Unicode escape sequence` возникла до model API: сгенерированный Workflow содержал неверно escaped JavaScript template literal. Proxy не может исправить JS, который Workflow runtime отклонил до запуска агентов. Для повторяемых задач стоит сохранять и переиспользовать проверенные Workflow scripts, а не генерировать их заново каждый раз.

## Auto mode и скрытые модельные вызовы

Auto mode использует отдельный server-side safety classifier и проверяет действия subagents. Он не обязан следовать выбранной `/model`; сообщение из скриншота прямо показывает попытку вызвать `claude-opus-4-8`. Поэтому Claude OAuth нужен даже если вся полезная работа уходит GPT/Grok. После регистрации Opus этот скрытый вызов получает provider `claude`; без него реестр возвращает пустой маршрут.

Также следует оставить классические Claude routes, особенно Haiku: `ANTHROPIC_DEFAULT_HAIKU_MODEL` задаёт модель для `haiku` и background functionality ([model configuration](https://code.claude.com/docs/en/model-config#environment-variables)). Другие потенциальные отдельные вызовы: subagents с model frontmatter, prompt/agent hooks со своей моделью, fallback/resume. Подмена Claude aliases на GPT/Grok сделала бы эти внутренние зависимости неявными, поэтому нативные IDs безопаснее.

## Авторизация

CLIProxyAPI предоставляет отдельные OAuth-команды `-claude-login`, `-codex-login`, `-xai-login` ([main.go, строки 94–103](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/cmd/server/main.go#L94-L103)); Claude ветка вызывает штатный login flow ([строки 642–654](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/cmd/server/main.go#L642-L654)). Claude OAuth запрашивает `user:inference` и `user:sessions:claude_code` среди scopes ([anthropic_auth.go, строки 190–207](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/auth/claude/anthropic_auth.go#L190-L207)).

Нужное состояние auth-dir:

- Claude OAuth credential — Opus/Haiku/классические модели и Auto classifier;
- Codex OAuth credential — `gpt-5.6-sol`;
- xAI OAuth credential — `grok-4.5`.

Авторизация добавляет credential в тот же auth-dir; после reload/restart сервис регистрирует каталог за credential. Не переносить Anthropic OAuth-токен из Claude Code вручную и не сохранять реальный proxy access token в отслеживаемый settings-файл.

## Effort suffixes

CLIProxyAPI понимает `model(value)`: budget, `none`, `auto`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`; `ultra` не является допустимым thinking suffix ([suffix.go, строки 12–43 и 109–145](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/thinking/suffix.go#L12-L43)). Suffix имеет приоритет над thinking в body ([apply.go, строки 127–164](https://github.com/router-for-me/CLIProxyAPI/blob/9f4f53ca5a4d1474e3f7eb61d6ffc984995f1f66/internal/thinking/apply.go#L127-L164)).

Практически:

- использовать `gpt-5.6-sol(high)` и `grok-4.5(high)`;
- GPT также поддерживает `xhigh`/`max`;
- Grok заканчивается на `high`; не рассчитывать на `xhigh`/`max`;
- Claude Code `ultracode` — режим масштабной Workflow-оркестрации, не model suffix CLIProxyAPI.

## Рекомендованный конечный дизайн

1. Сохранить основной `~/.claude/settings.json` источником всех обычных Claude Code функций.
2. Оставить `ccx` как `claude --settings <proxy-overlay>`; overlay содержит только proxy env, поэтому основная модель наследуется из обычных Claude settings или выбирается через `/model`/`--model`.
3. Авторизовать Claude в CLIProxyAPI рядом с уже существующими Codex/xAI credentials.
4. Не создавать alias `sonnet -> grok` или `opus -> gpt`; оставить нативные `gpt-5.6-sol` и `grok-4.5`.
5. Для mixed Workflow — явная модель на stage, без глобального `CLAUDE_CODE_SUBAGENT_MODEL`.
6. Для простого интерфейса оставить один `ccx`; session model выбирать через `/model`, модели Workflow stages — нативными IDs в script.
7. Проверять фактическую модель через proxy logs/usage и Workflow model usage, а не вопросом модели «кто ты»: self-identification ненадёжна.

## Минимальная проверка после реализации

- `/status`: загружены user settings и CLI overlay; Workflow/Auto активны.
- `/model`: видны Claude display names, GPT 5.6 Sol, Grok 4.5.
- Обычный prompt на Opus проходит.
- Прямые `--model gpt-5.6-sol(high)` и `--model grok-4.5(high)` делают tool call.
- Workflow из двух простых stages явно использует GPT и Grok; proxy log подтверждает оба model IDs.
- Auto mode разрешает/блокирует тестовую shell-команду без `claude-opus-4-8 unavailable`.
- MCP tool вызывается из GPT/Grok stage; SessionStart hook по-прежнему срабатывает.
