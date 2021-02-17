output "http_load_balancer_ip" {
  value = google_compute_global_forwarding_rule.web_tier_fwd_rule.ip_address
}
