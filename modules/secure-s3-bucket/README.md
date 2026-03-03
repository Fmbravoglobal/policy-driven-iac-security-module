This module provisions an S3 bucket with security-first defaults.

### Security Controls Implemented

- ✅ Server-side encryption (AES256)
- ✅ Public access blocking (ACL + Policy level)
- ✅ Versioning enabled
- ✅ Reusable modular Terraform design
- ✅ Policy-driven infrastructure enforcement

---

## Architecture Goals

This project demonstrates:

- Secure-by-default cloud provisioning
- Infrastructure-as-Code (IaC) security automation
- Zero Trust aligned storage configuration
- Modular Terraform engineering for enterprise reuse

---

## Example Usage

```hcl
module "secure_bucket" {
  source      = "./modules/secure-s3-bucket"
  bucket_name = "example-secure-bucket"
}
