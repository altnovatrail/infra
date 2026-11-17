# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T76. Новый релиз app на novatrail (веха эпика E5 app)

- **Цель:** на `novatrail` работает `app` релиза, который назовёт оркестратор; выкладка прошла, проверка `app` зелёная.
- **Почему:** R76 spec, R156 spec; слово автора 2026-11-17: эпик E5 app «Интерфейс по эталону» выкладывается вехами, чтобы автор видел ход работы на сайте и ловил ошибки раньше; цель эпика — интерфейс как в `draft/mockup/` spec.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `app` в `deploy/production.json` до релиза, который назовёт оркестратор (`api` — как есть, если оркестратор не назовёт новее); поправка к R29 — что пришло с релизом и чем проверено; выкладка; проверка Deploy (проверка `app` ждёт CDN, T71). Если релиз `app` требует от `api` того, чего на `novatrail` нет, — не выкладывать, вопрос оркестратору (status waiting).
- **Как проверить:** проверки репозитория зелёные; Deploy успешен.
- **Разделы:** R29 infra; T70, T73 infra.
- **Релиз, который назвал оркестратор:** `app` v0.1.23 (T92 `app`; на `novatrail` — v0.1.22); `api` — как есть, v0.1.60, если v0.1.23 не требует новее. Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Выяснилось при выполнении** (клон `app` во временной папке, 2026-11-17):
  - **`app` v0.1.23** — путь назад на «My subjects» с каждого экрана ученика, «Back to My subjects»: на «My essays» во всех его состояниях, на экране задачи, пока попытка открыта, и рядом с «Try again», когда чтение задачи или урока не ответило (T92 `app`, R57 app). Релиз неизменяемый, опубликован 2026-11-17;
  - **что нужно от `api`.** `git diff v0.1.22 v0.1.23` меняет только экраны, их тесты и документы: `package.json`, lock-файл и вызовы `api` те же, `app` — на `spec` v0.18.12, как v0.1.22. Значит, `api` v0.1.60 даёт всё, что зовёт `app` v0.1.23 (T75).
- **Решено исполнителем** (технические мелочи, R156 spec):
  - `api` остаётся v0.1.60: оркестратор не назвал новее, а `app` v0.1.23 нового от него не требует; путь `release` выкладывает только `app`;
  - [BREACH.md](../BREACH.md), часть 1, не меняется: хранилищ, секретов, прав, журналов и вызовов `api` не прибавилось;
  - после мержа, выкладки и проверки Deploy тело уходит в архив E6 следующим pull request, как у T75.
