# RUN.md — work plan of infra

What infra does, does not do and has still to decide — [docs/architecture.md](docs/architecture.md); why — [docs/decisions.md](docs/decisions.md). The platform is in `spec/`, a submodule at tag v0.18.6: the component's card — architecture 3.11 spec; the order of repositories — repositories 6 spec; learners' data and law — privacy spec; the platform's decisions — spec's log. Small tasks, one at a time, each reviewed by the author; only the current epic is in detail (R19 spec). Done epics are archived in `docs/plan/<epic>.md`. Other tables, each a file opening with its rules (R153 spec): 2, epics for later — [run/EPICS.md](run/EPICS.md); 3, questions to the author — [run/QUESTIONS.md](run/QUESTIONS.md); 4, debt — [run/DEBT.md](run/DEBT.md). Open tasks outside an epic — [run/TASKS.md](run/TASKS.md) (R155 spec).

Language (R154 spec): rules and tables in English, terse, for the session; the epic's description, table 1 and the bodies of tasks, here and in `run/TASKS.md`, in Russian — the author writes and reviews them.

## Rules

A task starts with «Выполни задачу T01 из RUN.md» in a new session in the devcontainer. One task — one session (R143 spec): the hook `UserPromptSubmit` of [.claude/settings.json](.claude/settings.json) — `spec/tools/session/` — stops «Выполни задачу T…» or «планируй T…» of another task in the same session and names `/clear`; the same task passes.

1. Do only the named task; touch other tasks' files only where it requires.
2. Read first: [CLAUDE.md](CLAUDE.md) with the rules it imports (RULES.md of `spec/`), the task — in table 1, or only its own body of `run/TASKS.md` (its opening says how) —, the sections it cites — its own and spec's —, [docs/decisions.md](docs/decisions.md).
   - Conflict with the documents or something missing — stop and ask; never guess.
   - A gap in the component itself — a subsection of [docs/architecture.md](docs/architecture.md), section 2. A gap across repositories — a row of [run/QUESTIONS.md](run/QUESTIONS.md) whose question opens with the mark «В реестр spec»: spec's session finds it on `main`, and it gets its О-, П- or Т- number once the author decides it there (R81 spec; RULES.md, Across repositories).
   - From [run/DEBT.md](run/DEBT.md) and [run/QUESTIONS.md](run/QUESTIONS.md) take only the rows the task and its sections name and those `grep -n` finds by the paths and parts it changes (R143 spec).
3. **Devcontainer only.** If `NOVATRAIL_DEVCONTAINER` is not `1`, stop before the first edit and ask to reopen in the container; "only documents" is no reason to go on. If `spec/` is empty, ask for `git submodule update --init`. Exception: a cloud session the author started for the task runs the checks it can reach, and its report names each one that did not run.
4. Outside this repository — editing `spec` or other repositories, their settings, anything that costs money — only after a warning (what, where, cost) and the author's confirmation. `spec/` is read only here; a task of its own moves it to a new tag.
   - Exception, no confirmation: the task's checks by R146 spec — browser: Playwright in the devcontainer, custom-token sign-in of a stand-in user on the dev project; AI: the `tutor` stub in `api` dev mode. A real AI call only where the task checks the model's words: dev key under the author's spend limit at the provider, within the task's ceiling, or with confirmation where it has none; «Сделано» names the provider, the calls and the cost.
   - Nothing on devices: engines are Chromium, WebKit and Firefox in CI; what only a device shows — pen, device voices, VoiceOver and TalkBack, the home screen — stays a row of [run/DEBT.md](run/DEBT.md) until the author decides otherwise.
5. Facts on AI providers, laws, prices and other platforms — from the primary source, with quote and date read, as a record of `docs/sources.md` (RULES.md). What is not confirmed is not stated: it becomes an open question.
6. End with the checks of what the task changed. Documents: `just -f spec/justfile docs-check-repo` (R32 spec) — relative links lead to existing files and headings; each spec section and number — «architecture 3.5 spec», «R18 spec», О-, П-, Т- — exists in `spec/` at its tag; own sections exist, R numbers have no gaps or repeats and the log's opening names the next free one; numbers В in [run/QUESTIONS.md](run/QUESTIONS.md) and Д in [run/DEBT.md](run/DEBT.md) do not repeat and the next free one is above each. If the tag of `spec` is older than this check, check the same by hand.

   Then `/code-review high`, one round: fix the findings, do not rerun. A small change may skip the review even if «Как проверить» names it.
