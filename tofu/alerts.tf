# The alerts on Cloud Run's built-in metrics, which Cloud Monitoring keeps by itself and at no
# charge (R07). The alerts themselves are charged from September 1, 2027: $0.35 a month for each
# metric a condition names, one here in each, and $0.50 a million points its query returns.
#
# The spend alert hears of a burst only once Billing has counted it, hours later; these read the
# platform's own count of api's requests and mail the operator while it lasts and again once it is
# over. They point at the metrics and at api's own log, never at request logs: the platform keeps
# none.
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
