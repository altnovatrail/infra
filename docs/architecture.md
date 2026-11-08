# infra — архитектура

> Статус: детализация, эпик E1, закончена 2026-11-08 — разделы 2 и 3; кода ещё нет. Каркас — из заготовки `spec`, 2026-10-19.
>
> Что делает компонент, чего не делает и что о нём ещё предстоит решить. Это подробности его карточки — architecture 3.11 spec. Карточка остаётся сводкой: если подробности меняют то, что в ней сказано, она правится в `spec` тем же путём, что и вопросы в его реестры (RULES.md, Across repositories).
>
> Почему решено так, а не иначе, — в [decisions.md](decisions.md); план работ — в [RUN.md](../RUN.md). Понятия — concepts spec. Документы и решения `spec` лежат в `spec/docs/` и цитируются с суффиксом «spec».

## 1. Назначение и границы

**Делает:**
- описывает кодом общую основу платформы: проекты в облаке, Workload Identity Federation для CI, Artifact Registry, домены, Secret Manager и бюджеты (architecture 3.11 spec). Основа — технологическая база MathTrail Canvas: Cloud Run и управляемые сервисы с масштабированием до нуля, Terraform (R11 spec). Образец — `infra/` canvas-api: `bootstrap.sh` и один корневой модуль Terraform. Будет ли это Terraform или его открытый форк OpenTofu, решит первый код `infra` (architecture 3.11 spec; Т-29);
- настраивает журналы и трассы платформы — Cloud Logging и Trace (architecture 3.12 spec):
  - журналы запросов Cloud Run исключаются в Cloud Logging. Cloud Run пишет их сам, и в их поле `httpRequest` есть IP-адрес клиента, а COPPA относит IP-адрес к персональной информации (architecture 1 spec; privacy 4 spec). Исключаются все, фильтром в каждом sink, а трасс у первого среза нет (R07; раздел 3.4);
  - регион журналов — `us-east4`, а бакет `_Required` — в `global`, пока нет организации Google Cloud (R04; R109 spec);
- выбирает и настраивает хостинг сборки `app` — Firebase Hosting, а своего домена у первого развёртывания нет (R06; раздел 3.3), а к этапу 4 — домен виджетов, отдельный регистрируемый (R16 spec), и хостинг виджетов (architecture 3.12 spec; Т-17). Платформе годится только хостинг, который шлёт свои заголовки ответа — CSP по `csp.json` сборки и кеш, — и отдаёт `/deployment.json` вне архива сборки (Т-17; architecture 3.12 spec). На хостинг сборки `app` потом переезжает и страница образцов `canvas` (R25 spec);
- выкатывает сервисы и сборку `app` по одному списку точных версий и дайджестов — это решил R106 spec, и Т-19 закрыт. На схеме зависимостей `infra` выкатывает релизы `api` и `app` (repositories 3 spec). Как идёт выкладка (R105 spec, R106 spec; architecture 3.11 spec):
  - образ сервиса собирает выкладка `infra`: берёт из релиза сервиса бинарник и `Dockerfile`, проверяет их рецептом `spec` `release-verify` (R77 spec), собирает образ на базе `gcr.io/distroless/static-debian13:nonroot` по digest, кладёт его в закрытый Artifact Registry `infra` и выкатывает ревизию Cloud Run по digest образа. Что сервис кладёт в образ сверх бинарника, делает его собственный код на стадии сборки: у `api` это пакеты модулей. Образов NovaTrail не публикует (RULES.md, Production images);
  - сборку `app` выкатка проверяет по подписи архива, пишет `/deployment.json` из списка выкатки, проверив его по `deployment.schema.json` этой сборки, собирает заголовок CSP по её `csp.json` и выпускает сборку, файл и заголовок одним выпуском хостинга (R85 spec). Список называет рядом с дайджестом сборки дайджест её `/deployment.json` (Т-19);
  - откат — revert списка. `api`, а пока формат модуля v0 — и сборка `app`, перешедшая на новую версию формата, откатываются только вперёд (Т-19);
  - задания `api` при выкладке — миграции до приёма запросов, задание после выкладки — когда ревизия приняла весь трафик — выкладка запускает тем же образом, а факты развёртывания и нижнюю ступень допуска `api` передаёт ревизии из своего репозитория (поправка 2026-11-08 к R106 spec);
  - формат и место списка и кто его правит, что выкатка проверяет до выкладки, что релиз `api` ниже выкаченного отклоняется и как ревизия `api` получает факты и ступень, — решено (R05; раздел 3.2);
- даёт self-hosting и локальный запуск всей платформы (architecture 3.11 spec): код открыт, и свою копию платформы оператор может развернуть сам (product 3 spec). Self-hosting берёт тот же список и тот же путь выкладки: собирает образ у себя из того же бинарника и по тому же `Dockerfile` (R105 spec, R106 spec). Подписанная сборка `app` у всех одна: конфигурацию развёртывания она читает во время работы из `/deployment.json`, а его оператор self-hosting пишет сам по той же схеме (R85 spec; Т-19). Свои факты для допуска к ИИ self-hosting заявляет сам (Т-20; R96 spec).

**Не делает:**
- не хранит данных учеников: из частей платформы их на сервере хранит только `api` (architecture 1 spec; R15 spec). Базу и сервис входа выбрал `api`: Neon Postgres и Firebase Auth (architecture 3.12 spec);
- не держит секретов в репозитории: ключи поставщиков ИИ лежат в Secret Manager (architecture 3.12 spec), а читает их сервисный аккаунт `api` (R15 spec). Если Т-28 решится по рекомендации, там же ляжет и отдельный ключ платформы для eval (R24 spec), и читать его будет CI `modules` и `tutor` через Workload Identity Federation. Значения ключей — никогда не в файлах репозитория (RULES.md, Hard rules);
- не держит кода сервисов и не выпускает их релизы: релиз с подписью — общий workflow из `.github`, который берёт каждый репозиторий с кодом (architecture 3.11 spec; repositories 2.1 spec);
- не заводит своих кластеров, очередей и шины событий. Фоновые работы — задания Cloud Run по расписанию (architecture 1 spec; R11 spec); Cloud Scheduler и задания Cloud Run выбирают `api` и `infra` вместе (architecture 3.12 spec);
- не раздаёт пакеты модулей в первом срезе: на этапе 2 они лежат в образе `api`, и медиафайлы раздаёт `api` (architecture 3.10 spec). Кладёт их в образ код самого `api` на стадии сборки, и логики пакетов выкладка не повторяет (R106 spec). Хранилище с CDN в `infra` по рекомендации Т-17 появится, когда модулей станет больше или придут сторонние авторы (repositories 8 spec);
- не решает регион данных один: его решил `spec` — США, одно место на всех учеников (R109 spec; П-11 закрыт), — а здесь только то, что из этого следует для ресурсов `infra` (R04).

