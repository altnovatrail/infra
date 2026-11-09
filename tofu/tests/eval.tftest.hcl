# The platform's keys for eval and who reads them, as R120 spec and R20 have it, checked against
# mock providers: no credential, no call to Google. The values are synthetic, apart from the
# subjects of modules and tutor, which are public.

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

  mock_resource "google_secret_manager_secret" {
    defaults = {
      id = "projects/novatrail-test-0/secrets/eval-key-mock"
    }
  }
}

mock_provider "google-beta" {}

# The variables every run starts from are in tests/terraform.tfvars.

# A copy that names no repository has no eval: no secret, no grant, nothing to hand anybody.
run "no_repository_no_eval" {
  command = plan

  assert {
    condition     = length(google_secret_manager_secret.eval) == 0 && length(google_secret_manager_secret_iam_member.eval_reads) == 0
    error_message = "With no repository of eval, there is no secret of eval and no grant."
  }

  assert {
    condition     = output.eval_access == null
    error_message = "With no eval, there is nothing to hand modules and tutor."
  }
}

# The platform's: a secret a provider, in the region alone, let go rather than deleted, each read by
# the jobs of the environment eval of modules and tutor alone.
run "the_platforms_keys_are_read_by_the_eval_jobs_of_modules_and_tutor" {
  command = apply

  variables {
    eval_github_subject_prefixes = [
      "repo:altnovatrail@344507087/modules@1425775415",
      "repo:altnovatrail@344507087/tutor@1425813274",
    ]
  }

  assert {
    condition     = toset([for s in google_secret_manager_secret.eval : s.secret_id]) == toset(["eval-key-anthropic", "eval-key-openai"])
    error_message = "A secret for each provider of eval: eval-key-anthropic and eval-key-openai."
  }

  assert {
    condition = alltrue([for s in google_secret_manager_secret.eval :
      length(s.replication[0].user_managed[0].replicas) == 1 && s.replication[0].user_managed[0].replicas[0].location == "us-east4" && length(s.replication[0].auto) == 0
    ])
    error_message = "Each secret of eval is replicated to the region alone, not automatically."
  }

  assert {
    condition     = alltrue([for s in google_secret_manager_secret.eval : s.deletion_policy == "ABANDON" && s.labels.purpose == "eval-key"])
    error_message = "A secret of eval the list stops naming is let go, not deleted."
  }

  assert {
    condition = toset([for g in google_secret_manager_secret_iam_member.eval_reads : g.member]) == toset([
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-eval/subject/repo:altnovatrail@344507087/modules@1425775415:environment:eval",
      "principal://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-eval/subject/repo:altnovatrail@344507087/tutor@1425813274:environment:eval",
    ])
    error_message = "The secrets of eval are read by the jobs of the environment eval of modules and tutor, through the pool github-eval, and by nobody else."
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.eval_reads) == 4 && alltrue([for g in google_secret_manager_secret_iam_member.eval_reads : g.role == "roles/secretmanager.secretAccessor"])
    error_message = "Each of the two secrets is read by each of the two repositories, with secretAccessor alone."
  }

  assert {
    condition     = output.eval_access.workload_identity_provider == "projects/123456789012/locations/global/workloadIdentityPools/github-eval/providers/github" && toset(keys(output.eval_access.secrets)) == toset(["anthropic", "openai"])
    error_message = "eval_access names the provider of the pool github-eval and the secrets by provider."
  }
}

# The pool's id is bootstrap.sh's: the principals name the pool it makes.
run "the_pool_is_bootstraps" {
  command = plan

  assert {
    condition     = local.eval_pool == regex("(?m)^eval_pool=([a-z0-9-]+)$", file("bootstrap.sh"))[0]
    error_message = "The pool of eval the grants name is the one bootstrap.sh makes."
  }

  assert {
    condition     = local.eval_provider == regex("(?m)^GCP_EVAL_WORKLOAD_IDENTITY_PROVIDER=projects/\\$\\{project_number\\}/locations/global/workloadIdentityPools/\\$\\{eval_pool\\}/providers/([a-z0-9-]+)$", file("bootstrap.sh"))[0]
    error_message = "The provider eval_access names is the one bootstrap.sh prints."
  }
}

run "a_subject_not_of_its_form_is_refused" {
  command = plan

  variables {
    eval_github_subject_prefixes = ["altnovatrail/modules"]
  }

  expect_failures = [var.eval_github_subject_prefixes]
}

run "repositories_of_two_owners_are_refused" {
  command = plan

  variables {
    eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415", "repo:other@1/tutor@2"]
  }

  expect_failures = [var.eval_github_subject_prefixes]
}

run "a_provider_code_not_of_the_table_form_is_refused" {
  command = plan

  variables {
    eval_providers = ["Anthropic"]
  }

  expect_failures = [var.eval_providers]
}

run "the_configurations_pool_named_as_evals_is_refused" {
  command = plan

  variables {
    workload_identity_pool_id = "github-eval"
  }

  expect_failures = [var.workload_identity_pool_id]
}

# Repositories with no provider of eval still have the pool's provider to sign in with: the output
# says so, with no secret.
run "repositories_with_no_provider_have_the_pool_and_no_secret" {
  command = plan

  variables {
    eval_github_subject_prefixes = ["repo:altnovatrail@344507087/modules@1425775415"]
    eval_providers               = []
  }

  assert {
    condition     = length(google_secret_manager_secret.eval) == 0 && output.eval_access.secrets == {}
    error_message = "With no provider of eval there is no secret, and eval_access says so."
  }
}
