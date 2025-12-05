# Container Image CI/CD GitHub Actions Workflows - User Guide

## 🚀 Features

### 1. Automatic Image Build & Security Scan (`ci.yaml`)

**Triggers**:

- On every Pull Request to the `main` branch

**What it does**:

- Discovers all microservices with a `Dockerfile` in `microservices-demo/src/`
- Builds Docker images for each service (without pushing)
- Scans images for vulnerabilities using Docker Scout and Trivy
- Uploads scan results to the GitHub Security tab (SARIF format)
- Ensures images are buildable and secure before merging

## ⚙️ Required GitHub Secrets

Add the following secrets in the repository settings:

```shell
DOCKERHUB_USERNAME      # Docker Hub username (for CI)
DOCKERHUB_PASSWORD      # Docker Hub password (for CI)
ECR_REGISTRY            # ECR registry URL (for CD)
AWS_ACCESS_KEY_ID       # AWS Access Key
AWS_SECRET_ACCESS_KEY   # AWS Secret Key  
AWS_REGION              # AWS region (for CD)
```

## 🔐 Permissions

- **CI:** Anyone can trigger by opening a PR to `main`
- **CD:** Only pushes to release tags will trigger image publishing

## 📂 Microservices Directory Structure

The workflows assume the following structure:

```shell
microservices-demo/
└── src/
    ├── service1/
    │   └── Dockerfile
    ├── service2/
    │   └── Dockerfile
    └── ...
```

## 🔄 Workflow

1. Open a PR to `main` branch
2. CI workflow builds and scans all service images, uploads results to Security tab
3. Merge PR and push a release tag (e.g., `v1.2.3`)
4. CD workflow builds and pushes all service images to ECR with version and `latest` tags

## 🚨 Troubleshooting

**Problem:** "No Dockerfiles found in microservices-demo/src"  
**Solution:** Ensure each microservice directory contains a valid `Dockerfile`

**Problem:** "Image scan results not visible in Security tab"  
**Solution:** Check SARIF upload steps and GitHub repository security settings

**Problem:** "ECR push fails"  
**Solution:** Verify AWS secrets and IAM role permissions

**Problem:** "Docker Hub login fails"  
**Solution:** Check `DOCKERHUB_USERNAME` and `DOCKERHUB_PASSWORD` secrets
