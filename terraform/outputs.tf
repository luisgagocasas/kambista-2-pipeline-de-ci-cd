output "cluster_endpoint" {
  value       = google_container_cluster.gke.endpoint
  description = "Endpoint público del API server de GKE"
}

output "write_kubeconfig_cmd" {
  value       = <<-EOT
printf %s '${google_container_cluster.gke.master_auth[0].cluster_ca_certificate}' | base64 -d > ca.crt && \
kubectl config set-cluster '${google_container_cluster.gke.name}' --server='https://${google_container_cluster.gke.endpoint}' --certificate-authority=ca.crt --embed-certs=true --kubeconfig=./kubeconfig-kanbista.yaml && \
kubectl config set-credentials sa-user --token='${data.google_client_config.default.access_token}' --kubeconfig=./kubeconfig-kanbista.yaml && \
kubectl config set-context sa-context --cluster='${google_container_cluster.gke.name}' --user=sa-user --kubeconfig=./kubeconfig-kanbista.yaml && \
kubectl --kubeconfig ./kubeconfig-kanbista.yaml config use-context sa-context && \
rm -f ca.crt
EOT
  description = "Generar kubeconfig local con kubectl config"
  sensitive   = true
}

output "cluster_name" {
  value       = google_container_cluster.gke.name
  description = "Nombre del cluster GKE"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.gke.master_auth[0].cluster_ca_certificate
  description = "Certificado CA del cluster (base64)"
  sensitive   = true
}

output "gcp_access_token" {
  value       = data.google_client_config.default.access_token
  description = "Token de acceso GCP para kubeconfig (caduca)"
  sensitive   = true
}
