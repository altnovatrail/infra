# Firebase in the project, and the Hosting site app's build is served from (R06, R12). Both
# resources are in the beta provider alone. Sign-in in this project is sign_in.tf's (R16).
#
# The export of Hosting's request logs to Cloud Logging is switched on only by a button in
# Firebase's console, and nothing here switches it on. Every sink excludes those logs all the same
# (logging.tf), since they hold the client's address (R07).

resource "google_firebase_project" "this" {
  provider = google-beta

  project = var.project_id

  depends_on = [google_project_service.enabled]
}

# Named after the project, which makes app's address https://<project>.web.app. Either way it ends
# up the project's default site: a project given Firebase after 2026-10-15 gets no site until one
# is made, and the first one made becomes the default; one given Firebase before that date got its
# default site at once, under the project's id, and this resource takes that site over rather than
# making it again (Firebase, Understand the default Hosting site: "The first Hosting site created in
# your Firebase project always becomes your default Hosting site"; canvas-api).
resource "google_firebase_hosting_site" "app" {
  provider = google-beta

  site_id = var.project_id

  # app's address is this site's: the configuration never deletes it.
  deletion_policy = "PREVENT"

  depends_on = [google_firebase_project.this]
}

# The Firebase web app app signs in as: its id and its API key are what /deployment.json names in
# signIn, with the project and its authDomain (R09 app; R17). Firebase makes the key itself, a
# browser key restricted to Firebase's APIs, and it is no secret: it is in every copy of app. The
# configuration never deletes the app, since a new one would come with a new key, and a new key
# signs everybody out of app on every device (architecture 3.7 app).
resource "google_firebase_web_app" "app" {
  provider = google-beta

  project      = var.project_id
  display_name = "app"

  deletion_policy = "PREVENT"

  depends_on = [google_firebase_project.this]
}

data "google_firebase_web_app_config" "app" {
  provider = google-beta

  project    = var.project_id
  web_app_id = google_firebase_web_app.app.app_id
}
