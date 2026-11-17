# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T77. english-essays — снова в каталоге novatrail

- **Цель:** каталог `novatrail` — olympiad-math, check-board и english-essays (версия без фразы об именах, которую назовёт оркестратор); выкладка прошла.
- **Почему:** разбор «в реестр spec» 2026-11-17, строка `infra` В51 — ответ автора: вернуть эссе; поправка к R150 spec (её запишет задача spec). Слово автора 2026-11-17 допускает чтение и оценку эссе на ступени «author» только на работе автора, до 2027-01-17. R76 spec, R156 spec.
- **Кто:** Claude; мерж — оркестратор (R156 spec). **План:** —.
- **Сделать:** `english-essays` в `api_catalog_modules` путём «facts only» (поправка 2026-11-16 к R05); поправка к R29 или к записи каталога — что пришло; выкладка и проверка Deploy; [SELF-HOSTING.md](../SELF-HOSTING.md) — граница слова для копий по ответу автора на В52 (слово действует только на `novatrail`; копия, где на «author» учится не только её оператор, называет `api` ниже v0.1.60 или ступень full; после 2027-01-17 — только `tutor` с допуском по eval); строки В51, В52 — по их правилам, с ответами автора.
- **Как проверить:** `just deploy-check`; проверки репозитория; Deploy успешен.
- **Разделы:** R05, R29; В51, В52; R150, R07 spec; Д152 spec.
- **Версия, которую назвал оркестратор:** `novatrail/english-essays` 0.2.1, без фразы об именах, в релизе `modules` v0.2.12 (2026-11-17, PR #117 `modules`, коммит b8e185f). Разбор записан в `spec` PR #177 (575214f, `spec` v0.18.16). Задача записана по тексту оркестратора (правило 6 COORDINATION.md spec).
- **Решено автором (2026-11-17, разбор «в реестр spec», T188 spec):**
  - **В51** — (a): эссе возвращаются в каталог `novatrail` «после версии english-essays без фразы об именах (Д152)» — поправка 2026-11-17 к R150 spec, строка «Порядка» 6.36;
  - **В52** — (a): слово автора действует только на `novatrail`; копия, где на ступени «author» учится не только её оператор, называет `api` ниже v0.1.60 или ступень `full`; после 2027-01-17 любое развёртывание называет только `api`, чей `tutor` допускает эти записи по eval, или не допускает их, — пятая поправка 2026-11-17 к R07 spec.
- **Выяснилось при выполнении** (клоны `api`, `modules` и `spec` во временной папке, 2026-11-17):
  - **откуда версия модуля.** Список не называет пакетов модулей: их кладёт в образ бинарь `api` командой `packages` по `modules.json`, который в нём зашит (R05; R41 api). У `api` v0.1.60 и v0.1.61, последнего релиза, `modules.json` — `modules` v0.2.7, индекс `sha256:6c46a1a9…083a`, где у `english-essays` версии 0.1.0 и 0.2.0: каталог `novatrail` отдал бы 0.2.0, с «Do not write your name or the real name of anyone you know.» в пяти заданиях. `infra` не подменит индекс: образ — бинарь релиза и его `Dockerfile` (R105 spec), а бинарь кладёт и читает только пакеты индекса, который закрепил его `modules.json`;
  - **индекс v0.2.12.** `release-verify modules v0.2.12 module-index.json` — «modules v0.2.12, signed by the shared release.yml of .github v0.1.31», sha256 `cb16bb45…d71a`; в нём `novatrail/english-essays` 0.2.1, пакет `sha256:5975e7c5…9fb5` (R40 modules). На `novatrail` он придёт только с релизом `api`, чей `modules.json` закрепит этот индекс, — строка «Порядка» 6.38, и его выкладкой — строка 6.39;
  - **срок каталога** — вопрос В54: ответ автора на В51 ставит эссе в каталог «после версии без фразы», а с `api` v0.1.60 на сайт пришла бы 0.2.0.
- **Ход работы (2026-11-17):**
  - [SELF-HOSTING.md](../SELF-HOSTING.md), «Your list», — граница слова для копий по ответу на В52; строки В51 и В52 ушли из таблицы 3, ответы — выше;
  - каталог не тронут: ждёт ответа на В54.
