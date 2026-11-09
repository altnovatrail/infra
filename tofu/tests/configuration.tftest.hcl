# The configuration's own rules, checked against mock providers: nothing here signs in anywhere or
# reads a deployment, so the tests run in tf-check and in CI with no credential at all (R10). Both
# providers are mocked; a provider left out would be the real one, and a plan with it would call
# Google. The values below are synthetic: the platform's own come when its project is created.

mock_provider "google" {}

mock_provider "google-beta" {}

variables {
  project_id = "novatrail-test-0"
  region     = "us-east4"
}

# The APIs on are exactly those the parts of the configuration stand on — one more is a change
# made on purpose, here as well — and none is switched off when its resource goes: switching one
# off would break whatever else still uses it.
run "the_apis_the_parts_need_are_on" {
  command = plan

  assert {
    condition = toset(keys(google_project_service.enabled)) == toset([
      "run.googleapis.com",
      "cloudscheduler.googleapis.com",
      "artifactregistry.googleapis.com",
      "secretmanager.googleapis.com",
      "iam.googleapis.com",
      "sts.googleapis.com",
      "iamcredentials.googleapis.com",
      "firebase.googleapis.com",
      "firebasehosting.googleapis.com",
      "billingbudgets.googleapis.com",
      "monitoring.googleapis.com",
      "logging.googleapis.com",
      "observability.googleapis.com",
    ])
    error_message = "The APIs on are not exactly those the parts stand on."
  }

  assert {
    condition     = alltrue([for s in google_project_service.enabled : s.disable_on_destroy == false])
    error_message = "No API is switched off when its resource is destroyed."
  }

  assert {
    condition     = output.project_id == "novatrail-test-0" && output.region == "us-east4"
    error_message = "The outputs name the project and the region given."
  }
}

# With Cloud Trace's API off, no trace is written: the first slice keeps none (R07).
run "cloud_trace_stays_off" {
  command = plan

  assert {
    condition     = length([for api in keys(google_project_service.enabled) : api if strcontains(api, "trace")]) == 0
    error_message = "No API whose name speaks of traces, Cloud Trace's among them, is turned on."
  }
}

# A project id is 6 to 30 characters, lowercase letters, digits and hyphens, starting with a letter
# and not ending with a hyphen: both ends of the length are taken, and each rule is refused alone.
run "a_project_id_of_6_characters_is_taken" {
  command = plan

  variables {
    project_id = "abcdef"
  }

  assert {
    condition     = output.project_id == "abcdef"
    error_message = "A project id of 6 characters is taken."
  }
}

run "a_project_id_of_30_characters_is_taken" {
  command = plan

  variables {
    project_id = "a23456789012345678901234567890"
  }

  assert {
    condition     = output.project_id == "a23456789012345678901234567890"
    error_message = "A project id of 30 characters is taken."
  }
}

run "a_project_id_of_5_characters_is_refused" {
  command = plan

  variables {
    project_id = "abcde"
  }

  expect_failures = [var.project_id]
}

run "a_project_id_of_31_characters_is_refused" {
  command = plan

  variables {
    project_id = "a234567890123456789012345678901"
  }

  expect_failures = [var.project_id]
}

run "a_project_id_starting_with_a_digit_is_refused" {
  command = plan

  variables {
    project_id = "1novatrail"
  }

  expect_failures = [var.project_id]
}

run "a_project_id_with_an_uppercase_letter_is_refused" {
  command = plan

  variables {
    project_id = "Novatrail-prod"
  }

  expect_failures = [var.project_id]
}

run "a_project_id_with_an_underscore_is_refused" {
  command = plan

  variables {
    project_id = "novatrail_prod"
  }

  expect_failures = [var.project_id]
}

run "a_project_id_ending_in_a_hyphen_is_refused" {
  command = plan

  variables {
    project_id = "novatrail-prod-"
  }

  expect_failures = [var.project_id]
}

run "a_region_not_of_googles_form_is_refused" {
  command = plan

  variables {
    region = "US East"
  }

  expect_failures = [var.region]
}
