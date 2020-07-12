variable "project_id" {
  description = "Project id for production workload"
  type = string
  default = "test-project"
}

variable "region" {
  description = "default region for production workload"
  type = string
  default = "asia-southeast1"
}

variable "vpc_name" {
  description = "vpc name for production workload"
  type = string
  default = "production-vpc"
}

variable "app_env" {
  description = "application environment"
  type = string
  default = "production"
}