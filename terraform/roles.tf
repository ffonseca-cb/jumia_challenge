# Role to be used by AWS Load Balancer Controller
module "iam_load_balancer_controller_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "AmazonEKSLoadBalancerControllerRole"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

# Role to be used by Service Account running jumia-phone-validator
module "iam_eks_role" {
  depends_on = [
    module.eks
  ]
  
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = local.service

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["jumia-phone-validator:sa-jumia-phone-validator"]
    }
  }
}