7. Do not commit: the author commits after review. Otherwise only on the author's word, as «доведи до мержа», and in a run of spec's orchestrator, «Сделай эпик E…»: its executor works by the contract `spec/tools/orchestrator/executor.md` — commits, pushes and opens the pull request, never merges (RULES.md, How we work; R156 spec).
8. End with a short report in Russian: what was done, files, how to check, what the review found or why there was none, what is open and what goes «в реестр spec».
9. When done: table 1 `[ ]` → `[x]`; append to the body «Сделано (дата)» — what was done, how checked — and «Открыто». A question for the author from «Открыто» is also a row of [run/QUESTIONS.md](run/QUESTIONS.md); what is put off, a row of [run/DEBT.md](run/DEBT.md).
   - Then move the body verbatim, relative links fixed, to the epic archive `docs/plan/<epic>.md`, with a gist sentence — an unheaded list item at the start of the receiving section: «T01 — сделана <дата>: <итог одной фразой>». Neither stays here, and a search by heading finds one body, in the archive (R153 spec).
   - A task outside an epic leaves `run/TASKS.md` for the current epic's archive, section «Задачи вне эпика, сделанные за его время»; with no current epic, to the last done epic's archive, section «Задачи вне эпика, сделанные после него» (R19 spec and its 2026-11-13 amendment).
