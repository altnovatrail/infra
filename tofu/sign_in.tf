# Sign-in in the platform's project: Identity Platform, which Firebase Authentication runs on, and
# its settings (R16). Firebase Authentication's settings are written by configuration only through
# it: the resource below "enable[s] Google Cloud Identity Platform (GCIP) (which is the backend for
# Firebase Authentication)" (Firebase, Get started with Terraform and Firebase). The step cannot be
# undone, and this resource is never deleted in Google Cloud: a destroy only forgets it.
#
# Sign-in with Google itself is not here. Its OAuth client and consent screen can no longer be made
# by any API, and the provider's resource for it would keep the client's secret in the state in
# plain text, so the operator turns it on in Firebase's console once, after the first apply
# (architecture 3.3). What app and api ask of sign-in is Google's window and nothing else
# (R03 api; R09 app).

resource "google_identity_platform_config" "this" {
  project = var.project_id

  # The whole list: Firebase's own address of the project, the authDomain app's sign-in window is
  # opened on, and app's origin, the address of the Hosting site app is served from (R06). A domain
  # set anywhere else is taken back by the next apply, a preview channel's among them: app is
  # released to the site's live channel alone, and a domain of its own joins this list when it is
  # bought. No localhost: app is run locally against a project of its own, never this one.
  authorized_domains = [
    "${var.project_id}.firebaseapp.com",
    "${google_firebase_hosting_site.app.site_id}.web.app",
  ]

  # No way in that would hold a password, an address of mail or a number of phone, and none that
  # would leave a user with nobody behind it (R03 api).
  sign_in {
    allow_duplicate_emails = false

    email {
      enabled = false
    }

    phone_number {
      enabled = false
    }

    anonymous {
      enabled = false
    }
  }

  # Activity logging writes every request of sign-in; it stays off, and every sink excludes it all
  # the same (R07 and its 2026-11-09 amendment).
  monitoring {
    request_logging {
      enabled = false
    }
  }

  multi_tenant {
    allow_tenants = false
  }

  mfa {
    state = "DISABLED"
  }

  # A user may sign up, through Google's window, and may not delete itself from the device: a user
  # is deleted by api alone, with its account and after its tokens are revoked (R03 api), and app
  # deletes an account through api.
  client {
    permissions {
      disabled_user_signup   = false
      disabled_user_deletion = true
    }
  }

  depends_on = [google_project_service.enabled, google_firebase_project.this]
}
