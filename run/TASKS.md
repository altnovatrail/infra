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
