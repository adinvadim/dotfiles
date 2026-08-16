# Paper и Figma: как разложить дизайн репозитория по файлам, страницам и артбордам

Проверено 2026-08-04. Исследование опирается только на первичные источники: публичную документацию и build log Paper, актуальную схему подключённого Paper MCP, официальный репозиторий плагина Paper и документацию/материалы Figma. Предлагаемая taxonomy дополнительно проверена на совместимость с локальными контрактами `domain-modeling` (`CONTEXT.md` / `CONTEXT-MAP.md`) и `to-spec` (issue как канонический носитель спеки). Это исследовательская записка; скилл `grill-with-paper` не изменялся.

## Короткий вывод

Сохранить инвариант **один Paper-файл = один репозиторий**. Самая сильная и предсказуемая taxonomy получается, если страница означает не grilling-сессию, отдельный экран, issue или стадию процесса, а **bounded context из `CONTEXT-MAP.md`**. Если у репозитория один корневой `CONTEXT.md`, достаточно одной рабочей страницы `Product`; не надо придумывать искусственные поддомены ради организации canvas.

Issue/spec становится spatial cluster внутри контекстной page. Это и есть delivery-sized product slice: один обсуждаемый и впоследствии публикуемый контракт, который может включать несколько экранов, состояний и grilling decisions.

Иными словами:

```text
Paper file = repository
Page = bounded context from CONTEXT-MAP.md; or Product for one root CONTEXT.md
Spec cluster = one issue/spec (delivery-sized product slice)
Artboard = screen, state, flow step, contract board, or decision option
Decision block = one permanent decision made during a grilling session
Grilling session = temporary work inside its spec cluster, never a page
Canon lane = current accepted context-wide truth, promoted from spec clusters
```

