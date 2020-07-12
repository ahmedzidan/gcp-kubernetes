provider "google" {
  version     = "~> 3.3.0"
  project     = var.project_id
  region      = var.region
  credentials = "credentials.json"
}
