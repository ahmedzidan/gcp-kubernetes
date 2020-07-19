terraform {
  backend "gcs" {
    prefix  = "terraform/test-airasia"
    credentials = "credentials.json"
  }
}
////////////////////////////////////////////////////////////////////////////////////
// vpc + private subnet + route
///////////////////////////////////////////////////////////////////////////////////
module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  version = "~> 2.4"
  project_id   = var.project_id
  network_name = var.network_name

  subnets = [
    {
      subnet_name           = var.subnet_name
      subnet_ip             = "10.0.0.0/16"
      subnet_region         = var.region
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    "${var.subnet_name}" = [
      {
        range_name    = var.ip_range_name_pods
        ip_cidr_range = "192.168.0.0/18"
      },
      {
        range_name    = var.ip_range_name_service
        ip_cidr_range = "192.168.64.0/18"
      },
    ]
  }
}

data "google_compute_subnetwork" "subnetwork" {
  name       = var.subnet_data_name
  project    = var.project_id
  region     = var.region
  depends_on = [module.gcp-network]
}

resource "google_compute_route" "internet" {
  name    = "my-router"
  network = module.gcp-network.network_self_link
  dest_range   = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  depends_on = [module.gcp-network]
}

resource "google_compute_firewall" "default" {
  name    = "test-firewall"
  network = module.gcp-network.network_name

  allow {
    protocol = "tcp"
    ports    = ["80","22", "443"]
  }
}
////////////////////////////////////////////////////////////////////////////////////
//
////////////////////////////////////////////////////////////////////////////////////
resource "google_compute_router" "router" {
  name    = "my-router"
  region  = var.region
  network = module.gcp-network.network_self_link

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
//////////////////////////////////////////////////////////////////////
// physical cluster
//////////////////////////////////////////////////////////////////////////
resource "google_container_cluster" "private" {
  name     = "${var.cluster_name_suffix}-clsuter"
  location = var.region
  node_locations = var.zones
  network = module.gcp-network.network_self_link
  subnetwork = module.gcp-network.subnets_names[0]

  ip_allocation_policy {
    cluster_secondary_range_name = var.ip_range_name_pods
    services_secondary_range_name = var.ip_range_name_service
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes = true
    master_ipv4_cidr_block = "172.16.0.0/28"
  }
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  depends_on = [module.gcp-network]
}

resource "google_container_node_pool" "nginx_cluster_nodes" {
  name               = "my-node-pool-test"
  location           = var.region
  cluster            = google_container_cluster.private.name
  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }
  node_config {
    machine_type = "n1-standard-1"
    disk_size_gb = 10
    disk_type          = "pd-standard"
    image_type         = "COS"
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  depends_on = [module.gcp-network]
}
///////////////////////////////////////////////////////////////////////////
// deploy nginx under nginx-app namespace
//////////////////////////////////////////////////////////////////////////
data "google_client_config" "default" {
}
provider "kubernetes" {
  load_config_file       = false
  host                   = google_container_cluster.private.endpoint
  token                  = data.google_client_config.default.access_token
  client_certificate     = base64decode(google_container_cluster.private.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.private.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.private.master_auth.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "nginx-app" {
  metadata {
    annotations = {
      name = "nginx-static-pages"
    }

    labels = {
      app = "nginx"
    }

    name = "nginx-static-pages"
  }
  timeouts {
    delete = "10m"
  }
}

resource "kubernetes_pod" "nginx" {
  metadata {
    name = "nginx-static-page"
    labels = {
      App = "nginx"
    }
    namespace = kubernetes_namespace.nginx-app.id
  }

  spec {
    container {
      image = "gcr.io/google-samples/hello-app:1.0"
      name  = "example"

      port {
        container_port = 80
      }
    }
  }
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

resource "kubernetes_service" "nginx-example" {
  metadata {
    name = "nginx-app-service"
  }

  spec {
    selector = {
      app = kubernetes_pod.nginx.metadata[0].labels.App
    }

    session_affinity = "ClientIP"

    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }

  depends_on = [google_container_node_pool.nginx_cluster_nodes]
}

///////////////////////////////////////////////////////////////////////////////////////
// deploy nodejs application to another namespace "virtual cluster"
//////////////////////////////////////////////////////////////////////////////////////
