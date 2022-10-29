# METRICS-SERVER
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  description      = "Metrics Server - Helm Chart"
  chart            = "metrics-server"
  version          = "3.8.2"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"

  values = [
    <<-EOT
      replicas: 2
      
    EOT
  ]
  
  depends_on = [
    aws_eks_node_group.control_plane_node_group
  ]
}