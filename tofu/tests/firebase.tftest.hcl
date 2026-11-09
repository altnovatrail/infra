# Firebase, the Hosting site of app's build and the identity that publishes it, as R06 and R12
# decided them, checked against mock providers: no credential, no call to Google.

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

# Firebase in the project, and its default Hosting site under the project's id, which makes app's
# address <project>.web.app; the configuration never deletes it (R06).
run "the_site_is_the_projects_and_kept" {
  command = plan

  assert {
    condition     = google_firebase_hosting_site.app.site_id == "novatrail-test-0" && output.hosting_site == "novatrail-test-0"
    error_message = "The site is named after the project, so app's address is novatrail-test-0.web.app."
  }

  assert {
    condition     = google_firebase_hosting_site.app.deletion_policy == "PREVENT"
    error_message = "The configuration never deletes the site app's address is."
  }

  assert {
    condition     = google_firebase_project.this.project == "novatrail-test-0"
    error_message = "Firebase is given to the platform's project."
  }
}

# The publisher of app's build: lent to the jobs of production-hosting alone, holding Hosting's
# rights less the making and deleting of sites — bootstrap.sh's role hostingPublisher, whose
# permissions its test holds — and the reading of API keys, and nothing of api's nor of sign-in
# (R12). With api's service made too, and the publisher given an address of its own,
# so that a grant to it among api's would show.
run "the_publisher_holds_hosting_alone" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  override_resource {
    target = google_service_account.hosting
    values = {
      name  = "projects/novatrail-test-0/serviceAccounts/hosting-publish@novatrail-test-0.iam.gserviceaccount.com"
      email = "hosting-publish@novatrail-test-0.iam.gserviceaccount.com"
    }
  }

  assert {
    condition     = google_service_account.hosting.account_id == "hosting-publish"
    error_message = "The publisher is hosting-publish."
  }

  assert {
    condition     = google_service_account_iam_member.hosting_from_github.role == "roles/iam.workloadIdentityUser" && google_service_account_iam_member.hosting_from_github.member == "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/infra-github/subject/repo:example@1000/infra@2000:environment:production-hosting"
    error_message = "Only the jobs of the environment production-hosting may borrow the publisher's identity."
  }

  assert {
    condition     = toset([for g in google_project_iam_member.grants : g.role if g.member == "serviceAccount:hosting-publish@novatrail-test-0.iam.gserviceaccount.com"]) == toset(["projects/novatrail-test-0/roles/hostingPublisher", "roles/serviceusage.apiKeysViewer"])
    error_message = "On the project the publisher holds bootstrap.sh's role hostingPublisher and the reading of API keys, and no other role."
  }

  assert {
    condition = !contains(flatten([
      [for m in google_cloud_run_v2_service_iam_member.deployer : m.member],
      [for m in google_cloud_run_v2_service_iam_member.public : m.member],
      [for m in values(google_cloud_run_v2_job_iam_member.deployer) : m.member],
      [google_artifact_registry_repository_iam_member.deployer.member],
      [google_secret_manager_secret_iam_member.deployer_adds_facts.member],
      [google_secret_manager_secret_iam_member.api_reads_facts.member],
      [for m in values(google_secret_manager_secret_iam_member.api_reads_job_secrets) : m.member],
      [google_service_account_iam_member.deployer_runs_as_api.member],
    ]), "serviceAccount:hosting-publish@novatrail-test-0.iam.gserviceaccount.com")
    error_message = "The publisher holds no grant on api's service, jobs, registry, secrets or identity."
  }

  assert {
    condition     = google_service_account_iam_member.hosting_from_github.member != google_service_account_iam_member.deployer_from_github.member
    error_message = "The publisher and api's deployment are borrowed from different environments."
  }
}

run "a_hosting_environment_not_of_githubs_form_is_refused" {
  command = plan

  variables {
    hosting_environment = "production hosting"
  }

  expect_failures = [var.hosting_environment]
}

run "the_publisher_and_the_deployment_in_one_environment_are_refused" {
  command = plan

  variables {
    hosting_environment = "production"
  }

  expect_failures = [var.hosting_environment]
}

run "one_environment_in_another_case_is_refused" {
  command = plan

  variables {
    hosting_environment = "Production"
  }

  expect_failures = [var.hosting_environment]
}
