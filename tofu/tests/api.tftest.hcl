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
    condition     = output.api_origin == "https://api-123456789012.us-east4.run.app"
    error_message = "api's deterministic address, which /deployment.json names, is known before the service: the service's name, the project's number and the region."
  }

  assert {
    condition     = length(google_cloud_scheduler_job.api) == 0 && length(google_service_account.scheduler) == 0
    error_message = "With no jobs, there is no schedule."
  }

  assert {
    condition     = toset(keys(google_secret_manager_secret.api_service)) == toset(["api-database-url", "api-openfga-database-url"]) && alltrue([for s in google_secret_manager_secret.api_service : s.deletion_protection == true && [for r in s.replication[0].user_managed[0].replicas : r.location] == ["us-east4"]])
    error_message = "The service's secrets, the pooler's connection strings, are there before any service, so that their values can be put first; replicated to the region alone, and never deleted by the configuration."
  }

  assert {
    condition     = toset([for m in google_secret_manager_secret_iam_member.api_reads_service_secrets : "${m.secret_id} ${m.role} ${m.member}"]) == toset([for id in ["api-database-url", "api-openfga-database-url"] : "${google_secret_manager_secret.api_service[id].id} roles/secretmanager.secretAccessor serviceAccount:${google_service_account.api.email}"])
    error_message = "api reads the service's two secrets, each by a grant on that secret alone."
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
    condition     = toset(keys(google_cloud_run_v2_job.api)) == toset(["after", "check", "migrate", "sweep"]) && length(google_cloud_run_v2_service.api) == 0
    error_message = "With api_image and no api_serving, the jobs are made and the service is not."
  }

  assert {
    condition     = length(google_cloud_run_v2_service_iam_member.public) == 0 && length(google_cloud_run_v2_service_iam_member.deployer) == 0 && toset(keys(google_cloud_run_v2_job_iam_member.deployer)) == toset(["after", "check", "migrate", "sweep"])
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
    condition = (
      google_cloud_run_v2_service.api[0].template[0].containers[0].name == "api" &&
      alltrue([for job in google_cloud_run_v2_job.api : job.template[0].template[0].containers[0].name == "api"])
    )
    error_message = "The container of the service and of every job is named api: gcloud's --update-secrets sets the facts' version in the volume of a named container only, and in an unnamed one makes a volume of its own (T24)."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "GOMEMLIMIT"]) == "921MiB"
    error_message = "1Gi of memory tells the runtime 921MiB."
  }

  assert {
    condition     = one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "API_APP_ORIGIN"]) == "https://novatrail-test-0.web.app"
    error_message = "api answers CORS for app's origin, the project's default site."
  }

  assert {
    condition = {
      for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.name => "${e.value_source[0].secret_key_ref[0].secret}:${e.value_source[0].secret_key_ref[0].version}" if length(e.value_source) > 0
      } == {
      API_DATABASE_URL         = "api-database-url:latest"
      API_OPENFGA_DATABASE_URL = "api-openfga-database-url:latest"
    }
    error_message = "serve reads each pooler's connection string in its variable, from the latest version of its own secret."
  }

  assert {
    condition     = length(google_cloud_run_v2_service.api[0].template[0].volumes) == 1
    error_message = "The facts' volume is the service's only one: the deployment changes its version, and the configuration leaves it alone by its place."
  }

  assert {
    condition = {
      for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.name => e.value if startswith(e.name, "API_CONSENT_FORMS_")
      } == {
      API_CONSENT_FORMS_BUCKET = "novatrail-test-0-consent-forms"
      API_CONSENT_FORMS_PREFIX = "consent-forms/"
    }
    error_message = "serve puts the scans of consent forms in consent_forms_bucket, under api's prefix consent-forms/, and is told no folder instead."
  }

  assert {
    condition     = endswith(one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == "API_CONSENT_FORMS_PREFIX"]), "/")
    error_message = "api's prefix in the bucket of the scans ends in a slash: api refuses one that does not."
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
    condition     = toset(keys(google_cloud_run_v2_job.api)) == toset(["after", "check", "migrate", "sweep"]) && google_cloud_run_v2_job.api["migrate"].name == "api-migrate"
    error_message = "The jobs are api-after, api-check, api-migrate and api-sweep, the four api's binary has."
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
      API_FIREBASE_PROJECT_ID               = "novatrail-test-0"
    }
    error_message = "migrate reads each connection string from a file, by the variable with the suffix _FILE, and is told the Firebase project."
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
    condition     = length(google_cloud_scheduler_job.api) == 0 && length(google_service_account.scheduler) == 0
    error_message = "With the jobs and no service, nothing runs by the clock yet: the first deployment has not migrated the databases, and the service's secrets may have no value."
  }
}

