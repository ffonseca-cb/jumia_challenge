# DEFAULT CERTIFICATE (EU-WEST-1)
resource "aws_acm_certificate" "cert_ie" {
  domain_name       = local.domain
  validation_method = "DNS"

  tags = merge(
		{ Resource = "acm_certificate" },
		local.tags
	)

  lifecycle {
    create_before_destroy = true
  }
}

# CERTIFICATE TO CLOUDFRONT (US-EAST-1 REQUIRED)
resource "aws_acm_certificate" "cert_us" {
  provider = aws.us-east-1

  domain_name       = local.domain
  validation_method = "DNS"

  tags = merge(
		{ Resource = "acm_certificate" },
		local.tags
	)

  lifecycle {
    create_before_destroy = true
  }
}