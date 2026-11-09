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
  description = "The name of api's Cloud Run service, which the alerts filter its metrics by, and the prefix of its jobs and its identities, which take up to ten characters more of 30."
  type        = string
  default     = "api"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,18}[a-z0-9]$", var.api_service_name))
    error_message = "api_service_name is 2 to 20 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit: Cloud Run names a service so, and its identities take up to ten characters more, of 30."
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

# api's service and jobs (R11).

variable "api_serving" {
  description = "Whether api's service is made: once api_image has made the jobs and the first deployment has run the check of the configuration and the migrations with them. Until then there are jobs and no service, so the first revision starts on a database already migrated."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.api_serving || var.api_image != null
    error_message = "api_serving needs api_image: the service is made with the first image, after the jobs."
  }
}

variable "api_image" {
  description = "The image api's service and jobs are made with, by digest, from this project's registry: the one the first deployment pushed. Until it is given there is neither service nor jobs. Once they exist, the deployment owns which image they run, and changing this moves nothing."
  type        = string
  default     = null

  validation {
    condition     = var.api_image == null || can(regex("^${var.region}-docker\\.pkg\\.dev/${var.project_id}/images/[a-z0-9][a-z0-9._/-]*@sha256:[0-9a-f]{64}$", var.api_image))
    error_message = "api_image is an image of this project's repository images, in its region, named by digest, never by tag: a tag can be moved under a running service."
  }
}

variable "api_jobs" {
  description = "api's jobs, by name: the arguments of the command each runs, the secrets it reads as files, by the variable api reads each from and the secret's id, how long it may take, and, for a job that runs by the clock, its schedule in cron's form, UTC. Only commands api's release has go here."
  type = map(object({
    args     = list(string)
    secrets  = optional(map(string), {})
    timeout  = optional(string, "600s")
    schedule = optional(string)
  }))
  nullable = false

  # migrate is the one job api's binary has so far: it applies the migrations of both databases
  # (api README, v0.1.3). The check of the configuration, the job after the rollout and the job of
  # the retention periods join the list when api's release names them.
  default = {
    migrate = {
      args = ["migrate"]
      secrets = {
        API_MIGRATE_DATABASE_URL         = "api-migrate-database-url"
        API_MIGRATE_OPENFGA_DATABASE_URL = "api-migrate-openfga-database-url"
      }
    }
  }

  validation {
    condition     = alltrue([for name, job in var.api_jobs : can(regex("^[a-z][a-z0-9-]{0,18}[a-z0-9]$", name))])
    error_message = "A job's name is 2 to 20 lowercase letters, digits and hyphens, starting with a letter: it is the end of the job's name in Cloud Run."
  }

  validation {
    condition     = alltrue(flatten([for job in values(var.api_jobs) : [for variable, secret in job.secrets : can(regex("^API_[A-Z0-9_]+$", variable)) && can(regex("^[a-z][a-z0-9-]{0,62}$", secret))]]))
    error_message = "A job's secrets name api's variable, API_ and capitals, and the secret's id, lowercase letters, digits and hyphens."
  }

  validation {
    condition     = alltrue([for job in values(var.api_jobs) : length(job.args) > 0 && can(regex("^[1-9][0-9]*s$", job.timeout)) && try(tonumber(trimsuffix(job.timeout, "s")) <= 604800, false)])
    error_message = "A job names its command, and its timeout is a whole number of seconds up to 604800s, Cloud Run's 168 hours, such as 600s."
  }

  validation {
    condition     = !contains(flatten([for job in values(var.api_jobs) : values(job.secrets)]), "api-admission-facts")
    error_message = "A job's secret is not the deployment facts' secret, api-admission-facts: that one the configuration makes, and the deployment adds its versions."
  }
}

variable "api_max_instances" {
  description = "How many instances of api may run at once."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.api_max_instances >= 1 && floor(var.api_max_instances) == var.api_max_instances
    error_message = "api_max_instances is a whole number, at least one."
  }
}

variable "api_concurrency" {
  description = "How many requests one instance of api serves at a time."
  type        = number
  default     = 40
  nullable    = false

  validation {
    condition     = var.api_concurrency >= 1 && var.api_concurrency <= 1000
    error_message = "api_concurrency is between 1 and 1000, the platform's limit."
  }
}

