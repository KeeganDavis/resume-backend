 # Backend project
variable "be_project_id" {
  description = "Backend GCP project id"
  type = string
}

variable "be_region" {
  description = "Backend project default region"
  type = string
}

variable "app_image_url" {
  description = "Image url to Artifact Registry"
  type = string
}