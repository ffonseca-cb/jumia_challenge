################################################################################
# EKS
################################################################################
resource "aws_eks_cluster" "cluster" {
  name     = "${replace(basename(local.name), "_", "-")}"
  role_arn = aws_iam_role.iam_cluster_role.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  encryption_config {
    resources = ["secrets"]
    
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  tags = merge(
		{ Resource = "eks_cluster" },
		local.tags
	)

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}

resource "aws_eks_addon" "vpc_cni_addon" {
  cluster_name  = aws_eks_cluster.cluster.name
  addon_name    = "vpc-cni"
}

resource "aws_eks_addon" "kube_proxy_addon" {
  cluster_name  = aws_eks_cluster.cluster.name
  addon_name    = "kube-proxy"
}

data "tls_certificate" "tls_cert" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.tls_cert.certificates.*.sha1_fingerprint
  url             = data.tls_certificate.tls_cert.url
}

# ROLE AND POLICIES FOR EKS CLUSTER
resource "aws_iam_role" "iam_cluster_role" {
  name = "${local.name}-EKSClusterRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "eks.amazonaws.com",
          "ecs.amazonaws.com"
        ]
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

resource "aws_iam_role_policy" "kms_eks_cluster_policy" {
  name = "${local.name}-eks-encryption"
  role = aws_iam_role.iam_cluster_role.id

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
  role       = aws_iam_role.iam_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.iam_cluster_role.name
}

# PROFILE FOR JUMIA-* NAMESPACES
resource "aws_eks_fargate_profile" "fargate_profile_service" {
  cluster_name           = aws_eks_cluster.cluster.name
  fargate_profile_name   = "${local.service_name}_profile"
  pod_execution_role_arn = aws_iam_role.iam_service_pods_role.arn
  subnet_ids             = module.vpc.private_subnets

  selector {
    namespace = "jumia-*"
  }

  tags = merge(
		{ Resource = "fargate_profile" },
		local.tags
	)
}

# ROLE FOR jumia-phone-validator
resource "aws_iam_role" "iam_service_pods_role" {
  name = "${local.tags.Service}-PodExecRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFargatePods",
      "Effect": "Allow",
      "Principal": {
        "Service": ["eks-fargate-pods.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "AllowIRSA",
      "Effect": "Allow",
      "Principal": {
          "Federated": "${resource.aws_iam_openid_connect_provider.oidc_provider.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
          "StringEquals": {
              "${replace(resource.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:aud": "sts.amazonaws.com",
              "${replace(resource.aws_iam_openid_connect_provider.oidc_provider.arn, "/^(.*provider/)/", "")}:sub": "system:serviceaccount:jumia-${local.product_name}:default"
          }
      }
    }
  ]
}
POLICY

  tags = merge(
		{ Resource = "iam_role" },
		local.tags
	)

  depends_on = [
    aws_iam_openid_connect_provider.oidc_provider
  ]
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy_service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = resource.aws_iam_role.iam_service_pods_role.name
}

# NODE GROUP USING EC2 LAUNCH TYPE TO SUPPORT K8S METRICS-SERVER
resource "aws_eks_node_group" "control_plane_node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "k8s_control_plane"
  node_role_arn   = aws_iam_role.iam_default_pods_role.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = ["t3a.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 20
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags =  merge(
		{ Resource = "eks_nodegroup" },
		local.tags
	)

  timeouts {
    create = "10m"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = aws_iam_role.iam_default_pods_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = aws_iam_role.iam_default_pods_role.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = aws_iam_role.iam_default_pods_role.name
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
        "Service": [
          "eks-fargate-pods.amazonaws.com",
          "eks.amazonaws.com",
          "ecs.amazonaws.com",
          "ec2.amazonaws.com"
        ]
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