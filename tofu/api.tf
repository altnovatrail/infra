# api's Cloud Run service and jobs, and the schedule of the jobs that run by the clock (R11).
#
# Which image they run is the deployment's to say, and so is the one value a deployment changes
# beside it: the version of the facts secret the service mounts (R05; the second 2026-11-08
# amendment to R106 spec). The configuration sets the two only when it creates the service, and
# owns everything around them, the lowest admission rung among it: a deployment takes only full
# (R05; R25 api), so there is nothing for the deployment to change there.
#
# Nothing here exists until api_image names an image in this project's registry: a Cloud Run
# resource cannot be made without one, and before the first deployment pushes api's image there is
# none to name. Google's placeholder image is no production image of NovaTrail (RULES.md,
# Production images), so it does not stand in. The jobs come first and the service after them, once
# api_serving says so: the first deployment runs the check of the configuration and the migrations
# with the jobs, and only then is the service made, on a database already migrated, as R05 orders
# every deployment.

locals {
  api_created = var.api_image != null
  api_serving = local.api_created && var.api_serving

  # Where the service reads the deployment facts: the file's path is in API_ADMISSION_FACTS_FILE.
  admission_dir  = "/etc/api/admission"
  admission_file = "facts.json"

  # The service's secrets, by api's variable: the pooler's connection strings of its two databases,
  # which serve opens at its start (README api).
  api_service_secrets = {
    API_DATABASE_URL         = "api-database-url"
    API_OPENFGA_DATABASE_URL = "api-openfga-database-url"
  }
  api_service_secret_ids = toset(values(local.api_service_secrets))

  # Every secret a job reads as a file, by its id, from every job of the list, but the service's:
  # a job that names one of those reads the service's secret, not a second of the same id.
  api_job_secret_ids = setsubtract(toset(flatten([for job in values(var.api_jobs) : values(job.secrets)])), local.api_service_secret_ids)

  # Every secret of api a volume may name, by its id.
  api_secrets = merge(google_secret_manager_secret.api_job, google_secret_manager_secret.api_service)

  # The origin app is served at, the one api answers CORS for: the default site, named after the
  # project (R06).
  app_origin = "https://${google_firebase_hosting_site.app.site_id}.web.app"

  # The jobs that run by the clock, once the jobs exist.
  api_scheduled_jobs = local.api_created ? { for name, job in var.api_jobs : name => job if job.schedule != null } : {}

  # The memory of the container in MiB, whichever unit it is written in.
  api_memory_mib = tonumber(regex("^[0-9]+", var.api_memory)) * (endswith(var.api_memory, "Gi") ? 1024 : 1)
}

resource "google_cloud_run_v2_service" "api" {
  count = local.api_serving ? 1 : 0

  name     = var.api_service_name
  location = var.region

  # app calls it from the families' browsers, over the public internet, at its own address on
  # run.app (R06).
  ingress = "INGRESS_TRAFFIC_ALL"

  # Nothing is lost with the service: the data is in api's databases, and the service is made again
  # from this file.
  deletion_protection = false

  # Down to nothing when nobody asks, and up to a small ceiling, which bounds how fast a burst can
  # spend.
  scaling {
    min_instance_count = 0
    max_instance_count = var.api_max_instances
  }

  template {
    service_account                  = google_service_account.api.email
    timeout                          = var.api_request_timeout
    max_instance_request_concurrency = var.api_concurrency

    containers {
      image = var.api_image

      resources {
        limits = {
          cpu    = var.api_cpu
          memory = var.api_memory
        }

        # Billed per request: an instance holding no request holds no CPU.
        cpu_idle = true

        # A starting instance gets the processor at full speed.
        startup_cpu_boost = true
      }

      # An instance gets its first request once its health answers: api answers GET /health.
      startup_probe {
        http_get {
          path = "/health"
        }

        period_seconds    = 1
        timeout_seconds   = 1
        failure_threshold = 30
      }

      # The lowest admission rung: full, the only one a deployment takes (R05; R25 api).
      env {
        name  = "API_ADMISSION_RUNG"
        value = "full"
      }

      env {
        name  = "API_ADMISSION_FACTS_FILE"
        value = "${local.admission_dir}/${local.admission_file}"
      }

      # The Firebase project whose ID tokens api accepts: the platform's own (R16).
      env {
        name  = "API_FIREBASE_PROJECT_ID"
        value = var.project_id
      }

      # The runtime is told nine tenths of the memory as the heap its collector keeps under.
      env {
        name  = "GOMEMLIMIT"
        value = "${floor(local.api_memory_mib * 9 / 10)}MiB"
      }

      # app is on its own origin, the site's, and api on run.app: api answers CORS for that one
      # origin, "when api has an origin of its own" (README api).
      env {
        name  = "API_APP_ORIGIN"
        value = local.app_origin
      }

      # The pooler's connection strings, each in its variable from the latest version of its secret,
      # resolved when an instance starts: api takes a secret from its variable or from a file, alike
      # (R26 api). Not volumes: the facts' volume stays the service's only one, the one whose version
      # the deployment changes and the configuration leaves alone by its place.
      dynamic "env" {
        for_each = local.api_service_secrets

        content {
          name = env.key

          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.api_service[env.value].secret_id
              version = "latest"
            }
          }
        }
      }

      volume_mounts {
        name       = "admission-facts"
        mount_path = local.admission_dir
      }
    }

    # The deployment facts, a file in one version of the secret. The deployment adds each version
    # and mounts the one it names; at creation the latest stands in (R05).
    volumes {
      name = "admission-facts"

      secret {
        secret = google_secret_manager_secret.admission_facts.secret_id

        items {
          path    = local.admission_file
          version = "latest"
        }
      }
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_secret_manager_secret_iam_member.api_reads_facts,
    google_secret_manager_secret_iam_member.api_reads_service_secrets,
  ]

  # The deployment owns the image and the facts' version; this configuration owns everything
  # around them. Without these lines the two would take turns. The deployment's gcloud
  # also writes itself into the service as its client. Traffic is not described: the provider
  # computes it when no block names it, so a move of traffic is not undone by the next apply.
  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
      template[0].volumes[0].secret[0].items[0].version,
    ]
  }
}

