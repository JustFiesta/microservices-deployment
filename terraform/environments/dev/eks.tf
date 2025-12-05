module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  name               = local.cluster_name
  kubernetes_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  iam_role_arn                       = aws_iam_role.cluster.arn
  iam_role_permissions_boundary      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DefaultBoundaryPolicy"
  node_iam_role_permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DefaultBoundaryPolicy"

  enable_irsa = false

  compute_config = {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  addons = {
    vpc-cni = { most_recent = true }
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  tags = local.tags
}
