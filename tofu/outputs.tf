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
