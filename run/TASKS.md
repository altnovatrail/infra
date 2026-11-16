# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T66. Переход на тег `spec` строки 7.14: стадия `toolchain-core`

- **Цель:** `infra` — на теге `spec` строки 7.14 COORDINATION.md spec, со стадией `toolchain-core` в `.devcontainer/Dockerfile` по шаблону и apt шаблона — только из источников снимка, так что общие проверки без браузера и Go-тестов идут в этой стадии, как задумала строка 7.13.
- **Кто:** я + Claude — Rebuild Container после мержа делаю я (правило [ci](../.claude/rules/ci.md)). **План:** —.
- **Почему:** строка 7.14 — стадия `toolchain-core` в Dockerfile `spec` и шаблона, по T166 spec; строка 7.13 — с тегом `spec` строки 7.14 проверки lint, licenses и документов идут в `toolchain-core`. Задача меняет `.devcontainer/` и потому последняя из задач строки 7.25 (T64, «Сделать», п. 2). Переход на тег — своей задачей, решением журнала (RULES.md, Across repositories), как R30. Ждёт тега `spec` строки 7.14 и T65. Последняя часть строки 7.13, T66 `.github` — стадия `toolchain-core` в релизе и проверках, — выходит после перехода `.github` на тег `spec` строки 7.14, а он меняет `.devcontainer/`; по решению координатора `spec` (T171 spec) ночью `.devcontainer/` не меняется, поэтому T65 взяла `v0.1.30` без неё, а релиз с T66 `.github` берёт эта задача (вторая поправка 2026-11-16 к R32).
- **Сделать:**
  1. Тег: последний тег `spec` со строкой 7.14; что меняют `tools/toolchain/`, заготовка `.devcontainer/`, RULES.md и шаблон RUN.md — по `git diff` тегов.
  2. `.devcontainer/Dockerfile` — стадия `toolchain-core` по заготовке; OpenTofu, ShellCheck и actionlint (R09) — в стадии, которую берут job OpenTofu и рецепты `ci-tofu`, `ci-shellcheck` и `ci-actionlint`; apt — только источники снимка.
  3. Свои job — в стадии, которая им нужна. Ключ кеша — по Dockerfile: старые записи — `gh cache delete` или семь дней (R32).
  4. Релиз `.github` с T66 `.github`, если он вышел: `gh release verify`, запись `docs/sources.md`; пять ссылок `ci.yml`, `codeql.yml` и `scorecard.yml` — на SHA его тега. R42 .github: смена того, как строится образ, — `toolchain-core`, — даёт файлу образа новый путь во всех workflow сразу; тот же путь и ключ — в `.github/actions/toolchain`, а сборка роли `build` (`docker build --target toolchain --tag novatrail-toolchain`) — та же, что у `toolchain.sh` нового тега, стадия и имя образа. Если релиз ещё не вышел, — строкой [QUESTIONS.md](QUESTIONS.md): ждать его или переходить на тег без него.
  5. Решение журнала о переходе; поправки к R09 и R32; где документы называют v0.18.3 и v0.1.30 — новые теги.
- **Как проверить:** `just ci-tofu`, `just ci-shellcheck`, `just ci-actionlint` и их тесты; `just tf-check`, `just bootstrap-test`; CI pull request — зелёный; `just -f spec/justfile docs-check-repo`; `/code-review high`, один круг.
- **Разделы:** строки 7.13, 7.14 и 7.25 COORDINATION.md spec; measurements 3.1 spec; R09, R30, R32 и её вторая поправка 2026-11-16; sources 5.9; T64, T65.

#### T67. Папка юридических текстов своей копии (Д12)

- **Цель:** своя копия платформы отдаёт тексты своего оператора: её выкладка передаёт `api` папку текстов в раскладке части `legal/` `spec` и путь к ней в `API_LEGAL_DIR`, а платформа, у которой папки нет, выкладывается как прежде (вторая поправка 2026-11-09 к R115 spec; R130 spec; Д12).
- **Кто:** Claude. **План:** да — как папка доходит до ревизии, документы не решают.
- **Почему:** ночная работа по слову автора 2026-11-16 (T171 spec, R156 spec): в таблице 1 и здесь нет открытой задачи, у которой «Кто» — ровно «Claude», и из строк [DEBT.md](DEBT.md) внутри репозитория целиком закрывается только Д12 — Д25 переписывает порядок при утечке, текст, который автор читает построчно. Релиз `api`, который называет переменную, вышел — v0.1.21, а список выкладывает v0.1.42 (sources 3.15).
- **Выяснилось при планировании** (`main` b4e104d; прочитано 2026-11-16; sources 3.15):
  - `api` v0.1.42 читает папку при старте и не стартует, если она нарушает правила части; папка — вне рабочего дерева git, только `VERSION`, `legal.yaml` и `texts/`; задание `check` папку не читает — раннюю проверку даёт рецепт `legal-check-dir` `spec` в CI pull request, а последнюю — ревизия без трафика, которая не становится `Ready` ([docs/architecture.md](../docs/architecture.md), раздел 3.2);
  - тома Secret Manager, как у фактов (R05), не годятся: версия — не больше 64 KiB, один секрет — один путь монтирования, а у самой части `legal/` 25 файлов в `texts/` на 384 КБ;
  - остаются слой над образом релиза — образ держит то, что кладут решения репозитория (R105 spec), — и том Cloud Storage, только для чтения, на втором поколении среды.
- **Решить при планировании:** как папка доходит до ревизии и заданий — строка В37 [QUESTIONS.md](QUESTIONS.md).
- **Сделать** (по ответу на В37):
  1. Место папки в `deploy/` копии и её проверка в pull request — `legal-check-dir` в job `Deploy`, когда папка есть; без папки — ни проверки, ни переменной.
  2. Выкладка `tools/deploy/api.sh` и модуль `tofu/api.tf` — папка в ревизии и в заданиях, которым она нужна, `API_LEGAL_DIR`; путь «только тексты», как путь «только факты»; тесты — синтетическая копия с папкой и платформа без неё.
  3. [docs/architecture.md](../docs/architecture.md), раздел 3.2 и таблица раздела 3.5; решение журнала; [SELF-HOSTING.md](../SELF-HOSTING.md) — шаг оператора с папкой; Д12 — закрыть.
- **Как проверить:** `just deploy-check` и тесты `tools/deploy/`; `just tf-check`; `just -f spec/justfile docs-check-repo`; `/code-review high`, один круг.
- **Разделы:** вторая поправка 2026-11-09 к R115 spec; R130 spec; R105 spec; [docs/architecture.md](../docs/architecture.md), разделы 3.2 и 3.5; R05, R11, R15, R21; sources 3.4, 3.15; Д12.
