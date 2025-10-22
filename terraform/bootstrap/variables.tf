# Frontend project
variable "fe_project_id" {
  description = "Frontend GCP project id"
  type = string
#   default = ""
}

variable "fe_region" {
  description = "Frontend project default region"
  type = string
#   default = ""
}

variable "fe_project_num" {
  description = "Frontend GCP project number"
  type = string
}

variable "my_domain" {
  description = "My public domain. (Ex: example.com)"
  type = string
  # default = ""
}

# Backend project
variable "be_project_id" {
  description = "Backend GCP project id"
  type = string
#   default = ""
}

variable "be_region" {
  description = "Backend project default region"
  type = string
#   default = ""
}

variable "be_project_num" {
  description = "Backend GCP project number"
  type = string
}

variable "my_user" {
  description = "My GCP email. (Ex: example@gmail.com)"
  type = string
  # default = ""
}

variable "gh_backend_repo" {
  description = "GitHub repo for backend code"
  type = string
  # default = ""
}