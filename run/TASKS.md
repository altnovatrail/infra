# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T70. Правдивые факты на `novatrail` и ИИ платформы другим взрослым (строка 6.24)

- **Цель:** на `novatrail` факты правдивы, и другие взрослые учатся с ИИ платформы.
- **Почему:** R76 spec, строка 6.24; R149 spec и третья поправка 2026-11-15 к R76 spec.
- **Кто:** Claude; коды `api invite` — шаг автора; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** пара — релиз `api` строки 6.23 и последний `app`, выкладка по списку (R29 infra); `deploy/production/facts.json` — `{"anthropic": {"data_processing_agreement": ["adult"]}}`, без `minimal_retention`; поправка к R25 infra; коды `api invite` другим взрослым — только после этого и не раньше 2026-11-28.
- **Как проверить:** `tofu plan` без лишнего; `just site-check` `app` после выкладки.
- **Разделы:** R25, R29 infra; R96, R149 spec.
- **Выяснилось при выполнении** (релизы и код — клоны `api` и `app` во временной папке, 2026-11-17):
  - **строка 6.23** — T94 `api` и R84 `api`. Таблица 0.4, политика 4 и выгрузка 3 есть с `api` v0.1.51, так что v0.1.55, который сейчас на проекте, их уже читает. Строка 6.24 просит `api` v0.1.51 или новее;
  - **пара** — `api` v0.1.57 и `app` v0.1.15, последние релизы на 2026-11-17, оба на `spec` v0.18.6. `deploy-check` принял все три файла. С `api` v0.1.56–v0.1.57 приходят `tutor` v0.1.42 вместо v0.1.35 (`access_returns`, T103 `api`), `module-kit` v0.3.3 и `just dev-app` с синтетическим ребёнком — последнее только для разработки. Миграций, заданий, переменных и прав нет; `modules` — тот же v0.2.7; Dockerfile — байт в байт прежний, `142cf5c9…c90a`;
  - **локально.** `api check` бинаря v0.1.57 на пакетах релиза (`modules` v0.2.7, 6 пакетов) принял новые факты со ступенью `author` и каталогом: «"admission_table":"0.4"» и «"rung":"author"». Опечатку `novatrail/check-bord` он отверг: «not in the pinned index»;
  - **один мерж.** Путь `release` выкладки сам берёт новую версию фактов: сначала задание `check` с этой версией, затем миграции, затем ревизия с ней (R15). Отдельно часть `facts` при смене `api` не идёт. `tofu/` и его значения не меняются, и `apply` должен дать «No changes».
- **Решено исполнителем** (технические мелочи, R156 spec):
  - пара — последние релизы, а не v0.1.51: строка 6.24 допускает «или новее», а R29 выкладывает новые релизы по мере выхода;
  - `[x]` — после выкладки и проверок после мержа;
  - коды `api invite` — шаг автора, а не выкладки (R25): задача их не ждёт и называет в «Открыто».
