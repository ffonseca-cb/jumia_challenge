# CONTAINER REPO
resource "aws_ecr_repository" "ecr" {
  name = replace(basename(local.tags.Service), "_", "-")
  force_delete = true

  encryption_configuration {
    encryption_type = "KMS"
    kms_key = aws_kms_key.eks.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}