# CLOUDFRONT TO HOST FRONTEND
module "cloudfront" {
  source = "terraform-aws-modules/cloudfront/aws"

  comment             = "CloudFront for DevOps Challenge"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"

  default_root_object = "index.html"

  create_origin_access_identity = true
  origin_access_identities = {
    frontend_bucket = "OAI for ${local.tags.Product}"
  }

  origin = {
    frontend_bucket = {
      domain_name = module.frontend_bucket.s3_bucket_bucket_domain_name
      s3_origin_config = {
        origin_access_identity = "frontend_bucket"
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

  viewer_certificate = {
    cloudfront_default_certificate = true
  }

  tags = merge(
      { Resource = "cloudfront_distro" },
      local.tags
  )
}