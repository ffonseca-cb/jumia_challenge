# BASTION HOST
module "bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.tags.Product}_bastion_sg"
  description = "Bastion Security group"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
		{ Resource = "security_group" },
		local.tags
	)
}

resource "aws_security_group_rule" "bastion_sg_rule_allow_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["189.60.250.227/32"] # ffonseca IP
  security_group_id = module.bastion_sg.security_group_id
  description       = "Allow SSH - Ingress"
}

resource "aws_security_group_rule" "bastion_sg_rule_allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.bastion_sg.security_group_id
  description       = "Allow all - Egress"
}

resource "aws_key_pair" "bastion_kp" {
  # Keypair was previously created with ssh-keygen (if needed, ask Felipe Fonseca for private key)
  key_name   = "bastion_kp"
  public_key = file("resources/bastion_keypair.pub")
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }
}

locals {
  instance-userdata = <<EOF
#!/bin/bash

# updates and installing tools
sudo yum update -y
sudo amazon-linux-extras enable postgresql14
sudo yum install postgresql -y

# ENV variables - *** Switch in accordance with locals values on main.tf ***
export BOOTSTRAP_BUCKET="tfstate-jumia-phone-validator-prd"
export SQL_KEY_PATH="sql-load/sample.sql"

# Loading data on database
aws s3 cp s3://$BOOTSTRAP_BUCKET/$SQL_KEY_PATH .
EOF
}

resource "aws_instance" "bastion_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3a.micro"

  key_name                = aws_key_pair.bastion_kp.key_name
  vpc_security_group_ids  = [module.bastion_sg.security_group_id]
  subnet_id               = module.vpc.public_subnets[0]
  iam_instance_profile    = aws_iam_instance_profile.bastion_instance_profile.name

  user_data_base64 = base64encode(local.instance-userdata)

  tags = merge(
		{ Resource = "ec2_instance" },
    { Name = "${local.name}_bastion" },
		local.tags
  )
}

# ROLE FOR BASTION (EC2_INSTANCE)
resource "aws_iam_role" "bastion_role" {
  name = "${local.name}-EC2BastionRole"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "secrets_policy" {
  name = "${local.name}-secrets_policy"
  role = aws_iam_role.bastion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
        ]
        Effect   = "Allow"
        Resource = "${aws_secretsmanager_secret_version.secret_version.arn}"
      },
      {
        Action = [
          "secretsmanager:ListSecrets",
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${local.service_name}/*"]
      },
    ]
  })
}

resource "aws_iam_role_policy" "sql_load_policy" {
  name = "${local.name}-sql_load_policy"
  role = aws_iam_role.bastion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ListObjectsInBucket"
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${local.bootstrap_bucket}"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${local.bootstrap_bucket}/*"]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${local.name}-instance_profile"
  role = aws_iam_role.bastion_role.name
}