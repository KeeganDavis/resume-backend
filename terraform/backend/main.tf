# initialize provider block for backend project
provider "google" {
  alias = "back_end"
  project = var.be_project_id
  region  = var.be_region
}

# Remote backend setup with cloud storage bucket
terraform {
  backend "gcs" {
    bucket = "resume-site-tf-state"   
    prefix = "dev"          
  }
}

# Create Cloud Run instance
resource "google_cloud_run_v2_service" "visitor_counter" {
  project = var.be_project_id
  name     = "resume-visitor-counter"
  location = var.be_region
  deletion_protection = false
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.app_image_url
    }
  }
}

# Create Firestore Datastore DB
resource "google_firestore_database" "visitors" {
  project = var.be_project_id
  name        = "resume-visitors"
  location_id = var.be_region
  type        = "DATASTORE_MODE"
}

# Create API Gateway
resource "google_api_gateway_api" "resume" {
  project = var.be_project_id
  provider = google-beta
  api_id = "resume-api"
}

# Create API Gateway config
resource "google_api_gateway_api_config" "resume" {
  project = var.be_project_id
  provider = google-beta
  api = google_api_gateway_api.resume.api_id
  display_name = "resume-api-cfg"

  openapi_documents {
    document {
      path = "openapi2-run.yaml"
      contents = base64encode(templatefile("${path.module}/../../api/openapi2-run.yaml.tftpl", {
        backend_run_uri = google_cloud_run_v2_service.visitor_counter.uri
      }))
    }
  }
  lifecycle {create_before_destroy = true}

  depends_on = [google_cloud_run_v2_service.visitor_counter]
}

# Create API Gateway gateway
resource "google_api_gateway_gateway" "resume" {
  project = var.be_project_id
  provider = google-beta
  api_config = google_api_gateway_api_config.resume.id
  gateway_id = "resume-api-gateway"
  display_name = "resume-api-gateway"
  region = var.be_region
}
  
# Create Artifact Registry repo
resource "google_artifact_registry_repository" "resume_repo" {
  project = var.be_project_id
  location      = var.be_region
  repository_id = "resume-repo"
  description   = "docker repo to hold cloud run visitor counter app"
  format        = "DOCKER"
}