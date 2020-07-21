terraform {
  backend "gcs" {
    bucket = "iprice-gke-tf"
    prefix  = "terraform3/test-app3"
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
    tags = [var.node_tag]
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  depends_on = [module.gcp-network]
}

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
///////////////////////////////////////////////////////////////////////////
// deploy nginx under nginx-app namespace
//////////////////////////////////////////////////////////////////////////
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
    delete = "20m"
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

resource "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-app-service"
    namespace = kubernetes_namespace.nginx-app.id
  }

  spec {
    selector = {
      app = kubernetes_pod.nginx.metadata[0].labels.App
    }

    session_affinity = "ClientIP"

    port {
      protocol    = "TCP"
      port        = 8080
      target_port = 80
      node_port   = var.node_port
    }
    type = "NodePort"
  }

  depends_on = [google_container_node_pool.nginx_cluster_nodes]
}

///////////////////////////////////////////////////////////////////////////////////////
// deploy nodejs application to another namespace "virtual cluster"
//////////////////////////////////////////////////////////////////////////////////////
resource "kubernetes_namespace" "nodejs-app" {
  metadata {
    annotations = {
      name = "nodejs-api"
    }

    labels = {
      app = "nodejs-api"
    }

    name = "nodejs-api"
  }
  timeouts {
    delete = "20m"
  }
}

resource "kubernetes_pod" "nodejs" {
  metadata {
    name = "nodejs-api"
    labels = {
      App = "nodejs-api"
    }
    namespace = kubernetes_namespace.nodejs-app.id
  }

  spec {
    container {
      image = "gcr.io/google-samples/hello-app:1.0"
      name  = "nodejs-api"

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

resource "kubernetes_service" "nodejs-service" {
  metadata {
    name = "nodejs-api-service"
    namespace = kubernetes_namespace.nodejs-app.id
  }

  spec {
    selector = {
      app = kubernetes_pod.nodejs.metadata[0].labels.App
    }

    session_affinity = "ClientIP"

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
      node_port   = var.nodejs_node_port
    }

    type = "NodePort"
  }

  depends_on = [google_container_node_pool.nginx_cluster_nodes]
}
//////////////////////////////////////////////////////////////////////////////////////////////////////
//http LB
//////////////////////////////////////////////////////////////////////////////////////////////////////
module "gce-lb-http" {
  source            = "GoogleCloudPlatform/lb-http/google"
  version           = "~> 3.1"
  project           = var.project_id
  name              = "http-lb"
  firewall_networks = [var.network_name]

  target_tags = [var.node_tag]

  // Use custom url map.
  url_map        = google_compute_url_map.my-url-map.self_link
  create_url_map = false
  backends = {
    default = {
      description                     = null
      protocol                        = "HTTP"
      port                            = var.node_port
      port_name                       = var.port_name
      timeout_sec                     = 10
      connection_draining_timeout_sec = null
      enable_cdn                      = false
      session_affinity                = null
      affinity_cookie_ttl_sec         = null

      health_check = {
        check_interval_sec  = 5
        timeout_sec         = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        request_path        = "/"
        port                = var.node_port
        host                = null
        logging             = true
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          # Each node pool instance group should be added to the backend.
          group                        = replace(element(google_container_node_pool.nginx_cluster_nodes.instance_group_urls, 1), "Manager", "")
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        },
        {
          # Each node pool instance group should be added to the backend.
          group                        = replace(element(google_container_node_pool.nginx_cluster_nodes.instance_group_urls, 2), "Manager", "")
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        },
      ]
    }
  }

}

resource "google_compute_url_map" "my-url-map" {
  // note that this is the name of the load balancer
  name            = "test-map"
  default_service = module.gce-lb-http.backend_services["default"].self_link

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = module.gce-lb-http.backend_services["default"].self_link

   /* path_rule {
      paths = [
        "/api",
        "/api/*"
      ]
      service = kubernetes_service.nodejs-service.spec[0].external_ips
    }*/
  }
}