# check, by default: api's command that checks the facts and the rung, run by the deployment before
# the migrations, with the facts first of its volumes and the rung, and no database.
run "check_runs_before_the_migrations_by_default" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = google_cloud_run_v2_job.api["check"].name == "api-check" && google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].args == tolist(["check"]) && output.api_jobs["check"].deploy == "check"
    error_message = "api-check runs `api check`, and the deployment runs it in the part check, before the migrations."
  }

  assert {
    condition     = google_cloud_run_v2_job.api["check"].template[0].template[0].volumes[0].secret[0].secret == "api-admission-facts" && one([for e in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].env : e.value if e.name == "API_ADMISSION_RUNG"]) == "full"
    error_message = "The check reads the facts, first of its volumes, and the rung full."
  }

  assert {
    condition     = length(google_cloud_run_v2_job.api["check"].template[0].template[0].volumes) == 1 && length([for e in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].env : e if endswith(e.name, "DATABASE_URL_FILE")]) == 0
    error_message = "The check reads no database: the facts are its only volume."
  }
}

# sweep, the daily pass, once the service exists: its command, the pooler's strings as files from
# the service's own secrets, a timeout past its nine minutes, and 09:00 UTC, night in the US.
run "sweep_runs_every_day_once_the_service_exists" {
  command = plan

  variables {
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_serving = true
  }

  assert {
    condition     = google_cloud_run_v2_job.api["sweep"].name == "api-sweep" && google_cloud_run_v2_job.api["sweep"].template[0].template[0].containers[0].args == tolist(["sweep"]) && google_cloud_run_v2_job.api["sweep"].template[0].template[0].timeout == "900s"
    error_message = "api-sweep runs `api sweep`, with 900s for a pass of nine minutes at most and its start."
  }

  assert {
    condition = {
      for e in google_cloud_run_v2_job.api["sweep"].template[0].template[0].containers[0].env : e.name => e.value
      } == {
      API_DATABASE_URL_FILE         = "/secrets/api-database-url/value"
      API_OPENFGA_DATABASE_URL_FILE = "/secrets/api-openfga-database-url/value"
      API_FIREBASE_PROJECT_ID       = "novatrail-test-0"
      API_CONSENT_FORMS_BUCKET      = "novatrail-test-0-consent-forms"
      API_CONSENT_FORMS_PREFIX      = "consent-forms/"
    }
    error_message = "sweep reads what serve opens: both pooler's strings, as files, the Firebase project whose users it lists, and the store of the scans, whose scans past their term it erases."
  }

  assert {
    condition     = toset([for v in google_cloud_run_v2_job.api["sweep"].template[0].template[0].volumes : v.secret[0].secret]) == toset(["api-database-url", "api-openfga-database-url"]) && !contains(keys(google_secret_manager_secret.api_job), "api-database-url")
    error_message = "sweep mounts the service's own secrets, and no second secret of the same id is made."
  }

  assert {
    condition     = toset(keys(google_cloud_scheduler_job.api)) == toset(["sweep"]) && google_cloud_scheduler_job.api["sweep"].schedule == "0 9 * * *" && google_cloud_scheduler_job.api["sweep"].time_zone == "Etc/UTC"
    error_message = "sweep runs by the clock at 09:00 UTC, and it is the one job that does."
  }

  assert {
    condition = (
      length([for e in google_cloud_run_v2_job.api["sweep"].template[0].template[0].containers[0].env : e if e.name == "API_REQUEST_TIMEOUT"]) == 0 &&
      length([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e if e.name == "API_REQUEST_TIMEOUT"]) == 0
    )
    error_message = "Neither sweep nor its service sets API_REQUEST_TIMEOUT, so both take api's default, 30s: a job gets the value its service has, as api asks. A change to one is a change to both."
  }
}

# after, by default: api's pass once the new revision takes all traffic, run by the deployment in
# the part after, with the pooler's string of api alone, as a file from the service's own secret, a
# timeout past its nine minutes, and no clock.
run "after_runs_once_the_revision_takes_all_traffic" {
  command = plan

  variables {
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_serving = true
  }

  assert {
    condition     = google_cloud_run_v2_job.api["after"].name == "api-after" && google_cloud_run_v2_job.api["after"].template[0].template[0].containers[0].args == tolist(["after"]) && google_cloud_run_v2_job.api["after"].template[0].template[0].timeout == "900s" && output.api_jobs["after"].deploy == "after"
    error_message = "api-after runs `api after`, in the part after, with 900s for a pass of nine minutes at most and its start."
  }

  assert {
    condition = {
      for e in google_cloud_run_v2_job.api["after"].template[0].template[0].containers[0].env : e.name => e.value
      } == {
      API_DATABASE_URL_FILE   = "/secrets/api-database-url/value"
      API_FIREBASE_PROJECT_ID = "novatrail-test-0"
    }
    error_message = "after reads api's pooler's string alone, as a file: neither openfga, nor the facts, nor the rung."
  }

  assert {
    condition     = [for v in google_cloud_run_v2_job.api["after"].template[0].template[0].volumes : v.secret[0].secret] == ["api-database-url"] && !contains(keys(google_secret_manager_secret.api_job), "api-database-url")
    error_message = "after mounts the service's own secret, and no second secret of the same id is made."
  }

  assert {
    condition     = !contains(keys(google_cloud_scheduler_job.api), "after")
    error_message = "after runs in the deployment, never by the clock."
  }
}

