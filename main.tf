locals {
  web_tier   = "web-tier-node"
  app_tier   = "app-tier-node"
}

# Create a service account for VM instances
resource "google_service_account" "gce-vm-sa" {
  account_id   = "gce-vm-service-account"
  display_name = "CompanyNews GCE Service Account"
}

# Create a custom network
resource "google_compute_network" "companynews_vpc_network" {
  name = "companynews-vpc-network"
  auto_create_subnetworks = false
}

# Create a subnetwork for WEB tier
resource "google_compute_subnetwork" "web_tier_subnetwork" {
  name          = "web-tier-subnetwork"
  ip_cidr_range = "10.1.0.0/24"
  region        = var.region_aus
  network       = google_compute_network.companynews_vpc_network.id
  private_ip_google_access	=	true 
}

# Create a subnetwork for APP tier
resource "google_compute_subnetwork" "app_tier_subnetwork" {
  name          = "app-tier-subnetwork"
  ip_cidr_range = "10.2.0.0/24"
  region        = var.region_aus
  network       = google_compute_network.companynews_vpc_network.id
  private_ip_google_access	=	true 
}

# Create Cloud Router and Cloud NAT
resource "google_compute_router" "companynews_router" {
  name    = "company-router"
  region  = var.region_aus
  network = google_compute_network.companynews_vpc_network.id 
}

resource "google_compute_router_nat" "companynews_nat" {
  name                               = "companynews-nat"
  router                             = google_compute_router.companynews_router.name
  region                             = var.region_aus
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Define Instance template for WEB tier
resource "google_compute_instance_template" "web-tier-template" {
  name        = "${local.web_tier}-template"
  description = "This template is used to create Web Tier server."
  tags = ["allow-incoming-ssh", "${local.web_tier}"]

  labels = {
    confidentiality = "confidential",
    trustlevel      = "high",
    integrity       = "highlytrusted"
    environment     = var.env  
  }

  instance_description = local.web_tier
  machine_type         = "n1-standard-1"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

# Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.os_image.self_link
    disk_size_gb = 50
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = google_compute_network.companynews_vpc_network.id
    subnetwork = google_compute_subnetwork.web_tier_subnetwork.id
  }

  metadata = merge(
    {
      enable-osconfig = "TRUE",
      enable-os-inventory = "TRUE",
      enable-guest-attributes = "TRUE",
      enable-oslogin = "TRUE",
    },
  )

  metadata_startup_script = "${file("web-tier-startup-script.sh")}"

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.gce-vm-sa.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "google_compute_health_check" "web_tier_autohealing" {
  name                = "${local.web_tier}-autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "80"
  }
}

# Create a Managed instance Group for Web Tier
resource "google_compute_region_instance_group_manager" "web_tier_mig" {
  name                       = "${local.web_tier}-cluster"
  base_instance_name         = local.web_tier
  region                     = var.region_aus
  distribution_policy_zones  = var.availability_zones_aus
  version {
    instance_template = google_compute_instance_template.web-tier-template.self_link
  }
  target_size  = var.web_tier_node_size
  named_port {
    name = "http"
    port = 80
  }
  
  auto_healing_policies {
  health_check      = google_compute_health_check.web_tier_autohealing.self_link
  initial_delay_sec = 300
  }
}

