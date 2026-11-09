# api's service, jobs and schedule, and the identities of api and of its deployment, as R11
# decided them, checked against mock providers: no credential, no call to Google. The values are
# synthetic, the image's digest among them.

mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }

  # The provider checks the form of a service account's name where another resource names it.
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/novatrail-test-0/serviceAccounts/mock-account@novatrail-test-0.iam.gserviceaccount.com"
      email = "mock-account@novatrail-test-0.iam.gserviceaccount.com"
    }
  }
}

mock_provider "google-beta" {}

# The variables every run starts from are in tests/terraform.tfvars.


# Before the first image: no service and no jobs, nor their rights, but api's identities and the
# deployment's way in are there, so that the first deployment can push.
run "with_no_image_there_is_no_service_and_no_job" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_service.api) == 0 && length(google_cloud_run_v2_job.api) == 0
    error_message = "With no api_image, neither the service nor the jobs are made."
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0 && length(google_cloud_run_v2_service_iam_member.deployer) == 0 && length(google_cloud_run_v2_job_iam_member.deployer) == 0
    error_message = "With no service and no jobs, there are no rights on them."
  }

  assert {
    condition     = google_service_account.api.account_id == "api-run" && google_service_account.deployer.account_id == "api-deploy"
    error_message = "api's identity and the deployment's are there before the first image."
  }

  assert {
    condition     = output.api_service_url == null
    error_message = "With no service, its address is null."
  }

  assert {
    condition     = length(google_cloud_scheduler_job.api) == 0 && length(google_service_account.scheduler) == 0
    error_message = "With no jobs, there is no schedule."
  }
}

# The first image makes the jobs and not yet the service: the first deployment runs the check and
# the migrations with the jobs, and the service comes after them, on a database already migrated.
run "the_first_image_makes_the_jobs_and_not_the_service" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = toset(keys(google_cloud_run_v2_job.api)) == toset(["migrate"]) && length(google_cloud_run_v2_service.api) == 0
    error_message = "With api_image and no api_serving, the jobs are made and the service is not."
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0 && length(google_cloud_run_v2_service_iam_member.deployer) == 0 && toset(keys(google_cloud_run_v2_job_iam_member.deployer)) == toset(["migrate"])
    error_message = "With no service, nobody may call it, and the deployment's role is on the jobs alone."
  }
}

run "serving_with_no_image_is_refused" {
  command = plan

  variables {
    api_serving = true
  }

  expect_failures = [var.api_serving]
}

# The service as the deployment finds it once it is made: the image given, scaled from nothing,
# healthy by GET /health, run as api, reading the facts from the file the secret's volume holds,
# with the rung full.
run "the_service_is_made_with_the_first_image" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].name == "api" && google_cloud_run_v2_service.api[0].location == "us-east4" && google_cloud_run_v2_service.api[0].ingress == "INGRESS_TRAFFIC_ALL"
    error_message = "The service api is in the region, and the internet reaches it."
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].template[0].containers[0].image == "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    error_message = "The service is made with the image given."
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].scaling[0].min_instance_count == 0 && google_cloud_run_v2_service.api[0].scaling[0].max_instance_count == 1
    error_message = "The service scales from 0 to 1 instance."
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].template[0].containers[0].startup_probe[0].http_get[0].path == "/health"
    error_message = "An instance is ready once GET /health answers."
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].template[0].service_account == google_service_account.api.email
    error_message = "The service runs as api."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "API_ADMISSION_RUNG"]) == "full"
    error_message = "The lowest admission rung is full, the only one a deployment takes."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "API_ADMISSION_FACTS_FILE"]) == "/etc/api/admission/facts.json"
    error_message = "API_ADMISSION_FACTS_FILE names the file of the facts' volume."
  }

  assert {
    condition = (
      google_cloud_run_v2_service.api[0].template[0].volumes[0].secret[0].secret == "api-admission-facts" &&
      google_cloud_run_v2_service.api[0].template[0].volumes[0].secret[0].items[0].path == "facts.json" &&
      one([for m in google_cloud_run_v2_service.api[0].template[0].containers[0].volume_mounts : m.mount_path if m.name == google_cloud_run_v2_service.api[0].template[0].volumes[0].name]) == "/etc/api/admission"
    )
    error_message = "The facts' secret is mounted as facts.json in /etc/api/admission: the first volume, whose version the deployment sets."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "GOMEMLIMIT"]) == "921MiB"
    error_message = "1Gi of memory tells the runtime 921MiB."
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.public[0].member == "allUsers" && google_cloud_run_v2_service_iam_member.public[0].role == "roles/run.invoker"
    error_message = "Anyone may call api: its own checks decide."
  }
}

