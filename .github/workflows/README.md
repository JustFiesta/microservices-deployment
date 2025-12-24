# GitHub Actions CI/CD Workflows

Complete CI/CD automation for microservices deployment on AWS using GitHub Actions. This directory contains workflows for container builds, infrastructure deployment, image promotion, and security scanning.

## Architecture Overview

### Workflow Organization

```shell
.github/
├── actions/                                    # Composite actions (reusable steps)
│   └── terraform-init-validate-plan/           # TF init/validate/plan sequence
│       └── action.yaml
└── workflows/                                  # CI/CD pipelines
    ├── ci.yaml                                 # Container build & push
    ├── helm-ci.yaml                            # Helm chart validation
    ├── terraform-ci.yaml                       # Terraform PR validation
    ├── terraform-apply.yaml                    # Terraform auto-deploy
    ├── promote-image.yaml                      # Image promotion (manual)
    ├── security-scans.yaml                     # Weekly Trivy scans
    ├── reusable_discover-app-services-changes.yaml    # Detect changed services
    ├── reusable_discover-app-services-all.yaml        # Discover all services
    ├── reusable_discover-terraform-envs.yaml          # Discover TF environments
    └── reusable_detect-terraform-changes.yaml         # Detect TF changes
```

### Design Philosophy

**Modularity Through Composition**:

- **Main Workflows**: Orchestration and trigger logic (what to do, when)
- **Reusable Workflows**: Business logic for discovery and detection (how to find what changed)
- **Composite Actions**: Low-level implementation details (Terraform commands, setup steps)

**Benefits**:
- **DRY Principle**: Service/environment discovery logic defined once, used everywhere
- **Consistency**: Same detection algorithm across all workflows
- **Maintainability**: Update discovery logic in one place
- **Testability**: Each component can be tested independently

---

## Main Workflows

### Container Image CI (`ci.yaml`)

**Trigger**: PR to `main` with changes in `microservices-demo/src/**`

**Purpose**: Build and push Docker images with automatic semantic versioning.

**Key Architectural Decisions**:

1. **Per-Service Change Detection**: Only builds microservices that were modified
   - Uses `git diff` to detect changed directories in `src/**`
   - Avoids rebuilding all 12 services on every change
   - Saves build time and ECR storage costs

2. **Parallel Matrix Builds**: All changed services build simultaneously
   - GitHub Actions matrix strategy with `max-parallel` unlimited
   - Typical 12-service build completes in ~5-8 minutes (vs ~60 minutes sequential)

3. **Multi-Tag Strategy**: Each build creates 3 tags
   - **Immutable**: `1.2.6-abc1234` (version + git SHA)
   - **Environment-versioned**: `dev-1.2.6`
   - **Environment-latest**: `dev`
   - Why: Supports both pinned deployments and rolling updates

4. **Semantic Versioning Per Service**: Independent version increments
   - Frontend: `frontend-1.2.5` → `frontend-1.2.6`
   - CartService: `cartservice-3.1.2` (unchanged)
   - Each service maintains own version history in git tags

**Flow**:
```
PR Created → Detect Changed Services → Build Matrix → Push to ECR → Tag Git (on merge)
```

**Output**: Images in ECR ready for deployment via ArgoCD

---

### Helm Chart CI (`helm-ci.yaml`)

**Trigger**: PR to `main` with changes in `helm/**`

**Purpose**: Validate Helm charts before deployment.

**Validation Pipeline**:
1. **Helm Lint**: Chart structure validation
2. **Template Rendering**: Test with all environment values files
3. **Kubeconform**: Kubernetes schema validation (ensures manifests are valid K8s resources)

**Why Separate from Application CI**:
- Chart changes don't require image rebuilds
- Faster feedback loop for infrastructure-as-code changes
- Validates all environment variations (dev, qa, prod values)

---

### Terraform CI (`terraform-ci.yaml`)

**Trigger**: PR with changes in `terraform/environments/**` or `terraform/modules/**`

**Purpose**: Validate and plan infrastructure changes before merge.

**Key Features**:

1. **Auto-Format**: Runs `terraform fmt -recursive` and commits if changes needed
   - Enforces consistent code style
   - Reduces review friction (no manual formatting comments)

2. **Environment Auto-Discovery**: Detects which environments changed
   - Scans `terraform/environments/` directory
   - Only plans for changed environments (not all)

3. **Plan as PR Comment**: Posts Terraform plan directly in PR
   - Sticky comment (updates on new commits)
   - Includes resource counts (add/change/destroy)
   - Enables review of infrastructure changes without leaving GitHub UI

**Constraint: One Environment Per PR**:
- Technical: Plan file uses fixed name `tfplan` (collision with multiple envs)
- Process: Clearer review when scoped to single environment
- Solution: Separate PRs for each environment

---

### Terraform Apply (`terraform-apply.yaml`)

