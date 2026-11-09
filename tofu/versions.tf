# What this configuration is pinned to, and where its state lives (R10).
#
# OpenTofu at the exact version the toolchain stage of .devcontainer/Dockerfile installs (R09):
# a raise of the ARG there without this line stops `tofu init`, so the two move together.
#
# Two providers at one version. Firebase's resources are in the beta provider alone, and the two
# are released together, so they move together: Dependabot raises them as one group. The lock file
# holds the hashes of every platform a provider's release ships, as the registry gives them.
#
# The state bucket is not created here and cannot be: a backend has to exist before the
# configuration that would create it is read. bootstrap.sh makes it once, and the backend's
# settings are given at init time.

terraform {
  required_version = "1.13.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.10.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "8.10.0"
    }
  }

  backend "gcs" {}
}

# Every request is counted against this project, whatever project the caller's own credentials
# name. The budget's API and Firebase's refuse a caller that signs in as a person otherwise, as a
# plan run by hand does. It takes Service Usage enabled in the project, which bootstrap.sh does
# before anything here runs.
provider "google" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
