# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T65. Переход CI на релиз `.github` строки 7.13

- **Цель:** CI `infra` — на релизе `.github` строки 7.13 COORDINATION.md spec: файл образа `toolchain` — один путь и один тег, как во всех общих workflow, без сохранения из pull request, а при промахе образ строит один job; что проверки доказывают, не меняется.
- **Кто:** Claude. **План:** —.
- **Почему:** остаток строки 7.25 COORDINATION.md spec после T64: «job Deploy — образ из кеша … переход на `.github` строки 7.13», «Зависит от» — «7.13 — для образа». Из кеша job OpenTofu и Deploy образ уже берут — через одно действие `.github/actions/toolchain`, теми же ключом и путём, что `documents.yml` v0.1.24 (R32), — и правка будет в одном месте. Задача ждёт релиза `.github` по строке 7.13: оркестратор запустит её, когда он выйдет.
- **Сделать:**
  1. Релиз: `gh release list -R altnovatrail/.github` и `gh release verify <тег> -R altnovatrail/.github`; что общие workflow меняют от v0.1.24 — путь, тег и сохранение файла образа, job сборки при промахе, входы и права, стадия `toolchain-core` — записью `docs/sources.md`.
  2. `.github/workflows/ci.yml`, `codeql.yml` и `scorecard.yml` — пять ссылок на SHA нового тега с его именем в комментарии; входы, которые новая версия требует или меняет.
  3. `.github/actions/toolchain/action.yml` — те же путь, тег и правило сохранения, что у `documents.yml` релиза; если релиз строит образ одним job, а остальные его ждут, — так же job OpenTofu и Deploy.
  4. Поправка к R32; правило [ci](../.claude/rules/ci.md).
- **Не делать:** `.devcontainer/` и тег `spec` — T66, последней. Если общие проверки релиза без стадии `toolchain-core` в `.devcontainer/Dockerfile` не работают, — остановиться и спросить автора строкой [QUESTIONS.md](QUESTIONS.md): порядок T65 и T66.
- **Как проверить:** `just ci-actionlint` и `just ci-actionlint-test`; CI pull request — зелёный, образ — из кеша; время job OpenTofu и Deploy до и после — по прогонам `main` и pull request; `just -f spec/justfile docs-check-repo`; `/code-review high`, один круг.
- **Разделы:** строки 7.13 и 7.25 COORDINATION.md spec; measurements 3.1 spec; R30 spec, R31 spec; R09, R32; T64.

#### T66. Переход на тег `spec` строки 7.14: стадия `toolchain-core`

- **Цель:** `infra` — на теге `spec` строки 7.14 COORDINATION.md spec, со стадией `toolchain-core` в `.devcontainer/Dockerfile` по шаблону и apt шаблона — только из источников снимка, так что общие проверки без браузера и Go-тестов идут в этой стадии, как задумала строка 7.13.
- **Кто:** я + Claude — Rebuild Container после мержа делаю я (правило [ci](../.claude/rules/ci.md)). **План:** —.
- **Почему:** строка 7.14 — стадия `toolchain-core` в Dockerfile `spec` и шаблона, по T166 spec; строка 7.13 — с тегом `spec` строки 7.14 проверки lint, licenses и документов идут в `toolchain-core`. Задача меняет `.devcontainer/` и потому последняя из задач строки 7.25 (T64, «Сделать», п. 2). Переход на тег — своей задачей, решением журнала (RULES.md, Across repositories), как R30. Ждёт тега `spec` строки 7.14 и T65.
- **Сделать:**
  1. Тег: последний тег `spec` со строкой 7.14; что меняют `tools/toolchain/`, заготовка `.devcontainer/`, RULES.md и шаблон RUN.md — по `git diff` тегов.
  2. `.devcontainer/Dockerfile` — стадия `toolchain-core` по заготовке; OpenTofu, ShellCheck и actionlint (R09) — в стадии, которую берут job OpenTofu и рецепты `ci-tofu`, `ci-shellcheck` и `ci-actionlint`; apt — только источники снимка.
  3. Свои job — в стадии, которая им нужна. Ключ кеша — по Dockerfile: старые записи — `gh cache delete` или семь дней (R32).
  4. Решение журнала о переходе; поправки к R09 и R32; где документы называют v0.18.3 — новый тег.
- **Как проверить:** `just ci-tofu`, `just ci-shellcheck`, `just ci-actionlint` и их тесты; `just tf-check`, `just bootstrap-test`; CI pull request — зелёный; `just -f spec/justfile docs-check-repo`; `/code-review high`, один круг.
- **Разделы:** строки 7.13, 7.14 и 7.25 COORDINATION.md spec; measurements 3.1 spec; R09, R30, R32; T64, T65.
