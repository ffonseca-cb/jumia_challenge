terraform {
  backend "s3" {
    bucket          = "tfstate-jumia-phone-validator-dev"
    key             = "infra/terraform.tfstate"
    region          = "eu-west-1"
    dynamodb_table  = "tfstate-jumia-phone-validator"
  }
}

locals {
  name            = "jumia_challenge"
  service         = "jumia_phone_validator"
  region          = "eu-west-1"
  env             = "dev"

  tags = {
    Owner       = "ffonseca"
    Service     = "jumia_phone_validator"
    Product     = "devops_challenge"
    # Resource
    # Environment
  }
}

data "aws_caller_identity" "current" {}