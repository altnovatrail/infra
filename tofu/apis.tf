# The APIs this project is allowed to use (R10). Service Usage and Resource Manager are not in the
# list: they are what enables the rest. bootstrap.sh turns them on before this configuration can be
# applied at all, and with them whatever it needs for what it creates itself — the state bucket,
# the federated pool CI signs in through and the custom roles, whose permissions are of Cloud Run,
# Firebase and sign-in (R13); those that the configuration stands on too are named here as well, because
# this is the list of what it stands on.
#
# Cloud Trace is not here: the platform writes no traces of its own. Google turns its API on in a
# new project, and Cloud Scheduler, which depends on it, keeps it on, so Cloud Run's own traces of
# some requests may come (R07, its third amendment of 2026-11-09).

locals {
  apis = [
    # The service of api and its jobs, and the schedule that starts the jobs that run by the clock
    # (R05).
    "run.googleapis.com",
    "cloudscheduler.googleapis.com",
    # The private registry the deployment pushes api's image to (R04, R05).
    "artifactregistry.googleapis.com",
    # The keys api reads and the file of deployment facts its revision mounts (R04, R05).
    "secretmanager.googleapis.com",
    # The identity a deployment arrives as: a federated pool, the token exchange that turns a
    # GitHub token into a Google one, and the impersonation that follows.
    "iam.googleapis.com",
    "sts.googleapis.com",
    "iamcredentials.googleapis.com",
    # Firebase in the project, and the Hosting site the app's build is served from (R06).
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    # Sign-in: Identity Platform, which Firebase Authentication runs on, and whose settings the
    # configuration holds (R16).
    "identitytoolkit.googleapis.com",
    # The spend alert, and the alerts on Cloud Run's built-in metrics (R06, R07).
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    # Where the logs are kept, and the observability bucket _Trace is created through, in the
    # region, before any trace (R04, R07).
    "logging.googleapis.com",
    "observability.googleapis.com",
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