**Данные и связи:**
- данных учеников и секретов в репозитории нет, как ни в одном (RULES.md, Hard rules). Но то, что он настраивает, — журналы, регион, хостинг — касается данных учеников, поэтому каждое предложение здесь сначала читается по privacy spec (RULES.md, Hard rules). Хостинг и инфраструктура — обработчики данных (privacy 2 spec);
- в журналах — события, коды, время и версии, без прямых идентификаторов, IP-адресов, работ, прочитанного и текста подсказок (R09 spec; privacy 4 spec; architecture 5 spec). Сроки хранения — П-9;
- хостинг `app` и сервис входа пишут IP-адрес в свои журналы сами. Эти журналы решаются вместе с выбором этих сервисов: хостинга — здесь, сервиса входа — в `api` (architecture 1 spec; architecture 3.12 spec; privacy 4 spec; П-9). Сервис входа `api` выбрал — Firebase Auth: IP-адреса он держит несколько недель, а получает их не только при входе — на iPad, в Safari и в мобильных браузерах его скрипт и iframe грузятся при каждом старте `app` (privacy 4 spec; architecture 3.12 spec; П-9);
- при сборке ни от чего не зависит, кроме `spec`, и по сети ни к кому не обращается (repositories 2.1 spec). На схеме зависимостей его стрелки — выкладка релизов `api` и `app` (repositories 3 spec);
- общие проверки CI — поиск секретов, DCO, CodeQL, Scorecard и проверку документов — берёт из `.github` ещё до кода; подключила их T21 `spec` (R30 spec; architecture 3.11 spec);
- файл релиза NovaTrail — бинарник сервиса, его `Dockerfile`, архив сборки `app` — входит в выкладку, только когда его принял рецепт `spec` `release-verify` (RULES.md, Release files are verified; R77 spec). Т-27, что сверяет эта проверка, закрыт им же;
- его сервисы (architecture 3.12 spec): хостинг сборки `app`, домен и хостинг виджетов на этапе 4, Secret Manager, Artifact Registry, Cloud Logging и Trace, а вместе с `api` — Cloud Scheduler и задания Cloud Run;
- этап 2, вместе с `tutor`, `canvas`, `api`, `app` и `skill-map` (product 11 spec). Репозиторий заведён раньше кода ради документов, а код ждал П-11 — регион данных, который нужен до первого развёртывания (architecture 3.11 spec; repositories 2.1, 6 spec). П-11 закрыт решением R109 spec (R03). Первое приложение — у автора, локально и без развёртывания, так что строку `infra` в сквозном плане `spec` автор отложил до первого развёртывания (R76 spec). Terraform или OpenTofu встанет в devcontainer вместе с кодом (T14 `spec`), а который из них — Т-29: он вырос из вопроса В2 этого репозитория, и решает его первый код `infra`.

## 2. Решить при детализации

Пункты «Решить при детализации» из карточки — по подразделу на пункт, а два пункта о выкатке — в одном, 2.2. Решённый пункт называет запись журнала, а само решение переехало в раздел 3. Вопрос, который выходит за этот репозиторий, уходит «в реестр spec» (RULES.md, Across repositories).

Эпик E1 решил всё, что карточка оставила детализации, кроме Т-29, а сверх её списка решил один пункт и отложил другой:
- 2.1–2.3 — регион, список выкатки и проверки, хостинг и адреса — решены: R04–R06, разделы 3.1–3.3. Регион закрыл в `spec` R109 spec. Что из 2.2 и 2.3 касается других репозиториев и реестров `spec`, ушло строками таблицы 3 [RUN.md](../RUN.md): В4 — переменные фактов и ступени для `api`, В5 — формат `/deployment.json` в `spec`, В6 и В7 — хостинг, домены и срок IP-адресов Firebase Hosting (Т-17, О-16, П-9);
- 2.4 — исключение журналов запросов, сверх списка карточки, — решён: R07, раздел 3.4. Сроки журналов и уточнение privacy 4 spec — строка В8, а карточку под него и под решённое правит строка В9 (начало architecture 3 spec);
- 2.5 — Terraform или OpenTofu — отложен сознательно: его решает эпик первого кода, первым делом (Т-29);
- 2.6 — self-hosting и локальный запуск всей платформы, сверх списка карточки, — отложен: что о них уже следует из решений E1, — раздел 3.5, а остальное решает эпик E3.

### 2.1. Регион (П-11)

Решено: R04, по R109 spec; раздел 3.1. Задачи — T01, T08.

### 2.2. Список версий и проверки выкатки (R106 spec)

Решено: R05; раздел 3.2. Задача — T02.

### 2.3. Хостинг сборки `app` и домены (Т-17)

Решено: R06; раздел 3.3. Задача — T03.

### 2.4. Исключение журналов запросов

Решено: R07; раздел 3.4. Задача — T04.

### 2.5. Terraform или OpenTofu (Т-29)

- **Суть:** чем `infra` описывает инфраструктуру. R11 spec называет базой Terraform, а Terraform с версии 1.6.0 вышел из открытых лицензий. Вопрос завёл этот репозиторий строкой В2 таблицы 3 [RUN.md](../RUN.md), а `spec` записал его в свой реестр как Т-29 и поставил в пункты карточки (architecture 3.11 spec).
- **Что известно:**
  - варианты Т-29 — Terraform по точной версии, названным исключением в решении `infra`, которое вводит его в devcontainer; OpenTofu по точной версии, тоже названным исключением, и поправка к R11 spec с правкой карточки 3.11 spec и мест, где назван Terraform; Terraform 1.5.7, последний под MPL 2.0 (repositories 8 spec);
  - рекомендация — предварительно OpenTofu, а решить в эпике первого кода `infra`, до того как инструмент встанет в devcontainer. MPL 2.0 проходит правило о лицензиях инструментов прямо, а грант BUSL — не об открытом коде, а о конкуренции, и его условия принимал бы и self-hosting (Т-29; раздел 4 этого документа);
  - поправка 2026-10-22 к R12 spec пускает и условия, бесплатные для всех, но только у инструмента, который NovaTrail не распространяет и без которого платформу можно собрать, запустить и развернуть. Terraform нужен, чтобы её развернуть, и рекомендация Т-29 прежняя (RULES.md, Hard rules; Т-29);
  - цена OpenTofu — правка мест, где назван Terraform, и проверка, что код по образцу canvas-api идёт под OpenTofu: здесь это не проверялось.
- **Варианты:** в Т-29.
- **Задача:** T09 и T11 эпика E2 «Первый код» (таблица 1 [RUN.md](../RUN.md)).

### 2.6. Self-hosting и локальный запуск

- **Суть:** как оператор копии платформы разворачивает её у себя и как платформа целиком запускается локально (architecture 3.11 spec). Пункта «Решить при детализации» о них у карточки нет.
- **Что уже следует из E1** — раздел 3.5: путь выкладки, каталог `deploy/`, хостинг со своими заголовками и журналы self-hosting берёт из R05–R07.
- **Отложено:**
  - что оператору self-hosting нужно сверх того — свой `bootstrap.sh`, переменные корневого модуля, свой регион, свой проект Firebase — видно только на первом коде, и решается в эпике self-hosting после него;
  - локальный запуск всей платформы — `api`, `app` и их базы на одной машине. Первое приложение уже идёт у автора локально, но его запускают сами `api` и `app` (R76 spec), а что из этого должен дать `infra`, — тот же эпик.
