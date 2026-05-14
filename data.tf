# 1. S3 Bucket for CodePipeline Artifacts (Stores the built code)
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "ev-fleet-pipeline-artifacts-kabi-yoobee0526" 
  force_destroy = true # To delete the project when completed.
}

# 2. S3 Bucket for Application Assets (Stores images, static files)
resource "aws_s3_bucket" "app_assets" {
  bucket        = "ev-fleet-app-assets-kabi-xyz987"
  force_destroy = true
}

# 3. DynamoDB Table (Stores the actual EV Telemetry data)
resource "aws_dynamodb_table" "ev_telemetry_table" {
  name           = "EV-Fleet-Telemetry-Data"
  billing_mode   = "PAY_PER_REQUEST" # Serverless billing: only pay for what you use
  hash_key       = "VehicleID"       # The primary search key
  range_key      = "Timestamp"       # Sorts the data by time

  attribute {
    name = "VehicleID"
    type = "S" # S = String (Text)
  }

  attribute {
    name = "Timestamp"
    type = "S"
  }
}

# 4. SNS TOPIC
resource "aws_sns_topic" "critical_alerts" {
  name = "ev-fleet-critical-alerts"
}

# Optional: Output the SNS Topic
output "sns_topic_arn" {
  value       = aws_sns_topic.critical_alerts.arn
  description = "The ARN of the SNS topic for alerts"
}
resource "aws_s3_bucket_versioning" "pipeline_versioning" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}