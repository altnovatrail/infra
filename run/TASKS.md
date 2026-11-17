# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T78. english-essays 0.2.1 в каталоге novatrail

- **Цель:** на `novatrail` работает `api` релиза, который назовёт оркестратор (индекс `modules` v0.2.12), и `novatrail/english-essays` стоит в `api_catalog_modules`; выкладка прошла.
- **Почему:** строки 6.36 и 6.39 «Порядка» COORDINATION.md spec; ответы автора на В51 и В54 `infra` (T77): каталог ждёт этой выкладки. R76 spec, R156 spec.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `api` в `deploy/production.json` до названного релиза; `english-essays` в `api_catalog_modules` путём фактов (поправка 2026-11-16 к R05); поправка к R29; выкладка; проверка Deploy; В54 — по её правилам.
- **Как проверить:** `just deploy-check`; проверки репозитория; Deploy успешен.
- **Разделы:** R05, R29; В51, В54; R150 spec.
- **Релиз, который назвал оркестратор:** `api` v0.1.62, релиз строки 6.38 (2026-11-17, PR #121 `api`, T110 `api`, R92 api: `modules` v0.2.12 с `english-essays` 0.2.1); `app` — как есть, v0.1.23. Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Выяснилось при выполнении** (клон `api` во временной папке, 2026-11-17):
  - **`api` v0.1.61–v0.1.62** — `modules.json` закрепляет `modules` v0.2.12 (индекс `sha256:cb16bb45…d71a`) вместо v0.2.7: новая версия только у `english-essays`, 0.2.1, пакет `sha256:5975e7c5…9fb5`; `olympiad-math` 0.3.0, `check-board` 0.1.0 и `grade-3-math` 0.3.0 — прежние. `spec` v0.18.14 вместо v0.18.9, предел времени одного теста. Миграций, заданий, переменных и прав нет; Dockerfile — байт в байт прежний, `142cf5c9…c90a`. Контракты `spec` v0.18.12 и v0.18.14 одинаковы, `deployment/` и `admission/` v0.18.6 и v0.18.14 — тоже;
  - **локально.** `release-verify` принял бинарь и Dockerfile v0.1.62 — «api v0.1.62, signed by the shared release.yml of .github v0.1.31». `api packages` положил 7 пакетов `modules` v0.2.12; `api check` с фактами, ступенью `author`, режимом `single` и каталогом из трёх модулей прошёл — «"admission_table":"0.4"» — и отверг `novatrail/english-essay`: «not in the pinned index».
- **Решено исполнителем** (технические мелочи, R156 spec):
  - один мерж: `api` в списке и каталог в `tofu/production.auto.tfvars`, по ответу на В54. «Путём фактов» здесь — внутри пути релиза: `target` даёт части `api` и `facts`, а `api.sh release` берёт новую версию фактов, гоняет задания `check` с каталогом конфигурации на новом образе до миграций и выводит ревизию (вторая поправка 2026-11-17 к R05). `apply` перед ним делает ревизию без трафика на образе v0.1.60, где `english-essays` 0.2.0 тоже в индексе;
  - запись каталога — четвёртая поправка 2026-11-17 к R25, релиз — шестая поправка 2026-11-17 к R29;
  - [BREACH.md](../BREACH.md), часть 1, не меняется: сочинение уходит к ИИ текстом, а хранится в таблице `works` — обе строки это уже называют;
  - **В54** ушла из таблицы 3 ещё в T77, с ответом автора в её теле: по её правилам делать нечего. В49, которую называет строка 6.36, не тронута: текст задачи её не называет;
  - `[x]`, Д31 и перенос тела в архив E6 — после мержа, выкладки и проверки Deploy.
- **Риски:** если путь релиза упадёт после `apply`, в конфигурации уже каталог с `english-essays`, а трафик — на v0.1.60, где это 0.2.0. Ручной прогон «только факты» тогда вывел бы 0.2.0 на сайт: сначала pull request — откат каталога или исправление релиза (вторая поправка 2026-11-17 к R05).
