#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# S3 → Lambda → SNS Infrastructure Provisioning
# ============================================================

readonly AWS_REGION="${AWS_REGION:-us-east-1}"
readonly LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-s3-lambda-function}"
readonly IAM_ROLE_NAME="${IAM_ROLE_NAME:-s3-lambda-sns}"
readonly SNS_TOPIC_NAME="${SNS_TOPIC_NAME:-s3-lambda-sns}"

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

trap 'die "Command failed at line $LINENO: $BASH_COMMAND"' ERR

# ------------------------------------------------------------
# Validate dependencies
# ------------------------------------------------------------

for cmd in aws jq; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command not found: $cmd"
done

# ------------------------------------------------------------
# Validate AWS authentication
# ------------------------------------------------------------

AWS_ACCOUNT_ID="$(
    aws sts get-caller-identity \
        --query 'Account' \
        --output text
)"

AWS_USER_ARN="$(
    aws sts get-caller-identity \
        --query 'Arn' \
        --output text
)"

log "AWS Account : $AWS_ACCOUNT_ID"
log "Identity    : $AWS_USER_ARN"
log "Region      : $AWS_REGION"

# ------------------------------------------------------------
# IAM Role Trust Policy
# ------------------------------------------------------------

readonly TRUST_POLICY="$(mktemp)"

cleanup() {
    rm -f "$TRUST_POLICY"
}

trap cleanup EXIT

cat > "$TRUST_POLICY" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# ------------------------------------------------------------
# Create IAM Role if it does not exist
# ------------------------------------------------------------

if aws iam get-role \
    --role-name "$IAM_ROLE_NAME" \
    >/dev/null 2>&1; then

    log "IAM role already exists: $IAM_ROLE_NAME"

else

    log "Creating IAM role: $IAM_ROLE_NAME"

    aws iam create-role \
        --role-name "$IAM_ROLE_NAME" \
        --assume-role-policy-document "file://$TRUST_POLICY" \
        --description "Execution role for S3 Lambda SNS automation" \
        >/dev/null

    log "IAM role created successfully."

fi

# ------------------------------------------------------------
# Retrieve Role ARN
# ------------------------------------------------------------

ROLE_ARN="$(
    aws iam get-role \
        --role-name "$IAM_ROLE_NAME" \
        --query 'Role.Arn' \
        --output text
)"

log "Role ARN: $ROLE_ARN"

# ------------------------------------------------------------
# Attach Lambda execution policy
# ------------------------------------------------------------

LAMBDA_POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

if aws iam list-attached-role-policies \
    --role-name "$IAM_ROLE_NAME" \
    --query "AttachedPolicies[?PolicyArn=='$LAMBDA_POLICY_ARN'].PolicyArn" \
    --output text |
    grep -q "$LAMBDA_POLICY_ARN"; then

    log "Lambda execution policy already attached."

else

    log "Attaching Lambda execution policy..."

    aws iam attach-role-policy \
        --role-name "$IAM_ROLE_NAME" \
        --policy-arn "$LAMBDA_POLICY_ARN"

    log "Lambda execution policy attached."

fi

# ------------------------------------------------------------
# Create SNS Topic if required
# ------------------------------------------------------------

SNS_TOPIC_ARN="$(
    aws sns create-topic \
        --name "$SNS_TOPIC_NAME" \
        --region "$AWS_REGION" \
        --query 'TopicArn' \
        --output text
)"

log "SNS Topic: $SNS_TOPIC_ARN"

# ------------------------------------------------------------
# Apply resource tags
# ------------------------------------------------------------

aws iam tag-role \
    --role-name "$IAM_ROLE_NAME" \
    --tags \
        Key=Environment,Value=Production \
        Key=ManagedBy,Value=Shell \
        Key=Project,Value=S3-Lambda-SNS

aws sns tag-resource \
    --resource-arn "$SNS_TOPIC_ARN" \
    --tags \
        Key=Environment,Value=Production \
        Key=ManagedBy,Value=Shell \
        Key=Project,Value=S3-Lambda-SNS

# ------------------------------------------------------------
# Verify configuration
# ------------------------------------------------------------

log "Verifying IAM role..."

aws iam get-role \
    --role-name "$IAM_ROLE_NAME" \
    --query 'Role.[RoleName,Arn,CreateDate]' \
    --output table

log "Verifying attached policies..."

aws iam list-attached-role-policies \
    --role-name "$IAM_ROLE_NAME" \
    --query 'AttachedPolicies[].[PolicyName,PolicyArn]' \
    --output table

log "Verifying SNS topic..."

aws sns get-topic-attributes \
    --topic-arn "$SNS_TOPIC_ARN" \
    --query 'Attributes.TopicArn' \
    --output text

log "Infrastructure provisioning completed successfully."