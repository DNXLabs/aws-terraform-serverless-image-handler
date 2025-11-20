# Demo UI - Web interface for testing image transformations
# This creates a separate S3 bucket and CloudFront distribution for the demo UI

# S3 Bucket for Demo UI Website
resource "aws_s3_bucket" "demo_ui" {
  count         = var.deploy_demo_ui ? 1 : 0
  bucket_prefix = "${var.environment_name}-sih-demo-ui-"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-demo-ui-bucket"
      Environment = var.environment_name
    }
  )
}

# Enable versioning for demo UI bucket
resource "aws_s3_bucket_versioning" "demo_ui" {
  count  = var.deploy_demo_ui ? 1 : 0
  bucket = aws_s3_bucket.demo_ui[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption for demo UI bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_ui" {
  count  = var.deploy_demo_ui ? 1 : 0
  bucket = aws_s3_bucket.demo_ui[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for demo UI bucket
resource "aws_s3_bucket_public_access_block" "demo_ui" {
  count  = var.deploy_demo_ui ? 1 : 0
  bucket = aws_s3_bucket.demo_ui[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for demo UI bucket
resource "aws_s3_bucket_lifecycle_configuration" "demo_ui" {
  count  = var.deploy_demo_ui ? 1 : 0
  bucket = aws_s3_bucket.demo_ui[0].id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
  }
}

# Origin Access Control for Demo UI
resource "aws_cloudfront_origin_access_control" "demo_ui" {
  count                             = var.deploy_demo_ui ? 1 : 0
  name                              = "${var.name}-demo-ui-oac"
  description                       = "OAC for Demo UI S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy for Demo UI - Allow CloudFront Access
resource "aws_s3_bucket_policy" "demo_ui" {
  count  = var.deploy_demo_ui ? 1 : 0
  bucket = aws_s3_bucket.demo_ui[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.demo_ui[0].arn,
          "${aws_s3_bucket.demo_ui[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.demo_ui[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.demo_ui[0].arn
          }
        }
      }
    ]
  })
}

# CloudFront Distribution for Demo UI
resource "aws_cloudfront_distribution" "demo_ui" {
  count = var.deploy_demo_ui ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Demo UI Distribution for ${var.name}"
  default_root_object = "index.html"
  http_version        = "http2"
  price_class         = "PriceClass_All"

  origin {
    domain_name              = aws_s3_bucket.demo_ui[0].bucket_regional_domain_name
    origin_id                = "demo-ui-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.demo_ui[0].id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "demo-ui-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Use AWS managed cache policy for caching static content
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  # Custom error responses for SPA routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "demo-ui/"
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
      Name        = "${var.name}-demo-ui-distribution"
      Environment = var.environment_name
    }
  )
}

# Demo UI Configuration File
# This creates a config file with the API endpoint URL
resource "aws_s3_object" "demo_ui_config" {
  count        = var.deploy_demo_ui ? 1 : 0
  bucket       = aws_s3_bucket.demo_ui[0].id
  key          = "demo-ui-config.js"
  content_type = "application/javascript"

  content = <<-EOT
    // Demo UI Configuration
    const demoUiConfig = {
      apiEndpoint: 'https://${aws_cloudfront_distribution.image_handler.domain_name}'
    };
  EOT

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-demo-ui-config"
      Environment = var.environment_name
    }
  )
}

