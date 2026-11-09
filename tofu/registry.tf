# The private registry the deployment pushes the services' images to, by digest, and Cloud Run
# pulls them from (R05; R105 spec). It is closed: nothing here makes it readable outside the
# project. Cloud Run's own service agent reads a repository of its project, and the deployment's
# identity is given the right to push in the task that creates it (T15). In the region, as a
# repository's place never changes once it is made (R04).

resource "google_artifact_registry_repository" "images" {
  location      = var.region
  repository_id = "images"
  format        = "DOCKER"
  description   = "The images of the platform's services, built by the deployment from the files of their releases."

  # Storage is the one thing here that grows by itself, so the repository is told what to forget.
  # The deployment pushes each release's image with the release's tag (T19), and only versions with
  # no tag are ever deleted: the serving image keeps its tag, so it stays however many pushes after
  # it failed, and a change of facts or rung can roll a new revision on it by its digest (R05).
  # What loses its tag is a push the same release made again. The most recent few stay whatever
  # their state: a version that matches a keep policy and a delete policy is kept.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = var.keep_images
    }
  }

  # Versions with no tag go once they are older than the age given.
  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = var.image_max_age
    }
  }

  # A policy that only reports what it would delete deletes nothing.
  cleanup_policy_dry_run = false

  # The serving revision's image is here: the configuration never deletes the repository, not by a
  # destroy and not by a change of region, which would be such a delete.
  deletion_policy = "PREVENT"

  depends_on = [google_project_service.enabled]
}
