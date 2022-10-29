# BUCKET THAT WILL HOST FRONTEND
module "frontend_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${local.service_name}-frontend-${local.tags.Environment}"

  force_destroy = true

  tags = merge(
    { Resource = "s3_bucket" },
	  local.tags
  )

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  acl = "private"

  versioning = {
    status     = true
    mfa_delete = false
  }
}

data "aws_iam_policy_document" "s3_frontend_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.frontend_bucket.s3_bucket_arn}/*"]

    principals {
      type        = "AWS"
      identifiers = module.cloudfront.cloudfront_origin_access_identity_iam_arns
    }
  }

  # Wait for the OAI on CloudFront to be created
  depends_on = [
    module.cloudfront
  ]
}

resource "aws_s3_bucket_policy" "s3_frontend_policy" {
  bucket = module.frontend_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_frontend_policy.json
}