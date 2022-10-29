# K8S SERVICE ACCOUNT FOR AWS LB CONTROLLER
resource "kubernetes_service_account_v1" "aws_lb_controller_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKSLoadBalancerControllerRole-Jumia"
    }
  }

  depends_on = [
    aws_eks_cluster.cluster
  ]
}

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

  set {
    name = "region"
    value = local.region
  }

  set {
    name = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    kubernetes_service_account_v1.aws_lb_controller_sa,
    module.iam_load_balancer_controller_role

  ]
}