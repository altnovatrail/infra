# The configuration against what bootstrap.sh lets the identity that applies it do (R13): a role
# granted here and not let there would pass every other check and be refused at the apply, after
# the merge. Read from the script itself, as canvas-api's test does, so that the two change
# together and the script is run again before the merge.

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

# The variables every run starts from are in tests/terraform.tfvars. What the script says is read
# out of it here: the ids of its two roles, and the roles its condition lets the configuration's
# identity grant on the project, with the shell's ${project} and ${publisher_role} put in.

variables {
  bootstrap_deployer_role  = regex("(?m)^deployer_role=([A-Za-z]+)$", file("bootstrap.sh"))[0]
  bootstrap_publisher_role = regex("(?m)^publisher_role=([A-Za-z]+)$", file("bootstrap.sh"))[0]
  bootstrap_grantable = [
    for role in regexall("'([^']+)'", regex("hasOnly\\(\\[([^\\]]*)\\]\\)", file("bootstrap.sh"))[0]) :
    replace(replace(role[0], "$${project}", "novatrail-test-0"), "$${publisher_role}", regex("(?m)^publisher_role=([A-Za-z]+)$", file("bootstrap.sh"))[0])
  ]
}

# The roles granted on the project are those the condition of the identity's IAM admin lets it
# grant, and no other.
run "the_project_grants_are_what_bootstrap_lets_the_configuration_grant" {
  command = plan

  assert {
    condition     = toset([for m in google_project_iam_member.hosting : m.role]) == toset(var.bootstrap_grantable)
    error_message = "The roles granted on the project are the ones the condition in bootstrap.sh lets the configuration's identity grant: change both together, and run bootstrap.sh again before the merge."
  }
}

# The custom roles the configuration grants are the ones bootstrap.sh makes, by the names IAM gives
# them.
run "the_custom_roles_granted_are_bootstraps" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = google_cloud_run_v2_service_iam_member.deployer[0].role == "projects/${var.project_id}/roles/${var.bootstrap_deployer_role}"
    error_message = "The deployment's role on api's service is the one bootstrap.sh makes."
  }

  assert {
    condition     = google_project_iam_member.hosting["hosting"].role == "projects/${var.project_id}/roles/${var.bootstrap_publisher_role}"
    error_message = "The publisher's role on the project is the one bootstrap.sh makes."
  }
}

# The environment whose jobs borrow the configuration's identity is bootstrap.sh's, and neither api's
# deployment nor the publisher of app's build is lent to it, in any case of letters.
run "the_deployment_in_the_configurations_environment_is_refused" {
  command = plan

  variables {
    deploy_environment = upper(regex("(?m)^config_environment=\"([A-Za-z0-9_.-]+)\"$", file("bootstrap.sh"))[0])
  }

  expect_failures = [var.deploy_environment]
}

run "the_publisher_in_the_configurations_environment_is_refused" {
  command = plan

  variables {
    hosting_environment = regex("(?m)^config_environment=\"([A-Za-z0-9_.-]+)\"$", file("bootstrap.sh"))[0]
  }

  expect_failures = [var.hosting_environment]
}
