## S3 bucket and objects
## Staging for Windows/Linux bootstrap artifacts (scripts, Sysmon, Caldera config).
## Kept private: lab instances use an instance profile; operator access is limited to the detected ISP IPs.
resource "aws_s3_bucket" "staging" {
  bucket = "operator-staging-${local.rs}"

  tags = {
    Name        = "Operator Lab"
    Environment = "Dev"
  }
}

data "aws_caller_identity" "current" {}

locals {
  operator_principal_arn = can(regex(":assumed-role/", data.aws_caller_identity.current.arn)) ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${split("/", data.aws_caller_identity.current.arn)[1]}" : data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "staging" {
  name               = "operator-staging-${local.rs}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "staging_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.staging.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.staging.arn]
  }
}

resource "aws_iam_role_policy" "staging_read" {
  name   = "operator-staging-read"
  role   = aws_iam_role.staging.id
  policy = data.aws_iam_policy_document.staging_read.json
}

resource "aws_iam_instance_profile" "staging" {
  name = "operator-staging-${local.rs}"
  role = aws_iam_role.staging.name
}

data "aws_iam_policy_document" "staging" {
  statement {
    sid    = "AllowLabInstances"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.staging.arn]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.staging.arn,
      "${aws_s3_bucket.staging.arn}/*",
    ]
  }

  statement {
    sid    = "AllowOperatorIp"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.operator_principal_arn]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.staging.arn,
      "${aws_s3_bucket.staging.arn}/*",
    ]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      values   = concat([local.src_ip], local.src_ipv6)
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.operator.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.operator-rt.id]

  tags = {
    Name = "operator-s3"
  }
}

resource "aws_s3_bucket_policy" "staging" {
  bucket = aws_s3_bucket.staging.id
  policy = data.aws_iam_policy_document.staging.json
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_policy.staging]
}

resource "aws_s3_object" "template_objects" {
  count   = length(local.templatefiles)
  bucket  = aws_s3_bucket.staging.id
  key     = replace(basename(local.templatefiles[count.index].name), ".tpl", "")
  content = local.script_contents[count.index]
}

output "storage_bucket" {
  value = aws_s3_bucket.staging.id
}
