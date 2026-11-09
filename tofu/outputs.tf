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