- **Задача:** эпик «Self-hosting и локальный запуск» в таблице 2 [RUN.md](../RUN.md).

## 3. Устройство

Здесь — то, что решено по разделу 2: из каких частей компонент состоит, его данные и как он связан с другими репозиториями. Решения — R04–R07; кода ещё нет, и строит его эпик E2 «Первый код» (таблица 1 [RUN.md](../RUN.md)).

**Из чего состоит репозиторий, когда придёт код:**

| Часть | Что делает | Решение |
|---|---|---|
| `bootstrap.sh` | один раз, руками оператора: проект, бакет состояния, Workload Identity Federation для CI и учётная запись конфигурации, как в canvas-api | R11 spec; образец — canvas-api |
| корневой модуль Terraform или OpenTofu | проект и его сервисы: Artifact Registry, Secret Manager, бакет журналов и sink с фильтром, `_Trace`, сайт Firebase Hosting, бюджет с оповещением, а сервис и задания Cloud Run — без образа: образ и ревизию ставит выкладка по digest, а модуль их не трогает, как `ignore_changes` у canvas-api (раздел 4). Всё — в регионе раздела 3.1 | R04, R05, R06, R07; Т-29 |
| `deploy/` | список выкатки, значения `/deployment.json`, файл фактов и схема списка | R05; раздел 3.2 |
| проверки pull request | схема, `release-verify` и sha256, `deployment.json`, факты, ступень, тег `api` не ниже | R05 |
| выкладка | рецепты и workflow: образ, задания `api`, ревизия, выпуск сборки `app` на Hosting | R05, R06; разделы 3.2, 3.3 |

Рецепты проверок и выкладки запускаются и без GitHub Actions — ими же пользуется self-hosting (раздел 3.5).

**Связи с другими репозиториями:**

| Репозиторий | Что `infra` берёт | Что `infra` даёт |
|---|---|---|
| `spec` | правила, `release-verify`, таблицу допуска, а с первым кодом — формат `/deployment.json` (R85 spec; В5) | строки «в реестр spec» таблицы 3 [RUN.md](../RUN.md) |
| `api` | бинарник и `Dockerfile` релиза, имена команд заданий и переменных (В4) | образ, ревизию и задания, файл фактов и ступень, адрес `*.run.app` |
| `app` | архив сборки с `deployment.schema.json` и `csp.json` | `/deployment.json`, заголовки, origin `web.app` и разрешённый домен Firebase |
| `canvas` | — | позже — отдельный сайт Hosting для страницы образцов (R06) |
| `.github` | общие проверки CI; файлы релизов, которые `infra` выкатывает, подписаны общим `release.yml`, а сверяет подпись `release-verify` `spec` (R77 spec) | — |
| `tutor` | коды ступеней допуска, `author` и `full`, тип файла фактов и его разбор (R57 tutor) | — |
| `modules`, `tutor` | — | если Т-28 решится по рекомендации, — ключ платформы для eval в Secret Manager, через Workload Identity Federation (R24 spec) |

### 3.1. Регион

Регион платформы — США, одно место на всех учеников (R109 spec; П-11 закрыт). Что это значит для ресурсов `infra` — R04. Источники — раздел 4.

| Ресурс | Место | Почему так и что после создания не меняется |
|---|---|---|
| сервисы и задания Cloud Run | `us-east4` (Ashburn, Virginia) | рядом с Neon `aws-us-east-1` базы `api`; цены Tier 1 |
| репозиторий Artifact Registry | `us-east4`, регионально | место репозитория не меняется; мультирегион медленнее |
| секреты Secret Manager | репликация по выбору, место `us-east4` | места репликации не меняются; автоматическая репликация — без ограничений, а региональный секрет доступен только из своего региона, и CI на GitHub, который читал бы ключ eval по Т-28, его бы не прочитал |
| бакет журналов | свой, `us-east4`; sink `_Default` направлен в него | бакет `_Default` создан в `global`, и место бакета не меняется — меняется sink. Журналы запросов Cloud Run исключаются (раздел 3.4) |
| бакет `_Required` | `global` | sink `_Required` не меняется, а регион бакету даёт только настройка организации или папки до создания проекта; организация связана с доменом, которого до О-16 нет — Д3 в таблице 4 [RUN.md](../RUN.md) |
| бакет трасс `_Trace` | `us-east4`, создаётся через Observability API до первой трассы | иначе место выберут настройки по умолчанию или сама система, а сменить его может только reprovision, который трассы стирает |

Не `infra`: базу Neon `aws-us-east-1` держит `api`; Firebase Auth обрабатывает данные только в США при любом регионе; хостинг сборки `app` выбирает T03, а Firebase Hosting — глобальный сервис; регион вызовов ИИ R109 spec не решает (R96 spec).

### 3.2. Список выкатки и выкладка

Сервисы и сборку `app` выкатывает `infra`, по одному списку точных версий и дайджестов, а образ сервиса собирает выкладка из файлов его релиза (R105, R106 spec). Репозиторий компонента сам ничего не выкатывает и доступа к production не имеет: проекты и Workload Identity Federation для CI — у `infra` (R106 spec). Как устроены список и выкладка — R05.

**Каталог `deploy/`:**
- `production.json` — список выкатки;
- `production/deployment.json` — значения `/deployment.json` сборки `app`, формат 1 (R09 app);
- `production/facts.json` — файл фактов развёртывания для функции допуска, в форме `facts` таблицы допуска ([текст таблицы допуска](../spec/admission/README.md), раздел 5);
- `schema/` — схема JSON списка.

**Пример списка** — синтетический: версии и дайджесты выдуманы.

```json
{
  "format": 1,
  "api": {
    "release": "v0.4.2",
    "binary": {
      "name": "api_v0.4.2_linux_amd64",
      "sha256": "1111111111111111111111111111111111111111111111111111111111111111"
    },
    "dockerfile": {
      "sha256": "2222222222222222222222222222222222222222222222222222222222222222"
    }
  },
  "app": {
    "release": "v0.3.0",
    "archive": {
      "name": "app_v0.3.0.tar.gz",
      "sha256": "3333333333333333333333333333333333333333333333333333333333333333"
    },
    "deployment": {
      "sha256": "4444444444444444444444444444444444444444444444444444444444444444"
    }
  },
  "admission": {
    "rung": "full"
  }
}
```

Имена файлов релиза — те, что выпустят релизы `api` и `app`: их пока нет, и в примере имена условные, по образцу `module-kit_v0.2.6_linux_amd64` (раздел 4).

