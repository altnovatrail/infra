# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T84. Новый релиз app на novatrail (веха эпика E5 app)

- **Цель:** на `novatrail` работает `app` релиза, который назовёт оркестратор; выкладка прошла, проверка `app` зелёная.
- **Почему:** R76 spec, R156 spec; слово автора 2026-11-17: эпик E5 app «Интерфейс по эталону» выкладывается вехами, чтобы автор видел ход работы на сайте и ловил ошибки раньше; цель эпика — интерфейс как в `draft/mockup/` spec.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `app` в `deploy/production.json` до релиза, который назовёт оркестратор (`api` — как есть, если оркестратор не назовёт новее); поправка к R29 — что пришло с релизом и чем проверено; выкладка; проверка Deploy (проверка `app` ждёт CDN, T71). Если релиз `app` требует от `api` того, чего на `novatrail` нет, — не выкладывать, вопрос оркестратору (status waiting).
- **Как проверить:** проверки репозитория зелёные; Deploy успешен.
- **Разделы:** R29 infra; T70, T73 infra.
- **Релиз, который назвал оркестратор:** `app` v0.1.37 (2026-11-18; последний релиз эпика E5 `app`: после вехи T82 — v0.1.35 — v0.1.36, T89 `app`, раздел для взрослых и подъём версий Dependabot, и v0.1.37, T90 `app`, юридические страницы и экраны сбоев; T91 `app` — итог E5, только документы, без релиза); `api` — как есть, v0.1.64. Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Выяснилось при выполнении** (клоны `app` и `api` во временной папке, 2026-11-18):
  - **`app` v0.1.36–v0.1.37** — раздел для взрослых по стилю эталона, в профиле владельца аватар меняется полем `avatar` из `ProfileSettings` контракта; версии от Dependabot — `@firebase/app` 0.16.6, `@firebase/auth` 1.13.10, `marked` 18.2.0 в сборке, Biome, Vite и его плагин React — в разработке (T89 `app`, R68 app); юридические страницы, лицензия модуля и страница о наставнике — листом юридического текста эталона, экраны сбоев — его карточкой, среди них «аккаунт удержан» и неудачное чтение аккаунта (T90 `app`, R69 app). Релизы неизменяемые, v0.1.37 опубликован 2026-11-18;
  - **что нужно от `api`.** `git diff v0.1.35 v0.1.37` не трогает `src/api/`; методы `api`, которые зовёт `src/` вне тестов, — тот же набор на обоих тегах; `UpdateProfile` с `avatar` — по контракту, и `api` v0.1.64 его принимает (ASCII, не длиннее 64 байт, `internal/account/settings.go`) в поле профиля `avatar`; `@altnovatrail/contracts` — прежний 0.18.12, `@altnovatrail/skill-map` — 0.1.12; подмодуль `spec` у `app` — тот же коммит. Значит, `api` v0.1.64 даёт всё, что зовёт `app` v0.1.37;
  - **архив.** `csp.json`, `deployment.schema.json` и `LICENSE` в архиве v0.1.37 байт в байт как у v0.1.35, `NOTICE` — только поднятые версии: заголовки Hosting и `deploy/production/deployment.json` не меняются, `font-src 'none'` прежний; `just deploy-check origin/main` прошёл.
- **Решено исполнителем** (технические мелочи, R156 spec):
  - `api` остаётся v0.1.64: оркестратор не назвал новее — v0.1.65 от 2026-11-18 несёт только переход `api` на `spec` v0.18.27 (T113 `api`), — а `app` v0.1.37 нового от него не требует; путь `release` выкладывает только `app`;
  - [BREACH.md](../BREACH.md), часть 1, не меняется: хранилищ, секретов, прав, журналов и вызовов `api` не прибавилось, аватар — поле профиля, а профили часть 1 уже называет;
  - поправка 2026-11-18 к R29, вторая; `[x]` и перенос тела в архив E6 — после мержа и зелёной проверки Deploy.
