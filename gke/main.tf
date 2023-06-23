# resource "google_project_service" "gke-project" {
#   project = "gke-demo-project"
#   #name    = "gke-demo-project"
#   service = "iam.googleapis.com"
  
# }
resource "google_compute_network" "gke-vpc_network" {
  project                 = "miza-org-project"
  name                    = "gke-vpc-network"
}

resource "google_compute_subnetwork" "gke-subnet" {
  name          = "gke-subnetwork"
  project       = "miza-org-project"
  ip_cidr_range =  "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.gke-vpc_network.id
#   secondary_ip_range {
#     range_name    = "tf-test-secondary-range-update1"
#     ip_cidr_range = "192.168.10.0/24"
#  }
}
resource "google_service_account" "gke-sc" {
  project      = "miza-org-project"
  account_id   = "myservice-id"
  display_name = "gke-service-account"
}

resource "google_container_cluster" "gke-cluster" {
  project  = "miza-org-project"
  name     = "my-gke-cluster"
  location = "us-central1"
  network  = google_compute_network.gke-vpc_network.self_link
  subnetwork = google_compute_subnetwork.gke-subnet.self_link
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "gke-nodepool" {
  name               = "gke-nodepool"
  project            = "miza-org-project"
  location           = "us-central1"
  cluster            = google_container_cluster.gke-cluster.name
  #max_pods_per_node  = "10"
  #version            = var.gke_version
  initial_node_count = 1

  # Autoscaling config.
  autoscaling {
    min_node_count = "2"
    max_node_count = "10"
  }

  lifecycle {
    ignore_changes = [
      initial_node_count
    ]
  }

  # Management Config
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    service_account = google_service_account.gke-sc.email
    preemptible     = false
    machine_type    = ""
    disk_type       = "pd-standard"
    disk_size_gb    = "20"

    # Needed for correctly functioning cluster, see
    # https://www.terraform.io/docs/providers/google/r/container_cluster.html#oauth_scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/userinfo.email"
    ]

    # metadata = {
    #   disable-legacy-endpoints = "true"
    # }

    # labels = {
    #   "cloud.google.com/gke-preemptible" = false
    # }

    tags = ["kubernetes"]
  }
}