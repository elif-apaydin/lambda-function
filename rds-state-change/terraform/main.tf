provider "aws" {
  region = "us-east-1"
}

variable "input_tags" {
    type = string
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "RDS-Change-Lambda"
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
  name          = "RDS-Change-Lambda-Logs"
  role          = aws_iam_role.iam_for_lambda.id
  policy        = data.aws_iam_policy_document.lambdalogspolicy.json
}

data "aws_iam_policy_document" "lambdalogspolicy" {
  statement {
    sid         = "createloggroup"
    actions     = [ "logs:CreateLogGroup",]
    resources   = ["arn:aws:logs:*:923913370688:*",]
  }

  statement {
    sid = "createlogstream"
    actions     = [ "logs:CreateLogStream","logs:PutLogEvents",]
    resources   = ["arn:aws:logs:*:923913370688:log-group:/aws/lambda/RDS-Change:*",]
  }
}

resource "aws_cloudwatch_event_rule" "RdsEvents" {
  name          = "RDS-Change"
  description   = "Detect any rds security related change"

  event_pattern = <<EOF
{
  "source": [
    "aws.rds"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "rds.amazonaws.com"
    ],
    "eventName": [
      "CreateDBCluster",
      "CreateDBClusterParameterGroup",
      "CreateDBClusterSnapshot",
      "CreateDBInstance",
      "CreateDBInstanceReadReplica",
      "CreateDBParameterGroup",
      "CreateDBSecurityGroup",
      "CreateDBSnapshot",
      "CreateDBSubnetGroup",
      "DeleteDBCluster",
      "DeleteDBClusterParameterGroup",
      "DeleteDBInstance",
      "DeleteDBClusterSnapshot",
      "DeleteDBParameterGroup",
      "DeleteDBSecurityGroup",
      "DeleteDBSnapshot",
      "DeleteDBSubnetGroup",
      "DeleteOptionGroup",
      "ModifyDBCluster",
      "ModifyDBInstance",
      "ModifyDBParameterGroup",
      "ModifyDBSubnetGroup",
      "RebootDBInstance",
      "RestoreDBClusterFromSnapshot",
      "RestoreDBInstanceFromDBSnapshot",
      "RestoreDBClusterToPointInTime",
      "RestoreDBInstanceToPointInTime",
      "RevokeDBSecurityGroupIngress",
      "ModifyDBClusterParameterGroup",
      "ModifyDBSnapshotAttribute"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule          = aws_cloudwatch_event_rule.RdsEvents.id
  target_id     = "Send-To-RDS-Change-Lambda"
  arn           = aws_lambda_function.RdsChange.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.RdsChange.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.RdsEvents.arn
}

resource "aws_lambda_function" "RdsChange" {
  filename      = "lambda/rds-change/lambda_function.py"
  function_name = "RDS-Change"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"
  timeout       = 5

  runtime       = "python3.8"
  tags = {
      APP_NAME  = var.input_tags
  }
}
