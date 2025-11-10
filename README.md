# Infraestructura con Terraform y GKE

## CI/CD con GitHub Actions (build remoto y deploy automático)
Este proyecto construye y publica la imagen Docker en Artifact Registry y actualiza el deployment en GKE mediante GitHub Actions.

### Credenciales y configuración
1. Habilita APIs necesarias en GCP:
   ```bash
   export PROJECT_ID="kambista-477721"
   gcloud services enable iamcredentials.googleapis.com iam.googleapis.com artifactregistry.googleapis.com container.googleapis.com --project "$PROJECT_ID"
   ```
2. Obtén el número del proyecto:
   ```bash
   export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
   ```
3. Crea Workload Identity Pool y Provider para GitHub:
   ```bash
   gcloud iam workload-identity-pools create github-pool \
     --project "$PROJECT_ID" --location=global \
     --display-name="GitHub Pool"

   gcloud iam workload-identity-pools providers create-oidc github-provider \
     --project "$PROJECT_ID" --location=global \
     --workload-identity-pool=github-pool \
     --display-name="GitHub OIDC" \
     --issuer-uri="https://token.actions.githubusercontent.com" \
     --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

   # Reemplaza <owner>/<repo> por tu organización/repositorio de GitHub
   gcloud iam workload-identity-pools providers update-oidc github-provider \
     --project "$PROJECT_ID" --location=global \
     --workload-identity-pool=github-pool \
     --attribute-condition="assertion.repository=='<owner>/<repo>'"

   export WIF_PROVIDER="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
   ```
4. Crea la cuenta de servicio para GitHub Actions y asigna permisos:
   ```bash
   gcloud iam service-accounts create github-actions-deployer \
     --project "$PROJECT_ID" \
     --display-name "GitHub Actions Deployer"

   gcloud iam service-accounts add-iam-policy-binding \
     github-actions-deployer@"$PROJECT_ID".iam.gserviceaccount.com \
     --project "$PROJECT_ID" \
     --role "roles/iam.workloadIdentityUser" \
     --member "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/<owner>/<repo>"

   gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member "serviceAccount:github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
     --role "roles/artifactregistry.writer"

   gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member "serviceAccount:github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
     --role "roles/container.admin"
   ```
5. Crea los secretos en GitHub (Settings → Secrets and variables → Actions):
   - `GCP_PROJECT_ID` = `kambista-477721`
   - `GCP_REGION` = `us-central1` (o tu región)
   - `GCP_ARTIFACT_REPO` = `kanbista-apptest5` (o el repo creado por Terraform)
   - `GKE_CLUSTER_NAME` = `kanbista-pruebatest5` o `kanbista-gke`
   - `GKE_LOCATION` = `us-central1-a` (zona) o `us-central1` (región), según Terraform
   - `GCP_WORKLOAD_IDENTITY_PROVIDER` = valor de `$WIF_PROVIDER`
   - `GCP_SERVICE_ACCOUNT` = `github-actions-deployer@kambista-477721.iam.gserviceaccount.com`
   - (opcional) `K8S_NAMESPACE` si cambias el namespace; por defecto `kanbista`

### Ejecutar el workflow
1. En GitHub → Actions → "CI/CD - Build & Deploy to GKE" → "Run workflow".
2. Selecciona el `branch` y escribe el `mensaje_del_dia`.
3. El pipeline construye la imagen con el mensaje bajo el `h1` del `index.html`, publica en Artifact Registry y actualiza el deployment `hello-node` en `kanbista`.

## Requisitos
- Terraform `>= 1.6`
- Provider `google >= 5.0`
- `kubectl` instalado
- Docker instalado
- Proyecto de GCP con facturación habilitada y una cuenta de servicio con llave JSON (`terraform/kambista-477721-4c3fb4146f9f.json`)

## Paso 1: Terraform
- `terraform -chdir=terraform init`
- `terraform -chdir=terraform plan`
- `terraform -chdir=terraform apply -auto-approve`

## Paso 2: Docker
Este paso se realiza ahora con GitHub Actions (ver sección CI/CD). No es necesario construir localmente.

## Paso 3: Kubeconfig
- `terraform -chdir=terraform output -raw write_kubeconfig_cmd | bash`

## Paso 4: Despliegue en namespace `kanbista`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/namespace.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml create secret docker-registry artifact-registry-pull --docker-server=us-central1-docker.pkg.dev --docker-username=_json_key --docker-password="$(cat terraform/kambista-477721-4c3fb4146f9f.json)" -n kanbista`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/deployment.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -f k8s/service.yaml`
- `kubectl --kubeconfig ./kubeconfig-kanbista.yaml apply -n kanbista --validate=false -f k8s/ingress.yaml`

## Paso 5: URL del sitio
- Obtener IP del Ingress: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml get ingress hello-node-ingress -n kanbista -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- Acceder: `http://<INGRESS_IP>/` (puede tardar 1–3 minutos en asignarse)
- IP del API server (referencia): `terraform -chdir=terraform output -raw cluster_endpoint`

### Información en vivo (monitoreo)
- Eventos del Ingress: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml describe ingress hello-node-ingress -n kanbista`
- Observación del Ingress: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml -n kanbista get ingress hello-node-ingress -w`
- Service y endpoints: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml get svc hello-node -n kanbista` y `kubectl --kubeconfig ./kubeconfig-kanbista.yaml get endpoints hello-node -n kanbista`
- Pods: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml get pods -n kanbista`
- Detalle del deployment: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml describe deploy hello-node -n kanbista`
- Estado de rollout: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml rollout status deploy/hello-node -n kanbista`
- Logs de la app: `kubectl --kubeconfig ./kubeconfig-kanbista.yaml logs -f deploy/hello-node -n kanbista`

## Borrado
- `terraform -chdir=terraform destroy -auto-approve`
