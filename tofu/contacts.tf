# The project's contact for Google's notifications of the category Security (R27, its second
# 2026-11-17 amendment). Without a contact of its own a category goes to a fallback contact chosen
# by an IAM role, and Security's is the Organization Administrator: a project with no organization,
# as the platform's has none, has nobody who holds that role, so by the documentation a letter about
# a compromised project has no recipient, and what Google does then it does not say (sources 5.7).
# The other categories fall back to the project's owners or the billing account's administrators,
# who are there, and are left to them.
#
# The address is the operator's, the one the alerts are mailed to, TF_VAR_operator_email: it need not
# be a Google account, and a list is what Google advises. A deployment that names no operator gets
# no contact, and its letters go to the fallback.

resource "google_essential_contacts_contact" "security" {
  count = local.operator_named ? 1 : 0

  parent                              = "projects/${var.project_id}"
  email                               = var.operator_email
  language_tag                        = "en"
  notification_category_subscriptions = ["SECURITY"]

  depends_on = [google_project_service.enabled]
}
