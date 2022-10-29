# # ROLE FOR AWS LOAD BALANCER CONTROLLER
module "iam_load_balancer_controller_role" {
  depends_on = [
    aws_eks_cluster.cluster,
    aws_iam_openid_connect_provider.oidc_provider
  ]

  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "AmazonEKSLoadBalancerControllerRole-Jumia"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    one = {
      provider_arn               = resource.aws_iam_openid_connect_provider.oidc_provider.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = merge(
		{ Resource = "iam_role" },
		local.tags
	)
}

# #ROLE FOR CLUSTER AUTOSCALING
# resource "aws_iam_role" "cluster_autoscaler_role" {
#   name = "${local.name}-ClusterAutoscalerRole"

#   assume_role_policy = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "AllowClusterAutoScaler",
#       "Effect": "Allow",
#       "Principal": {
#           "Federated": "${resource.aws_iam_openid_connect_provider.oidc_provider.arn}"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity",
#       "Condition": {
#           "StringEquals": {
#               "${replace(resource.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:aud": "sts.amazonaws.com",
#               "${replace(resource.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:sub": "system:serviceaccount:kube-system:cluster-autoscaler"
#           }
#       }
#     }
#   ]
# }
# POLICY

#   tags = merge(
# 		{ Resource = "iam_role" },
# 		local.tags
# 	)
# }

# data "aws_iam_policy_document" "cluster_autoscaler_policy_document" {
#   statement {
#     effect = "Allow"

#     actions = [
#       "autoscaling:SetDesiredCapacity",
#       "autoscaling:TerminateInstanceInAutoScalingGroup"
#     ]

#     resources = ["*"]

#     condition {
#       test     = "ForAnyValue:StringEquals"
#       variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${aws_eks_cluster.cluster.name}"
#       values   = ["owned"]
#     }
#   }
  
#   statement {
#     effect = "Allow"

#     actions = [
#       "autoscaling:DescribeAutoScalingInstances",
#       "autoscaling:DescribeAutoScalingGroups",
#       "ec2:DescribeLaunchTemplateVersions",
#       "autoscaling:DescribeTags",
#       "autoscaling:DescribeLaunchConfigurations"
#     ]

#     resources = ["*"]
#   }

#   depends_on = [
#     aws_eks_cluster.cluster
#   ]
# }

# resource "aws_iam_policy" "cluster_autoscaler_policy" {
#   name        = "AmazonEKSClusterAutoscalerPolicy_Jumia"
#   path        = "/"
#   description = "Cluster AutoScaler Policy"

#   policy = data.aws_iam_policy_document.cluster_autoscaler_policy_document.json
# }

# resource "aws_iam_role_policy_attachment" "cluster_autoscaler_role_attach" {
#   policy_arn = aws_iam_policy.cluster_autoscaler_policy.arn
#   role = aws_iam_role.cluster_autoscaler_role.name
# }