10. Language (R14 spec, R42 spec, R143 spec, R154 spec): this plan and `run/` in English, the epic's description, table 1, the bodies of tasks, the epic archives `docs/plan/` and the reports in Russian; `docs/` in English; README, CLAUDE.md, AGENTS.md, code, comments, schema descriptions, prompts and normative texts for authors in English.
11. A task larger than one review (≈ 30–60 minutes of reading): propose a split before starting.
12. Before a new task, close the findings on the previous one, once SonarCloud, CodeQL and Scorecard run here (R30 spec); an allowed departure from rule 1.
    - SonarCloud sees merged code: its verdict on the previous task is in [New Code](https://sonarcloud.io/summary/new_code?id=altnovatrail_infra); CodeQL and Scorecard — the Security tab, `gh api 'repos/altnovatrail/infra/code-scanning/alerts?state=open'`.
    - Fix in code first; "false positive" is the last resort, with the reason in words; what a change cannot close stays open — shared reasons in R33 spec, own ones in the log, like R51 canvas-api. Never skip silently.
    - Report these fixes in a separate paragraph: the author commits them apart from the task.

**Statuses:** `[ ]` not started; `[x]` done, the executor marks it; `[-]` not done — the author's decision, reason in the task; `[?]` deferred — the author's decision, reason and when to return in the task. A task that fails the author's review returns to `[ ]` with what to fix.

**Who:** «Claude» — the executor does it, the author reviews; «Claude, проверяю я» — texts the author reads line by line; «я + Claude» — the author does some steps: decisions, sign-ins, GitHub settings, confirmations by rule 4.

**Plan:** «да» — plan mode first: decisions missing from the documents, or larger than one review (rule 11); «—» — run at once.

**Task body** (Russian): «Цель», «Сделать», «Как проверить», «Разделы»; as needed «Не делать», «Решить при планировании», «Мой шаг», «Стоимость», «Риски»; from planning «Почему», «Решено автором (дата)», «Выяснилось при планировании»; when done «Сделано (дата)», «Открыто» (rule 9).

**Citations.** Own sections — `architecture 2`, own decisions — `R03`; spec's sections and decisions — «architecture 3.5 spec», «R18 spec», its open questions — «Т-22», «П-7», «О-2»: the repository keeps no registers; other NovaTrail repositories' decisions — «R03 api»; MathTrail's — «R44 canvas-api», «R163 standalone», in a list «canvas-api: R44, R59». Each log numbers its own: «R19 spec» and `R19` of this log differ. A task — «T03», from another repository «T03 infra»; one not here is in `run/TASKS.md` or an archive: `grep -n '^#### T03\.' RUN.md run/TASKS.md docs/plan/*.md`. Task numbers are global and never reused: take the one free when writing it down.

## Epics

- **Table 1** is the current epic: its tasks in detail, run one at a time. Its rows and the bodies go in the order they run; the number does not set the order: a task added later takes a free number and stands where it runs (R26).
- **Next epic.** Once table 1 is all checked, the author picks the next epic from [run/EPICS.md](run/EPICS.md) and splits it with Claude in plan mode into tasks of one review each, into table 1 and this file.
- **A done epic** goes to `docs/plan/<epic>.md` (R59 canvas-api): bodies and gist sentences are there already (rule 9); move its description and table of tasks verbatim; questions and debt stay in `run/`; until the next epic, table 1 reads «Current epic — none» and names it as the last done epic; measure the epic's sessions — `just -f spec/justfile tokens-report --since <first day of the epic> --row` — as a row of measurements 1, and a new analysis by the threshold of R145 spec; check [BREACH.md](BREACH.md) against what the epic changed — where learners' data lie, what opens them, which logs — and the laws it touched (R27). Never read an archive whole: take the task cited.

## Table 1. Current epic — E6. Переход на `spec` 0.17 и ответы на вопросы E5

**Результат:**
- `infra` — на последнем теге `spec`, v0.18.3 (R156 spec), своей задачей с решением в журнале (RULES.md, Across repositories; R30): контейнер и правила RUN.md — по шаблону тега (T56), план — в `run/` и по-английски по R153–R155 spec (T62), CI — на последнем релизе `.github` (T63);
- тексты `infra`, которые пересказывают R116, R125, R126, R128 spec, карточку 3.11 и таблицу 3.12 spec, — по их поправкам 2026-11-13, а ссылки на В24–В35 — на ответы `spec`;
- на `eval-set/samples/` стоит правило жизненного цикла — 12 месяцев от загрузки (поправка 2026-11-13 к R126 spec; Д239 spec), — до первой ссылки eval-набора;
- раздел 2.8 [docs/architecture.md](docs/architecture.md) решён, и журнал чтения секретов включён или отвергнут решением (Д20);
- проверки на проекте, которых E5 не сделал: подписанная страница после снятия `bucketUploader` (Д21), письма Google о безопасности и журнал подключений Neon (Д22).

Код — со своими тестами (RULES.md, How we work).

| Статус | ID | Задача | Кто | План | Зависит от |
|---|---|---|---|---|---|
| [x] | T56 | Переход на `spec` v0.18.3 | я + Claude | — | — |
| [x] | T62 | План по R153–R155 spec: таблицы в `run/`, план на английском | Claude | — | T56 |
| [x] | T63 | Переход CI на последний релиз `.github` (Д146 spec) | Claude | — | T62 |
| [x] | T57 | Тексты `infra` по ответам `spec` на В24–В35 | Claude | — | T62 |
| [ ] | T58 | Правило жизненного цикла на `eval-set/samples/` | я + Claude | — | T56 |
| [ ] | T59 | Журнал чтения секретов (Д20) | я + Claude | да | T56 |
| [ ] | T60 | Проверки на проекте: страница загрузки, письма Google, Neon (Д21, Д22) | я + Claude | — | T58 |
| [ ] | T61 | Итог эпика | Claude, проверяю я | — | T56–T60, T62, T63 |

**Почему такой порядок.**
- T56 — первой: ответы `spec` на В24–В35 и поправки, на которые опираются остальные задачи, есть только на теге линии 0.17 и новее.
- T62 и T63 — вторая и третья части перехода на v0.18.3 по правилу 11 (R30), как T67 и T68 `sim`: T62 переносит таблицы и переводит правила, которые правят все задачи после неё, а T63 правит строки таблицы 4, которые T62 уже перенесла.
- T57 — сразу за ними: она правит ссылки, которые T56 сделала живыми, и не трогает кода. T58 — от T57 не зависит, но пишет в раздел 3.7, который T57 тоже правит: так они не сталкиваются.
- T58 — до первой ссылки eval-набора (поправка 2026-11-13 к R126 spec). Ссылки нет, пока `spec` не сделал T151.
- T59 — с планированием: до решения нужно увидеть записи на проекте.
- T60 — после T58: страница загрузки проверяется на бакете, где `bootstrap.sh` уже поставил правило T58, одним заходом на проект.
- T61 — итог.

## Epic E6. Переход на `spec` 0.17 и ответы на вопросы E5

**Почему эпик такой.** E5 задал `spec` вопросы В24–В35, и `spec` ответил на все 2026-11-13…15 — таблица 5 RUN.md `spec` на `main`, — но ответы лежат на теге линии 0.17, а `infra` стоит на v0.16.3. Один ответ — работа кода: правило на `eval-set/samples/` (В32). E5 оставил и свои долги: журнал чтения секретов (Д20) и проверки на проекте, которых не было (Д21, Д22). Эпик предложила T51, итог E5, 2026-11-15, по решению автора.

**Выяснилось при планировании** (код — коммит 04a3030; `spec` v0.17.12; прочитано 2026-11-15):
- **тег.** Последний тег `spec` — v0.17.12, от 2026-11-14; на `main` после него — архив E12 `spec` с поправкой 2026-11-15 к `R147` `spec`, которая сдвигает «первого ребёнка» (Д23). `deployment/`, `admission/admission-table.json` и их схемы, `tools/release/`, `tools/toolchain/` и `tools/licenses/` между тегами не менялись: факты `{}` со ступенью `full` проходят и на v0.17.12. RULES.md не менялся;
- **шаблон.** Правило 4 шаблона RUN.md получило исключение R146 `spec` — проверки задачи без автора, — правило 9 и «Как устроен план» — архив задачи вне эпика, когда текущего эпика нет (поправка 2026-11-13 к R19 `spec`). Environment шаблона CLAUDE.md и поправка 2026-11-13 к R21 `spec` — имя контейнера в его сети, `--network-alias=<repository>`: в `.devcontainer/devcontainer.json` `infra` его нет, а образ `spec` тот же — контейнер пересоздаётся, а не пересобирается;
- **ответы.** В24 — поправка 2026-11-13 к R128 `spec`, privacy 4 spec; В25 — строка «Secret Manager» таблицы 3.12; В26 — поправка 2026-11-13 к R76 `spec`; В27 — строка Д237 `spec`, для `app`; В28 — строка 7.7 закрыта; В29 — T150 `spec`, Д200; В30 — поправки 2026-11-13 к R125 и R126 `spec`, T151 `spec`; В31 — поправки 2026-11-13 к R116 и R125 `spec`; В32 — поправка 2026-11-13 к R126 `spec`, строка Д239 `spec`: правило — `age` 364 дня, как у форм; В33 — поправка 2026-11-13 к R125 `spec`, строка Д240 `spec` (Д23); В34 — строки 6.16 и 6.17 закрыты, 6.21; В35 — `R149` и `R150` `spec`, строки 6.20 и 6.21;
- **тексты.** На В24–В35 ссылаются 18 мест [docs/decisions.md](docs/decisions.md), 6 — [docs/architecture.md](docs/architecture.md), одно — [BREACH.md](BREACH.md) и три — [run/DEBT.md](run/DEBT.md). В [docs/architecture.md](docs/architecture.md), раздел 3.7, о правиле `eval-set/samples/` сказано «none … row В32»;
- **Д208 `spec`** — `NOTICE` и `LICENSE` в архиве `app`: «`infra` — своим переходом на тег», проверять, что они есть, выкладка может;
- **бакет.** Правило на `eval-set/forms/` в `tofu/bootstrap.sh` уже есть — `age` 364 и `daysSinceCustomTime` 364; на `eval-set/samples/` правила нет.

**Не входит:** ключ поставщика ИИ, факты, ступень `author` и каталог — строка 6.21, вне эпика (R29); свой проект оператора для бакетов — до первого ребёнка (Д23; строка Д240 `spec`); законы об утечках других штатов — T150 `spec`; первая ссылка взрослому — после T151 `spec`; папка юридических текстов копии (Д12); свой домен — после О-16 (R06).

#### T58. Правило жизненного цикла на `eval-set/samples/`

- **Цель:** файл eval-набора в бакете оператора стирается правилом через 12 месяцев от загрузки, если организатор не стёр его раньше (поправка 2026-11-13 к R126 `spec`).
- **Кто:** я + Claude — `bootstrap.sh` на проекте запускаю я. **План:** —.
- **Сделать:**
  1. `tofu/bootstrap.sh` — правило `Delete` с `age` 364 и `matchesPrefix` `eval-set/samples/`, как у `eval-set/forms/` (строка Д239 `spec`), с тестом в `just bootstrap-test`, который без правила падает.
  2. Раздел 3.7 — правило в таблице правил, без «none … row В32»; поправка к R28; [SELF-HOSTING.md](SELF-HOSTING.md), раздел о бакете, — если перечисляет правила; инструмент организатора `tools/organizer/` — если его текст говорит о сроке файла.
  3. На проекте: я запускаю `bootstrap.sh` с переменными `BOOTSTRAP_*`; `gcloud storage buckets describe gs://novatrail-operator --format='json(lifecycle_config)'` — шесть правил.
- **Как проверить:** `just bootstrap-test`; `just tf-check`; `just -f spec/justfile docs-check-repo`; правило на проекте.
- **Разделы:** поправка 2026-11-13 к R126 `spec`; строка Д239 `spec`; R28; [docs/architecture.md](docs/architecture.md), раздел 3.7; правило [tofu](.claude/rules/tofu.md).
- **Ждёт автора (2026-11-17):** шаг 3 — запуск `bootstrap.sh` на проекте, строка В46 [run/QUESTIONS.md](run/QUESTIONS.md); шаги 1 и 2 — в ветке `t58-samples-lifecycle`.

#### T59. Журнал чтения секретов (Д20)

- **Цель:** при утечке видно, кто прочитал версию секрета, — или решено с причиной, почему нет ([docs/architecture.md](docs/architecture.md), раздел 2.8).
- **Кто:** я + Claude — включение на проекте и чтение записей идут моими правами. **План:** да — до решения нужно увидеть записи.
- **Решить при планировании:** варианты (а) и (б) [docs/architecture.md](docs/architecture.md), раздел 2.8, — после того, как на проекте видно, что в записи `AccessSecretVersion`, кроме вызывающего и адреса, сколько их в день от сервиса и заданий `api` и во что они обходятся (sources 2.6). Как включить для проверки — временно руками или сразу модулем.
- **Сделать:**
  1. На проекте: `DATA_READ` для `secretmanager.googleapis.com`, на время проверки; записи за сутки — состав, число и объём; цена — по прайсу Cloud Logging, записью в `docs/sources.md`.
  2. По решению: (а) — `google_project_iam_audit_config` в `tofu/`, исключение `data-access-audit` каждого приёмника пропускает эти записи, тест; поправки к R07 и решение по [docs/architecture.md](docs/architecture.md), раздел 2.8; [BREACH.md](BREACH.md), раздел 4, и часть 1 — что журнал теперь показывает; (б) — снять проверочное включение, а [docs/architecture.md](docs/architecture.md), раздел 2.8, — решением с причиной.
  3. Д20 — закрыть или переписать «когда».
- **Как проверить:** `just tf-check`; после `apply` мержа — чтение секрета `api-run` видно в бакете `us-east4`, а чужих записей Data Access нет; `just -f spec/justfile docs-check-repo`; `/code-review high`.
- **Разделы:** [docs/architecture.md](docs/architecture.md), разделы 2.8 и 3.4; R07 и его поправки; R27; sources 2.6; privacy 4 spec; Д20.

#### T60. Проверки на проекте: страница загрузки, письма Google, Neon (Д21, Д22)

- **Цель:** то, что BREACH.md, часть 1, и раздел 3.7 обещают оператору, проверено на проекте, а не только прочитано.
- **Кто:** я + Claude — шаги на проекте и в консоли Neon идут моими правами. **План:** —.
- **Сделать:**
  1. Д21, страница: инструментом организатора — страница на синтетический файл; снять `bucketUploader` с учётной записи загрузки; загрузка той же страницей отказывает; вернуть роль `bootstrap.sh`. Что увидено — в раздел 3.7 и BREACH.md, часть 1; если загрузка прошла — BREACH.md правится в той же правке и вопрос — в таблицу 3.
  2. Д22, письма: кому на проекте идут письма Google о безопасности (sources 5.7). Если не оператору — Essential Contacts модулем, с адресом из окружения, как `TF_VAR_operator_email`, с тестом; решение — поправкой к R07 или R27.
  3. Д22, Neon: что план Free пишет о подключениях к базе и где оператор это видит — из первоисточника, записью в `docs/sources.md`, и BREACH.md, часть 1.
  4. Д21 и Д22 — переписать: что проверено, уходит; что осталось — с «когда».
- **Как проверить:** записи шагов в «Сделано»; `just tf-check`, если модуль менялся; `just -f spec/justfile docs-check-repo`.
- **Разделы:** [BREACH.md](BREACH.md), часть 1; [docs/architecture.md](docs/architecture.md), раздел 3.7; R27, R28; sources 5.7, 10.1–10.9; Д21, Д22.

#### T61. Итог эпика

- **Цель:** E6 сверен с [docs/architecture.md](docs/architecture.md) и карточкой, а следующий эпик выбран.
- **Кто:** Claude, проверяю я. **План:** —.
- **Сделать:**
  - сверить код и выкладку с разделом 3 и с карточкой 3.11 `spec` на теге; если что-то меняет сказанное там, — строкой таблицы 3 «в реестр spec»; о переходе и E6 — строкой таблицы 3 для COORDINATION.md `spec`;
  - [BREACH.md](BREACH.md) — сверить с тем, что эпик поменял (R27);
  - что E6 оставил — в таблицу 3 или 4;
  - следующий эпик — предложить в таблицу 2.
- **Как проверить:** `just -f spec/justfile docs-check-repo` — ok; в таблице 2 — следующий эпик.
- **Разделы:** [docs/architecture.md](docs/architecture.md), раздел 3; architecture 3.11 spec; R27.
