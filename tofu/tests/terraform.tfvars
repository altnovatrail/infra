# The values every test file starts from, synthetic: tofu test reads this file for each of them.
# A run that needs another value sets it in its own variables block.

project_id = "novatrail-test-0"
region     = "us-east4"

billing_account = "0A1B2C-3D4E5F-6A7B8C"
budget_amount   = "10"
budget_currency = "USD"

workload_identity_pool_id  = "infra-github"
github_oidc_subject_prefix = "repo:example@1000/infra@2000"