# A job that names a secret of the service reads that secret: the configuration makes no second
# one of the same id, and makes the job's own as before.
run "a_job_naming_a_service_secret_reads_the_services_own" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_jobs = {
      daily = {
        args = ["daily"]
        secrets = {
          API_DATABASE_URL = "api-database-url"
          API_DAILY_TOKEN  = "api-daily-token"
        }
      }
    }
  }

  assert {
    condition     = toset(keys(google_secret_manager_secret.api_job)) == toset(["api-daily-token"]) && toset(keys(google_secret_manager_secret.api_service)) == toset(["api-database-url", "api-openfga-database-url"])
    error_message = "The job's own secret is made, and the service's is not made a second time."
  }

  assert {
    condition     = toset([for v in google_cloud_run_v2_job.api["daily"].template[0].template[0].volumes : v.secret[0].secret]) == toset(["api-database-url", "api-daily-token"])
    error_message = "The job mounts the service's secret and its own."
  }
}

# A job of the check gets what the revision will run with: the facts, first of its volumes, at the
# path the service reads them, and the same rung. The other jobs get neither.
run "a_job_of_the_check_reads_the_facts_and_the_rung_the_service_does" {
  command = plan

  variables {
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_serving = true
    api_jobs = {
      check = {
        args   = ["check"]
        deploy = "check"
      }
      migrate = {
        args   = ["migrate"]
        deploy = "migrate"
        secrets = {
          API_MIGRATE_DATABASE_URL = "api-migrate-database-url"
        }
      }
    }
  }

  assert {
    condition = (
      google_cloud_run_v2_job.api["check"].template[0].template[0].volumes[0].secret[0].secret == "api-admission-facts" &&
      google_cloud_run_v2_job.api["check"].template[0].template[0].volumes[0].secret[0].items[0].path == "facts.json" &&
      one([for m in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].volume_mounts : m.mount_path if m.name == google_cloud_run_v2_job.api["check"].template[0].template[0].volumes[0].name]) == "/etc/api/admission"
    )
    error_message = "The job of the check mounts the facts first, where the service mounts them: the deployment sets that volume's version."
  }

  assert {
    condition = alltrue([for name in ["API_ADMISSION_RUNG", "API_ADMISSION_FACTS_FILE"] :
      one([for e in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].env : e.value if e.name == name]) ==
      one([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.value if e.name == name])
    ])
    error_message = "The job of the check is told the rung and the facts' path the service is told."
  }

  assert {
    condition = (
      { for e in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].env : e.name => e.value if startswith(e.name, "API_CONSENT_FORMS_") } ==
      { for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : e.name => e.value if startswith(e.name, "API_CONSENT_FORMS_") } &&
      length([for e in google_cloud_run_v2_job.api["check"].template[0].template[0].containers[0].env : e if startswith(e.name, "API_CONSENT_FORMS_")]) == 2
    )
    error_message = "The job of the check is told the store of the scans the service is told, which api's check checks as serve takes it, though the job does not ask for it."
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_job.api["migrate"].template[0].template[0].containers[0].env : e if startswith(e.name, "API_CONSENT_FORMS_")]) == 0
    error_message = "A job that does not ask for the store of the scans is not told it."
  }

  assert {
    condition = (
      !contains([for v in google_cloud_run_v2_job.api["migrate"].template[0].template[0].volumes : v.secret[0].secret], "api-admission-facts") &&
      length([for e in google_cloud_run_v2_job.api["migrate"].template[0].template[0].containers[0].env : e if startswith(e.name, "API_ADMISSION_")]) == 0
    )
    error_message = "A job of another part reads neither the facts nor the rung."
  }
}