**Pull request со списком** — CI без доступа к production:
1. список — по своей схеме;
2. бинарник, `Dockerfile` и архив — `release-verify` с репозиторием и тегом из списка, а sha256 каждого — как в списке. Если Sigstore или GitHub не отвечают, файл отклоняется (R77 spec);
3. `deployment.json` — по `deployment.schema.json` из архива, а его sha256 — как в списке;
4. `facts.json` — по словарю фактов таблицы допуска тега `spec` подмодуля: это ранний знак, а окончательно файл проверяет образ нового релиза `api` (шаг 4 ниже);
5. ступень — `full` (R25 api);
6. тег `api` — не ниже, чем в списке на `main`.

**Выкладка** — после мержа, из коммита списка. Первое задание проверяет, что `main` стоит на этом коммите, а каждое следующее — на повторной попытке (R45 canvas-api). Выкладка делает только то, что изменилось против `main` до мержа.

Новый релиз `api`:
1. конфигурация облака — `apply` Terraform или OpenTofu из того же коммита (Т-29); этот шаг идёт на каждой выкладке;
2. тег `api` — не ниже, чем у ревизии, которая сейчас принимает трафик: `main` может опережать production, если прошлая выкладка не дошла. Затем повтор `release-verify` и sha256 каждого файла — в задание, которое достаёт production, попадает только проверенный файл;
3. образ — по `Dockerfile` из релиза, вокруг его бинарника, на базе по digest, которую называет `Dockerfile` (R105 spec). Стадия сборки кладёт в образ пакеты модулей командой бинарника, и ей нужна сеть (architecture 3.3 api). Образ — в Artifact Registry `us-east4` (R04), его digest — из push;
4. проверка конфигурации — заданием Cloud Run тем же образом, с файлом фактов и ступенью нового списка: неизвестный таблице этого релиза факт останавливает выкладку до миграций. Команду называет релиз `api` (В4 таблицы 3 [RUN.md](../RUN.md));
5. задание миграций обеих баз, `api` и `openfga` (R05 api), — тем же образом по digest, командой, которую называет релиз `api`. Не прошло — выкладка останавливается, и новой ревизии нет;
6. ревизия Cloud Run по digest образа — с файлом фактов томом на точной версии секрета и со ступенью переменной окружения (R05; В4) — сначала без трафика; когда она запустилась — весь трафик ей;
7. задание после выкладки — тем же образом, когда новая ревизия приняла весь трафик (поправка 2026-11-08 к R106 spec).

Только факты или ступень: новая версия секрета фактов и новая ревизия на образе, который уже выкачен, по его digest, — шаг 6 без шагов 2–5 и 7. Сборки, миграций и `release-verify` нет: файлы релиза не менялись, и снятие факта не ждёт Sigstore.

Новый релиз `app`:
1. `release-verify` архива и sha256 — как в шаге 2;
2. архив раскладывается на хостинг, `/deployment.json` пишется из `deploy/production/deployment.json`, заголовок CSP собирается по `csp.json` архива, и всё выходит одним выпуском хостинга (R85 spec; R09 app). На Firebase Hosting — раздел 3.3 (R06);
3. домен `app` — в разрешённых доменах проекта Firebase (Т-19).

**Откат:**
- `api` — только вперёд: новый релиз `api` и новый pull request, а тег ниже не пустят ни CI, ни выкладка;
- сборка `app` — pull request, который возвращает блок `app` списка к прежним значениям: прежняя сборка со своим файлом, одним выпуском. Revert целого коммита, который поднял и `api`, был бы отклонён. Перешедшая на новую версию формата модуля сборка — только вперёд, и это проверяет автор в ревью;
- факты и ступень — pull request с прежними значениями: новая ревизия на том же образе. Срочно закрыть ИИ платформы — снять факт (R96 spec).

Не дошедшую выкладку повторяют, перезапустив её задания, или чинят вперёд новым pull request.

**Self-hosting** — тот же каталог `deploy/` со своими `deployment.json` и фактами, те же проверки и шаги в своём проекте и своём закрытом реестре. Подписанные файлы релизов у всех одни (R105, R106 spec; Т-20).

### 3.3. Хостинг сборки `app` и домены

Сборку `app` раздаёт Firebase Hosting — сайт проекта по умолчанию, план Blaze; бюджет проекта с оповещением ставит первый код (R06).

**Выпуск** — шаг выкладки `app` раздела 3.2:
1. папка выпуска — архив новой сборки, `assets/` сборки, которая сейчас выпущена на Hosting, и `/deployment.json` из `deploy/production/deployment.json`. Выпущенную сборку выкатка узнаёт по выпуску Hosting, а не по списку на `main`, и проверяет её архив, как новый: `release-verify` и sha256. Версия Hosting — полный набор файлов, и без `assets/` прошлой сборки она убрала бы их. У первого выпуска прошлой сборки нет;
2. `firebase.json` пишет выкатка:
   - `headers`: на всех путях — `X-Content-Type-Options: nosniff` и HSTS; на всех путях вне `/assets/**` — CSP по `csp.json` архива с `{api}` и `{authDomain}` из `deployment.json` и с `frame-ancestors 'none'`, и `Cache-Control: no-cache`; у `/assets/**` — `immutable`. Заголовки Hosting сверяет с путём запроса до rewrites, поэтому они стоят не по пути `index.html`;
   - rewrite SPA на `index.html` — только вне `/assets/**` и `/deployment.json`;
   - без `Cross-Origin-Opener-Policy: same-origin`;
3. выпуск — одна версия: файлы и `firebase.json` вместе;
4. проверка после выпуска — байты `index.html`, заголовки у `/`, у пути SPA и у файла в `/assets/`, `404` на неизвестный файл в `/assets/`.

Откат — по R05, pull request с прежним блоком `app`; откат версией в консоли Firebase не используется.

**Журналы:**

| Журнал | IP-адрес | Где и сколько |
|---|---|---|
| журналы самого Firebase Hosting | да | у Firebase, глобально: «a few months», не настраивается — В7 таблицы 3 [RUN.md](../RUN.md) |
| выгрузка журналов Hosting в Cloud Logging | да, `remoteIp` | не включается: в Cloud Logging проекта журналов Hosting нет (вход T04) |

**Адреса и домены:**

| Что | Адрес | Когда меняется |
|---|---|---|
| `app` | `<проект>.web.app` | свой домен у Hosting — когда он будет куплен |
| `api` | `*.run.app` своего сервиса, CORS — точному origin `app` | когда будет свой домен; как — решить тогда, domain mapping Cloud Run в Preview |
| `authDomain` Firebase Auth | `<проект>.firebaseapp.com` | не меняется: `app` входит окном (R09 app) |
| основной домен и домен виджетов | нет | когда покупать, решает `spec` (О-16, Т-17); рекомендация — вместе после О-16, до публичного запуска (В6 таблицы 3 [RUN.md](../RUN.md)); виджеты — этап 4, хостинг бандлов — Т-17 |

Сайт по умолчанию отвечает на двух адресах, `web.app` и `firebaseapp.com`, с одним содержимым. Origin `app` — только `web.app`: его называют CORS `api` и `/deployment.json`. Выкатка добавляет его в разрешённые домены проекта Firebase (Т-19) и не убирает тех, что ставит туда сам Firebase.

