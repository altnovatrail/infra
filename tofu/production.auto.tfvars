# The platform's values of the configuration, which bootstrap.sh reads too. None is a
# secret: the billing account and the operator's address arrive from the environment, as
# TF_VAR_billing_account and TF_VAR_operator_email.

project_id = "novatrail"
region     = "us-east4"

# An alert, not a cap: nothing stops the project at this number.
budget_amount   = "5"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:altnovatrail@344507087/infra@1425816333"

# modules and tutor, whose jobs of the environment eval read the keys for eval.
# One line, which bootstrap.sh reads; a change of it is a run of bootstrap.sh before the merge.
eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415", "repo:altnovatrail@344507087/tutor@1425813274"]

# The operator's bucket and the bucket of the scans of consents, which bootstrap.sh makes and keeps,
# with all their access. A change of either is a run of bootstrap.sh before the merge.
operator_bucket      = "novatrail-operator"
consent_forms_bucket = "novatrail-consent-forms"

# The image the jobs are made with; which image they run after that is the deployment's.
api_image = "us-east4-docker.pkg.dev/novatrail/images/api@sha256:e3430c99f7069a853768f23222bebc6cd6cecb55caa9db58d7272f5ee46352b2"

# The service of api, made only once its jobs have run the check of the configuration and the
# migrations.
api_serving = true

# Platform AI: the rung, which the rung of deploy/production.json must equal, the catalog api lays,
# and the version of api-anthropic-key the operator added by hand.
api_admission_rung        = "author"
api_catalog_modules       = ["novatrail/olympiad-math", "novatrail/check-board", "novatrail/english-essays"]
api_anthropic_key_version = "1"

# Handwriting read by one model, not by the pair of readers.
api_reading_mode = "single"
