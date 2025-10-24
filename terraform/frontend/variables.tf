# Frontend project
variable "fe_project_id" {
  description = "Frontend GCP project id"
  type = string
}

variable "fe_region" {
  description = "Frontend project default region"
  type = string
}

variable "my_domain" {
  description = "My public domain. (Ex: example.com)"
  type = string
}

variable "gh_fe_sa" {
  description = "Service account email for GitHub frontend repo"
  type = string
}