# The APIs this configuration stands on. Service Usage and Resource Manager are not in the
# list: they enable the rest, so bootstrap.sh turns them on before the first apply, with whatever its
# own resources need; those this configuration needs too are named here as well.
#
# Cloud Trace is not here: the platform writes no traces of its own, but Google turns its API on in
# a new project and Cloud Scheduler, which depends on it, keeps it on, so Cloud Run's own traces of
# some requests may come.

locals {
  apis = [
    # The service of api and its jobs, and the schedule that starts the jobs that run by the clock.
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    # The private registry the deployment pushes api's image to.
    "artifactregistry.googleapis.com",
    # The keys api reads and the file of deployment facts its revision mounts.
    "secretmanager.googleapis.com",
    # The identity a deployment arrives as: a federated pool, the token exchange that turns a
    # GitHub token into a Google one, and the impersonation that follows.
    "iam.googleapis.com",
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    # Firebase in the project, and the Hosting site the app's build is served from.
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    # Sign-in: Identity Platform, which Firebase Authentication runs on, and whose settings the
    # configuration holds.
    "identitytoolkit.googleapis.com",
    # The spend alert, and the alerts on Cloud Run's built-in metrics.
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    # Where the logs are kept, and the observability bucket _Trace is created through, in the
    # region, before any trace.
    "logging.googleapis.com",
    "observability.googleapis.com",
    # The project's contact for Google's security notifications.
    "essentialcontacts.googleapis.com",
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.apis)

  service = each.value

  # Switching an API off is not the opposite of switching it on: it would break whatever else in
  # the project still uses it, and the resources that needed it here are gone by the time this
  # would run.
  disable_on_destroy = false
}
