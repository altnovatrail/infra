# The values every test file starts from, synthetic: tofu test reads this file for each of them.
# A run that needs another value sets it in its own variables block.

project_id = "novatrail-test-0"
region     = "us-east4"

billing_account = "0A1B2C-3D4E5F-6A7B8C"
budget_amount   = "10"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:example@1000/infra@2000"

operator_bucket      = "novatrail-test-0-operator"
consent_forms_bucket = "novatrail-test-0-consent-forms"

# Every variable of the configuration is set here: tofu test reads tofu/production.auto.tfvars as
# well, and this file wins, so no test stands on what a deployment writes there — the platform's
# values, a copy's, or a later api_image or environment (T30). The ones with a default are null, and
# a variable that may not be null takes its default for a null, so the tests read the default itself
# and not a copy of it (Д19). In a run's assertion var.<name> is still the null of this file: read
# what the module made of it instead. tf-check refuses a variable this file does not set, and one
# with a default it sets to anything but null.
eval_github_subject_prefixes = null
log_retention_days           = null
api_service_name             = null
keep_images                  = null
image_max_age                = null
operator_email               = null
load_alert_per_minute        = null
error_alert_per_minute       = null
api_serving                  = null
api_image                    = null
api_max_instances            = null
api_concurrency              = null
api_cpu                      = null
api_memory                   = null
api_request_timeout          = null
deploy_environment           = null
hosting_environment          = null
eval_providers               = null
api_jobs                     = null
