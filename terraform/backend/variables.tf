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

variable "app_image_url" {
  description = "Image url to Artifact Registry"
  type = string
}