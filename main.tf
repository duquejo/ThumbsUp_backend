provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      product = "thumbsup-lambda-api-gateway"
    }
  }
}

/** S3 bucket **/
resource "random_pet" "lambda_bucket_name" {
  prefix = "zemoga-thumbsup"
  length = 2
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}


/** Lambda s3 zipping **/
data "archive_file" "lambda_thumbsup_persistency" {
  type = "zip"

  source_dir  = "${path.module}/zemoga-thumbsup-persistency"
  output_path = "${path.module}/zemoga-thumbsup-persistency.zip"
}

resource "aws_s3_object" "lambda_thumbsup_persistency" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "zemoga-thumbsup-persistency.zip"
  source = data.archive_file.lambda_thumbsup_persistency.output_path

  etag = filemd5(data.archive_file.lambda_thumbsup_persistency.output_path)
}

data "archive_file" "lambda_thumbsup_data" {
  type = "zip"

  source_dir  = "${path.module}/zemoga-thumbsup-data"
  output_path = "${path.module}/zemoga-thumbsup-data.zip"
}

resource "aws_s3_object" "lambda_thumbsup_data" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "zemoga-thumbsup-data.zip"
  source = data.archive_file.lambda_thumbsup_data.output_path

  etag = filemd5(data.archive_file.lambda_thumbsup_data.output_path)
}

/** Lambda resource **/
resource "aws_lambda_function" "thumbsup_persistency" {
  function_name = "ThumbsUpPersistency"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_thumbsup_persistency.key

  runtime       = "nodejs18.x"
  architectures = ["arm64"]
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda_thumbsup_persistency.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      redis_host     = local.envs["REDIS_HOST"]
      redis_port     = local.envs["REDIS_PORT"]
      redis_username = local.envs["REDIS_USERNAME"]
      redis_password = local.envs["REDIS_PASSWORD"]
    }
  }
}

# resource "aws_cloudwatch_log_group" "thumbsup_persistency" {
#   name              = "/aws/lambda/${aws_lambda_function.thumbsup_persistency.function_name}"
#   retention_in_days = 1
# }

resource "aws_lambda_function" "thumbsup_data" {
  function_name = "ThumbsUpData"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_thumbsup_data.key

  runtime       = "nodejs18.x"
  architectures = ["arm64"]
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda_thumbsup_data.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      redis_host     = local.envs["REDIS_HOST"]
      redis_port     = local.envs["REDIS_PORT"]
      redis_username = local.envs["REDIS_USERNAME"]
      redis_password = local.envs["REDIS_PASSWORD"]
    }
  }
}

# resource "aws_cloudwatch_log_group" "thumbsup_data" {
#   name              = "/aws/lambda/${aws_lambda_function.thumbsup_data.function_name}"
#   retention_in_days = 1
# }

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

/** HTTP ApiGateway **/
resource "aws_apigatewayv2_api" "lambda" {
  name          = "thumbsup_gw"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_headers = ["content-type"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    max_age       = 300
  }

}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "v1"
  auto_deploy = true

  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_gw.arn

  #   format = jsonencode({
  #     requestId               = "$context.requestId"
  #     sourceIp                = "$context.identity.sourceIp"
  #     requestTime             = "$context.requestTime"
  #     protocol                = "$context.protocol"
  #     httpMethod              = "$context.httpMethod"
  #     resourcePath            = "$context.resourcePath"
  #     routeKey                = "$context.routeKey"
  #     status                  = "$context.status"
  #     responseLength          = "$context.responseLength"
  #     integrationErrorMessage = "$context.integrationErrorMessage"
  #     }
  #   )
  # }
}

resource "aws_apigatewayv2_integration" "thumbsup_persistency" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.thumbsup_persistency.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "thumbsup_persistency" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "POST /save"
  target    = "integrations/${aws_apigatewayv2_integration.thumbsup_persistency.id}"
}

resource "aws_apigatewayv2_integration" "thumbsup_data" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.thumbsup_data.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "thumbsup_data" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /list"
  target    = "integrations/${aws_apigatewayv2_integration.thumbsup_data.id}"
}

# resource "aws_cloudwatch_log_group" "api_gw" {
#   name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

#   retention_in_days = 1
# }

resource "aws_lambda_permission" "api_gw_thumbsup_persistency" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbsup_persistency.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_thumbsup_data" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbsup_data.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}