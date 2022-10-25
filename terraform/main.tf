terraform {
  backend "s3" {
    bucket          = "tfstate-jumia-phone-validator-dev"
    key             = "infra/terraform.tfstate"
    region          = "us-east-1"
    dynamodb_table  = "tfstate-jumia-phone-validator-dev"
  }
}

locals {
  name            = "jumia_challenge"
  service         = "jumia_phone_validator"
  region          = "us-east-1"
  env             = "ffonseca"

  cluster_version = "1.22"

  tags = {
    Owner       = "ffonseca"
    Service     = "jumia_phone_validator"
    Product     = "devops_challenge"
    # Resource
    # Environment
  }
}

data "aws_caller_identity" "current" {}