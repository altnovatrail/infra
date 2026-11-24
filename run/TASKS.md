# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T106. Переход на тег `spec` v0.19.17

- **Цель:** `infra` стоит на последнем теге `spec`, v0.19.17, — его правила, план и документы по этому тегу, — его расширения VS Code в `.devcontainer/` и Claude Code — последних стабильных версий по проверке `devcontainer-outdated`.
- **Почему:** слово автора 2026-11-23: расширения VS Code и Claude Code во всех devcontainer — до последних стабильных версий, каждый репозиторий сам проверяет, что у него устарело. Строка 7.61 COORDINATION.md `spec`, по тексту T286 `spec`; R30 `spec`, пункт «Versions». Задача вне эпика — по правилам этого RUN.md.
- **Кто:** Claude — исполнитель прогона оркестратора `spec`, одна задача, своя ветка и один pull request; мерж — оркестратор по слову автора. **План:** —.
- **Сделать:**
  1. `gh release verify v0.19.17 -R altnovatrail/spec`; подмодуль `spec/` — на v0.19.17; где репозиторий берёт модуль Go или пакет npm `spec` — та же версия, пакет npm — через `release-verify-npm`; тег — в строках CLAUDE.md и RUN.md, которые его называют; другой документ тега не называет, а называет подмодуль, и README.md раздела «Status» не держит.
  2. Что теги после v0.19.13 до v0.19.17 несут этому репозиторию: `git -C spec log --oneline v0.19.13..v0.19.17`; строки таблицы 4 `spec` с именем репозитория в обратных кавычках — `grep -n '`infra`' spec/run/DEBT.md`; карточка компонента в `spec/docs/architecture.md`; `spec/RULES.md`. Что из них берёт эта задача, а что — задача своя, решает сессия; отложенное — строкой таблицы 4.
  3. Сначала — `just -f spec/justfile devcontainer-outdated`, его вывод — в отчёт: что репозиторий отставал. Затем заготовка `spec/repo-template/`: `just new-repo-draft infra docs 3.11 v0.19.17` на клоне `spec` v0.19.17 во временной папке. `.devcontainer/`, `.claude/`, CLAUDE.md, правила RUN.md и раскладка таблиц плана — по ней, где она изменилась, с отличиями, которые держат решения этого журнала.
  4. После шага 3 — `just -f spec/justfile devcontainer-outdated` снова: поднять всё, что она ещё называет, — свои расширения репозитория тоже, — пока она не выйдет с 0. Смена мажорной версии — сначала её changelog; ломает настройки `devcontainer.json` — последняя минорная старой мажорной, причина — в отчёт. `CLAUDE_CODE_VERSION` выше, чем у тега `spec`, — по строке Д251 `spec`: `headless.md` и changelog, и `claude -p` новой версии входит по подписке; иначе — версия тега `spec` и вопрос в таблице 3.
  5. Коммит перехода говорит, что тег принёс и что взято; записи журнала, которые тег меняет, переписываются на месте; строки таблиц 3 и 4, которые тег закрывает, закрываются.
  6. Переход больше одного ревью — разбить по правилу 11: эта задача — первая часть, остальные — следующими задачами, и назвать их в отчёте.
- **Как проверить:** `just -f spec/justfile docs-check-repo` на новом теге — зелёный; `just -f spec/justfile devcontainer-outdated` — 0; проверки частей, которые задача меняет, — правило 6 этого RUN.md; `/code-review high`, один круг.
- **Мой шаг:** нет — после мержа оркестратор сам пересобирает контейнер и проверяет `claude --version`.
- **Разделы:** карточка компонента в `spec/docs/architecture.md`; `spec/RULES.md`; `spec/repo-template/`.
- **Задача записана** по тексту оркестратора под номером T106, свободным 2026-11-24 (правило 6 COORDINATION.md spec).
