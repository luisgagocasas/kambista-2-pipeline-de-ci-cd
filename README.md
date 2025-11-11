# Infraestructura con Terraform y GKE

## Guía de ejecución manual
Esta guía lista únicamente los pasos que tú ejecutas de forma manual. El pipeline de GitHub Actions se encarga de construir la imagen, publicar en Artifact Registry y desplegar en GKE.

### Requisitos previos
- Terraform `>= 1.6` y provider `google >= 5.0`.
- Proyecto GCP con facturación habilitada.
- Cuenta de servicio para despliegue y llave JSON disponible localmente.
- Secrets en GitHub (Settings → Secrets and variables → Actions):
  - `GCP_PROJECT_ID`, `GCP_REGION`, `GCP_ARTIFACT_REPO`, `GKE_CLUSTER_NAME`, `GKE_LOCATION`, `GCP_SERVICE_ACCOUNT`, `K8S_NAMESPACE`.
  - `GCP_WORKLOAD_IDENTITY_PROVIDER` con `projectNumber`: `projects/668774990103/locations/global/workloadIdentityPools/github-pool/providers/github-provider`.
  - Opcional (fallback si falla WIF): `GCP_SA_KEY_JSON` con el contenido de la llave JSON de la service account.

### Paso 1: Terraform (infraestructura)
- `terraform -chdir=terraform init`
- `terraform -chdir=terraform plan`
- `terraform -chdir=terraform apply -auto-approve`

### Paso 2: kubeconfig local (solo bootstrap inicial)
- `terraform -chdir=terraform output -raw write_kubeconfig_cmd | bash`

### Paso 3: Bootstrap de Kubernetes (una sola vez)
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/namespace.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml create secret docker-registry artifact-registry-pull --docker-server=us-central1-docker.pkg.dev --docker-username=_json_key --docker-password="$(cat terraform/kambista-477721-4c3fb4146f9f.json)" -n kanbista`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/deployment.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/service.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -n kanbista --validate=false -f k8s/ingress.yaml`

Nota: usa `kubectl` nuevamente solo si cambias los manifiestos en `k8s/`.

### Paso 4: Ejecutar el workflow (cada despliegue)
- En GitHub → Actions → "CI/CD - Build & Deploy to GKE" → "Run workflow".
- Selecciona `branch` y escribe `mensaje_del_dia`.

Nota: el workflow intenta autenticarse primero con Workload Identity Federation. Si falla, usa el secret `GCP_SA_KEY_JSON` como fallback para garantizar el despliegue.

### Acceso (opcional)
- IP del Ingress: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml get ingress hello-node-ingress -n kanbista -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- Abre `http://<INGRESS_IP>/`.

#### Comandos en vivo (fundamentales)
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista get ingress hello-node-ingress -w`: observa cambios del Ingress en tiempo real.
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista get pods -w`: ve creación/actualización de pods conforme al rollout.
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista rollout status deploy/hello-node`: sigue el estado del despliegue hasta completar.
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista logs -f deploy/hello-node`: tail de logs de la aplicación durante el despliegue.
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista get events --sort-by=.lastTimestamp`: revisa eventos recientes para diagnosticar rápidamente.

### Borrado (opcional)
- `terraform -chdir=terraform destroy -auto-approve`
