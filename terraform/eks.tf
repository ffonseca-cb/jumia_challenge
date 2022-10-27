################################################################################
# EKS
################################################################################
resource "aws_eks_cluster" "cluster" {
  name     = local.name
  role_arn = aws_iam_role.iam_eks_role.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
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

# PROFILE FOR KUBE-SYSTEM AND DEFAULT NAMESPACES
resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.cluster.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = aws_iam_role.iam_default_pods_role.arn
  subnet_ids             = module.vpc.private_subnets

  selector {
    namespace = "kube-system"
  }

  selector {
    namespace = "default"
  }

  tags = merge(
		{ Resource = "fargate_profile" },
		local.tags
	)
}

# PROFILE FOR JUMIA-* NAMESPACES
resource "aws_eks_fargate_profile" "fargate_profile_service" {
  cluster_name           = aws_eks_cluster.cluster.name
  fargate_profile_name   = local.tags.Service
  pod_execution_role_arn = aws_iam_role.iam_default_pods_role.arn # ALTERAR PARA A ROLE CORRETA
  subnet_ids             = module.vpc.private_subnets

  selector {
    namespace = "jumia-*"
  }
}


################################################################################
# Modify EKS CoreDNS Deployment
################################################################################

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

# Separate resource so that this is only ever executed once
resource "null_resource" "remove_default_coredns_deployment" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are removing the deployment provided by the EKS service and replacing it through the self-managed CoreDNS Helm addon
    # However, we are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      kubectl --namespace kube-system delete deployment coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }

  # Waiting for the default fargate profile to be created
  depends_on = [
    resource.aws_eks_fargate_profile.fargate_profile
  ]
}

resource "null_resource" "modify_kube_dns" {
  triggers = {}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    # We are maintaing the existing kube-dns service and annotating it for Helm to assume control
    command = <<-EOT
      echo "Setting implicit dependency on ${aws_iam_role.iam_default_pods_role.arn}"
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-name=coredns --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system annotate --overwrite service kube-dns meta.helm.sh/release-namespace=kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      kubectl --namespace kube-system label --overwrite service kube-dns app.kubernetes.io/managed-by=Helm --kubeconfig <(echo $KUBECONFIG | base64 --decode)
    EOT
  }

  depends_on = [
    null_resource.remove_default_coredns_deployment
  ]
}

################################################################################
# CoreDNS Helm Chart (self-managed)
################################################################################

data "aws_eks_addon_version" "this" {
  for_each = toset(["coredns"])

  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.cluster.version
  most_recent        = true
}

resource "helm_release" "coredns" {
  name             = "coredns"
  namespace        = "kube-system"
  create_namespace = false
  description      = "CoreDNS is a DNS server that chains plugins and provides Kubernetes DNS Services"
  chart            = "coredns"
  version          = "1.19.4"
  repository       = "https://coredns.github.io/helm"

  # For EKS image repositories https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  values = [
    <<-EOT
      image:
        repository: 602401143452.dkr.ecr.eu-west-1.amazonaws.com/eks/coredns
        tag: ${data.aws_eks_addon_version.this["coredns"].version}
      deployment:
        name: coredns
        annotations:
          eks.amazonaws.com/compute-type: fargate
      service:
        name: kube-dns
        annotations:
          eks.amazonaws.com/compute-type: fargate
      podAnnotations:
        eks.amazonaws.com/compute-type: fargate
      EOT
  ]

  depends_on = [
    # Need to ensure the CoreDNS updates are peformed before provisioning
    null_resource.modify_kube_dns
  ]
}


###########
# OUTPUTS #
###########
output "endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.cluster.certificate_authority[0].data
}

output "oidc_provider" {
  value = resource.aws_iam_openid_connect_provider.oidc_provider.arn
}