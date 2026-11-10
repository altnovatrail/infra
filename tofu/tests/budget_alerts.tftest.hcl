# The spend alert and the alerts on Cloud Run's built-in metrics as R06 and R07 decided them,
# checked against mock providers: no credential, no call to Google. The values are synthetic, and
# the operator's address is example.com's.

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


# The budget counts this project alone, by its number, a month at a time, and mails at half of
# the amount, nine tenths of it and all of it. It is an alert, not a cap (R06).
run "the_budget_counts_this_project_by_the_month" {
  command = plan

  assert {
    condition     = google_billing_budget.spend.budget_filter[0].projects == toset(["projects/123456789012"]) && google_billing_budget.spend.budget_filter[0].calendar_period == "MONTH"
    error_message = "The budget counts this project alone, by its number, a month at a time."
  }

  assert {
    condition     = google_billing_budget.spend.amount[0].specified_amount[0].units == "10" && google_billing_budget.spend.amount[0].specified_amount[0].currency_code == "USD"
    error_message = "The budget's amount and currency are those given."
  }

  assert {
    condition     = toset([for r in google_billing_budget.spend.threshold_rules : r.threshold_percent]) == toset([0.5, 0.9, 1.0])
    error_message = "The budget mails at 50, 90 and 100 percent."
  }
}

run "no_operator_makes_no_alert" {
  command = plan

  assert {
    condition     = length(google_monitoring_notification_channel.operator) == 0 && length(google_monitoring_alert_policy.api) == 0 && length(google_monitoring_alert_policy.api_jobs) == 0
    error_message = "With no operator's address, neither the alerts nor their channel are made."
  }

  assert {
    condition     = length(google_billing_budget.spend.all_updates_rule[0].monitoring_notification_channels) == 0 && google_billing_budget.spend.all_updates_rule[0].disable_default_iam_recipients == false
    error_message = "With no operator, the budget mails the billing account's administrators and users alone."
  }
}

# With an operator: two alerts on api's request count, both read from Cloud Run's metrics and
# neither from a log, and both mailed to the operator (R07).
run "an_operator_gets_the_load_and_the_error_alerts" {
  command = plan

  variables {
    operator_email = "operator@example.com"
  }

  assert {
    condition     = length(google_monitoring_notification_channel.operator) == 1 && toset(keys(google_monitoring_alert_policy.api)) == toset(["load", "errors"])
    error_message = "With an operator's address, the load alert, the error alert and their channel are made."
  }

  assert {
    condition = alltrue([for p in google_monitoring_alert_policy.api :
      strcontains(p.conditions[0].condition_threshold[0].filter, "metric.type=\"run.googleapis.com/request_count\"") &&
      strcontains(p.conditions[0].condition_threshold[0].filter, "resource.labels.service_name=\"api\"")
    ])
    error_message = "Both alerts read Cloud Run's request count of the service api."
  }

  assert {
    condition = alltrue([for p in google_monitoring_alert_policy.api :
      !strcontains(p.conditions[0].condition_threshold[0].filter, "logging.googleapis.com") && length(p.conditions[0].condition_matched_log) == 0
    ])
    error_message = "No alert reads a log: the platform keeps no request logs, and log-based metrics would count excluded entries too."
  }

  assert {
    condition     = strcontains(google_monitoring_alert_policy.api["errors"].conditions[0].condition_threshold[0].filter, "metric.labels.response_code_class=\"5xx\"") && !strcontains(google_monitoring_alert_policy.api["load"].conditions[0].condition_threshold[0].filter, "response_code_class")
    error_message = "The error alert counts 5xx answers alone, and the load alert every answer."
  }

  assert {
    condition     = google_monitoring_alert_policy.api["load"].conditions[0].condition_threshold[0].threshold_value == 5 && google_monitoring_alert_policy.api["errors"].conditions[0].condition_threshold[0].threshold_value == 1 / 60
    error_message = "300 requests a minute are 5 a second, and one failed answer a minute is a sixtieth of one, the rates the conditions compare."
  }

  assert {
    condition = alltrue([for p in google_monitoring_alert_policy.api :
      !strcontains(lower(replace(p.documentation[0].content, "the platform keeps no request logs", "")), "request log") && !strcontains(lower(p.documentation[0].content), "logs explorer")
    ])
    error_message = "An alert's mail sends nobody to request logs, nor to Logs Explorer to look for them: there are none."
  }

  assert {
    condition     = length(google_billing_budget.spend.all_updates_rule[0].monitoring_notification_channels) == 1 && google_billing_budget.spend.all_updates_rule[0].disable_default_iam_recipients == false
    error_message = "With an operator, the budget mails the operator's channel too, and still the billing account's administrators and users."
  }

  assert {
    condition     = length(google_monitoring_alert_policy.api_jobs) == 0
    error_message = "With no service, nothing runs by the clock, and there is no alert on it."
  }
}

# With an operator and the service: an alert on a failed execution of a job by the clock, read from
# Cloud Run's count of a job's completed executions, mailed to the operator.
run "an_operator_hears_of_a_failed_job_by_the_clock" {
  command = plan

  variables {
    operator_email = "operator@example.com"
    api_image      = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
    api_serving    = true
  }

  assert {
    condition     = length(google_monitoring_alert_policy.api_jobs) == 1 && google_monitoring_alert_policy.api_jobs[0].notification_channels == tolist([google_monitoring_notification_channel.operator[0].name])
    error_message = "The alert on the jobs by the clock is made, and mails the operator."
  }

  assert {
    condition = (
      google_monitoring_alert_policy.api_jobs[0].conditions[0].condition_threshold[0].filter ==
      "resource.type=\"cloud_run_job\" AND resource.labels.job_name=one_of(\"api-sweep\") AND metric.type=\"run.googleapis.com/job/completed_execution_count\" AND metric.labels.result!=\"succeeded\""
    )
    error_message = "It counts the executions of api-sweep, the one job by the clock, that did not succeed, and of no job the deployment runs."
  }

  assert {
    condition     = google_monitoring_alert_policy.api_jobs[0].conditions[0].condition_threshold[0].threshold_value == 0 && google_monitoring_alert_policy.api_jobs[0].conditions[0].condition_threshold[0].comparison == "COMPARISON_GT"
    error_message = "One failed execution is enough."
  }
}

run "a_billing_account_not_of_its_form_is_refused" {
  command = plan

  variables {
    billing_account = "billing-account"
  }

  expect_failures = [var.billing_account]
}

run "a_budget_of_no_whole_units_is_refused" {
  command = plan

  variables {
    budget_amount = "0"
  }

  expect_failures = [var.budget_amount]
}

run "a_currency_not_of_iso_form_is_refused" {
  command = plan

  variables {
    budget_currency = "usd"
  }

  expect_failures = [var.budget_currency]
}

run "an_operator_address_not_of_a_mails_form_is_refused" {
  command = plan

  variables {
    operator_email = "operator"
  }

  expect_failures = [var.operator_email]
}
