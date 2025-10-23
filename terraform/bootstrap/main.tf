# --------------------------------------------- Frontend bootstrap ---------------------------------- #
# initialize provider for front end project
provider "google" {
  alias = "front_end"
  project = var.fe_project_id
  region  = var.fe_region
}

# Bucket to hold Terraform remote state
resource "google_storage_bucket" "remote_state_fe" {
  project = var.fe_project_id
  name          = "resume-site-tf-state-fe"
  location      = var.fe_region
  force_destroy = false
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_iam_member" "fe_remote_state_obj_admin" {
  bucket = google_storage_bucket.remote_state_fe.name
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gh_fe.email}"
}

resource "google_storage_bucket_iam_member" "fe_remote_state_reader" {
  bucket = google_storage_bucket.remote_state_fe.name
  role = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.gh_fe.email}"
}

# Workload Identity Federation and service account setup to GitHub fe repo
resource "google_iam_workload_identity_pool" "gh_fe" {
  project = var.fe_project_id
  workload_identity_pool_id = "github-fe"
  display_name = "GitHub frontend OIDC pool"
  disabled = false
}

resource "google_iam_workload_identity_pool_provider" "gh_fe" {
  project = var.fe_project_id
  workload_identity_pool_id = google_iam_workload_identity_pool.gh_fe.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-fe"
  display_name = "GitHub"
  
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"        
    "attribute.sub"        = "attribute.sub"        
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "attribute.repository==assertion.repository"
}

# Frontend CI/CD SA
resource "google_service_account" "gh_fe" {
  account_id = "gh-frontend-deployer"
  display_name = "GitHub Frontend Deployer"
  project = var.fe_project_id
}

# FRONTEND: allow the repo to impersonate SA (any branch)
resource "google_service_account_iam_member" "frontend_wif" {
  service_account_id = google_service_account.gh_fe.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_fe.name}/attribute.repository/${var.gh_backend_repo}"
}

# FRONTEND: allow the repo to impersonate SA (any branch)
resource "google_service_account_iam_member" "frontend_repo_wif" {
  service_account_id = google_service_account.gh_fe.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_fe.name}/attribute.repository/${var.gh_frontend_repo}"
}

resource "google_project_iam_member" "ci_storage_admin" {
  project = var.fe_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.gh_fe.email}"
}

resource "google_project_iam_member" "ci_dns_admin" {
  project = var.fe_project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.gh_fe.email}"
}

resource "google_project_iam_member" "ci_cert_manager_editor" {
  project = var.fe_project_id
  role    = "roles/certificatemanager.editor"
  member  = "serviceAccount:${google_service_account.gh_fe.email}"
}

resource "google_project_iam_member" "ci_lb_admin" {
  project = var.fe_project_id
  role = "roles/compute.loadBalancerAdmin"
  member = "serviceAccount:${google_service_account.gh_fe.email}"
}


# --------------------------------------------- Backend bootstrap ---------------------------------- #
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

resource "google_project_iam_member" "be_datastore_user" {
  project = var.be_project_id
  role = "roles/datastore.user"
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

resource "google_project_iam_member" "be_sa_user" {
  project = var.be_project_id
  role = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.gh_be.email}"
}