**Trigger**: Push to `main` with changes in `terraform/**`

**Purpose**: Automatically apply approved Terraform changes.

**Design Decision: Auto-Apply**:
- **Why**: Reduces manual toil, faster deployment
- **Safety**: PR review + plan preview ensures changes are vetted before merge
- **Audit**: Full logs in GitHub Actions, git history tracks all changes

**Flow**:
```
Merge to Main → Detect Changed Envs → Apply Changes → Update Infrastructure
```

**Important**: Uses same detection logic as terraform-ci (via reusable workflow)

---

### Image Promotion (`promote-image.yaml`)

**Trigger**: Manual (workflow_dispatch)

**Purpose**: Promote container images between environments without rebuilding.

**Key Architecture**:

1. **Metadata-Only Copy**: Uses `crane` tool (not Docker)
   - No image pull/push (copies manifest + layers pointers)
   - Instant promotion (~2 seconds vs ~2 minutes with Docker)
   - Saves bandwidth and time

2. **Dynamic Environments**: Supports arbitrary environment names
   - Not limited to dev/qa/prod
   - Enables hotfix environments (e.g., `hotfix-202412`)
   - Supports feature branches (e.g., `feature-new-ui`)

3. **Dual Tagging**: Creates both versioned and latest tags
   - `qa-1.2.6` (immutable, for rollback)
   - `qa` (rolling update tag)

**Use Case**:
```
Dev image tested → Promote to QA → Test in QA → Promote to Prod
```

**Why Manual**: Controlled promotion prevents untested images reaching production

---

### Security Scans (`security-scans.yaml`)

**Trigger**: Weekly (Monday 6AM UTC) + Manual

**Purpose**: Continuous vulnerability scanning of all deployed images.

**Coverage Strategy**:
- Discovers all services automatically
- Discovers all environments automatically
- Scans every combination (12 services × 3 environments = 36 scans)

**Integration**: SARIF upload to GitHub Security tab
- Centralizes vulnerability tracking
- Integrates with dependabot and code scanning
- Enables security policy enforcement

---

## Reusable Workflows

### Service Discovery Workflows

**`reusable_discover-app-services-changes.yaml`**:
- **Input**: Git diff between base and head
- **Output**: JSON array of changed services
- **Algorithm**: Scans `microservices-demo/src/*/Dockerfile` for changes
- **Used by**: `ci.yaml`

**`reusable_discover-app-services-all.yaml`**:
- **Input**: None
- **Output**: JSON array of all services
- **Algorithm**: `find microservices-demo/src -name Dockerfile`
- **Used by**: `security-scans.yaml`

### Terraform Discovery Workflows

**`reusable_discover-terraform-envs.yaml`**:
- **Input**: Optional exclude list
- **Output**: JSON array of environment names
- **Algorithm**: `find terraform/environments -maxdepth 1 -type d`
- **Used by**: `security-scans.yaml`

**`reusable_detect-terraform-changes.yaml`**:
- **Input**: Git diff
- **Output**: Boolean `has_changes` + array of changed environments
- **Algorithm**: Extracts environment name from changed file paths
- **Used by**: `terraform-ci.yaml`, `terraform-apply.yaml`

### Why Reusable Workflows?

**Problem Solved**: Discovery logic used in 5+ places
**Solution**: Single source of truth via reusable workflows
**Alternative Rejected**: Duplicate logic in each workflow (error-prone, hard to maintain)

---

## Composite Actions

### `terraform-init-validate-plan/`

**Purpose**: Standard Terraform workflow steps packaged as reusable action.

**Steps**:
1. `terraform init` (with backend config)
2. `terraform validate`
3. `terraform plan -out=tfplan`
4. Parse plan output to structured format

**Inputs**:
- `working-directory`: Path to Terraform environment

**Outputs**:
- `plan-summary`: Resource counts (e.g., "2 to add, 1 to change, 0 to destroy")
- `plan-content`: Full plan output for PR comment

**Why Composite Action (not reusable workflow)**:
- Runs as steps within job (shares job context)
- Lower overhead than separate workflow
- Used for low-level implementation, not orchestration

**Used by**: Both `terraform-ci.yaml` and `terraform-apply.yaml`

---

## Workflow Constraints & Limitations

### Terraform: One Environment Per PR

**Constraint**: Workflows fail if multiple environments changed in single PR.

**Technical Reason**:
- Plan file saved as artifact with fixed name `tfplan-${{ env_name }}`
- If `dev` and `qa` both change, plan files collide
- PR comment logic assumes single environment identifier

**Process Reason**:
- Clearer review when changes scoped to one environment
- Terraform apply failures easier to debug
- Git history more granular (easier rollback)

