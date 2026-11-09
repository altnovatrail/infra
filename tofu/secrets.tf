# The secrets the configuration makes. It makes the secret and never a value: the values arrive
# from whoever holds them, never from a file of this repository (RULES.md, Hard rules).
#
# The facts of the deployment for api's admission function: no secret is in them (R25 api), and a
# secret is only the way to hand api's revision a file. The deployment adds each new facts.json as
# a new version and mounts that exact version as a volume, with its path in
# API_ADMISSION_FACTS_FILE (R05; the second 2026-11-08 amendment to R106 spec). Its replicas stay
# in the region, as every secret's do (R04).

resource "google_secret_manager_secret" "admission_facts" {
  secret_id = "api-admission-facts"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    purpose = "api-admission-facts"
  }

  # The serving revision mounts one of its versions, and an instance that starts reads it: the
  # configuration never deletes the secret.
  deletion_protection = true

  depends_on = [google_project_service.enabled]
}

# The secrets api's jobs read as files, one for every id the list of jobs names: the direct
# connection strings of api's two databases for migrate, to begin with (R11). Their values are put
# by whoever holds them; each is replicated to the region alone. A secret the list stops naming is
# let go rather than deleted: the configuration forgets it and its value stays, for whoever holds
# it to delete.
resource "google_secret_manager_secret" "api_job" {
  for_each = local.api_job_secret_ids

  secret_id = each.value

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    purpose = "api-job-secret"
  }

  deletion_policy = "ABANDON"

  depends_on = [google_project_service.enabled]
}
