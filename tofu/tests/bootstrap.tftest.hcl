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
# out of it here: the ids of its three roles, the value it reads the scans' bucket from and the
# prefix it grants api's service account its right under there, and the roles its condition lets the
# configuration's identity grant on the project, as the script writes them; the run puts the shell's
# ${project}, ${publisher_role} and ${sign_in_role} in.

variables {
  bootstrap_deployer_role        = regex("(?m)^deployer_role=([A-Za-z]+)$", file("bootstrap.sh"))[0]
  bootstrap_publisher_role       = regex("(?m)^publisher_role=([A-Za-z]+)$", file("bootstrap.sh"))[0]
  bootstrap_sign_in_role         = regex("(?m)^sign_in_role=([A-Za-z]+)$", file("bootstrap.sh"))[0]
  bootstrap_consent_forms_value  = regex("(?m)^consent_forms_bucket=\"\\$\\(hcl_value ([a-z_]+) \"\\$tfvars\"\\)\"$", file("bootstrap.sh"))[0]
  bootstrap_consent_forms_prefix = regex("under \"\\$consent_forms_bucket\" ([^)[:space:]]+)\\)", file("bootstrap.sh"))[0]
  bootstrap_grantable = [
    for role in regexall("'([^']+)'", regex("hasOnly\\(\\[([^\\]]*)\\]\\)", file("bootstrap.sh"))[0]) : role[0]
  ]
}

# The roles granted on the project are those the condition of the identity's IAM admin lets it
# grant, and no other. Every grant on the project is in google_project_iam_member.grants, and
# tf-check refuses one declared anywhere else.
run "the_project_grants_are_what_bootstrap_lets_the_configuration_grant" {
  command = plan

  assert {
    condition = toset([for g in google_project_iam_member.grants : g.role]) == toset([
      for role in var.bootstrap_grantable :
      replace(replace(replace(role, "$${project}", var.project_id), "$${publisher_role}", var.bootstrap_publisher_role), "$${sign_in_role}", var.bootstrap_sign_in_role)
    ])
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
    condition     = google_project_iam_member.grants["hosting"].role == "projects/${var.project_id}/roles/${var.bootstrap_publisher_role}"
    error_message = "The publisher's role on the project is the one bootstrap.sh makes."
  }

  assert {
    condition     = google_project_iam_member.grants["api_sign_in"].role == "projects/${var.project_id}/roles/${var.bootstrap_sign_in_role}"
    error_message = "api's role of sign-in on the project is the one bootstrap.sh makes."
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

# The buckets bootstrap.sh makes for the operator are named in the values both read, and the module
# takes them in the form the script does, and not one bucket for both (R28).
run "a_bucket_name_of_another_form_is_refused" {
  command = plan

  variables {
    operator_bucket = "Novatrail-Operator"
  }

  expect_failures = [var.operator_bucket]
}

run "one_bucket_for_the_files_and_the_scans_is_refused" {
  command = plan

  variables {
    consent_forms_bucket = "novatrail-test-0-operator"
  }

  expect_failures = [var.consent_forms_bucket]
}

# The scans' bucket grants api's service account by the name the module gives it: bootstrap.sh
# takes the default of api_service_name where the values leave it out, and that default is the
# module's own.
run "bootstraps_api_account_is_the_modules" {
  command = plan

  assert {
    condition     = google_service_account.api.account_id == "${regex("(?m)^api_service_name=\"\\$\\{api_service_name:-([a-z0-9-]+)\\}\"$", file("bootstrap.sh"))[0]}-run"
    error_message = "The service account bootstrap.sh grants in the scans' bucket, by the default name of api's service, is the one the module makes."
  }
}

# api is told the bucket bootstrap.sh makes for the scans, which both read from the same value, and
# the prefix under which the script grants api's service account its right there: another prefix
# would put every scan where api may not write (R28).
run "the_scans_bucket_and_prefix_are_bootstraps" {
  command = plan

  variables {
    api_serving = true
    api_image   = "us-east4-docker.pkg.dev/novatrail-test-0/images/api@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition = alltrue([for env in [google_cloud_run_v2_service.api[0].template[0].containers[0].env, google_cloud_run_v2_job.api["sweep"].template[0].template[0].containers[0].env] :
      one([for e in env : e.value if e.name == "API_CONSENT_FORMS_BUCKET"]) == var.consent_forms_bucket &&
      one([for e in env : e.value if e.name == "API_CONSENT_FORMS_PREFIX"]) == var.bootstrap_consent_forms_prefix
    ])
    error_message = "api's service and sweep are told the scans' bucket of the values and the prefix bootstrap.sh grants api's service account its right under: change both together, and run bootstrap.sh again before the merge."
  }

  assert {
    condition     = var.bootstrap_consent_forms_value == "consent_forms_bucket"
    error_message = "bootstrap.sh reads the scans' bucket from the value consent_forms_bucket, the one the module names to api."
  }
}
