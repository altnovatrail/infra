# What a person, or a deployment, needs to know after an apply. Each part of the configuration adds
# its own.

output "project_id" {
  description = "The project, which is the Firebase project too."
  value       = var.project_id
}

output "region" {
  description = "The region everything regional here lives in."
  value       = var.region
}

output "log_bucket" {
  description = "The bucket the project's logs are kept in, in its region."
  value       = google_logging_project_bucket_config.logs.bucket_id
}

output "image_repository" {
  description = "Where the deployment pushes images: this, a slash, and the image's name."
  value       = google_artifact_registry_repository.images.registry_uri
}

output "admission_facts_secret" {
  description = "The secret whose versions are api's deployment facts: the deployment adds each, and mounts the one it names."
  value       = google_secret_manager_secret.admission_facts.secret_id
}

output "api_service_account" {
  description = "The identity api runs as, in its service and its jobs."
  value       = google_service_account.api.email
}

output "deploy_service_account" {
  description = "The identity the deployment borrows to push api's image, add a version of its facts, run its jobs and roll a revision."
  value       = google_service_account.deployer.email
}

output "api_service_url" {
  description = "api's address as the provider reads it from the service, null until the service exists: whether the service is there. The address /deployment.json names is api_origin."
  value       = one(google_cloud_run_v2_service.api[*].uri)
}

# The deterministic address of the service, which Cloud Run gives a service for its name, its
# project's number and its region, and which is known before the service is: /deployment.json names
# it with the first list (R05). api_service_name stays short enough for its jobs' names, so the DNS
# segment of name and number stays under the 63 characters such an address may have.
output "api_origin" {
  description = "api's origin as /deployment.json names it: https://<service>-<project number>.<region>.run.app, known before the service exists."
  value       = "https://${var.api_service_name}-${data.google_project.this.number}.${var.region}.run.app"
}

output "hosting_site" {
  description = "The Hosting site app's build is published to."
  value       = google_firebase_hosting_site.app.site_id
}

output "hosting_url" {
  description = "The address app is served at."
  value       = google_firebase_hosting_site.app.default_url
}

# What production/deployment.json names in signIn, for the operator to write into it: the file is
# the list's, reviewed in its pull request, and the deployment copies it as it is (R05; R17).
output "app_sign_in" {
  description = "The signIn block of /deployment.json: the Firebase web app app signs in as."
  value = {
    service    = "firebase"
    apiKey     = data.google_firebase_web_app_config.app.api_key
    authDomain = data.google_firebase_web_app_config.app.auth_domain
    projectId  = var.project_id
    appId      = google_firebase_web_app.app.app_id
  }
}

output "hosting_service_account" {
  description = "The identity app's build is published with."
  value       = google_service_account.hosting.email
}

# What api's deployment works on, read with tofu output -json in the deployment's job after the
# apply (R15): the service, the jobs with their part in the deployment, and the file of the facts.
output "api_service_name" {
  description = "The name of api's Cloud Run service, whether it is made yet or not."
  value       = var.api_service_name
}

output "api_jobs" {
  description = "api's jobs that are made, by their name in the list: the Cloud Run job, and its part in the deployment — check, migrate, after, or null for a job of the clock."
  value       = { for name, job in google_cloud_run_v2_job.api : name => { job = job.name, deploy = var.api_jobs[name].deploy } }
}

output "admission_facts_file" {
  description = "Where api's revision reads the deployment facts, the file of the secret's version mounted as a volume: the path in API_ADMISSION_FACTS_FILE."
  value       = local.admission_path
}

# What modules and tutor sign in with and read, for the operator to hand them: the provider of the
# pool bootstrap.sh makes, and the secrets by provider (R120 spec; R20). null with no eval.
output "eval_access" {
  description = "The workload identity provider of the pool github-eval and the eval secrets by provider, or null with no eval."
  value = length(var.eval_github_subject_prefixes) == 0 ? null : {
    workload_identity_provider = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${local.eval_pool}/providers/${local.eval_provider}"
    secrets                    = { for code, secret in google_secret_manager_secret.eval : code => secret.id }
  }
}

# The GitHub environments whose jobs may borrow api's deployment and the publisher: the workflow runs
# its jobs in them, and checks first that each is there and run from main alone (R18).
output "deploy_environment" {
  description = "The GitHub environment of api's deployment."
  value       = var.deploy_environment
}

output "hosting_environment" {
  description = "The GitHub environment of app's publisher."
  value       = var.hosting_environment
}
