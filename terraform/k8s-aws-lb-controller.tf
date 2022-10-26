# AWS LOAD BALANCER CONTROLLER
resource "helm_release" "aws_lb_controller" {
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  description      = "AWS Load Balancer Controller"
  chart            = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"

  values = [
    <<-EOT
      clusterName: ${aws_eks_cluster.cluster.name}
      serviceAccount:
        create: false
        name: aws-load-balancer-controller
      vpcId: ${module.vpc.vpc_id}
      region: ${local.region}
      EOT
  ]

  depends_on = [
    null_resource.modify_kube_dns
  ]
}