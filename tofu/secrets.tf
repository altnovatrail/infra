# The configuration makes each secret and never a value: the values arrive from whoever holds them,
# never from a file of this repository. Every secret's replicas stay in the region.
#
# The deployment facts hold no secret: a secret is only the way to hand api's revision a file.
# The deployment adds each facts.json as a version and mounts that exact version.

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

# Made before any service, so that whoever holds the values can put them before the service is
# made; a job that names one reads the same secret. Never deleted: the serving revision mounts them.
resource "google_secret_manager_secret" "api_service" {
  for_each = local.api_service_secret_ids

  secret_id = each.value

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    purpose = "api-service-secret"
  }

  deletion_protection = true

  depends_on = [google_project_service.enabled]
}

# One for every id the list of jobs names. A secret the list stops naming is let go rather
# than deleted: its value stays, for whoever holds it to delete.
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

# The platform's keys for eval, one a provider. A global secret with its replica in
# the region, not a regional one: a regional secret is read only from its region, and GitHub's
# runners are elsewhere. A provider the list stops naming is let go rather than deleted: its value
# stays, for the author to delete.
resource "google_secret_manager_secret" "eval" {
  for_each = local.eval_secrets

  secret_id = "eval-key-${each.value}"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    purpose = "eval-key"
  }

  deletion_policy = "ABANDON"

  depends_on = [google_project_service.enabled]
}

# The service reads the exact version api_anthropic_key_version names, which the operator puts by
# hand before the merge that names it. Made on every copy, one with no key among them:
# an empty secret opens nothing. Never deleted: the serving revision mounts one of its versions.
resource "google_secret_manager_secret" "anthropic_key" {
  secret_id = "api-anthropic-key"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    purpose = "api-provider-key"
  }

  deletion_protection = true

  depends_on = [google_project_service.enabled]
}
