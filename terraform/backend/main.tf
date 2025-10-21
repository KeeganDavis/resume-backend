# initialize provider block for backend project
provider "google" {
  alias = "back_end"
  project = var.be_project_id
  region  = var.be_region
}

# Bucket to hold Terraform remote state
resource "google_storage_bucket" "backend_state" {
  project = var.be_project_id
  name          = "resume-site-tf-state"
  location      = var.be_region
  force_destroy = false
  versioning {
    enabled = true
  }
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
      # Placeholder image
      image = "us-docker.pkg.dev/cloudrun/container/hello"
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

# Fetch the Compute Engine default service account email for this project
data "google_compute_default_service_account" "this" {
  project = var.be_project_id
}

# Update IAM policy for Compute Engine default service account to access datastore db
resource "google_project_iam_member" "compute_sa_datastore_user" {
  project = var.be_project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${data.google_compute_default_service_account.this.email}"
}

# Create service account for api to access cloud run
resource "google_service_account" "resume_api_sa" {
  account_id   = "resume-api-sa"
  description = "Access cloud run visitor counter app for API"
  project = var.be_project_id
}
# Add ownership of api-sa service account
resource "google_service_account_iam_member" "resume_api_sa_admin" {
  service_account_id = google_service_account.resume_api_sa.name
  role               = "roles/iam.serviceAccountAdmin"
  member             = "user:${var.my_user}"
}

# Update IAM policy for api-sa to have run invoker role
resource "google_project_iam_member" "resume_api_sa_run_invoker" {
  project = var.be_project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.resume_api_sa.email}"
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

# Workload Identity Federation and service account setup to GitHub be repo
resource "google_iam_workload_identity_pool" "gh_be" {
  project                   = var.be_project_id
  workload_identity_pool_id = "github-be-1"
  display_name              = "GitHub backend OIDC pool"
}

resource "google_iam_workload_identity_pool_provider" "gh_be" {
  project                            = var.be_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_be.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-be"
  display_name                       = "GitHub"

  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"        
    "attribute.sub"        = "attribute.sub"        
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "attribute.repository==assertion.repository"
}

# Backend CI/CD SA
resource "google_service_account" "gh_be" {
  account_id = "gh-backend-deployer"
  display_name = "GitHub Backend Deployer"
  project = var.be_project_id
}

# BACKEND: allow the repo to impersonate SA (any branch)
resource "google_service_account_iam_member" "backend_wif" {
  service_account_id = google_service_account.gh_be.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_be.name}/attribute.repository/${var.gh_backend_repo}"
}

resource "google_project_iam_member" "be_ar_writer" {
  project = var.be_project_id
  role = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}

resource "google_project_iam_member" "be_api_gw_admin" {
  project = var.be_project_id
  role = "roles/apigateway.admin"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}

resource "google_project_iam_member" "be_run_admin" {
  project = var.be_project_id
  role = "roles/run.admin"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}

resource "google_storage_bucket_iam_member" "be_remote_state_obj_admin" {
  bucket = google_storage_bucket.backend_state.name
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}

resource "google_storage_bucket_iam_member" "be_remote_state_reader" {
  bucket = google_storage_bucket.backend_state.name
  role = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}