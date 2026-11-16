# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T64. Скорость CI: строка 7.25

- **Цель:** CI `infra` быстрее по строке 7.25 COORDINATION.md spec; что проверки доказывают, не меняется.
- **Кто:** Claude. **План:** —.
- **Почему:** R76 spec, R156 spec, строка 7.25 COORDINATION.md spec и шестая поправка 2026-11-15 к R76 spec; замеры — measurements 3.1 spec; общая часть — строки 7.13 (`.github`) и 7.14 (T166 spec). Слово автора 2026-11-16: ускорение CI — сейчас, в прогоне оркестратора T171 spec.
- **Что нужно** (строка 7.25): `tofu/tests/bootstrap.test.mjs` — асинхронный `spawn` и `concurrency: 4`, или файл на четыре и `--test-concurrency=4`; job Deploy — образ из кеша, `deploy-check-release-test` — параллельно остальным; переход на `.github` строки 7.13
- **Зависит от** (строка 7.25): 7.13 — для образа; тесты — нет
- **Сделать:**
  1. Сейчас — всё из «Что нужно», что не ждёт ни релиза `.github` строки 7.13, ни тега `spec` строки 7.14, ни другой строки.
  2. То, что их ждёт, — следующей задачей (или задачами) этого плана, записанной по его правилам и названной в отчёте: оркестратор запустит её, когда релиз выйдет. Переход на тег `spec` со стадией `toolchain-core` меняет `.devcontainer/` — его делает последняя из них.
  3. `.devcontainer/` в этой задаче не меняй: пересобрать контейнер ночью некому.
  4. Если сейчас делать нечего — запиши задачу с её частью, что ждёт, и верни done без pull request.
- **Как проверить:** проверки тронутых частей по правилам этого репозитория; CI pull request зелёный; время изменённых job до и после — в отчёте, по прогонам `main` и этого pull request; `/code-review high`, один круг.
- **Разделы:** строка 7.25 COORDINATION.md spec; measurements 3.1 spec; R76 spec, R156 spec.
