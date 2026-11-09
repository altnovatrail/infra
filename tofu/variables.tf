# What a deployment says about itself. The platform's values come in a file of their own when its
# project is created; a self-hosted copy gives its own (R10). Each part of the configuration
# brings the variables it needs.

variable "project_id" {
  description = "The Google Cloud project that holds every resource here, and the Firebase project too. The app's address, <project>.web.app, is named after it."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id is a project id: 6 to 30 lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "region" {
  description = "Where everything this configuration keeps in a region lives: the services and jobs, the images, the secrets' replicas, the logs and the traces. The platform's is us-east4 (R04); a self-hosted copy chooses its own."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region is the name of a Google Cloud region, such as us-east4."
  }
}
