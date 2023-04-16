data "archive_file" "lambda_my_function" {
  type        = "zip"
  source_file = "${path.root}/../example/lambda.py"
  output_path = "${path.root}/../example.zip"
}

resource "aws_s3_bucket" "api-bucket" {
  bucket        = "api-bucket-giiiiitdoc"
  force_destroy = true
}

resource "aws_s3_object" "api_code_archive" {
  bucket = aws_s3_bucket.api-bucket.id
  key    = "lambda.zip"
  source = data.archive_file.lambda_my_function.output_path

}