# Demo UI HTML File
resource "aws_s3_object" "demo_ui_index" {
  count        = var.deploy_demo_ui ? 1 : 0
  bucket       = aws_s3_bucket.demo_ui[0].id
  key          = "index.html"
  content_type = "text/html"

  content = <<-EOT
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Serverless Image Handler - Demo UI</title>
    <script src="demo-ui-config.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #232f3e; margin-bottom: 10px; }
        .subtitle { color: #666; margin-bottom: 30px; }
        .section { margin-bottom: 30px; padding: 20px; background: #f9f9f9; border-radius: 4px; }
        .section h2 { color: #232f3e; margin-bottom: 15px; font-size: 18px; }
        .input-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; color: #333; }
        input, select { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; }
        button { background: #ff9900; color: white; border: none; padding: 12px 24px; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: bold; }
        button:hover { background: #ec7211; }
        .result { margin-top: 20px; padding: 20px; background: white; border: 1px solid #ddd; border-radius: 4px; }
        .image-preview { max-width: 100%; margin-top: 20px; border: 1px solid #ddd; }
        .url-output { padding: 10px; background: #f5f5f5; border: 1px solid #ddd; border-radius: 4px; font-family: monospace; font-size: 12px; word-break: break-all; margin-top: 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; }
        .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #0073bb; border-radius: 4px; margin-bottom: 20px; }
        .endpoint { background: #232f3e; color: white; padding: 15px; border-radius: 4px; margin-bottom: 20px; font-family: monospace; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖼️ Serverless Image Handler - Demo UI</h1>
        <p class="subtitle">Test dynamic image transformations with CloudFront</p>
        
        <div class="info">
            <strong>📍 API Endpoint:</strong><br>
            <div class="endpoint" id="api-endpoint">Loading...</div>
        </div>

        <div class="section">
            <h2>Image Source</h2>
            <div class="input-group">
                <label for="bucket">S3 Bucket Name:</label>
                <input type="text" id="bucket" placeholder="Enter full bucket name (e.g., staging-general-assets-bucket-new-au...)">
            </div>
            <div class="input-group">
                <label for="imageKey">Image Path (e.g., TestImage.png or productGroup/1000005/demo1.png):</label>
                <input type="text" id="imageKey" placeholder="TestImage.png">
            </div>
        </div>

        <div class="section">
            <h2>Transformations</h2>
            <div class="grid">
                <div class="input-group">
                    <label for="width">Width (px):</label>
                    <input type="number" id="width" placeholder="Leave empty for original">
                </div>
                <div class="input-group">
                    <label for="height">Height (px):</label>
                    <input type="number" id="height" placeholder="Leave empty for original">
                </div>
                <div class="input-group">
                    <label for="fit">Fit Mode:</label>
                    <select id="fit">
                        <option value="">None</option>
                        <option value="cover">Cover (crop to fill)</option>
                        <option value="contain">Contain (fit within)</option>
                        <option value="fill">Fill (stretch)</option>
                        <option value="inside">Inside</option>
                        <option value="outside">Outside</option>
                    </select>
                </div>
                <div class="input-group">
                    <label for="format">Format:</label>
                    <select id="format">
                        <option value="">Original</option>
                        <option value="jpeg">JPEG</option>
                        <option value="png">PNG</option>
                        <option value="webp">WebP</option>
                    </select>
                </div>
                <div class="input-group">
                    <label for="rotate">Rotate (degrees):</label>
                    <input type="number" id="rotate" placeholder="0, 90, 180, 270">
                </div>
                <div class="input-group">
                    <label for="grayscale">Grayscale:</label>
                    <select id="grayscale">
                        <option value="">No</option>
                        <option value="true">Yes</option>
                    </select>
                </div>
            </div>
        </div>

        <button onclick="generateUrl()">Generate Image URL</button>
        <button onclick="clearForm()" style="background: #666; margin-left: 10px;">Clear</button>

        <div class="result" id="result" style="display: none;">
            <h2>Result</h2>
            <div class="url-output" id="generatedUrl"></div>
            <div style="margin-top: 20px;">
                <button onclick="copyUrl()">Copy URL</button>
                <button onclick="openInNewTab()" style="background: #0073bb; margin-left: 10px;">Open in New Tab</button>
            </div>
            <img id="preview" class="image-preview" style="display: none;">
        </div>
    </div>

    <script>
        // Load API endpoint from config
        document.getElementById('api-endpoint').textContent = demoUiConfig.apiEndpoint;

        function generateUrl() {
            const bucket = document.getElementById('bucket').value.trim();
            const imageKey = document.getElementById('imageKey').value.trim();
            
            if (!bucket) {
                alert('Please enter a bucket name');
                return;
            }
            
            if (!imageKey) {
                alert('Please enter an image path');
                return;
            }

            // Build the request object
            const request = {
                bucket: bucket,
                key: imageKey
            };

            // Add edits if specified
            const width = document.getElementById('width').value;
            const height = document.getElementById('height').value;
            const fit = document.getElementById('fit').value;
            const format = document.getElementById('format').value;
            const rotate = document.getElementById('rotate').value;
            const grayscale = document.getElementById('grayscale').value;

            const edits = {};
            
            if (width || height || fit) {
                edits.resize = {};
                if (width) edits.resize.width = parseInt(width);
                if (height) edits.resize.height = parseInt(height);
                if (fit) edits.resize.fit = fit;
            }
            
            if (format) {
                edits.toFormat = format;
            }
            
            if (rotate) {
                edits.rotate = parseInt(rotate);
            }
            
            if (grayscale === 'true') {
                edits.grayscale = true;
            }

            if (Object.keys(edits).length > 0) {
                request.edits = edits;
            }

            // Convert to JSON and base64 encode
            const jsonString = JSON.stringify(request);
            const base64Request = btoa(jsonString);
            
            // Build final URL
            const url = demoUiConfig.apiEndpoint + '/' + base64Request;

            document.getElementById('generatedUrl').textContent = url;
            document.getElementById('result').style.display = 'block';
            
            const preview = document.getElementById('preview');
            preview.src = url;
            preview.style.display = 'block';
            preview.onerror = function() {
                alert('Failed to load image. Please check the bucket and image path.');
            };
        }

        function copyUrl() {
            const url = document.getElementById('generatedUrl').textContent;
            navigator.clipboard.writeText(url).then(() => {
                alert('URL copied to clipboard!');
            });
        }

        function openInNewTab() {
            const url = document.getElementById('generatedUrl').textContent;
            window.open(url, '_blank');
        }

        function clearForm() {
            document.getElementById('imageKey').value = '';
            document.getElementById('width').value = '';
            document.getElementById('height').value = '';
            document.getElementById('fit').value = '';
            document.getElementById('format').value = '';
            document.getElementById('rotate').value = '';
            document.getElementById('grayscale').value = '';
            document.getElementById('result').style.display = 'none';
        }
    </script>
</body>
</html>
  EOT

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-demo-ui-index"
      Environment = var.environment_name
    }
  )
}