# The job migrate: its command, its two connection strings as files, run as api, never retried by
# the platform; and no schedule, since it runs with each deployment.
run "migrate_reads_its_secrets_as_files" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = toset(keys(google_cloud_run_v2_job.api)) == toset(["migrate"]) && google_cloud_run_v2_job.api["migrate"].name == "api-migrate"
    error_message = "The one job is api-migrate: the only one api's binary has."
  }

  assert {
    condition     = google_cloud_run_v2_job.api["migrate"].template[0].template[0].containers[0].args == tolist(["migrate"]) && google_cloud_run_v2_job.api["migrate"].template[0].template[0].max_retries == 0
    error_message = "api-migrate runs `api migrate`, and the platform does not run it again behind the deployment's back."
  }

  assert {
    condition = {
      for e in google_cloud_run_v2_job.api["migrate"].template[0].template[0].containers[0].env : e.name => e.value
      } == {
      API_MIGRATE_DATABASE_URL_FILE         = "/secrets/api-migrate-database-url/value"
      API_MIGRATE_OPENFGA_DATABASE_URL_FILE = "/secrets/api-migrate-openfga-database-url/value"
    }
    error_message = "migrate reads each connection string from a file, by the variable with the suffix _FILE."
  }

  assert {
    condition     = toset([for v in google_cloud_run_v2_job.api["migrate"].template[0].template[0].volumes : v.secret[0].secret]) == toset(["api-migrate-database-url", "api-migrate-openfga-database-url"])
    error_message = "Each connection string is a volume of its own secret."
  }

  assert {
    condition     = toset(keys(google_secret_manager_secret.api_job)) == toset(["api-migrate-database-url", "api-migrate-openfga-database-url"]) && alltrue([for s in google_secret_manager_secret.api_job : s.deletion_policy == "ABANDON" && [for r in s.replication[0].user_managed[0].replicas : r.location] == ["us-east4"]])
    error_message = "The secrets the jobs name are made, replicated to the region alone, and let go rather than deleted when the list stops naming them."
  }

  assert {
    condition     = google_cloud_run_v2_job.api["migrate"].template[0].template[0].service_account == google_service_account.api.email
    error_message = "The job runs as api."
  }

  assert {
    condition     = length(google_cloud_scheduler_job.api) == 0
    error_message = "migrate has no schedule: it runs with each deployment."
  }
}

# A job with a schedule gets Cloud Scheduler, and an identity of its own that may run the jobs
# that run by the clock and nothing else.
run "a_job_with_a_schedule_runs_by_the_clock" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_jobs = {
      daily = {
        args     = ["daily"]
        schedule = "15 3 * * *"
      }
    }
  }

  assert {
    condition     = length(google_service_account.scheduler) == 1 && toset(keys(google_cloud_scheduler_job.api)) == toset(["daily"])
    error_message = "The job with a schedule gets Cloud Scheduler and its identity."
  }

  assert {
    condition     = google_cloud_scheduler_job.api["daily"].schedule == "15 3 * * *" && google_cloud_scheduler_job.api["daily"].time_zone == "Etc/UTC" && google_cloud_scheduler_job.api["daily"].region == "us-east4"
    error_message = "The schedule is the job's, in UTC, in the region."
  }

  assert {
    condition     = endswith(google_cloud_scheduler_job.api["daily"].http_target[0].uri, "/v2/projects/novatrail-test-0/locations/us-east4/jobs/api-daily:run") && google_cloud_scheduler_job.api["daily"].http_target[0].http_method == "POST"
    error_message = "Cloud Scheduler runs the job through Cloud Run's API."
  }

  assert {
    condition     = google_cloud_run_v2_job_iam_member.scheduler["daily"].role == "roles/run.invoker" && google_cloud_run_v2_job_iam_member.scheduler["daily"].member == "serviceAccount:${google_service_account.scheduler[0].email}"
    error_message = "The scheduler's identity may run the job, as an invoker of it alone."
  }
}

