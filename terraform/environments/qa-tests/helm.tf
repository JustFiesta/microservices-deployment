# #
# # NGINX Ingress Controller
# #
# resource "kubernetes_namespace" "ingress_nginx" {
#   metadata {
#     name = "ingress-nginx"
#   }
# }

# resource "helm_release" "nginx_ingress" {
#   name       = "ingress-nginx"
#   namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
#   repository = "https://kubernetes.github.io/ingress-nginx"
#   chart      = "ingress-nginx"
#   version    = "4.10.0"

#   values = [yamlencode({
#     controller = {
#       replicaCount = 2

#       service = {
#         type = "LoadBalancer"
#         annotations = {
#           "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
#         }
#       }

#       ingressClassResource = {
#         default = true
#       }
#     }
#   })]
# }

# #
# # Metrics Server
# #
# resource "helm_release" "metrics_server" {
#   name       = "metrics-server"
#   namespace  = "kube-system"
#   repository = "https://kubernetes-sigs.github.io/metrics-server/"
#   chart      = "metrics-server"
#   version    = "3.12.1"

#   values = [yamlencode({
#     args = [
#       "--kubelet-insecure-tls",
#       "--kubelet-preferred-address-types=InternalIP"
#     ]
#   })]
# }

# #
# # Argo CD
# #
# resource "kubernetes_namespace" "argocd" {
#   metadata {
#     name = "argocd"
#   }
# }

# resource "helm_release" "argocd" {
#   name       = "argocd"
#   namespace  = kubernetes_namespace.argocd.metadata[0].name
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   version    = "7.7.12"

#   values = [yamlencode({
#     server = {
#       service = {
#         type = "LoadBalancer"
#         annotations = {
#           "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
#         }
#       }
#     }

#     configs = {
#       params = {
#         "server.insecure" = true
#       }
#     }
#   })]
# }

# #
# # Prometheus & Grafana
# #
# resource "kubernetes_namespace" "monitoring" {
#   metadata {
#     name = "monitoring"
#   }
# }

# resource "helm_release" "kube_prometheus_stack" {
#   name       = "kube-prometheus-stack"
#   namespace  = kubernetes_namespace.monitoring.metadata[0].name
#   repository = "https://prometheus-community.github.io/helm-charts"
#   chart      = "kube-prometheus-stack"
#   version    = "65.0.0"

#   values = [yamlencode({
#     prometheus = {
#       prometheusSpec = {
#         retention = "2h"
        
#         resources = {
#           requests = {
#             cpu    = "200m"
#             memory = "512Mi"
#           }
#           limits = {
#             cpu    = "500m"
#             memory = "1Gi"
#           }
#         }
#       }
#     }

#     grafana = {
#       adminPassword = "admin123"
      
#       service = {
#         type = "LoadBalancer"
#         annotations = {
#           "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
#         }
#       }

#       resources = {
#         requests = {
#           cpu    = "100m"
#           memory = "128Mi"
#         }
#         limits = {
#           cpu    = "200m"
#           memory = "256Mi"
#         }
#       }
#     }

#     alertmanager = {
#       enabled = false
#     }

#     prometheus-node-exporter = {
#       enabled = true
#     }

#     kube-state-metrics = {
#       enabled = true
#     }
#   })]

#   depends_on = [
#     kubernetes_namespace.monitoring,
#   ]
# }