# The store of the scans goes to a job that asks for it, and once to a job of the check that asks for
# it as well: a variable given twice Cloud Run refuses at the apply.
run "the_store_of_the_scans_goes_to_the_jobs_that_open_it" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_jobs = {
      check = {
        args          = ["check"]
        deploy        = "check"
        consent_forms = true
      }
      migrate = {
        args   = ["migrate"]
        deploy = "migrate"
      }
      daily = {
        args          = ["daily"]
        consent_forms = true
      }
      hourly = {
        args = ["hourly"]
      }
    }
  }

  assert {
    condition = alltrue([for name in ["check", "daily"] :
      { for e in google_cloud_run_v2_job.api[name].template[0].template[0].containers[0].env : e.name => e.value if startswith(e.name, "API_CONSENT_FORMS_") } == {
        API_CONSENT_FORMS_BUCKET = "novatrail-test-0-consent-forms"
        API_CONSENT_FORMS_PREFIX = "consent-forms/"
      } &&
      length([for e in google_cloud_run_v2_job.api[name].template[0].template[0].containers[0].env : e if startswith(e.name, "API_CONSENT_FORMS_")]) == 2
    ])
    error_message = "A job that asks for the store of the scans is told the bucket and the prefix, each once, a job of the check among them."
  }

  assert {
    condition = alltrue([for name in ["migrate", "hourly"] :
      length([for e in google_cloud_run_v2_job.api[name].template[0].template[0].containers[0].env : e if startswith(e.name, "API_CONSENT_FORMS_")]) == 0
    ])
    error_message = "A job of another part or of the clock that does not ask for the store is not told it."
  }
}

# A job with a schedule gets Cloud Scheduler, and an identity of its own that may run the jobs
# that run by the clock and nothing else.
run "a_job_with_a_schedule_runs_by_the_clock" {
  command = plan

  variables {
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_serving = true
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
    condition     = google_cloud_run_v2_service_iam_member.deployer[0].role == "projects/novatrail-test-0/roles/apiDeployer" && toset([for m in values(google_cloud_run_v2_job_iam_member.deployer) : m.role]) == toset(["projects/novatrail-test-0/roles/apiDeployer"]) && toset(keys(google_cloud_run_v2_job_iam_member.deployer)) == toset(["after", "check", "migrate", "sweep"])
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

# A secret of a job's own by the names of the facts' volume or variables would give a job of the
# check two of each, which Cloud Run refuses at the apply: the plan refuses it first.
run "a_job_secret_by_the_facts_volumes_or_variables_name_is_refused" {
  command = plan

  variables {
    api_jobs = {
      check = {
        args    = ["check"]
        deploy  = "check"
        secrets = { API_ADMISSION_RUNG = "admission-facts" }
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

# Each job's part in api's deployment, which the deployment reads from the configuration's outputs
# with the service's name and the file of the facts (R15): migrate migrates; a job of the clock has
# none.
run "the_deployment_reads_the_jobs_parts_from_the_outputs" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_jobs = {
      migrate = {
        args   = ["migrate"]
        deploy = "migrate"
      }
      daily = {
        args     = ["daily"]
        schedule = "15 3 * * *"
      }
    }
  }

  assert {
    condition     = toset(keys(output.api_jobs)) == toset(["migrate", "daily"]) && output.api_jobs["migrate"].job == "api-migrate" && output.api_jobs["migrate"].deploy == "migrate" && output.api_jobs["daily"].job == "api-daily" && output.api_jobs["daily"].deploy == null
    error_message = "The outputs name each job made, by its Cloud Run name, with its part in the deployment."
  }

  assert {
    condition     = output.api_service_name == "api" && output.admission_facts_file == "/etc/api/admission/facts.json"
    error_message = "The outputs name the service and the file of the facts the revision reads."
  }
}

# The default list is what the tests read: tests/terraform.tfvars gives api_jobs as null, and the
# module takes its default. An assertion on var.api_jobs would see that null, so this one reads
# what the module made of it.
run "the_default_jobs_take_their_parts_in_the_deployment" {
  command = plan

  variables {
    api_image = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = toset(keys(output.api_jobs)) == toset(["check", "migrate", "after", "sweep"]) && alltrue([for name in ["check", "migrate", "after"] : output.api_jobs[name].job == "api-${name}" && output.api_jobs[name].deploy == name]) && output.api_jobs["sweep"].job == "api-sweep" && output.api_jobs["sweep"].deploy == null
    error_message = "The default list's check, migrate and after are the deployment's, and sweep goes by the clock."
  }
}

run "a_part_in_the_deployment_it_does_not_know_is_refused" {
  command = plan

  variables {
    api_jobs = {
      migrate = {
        args   = ["migrate"]
        deploy = "before"
      }
    }
  }

  expect_failures = [var.api_jobs]
}

run "a_job_of_the_deployment_on_a_schedule_is_refused" {
  command = plan

  variables {
    api_jobs = {
      migrate = {
        args     = ["migrate"]
        deploy   = "migrate"
        schedule = "15 3 * * *"
      }
    }
  }

  expect_failures = [var.api_jobs]
}
