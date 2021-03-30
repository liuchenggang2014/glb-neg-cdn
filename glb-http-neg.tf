provider "google" {
  # Update credentials to the correct location, alternatively set   GOOGLE_APPLICATION_CREDENTIALS=/path/to/.ssh/bq-key.json in your shell session and   remove the credentials attribute.
  #   credentials = file("cliu201-sa.json")
  project = "cliu201"
  region  = "us-central1"
  zone    = "us-central1-c"

}

provider "google-beta" {
  # Update credentials to the correct location, alternatively set   GOOGLE_APPLICATION_CREDENTIALS=/path/to/.ssh/bq-key.json in your shell session and   remove the credentials attribute.
  #   credentials = file("cliu201-sa.json")
  project = "cliu201"
  region  = "us-central1"
  zone    = "us-central1-c"

}

###########################  
# install terraform and run terraform init & terraform apply
# 1. create internet NEG with https://www.google.com
# 2. create the backend service with the instance group
# 3. create url map and http target proxy
# 4. create global ip
# 5. create forwarding rule
###########################  





###########################         01-create internel NEG        ########################### 
resource "google_compute_global_network_endpoint_group" "neg" {
  name                  = "my-lb-neg"
  default_port          = "443"
  network_endpoint_type = "INTERNET_FQDN_PORT"
}

resource "google_compute_global_network_endpoint" "proxy" {
  global_network_endpoint_group = google_compute_global_network_endpoint_group.neg.name
  fqdn                          = "www.google.com"
  port                          = 443
}



########################### 02-create backend service and health check  ########################### 
resource "google_compute_backend_service" "be-gameserver" {
  provider                        = google-beta
  protocol                        = "HTTPS"
  name                            = "be-gameserver-2"
  enable_cdn                      = true
  timeout_sec                     = 30
  connection_draining_timeout_sec = 30
  cdn_policy {
    cache_mode  = "FORCE_CACHE_ALL"
    default_ttl = 3600
    client_ttl  = 7200
    # max_ttl     = 10800
    cache_key_policy {
      include_host         = "false"
      include_protocol     = "false"
      include_query_string = "false"
    }
  }

  custom_request_headers  = ["host: ${google_compute_global_network_endpoint.proxy.fqdn}"]
  custom_response_headers = ["X-Cache-Hit: {cdn_cache_status}"]

  backend {
    group = google_compute_global_network_endpoint_group.neg.id
  }
}

resource "google_compute_http_health_check" "default" {
  name               = "health-check-2"
  request_path       = "/"
  check_interval_sec = 5
  timeout_sec        = 5
}

###########################  4. create url map and http target proxy
resource "google_compute_target_http_proxy" "game-target-http-proxy" {
  name    = "tgame-target-http-proxy-2"
  url_map = google_compute_url_map.game-url-map.id
}

resource "google_compute_url_map" "game-url-map" {
  name            = "game-url-map-2"
  default_service = google_compute_backend_service.be-gameserver.id

  #   host_rule {
  #     hosts        = ["*"]
  #     path_matcher = "allpaths"
  #   }

  #   path_matcher {
  #     name            = "allpaths"
  #     default_service = google_compute_backend_service.be-gameserver.id

  #     path_rule {
  #       paths   = ["/*"]
  #       service = google_compute_backend_service.be-gameserver.id
  #     }
  #   }
}




########################### 5. create global ip########################### 
resource "google_compute_global_address" "default" {
  name = "glb-http-neg-global-ip"
}


########################### 6. create forwarding rule ########################### 
resource "google_compute_global_forwarding_rule" "global-rule" {

  name       = "global-rule-game-2"
  target     = google_compute_target_http_proxy.game-target-http-proxy.id
  ip_address = google_compute_global_address.default.address
  port_range = "80"
}




