# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_execution" {
  name_prefix = "DynImgTrans-ImgHandlerRole-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-lambda-execution-role"
      Environment = var.environment_name
    }
  )
}

# IAM Policy for Lambda - CloudWatch Logs
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.name}-lambda-logs-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })
}

# IAM Policy for Lambda - S3 Access to Source Buckets
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.name}-lambda-s3-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          for bucket in split(",", replace(var.source_buckets, " ", "")) : "arn:aws:s3:::${bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          for bucket in split(",", replace(var.source_buckets, " ", "")) : "arn:aws:s3:::${bucket}"
        ]
      }
    ]
  })
}

# IAM Policy for Lambda - Rekognition (for face detection, content moderation)
resource "aws_iam_role_policy" "lambda_rekognition" {
  name = "${var.name}-lambda-rekognition-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectFaces",
          "rekognition:DetectModerationLabels"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for Lambda - Secrets Manager (conditional)
resource "aws_iam_role_policy" "lambda_secrets_manager" {
  count = var.enable_signature ? 1 : 0
  name  = "${var.name}-lambda-secrets-manager-policy"
  role  = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.secrets_manager_secret != "" ? "arn:aws:secretsmanager:*:*:secret:${var.secrets_manager_secret}*" : null
      }
    ]
  })
}

# IAM Policy for Lambda - Fallback Image S3 Access (conditional)
resource "aws_iam_role_policy" "lambda_fallback_image" {
  count = var.enable_default_fallback_image ? 1 : 0
  name  = "${var.name}-lambda-fallback-image-policy"
  role  = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.fallback_image_s3_bucket}/${var.fallback_image_s3_key}"
      }
    ]
  })
}

# IAM Policy for Lambda - S3 Object Lambda (conditional)
resource "aws_iam_role_policy" "lambda_s3_object_lambda" {
  count = var.enable_s3_object_lambda ? 1 : 0
  name  = "${var.name}-lambda-s3-object-lambda-policy"
  role  = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3-object-lambda:WriteGetObjectResponse"
        ]
        Resource = "*"
      }
    ]
  })
}
