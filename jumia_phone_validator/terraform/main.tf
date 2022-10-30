terraform {
  backend "s3" {
    bucket          = "tfstate-jumia-phone-validator-prd"
    key             = "infra/terraform.tfstate"
    region          = "eu-west-1"
    dynamodb_table  = "tfstate-jumia-phone-validator-prd"
  }
}

locals {
  # Generic info
  name    = "jumia_challenge"
  region  = "eu-west-1"
  domain  = "jumia-devops-challenge.eu"
  dns_zone_id = "Z0524081XI5U8NS279SJ" # Created automatically with domain registrar

  bootstrap_bucket = "tfstate-jumia-phone-validator-prd"

  tags = {
    Owner       = "ffonseca"
    Service     = "jumia_phone_validator"
    Product     = "devops_challenge"
    Environment = "prd"
  }

  # K8s configs
  product_name = "${replace(basename(local.tags.Product), "_", "-")}"
  service_name = "${replace(basename(local.tags.Service), "_", "-")}"
}

variable "db_password" {} # Insert with ENV variable with pipeline

data "aws_caller_identity" "current" {}