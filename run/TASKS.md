# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T109. `sources` по правилу записей `spec` v0.19.20, часть 2: код и документация на версии, поведение под проверкой, повторные чтения

- **Цель:** вторая часть пересмотра `docs/sources.md` по правилу записей `spec/RULES.md` v0.19.20 (строка 7.73 COORDINATION.md `spec`, текст T291 `spec`): после неё запись есть только у того, что прогон не проверит или у чего нет версии. Первая часть — T108: переход на тег, вводные и записи о тегах `spec` и файлах репозиториев NovaTrail и MathTrail.
- **Почему отдельно:** правило 11 — весь пересмотр больше одного ревью (≈ 300 ссылок на ≈ 90 записей); и `tools/deploy-check/check.mjs` (две ссылки на sources 4.5) лежит в путях Deploy, а T108 шла, пока параллельно шла выкладка другой задачи.
- **Сделать:**
  - свернуть повторные чтения до текущего (1.1, 2.1, 2.3, 2.6, 4.5, 5.2, 5.7, 10.7 и другие с «read again»): тот же текст — дата записи, другой — утверждения переписать;
  - код и документация программ на версии или коммите — ссылка у утверждения, пункт записи удалить: terraform-provider-google и -beta v8.10.0 (2.2, 2.6, 3.6, 3.13, 4.5, 4.7, 5.7 — там `main`, закрепить коммит), документация и CHANGELOG OpenTofu и Terraform на тегах и dependabot-core (5.2), `actions/*` на коммитах и github/docs (5.8, 5.9 — github/docs на `main`, закрепить коммит), `setup-gcloud` (5.5), python-storage и код Google Cloud CLI 593.0.0 (10.8), исходники страниц Neon (3.16, если закрепить коммит); лицензии остаются записями, но не те, что проверяет `just ci-licenses`;
  - поведение, которое проверяет наш прогон, — ссылка на тест или запись `measurements`, пункт записи удалить: схема провайдеров (`tofu providers schema -json`, `tofu validate`: 3.6, 4.6, 5.4, 7.3), суммы архивов, которые держат `ARG` Dockerfile и `tools/ci/versions.env` (5.2, 5.3, 5.5), ответы GitHub API о субъектах OIDC (5.3, 5.5, 5.6), абзацы «the project showed» (3.14, 10.1, 10.2, 10.3, 10.7, 10.8, 10.9) — в `docs/measurements.md`, раздел 3, как 3.1 из T108;
  - 4.5: пункт `app` `main` 375a09b и релиз `firebase-tools` — ссылки у утверждений, и в `tools/deploy-check/check.mjs` тоже;
  - номера не переиспользовать, архивы `docs/plan/` не трогать, смысл утверждений не менять; ссылки на записи `spec` сверить с тегом, на котором будет репозиторий.
- **Не делать:** выкладку и `deploy/`; `tools/deploy-check/` — только комментарии со ссылками, когда параллельной выкладки нет: правка запускает Deploy после мержа.
- **Как проверить:** `just -f spec/justfile docs-check-repo`; `just deploy-check-test` и `just organizer-test`, если задеты комментарии `tools/`; размер `docs/sources.md` до и после — в отчёт.
- **Разделы:** `spec/RULES.md`, «The bar» и «Citations»; R171 `spec`; строка 7.73 «Порядка» `spec`; T108.
