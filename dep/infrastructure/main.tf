terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1" # You can change this to your preferred region
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "hireapro-api"
  protocol_type = "HTTP"
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "Prod"
  auto_deploy = true
}

# Lambda function
resource "aws_lambda_function" "aspnet_core_function" {
  function_name = "hireapro-api-function"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "solifas/hireapro:9" # Local image name

  vpc_config {
    subnet_ids         = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      ASPNETCORE_ENVIRONMENT = "Production"
    }
  }
}

# Security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "hireapro-lambda-sg"
  description = "Security group for HireAPro Lambda function"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "hireapro-lambda-role"

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
}

# IAM policy attachment for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM policy attachment for Lambda VPC access
resource "aws_iam_role_policy_attachment" "lambda_vpc_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# API Gateway integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.aspnet_core_function.invoke_arn
}

# API Gateway route for proxy
resource "aws_apigatewayv2_route" "proxy_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway route for root
resource "aws_apigatewayv2_route" "root_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aspnet_core_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# Output the API endpoint
output "api_endpoint" {
  value       = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/"
  description = "API endpoint URL for Prod environment"
}
