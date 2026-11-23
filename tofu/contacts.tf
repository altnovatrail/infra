# Only Security gets a contact of its own. Its fallback is the Organization Administrator, whom a
# project with no organization does not have, so a letter about a compromised project would have no
# recipient; the other categories fall back to the owners or the billing administrators, who exist.
# The address is the alerts' operator_email, which need not be a Google account; with no operator
# named there is no contact, and the letters go to the fallback.

resource "google_essential_contacts_contact" "security" {
  count = local.operator_named ? 1 : 0

  parent                              = "projects/${var.project_id}"
  email                               = var.operator_email
  language_tag                        = "en"
  notification_category_subscriptions = ["SECURITY"]

  depends_on = [google_project_service.enabled]
}