**Страница образцов `canvas`** — когда переедет на хостинг (R25 spec), отдельным сайтом проекта и своим origin: выход `app` стирает хранилище своего origin. Тогда в журналы Firebase попадут и IP-адреса устройств, на которых делают образцы детей, — В7.

**Не проверено — первый код:** умеют ли rewrites исключить `/assets/**` и `/deployment.json` (иначе — явный список путей SPA) и шлёт ли Hosting сам HSTS или `Cross-Origin-Opener-Policy`.

### 3.4. Журналы и трассы

Журналы платформы — без прямых идентификаторов и IP-адресов (privacy 4 spec). Как этого держится `infra` — R07.

**Sink и фильтры:**

| Sink | Куда | Фильтр исключения |
|---|---|---|
| `_Default` | свой бакет журналов в `us-east4`, 30 дней (R04) | `LOG_ID("run.googleapis.com/requests")` — журналы запросов Cloud Run |
| `_Required` | бакет `_Required` в `global`, 400 дней | не меняется; журналов запросов не получает |
| любой sink, который заведёт проект | — | тот же, что у `_Default` |

Фильтр применяется к записи, которую Logging API или Telemetry API уже принял: IP-адрес доходит до Google как до обработчика, но в бакете не хранится. Точное имя журнала в фильтре первый код сверяет по записи в проекте.

**Перечень журналов и трасс:**

| Что | Что в нём | Где и сколько |
|---|---|---|
| журналы запросов Cloud Run, у сервиса `api` | `httpRequest`: IP-адрес клиента, user agent | исключены — не хранятся |
| журналы контейнера `api` и его заданий | события `api` без идентификаторов и адресов; у заданий — счётчики (R26 api; T28 api) | бакет `us-east4`, 30 дней |
| системные журналы Cloud Run | события платформы о ревизиях и заданиях | бакет `us-east4`, 30 дней |
| Admin Activity | `callerIp` и почта вызывающего — оператора и CI при правке ресурсов; `SignUp` Identity Platform тоже пишет сюда, а вход Google, `SignInWithIdp`, — нет | `_Required`, `global`, 400 дней (Д3); не исключить |
| System Event | действия самого Google с ресурсами проекта | `_Required`, `global`, 400 дней |
| Policy Denied | `callerIp` и почта того, кому политика отказала | бакет `us-east4`, 30 дней |
| Data Access audit | был бы `callerIp` | не включается |
| журнал активности Identity Platform | был бы каждый запрос входа | не включается |
| выгрузка журналов Firebase Hosting | была бы `remoteIp` | не включается (R06) |
| журналы Firebase Auth и Firebase Hosting у самого Firebase | IP-адреса | у Firebase: Auth — «a few weeks», Hosting — «a few months» (П-9; В7) |
| трассы | — | нет: Cloud Trace API не включается |

Журналов запросов у заданий Cloud Run нет: их пишут только сервисы.

**Для разбора сбоев:**
- журнал `api` — метод, код, причина отказа и время каждого вызова, без тела, заголовков и адреса (architecture 3.9 api);
- встроенные метрики Cloud Run в Cloud Monitoring — число запросов, задержки, экземпляры;
- Error Reporting — по журналам `api`, которые хранятся.

Своих метрик по журналам, где меткой стал бы адрес, проект не заводит: они считаются и по исключённым записям. Оповещения — на встроенных метриках, первый код.

**Трассы:** нет. Cloud Trace API не включается, а бакет `_Trace` всё равно создаётся в `us-east4` до любой трассы (R04): Cloud Run трассирует часть запросов сам.

**Не проверено — первый код:** точное имя журнала запросов в фильтре; что без Cloud Trace API у Cloud Run нет трасс, а если есть — их атрибуты; вызывает ли что-то в проекте `SignUp` Identity Platform и что лежит в его записи Admin Activity (В8).

### 3.5. Self-hosting и локальный запуск

Self-hosting — копия платформы, которую оператор разворачивает у себя (product 3 spec; architecture 3.11 spec). Из решений E1 для неё следует:
- **те же файлы релизов:** образ сервиса оператор собирает у себя из того же бинарника и по тому же `Dockerfile`, после `release-verify`, и держит в своём закрытом реестре (R105, R106 spec);
- **тот же каталог `deploy/`** — свой список, свои значения `/deployment.json` и свой файл фактов; ступень — `full` (R05; R25 api);
- **те же проверки и шаги выкладки** — рецептами, без GitHub Actions, в своём проекте (R05);
- **хостинг сборки `app`** — любой, который шлёт свои заголовки; без них — более слабая защита (R06; Т-17);
- **журналы** — то же исключение журналов запросов и те же правила для метрик и трасс, если копия на Google Cloud (R07);
- **регион** — у копии свой: R109 spec и R04 — о платформе.

Что сверх этого — свой `bootstrap.sh`, переменные корневого модуля, свой проект Firebase — и локальный запуск всей платформы отложены: раздел 2.6.

## 4. Источники

Внешний факт — условия поставщика, цена, закон, документация библиотеки — встаёт сюда с источником и датой прочтения (RULES.md, The bar).

