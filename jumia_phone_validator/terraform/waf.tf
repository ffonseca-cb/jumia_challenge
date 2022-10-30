# WAFs on CloudFront Distribution and ALB
module "waf_regional_acl" {
    source = "git@github.com:binbashar/terraform-aws-waf-owasp.git//modules/waf-regional?ref=v1.0.17"

    # Just a prefix to add some level of organization
    waf_prefix = "owasp10-regional"

    # List of IPs that are blacklisted
    blacklisted_ips = []

    # List of IPs that are allowed to access admin pages
    admin_remote_ipset = []

    # Pass the list of ALB ARNs that the WAF ACL will be connected to
    alb_arn = [
        data.aws_alb.alb.arn
    ]

    # By default seted to COUNT for testing in order to avoid service affection; when ready, set it to BLOCK
    rule_size_restriction_action_type   = "COUNT"
    rule_sqli_action                    = "COUNT"
    rule_xss_action                     = "COUNT"
    rule_lfi_rfi_action                 = "COUNT"
    rule_ssi_action_type                = "COUNT"
    rule_auth_tokens_action             = "COUNT"
    rule_admin_access_action_type       = "COUNT"
    rule_php_insecurities_action_type   = "COUNT"
    rule_csrf_action_type               = "COUNT"
    rule_blacklisted_ips_action_type    = "COUNT"

    depends_on = [
      data.aws_alb.alb
    ]
}

module "waf_global_cloudfront" {
    source = "git@github.com:binbashar/terraform-aws-waf-owasp.git//modules/waf-global?ref=v1.0.17"

    # Just a prefix to add some level of organization
    waf_prefix = "owasp10-global"

    # List of IPs that are blacklisted
    blacklisted_ips = []

    # List of IPs that are allowed to access admin pages
    admin_remote_ipset = []

    # By default seted to COUNT for testing in order to avoid service affection; when ready, set it to BLOCK
    rule_size_restriction_action_type   = "COUNT"
    rule_sqli_action                    = "COUNT"
    rule_xss_action                     = "COUNT"
    rule_lfi_rfi_action                 = "COUNT"
    rule_ssi_action_type                = "COUNT"
    rule_auth_tokens_action             = "COUNT"
    rule_admin_access_action_type       = "COUNT"
    rule_php_insecurities_action_type   = "COUNT"
    rule_csrf_action_type               = "COUNT"
    rule_blacklisted_ips_action_type    = "COUNT"
}