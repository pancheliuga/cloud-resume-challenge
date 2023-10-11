# Setup the DynamoDB table.
resource "aws_dynamodb_table" "visitors_count" {
  name         = "${var.project}-visitors-count"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "IPHash"

  attribute {
    name = "IPHash"
    type = "S"
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Setup the bucket for the Lambda function code.
resource "aws_s3_bucket" "app" {
  bucket = "${var.project}-app"

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_s3_object" "app" {
  bucket = aws_s3_bucket.app.id

  key    = "app.zip"
  source = data.archive_file.app.output_path

  etag = filemd5(data.archive_file.app.output_path)
}

data "archive_file" "app" {
  type = "zip"

  output_path = "${path.module}/app.zip"
  source_file  = "${path.module}/../../../app/src/ddb_lambda.py"
}

# Setup the Lambda function.
resource "aws_lambda_function" "app" {
  function_name = "${var.project}-app"

  s3_bucket = aws_s3_bucket.app.id
  s3_key    = aws_s3_object.app.key

  runtime = "python3.9"
  handler = "ddb_lambda.lambda_handler"
  
  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.visitors_count.name
    }
  }

  source_code_hash = data.archive_file.app.output_base64sha256

  role = aws_iam_role.app.arn

  depends_on = [
    aws_cloudwatch_log_group.app,
  ]

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# Setup the Lambda function roles and policies.
resource "aws_iam_role" "app" {
  name = "${var.project}-app"

  assume_role_policy = templatefile("${path.module}/templates/lambda-role-policy.json", {})
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "app_dynamodb" {
  name = "${var.project}-app-dynamodb"
  role = aws_iam_role.app.id

  policy = templatefile(
    "${path.module}/templates/dynamodb-role-policy.json",
    {
      visitors_count = aws_dynamodb_table.visitors_count.arn,
    }
  )
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/aws/lambda/${var.project}-app"

  retention_in_days = 30
}

# Setup the HTTP API Gateway, its stages and routes.
resource "aws_apigatewayv2_api" "app" {
  name          = "${var.project}-app"
  protocol_type = "HTTP"

  cors_configuration {
    allow_methods = ["POST"]
    allow_origins = ["*"]
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.app_api.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }

  default_route_settings {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}

resource "aws_apigatewayv2_route" "app" {
  api_id = aws_apigatewayv2_api.app.id

  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_integration" "app" {
  api_id = aws_apigatewayv2_api.app.id

  integration_uri    = aws_lambda_function.app.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_api_mapping" "app" {
  count = var.domain == null || var.domain == "" ? 0 : 1

  api_id      = aws_apigatewayv2_api.app.id
  domain_name = aws_apigatewayv2_domain_name.app[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_apigatewayv2_domain_name" "app" {
  count = var.domain == null || var.domain == "" ? 0 : 1

  domain_name = var.domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.app[0].arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_acm_certificate" "app" {
  count = var.domain == null || var.domain == "" ? 0 : 1

  domain_name = var.domain
  validation_method = "DNS"

  tags = {
    Project     = var.project
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lambda_permission" "app" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.app.execution_arn}/*/*/"
}

resource "aws_cloudwatch_log_group" "app_api" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.app.name}"

  retention_in_days = 30
}

# Setup CloudWatch alarms and email alerts.
resource "aws_sns_topic" "app" {
  name = "${var.project}-alarms"
}

resource "aws_sns_topic_subscription" "app" {
  count = var.alarm_email == null || var.alarm_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.app.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "app_api_latency" {
  alarm_name                = "${var.project}-api-latency"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Latency"
  namespace                 = "AWS/ApiGateway"
  period                    = 300
  statistic                 = "Average"
  threshold                 = 3000
  alarm_description         = "Project: ${var.project}\nEnvironment: ${var.environment}\n\nThe HTTP API Gateway for the Cloud Resume Challenge has had a sudden increase in latency for the past 5 minutes. You may need to check the HTTP API Gateway and determine the cause of the error."
  insufficient_data_actions = []

  dimensions = {
    ApiName = aws_apigatewayv2_api.app.name
    Stage   = aws_apigatewayv2_stage.default.name
  }

  alarm_actions = [aws_sns_topic.app.arn]
}

resource "aws_cloudwatch_metric_alarm" "app_api_count" {
  alarm_name                = "${var.project}-api-count"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Count"
  namespace                 = "AWS/ApiGateway"
  period                    = 300
  statistic                 = "Sum"
  threshold                 = 100
  alarm_description         = "Project: ${var.project}\nEnvironment: ${var.environment}\n\nThe HTTP API Gateway for the Cloud Resume Challenge has encountered a sudden amount of API calls for the last 5 minutes. You may need to check the API calls made and determine if this is a DDoS attack or just a sudden influx of users."
  insufficient_data_actions = []

  dimensions = {
    ApiName = aws_apigatewayv2_api.app.name
    Stage   = aws_apigatewayv2_stage.default.name
  }

  alarm_actions = [aws_sns_topic.app.arn]
}

resource "aws_cloudwatch_metric_alarm" "app_lambda_error" {
  alarm_name                = "${var.project}-lambda-error"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = 3600
  statistic                 = "Sum"
  threshold                 = 5
  alarm_description         = "Project: ${var.project}\nEnvironment: ${var.environment}\n\nThe Lambda function has encountered a sudden amount of errors for the past hour. You may need to check the lambda function and determine the cause of the error."
  insufficient_data_actions = []

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  alarm_actions = [aws_sns_topic.app.arn]
}