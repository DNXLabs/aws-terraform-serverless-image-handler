# S3 Bucket for CloudFront Logging
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket_prefix = "${var.environment_name}-cf-logs-"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-cloudfront-logs"
      Environment = var.environment_name
    }
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# CloudFront Cache Policy
resource "aws_cloudfront_cache_policy" "image_handler" {
  name        = "ServerlessImageHandler-${var.environment_name}"
  comment     = "Cache policy for Serverless Image Handler"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = var.auto_webp ? ["origin", "accept"] : ["origin"]
      }
    }

    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false
  }
}

# CloudFront Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "image_handler" {
  name    = "${var.name}-origin-request-policy"
  comment = "Origin request policy for Serverless Image Handler"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["origin", "accept"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# CloudFront Function for Request Modification
resource "aws_cloudfront_function" "request_modifier" {
  name    = "${var.name}-request-modifier"
  runtime = "cloudfront-js-2.0"
  comment = "Modifies requests for image handler"
  publish = true
  code    = <<-EOT
function handler(event) {
    // Normalize accept header to only include values used on the backend
    if(event.request.headers && event.request.headers.accept && event.request.headers.accept.value) {
        event.request.headers.accept.value = event.request.headers.accept.value.indexOf("image/webp") > -1 ? "image/webp" : ""
    }
    event.request.querystring = processQueryParams(event.request.querystring).join('&')
    return event.request;
}

function processQueryParams(querystring) {
    if (querystring == null) {
        return [];
    }

    const ALLOWED_PARAMS = ['signature', 'expires', 'format', 'fit', 'width', 'height', 'rotate', 'flip', 'flop', 'grayscale'];
    
    let qs = [];
    for (const key in querystring) {
        if (!ALLOWED_PARAMS.includes(key)) {
            continue;
        }
        const value = querystring[key];
        qs.push(
            value.multiValue
                ? `$${key}=$${value.multiValue[value.multiValue.length - 1].value}`
                : `$${key}=$${value.value}`
        )
    }

    return qs.sort();
}
EOT
}

# CloudFront Function for Response Modification (S3 Object Lambda only)
resource "aws_cloudfront_function" "response_modifier" {
  count   = var.enable_s3_object_lambda ? 1 : 0
  name    = "${var.name}-response-modifier"
  runtime = "cloudfront-js-2.0"
  comment = "Modifies responses from S3 Object Lambda"
  publish = true
  code    = <<-EOT
function handler(event) {
    const response = event.response;

    try {
        Object.keys(response.headers).forEach(key => {
            if (key.startsWith("x-amz-meta-") && key !== "x-amz-meta-statuscode") {
                const headerName = key.replace("x-amz-meta-", "");
                response.headers[headerName] = response.headers[key];
                delete response.headers[key];
            }
        });

        const statusCodeHeader = response.headers["x-amz-meta-statuscode"];
        if (statusCodeHeader) {
            const status = parseInt(statusCodeHeader.value);
            if (status >= 400 && status <= 599) {
                response.statusCode = status;
            }

            delete response.headers["x-amz-meta-statuscode"];
        }
    } catch (e) {
        console.log("Error: ", e);
    }
    return response;
}
EOT
}

# S3 Object Lambda Access Point (when S3 Object Lambda is enabled)
resource "aws_s3_access_point" "image_handler" {
  count  = var.enable_s3_object_lambda ? 1 : 0
  bucket = split(",", replace(var.source_buckets, " ", ""))[0]
  name   = "sih-ap-${random_id.uuid.hex}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action = "s3:*"
      Resource = [
        "arn:aws:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:accesspoint/sih-ap-${random_id.uuid.hex}",
        "arn:aws:s3:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:accesspoint/sih-ap-${random_id.uuid.hex}/object/*"
      ]
      Condition = {
        "ForAnyValue:StringEquals" = {
          "aws:CalledVia" = ["s3-object-lambda.amazonaws.com"]
        }
      }
    }]
  })
}

resource "aws_s3control_object_lambda_access_point" "image_handler" {
  count = var.enable_s3_object_lambda ? 1 : 0
  name  = "sih-olap-${random_id.uuid.hex}"

  configuration {
    supporting_access_point = aws_s3_access_point.image_handler[0].arn

    transformation_configuration {
      actions = ["GetObject", "HeadObject"]

      content_transformation {
        aws_lambda {
          function_arn = aws_lambda_function.image_handler.arn
        }
      }
    }
  }
}

# Object Lambda Access Point Policy (required for CloudFront access)
resource "aws_s3control_object_lambda_access_point_policy" "image_handler" {
  count = var.enable_s3_object_lambda ? 1 : 0
  name  = aws_s3control_object_lambda_access_point.image_handler[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3-object-lambda:Get*"
        Resource = aws_s3control_object_lambda_access_point.image_handler[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_cloudfront_distribution.image_handler.arn
          }
        }
      }
    ]
  })
}

# Origin Access Control for S3 Object Lambda
resource "aws_cloudfront_origin_access_control" "image_handler" {
  count                             = var.enable_s3_object_lambda ? 1 : 0
  name                              = "SIH-origin-access-control-${random_id.uuid.hex}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

resource "random_id" "uuid" {
  byte_length = 8
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "image_handler" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Image Handler Distribution for ${var.name}"
  http_version        = "http2"
  price_class         = var.cloudfront_price_class
  default_root_object = ""

  dynamic "origin" {
    for_each = var.enable_s3_object_lambda ? [1] : []
    content {
      # S3 Object Lambda origin
      # The alias value provides the domain name prefix
      # Format: {alias}.s3.{region}.amazonaws.com
      domain_name              = "${aws_s3control_object_lambda_access_point.image_handler[0].alias}.s3.${data.aws_region.current.name}.amazonaws.com"
      origin_id                = "lambda-origin"
      origin_path              = "/image"
      origin_access_control_id = aws_cloudfront_origin_access_control.image_handler[0].id

      s3_origin_config {
        origin_access_identity = ""
      }

      dynamic "origin_shield" {
        for_each = var.origin_shield_region != "Disabled" ? [1] : []
        content {
          enabled              = true
          origin_shield_region = var.origin_shield_region
        }
      }
    }
  }

  dynamic "origin" {
    for_each = var.enable_s3_object_lambda ? [] : [1]
    content {
      # Lambda Function URL origin configuration
      domain_name = "${aws_lambda_function.image_handler.function_name}.lambda-url.${data.aws_region.current.name}.on.aws"
      origin_id   = "lambda-origin"

      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      dynamic "origin_shield" {
        for_each = var.origin_shield_region != "Disabled" ? [1] : []
        content {
          enabled              = true
          origin_shield_region = var.origin_shield_region
        }
      }
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "lambda-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = aws_cloudfront_cache_policy.image_handler.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.image_handler.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.request_modifier.arn
    }

    # Add response modifier function for S3 Object Lambda
    dynamic "function_association" {
      for_each = var.enable_s3_object_lambda ? [1] : []
      content {
        event_type   = "viewer-response"
        function_arn = aws_cloudfront_function.response_modifier[0].arn
      }
    }
  }

  # Custom error responses for 5xx errors
  custom_error_response {
    error_code            = 500
    error_caching_min_ttl = 600
  }

  custom_error_response {
    error_code            = 501
    error_caching_min_ttl = 600
  }

  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 600
  }

  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 600
  }

  custom_error_response {
    error_code            = 504
    error_caching_min_ttl = 600
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "image-handler/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-cloudfront-distribution"
      Environment = var.environment_name
    }
  )
}

# Data source for current region
data "aws_region" "current" {}