- **Место бакетов журналов** (раздел 2.1) — Google Cloud, [Regionalize your logs](https://docs.cloud.google.com/logging/docs/regionalized-logs), обновлено 2026-10-16, прочитано 2026-10-19: «For each Google Cloud project, billing account, folder, and organization, Logging automatically creates two log buckets: _Required and _Default, which are in the global location. You can't change the location of existing buckets»; «After you create the log bucket, the location can't be changed, but you can create a new bucket and then direct log entries to the new log bucket by using sinks». Перечитано 2026-11-08, страница обновлена 2026-11-06, и эти фразы на месте. Ещё — с неё же: «Redirecting the _Default sink ensures that all future logs go into the regionalized log bucket rather than the _Default bucket, which is global. You can't change the _Required sink, with the logs going into a different global bucket». Прочитано 2026-11-08:
  - [Supported regions](https://docs.cloud.google.com/logging/docs/region-support), обновлено 2026-11-06: «Multi-regions: EU and US»; `us-east4` — «North Virginia»; «Tip: If you want to automatically apply a particular storage region to the new _Default and _Required buckets created in your organization, then configure a default resource location»;
  - [Configure default settings for organizations and folders](https://docs.cloud.google.com/logging/docs/default-settings), обновлено 2026-11-06: «For new projects in the organization, the _Default and _Required log buckets are created in the specified location».
- **Место бакета трасс** (раздел 2.1) — Google Cloud, прочитано 2026-11-08:
  - [Trace storage overview](https://docs.cloud.google.com/trace/docs/storage-overview), обновлено 2026-11-06: «Trace data is stored in a dataset that is managed by the observability bucket named _Trace»; «The system uses the applicable default settings for observability buckets to determine the bucket's location and encryption key. If you haven't defined default settings, then the system selects a supported location»; «Manual creation: You can use the Observability API to create the _Trace bucket before your Google Cloud project receives trace data. You must provide the location of the bucket»;
  - [Observability bucket locations](https://docs.cloud.google.com/stackdriver/docs/observability/observability-bucket-locations), обновлено 2026-11-06: «Multi-regions: EU and US», «us: Data is stored in any data center within the United States»; `us-east4` — «North Virginia». `global` в списке нет;
  - [Update observability buckets](https://docs.cloud.google.com/trace/docs/update-observability-buckets), обновлено 2026-11-06: «You can't modify the location»; «If you need to resolve compliance issues, then reprovision the observability bucket», и reprovision умеет «Change the storage location of an observability bucket»;
  - [Cloud Trace release notes](https://docs.cloud.google.com/trace/docs/release-notes), November 06, 2026: «You can reprovision an existing _Trace bucket to satisfy regulatory requirements for data residency and encryption. … Reprovisioning is a destructive operation».
- **Организация и папки Google Cloud** (раздел 2.1) — Google Cloud, прочитано 2026-11-08:
  - [Creating and managing organization resources](https://docs.cloud.google.com/resource-manager/docs/creating-managing-organization), обновлено 2026-11-02: «Once you have created your Google Workspace or Cloud Identity account and associated it with a domain, your organization resource will be automatically created for you»; «An organization resource is associated with exactly one domain, which is set when the organization resource is created»;
  - [Create folders](https://docs.cloud.google.com/resource-manager/docs/creating-managing-folders), обновлено 2026-11-02: «folders can contain projects, other folders, or a combination of both under an organization resource».
- **Регионы Cloud Run** (раздел 2.1; В3) — Google Cloud, прочитано 2026-11-08:
  - [Cloud Run locations](https://docs.cloud.google.com/run/docs/locations), обновлено 2026-10-30: `us-east4 (Northern Virginia)` и `europe-west1`, `europe-west4` — в «Tier 1 pricing», `europe-west3 (Frankfurt, Germany)` — в «Tier 2 pricing»; «The domain mapping feature of Cloud Run is available in the following regions: asia-east1 asia-northeast1 asia-southeast1 europe-north1 europe-west1 europe-west4 us-central1 us-east1 us-east4 us-west1»;
  - [Mapping custom domains](https://docs.cloud.google.com/run/docs/mapping-custom-domains), обновлено 2026-10-30: «Cloud Run domain mappings are in the preview launch stage. Due to latency issues, they are not production-ready and are not supported at General Availability»;
  - [Regions and zones](https://docs.cloud.google.com/compute/docs/regions-zones), обновлено 2026-11-06: `us-east4` — «Ashburn, Virginia», `europe-west3` — Frankfurt.
- **Место Artifact Registry и Secret Manager** (раздел 2.1) — Google Cloud, прочитано 2026-11-08:
  - [Create standard repositories](https://docs.cloud.google.com/artifact-registry/docs/repositories/create-repos), обновлено 2026-11-07: «When you create a repository, you must configure the following settings that cannot be changed after the repository is created: Artifact format. … Repository location»;
  - [Repository locations](https://docs.cloud.google.com/artifact-registry/docs/repositories/repo-locations), обновлено 2026-10-26: «operations in multi-region repositories may be slower than single-region repositories»;
  - [Choose a replication policy](https://docs.cloud.google.com/secret-manager/docs/choosing-replication), обновлено 2026-10-26: «A secret with an automatic replication policy has its payload data replicated without restriction»; «The locations in the replication policy can't be updated»;
  - [Regional secrets and data residency](https://docs.cloud.google.com/secret-manager/regional-secrets/data-residency), обновлено 2026-10-26: «With regional secrets, your secret data remains within the chosen location at all times, whether it's at rest, in use, or in transit»; «Regional secrets can only be accessed by applications or services running within the same location».
- **Регионы Neon** (раздел 2.1; В3) — [Regions](https://neon.com/docs/introduction/regions), «Last updated: 2026-10-14», прочитано 2026-11-08: регионы AWS — `aws-us-east-1` (N. Virginia), `aws-us-east-2`, `aws-us-west-2`, `aws-eu-central-1` (Frankfurt), `aws-eu-west-2` (London), `aws-ap-southeast-1`, `aws-ap-southeast-2`, `aws-sa-east-1`; в таблице функций у `aws-us-west-2`, `aws-eu-west-2` и `aws-ap-southeast-2` части функций нет; «You cannot change the region for an existing project. If you need your data in a different region, you create a new Neon project in that region and migrate your database there».
- **Firebase** (раздел 2.1; вход T03) — [Privacy and Security in Firebase](https://firebase.google.com/support/privacy), «Last modified: September 24, 2026», обновлено 2026-11-05, прочитано 2026-11-08: «The Firebase Authentication service is run only from US data centers»; Hosting — в списке «Global services»: «The majority of Firebase services run on global Google infrastructure. They could process data at any of the Google Cloud Platform locations or Google data center locations»; «Firebase Hosting IP addresses How it helps: Hosting uses IP addresses of incoming requests to detect abuse and provide customers with detailed analysis of usage data. Retention: Hosting retains IP data for a few months».
- **Регион вызовов ИИ** (раздел 2.1; В3), прочитано 2026-11-08:
  - Anthropic, [Data residency](https://platform.claude.com/docs/en/manage-claude/data-residency), даты на странице нет: «"us" Inference runs only in US-based infrastructure»; «Inference geo: Only "us" and "global" are available. Workspace geo: Only "us" is currently available»; «US-only inference ( inference_geo: "us" ) is priced at 1.1x the standard rate across all token pricing categories»;
  - OpenAI, [Your data](https://developers.openai.com/api/docs/guides/your-data), даты на странице нет: «Contact our sales team to see if you're eligible for using data residency controls»; «To use data residency with any region other than the United States, you must be approved for abuse monitoring controls, and execute a Modified Retention amendment».
- **Маршрутизация журналов в Cloud Logging** (разделы 2.4, 3.4) — Google Cloud, [Route log entries](https://docs.cloud.google.com/logging/docs/routing/overview), обновлено 2026-10-16, прочитано 2026-10-19; перечитано 2026-11-08, обновлено 2026-11-06, и эти фразы на месте, а последняя теперь кончается «Logging API or Telemetry API». Ещё — с неё же: «A project-level sink routes the log entry to the sink's destination when the log entry matches the sink's inclusion filter but doesn't match any of the sink's exclusion filters»; «You can modify and disable the _Default log sink»:
  - «If the log entry matches the inclusion filter and at least one exclusion filter, then it isn't routed»;
  - «You can't use exclusion filters to reduce the consumption of your entries.write API quota or the number of entries.write API calls. Exclusion filters are applied after log entries are received by the Logging API»;
  - «For each Google Cloud project, billing account, folder, and organization, Cloud Logging creates two log sinks, one named _Required and the other named _Default».
- **Журналы и трассы Google Cloud** (раздел 3.4; R07), прочитано 2026-11-08:
  - [Logging for Cloud Run](https://docs.cloud.google.com/run/docs/logging), обновлено 2026-10-30: «Request logs (services only): logs of requests sent to Cloud Run services. These logs are created automatically»; «Although you cannot control the amount of request logs directly from Cloud Run, you can make use of the logs exclusion feature from Cloud Logging»; имя журнала в образце записи — `run.googleapis.com%2Frequests`, типы ресурсов — `cloud_run_revision` и `cloud_run_job`;
  - [Log-based metrics overview](https://docs.cloud.google.com/logging/docs/logs-based-metrics), обновлено 2026-11-06: «System log-based metrics are calculated from included logs only. User-defined log-based metrics are calculated from both included and excluded logs»;
  - [Field-level access control](https://docs.cloud.google.com/logging/docs/field-level-acl), обновлено 2026-11-06: «Field-level access controls let you hide individual LogEntry fields from users of a Google Cloud project»;
  - [Cloud Audit Logs overview](https://docs.cloud.google.com/logging/docs/audit), обновлено 2026-11-06: «Admin Activity audit logs are always written; you can't configure, exclude, or disable them»; «Except for BigQuery, Data Access audit logs are disabled by default because they can generate large volumes of data»; «Publicly available resources that have the Identity and Access Management policies allAuthenticatedUsers or allUsers don't generate audit logs»; «The IP address of the caller is held in the RequestMetadata.callerIp field of the AuditLog object»; «Audit logging doesn't redact the caller's principal email address for any access that succeeds or for any write operation»; _Default «store any enabled Data Access audit logs as well as Policy Denied audit logs»;
  - [Quotas and limits](https://docs.cloud.google.com/logging/quotas), обновлено 2026-11-06: «_Required project, folder, organization 400 days Not configurable»; «you can configure Cloud Logging to retain your logs between 1 day and 3650 days»;
  - [Cloud Observability pricing](https://cloud.google.com/stackdriver/pricing), даты на странице нет: «Suppose a log entry originates in a project but the project doesn't store the log entry in one of its log buckets. In this scenario, the project isn't charged for the log entry»;
  - [Monitor Cloud Run](https://docs.cloud.google.com/run/docs/monitoring), обновлено 2026-10-30: «Cloud Run is automatically integrated with Cloud Monitoring with no setup or configuration required»; «there is no charge for metrics on the fully managed version of Cloud Run»; среди метрик — Request count и Request latencies;
  - [Trace for Cloud Run](https://docs.cloud.google.com/run/docs/trace), обновлено 2026-10-30: «Incoming requests to Cloud Run services automatically generate traces that you can view in Cloud Trace»; «requests are sampled at a maximum rate of 0.1 requests per second for each instance»; «Cloud Run does not support configuration of the Cloud Run sample rate». Атрибутов спанов страница не называет; [Cloud Trace quotas](https://docs.cloud.google.com/trace/docs/quotas), обновлено 2026-11-06: «Spans stored in the _Trace bucket» — 30 дней;
  - [Identity Platform activity logging](https://cloud.google.com/identity-platform/docs/activity-logging), обновлено 2026-11-03: «Activity logging is disabled by default», журнал `identitytoolkit.googleapis.com/requests`;
  - [Identity Platform audit logging](https://docs.cloud.google.com/identity-platform/docs/audit-logging), обновлено 2026-11-03: «Methods that require an IAM permission with the type property value of ADMIN_WRITE generate Admin Activity audit logs»; у «google.cloud.identitytoolkit.v1.AuthenticationService.SignUp» — «Audit log type: Admin activity»; `SignInWithIdp` — в списке «The following methods don't produce audit logs»;
  - [Error Reporting overview](https://docs.cloud.google.com/error-reporting/docs/grouping-errors), обновлено 2026-11-06: «Error Reporting collects events directly from the Error Reporting API or infers them by scanning log entries»; условие — «The log bucket is stored in the same project where the log entries originated».
- **Журналы `api`** (раздел 3.4; R07) — [`api` `main` 5a02ff4](https://github.com/altnovatrail/api/tree/5a02ff4), прочитано 2026-11-08 через API GitHub: architecture 3.9 api — «перехватчик Connect пишет метод, код, причину отказа и время. Тела, заголовков и адреса запроса он не пишет»; `internal/server/server.go` — жалобы сервера, которые «name the client's address, so they go through the log's guard, which drops them».
- **Лицензии Terraform и OpenTofu** (разделы 1 и 2.5; Т-29, который вырос из строки В2 таблицы 3 [RUN.md](../RUN.md)), прочитано 2026-10-20:
  - [hashicorp/terraform, `LICENSE`](https://github.com/hashicorp/terraform/blob/79307e8/LICENSE), коммит 79307e8: «Business Source License 1.1», «Licensed Work: Terraform Version 1.6.0 or later». Additional Use Grant: «You may make production use of the Licensed Work, provided Your use does not include offering the Licensed Work to third parties on a hosted or embedded basis in order to compete with IBM Corp.'s paid version(s) of the Licensed Work»; «Products that are not provided on a paid basis are not competitive». Тот же файл на теге v1.5.7, последнем теге ветки 1.5, — «Mozilla Public License, version 2.0». Последний релиз Terraform — v1.16.6 от 2026-10-14 (релизы hashicorp/terraform на GitHub);
  - [opentofu/opentofu, `LICENSE`](https://github.com/opentofu/opentofu/blob/42f15c9/LICENSE), коммит 42f15c9: «Mozilla Public License, version 2.0»;
  - Open Source Initiative, [OSI Approved Licenses](https://opensource.org/licenses): Mozilla Public License 2.0 в списке есть, Business Source License — нет.
- **Секрет томом в Cloud Run** (раздел 3.2; R05) — Google Cloud, [Configure secrets for services](https://docs.cloud.google.com/run/docs/configuring/services/secrets), обновлено 2026-10-30, прочитано 2026-11-08: «In the Version 1 list, select the version of the secret to reference. By default, the latest version is selected. You can select a specific version if you want»; «--update-secrets = PATH = SECRET_NAME : VERSION».
- **Firebase Hosting** (раздел 3.3; R06), прочитано 2026-11-08; у всех страниц firebase.google.com дата «Last updated 2026-11-05 UTC» — дата сайта, а не страницы:
  - [Firebase Hosting](https://firebase.google.com/docs/hosting): «By default, every Firebase project has subdomains at no cost on the web.app and firebaseapp.com domains. These two sites serve the same deployed content and configuration»; «You can create multiple sites if you have related sites and apps that serve different content but still share the same Firebase project resources»;
  - [Configure Hosting behavior](https://firebase.google.com/docs/hosting/full-config): «Specify custom, file-specific response headers by creating a headers attribute that contains an array of header objects»; «The URL pattern matching for custom headers is done before any rewrite rules are applied»; «Firebase Hosting only applies a rewrite rule if a file or directory does not exist at a URL path that matches the specified source or regex URL pattern»;
  - [Manage live & preview channels, releases, and versions](https://firebase.google.com/docs/hosting/manage-hosting-resources): «The content and configuration served by each channel is packaged into a version object that has a unique identifier»; «By rolling back, you create a new release that serves the same version of content as a previous release»; «the primary way to delete selected files from a deployed site is to delete the files locally, and then redeploy»;
  - [Privacy and Security in Firebase](https://firebase.google.com/support/privacy): «Hosting uses IP addresses of incoming requests to detect abuse and provide customers with detailed analysis of usage data. Retention: Hosting retains IP data for a few months»; Hosting — в списке «Global services»: «The majority of Firebase services run on global Google infrastructure»;
  - [Web request logs and metrics](https://firebase.google.com/docs/hosting/web-request-logs-and-metrics): «Click Link in the Cloud Logging integration card in the Firebase console»; поле «remoteIp The originating client IP for the request»;
  - [Usage, quotas, and pricing](https://firebase.google.com/docs/hosting/usage-quotas-pricing): «Storage for your Hosting content is at no cost up to 10 GB»; «Data transfer from the CDN to your end users is at no cost up to 10 GB/month»; на плане Spark при превышении — «your sites will be disabled»;
  - [Serve dynamic content with Cloud Run](https://firebase.google.com/docs/hosting/cloud-run): «Firebase Hosting is subject to a 60-second request timeout»; `us-east4` — среди регионов rewrites.
- **Firebase Auth** (раздел 3.3; R06), прочитано 2026-11-08: [Best practices for using signInWithRedirect](https://firebase.google.com/docs/auth/web/redirect-best-practices) — «If you host your app with a service other than Firebase, use Option 2, Option 3, Option 4, or Option 5», а Option 2, вход окном, — «popups are occasionally blocked by the device or platform, and the flow is less smooth for mobile users»; [Email link authentication](https://firebase.google.com/docs/auth/web/email-link-auth) — «In projects created after April 28, 2025, Firebase Authentication no longer includes localhost as an authorized domain by default».
- **Отвергнутые хостинги** (R06), прочитано 2026-11-08:
  - Google Cloud, [External Application Load Balancer logging](https://docs.cloud.google.com/load-balancing/docs/https/https-logging-monitoring), обновлено 2026-11-03: «For external Application Load Balancers with backend buckets, logging is automatically enabled and cannot be disabled»; [Web serving overview](https://docs.cloud.google.com/architecture/web-serving-overview), обновлено 2026-02-18: для «Static website» — «Cloud Storage», «Firebase Hosting»;
  - Cloudflare, [Serving Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/): «If your project does not include a top-level 404.html file, Pages assumes that you are deploying a single-page application»;
  - GitHub, [community discussion 54257](https://github.com/orgs/community/discussions/54257), ответ сотрудника GitHub 2023-05-02: «We don't support this feature today so a `meta` tag unfortunately is the only way».
- **RE2** (раздел 3.3; R06) — [синтаксис RE2](https://github.com/google/re2/wiki/Syntax), прочитано 2026-11-08: `(?=re)` — «NOT SUPPORTED».
- **Список выкатки: `api`, `app`, `tutor` и `.github`** (раздел 3.2; R05), прочитано 2026-11-08 через API GitHub:
  - `api`, [`main` 5ad5c8b](https://github.com/altnovatrail/api/tree/5ad5c8b), `docs/decisions.md`: R25 api — «выкладка `infra` передаёт оба значения ревизии Cloud Run, а `api` читает их при старте. Как именно — переменной окружения или файлом, — решают T02 `infra` и эпик кода `api`. Секретов в них нет»; «„Автор“ — только в первом приложении: любое развёртывание, даже где учится один автор, передаёт „полную“»; «Нет значения ступени — „полная“». R26 api — «конфигурация, `internal/config`: только окружение, только объявленные имена», «префикс переменных — `API_`»; о секретах — «Значение — из переменной `X` или из файла по абсолютному пути в `X_FILE`». Релизов у `api` ещё нет;
  - `app`, [`main` 375a09b](https://github.com/altnovatrail/app/tree/375a09b), architecture 3.7 app: «`release-files` пакует сборку — `index.html` с нижним слоем, `assets/`, `deployment.schema.json` и `csp.json`, без `deployment.json`»; «Откат — прежний список: прежняя сборка со своим файлом, тоже одним выпуском». Релизов у `app` ещё нет;
  - `tutor`, [`main` 28ea592](https://github.com/altnovatrail/tutor/tree/28ea592), `admission/models.go`: `StageAuthor Stage = "author"`, `StageFull Stage = "full"`;
  - `.github`, релиз v0.1.21, `.github/workflows/release.yml`: у `workflow_call` нет `outputs`; файлы релиза — то, что рецепт `release-files` вызывающего пишет в `dist/`, и `.sigstore.json` к каждому. Образец имён файлов сервиса Go — релиз `module-kit` v0.2.6: `module-kit_v0.2.6_linux_amd64` и `SHA256SUMS`.
- **Регион, адреса, журналы и выкладка в canvas-api** (разделы 2.1–2.4, 3.2) — [mathtrail/canvas-api](https://github.com/mathtrail/canvas-api/tree/0901af0), коммит 0901af0, прочитано 2026-10-19, а цитаты R45 и R58 canvas-api, его environments, `service_api.tf` и `justfile` — 2026-11-08:
  - `docs/decisions.md`: R54 canvas-api — весь контур в `us-east4`, потому что в бете только семьи из США; R55 canvas-api — API по адресу `*.run.app`, приложение по адресу Firebase Hosting `web.app`, своего домена нет: «свой домен не нужен закрытой бете по приглашениям, а domain mapping Cloud Run в Preview»; R57 canvas-api — журналы в бакете `default-us-east4` на 30 дней, `_Required` остаётся в `global`, место трасс задано до первой трассы; R45 canvas-api и R58 canvas-api — выкладка после релиза, из его тега: «выкладка идёт, только если `main` всё ещё стоит на этом коммите. Иначе перезапуск CI старого коммита откатил бы prod», «Выкатываются подписанные файлы релиза, а не сборка из тега», после отката — `update-traffic --to-latest`; у environment `prod` и `prod-hosting` только правило ветки `main`, без reviewers (API GitHub, прочитано 2026-11-08); `justfile`, комментарий к `ci-hosting-check`: «a browser that kept it would ask for the files of a release that the next one removed»; в `infra/terraform/service_api.tf` образ — в `ignore_changes`, и выкладка ставит его по digest из push, мимо Terraform;
  - `infra/terraform/logging.tf` — бакет журналов в регионе проекта и sink `_Default`, перенаправленный в него с прежним фильтром; фильтра исключения журналов запросов в нём нет;
  - `docs/privacy.md`, таблица открытых вопросов: «Журналы запросов Cloud Run с IP-адресами» — варианты «оставить 30 дней; исключить часть журналов; сократить срок», рекомендация — «сократить срок хранения журналов запросов до минимума, нужного для безопасности».
