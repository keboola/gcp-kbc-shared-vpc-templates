variable "keboola_stack" {
  description = "Keboola stack"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "gcp_host_project_id" {
  description = "GCP Host project id"
  type        = string
}

variable "gcp_service_project_id" {
  description = "GCP Service project id"
  type        = string
}

variable "vpc_main_subnet_primary_ip_cidr_range" {
  description = "VPC main subnet primary ip cidr range"
  type        = string
}

variable "vpc_main_subnet_secondary_pods_ip_cidr_range" {
  description = "VPC main subnet secondary pods ip cidr range"
  type        = string
}

variable "vpc_main_subnet_secondary_services_ip_cidr_range" {
  description = "VPC main subnet secondary services ip cidr range"
  type        = string
}
variable "vpc_gke_master_ipv4_cidr_block" {
  description = "VPC GKE main subnet primary ip cidr range (shold be /28)"
  type        = string
}

variable "gke_nodes_tag" {
  description = "GKE nodes tag"
  type        = string
}

variable "vpc_host_network_self_link" {
  description = "Host network self link"
  type        = string
}

variable "vpc_proxy_subnet_ip_cidr_range" {
  description = "VPC proxy subnet ip cidr range"
  type        = string
}

variable "deploy_stack_service_account_email" {
  description = "Deploy stack service account email"
  type        = string
}
