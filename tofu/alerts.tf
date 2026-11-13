# The alerts on Cloud Run's built-in metrics, which Cloud Monitoring keeps by itself and at no
# charge (R07). The alerts themselves are charged from September 1, 2027: $0.35 a month for each
# metric a condition names, one here in each, and $0.50 a million points its query returns.
#
# The spend alert hears of a burst only once Billing has counted it, hours later; these read the
# platform's own count of api's requests and mail the operator while it lasts and again once it is
# over; the two on the jobs by the clock mail once, at a failed run and at a day with no run. They
# point at the metrics and at api's own log, never at request logs: the platform keeps none.
#
# The operator's address is a person's, so it is no part of the public description of the
# deployment: it arrives as TF_VAR_operator_email, and every plan prints it as a sensitive value. A
# deployment that names no operator gets neither the channel nor the alerts.

locals {
  # Whether an operator is named. Only that is read out of the address, which stays sensitive: a
  # yes or a no tells nothing of it, and for_each cannot take a sensitive value.
  operator_named = nonsensitive(var.operator_email != "")

  alerts = local.operator_named ? {
    # More requests than the service is sized for: a burst, or a client in a loop.
    load = {
      display_name = "${var.api_service_name} load"
      condition    = "Requests a minute, on average over five minutes"
      response     = ""
      per_minute   = var.load_alert_per_minute
      subject      = "${var.api_service_name}: more than ${var.load_alert_per_minute} requests a minute"
      content      = "The service has had more than ${var.load_alert_per_minute} requests a minute on average over the last five minutes."
    }
    # Answers of the 5xx class: the service failing, not a client asking wrong.
    errors = {
      display_name = "${var.api_service_name} errors"
      condition    = "5xx answers a minute, on average over five minutes"
      response     = "5xx"
      per_minute   = var.error_alert_per_minute
      subject      = "${var.api_service_name}: more than ${var.error_alert_per_minute} failed answers a minute"
      content      = "The service has answered more than ${var.error_alert_per_minute} requests a minute with a 5xx code on average over the last five minutes."
    }
  } : {}
}

resource "google_monitoring_notification_channel" "operator" {
  count = local.operator_named ? 1 : 0

  display_name = "${var.api_service_name} operator"
  type         = "email"
  labels = {
    email_address = var.operator_email
  }

  depends_on = [google_project_service.enabled]
}

resource "google_monitoring_alert_policy" "api" {
  for_each = local.alerts

  display_name = each.value.display_name
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = each.value.condition

    condition_threshold {
      filter = join(" AND ", compact([
        "resource.type=\"cloud_run_revision\"",
        "resource.labels.service_name=\"${var.api_service_name}\"",
        "metric.type=\"run.googleapis.com/request_count\"",
        each.value.response == "" ? "" : "metric.labels.response_code_class=\"${each.value.response}\"",
      ]))

      # The rate over the last five minutes, every revision and every answer summed: an average
      # that rolls, so a burst of seconds mails nobody.
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = each.value.per_minute / 60

      # A minute over the line before it fires: Cloud Monitoring takes a rule for missing points only
      # in a condition that waits a minute at least. No requests write no points, and that is
      # neither load nor errors, so the incident closes rather than waiting for data that will not
      # come.
      duration                = "60s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
    }
  }

  alert_strategy {
    auto_close           = "1800s"
    notification_prompts = ["OPENED", "CLOSED"]
  }

  notification_channels = [google_monitoring_notification_channel.operator[0].name]

  documentation {
    subject   = each.value.subject
    mime_type = "text/markdown"
    content   = <<-EOT
      ${each.value.content}

      - The service's metrics in Cloud Run show which answers the requests got, how long they took and how many instances served them.
      - api's own log, in the bucket `${google_logging_project_bucket_config.logs.bucket_id}`, shows the method, the code and the reason of each refusal; the platform keeps no request logs.

      A second mail comes once the rate is back under the line.
    EOT
  }

  depends_on = [google_project_service.enabled]
}

# A job by the clock that did not pass: sweep exits 1 unless its pass was clean, and the next pass
# picks up what it left (README api). A pass that fails day after day leaves the deletions and the
# terms of retention standing, with nobody told; this mails the operator at the first. It reads
# Cloud Run's own count of a job's completed executions by their result: every result but
# "succeeded". Google's list of metrics names the label and not its values. On the project, Cloud
# Run wrote "succeeded" for the deployment's jobs and for the first run of sweep by the clock, and
# "failed" for a run of api-migrate (T42, T43). Matching what is not a success, a value spelled
# otherwise mails too many rather than none. One metric, charged as the two above.
locals {
  # The names of the jobs by the clock, as Cloud Run knows them.
  api_clock_job_names = [for name in keys(local.api_scheduled_jobs) : google_cloud_run_v2_job.api[name].name]
}

