variable "name" {
  description = "Name prefix for the image handler resources"
  type        = string
}

variable "environment_name" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "source_buckets" {
  description = "Comma-separated list of S3 buckets containing source images"
  type        = string
}

variable "cors_enabled" {
  description = "Enable CORS for the image handler API"
  type        = bool
  default     = false
}

variable "cors_origin" {
  description = "CORS origin value (e.g., * or specific domain)"
  type        = string
  default     = "*"
}

variable "deploy_demo_ui" {
  description = "Deploy demo UI for testing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 180
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid value."
  }
}

variable "auto_webp" {
  description = "Automatically convert to WebP when accept header includes image/webp"
  type        = bool
  default     = false
}

variable "enable_signature" {
  description = "Enable URL signature validation"
  type        = bool
  default     = false
}

variable "secrets_manager_secret" {
  description = "AWS Secrets Manager secret name for signature validation"
  type        = string
  default     = ""
}

variable "secrets_manager_key" {
  description = "AWS Secrets Manager secret key for signature validation"
  type        = string
  default     = ""
}

variable "enable_default_fallback_image" {
  description = "Enable default fallback image on errors"
  type        = bool
  default     = false
}

variable "fallback_image_s3_bucket" {
  description = "S3 bucket containing fallback image"
  type        = string
  default     = ""
}

variable "fallback_image_s3_key" {
  description = "S3 key for fallback image"
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_All"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "origin_shield_region" {
  description = "Enable Origin Shield in specified region (or 'Disabled')"
  type        = string
  default     = "Disabled"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 1024
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 29
}

variable "enable_s3_object_lambda" {
  description = "Enable S3 Object Lambda (for images > 6MB)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "solution_version" {
  description = "Solution version identifier"
  type        = string
  default     = "v1.0.0"
}

variable "solution_id" {
  description = "Solution ID for tracking"
  type        = string
  default     = "custom-image-handler"
}

variable "enable_solution_metrics" {
  description = "Enable anonymous usage metrics collection"
  type        = bool
  default     = false
}
