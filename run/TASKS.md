# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T90. Новый релиз app на novatrail (иконки 6.41 и тексты E16)

- **Цель:** на `novatrail` работает `app` релиза, который назовёт оркестратор; выкладка прошла, проверка `app` зелёная.
- **Почему:** R76 spec, R156 spec; слово автора 2026-11-18: выложить новый релиз `app` сразу, как возможно — иконки строки 6.41 COORDINATION.md spec (app#101) и правки эпика E16 `app`.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** поднять `app` в `deploy/production.json` до релиза, который назовёт оркестратор (`api` — как есть); что пришло с релизом и чем проверено — в коммите и описании pull request, решения не дополнять хроникой (R160 spec); выкладка; проверка Deploy (проверка `app` ждёт CDN, T71). Если релиз `app` требует от `api` того, чего на `novatrail` нет, — не выкладывать, вопрос оркестратору (status waiting).
- **Как проверить:** проверки репозитория зелёные; Deploy успешен.
- **Разделы:** R29 infra; T70, T73 infra.
- **Релиз, который назвал оркестратор:** `app` v0.1.40 (иконки 6.41 и E16 `app`); `api` — как есть, v0.1.64. Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Решено исполнителем** (технические мелочи, R156 spec): `api` остаётся v0.1.64 — `app` v0.1.40 нового от него не требует (что пришло с релизом и чем проверено — pull request #126); [BREACH.md](../BREACH.md), часть 1, не меняется; `[x]` и перенос тела T90 в архив — после мержа и зелёной проверки Deploy.
