# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T91. Выкладка E11 на novatrail: api v0.1.72 и app v0.1.42

- **Цель:** на `novatrail` работает режим «Задача с моей бумаги» (эпик E11 `spec`, `R162` `spec`): `api` v0.1.72 и `app` v0.1.42; выкладка прошла, проверка Deploy зелёная.
- **Почему:** R76 spec, R156 spec; строка 6.44 COORDINATION.md spec; слово автора 2026-11-20 — выложить E11, как только выпущен. Выпуски: spec v0.19.0 и v0.19.1 (spec #206, #207), module-kit v0.3.16, tutor v0.1.59, canvas 0.3.36, api v0.1.72 (api#135), app v0.1.42 (app#106).
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `api` и `app` в `deploy/production.json` до v0.1.72 и v0.1.42 — их файлы и суммы из релизов, как в T90 и T81; что пришло с релизами и чем проверено — в коммите и описании pull request, без хроники в решениях (R160 spec). `api` v0.1.72 несёт миграции 0023–0025 (ключ задачи с бумаги, режим подсказок, закрытие попыток страницы) и новые RPC `PaperService`, `DebugService`, `AccountService/SetHintMode`; `app` v0.1.42 их вызывает — проверить, что выкладка `api` идёт раньше `app` или обе одним прогоном, как задаёт deploy.yml. Если `deploy-check` или выкладка требуют от `infra` нового тега `spec` (таблица допуска 0.5 с `task_finding`, `statement_reading`, `task_solving`; release-verify выпусков на spec v0.19.x) — перейти на последний тег `spec` в этой же задаче, со строками CLAUDE.md и RUN.md, что называют тег (R160 spec). Отладочный режим `API_DEBUG_MODELS` на проде не включать. Тело T90 — в архив эпика по правилу 9, как T90 сделала с T84, если его Deploy был зелёным.
- **Как проверить:** проверки репозитория зелёные, `just deploy-check origin/main`; после мержа Deploy успешен (проверка `app` ждёт CDN, T71); на `https://novatrail.web.app` карточка «Задача с моей бумаги» на главной открыта, не «Будет позже».
- **Разделы:** R29 infra, R106 spec, `R162` `spec`; T70, T73, T81, T90 infra.
- **Задача записана** по тексту оркестратора под номером T91, свободным 2026-11-20 (правило 6 COORDINATION.md spec).
- **Выяснилось при выполнении** (клоны `api`, `app` и `tutor` во временной папке, 2026-11-20):
  - **миграции.** От v0.1.64 до v0.1.72 у `api` их пять, 0022–0026: попытки страницы с бумаги рядом с попытками модуля, ключ задачи, режим подсказок, закрытие попыток страницы и её ID; у 0001–0020 изменились только комментарии. Выкладка `release` запускает `check`, затем `migrate`, затем ревизию; в `deploy.yml` задача `app` ждёт задачу `api`, так что оба релиза идут одним прогоном, `api` раньше;
  - **время запроса.** `FindTasks` и `SubmitWork` идут до 90 с, `API_HTTP_WRITE_TIMEOUT` у `api` — 120 с (R98 api), и `app` v0.1.42 ставит этим двум вызовам срок 90 с, а Cloud Run резал запрос к `api` на 60 с (`api_request_timeout`). Без правки третья попытка модели обрывалась бы платформой;
  - **допуск.** `tutor` v0.1.59 допускает все вызовы задачи с бумаги на ступени `author`, моделями Anthropic, словом автора до 2027-01-17; ключ и факты `novatrail` прежние, нового секрета, бакета или переменной `api` не требует, `API_DEBUG_MODELS` модуль не ставит. Карточка «Задача с моей бумаги» в `app` v0.1.42 открыта всегда;
  - **тег `spec`.** `just deploy-check origin/main` проходит на v0.18.34: факты — словарь таблицы допуска, он не менялся, а release-verify принимает оба релиза. Переход на тег не нужен; `R162` `spec` записан кодом, его нет на теге.
- **Решено исполнителем** (технические мелочи, R156 spec):
  - `api_request_timeout` по умолчанию — 120 с, как `API_HTTP_WRITE_TIMEOUT` `api`: R11 и раньше держал запрос ровно по нему; R11 переписан целиком, с поправками, по R160 spec, ссылки на его поправки — на R11;
  - Д30 охватывает и записи задачи с бумаги, допущенные словом автора до того же дня; [BREACH.md](../BREACH.md), часть 1: к Anthropic уходят и фото страницы, и слова ученика о ней;
  - тело T90 — в архив E6: её Deploy, run 44322017268, зелёный.