# Define Instance template for APP tier
resource "google_compute_instance_template" "app-tier-template" {
  name        = "${local.app_tier}-template"
  description = "This template is used to create Web Tier server."
  tags = ["allow-incoming-ssh", "${local.app_tier}"]

  labels = {
    confidentiality = "confidential",
    trustlevel      = "high",
    integrity       = "highlytrusted"
    environment     = var.env  
  }

  instance_description = local.app_tier
  machine_type         = "n1-standard-1"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

# Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.os_image.self_link
    disk_size_gb = 50
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = google_compute_network.companynews_vpc_network.id
    subnetwork = google_compute_subnetwork.app_tier_subnetwork.id
  }

  metadata = merge(
    {
      enable-osconfig = "TRUE",
      enable-os-inventory = "TRUE",
      enable-guest-attributes = "TRUE",
      enable-oslogin = "TRUE",
    },
  )

  metadata_startup_script = "${file("app-tier-startup-script.sh")}"

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.gce-vm-sa.email
    scopes = ["cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create firewall rule to connect to Web tier VM
resource "google_compute_firewall" "web_tier_fw_rules" {
  name    = "${local.web_tier}-firewall-rules"
  network = google_compute_network.companynews_vpc_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  source_ranges = ["0.0.0.0/0"]

# target_service_accounts = [google_service_account.gce-vm-sa.email]
  target_tags = ["${local.web_tier}"]
}

resource "google_compute_health_check" "app_tier_autohealing" {
  name                = "${local.app_tier}-autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "80"
  }
}

# Create a Managed instance Group for APP Tier
resource "google_compute_region_instance_group_manager" "app_tier_mig" {
  name                       = "${local.app_tier}-cluster"
  base_instance_name         = local.app_tier
  region                     = var.region_aus
  distribution_policy_zones  = var.availability_zones_aus
  version {
    instance_template = google_compute_instance_template.app-tier-template.self_link
  }
  target_size  = var.app_tier_node_size
  named_port {
    name = "http"
    port = 80
  }
  
  auto_healing_policies {
  health_check      = google_compute_health_check.app_tier_autohealing.self_link
  initial_delay_sec = 300
  }
}

# Create firewall rule to connect to APP tier VM
resource "google_compute_firewall" "app_tier_fw_rules" {
  name    = "${local.app_tier}-firewall-rules"
  network = google_compute_network.companynews_vpc_network.id

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["${local.app_tier}"]
}

# Create firewall rule to connect to APP tier Application from WEB tier
resource "google_compute_firewall" "app_tier_web_fw_rules" {
  name    = "${local.app_tier}-web-firewall-rules"
  network = google_compute_network.companynews_vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["10.1.0.0/24"]

# target_service_accounts = [google_service_account.gce-vm-sa.email]
  target_tags = ["${local.app_tier}"]
}

# HTTPS Load balancer - backend service
resource "google_compute_backend_service" "web_tier_bs" {
  provider                        = google-beta
  name                            = "${local.web_tier}-backend-service"
  protocol                        = "HTTP"
  connection_draining_timeout_sec = 10
  health_checks = [google_compute_http_health_check.bs_health_check.id]
  backend {
    group = google_compute_region_instance_group_manager.web_tier_mig.instance_group
  } 
}

resource "google_compute_http_health_check" "bs_health_check" {
  name               = "bs-health-check"
  check_interval_sec = 1
  timeout_sec        = 1
}

# HTTPS Load balancer - url map
# URL maps define matching patterns for URL-based routing of requests to the appropriate backend services. 
# A default service is defined to handle any requests that do not match a specified host rule or path matching rule.
resource "google_compute_url_map" "web_tier_url_map" {
  provider = google-beta
  name            = "${local.web_tier}-load-balancer"
  description     = "URL-based routing of requests to Web Tier backend service"
  default_service = google_compute_backend_service.web_tier_bs.id
}

# HTTPS Load Balancer - target proxy
# Target proxies terminate HTTP(S) connections from clients. 
# One or more global forwarding rules direct traffic to the target proxy, and the target proxy consults the URL map to determine how to route traffic to backends.
resource "google_compute_target_http_proxy" "web_tier_http_proxy" {
  provider = google-beta
  name    = "${local.web_tier}-http-proxy"
  description = "wen tier http proxy"
  url_map = google_compute_url_map.web_tier_url_map.id
}

# Global forwarding rules route traffic by IP address, port, and protocol to a load balancing configuration consisting of a target proxy, URL map, and one or more backend services.
resource "google_compute_global_forwarding_rule" "web_tier_fwd_rule" {
  provider = google-beta
  name   = "web-tier-forwarding-rule"
  port_range            = "80"
  target                = google_compute_target_http_proxy.web_tier_http_proxy.self_link
}
