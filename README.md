# AWS Serverless Image Handler Terraform Module

This Terraform module deploys a serverless image transformation solution using AWS Lambda and CloudFront, converted from the AWS CloudFormation template for Dynamic Image Transformation.

## Features

- **Dynamic Image Transformation**: Resize, crop, rotate, and apply filters to images on-the-fly
- **CloudFront CDN**: Global content delivery with edge caching
- **Auto WebP**: Automatically convert images to WebP format when supported by client
- **CORS Support**: Configurable cross-origin resource sharing
- **Signature Validation**: Optional URL signature validation for secure image requests
- **Fallback Images**: Display default images on errors instead of JSON responses
- **S3 Object Lambda**: Support for processing images larger than 6MB
- **CloudWatch Logging**: Configurable log retention and monitoring

## Architecture

The module creates:
- AWS Lambda function for image processing
- CloudFront distribution for content delivery
- CloudFront cache and origin request policies
- CloudFront function for request modification
- IAM roles and policies for Lambda execution
- S3 bucket for CloudFront access logs
- CloudWatch log groups with configurable retention

## Usage

### Basic Example

```hcl
module "image_handler" {
  source = "./modules/aws-serverless-image-handler-1.0.0"

  name             = "staging-image-processor"
  environment_name = "staging"
  source_buckets   = "my-images-bucket,my-other-images-bucket"
  
  cors_enabled = true
  cors_origin  = "*"
  auto_webp    = true
  
  tags = {
    Environment = "staging"
    Project     = "MyProject"
  }
}
```

### Complete Example with All Options

```hcl
module "image_handler" {
  source = "./modules/aws-serverless-image-handler-1.0.0"

  name             = "prod-image-processor"
  environment_name = "production"
  source_buckets   = "prod-images-bucket"
  
  # CORS
  cors_enabled = true
  cors_origin  = "https://example.com"
  
  # Demo UI
  deploy_demo_ui = false
  
  # Logging
  log_retention_days = 180
  
  # Image Processing
  auto_webp = true
  
  # Security
  enable_signature       = true
  secrets_manager_secret = "image-handler-secret"
  secrets_manager_key    = "signature-key"
  
  # Fallback
  enable_default_fallback_image = true
  fallback_image_s3_bucket      = "fallback-images-bucket"
  fallback_image_s3_key         = "default-fallback.jpg"
  
  # CloudFront
  cloudfront_price_class = "PriceClass_100"  # US, Europe, Israel
  origin_shield_region   = "ap-southeast-2"
  
  # Lambda
  lambda_memory_size = 1536
  lambda_timeout     = 29
  
  # Large Images
  enable_s3_object_lambda = true
  
  tags = {
    Environment = "production"
    Project     = "MyProject"
    ManagedBy   = "Terraform"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for resources | `string` | n/a | yes |
| environment_name | Environment name | `string` | n/a | yes |
| source_buckets | Comma-separated list of S3 buckets with source images | `string` | n/a | yes |
| cors_enabled | Enable CORS | `bool` | `false` | no |
| cors_origin | CORS origin value | `string` | `"*"` | no |
| deploy_demo_ui | Deploy demo UI | `bool` | `false` | no |
| log_retention_days | CloudWatch log retention in days | `number` | `180` | no |
| auto_webp | Auto-convert to WebP | `bool` | `false` | no |
| enable_signature | Enable URL signature validation | `bool` | `false` | no |
| secrets_manager_secret | Secrets Manager secret name | `string` | `""` | no |
| secrets_manager_key | Secrets Manager secret key | `string` | `""` | no |
| enable_default_fallback_image | Enable fallback image | `bool` | `false` | no |
| fallback_image_s3_bucket | Fallback image S3 bucket | `string` | `""` | no |
| fallback_image_s3_key | Fallback image S3 key | `string` | `""` | no |
| cloudfront_price_class | CloudFront price class | `string` | `"PriceClass_All"` | no |
| origin_shield_region | Origin Shield region or 'Disabled' | `string` | `"Disabled"` | no |
| lambda_memory_size | Lambda memory size in MB | `number` | `1024` | no |
| lambda_timeout | Lambda timeout in seconds | `number` | `29` | no |
| enable_s3_object_lambda | Enable S3 Object Lambda | `bool` | `false` | no |
| enable_solution_metrics | Enable anonymous usage metrics collection | `bool` | `false` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cloudfront_distribution_id | CloudFront distribution ID |
| cloudfront_domain_name | CloudFront domain name |
| api_endpoint | API endpoint URL |
| lambda_function_arn | Lambda function ARN |
| lambda_function_name | Lambda function name |
| cloudfront_logs_bucket | S3 bucket for CloudFront logs |

## Image Transformation Examples

Once deployed, you can transform images using URL parameters:

### Basic Resize
```
https://<cloudfront-domain>/image.jpg?width=300&height=200
```

### Crop and Format
```
https://<cloudfront-domain>/image.jpg?width=400&height=400&fit=cover&format=webp
```

### Rotate and Flip
```
https://<cloudfront-domain>/image.jpg?rotate=90&flip=true
```

### Grayscale
```
https://<cloudfront-domain>/image.jpg?grayscale=true
```

## Important Notes

### Lambda Code Deployment

**IMPORTANT**: This module uses the official AWS Solutions Lambda package for image processing. The Lambda function is automatically deployed from:

- S3 Bucket: `solutions-{region}`
- S3 Key: `dynamic-image-transformation-for-amazon-cloudfront/v7.0.7/...`

No manual Lambda code deployment is required. The module handles this automatically.

### Source Bucket Permissions

Ensure the Lambda function has appropriate permissions to read from your source S3 buckets.

### CloudFront Caching

The module configures CloudFront to cache transformed images. The cache key includes:
- Query parameters (width, height, format, etc.)
- Origin header
- Accept header (when auto_webp is enabled)

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0

## License

This module is based on the AWS CloudFormation template for Dynamic Image Transformation.

## Conversion Notes

This module was converted from CloudFormation template SO0023 v7.0.7. Key differences:
- Simplified architecture (removed API Gateway complexity where possible)
- Uses Lambda Function URLs for simpler integration
- Maintains CloudFormation feature parity for core image transformation
- Configurable through Terraform variables instead of CloudFormation parameters
