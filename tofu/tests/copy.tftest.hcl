# A self-hosted copy: the same configuration on a copy's own values — another project, a region
# outside the US, another currency, another repository and pool, its own GitHub environments, and no
# eval — checked against mock providers: no credential, no call to Google. Nothing of the
# platform's own deployment may reach it: not the name novatrail, not the region us-east4 (T29;
# docs/architecture.md, section 3.5).

mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "987654321098"
    }
  }

  # The provider checks the form of a service account's name where another resource names it.
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/acme-learning-1/serviceAccounts/mock-account@acme-learning-1.iam.gserviceaccount.com"
      email = "mock-account@acme-learning-1.iam.gserviceaccount.com"
    }
  }
}

mock_provider "google-beta" {
  mock_data "google_firebase_web_app_config" {
    defaults = {
      api_key     = "synthetic-browser-key"
      auth_domain = "acme-learning-1.firebaseapp.com"
    }
  }
}

# Every run takes the copy's values over tests/terraform.tfvars.
variables {
  project_id                 = "acme-learning-1"
  region                     = "europe-west3"
  billing_account            = "0A1B2C-3D4E5F-6A7B8C"
  budget_amount              = "20"
  budget_currency            = "EUR"
  workload_identity_pool_id  = "acme-ci"
  github_oidc_subject_prefix = "repo:acme@555/platform@777"
  deploy_environment         = "acme-api"
  hosting_environment        = "acme-site"
  operator_email             = "operator@example.org"
  api_serving                = true
  api_image                  = "europe-west3-docker.pkg.dev/acme-learning-1/images/api@sha256:2222222222222222222222222222222222222222222222222222222222222222"
}

run "a_copy_keeps_everything_regional_in_its_region" {
  command = apply

  assert {
    condition     = google_artifact_registry_repository.images.location == "europe-west3" && google_logging_project_bucket_config.logs.location == "europe-west3" && google_observability_project_settings.traces.default_storage_location == "europe-west3"
    error_message = "The registry, the bucket of logs and the place of traces are in the copy's region."
  }

  assert {
    condition = alltrue([for s in concat([google_secret_manager_secret.admission_facts], values(google_secret_manager_secret.api_job), values(google_secret_manager_secret.api_service)) :
      s.replication[0].user_managed[0].replicas[0].location == "europe-west3"
    ])
    error_message = "Every secret is replicated to the copy's region alone."
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].location == "europe-west3" && alltrue([for j in values(google_cloud_run_v2_job.api) : j.location == "europe-west3"])
    error_message = "api's service and jobs run in the copy's region."
  }

  assert {
    condition     = google_billing_budget.spend.amount[0].specified_amount[0].currency_code == "EUR"
    error_message = "The budget is in the copy's currency."
  }
}

run "a_copy_signs_in_and_publishes_under_its_own_names" {
  command = apply

  assert {
    condition     = google_firebase_hosting_site.app.site_id == "acme-learning-1" && toset(google_identity_platform_config.this.authorized_domains) == toset(["acme-learning-1.firebaseapp.com", "acme-learning-1.web.app"])
    error_message = "The copy's site is named after its project, and its sign-in admits its own two domains alone."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "API_APP_ORIGIN"]) == "https://acme-learning-1.web.app"
    error_message = "The copy's api answers CORS for the copy's own site."
  }

  assert {
    condition     = output.api_origin == "https://api-987654321098.europe-west3.run.app"
    error_message = "The copy's api is at its own deterministic address, in its own region."
  }

  assert {
    condition     = output.project_id == "acme-learning-1" && output.region == "europe-west3" && output.hosting_site == "acme-learning-1" && output.app_sign_in.projectId == "acme-learning-1"
    error_message = "The outputs a deployment reads name the copy's project, region and site. The addresses the provider computes from them are not checked here: mock providers make them up."
  }
}

