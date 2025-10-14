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