Это **предлагаемый синтез**, а не правило Paper или Figma. Он намеренно не копирует один-в-один популярный Figma-шаблон «Discovery / Flow / Prototype / Ready for dev». В Figma такой skeleton официально рекомендуется как один из рабочих вариантов, но Figma одновременно советует начинать с product surface, если именно так люди ищут работу, и держать логику структуры одинаковой во всех ветках. Bounded context — репозиторно-проверяемая версия product surface; для модели «file уже равен repo» домен становится первым измерением, stage — lane/status, а issue/spec — cluster. [Figma: team, folder, and file organization](https://www.figma.com/best-practices/team-file-organization/)

## Что действительно поддерживают Paper и Figma

### Paper

Paper позиционирует файл как HTML/CSS-canvas, который агент может читать и изменять; MCP работает с текущим открытым контекстом и рекомендует сначала проверять имя файла, страницы, артборды и selection. Хорошо структурированный дизайн, flex-контейнеры и небольшие итерации дают агенту более надёжный контекст; для больших и глубоко вложенных импортов Paper прямо советует дробить работу на меньшие части. [Paper MCP documentation](https://paper.design/docs/mcp), [official Paper agent plugin](https://github.com/paper-design/agent-plugins/tree/cd89a2fd012cac8d6c0fa8f5420c9e49577f0c49/plugins/paper-desktop)

Страницы в Paper уже являются реальным адресуемым уровнем: в майском build log зафиксировано, что агенты могут менять страницы внутри файла, а страницы можно переупорядочивать; в июне Paper отдельно улучшил скорость переключения страниц и поддержку крупных файлов. Но Paper не публикует рекомендуемую page taxonomy, не описывает страницы как блокировки или ветки и не даёт порога «столько-то артбордов на страницу». [Paper build log](https://paper.design/build-log)

Paper-токены принадлежат файлу и могут поддерживать единый язык всего репозитория: цвет, типографику, spacing, container, breakpoint и radius. Это сильный аргумент в пользу одного файла на репозиторий и общей foundation-area (или отдельной foundation-page при нескольких contexts), но не в пользу отдельной страницы на каждую сессию. [Paper tokens](https://paper.design/docs/tokens)

### Figma

В Figma каждая page — отдельный canvas. Официальная документация перечисляет несколько допустимых осей: стадия процесса, milestone, компоненты/styles или user flow; то есть сама Figma не объявляет одну универсальную семантику страницы. [Figma: create and manage pages](https://help.figma.com/hc/en-us/articles/360038511293-Create-and-manage-pages)

Для более мелкой структуры у Figma есть sections: подписанные top-level области canvas, которые группируют связанные идеи, дают прямую ссылку, направляют участников и могут иметь Ready for development / Changed status. Sections могут содержать любые слои и другие sections. [Figma: organize your canvas with sections](https://help.figma.com/hc/en-us/articles/9771500257687-Organize-your-canvas-with-sections)

Актуальная официальная рекомендация Figma для продуктовых команд начинается с вопроса, по чему люди ищут работу. Для многих команд самый предсказуемый первый уровень — product surface, внутри которого уже живут flows и статусы; структуру следует повторять последовательно. Внутри файла Figma предлагает skeleton Cover / Visual research / User research / Discovery / Flow / Prototype / Local components / Ready for development, но подчёркивает, что он может быть меньше или больше. [Figma: team, folder, and file organization](https://www.figma.com/best-practices/team-file-organization/)

Старая, но всё ещё официальная подборка Figma отдельно называет pages-by-feature способом дать нескольким дизайнерам работать независимо над частями продукта, сохраняя общий контекст файла. Она также показывает альтернативы: platform, process stage и atomic-design pages. Это полезные варианты, но не доказательство, что feature всегда должна быть page. [Figma: five ways to structure a workflow with Pages](https://www.figma.com/blog/five-ways-to-structure-your-workflow-with-pages-in-figma/)

Figma поддерживает настоящую multiplayer-модель на уровне файла: до 200 одновременных editors, а синхронизация и conflict resolution происходят в реальном времени. Но даже там два одновременных изменения одного свойства не сливаются семантически: для одного text value победит одно из значений. То есть даже multiplayer не превращает информационную архитектуру страниц в защиту от конфликтов. [Figma multiplayer limits](https://help.figma.com/hc/en-us/articles/1500006775761-How-many-people-can-be-in-a-file-at-once), [Figma multiplayer architecture](https://www.figma.com/blog/how-figmas-multiplayer-technology-works/)

Figma branches — отдельный механизм изоляции: ветка является копией main file, изменения не затрагивают main до merge, а конфликты разрешаются при обновлении/слиянии. Pages сами такой гарантии не дают. [Figma: guide to branching](https://help.figma.com/hc/en-us/articles/360063144053-Guide-to-branching)

## Проверка ограничения Paper по параллельным страницам

Фраза «Paper не может одновременно рисовать в двух-трёх pages» верна как практическое ограничение **одной агентской MCP-сессии**, но её нельзя расширять до утверждения, что Paper вообще не поддерживает одновременное редактирование людьми.

Текущая live-схема Paper MCP, полученная от подключённого first-party server 2026-08-04, устроена так:

- `create_page({ fileId?, name? })` создаёт page, но не переключает контекст;
- `open_file({ fileId, pageId? })` переключает текущую page, после чего вызовы без адреса используют этот sticky context;
- write-tools (`create_artboard`, `write_html`, `update_styles`, `move_nodes`, `delete_nodes` и другие) принимают `fileId`, но не принимают `pageId`;
- официальный MCP guide говорит использовать явный `fileId` при одновременной работе с несколькими **files**, но не даёт эквивалентной адресации для нескольких pages одного file.

Из интерфейса следует: два агента одной сессии могут по очереди вызвать `open_file(..., pageId)` и затем отправить запись не на ту страницу, потому что page — изменяемый session context. Это **вывод из первичной API-схемы, а не опубликованная Paper гарантия и не результат разрушающего race-test**. Публичный build log подтверждает саму возможность agents change pages, но не обещает page-isolated concurrent writes. [Paper build log](https://paper.design/build-log), [Paper MCP documentation](https://paper.design/docs/mcp)

Практическое следствие жёсткое: **page boundaries не надо проектировать как механизм блокировок**. Для одного Paper-file нужен один active writer lease: в любой момент один агент мутирует файл, остальные параллельно исследуют код, документацию или готовят решения без Paper writes. Переключение page и серия изменений на ней должны быть одной сериализованной критической секцией. Если Paper позже добавит `pageId` каждому mutation tool или официальный per-page concurrency contract, это решение можно пересмотреть.

## Предлагаемый синтез: page как bounded context, cluster как issue/spec

Это архитектурное решение выводится не напрямую из Paper/Figma, а из пересечения трёх источников правды:

- Paper даёт `file → page → artboard/layer`, file-level tokens и session-scoped page switching;
- Figma показывает, что product surface — предсказуемый верхний уровень, sections удобны для связанных work packets, а stages не обязаны быть pages;
- локальный `domain-modeling` уже определяет единственную каноническую карту доменов: один `CONTEXT.md` для single-context repo или `CONTEXT-MAP.md`, указывающий на отдельные context glossaries. [`domain-modeling` contract](/Users/comp/.agents/skills/domain-modeling/SKILL.md)

Отсюда предлагается hierarchy:

```text
Repository
└── Paper file
    ├── Page = bounded context from CONTEXT-MAP.md
    │   ├── Context/Canon (page-level)
    │   ├── Spec cluster = issue produced/consumed by to-spec
    │   │   ├── Artboard = screen / state / flow step / option
    │   │   └── Decision block = one grilling decision
    │   └── Spec cluster …
    └── Page …
```

Если `CONTEXT-MAP.md` отсутствует и существует один root `CONTEXT.md`, рабочая page называется `Product`. Если domain files ещё не созданы, также начинать с `Product`: `domain-modeling` создаёт contexts лениво и только после реального прояснения границы. Design workflow не должен самовольно объявлять новый bounded context ради расчистки canvas.

### Почему bounded context лучше product slice на уровне page

Bounded context устойчив, имеет собственный ubiquitous language, docs/ADR home и обычно модульную границу в коде. Он отвечает на вопрос «в каком языке и модели мы сейчас проектируем?» и переживает десятки тикетов. Это хорошо соответствует назначению page как долговечной области файла.

Product slice, напротив, ближе к issue/spec: один пользовательский outcome, который можно обсудить, принять, протестировать и передать в разработку. Его жизненный цикл короче контекста, а `to-spec` уже превращает накопленные решения в issue. Поэтому product slice лучше назвать **spec cluster**, а не page. [`to-spec` contract](/Users/comp/.agents/skills/to-spec/SKILL.md)

Пример:

```text
Page: Wardrobe                    # bounded context
  Cluster: #174 Item categories   # issue/spec
    Artboards: default, selected, validation error, mobile/desktop
    Decision blocks: D001 affordance; D002 save feedback

  Cluster: #193 Capsules          # another issue/spec in the same language
```

### Оценка модели против фактов Paper/Figma

Сильные стороны:

- страниц будет значительно меньше, чем при page-per-session или page-per-issue;
- page names выводятся из versioned repository artifact, а не из вкуса агента;
- несколько grilling sessions естественно собираются в один будущий/существующий issue cluster;
- screen/state остаётся artboard — это совпадает с тем, как Paper MCP читает и создаёт top-level design frames;
- stage/status не ломает taxonomy: `WIP`, `Canon`, `Superseded` остаются lanes/labels;
- схема близка к Figma product-surface-first: contexts играют роль устойчивых surfaces, specs — роль связанных sections/work packets. [Figma: organize your canvas with sections](https://help.figma.com/hc/en-us/articles/9771500257687-Organize-your-canvas-with-sections), [Figma: team, folder, and file organization](https://www.figma.com/best-practices/team-file-organization/)

Риски и поправки:

- один bounded context может быть визуально огромным; в таком случае сначала улучшать spatial clusters и index, а не изобретать subcontext. Если граница действительно новая, зафиксировать её через `domain-modeling` и только потом создать page;
- некоторые bounded contexts не имеют UI — пустую page для них создавать не нужно;
- cross-context journey не принадлежит честно одной page; для него допустима специальная overview-page, которая ссылается на канонические artboards contexts, но не дублирует их;
- issue/spec — хронологический артефакт, а current product truth — семантический. Поэтому accepted screen нельзя навсегда оставлять только внутри старого issue cluster: после принятия его нужно promote/update в page-level `Canon`, а spec cluster сжимать до history/decision summary;
- Paper не имеет опубликованного section primitive уровня Figma, поэтому cluster — spatial/naming convention, а не контейнер с изоляцией или Ready-for-dev status.

Viewport сам по себе page не создаёт. Mobile/desktop лучше держать рядом в одном spec/flow cluster и разделять lanes или artboard variants; Figma тоже рекомендует группировать платформы на canvas и делить на pages/files только при большом масштабе, используя ownership разработчиков как tie-breaker. [Figma: frame organization and platform flows](https://www.figma.com/best-practices/team-file-organization/)

## Структура Paper-файла

### Pages

Рекомендуемый минимальный набор:

```text
00 · Map & foundations
10 · <Bounded context from CONTEXT-MAP>
20 · <Bounded context from CONTEXT-MAP>
30 · <Bounded context from CONTEXT-MAP>
…
90 · Cross-context journeys       # только если реальная сквозная карта нужна
```

Для single-context repo набор ещё проще: одна `Product` page, а Map/foundations становятся её первыми canvas areas. Отдельная `00 · Map & foundations` нужна только когда реальный `CONTEXT-MAP.md` содержит несколько contexts или общие file-level foundations достаточно велики, чтобы заслуживать собственный canvas.

`00 · Map & foundations` — системное исключение из page=bounded-context. На ней находятся визуализация `CONTEXT-MAP`, file-level tokens/sticker sheet, ссылки на system-wide docs/ADR и правила именования. Не надо заранее создавать пустые context pages: Figma также рекомендует начинать с самой мелкой работающей иерархии и добавлять уровни, когда появляется реальная работа. [Figma: keep the hierarchy shallow](https://www.figma.com/best-practices/team-file-organization/)

`90 · Cross-context journeys` создаётся только для настоящего end-to-end journey, пересекающего несколько contexts. Это обзор и навигация, не место для дублирования всех канонических экранов. Figma рекомендует иметь одно надёжное текущее представление полного user journey; в этой модели оно ссылается на Canon контекстных pages. [Figma: a reliable home for your user journey](https://www.figma.com/best-practices/team-file-organization/)

Числовой префикс задаёт стабильный порядок и оставляет промежутки для будущих contexts. Ticket ID в page title не включается: тикеты короче жизни страницы. Если Paper позже поддержит page dividers или folders, смысловая модель от этого не меняется.

### Внутри каждой context page

У Paper пока нет опубликованного эквивалента Figma section с link/status semantics, поэтому section следует моделировать **пространственными lanes и стабильными именами**, не дополнительными pages:

```text
┌──────────────────────────────────────────────────────────────┐
│ 00 · Context                                                 │
│ CONTEXT link · language · scope · code · owner · date       │
├──────────────────────────────────────────────────────────────┤
│ 10 · Canon                                                   │
│ current accepted journeys / states / responsive variants     │
├──────────────────────────────────────────────────────────────┤
│ 20 · SPEC #174 · Item categories                             │
│ issue contract · WIP fork · D001…Dnn · accepted consequence │
├──────────────────────────────────────────────────────────────┤
│ 30 · SPEC #193 · Capsules                                    │
│ issue contract · compact immutable decision history          │
├──────────────────────────────────────────────────────────────┤
│ 40 · Reference (optional)                                    │
│ only material needed to understand this context              │
└──────────────────────────────────────────────────────────────┘
```

`Context` is the page README on canvas. It should link the context’s `CONTEXT.md`, summarize scope without copying the glossary, and include relevant code module, context-specific ADR home, owner and last accepted date. The glossary remains canonical in the repo; Paper consumes its language but does not fork it.

`Canon` contains only the current accepted truth. Arrange a journey left-to-right and states/viewport variants top-to-bottom. It should be possible to link the page and understand the product without entering WIP.

Each `SPEC` cluster corresponds to an existing issue/spec or a draft that `to-spec` will publish and rename. It contains the compact problem/solution contract, current WIP options and permanent decision blocks from one or more grilling sessions. Once a decision is accepted, update Canon, record the decision inside the spec cluster, then remove rejected option artboards. This preserves the current skill’s useful anti-clutter behavior while retaining traceability to delivery.

Decision blocks are spec-local and remain compact/immutable. They are not a visual archive of every rejected screen: question, options, choice, rationale, consequence and issue link are enough. The accepted current design itself lives in Canon; the spec cluster records why it changed.

`Reference` is optional and deliberately small. Image-heavy research belongs in repository docs or another deliberately linked artifact, not copied indefinitely into every Paper file; Figma likewise recommends separating image-heavy research to control file size. [Figma: file size guidance](https://www.figma.com/best-practices/team-file-organization/)

## Stable naming scheme

### Pages

```text
<order> · <Bounded-context canonical name>
```

Examples:

```text
10 · Wardrobe
20 · Upload processing
30 · Blog
40 · Identity
```

Use the exact canonical name from `CONTEXT-MAP.md` / context glossary, not a UI synonym. The Context board records the repository path to that `CONTEXT.md`. If the repo has only root `CONTEXT.md`, use `Product` rather than guessing a more specific context.

### Spec clusters

```text
SPEC · #<issue> · <spec title>
SPEC · Draft · <subject>          # only until to-spec publishes it
```

Examples:

```text
SPEC · #174 · Item category affordance
SPEC · #193 · Wardrobe capsules
SPEC · Draft · Empty wardrobe recovery
```

After `to-spec` publishes the issue, rename `Draft` to its issue number and link the issue on the cluster contract board. Do not create another Paper cluster during publication.

### Permanent canonical artboards

```text
CANON · <Journey or screen> · <State> · <Viewport>
```

Examples:

```text
CANON · Item editor · Default · mobile
CANON · Item editor · Validation error · mobile
CANON · Item editor · Default · desktop
CANON · Processing center · Empty · mobile
```

Canonical names must express product meaning. The current pattern `Accepted — D<nn> — <decision>` should not become the final identity of the screen: it couples durable design to the last interview step and becomes meaningless after later decisions. Put the producing decision in the Context/metadata or suffix only when useful, e.g. `… · @D042`.

### Temporary decision options and permanent log

```text
WIP · #174 · D02 · <Decision> · A · <Option>
WIP · #174 · D02 · <Decision> · B · <Option>
LOG · #174 · D02 · <Decision>
```

Decision IDs should be **spec-local and monotonic** unless the repository already has a global decision registry. They remain unambiguous when paired with context + issue: `wardrobe/#174/D02`. A new grilling chat does not reset numbering when it continues the same spec.

### Other useful prefixes

```text
CTX · <Bounded context>
SPEC · #<issue> · Contract
FLOW · <Journey> · Overview
REF · <Source or contract>
```

Do not encode every hierarchy level into every layer name. Figma’s naming guidance makes the same point at file level: broader structure may be carried by the container, while the name remains specific enough to make sense when seen alone. [Figma: naming guidance](https://www.figma.com/best-practices/team-file-organization/)

## Связь с документацией и кодом

Для каждого bounded context и spec cluster должна существовать двусторонняя связь:

```text
Paper Context board
  → exact CONTEXT.md from CONTEXT-MAP.md
  → context ADR home and relevant code module

Paper Spec cluster
  → exact issue/spec URL
  → accepted consequence and decision IDs

Repository docs
  → exact Paper page URL
  → accepted snapshot/export table when the repo uses snapshots
  → bounded-context name, issue number and acceptance date
```

Локальные проекты уже показывают полезную конвенцию: Paper-файл носит имя репозитория, PRD/README ссылаются на конкретную Paper-page, а accepted PNG считаются immutable snapshots и переэкспортируются при изменении. Это стоит сохранить. Меняется только гранулярность: page соответствует context, issue/spec получает cluster, несколько grilling decisions остаются внутри него.

Long-form documentation не следует переносить целиком на canvas. Figma рекомендует держать подробные docs отдельно, чтобы docs и components могли version independently; в Paper Context достаточно краткого контракта и ссылок. [Figma: layer naming and documentation](https://www.figma.com/best-practices/team-file-organization/)

## Миграция без большого взрыва

1. Не перестраивать весь Paper-файл сразу. Прочитать root `CONTEXT.md` или `CONTEXT-MAP.md`; на `00 · Map & foundations` сопоставить текущие session-pages только с уже существующими bounded contexts.
2. Для single-context repo создать/использовать `Product`; для multi-context repo выбрать одну перегруженную область и создать page с точным canonical context name.
3. Сгруппировать current accepted artboards по issue/spec; rejected visuals не мигрировать. Если issue ещё нет, временно назвать cluster `SPEC · Draft · <subject>`.
4. Создать Context + Canon, затем перенести accepted current truth в Canon, а decision summaries — в соответствующие spec clusters.
5. Обновить docs/issue links. Следующие grilling-сессии направлять в существующий context + spec cluster по routing rules ниже.
6. Старые session-pages архивировать/удалять только после проверки ссылок и сохранения нужных snapshots. Paper не публикует гарантию сохранения ссылок при переносе nodes между pages, поэтому это требует ручной проверки.

### Routing rules для будущего скилла

Перед созданием page скилл должен последовательно определить:

1. Есть ли manifest/repository name? Это Paper file.
2. Есть ли `CONTEXT-MAP.md`? Если да, найти владеющий bounded context и открыть page с его canonical name.
3. Если map нет, использовать `Product`, основанный на root `CONTEXT.md` (или пока без glossary, если context files ещё не созданы).
4. Если ни один context честно не владеет вопросом, не создавать page автоматически: это сигнал для `domain-modeling` проверить/зафиксировать новую границу.
5. Есть ли issue/spec, который гриллинг продолжает? Найти его `SPEC` cluster; иначе создать `SPEC · Draft · <subject>` для последующего `to-spec`.
6. Найти/создать `CTX`, определить `CANON`, занять WIP-area внутри spec cluster, продолжить spec-local decision numbering из `LOG`.
7. После принятия обновить `CANON`; оставить в spec cluster decision block и accepted consequence. После `to-spec` заменить `Draft` на issue number и добавить ссылку.

Главный safety rule: если в этом Paper file уже есть active writer, не начинать вторую Paper mutation-сессию даже на другой page. Исследование и подготовка могут идти параллельно; canvas writes — последовательно.

## Что не удалось подтвердить

- Paper не публикует семантическую best practice для pages, поэтому `page = bounded context; cluster = issue/spec` — рекомендация, синтезированная из возможностей Paper, локальных domain/spec contracts и более зрелых Figma patterns, а не правило Paper.
- Не найден официальный Paper contract для одновременной записи несколькими агентами на разные pages одного file. Текущая MCP-схема указывает на sticky page context, но поведение при гонке специально не тестировалось.
- Не найден опубликованный Paper-аналог Figma sections с отдельными share links и Ready for dev status. Lanes поэтому являются canvas convention, не product feature.
- Paper быстро меняется: page switching появился в build log только в мае 2026, а оптимизация больших files и page switching — в июне. Перед реализацией скилла стоит повторно проверить schemas `open_file`, `create_page` и mutation tools.
- Ни Paper, ни Figma не дают универсального количественного порога «сколько artboards = новая page». В предлагаемой модели новую page разрешает новая зафиксированная domain boundary, а canvas size остаётся только сигналом пересмотреть модель, index или spatial layout.

## Источники

### Paper, first-party

- [Paper MCP documentation](https://paper.design/docs/mcp)
- [Paper build log](https://paper.design/build-log)
- [Paper tokens](https://paper.design/docs/tokens)
- [Paper agent plugins repository, pinned revision](https://github.com/paper-design/agent-plugins/tree/cd89a2fd012cac8d6c0fa8f5420c9e49577f0c49/plugins/paper-desktop)
- Live Paper MCP schemas and `get_guide({ topic: "paper-mcp-instructions" })`, captured 2026-08-04 from the connected first-party server

### Figma, first-party

- [Create and manage pages](https://help.figma.com/hc/en-us/articles/360038511293-Create-and-manage-pages)
- [Organize your canvas with sections](https://help.figma.com/hc/en-us/articles/9771500257687-Organize-your-canvas-with-sections)
- [Team, folder, and file organization](https://www.figma.com/best-practices/team-file-organization/)
- [Five ways to structure a workflow with Pages](https://www.figma.com/blog/five-ways-to-structure-your-workflow-with-pages-in-figma/)
- [Guide to files and projects](https://help.figma.com/hc/en-us/articles/1500005554982-Guide-to-files-and-projects)
- [How many people can be in a file at once?](https://help.figma.com/hc/en-us/articles/1500006775761-How-many-people-can-be-in-a-file-at-once)
- [How Figma’s multiplayer technology works](https://www.figma.com/blog/how-figmas-multiplayer-technology-works/)
- [Guide to branching](https://help.figma.com/hc/en-us/articles/360063144053-Guide-to-branching)

### Local workflow contracts

- [`domain-modeling` skill](/Users/comp/.agents/skills/domain-modeling/SKILL.md) — root `CONTEXT.md` for one context; root `CONTEXT-MAP.md` points to multiple context glossaries; contexts are created lazily
- [`to-spec` skill](/Users/comp/.agents/skills/to-spec/SKILL.md) — turns settled conversation into a spec published as a project-tracker issue and uses domain glossary vocabulary
