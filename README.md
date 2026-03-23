# policy-driven-iac-security-module

[![Terraform Validate](https://github.com/Fmbravoglobal/policy-driven-iac-security-module/actions/workflows/security-pipeline.yml/badge.svg)](https://github.com/Fmbravoglobal/policy-driven-iac-security-module/actions/workflows/security-pipeline.yml)

## Overview

A reusable, production-grade **Terraform module** that enforces cloud security controls as code. The module provisions a fully hardened AWS S3 environment with encryption, access logging, versioning, lifecycle management, cross-region replication, and SNS event notifications — all enforced automatically with no manual configuration required.

Designed for teams that need consistent, auditable, and policy-compliant storage infrastructure across multiple environments.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Calling Terraform Root                 │
│                                                          │
│   module "secure_s3" {                                   │
│     source        = "./modules/secure-s3-bucket"         │
│     bucket_name   = "my-prod-bucket"                     │
│     kms_key_arn   = aws_kms_key.main.arn                 │
│   }                                                      │
└───────────────────────┬─────────────────────────────────┘
                        │ provisions
          ┌─────────────▼────────────────────────┐
          │         secure-s3-bucket module       │
          │                                       │
          │  ┌────────────┐    ┌───────────────┐  │
          │  │ Main Bucket│    │  Log Bucket   │  │
          │  │ KMS-AES256 │    │  KMS-AES256   │  │
          │  │ Versioning │───>│  Versioning   │  │
          │  │ Lifecycle  │    │  Lifecycle    │  │
          │  └─────┬──────┘    └───────────────┘  │
          │        │ events                        │
          │  ┌─────▼──────────────────────────┐   │
          │  │  SNS Topic (KMS encrypted)     │   │
          │  │  Object Created/Removed alerts │   │
          │  └────────────────────────────────┘   │
          │                                       │
          │  ┌────────────────────────────────┐   │
          │  │  Cross-Region Replica Bucket   │   │
          │  │  IAM Replication Role          │   │
          │  └────────────────────────────────┘   │
          └───────────────────────────────────────┘
```

---

## Security Controls Enforced

| Control | Implementation |
|---|---|
| Encryption at rest | AWS KMS (customer-managed key) |
| Public access blocked | All 4 public access block settings enabled |
| Access logging | All requests logged to dedicated log bucket |
| Versioning | Enabled on both main and log buckets |
| TLS-only access | Bucket policy denies all non-HTTPS requests |
| Lifecycle management | Incomplete multipart cleanup, noncurrent version expiry |
| Event notifications | SNS topic alerts on all object create/delete events |
| Cross-region replication | Encrypted replication for disaster recovery |

---

## Module Inputs

| Variable | Description | Required |
|---|---|---|
| `bucket_name` | Name of the primary S3 bucket | Yes |
| `kms_key_arn` | ARN of the KMS key for encryption | Yes |
| `replica_kms_key_arn` | KMS key ARN in the replica region | Yes |
| `aws_region` | AWS region for the primary bucket | No (default: us-east-1) |

## Module Outputs

| Output | Description |
|---|---|
| `bucket_arn` | ARN of the primary S3 bucket |
| `bucket_id` | ID/name of the primary S3 bucket |
| `log_bucket_id` | ID of the logging bucket |
| `sns_topic_arn` | ARN of the SNS event notification topic |

---

## Usage

```hcl
module "secure_s3" {
  source              = "./modules/secure-s3-bucket"
  bucket_name         = "my-application-data"
  kms_key_arn         = aws_kms_key.main.arn
  replica_kms_key_arn = aws_kms_key.replica.arn
}

output "bucket_arn" {
  value = module.secure_s3.bucket_arn
}
```

---

## Compliance Alignment

This module satisfies controls from:

- **NIST 800-53**: SC-28 (Protection of Information at Rest), AU-9 (Protection of Audit Information)
- **CIS AWS Benchmark**: 2.1.1 (S3 Block Public Access), 2.1.2 (S3 Versioning)
- **SOC 2 Type II**: Availability and Confidentiality criteria
- **PCI-DSS**: Requirement 3 (Protect Stored Cardholder Data), Requirement 10 (Logging)

---

## CI/CD Security Scanning

The GitHub Actions pipeline runs on every push and pull request:

- `terraform fmt` — formatting validation
- `terraform validate` — configuration syntax check
- **Checkov** — policy-as-code scanning (200+ AWS security rules)
- **KICS** — infrastructure misconfiguration detection
- **Regula** — OPA-based compliance checks

---

## Repository Structure

```
policy-driven-iac-security-module/
├── modules/
│   └── secure-s3-bucket/
│       ├── main.tf        # S3, KMS, SNS, IAM, replication resources
│       ├── variable.tf    # Input variable definitions
│       └── outputs.tf     # Output value definitions
└── .github/
    └── workflows/
        └── security-pipeline.yml
```

---

## Author

**Oluwafemi Alabi Okunlola** | Cloud Security Engineer
[oluwafemiokunlola308@gmail.com](mailto:oluwafemiokunlola308@gmail.com)
