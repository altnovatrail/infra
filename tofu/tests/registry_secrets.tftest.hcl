# The registry of images and the secret of api's deployment facts as R04 and R05 decided them,
# checked against mock providers: no credential, no call to Google. The values are synthetic.

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


# One repository of Docker images, in the region, never deleted by the configuration: the serving
# revision's image is in it (R04, R05).
run "the_registry_is_in_the_region_and_kept" {
  command = plan

  assert {
    condition     = google_artifact_registry_repository.images.location == "us-east4" && google_artifact_registry_repository.images.format == "DOCKER"
    error_message = "The repository holds Docker images, in the region."
  }

  assert {
    condition     = google_artifact_registry_repository.images.deletion_policy == "PREVENT"
    error_message = "The configuration never deletes the repository."
  }

  assert {
    condition     = google_artifact_registry_repository.images.repository_id == "images"
    error_message = "The repository is images."
  }
}

# The cleanup keeps the most recent images whatever their state, and deletes only versions with no
# tag past their age: the serving image keeps its release's tag, however many pushes come after it.
run "the_cleanup_keeps_the_recent_and_deletes_the_old" {
  command = plan

  assert {
    condition     = google_artifact_registry_repository.images.cleanup_policy_dry_run == false
    error_message = "The cleanup deletes, rather than only reporting what it would."
  }

  assert {
    condition = anytrue([for p in google_artifact_registry_repository.images.cleanup_policies :
      p.action == "KEEP" && p.most_recent_versions[0].keep_count == 5
    ])
    error_message = "The five most recent versions are kept."
  }

  assert {
    condition = anytrue([for p in google_artifact_registry_repository.images.cleanup_policies :
      p.action == "DELETE" && p.condition[0].older_than == "30d" && p.condition[0].tag_state == "UNTAGGED"
    ])
    error_message = "Versions with no tag older than 30 days are deleted, unless they are among the most recent."
  }

  assert {
    condition = alltrue([for p in google_artifact_registry_repository.images.cleanup_policies :
      p.condition[0].tag_state == "UNTAGGED" if p.action == "DELETE"
    ])
    error_message = "No delete policy reaches a tagged version: the serving image has its release's tag."
  }
}

run "keeping_no_image_is_refused" {
  command = plan

  variables {
    keep_images = 0
  }

  expect_failures = [var.keep_images]
}

run "an_age_in_hours_is_taken" {
  command = plan

  variables {
    image_max_age = "720h"
  }

  assert {
    condition     = anytrue([for p in google_artifact_registry_repository.images.cleanup_policies : p.action == "DELETE" && p.condition[0].older_than == "720h"])
    error_message = "An age in hours is taken, as Artifact Registry takes it."
  }
}

run "an_age_not_of_artifact_registrys_form_is_refused" {
  command = plan

  variables {
    image_max_age = "30 days"
  }

  expect_failures = [var.image_max_age]
}

# The facts' secret keeps its replicas in the region alone, and no value comes with it: the
# deployment adds each version (R04, R05).
run "the_facts_secret_stays_in_the_region_without_a_value" {
  command = plan

  assert {
    condition     = google_secret_manager_secret.admission_facts.secret_id == "api-admission-facts" && output.admission_facts_secret == "api-admission-facts"
    error_message = "The secret of api's deployment facts is api-admission-facts."
  }

  assert {
    condition = length(google_secret_manager_secret.admission_facts.replication[0].auto) == 0 && [
      for r in google_secret_manager_secret.admission_facts.replication[0].user_managed[0].replicas : r.location
    ] == ["us-east4"]
    error_message = "The secret is replicated by choice, to the region alone, never automatically."
  }

  assert {
    condition     = google_secret_manager_secret.admission_facts.deletion_protection == true
    error_message = "The configuration never deletes the secret the serving revision mounts."
  }
}

# Another region moves them both: nothing names us-east4 but the variable.
run "another_region_moves_the_registry_and_the_secret" {
  command = plan

  variables {
    region = "europe-west1"
  }

  assert {
    condition = google_artifact_registry_repository.images.location == "europe-west1" && [
      for r in google_secret_manager_secret.admission_facts.replication[0].user_managed[0].replicas : r.location
    ] == ["europe-west1"]
    error_message = "The repository and the secret's replica are in the region given."
  }
}