**Solution**:
```bash
# ✅ CORRECT: Separate PRs
# PR 1: terraform/environments/dev/eks.tf
# PR 2: terraform/environments/qa/vpc.tf

# ❌ WRONG: Multiple environments in one PR
# PR 1: terraform/environments/dev/eks.tf + terraform/environments/qa/vpc.tf
```

**Exception**: Changes to `terraform/modules/` (shared) are allowed with environment changes

### Image Promotion: Naming Validation

**Service Name Regex**: `[a-zA-Z0-9_]+`
- Valid: `frontend`, `cart_service`
- Invalid: `front-end`, `cart.service`

**Environment Name Regex**: `[a-zA-Z0-9_-]+`
- Valid: `qa`, `prod`, `hotfix-202412`
- Invalid: `qa/prod`, `test.env`

**Reason**: ECR tag naming rules + security (injection prevention)

---

## Required GitHub Configuration

### Secrets (Settings → Secrets and variables → Actions)

| Secret | Description | Usage |
|--------|-------------|-------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | ECR push/pull, Terraform apply |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | AWS authentication |

**Security Note**: Use dedicated IAM user with minimal permissions. Consider OIDC for keyless auth in production.

### Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_REGION` | AWS region for all resources | `eu-west-1` |
| `ECR_REGISTRY_URI` | ECR registry URL with project prefix | `123456789010.dkr.ecr.eu-west-1.amazonaws.com/test-microservices-demo` |
| `TERRAFORM_VERSION` | Terraform version for workflows | `1.9.0` |

**Important**: All environments share the same GitHub variables (no per-environment variables).

---

## Best Practices

### Commit Message Convention

Format: `<type>(<scope>): <subject>`

Examples:
```bash
feat(frontend): add shopping cart persistence
fix(cartservice): handle empty cart edge case
terraform(dev): upgrade EKS cluster to 1.35
ci: add Helm chart validation workflow
docs(readme): update deployment instructions
```

**Types**: `feat`, `fix`, `terraform`, `ci`, `docs`, `refactor`, `test`, `chore`

### Branch Naming Strategy

| Purpose | Format | Example |
|---------|--------|---------|
| Feature | `feature/<description>` | `feature/shopping-cart` |
| Bugfix | `fix/<description>` | `fix/cart-crash-on-empty` |
| Terraform | `terraform/<action>-<env>` | `terraform/upgrade-dev` |
| Hotfix | `hotfix/<description>` | `hotfix/critical-bug` |

### Pull Request Workflow

1. **Create branch** from `main`
2. **Make changes** to code/infrastructure
3. **Push and create PR**
4. **Review automated checks**:
   - Container builds (if services changed)
   - Terraform plan (if infra changed)
   - Helm validation (if chart changed)
5. **Address review comments**
6. **Merge to main**
7. **Automatic deployment**:
   - Terraform: Auto-apply changes
   - Images: Tagged in ECR, ArgoCD pulls based on Helm values

---

## Integration Points

### With Terraform

Workflows deploy infrastructure defined in `/terraform`:
- ECR repositories (global environment)
- EKS clusters (per environment)
- ArgoCD, NGINX, Prometheus (via Helm)

See [terraform/README.md](../terraform/README.md) for infrastructure details.

### With Helm

Helm chart CI validates manifests in `/helm`:
- Lints chart structure
- Renders templates with environment values
- Validates Kubernetes schemas

See [helm/README.md](../helm/README.md) for chart details.

### With ArgoCD

Image builds trigger ArgoCD deployments:
1. CI pushes image with `dev` tag to ECR
2. ArgoCD monitors Helm chart in git
3. Chart references `global.image.tag: "dev"`
4. ArgoCD detects new `dev` tag in ECR (via image updater or manual values update)
5. ArgoCD syncs new image to cluster

See [argocd/README.md](../argocd/README.md) for GitOps configuration.

---

## Troubleshooting

### Common Issues

**Image builds failing**:
- Check Dockerfile syntax in service directory
- Verify ECR repository exists (created by Terraform global environment)
- Check AWS credentials are valid

**Terraform plan not posting to PR**:
- Verify GitHub token has permissions to comment on PRs
- Check workflow logs for API errors
- Ensure PR is from same repository (not fork)

**Multiple environment error in Terraform workflow**:
- Only change one environment per PR
- Create separate PRs for dev, qa, prod changes
- Check git diff to see which environments modified

**Security scans failing**:
- Ensure images exist in ECR for all environments
- Check Trivy database can be downloaded (network issues)
- Verify SARIF upload permissions in repository settings

---

## Related Documentation

- [Main README](../../README.md) - Project overview and setup guide
- [Terraform README](../../terraform/README.md) - Infrastructure as Code details
- [Helm README](../../helm/README.md) - Kubernetes deployment charts
- [ArgoCD README](../../argocd/README.md) - GitOps configuration
- [GitHub Actions Docs](https://docs.github.com/en/actions) - Official documentation
