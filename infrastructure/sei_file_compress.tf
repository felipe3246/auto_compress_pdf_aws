# Configure the AWS Provider
provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Get the default VPC ID
data "aws_vpc" "default_vpc" {
  default = true
}

# Get the availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get the default subnets in the default VPC
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Create an S3 bucket
resource "aws_s3_bucket" "sei_compress_package" {
  bucket = "sei-compress-package"
}

# Create an SNS topic
resource "aws_sns_topic" "sei_compressor" {
  name = "sei-compressor"
}

# Define the lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../lambda" # Replace with the path to your Lambda function code
  output_path = "../lambda/lambda_function.zip"
}

# Upload the Lambda function to S3
resource "aws_s3_object" "lambda_function" {
  bucket = aws_s3_bucket.sei_compress_package.id
  key    = "lambda_function.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# Create an EFS file system
resource "aws_efs_file_system" "sei_efs" {
  creation_token = "sei-efs"

  tags = {
    Name = "sei-efs"
  }
}

# Create EFS mount targets in the availability zones where the Lambda function has corresponding subnets
resource "aws_efs_mount_target" "efs_mount_targets" {
  count           = length(data.aws_subnets.default_subnets.ids)
  file_system_id  = aws_efs_file_system.sei_efs.id
  subnet_id       = data.aws_subnets.default_subnets.ids[count.index]
  security_groups = [aws_security_group.efs_security_group.id]
}

# Create a security group for EFS
resource "aws_security_group" "efs_security_group" {
  name_prefix = "efs-sg-"
  vpc_id      = data.aws_vpc.default_vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_security_group.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create VPC endpoint for EFS
resource "aws_vpc_endpoint" "efs_endpoint" {
  vpc_id            = data.aws_vpc.default_vpc.id
  service_name      = "com.amazonaws.us-east-1.elasticfilesystem"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.efs_security_group.id,
  ]

  subnet_ids = data.aws_subnets.default_subnets.ids

  private_dns_enabled = true
}

# Create a security group for the Lambda function
resource "aws_security_group" "lambda_security_group" {
  name_prefix = "lambda-sg-"
  vpc_id      = data.aws_vpc.default_vpc.id

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create an EFS access point
resource "aws_efs_access_point" "sei_access_point" {
  file_system_id = aws_efs_file_system.sei_efs.id

  root_directory {
    path = "/"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }
  posix_user {
    gid = 1000
    uid = 1000
  }
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name               = "sei_compress_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Assume role policy document for the Lambda function
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create an IAM policy for managing network interfaces
resource "aws_iam_policy" "lambda_vpc_network_interface_policy" {
  name        = "lambda_vpc_network_interface_policy"
  description = "Policy to allow Lambda function to manage network interfaces"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach necessary policies to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sns_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_efs_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_efs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access_execution_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_network_interface_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_network_interface_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_xray_write_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# SNS policy for the Lambda function
resource "aws_iam_policy" "lambda_sns_policy" {
  name        = "lambda_sns_policy"
  description = "Policy to allow Lambda function to interact with SNS"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Subscribe"
      ],
      "Resource": "${aws_sns_topic.sei_compressor.arn}"
    }
  ]
}
EOF
}

# EFS policy for the Lambda function
resource "aws_iam_policy" "lambda_efs_policy" {
  name        = "lambda_efs_policy"
  description = "Policy to allow Lambda function to interact with EFS"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Resource": ["${aws_efs_file_system.sei_efs.arn}", "${aws_efs_access_point.sei_access_point.arn}"]
    }
  ]
}
EOF
}

# Create a log group for the Lambda function
resource "aws_cloudwatch_log_group" "sei_compress_lambda_log_group" {
  name              = "/aws/lambda/sei_compress_lambda"
  retention_in_days = 7 # Adjust the retention period as needed
}

# Create the Lambda function
resource "aws_lambda_function" "sei_compress_lambda" {
  function_name = "sei_compress_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.10"
  s3_bucket     = aws_s3_bucket.sei_compress_package.id
  s3_key        = aws_s3_object.lambda_function.key
  timeout       = 60 # Adjust the timeout as needed
  memory_size   = 256
  source_code_hash = filebase64sha256("${data.archive_file.lambda_zip.output_path}")

  vpc_config {
    subnet_ids         = data.aws_subnets.default_subnets.ids
    security_group_ids = [aws_security_group.lambda_security_group.id]
  }

  file_system_config {
    arn            = aws_efs_access_point.sei_access_point.arn
    local_mount_path = "/mnt/lambda"
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.sei_compress_lambda_log_group
  ]
  
  layers = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p310-Pillow:7"]

  environment {
    variables = {
      USER_ID = 1000
      GROUP_ID =1000
    }
  }
}

# Add SNS trigger to the Lambda function
resource "aws_lambda_permission" "sns_trigger" {
  statement_id   = "AllowExecutionFromSNS"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.sei_compress_lambda.function_name
  principal      = "sns.amazonaws.com"
  source_arn     = aws_sns_topic.sei_compressor.arn
}

# Subscribe the Lambda function to the SNS topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.sei_compressor.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sei_compress_lambda.arn
}