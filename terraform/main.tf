# initialize provider for front end project
provider "google" {
  alias = "front_end"
  project = var.fe_project_id
  region  = var.fe_region
}

# Create Google Cloud Storage bucket
resource "google_storage_bucket" "static_site" {
  project = var.fe_project_id
  name          = "resume-site-keegan"
  location      = var.fe_region
  force_destroy = true

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "resume.html"
    not_found_page   = "404.html"
  }
  cors {
    origin          = ["https://${var.my_domain}"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Make bucket public by granting allUsers storage.objectViewer access
resource "google_storage_bucket_iam_member" "public_rule" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Create load balancer and SSL certificates
module "lb-frontend" {
  source  = "terraform-google-modules/lb-http/google//modules/frontend"
  version = "~> 12.0"

  project_id    = var.fe_project_id
  name          = "resume-lb-fe"

  http_forward = false
  managed_ssl_certificate_domains = [var.my_domain, "www.${var.my_domain}"]
  ssl           = true
  url_map_input = module.lb-backend.backend_service_info
}

module "lb-backend" {
  source  = "terraform-google-modules/lb-http/google//modules/backend"
  version = "~> 12.0"

  project_id          = var.fe_project_id
  name                = "resume-be-bucket"
  backend_bucket_name = google_storage_bucket.static_site.name
  enable_cdn          = true
}

resource "google_dns_managed_zone" "static_site" {
  name        = "resume-dns-zone"
  dns_name    = "${var.my_domain}."
  description = "DNS zone for public resume static site."
  project     = var.fe_project_id
}

resource "google_dns_record_set" "a" {
  name         = "${var.my_domain}."
  managed_zone = google_dns_managed_zone.static_site.name
  type         = "A"
  ttl          = 300
  project     = var.fe_project_id

  rrdatas = [module.lb-frontend.external_ip]
}

resource "google_dns_record_set" "cname" {
  name         = "www.${var.my_domain}."
  managed_zone = google_dns_managed_zone.static_site.name
  type         = "CNAME"
  ttl          = 300
  project      = var.fe_project_id
  rrdatas      = ["${var.my_domain}."]
}

# initialize provider block for backend project
provider "google" {
  alias = "back_end"
  project = var.be_project_id
  region  = var.be_region
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
      contents = base64encode(templatefile("${path.module}/../api/openapi2-run.yaml.tftpl", {
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
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_fe.name}/attribute.repository/${var.gh_frontend_repo}"
}

resource "google_storage_bucket_iam_member" "fe_writer" {
  bucket = google_storage_bucket.static_site.name
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gh_fe.email}"
}

resource "google_project_iam_member" "fe_lb_admin" {
  project = var.fe_project_id
  role = "roles/compute.loadBalancerAdmin"
  member = "serviceAccount:${google_service_account.gh_fe.email}"
}