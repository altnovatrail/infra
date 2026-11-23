# Firebase Authentication's settings are written by configuration only through Identity Platform,
# which it runs on. Turning it on cannot be undone, and a destroy only forgets this resource.
#
# Sign-in with Google itself is not here: its OAuth client and consent screen cannot be made by any
# API, and the provider's resource for it would keep the client's secret in the state in plain
# text, so the operator turns it on in Firebase's console once, after the first apply.

resource "google_identity_platform_config" "this" {
  project = var.project_id

  # The whole list: Firebase's own address of the project, the authDomain app's sign-in window is
  # opened on, and app's origin, the address of the Hosting site app is served from. A domain
  # set anywhere else is taken back by the next apply, a preview channel's among them: app is
  # released to the site's live channel alone, and a domain of its own joins this list when it is
  # bought. No localhost: app is run locally against a project of its own, never this one.
  authorized_domains = [
    "${var.project_id}.firebaseapp.com",
    "${google_firebase_hosting_site.app.site_id}.web.app",
  ]

  # No way in that would hold a password, an address of mail or a number of phone, and none that
  # would leave a user with nobody behind it.
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
  # the same.
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
  # is deleted by api alone, with its account and after its tokens are revoked, and app
  # deletes an account through api.
  client {
    permissions {
      disabled_user_signup   = false
      disabled_user_deletion = true
    }
  }

  depends_on = [google_project_service.enabled, google_firebase_project.this]
}
