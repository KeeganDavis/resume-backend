output "fe_bucket_name" {
  description = "Name of bucket used to store static website files."
  value = google_storage_bucket.static_site.name
}

output "fe_workload_identity_provider" {
  description = "Frontend Workload Identity provider ID for GitHub. Paste into GH env variable WORKLOAD_IDENTITY_PROVIDER in resume-frontend repo"
  value = "projects/${var.fe_project_num}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.gh_fe.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.gh_fe.workload_identity_pool_provider_id}"
}

output "fe_deployer_sa" {
  description = "Frontend service account email for GitHub Workload Identity Provider. Paste into SERVICE_ACCOUNT_EMAIL in resume-frontend repo."
  value = google_service_account.gh_fe.email
}