locals {
  project_name = "mbocak-microservices-qa-env"
  tags = {
    env     = "qa-tests"
    owner   = "mbocak"
    project = "k8s-microservices-qa-env"
  }

  vpc_name      = "${local.project_name}-vpc"
  cluster_name  = "${local.project_name}"
  cluster_role  = "${local.project_name}-cluster-role"
  node_role     = "${local.project_name}-node-role"
}
