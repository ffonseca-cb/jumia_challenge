# DEPLOYING BACKEND APPLICATION ON KUBERNETES
resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = "jumia-${replace(basename(local.tags.Product), "_", "-")}"
  }
}

resource "kubernetes_service_v1" "service" {
  metadata {
    name = "${replace(basename(local.tags.Service), "_", "-")}-service"
    namespace = "jumia-${replace(basename(local.tags.Product), "_", "-")}"
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = replace(basename(local.tags.Service), "_", "-")
    }
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    type = "NodePort"
  }

  depends_on = [
   kubernetes_namespace_v1.ns
  ]
}

resource "kubernetes_deployment_v1" "deployment" {
  metadata {
    name = "${replace(basename(local.tags.Service), "_", "-")}"
    namespace = "jumia-${replace(basename(local.tags.Product), "_", "-")}"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        "app.kubernetes.io/name" = replace(basename(local.tags.Service), "_", "-")
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = replace(basename(local.tags.Service), "_", "-")
        }
      }

      spec {
        container {
          image = "${aws_ecr_repository.ecr.repository_url}:latest"
          name  = replace(basename(local.tags.Service), "_", "-")

          port {
            container_port = 8080
          }
        }
      }
    }
  }

  depends_on = [
   kubernetes_namespace_v1.ns
  ]
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name = "${replace(basename(local.tags.Product), "_", "-")}-ingress"
    namespace = "jumia-${replace(basename(local.tags.Product), "_", "-")}"

    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/certificate-arn" = "${resource.aws_acm_certificate.cert_ie.arn}"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\": \"redirect\", \"RedirectConfig\": { \"Protocol\": \"HTTPS\", \"Port\": \"443\", \"StatusCode\": \"HTTP_301\"}}"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/v1/customers"
    }
  }

  spec {
    rule {
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "${replace(basename(local.tags.Service), "_", "-")}-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    ingress_class_name = "alb"
  }

  depends_on = [
   kubernetes_namespace_v1.ns
  ]
}