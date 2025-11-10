resource "google_project_service" "cloudresourcemanager" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "serviceusage" {
  project            = var.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.cloudresourcemanager]
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.serviceusage]
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.serviceusage]
}

resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.artifact_registry_repo
  format        = "DOCKER"
  project       = var.project_id
  depends_on    = [google_project_service.artifactregistry]
}

resource "google_container_cluster" "gke" {
  name                     = var.cluster_name
  location                 = var.location
  network                  = "default"
  remove_default_node_pool = false
  initial_node_count       = 1
  deletion_protection      = false
  project                  = var.project_id
  node_config {
    disk_type    = var.node_disk_type
    disk_size_gb = var.node_disk_size_gb
  }
  addons_config {
    http_load_balancing {
      disabled = false
    }
  }
  depends_on = [google_project_service.container]
}
