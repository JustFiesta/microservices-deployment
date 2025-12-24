# Helm Chart - Microservices Demo

Helm chart for deploying the Online Boutique microservices application to Kubernetes. This chart is designed for GitOps deployment via ArgoCD with environment-specific value overrides.

## Chart Overview

This chart packages all microservices into a single deployment unit with:

- Environment-specific configuration via values files
- Centralized image registry and tagging
- Resource limits and requests per service
- Ingress configuration for external access
- Horizontal Pod Autoscaler (HPA) support

---

## Architecture Pattern

### Environment-Based Values Files

The chart uses **base + overlay pattern** for configuration:

```shell
helm/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Base values (defaults)
├── values-dev.yaml         # Dev environment overrides
└── templates/              # Kubernetes manifest templates
    ├── adservice.yaml
    ├── cartservice.yaml
    ├── frontend.yaml
    ├── hpa.yaml
    └── ...
```

**How it works**:

1. `values.yaml` defines defaults for all services
2. Environment-specific files override only what's different
3. ArgoCD applies: `helm template -f values.yaml -f values-dev.yaml`

---

## Configuration Philosophy

### Image Tagging Strategy

Each service can use either:

1. **Global Tag** (default): `global.image.tag: "dev"`
   - All services pull `dev` tag (environment-latest)
   - Used when no per-service tag is specified

2. **Per-Service Tag** (override): `frontend.image.tag: "dev-1.2.3"`
   - Specific version for individual service
   - Allows gradual rollout becouse every service can be versioned separettly
   - Example: Most services use `dev`, frontend uses `dev-1.2.5`

**Image URI Construction**:

```yaml
# Template logic
image: {{ .Values.global.image.registry }}/{{ .Values.global.image.project }}/{{ .Values.adservice.image.name }}:{{ .Values.adservice.image.tag | default .Values.global.image.tag }}

# Result
123456789010.dkr.ecr.eu-west-1.amazonaws.com/test-microservices-demo/adservice:dev-1.0.0
```

### Environment-Specific Overrides

One can create more ovverides suited for each needs. I staied with basic ones as this is just a demonstation of automation.

**Dev Environment** (`values-dev.yaml`):

- Uses `dev` tag for all services
- Lower resource limits
- LoadGenerator enabled with high traffic
- Single replica per service

---

## Service Configuration

### Base Configuration Pattern

Each service in `values.yaml` follows this structure:

```yaml
servicename:
  enabled: true              # Enable/disable service
  replicaCount: 1            # Number of replicas
  image:
    name: servicename        # Image name (matches ECR repository)
    tag: ""                  # Optional override (defaults to global.image.tag)
  port: 8080                 # Container port
  resources:                 # Resource limits
    requests:
      cpu: 200m
      memory: 180Mi
    limits:
      cpu: 300m
      memory: 300Mi
  env:                       # Environment variables (if needed)
    - name: VAR_NAME
      value: "value"
```

---

## GitOps Deployment with ArgoCD

### ArgoCD Integration

This chart is deployed via ArgoCD Applications defined in `/argocd/<env>/` directory.

**ArgoCD Application Pattern**:

```yaml
# argocd/dev/microservices-demo-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microservices-demo-dev
spec:
  source:
    repoURL: https://github.com/your-org/microservices-demo
    targetRevision: main
    path: helm
    helm:
      valueFiles:
        - values.yaml
        - values-dev.yaml  # Environment-specific overrides
  destination:
    namespace: dev
```

**Workflow**:

1. Developer updates `values-dev.yaml` with new image tag
2. Creates PR, merges to main
3. ArgoCD detects git change
4. ArgoCD runs `helm template` with merged values
5. ArgoCD applies manifests to Kubernetes
6. Kubernetes pulls new images from ECR

---

## Ingress Configuration

### Ingress Pattern

The chart creates an Ingress resource for the frontend service:

```yaml
# values.yaml
global:
  ingress:
    enabled: true
    className: "nginx"
    host: ""  # Catch-all (any host)
    annotations: {}
```

**Why NGINX Ingress Controller?**

- Terraform deploys NGINX Ingress Controller to cluster (`terraform/environments/dev/helm.tf`)
- Creates AWS LoadBalancer automatically
- No additional ingress configuration needed

**Access Pattern**:

```
User → AWS ELB → NGINX Ingress Controller → frontend Service → frontend Pods
```

### Environment-Specific Ingress

