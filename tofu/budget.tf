# The spend alert. On the Blaze plan nothing stops a project at a number (R06): this is an alert
# and not a cap, and what it buys is finding out on the day something starts costing money rather
# than at the end of the month. It is mailed to the billing account's administrators and users, as a
# budget is by default, and to the operator's channel too, where one is named: whoever gets the
# alerts on load and errors hears of spending as well.

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_billing_budget" "spend" {
  billing_account = var.billing_account
  display_name    = "${var.project_id} spend"

  # Only this project's charges, and only what is charged: the free allowance arrives as a credit
  # and is taken off before this is measured. The allowance is the billing account's, shared with
  # every project on it, so this one can be charged before it has used any.
  budget_filter {
    projects        = ["projects/${data.google_project.this.number}"]
    calendar_period = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = var.budget_amount
    }
  }

  # Half of it, nine tenths of it, and all of it.
  threshold_rules {
    threshold_percent = 0.5
  }

  threshold_rules {
    threshold_percent = 0.9
  }

  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = google_monitoring_notification_channel.operator[*].name
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.enabled]
}
