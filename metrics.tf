# Solution Metrics - Optional anonymous usage tracking
# This collects CloudWatch metrics about image handler usage

# IAM Role for Metrics Lambda
resource "aws_iam_role" "metrics_lambda" {
  count       = var.enable_solution_metrics ? 1 : 0
  name_prefix = "DynImgTrans-MetricsRole-"

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
      Name        = "${var.name}-metrics-role"
      Environment = var.environment_name
    }
  )
}

# IAM Policy for Metrics Lambda - CloudWatch Logs
resource "aws_iam_role_policy" "metrics_lambda_logs" {
  count = var.enable_solution_metrics ? 1 : 0
  name  = "${var.name}-metrics-logs-policy"
  role  = aws_iam_role.metrics_lambda[0].id

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

# IAM Policy for Metrics Lambda - SQS
resource "aws_iam_role_policy" "metrics_lambda_sqs" {
  count = var.enable_solution_metrics ? 1 : 0
  name  = "${var.name}-metrics-sqs-policy"
  role  = aws_iam_role.metrics_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.metrics_queue[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueUrl",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.metrics_queue[0].arn
      }
    ]
  })
}

# IAM Policy for Metrics Lambda - CloudWatch Metrics
resource "aws_iam_role_policy" "metrics_lambda_cloudwatch" {
  count = var.enable_solution_metrics ? 1 : 0
  name  = "${var.name}-metrics-cloudwatch-policy"
  role  = aws_iam_role.metrics_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "cloudwatch:GetMetricData"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults"
        ]
        Resource = aws_cloudwatch_log_group.lambda_logs.arn
      },
      {
        Effect   = "Allow"
        Action   = "logs:DescribeQueryDefinitions"
        Resource = "*"
      }
    ]
  })
}

# SQS Queue for Metrics Processing
resource "aws_sqs_queue" "metrics_queue" {
  count                     = var.enable_solution_metrics ? 1 : 0
  name_prefix               = "${var.name}-metrics-queue-"
  delay_seconds             = 900 # 15 minutes delay
  max_message_size          = 1024
  message_retention_seconds = 86400 # 1 day
  receive_wait_time_seconds = 20
  visibility_timeout_seconds = 1020 # 17 minutes

  # Enable encryption
  sqs_managed_sse_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-metrics-queue"
      Environment = var.environment_name
    }
  )
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "metrics_queue" {
  count     = var.enable_solution_metrics ? 1 : 0
  queue_url = aws_sqs_queue.metrics_queue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "QueueOwnerOnlyAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "sqs:DeleteMessage",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:RemovePermission",
          "sqs:AddPermission",
          "sqs:SetQueueAttributes"
        ]
        Resource = aws_sqs_queue.metrics_queue[0].arn
      },
      {
        Sid    = "HttpsOnly"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "SQS:*"
        Resource = aws_sqs_queue.metrics_queue[0].arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Metrics Lambda Function
resource "aws_lambda_function" "metrics" {
  count         = var.enable_solution_metrics ? 1 : 0
  function_name = "${var.name}-metrics"
  description   = "Collects anonymous usage metrics for serverless image handler"
  role          = aws_iam_role.metrics_lambda[0].arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60
  memory_size   = 128

  # Using the official AWS Solutions metrics Lambda package
  s3_bucket = "solutions-${data.aws_region.current.name}"
  s3_key    = "dynamic-image-transformation-for-amazon-cloudfront/v7.0.7/181f9dab1aba08559606595cdd0d17d4f7b827288970bf46d0d8a3302cec82d1.zip"

  environment {
    variables = {
      QUERY_PREFIX   = "${var.name}-"
      SOLUTION_ID    = var.solution_id
      SOLUTION_NAME  = "dynamic-image-transformation-for-amazon-cloudfront"
      SOLUTION_VERSION = var.solution_version
      UUID           = random_id.uuid.hex
      EXECUTION_DAY  = var.log_retention_days < 7 ? "*" : "MON"
      SQS_QUEUE_URL  = aws_sqs_queue.metrics_queue[0].url
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-metrics"
      Environment = var.environment_name
    }
  )
}

# CloudWatch Log Group for Metrics Lambda
resource "aws_cloudwatch_log_group" "metrics_lambda_logs" {
  count             = var.enable_solution_metrics ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.metrics[0].function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-metrics-logs"
      Environment = var.environment_name
    }
  )
}

