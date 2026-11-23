# TASKS.md — tasks outside an epic of `infra`

Open tasks outside the current epic, each as its body, in Russian (R154 spec, R155 spec).

- Never read whole: a session reads only its own task — `grep -n '^#### T' run/TASKS.md` lists them, `awk '/^#### T01\./{p=1;print;next} /^#### /{p=0} p' run/TASKS.md` gives one body.
- A new task outside an epic goes here as a body, its number the one free when it is written down (RUN.md, Citations): a new release of `api` or `app` by the list among them (R29). When done, the body leaves for the archive (RUN.md rule 9).

## Tasks outside an epic

#### T102. Ссылки по R171 spec: журнал решений, разделы «The operator's bucket» — конец, и ключ `"citations"`

- **Цель:** записи разделов `##` `docs/decisions.md` от «The operator's bucket» до конца — без датированных поправок и со ссылками по R171 spec; `docs-budgets.json` — `"citations": true`, и `docs-check-repo` с ним зелёный.
- **Почему:** последняя часть T95 по шагу 9 её тела: ключ включает она.
- **Кто:** Claude. **План:** —. **Зависит от:** T95–T101.
- **Сделать:** как T98, для этих разделов; затем ключ — как в `spec/repo-template/files/docs-budgets.json` — и то, что он ещё найдёт по всему репозиторию; строка 7.49 COORDINATION.md spec ждёт этой задачи.
- **Как проверить:** `docs-check-repo` с ключом — зелёный; `/code-review high`, один круг; в отчёте — ссылок было и стало, по видам, по всему репозиторию: замер «до» — в T95, коммит 015d936.
- **Разделы:** как у T95.
