# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T75. Новый релиз app на novatrail (веха эпика E5 app)

- **Цель:** на `novatrail` работает `app` релиза, который назовёт оркестратор; выкладка прошла, проверка `app` зелёная.
- **Почему:** R76 spec, R156 spec; слово автора 2026-11-17: эпик E5 app «Интерфейс по эталону» выкладывается вехами, чтобы автор видел ход работы на сайте и ловил ошибки раньше; цель эпика — интерфейс как в `draft/mockup/` spec.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `app` в `deploy/production.json` до релиза, который назовёт оркестратор (`api` — как есть, если оркестратор не назовёт новее); поправка к R29 — что пришло с релизом и чем проверено; выкладка; проверка Deploy (проверка `app` ждёт CDN, T71). Если релиз `app` требует от `api` того, чего на `novatrail` нет, — не выкладывать, вопрос оркестратору (status waiting).
- **Как проверить:** проверки репозитория зелёные; Deploy успешен.
- **Разделы:** R29 infra; T70, T73 infra.
- **Релиз, который назвал оркестратор:** `app` v0.1.22 (T88 `app`; на `novatrail` — v0.1.19); `api` — как есть, v0.1.60, если v0.1.22 не требует новее. Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Выяснилось при выполнении** (клоны `app`, `api` и `spec` во временной папке, 2026-11-17):
  - **`app` v0.1.20–v0.1.22** — переход на `spec` v0.18.12 (T72 `app`, R55 app): `@altnovatrail/contracts` 0.18.12 вместо 0.18.6; поправка уровня модуля взрослым — «Easier» и «Harder» на карте модуля, `SetModuleLevel` (T73 `app`, R56 app); слова наставника — только при открытой панели: при закрытой «Check» кончается вердиктом, без `GetRungWords` и `GetCorrectAnswerWords`, а открытие панели один раз просит слова последней отправки (T88 `app`; вторая поправка 2026-11-17 к R148 spec, поправка 2026-11-17 к R97 spec); README (T74 `app`); план эпика E5 `app` (T75 `app`). Релиз неизменяемый, опубликован 2026-11-17;
  - **что нужно от `api`.** `SetModuleLevel` `api` отдаёт с v0.1.59 (T105 `api`). Слова последней отправки без окна времени — поведение `praisable` в `internal/learning/hints.go` `api` на `main` ea510b7 (поправка 2026-11-17 к R97 spec): коммит ea510b7 — предок v0.1.60, и файл в них одинаков. `.proto` `spec` v0.18.9, на котором `api` v0.1.60, и v0.18.12 одинаковы: `git diff v0.18.9 v0.18.12 -- contracts` меняет только `contracts/README.md`. Значит, `api` v0.1.60 даёт всё, что зовёт `app` v0.1.22;
  - **`spec`.** `deployment/` и `admission/` на v0.18.6, где стоит `infra`, и на v0.18.12 одинаковы (`git diff --stat` пуст), так что проверка списка по подмодулю держит релиз.
- **Решено исполнителем** (технические мелочи, R156 spec):
  - `api` остаётся v0.1.60: оркестратор не назвал новее, а `app` v0.1.22 нового от него не требует; путь `release` выкладывает только `app`;
  - [BREACH.md](../BREACH.md), часть 1, не меняется: хранилищ, секретов, прав и журналов не прибавилось, а работа уходит к ИИ за словами наставника реже — только при открытой панели;
  - после мержа, выкладки и проверки Deploy тело уходит в архив E6 следующим pull request, как у T73: строки статуса у задачи вне эпика нет.
