# DEPLOYING BACKEND APPLICATION ON KUBERNETES
locals {
  ns = "jumia-${local.product_name}"
  deployment = "${local.service_name}-deployment"
  service = "${local.service_name}-service"
  ingress = "${local.product_name}-ingress"
}

resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = local.ns
  }
}

resource "kubernetes_service_v1" "service" {
  metadata {
    name = local.service
    namespace = local.ns
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = local.service_name
    }
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    type = "NodePort"
  }

  depends_on = [
   kubernetes_namespace_v1.ns,
   helm_release.aws_lb_controller
  ]
}

resource "kubernetes_deployment_v1" "deployment" {
  metadata {
    name = local.deployment
    namespace = local.ns
  }

  spec {
    replicas = 4

    selector {
      match_labels = {
        "app.kubernetes.io/name" = local.service_name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = local.service_name
        }
      }

      spec {
        container {
          image = "${aws_ecr_repository.ecr.repository_url}:latest"
          name  = local.service_name

          port {
            container_port = 8080
          }

          env {
            name = "PGPASS"
            value = var.db_password
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
   kubernetes_namespace_v1.ns,
   helm_release.aws_lb_controller,
   aws_eks_node_group.control_plane_node_group
  ]
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name = local.ingress
    namespace = local.ns

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
              name = local.service
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
   kubernetes_namespace_v1.ns,
   helm_release.aws_lb_controller,
   kubernetes_service_account_v1.aws_lb_controller_sa,
   aws_eks_node_group.control_plane_node_group,
   module.iam_load_balancer_controller_role,
   module.vpc,
   aws_eks_addon.kube_proxy_addon,
   aws_eks_addon.vpc_cni_addon
  ]
}

resource "kubernetes_horizontal_pod_autoscaler_v1" "hpa" {
  metadata {
    name = "${local.service_name}-hpa"
  }

  spec {
    max_replicas = 20
    min_replicas = 4

    scale_target_ref {
      kind = "Deployment"
      name = local.deployment
    }
  }
}

# WAITING THE ALB CREATION
resource "time_sleep" "wait_90_seconds" {
  depends_on = [kubernetes_ingress_v1.ingress]

  create_duration = "90s"
}

# QUERY ON LOAD BALANCERS TO FIND API ORIGIN
data "aws_alb" "alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = "${replace(basename(local.name), "_", "-")}"
  }

  depends_on = [
    resource.time_sleep.wait_90_seconds
  ]
}