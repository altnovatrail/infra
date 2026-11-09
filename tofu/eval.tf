# Who reads the platform's keys for eval, the secrets eval-key-<provider> of secrets.tf: the jobs of
# the GitHub environment eval of modules and tutor, through the federated pool github-eval, with no
# service account between and no long-lived copy in GitHub (R120 spec).
#
# The pool and its provider are not described here, though R120 spec put them in the module: no
# condition of IAM narrows a right over pools to one of them, so the right to make this pool would
# be the right to change the pool this configuration is applied through. bootstrap.sh makes both,
# with R120's condition, as it makes its own (R13; R20).

locals {
  # The pool bootstrap.sh makes and its provider, by their ids there, and the environment R120 spec
  # names.
  eval_pool        = "github-eval"
  eval_provider    = "github"
  eval_environment = "eval"

  eval_secrets = length(var.eval_github_subject_prefixes) > 0 ? toset(var.eval_providers) : toset([])

  # Each repository's jobs of the environment eval, by the subject GitHub gives them.
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
