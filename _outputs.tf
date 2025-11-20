output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.image_handler.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.image_handler.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.image_handler.domain_name
}

output "api_endpoint" {
  description = "API endpoint URL for image requests"
  value       = "https://${aws_cloudfront_distribution.image_handler.domain_name}"
}

output "lambda_function_arn" {
  description = "ARN of the image handler Lambda function"
  value       = aws_lambda_function.image_handler.arn
}

output "lambda_function_name" {
  description = "Name of the image handler Lambda function"
  value       = aws_lambda_function.image_handler.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "cloudfront_logs_bucket" {
  description = "S3 bucket for CloudFront access logs"
  value       = aws_s3_bucket.cloudfront_logs.id
}

output "cloudfront_logs_bucket_arn" {
  description = "ARN of the S3 bucket for CloudFront access logs"
  value       = aws_s3_bucket.cloudfront_logs.arn
}

output "source_buckets" {
  description = "List of source S3 buckets configured"
  value       = var.source_buckets
}

# Demo UI Outputs
output "demo_ui_url" {
  description = "Demo UI URL for testing (only available when deploy_demo_ui is true)"
  value       = var.deploy_demo_ui ? "https://${aws_cloudfront_distribution.demo_ui[0].domain_name}/index.html" : null
}

output "demo_ui_distribution_id" {
  description = "CloudFront distribution ID for demo UI"
  value       = var.deploy_demo_ui ? aws_cloudfront_distribution.demo_ui[0].id : null
}

output "demo_ui_bucket" {
  description = "S3 bucket for demo UI"
  value       = var.deploy_demo_ui ? aws_s3_bucket.demo_ui[0].id : null
}
