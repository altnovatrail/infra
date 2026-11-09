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

variable "log_retention_days" {
  description = "How many days the logs in the region's bucket are kept. The platform's are 30 (R07); the audit in _Required is kept 400 days, which nothing here can change."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3650 && floor(var.log_retention_days) == var.log_retention_days
    error_message = "log_retention_days is a whole number of days, from 1 to 3650."
  }
}

variable "api_service_name" {
  description = "The name of api's Cloud Run service, which the alerts filter its metrics by and the service and its jobs are named after (T15)."
  type        = string
  default     = "api"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,47}[a-z0-9]$", var.api_service_name))
    error_message = "api_service_name is 2 to 49 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit, as Cloud Run names a service."
  }
}

# The images. A deployment pushes one image per release of api, so the most recent few are the
# serving one and those a new revision might still stand on.

variable "keep_images" {
  description = "How many of the most recent image versions survive the cleanup, whatever their age."
  type        = number
  default     = 5
  nullable    = false

  validation {
    condition     = var.keep_images >= 1 && floor(var.keep_images) == var.keep_images
    error_message = "keep_images is a whole number, at least one: the serving image is the most recent."
  }
}

variable "image_max_age" {
  description = "How old an image version with no tag may get before the cleanup deletes it, unless it is one of the most recent ones. A duration as Artifact Registry takes it: a whole number of s, m, h or d."
  type        = string
  default     = "30d"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*[smhd]$", var.image_max_age))
    error_message = "image_max_age is a whole number of seconds, minutes, hours or days, such as 30d or 720h."
  }
}

# The spend alert (R06).

variable "billing_account" {
  description = "The billing account the project pays through; the spend alert is made on it. It names the account that pays, so it is not written beside the deployment's other values and arrives from the environment, as TF_VAR_billing_account."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9A-Z]{6}-[0-9A-Z]{6}-[0-9A-Z]{6}$", var.billing_account))
    error_message = "billing_account is the id of a billing account, which reads like 01ABCD-234567-89EFGH, and it comes from TF_VAR_billing_account."
  }
}

variable "budget_amount" {
  description = "The monthly spend, in whole units of budget_currency, the spend alert is measured against. An alert and not a cap: nothing stops a project at a number."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.budget_amount))
    error_message = "budget_amount is a whole number of units, at least one."
  }
}

variable "budget_currency" {
  description = "The currency of the spend alert, as an ISO 4217 code: the billing account's own, which is what the amount is measured in."
  type        = string

  validation {
    condition     = can(regex("^[A-Z]{3}$", var.budget_currency))
    error_message = "budget_currency is a three-letter currency code, such as USD."
  }
}

# The alerts on Cloud Run's built-in metrics (R07).

variable "operator_email" {
  description = "The address the alerts are mailed to. Empty means no alerts. It is a person's address, so it is not written in this repository: it arrives from the environment, as TF_VAR_operator_email."
  type        = string
  default     = ""
  sensitive   = true
  nullable    = false

  validation {
    condition     = var.operator_email == "" || can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.operator_email))
    error_message = "operator_email is empty, or an email address."
  }
}

variable "load_alert_per_minute" {
  description = "Requests a minute to api, all its revisions together and on average over five minutes, past which the load alert is mailed."
  type        = number
  default     = 300
  nullable    = false

  validation {
    condition     = var.load_alert_per_minute > 0
    error_message = "load_alert_per_minute is more than zero."
  }
}

variable "error_alert_per_minute" {
  description = "Answers of the 5xx class a minute from api, on average over five minutes, past which the error alert is mailed."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.error_alert_per_minute > 0
    error_message = "error_alert_per_minute is more than zero."
  }
}
