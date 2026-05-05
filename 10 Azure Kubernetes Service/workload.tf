# Redis Backend (Confirmed Working)
resource "kubernetes_deployment" "azure_vote_back" {
  metadata { name = "azure-vote-back" }
  spec {
    replicas = 1
    selector { match_labels = { app = "azure-vote-back" } }
    template {
      metadata { labels = { app = "azure-vote-back" } }
      spec {
        container {
          name  = "redis"
          image = "mcr.microsoft.com/oss/bitnami/redis:6.0.8"
          port { container_port = 6379 }
          env {
            name  = "ALLOW_EMPTY_PASSWORD"
            value = "yes"
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "azure_vote_back" {
  metadata { name = "azure-vote-back" }
  spec {
    selector = { app = "azure-vote-back" }
    port { port = 6379 }
    type = "ClusterIP"
  }
}

# Frontend: Transition to stable Nginx Alpine
resource "kubernetes_deployment" "azure_vote_front" {
  metadata { name = "azure-vote-front" }
  spec {
    replicas = 1
    selector { match_labels = { app = "azure-vote-front" } }
    template {
      metadata { labels = { app = "azure-vote-front" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"
          port { container_port = 80 }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "azure_vote_front" {
  metadata { name = "azure-vote-front" }
  spec {
    selector = { app = "azure-vote-front" }
    port { port = 80 }
    type = "LoadBalancer"
  }
}