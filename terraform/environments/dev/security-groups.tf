data "aws_security_groups" "backend_sg" {
  filter {
    name   = "tag:service.eks.amazonaws.com/resource"
    values = ["ManagedBackendSecurityGroup"]
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  depends_on = [module.eks]
}

data "aws_security_groups" "argocd_lb_sg" {
  filter {
    name   = "tag:service.eks.amazonaws.com/stack"
    values = ["argocd/argocd-server"]
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  depends_on = [helm_release.argocd]
}

resource "aws_security_group_rule" "argocd_backend_from_lb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = tolist(data.aws_security_groups.argocd_lb_sg.ids)[0]
  security_group_id        = tolist(data.aws_security_groups.backend_sg.ids)[0]
  description              = "Allow ArgoCD LoadBalancer to reach ArgoCD server pods"
}

# Optional for tests: NGINX ingress controller
data "aws_security_groups" "nginx_lb_sg" {
  filter {
    name   = "tag:service.eks.amazonaws.com/stack"
    values = ["ingress-nginx/ingress-nginx-controller"]
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  depends_on = [helm_release.nginx_ingress]
}

resource "aws_security_group_rule" "nginx_backend_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = tolist(data.aws_security_groups.nginx_lb_sg.ids)[0]
  security_group_id        = tolist(data.aws_security_groups.backend_sg.ids)[0]
  description              = "Allow NGINX LoadBalancer to reach NGINX ingress pods (HTTP)"
}

resource "aws_security_group_rule" "nginx_backend_from_lb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = tolist(data.aws_security_groups.nginx_lb_sg.ids)[0]
  security_group_id        = tolist(data.aws_security_groups.backend_sg.ids)[0]
  description              = "Allow NGINX LoadBalancer to reach NGINX ingress pods (HTTPS)"
}