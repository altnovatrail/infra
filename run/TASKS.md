# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T68. Переход на тег `spec` v0.18.6

- **Цель:** `infra` стоит на последнем теге `spec`, v0.18.6, — его правила, план и документы по этому тегу, — и остальные задачи эпика прогона COORDINATION.md (волна 0; слово автора 2026-11-16) `spec` идут здесь на нём.
- **Кто:** Claude — исполнитель прогона оркестратора `spec`; Rebuild Container после мержа делаю я. **План:** —.
- **Почему:** R156 spec — волна 0 прогона «Сделай эпик E…»: оркестратор первым переводит каждый репозиторий эпика на последний тег `spec`; переход — задача и решение журнала (RULES.md spec, Across repositories). Задача вне эпика или в текущем эпике — по правилам этого RUN.md.
- **Сделать:**
  1. `gh release verify v0.18.6 -R altnovatrail/spec`; подмодуль `spec/` — на v0.18.6; где репозиторий берёт модуль Go или пакет npm `spec` — та же версия, пакет npm — через `release-verify-npm` (R77 spec); тег — везде, где этот репозиторий его называет: CLAUDE.md, README, начало RUN.md, статус `docs/architecture.md`.
  2. Что теги после v0.18.4 до v0.18.6 несут этому репозиторию: `git -C spec log --oneline v0.18.4..v0.18.6`; строки таблицы 4 `spec` с именем репозитория в обратных кавычках — `grep -n '`infra`' spec/run/DEBT.md`; карточка architecture 3.11 spec; RULES.md spec. Что из них берёт эта задача, а что — задача своя, решает сессия; отложенное — строкой таблицы 4.
  3. Заготовка `spec/repo-template/` (repositories 2.2 spec): `just new-repo-draft infra docs 3.11 v0.18.6` на клоне `spec` v0.18.6 во временной папке, как T56 `sim`. `.devcontainer/`, `.claude/`, CLAUDE.md, правила RUN.md и раскладка таблиц плана — по ней, где она изменилась, с отличиями, которые держат решения этого журнала.
  4. Решение журнала о переходе — что тег принёс и что взято —, поправки к записям, которые он меняет; строки таблиц 3 и 4, которые тег закрывает.
  5. Переход больше одного ревью — разбить по правилу 11: эта задача — первая часть, остальные — следующими задачами, и назвать их в отчёте.
- **Как проверить:** `just -f spec/justfile docs-check-repo` на новом теге — зелёный; проверки частей, которые задача меняет, — правило 6 этого RUN.md; `/code-review high`, один круг.
- **Мой шаг:** если задача меняет `.devcontainer/` — назвать это в отчёте: после мержа автор пересобирает контейнер, и оркестратор ждёт этого перед следующей задачей.
- **Разделы:** R156 spec, R76 spec; RULES.md spec; repositories 2.2 spec; карточка architecture 3.11 spec.
