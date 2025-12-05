locals {
  project_name = "mbocak-microservices-demo"
  tags = {
    env     = "dev"
    owner   = "mbocak"
    project = "k8s-microservices-demo"
  }

  vpc_name      = "${local.project_name}-vpc"
  cluster_name  = "${local.project_name}-cluster"
  cluster_role  = "${local.project_name}-cluster-role"
  node_role     = "${local.project_name}-node-role"
}
