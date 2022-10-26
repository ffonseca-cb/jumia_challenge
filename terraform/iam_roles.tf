# ROLE AND POLICIES FOR EKS CLUSTER
resource "aws_iam_role" "iam_eks_role" {
  name = "${local.name}-EKSClusterRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = merge(
		{ Resource = "iam_role" },
		local.tags
	)
}

resource "aws_iam_role_policy" "kms" {
  name = "${local.name}-eks-encryption"
  role = aws_iam_role.iam_eks_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ListGrants",
            "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.eks.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_eks_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.iam_eks_role.name
}

# ROLE AND POLICIES FOR DEFAULT/KUBE-SYSTEM PODS
resource "aws_iam_role" "iam_default_pods_role" {
  name = "${local.name}-PodExecDefaultRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = merge(
		{ Resource = "iam_role" },
		local.tags
	)
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.iam_default_pods_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.iam_default_pods_role.name
}

# ROLE FOR AWS LOAD BALANCER CONTROLLER
module "iam_load_balancer_controller_role" {
  depends_on = [
    aws_eks_cluster.cluster
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

# ROLE FOR jumia-phone-validator
module "iam_service_role" {
  depends_on = [
    aws_eks_cluster.cluster
  ]
  
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = local.tags.Service

  oidc_providers = {
    one = {
      provider_arn               = resource.aws_iam_openid_connect_provider.oidc_provider.arn
      namespace_service_accounts = ["jumia-phone-validator:sa-jumia-phone-validator"]
    }
  }

  tags = merge(
		{ Resource = "iam_role" },
		local.tags
	)
}