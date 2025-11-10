variable "project_id" {
  type = string
}

variable "credentials_file_path" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "location" {
  type    = string
  default = "us-central1"
}

variable "cluster_name" {
  type    = string
  default = "kanbista-gke"
}

variable "artifact_registry_repo" {
  type    = string
  default = "kanbista-app"
}

variable "node_disk_type" {
  type    = string
  default = "pd-standard"
}

variable "node_disk_size_gb" {
  type    = number
  default = 50
}
