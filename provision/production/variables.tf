variable "region" {
  description = "default region for production workload"
  type        = string
  default     = "asia-southeast1"
}

variable "zones" {
  description = "The zone to host the cluster in (required if is a zonal cluster)"
  type        = list(string)
  default     = ["asia-southeast1-a", "asia-southeast1-b"]
}

variable "network_name" {
  description = "Network name for the application clusters"
  type        = string
  default     = "airasia-app-network"
}

variable "subnet_name" {
  description = "subnet name for the applications"
  type        = string
  default     = "airasia-app-subnet"
}

variable "ip_range_name_pods" {
  description = "ip range name for nginx pods"
  type        = string
  default     = "ip-range-name-nginx-pods"
}

variable "ip_range_name_service" {
  description = "ip range name for nginx service"
  type        = string
  default     = "ip-range-name-nginx-service"
}

variable "subnet_data_name" {
  description = "name for the data subnet"
  type        = string
  default     = "airasia-subnet-data"
}

variable "cluster_name_suffix" {
  description = "cluster name suffix"
  type        = string
  default     = "private"
}

variable "vpc_name" {
  description = "vpc name for production workload"
  type        = string
  default     = "production-vpc"
}
variable "node_tag" {
  description = "nodes tag"
  type        = string
  default     = "private-node"
}

variable "nginx_service_name" {
  description = "name for nginx service"
  type        = string
  default     = "nginx-static-page"
}

variable "nginx_image_url" {
  description = "nginx docker registry url"
  type        = string
  default     = "gcr.io/google-samples/hello-app"
}

variable "nginx_app_version" {
  description = "nginx app version"
  type        = string
  default     = "1.0"
}
variable "node_port" {
  description = "nope service port for nginx static pages"
  type        = string
  default     = "30000"
}
variable "port_name" {
  description = "port name for nginx static pages"
  type        = string
  default     = "http"
}
variable "api_service_name" {
  description = "name for nodejs api service"
  type        = string
  default     = "nodejs-api"
}
variable "api_pods_name" {
  description = "name for nodejs api pods"
  type        = string
  default     = "nodejs-pods"
}
variable "nodejs_image_url" {
  description = "nodejs image docker registry url"
  type        = string
  default     = "gcr.io/google-samples/node-hello"
}
variable "node_app_version" {
  description = "app version to deploy"
  type        = string
  default     = "1.0"
}
variable "nodejs_node_port" {
  description = "nodejs node port"
  type        = string
  default     = "30002"
}

variable "app_env" {
  description = "application environment"
  type        = string
  default     = "production"
}

variable "project_id" {
  description = "Project id for production workload"
  type        = string
}
