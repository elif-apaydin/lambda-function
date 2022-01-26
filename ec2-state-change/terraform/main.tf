provider "aws" {
  region        = "eu-central-1"
}

variable "input_tags" {
    type        = string
}

resource "aws_iam_role" "iam_for_lambda" {
  name          = "EC2-Change-Lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "VisualEditor0"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambdalogs" {
  name          = "EC2-Change-Lambda-Logs"
  role          = aws_iam_role.iam_for_lambda.id
  policy        = data.aws_iam_policy_document.lambdalogspolicy.json
}

data "aws_iam_policy_document" "lambdalogspolicy" {
  statement {
    sid         = "createloggroup"
    actions     = ["logs:CreateLogGroup",]
    resources   = ["arn:aws:logs:*:923913370688:*",]
  }

  statement {
    sid         = "createlogstream"
    actions     = [ "logs:CreateLogStream","logs:PutLogEvents",]
    resources   = ["arn:aws:logs:*:923913370688:log-group:/aws/lambda/EC2-Change:*",]
  }
}

resource "aws_cloudwatch_event_rule" "EC2Events" {
  name          = "EC2-Change"
  description   = "Detect any ec2 security related change"

  event_pattern = <<EOF
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "ec2.amazonaws.com"
    ],
    "eventName": [
      "TerminateInstances",
      "CreateInstanceSnapshot",
      "StartInstances",
      "StopInstances",
      "RunInstances",
      "CreateInstancesFromSnapshot",
      "DeleteInstanceSnaphsot",
      "RebootInstances",
      "CreateInstances"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule          = aws_cloudwatch_event_rule.EC2Events.id
  target_id     = "Send-To-EC2-Change-Lambda"
  arn           = aws_lambda_function.EC2Change.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.EC2Change.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.EC2Events.arn
}

resource "aws_lambda_function" "EC2Change" {
  filename      = "lambda/ec2-change/lambda_function.zip"
  function_name = "EC2-Change"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 5

  runtime = "python3.8"
  tags = {
      APP_NAME  = var.input_tags
  }
}
