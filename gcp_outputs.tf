/*
 * Terraform output variables for GCP.
 */

output "global_ip" {
  value = google_compute_global_address.default.address
}

output "external_fqdn" {
  value = google_compute_global_network_endpoint.proxy.fqdn
}


