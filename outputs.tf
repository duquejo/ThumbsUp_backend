output "lambda_bucket_name" {
  description = "Name of the S3 bucket used to store function code."
  value       = aws_s3_bucket.lambda_bucket.id
}

output "function_name_persistency" {
  description = "Name of the Persistency Lambda function."
  value       = aws_lambda_function.thumbsup_persistency.function_name
}

output "function_name_data" {
  description = "Name of the Data Lambda function."
  value       = aws_lambda_function.thumbsup_data.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "envs" {
  value     = local.envs
  sensitive = true
}