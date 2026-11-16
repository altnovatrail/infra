# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T69. ИИ платформы на `novatrail` для автора: ключ, факты, ступень `author`, каталог (строка 6.21)

- **Цель:** на `novatrail` автор решает задачи модуля доски с ИИ платформы, а каталог — без «Short essays in English».
- **Почему:** R76 spec, строка 6.21 COORDINATION.md spec; R149 и R150 spec; ответ на строки В34 и В35. Автор решил 2026-11-16: в `infra` эта строка идёт первой, раньше остатка E6 (T58–T61), затем 6.24.
- **Кто:** я + Claude — лимит трат, ключ и проверка базы идут моими правами; мерж — оркестратор (R156 spec). **План:** да — его составил исполнитель, без утверждения: он в описании pull request.
- **Сделать:**
  - до ключа — шаг автора: лимит трат рабочей области Anthropic (Д11 `api`);
  - ключ Anthropic платформы — секрет Secret Manager, томом на точной версии, путь — `API_ANTHROPIC_KEY_FILE` (R46 api); ключ кладёт автор, в репозиторий он не попадает;
  - `deploy/production/facts.json` — `{"anthropic": {"data_processing_agreement": ["adult"], "minimal_retention": ["adult"]}}`; `minimal_retention` объявлен неправдиво, как в первом приложении, и это записано в R149 spec;
  - ступень `author` — в `deploy/production.json` и `tofu/api.tf`; список каталога — `novatrail/olympiad-math` и `novatrail/check-board`; обе переменные — у службы и у задания `check`;
  - пара — релиз `api` строки 6.20 и последний релиз `app`, выкладка по списку (R29 infra); поправка к R25 infra: ступень, факты, ключ, каталог; до выкладки — проверить, что в базе нет аккаунтов, кроме автора (строка В23), а найденный — автору на решение, без удаления; кодов `api invite` другим — нет до T159 spec;
  - после выкладки — `just site-check` `app` с версией пары; автор решает задачу модуля доски: «Проверить», неверный ответ — рамка у ошибки.
- **Как проверить:** `tofu plan` без лишнего; проверки после выкладки; траты — поставщик, число вызовов и сумма (правило 4 RUN.md spec).
- **Разделы:** R25, R29 infra; R45, R46, R55 api; R149, R150 spec; architecture 3.11 spec.
- **Выяснилось при планировании** (релизы и код — клоны `api` и `app` во временной папке, 2026-11-16):
  - **пара** — `api` v0.1.55 и `app` v0.1.14, последние на 2026-11-16, оба на `spec` v0.18.4. `release-verify` принял все три файла. Dockerfile — байт в байт прежний, `142cf5c9…c90a`. Миграции `0018`–`0020` базы `api` только добавляют столбцы; у `openfga` новых нет. Новых заданий и прав нет. Новая переменная одна — `API_CATALOG_MODULES`; `api check` читает её вместе с `API_ADMISSION_RUNG`, `API_ADMISSION_FACTS_FILE` и `API_PACKAGES_DIR`, ключа не читает;
  - **`api` v0.1.42**, который сейчас на проекте, ступень `author` на развёртывании отвергает. `apply` строит ревизию шаблона на образе, который сейчас обслуживает трафик. Поэтому сначала идёт пара, а ступень — потом;
  - **секрет ключа** появляется только после `apply`, а версия, которую монтирует служба, должна быть до `apply`, который её называет. Поэтому выкладок две;
  - **таблица 0.4.** `api` v0.1.55 читает её: `minimal_retention` клеткам `adult` уже не нужен. Факт объявлен по тексту строки 6.21, а снимает его строка 6.24;
  - **локально.** `api check` бинаря v0.1.55 на пакетах релиза (`modules` v0.2.7, 6 пакетов) принял факты строки 6.21, ступень `author` и каталог: «"admission_table":"0.4"» и «"rung":"author"». Опечатку `novatrail/check-bord` он отверг: «not in the pinned index»;
  - **путь «только факты»** раньше не видел смены ступени, а ключа и каталога не было вовсе. Ревизия, которую строит `apply`, трафика не получает (поправка 2026-11-13 к R11). Теперь `target` даёт часть `facts` и при смене `admission` в списке, и при смене трёх значений `tofu/production.auto.tfvars`.
- **План:**
  1. Pull request 1 (этот прогон): модуль, проверки списка, `target`, документы, пара `api` v0.1.55 и `app` v0.1.14. Ступень `full`, факты `{}`, секрет ключа — без значения. После мержа `Deploy` выкладывает пару: проверка, миграции, ревизия, `after`, затем `app`.
  2. Шаги автора (вопросами оркестратору): лимит трат рабочей области Anthropic; ключ — первой версией `api-anthropic-key`; список аккаунтов базы `api` — только автор.
  3. Pull request 2: `api_anthropic_key_version`, `api_admission_rung = "author"`, `api_catalog_modules`, ступень списка и факты. После мержа — путь фактов: задание `check`, затем ревизия.
  4. После выкладки: прогон `Deploy` по журналу; `just site-check https://novatrail.web.app v0.1.14` `app` (в контейнере `infra` нет браузеров — шаг автора или `app`); автор решает задачу модуля доски; траты у поставщика — число вызовов и сумма. Затем «Сделано», `[x]`, перенос в архив E6.
- **Решено исполнителем** (технические мелочи, R156 spec):
  - ступень, каталог и версия ключа — переменные модуля `api_admission_rung` (по умолчанию `full`), `api_catalog_modules` (по умолчанию пустой список — весь индекс) и `api_anthropic_key_version` (по умолчанию нет ключа). Значения `novatrail` — в `tofu/production.auto.tfvars`, а `deploy-check` держит ступень списка равной ступени конфигурации. У копии остаются значения по умолчанию;
  - секрет — `api-anthropic-key` (по имени службы), том — второй, `/etc/api/anthropic/key`; факты остаются первым томом, и выкладка ставит их версию по месту.
- **Ход работы (2026-11-16):**
  - **первый мерж** — pull request 92, мерж b7d746f, прогон `Deploy` 43979833185, все четыре задания зелёные. `config`: «Plan: 2 to add, 0 to change, 0 to destroy» — секрет `api-anthropic-key` и право `api_reads_anthropic_key`; служба и задания не менялись. `api`: «api v0.1.55 after v0.1.42, which takes the traffic», образ `api@sha256:e464dc71933abdfa72e02afaa789f522454b661a9efa4515f231593458b66d4a`, версия фактов 8. `api-check-2f7k2`, `api-migrate-jdkjr` и `api-after-tcmf4` — «has successfully completed», ревизия `api-00008-h6c` — весь трафик. `app`: «app v0.1.6 came before: its 2 files of assets/ are kept», «released: app v0.1.14»;
  - **сайт** (`curl` из контейнера): sha256 `/deployment.json` — `13e18579…6cd4`, как в списке; у `/` — CSP, `nosniff` и `no-cache`; `index-C1vX3E7p.js` — файл архива v0.1.14; `/health` `api` — 200;
  - **ждём автора** — В38 (лимит трат), В39 (ключ) и В40 (аккаунты базы) в [QUESTIONS.md](QUESTIONS.md).
- **Мой шаг:** лимит трат; ключ в Secret Manager; проверка аккаунтов базы; вход на сайт и задача доски; `site-check`, если его не прогонит оркестратор.
- **Риски:** `gcloud run services update --update-secrets` пути фактов на службе с двумя томами секретов на проекте ещё не проверялся. Проверка — первый прогон пути фактов в pull request 2, а после него — `tofu plan` без изменений.
