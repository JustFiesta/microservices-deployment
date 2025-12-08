# Microservices Deployment

This repository contains resources for successful deployment of [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) project.

It was made as a practical task to test my knowlage for containers creation/security and Kubernetes on Cloud. All complaining with DevOps principals.

The deployment is fully Automated with CI/CD for code and also for Terraform files.

## Statuses

[![Terraform Apply](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/terraform-apply.yaml) [![Build](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml/badge.svg)](https://github.com/JustFiesta/microservices-deployment/actions/workflows/ci.yaml)

## Technologies

* GitHub Actions
* Docker
* AWS
* Terraform
* Managed Kubernetes
* Helm

## Goals

1. Create infrastructure for AWS managed Kubernetes Cluster
2. Containerize the apps from [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo), with the smallest possible image without drawbacks
3. Scan containers with Trivy
4. Push to cloud managed repository
5. Create K8 manifests do deploy application
6. Scan manifests with Trivy
7. Create and deploy app into Helm Charts
8. Add Redis to application stack

## Replication

TODO

1. Create S3 on AWS
2. Add S3 name into provider
3. Set reqiured ENVs in repository secrets:

    * AWS_REGION
    * AWS_ACCESS_KEY_ID
    * AWS_SECRET_ACCESS_KEY
    * ECR_REGISTRY
    * TERRAFORM_VERSION

4. Create TF environment (eg. terraform/env/dev/main.tf)
5. Setup ArgoCD in Kubernetes Cluster
6. Reapply code - make some sample change in microserives-demo/src/
7. Reapply Kubernetes manifests - change their version to correct ones from ECR
