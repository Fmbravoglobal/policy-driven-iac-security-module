variable "bucket_name" {
  description = "Name of the main S3 bucket"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 bucket encryption"
  type        = string
}
