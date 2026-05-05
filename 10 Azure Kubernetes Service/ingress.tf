resource "kubernetes_namespace" "ingress_ns" {
  metadata {
    name = "ingress-basic"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_ns.metadata[0].name
  version    = "4.9.0"

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.nodeSelector.kubernetes\\.io/os"
    value = "linux"
  }
}