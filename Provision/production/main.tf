terraform {
  backend "gcs" {
    bucket  = "test-tf-state"
    prefix  = "terraform/state"
    credentials = "credentials.json"
  }
}
