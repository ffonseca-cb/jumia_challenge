# ENTRIES TO VALIDADE CERTIFICATE
resource "aws_route53_record" "certificate_record" {
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
  zone_id         = local.dns_zone_id
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.cert_us.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_record : record.fqdn]
}

# APPLICATION URL
resource "aws_route53_record" "frontend_record" {
  zone_id = local.dns_zone_id
  name    = local.domain
  type    = "A"

  alias {
    name                   = module.cloudfront.cloudfront_distribution_domain_name
    zone_id                = module.cloudfront.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = true
  }
}

# DATABASE FRIENDLY URL
resource "aws_route53_record" "db_record" {
  zone_id = local.dns_zone_id
  name    = "rds.${local.domain}"
  type    = "A"

  alias {
    name                   = aws_db_instance.postgres.address
    zone_id                = aws_db_instance.postgres.hosted_zone_id
    evaluate_target_health = true
  }

  depends_on = [
    aws_db_instance.postgres
  ]
}

#BASTION FRIENDLY URL
resource "aws_eip" "lb" {
  instance = aws_instance.bastion_instance.id
  vpc      = true

  depends_on = [
    module.vpc
  ]
}

resource "aws_route53_record" "bastion_record" {
  zone_id = local.dns_zone_id
  name    = "bastion.${local.domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.lb.public_ip]
}