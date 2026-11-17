# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T72. Режим чтения почерка на novatrail: single

- **Цель:** на развёртывании `novatrail` почерк читает один Haiku 5.5 · medium: переменная `API_READING_MODE=single` у сервиса `api`, `api` поднят до релиза с ней, выкладка прошла.
- **Почему:** R76 spec, R156 spec; слово автора 2026-11-17: «выстави сейчас этот режим» (только Haiku medium); поправка 2026-11-17 к R68 spec (пишет задача spec того же прогона). Находка В42 `infra` (T69).
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:**
  - переменная `api_reading_mode` (`pair`|`single`, по умолчанию `pair`, проверка значения) → env `API_READING_MODE` у службы `api` и у задания `check` (где задано `API_ADMISSION_RUNG`); на `novatrail` — `single`; поправка к R25 infra;
  - поднять `api` до v0.1.58 — релиз с `API_READING_MODE` (T104 api, PR #115, merge ea510b7c; `compare` v0.1.58 — identical) тем путём, каким репозиторий меняет версию `api`;
  - тесты tofu (`tofu/tests/api.tftest.hcl`): env по умолчанию и `single`, отказ чужого значения; `docs/architecture.md`, решение;
  - выкладка тем же путём, что в T69; проверка: на ревизии `API_READING_MODE=single` (`gcloud run services describe` или CI-лог выкладки). Шаг автора, если нужен, — вопросом с готовой командой для Cloud Shell; ключей и UID автору не присылать и не просить.
- **Как проверить:** проверки репозитория зелёные; выкладка успешна; на ревизии `single`.
- **Слово автора 2026-11-17 «оставить single для абсолютно всех»** (T180 spec, v0.18.9): `single` разрешён и при ступени `full`, но на `novatrail` ступень и так `author`.
- **Проверка выкладки:** после мержа Deploy пройдёт сам (проверка app теперь ждёт CDN, T71); если для проверки ревизии нужен `gcloud` с правами автора — вопрос с готовой командой для Cloud Shell.
- **Строка:** 6.31 COORDINATION.md spec (поправка 2026-11-17 к R68 spec; T179 spec) — её текст главнее этого, если они расходятся.
- **Разделы:** R68 spec; architecture 3.11 spec; `tofu/api.tf`, `tofu/variables.tf`; T69 infra.
- **Выяснилось при выполнении** (релиз и код — клон `api` во временной папке, 2026-11-17):
  - **`api` v0.1.58** — последний релиз; с ним приходят `API_READING_MODE` (R88 api) и `tutor` v0.1.45. Миграций, заданий, прав и других переменных нет; `modules` — тот же v0.2.7; Dockerfile — байт в байт прежний, `142cf5c9…c90a`; `app` v0.1.15 — всё ещё последний;
  - **локально.** `api check` бинаря v0.1.58 на пакетах релиза с фактами, каталогом и ступенью `author` принял `API_READING_MODE=single` — «"reading_mode":"single"», — принял его и при ступени `full` и отверг `haiku`: «API_READING_MODE must be pair, single or unset». `api check` v0.1.57 с `API_READING_MODE=single` прошёл как прежде: ревизия, которую `apply` делает на прежнем образе, стартует;
  - **один мерж.** Путь `release` берёт и новую версию `api`, и новые значения ревизии: `apply` делает ревизию без трафика, задание `check` v0.1.58 проверяет режим до миграций, новая ревизия получает весь трафик.
- **Решено исполнителем** (технические мелочи, R156 spec):
  - модуль задаёт `API_READING_MODE` всегда, и `pair` тоже, как ступень; задания других частей почерка не читают и режима не получают;
  - смена `api_reading_mode` идёт путём фактов, как ступень, каталог и версия ключа (`REVISION_VALUES` в `tools/deploy/target.mjs`; поправка 2026-11-17 к R05); проверки списка режим не читают — его проверяет `api check`;
  - В44 удалена из таблицы 3: `spec` записал её поправкой 2026-11-17 к R68 spec, ответ — в поправке к R25;
  - `[x]` — после мержа, выкладки и проверки ревизии.
