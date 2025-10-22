output "fe_bucket_name" {
  description = "Name of bucket used to store static website files."
  value = google_storage_bucket.static_site.name
}