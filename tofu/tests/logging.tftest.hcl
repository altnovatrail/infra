# The logs and the traces as R04 and R07 decided them, checked against mock providers, as the
# configuration's other tests are: no credential, no call to Google. The values are synthetic.

mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      number = "123456789012"
    }
  }
}

mock_provider "google-beta" {}

variables {
  project_id = "novatrail-test-0"
  region     = "us-east4"

  billing_account = "0A1B2C-3D4E5F-6A7B8C"
  budget_amount   = "10"
  budget_currency = "USD"
}

# Every sink the project has excludes Cloud Run's request logs, which hold the client's address,
# the Data Access audit and Identity Platform's activity log: the ones to come too, since they are
# made from the same list, which tf-check holds every sink to (R07).
run "every_sink_excludes_what_the_platform_keeps_none_of" {
  command = plan

  assert {
    condition     = length(google_logging_project_sink.sinks) >= 1
    error_message = "The configuration has its sinks, _Default among them."
  }

  assert {
    condition = alltrue(flatten([for sink in google_logging_project_sink.sinks : [for log in [
      "LOG_ID(\"run.googleapis.com/requests\")",
      "LOG_ID(\"cloudaudit.googleapis.com/data_access\")",
      "LOG_ID(\"identitytoolkit.googleapis.com/requests\")",
    ] : contains([for exclusion in sink.exclusions : exclusion.filter if exclusion.disabled != true], log)]]))
    error_message = "A sink lets through a log the platform keeps none of: each needs an exclusion, not disabled, of Cloud Run's request logs, of the Data Access audit and of Identity Platform's requests."
  }
}

# The _Default sink keeps taking what it took, word for word, and sends it to the region's bucket
# rather than to the global one (R04).
run "the_default_sink_goes_to_the_regions_bucket" {
  command = plan

  assert {
    condition     = google_logging_project_sink.sinks["_Default"].destination == "logging.googleapis.com/projects/novatrail-test-0/locations/us-east4/buckets/default-us-east4"
    error_message = "The _Default sink sends the logs to the bucket of the region."
  }

  assert {
    condition     = google_logging_project_sink.sinks["_Default"].filter == "NOT LOG_ID(\"cloudaudit.googleapis.com/activity\") AND NOT LOG_ID(\"externalaudit.googleapis.com/activity\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"externalaudit.googleapis.com/system_event\") AND NOT LOG_ID(\"cloudaudit.googleapis.com/access_transparency\") AND NOT LOG_ID(\"externalaudit.googleapis.com/access_transparency\")"
    error_message = "The _Default sink keeps the filter Cloud Logging created it with: everything the _Required sink does not take."
  }
}

# The logs are kept 30 days in a bucket of the region (R04, R07).
run "the_logs_are_kept_30_days_in_the_region" {
  command = plan

  assert {
    condition     = google_logging_project_bucket_config.logs.location == "us-east4" && google_logging_project_bucket_config.logs.bucket_id == "default-us-east4"
    error_message = "The log bucket is in the region, and named after it."
  }

  assert {
    condition     = google_logging_project_bucket_config.logs.retention_days == 30
    error_message = "The logs are kept 30 days."
  }

  assert {
    condition     = output.log_bucket == "default-us-east4"
    error_message = "The output names the log bucket."
  }

  assert {
    condition     = google_logging_project_bucket_config.logs.deletion_policy == "PREVENT"
    error_message = "The configuration never deletes the log bucket, which the _Default sink points at: not by a destroy, not by a change of region."
  }
}

# The place _Trace is made in, with the first trace, is the region (R04, amended 2026-11-09).
run "traces_are_kept_in_the_region" {
  command = plan

  assert {
    condition     = google_observability_project_settings.traces.location == "global" && google_observability_project_settings.traces.default_storage_location == "us-east4"
    error_message = "The project's settings for observability buckets name the region as their place."
  }
}

# A self-hosted copy made in another region keeps its logs and traces there: nothing names us-east4
# but the variable. This is a new project's plan, not a move: the log bucket is never deleted, and
# _Trace keeps the place it was made in (R04).
run "another_region_moves_the_logs_and_the_traces" {
  command = plan

  variables {
    region = "europe-west1"
  }

  assert {
    condition     = google_logging_project_bucket_config.logs.location == "europe-west1" && google_observability_project_settings.traces.default_storage_location == "europe-west1"
    error_message = "The log bucket and _Trace are in the region given."
  }

  assert {
    condition     = endswith(google_logging_project_sink.sinks["_Default"].destination, "/locations/europe-west1/buckets/default-europe-west1")
    error_message = "The _Default sink sends the logs to the bucket of the region given."
  }
}

run "a_retention_of_0_days_is_refused" {
  command = plan

  variables {
    log_retention_days = 0
  }

  expect_failures = [var.log_retention_days]
}

run "a_retention_past_3650_days_is_refused" {
  command = plan

  variables {
    log_retention_days = 3651
  }

  expect_failures = [var.log_retention_days]
}

run "no_retention_given_is_30_days" {
  command = plan

  variables {
    log_retention_days = null
  }

  assert {
    condition     = google_logging_project_bucket_config.logs.retention_days == 30
    error_message = "A retention given as null is the default, 30 days."
  }
}

run "a_retention_of_part_of_a_day_is_refused" {
  command = plan

  variables {
    log_retention_days = 1.5
  }

  expect_failures = [var.log_retention_days]
}
