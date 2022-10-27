terraform {
  backend "s3" {
    bucket          = "tfstate-jumia-phone-validator-dev"
    key             = "infra/terraform.tfstate"
    region          = "eu-west-1"
    dynamodb_table  = "tfstate-jumia-phone-validator"
  }
}

locals {
  name    = "jumia_challenge"
  region  = "eu-west-1"
  domain  = "jumia-devops-challenge.eu"

  tags = {
    Owner       = "ffonseca"
    Service     = "jumia_phone_validator"
    Product     = "devops_challenge"
    Environment = "dev"
  }
}

data "aws_caller_identity" "current" {}