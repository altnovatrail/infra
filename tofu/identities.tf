# The identities of api and of its deployment, and the narrow rights each holds (R11).
#
# The pool a deployment's tokens are exchanged in is not described here. It is what this
# configuration itself is applied through, and a door is not built by whoever walks in by it: the
# pool, its provider and the identity that applies the configuration are made once, from outside,
# by bootstrap.sh, and named here by id (R13).
#
# Nor are the two custom roles below, the deployment's and the publisher's: bootstrap.sh makes
# them and holds their permissions, and the configuration grants them by name. The identity that
# applies the configuration may grant the publisher's role on the project, and IAM's limit on such
# a grant holds only while that identity cannot change the role itself, so it holds no right to
# change any role (R13).
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
# the eleven permissions of bootstrap.sh's role apiDeployer. It is granted on the service and on
# each job; canvas-api's deployment ran on such grants, run.operations.get among them, and the
# first deployment shows it here too (T24).
resource "google_cloud_run_v2_service_iam_member" "deployer" {
  count = local.api_serving ? 1 : 0

  location = google_cloud_run_v2_service.api[0].location
  name     = google_cloud_run_v2_service.api[0].name
  role     = local.deployer_role
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_cloud_run_v2_job_iam_member" "deployer" {
  for_each = google_cloud_run_v2_job.api

  location = each.value.location
  name     = each.value.name
  role     = local.deployer_role
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

# Hosting takes no grant on a site, so its rights are on the project: bootstrap.sh's role
# hostingPublisher, the ready-made Firebase Hosting Admin less the making and the deleting of
# sites — a release goes through firebasehosting.sites.update, and the site app's address is stays
# out of the CLI's reach — and the reading of API keys, which the CLI's deploy asks for
# (canvas-api). These two are all the configuration may grant on the project: the condition
# bootstrap.sh puts on that right names the same two, and a test holds them together.
resource "google_project_iam_member" "hosting" {
  for_each = local.hosting_project_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.hosting.email}"
}

locals {
  # The custom roles bootstrap.sh makes, by the names IAM gives them.
  deployer_role = "projects/${var.project_id}/roles/apiDeployer"
  hosting_role  = "projects/${var.project_id}/roles/hostingPublisher"

  hosting_project_roles = {
    hosting  = local.hosting_role
    api_keys = "roles/serviceusage.apiKeysViewer"
  }
}
