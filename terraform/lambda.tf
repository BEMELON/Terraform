resource "aws_lambda_function" "api_lambda" {
  function_name    = "example-api"
  role             = aws_iam_role.api_lambda_role.arn
  s3_bucket        = aws_s3_bucket.api-bucket.id
  s3_key           = aws_s3_object.api_code_archive.key
  source_code_hash = data.archive_file.lambda_my_function.output_base64sha256

  architectures = ["arm64"]
  runtime       = "provided.al2"
  handler       = "main"
  memory_size   = 128
  publish       = true

}


resource "aws_lambda_alias" "api_lambda_alias" {
  name             = "production"
  function_name    = aws_lambda_function.api_lambda.function_name
  function_version = aws_lambda_function.api_lambda.version

  lifecycle {
    ignore_changes = [
      function_version
    ]
  }
}

resource "aws_cloudwatch_log_group" "api_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.api_lambda.function_name}"
  retention_in_days = 14
  tags              = {}
}

resource "aws_iam_role" "api_lambda_role" {
  name = "example-api-lambda-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
  ] })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "example-api-lambda-policy"
  role = aws_iam_role.api_lambda_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      }
    ]
  })
}

/*
 * An API gateway to expose our function
 * to the Internet
 */
resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "example-api-gateway"
  protocol_type = "HTTP"
  tags          = {}
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api_gateway_log_group/${aws_apigatewayv2_api.api_gateway.name}"
  retention_in_days = 14
  tags              = {}
}

/*
 * Default stage for our API gateway
 * with basic access logs
 */
resource "aws_apigatewayv2_stage" "api_gateway_default_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "$default"
  auto_deploy = true
  tags        = {}

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      status                  = "$context.status"
      responseLatency         = "$context.responseLatency"
      path                    = "$context.path"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

/*
 * Integrate our function with our API gateway
 * so that they can communicate
 */
resource "aws_apigatewayv2_integration" "api_gateway_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_uri    = "${aws_lambda_function.api_lambda.arn}:${aws_lambda_alias.api_lambda_alias.name}"
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  request_parameters = {}
  request_templates  = {}
}

/*
 * Tell our API gateway to forward all incoming
 * requests (every path + HTTP verb) to our function
 */
resource "aws_apigatewayv2_route" "api_gateway_any_route" {
  api_id               = aws_apigatewayv2_api.api_gateway.id
  route_key            = "ANY /{proxy+}"
  target               = "integrations/${aws_apigatewayv2_integration.api_gateway_integration.id}"
  authorization_scopes = []
  request_models       = {}
}

/*
 * Allow our API gateway to invoke our function
 */
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  principal     = "apigateway.amazonaws.com"
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_lambda.function_name
  qualifier     = aws_lambda_alias.api_lambda_alias.name
  source_arn    = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*/*"
}

/*
 * Tell Terraform to output the URL
 * of our default API gateway stage after each `terraform apply`
 */
output "api_gateway_invoke_url" {
  description = "API gateway default stage invokation URL"
  value       = aws_apigatewayv2_stage.api_gateway_default_stage.invoke_url
}
