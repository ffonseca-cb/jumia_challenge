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

resource "aws_security_group_rule" "rds_sg_ingress" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = module.vpc.private_subnets_cidr_blocks
  security_group_id = module.rds_sg.security_group_id
}

################################################################################
# RDS Module
################################################################################
module "rds_postgres" {
  source  = "terraform-aws-modules/rds/aws"

  identifier = "${replace(basename(local.tags.Service), "_", "-")}-db-${local.tags.Environment}"

  engine               = "postgres"
  engine_version       = "14.1"
  family               = "postgres14" # DB parameter group
  major_engine_version = "14"         # DB option group
  instance_class       = "db.t4g.small"

  allocated_storage     = 20

  db_name  = "postgres"
  username = "postgres"
  port     = 5432

  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:30-06:30"

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(
		{ Resource = "rds_instance" },
		local.tags
	)
}