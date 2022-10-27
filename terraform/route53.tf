# CHECKING THE ZONE THAT WAS CREATEAD WITH THE DOMAIN REGISTRAR
data "aws_route53_zone" "this" {
  name = local.domain
}

# ENTRIES TO VALIDADE CERTIFICATE
resource "aws_route53_record" "dns_zone" {
  for_each = {
    for dvo in aws_acm_certificate.cert_us.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.cert_us.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_zone : record.fqdn]
}

# APPLICATION URL
resource "aws_route53_record" "frontend_record" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domain
  type    = "A"

  alias {
    name                   = module.cloudfront.cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}