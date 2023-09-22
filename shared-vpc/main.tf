terraform {
  required_version = "~> 1.1"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.74.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}


## Enable compute engine api
resource "google_project_service" "enable_container_api" {
  service = "container.googleapis.com"
}

## Enable service networking api
resource "google_project_service" "enable_servicenetworking_api" {
  service = "servicenetworking.googleapis.com"
}

## VPC, subnets, service peering
resource "google_compute_network" "kbc" {
  name                    = "keboola-shared-vpc"
  auto_create_subnetworks = "false"
}

# A host project provides network resources to associated service projects.
resource "google_compute_shared_vpc_host_project" "host" {
  project = var.gcp_project
}

## /24 IP range allocation for Goggle private connect services where MySQL dbs are deployed
resource "google_compute_global_address" "kbc_google_services_peering" {
  name          = "kbc-google-services-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.kbc.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.kbc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.kbc_google_services_peering.name]
  depends_on              = [google_compute_global_address.kbc_google_services_peering]
}

### 10.13.0.0/24 proxy subnet for load balancers proxies
resource "google_compute_subnetwork" "proxy" {
  name          = "keboola-shared-vpc-proxy"
  region        = var.gcp_region
  network       = google_compute_network.kbc.self_link
  ip_cidr_range = "10.13.0.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

### Cloud NAT
resource "google_compute_router" "main" {
  name    = "keboola-shared-vpc-main"
  region  = var.gcp_region
  network = google_compute_network.kbc.self_link

}

resource "google_compute_router_nat" "main" {
  name                               = "keboola-shared-vpc-main"
  router                             = google_compute_router.main.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

## subnet for openvpn gateway
resource "google_compute_subnetwork" "openvpn" {
  name          = "openvpn"
  region        = var.gcp_region
  network       = google_compute_network.kbc.self_link
  ip_cidr_range = "10.200.0.0/24"
}


locals {
  test_service_projects_attachments = [
    {
      keboola_stack                                    = "dev-keboola-demo-gcp-us-central1",
      service_project_id                               = "dev-keboola-demo-gcp-us-central1",
      vpc_main_subnet_primary_ip_cidr_range            = "10.10.0.0/24",
      vpc_main_subnet_secondary_pods_ip_cidr_range     = "10.11.0.0/17",
      vpc_main_subnet_secondary_services_ip_cidr_range = "10.12.0.0/16",
      vpc_gke_master_ipv4_cidr_block                   = "172.16.0.0/28"
      deploy_stack_service_account_email               = "stack-deploy@dev-keboola-demo-gcp-us-central1.iam.gserviceaccount.com"
    },

  ]
}

module "test_shared_vpc_service_project_attachment" {
  for_each = { for project in local.test_service_projects_attachments : project.service_project_id => project }
  source   = "./service-project-attachment"

  vpc_host_network_self_link                       = google_compute_network.kbc.self_link
  gcp_region                                       = var.gcp_region
  gke_nodes_tag                                    = "gke-${each.value.keboola_stack}"
  gcp_host_project_id                              = var.gcp_project
  vpc_proxy_subnet_ip_cidr_range                   = google_compute_subnetwork.proxy.ip_cidr_range
  gcp_service_project_id                           = each.key
  keboola_stack                                    = each.value.keboola_stack
  vpc_main_subnet_primary_ip_cidr_range            = each.value.vpc_main_subnet_primary_ip_cidr_range
  vpc_main_subnet_secondary_pods_ip_cidr_range     = each.value.vpc_main_subnet_secondary_pods_ip_cidr_range
  vpc_main_subnet_secondary_services_ip_cidr_range = each.value.vpc_main_subnet_secondary_services_ip_cidr_range
  vpc_gke_master_ipv4_cidr_block                   = each.value.vpc_gke_master_ipv4_cidr_block
  deploy_stack_service_account_email               = each.value.deploy_stack_service_account_email
}
