provider "aws" {
  region = "us-east-1"
}

variable "input_tags" {
    type = string
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "IAM-Change-Lambda"
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
  name        = "IAM-Change-Lambda-Logs"
  role        = aws_iam_role.iam_for_lambda.id
  policy      = data.aws_iam_policy_document.lambdalogspolicy.json
}

data "aws_iam_policy_document" "lambdalogspolicy" {
  statement {
    sid       = "createloggroup"
    actions   = [ "logs:CreateLogGroup",]
    resources = ["arn:aws:logs:*:923913370688:*",]
  }

  statement {
    sid       = "createlogstream"
    actions   = [ "logs:CreateLogStream",
                "logs:PutLogEvents",]
    resources = [
    "arn:aws:logs:*:923913370688:log-group:/aws/lambda/IAM-Change:*",]
  }
}

resource "aws_cloudwatch_event_rule" "IAMEvents" {
  name          = "IAM-Change"
  description   = "Detect any IAM security related change"

  event_pattern = <<EOF
{
  "source": [
    "aws.iam"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "iam.amazonaws.com"
    ],
    "eventName": [
      "AddUserToGroup",
      "CreateLoginProfile",
      "DeleteUser",
      "CreateUser",
      "DeleteGroupPolicy",
      "DeleteRolePolicy",
      "DeleteUserPolicy",
      "PutGroupPolicy",
      "PutRolePolicy",
      "PutUserPolicy",
      "CreatePolicy",
      "DeletePolicy",
      "CreatePolicyVersion",
      "DeletePolicyVersion",
      "AttachRolePolicy",
      "DetachRolePolicy",
      "AttachUserPolicy",
      "DetachUserPolicy",
      "AttachGroupPolicy",
      "DetachGroupPolicy",
      "AddRoleToInstanceProfile",
      "AddUserToGroup",
      "CreateAccessKey",
      "CreateInstanceProfile",
      "CreateRole",
      "DeleteAccessKey",
      "DeleteLoginProfile",
      "DeleteRole"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule          = aws_cloudwatch_event_rule.IAMEvents.id
  target_id     = "Send-To-IAM-Change-Lambda"
  arn           = aws_lambda_function.IAMChange.arn
}


resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.IAMChange.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.IAMEvents.arn
}


resource "aws_lambda_function" "IAMChange" {
  filename      = "lambda/iam-change/lambda_function.zip"
  function_name = "IAM-Change"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 5

  runtime       = "python3.8"
  tags          = {
      APP_NAME  = var.input_tags
  }
}
