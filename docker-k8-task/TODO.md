# Task list

1. Create GitHub Actions pipeline to check container images and push them to repository
    * build container images with correct tags
        * find services for build [DONE]
        * move config to one place (envs) [DONE]
    * scan with sec tools (Trivy, Checkov, Docker Scout) [DONE]
    * outpu scans to Security tab on GitHub [DONE]
    * scan manifests with sec tools in pipeline [IN_FUTURE]
    * push images to repository [DONE]
    * !!! Run pipeliene only for changed services!
    * Correct the semver for different envs (push in CI as dev and then promote to others on approval)
2. Contenerise each app for minimal image [DONE]
3. Create GitHub Actions pipeline for infrastructure with GitOps approach
    * Create TF pipelines (plan/apply with command support) [DONE]
    * Give visability to apply with comment into PR somehow - maybe change to automatic apply if plan is good with comment on apply status and PR closing
    * Create pipeline for deploing K8 manifests/Kustomize/Helm files
4. Create infrastructure on Cloud:
    * TF S3 [DONE]
    * K8 cluster
    * IAM
5. Enable K8 cluster to pull images from repository
6. Install K8 addons: HPA controller, Metrics server
7. Create manifests for application with Kustomize
8. Build Helm charts based on manifests
9. Add Redis to infrastructure and application