resource "google_monitoring_alert_policy" "api_jobs" {
  count = local.operator_named && length(local.api_scheduled_jobs) > 0 ? 1 : 0

  display_name = "${var.api_service_name} jobs by the clock"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "A failed execution of a job by the clock"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"cloud_run_job\"",
        "resource.labels.job_name=one_of(${join(",", [for name in local.api_clock_job_names : "\"${name}\""])})",
        "metric.type=\"run.googleapis.com/job/completed_execution_count\"",
        "metric.labels.result!=\"succeeded\"",
      ])

      # The failed executions of the last five minutes, every job summed: one is enough.
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }

      comparison      = "COMPARISON_GT"
      threshold_value = 0

      # A failure stays in the five minutes' sum long enough for the minute a condition must wait
      # before it may take missing points as no incident: a day with no failure writes none.
      duration                = "60s"
      evaluation_missing_data = "EVALUATION_MISSING_DATA_INACTIVE"
    }
  }

  alert_strategy {
    auto_close           = "1800s"
    notification_prompts = ["OPENED"]
  }

  notification_channels = [google_monitoring_notification_channel.operator[0].name]

  documentation {
    subject   = "${var.api_service_name}: a job by the clock failed"
    mime_type = "text/markdown"
    content   = <<-EOT
      An execution of one of api's jobs by the clock (${join(", ", [for name in local.api_clock_job_names : "`${name}`"])}) failed.

      - The job's executions in Cloud Run show which one failed and how long it ran.
      - api's own log, in the bucket `${google_logging_project_bucket_config.logs.bucket_id}`, shows each step of the pass with its counts.

      The next pass picks up what this one left. A failure day after day leaves deletions and the terms of retention standing.
    EOT
  }

  depends_on = [google_project_service.enabled]
}

# A job by the clock that did not run at all: Cloud Scheduler could not call it — its account's
# right, the job's address —, the schedule is paused, or Cloud Scheduler failed. No execution writes
# no point, so the alert above stays silent; Cloud Scheduler has no metric of its own and retries no
# failed call (the 2026-11-13 amendment to R07). This counts each job's executions whatever their
# result, over the last 25 hours, the longest window an alert may roll, and takes no data as the
# condition met: a job that runs every day, and completes within the hour, always has a point in it,
# and a day with no run empties it about an hour after the run it missed. A condition on absence
# waits 23.5 hours at most, less than a day, and would open at each day's gap (T34). So a job by the
# clock runs every day, and its timeout is under the hour (variables.tf). Each job is a condition of
# its own, so that one job's points never stand for another's missing ones, and each is a metric
# charged as the others. A job with no run yet has no data either: made, renamed or added, it may
# mail before its first run. It mails only when the incident opens: Cloud Monitoring also closes
# one that has had no data for a day more than auto_close, and a mail of that would read as a run.
resource "google_monitoring_alert_policy" "api_jobs_missed" {
  count = local.operator_named && length(local.api_scheduled_jobs) > 0 ? 1 : 0

  display_name = "${var.api_service_name} jobs by the clock not run"
  combiner     = "OR"
  severity     = "WARNING"

  dynamic "conditions" {
    for_each = local.api_clock_job_names

    content {
      display_name = "No execution of ${conditions.value} for 25 hours"

      condition_threshold {
        filter = join(" AND ", [
          "resource.type=\"cloud_run_job\"",
          "resource.labels.job_name=\"${conditions.value}\"",
          "metric.type=\"run.googleapis.com/job/completed_execution_count\"",
        ])

        # The job's executions of the last 25 hours, every result summed: one is enough.
        aggregations {
          alignment_period     = "90000s"
          per_series_aligner   = "ALIGN_SUM"
          cross_series_reducer = "REDUCE_SUM"
        }

        comparison      = "COMPARISON_LT"
        threshold_value = 1

        # No point in the window is the miss itself.
        duration                = "300s"
        evaluation_missing_data = "EVALUATION_MISSING_DATA_ACTIVE"
      }
    }
  }

  alert_strategy {
    auto_close           = "1800s"
    notification_prompts = ["OPENED"]
  }

  notification_channels = [google_monitoring_notification_channel.operator[0].name]

  documentation {
    subject   = "${var.api_service_name}: a job by the clock has not run for a day"
    mime_type = "text/markdown"
    content   = <<-EOT
      One of api's jobs by the clock (${join(", ", [for name in local.api_clock_job_names : "`${name}`"])}) has completed no execution in the last 25 hours: Cloud Scheduler did not start it, or it did not finish. A job made or renamed less than a day ago may have had no run yet.

      - Cloud Scheduler's log of its attempts, `cloudscheduler.googleapis.com/executions` in the bucket `${google_logging_project_bucket_config.logs.bucket_id}`, shows each call and the status it got, in `AttemptFinished`.
      - ${join(", ", [for name in keys(local.api_scheduled_jobs) : "`gcloud scheduler jobs describe ${google_cloud_scheduler_job.api[name].name} --location=${var.region}`"])} shows whether the schedule is enabled and the status of its last call.
      - The job's executions in Cloud Run show whether one started and how long it ran.

      The next pass picks up what a missed one left, but until a pass runs, deletions and the terms of retention stand.
    EOT
  }

  depends_on = [google_project_service.enabled]
}
