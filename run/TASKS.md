# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T74. README без «Status», «License», фразы о языках и версии spec

- **Цель:** README.md этого репозитория короче: в нём нет разделов «Status» и «License», в «Documents» нет фразы о языках документов, а ссылка на spec не называет версию.
- **Почему:** слово автора 2026-11-17 для README.md всех репозиториев: «удали раздел Status и License — это бесполезные разделы; в разделе Documents удали глупое предложение о языках… Также убери упоминание конкретной версии spec». Статус и тег в README устаревают с каждой задачей и переходом на тег, а лицензию называют файлы LICENSE и NOTICE и бейдж. Правило для заготовки и для `spec-tag.md` записывает отдельная задача spec этого прогона (поправка к R21 spec).
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:**
  - README.md: удалить раздел `## Status` целиком и раздел `## License` целиком (бейдж лицензии в шапке оставить); в `## Documents` удалить предложение о языках документов и плана («The documents and the work plan are in English; …» или его вариант); фразу о spec — без версии: ссылка на `https://github.com/altnovatrail/spec` без `/tree/vX`, «checked out here as a git submodule» без «at `vX`». Остальное не трогать. Если в README есть другие файлы README.md с теми же разделами (например, в подпапках, которые этот репозиторий публикует) — так же.
  - Найти, что в этом репозитории велит обновлять статус или тег в README: `grep -rn -i 'README' RUN.md run/ docs/decisions.md CLAUDE.md AGENTS.md .claude/ tools/ scripts/ 2>/dev/null | grep -i -E 'status|статус|tag|тег|version|верси|license|лиценз'`. Открытые тела задач и правила плана — без этой части; решения журнала — поправкой 2026-11-17 (не переписывать), если решение держит раздел. Проверка или тест, который требует эти разделы, — поправить вместе с ним.
  - Если раздел «Status» держал что-то, чего больше нигде нет и что нужно сессии (например, адрес развёртывания или ссылку), — перенести в подходящий раздел README или в `docs/architecture.md` одной строкой, а не терять.
- **Как проверить:** `just -f spec/justfile docs-check-repo` (в spec — `just docs-check`); проверки частей, которые задача меняет; ревью не обязательно, если меняются только документы (правило ревью этого RUN.md).
- **Разделы:** README.md; R21 spec (заготовка); RULES.md spec, Language.
