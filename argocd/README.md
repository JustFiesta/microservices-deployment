# ArgoCD Applications

This directory contains ArgoCD Application manifests for the microservices-demo project across different environments.

## Why ArgoCD?

This project uses ArgoCD as a declarative, GitOps continuous delivery tool to automate Kubernetes deployments. ArgoCD continuously monitors this Git repository and automatically synchronizes the desired application state with the actual cluster state.

**Key benefits for this project:**

- **GitOps workflow**: All deployment configurations are versioned in Git, providing a single source of truth
- **Automated deployments**: Changes to Helm charts are automatically deployed when merged to the main branch
- **Multi-environment management**: Easy management of dev, staging, and prod environments from a single repository
- **Rollback capability**: Quick rollback to any previous version through Git history
- **Declarative configuration**: Infrastructure and application state defined as code
- **Visibility**: Full audit trail of who deployed what and when through Git commits

## Structure

Application manifests are organized by environment in subdirectories:

```shell
argocd/
├── dev/
│   └── microservices-demo.yaml
├── staging/
│   └── microservices-demo.yaml
├── prod/
│   └── microservices-demo.yaml
└── test-qa/
    └── microservices-demo.yaml
```

Each environment has its own directory containing the application manifest(s) for that environment.

## Prerequisites

Before working with ArgoCD applications, ensure you have:

1. **AWS CLI**

2. **kubectl**

3. **Configured kubectl context** - Access to the AWS EKS cluster

   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster-name>

   kubectl config current-context
   kubectl get nodes
   ```

4. **ArgoCD installed** on the cluster (in `argocd` namespace)

## Configuration Notes

- Applications use **automated sync** with `prune` and `selfHeal` enabled
- Environment-specific values are managed via Helm values files (e.g., `values-dev.yaml`)
- Each environment deploys to its own namespace

## Getting Initial ArgoCD Password

After installing ArgoCD, retrieve the initial admin password:

```bash
# Get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# Login via CLI (assuming ArgoCD is exposed publicly)
argocd login <argocd-server-url> --username admin --password <password-from-above>

# Change the password (recommended)
argocd account update-password
```

> **Note:** If ArgoCD is not exposed publicly, you can use port-forwarding:
> ```bash
> kubectl port-forward svc/argocd-server -n argocd 8080:443
> argocd login localhost:8080 --username admin --password <password>
> ```

## User Responsibilities

**Users are fully responsible for:**

1. **Creating** - Writing ArgoCD Application manifests
2. **Validation** - Ensuring YAML syntax and configuration correctness
3. **Deployment** - Applying manifests to the cluster
4. **Management** - Syncing, rolling back, and monitoring applications

> **Note:** There is no CI/CD pipeline for these manifests as they are typically created once per environment and rarely modified. Once applied, ArgoCD handles continuous deployment of your actual application code automatically.

## Workflow for Adding Applications

### 1. Create Application Manifest

Create a new environment directory and manifest file:

```bash
# Create environment directory
mkdir -p argocd/test

# Create manifest file
cat > argocd/test/microservices-demo.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: microservices-demo-test
  namespace: argocd
  labels:
    environment: test
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/microservices-demo.git
    targetRevision: main
    path: helm
    helm:
      valueFiles:
      - values.yaml
      - values-test.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: test
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

### 2. Validate the Manifest

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f argocd/test/microservices-demo.yaml
```

### 3. Deploy to ArgoCD

```bash
# Apply the manifest
kubectl apply -f argocd/test/microservices-demo.yaml -n argocd

# Or apply all manifests for an environment
kubectl apply -f argocd/test/ -n argocd

# Verify application is created
kubectl get applications -n argocd
```

### 4. Monitor Sync Status

Check the ArgoCD UI to monitor sync progress, application health, and deployment status. The UI provides real-time visualization of the sync process and resource health.

## Managing Applications

### Synchronization

Use the ArgoCD UI to manually sync applications:

- Navigate to the application in the UI
- Click "SYNC" button
- Select sync options (prune, force, dry run, etc.)
- Confirm synchronization

Alternatively, use kubectl:

```bash
# Trigger sync by updating the Application resource
kubectl patch application microservices-demo-dev -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Rollback

Rollback via ArgoCD UI:

- Open the application
- Go to "History and Rollback" tab
- Select the desired revision
- Click "Rollback"

### Deletion

```bash
# Delete application (keeps resources in cluster)
kubectl delete -f argocd/dev/microservices-demo.yaml -n argocd

# To also delete cluster resources, first remove the finalizer or delete via UI with cascade option
```

## References

If you're new to ArgoCD, check out these official resources:

- **[ArgoCD Getting Started Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)** - Quick introduction and basic concepts
- **[Core Concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)** - Understanding Applications, Projects, and sync strategies
- **[ArgoCD User Guide](https://argo-cd.readthedocs.io/en/stable/user-guide/)** - Comprehensive guide for daily operations
- **[ArgoCD Architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/)** - How ArgoCD works under the hood
