# QUERY ON LOAD BALANCERS TO FIND API ORIGIN
data "aws_alb" "alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = "${replace(basename(local.name), "_", "-")}"
  }

  depends_on = [
    resource.time_sleep.wait_90_seconds
  ]
}

# WAITING THE ALB CREATION
resource "time_sleep" "wait_90_seconds" {
  depends_on = [kubernetes_ingress_v1.ingress]

  create_duration = "90s"
}

# CLOUDFRONT TO HOST FRONTEND
module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  comment             = "CloudFront for DevOps Challenge"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"

  aliases = [
    local.domain
  ]

  default_root_object = "index.html"

  create_origin_access_identity = true
  origin_access_identities = {
    frontend_bucket = "OAI for ${local.tags.Product}"
  }

  origin = {
    frontend_bucket = {
      domain_name = module.frontend_bucket.s3_bucket_bucket_regional_domain_name
      s3_origin_config = {
        origin_access_identity = "frontend_bucket"
      }
    }

    api_alb = {
      domain_name = data.aws_alb.alb.dns_name
      
      custom_origin_config = {
        http_port = "80"
        https_port = "443"

        origin_ssl_protocols = [
          "TLSv1.2"
        ]

        origin_protocol_policy = "http-only"
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = "frontend_bucket"
    viewer_protocol_policy     = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/api/v1/customers"
      target_origin_id       = "api_alb"
      viewer_protocol_policy = "allow-all"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true
    }
  ]

  viewer_certificate = {
    acm_certificate_arn = aws_acm_certificate.cert_us.arn
    ssl_support_method  = "sni-only"
  }

  tags = merge(
      { Resource = "cloudfront_distribution" },
      local.tags
  )

  depends_on = [
    data.aws_alb.alb
  ]
}