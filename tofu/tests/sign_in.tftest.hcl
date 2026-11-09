# Sign-in in the platform's project as R16 decided it, checked against mock providers: no
# credential, no call to Google.

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

# The authorized domains are the whole list: Firebase's address of the project and app's, and no
# localhost (R06).
run "the_authorized_domains_are_the_projects_two" {
  command = plan

  assert {
    condition     = google_identity_platform_config.this.authorized_domains == tolist(["novatrail-test-0.firebaseapp.com", "novatrail-test-0.web.app"])
    error_message = "The authorized domains are novatrail-test-0.firebaseapp.com and novatrail-test-0.web.app, and nothing else."
  }
}

# Google's window is the only way in, and the settings that would keep or log more stay off.
run "no_other_way_in_and_no_activity_log" {
  command = plan

  assert {
    condition = alltrue([
      !google_identity_platform_config.this.sign_in[0].email[0].enabled,
      !google_identity_platform_config.this.sign_in[0].phone_number[0].enabled,
      !google_identity_platform_config.this.sign_in[0].anonymous[0].enabled,
      !google_identity_platform_config.this.sign_in[0].allow_duplicate_emails,
    ])
    error_message = "Sign-in by mail, by phone and anonymous sign-in are off (R03 api)."
  }

  assert {
    condition     = !google_identity_platform_config.this.monitoring[0].request_logging[0].enabled
    error_message = "Identity Platform's activity log stays off (R07)."
  }

  assert {
    condition     = !google_identity_platform_config.this.multi_tenant[0].allow_tenants && google_identity_platform_config.this.mfa[0].state == "DISABLED"
    error_message = "No tenants and no second factor."
  }

  assert {
    condition     = !google_identity_platform_config.this.client[0].permissions[0].disabled_user_signup && google_identity_platform_config.this.client[0].permissions[0].disabled_user_deletion
    error_message = "A user signs up through Google's window, and only api deletes a user (R03 api)."
  }
}

# api manages its users of sign-in by bootstrap.sh's role signInUsers on the project, and its service
# and jobs are told which project's tokens it accepts.
run "api_holds_its_role_of_sign_in_and_its_project" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  override_resource {
    target = google_service_account.api
    values = {
      name  = "projects/novatrail-test-0/serviceAccounts/api-run@novatrail-test-0.iam.gserviceaccount.com"
      email = "api-run@novatrail-test-0.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = google_project_iam_member.grants["api_sign_in"].member == "serviceAccount:api-run@novatrail-test-0.iam.gserviceaccount.com"
    error_message = "api's role of sign-in, the one bootstrap.sh makes (bootstrap.tftest.hcl), is api-run's."
  }

  assert {
    condition     = contains([for e in google_cloud_run_v2_service.api[0].template[0].containers[0].env : "${e.name}=${e.value}"], "API_FIREBASE_PROJECT_ID=novatrail-test-0")
    error_message = "api's service is told the platform's project as the Firebase project whose tokens it accepts."
  }

  assert {
    condition     = alltrue([for job in google_cloud_run_v2_job.api : contains([for e in job.template[0].template[0].containers[0].env : "${e.name}=${e.value}"], "API_FIREBASE_PROJECT_ID=novatrail-test-0")])
    error_message = "api's jobs are told the same project as its service."
  }
}