# The deployment's way in: one GitHub environment of the repository, and the rights the steps of
# R05 need, each on its own resource.
run "the_deployment_holds_what_its_steps_need_and_no_more" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = google_service_account_iam_member.deployer_from_github.role == "roles/iam.workloadIdentityUser" && google_service_account_iam_member.deployer_from_github.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/infra-github/subject/repo:example@1000/infra@2000:environment:production"
    error_message = "Only the jobs of the environment production of the repository may borrow the deployment's identity."
  }

  # What the role holds is bootstrap.sh's, and its test holds it to the steps' rights.
  assert {
    condition     = google_cloud_run_v2_service_iam_member.deployer[0].role == "projects/novatrail-test-0/roles/apiDeployer" && toset([for m in values(google_cloud_run_v2_job_iam_member.deployer) : m.role]) == toset(["projects/novatrail-test-0/roles/apiDeployer"]) && toset(keys(google_cloud_run_v2_job_iam_member.deployer)) == toset(["migrate"])
    error_message = "The deployment's role, apiDeployer, which bootstrap.sh makes, is granted on the service and on each job, not on the project."
  }

  assert {
    condition     = google_artifact_registry_repository_iam_member.deployer.role == "roles/artifactregistry.writer"
    error_message = "The deployment may push to the repository."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.deployer_adds_facts.role == "roles/secretmanager.secretVersionAdder"
    error_message = "The deployment may add a version of the facts, and not read any secret."
  }

  assert {
    condition     = google_service_account_iam_member.deployer_runs_as_api.role == "roles/iam.serviceAccountUser"
    error_message = "The deployment may let a revision and a job run as api."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.api_reads_facts.role == "roles/secretmanager.secretAccessor" && toset(keys(google_secret_manager_secret_iam_member.api_reads_job_secrets)) == toset(["api-migrate-database-url", "api-migrate-openfga-database-url"])
    error_message = "api reads the facts and the secrets of its jobs."
  }
}

run "an_image_by_tag_is_refused" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api:v0.1.3"
  }

  expect_failures = [var.api_image]
}

run "an_image_from_another_registry_is_refused" {
  command = plan

  variables {
    api_image = "us-docker.pkg.dev/cloudrun/container/hello@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  expect_failures = [var.api_image]
}

run "a_subject_prefix_not_of_githubs_form_is_refused" {
  command = plan

  variables {
    github_oidc_subject_prefix = "repo:altnovatrail/infra"
  }

  expect_failures = [var.github_oidc_subject_prefix]
}

run "a_job_secret_not_named_by_an_api_variable_is_refused" {
  command = plan

  variables {
    api_jobs = {
      migrate = {
        args    = ["migrate"]
        secrets = { DATABASE_URL = "api-migrate-database-url" }
      }
    }
  }

  expect_failures = [var.api_jobs]
}

run "a_job_reading_the_facts_secret_is_refused" {
  command = plan

  variables {
    api_jobs = {
      check = {
        args    = ["check"]
        secrets = { API_ADMISSION_FACTS = "api-admission-facts" }
      }
    }
  }

  expect_failures = [var.api_jobs]
}

run "a_job_timeout_past_168_hours_is_refused" {
  command = plan

  variables {
    api_jobs = {
      migrate = {
        args    = ["migrate"]
        timeout = "604801s"
      }
    }
  }

  expect_failures = [var.api_jobs]
}

run "a_cpu_cloud_run_does_not_take_is_refused" {
  command = plan

  variables {
    api_cpu = "3"
  }

  expect_failures = [var.api_cpu]
}

run "four_cpus_with_less_than_2gi_are_refused" {
  command = plan

  variables {
    api_cpu    = "4"
    api_memory = "1Gi"
  }

  expect_failures = [var.api_memory]
}

run "four_cpus_with_2gi_are_taken" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_cpu     = "4"
    api_memory  = "2Gi"
  }

  assert {
    condition     = google_cloud_run_v2_service.api[0].template[0].containers[0].resources[0].limits["cpu"] == "4" && google_cloud_run_v2_service.api[0].template[0].containers[0].resources[0].limits["memory"] == "2Gi"
    error_message = "4 vCPUs with 2Gi are what the service is made with."
  }
}

run "a_request_timeout_past_an_hour_is_refused" {
  command = plan

  variables {
    api_request_timeout = "3601s"
  }

  expect_failures = [var.api_request_timeout]
}
