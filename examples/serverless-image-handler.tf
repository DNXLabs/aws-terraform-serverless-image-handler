# Serverless Image Handler Module
# This creates a CloudFront distribution with Lambda for dynamic image transformation

module "serverless_image_handler" {
  for_each = {
    for handler in try(local.workspace.serverless_image_handler.handlers, []) : handler.name => handler
  }

  source = "./modules/aws-serverless-image-handler-1.0.0"

  name             = "${local.workspace.environment_name}-${each.value.name}"
  environment_name = local.workspace.environment_name

  # Source bucket configuration
  source_buckets = each.value.source_buckets

  # CORS configuration
  cors_enabled = try(each.value.cors_enabled, false)
  cors_origin  = try(each.value.cors_origin, "*")

  # Demo UI
  deploy_demo_ui = try(each.value.deploy_demo_ui, false)

  # Logging
  log_retention_days = try(each.value.log_retention_days, 180)

  # Image processing options
  auto_webp = try(each.value.auto_webp, false)

  # Signature validation
  enable_signature       = try(each.value.enable_signature, false)
  secrets_manager_secret = try(each.value.secrets_manager_secret, "")
  secrets_manager_key    = try(each.value.secrets_manager_key, "")

  # Fallback image
  enable_default_fallback_image = try(each.value.enable_default_fallback_image, false)
  fallback_image_s3_bucket      = try(each.value.fallback_image_s3_bucket, "")
  fallback_image_s3_key         = try(each.value.fallback_image_s3_key, "")

  # CloudFront configuration
  cloudfront_price_class = try(each.value.cloudfront_price_class, "PriceClass_All")
  origin_shield_region   = try(each.value.origin_shield_region, "Disabled")

  # Lambda configuration
  lambda_memory_size = try(each.value.lambda_memory_size, 1024)
  lambda_timeout     = try(each.value.lambda_timeout, 29)

  # S3 Object Lambda (for large images)
  enable_s3_object_lambda = try(each.value.enable_s3_object_lambda, false)

  # Solution Metrics (optional anonymous usage tracking)
  enable_solution_metrics = try(each.value.enable_solution_metrics, false)

  # Tags
  tags = merge(
    try(each.value.tags, {}),
    {
      Environment = local.workspace.environment_name
      ManagedBy   = "Terraform"
      Module      = "serverless-image-handler"
    }
  )
}
