# ============================================================
# TERRAFORM & PROVIDER CONFIGURATION
# ============================================================
# This block tells Terraform WHICH plugins (providers) it needs
# to talk to AWS, and pins their versions so a future update
# doesn't silently change behavior underneath you.
# Analogy: like pinning a specific SQL Server ODBC driver version
# in a connection string instead of "whatever's latest."
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# ============================================================
# PROVIDER: AWS
# ============================================================
# Tells Terraform which cloud account/region to operate in.
# Credentials are pulled automatically from ~/.aws/credentials
# (the profile you configured earlier via `aws configure`).
provider "aws" {
  region = "ap-south-1"   # Mumbai region — matches where your EC2 instance already lives
}



# ============================================================
# RESOURCE: random suffix generator
# ============================================================
# S3 bucket names must be GLOBALLY unique across ALL of AWS —
# not just your account, every account on Earth. This is different
# from EC2, where AWS auto-generates unique IDs for you.
# Analogy: like a fully-qualified domain name — nobody else can
# have "google.com," and nobody else can have your exact bucket name.
#
# This resource generates a random hex string (e.g. "a1b2c3d4") that
# we'll append to our bucket name to avoid colliding with someone
# else's bucket that happens to share the same base name.
resource "random_id" "suffix" {
  byte_length = 4   # 4 bytes = 8 hex characters of randomness
}

# ============================================================
# RESOURCE: S3 bucket
# ============================================================
# This creates the actual bucket. Note the name uses string
# interpolation (${...}) to combine our chosen prefix with the
# random suffix generated above.
resource "aws_s3_bucket" "lab_bucket" {
  bucket = "shahed-dbre-lab-${random_id.suffix.hex}"

  tags = {
    Name = "terraform-lab-bucket"
  }
}

# ============================================================
# NOTE ON WHAT'S DELIBERATELY MISSING (for now)
# ============================================================
# This bucket, as written, has:
#   - No explicit public-access blocking
#   - No encryption configuration
#   - No versioning
#
# For a throwaway personal lab bucket, that's acceptable.
# In any real (especially healthcare) environment, an S3 bucket
# with no public-access block is exactly the kind of misconfiguration
# behind most "data breach via open S3 bucket" headlines.
#
# We're building this bare-bones first so you understand the minimal
# working version — the next module will add:
#   aws_s3_bucket_public_access_block
#   aws_s3_bucket_server_side_encryption_configuration
#   aws_s3_bucket_versioning
# and explain exactly why each one matters.

# Output the bucket name so you can find it without checking the console.
output "s3_bucket_name" {
  value = aws_s3_bucket.lab_bucket.bucket
}
# ============================================================
# RESOURCE: S3 bucket versioning
# ============================================================
# Versioning keeps every past version of an object when it's
# overwritten or deleted, instead of losing the old copy forever.
# Analogy: like keeping point-in-time recovery for a database —
# without it, an accidental overwrite or delete is unrecoverable.
resource "aws_s3_bucket_versioning" "lab_bucket_versioning" {
  bucket = aws_s3_bucket.lab_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
# ============================================================
# RESOURCE: RDS SQL Server instance (free-tier lab)
# ============================================================
resource "aws_db_instance" "sql_lab" {
  identifier           = "dbre-lab-sqlserver"
  engine               = "sqlserver-ex"
  engine_version       = "15.00.4430.1.v1"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"

  license_model        = "license-included"
  multi_az             = false

  username             = "admin"
  password             = var.db_password

  publicly_accessible  = true
  skip_final_snapshot  = true

  tags = {
    Name = "dbre-lab-sqlserver"
  }
}

variable "db_password" {
  description = "Master password for the SQL Server RDS instance"
  type        = string
  sensitive   = true
}

output "rds_endpoint" {
  value = aws_db_instance.sql_lab.endpoint
}
