variable "region" {
  description = "default region for production workload"
  type = string
  default = "asia-southeast1"
}

variable "zones" {
  type        = list(string)
  description = "The zone to host the cluster in (required if is a zonal cluster)"
  default = ["asia-southeast1-a", "asia-southeast1-b"]
}

variable "network_name" {
  type = string
  description = "Network name for the application clusters"
  default = "airasia-app-network"
}

variable "subnet_name" {
  type = string
  description = "subnet name for the applications"
  default = "airasia-app-subnet"
}

variable "ip_range_name_pods" {
  type = string
  description = "ip range name for nginx pods"
  default = "ip-range-name-nginx-pods"
}

variable "ip_range_name_service" {
  type = string
  description = "ip range name for nginx service"
  default = "ip-range-name-nginx-service"
}

variable "subnet_data_name" {
  type = string
  description = "name for the data subnet"
  default = "airasia-subnet-data"
}

variable "cluster_name_suffix" {
  type = string
  description = "cluster name suffix"
  default = "private"
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

variable "node_port" {
  default = "30000"
}
variable "nodejs_node_port" {
  default = "30002"
}

variable "port_name" {
  default = "http"
}

variable "node_tag" {
  type = string
  description = "node tag"
  default = "lb-https-gke"
}

variable "project_id" {
  description = "Project id for production workload"
  type = string
}
