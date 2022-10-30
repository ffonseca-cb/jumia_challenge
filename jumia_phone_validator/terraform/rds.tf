# RDS POSTGRES DATABASE
module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.tags.Product}_rds_sg"
  description = "RDS Security group"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
		{ Resource = "security_group" },
		local.tags
	)
}

resource "aws_security_group_rule" "rds_sg_rule_ingress" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = module.vpc.private_subnets_cidr_blocks
  security_group_id = module.rds_sg.security_group_id
  description       = "Allow connections from application/private subnets"
}

resource "aws_security_group_rule" "bastion_sg_rule_ingress" {
  type                      = "ingress"
  from_port                 = 5432
  to_port                   = 5432
  protocol                  = "tcp"
  source_security_group_id  = module.bastion_sg.security_group_id
  security_group_id         = module.rds_sg.security_group_id
  description               = "Allow connections from bastion host"
}

resource "aws_security_group_rule" "rds_sg_rule_allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.rds_sg.security_group_id
  description       = "Allow all - Egress"
}

# RDS INSTANCE
resource "aws_db_instance" "postgres" {
  identifier            = "${local.service_name}"

  allocated_storage     = 20

  db_name               = local.tags.Service
  engine                = "postgres"
  engine_version        = "14.4"
  instance_class        = "db.t4g.small"
  username              = "${local.tags.Service}_dba"
  password              = var.db_password
  #password              = templatefile("../../rds_pass.txt", { "\n" = "" })
  port                  = 5432

  iam_database_authentication_enabled = true

  skip_final_snapshot   = true
  multi_az              = true
  db_subnet_group_name  = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "03:30-06:30"
  backup_retention_period = 30

  tags = merge(
		{ Resource = "rds_instance" },
		local.tags
	)
}