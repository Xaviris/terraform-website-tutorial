# Bucket to store website
resource "google_storage_bucket" "website" {
    name = "example-website-bucket-1"
    location = "US"
}

# Make new object public
resource "google_storage_object_access_control" "public_rule" {
    object = google_storage_bucket_object.static_site_src.name
    bucket = google_storage_bucket.website.name
    role = "READER"
    entity = "allUsers"
}

# Upload html file to bucket
resource "google_storage_bucket_object" "static_site_src" {
    name = "index.html"
    source = "../website/index.html"
    bucket = google_storage_bucket.website.name
}

# Reserve static ip address
resource "google_compute_global_address" "website_ip" {
    name = "website-lb-ip"
}

# Create DNS Managed zone
resource "google_dns_managed_zone" "terraform-codecamp-tutorial" {
    name = "terraform-codecamp-tutorial"
    dns_name = "terraform-test.com."
}

# # Get managed DNS Zone
# data "google_dns_managed_zone" "dns_zone" {
#     name = "terraform-codecamp-tutorial"
# }

# Add IP to DNS
resource "google_dns_record_set" "website" {
    name = "website.${google_dns_managed_zone.terraform-codecamp-tutorial.dns_name}"
    type = "A"
    ttl = 300
    managed_zone = google_dns_managed_zone.terraform-codecamp-tutorial.name
    rrdatas = [google_compute_global_address.website_ip.address]
}

# Add bucket as CDN backend
resource "google_compute_backend_bucket" "website-backend" {
    name = "website-backend"
    bucket_name = google_storage_bucket.website.name
    description = "Contains files needed for website"
    enable_cdn = true
}

# GCP URL MAP
resource "google_compute_url_map" "website-map" {
    name = "website-url-map"
    default_service = google_compute_backend_bucket.website-backend.self_link
    host_rule {
        hosts = ["*"]
        path_matcher = "allpaths"
    }
    path_matcher {
        name = "allpaths"
        default_service = google_compute_backend_bucket.website-backend.self_link
    }
}

# GCP HTTP Proxy
resource "google_compute_target_http_proxy" "website" {
    name = "website-target-proxy"
    url_map = google_compute_url_map.website-map.self_link
}

# GCP Forwarding Rule
resource "google_compute_global_forwarding_rule" "default" {
    name = "website-forwarding-rule"
    load_balancing_scheme = "EXTERNAL"
    ip_address = google_compute_global_address.website_ip.address
    ip_protocol = "TCP"
    port_range = "80"
    target = google_compute_target_http_proxy.website.self_link
}