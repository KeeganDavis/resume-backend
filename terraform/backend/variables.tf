variable "my_user" {
  description = "My GCP email. (Ex: example@gmail.com)"
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