# Anyone may call it: whether a caller gets anything is api's own checks.
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = local.api_serving ? 1 : 0

  location = google_cloud_run_v2_service.api[0].location
  name     = google_cloud_run_v2_service.api[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# api's jobs, one for each entry of the list, with the same image as the service once the deployment
# has set it. A job added to the list later is made with api_image, the first image, and gets the
# serving one when the deployment sets the image of every job: a job joins the list with the release
# of api that has its command, so the deployment of that release follows its apply (R05). A job's secrets come as files, each the latest version of its secret, with the path
# in the variable the name names with the suffix _FILE, as api reads any secret (R29 api).
resource "google_cloud_run_v2_job" "api" {
  for_each = local.api_created ? var.api_jobs : {}

  name     = "${var.api_service_name}-${each.key}"
  location = var.region

  deletion_protection = false

  template {
    task_count = 1

    template {
      service_account = google_service_account.api.email
      timeout         = each.value.timeout

      # The deployment decides whether a failed job runs again: a migration run twice by the
      # platform behind its back is not what it asked for.
      max_retries = 0

      containers {
        image = var.api_image
        args  = each.value.args

        resources {
          limits = {
            cpu    = var.api_cpu
            memory = var.api_memory
          }
        }

        # The same Firebase project as the service's, for a job that goes through api's users of
        # sign-in (R16).
        env {
          name  = "API_FIREBASE_PROJECT_ID"
          value = var.project_id
        }

        dynamic "env" {
          for_each = each.value.secrets

          content {
            name  = "${env.key}_FILE"
            value = "/secrets/${env.value}/value"
          }
        }

        dynamic "volume_mounts" {
          for_each = toset(values(each.value.secrets))

          content {
            name       = volume_mounts.value
            mount_path = "/secrets/${volume_mounts.value}"
          }
        }
      }

      dynamic "volumes" {
        for_each = toset(values(each.value.secrets))

        content {
          name = volumes.value

          secret {
            secret = local.api_secrets[volumes.value].secret_id

            items {
              path    = "value"
              version = "latest"
            }
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.enabled,
    google_secret_manager_secret_iam_member.api_reads_job_secrets,
    google_secret_manager_secret_iam_member.api_reads_service_secrets,
  ]

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      template[0].template[0].containers[0].image,
    ]
  }
}

# The schedule of the jobs that run by the clock: Cloud Scheduler calls Cloud Run's API to run the
# job, as an identity that may run those jobs and nothing else.
resource "google_service_account" "scheduler" {
  count = length(local.api_scheduled_jobs) > 0 ? 1 : 0

  account_id   = "${var.api_service_name}-scheduler"
  display_name = "Runs ${var.api_service_name}'s jobs by the clock"

  depends_on = [google_project_service.enabled]
}

resource "google_cloud_run_v2_job_iam_member" "scheduler" {
  for_each = local.api_scheduled_jobs

  location = google_cloud_run_v2_job.api[each.key].location
  name     = google_cloud_run_v2_job.api[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler[0].email}"
}

resource "google_cloud_scheduler_job" "api" {
  for_each = local.api_scheduled_jobs

  name      = "${var.api_service_name}-${each.key}"
  region    = var.region
  schedule  = each.value.schedule
  time_zone = "Etc/UTC"

  http_target {
    http_method = "POST"
    uri         = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.api[each.key].name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler[0].email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_project_service.enabled]
}
