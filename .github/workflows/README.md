# Configuración de CI/CD para GKE

Este workflow automatiza la construcción y despliegue de la aplicación en Google Kubernetes Engine (GKE).

## 🔑 Secrets Requeridos

Para que el workflow funcione correctamente, debes configurar los siguientes secrets en tu repositorio de GitHub:

### Secrets Obligatorios

#### Opción 1: Workload Identity Federation (Recomendado)
- **`GCP_WORKLOAD_IDENTITY_PROVIDER`**: Provider de Workload Identity Federation
  - Formato: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID`
- **`GCP_SERVICE_ACCOUNT`**: Email de la cuenta de servicio
  - Formato: `sa-name@project-id.iam.gserviceaccount.com`

#### Opción 2: JSON Key (Fallback)
- **`GCP_SA_KEY_JSON`**: Contenido completo del archivo JSON de la cuenta de servicio de GCP

### Configuración del Proyecto

- **`GCP_PROJECT_ID`**: ID del proyecto de GCP
  - Ejemplo: `mi-proyecto-123456`
- **`GCP_REGION`**: Región para Artifact Registry
  - Ejemplo: `us-central1`
- **`GCP_ARTIFACT_REPO`**: Nombre del repositorio de Artifact Registry
  - Ejemplo: `docker-repo`

### Configuración de GKE

- **`GKE_CLUSTER_NAME`**: Nombre del cluster de GKE
  - Ejemplo: `mi-cluster-gke`
- **`GKE_LOCATION`**: Ubicación del cluster (zona o región)
  - Ejemplo: `us-central1-a` o `us-central1`
- **`K8S_NAMESPACE`**: Namespace de Kubernetes donde se desplegará la app
  - Ejemplo: `production`

## 🚀 Cómo Ejecutar el Workflow

1. Ve a la pestaña "Actions" en tu repositorio
2. Selecciona "CI/CD - Build & Deploy to GKE"
3. Haz clic en "Run workflow"
4. (Opcional) Ingresa un "Mensaje del día" personalizado
5. Haz clic en "Run workflow" para iniciar

## 📋 Prerequisitos

### Permisos de la Cuenta de Servicio

La cuenta de servicio debe tener los siguientes roles:

```bash
# Artifact Registry
roles/artifactregistry.writer

# GKE
roles/container.developer
roles/container.clusterViewer

# Storage (si usas GCS)
roles/storage.objectViewer
```

### Comandos para Configurar Permisos

```bash
# Variables
PROJECT_ID="tu-proyecto"
SA_EMAIL="tu-sa@tu-proyecto.iam.gserviceaccount.com"

# Asignar roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.clusterViewer"
```

## 🔧 Configurar Workload Identity Federation (Recomendado)

### 1. Crear el Pool de Identidades

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### 2. Crear el Provider

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### 3. Vincular la Cuenta de Servicio

```bash
# Obtener el nombre completo del provider
WORKLOAD_IDENTITY_PROVIDER=$(gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)")

# Vincular con tu repositorio
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_PROVIDER}/attribute.repository/TU_USUARIO/TU_REPO"
```

### 4. Obtener el Provider ID para el Secret

```bash
echo $WORKLOAD_IDENTITY_PROVIDER
```

Copia este valor y úsalo como `GCP_WORKLOAD_IDENTITY_PROVIDER` en GitHub Secrets.

## 🐛 Troubleshooting

### Error: "No hay cuenta activa en gcloud"

**Causa**: La autenticación con GCP falló.

**Solución**:
1. Verifica que los secrets estén configurados correctamente
2. Si usas WIF, verifica que el provider y la cuenta de servicio estén bien configurados
3. Si usas JSON key, verifica que el contenido del JSON sea válido
4. Revisa los logs del step "Verify Google Cloud authentication" para más detalles

### Error: "Cluster no encontrado"

**Causa**: El nombre del cluster o la ubicación son incorrectos.

**Solución**:
1. Verifica el nombre del cluster: `gcloud container clusters list`
2. Verifica que `GKE_CLUSTER_NAME` y `GKE_LOCATION` sean correctos
3. Asegúrate de que la cuenta de servicio tenga acceso al cluster

### Error: "Permission denied"

**Causa**: La cuenta de servicio no tiene los permisos necesarios.

**Solución**:
1. Revisa que la cuenta de servicio tenga los roles mencionados arriba
2. Espera unos minutos después de asignar los roles (la propagación puede tardar)

## 📦 Estructura del Workflow

```
├── build (Job)
│   ├── Autenticación con GCP
│   ├── Crear/verificar Artifact Registry
│   ├── Construir imagen Docker
│   └── Publicar imagen en Artifact Registry
│
└── deploy (Job)
    ├── Autenticación con GCP
    ├── Obtener credenciales de GKE
    ├── Aplicar manifiestos de Kubernetes
    └── Actualizar deployment con nueva imagen
```

## 📝 Notas

- El workflow usa `workflow_dispatch` para ejecución manual
- La imagen Docker se etiqueta con el SHA del commit
- El deployment usa rolling update para zero-downtime
- El timeout para el rollout es de 300 segundos (5 minutos)
- Se instala automáticamente `gke-gcloud-auth-plugin` para compatibilidad

## 🔗 Referencias

- [GitHub Actions - Google Auth](https://github.com/google-github-actions/auth)
- [GKE Credentials](https://github.com/google-github-actions/get-gke-credentials)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
