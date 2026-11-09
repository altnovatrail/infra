# The platform's values of the configuration, which bootstrap.sh reads too (R10, R13). None is a
# secret: the billing account and the operator's address arrive from the environment, as
# TF_VAR_billing_account and TF_VAR_operator_email.

project_id = "novatrail"
region     = "us-east4"

# An alert, not a cap: nothing stops the project at this number (R07).
budget_amount   = "5"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:altnovatrail@344507087/infra@1425816333"

# modules and tutor, whose jobs of the environment eval read the keys for eval (R120 spec; R20).
# One line, which bootstrap.sh reads; a change of it is a run of bootstrap.sh before the merge.
eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415", "repo:altnovatrail@344507087/tutor@1425813274"]
