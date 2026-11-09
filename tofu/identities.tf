# The identities of api and of its deployment, and the narrow rights each holds (R11).
#
# The pool a deployment's tokens are exchanged in is not described here. It is what this
# configuration itself is applied through, and a door is not built by whoever walks in by it: the
# pool, its provider and the identity that applies the configuration are made once, from outside,
# by bootstrap.sh (T17), and named here by id.
#
# The deployment's identity is lent to the jobs of one GitHub environment, by the subject GitHub
# gives such a job, which names the environment: infra's workflow of the deployment alone, never a
# component's repository, which has no access to production (R106 spec).

locals {
  # Everybody whose token carries the repository's subject, ready for its environment.
  github_subject = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}/subject/${var.github_oidc_subject_prefix}"
}

# What api runs as, in the service and in its jobs: it reads its secrets, and nothing more yet.
# Each grant comes with what first uses it.
resource "google_service_account" "api" {
  account_id   = "${var.api_service_name}-run"
  display_name = "Runtime identity of ${var.api_service_name}"

  depends_on = [google_project_service.enabled]
}

resource "google_secret_manager_secret_iam_member" "api_reads_facts" {
  secret_id = google_secret_manager_secret.admission_facts.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_reads_job_secrets" {
  for_each = google_secret_manager_secret.api_job

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# How a deployment gets in: an identity with just enough rights for the steps of R05, borrowed by
# the jobs of the environment that deploys. No service account key exists anywhere.
resource "google_service_account" "deployer" {
  account_id   = "${var.api_service_name}-deploy"
  display_name = "Deployment identity of ${var.api_service_name}"

  depends_on = [google_project_service.enabled]
}

resource "google_service_account_iam_member" "deployer_from_github" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_subject}:environment:${var.deploy_environment}"
}

# Push api's image into the one repository,
resource "google_artifact_registry_repository_iam_member" "deployer" {
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

# add a version of the deployment facts, and only of that secret,
resource "google_secret_manager_secret_iam_member" "deployer_adds_facts" {
  secret_id = google_secret_manager_secret.admission_facts.id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = "serviceAccount:${google_service_account.deployer.email}"
}

# run the jobs with the new image and roll a revision of the one service — and only those. The
# ready-made developer role carries far more, deleting the service among it; a deployment needs
# these. They are granted on the service and on each job; canvas-api's deployment ran on such grants,
# run.operations.get among them, and the first deployment shows it here too (T24).
resource "google_project_iam_custom_role" "deployer" {
  role_id     = "${replace(var.api_service_name, "-", "")}Deployer"
  title       = "Deploys ${var.api_service_name}"
  description = "Reads the service and its jobs, sets the image of each, runs the jobs and rolls a new revision. Nothing else."

  permissions = local.deployer_permissions

  depends_on = [google_project_service.enabled]
}

locals {
  deployer_permissions = [
    "run.services.get",
    "run.services.update",
    "run.revisions.get",
    "run.revisions.list",
    "run.operations.get",
    "run.jobs.get",
    "run.jobs.update",
    "run.jobs.run",
    "run.jobs.runWithOverrides",
    "run.executions.get",
    "run.executions.list",
  ]
}

resource "google_cloud_run_v2_service_iam_member" "deployer" {
  count = local.api_serving ? 1 : 0

  location = google_cloud_run_v2_service.api[0].location
  name     = google_cloud_run_v2_service.api[0].name
  role     = google_project_iam_custom_role.deployer.name
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_cloud_run_v2_job_iam_member" "deployer" {
  for_each = google_cloud_run_v2_job.api

  location = each.value.location
  name     = each.value.name
  role     = google_project_iam_custom_role.deployer.name
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# and let that revision and those jobs run as api. Nothing wider: it cannot make or delete services,
# change who may call them, or read a secret by itself. What runs as api reads api's secrets, so an
# identity that may set the image api runs may reach them that way: the deployment is trusted with
# what api is, and its door is one environment of one repository.
resource "google_service_account_iam_member" "deployer_runs_as_api" {
  service_account_id = google_service_account.api.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# The publisher of app's build on Hosting, and nothing else (R12). Its job runs a large program of
# somebody else's, the Firebase CLI, so it has an environment and an identity of its own and
# reaches neither api, nor this configuration, nor the settings of sign-in: who puts
# <project>.web.app among the authorized domains is decided with sign-in in production (T27).
resource "google_service_account" "hosting" {
  account_id   = "hosting-publish"
  display_name = "Publishes app's build on Firebase Hosting"

  depends_on = [google_project_service.enabled]
}

resource "google_service_account_iam_member" "hosting_from_github" {
  service_account_id = google_service_account.hosting.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_subject}:environment:${var.hosting_environment}"
}

# Hosting takes no grant on a site, so its rights are on the project. The ready-made Firebase
# Hosting Admin role, less the making and the deleting of sites: a release goes through
# firebasehosting.sites.update, and the site app's address is stays out of the CLI's reach.
resource "google_project_iam_custom_role" "hosting" {
  role_id     = "hostingPublisher"
  title       = "Publishes app's build"
  description = "Reads the project and its Hosting sites and releases new versions of them. It makes and deletes no site."

  permissions = local.hosting_permissions

  depends_on = [google_project_service.enabled]
}

# The project's Hosting rights, and the reading of its API keys, which the CLI's deploy asks for
# (canvas-api).
resource "google_project_iam_member" "hosting" {
  # By keys known before any apply: the custom role's name is known only once the role is made.
  for_each = local.hosting_project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.hosting.email}"
}

locals {
  hosting_permissions = [
    "firebase.clients.get",
    "firebase.clients.list",
    "firebase.projects.get",
    "firebasehosting.sites.get",
    "firebasehosting.sites.list",
    "firebasehosting.sites.update",
    "resourcemanager.projects.get",
    "resourcemanager.projects.list",
  ]

  hosting_project_roles = {
    hosting  = google_project_iam_custom_role.hosting.name
    api_keys = "roles/serviceusage.apiKeysViewer"
  }
}