**Dev**: Catch-all host (any hostname works)
**Prod**: Specific hostname (e.g., `shop.example.com`)

```yaml
# values-prod.yaml
global:
  ingress:
    host: "shop.example.com"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

---

## Horizontal Pod Autoscaler (HPA)

### HPA Configuration

Template: `templates/hpa.yaml`

The chart includes HPA support for auto-scaling based on CPU/memory. It is configured to scale Frontend based on its load. Loadgenerator is setted to push it to limits, to see how HPA reacts.

### HPA in Action

**Observed Behavior with LoadGenerator**:

When LoadGenerator is enabled with high traffic settings (`values-dev.yaml`):
- **LoadGenerator** sends continuous requests to frontend
- **Frontend** CPU usage increases under load
- **HPA** detects CPU > 80% threshold
- **Kubernetes** automatically scales frontend replicas (e.g., 1 → 3 pods)
- **ArgoCD** ignores replica count differences (HPA manages this)

**Why ArgoCD Ignores Replicas**:
- HPA dynamically adjusts `spec.replicas` in Deployment
- ArgoCD detects this as "drift" from git state
- ArgoCD is configured to **ignore** `spec.replicas` field when HPA is present
- This prevents ArgoCD from constantly reverting HPA scaling decisions

**Configuration** (ArgoCD Application):
```yaml
# argocd/dev/microservices-demo-dev.yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore when HPA is active
```

**Result**: Git defines desired baseline (1 replica), HPA manages actual count (1-5 replicas) based on load

---

## CI/CD Integration

Integration is paused by 1 manual step - user needs to create PR and change tag in values file per environment. This ensures what is tested and when.

### Image Tag Management

**CI Pipeline** (`ci.yaml`):

1. Builds new image: `frontend:dev-1.2.5`
2. Pushes to ECR

**Manual Update** (current approach):

1. Developer updates `values-dev.yaml`:

   ```yaml
   frontend:
     image:
       tag: "dev-1.2.5"
   ```

2. Creates PR, merges
3. ArgoCD deploys new version

### Validation Workflow

**Helm Chart CI** (`helm-ci.yaml`):

1. Runs `helm lint` on chart
2. Renders templates: `helm template -f values.yaml -f values-dev.yaml`
3. Validates with Kubeconform (Kubernetes schema validation)
4. Ensures manifests are valid before merge

## Local Testing

### Render Templates Locally

```bash
# Render with dev values
helm template microservices-demo ./helm \
  -f helm/values.yaml \
  -f helm/values-dev.yaml \
  --debug

# Render specific service
helm template microservices-demo ./helm \
  -f helm/values-dev.yaml \
  -s templates/frontend.yaml
```

---

## Adding New Environment

This operation needs kubectl to be configured aganist EKS cluster - here is assumed it was QA environment was created via Terraform Workflows and kubectl configured manually on local machine.

### Steps to Create QA Environment

1. **Create values file**: `helm/values-qa.yaml`

    ```yaml
    # values-qa.yaml
    global:
    image:
        tag: "qa"

    # Override specific services with versions
    frontend:
    image:
        tag: "qa-1.2.5"

    # Higher resources for QA
    currencyservice:
    replicaCount: 2
    resources:
        requests:
        cpu: 300m
        memory: 256Mi
    ```

2. **Create ArgoCD Application**: `argocd/qa/microservices-demo-qa.yaml`

    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
    name: microservices-demo-qa
    spec:
    source:
        path: helm
        helm:
        valueFiles:
            - values.yaml
            - values-qa.yaml
    destination:
        namespace: qa
    ```

3. **Deploy to cluster**:

    ```bash
    kubectl apply -f argocd/qa/microservices-demo-qa.yaml -n argocd
    ```

## Chart Versioning

**Chart Version** (`Chart.yaml`):

- Incremented when chart structure changes (templates, new features)
- Does NOT change when updating image tags in values files

**Application Version**: Not used (per-service versioning instead, basing on tags)

**When to bump chart version**:

- Adding new service template
- Changing template logic
- Adding new values parameters
- Breaking changes to existing values

---

## Related Documentation

- **ArgoCD Configuration**: See [`/argocd/README.md`](/argocd/README.md)
- **CI/CD Workflows**: See [`/.github/README.md`](/.github/README.md)
- **Infrastructure**: See [`/terraform/README.md`](/terraform/README.md)
- **Application**: See [`/microservices-demo/README.md`](/microservices-demo/README.md)
