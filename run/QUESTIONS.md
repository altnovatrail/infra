# QUESTIONS.md — questions to the author of `infra`

Table 3 of [RUN.md](../RUN.md): the author's open questions from tasks' «Открыто» (R153 spec, R154 spec).

- Never read whole: take the rows the task and its sections name — `grep -n '^| В37 ' run/QUESTIONS.md` — and those `grep -n` finds by the paths and parts it changes (RUN.md rule 2).
- A row comes from a task's «Открыто» (RUN.md rule 9). Record the author's answer where it belongs — the task, a document or [DEBT.md](DEBT.md) — and delete the row.
- A row whose question opens with the mark «В реестр spec» is for `spec`: its session finds it on `main` (R81 spec; RULES.md, Across repositories). It leaves once `spec` has recorded it: the task that rests on it names its number.
- «В…» of table 3 of RUN.md before T62 is this table, the same register (R31).

## Table 3. Questions to the author

Numbers are not reused: next — В38.

| ID | Question | From | Options | Recommendation |
|---|---|---|---|---|
| В37 | How a self-hosted copy's folder of legal texts reaches its `api` revision and jobs (Д12; T67 of [TASKS.md](TASKS.md)). `api` reads the folder named by `API_LEGAL_DIR` at its start and does not start if it breaks the part's rules; the platform has no folder. A Secret Manager volume, as for the facts (R05), does not fit: a version holds at most 64 KiB and one secret takes one mount path, while the part `legal/` of `spec` alone is 25 files, 384 KB (sources 3.15). No document says what may go into the image beyond the binary but "what the repository's own decisions put there" (R105 spec) | T67 | (a) a layer over the release's image: the folder in the copy's `deploy/`, checked in the pull request by `legal-check-dir`; the deployment builds `FROM` the release's image by digest with the folder copied in at a fixed path, under a tag of the release and the folder's sha256, and rolls the revision and the jobs by its digest; a change of the texts alone is a path like "facts only". No new resource; the texts are public anyway. Cost: the copy's image holds its operator's texts, a second image per release; (b) a Cloud Storage volume, read-only: the deployment uploads the folder under a prefix named by its sha256 into a bucket of the copy and mounts it. Cost: a bucket and its rights in the module, the second-generation environment, a mount that fails the start after 30 s, a file system not fully POSIX; (c) not now: Д12 waits for the first copy with texts of its own, as its «When to return» says | (a): the texts are pinned by a digest as the binary is, reviewed in the pull request, and need no resource or right in the cloud; the platform's image does not change |
