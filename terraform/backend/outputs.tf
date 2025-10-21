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

output "be_workload_identity_provider" {
  description = "Backend Workload Identity provider ID for GitHub. Paste into GH env variable WORKLOAD_IDENTITY_PROVIDER in resume-backend repo"
  value = "projects/${var.be_project_num}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.gh_be.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.gh_be.workload_identity_pool_provider_id}"
}

output "be_deployer_sa" {
  description = "Backend service account email for GitHub Workload Identity Provider. Paste into SERVICE_ACCOUNT_EMAIL in resume-backend repo."
  value = google_service_account.gh_be.email
}