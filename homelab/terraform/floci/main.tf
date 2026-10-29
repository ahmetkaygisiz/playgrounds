# Floci (yerel AWS emülatörü) üzerinde ücretsiz AWS IaC pratiği.
#   terraform init && terraform apply
# Gerçek AWS'e geçmek için provider bloğundaki endpoint/skip ayarlarını kaldırmanız yeterli.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "floci_endpoint" {
  description = "Floci adresi (Ansible'da floci grubundaki Pi)"
  type        = string
  default     = "http://192.168.50.252:4566"
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "homelab"
}

provider "aws" {
  region     = var.region
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3       = var.floci_endpoint
    sqs      = var.floci_endpoint
    sns      = var.floci_endpoint
    dynamodb = var.floci_endpoint
    iam      = var.floci_endpoint
    sts      = var.floci_endpoint
  }

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}

# ---------- S3: örn. n8n yedekleri / artefaktlar ----------
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project}-artifacts"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------- SNS -> SQS (DLQ ile) : olay tabanlı mimari örneği ----------
resource "aws_sqs_queue" "events_dlq" {
  name = "${var.project}-events-dlq"
}

resource "aws_sqs_queue" "events" {
  name                       = "${var.project}-events"
  visibility_timeout_seconds = 60
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.events_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sns_topic" "events" {
  name = "${var.project}-events"
}

resource "aws_sns_topic_subscription" "events_to_sqs" {
  topic_arn = aws_sns_topic.events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.events.arn
}

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.events.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.events.arn } }
    }]
  })
}

# ---------- DynamoDB ----------
resource "aws_dynamodb_table" "items" {
  name         = "${var.project}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
}

output "resources" {
  value = {
    s3_bucket  = aws_s3_bucket.artifacts.bucket
    sqs_queue  = aws_sqs_queue.events.id
    sns_topic  = aws_sns_topic.events.arn
    dynamodb   = aws_dynamodb_table.items.name
    aws_cli_ex = "aws --endpoint-url ${var.floci_endpoint} s3 ls"
  }
}
