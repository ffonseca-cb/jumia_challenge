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
  public_key = file("bastion_keypair.pub")
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-ami-hvm-*-x86_64-gp2",
    ]
  }

  # filter {
  #   name = "owner-alias"

  #   values = [
  #     "amazon",
  #   ]
  # }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "${local.name}_bastion"

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3a.micro"
  key_name               = aws_key_pair.bastion_kp.key_name
  vpc_security_group_ids = [module.bastion_sg.security_group_id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = merge(
		{ Resource = "ec2_instance" },
		local.tags
	)
}