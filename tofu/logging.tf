# Where the project's logs and traces are kept: in its region, as the rest of it is (R04), and
# without Cloud Run's request logs, which carry the client's IP address (R07).
#
# Cloud Logging made the project's own buckets in `global`, and a bucket never changes its
# location, so the logs go to a bucket of this region instead, by the sink that filled the default
# one. The bucket `_Required` — the audit of who changed what in the project, 400 days — stays
# where it is: neither it nor its sink can be changed, and it takes no request logs (Д3 in RUN.md).
#
# Two more logs are off by Google's own default and nothing here turns them on: the Data Access
# audit, with the caller's address, and the activity log of Identity Platform, which would hold
# every sign-in request. Every sink excludes them as well, so that they are not kept even where
# something else turns them on — a self-hosted copy's organization, a later change (R07, amended
# 2026-11-09).

locals {
  # What no sink of the project keeps, by the name of each exclusion (R07). Cloud Run's request logs
  # hold the client's address in httpRequest; the log's exact name is checked against an entry of
  # the project once it has one (T24).
  exclusions = {
    "cloud-run-request-logs" = {
      filter      = "LOG_ID(\"run.googleapis.com/requests\")"
      description = "Cloud Run's request logs hold the client's IP address, and the platform keeps none (R07)."
    }
    "data-access-audit" = {
      filter      = "LOG_ID(\"cloudaudit.googleapis.com/data_access\")"
      description = "The Data Access audit holds the caller's IP address; the platform keeps none (R07)."
    }
    "identity-platform-requests" = {
      filter      = "LOG_ID(\"identitytoolkit.googleapis.com/requests\")"
      description = "Identity Platform's activity log holds every sign-in request; the platform keeps none (R07)."
    }
  }

  # What the _Default sink takes, as Cloud Logging creates it, word for word: everything the
  # _Required sink does not.
  default_sink_filter = join(" AND ", [
    "NOT LOG_ID(\"cloudaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/activity\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/system_event\")",
    "NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\")",
    "NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")",
  ])

  # Every sink of the project, by name. A sink added here gets every exclusion above, and the tests
  # hold each of them to it; tf-check refuses a sink declared anywhere but in this list.
  sinks = {
    "_Default" = {
      destination = "logging.googleapis.com/projects/${var.project_id}/locations/${var.region}/buckets/${google_logging_project_bucket_config.logs.bucket_id}"
      filter      = local.default_sink_filter
    }
  }
}

resource "google_logging_project_bucket_config" "logs" {
  project        = var.project_id
  location       = var.region
  bucket_id      = "default-${var.region}"
  retention_days = var.log_retention_days
  description    = "Every log of the project but the audit of its changes, kept in its region."

  # The _Default sink points here, and a destroy leaves the sink as it is: deleting the bucket would
  # leave the project's logs going to a bucket pending deletion, and a change of region would be
  # such a delete too. A bucket's place does not change (R04), so this one is not deleted by the
  # configuration at all.
  deletion_policy = "PREVENT"

  depends_on = [google_project_service.enabled]
}

# The configuration takes the existing _Default sink over rather than creating one: the provider
# updates a sink that is already there, and a destroy leaves _Default where it is.
#
# The bucket is in the sink's own project, and such a sink has no writer identity whatever it asks
# for. The provider reads a sink with no writer identity as one with a unique identity, so that is
# what is written here: written false, every plan would show a change that no apply makes (as
# canvas-api found).
resource "google_logging_project_sink" "sinks" {
  for_each = local.sinks

  name                   = each.key
  destination            = each.value.destination
  filter                 = each.value.filter
  unique_writer_identity = true

  dynamic "exclusions" {
    for_each = local.exclusions

    content {
      name        = exclusions.key
      description = exclusions.value.description
      filter      = exclusions.value.filter
    }
  }
}

# Where traces are kept: the bucket _Trace, which the system makes with the first trace, in the
# place the project's settings for observability buckets name. The setting comes before any trace:
# a bucket keeps its place for good, and only a reprovision that erases the traces could move it
# (R04, amended 2026-11-09). The platform writes no traces — Cloud Trace's API is off (R07) — but
# Cloud Run samples some requests by itself, and the place is set for whatever comes.
#
# The setting, not the bucket: the provider sets it with a PATCH that a second apply repeats
# harmlessly, while it creates the bucket with a POST that fails wherever _Trace already is, and
# never deletes one.
resource "google_observability_project_settings" "traces" {
  project                  = var.project_id
  location                 = "global"
  default_storage_location = var.region

  depends_on = [google_project_service.enabled]
}
