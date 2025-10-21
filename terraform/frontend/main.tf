# initialize provider for front end project
provider "google" {
  alias = "front_end"
  project = var.fe_project_id
  region  = var.fe_region
}

# Bucket to hold Terraform remote state
resource "google_storage_bucket" "backend_state" {
  project = var.fe_project_id
  name          = "resume-site-tf-state-fe"
  location      = var.fe_region
  force_destroy = false
  versioning {
    enabled = true
  }
}

# Remote backend setup with cloud storage bucket
terraform {
  backend "gcs" {
    bucket = "resume-site-tf-state-fe"   
    prefix = "dev"          
  }
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