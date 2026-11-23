# The keys for eval are read by the jobs of the GitHub environment eval straight through the pool
# github-eval, with no service account between and no long-lived copy in GitHub.
#
# The pool and its provider, with the condition that admits those jobs alone, are bootstrap.sh's,
# not the module's: no IAM condition narrows a right over pools to one of
# them, so the right to make this pool would be the right to change the pool this configuration is
# applied through.

locals {
  # The ids bootstrap.sh gives the pool and its provider, and the environment of the eval jobs.
  eval_pool        = "github-eval"
  eval_provider    = "github"
  eval_environment = "eval"

  eval_secrets = length(var.eval_github_subject_prefixes) > 0 ? toset(var.eval_providers) : toset([])

  eval_readers = [
    for prefix in var.eval_github_subject_prefixes :
    "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${local.eval_pool}/subject/${prefix}:environment:${local.eval_environment}"
  ]

  eval_grants = {
    for pair in setproduct(local.eval_secrets, local.eval_readers) : "${pair[0]} ${pair[1]}" => {
      provider = pair[0]
      member   = pair[1]
    }
  }
}

resource "google_secret_manager_secret_iam_member" "eval_reads" {
  for_each = local.eval_grants

  secret_id = google_secret_manager_secret.eval[each.value.provider].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