run "a_copy_lends_its_identities_to_its_own_repository_and_environments" {
  command = apply

  assert {
    condition     = google_service_account_iam_member.deployer_from_github.member == "principal://iam.googleapis.com/projects/987654321098/locations/global/workloadIdentityPools/acme-ci/subject/repo:acme@555/platform@777:environment:acme-api"
    error_message = "api's deployment is lent to the jobs of the copy's own environment, through its own pool, of its own repository."
  }

  assert {
    condition     = google_service_account_iam_member.hosting_from_github.member == "principal://iam.googleapis.com/projects/987654321098/locations/global/workloadIdentityPools/acme-ci/subject/repo:acme@555/platform@777:environment:acme-site"
    error_message = "The publisher is lent to the jobs of the copy's own environment."
  }

  assert {
    condition     = length(google_secret_manager_secret.eval) == 0 && output.eval_access == null
    error_message = "A copy that names no repository of eval has no eval."
  }
}

# Nothing of the platform's own deployment reaches the copy: its name, its region, its pool and its
# numbers appear in no resource the configuration makes, and in none of its outputs.
run "nothing_of_the_platform_reaches_a_copy" {
  command = apply

  assert {
    condition = alltrue([for text in [
      jsonencode(google_artifact_registry_repository.images),
      jsonencode(google_logging_project_bucket_config.logs),
      jsonencode(google_logging_project_sink.sinks),
      jsonencode(google_observability_project_settings.traces),
      jsonencode(google_secret_manager_secret.admission_facts),
      jsonencode(google_secret_manager_secret.api_job),
      jsonencode(google_secret_manager_secret.api_service),
      jsonencode(google_cloud_run_v2_service.api),
      jsonencode(google_cloud_run_v2_job.api),
      jsonencode(google_cloud_scheduler_job.api),
      jsonencode(google_firebase_hosting_site.app),
      jsonencode(google_identity_platform_config.this),
      jsonencode(google_service_account_iam_member.deployer_from_github),
      jsonencode(google_service_account_iam_member.hosting_from_github),
      jsonencode(google_project_iam_member.grants),
      jsonencode(google_billing_budget.spend),
      jsonencode(google_monitoring_alert_policy.api),
      jsonencode(google_monitoring_alert_policy.api_jobs),
      jsonencode(google_monitoring_notification_channel.operator),
      jsonencode(google_project_service.enabled),
      jsonencode(google_firebase_project.this),
      jsonencode(google_firebase_web_app.app),
      jsonencode(google_service_account.api),
      jsonencode(google_service_account.deployer),
      jsonencode(google_service_account.hosting),
      jsonencode(google_service_account.scheduler),
      jsonencode(google_artifact_registry_repository_iam_member.deployer),
      jsonencode(google_secret_manager_secret_iam_member.api_reads_facts),
      jsonencode(google_secret_manager_secret_iam_member.api_reads_job_secrets),
      jsonencode(google_secret_manager_secret_iam_member.api_reads_service_secrets),
      jsonencode(google_secret_manager_secret_iam_member.deployer_adds_facts),
      jsonencode(google_cloud_run_v2_service_iam_member.deployer),
      jsonencode(google_cloud_run_v2_service_iam_member.public),
      jsonencode(google_cloud_run_v2_job_iam_member.deployer),
      jsonencode(google_cloud_run_v2_job_iam_member.scheduler),
      jsonencode(google_service_account_iam_member.deployer_runs_as_api),
      jsonencode(google_secret_manager_secret.eval),
      jsonencode(google_secret_manager_secret_iam_member.eval_reads),
      jsonencode([output.project_id, output.region, output.hosting_site, output.hosting_url, output.app_sign_in, output.api_jobs, output.api_service_name, output.api_service_url, output.api_service_account, output.deploy_service_account, output.hosting_service_account, output.image_repository, output.log_bucket, output.admission_facts_secret, output.admission_facts_file, output.deploy_environment, output.hosting_environment, output.eval_access, output.api_origin]),
      ] : alltrue([for platform in ["novatrail", "us-east4", "344507087", "altnovatrail", "1425816333", "infra-github"] : !strcontains(text, platform)])
    ])
    error_message = "A resource of the copy carries the platform's name, region or numbers."
  }
}
