# Lambda Function for Image Processing
# Using the official AWS Solutions Lambda package
resource "aws_lambda_function" "image_handler" {
  function_name = "DynamicImageTransformatio-BackEndImageHandlerLambd-${var.environment_name}"
  description   = "Serverless Image Handler - Performs image edits and transformations"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  # Using the official AWS Solutions Lambda package from CloudFormation
  s3_bucket = "solutions-${data.aws_region.current.name}"
  s3_key    = "dynamic-image-transformation-for-amazon-cloudfront/v7.0.7/0168841080e38f8c6c1be6dd80844c95dc42fc23cbb7b366cb88aa7c3e49bf08.zip"

  environment {
    variables = {
      AUTO_WEBP                        = var.auto_webp ? "Yes" : "No"
      CORS_ENABLED                     = var.cors_enabled ? "Yes" : "No"
      CORS_ORIGIN                      = var.cors_origin
      SOURCE_BUCKETS                   = var.source_buckets
      ENABLE_SIGNATURE                 = var.enable_signature ? "Yes" : "No"
      SECRETS_MANAGER                  = var.secrets_manager_secret
      SECRET_KEY                       = var.secrets_manager_key
      ENABLE_DEFAULT_FALLBACK_IMAGE    = var.enable_default_fallback_image ? "Yes" : "No"
      DEFAULT_FALLBACK_IMAGE_BUCKET    = var.fallback_image_s3_bucket
      DEFAULT_FALLBACK_IMAGE_KEY       = var.fallback_image_s3_key
      ENABLE_S3_OBJECT_LAMBDA          = var.enable_s3_object_lambda ? "Yes" : "No"
      SOLUTION_VERSION                 = var.solution_version
      SOLUTION_ID                      = "custom-image-handler"
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-image-handler"
      Environment = var.environment_name
    }
  )
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.image_handler.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-lambda-logs"
      Environment = var.environment_name
    }
  )
}

# Lambda Permission for CloudFront
resource "aws_lambda_permission" "cloudfront_invoke" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_handler.function_name
  principal     = "cloudfront.amazonaws.com"
}