variable "api_cpu" {
  description = "CPU of api's container, in whole vCPUs, as the platform takes them: 1, 2, or 1000m, 2000m."
  type        = string
  default     = "1"
  nullable    = false

  validation {
    condition     = contains(["1", "2", "4", "6", "8", "1000m", "2000m", "4000m", "6000m", "8000m"], var.api_cpu)
    error_message = "api_cpu is 1, 2, 4, 6 or 8 vCPUs, as Cloud Run takes them, or the same in thousandths: 1000m to 8000m."
  }
}

variable "api_memory" {
  description = "Memory of api's container, in Mi or Gi. Nine tenths of it is the soft limit the Go runtime is told."
  type        = string
  default     = "1Gi"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*(Mi|Gi)$", var.api_memory))
    error_message = "api_memory is a whole number of Mi or Gi, such as 1Gi."
  }

  # Cloud Run asks at least 2 GiB with 4 vCPUs and 4 GiB with 6 or 8.
  validation {
    condition = !can(regex("^[1-9][0-9]*(Mi|Gi)$", var.api_memory)) || (
      tonumber(regex("^[0-9]+", var.api_memory)) * (endswith(var.api_memory, "Gi") ? 1024 : 1) >=
      lookup({ "4" = 2048, "4000m" = 2048, "6" = 4096, "6000m" = 4096, "8" = 4096, "8000m" = 4096 }, var.api_cpu, 0)
    )
    error_message = "api_memory is at least 2Gi with 4 vCPUs and at least 4Gi with 6 or 8, as Cloud Run asks."
  }
}

variable "api_request_timeout" {
  description = "How long a request to api may take before the platform cuts it off: api's own write timeout, API_HTTP_WRITE_TIMEOUT, is 60s."
  type        = string
  default     = "60s"
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]*s$", var.api_request_timeout)) && try(tonumber(trimsuffix(var.api_request_timeout, "s")) <= 3600, false)
    error_message = "api_request_timeout is a whole number of seconds up to 3600s, Cloud Run's limit, such as 60s."
  }
}

# Who may deploy: the jobs of one GitHub environment of infra's repository (R11).

variable "workload_identity_pool_id" {
  description = "The federated pool the repository's tokens are exchanged in. It exists before this configuration is ever applied, since the apply itself signs in through it, so it is named here rather than made: bootstrap.sh prints it."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.workload_identity_pool_id))
    error_message = "workload_identity_pool_id is 4 to 32 lowercase letters, digits and hyphens."
  }
}

variable "github_oidc_subject_prefix" {
  description = "How GitHub begins the subject of the repository's tokens: the owner and the repository, each with its numeric id, as `gh api repos/OWNER/NAME/actions/oidc/customization/sub --jq .sub_claim_prefix` prints it. A job's subject goes on to name its environment, so an identity bound to one subject is lent to the jobs of one environment alone."
  type        = string

  validation {
    condition     = can(regex("^repo:[^/@:]+@[0-9]+/[^/@:]+@[0-9]+$", var.github_oidc_subject_prefix))
    error_message = "github_oidc_subject_prefix is repo:OWNER@OWNER_ID/NAME@REPOSITORY_ID."
  }
}

variable "deploy_environment" {
  description = "The GitHub environment whose jobs may borrow the deployment's identity: only main may run in it (R05)."
  type        = string
  default     = "production"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,255}$", var.deploy_environment))
    error_message = "deploy_environment is the name of a GitHub environment: letters, digits, dots, hyphens and underscores."
  }
}

variable "hosting_environment" {
  description = "The GitHub environment whose jobs may borrow the identity that publishes app's build on Hosting: only main may run in it, and none of api's deployment does (R12)."
  type        = string
  default     = "production-hosting"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,255}$", var.hosting_environment))
    error_message = "hosting_environment is the name of a GitHub environment: letters, digits, dots, hyphens and underscores."
  }

  validation {
    condition     = lower(var.hosting_environment) != lower(var.deploy_environment)
    error_message = "hosting_environment is not deploy_environment, in any case of letters, as GitHub compares the names: the publisher of app's build and api's deployment are lent to the jobs of different environments."
  }
}
