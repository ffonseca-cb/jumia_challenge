# METRICS SERVER CONFIG
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.cluster.id
}

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = aws_eks_cluster.cluster.id
      cluster = {
        certificate-authority-data = aws_eks_cluster.cluster.certificate_authority[0].data
        server                     = aws_eks_cluster.cluster.endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = aws_eks_cluster.cluster.id
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
  })
}

resource "null_resource" "metrics_server" {
  triggers = {}

  provisioner "local-exec" {
    when = create
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    command = <<-EOT
      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    # environment = {
    #   KUBECONFIG = base64encode(local.kubeconfig)
    # }

    command = <<-EOT
      kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    EOT
  }

  # Waiting for the default fargate profile to be created
  depends_on = [
    aws_eks_node_group.control_plane_node_group
  ]
}

data "aws_iam_policy_document" "cluster_autoscaler_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]

    resources = ["*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${aws_eks_cluster.cluster.name}"
      values   = ["owned"]
    }
  }
  
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeLaunchTemplateVersions",
      "autoscaling:DescribeTags",
      "autoscaling:DescribeLaunchConfigurations"
    ]

    resources = ["*"]
  }

  # Wait for the OAI on CloudFront to be created
  depends_on = [
    aws_eks_cluster.cluster
  ]
}

resource "aws_iam_policy" "cluster_autoscaler_policy" {
  name        = "AmazonEKSClusterAutoscalerPolicy_Jumia"
  path        = "/"
  description = "Cluster AutoScaler Policy"

  policy = data.aws_iam_policy_document.cluster_autoscaler_policy_document.json
}