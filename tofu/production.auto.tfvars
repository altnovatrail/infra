# The platform's values of the configuration, which bootstrap.sh reads too (R10, R13). None is a
# secret: the billing account and the operator's address arrive from the environment, as
# TF_VAR_billing_account and TF_VAR_operator_email.

project_id = "novatrail"
region     = "us-east4"

# An alert, not a cap: nothing stops the project at this number (R06).
budget_amount   = "5"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:altnovatrail@344507087/infra@1425816333"

# modules and tutor, whose jobs of the environment eval read the keys for eval (R120 spec; R20).
# One line, which bootstrap.sh reads; a change of it is a run of bootstrap.sh before the merge.
eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415", "repo:altnovatrail@344507087/tutor@1425813274"]

# The operator's bucket and the bucket of the scans of consents, which bootstrap.sh makes and keeps,
# with all their access (R28). A change of either is a run of bootstrap.sh before the merge.
operator_bucket      = "novatrail-operator"
consent_forms_bucket = "novatrail-consent-forms"

# The first image of api, v0.1.22, which the first deployment pushed (run 43164987259): the jobs are
# made with it. From now on the deployment owns which image they run (R11).
api_image = "us-east4-docker.pkg.dev/novatrail/images/api@sha256:e3430c99f7069a853768f23222bebc6cd6cecb55caa9db58d7272f5ee46352b2"

# The service of api, once the jobs ran the check of the configuration and the migrations with the
# first image (run 43264054707). The run of this merge ships app too (R05).
api_serving = true

# Platform AI for the author, and from 2026-11-28 for the other adults (R149, R150 spec; the 2026-11-16
# and 2026-11-17 amendments to R25): the rung author, which deploy/production.json names too, the
# catalog without "Short essays in English", and the platform's key of Anthropic, version 1 of
# api-anthropic-key, which the operator added (T69; Д28).
api_admission_rung        = "author"
api_catalog_modules       = ["novatrail/olympiad-math", "novatrail/check-board"]
api_anthropic_key_version = "1"

# Handwriting read by Claude Haiku 5.5 at medium alone, not by the pair of R68 spec: the author's
# word of 2026-11-17 (the 2026-11-17 amendment to R68 spec; R88 api;
# the second 2026-11-17 amendment to R25; T72).
api_reading_mode = "single"
