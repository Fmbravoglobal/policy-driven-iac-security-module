terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

############################################
# 1) MAIN BUCKET
############################################
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

############################################
# 2) LOG BUCKET (same region)
############################################
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-logs"
}

resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

############################################
# 3) KMS ENCRYPTION (both buckets)
############################################
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    bucket_key_enabled = true
  }
}

############################################
# 4) VERSIONING (both buckets)
############################################
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# 5) LIFECYCLE (both buckets)
############################################
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "lifecycle-default"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expiration {
      days = 365
    }
  }

  depends_on = [aws_s3_bucket_versioning.log_bucket]
}

############################################
# 6) ACCESS LOGGING (main -> log bucket)
############################################
resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "s3-access-logs/${var.bucket_name}/"
}

############################################
# 7) EVENT NOTIFICATIONS (SNS topic)
############################################
resource "aws_sns_topic" "s3_events" {
  name              = "${var.bucket_name}-s3-events"
  kms_master_key_id = var.kms_key_arn
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    sid    = "AllowS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.s3_events.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_s3_bucket.this.arn,
        aws_s3_bucket.log_bucket.arn
      ]
    }
  }
}

resource "aws_sns_topic_policy" "s3_events" {
  arn    = aws_sns_topic.s3_events.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.s3_events]
}

resource "aws_s3_bucket_notification" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.s3_events]
}

}

############################################
# S3 CROSS REGION REPLICATION
############################################

resource "aws_s3_bucket_replication_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.replication.arn

  depends_on = [
    aws_s3_bucket_versioning.this,
    aws_s3_bucket_versioning.replica
  ]

  rule {
    id     = "replicate-main"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket = aws_s3_bucket.replica.arn

      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn
      }
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  role   = aws_iam_role.replication.arn

  depends_on = [
    aws_s3_bucket_versioning.log_bucket,
    aws_s3_bucket_versioning.log_replica
  ]

  rule {
    id     = "replicate-logs"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket = aws_s3_bucket.log_replica.arn

      encryption_configuration {
        replica_kms_key_id = var.replica_kms_key_arn
      }
    }
  }
}
