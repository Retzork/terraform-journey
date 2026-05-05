resource "kubernetes_horizontal_pod_autoscaler_v2" "azure_vote_front_hpa" {
  metadata {
    name      = "azure-vote-front-hpa"
    namespace = "default"
  }

  spec {
    max_replicas = 10
    min_replicas = 1

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "azure-vote-front"
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 50
        }
      }
    }
  }
}