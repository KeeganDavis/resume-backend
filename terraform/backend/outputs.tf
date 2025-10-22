output "resume_api_gw_url" {
  description = "URL returned from API gateway."
  value = google_api_gateway_gateway.resume.default_hostname
}

output "visitors_datastore_db_name" {
  description = "Name returned from datastore database"
  value = google_firestore_database.visitors.name
}

output "artifact_registry_repo_uri" {
  description = "Artifact registry repo endpoint"
  value = "${var.be_region}-docker.pkg.dev/${var.be_project_id}/${google_artifact_registry_repository.resume_repo.name}"
}