# EventBridge Rule for Scheduled Metrics Collection
resource "aws_cloudwatch_event_rule" "metrics_schedule" {
  count               = var.enable_solution_metrics ? 1 : 0
  name_prefix         = "${var.name}-metrics-"
  description         = "Scheduled trigger for metrics collection"
  schedule_expression = "cron(0 23 ? * ${var.log_retention_days < 7 ? "*" : "MON"} *)"
  is_enabled          = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-metrics-schedule"
      Environment = var.environment_name
    }
  )
}

# EventBridge Target - Metrics Lambda with Input Transformation
resource "aws_cloudwatch_event_target" "metrics_lambda" {
  count = var.enable_solution_metrics ? 1 : 0
  rule  = aws_cloudwatch_event_rule.metrics_schedule[0].name
  arn   = aws_lambda_function.metrics[0].arn

  input_transformer {
    input_paths = {
      time        = "$.time"
      detail-type = "$.detail-type"
    }

    input_template = jsonencode({
      detail-type = "<detail-type>"
      time        = "<time>"
      metrics-data-query = [
        {
          MetricStat = {
            Metric = {
              Namespace  = "AWS/Lambda"
              Dimensions = [
                {
                  Name  = "FunctionName"
                  Value = aws_lambda_function.image_handler.function_name
                }
              ]
              MetricName = "Invocations"
            }
            Stat   = "Sum"
            Period = 604800 # 1 week
          }
          Id = "id_AWS_Lambda_Invocations"
        },
        {
          MetricStat = {
            Metric = {
              Namespace  = "AWS/CloudFront"
              Dimensions = [
                {
                  Name  = "DistributionId"
                  Value = aws_cloudfront_distribution.image_handler.id
                },
                {
                  Name  = "Region"
                  Value = "Global"
                }
              ]
              MetricName = "Requests"
            }
            Stat   = "Sum"
            Period = 604800
          }
          region = "us-east-1"
          Id     = "id_AWS_CloudFront_Requests"
        },
        {
          MetricStat = {
            Metric = {
              Namespace  = "AWS/CloudFront"
              Dimensions = [
                {
                  Name  = "DistributionId"
                  Value = aws_cloudfront_distribution.image_handler.id
                },
                {
                  Name  = "Region"
                  Value = "Global"
                }
              ]
              MetricName = "BytesDownloaded"
            }
            Stat   = "Sum"
            Period = 604800
          }
          region = "us-east-1"
          Id     = "id_AWS_CloudFront_BytesDownloaded"
        }
      ]
    })
  }
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "metrics_eventbridge" {
  count         = var.enable_solution_metrics ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.metrics[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.metrics_schedule[0].arn
}

# Lambda Event Source Mapping for SQS
resource "aws_lambda_event_source_mapping" "metrics_sqs" {
  count            = var.enable_solution_metrics ? 1 : 0
  event_source_arn = aws_sqs_queue.metrics_queue[0].arn
  function_name    = aws_lambda_function.metrics[0].arn
}

# CloudWatch Logs Query Definition - Billed Duration & Memory Size
resource "aws_cloudwatch_query_definition" "billed_duration_memory" {
  count = var.enable_solution_metrics ? 1 : 0
  name  = "${var.name}-BilledDurationMemorySizeQuery"

  log_group_names = [
    aws_cloudwatch_log_group.lambda_logs.name
  ]

  query_string = <<-EOT
    stats sum(@billedDuration) as AWSLambdaBilledDuration, max(@memorySize) as AWSLambdaMemorySize
  EOT
}

# CloudWatch Logs Query Definition - Request Info
resource "aws_cloudwatch_query_definition" "request_info" {
  count = var.enable_solution_metrics ? 1 : 0
  name  = "${var.name}-RequestInfoQuery"

  log_group_names = [
    aws_cloudwatch_log_group.lambda_logs.name
  ]

  query_string = <<-EOT
    parse @message "requestType: 'Default'" as DefaultRequests
    | parse @message "requestType: 'Thumbor'" as ThumborRequests
    | parse @message "requestType: 'Custom'" as CustomRequests
    | parse @message "Query param edits:" as QueryParamRequests
    | parse @message "expires" as ExpiresRequests
    | stats count(DefaultRequests) as DefaultRequestsCount, count(ThumborRequests) as ThumborRequestsCount, count(CustomRequests) as CustomRequestsCount, count(QueryParamRequests) as QueryParamRequestsCount, count(ExpiresRequests) as ExpiresRequestsCount
  EOT
}
