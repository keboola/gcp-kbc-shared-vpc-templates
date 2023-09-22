output "vpc_main_subnet_self_link" {
  value       = google_compute_subnetwork.main.self_link
  description = "Keboola main subnet self_link"
}

output "keboola_stack" {
  value       = var.keboola_stack
  description = "Keboola stack name"
}
