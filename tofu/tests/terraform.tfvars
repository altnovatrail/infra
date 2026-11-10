# The values every test file starts from, synthetic: tofu test reads this file for each of them.
# A run that needs another value sets it in its own variables block.

project_id = "novatrail-test-0"
region     = "us-east4"

billing_account = "0A1B2C-3D4E5F-6A7B8C"
budget_amount   = "10"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:example@1000/infra@2000"

# Every variable of the configuration is set here, the ones with a default to that default:
# tofu test reads tofu/production.auto.tfvars as well, and this file wins, so no test stands on
# what a deployment writes there — the platform's values, a copy's, or a later api_image or
# environment (T30). tf-check refuses a variable this file does not set.
eval_github_subject_prefixes = []
log_retention_days           = 30
api_service_name             = "api"
keep_images                  = 5
image_max_age                = "30d"
operator_email               = ""
load_alert_per_minute        = 300
error_alert_per_minute       = 1
api_serving                  = false
api_image                    = null
api_max_instances            = 1
api_concurrency              = 40
api_cpu                      = "1"
api_memory                   = "1Gi"
api_request_timeout          = "60s"
deploy_environment           = "production"
hosting_environment          = "production-hosting"
eval_providers               = ["anthropic", "openai"]
api_jobs = {
  migrate = {
    args   = ["migrate"]
    deploy = "migrate"
    secrets = {
      API_MIGRATE_DATABASE_URL         = "api-migrate-database-url"
      API_MIGRATE_OPENFGA_DATABASE_URL = "api-migrate-openfga-database-url"
    }
  }
  sweep = {
    args     = ["sweep"]
    schedule = "0 9 * * *"
    timeout  = "900s"
    secrets = {
      API_DATABASE_URL         = "api-database-url"
      API_OPENFGA_DATABASE_URL = "api-openfga-database-url"
    }
  }
}
