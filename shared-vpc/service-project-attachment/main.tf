## create attachment
resource "google_compute_shared_vpc_service_project" "service_project" {
  host_project    = var.gcp_host_project_id
  service_project = var.gcp_service_project_id
}

## main subnet for GKE
resource "google_compute_subnetwork" "main" {
  name          = "${var.keboola_stack}-main"
  region        = var.gcp_region
  network       = var.vpc_host_network_self_link
  ip_cidr_range = var.vpc_main_subnet_primary_ip_cidr_range

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.vpc_main_subnet_secondary_pods_ip_cidr_range
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.vpc_main_subnet_secondary_services_ip_cidr_range
  }
}

## FIREWALL RULES
resource "google_compute_firewall" "gke_health_check_rules" {
  name        = "${var.keboola_stack}-gke-health-check"
  network     = var.vpc_host_network_self_link
  description = "A firewall rule to allow health check from Google Cloud to GKE"
  priority    = 1000
  direction   = "INGRESS"
  disabled    = false
  # https://cloud.google.com/load-balancing/docs/health-checks#fw-rule
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = [var.gke_nodes_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balance-ingress#create_a_firewall_rule
resource "google_compute_firewall" "private_load_balancer" {
  name          = "${var.keboola_stack}-gke-allow-lb-proxy"
  network       = var.vpc_host_network_self_link
  description   = "Allow connections from the load balancer proxies in the proxy-subnet"
  priority      = 1000
  direction     = "INGRESS"
  disabled      = false
  source_ranges = [var.vpc_proxy_subnet_ip_cidr_range]
  target_tags   = [var.gke_nodes_tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#add_firewall_rules
resource "google_compute_firewall" "gke_nginx_admission_webhook" {
  name        = "${var.keboola_stack}-gke-nginx-admission-webhook"
  network     = var.vpc_host_network_self_link
  description = "A firewall rule to allow admission webhook from  GKE control plane"
  priority    = 1000
  direction   = "INGRESS"
  disabled    = false
  # https://cloud.google.com/load-balancing/docs/health-checks#fw-rule
  source_ranges = [var.vpc_gke_master_ipv4_cidr_block]
  target_tags   = [var.gke_nodes_tag]

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }
}

resource "google_compute_firewall" "ssh_bastion" {
  name          = "${var.keboola_stack}-ssh-bastion"
  network       = var.vpc_host_network_self_link
  description   = "Allow connections to ssh-bastion nodeport from nodes"
  priority      = 1000
  direction     = "INGRESS"
  disabled      = false
  source_ranges = [var.gke_nodes_tag]
  target_tags   = [var.gke_nodes_tag]

  allow {
    protocol = "tcp"
    ports    = ["32222"]
  }
}

data "google_project" "service_project" {
  project_id = var.gcp_service_project_id
}
locals {
  service_project_number                   = data.google_project.service_project.number
  service_google_api_service_account_email = "${local.service_project_number}@cloudservices.gserviceaccount.com"
  service_gke_service_account_email        = "service-${local.service_project_number}@container-engine-robot.iam.gserviceaccount.com"

}


## IAM roles

# A Shared VPC Admin defines a Service Project Admin by granting an IAM principal the Network User (compute.networkUser) role to either the whole host project or select subnets of its Shared VPC networks.
resource "google_compute_subnetwork_iam_binding" "binding" {
  subnetwork = google_compute_subnetwork.main.name
  region     = var.gcp_region
  role       = "roles/compute.networkUser"
  members = [
    "serviceAccount:${local.service_google_api_service_account_email}",
    "serviceAccount:${local.service_gke_service_account_email}",
    "serviceAccount:${var.deploy_stack_service_account_email}"
  ]
}

# This binding allows the service project's GKE service account to perform network management operations in the host project, as if it were the host project's GKE service account.
resource "google_project_iam_member" "host_service_agent_user" {
  project = var.gcp_host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:${local.service_gke_service_account_email}"

}
